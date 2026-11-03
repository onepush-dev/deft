// Railway bootstrap helper for Deft. Usage:
//   node db-state.mjs state  -> prints fresh | ready | partial | existing
//   node db-state.mjs mark   -> records that this wrapper's first-boot init finished
//   node db-state.mjs reset  -> drops the public schema (only allowed when state = partial)
// The marker lives in its own schema (railway_bootstrap), outside Deft's public schema.
import { createRequire } from 'node:module'
const require = createRequire('/app/packages/db/package.json')
const pg = require('pg')
const c = new pg.Client({ connectionString: process.env.DATABASE_URL })
const q = async (sql) => (await c.query(sql)).rows
async function state() {
  const [{ n }] = await q("SELECT count(*)::int AS n FROM information_schema.tables WHERE table_schema='public' AND table_type='BASE TABLE'")
  if (n === 0) return 'fresh'
  const [{ m }] = await q("SELECT to_regclass('railway_bootstrap.init_done') IS NOT NULL AS m")
  if (m) return 'ready'
  const [{ u }] = await q("SELECT to_regclass('public.users') IS NOT NULL AS u")
  const users = u ? (await q('SELECT count(*)::int AS k FROM public.users WHERE NOT is_agent'))[0].k : 0
  // No human accounts were ever created: an earlier first boot stopped mid-init (e.g. Postgres restarted).
  return users === 0 ? 'partial' : 'existing'
}
await c.connect()
try {
  const cmd = process.argv[2]
  if (cmd === 'state') console.log(await state())
  else if (cmd === 'mark') await q('CREATE SCHEMA IF NOT EXISTS railway_bootstrap; CREATE TABLE IF NOT EXISTS railway_bootstrap.init_done (done_at timestamptz NOT NULL DEFAULT now()); INSERT INTO railway_bootstrap.init_done DEFAULT VALUES')
  else if (cmd === 'reset') {
    if ((await state()) !== 'partial') throw new Error('refusing reset: database is not a partial, account-less first-boot init')
    await q('DROP SCHEMA public CASCADE; CREATE SCHEMA public; GRANT ALL ON SCHEMA public TO public')
  } else throw new Error(`unknown command ${cmd}`)
} catch (e) { console.error(`[railway] db-state: ${e.message}`); process.exitCode = 1 } finally { await c.end() }
