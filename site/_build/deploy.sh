#!/usr/bin/env bash
# Build the Own Hub website for its domain and publish it on Cloudflare Pages.
#
# Usage (from anywhere):
#   site/_build/deploy.sh https://your-domain              build, check, deploy
#   site/_build/deploy.sh https://your-domain --dry-run    build and check only
#   BASE_URL=https://your-domain site/_build/deploy.sh     the same, from the environment
#
# Options:
#   --dry-run               stop after the build and the checks; print the folder
#   --yes                   do not ask before uploading
#   --project NAME          Cloudflare Pages project (default: ownhub)
#   --branch NAME           branch to deploy as (default: main, the production branch)
#   --keep-contact-emails   keep the mailbox in config.json instead of privacy@ and
#                           support@ the domain
#   --skip-mail-check       do not look up the domain's MX record
#   --skip-origin-check     do not compare the waitlist function's SITE_ORIGIN
#
# What it does:
#   1. builds the site for the domain into a fresh temporary folder that holds
#      only what is published (pages, assets, _headers, _redirects; never
#      _build/ or config.json), and runs the build's internal link check;
#   2. refuses to go on if the waitlist function would send visitors back to a
#      different domain, or if the domain cannot receive mail yet;
#   3. uploads the folder with Wrangler:
#        npx wrangler pages deploy <folder> --project-name ownhub --branch main
#      Command reference:
#        https://developers.cloudflare.com/workers/wrangler/commands/pages/
#        https://developers.cloudflare.com/pages/how-to/use-direct-upload-with-continuous-integration/
#
# ONE-TIME SETUP, the first time only
#   a. Log Wrangler in to the Cloudflare account:   npx wrangler login
#      (or export CLOUDFLARE_API_TOKEN and CLOUDFLARE_ACCOUNT_ID for a token)
#   b. Create the Pages project, with main as its production branch:
#        npx wrangler pages project create ownhub --production-branch main
#   c. Point the waitlist function at the domain. In functions/waitlist/join.py
#      set SITE_ORIGIN = "https://your-domain", set "baseUrl" in
#      site/config.json to the same value (a test holds the two together), and
#      redeploy the join_waitlist function. Until then the form would send a
#      visitor back to the placeholder address after she joins.
#   d. Make privacy@ and support@ the domain reach the monitored mailbox
#      (skip with --keep-contact-emails). With the domain on Cloudflare:
#      dashboard > the domain > Email > Email Routing > Get started, add the
#      Gmail address as a destination and confirm it from the email Cloudflare
#      sends, then add two custom addresses, privacy and support, each set to
#      "Send to an email" > that Gmail address. Cloudflare adds the MX and TXT
#      records itself. https://developers.cloudflare.com/email-routing/get-started/
#      Then tell counsel: the mail passes through Cloudflare before Gmail, which
#      the privacy policy's list of processors should say.
#
# ATTACHING THE DOMAIN, in the Cloudflare dashboard, after the first deploy
#   (https://developers.cloudflare.com/pages/configuration/custom-domains/)
#   1. Buy the domain, or add it to Cloudflare: dashboard > Add a domain, then
#      at the registrar replace the nameservers with the two Cloudflare shows.
#      An apex domain (your-domain, not www.your-domain) must be a zone on the
#      same Cloudflare account as the Pages project.
#   2. Workers & Pages > ownhub > Custom domains > Set up a domain.
#   3. Enter your-domain, select Continue, then Activate domain. Cloudflare
#      creates the CNAME record itself when the domain is a zone on the account.
#   4. Repeat for www.your-domain, then send www to the apex: Rules >
#      Redirect Rules > Create rule > "Redirect from WWW to root" template
#      (https://developers.cloudflare.com/rules/url-forwarding/examples/redirect-www-to-root/).
#   5. Wait until the domain shows Active (the certificate is issued for you),
#      then open https://your-domain/privacy and check it loads with a 200.
#   6. Search engines: submit https://your-domain/sitemap.xml in Google Search
#      Console. The project's *.pages.dev address stays out of the index (see
#      _headers).
#   7. Give the stores https://your-domain/privacy, /terms, /support and
#      /delete-account (Arabic: /ar/privacy and so on).
set -euo pipefail

HERE="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
SITE="$(dirname "$HERE")"
REPO="$(dirname "$SITE")"

BASE="${BASE_URL:-}"
PROJECT="ownhub"
BRANCH="main"
DRY=0
YES=0
KEEP=0
SKIP_MAIL=0
SKIP_ORIGIN=0

while [ $# -gt 0 ]; do
  case "$1" in
    --dry-run) DRY=1 ;;
    --yes) YES=1 ;;
    --project) PROJECT="$2"; shift ;;
    --branch) BRANCH="$2"; shift ;;
    --keep-contact-emails) KEEP=1 ;;
    --skip-mail-check) SKIP_MAIL=1 ;;
    --skip-origin-check) SKIP_ORIGIN=1 ;;
    -h|--help) sed -n '2,20p' "$0"; exit 0 ;;
    https://*) BASE="$1" ;;
    *) echo "unknown argument: $1" >&2; exit 2 ;;
  esac
  shift
done

if [ -z "$BASE" ]; then
  echo "Give the domain: site/_build/deploy.sh https://your-domain" >&2
  exit 2
fi
BASE="${BASE%/}"
HOST="${BASE#https://}"
case "$HOST" in
  */*|"" ) echo "the domain must look like https://example.com" >&2; exit 2 ;;
esac

# 1. Build into a clean folder outside the repository.
OUT="$(mktemp -d "${TMPDIR:-/tmp}/ownhub-site.XXXXXX")/site"
BUILD_ARGS=(--base-url "$BASE" --out "$OUT")
[ "$KEEP" = 1 ] && BUILD_ARGS+=(--keep-contact-emails)
python3 "$HERE/build.py" "${BUILD_ARGS[@]}"

# Only publishable files may leave this machine.
LEAKS="$(cd "$OUT" && find . \( -name '_build' -o -name 'config.json' -o -name '*.py' \
  -o -name '*.pyc' -o -name '*.md' -o -name '*.sh' -o -name '.DS_Store' -o -name '.*.swp' \) -print)"
if [ -n "$LEAKS" ]; then
  echo "Refusing to deploy: the output holds files that are not part of the site:" >&2
  echo "$LEAKS" >&2
  exit 1
fi
for f in index.html ar/index.html privacy.html terms.html support.html delete-account.html \
         404.html _headers _redirects sitemap.xml robots.txt; do
  [ -f "$OUT/$f" ] || { echo "Refusing to deploy: $f is missing" >&2; exit 1; }
done

# 2a. The waitlist form posts to a Cloud Function that redirects back to
# SITE_ORIGIN. It has to be this domain.
if [ "$SKIP_ORIGIN" = 0 ]; then
  ORIGIN="$(sed -n 's/^SITE_ORIGIN = "\(.*\)"$/\1/p' "$REPO/functions/waitlist/join.py")"
  if [ "$ORIGIN" != "$BASE" ]; then
    echo >&2
    echo "Stop: functions/waitlist/join.py has SITE_ORIGIN = \"$ORIGIN\"," >&2
    echo "so after joining the waitlist a visitor would be sent to that address." >&2
    echo "Set it (and baseUrl in site/config.json) to $BASE, redeploy join_waitlist," >&2
    echo "then run this again. Or pass --skip-origin-check to deploy anyway." >&2
    exit 1
  fi
fi

# 2b. privacy@ and support@ the domain must be able to receive mail.
if [ "$KEEP" = 0 ] && [ "$SKIP_MAIL" = 0 ]; then
  MAILDOMAIN="${HOST#www.}"
  if command -v dig >/dev/null 2>&1; then
    if [ -z "$(dig +short MX "$MAILDOMAIN")" ]; then
      echo >&2
      echo "Stop: $MAILDOMAIN has no MX record yet, so privacy@$MAILDOMAIN and" >&2
      echo "support@$MAILDOMAIN (now printed on the policy and support pages) bounce." >&2
      echo "Set up Email Routing (see the top of this script), or run again with" >&2
      echo "--keep-contact-emails to publish the mailbox from config.json instead." >&2
      exit 1
    fi
  else
    echo "Note: dig is not installed, so the MX record was not checked." >&2
  fi
fi

echo
echo "Built for $BASE in $OUT"
if [ "$DRY" = 1 ]; then
  echo "Dry run: nothing uploaded. Preview it with:"
  echo "  npx wrangler pages dev \"$OUT\""
  exit 0
fi

if [ "$YES" = 0 ]; then
  printf "Upload to Cloudflare Pages project '%s' (branch %s)? [y/N] " "$PROJECT" "$BRANCH"
  read -r answer
  case "$answer" in y|Y|yes) ;; *) echo "Nothing uploaded."; exit 0 ;; esac
fi

# 3. Publish.
npx wrangler pages deploy "$OUT" --project-name "$PROJECT" --branch "$BRANCH" --commit-dirty=true
