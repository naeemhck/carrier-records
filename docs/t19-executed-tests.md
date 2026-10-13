# T19 executed test ledger â€” 2026-10-12

Each row is one executed assertion/test or one audited payload file. Repeated case labels are retained with unique sequence IDs. Synthetic loopback tests and mocked helper tests do not pass installed hosted field gates. No passwords, tokens, private party names, trip identifiers or balances are included.

## Run contexts

| Run | Execution/result | Scope |
|---|---|---|
| API | `python tools/tests/t03_api.py`: exit 0 | Guarded empty loopback; real restricted roles/HTTP/RLS; synthetic fixtures cleaned |
| FAULT-1 | Exit 1 at account-input assertion, before fault phase | Isolated fixture cleanup PASS; original response status not captured; cause unestablished |
| FAULT | `python tools/tests/t03_api.py --resilience`: exit 0 | Guarded empty loopback; actual before/after-commit connection drops, concurrent retries and revocations; fixtures cleaned |
| UNIT-1 | Six tests: five PASS, one ERROR | Mocked helper; configuration fixture blocked by sandbox temp-directory permissions |
| UNIT-2 | Same six tests: exit 0/all PASS | Mocked helper rerun with permitted temp-directory access; validation unchanged |
| HOST | 13 checks: exit 0/all PASS | Fresh public/anonymous pilot HTTP plus read-only hosted metadata; no financial writes |
| PACKAGE | 60 file inspections: exit 0 | Installed and staged 0.1.0+4 exact bytes/hashes/no privileged material |
| PILOT-API | Prior user-executed reports: exit 0 each | Actual existing pilot staff Auth/scoped reads/admin/global-balance denials/local-session logout |

## Individual executed cases

| ID | Case | Result |
|---|---|---|
| FAULT1-001 | trusted Auth identity creation | PASS |
| FAULT1-002 | service-only first administrator bootstrap | PASS |
| FAULT1-003 | temporary administrator sign-in | PASS |
| FAULT1-004 | temporary password cannot list accounts | PASS |
| FAULT1-005 | temporary password cannot read offices | PASS |
| FAULT1-006 | live session profile | PASS |
| FAULT1-007 | synthetic identities and business fixtures removed | PASS |
| FAULT1-FAILED | invalid current credential rejected | FAIL â€” actual HTTP status not captured in this attempt; fault cases not reached |
| API-001 | trusted Auth identity creation | PASS |
| API-002 | service-only first administrator bootstrap | PASS |
| API-003 | temporary administrator sign-in | PASS |
| API-004 | temporary password cannot list accounts | PASS |
| API-005 | temporary password cannot read offices | PASS |
| API-006 | live session profile | PASS |
| API-007 | invalid current credential rejected | PASS |
| API-008 | invalid current credential rejected | PASS |
| API-009 | invalid current credential rejected | PASS |
| API-010 | invalid current credential rejected | PASS |
| API-011 | incorrect short current credential denied by Auth | PASS |
| API-012 | safe account failure identifies stage without credentials | PASS |
| API-013 | new password policy preserved | PASS |
| API-014 | new password policy preserved | PASS |
| API-015 | new password policy preserved | PASS |
| API-016 | live session profile | PASS |
| API-017 | live session profile | PASS |
| API-018 | rejected changes preserve password gate and version | PASS |
| API-019 | live session profile | PASS |
| API-020 | verified password change through Edge (HTTP 200) | PASS |
| API-021 | old access token revoked after password change | PASS |
| API-022 | old refresh token revoked after password change | PASS |
| API-023 | changed administrator password login | PASS |
| API-024 | live session profile | PASS |
| API-025 | administrator creates origin | PASS |
| API-026 | assigned active staff sign-in origin | PASS |
| API-027 | live session profile | PASS |
| API-028 | verified password change through Edge (HTTP 200) | PASS |
| API-029 | staff changed-password login origin | PASS |
| API-030 | administrator creates destination | PASS |
| API-031 | assigned active staff sign-in destination | PASS |
| API-032 | live session profile | PASS |
| API-033 | verified password change through Edge (HTTP 200) | PASS |
| API-034 | staff changed-password login destination | PASS |
| API-035 | administrator creates outside | PASS |
| API-036 | assigned active staff sign-in outside | PASS |
| API-037 | live session profile | PASS |
| API-038 | verified password change through Edge (HTTP 200) | PASS |
| API-039 | staff changed-password login outside | PASS |
| API-040 | administrator creates unassigned | PASS |
| API-041 | unassigned account cannot sign in | PASS |
| API-042 | AT-12 RLS filters assigned trips | PASS |
| API-043 | AT-12 RLS filters assigned trips | PASS |
| API-044 | AT-12 RLS filters assigned trips | PASS |
| API-045 | AT-12 origin EDIT_FARE | PASS |
| API-046 | AT-12 origin DISPATCH | PASS |
| API-047 | AT-12 origin POST_MONEY | PASS |
| API-048 | AT-12 origin EXPENSE | PASS |
| API-049 | AT-12 origin cannot arrive | PASS |
| API-050 | AT-12 destination can arrive | PASS |
| API-051 | AT-12 destination cannot EDIT_FARE | PASS |
| API-052 | AT-12 destination cannot DISPATCH | PASS |
| API-053 | AT-12 unrelated office denied | PASS |
| API-054 | AT-12 unknown operation denied | PASS |
| API-055 | AT-12 direct trip mutation denied | PASS |
| API-056 | AT-13 direct financial_events POST denied | PASS |
| API-057 | AT-13 direct financial_events PATCH denied | PASS |
| API-058 | AT-13 direct financial_events DELETE denied | PASS |
| API-059 | AT-13 direct journal_lines POST denied | PASS |
| API-060 | AT-13 direct journal_lines PATCH denied | PASS |
| API-061 | AT-13 direct journal_lines DELETE denied | PASS |
| API-062 | AT-13 direct allocations POST denied | PASS |
| API-063 | AT-13 direct allocations PATCH denied | PASS |
| API-064 | AT-13 direct allocations DELETE denied | PASS |
| API-065 | AT-13 direct idempotency_records POST denied | PASS |
| API-066 | AT-13 direct idempotency_records PATCH denied | PASS |
| API-067 | AT-13 direct idempotency_records DELETE denied | PASS |
| API-068 | AT-12 direct trip mutation denied | PASS |
| API-069 | AT-13 direct financial_events POST denied | PASS |
| API-070 | AT-13 direct financial_events PATCH denied | PASS |
| API-071 | AT-13 direct financial_events DELETE denied | PASS |
| API-072 | AT-13 direct journal_lines POST denied | PASS |
| API-073 | AT-13 direct journal_lines PATCH denied | PASS |
| API-074 | AT-13 direct journal_lines DELETE denied | PASS |
| API-075 | AT-13 direct allocations POST denied | PASS |
| API-076 | AT-13 direct allocations PATCH denied | PASS |
| API-077 | AT-13 direct allocations DELETE denied | PASS |
| API-078 | AT-13 direct idempotency_records POST denied | PASS |
| API-079 | AT-13 direct idempotency_records PATCH denied | PASS |
| API-080 | AT-13 direct idempotency_records DELETE denied | PASS |
| API-081 | AT-12 direct trip mutation denied | PASS |
| API-082 | AT-13 direct financial_events POST denied | PASS |
| API-083 | AT-13 direct financial_events PATCH denied | PASS |
| API-084 | AT-13 direct financial_events DELETE denied | PASS |
| API-085 | AT-13 direct journal_lines POST denied | PASS |
| API-086 | AT-13 direct journal_lines PATCH denied | PASS |
| API-087 | AT-13 direct journal_lines DELETE denied | PASS |
| API-088 | AT-13 direct allocations POST denied | PASS |
| API-089 | AT-13 direct allocations PATCH denied | PASS |
| API-090 | AT-13 direct allocations DELETE denied | PASS |
| API-091 | AT-13 direct idempotency_records POST denied | PASS |
| API-092 | AT-13 direct idempotency_records PATCH denied | PASS |
| API-093 | AT-13 direct idempotency_records DELETE denied | PASS |
| API-094 | AT-12 direct trip mutation denied | PASS |
| API-095 | AT-13 direct financial_events POST denied | PASS |
| API-096 | AT-13 direct financial_events PATCH denied | PASS |
| API-097 | AT-13 direct financial_events DELETE denied | PASS |
| API-098 | AT-13 direct journal_lines POST denied | PASS |
| API-099 | AT-13 direct journal_lines PATCH denied | PASS |
| API-100 | AT-13 direct journal_lines DELETE denied | PASS |
| API-101 | AT-13 direct allocations POST denied | PASS |
| API-102 | AT-13 direct allocations PATCH denied | PASS |
| API-103 | AT-13 direct allocations DELETE denied | PASS |
| API-104 | AT-13 direct idempotency_records POST denied | PASS |
| API-105 | AT-13 direct idempotency_records PATCH denied | PASS |
| API-106 | AT-13 direct idempotency_records DELETE denied | PASS |
| API-107 | AT-13 staff cannot create administrator | PASS |
| API-108 | AT-13 privileged service RPC denied | PASS |
| API-109 | AT-13 public signup disabled | PASS |
| API-110 | AT-13 direct role/status/password-flag update denied | PASS |
| API-111 | AT-13 direct office assignment denied | PASS |
| API-112 | AT-13 staff cannot invoke administrator account update | PASS |
| API-113 | AT-13 forged JWT fails direct backend verification | PASS |
| API-114 | administrator self-disable denied | PASS |
| API-115 | administrator self-demotion denied | PASS |
| API-116 | AT-13 metadata cannot grant admin | PASS |
| API-117 | AT-14 null report scope denied | PASS |
| API-118 | AT-14 staff complete global balance denied | PASS |
| API-119 | AT-14 staff exact scoped totals and explicit label | PASS |
| API-120 | AT-14 administrator complete exact totals | PASS |
| API-121 | AT-14 direct event metadata closed | PASS |
| API-122 | trusted synthetic receipt upload | PASS |
| API-123 | AT-13 private receipt scope | PASS |
| API-124 | AT-13 private receipt scope | PASS |
| API-125 | AT-13 private receipt scope | PASS |
| API-126 | AT-13 private receipt scope | PASS |
| API-127 | AT-13 persistent signed-URL bypass blocked | PASS |
| API-128 | live session profile | PASS |
| API-129 | null account version rejected | PASS |
| API-130 | administrator disables account | PASS |
| API-131 | AT-13 disabled old JWT denied | PASS |
| API-132 | AT-13 disabled receipt denied | PASS |
| API-133 | disabled password sign-in denied | PASS |
| API-134 | disabled refresh denied | PASS |
| API-135 | stale account version rejected | PASS |
| API-136 | administrator enables account | PASS |
| API-137 | enabled account fresh sign-in | PASS |
| API-138 | live session profile | PASS |
| API-139 | administrator resets password | PASS |
| API-140 | reset invalidates old access JWT | PASS |
| API-141 | old password fails after reset | PASS |
| API-142 | reset temporary password sign-in | PASS |
| API-143 | live session profile | PASS |
| API-144 | reset forces password change | PASS |
| API-145 | temporary reset token business data denied | PASS |
| API-146 | live session profile | PASS |
| API-147 | wrong current password denied | PASS |
| API-148 | live session profile | PASS |
| API-149 | verified password change through Edge (HTTP 200) | PASS |
| API-150 | live session profile | PASS |
| API-151 | administrator removes assignments | PASS |
| API-152 | lost assignment old JWT denied | PASS |
| API-153 | lost assignment new login denied | PASS |
| API-154 | administrator account list excludes Auth identities and credentials | PASS |
| API-155 | audit contains no passwords or tokens | PASS |
| API-156 | unknown/forged actor fields rejected | PASS |
| API-157 | live session profile | PASS |
| API-158 | password preparation locks target before external update | PASS |
| API-159 | pending password account cannot sign in | PASS |
| API-160 | ordinary administrator cannot call trusted password recovery | PASS |
| API-161 | trusted recovery resets Auth password | PASS |
| API-162 | trusted recovery unlocks with forced password change | PASS |
| API-163 | live session profile | PASS |
| API-164 | recovered account still requires change | PASS |
| API-165 | live session profile | PASS |
| API-166 | verified password change through Edge (HTTP 200) | PASS |
| API-167 | global logout succeeds | PASS |
| API-168 | logged-out JWT fails live authorization | PASS |
| API-169 | synthetic identities and business fixtures removed | PASS |
| FAULT-001 | trusted Auth identity creation | PASS |
| FAULT-002 | service-only first administrator bootstrap | PASS |
| FAULT-003 | temporary administrator sign-in | PASS |
| FAULT-004 | temporary password cannot list accounts | PASS |
| FAULT-005 | temporary password cannot read offices | PASS |
| FAULT-006 | live session profile | PASS |
| FAULT-007 | invalid current credential rejected (HTTP 400) | PASS |
| FAULT-008 | invalid current credential rejected (HTTP 400) | PASS |
| FAULT-009 | invalid current credential rejected (HTTP 400) | PASS |
| FAULT-010 | invalid current credential rejected (HTTP 400) | PASS |
| FAULT-011 | incorrect short current credential denied by Auth | PASS |
| FAULT-012 | safe account failure identifies stage without credentials | PASS |
| FAULT-013 | new password policy preserved | PASS |
| FAULT-014 | new password policy preserved | PASS |
| FAULT-015 | new password policy preserved | PASS |
| FAULT-016 | live session profile | PASS |
| FAULT-017 | live session profile | PASS |
| FAULT-018 | rejected changes preserve password gate and version | PASS |
| FAULT-019 | live session profile | PASS |
| FAULT-020 | verified password change through Edge (HTTP 200) | PASS |
| FAULT-021 | old access token revoked after password change | PASS |
| FAULT-022 | old refresh token revoked after password change | PASS |
| FAULT-023 | changed administrator password login | PASS |
| FAULT-024 | live session profile | PASS |
| FAULT-025 | administrator creates origin | PASS |
| FAULT-026 | assigned active staff sign-in origin | PASS |
| FAULT-027 | live session profile | PASS |
| FAULT-028 | verified password change through Edge (HTTP 200) | PASS |
| FAULT-029 | staff changed-password login origin | PASS |
| FAULT-030 | administrator creates destination | PASS |
| FAULT-031 | assigned active staff sign-in destination | PASS |
| FAULT-032 | live session profile | PASS |
| FAULT-033 | verified password change through Edge (HTTP 200) | PASS |
| FAULT-034 | staff changed-password login destination | PASS |
| FAULT-035 | administrator creates outside | PASS |
| FAULT-036 | assigned active staff sign-in outside | PASS |
| FAULT-037 | live session profile | PASS |
| FAULT-038 | verified password change through Edge (HTTP 200) | PASS |
| FAULT-039 | staff changed-password login outside | PASS |
| FAULT-040 | administrator creates unassigned | PASS |
| FAULT-041 | unassigned account cannot sign in | PASS |
| FAULT-042 | AT-12 RLS filters assigned trips | PASS |
| FAULT-043 | AT-12 RLS filters assigned trips | PASS |
| FAULT-044 | AT-12 RLS filters assigned trips | PASS |
| FAULT-045 | AT-12 origin EDIT_FARE | PASS |
| FAULT-046 | AT-12 origin DISPATCH | PASS |
| FAULT-047 | AT-12 origin POST_MONEY | PASS |
| FAULT-048 | AT-12 origin EXPENSE | PASS |
| FAULT-049 | AT-12 origin cannot arrive | PASS |
| FAULT-050 | AT-12 destination can arrive | PASS |
| FAULT-051 | AT-12 destination cannot EDIT_FARE | PASS |
| FAULT-052 | AT-12 destination cannot DISPATCH | PASS |
| FAULT-053 | AT-12 unrelated office denied | PASS |
| FAULT-054 | AT-12 unknown operation denied | PASS |
| FAULT-055 | AT-12 direct trip mutation denied | PASS |
| FAULT-056 | AT-13 direct financial_events POST denied | PASS |
| FAULT-057 | AT-13 direct financial_events PATCH denied | PASS |
| FAULT-058 | AT-13 direct financial_events DELETE denied | PASS |
| FAULT-059 | AT-13 direct journal_lines POST denied | PASS |
| FAULT-060 | AT-13 direct journal_lines PATCH denied | PASS |
| FAULT-061 | AT-13 direct journal_lines DELETE denied | PASS |
| FAULT-062 | AT-13 direct allocations POST denied | PASS |
| FAULT-063 | AT-13 direct allocations PATCH denied | PASS |
| FAULT-064 | AT-13 direct allocations DELETE denied | PASS |
| FAULT-065 | AT-13 direct idempotency_records POST denied | PASS |
| FAULT-066 | AT-13 direct idempotency_records PATCH denied | PASS |
| FAULT-067 | AT-13 direct idempotency_records DELETE denied | PASS |
| FAULT-068 | AT-12 direct trip mutation denied | PASS |
| FAULT-069 | AT-13 direct financial_events POST denied | PASS |
| FAULT-070 | AT-13 direct financial_events PATCH denied | PASS |
| FAULT-071 | AT-13 direct financial_events DELETE denied | PASS |
| FAULT-072 | AT-13 direct journal_lines POST denied | PASS |
| FAULT-073 | AT-13 direct journal_lines PATCH denied | PASS |
| FAULT-074 | AT-13 direct journal_lines DELETE denied | PASS |
| FAULT-075 | AT-13 direct allocations POST denied | PASS |
| FAULT-076 | AT-13 direct allocations PATCH denied | PASS |
| FAULT-077 | AT-13 direct allocations DELETE denied | PASS |
| FAULT-078 | AT-13 direct idempotency_records POST denied | PASS |
| FAULT-079 | AT-13 direct idempotency_records PATCH denied | PASS |
| FAULT-080 | AT-13 direct idempotency_records DELETE denied | PASS |
| FAULT-081 | AT-12 direct trip mutation denied | PASS |
| FAULT-082 | AT-13 direct financial_events POST denied | PASS |
| FAULT-083 | AT-13 direct financial_events PATCH denied | PASS |
| FAULT-084 | AT-13 direct financial_events DELETE denied | PASS |
| FAULT-085 | AT-13 direct journal_lines POST denied | PASS |
| FAULT-086 | AT-13 direct journal_lines PATCH denied | PASS |
| FAULT-087 | AT-13 direct journal_lines DELETE denied | PASS |
| FAULT-088 | AT-13 direct allocations POST denied | PASS |
| FAULT-089 | AT-13 direct allocations PATCH denied | PASS |
| FAULT-090 | AT-13 direct allocations DELETE denied | PASS |
| FAULT-091 | AT-13 direct idempotency_records POST denied | PASS |
| FAULT-092 | AT-13 direct idempotency_records PATCH denied | PASS |
| FAULT-093 | AT-13 direct idempotency_records DELETE denied | PASS |
| FAULT-094 | AT-12 direct trip mutation denied | PASS |
| FAULT-095 | AT-13 direct financial_events POST denied | PASS |
| FAULT-096 | AT-13 direct financial_events PATCH denied | PASS |
| FAULT-097 | AT-13 direct financial_events DELETE denied | PASS |
| FAULT-098 | AT-13 direct journal_lines POST denied | PASS |
| FAULT-099 | AT-13 direct journal_lines PATCH denied | PASS |
| FAULT-100 | AT-13 direct journal_lines DELETE denied | PASS |
| FAULT-101 | AT-13 direct allocations POST denied | PASS |
| FAULT-102 | AT-13 direct allocations PATCH denied | PASS |
| FAULT-103 | AT-13 direct allocations DELETE denied | PASS |
| FAULT-104 | AT-13 direct idempotency_records POST denied | PASS |
| FAULT-105 | AT-13 direct idempotency_records PATCH denied | PASS |
| FAULT-106 | AT-13 direct idempotency_records DELETE denied | PASS |
| FAULT-107 | AT-13 staff cannot create administrator | PASS |
| FAULT-108 | AT-13 privileged service RPC denied | PASS |
| FAULT-109 | AT-13 public signup disabled | PASS |
| FAULT-110 | AT-13 direct role/status/password-flag update denied | PASS |
| FAULT-111 | AT-13 direct office assignment denied | PASS |
| FAULT-112 | AT-13 staff cannot invoke administrator account update | PASS |
| FAULT-113 | AT-13 forged JWT fails direct backend verification | PASS |
| FAULT-114 | administrator self-disable denied | PASS |
| FAULT-115 | administrator self-demotion denied | PASS |
| FAULT-116 | AT-13 metadata cannot grant admin | PASS |
| FAULT-117 | AT-14 null report scope denied | PASS |
| FAULT-118 | AT-14 staff complete global balance denied | PASS |
| FAULT-119 | AT-14 staff exact scoped totals and explicit label | PASS |
| FAULT-120 | AT-14 administrator complete exact totals | PASS |
| FAULT-121 | AT-14 direct event metadata closed | PASS |
| FAULT-122 | trusted synthetic receipt upload | PASS |
| FAULT-123 | AT-13 private receipt scope | PASS |
| FAULT-124 | AT-13 private receipt scope | PASS |
| FAULT-125 | AT-13 private receipt scope | PASS |
| FAULT-126 | AT-13 private receipt scope | PASS |
| FAULT-127 | AT-13 persistent signed-URL bypass blocked | PASS |
| FAULT-128 | live session profile | PASS |
| FAULT-129 | null account version rejected | PASS |
| FAULT-130 | administrator disables account | PASS |
| FAULT-131 | AT-13 disabled old JWT denied | PASS |
| FAULT-132 | AT-13 disabled receipt denied | PASS |
| FAULT-133 | disabled password sign-in denied | PASS |
| FAULT-134 | disabled refresh denied | PASS |
| FAULT-135 | stale account version rejected | PASS |
| FAULT-136 | administrator enables account | PASS |
| FAULT-137 | enabled account fresh sign-in | PASS |
| FAULT-138 | live session profile | PASS |
| FAULT-139 | administrator resets password | PASS |
| FAULT-140 | reset invalidates old access JWT | PASS |
| FAULT-141 | old password fails after reset | PASS |
| FAULT-142 | reset temporary password sign-in | PASS |
| FAULT-143 | live session profile | PASS |
| FAULT-144 | reset forces password change | PASS |
| FAULT-145 | temporary reset token business data denied | PASS |
| FAULT-146 | live session profile | PASS |
| FAULT-147 | wrong current password denied | PASS |
| FAULT-148 | live session profile | PASS |
| FAULT-149 | verified password change through Edge (HTTP 200) | PASS |
| FAULT-150 | live session profile | PASS |
| FAULT-151 | administrator removes assignments | PASS |
| FAULT-152 | lost assignment old JWT denied | PASS |
| FAULT-153 | lost assignment new login denied | PASS |
| FAULT-154 | administrator account list excludes Auth identities and credentials | PASS |
| FAULT-155 | audit contains no passwords or tokens | PASS |
| FAULT-156 | unknown/forged actor fields rejected | PASS |
| FAULT-157 | live session profile | PASS |
| FAULT-158 | password preparation locks target before external update | PASS |
| FAULT-159 | pending password account cannot sign in | PASS |
| FAULT-160 | ordinary administrator cannot call trusted password recovery | PASS |
| FAULT-161 | trusted recovery resets Auth password | PASS |
| FAULT-162 | trusted recovery unlocks with forced password change | PASS |
| FAULT-163 | live session profile | PASS |
| FAULT-164 | recovered account still requires change | PASS |
| FAULT-165 | live session profile | PASS |
| FAULT-166 | verified password change through Edge (HTTP 200) | PASS |
| FAULT-167 | AT33 managed restricted fault-test staff | PASS |
| FAULT-168 | AT33 temporary login | PASS |
| FAULT-169 | live session profile | PASS |
| FAULT-170 | verified password change through Edge (HTTP 200) | PASS |
| FAULT-171 | AT33 fresh restricted login | PASS |
| FAULT-172 | AT33 synthetic PARTY | PASS |
| FAULT-173 | AT33 synthetic PARTY | PASS |
| FAULT-174 | AT33 synthetic PARTY | PASS |
| FAULT-175 | AT33 synthetic VEHICLE | PASS |
| FAULT-176 | AT33 overlap review | PASS |
| FAULT-177 | AT33 operational draft | PASS |
| FAULT-178 | AT33 dropped connection has no success acknowledgement | PASS |
| FAULT-179 | AT33 before fault has exact commit state | PASS |
| FAULT-180 | AT33 same-request retry succeeds | PASS |
| FAULT-181 | AT33 duplicate retry returns same result exactly once | PASS |
| FAULT-182 | AT33 altered retry rejected | PASS |
| FAULT-183 | AT33 dropped connection has no success acknowledgement | PASS |
| FAULT-184 | AT33 after fault has exact commit state | PASS |
| FAULT-185 | AT33 lost response followed real backend commit | PASS |
| FAULT-186 | AT33 same-request retry succeeds | PASS |
| FAULT-187 | AT33 duplicate retry returns same result exactly once | PASS |
| FAULT-188 | AT33 altered retry rejected | PASS |
| FAULT-189 | AT33 five concurrent identical retries commit once | PASS |
| FAULT-190 | AT33 malformed JWT cannot post through direct proxy | PASS |
| FAULT-191 | AT33 actual expired session cannot acknowledge or post | PASS |
| FAULT-192 | AT33 fresh authentication after session expiry | PASS |
| FAULT-193 | live session profile | PASS |
| FAULT-194 | AT33 revoke live staff assignment | PASS |
| FAULT-195 | AT33 obsolete office token cannot post | PASS |
| FAULT-196 | AT33 financial histories remain balanced | PASS |
| FAULT-197 | global logout succeeds | PASS |
| FAULT-198 | logged-out JWT fails live authorization | PASS |
| FAULT-199 | synthetic identities and business fixtures removed | PASS |
| UNIT1-01 | both_role_matrices_and_local_session_cleanup | PASS |
| UNIT2-01 | both_role_matrices_and_local_session_cleanup | PASS |
| UNIT1-02 | malformed_request_denial_is_not_authorization_evidence | PASS |
| UNIT2-02 | malformed_request_denial_is_not_authorization_evidence | PASS |
| UNIT1-03 | missing_trip_is_not_a_trip_permission_pass | PASS |
| UNIT2-03 | missing_trip_is_not_a_trip_permission_pass | PASS |
| UNIT1-04 | preflight_does_not_claim_trip_operations | PASS |
| UNIT2-04 | preflight_does_not_claim_trip_operations | PASS |
| UNIT1-05 | public_configuration_and_secret_rejection | ERROR â€” sandbox temp write denied |
| UNIT2-05 | public_configuration_and_secret_rejection | PASS |
| UNIT1-06 | wrong_office_stops_before_other_operations | PASS |
| UNIT2-06 | wrong_office_stops_before_other_operations | PASS |
| HOST-01 | Hosted public signup disabled (HTTP 200) | PASS |
| HOST-02 | Hosted anonymous sign-in disabled (HTTP 200) | PASS |
| HOST-03 | Anonymous staff-accounts request denied (HTTP 401) | PASS |
| HOST-04 | Anonymous expense-receipts request denied (HTTP 401) | PASS |
| HOST-05 | Anonymous get_session_profile denied (HTTP 401) | PASS |
| HOST-06 | Anonymous list_staff_accounts denied (HTTP 401) | PASS |
| HOST-07 | All exposed public tables have RLS | PASS |
| HOST-08 | All 24 ordinary direct financial write grants absent | PASS |
| HOST-09 | Command roles NOLOGIN and NOBYPASSRLS | PASS |
| HOST-10 | Auth admin may execute token hook | PASS |
| HOST-11 | Ordinary roles cannot execute token hook | PASS |
| HOST-12 | Receipt bucket private with exact size/MIME restrictions | PASS |
| HOST-13 | Hosted migration count remains nineteen | PASS |
| STAGED-01 | accounts-setup.md â€” byte/hash/credential exclusion | PASS |
| STAGED-02 | app_links_plugin.dll â€” byte/hash/credential exclusion | PASS |
| STAGED-03 | carrier_records.exe â€” byte/hash/credential exclusion | PASS |
| STAGED-04 | file_selector_windows_plugin.dll â€” byte/hash/credential exclusion | PASS |
| STAGED-05 | flutter_secure_storage_windows_plugin.dll â€” byte/hash/credential exclusion | PASS |
| STAGED-06 | flutter_windows.dll â€” byte/hash/credential exclusion | PASS |
| STAGED-07 | INSTALLATION.md â€” byte/hash/credential exclusion | PASS |
| STAGED-08 | masters-setup.md â€” byte/hash/credential exclusion | PASS |
| STAGED-09 | native_assets.json â€” byte/hash/credential exclusion | PASS |
| STAGED-10 | pdfium.dll â€” byte/hash/credential exclusion | PASS |
| STAGED-11 | printing_plugin.dll â€” byte/hash/credential exclusion | PASS |
| STAGED-12 | restoration-evidence.md â€” byte/hash/credential exclusion | PASS |
| STAGED-13 | restoration-setup.md â€” byte/hash/credential exclusion | PASS |
| STAGED-14 | share_plus_plugin.dll â€” byte/hash/credential exclusion | PASS |
| STAGED-15 | url_launcher_windows_plugin.dll â€” byte/hash/credential exclusion | PASS |
| STAGED-16 | windows-backend-prerequisites.md â€” byte/hash/credential exclusion | PASS |
| STAGED-17 | windows-pilot-checklist.md â€” byte/hash/credential exclusion | PASS |
| STAGED-18 | data/app.so â€” byte/hash/credential exclusion | PASS |
| STAGED-19 | data/icudtl.dat â€” byte/hash/credential exclusion | PASS |
| STAGED-20 | data/flutter_assets/AssetManifest.bin â€” byte/hash/credential exclusion | PASS |
| STAGED-21 | data/flutter_assets/FontManifest.json â€” byte/hash/credential exclusion | PASS |
| STAGED-22 | data/flutter_assets/NativeAssetsManifest.json â€” byte/hash/credential exclusion | PASS |
| STAGED-23 | data/flutter_assets/NOTICES.Z â€” byte/hash/credential exclusion | PASS |
| STAGED-24 | data/flutter_assets/assets/fonts/NotoSans-Bold.ttf â€” byte/hash/credential exclusion | PASS |
| STAGED-25 | data/flutter_assets/assets/fonts/NotoSans-Regular.ttf â€” byte/hash/credential exclusion | PASS |
| STAGED-26 | data/flutter_assets/fonts/MaterialIcons-Regular.otf â€” byte/hash/credential exclusion | PASS |
| STAGED-27 | data/flutter_assets/packages/cupertino_icons/assets/CupertinoIcons.ttf â€” byte/hash/credential exclusion | PASS |
| STAGED-28 | data/flutter_assets/packages/material_ui/shaders/ink_sparkle.frag â€” byte/hash/credential exclusion | PASS |
| STAGED-29 | data/flutter_assets/shaders/ink_sparkle.frag â€” byte/hash/credential exclusion | PASS |
| STAGED-30 | data/flutter_assets/shaders/stretch_effect.frag â€” byte/hash/credential exclusion | PASS |
| INSTALLED-01 | accounts-setup.md â€” byte/hash/credential exclusion | PASS |
| INSTALLED-02 | app_links_plugin.dll â€” byte/hash/credential exclusion | PASS |
| INSTALLED-03 | carrier_records.exe â€” byte/hash/credential exclusion | PASS |
| INSTALLED-04 | file_selector_windows_plugin.dll â€” byte/hash/credential exclusion | PASS |
| INSTALLED-05 | flutter_secure_storage_windows_plugin.dll â€” byte/hash/credential exclusion | PASS |
| INSTALLED-06 | flutter_windows.dll â€” byte/hash/credential exclusion | PASS |
| INSTALLED-07 | INSTALLATION.md â€” byte/hash/credential exclusion | PASS |
| INSTALLED-08 | masters-setup.md â€” byte/hash/credential exclusion | PASS |
| INSTALLED-09 | native_assets.json â€” byte/hash/credential exclusion | PASS |
| INSTALLED-10 | pdfium.dll â€” byte/hash/credential exclusion | PASS |
| INSTALLED-11 | printing_plugin.dll â€” byte/hash/credential exclusion | PASS |
| INSTALLED-12 | restoration-evidence.md â€” byte/hash/credential exclusion | PASS |
| INSTALLED-13 | restoration-setup.md â€” byte/hash/credential exclusion | PASS |
| INSTALLED-14 | share_plus_plugin.dll â€” byte/hash/credential exclusion | PASS |
| INSTALLED-15 | url_launcher_windows_plugin.dll â€” byte/hash/credential exclusion | PASS |
| INSTALLED-16 | windows-backend-prerequisites.md â€” byte/hash/credential exclusion | PASS |
| INSTALLED-17 | windows-pilot-checklist.md â€” byte/hash/credential exclusion | PASS |
| INSTALLED-18 | data/app.so â€” byte/hash/credential exclusion | PASS |
| INSTALLED-19 | data/icudtl.dat â€” byte/hash/credential exclusion | PASS |
| INSTALLED-20 | data/flutter_assets/AssetManifest.bin â€” byte/hash/credential exclusion | PASS |
| INSTALLED-21 | data/flutter_assets/FontManifest.json â€” byte/hash/credential exclusion | PASS |
| INSTALLED-22 | data/flutter_assets/NativeAssetsManifest.json â€” byte/hash/credential exclusion | PASS |
| INSTALLED-23 | data/flutter_assets/NOTICES.Z â€” byte/hash/credential exclusion | PASS |
| INSTALLED-24 | data/flutter_assets/assets/fonts/NotoSans-Bold.ttf â€” byte/hash/credential exclusion | PASS |
| INSTALLED-25 | data/flutter_assets/assets/fonts/NotoSans-Regular.ttf â€” byte/hash/credential exclusion | PASS |
| INSTALLED-26 | data/flutter_assets/fonts/MaterialIcons-Regular.otf â€” byte/hash/credential exclusion | PASS |
| INSTALLED-27 | data/flutter_assets/packages/cupertino_icons/assets/CupertinoIcons.ttf â€” byte/hash/credential exclusion | PASS |
| INSTALLED-28 | data/flutter_assets/packages/material_ui/shaders/ink_sparkle.frag â€” byte/hash/credential exclusion | PASS |
| INSTALLED-29 | data/flutter_assets/shaders/ink_sparkle.frag â€” byte/hash/credential exclusion | PASS |
| INSTALLED-30 | data/flutter_assets/shaders/stretch_effect.frag â€” byte/hash/credential exclusion | PASS |
| PILOT_KHI-01 | existing staff authentication (HTTP 200) | PASS |
| PILOT_KHI-02 | ready staff with exactly the assigned office (HTTP 200) | PASS |
| PILOT_KHI-03 | staff account administration denied (HTTP 403) | PASS |
| PILOT_KHI-04 | complete business balance denied (HTTP 403) | PASS |
| PILOT_KHI-05 | explicitly scoped balance allowed (HTTP 200) | PASS |
| PILOT_KHI-06 | office-scoped draft list allowed (HTTP 200) | PASS |
| PILOT_KHI-07 | trip operation matrix | NOT_RUN |
| PILOT_KHI-08 | probe session logout (HTTP 204) | PASS |
| PILOT_ISB-01 | existing staff authentication (HTTP 200) | PASS |
| PILOT_ISB-02 | ready staff with exactly the assigned office (HTTP 200) | PASS |
| PILOT_ISB-03 | staff account administration denied (HTTP 403) | PASS |
| PILOT_ISB-04 | complete business balance denied (HTTP 403) | PASS |
| PILOT_ISB-05 | explicitly scoped balance allowed (HTTP 200) | PASS |
| PILOT_ISB-06 | office-scoped draft list allowed (HTTP 200) | PASS |
| PILOT_ISB-07 | trip operation matrix | NOT_RUN |
| PILOT_ISB-08 | probe session logout (HTTP 204) | PASS |

## Post-run cleanup and health

| ID | Check | Actual result |
|---|---|---|
| CLEANUP-01 | Isolated Auth identities removed | PASS — count 0 |
| CLEANUP-02 | Isolated businesses removed | PASS — count 0 |
| CLEANUP-03 | Isolated financial events removed | PASS — count 0 |
| CLEANUP-04 | Isolated trips removed | PASS — count 0 |
| CLEANUP-05 | No disabled user triggers remain | PASS — count 0 |
| HEALTH-01 | Local Auth ready after cleanup | PASS — HTTP200 |
| HOST-INVENTORY-01 | Existing pilot staff still ready/correct single offices | PASS — both active STAFF, password gate cleared, three Auth identities |
| HOST-INVENTORY-02 | Hosted operational prerequisites | OBSERVED — two vehicles, no drivers, one customer, no trips; trip field tests NOT RUN |
| AUDIT-01 | Final source/history credential exclusion | PASS — 256 tracked/two intended new files/460 historical blobs, no findings |
| DOC-01 | Relative links, unique test IDs and task gates | PASS — links resolve, IDs unique, T19 IN PROGRESS/T20 TODO |
| DIFF-01 | Whitespace/diff validation | PASS — git diff --check |

## Limits and evidence retention

## Requested installed/hosted Computer Use retry

User explicitly requests screen tests of the installed hosted app and offers local password entry. Module initialization succeeds, but no password handoff or app interaction is reached.

| ID | Check | Actual result |
|---|---|---|
| SCREEN-01 | Initial native app inventory | BLOCKED — native pipe unavailable, system cannot find specified file, os error 2 |
| SCREEN-02 | Inventory retry after two seconds | BLOCKED — same error |
| SCREEN-03 | Reset JavaScript session/reinitialize/inventory retry | BLOCKED — same error |
| SCREEN-04 | Enabled-surface inventory after user reports another chat works | OBSERVED — native apps empty, only browser surfaces listed in this chat |
| SCREEN-05 | Direct open-window inventory with app reported open | BLOCKED — same native pipe unavailable/os error 2 |

These are failed tooling connection attempts, not failed Carrier Records operations or passed hosted UI tests. Asked whether ChatGPT itself had been fully reopened; answer pending. No Windows restart, credential entry, native input, backend write or additional isolated regression performed for this request.

User subsequently reports Computer Use works in another chat. This narrows the likely fault to this chat's native runtime attachment; exact attachment failure remains unproven. Prepared [working-chat handoff](computer-use-test-handoff.md) to resume the same workspace/field gates without duplicate setup. No need to infer global plugin/PC failure from this chat's missing connection.

Fresh local fixture cleanup/health and hosted inventory are recorded in windows-release-evidence.md. Protected-store contents are never extracted. Raw current run logs and sanitized hosted/probe reports remain ignored under tools/.local; this ledger records every emitted assertion without importing private data. Local fixture tests exercise real API enforcement but do not prove a hosted installed UI save, physical printing, clean-machine installation or office/recovery sign-off. See t19-test-register.md for field gates that remain pending.

## Installed continuation with working native inventory

All twenty-seven CU26 attempts, including each capture failure, physical-Escape stop, keyboard recovery, strict config validation and actual installed administrator observation, are individually recorded with inputs, expected/actual results, account/environment, status, evidence and retest in [installed continuation](t19-installed-continuation.md). No master form/save, trip or financial workflow was reached. T19 IN PROGRESS; T20 TODO.

Latest recovery: user manually opens Company and master records; actual installed accessibility observation confirms the page/configured company. Keyboard focus briefly reaches Back/Offices, later returns to root; latest indexed Parties click rejected as unavailable in cached app state. CU26-20 through CU26-27 recorded separately in docs/t19-installed-continuation.md; no party editor, new record or save. T19 IN PROGRESS; T20 TODO.


## Browser-fix delivery: final synthetic regression and installer assertions
2026-10-12. All BFX-B assertions below are from the guarded empty-loopback combined T03/T05/T06/T07 run (exit0,615 PASS), not hosted UI evidence. Initial startup503 and failed rollback-comparison attempts are retained separately in browser-bugs-evidence.md. BFX-P entries are exact build6 staged/installed payload audits (60 inspections); they do not prove launch/login. User stopped Computer Use; remaining field checks stay pending.
| ID | Executed assertion | Result |
|---|---|---|
| BFX-B-001 | trusted Auth identity creation | PASS |
| BFX-B-002 | service-only first administrator bootstrap | PASS |
| BFX-B-003 | temporary administrator sign-in | PASS |
| BFX-B-004 | temporary password cannot list accounts | PASS |
| BFX-B-005 | temporary password cannot read offices | PASS |
| BFX-B-006 | live session profile | PASS |
| BFX-B-007 | invalid current credential rejected (HTTP 400) | PASS |
| BFX-B-008 | invalid current credential rejected (HTTP 400) | PASS |
| BFX-B-009 | invalid current credential rejected (HTTP 400) | PASS |
| BFX-B-010 | invalid current credential rejected (HTTP 400) | PASS |
| BFX-B-011 | incorrect short current credential denied by Auth | PASS |
| BFX-B-012 | safe account failure identifies stage without credentials | PASS |
| BFX-B-013 | new password policy preserved | PASS |
| BFX-B-014 | new password policy preserved | PASS |
| BFX-B-015 | new password policy preserved | PASS |
| BFX-B-016 | live session profile | PASS |
| BFX-B-017 | live session profile | PASS |
| BFX-B-018 | rejected changes preserve password gate and version | PASS |
| BFX-B-019 | live session profile | PASS |
| BFX-B-020 | verified password change through Edge (HTTP 200) | PASS |
| BFX-B-021 | old access token revoked after password change | PASS |
| BFX-B-022 | old refresh token revoked after password change | PASS |
| BFX-B-023 | changed administrator password login | PASS |
| BFX-B-024 | live session profile | PASS |
| BFX-B-025 | administrator creates origin | PASS |
| BFX-B-026 | assigned active staff sign-in origin | PASS |
| BFX-B-027 | live session profile | PASS |
| BFX-B-028 | verified password change through Edge (HTTP 200) | PASS |
| BFX-B-029 | staff changed-password login origin | PASS |
| BFX-B-030 | administrator creates destination | PASS |
| BFX-B-031 | assigned active staff sign-in destination | PASS |
| BFX-B-032 | live session profile | PASS |
| BFX-B-033 | verified password change through Edge (HTTP 200) | PASS |
| BFX-B-034 | staff changed-password login destination | PASS |
| BFX-B-035 | administrator creates outside | PASS |
| BFX-B-036 | assigned active staff sign-in outside | PASS |
| BFX-B-037 | live session profile | PASS |
| BFX-B-038 | verified password change through Edge (HTTP 200) | PASS |
| BFX-B-039 | staff changed-password login outside | PASS |
| BFX-B-040 | administrator creates unassigned | PASS |
| BFX-B-041 | unassigned account cannot sign in | PASS |
| BFX-B-042 | AT-12 RLS filters assigned trips | PASS |
| BFX-B-043 | AT-12 RLS filters assigned trips | PASS |
| BFX-B-044 | AT-12 RLS filters assigned trips | PASS |
| BFX-B-045 | AT-12 origin EDIT_FARE | PASS |
| BFX-B-046 | AT-12 origin DISPATCH | PASS |
| BFX-B-047 | AT-12 origin POST_MONEY | PASS |
| BFX-B-048 | AT-12 origin EXPENSE | PASS |
| BFX-B-049 | AT-12 origin cannot arrive | PASS |
| BFX-B-050 | AT-12 destination can arrive | PASS |
| BFX-B-051 | AT-12 destination cannot EDIT_FARE | PASS |
| BFX-B-052 | AT-12 destination cannot DISPATCH | PASS |
| BFX-B-053 | AT-12 unrelated office denied | PASS |
| BFX-B-054 | AT-12 unknown operation denied | PASS |
| BFX-B-055 | AT-12 direct trip mutation denied | PASS |
| BFX-B-056 | AT-13 direct financial_events POST denied | PASS |
| BFX-B-057 | AT-13 direct financial_events PATCH denied | PASS |
| BFX-B-058 | AT-13 direct financial_events DELETE denied | PASS |
| BFX-B-059 | AT-13 direct journal_lines POST denied | PASS |
| BFX-B-060 | AT-13 direct journal_lines PATCH denied | PASS |
| BFX-B-061 | AT-13 direct journal_lines DELETE denied | PASS |
| BFX-B-062 | AT-13 direct allocations POST denied | PASS |
| BFX-B-063 | AT-13 direct allocations PATCH denied | PASS |
| BFX-B-064 | AT-13 direct allocations DELETE denied | PASS |
| BFX-B-065 | AT-13 direct idempotency_records POST denied | PASS |
| BFX-B-066 | AT-13 direct idempotency_records PATCH denied | PASS |
| BFX-B-067 | AT-13 direct idempotency_records DELETE denied | PASS |
| BFX-B-068 | AT-12 direct trip mutation denied | PASS |
| BFX-B-069 | AT-13 direct financial_events POST denied | PASS |
| BFX-B-070 | AT-13 direct financial_events PATCH denied | PASS |
| BFX-B-071 | AT-13 direct financial_events DELETE denied | PASS |
| BFX-B-072 | AT-13 direct journal_lines POST denied | PASS |
| BFX-B-073 | AT-13 direct journal_lines PATCH denied | PASS |
| BFX-B-074 | AT-13 direct journal_lines DELETE denied | PASS |
| BFX-B-075 | AT-13 direct allocations POST denied | PASS |
| BFX-B-076 | AT-13 direct allocations PATCH denied | PASS |
| BFX-B-077 | AT-13 direct allocations DELETE denied | PASS |
| BFX-B-078 | AT-13 direct idempotency_records POST denied | PASS |
| BFX-B-079 | AT-13 direct idempotency_records PATCH denied | PASS |
| BFX-B-080 | AT-13 direct idempotency_records DELETE denied | PASS |
| BFX-B-081 | AT-12 direct trip mutation denied | PASS |
| BFX-B-082 | AT-13 direct financial_events POST denied | PASS |
| BFX-B-083 | AT-13 direct financial_events PATCH denied | PASS |
| BFX-B-084 | AT-13 direct financial_events DELETE denied | PASS |
| BFX-B-085 | AT-13 direct journal_lines POST denied | PASS |
| BFX-B-086 | AT-13 direct journal_lines PATCH denied | PASS |
| BFX-B-087 | AT-13 direct journal_lines DELETE denied | PASS |
| BFX-B-088 | AT-13 direct allocations POST denied | PASS |
| BFX-B-089 | AT-13 direct allocations PATCH denied | PASS |
| BFX-B-090 | AT-13 direct allocations DELETE denied | PASS |
| BFX-B-091 | AT-13 direct idempotency_records POST denied | PASS |
| BFX-B-092 | AT-13 direct idempotency_records PATCH denied | PASS |
| BFX-B-093 | AT-13 direct idempotency_records DELETE denied | PASS |
| BFX-B-094 | AT-12 direct trip mutation denied | PASS |
| BFX-B-095 | AT-13 direct financial_events POST denied | PASS |
| BFX-B-096 | AT-13 direct financial_events PATCH denied | PASS |
| BFX-B-097 | AT-13 direct financial_events DELETE denied | PASS |
| BFX-B-098 | AT-13 direct journal_lines POST denied | PASS |
| BFX-B-099 | AT-13 direct journal_lines PATCH denied | PASS |
| BFX-B-100 | AT-13 direct journal_lines DELETE denied | PASS |
| BFX-B-101 | AT-13 direct allocations POST denied | PASS |
| BFX-B-102 | AT-13 direct allocations PATCH denied | PASS |
| BFX-B-103 | AT-13 direct allocations DELETE denied | PASS |
| BFX-B-104 | AT-13 direct idempotency_records POST denied | PASS |
| BFX-B-105 | AT-13 direct idempotency_records PATCH denied | PASS |
| BFX-B-106 | AT-13 direct idempotency_records DELETE denied | PASS |
| BFX-B-107 | AT-13 staff cannot create administrator | PASS |
| BFX-B-108 | AT-13 privileged service RPC denied | PASS |
| BFX-B-109 | AT-13 public signup disabled | PASS |
| BFX-B-110 | AT-13 direct role/status/password-flag update denied | PASS |
| BFX-B-111 | AT-13 direct office assignment denied | PASS |
| BFX-B-112 | AT-13 staff cannot invoke administrator account update | PASS |
| BFX-B-113 | AT-13 forged JWT fails direct backend verification | PASS |
| BFX-B-114 | administrator self-disable denied | PASS |
| BFX-B-115 | administrator self-demotion denied | PASS |
| BFX-B-116 | AT-13 metadata cannot grant admin | PASS |
| BFX-B-117 | AT-14 null report scope denied | PASS |
| BFX-B-118 | AT-14 staff complete global balance denied | PASS |
| BFX-B-119 | AT-14 staff exact scoped totals and explicit label | PASS |
| BFX-B-120 | AT-14 administrator complete exact totals | PASS |
| BFX-B-121 | AT-14 direct event metadata closed | PASS |
| BFX-B-122 | trusted synthetic receipt upload | PASS |
| BFX-B-123 | AT-13 private receipt scope | PASS |
| BFX-B-124 | AT-13 private receipt scope | PASS |
| BFX-B-125 | AT-13 private receipt scope | PASS |
| BFX-B-126 | AT-13 private receipt scope | PASS |
| BFX-B-127 | AT-13 persistent signed-URL bypass blocked | PASS |
| BFX-B-128 | live session profile | PASS |
| BFX-B-129 | null account version rejected | PASS |
| BFX-B-130 | administrator disables account | PASS |
| BFX-B-131 | AT-13 disabled old JWT denied | PASS |
| BFX-B-132 | AT-13 disabled receipt denied | PASS |
| BFX-B-133 | disabled password sign-in denied | PASS |
| BFX-B-134 | disabled refresh denied | PASS |
| BFX-B-135 | stale account version rejected | PASS |
| BFX-B-136 | administrator enables account | PASS |
| BFX-B-137 | enabled account fresh sign-in | PASS |
| BFX-B-138 | live session profile | PASS |
| BFX-B-139 | administrator resets password | PASS |
| BFX-B-140 | reset invalidates old access JWT | PASS |
| BFX-B-141 | old password fails after reset | PASS |
| BFX-B-142 | reset temporary password sign-in | PASS |
| BFX-B-143 | live session profile | PASS |
| BFX-B-144 | reset forces password change | PASS |
| BFX-B-145 | temporary reset token business data denied | PASS |
| BFX-B-146 | live session profile | PASS |
| BFX-B-147 | wrong current password denied | PASS |
| BFX-B-148 | live session profile | PASS |
| BFX-B-149 | verified password change through Edge (HTTP 200) | PASS |
| BFX-B-150 | live session profile | PASS |
| BFX-B-151 | administrator removes assignments | PASS |
| BFX-B-152 | lost assignment old JWT denied | PASS |
| BFX-B-153 | lost assignment new login denied | PASS |
| BFX-B-154 | administrator account list excludes Auth identities and credentials | PASS |
| BFX-B-155 | audit contains no passwords or tokens | PASS |
| BFX-B-156 | unknown/forged actor fields rejected | PASS |
| BFX-B-157 | live session profile | PASS |
| BFX-B-158 | password preparation locks target before external update | PASS |
| BFX-B-159 | pending password account cannot sign in | PASS |
| BFX-B-160 | ordinary administrator cannot call trusted password recovery | PASS |
| BFX-B-161 | trusted recovery resets Auth password | PASS |
| BFX-B-162 | trusted recovery unlocks with forced password change | PASS |
| BFX-B-163 | live session profile | PASS |
| BFX-B-164 | recovered account still requires change | PASS |
| BFX-B-165 | live session profile | PASS |
| BFX-B-166 | verified password change through Edge (HTTP 200) | PASS |
| BFX-B-167 | T05 create synthetic entry | PASS |
| BFX-B-168 | T05 temporary sign in | PASS |
| BFX-B-169 | live session profile | PASS |
| BFX-B-170 | verified password change through Edge (HTTP 200) | PASS |
| BFX-B-171 | T05 ready sign in | PASS |
| BFX-B-172 | T05 create synthetic colleague | PASS |
| BFX-B-173 | T05 temporary sign in | PASS |
| BFX-B-174 | live session profile | PASS |
| BFX-B-175 | verified password change through Edge (HTTP 200) | PASS |
| BFX-B-176 | T05 ready sign in | PASS |
| BFX-B-177 | T05 scope sign in destination | PASS |
| BFX-B-178 | T05 scope sign in outside | PASS |
| BFX-B-179 | T05 master fixture PARTY | PASS |
| BFX-B-180 | T05 master fixture PARTY | PASS |
| BFX-B-181 | T05 master fixture PARTY | PASS |
| BFX-B-182 | T05 master fixture PARTY | PASS |
| BFX-B-183 | T05 master fixture PARTY | PASS |
| BFX-B-184 | T05 master fixture VEHICLE | PASS |
| BFX-B-185 | T05 master fixture ROUTE | PASS |
| BFX-B-186 | T05 master fixture OFFICE | PASS |
| BFX-B-187 | AT-08 draft multi-customer create | PASS |
| BFX-B-188 | T05 only draft lifecycle, potential values, server owner | PASS |
| BFX-B-189 | AT-08 draft exact combined totals | PASS |
| BFX-B-190 | AT-08 separate customers retain independent fares/counts | PASS |
| BFX-B-191 | T05 optional identifiers do not replace car count | PASS |
| BFX-B-192 | T05 identifier stops inherit consignment pickup/drop | PASS |
| BFX-B-193 | T05 create retry returns identical response | PASS |
| BFX-B-194 | T05 request ID mismatch denied | PASS |
| BFX-B-195 | T05 one create audit with trusted actor | PASS |
| BFX-B-196 | T05 origin/destination/admin detail readable | PASS |
| BFX-B-197 | T05 origin/destination/admin detail readable | PASS |
| BFX-B-198 | T05 origin/destination/admin detail readable | PASS |
| BFX-B-199 | T05 destination detail not editable | PASS |
| BFX-B-200 | T05 unrelated detail denied | PASS |
| BFX-B-201 | T05 office scoped search | PASS |
| BFX-B-202 | T05 search cannot expand office scope | PASS |
| BFX-B-203 | T05 office scoped search | PASS |
| BFX-B-204 | T05 search cannot expand office scope | PASS |
| BFX-B-205 | T05 office scoped search | PASS |
| BFX-B-206 | T05 search cannot expand office scope | PASS |
| BFX-B-207 | T05 office scoped search | PASS |
| BFX-B-208 | T05 search cannot expand office scope | PASS |
| BFX-B-209 | T05 office scoped search | PASS |
| BFX-B-210 | T05 search cannot expand office scope | PASS |
| BFX-B-211 | T05 office scoped search | PASS |
| BFX-B-212 | T05 search cannot expand office scope | PASS |
| BFX-B-213 | T05 office scoped search | PASS |
| BFX-B-214 | T05 search cannot expand office scope | PASS |
| BFX-B-215 | T05 office scoped search | PASS |
| BFX-B-216 | T05 search cannot expand office scope | PASS |
| BFX-B-217 | T05 office scoped search | PASS |
| BFX-B-218 | T05 search cannot expand office scope | PASS |
| BFX-B-219 | T05 unauthorized office filter denied | PASS |
| BFX-B-220 | T05 date/state/vehicle filters | PASS |
| BFX-B-221 | T05 date outside range filters draft | PASS |
| BFX-B-222 | T05 invalid date/range/query rejected | PASS |
| BFX-B-223 | T05 direct trips RLS hides outside row | PASS |
| BFX-B-224 | T05 direct trips POST denied | PASS |
| BFX-B-225 | T05 direct trips PATCH denied | PASS |
| BFX-B-226 | T05 direct trips DELETE denied | PASS |
| BFX-B-227 | T05 direct trips POST denied | PASS |
| BFX-B-228 | T05 direct trips PATCH denied | PASS |
| BFX-B-229 | T05 direct trips DELETE denied | PASS |
| BFX-B-230 | T05 direct trips POST denied | PASS |
| BFX-B-231 | T05 direct trips PATCH denied | PASS |
| BFX-B-232 | T05 direct trips DELETE denied | PASS |
| BFX-B-233 | T05 direct trips POST denied | PASS |
| BFX-B-234 | T05 direct trips PATCH denied | PASS |
| BFX-B-235 | T05 direct trips DELETE denied | PASS |
| BFX-B-236 | T05 direct consignments RLS hides outside row | PASS |
| BFX-B-237 | T05 direct consignments POST denied | PASS |
| BFX-B-238 | T05 direct consignments PATCH denied | PASS |
| BFX-B-239 | T05 direct consignments DELETE denied | PASS |
| BFX-B-240 | T05 direct consignments POST denied | PASS |
| BFX-B-241 | T05 direct consignments PATCH denied | PASS |
| BFX-B-242 | T05 direct consignments DELETE denied | PASS |
| BFX-B-243 | T05 direct consignments POST denied | PASS |
| BFX-B-244 | T05 direct consignments PATCH denied | PASS |
| BFX-B-245 | T05 direct consignments DELETE denied | PASS |
| BFX-B-246 | T05 direct consignments POST denied | PASS |
| BFX-B-247 | T05 direct consignments PATCH denied | PASS |
| BFX-B-248 | T05 direct consignments DELETE denied | PASS |
| BFX-B-249 | T05 direct stops RLS hides outside row | PASS |
| BFX-B-250 | T05 direct stops POST denied | PASS |
| BFX-B-251 | T05 direct stops PATCH denied | PASS |
| BFX-B-252 | T05 direct stops DELETE denied | PASS |
| BFX-B-253 | T05 direct stops POST denied | PASS |
| BFX-B-254 | T05 direct stops PATCH denied | PASS |
| BFX-B-255 | T05 direct stops DELETE denied | PASS |
| BFX-B-256 | T05 direct stops POST denied | PASS |
| BFX-B-257 | T05 direct stops PATCH denied | PASS |
| BFX-B-258 | T05 direct stops DELETE denied | PASS |
| BFX-B-259 | T05 direct stops POST denied | PASS |
| BFX-B-260 | T05 direct stops PATCH denied | PASS |
| BFX-B-261 | T05 direct stops DELETE denied | PASS |
| BFX-B-262 | T05 direct consignment_cars RLS hides outside row | PASS |
| BFX-B-263 | T05 direct consignment_cars POST denied | PASS |
| BFX-B-264 | T05 direct consignment_cars PATCH denied | PASS |
| BFX-B-265 | T05 direct consignment_cars DELETE denied | PASS |
| BFX-B-266 | T05 direct consignment_cars POST denied | PASS |
| BFX-B-267 | T05 direct consignment_cars PATCH denied | PASS |
| BFX-B-268 | T05 direct consignment_cars DELETE denied | PASS |
| BFX-B-269 | T05 direct consignment_cars POST denied | PASS |
| BFX-B-270 | T05 direct consignment_cars PATCH denied | PASS |
| BFX-B-271 | T05 direct consignment_cars DELETE denied | PASS |
| BFX-B-272 | T05 direct consignment_cars POST denied | PASS |
| BFX-B-273 | T05 direct consignment_cars PATCH denied | PASS |
| BFX-B-274 | T05 direct consignment_cars DELETE denied | PASS |
| BFX-B-275 | T05 only assigned creator/admin edits | PASS |
| BFX-B-276 | T05 only assigned creator/admin edits | PASS |
| BFX-B-277 | T05 only assigned creator/admin edits | PASS |
| BFX-B-278 | T05 only assigned creator/admin edits | PASS |
| BFX-B-279 | T05 spoofing new origin cannot bypass existing origin | PASS |
| BFX-B-280 | T05 manipulated derived prices reconciled | PASS |
| BFX-B-281 | T05 manipulated client cannot override server totals | PASS |
| BFX-B-282 | T05 stale expected version denied | PASS |
| BFX-B-283 | T05 JSON numeric fare rejected | PASS |
| BFX-B-284 | T05 extra decimal fare rejected | PASS |
| BFX-B-285 | T05 negative fare rejected | PASS |
| BFX-B-286 | T05 percentage over 100 rejected | PASS |
| BFX-B-287 | T05 deduction greater than fare rejected | PASS |
| BFX-B-288 | T05 broker missing for commission rejected | PASS |
| BFX-B-289 | T05 zero count rejected | PASS |
| BFX-B-290 | T05 more identifiers than count rejected | PASS |
| BFX-B-291 | T05 duplicate identifiers rejected | PASS |
| BFX-B-292 | T05 foreign stop rejected | PASS |
| BFX-B-293 | T05 drop before pickup rejected | PASS |
| BFX-B-294 | T05 wrong stop kind rejected | PASS |
| BFX-B-295 | T05 wrong customer role rejected | PASS |
| BFX-B-296 | T05 duplicate child ID rejected | PASS |
| BFX-B-297 | T05 reuse child from other draft rejected | PASS |
| BFX-B-298 | T05 empty cannot carry consignments rejected | PASS |
| BFX-B-299 | T05 loaded requires consignments rejected | PASS |
| BFX-B-300 | T05 injected state rejected | PASS |
| BFX-B-301 | T05 injected dispatch_date rejected | PASS |
| BFX-B-302 | T05 injected owner_id rejected | PASS |
| BFX-B-303 | T05 injected business_id rejected | PASS |
| BFX-B-304 | T05 injected created_by rejected | PASS |
| BFX-B-305 | T05 failed aggregate writes roll back completely | PASS |
| BFX-B-306 | T05 missing edit reason rejected | PASS |
| BFX-B-307 | T05 null expected version rejected | PASS |
| BFX-B-308 | T05 competing edits exactly one succeeds | PASS |
| BFX-B-309 | T05 update current owner | PASS |
| BFX-B-310 | T05 update route fare | PASS |
| BFX-B-311 | T05 saved draft edit preserves history | PASS |
| BFX-B-312 | T05 existing owner/route/agreed fares remain recorded | PASS |
| BFX-B-313 | T05 new draft snapshots current owner | PASS |
| BFX-B-314 | T05 new draft uses new owner/route | PASS |
| BFX-B-315 | AT-09 linked empty return | PASS |
| BFX-B-316 | AT-09 return links original, reverses offices | PASS |
| BFX-B-317 | AT-09 linked loaded return | PASS |
| BFX-B-318 | AT-09 return links original, reverses offices | PASS |
| BFX-B-319 | AT-09 original detail shows both returns | PASS |
| BFX-B-320 | AT-09 return cycle rejected | PASS |
| BFX-B-321 | T05 administrator edits another creator draft | PASS |
| BFX-B-322 | AT-09 invalid return direction rejected | PASS |
| BFX-B-323 | AT-09 self return rejected | PASS |
| BFX-B-324 | AT-09 linked parent offices cannot be changed | PASS |
| BFX-B-325 | T05 aggregate edit fixture | PASS |
| BFX-B-326 | T05 reorder stops atomically | PASS |
| BFX-B-327 | T05 reorder keeps links and consecutive positions | PASS |
| BFX-B-328 | T05 remove draft children atomically | PASS |
| BFX-B-329 | T05 removed consignment, cars and unused stops absent | PASS |
| BFX-B-330 | T05 convert unposted draft to empty | PASS |
| BFX-B-331 | T05 empty edit clears quote aggregate and children | PASS |
| BFX-B-332 | T05 archive customer fixture | PASS |
| BFX-B-333 | T05 new draft cannot choose archived customer | PASS |
| BFX-B-334 | T05 existing draft retains archived customer | PASS |
| BFX-B-335 | T05 archived historical agreement preserved | PASS |
| BFX-B-336 | T05 restore synthetic customer | PASS |
| BFX-B-337 | T05 bounded pagination without repeats | PASS |
| BFX-B-338 | T05 overlap review | PASS |
| BFX-B-339 | T05 overlap includes visible trip plus generic restricted warning | PASS |
| BFX-B-340 | T05 overlap response discloses no hidden ID/name/count | PASS |
| BFX-B-341 | T05 overlapping draft cannot save without review | PASS |
| BFX-B-342 | T05 explicit checkbox alone cannot bypass ticket | PASS |
| BFX-B-343 | T05 review belongs to actor | PASS |
| BFX-B-344 | T05 overlap confirmation requires reason | PASS |
| BFX-B-345 | T05 changed overlap context must be reviewed again | PASS |
| BFX-B-346 | T05 renewed overlap review | PASS |
| BFX-B-347 | T05 confirmed overlap draft save | PASS |
| BFX-B-348 | T05 confirmed warning and reason recorded | PASS |
| BFX-B-349 | T05 expiring review fixture | PASS |
| BFX-B-350 | T05 expired review denied | PASS |
| BFX-B-351 | T05 dispatched record cannot be edited by draft command | PASS |
| BFX-B-352 | T05 drafts post no financial events | PASS |
| BFX-B-353 | T06 managed synthetic lifecycle | PASS |
| BFX-B-354 | T06 temporary login | PASS |
| BFX-B-355 | live session profile | PASS |
| BFX-B-356 | verified password change through Edge (HTTP 200) | PASS |
| BFX-B-357 | T06 ready login | PASS |
| BFX-B-358 | T06 managed synthetic dispatcher | PASS |
| BFX-B-359 | T06 temporary login | PASS |
| BFX-B-360 | live session profile | PASS |
| BFX-B-361 | verified password change through Edge (HTTP 200) | PASS |
| BFX-B-362 | T06 ready login | PASS |
| BFX-B-363 | T06 managed synthetic arrivalpeer | PASS |
| BFX-B-364 | T06 temporary login | PASS |
| BFX-B-365 | live session profile | PASS |
| BFX-B-366 | verified password change through Edge (HTTP 200) | PASS |
| BFX-B-367 | T06 ready login | PASS |
| BFX-B-368 | T06 existing scope login | PASS |
| BFX-B-369 | T06 existing scope login | PASS |
| BFX-B-370 | T06 synthetic PARTY | PASS |
| BFX-B-371 | T06 synthetic PARTY | PASS |
| BFX-B-372 | T06 synthetic PARTY | PASS |
| BFX-B-373 | T06 synthetic PARTY | PASS |
| BFX-B-374 | T06 synthetic PARTY | PASS |
| BFX-B-375 | T06 synthetic VEHICLE | PASS |
| BFX-B-376 | T06 draft overlap review | PASS |
| BFX-B-377 | T06 save draft | PASS |
| BFX-B-378 | AT-12 origin lifecycle controls | PASS |
| BFX-B-379 | AT-12 destination read-only fare/draft controls | PASS |
| BFX-B-380 | AT-12/15 denied unauthorized/other-creator draft cancellation | PASS |
| BFX-B-381 | AT-12/15 denied unauthorized/other-creator draft cancellation | PASS |
| BFX-B-382 | AT-12/15 denied unauthorized/other-creator draft cancellation | PASS |
| BFX-B-383 | AT-12/15 denied unauthorized/other-creator draft cancellation | PASS |
| BFX-B-384 | AT-08 cancel one draft consignment | PASS |
| BFX-B-385 | AT-08 cancelled quote excluded, evidence retained | PASS |
| BFX-B-386 | AT-08 draft save cannot remove cancelled evidence | PASS |
| BFX-B-387 | AT-08 draft save cannot rewrite cancelled agreed fare | PASS |
| BFX-B-388 | AT-08 rejected cancelled edits roll back aggregate version | PASS |
| BFX-B-389 | AT-07 planned draft posts no earnings | PASS |
| BFX-B-390 | AT-12 destination/outside/anonymous cannot dispatch | PASS |
| BFX-B-391 | AT-12 destination/outside/anonymous cannot dispatch | PASS |
| BFX-B-392 | AT-12 destination/outside/anonymous cannot dispatch | PASS |
| BFX-B-393 | T06 invalid date/reason/actor/unsupported advance fields rejected | PASS |
| BFX-B-394 | T06 invalid date/reason/actor/unsupported advance fields rejected | PASS |
| BFX-B-395 | T06 invalid date/reason/actor/unsupported advance fields rejected | PASS |
| BFX-B-396 | T06 invalid date/reason/actor/unsupported advance fields rejected | PASS |
| BFX-B-397 | T06 invalid date/reason/actor/unsupported advance fields rejected | PASS |
| BFX-B-398 | T06 arrival before dispatch rejected | PASS |
| BFX-B-399 | T06 server overlap review | PASS |
| BFX-B-400 | AT-07/12 origin colleague dispatches reviewed draft | PASS |
| BFX-B-401 | AT-07 actual dispatch recognized atomically | PASS |
| BFX-B-402 | T06 dispatch retry returns one committed result | PASS |
| BFX-B-403 | T06 changed retry rejected | PASS |
| BFX-B-404 | T06 exactly two active consignment dispatch events | PASS |
| BFX-B-405 | T06 every dispatch journal balanced | PASS |
| BFX-B-406 | T06 exact debt/owner/broker recognition split | PASS |
| BFX-B-407 | AT-12 origin/outside/anonymous cannot arrive | PASS |
| BFX-B-408 | AT-12 origin/outside/anonymous cannot arrive | PASS |
| BFX-B-409 | AT-12 origin/outside/anonymous cannot arrive | PASS |
| BFX-B-410 | T06 missing/early/impossible arrival date rejected | PASS |
| BFX-B-411 | T06 missing/early/impossible arrival date rejected | PASS |
| BFX-B-412 | T06 missing/early/impossible arrival date rejected | PASS |
| BFX-B-413 | AT-12 direct cross-office fare edit denied | PASS |
| BFX-B-414 | AT-15 confirmed fare cannot use draft edits | PASS |
| BFX-B-415 | AT-08 destination arrival | PASS |
| BFX-B-416 | AT-08 active delivered, cancelled stays cancelled | PASS |
| BFX-B-417 | AT-08 all stops/counts/car IDs and prices preserved | PASS |
| BFX-B-418 | Arrival leaves customer/owner/broker balances byte-equivalent | PASS |
| BFX-B-419 | Arrival creates no receipt, settlement or financial event | PASS |
| BFX-B-420 | Arrival cannot repeat as a fresh transition | PASS |
| BFX-B-421 | AT-15 trip creator cannot correct colleague dispatch date | PASS |
| BFX-B-422 | AT-15 other destination creator cannot correct arrival | PASS |
| BFX-B-423 | AT-15 arrival creator needs current destination permission | PASS |
| BFX-B-424 | AT-15 arrival creator correction | PASS |
| BFX-B-425 | Arrival date correction leaves money untouched | PASS |
| BFX-B-426 | AT-15 colleague cannot correct trip creator notes | PASS |
| BFX-B-427 | AT-15 own operational correction | PASS |
| BFX-B-428 | Operational edit cannot inject fare/date/state/owner | PASS |
| BFX-B-429 | AT-07/15 append dispatch date reversal/replacement | PASS |
| BFX-B-430 | AT-15 corrected date retry creates no extra postings | PASS |
| BFX-B-431 | AT-15 original dispatch event data immutable | PASS |
| BFX-B-432 | AT-15 one exact reversal and replacement per source | PASS |
| BFX-B-433 | AT-07 historical monthly earnings move with correction | PASS |
| BFX-B-434 | AT-07 correction changes date basis, not lifetime owner debt | PASS |
| BFX-B-435 | T06 dispatch cannot be corrected beyond arrival | PASS |
| BFX-B-436 | AT-15 concurrent edits one commit, one conflict | PASS |
| BFX-B-437 | T06 scoped audit history | PASS |
| BFX-B-438 | AT-07/15 history explains effective-date correction | PASS |
| BFX-B-439 | T06 history has no Auth/business/request IDs or hidden snapshots | PASS |
| BFX-B-440 | T06 outside/anonymous audit history denied | PASS |
| BFX-B-441 | AT-15 dependent receipt blocks date repost | PASS |
| BFX-B-442 | AT-07 receipt fixture retains independent March effective date | PASS |
| BFX-B-443 | T06 confirmed cancellation requires later financial adjustment | PASS |
| BFX-B-444 | T06 draft overlap review | PASS |
| BFX-B-445 | T06 save draft | PASS |
| BFX-B-446 | T06 server overlap review | PASS |
| BFX-B-447 | T06 draft overlap review | PASS |
| BFX-B-448 | T06 save draft | PASS |
| BFX-B-449 | T06 server overlap review | PASS |
| BFX-B-450 | T06 deferred commit failure is an HTTP failure | PASS |
| BFX-B-451 | T06 failed posting rolls back state, journal, batch, audit and retry | PASS |
| BFX-B-452 | T06 same request succeeds once after commit failure removed | PASS |
| BFX-B-453 | T06 draft overlap review | PASS |
| BFX-B-454 | T06 save draft | PASS |
| BFX-B-455 | T06 draft overlap review | PASS |
| BFX-B-456 | T06 save draft | PASS |
| BFX-B-457 | T06 server overlap review | PASS |
| BFX-B-458 | T06 server overlap review | PASS |
| BFX-B-459 | T06 empty dispatch creates no fare | PASS |
| BFX-B-460 | T06 empty dispatch has recognition marker but no financial events | PASS |
| BFX-B-461 | T06 second dispatch cannot reuse pre-dispatch overlap review | PASS |
| BFX-B-462 | T06 acknowledged draft flag alone cannot dispatch overlap | PASS |
| BFX-B-463 | T06 server overlap review | PASS |
| BFX-B-464 | T06 refreshed reviewed overlap dispatch | PASS |
| BFX-B-465 | AT-08/15 concurrent arrival one commit one conflict | PASS |
| BFX-B-466 | T06 draft overlap review | PASS |
| BFX-B-467 | T06 save draft | PASS |
| BFX-B-468 | T06 draft cancellation retains record | PASS |
| BFX-B-469 | T06 cancelled draft has no actual dates or financial success | PASS |
| BFX-B-470 | T06 cancelled draft cannot dispatch | PASS |
| BFX-B-471 | live session profile | PASS |
| BFX-B-472 | T06 revoke dispatcher origin assignment | PASS |
| BFX-B-473 | AT-15 revoked creator JWT cannot correct own dispatch | PASS |
| BFX-B-474 | AT-15 administrator corrects another creator notes | PASS |
| BFX-B-475 | T06 null expected version rejected | PASS |
| BFX-B-476 | T07 managed origin staff | PASS |
| BFX-B-477 | T07 temporary login | PASS |
| BFX-B-478 | live session profile | PASS |
| BFX-B-479 | verified password change through Edge (HTTP 200) | PASS |
| BFX-B-480 | T07 ready login | PASS |
| BFX-B-481 | T07 destination login | PASS |
| BFX-B-482 | T07 unrelated login | PASS |
| BFX-B-483 | T07 synthetic PARTY | PASS |
| BFX-B-484 | T07 synthetic PARTY | PASS |
| BFX-B-485 | T07 synthetic PARTY | PASS |
| BFX-B-486 | T07 synthetic PARTY | PASS |
| BFX-B-487 | T07 synthetic VEHICLE | PASS |
| BFX-B-488 | T07 draft review | PASS |
| BFX-B-489 | T07 save draft | PASS |
| BFX-B-490 | T07 actual dispatch review | PASS |
| BFX-B-491 | T07 existing atomic dispatch | PASS |
| BFX-B-492 | AT-16 dispatch retry does not duplicate earnings | PASS |
| BFX-B-493 | AT-01 recognized exact deducted split | PASS |
| BFX-B-494 | T07 scoped claim read omits raw event/actor/business metadata | PASS |
| BFX-B-495 | T07 unrelated/anonymous ledger reads denied | PASS |
| BFX-B-496 | T07 unauthorized receipt denied | PASS |
| BFX-B-497 | T07 unauthorized receipt denied | PASS |
| BFX-B-498 | AT-17 invalid precision/type/range/sign rejected | PASS |
| BFX-B-499 | AT-17 invalid precision/type/range/sign rejected | PASS |
| BFX-B-500 | AT-17 invalid precision/type/range/sign rejected | PASS |
| BFX-B-501 | AT-17 invalid precision/type/range/sign rejected | PASS |
| BFX-B-502 | AT-17 invalid precision/type/range/sign rejected | PASS |
| BFX-B-503 | T07 spoofing/wrong-party/duplicate/mismatch denied | PASS |
| BFX-B-504 | T07 spoofing/wrong-party/duplicate/mismatch denied | PASS |
| BFX-B-505 | T07 spoofing/wrong-party/duplicate/mismatch denied | PASS |
| BFX-B-506 | T07 spoofing/wrong-party/duplicate/mismatch denied | PASS |
| BFX-B-507 | T07 spoofing/wrong-party/duplicate/mismatch denied | PASS |
| BFX-B-508 | T07 spoofing/wrong-party/duplicate/mismatch denied | PASS |
| BFX-B-509 | T07 nonzero create version denied | PASS |
| BFX-B-510 | T07 unimplemented recognition/expense/correction workflows blocked | PASS |
| BFX-B-511 | AT-04 customer receipt by destination staff | PASS |
| BFX-B-512 | AT-04 customer debt, held money and owner debt separate | PASS |
| BFX-B-513 | AT-16 identical receipt retry returns exact result | PASS |
| BFX-B-514 | AT-16 changed request or different actor rejected | PASS |
| BFX-B-515 | AT-16 one event/audit/idempotency result on retries | PASS |
| BFX-B-516 | T07 archive/restore recipient | PASS |
| BFX-B-517 | AT-16 archived recipient retains committed retry result | PASS |
| BFX-B-518 | T07 archived recipient cannot receive new posting | PASS |
| BFX-B-519 | T07 archive/restore recipient | PASS |
| BFX-B-520 | AT-04 private retention/remittance kernel yields 40000 debt and zero custody | PASS |
| BFX-B-521 | AT-16 private kernel settlement retry consumes once | PASS |
| BFX-B-522 | T07 draft review | PASS |
| BFX-B-523 | T07 save draft | PASS |
| BFX-B-524 | T07 actual dispatch review | PASS |
| BFX-B-525 | T07 existing atomic dispatch | PASS |
| BFX-B-526 | AT-16 dispatch retry does not duplicate earnings | PASS |
| BFX-B-527 | AT-01/02 full customer receipt | PASS |
| BFX-B-528 | AT-01/02 receipt is not owner settlement | PASS |
| BFX-B-529 | AT-01/02 full canonical private settlement balances zero | PASS |
| BFX-B-530 | T07 draft review | PASS |
| BFX-B-531 | T07 save draft | PASS |
| BFX-B-532 | T07 actual dispatch review | PASS |
| BFX-B-533 | T07 existing atomic dispatch | PASS |
| BFX-B-534 | AT-16 dispatch retry does not duplicate earnings | PASS |
| BFX-B-535 | AT-01/02 full customer receipt | PASS |
| BFX-B-536 | AT-01/02 receipt is not owner settlement | PASS |
| BFX-B-537 | AT-01/02 full canonical private settlement balances zero | PASS |
| BFX-B-538 | T07 draft review | PASS |
| BFX-B-539 | T07 save draft | PASS |
| BFX-B-540 | T07 actual dispatch review | PASS |
| BFX-B-541 | T07 existing atomic dispatch | PASS |
| BFX-B-542 | AT-16 dispatch retry does not duplicate earnings | PASS |
| BFX-B-543 | AT-16 competing customer claim one commit one conflict | PASS |
| BFX-B-544 | AT-17 exact paisa remaining derived from journal | PASS |
| BFX-B-545 | AT-16 concurrent identical retries return one event | PASS |
| BFX-B-546 | T07 consumed claims excluded from open choices | PASS |
| BFX-B-547 | T07 draft review | PASS |
| BFX-B-548 | T07 save draft | PASS |
| BFX-B-549 | T07 actual dispatch review | PASS |
| BFX-B-550 | T07 existing atomic dispatch | PASS |
| BFX-B-551 | AT-16 dispatch retry does not duplicate earnings | PASS |
| BFX-B-552 | T07 seed real custody for race | PASS |
| BFX-B-553 | AT-16 competing custody spend one commit one conflict | PASS |
| BFX-B-554 | T07 custody cannot go negative | PASS |
| BFX-B-555 | T07 overdraft rejected at current source revision | PASS |
| BFX-B-556 | T07 pre-earning receipt requires later advance workflow | PASS |
| BFX-B-557 | T07 draft review | PASS |
| BFX-B-558 | T07 save draft | PASS |
| BFX-B-559 | T07 actual dispatch review | PASS |
| BFX-B-560 | T07 existing atomic dispatch | PASS |
| BFX-B-561 | AT-16 dispatch retry does not duplicate earnings | PASS |
| BFX-B-562 | T07 draft review | PASS |
| BFX-B-563 | T07 save draft | PASS |
| BFX-B-564 | T07 actual dispatch review | PASS |
| BFX-B-565 | T07 existing atomic dispatch | PASS |
| BFX-B-566 | AT-16 dispatch retry does not duplicate earnings | PASS |
| BFX-B-567 | T07 multi-trip explicit receipt | PASS |
| BFX-B-568 | T07 bulk event metadata stays private; trip totals are contextual | PASS |
| BFX-B-569 | T07 draft review | PASS |
| BFX-B-570 | T07 save draft | PASS |
| BFX-B-571 | T07 actual dispatch review | PASS |
| BFX-B-572 | T07 existing atomic dispatch | PASS |
| BFX-B-573 | AT-16 dispatch retry does not duplicate earnings | PASS |
| BFX-B-574 | T07 any inaccessible bulk target denied | PASS |
| BFX-B-575 | T07 draft review | PASS |
| BFX-B-576 | T07 save draft | PASS |
| BFX-B-577 | T07 actual dispatch review | PASS |
| BFX-B-578 | T07 existing atomic dispatch | PASS |
| BFX-B-579 | AT-16 dispatch retry does not duplicate earnings | PASS |
| BFX-B-580 | T07 real receipt supplies claim-kernel fixture custody | PASS |
| BFX-B-581 | T07 synthetic CATEGORY | PASS |
| BFX-B-582 | T07 private funding/reimbursement/credit claims consume exactly once | PASS |
| BFX-B-583 | T07 eight distinct account purposes query from effective journal | PASS |
| BFX-B-584 | T07 draft review | PASS |
| BFX-B-585 | T07 save draft | PASS |
| BFX-B-586 | T07 actual dispatch review | PASS |
| BFX-B-587 | T07 existing atomic dispatch | PASS |
| BFX-B-588 | AT-16 dispatch retry does not duplicate earnings | PASS |
| BFX-B-589 | T07 owner receives customer funds in custody | PASS |
| BFX-B-590 | T07 owner custody receipt still does not settle owner entitlement | PASS |
| BFX-B-591 | T07 draft review | PASS |
| BFX-B-592 | T07 save draft | PASS |
| BFX-B-593 | T07 actual dispatch review | PASS |
| BFX-B-594 | T07 existing atomic dispatch | PASS |
| BFX-B-595 | AT-16 dispatch retry does not duplicate earnings | PASS |
| BFX-B-596 | T07 draft review | PASS |
| BFX-B-597 | T07 save draft | PASS |
| BFX-B-598 | T07 actual dispatch review | PASS |
| BFX-B-599 | T07 existing atomic dispatch | PASS |
| BFX-B-600 | AT-16 dispatch retry does not duplicate earnings | PASS |
| BFX-B-601 | T07 exact wide aggregate summary | PASS |
| BFX-B-602 | AT-17 aggregate balances exceed single posting bound without overflow | PASS |
| BFX-B-603 | T07 draft review | PASS |
| BFX-B-604 | T07 save draft | PASS |
| BFX-B-605 | T07 actual dispatch review | PASS |
| BFX-B-606 | T07 existing atomic dispatch | PASS |
| BFX-B-607 | AT-16 dispatch retry does not duplicate earnings | PASS |
| BFX-B-608 | T07 deferred commit failure returns failure | PASS |
| BFX-B-609 | T07 no partial event/allocations/audit/retry/claim changes | PASS |
| BFX-B-610 | T07 same receipt request succeeds after rollback | PASS |
| BFX-B-611 | T07 every created event balanced | PASS |
| BFX-B-612 | T07 original recognition once, no second earnings from receipt | PASS |
| BFX-B-613 | global logout succeeds | PASS |
| BFX-B-614 | logged-out JWT fails live authorization | PASS |
| BFX-B-615 | synthetic identities and business fixtures removed | PASS |
| BFX-P-staged-01 | Build6 staged: accounts-setup.md — manifest bytes/hash and credential/privacy scan | PASS |
| BFX-P-staged-02 | Build6 staged: app_links_plugin.dll — manifest bytes/hash and credential/privacy scan | PASS |
| BFX-P-staged-03 | Build6 staged: carrier_records.exe — manifest bytes/hash and credential/privacy scan | PASS |
| BFX-P-staged-04 | Build6 staged: file_selector_windows_plugin.dll — manifest bytes/hash and credential/privacy scan | PASS |
| BFX-P-staged-05 | Build6 staged: flutter_secure_storage_windows_plugin.dll — manifest bytes/hash and credential/privacy scan | PASS |
| BFX-P-staged-06 | Build6 staged: flutter_windows.dll — manifest bytes/hash and credential/privacy scan | PASS |
| BFX-P-staged-07 | Build6 staged: INSTALLATION.md — manifest bytes/hash and credential/privacy scan | PASS |
| BFX-P-staged-08 | Build6 staged: masters-setup.md — manifest bytes/hash and credential/privacy scan | PASS |
| BFX-P-staged-09 | Build6 staged: native_assets.json — manifest bytes/hash and credential/privacy scan | PASS |
| BFX-P-staged-10 | Build6 staged: pdfium.dll — manifest bytes/hash and credential/privacy scan | PASS |
| BFX-P-staged-11 | Build6 staged: printing_plugin.dll — manifest bytes/hash and credential/privacy scan | PASS |
| BFX-P-staged-12 | Build6 staged: restoration-evidence.md — manifest bytes/hash and credential/privacy scan | PASS |
| BFX-P-staged-13 | Build6 staged: restoration-setup.md — manifest bytes/hash and credential/privacy scan | PASS |
| BFX-P-staged-14 | Build6 staged: share_plus_plugin.dll — manifest bytes/hash and credential/privacy scan | PASS |
| BFX-P-staged-15 | Build6 staged: url_launcher_windows_plugin.dll — manifest bytes/hash and credential/privacy scan | PASS |
| BFX-P-staged-16 | Build6 staged: windows-backend-prerequisites.md — manifest bytes/hash and credential/privacy scan | PASS |
| BFX-P-staged-17 | Build6 staged: windows-pilot-checklist.md — manifest bytes/hash and credential/privacy scan | PASS |
| BFX-P-staged-18 | Build6 staged: data/app.so — manifest bytes/hash and credential/privacy scan | PASS |
| BFX-P-staged-19 | Build6 staged: data/icudtl.dat — manifest bytes/hash and credential/privacy scan | PASS |
| BFX-P-staged-20 | Build6 staged: data/flutter_assets/AssetManifest.bin — manifest bytes/hash and credential/privacy scan | PASS |
| BFX-P-staged-21 | Build6 staged: data/flutter_assets/FontManifest.json — manifest bytes/hash and credential/privacy scan | PASS |
| BFX-P-staged-22 | Build6 staged: data/flutter_assets/NativeAssetsManifest.json — manifest bytes/hash and credential/privacy scan | PASS |
| BFX-P-staged-23 | Build6 staged: data/flutter_assets/NOTICES.Z — manifest bytes/hash and credential/privacy scan | PASS |
| BFX-P-staged-24 | Build6 staged: data/flutter_assets/assets/fonts/NotoSans-Bold.ttf — manifest bytes/hash and credential/privacy scan | PASS |
| BFX-P-staged-25 | Build6 staged: data/flutter_assets/assets/fonts/NotoSans-Regular.ttf — manifest bytes/hash and credential/privacy scan | PASS |
| BFX-P-staged-26 | Build6 staged: data/flutter_assets/fonts/MaterialIcons-Regular.otf — manifest bytes/hash and credential/privacy scan | PASS |
| BFX-P-staged-27 | Build6 staged: data/flutter_assets/packages/cupertino_icons/assets/CupertinoIcons.ttf — manifest bytes/hash and credential/privacy scan | PASS |
| BFX-P-staged-28 | Build6 staged: data/flutter_assets/packages/material_ui/shaders/ink_sparkle.frag — manifest bytes/hash and credential/privacy scan | PASS |
| BFX-P-staged-29 | Build6 staged: data/flutter_assets/shaders/ink_sparkle.frag — manifest bytes/hash and credential/privacy scan | PASS |
| BFX-P-staged-30 | Build6 staged: data/flutter_assets/shaders/stretch_effect.frag — manifest bytes/hash and credential/privacy scan | PASS |
| BFX-P-installed-01 | Build6 installed: accounts-setup.md — manifest bytes/hash and credential/privacy scan | PASS |
| BFX-P-installed-02 | Build6 installed: app_links_plugin.dll — manifest bytes/hash and credential/privacy scan | PASS |
| BFX-P-installed-03 | Build6 installed: carrier_records.exe — manifest bytes/hash and credential/privacy scan | PASS |
| BFX-P-installed-04 | Build6 installed: file_selector_windows_plugin.dll — manifest bytes/hash and credential/privacy scan | PASS |
| BFX-P-installed-05 | Build6 installed: flutter_secure_storage_windows_plugin.dll — manifest bytes/hash and credential/privacy scan | PASS |
| BFX-P-installed-06 | Build6 installed: flutter_windows.dll — manifest bytes/hash and credential/privacy scan | PASS |
| BFX-P-installed-07 | Build6 installed: INSTALLATION.md — manifest bytes/hash and credential/privacy scan | PASS |
| BFX-P-installed-08 | Build6 installed: masters-setup.md — manifest bytes/hash and credential/privacy scan | PASS |
| BFX-P-installed-09 | Build6 installed: native_assets.json — manifest bytes/hash and credential/privacy scan | PASS |
| BFX-P-installed-10 | Build6 installed: pdfium.dll — manifest bytes/hash and credential/privacy scan | PASS |
| BFX-P-installed-11 | Build6 installed: printing_plugin.dll — manifest bytes/hash and credential/privacy scan | PASS |
| BFX-P-installed-12 | Build6 installed: restoration-evidence.md — manifest bytes/hash and credential/privacy scan | PASS |
| BFX-P-installed-13 | Build6 installed: restoration-setup.md — manifest bytes/hash and credential/privacy scan | PASS |
| BFX-P-installed-14 | Build6 installed: share_plus_plugin.dll — manifest bytes/hash and credential/privacy scan | PASS |
| BFX-P-installed-15 | Build6 installed: url_launcher_windows_plugin.dll — manifest bytes/hash and credential/privacy scan | PASS |
| BFX-P-installed-16 | Build6 installed: windows-backend-prerequisites.md — manifest bytes/hash and credential/privacy scan | PASS |
| BFX-P-installed-17 | Build6 installed: windows-pilot-checklist.md — manifest bytes/hash and credential/privacy scan | PASS |
| BFX-P-installed-18 | Build6 installed: data/app.so — manifest bytes/hash and credential/privacy scan | PASS |
| BFX-P-installed-19 | Build6 installed: data/icudtl.dat — manifest bytes/hash and credential/privacy scan | PASS |
| BFX-P-installed-20 | Build6 installed: data/flutter_assets/AssetManifest.bin — manifest bytes/hash and credential/privacy scan | PASS |
| BFX-P-installed-21 | Build6 installed: data/flutter_assets/FontManifest.json — manifest bytes/hash and credential/privacy scan | PASS |
| BFX-P-installed-22 | Build6 installed: data/flutter_assets/NativeAssetsManifest.json — manifest bytes/hash and credential/privacy scan | PASS |
| BFX-P-installed-23 | Build6 installed: data/flutter_assets/NOTICES.Z — manifest bytes/hash and credential/privacy scan | PASS |
| BFX-P-installed-24 | Build6 installed: data/flutter_assets/assets/fonts/NotoSans-Bold.ttf — manifest bytes/hash and credential/privacy scan | PASS |
| BFX-P-installed-25 | Build6 installed: data/flutter_assets/assets/fonts/NotoSans-Regular.ttf — manifest bytes/hash and credential/privacy scan | PASS |
| BFX-P-installed-26 | Build6 installed: data/flutter_assets/fonts/MaterialIcons-Regular.otf — manifest bytes/hash and credential/privacy scan | PASS |
| BFX-P-installed-27 | Build6 installed: data/flutter_assets/packages/cupertino_icons/assets/CupertinoIcons.ttf — manifest bytes/hash and credential/privacy scan | PASS |
| BFX-P-installed-28 | Build6 installed: data/flutter_assets/packages/material_ui/shaders/ink_sparkle.frag — manifest bytes/hash and credential/privacy scan | PASS |
| BFX-P-installed-29 | Build6 installed: data/flutter_assets/shaders/ink_sparkle.frag — manifest bytes/hash and credential/privacy scan | PASS |
| BFX-P-installed-30 | Build6 installed: data/flutter_assets/shaders/stretch_effect.frag — manifest bytes/hash and credential/privacy scan | PASS |

### Final Flutter build6 console evidence
Command `tools/flutter.ps1 test --no-pub`: exit0,91 tests PASS. Parallel console labels can repeat; this is the observed progress transcript, not an invented unique-case mapping. Full source tests and relevant red/green attempts are preserved.

```text
00:00 +0: loading D:/portfolio/transport_project/app/test/account_error_test.dart
00:00 +0: D:/portfolio/transport_project/app/test/account_error_test.dart: account errors identify only approved stages and status
00:00 +1: D:/portfolio/transport_project/app/test/account_error_test.dart: unknown bodies and exceptions cannot expose private information
00:00 +2: D:/portfolio/transport_project/app/test/auth_test.dart: configuration accepts public keys and normalizes usernames
00:00 +3: D:/portfolio/transport_project/app/test/auth_test.dart: configuration rejects privileged keys and insecure production URLs
00:00 +4: D:/portfolio/transport_project/app/test/auth_test.dart: session writes are serialized and logout deletion wins pending writes
00:00 +5: D:/portfolio/transport_project/app/test/auth_test.dart: secure storage errors propagate without plaintext fallback
00:02 +6: D:/portfolio/transport_project/app/test/backup_workspace_test.dart: failed manual helper never claims backup success or active schedule
00:05 +7: D:/portfolio/transport_project/app/test/browser_bug_regression_test.dart: destination picker retains authorized label outside origin assignments
00:10 +8: D:/portfolio/transport_project/app/test/browser_bug_regression_test.dart: Escape dismisses an idle operation without backend mutation
00:10 +9: D:/portfolio/transport_project/app/test/correction_workspace_test.dart: Correction commits before success and preserves UUID after lost response
00:12 +10: D:/portfolio/transport_project/app/test/correction_workspace_test.dart: Correction commits before success and preserves UUID after lost response
00:13 +11: D:/portfolio/transport_project/app/test/correction_workspace_test.dart: Correction commits before success and preserves UUID after lost response
00:14 +12: D:/portfolio/transport_project/app/test/correction_workspace_test.dart: Correction commits before success and preserves UUID after lost response
00:17 +13: D:/portfolio/transport_project/app/test/correction_workspace_test.dart: Cancellation reviews exact fee split; conflict prevents automatic repost
00:46 +14: D:/portfolio/transport_project/app/test/document_workspace_test.dart: Issuance waits for commit and ambiguous retry preserves UUID and reason
00:48 +15: D:/portfolio/transport_project/app/test/document_workspace_test.dart: Issuance waits for commit and ambiguous retry preserves UUID and reason
00:48 +16: D:/portfolio/transport_project/app/test/document_workspace_test.dart: Issuance waits for commit and ambiguous retry preserves UUID and reason
00:48 +17: D:/portfolio/transport_project/app/test/document_workspace_test.dart: Issuance waits for commit and ambiguous retry preserves UUID and reason
00:48 +18: D:/portfolio/transport_project/app/test/document_workspace_test.dart: Issuance waits for commit and ambiguous retry preserves UUID and reason
00:48 +19: D:/portfolio/transport_project/app/test/document_workspace_test.dart: Issuance waits for commit and ambiguous retry preserves UUID and reason
00:51 +20: D:/portfolio/transport_project/app/test/document_workspace_test.dart: Reprint view displays original snapshot and supersession without joins
00:54 +21: D:/portfolio/transport_project/app/test/expense_model_test.dart: Owner personally pays cost without an entitlement allocation
00:54 +22: D:/portfolio/transport_project/app/test/expense_model_test.dart: Broker advance requires separately agreed exact owner offset
00:54 +23: D:/portfolio/transport_project/app/test/expense_model_test.dart: Held spending validates both cash and noncash amounts independently
00:54 +24: D:/portfolio/transport_project/app/test/expense_model_test.dart: Different cost bearer and draft have separate recovery without owner netting
00:54 +25: D:/portfolio/transport_project/app/test/expense_model_test.dart: Exact validation rejects extra decimals and self funding mismatch
00:54 +26: D:/portfolio/transport_project/app/test/expense_model_test.dart: Expense above available entitlement only consumes its available claim
00:57 +27: D:/portfolio/transport_project/app/test/expense_workspace_test.dart: Lost posting retry keeps UUID; upload failure retries only receipt
00:58 +28: D:/portfolio/transport_project/app/test/expense_workspace_test.dart: Lost posting retry keeps UUID; upload failure retries only receipt
00:59 +29: D:/portfolio/transport_project/app/test/expense_workspace_test.dart: Lost posting retry keeps UUID; upload failure retries only receipt
00:59 +30: D:/portfolio/transport_project/app/test/expense_workspace_test.dart: Lost posting retry keeps UUID; upload failure retries only receipt
01:00 +31: D:/portfolio/transport_project/app/test/expense_workspace_test.dart: Lost posting retry keeps UUID; upload failure retries only receipt
01:04 +32: D:/portfolio/transport_project/app/test/expense_workspace_test.dart: Lost posting retry keeps UUID; upload failure retries only receipt
01:04 +33: D:/portfolio/transport_project/app/test/expense_workspace_test.dart: Lost posting retry keeps UUID; upload failure retries only receipt
01:04 +34: D:/portfolio/transport_project/app/test/expense_workspace_test.dart: Lost posting retry keeps UUID; upload failure retries only receipt
01:04 +35: D:/portfolio/transport_project/app/test/expense_workspace_test.dart: Lost posting retry keeps UUID; upload failure retries only receipt
01:04 +36: D:/portfolio/transport_project/app/test/expense_workspace_test.dart: Lost posting retry keeps UUID; upload failure retries only receipt
01:04 +37: D:/portfolio/transport_project/app/test/expense_workspace_test.dart: Lost posting retry keeps UUID; upload failure retries only receipt
01:04 +38: D:/portfolio/transport_project/app/test/expense_workspace_test.dart: Lost posting retry keeps UUID; upload failure retries only receipt
01:05 +39: D:/portfolio/transport_project/app/test/expense_workspace_test.dart: Revoked office hides expense editor and an already open selector
01:06 +40: D:/portfolio/transport_project/app/test/installed_config_test.dart: installed public configuration validates production contract
01:07 +41: D:/portfolio/transport_project/app/test/installed_config_test.dart: installed file loads without rewrites and fails closed when corrupt
01:07 +42: D:/portfolio/transport_project/app/test/installed_config_test.dart: non-Windows and development configurations keep their explicit source
01:08 +43: D:/portfolio/transport_project/app/test/masters_test.dart: master workspace and party picker load asynchronously
01:11 +44: D:/portfolio/transport_project/app/test/masters_test.dart: master workspace and party picker load asynchronously
01:11 +45: D:/portfolio/transport_project/app/test/masters_test.dart: master workspace and party picker load asynchronously
01:11 +46: D:/portfolio/transport_project/app/test/masters_test.dart: master workspace and party picker load asynchronously
01:11 +47: D:/portfolio/transport_project/app/test/masters_test.dart: master workspace and party picker load asynchronously
01:12 +48: D:/portfolio/transport_project/app/test/output_export_test.dart: Generate actual compact, hidden-column and wide multi-page files for independent inspection
01:12 +49: D:/portfolio/transport_project/app/test/masters_test.dart: route fare is exact, optional and rejects extra decimals
01:12 +50: D:/portfolio/transport_project/app/test/masters_test.dart: one party has multiple roles without privileged or history fields
01:12 +51: D:/portfolio/transport_project/app/test/masters_test.dart: failed save retains fields and retry ID; changed input gets a new ID
01:13 +52: D:/portfolio/transport_project/app/test/masters_test.dart: version conflict retains edit and prevents silent overwrite
01:16 +53: D:/portfolio/transport_project/app/test/output_file_actions_test.dart: Issued exports re-read authority and reject changed snapshots or digests
01:16 +54: D:/portfolio/transport_project/app/test/output_file_actions_test.dart: Revoked access never reaches a file destination
01:17 +55: D:/portfolio/transport_project/app/test/output_file_actions_test.dart: Revoked access never reaches a file destination
01:19 +56: D:/portfolio/transport_project/app/test/output_workspace_test.dart: Desktop configuration and preview remain visible together
01:21 +57: D:/portfolio/transport_project/app/test/output_workspace_test.dart: Desktop configuration and preview remain visible together
01:23 +58: D:/portfolio/transport_project/app/test/output_file_actions_test.dart: File success waits for destination confirmation: false
01:23 +59: D:/portfolio/transport_project/app/test/output_workspace_test.dart: Hidden expense column preserves filters and canonical preview total
01:26 +60: D:/portfolio/transport_project/app/test/payment_model_test.dart: cash and identified credit exactly equal payment
01:26 +61: D:/portfolio/transport_project/app/test/output_workspace_test.dart: Preset ambiguous retry keeps UUID and body until committed
01:26 +62: D:/portfolio/transport_project/app/test/output_workspace_test.dart: Preset ambiguous retry keeps UUID and body until committed
01:26 +63: D:/portfolio/transport_project/app/test/output_workspace_test.dart: Preset ambiguous retry keeps UUID and body until committed
01:26 +64: D:/portfolio/transport_project/app/test/output_workspace_test.dart: Preset ambiguous retry keeps UUID and body until committed
01:28 +65: D:/portfolio/transport_project/app/test/output_workspace_test.dart: Current scope guard removes output preview and open preset form
01:29 +66: D:/portfolio/transport_project/app/test/payment_workspace_test.dart: revoked scope hides payment form and its open party picker
01:33 +67: D:/portfolio/transport_project/app/test/report_workspace_test.dart: Scoped report pagination retains filters and distinct server totals
01:37 +68: D:/portfolio/transport_project/app/test/payment_workspace_test.dart: await commit, preserve ambiguous request and require conflict review
01:38 +69: D:/portfolio/transport_project/app/test/payment_workspace_test.dart: await commit, preserve ambiguous request and require conflict review
01:41 +70: D:/portfolio/transport_project/app/test/trip_draft_test.dart: saved inherited car stops follow subsequent consignment edits
01:41 +71: D:/portfolio/transport_project/app/test/trip_draft_test.dart: AT-08 independent customers aggregate exact potential amounts
01:41 +72: D:/portfolio/transport_project/app/test/trip_draft_test.dart: aggregate preview does not overflow per-consignment money bound
01:41 +73: D:/portfolio/transport_project/app/test/trip_draft_test.dart: count includes cars with optional identifiers and rejects duplicates/excess
01:41 +74: D:/portfolio/transport_project/app/test/trip_draft_test.dart: wrong-kind, foreign and reordered stop links require correction
01:41 +75: D:/portfolio/transport_project/app/test/trip_draft_test.dart: draft edits require reason, valid business date and loaded contents
01:41 +76: D:/portfolio/transport_project/app/test/trip_draft_test.dart: AT-09 linked return reverses offices, preserves vehicle, starts empty
01:42 +77: D:/portfolio/transport_project/app/test/trip_lifecycle_test.dart: actual dates and corrections enforce chronological business dates
01:43 +78: D:/portfolio/transport_project/app/test/trip_lifecycle_test.dart: operational payload contains no financial commands or editable prices
01:43 +79: D:/portfolio/transport_project/app/test/trip_lifecycle_test.dart: pending transaction does not show success or accept duplicate clicks
01:46 +80: D:/portfolio/transport_project/app/test/trip_workspace_test.dart: scope change hides an already opened draft editor
01:47 +81: D:/portfolio/transport_project/app/test/trip_lifecycle_test.dart: lost response retry preserves UUID and payload; changed input gets new UUID
01:47 +82: D:/portfolio/transport_project/app/test/trip_workspace_test.dart: office trip workspace loads without asynchronous setState return
01:47 +83: D:/portfolio/transport_project/app/test/trip_lifecycle_test.dart: concurrent-edit conflict preserves input and requires closing to reload
01:48 +84: D:/portfolio/transport_project/app/test/trip_workspace_test.dart: lost save response retains request, prices and exact overlap ticket
01:49 +85: D:/portfolio/transport_project/app/test/trip_workspace_test.dart: lost save response retains request, prices and exact overlap ticket
01:50 +86: D:/portfolio/transport_project/app/test/trip_workspace_test.dart: version conflict keeps entries and disables overwrite until reopening
01:53 +87: D:/portfolio/transport_project/app/test/web_config_test.dart: web startup uses compiled public configuration without native I/O
01:54 +88: D:/portfolio/transport_project/app/test/web_money_test.dart: AT-17 web preserves adjacent paisa above JavaScript safe integers
01:54 +89: D:/portfolio/transport_project/app/test/web_money_test.dart: AT-17 full numeric range keeps exact sums and rejects overflow
02:19 +90: D:/portfolio/transport_project/app/test/widget_test.dart: application harness loads the setup route
02:21 +91: All tests passed!

```
