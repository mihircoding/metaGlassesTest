import { test } from 'node:test';
import assert from 'node:assert/strict';
import { readFileSync } from 'node:fs';
import { PGlite } from '@electric-sql/pglite';
import { pgcrypto } from '@electric-sql/pglite/contrib/pgcrypto';

const sql = (f) => readFileSync(new URL(f, import.meta.url), 'utf8');

test('schema, RLS and functions', async () => {
  const db = new PGlite({ extensions: { pgcrypto } });
  await db.exec(sql('./auth_stub.sql'));
  await db.exec(sql('../migrations/0001_init.sql'));
  await db.exec(sql('./rls_check.sql'));
});

test('demo seed', async () => {
  const db = new PGlite({ extensions: { pgcrypto } });
  await db.exec(sql('./auth_stub.sql'));
  await db.exec(sql('../migrations/0001_init.sql'));
  await db.exec(`insert into auth.users (id, email, raw_user_meta_data)
    values ('e0000000-0000-4000-8000-000000000001', 'existing@example.com', '{"role":"patient","full_name":"Existing"}')`);
  await db.exec(sql('../seed.sql'));
  const one = async (q) => Object.values((await db.query(q)).rows[0])[0];
  assert.equal(Number(await one(`select count(*) from profiles`)), 5);
  assert.equal(Number(await one(`select count(*) from care_links where status = 'accepted'`)), 3);
  for (const email of ['maria@nutravision.demo', 'james@nutravision.demo', 'alex@nutravision.demo']) {
    const days = await one(`select count(distinct (logged_at at time zone 'UTC')::date) from food_logs f join profiles p on p.id = f.user_id where p.email = '${email}'`);
    assert.equal(Number(days), 30, email);
  }
  assert.ok(Number(await one(`select count(*) from workouts`)) >= 30);
  assert.ok(Number(await one(`select count(*) from weight_logs`)) >= 12);
  assert.equal(Number(await one(`select count(*) from recommendations where status = 'pending'`)), 1);
  const saltyDays = Number(await one(`select count(*) from (select sum(f.sodium_mg * f.servings) s from food_logs f join profiles p on p.id = f.user_id
    where p.email = 'james@nutravision.demo' and logged_at > now() - interval '7 days' group by (logged_at at time zone 'UTC')::date) d where s > 1500`));
  assert.ok(saltyDays >= 2 && saltyDays <= 5, `salty days ${saltyDays}`);
  assert.equal(Number(await one(`select count(*) from auth.identities`)), 4);
  const ex = "'e0000000-0000-4000-8000-000000000001'";
  for (const [tbl, col] of [['food_logs', 'user_id'], ['workouts', 'user_id'], ['weight_logs', 'user_id'], ['care_links', 'patient_id'], ['auth.identities', 'user_id']]) {
    assert.equal(Number(await one(`select count(*) from ${tbl} where ${col} = ${ex}`)), 0, tbl);
  }
});
