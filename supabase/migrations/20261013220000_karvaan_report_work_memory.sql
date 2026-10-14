-- Captured plan spills 1735 read/2459 written 8KB temporary blocks per report.
-- Bounded per-function budget, not a global setting, timeout increase or paid upgrade.
-- Five measured users; hosted memory/concurrency limits still need separate validation.
begin;
grant carrier_security to postgres;
ALTER FUNCTION private.report_facts(jsonb,boolean) SET work_mem TO '8MB';
revoke carrier_security from postgres;
commit;
