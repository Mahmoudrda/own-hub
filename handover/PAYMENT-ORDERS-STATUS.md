# Payment work orders: status (27 Oct 2026)

Spec (source of truth): `docs/plan/INSTAPAY-PAYMENTS-SPEC.md` (copy in `reference/`). Work orders WO-10a to WO-10q are being written; they were not finished when the session paused.

Two writer agents were started in the Claude session. If their files appear in `work-orders/` (WO-10*.md, INDEX-10-server.md, INDEX-10-app.md) they finished or partly finished; check each file ends with its "If stuck" section. To resume in Claude: ask it to "continue the payment work orders"; it should resume the two agents or restart them with the briefs below.

Server agent writes: WO-10a data model and rules; 10b state machine callables; 10m unique piaster amount, reference code, risk score and green/amber/red; 10l-server OCR and deterministic checks; 10n coach non-receipt evidence and auto-reject; 10o strikes, suspensions, dispute rate, two-staff approval; 10c scheduled functions (expiry, 48h and 72h escalation, fee statements); 10d-server coach address with OTP and 24h delay; 10p kill switch `config/payments.enabled` and release gating tests.
App and compliance agent writes: WO-10d-app coach setup; 10e client screens PAY1 to PAY3 and PAY6 with on-device OCR autofill; 10f coach inbox and decision sheet; 10g refunds and service dispute; 10h statement and record download; 10i admin-web dispute queue; 10j notifications, privacy text, store answers, terms drafts for counsel; 10k test program and manual two-phone script; 10q Apple and Google payment policy review and review-notes paragraph.

Order for Gemini once written: 10a, 10b, 10m, 10l, 10d, 10e, 10f, 10n, 10c, 10g, 10h, 10o, 10i, 10j, 10p, 10k (10q is read by the owner before submission). Do not build payments from the spec alone.
