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
