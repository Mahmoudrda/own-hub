import { ref as storageRef, getBytes } from "https://www.gstatic.com/firebasejs/11.0.2/firebase-storage.js";
import * as L from "./logic.js";

const FILE_MAX_BYTES = 12 * 1024 * 1024;

// Mounts the private coaching tabs. `ctx` carries the dashboard's own helpers so
// the look, the dialogs and the error handling stay the same everywhere.
export function mountCoaching(ctx) {
  const { h, $, call, notice, askDialog, setEmpty, skeletons, setBadge, getState } = ctx;
  const claims = () => getState().claims ?? {};
  const personal = () => getState().personalStorage;
  const fail = (e) => notice(L.coachingMessage(e));

  const dateFormat = (v, extra) => {
    const iso = L.toIso(v);
    return iso ? new Intl.DateTimeFormat([], { timeZone: L.TIMEZONE, day: "numeric", month: "short", year: "numeric", ...extra }).format(new Date(iso)) : "";
  };
  const when = (v) => dateFormat(v, { hour: "2-digit", minute: "2-digit" });
  const dateOnly = (v) => dateFormat(v);

  // Runs one action with its button switched off, so a double tap sends once.
  async function busy(btn, fn) {
    if (btn) btn.disabled = true;
    try { return await fn(); } catch (e) { fail(e); return undefined; } finally { if (btn?.isConnected) btn.disabled = false; }
  }

  const row = (label, value) => (value === undefined || value === null || value === "" ? null
    : h("div", { class: "kv" }, h("span", { class: "k", text: label }), h("span", { class: "v", text: String(value) })));

  // A re-render drops the pressed button, so focus is handed back by its data-k.
  const refocus = (root, k) => root.querySelector(`[data-k="${k}"]`)?.focus();

  function chipGroup({ label, options, labels, value, onPick, key }) {
    return h("div", { class: "chips", role: "group", "aria-label": label },
      options.map((o) => h("button", {
        class: "chip", type: "button", "aria-pressed": String(value === o), "data-k": `${key}:${o}`,
        onclick: () => onPick(value === o ? "" : o),
      }, labels[o] ?? o)));
  }

  /* files in the personal bucket */

  const dataUrls = new Map();

  function readAsDataUrl(blob) {
    return new Promise((resolve, reject) => {
      const r = new FileReader();
      r.onload = () => resolve(r.result);
      r.onerror = () => reject(r.error);
      r.readAsDataURL(blob);
    });
  }

  async function fetchBlob(path, mime) {
    const bytes = await getBytes(storageRef(personal(), path), FILE_MAX_BYTES);
    return new Blob([bytes], { type: mime || (L.fileKind(path) === "pdf" ? "application/pdf" : "image/jpeg") });
  }

  // Pictures travel as data URLs: the page policy allows data: images, not blob: ones.
  async function imageUrl(path, mime) {
    if (dataUrls.has(path)) return dataUrls.get(path);
    const url = await readAsDataUrl(await fetchBlob(path, mime));
    dataUrls.set(path, url);
    return url;
  }

  function fileProblem(e) {
    const code = e?.code ?? "";
    if (code === "storage/object-not-found") return "The file is not in storage.";
    if (code === "storage/unauthorized") return "This account can not open that file.";
    return "The file could not be loaded.";
  }

  function saveBlob(blob, name) {
    const url = URL.createObjectURL(blob);
    const a = h("a", { href: url, download: name });
    document.body.append(a);
    a.click();
    a.remove();
    setTimeout(() => URL.revokeObjectURL(url), 60000);
  }

  function fileName(path) {
    return String(path ?? "").split("/").pop() || "file";
  }

  // A picture shown in place, a PDF with Open and Download, anything else with Download.
  function fileView(path, { label, mime = "", big = false } = {}) {
    if (!path) return h("p", { class: "muted", text: `${label}: no file` });
    const kind = L.fileKind(path, mime);
    if (kind === "image") {
      const box = h("figure", { class: `proof-fig${big ? " big" : ""}` }, h("p", { class: "muted", text: "Loading picture..." }));
      const load = async () => {
        box.replaceChildren(h("p", { class: "muted", text: "Loading picture..." }));
        try {
          const src = await imageUrl(path, mime);
          box.replaceChildren(h("img", { src, alt: label, class: "proof-img" }));
        } catch (e) {
          box.replaceChildren(h("p", { class: "field-error", text: fileProblem(e) }), h("button", { class: "btn ctl", type: "button", onclick: load }, "Try again"));
        }
      };
      load();
      return box;
    }
    const status = h("span", { class: "muted", role: "status", "aria-live": "polite" });
    const open = h("button", { class: "btn ctl", type: "button" }, "Open");
    const download = h("button", { class: "btn ctl", type: "button" }, "Download");
    if (kind !== "pdf") open.hidden = true;
    open.addEventListener("click", () => busy(open, async () => {
      // The tab is opened first, while the tap still counts, then pointed at the file.
      const tab = window.open("about:blank", "_blank");
      status.textContent = "Loading...";
      try {
        const blob = await fetchBlob(path, mime);
        const url = URL.createObjectURL(blob);
        if (tab) { tab.location.href = url; status.textContent = "Opened in a new tab. If it stays blank, use Download."; }
        else { saveBlob(blob, fileName(path)); status.textContent = "Pop-ups are blocked, so the file was downloaded."; }
        setTimeout(() => URL.revokeObjectURL(url), 5 * 60000);
      } catch (e) { tab?.close(); status.textContent = fileProblem(e); }
    }));
    download.addEventListener("click", () => busy(download, async () => {
      status.textContent = "Loading...";
      try { saveBlob(await fetchBlob(path, mime), fileName(path)); status.textContent = ""; } catch (e) { status.textContent = fileProblem(e); }
    }));
    return h("div", { class: "file-row" }, h("span", { class: "file-name", text: `${label}: ${fileName(path)}` }), open, download, status);
  }

  /* shared list scaffolding */

  function mountLoading(root) {
    root.replaceChildren(h("ul", { class: "list", "aria-busy": "true" }, skeletons(3)));
  }

  function loadFailed(root, retry, what) {
    const box = h("div", { class: "empty-state" });
    root.replaceChildren(box);
    setEmpty(box, { title: `${what} could not be loaded.`, hint: "Check your internet connection and try again.", art: "plug", action: { label: "Try again", onclick: retry } });
  }

  // The "Load more" button under a list. It is left out when the server has no more.
  function loadMoreButton(next, loading, onClick) {
    if (!next) return null;
    return h("div", { class: "actions" },
      h("button", { class: "btn", type: "button", "data-k": "load-more", "aria-busy": String(loading), disabled: loading, onclick: onClick }, loading ? "Loading..." : "Load more"));
  }

  // Fetches the next page of a list and hands it to `apply` (append), then draws again.
  async function nextPage(state, fetchPage, apply, render, key) {
    if (state.paging) return;
    const start = state.next;
    state.paging = true;
    render();
    try {
      const data = await fetchPage(start);
      // A reload while this page was coming makes it stale.
      if (state.next === start) {
        apply(data.items ?? []);
        state.next = data.next ?? null;
      }
    } catch (e) { fail(e); }
    state.paging = false;
    render();
    refocus($(key), "load-more");
  }

  /* ============== Coaches ============== */

  const co = { status: "submitted", items: [], loaded: false, failed: false, next: null, paging: false, section: "applications", openUid: null, reasons: {}, ticked: new Set(), note: "", counts: 0, suspendOpen: false };

  async function loadCoaches({ quiet = false } = {}) {
    const root = $("coaches-root");
    if (!co.loaded && !quiet) mountLoading(root);
    const status = co.status;
    try {
      const data = await call("list_coach_applications", { status });
      if (status !== co.status) return;
      co.items = data.items ?? [];
      co.next = data.next ?? null;
      co.paging = false;
      co.loaded = true;
      co.failed = false;
      if (status === "submitted") co.counts = co.items.length;
    } catch (e) {
      if (!quiet) fail(e);
      if (!co.loaded) co.failed = true;
    }
    refreshCoachesBadge();
    if (L.canDecidePortfolio(claims()) && !ph.loaded) loadPhotos({ quiet: true });
    if (!quiet || getState().tab === "coaches") renderCoaches();
  }

  const refreshCoachesBadge = () => setBadge("coaches", L.coachesBadgeCount(co.counts, ph.items.length), "waiting");

  function renderCoaches() {
    const root = $("coaches-root");
    if (co.failed && !co.loaded) { loadFailed(root, () => loadCoaches(), "The applications"); return; }
    if (!co.loaded) { mountLoading(root); return; }
    if (co.openUid) { renderApplication(root); return; }
    if (co.section === "photos") { renderPhotos(root); return; }
    const chips = h("div", { class: "chips", role: "group", "aria-label": "Show" },
      L.APPLICATION_STATUSES.map((s) => h("button", {
        class: "chip", type: "button", "aria-pressed": String(co.status === s),
        onclick: () => { co.status = s; co.loaded = false; co.items = []; loadCoaches(); },
      }, L.APPLICATION_STATUS_LABELS[s])));
    const list = h("ul", { class: "list", "aria-busy": "false" }, co.items.map((a, i) => applicationCard(a, i)));
    const empty = h("div", { class: "empty-state", hidden: co.items.length > 0 });
    if (!co.items.length) setEmpty(empty, { title: co.status === "submitted" ? "No applications are waiting." : "Nothing here yet.", hint: "New applications appear here as soon as a coach sends one.", art: "lockers" });
    root.replaceChildren(
      h("div", { class: "panel-head" }, h("h2", { text: "Coach applications" }),
        h("p", { class: "about", text: "Coaches who applied to Own Hub. Review each application, then approve it, ask for changes or reject it." }), h("p", { class: "muted", text: `${co.items.length} ${L.APPLICATION_STATUS_LABELS[co.status].toLowerCase()}` })),
      sectionSwitch(), h("div", { class: "filters" }, chips), list, empty,
      loadMoreButton(co.next, co.paging, loadMoreCoaches));
  }

  // Applications or Portfolio photos, for accounts that may check photos.
  function sectionSwitch() {
    if (!L.canDecidePortfolio(claims())) return null;
    const tab = (id, label) => h("button", {
      class: "chip", type: "button", "aria-pressed": String(co.section === id), "data-k": `section:${id}`,
      onclick: () => { co.section = id; renderCoaches(); refocus($("coaches-root"), `section:${id}`); },
    }, label);
    return h("div", { class: "chips", role: "group", "aria-label": "Coaches sections" },
      tab("applications", "Applications"), tab("photos", ph.items.length ? `Portfolio photos (${ph.items.length}${ph.next ? "+" : ""})` : "Portfolio photos"));
  }

  /* ---- Portfolio photos ---- */

  const ph = { items: [], loaded: false, failed: false, next: null, paging: false, reason: "" };

  async function loadPhotos({ quiet = false } = {}) {
    if (!L.canDecidePortfolio(claims())) return;
    try {
      const data = await call("list_portfolio_media", {});
      ph.items = data.items ?? [];
      ph.next = data.next ?? null;
      ph.paging = false;
      ph.loaded = true;
      ph.failed = false;
    } catch (e) {
      if (!quiet) fail(e);
      if (!ph.loaded) ph.failed = true;
    }
    refreshCoachesBadge();
    if (getState().tab === "coaches" && co.section === "photos" && !co.openUid) renderCoaches();
  }

  function loadMorePhotos() {
    return nextPage(ph, (after) => call("list_portfolio_media", { after }),
      (items) => { ph.items = L.appendPage(ph.items, items, L.portfolioKey); refreshCoachesBadge(); }, renderCoaches, "coaches-root");
  }

  function photoHead() {
    return h("div", { class: "panel-head" }, h("h2", { text: "Portfolio photos" }),
      h("p", { class: "about", text: "Coaches' transformations, feedback and photos. Members see each one only after you approve it." }),
      h("p", { class: "muted", "aria-live": "polite", text: ph.items.length ? `${ph.items.length}${ph.next ? "+" : ""} waiting` : "" }));
  }

  function renderPhotos(root) {
    if (ph.failed && !ph.loaded) { loadFailed(root, () => { ph.failed = false; loadPhotos(); }, "The portfolio photos"); return; }
    if (!ph.loaded) { mountLoading(root); loadPhotos(); return; }
    const item = ph.items[0];
    if (!item) {
      const empty = h("div", { class: "empty-state" });
      setEmpty(empty, { title: "No photos are waiting.", hint: "A coach's new transformation, feedback or photo appears here to be checked before members see it.", art: "sieve" });
      root.replaceChildren(sectionSwitch(), photoHead(), empty, loadMoreButton(ph.next, ph.paging, loadMorePhotos));
      return;
    }
    root.replaceChildren(sectionSwitch(), photoHead(), photoCard(item), loadMoreButton(ph.next, ph.paging, loadMorePhotos));
  }

  function photoCard(item) {
    const pic = (path, label) => fileView(path, { label });
    let body;
    if (item.kind === "transformation") {
      body = h("div", {},
        h("div", { class: "ba" },
          h("div", {}, h("span", { class: "flabel", text: "Before" }), pic(item.beforePath, "Before photo")),
          h("div", {}, h("span", { class: "flabel", text: "After" }), pic(item.afterPath, "After photo"))),
        h("div", {}, h("span", { class: "flabel", text: "Her client's written agreement" }),
          item.consentPath ? pic(item.consentPath, "Written agreement") : h("p", { class: "badge known", text: "No written agreement uploaded: do not approve" })),
        row("Weeks", item.weeks), row("Note", item.note),
        h("p", { class: "badge sage", text: `${L.PORTFOLIO_CONSENT_LINE}${item.consent?.at ? ` · ${dateOnly(item.consent.at)}` : ""}` }));
    } else if (item.kind === "feedback") {
      body = h("div", {}, h("blockquote", { text: item.text ?? "" }), row("From", item.from),
        item.imagePath ? pic(item.imagePath, "Feedback screenshot") : null);
    } else {
      body = h("div", {}, pic(item.imagePath, "Photo"), row("Caption", item.caption));
    }
    const problems = h("div", { class: "problems", role: "alert", hidden: true });
    return h("section", { class: "card", "aria-labelledby": "ph-title" },
      h("h3", { id: "ph-title", text: item.coachName || "Unnamed coach" }),
      h("p", { class: "meta" }, h("span", { class: "badge", text: L.PORTFOLIO_KIND_LABELS[item.kind] ?? item.kind })),
      body,
      h("div", { class: "reason-box" },
        h("span", { class: "flabel", text: "Reason, if you reject it" }),
        chipGroup({
          label: "Reason for rejecting", options: L.PORTFOLIO_REJECT_REASONS, labels: L.PORTFOLIO_REJECT_LABELS, value: ph.reason, key: "ph-reason",
          onPick: (v) => { const was = ph.reason; ph.reason = v; renderCoaches(); refocus($("coaches-root"), `ph-reason:${v || was}`); },
        })),
      problems,
      h("div", { class: "actions" },
        h("button", { class: "btn primary big", type: "button", onclick: (ev) => decidePhoto(ev.currentTarget, item, "approve", problems) }, "Approve"),
        h("button", { class: "btn quiet-danger", type: "button", onclick: (ev) => decidePhoto(ev.currentTarget, item, "reject", problems) }, "Reject")));
  }

  async function decidePhoto(btn, item, decision, problemsBox) {
    const problems = L.portfolioRejectProblems(decision, ph.reason);
    problemsBox.replaceChildren(...(problems.length ? [h("ul", {}, problems.map((p) => h("li", { text: p })))] : []));
    problemsBox.hidden = problems.length === 0;
    if (problems.length) return;
    await busy(btn, async () => {
      await call("decide_portfolio_media", L.portfolioDecisionPayload(item, decision, ph.reason));
      notice(decision === "approve" ? "Approved. Members can see it." : "Rejected. The coach is told why.", true);
      ph.items = ph.items.filter((x) => L.portfolioKey(x) !== L.portfolioKey(item));
      ph.reason = "";
      refreshCoachesBadge();
      renderCoaches();
      if (!ph.items.length && ph.next) loadMorePhotos();
    });
  }

  function loadMoreCoaches() {
    const status = co.status;
    return nextPage(co, (after) => call("list_coach_applications", { status, after }),
      (items) => { if (status === co.status) co.items = L.appendPage(co.items, items, (x) => x.uid); }, renderCoaches, "coaches-root");
  }

  function applicationCard(a, i) {
    const p = a.personal ?? {};
    return h("li", { class: "item", vars: { "--i": Math.min(i, 8) } },
      h("div", { class: "item-head" },
        h("div", { class: "who" },
          h("div", { class: "name", text: p.displayName || p.fullName || "Unnamed coach" }),
          h("div", { class: "meta" },
            h("span", { class: "badge", text: L.APPLICATION_STATUS_LABELS[a.status] ?? a.status }),
            a.round > 1 ? h("span", { text: `Round ${a.round}` }) : null,
            a.submittedAt ? h("span", { text: `Sent ${when(a.submittedAt)}` }) : null),
          h("div", { class: "muted", text: (a.specialties ?? []).join(", ") })),
        h("button", { class: "btn primary", type: "button", onclick: () => openApplication(a.uid) }, "Review")));
  }

  function openApplication(uid) {
    co.openUid = uid;
    co.reasons = {};
    co.ticked = new Set();
    co.note = "";
    co.suspendOpen = false;
    renderCoaches();
    window.scrollTo({ top: 0, behavior: "auto" });
    $("coaches-root").querySelector("h2")?.focus();
  }

  function closeApplication() {
    co.openUid = null;
    renderCoaches();
  }

  function sectionCard(section, body) {
    const decidable = currentApp()?.status === "submitted";
    return h("section", { class: "card", "aria-labelledby": `sec-${section}` },
      h("h3", { id: `sec-${section}`, text: L.SECTION_LABELS[section] }),
      body,
      decidable && L.SECTIONS.includes(section) ? h("div", { class: "reason-box" },
        h("span", { class: "flabel", text: "Reason, if this section needs work" }),
        chipGroup({
          label: `Reason for ${L.SECTION_LABELS[section]}`, options: L.SECTION_REASONS, labels: L.SECTION_REASON_LABELS, value: co.reasons[section] ?? "",
          key: section,
          onPick: (v) => { const was = co.reasons[section]; if (v) co.reasons[section] = v; else delete co.reasons[section]; renderApplication($("coaches-root"), { focusK: `${section}:${v || was}` }); },
        })) : null);
  }

  const currentApp = () => co.items.find((x) => x.uid === co.openUid);

  function renderApplication(root, { keepFocus = null, focusK = null } = {}) {
    const a = currentApp();
    if (!a) { co.openUid = null; renderCoaches(); return; }
    const p = a.personal ?? {};
    const certs = a.certificates ?? [];
    const open = a.status === "submitted";
    const ticked = [...co.ticked].filter((id) => certs.some((c) => c.id === id));
    const nameMatches = L.namesMatch(p.fullName, a.payout?.holderName);

    const head = h("div", { class: "review-bar" },
      h("button", { class: "btn", type: "button", onclick: closeApplication }, "Back to the list"),
      h("span", { class: "review-where", text: `${L.APPLICATION_STATUS_LABELS[a.status] ?? a.status}${a.round > 1 ? ` · round ${a.round}` : ""}` }));

    const cards = [
      sectionCard("personal", h("div", {},
        row("Legal name", p.fullName), row("Shown as", p.displayName), row("Governorate", p.governorate),
        row("Languages", (p.languages ?? []).join(", ")), row("Headline", p.headline),
        p.photoPath ? fileView(p.photoPath, { label: "Profile photo" }) : null)),
      sectionCard("education", (a.education ?? []).length ? h("ul", { class: "plain-list" }, a.education.map((e) => h("li", {},
        h("strong", { text: e.degree }), h("span", { class: "muted", text: ` · ${e.institution ?? ""}${e.year ? ` · ${e.year}` : ""}` }),
        fileView(e.path, { label: `${e.degree || "Education"} file` })))) : h("p", { class: "muted", text: "None added." })),
      sectionCard("certificates", certs.length ? h("ul", { class: "plain-list" }, certs.map((c) => h("li", {},
        h("strong", { text: c.title }), h("span", { class: "muted", text: ` · ${c.issuer ?? ""}${c.year ? ` · ${c.year}` : ""}` }),
        fileView(c.path, { label: `${c.title || "Certificate"} file`, mime: c.mime }),
        open ? h("label", { class: "opt", for: `cert-${c.id}` },
          h("input", {
            type: "checkbox", id: `cert-${c.id}`, checked: co.ticked.has(c.id),
            onchange: (ev) => { if (ev.target.checked) co.ticked.add(c.id); else co.ticked.delete(c.id); renderApplication(root, { keepFocus: `cert-${c.id}` }); },
          }),
          h("span", { class: "opt-text" }, h("span", { class: "opt-name", text: "I checked this certificate" }))) : null))) : h("p", { class: "muted", text: "None added." })),
      sectionCard("specialties", h("div", {},
        h("div", { class: "chips" }, (a.specialties ?? []).map((s) => h("span", { class: "badge", text: s }))),
        row("Years of experience", a.yearsExperience), row("Qualifications", a.qualifications))),
      sectionCard("feedback", (a.testimonials ?? []).length ? h("ul", { class: "plain-list" }, a.testimonials.map((t) => h("li", {},
        h("blockquote", { text: t.text }), h("span", { class: "muted", text: `From ${t.from ?? "unnamed"}${t.source ? ` · ${t.source}` : ""}` }),
        t.imagePath ? fileView(t.imagePath, { label: "Feedback screenshot" }) : null))) : h("p", { class: "muted", text: "None added." })),
      sectionCard("transformations", (a.transformations ?? []).length ? h("ul", { class: "plain-list" }, a.transformations.map((t) => h("li", {},
        h("div", { class: "ba" },
          h("div", {}, h("span", { class: "flabel", text: "Before" }), fileView(t.beforePath, { label: "Before photo" })),
          h("div", {}, h("span", { class: "flabel", text: "After" }), fileView(t.afterPath, { label: "After photo" }))),
        row("Weeks", t.weeks), row("Note", t.note),
        h("p", { class: t.clientConsent ? "badge sage" : "badge known", text: t.clientConsent ? "The client agreed to the photos being used" : "No consent from the client" })))) : h("p", { class: "muted", text: "None added." })),
      sectionCard("approach", h("div", {},
        h("p", { text: a.approach?.text ?? "" }),
        row("Check-ins per week", a.approach?.checkInsPerWeek), row("Replies within (hours)", a.approach?.replyHours),
        row("Trains", (a.approach?.trainsWhere ?? []).join(", ")))),
      a.payout ? sectionCard("payout", h("div", {},
        row("Rail", L.railLabel(a.payout?.rail)), row("Account", a.payout?.account), row("Holder name", a.payout?.holderName),
        h("p", { class: nameMatches ? "badge sage" : "badge known", text: nameMatches ? "Holder name matches her legal name" : "Holder name differs from her legal name" }))) : null,
      sectionCard("terms", h("div", {}, row("Terms version", a.termsVersion), row("Rules accepted", L.acceptedRuleLabels(a.rules).join(", ")))),
    ];

    let decision = null;
    if (open) {
      const problemsBox = h("div", { class: "problems", id: "co-problems", role: "alert", hidden: true });
      const noteBox = h("textarea", { id: "co-note", rows: 3, maxlength: "500", oninput: (ev) => { co.note = ev.target.value; } });
      noteBox.value = co.note;
      const approveBtn = h("button", { class: "btn primary big", type: "button", disabled: !L.canApproveApplication(ticked), onclick: (ev) => decide(ev.currentTarget, "approve", problemsBox, ticked) }, "Approve");
      decision = h("div", { class: "card" },
        h("h3", { text: "Decision" }),
        h("label", { for: "co-note", text: "Note to her (optional for Approve)" }), noteBox,
        problemsBox,
        L.canApproveApplication(ticked) ? null : h("p", { class: "hint", text: "To approve, tick at least one certificate you checked." }),
        h("div", { class: "actions" },
          approveBtn,
          h("button", { class: "btn", type: "button", onclick: (ev) => decide(ev.currentTarget, "needs_changes", problemsBox, ticked) }, "Needs changes"),
          h("button", { class: "btn quiet-danger", type: "button", onclick: (ev) => decide(ev.currentTarget, "reject", problemsBox, ticked) }, "Reject")));
    }
    let suspend = null;
    if (a.status === "approved" && L.isAdmin(claims())) {
      const reason = h("input", { type: "text", id: "co-suspend-reason", maxlength: "200", "aria-label": "Reason for suspending" });
      suspend = h("div", { class: "card" },
        h("h3", { text: "Suspend this coach" }),
        h("p", { class: "muted", text: "She loses coach access at once. Her clients are not refunded by this." }),
        co.suspendOpen ? h("div", {}, h("label", { for: "co-suspend-reason", text: "Reason" }), reason,
          h("div", { class: "actions" },
            h("button", { class: "btn danger", type: "button", onclick: (ev) => suspendCoach(ev.currentTarget, a.uid, reason) }, "Suspend coach"),
            h("button", { class: "btn", type: "button", onclick: () => { co.suspendOpen = false; renderApplication(root); } }, "Cancel")))
          : h("button", { class: "btn quiet-danger", type: "button", onclick: () => { co.suspendOpen = true; renderApplication(root, { keepFocus: "co-suspend-reason" }); } }, "Suspend coach..."));
    }
    if (a.note || Object.keys(a.reasons ?? {}).length) {
      cards.unshift(h("section", { class: "card" }, h("h3", { text: "Earlier decision" }),
        ...Object.entries(a.reasons ?? {}).map(([s, r]) => row(L.SECTION_LABELS[s] ?? s, L.SECTION_REASON_LABELS[r] ?? r)), row("Note", a.note)));
    }
    root.replaceChildren(head, h("h2", { class: "review-title", tabindex: "-1", text: p.displayName || p.fullName || "Application" }), ...cards, ...[decision, suspend].filter(Boolean));
    if (keepFocus) $(keepFocus)?.focus();
    if (focusK) refocus(root, focusK);
  }

  async function decide(btn, decision, problemsBox, ticked) {
    const problems = L.applicationDecisionProblems(decision, co.reasons);
    problemsBox.replaceChildren(...(problems.length ? [h("ul", {}, problems.map((p) => h("li", { text: p })))] : []));
    problemsBox.hidden = problems.length === 0;
    if (problems.length) return;
    if (decision === "reject") {
      const pick = await askDialog({ title: "Reject this application?", body: "She is told it was rejected, and can apply again after 30 days.", actions: [{ id: "no", label: "Keep reviewing", safe: true }, { id: "yes", label: "Reject", kind: "danger" }] });
      if (pick !== "yes") return;
    }
    await busy(btn, async () => {
      await call("decide_coach_application", L.applicationPayload(co.openUid, decision, { reasons: co.reasons, ticked, note: co.note }));
      notice(decision === "approve" ? "Approved. She is now a coach." : decision === "reject" ? "Rejected." : "Sent back to her for changes.", true);
      co.items = co.items.filter((x) => x.uid !== co.openUid);
      co.counts = co.status === "submitted" ? co.items.length : co.counts;
      co.openUid = null;
      renderCoaches();
      loadCoaches();
    });
  }

  async function suspendCoach(btn, uid, input) {
    const reason = input.value.trim();
    if (!reason) { notice("Write a short reason first."); input.focus(); return; }
    const pick = await askDialog({ title: "Suspend this coach?", body: "She loses coach access at once.", actions: [{ id: "no", label: "Cancel", safe: true }, { id: "yes", label: "Suspend", kind: "danger" }] });
    if (pick !== "yes") return;
    await busy(btn, async () => {
      await call("suspend_coach", { uid, reason });
      notice("Coach suspended.", true);
      co.suspendOpen = false;
      co.openUid = null;
      co.loaded = false;
      loadCoaches();
    });
  }

  /* ============== Payments ============== */

  const pay = { items: [], loaded: false, failed: false, next: null, paging: false, reason: "", justDone: "", opened: false };

  async function loadPayments({ quiet = false } = {}) {
    const root = $("payments-root");
    if (!pay.loaded && !quiet) mountLoading(root);
    try {
      const data = await call("list_payment_proofs", { status: "pending" });
      pay.items = data.items ?? [];
      pay.next = data.next ?? null;
      pay.paging = false;
      pay.loaded = true;
      pay.failed = false;
    } catch (e) {
      if (!quiet) fail(e);
      if (!pay.loaded) pay.failed = true;
    }
    setBadge("payments", pay.items.length, "waiting");
    if (!quiet || getState().tab === "payments") renderPayments();
  }

  function renderPayments() {
    const root = $("payments-root");
    if (pay.failed && !pay.loaded) { loadFailed(root, () => loadPayments(), "The payments"); return; }
    if (!pay.loaded) { mountLoading(root); return; }
    const done = pay.justDone ? h("p", { class: "notice ok inline-note", role: "status", text: pay.justDone }) : null;
    const head = h("div", { class: "panel-head" }, h("h2", { text: "Payments to check" }),
      h("p", { class: "about", text: "Members who say they have paid. Check the screenshot and the amount, then approve or reject it." }), h("p", { class: "muted", "aria-live": "polite", text: pay.items.length ? `${pay.items.length} waiting, oldest first` : "" }));
    const p = pay.items[0];
    if (!p) {
      const empty = h("div", { class: "empty-state" });
      setEmpty(empty, { title: "No payments are waiting.", hint: "A new payment appears here when a member says she has paid.", art: "vault" });
      root.replaceChildren(...[head, done, empty].filter(Boolean));
      return;
    }
    const differs = L.amountMismatch(p.expectedEgp, p.amountEgp);
    const problemsBox = h("div", { class: "problems", id: "pay-problems", role: "alert", hidden: true });
    root.replaceChildren(...[head, done,
      h("section", { class: "card", "aria-label": "Payment to check" },
        h("div", { class: "pay-grid" },
          fileView(p.imagePath, { label: "Payment screenshot", big: true }),
          h("div", { class: "pay-facts" },
            h("div", { class: `amount-pair${differs ? " differs" : ""}` },
              h("div", {}, h("span", { class: "flabel", text: "Expected" }), h("strong", { class: "amount", text: L.formatEgp(p.expectedEgp) })),
              h("div", {}, h("span", { class: "flabel", text: "She entered" }), h("strong", { class: "amount", text: L.formatEgp(p.amountEgp) }))),
            differs ? h("p", { class: "field-error", role: "alert", text: "The amounts are different. Check the screenshot before you decide." }) : null,
            row("Coach", p.coachName), row("Package", p.packageTitle), row("Payment code", p.paymentCode), row("Reference", p.reference), row("Rail", L.railLabel(p.rail)),
            row("Sender name", p.senderName), row("Paid on", dateOnly(p.paidAt)), row("Sent", when(p.createdAt)),
            (p.flags ?? []).length ? h("div", { class: "chips flags", role: "list", "aria-label": "Warnings" }, p.flags.map((f) => h("span", { class: "badge flag", role: "listitem", text: L.flagLabel(f) }))) : null)),
        h("div", { class: "reason-box" },
          h("span", { class: "flabel", text: "Reason, if you reject it" }),
          chipGroup({ label: "Reject reason", options: L.PROOF_REJECT_REASONS, labels: L.PROOF_REJECT_LABELS, value: pay.reason, key: "pay", onPick: (v) => { const was = pay.reason; pay.reason = v; renderPayments(); refocus($("payments-root"), `pay:${v || was}`); } })),
        problemsBox,
        h("div", { class: "actions" },
          h("button", { class: "btn primary big", type: "button", onclick: (ev) => decidePayment(ev.currentTarget, p, "approve", problemsBox) }, "Approve"),
          h("button", { class: "btn", type: "button", onclick: (ev) => decidePayment(ev.currentTarget, p, "reject", problemsBox) }, "Reject"),
          pay.items.length > 1 ? h("button", { class: "btn quiet", type: "button", onclick: () => { pay.items.push(pay.items.shift()); pay.reason = ""; renderPayments(); } }, "Skip for now") : null),
        loadMoreButton(pay.next, pay.paging, loadMorePayments))].filter(Boolean));
  }

  function loadMorePayments() {
    return nextPage(pay, (after) => call("list_payment_proofs", { status: "pending", after }),
      (items) => { pay.items = L.appendPage(pay.items, items, (x) => x.proofId); }, renderPayments, "payments-root");
  }

  async function decidePayment(btn, p, decision, problemsBox) {
    if (decision === "reject" && !pay.reason) {
      problemsBox.replaceChildren(h("ul", {}, h("li", { text: "Pick a reason before you reject." })));
      problemsBox.hidden = false;
      return;
    }
    await busy(btn, async () => {
      await call("decide_payment_proof", { proofId: p.proofId, decision, ...(decision === "reject" ? { reason: pay.reason } : {}) });
      pay.items = pay.items.filter((x) => x !== p);
      pay.reason = "";
      pay.justDone = `${decision === "approve" ? "Approved" : "Rejected"}. Screenshot deleted.`;
      setBadge("payments", pay.items.length, "waiting");
      renderPayments();
      $("payments-root").querySelector("[role=status]")?.scrollIntoView({ block: "nearest" });
      if (!pay.items.length) loadPayments({ quiet: true });
    });
  }

  /* ============== Refunds ============== */

  const rf = { items: [], loaded: false, failed: false, next: null, paging: false, form: {} };

  async function loadRefunds({ quiet = false } = {}) {
    const root = $("refunds-root");
    if (!rf.loaded && !quiet) mountLoading(root);
    try {
      const data = await call("list_refund_requests", {});
      rf.items = data.items ?? [];
      rf.next = data.next ?? null;
      rf.paging = false;
      rf.loaded = true;
      rf.failed = false;
    } catch (e) {
      if (!quiet) fail(e);
      if (!rf.loaded) rf.failed = true;
    }
    setBadge("refunds", rf.items.length, "waiting");
    if (!quiet || getState().tab === "refunds") renderRefunds();
  }

  const refundAmount = (s) => s.cancellation.refundEgp;

  function renderRefunds() {
    const root = $("refunds-root");
    if (rf.failed && !rf.loaded) { loadFailed(root, () => loadRefunds(), "The refund requests"); return; }
    if (!rf.loaded) { mountLoading(root); return; }
    const empty = h("div", { class: "empty-state", hidden: rf.items.length > 0 });
    if (!rf.items.length) setEmpty(empty, { title: "No refund requests.", hint: "A request appears here when a member cancels inside the 14 days.", art: "cabinet" });
    root.replaceChildren(
      h("div", { class: "panel-head" }, h("h2", { text: "Refund requests" }),
        h("p", { class: "about", text: "Members who cancelled inside the 14 days. Send the refund, then record it here." }), h("p", { class: "muted", text: `${rf.items.length} open` })),
      h("ul", { class: "list" }, rf.items.map((s, i) => refundCard(s, i))), empty,
      loadMoreButton(rf.next, rf.paging, loadMoreRefunds));
  }

  function loadMoreRefunds() {
    return nextPage(rf, (after) => call("list_refund_requests", { after }),
      (items) => { rf.items = L.appendPage(rf.items, items, (x) => x.subId); }, renderRefunds, "refunds-root");
  }

  function refundCard(s, i) {
    const id = s.subId;
    const amount = refundAmount(s);
    const f = (rf.form[id] ??= { rail: s.rail || "instapay", reference: "" });
    const refInput = h("input", { type: "text", id: `rf-ref-${id}`, autocomplete: "off", maxlength: "40", oninput: (ev) => { f.reference = ev.target.value; } });
    refInput.value = f.reference;
    const amtInput = h("input", { type: "number", id: `rf-amt-${id}`, readonly: "", "aria-describedby": `rf-amt-note-${id}` });
    amtInput.value = String(amount);
    const rail = h("select", { id: `rf-rail-${id}`, onchange: (ev) => { f.rail = ev.target.value; } },
      Object.entries(L.RAIL_LABELS).map(([v, t]) => h("option", { value: v, selected: f.rail === v }, t)));
    const problems = h("div", { class: "problems", role: "alert", hidden: true });
    return h("li", { class: "item", vars: { "--i": Math.min(i, 8) } },
      h("div", { class: "item-head" }, h("div", { class: "who" },
        h("div", { class: "name", text: s.packageTitle || "Package" }),
        row("Coach", s.coachName), row("Paid by", s.senderName),
        h("div", { class: "meta" }, h("span", { text: `Price ${L.formatEgp(s.priceFinalEgp)}` }), h("span", { text: `${s.sessionsUsed ?? 0} of ${s.sessionsIncluded ?? 0} sessions used` })),
        row("Requested", when(s.cancellation.requestedAt)), row("Her reason", s.cancellation?.reason),
        h("p", { class: "amount-line" }, "Refund: ", h("strong", { text: L.formatEgp(amount) })))),
      h("div", { class: "row" },
        h("div", { class: "inline" }, h("label", { for: `rf-rail-${id}`, text: "Rail" }), rail),
        h("div", { class: "inline" }, h("label", { for: `rf-ref-${id}`, text: "Transfer reference" }), refInput),
        h("div", { class: "inline" }, h("label", { for: `rf-amt-${id}`, text: "Amount (EGP)" }), amtInput,
          h("small", { class: "muted", id: `rf-amt-note-${id}`, text: "Worked out by the server. It checks the amount again when you record." }))),
      problems,
      h("div", { class: "actions" },
        h("button", { class: "btn primary", type: "button", onclick: (ev) => recordRefund(ev.currentTarget, s, f, problems) }, "Record refund"),
        h("button", { class: "btn quiet-danger", type: "button", onclick: (ev) => declineRefund(ev.currentTarget, s) }, "Decline")));
  }

  async function recordRefund(btn, s, f, box) {
    const out = [];
    if (!L.RAIL_PATTERNS[f.rail].reference.test(f.reference.trim())) out.push("The reference is 6 to 40 letters, digits or dashes.");
    const amount = refundAmount(s);
    box.replaceChildren(...(out.length ? [h("ul", {}, out.map((p) => h("li", { text: p })))] : []));
    box.hidden = out.length === 0;
    if (out.length) return;
    await busy(btn, async () => {
      await call("record_refund", { subId: s.subId, decision: "refund", rail: f.rail, reference: f.reference.trim(), amountEgp: amount });
      notice("Refund recorded.", true);
      rf.items = rf.items.filter((x) => x !== s);
      renderRefunds();
      loadRefunds({ quiet: true });
    });
  }

  async function declineRefund(btn, s) {
    const pick = await askDialog({ title: "Decline this refund?", body: "The coaching carries on and she can ask again. She is not sent a message about this, so tell her yourself if she needs to know.", actions: [{ id: "no", label: "Keep it", safe: true }, { id: "yes", label: "Decline", kind: "danger" }] });
    if (pick !== "yes") return;
    await busy(btn, async () => {
      await call("record_refund", { subId: s.subId, decision: "decline" });
      notice("Declined.", true);
      rf.items = rf.items.filter((x) => x !== s);
      renderRefunds();
      loadRefunds({ quiet: true });
    });
  }

  /* ============== Payouts ============== */

  const po = { coaches: [], loaded: false, failed: false, form: {} };

  async function loadPayouts({ quiet = false } = {}) {
    const root = $("payouts-root");
    if (!po.loaded && !quiet) mountLoading(root);
    try {
      const data = await call("list_payouts_owed", {});
      po.coaches = data.coaches ?? [];
      po.loaded = true;
      po.failed = false;
    } catch (e) {
      if (!quiet) fail(e);
      if (!po.loaded) po.failed = true;
    }
    setBadge("payouts", L.payoutBadgeCount(po.coaches), "to pay");
    if (!quiet || getState().tab === "payouts") renderPayouts();
  }

  function renderPayouts() {
    const root = $("payouts-root");
    if (po.failed && !po.loaded) { loadFailed(root, () => loadPayouts(), "The payouts"); return; }
    if (!po.loaded) { mountLoading(root); return; }
    const empty = h("div", { class: "empty-state", hidden: po.coaches.length > 0 });
    if (!po.coaches.length) setEmpty(empty, { title: "Nobody is owed anything.", hint: "Coaches appear here once a client's 14 days are over.", art: "stack" });
    root.replaceChildren(
      h("div", { class: "panel-head" }, h("h2", { text: "Coach payouts" }), h("p", { class: "about", text: "Pay each coach from the Own Hub account, then record it here." })),
      h("ul", { class: "list" }, po.coaches.map((c, i) => payoutCard(c, i))), empty);
  }

  async function copyText(text, what) {
    try { await navigator.clipboard.writeText(text); notice(`${what} copied.`, true); } catch (e) { notice("Copy is not available here. Select the text and copy it."); }
  }

  function payoutCard(c, i) {
    const uid = c.coachUid;
    const acct = c.account ?? null;
    const needsConfirm = L.payoutNeedsConfirm(c);
    const confirmed = c.payoutState === "confirmed";
    const f = (po.form[uid] ??= { rail: acct?.rail || "instapay", reference: "", paidAt: L.cairoDayKey(new Date().toISOString()) });
    const entryIds = c.entryIds;
    const sum = c.amountEgp;
    const ref = h("input", { type: "text", id: `po-ref-${uid}`, autocomplete: "off", maxlength: "40", oninput: (ev) => { f.reference = ev.target.value; } });
    ref.value = f.reference;
    const date = h("input", { type: "date", id: `po-date-${uid}`, max: L.cairoDayKey(new Date().toISOString()), oninput: (ev) => { f.paidAt = ev.target.value; } });
    date.value = f.paidAt;
    const rail = h("select", { id: `po-rail-${uid}`, onchange: (ev) => { f.rail = ev.target.value; } },
      Object.entries(L.RAIL_LABELS).map(([v, t]) => h("option", { value: v, selected: f.rail === v }, t)));
    const problems = h("div", { class: "problems", role: "alert", hidden: true });
    // The account waiting for a decision, when the server sends it.
    const waiting = c.pendingPayout;
    const matches = c.payoutNameMatches;
    const who = c.displayName || "Coach";
    return h("li", { class: "item", vars: { "--i": Math.min(i, 8) } },
      h("div", { class: "item-head" }, h("div", { class: "who" },
        h("div", { class: "name", text: who }),
        h("div", { class: "meta" }, h("span", { class: "badge sage", text: `Owed ${L.formatEgp(sum)}` }),
          h("span", { class: `badge${confirmed ? "" : " known"}`, text: `Account ${c.payoutState ?? "not set"}` })))),
      acct?.account ? h("div", { class: "acct" },
        h("div", {}, h("span", { class: "flabel", text: `${L.railLabel(acct.rail)} · ${acct.holderName ?? ""}` }), h("code", { class: "phone", text: acct.account })),
        h("button", { class: "btn ctl", type: "button", "aria-label": `Copy the account of ${who}`, onclick: () => copyText(acct.account, "Account") }, "Copy")) : h("p", { class: "muted", text: confirmed ? "No payout account on file." : "The account is not confirmed yet, so it is not shown." }),
      needsConfirm ? h("div", { class: "confirm-strip" },
        h("p", { text: waiting ? `Waiting for you: ${L.railLabel(waiting.rail)} ${waiting.account ?? ""}, holder ${waiting.holderName ?? ""}.` : "Her payout account is waiting for you to confirm or reject it." }),
        matches === null ? null : h("p", { class: matches ? "badge sage" : "badge known", text: matches ? "Holder name matches her legal name" : "Holder name does not match her legal name" }),
        waiting?.account ? h("button", { class: "btn ctl", type: "button", onclick: () => copyText(waiting.account, "Account") }, "Copy account") : null,
        h("button", { class: "btn primary", type: "button", onclick: (ev) => confirmAccount(ev.currentTarget, uid, "confirm") }, "Confirm account"),
        h("button", { class: "btn quiet-danger", type: "button", onclick: (ev) => confirmAccount(ev.currentTarget, uid, "reject") }, "Reject account")) : null,
      h("div", { class: "row" },
        h("div", { class: "inline" }, h("label", { for: `po-rail-${uid}`, text: "Rail" }), rail),
        h("div", { class: "inline" }, h("label", { for: `po-ref-${uid}`, text: "Transfer reference" }), ref),
        h("div", { class: "inline" }, h("label", { for: `po-date-${uid}`, text: "Paid on" }), date)),
      h("p", { class: "hint", text: `You are recording ${L.formatEgp(sum)}. The server works out the final amount.` }),
      problems,
      h("div", { class: "actions" },
        h("button", { class: "btn primary", type: "button", disabled: !confirmed || sum <= 0 || !entryIds.length, onclick: (ev) => recordPayout(ev.currentTarget, uid, f, entryIds, problems) }, "Record payout"),
        !confirmed ? h("span", { class: "hint", text: "Confirm her payout account first." }) : null));
  }

  async function confirmAccount(btn, uid, decision) {
    await busy(btn, async () => {
      await call("confirm_payout_account", { uid, decision });
      notice(decision === "confirm" ? "Account confirmed." : "Account rejected.", true);
      await loadPayouts();
    });
  }

  async function recordPayout(btn, uid, f, entryIds, box) {
    const out = [];
    if (!L.RAIL_PATTERNS[f.rail].reference.test(f.reference.trim())) out.push("The reference is 6 to 40 letters, digits or dashes.");
    if (!f.paidAt) out.push("Pick the date you paid.");
    else if (f.paidAt > L.cairoDayKey(new Date().toISOString())) out.push("The date can not be in the future.");
    box.replaceChildren(...(out.length ? [h("ul", {}, out.map((p) => h("li", { text: p })))] : []));
    box.hidden = out.length === 0;
    if (out.length) return;
    await busy(btn, async () => {
      const res = await call("record_coach_payout", { coachUid: uid, entryIds, rail: f.rail, reference: f.reference.trim(), paidAt: f.paidAt });
      notice(`Payout recorded${res?.amountEgp != null ? `: ${L.formatEgp(res.amountEgp)}` : ""}.`, true);
      delete po.form[uid];
      await loadPayouts();
    });
  }

  /* ============== Reports ============== */

  const rp = { items: [], loaded: false, failed: false, next: null, paging: false, notes: {} };

  async function loadReports({ quiet = false } = {}) {
    const root = $("reports-root");
    if (!rp.loaded && !quiet) mountLoading(root);
    try {
      const data = await call("list_coaching_reports", { state: L.REPORT_STATE_OPEN });
      rp.items = data.items ?? [];
      rp.next = data.next ?? null;
      rp.paging = false;
      rp.loaded = true;
      rp.failed = false;
    } catch (e) {
      if (!quiet) fail(e);
      if (!rp.loaded) rp.failed = true;
    }
    setBadge("reports", rp.items.length, "open");
    if (!quiet || getState().tab === "reports") renderReports();
  }

  function renderReports() {
    const root = $("reports-root");
    if (rp.failed && !rp.loaded) { loadFailed(root, () => loadReports(), "The reports"); return; }
    if (!rp.loaded) { mountLoading(root); return; }
    const empty = h("div", { class: "empty-state", hidden: rp.items.length > 0 });
    if (!rp.items.length) setEmpty(empty, { title: "No open reports.", hint: "A report about a coach, a message or a plan appears here.", art: "settle" });
    root.replaceChildren(
      h("div", { class: "panel-head" }, h("h2", { text: "Coaching reports" }),
        h("p", { class: "about", text: "Members' reports about a coach, a message or a plan. Read each one, then dismiss it or act on it." }), h("p", { class: "muted", text: `${rp.items.length} open` })),
      h("ul", { class: "list" }, rp.items.map((r, i) => reportCard(r, i))), empty,
      loadMoreButton(rp.next, rp.paging, loadMoreReports));
  }

  function loadMoreReports() {
    return nextPage(rp, (after) => call("list_coaching_reports", { state: L.REPORT_STATE_OPEN, after }),
      (items) => { rp.items = L.appendPage(rp.items, items, (x) => x.reportId); }, renderReports, "reports-root");
  }

  function reportCard(r, i) {
    const id = r.reportId;
    const snap = Object.entries(r.subject ?? {}).filter(([, v]) => v != null && typeof v !== "object" && v !== "");
    const note = h("textarea", { id: `rp-note-${id}`, rows: 2, maxlength: "500", oninput: (ev) => { rp.notes[id] = ev.target.value; } });
    note.value = rp.notes[id] ?? "";
    return h("li", { class: "item", vars: { "--i": Math.min(i, 8) } },
      h("div", { class: "item-head" }, h("div", { class: "who" },
        h("div", { class: "name", text: L.REPORT_KIND_LABELS[r.subjectKind] ?? r.subjectKind }),
        h("div", { class: "meta" }, h("span", { class: "badge known", text: L.REPORT_REASON_LABELS[r.reason] ?? r.reason }), h("span", { text: `Reported ${when(r.createdAt)}` })),
        r.note ? h("blockquote", { text: r.note }) : null)),
      snap.length ? h("div", { class: "snapshot" }, h("span", { class: "flabel", text: "What was reported" }), snap.map(([k, v]) => row(k, v))) : null,
      h("label", { for: `rp-note-${id}`, text: "Note (optional)" }), note,
      h("div", { class: "actions" }, L.reportDecisionsFor(r.subjectKind).map((d) => h("button", {
        class: `btn${d === "dismiss" ? " primary" : d === "suspend_coach" || d === "end_coaching" ? " quiet-danger" : ""}`, type: "button",
        onclick: (ev) => decideReport(ev.currentTarget, r, id, d),
      }, L.REPORT_DECISION_LABELS[d]))));
  }

  async function decideReport(btn, r, id, decision) {
    if (decision === "suspend_coach" || decision === "end_coaching") {
      const suspend = decision === "suspend_coach";
      const pick = await askDialog({
        title: suspend ? "Suspend this coach?" : "End this coaching?",
        body: suspend ? "She loses coach access at once." : "The coaching ends now and the client is told.",
        actions: [{ id: "no", label: "Cancel", safe: true }, { id: "yes", label: suspend ? "Suspend" : "End coaching", kind: "danger" }],
      });
      if (pick !== "yes") return;
    }
    await busy(btn, async () => {
      await call("decide_coaching_report", { reportId: id, decision, note: (rp.notes[id] ?? "").trim() });
      notice(`${L.REPORT_DECISION_LABELS[decision]}: done.`, true);
      rp.items = rp.items.filter((x) => x !== r);
      renderReports();
      loadReports({ quiet: true });
    });
  }

  /* ============== Settings: receiving accounts and seller details (admin) ============== */

  const st = { loaded: false, version: null, form: null, seller: Object.fromEntries(L.SELLER_FIELDS.map(([k]) => [k, ""])) };

  async function loadCoachingSettings() {
    const root = $("coaching-settings");
    if (!L.PAYMENTS_LIVE) { root.hidden = true; return; }
    root.hidden = false;
    try {
      const d = await call("get_receiving_accounts", {});
      st.version = d.version ?? null;
      if (d.seller) st.seller = L.sellerToForm(d.seller);
      const one = (a) => ({ address: a?.address ?? "", again: "", holderName: a?.holderName ?? "", enabled: !!a?.enabled });
      st.form = { instapay: one(d.instapay), vodafoneCash: one(d.vodafoneCash) };
      st.loaded = true;
    } catch (e) {
      if (!st.form) st.form = { instapay: { address: "", again: "", holderName: "", enabled: false }, vodafoneCash: { address: "", again: "", holderName: "", enabled: false } };
      fail(e);
    }
    renderCoachingSettings();
  }

  function renderCoachingSettings() {
    const root = $("coaching-settings");
    const problemsA = h("div", { class: "problems", id: "acct-problems", role: "alert", hidden: true });
    const problemsS = h("div", { class: "problems", id: "seller-problems", role: "alert", hidden: true });
    const railBlock = (rail) => {
      const f = st.form[rail];
      const base = `acct-${rail}`;
      const addr = h("input", { type: "text", id: `${base}-address`, autocomplete: "off", spellcheck: "false", oninput: (ev) => { f.address = ev.target.value; } });
      addr.value = f.address;
      const again = h("input", { type: "text", id: `${base}-again`, autocomplete: "off", spellcheck: "false", oninput: (ev) => { f.again = ev.target.value; matchHint.textContent = f.again ? (L.retypeMatch(f.address, f.again) ? "Matches." : "Does not match yet.") : ""; } });
      again.value = f.again;
      const matchHint = h("p", { class: "hint", "aria-live": "polite" });
      const holder = h("input", { type: "text", id: `${base}-holder`, autocomplete: "off", maxlength: "80", oninput: (ev) => { f.holderName = ev.target.value; } });
      holder.value = f.holderName;
      return h("fieldset", { class: "group" },
        h("legend", { text: L.railLabel(rail) }),
        h("label", { class: "switch", for: `${base}-on` }, h("input", { type: "checkbox", role: "switch", id: `${base}-on`, checked: f.enabled, onchange: (ev) => { f.enabled = ev.target.checked; } }), h("span", { class: "track" }), h("span", { text: "Members can pay here" })),
        h("label", { for: `${base}-address`, text: rail === "instapay" ? "InstaPay address" : "Vodafone Cash number" }), addr,
        h("label", { for: `${base}-again`, text: "Type it again" }), again, matchHint,
        h("label", { for: `${base}-holder`, text: "Holder name" }), holder);
    };
    const sellerFields = L.SELLER_FIELDS.map(([key, label]) => {
      const input = h("input", { type: key === "supportEmail" ? "email" : "text", id: `seller-${key}`, autocomplete: "off", inputmode: key === "vatRatePercent" ? "decimal" : null, oninput: (ev) => { st.seller[key] = ev.target.value; } });
      input.value = st.seller[key];
      if (key.endsWith("Ar")) input.setAttribute("dir", "rtl");
      return h("div", { class: "field" }, h("label", { for: `seller-${key}`, text: label }), input);
    });
    root.replaceChildren(
      h("div", { class: "card" },
        h("h2", { text: "Receiving accounts" }),
        h("p", { class: "muted", text: "Where members send their payment. Type each account twice before saving." }),
        h("p", { class: "muted", text: st.version != null ? `Saved version ${st.version}` : "Nothing saved yet." }),
        railBlock("instapay"), railBlock("vodafoneCash"), problemsA,
        h("button", { class: "btn primary", id: "acct-save", type: "button", onclick: (ev) => saveAccounts(ev.currentTarget, problemsA) }, "Save accounts")),
      h("div", { class: "card" },
        h("h2", { text: "Seller details" }),
        h("p", { class: "muted", text: "Shown on every checkout and receipt. Saving replaces the details below." }),
        ...sellerFields, problemsS,
        h("button", { class: "btn primary", id: "seller-save", type: "button", onclick: (ev) => saveSeller(ev.currentTarget, problemsS) }, "Save seller details")));
  }

  function showProblems(box, problems) {
    box.replaceChildren(...(problems.length ? [h("strong", { text: problems.length === 1 ? "One thing to fix before saving:" : `${problems.length} things to fix before saving:` }), h("ul", {}, problems.map((p) => h("li", { text: p })))] : []));
    box.hidden = problems.length === 0;
  }

  async function saveAccounts(btn, box) {
    const problems = L.receivingProblems(st.form);
    showProblems(box, problems);
    if (problems.length) return;
    await busy(btn, async () => {
      const res = await call("set_receiving_accounts", L.receivingPayload(st.form));
      st.version = res.version ?? st.version;
      for (const r of ["instapay", "vodafoneCash"]) st.form[r].again = "";
      notice(`Accounts saved${res.version != null ? ` (version ${res.version})` : ""}.`, true);
      renderCoachingSettings();
    });
  }

  async function saveSeller(btn, box) {
    const problems = L.sellerProblems(st.seller);
    showProblems(box, problems);
    if (problems.length) return;
    await busy(btn, async () => {
      await call("set_seller_details", L.sellerPayload(st.seller));
      notice("Seller details saved.", true);
    });
  }

  /* ============== wiring for the dashboard ============== */

  const loaders = { coaches: loadCoaches, payments: loadPayments, refunds: loadRefunds, payouts: loadPayouts, reports: loadReports };
  return {
    load: (tab, opts) => loaders[tab]?.(opts),
    loadSettings: loadCoachingSettings,
    // Called when she leaves a coaching tab: pictures are dropped from memory.
    release: () => dataUrls.clear(),
  };
}
