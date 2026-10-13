# Karvaan local-only bilingual update

Requested 2026-10-13; base main a0bd553b6de18352f587cb1cc6fc662443f9178b.
Branch update/karvaan-bilingual is isolated from main and all shipping systems.

Product name becomes Karvaan / کارواں. Company and user-entered identities do not change.
English and Urdu appear together; overall layout remains LTR, with RTL confined to Urdu runs. Latin digits remain in amounts, identifiers and dates. No language toggle, translation service or new input workflow.

The attachment references a supplied draft but includes no bilingual wording. No existing bilingual-glossary.md was found. Provisional translations need office review, especially consignment, custody, cost bearer, settlement and brokerage. Independent implementation proceeds without treating provisional vocabulary as approved.

Later same-day clarification: user supplied C:/Users/Naeem/Downloads/bilingual-implementation-draft.md (preserved under docs/) and five provisional choices: کنسائنمنٹ, تحویل / رقم زیرِ تحویل, اخراجات کا ذمہ دار (compact ذمہ دار), تصفیہ, کمیشن. No separate draft glossary was present. Apply these choices; office review remains pending. Initial missing-draft statement above records chronology only.

Before candidate execution: dedicated local Supabase identity, port bind preflight, ignored test-only defines and separate protected session namespace. Launcher and runtime must reject hosted endpoints even with APP_ENV=test, and verify the intended backend identity. Never load production defines, installed client.json or existing sessions. Preserve old local containers/data.

Preserve installer AppId/install directory, Android application ID, ordinary production config/session compatibility, company identity, permanent numbers, historical fares/owners and issued snapshots. New bilingual output uses a new snapshotted template version; legacy renderer/fonts remain unchanged. Rendering does not grant recipient access or change money calculations.

No push, main merge, candidate installation, hosted Supabase contact/change, Cloudflare deployment, domain/repository/integration rename or production scheduling. Earlier shipping permissions do not apply. Official font/package downloads are permitted. Only synthetic local fixtures may be used.

U00 planning; U01 isolation; U02 branding; U03 catalogue/fonts/widgets; U04 complete UI extraction; U05 PDF/XLSX and immutable template; U06 regression/build/visual verification; U07 review handoff. See tasks.md for actual status. T19 IN PROGRESS and T20 TODO remain unchanged.

Evidence will record failures and actual results separately; absent devices/printers are pending, not inferred passes. Candidate paths/hashes and a future explicitly authorized installation/deployment/rollback checklist will accompany the handoff.
