-- The portal's database role (PORTAL_SPEC.md § Data). The site is internet-facing; it must not
-- connect as the game's owner role. Read everything, write only its own web_* tables and the two
-- whitelist columns the /whitelist page maintains.
--
--   docker exec -i armapunk-pg psql -U armapunk -d armapunk -v pw=<password> -f - < website/sql/pg/role_web.sql
--
-- Re-runnable: every statement is idempotent or guarded.
-- psql variables are not substituted inside dollar-quoted blocks, so the role statements are
-- built by SELECT format(...) and executed with \gexec (pass the password raw: -v pw=<secret>).
SELECT format('CREATE ROLE armapunk_web LOGIN PASSWORD %L', :'pw')
  WHERE NOT EXISTS (SELECT 1 FROM pg_roles WHERE rolname = 'armapunk_web') \gexec
SELECT format('ALTER ROLE armapunk_web WITH LOGIN PASSWORD %L', :'pw') \gexec

GRANT CONNECT ON DATABASE armapunk TO armapunk_web;
GRANT USAGE ON SCHEMA public TO armapunk_web;
GRANT SELECT ON ALL TABLES IN SCHEMA public TO armapunk_web;
ALTER DEFAULT PRIVILEGES FOR ROLE armapunk IN SCHEMA public GRANT SELECT ON TABLES TO armapunk_web;

-- Site-native tables: full row access + their serial sequences.
DO $$
DECLARE t text;
BEGIN
  FOR t IN SELECT tablename FROM pg_tables WHERE schemaname = 'public' AND tablename LIKE 'web\_%' LOOP
    EXECUTE format('GRANT INSERT, UPDATE, DELETE ON TABLE public.%I TO armapunk_web', t);
  END LOOP;
END $$;
GRANT USAGE, SELECT, UPDATE ON ALL SEQUENCES IN SCHEMA public TO armapunk_web;

-- The in-game faction whitelist the /whitelist page maintains (fn_dutySRV reads coplevel >= 1 /
-- mediclevel >= 1 as eligibility). Nothing else on players_global is writable.
GRANT UPDATE (coplevel, mediclevel) ON public.players_global TO armapunk_web;
