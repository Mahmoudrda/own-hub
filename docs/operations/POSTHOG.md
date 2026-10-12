# PostHog integration — implemented 12 October 2026

The Flutter app uses `posthog_flutter` 5.53.0 (locked in pubspec.lock), including structured Logs support. The project ingestion token supplied by the owner is configured in `app/lib/app_state/posthog_analytics.dart` with `https://us.i.posthog.com`. A project ingestion token is client configuration; no personal API key or dashboard credential is committed.

The wizard's help was inspected with `npx -y @posthog/wizard@latest --help`. Its authenticated setup expects a personal key/OAuth; the supplied `phc_` ingestion token is not that credential. Integration was completed directly using the [official Flutter SDK documentation](https://posthog.com/docs/libraries/flutter) and installed SDK source rather than giving a second setup process control of repository edits.

## What runs

- Android and iOS only. Native `AUTO_INIT` and push-open prewarm are disabled; Dart initializes only after usage-statistics consent. Web/macOS integration is not enabled by this change.
- Release builds use PostHog alongside existing Firebase analytics. Debug/profile send nothing remotely unless explicitly started with `--dart-define=OWNHUB_ANALYTICS_DEBUG=true`, and still require consent.
- Consent key v2 intentionally does not inherit the old Google-only grant. The existing optional switch names both processors. The switch and account-data erase stop new app captures and request opt-out/reset. SDK calls cannot block signup or the first frame.
- Only eight milestones: tutorial begin/complete, sign-up begin/complete, login, workout start/complete, coach enquiry sent. No per-set, screen-view or button-click firehose. Incoming event properties are discarded, and `$geoip_disable` is set on captures. SDK technical metadata and a pseudonymous identifier still exist; this is not zero-data analytics.
- At most 120 attempted milestones per app process; consent toggling does not reset the cap. This is a device-side guard, not an organization-wide monthly cap. Queues are bounded and batches flush normally; no flush per tap.
- One fixed `analytics_ready` info log per process after consent, with only `integration=flutter` and `schema_version=1`; service `own-hub-mobile`. No order IDs, user text, exception bodies or health values. The log rate/buffer is bounded.
- Replay, surveys, feature-flag preloading/events, lifecycle capture, rage-click capture, push subscription/open capture and error autocapture are disabled. No person profiles, identify, alias or user-property calls are added. Existing Firebase crash consent remains separate.
- `--dart-define=OWNHUB_POSTHOG_ENABLED=false` disables the integration for a build. Android already requires API 24, above the SDK floor, so it was not downgraded to 21/23.

## Verification commands

```sh
(cd app && flutter analyze)
(cd app && flutter test test/release/posthog_analytics_test.dart \
  test/release/analytics_consent_test.dart \
  test/release/analytics_privacy_guard_test.dart \
  test/domain/analytics_gateway_test.dart \
  test/routing/analytics_events_test.dart \
  test/features/account/privacy_view_test.dart \
  test/features/signup/phone_number_view_test.dart \
  test/features/cycle/cycle_no_analytics_call_sites_test.dart)
# With a connected supported device:
(cd app && flutter run --dart-define=OWNHUB_ANALYTICS_DEBUG=true)
```

On a fresh synthetic device/account, first leave statistics off and inspect traffic: no PostHog initialization/ingestion. Turn “Help improve Own Hub” on and perform an actual allowed milestone; after the batch interval look for that event and `analytics_ready` under Logs/service `own-hub-mobile`. Turn it off, exercise the same flow, background/restart, and verify no new events/logs. Repeat offline/reconnect to inspect the native SDK's persisted queues as well as the app's queue. Test account-data erase separately. Do not send real health or identity data to test analytics.

Unit tests exercise initialization/consent races, revocation, allowlisting, failure isolation, caps, old-consent migration, native configuration and optional collection settings. They cannot prove live ingestion, dashboard settings, native offline queue behavior or regional transfer legality. Capture evidence for those checks before release. See acceptance checklist A01–A05.

## Free-tier and release operations

The [current pricing page](https://posthog.com/pricing) lists 1 million analytics events and 10 GB logs per month in the free allowance, with free-plan analytics retention of one year and default logs retention of 14 days. Recheck when launching. Do not add paid products or a payment card to make integration work. If a card is already present, verify each product's billing limit is $0 in the dashboard. Project-wide limits are owner/dashboard settings; this ingestion token cannot verify or change them. Keep recording and other automatic products disabled in the project too.

Bilingual in-app and website privacy copy and store-declaration notes were updated locally; this commit does not deploy the website or submit new store disclosures. The notices describe current processor use, not a legal certification. Review processor agreements, retention, deletion handling and US transfers for Egypt before launching, and for Saudi Arabia/UAE only before any later expansion. Anonymous-looking IDs may still be personal data; opting out/resetting a device identifier does not itself erase previously ingested provider records.
