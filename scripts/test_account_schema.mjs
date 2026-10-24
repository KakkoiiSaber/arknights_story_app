import assert from 'node:assert/strict';
import { readFile, readdir } from 'node:fs/promises';
import { PGlite } from '@electric-sql/pglite';

const db = new PGlite();
const a = '11111111-1111-1111-1111-111111111111';
const b = '22222222-2222-2222-2222-222222222222';
try {
  await db.exec(`create role anon; create role authenticated;
    create schema auth;
    create table auth.users(id uuid primary key);
    insert into auth.users values ('${a}'), ('${b}');
    create function auth.uid() returns uuid language sql as
      'select nullif(current_setting(''request.jwt.claim.sub'', true), '''')::uuid';
    grant usage on schema public, auth to anon, authenticated;
    grant execute on function auth.uid() to anon, authenticated;`);
  for (const name of (await readdir('supabase/migrations')).filter(n => n.endsWith('.sql')).sort()) {
    await db.exec(await readFile(`supabase/migrations/${name}`, 'utf8'));
  }
  async function login(user, role = 'authenticated') {
    await db.exec(`reset role; set role ${role}; set request.jwt.claim.sub = '${user}';`);
  }
  async function sync(mutations) {
    return (await db.query('select public.sync_reading_records($1::jsonb) as result',
      [JSON.stringify(mutations)])).rows[0].result;
  }
  const setting = (value, rev) => ({kind: 'setting', key: 'doctorName', value: {value}, base_revision: rev});
  await login(a);
  let rows = await sync([setting('A', 0)]);
  assert.equal(rows[0].revision, 1); assert.equal(rows[0].conflict, false);
  rows = await sync([setting('stale', 0)]);
  assert.equal(rows[0].conflict, true); assert.equal(rows[0].value.value, 'A');
  rows = await sync([setting('B', 1)]);
  assert.equal(rows[0].revision, 2);
  rows = await sync([setting('old-device', 1)]);
  assert.equal(rows[0].value.value, 'B'); assert.equal(rows[0].conflict, true);
  await sync([{kind:'chapter', key:'obt/test', value:{completed:true}, base_revision:0},
    {kind:'resume', key:'main_0', value:{chapterId:'obt/test'}, base_revision:0}]);
  await login(b);
  for (const table of ['user_settings', 'chapter_progress', 'reading_resume']) {
    assert.equal((await db.query(`select * from public.${table}`)).rows.length, 0, `RLS on ${table}`);
  }
  await assert.rejects(db.query('insert into public.user_settings(user_id, setting_key, value) values ($1,$2,$3)',
    [a,'fontScale','{"value":1}']), /row-level security/);
  rows = await sync([setting('user-B',0)]);
  assert.equal(rows[0].value.value, 'user-B');
  await login(a);
  assert.equal((await db.query('select * from public.user_settings')).rows[0].value.value, 'B');
  assert.equal((await db.query('update public.user_settings set user_id=$1 where user_id=$2 returning *',[b,a])
    .then(() => false).catch(() => true)), true, 'Ownership cannot be reassigned');
  await assert.rejects(sync([{...setting('bad',2),kind:'arbitrary_table'}]), /Invalid record kind/);
  await login('', 'anon');
  await assert.rejects(sync([setting('anonymous',0)]), /permission denied/);
  console.log('Account schema: migration, revisions, stale writes, all-table RLS and ownership tests passed.');
} finally { await db.close(); }
