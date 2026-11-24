import { test } from 'node:test';
import assert from 'node:assert/strict';
import { readFileSync } from 'node:fs';
import { PGlite } from '@electric-sql/pglite';
import { pgcrypto } from '@electric-sql/pglite/contrib/pgcrypto';

const sql = (f) => readFileSync(new URL(f, import.meta.url), 'utf8');
const MIGRATIONS = ['0002_delete_account', '0003_keep_plans_when_author_deleted', '0004_doctor_verification', '0005_ai_scan_quota', '0006_vitals_fluids_notes'];

test('schema, RLS and functions', async () => {
  const db = new PGlite({ extensions: { pgcrypto } });
  await db.exec(sql('./auth_stub.sql'));
  await db.exec(sql('../migrations/0001_init.sql'));
  await db.exec(sql('../migrations/0002_delete_account.sql'));
  await db.exec(sql('../migrations/0003_keep_plans_when_author_deleted.sql'));
  await db.exec(sql('../migrations/0004_doctor_verification.sql'));
  await db.exec(sql('./rls_check.sql'));
});

test('delete_my_account removes the caller and everything they own, and nobody else', async () => {
  const db = new PGlite({ extensions: { pgcrypto } });
  await db.exec(sql('./auth_stub.sql'));
  await db.exec(sql('../migrations/0001_init.sql'));
  await db.exec(sql('../migrations/0002_delete_account.sql'));
  await db.exec(sql('../migrations/0003_keep_plans_when_author_deleted.sql'));
  await db.exec(sql('../migrations/0004_doctor_verification.sql'));
  const gone = "'a0000000-0000-4000-8000-00000000000a'";
  const kept = "'b0000000-0000-4000-8000-00000000000b'";
  await db.exec(`insert into auth.users (id, email, raw_user_meta_data) values
    (${gone}, 'gone@example.com', '{"role":"patient","full_name":"Gone"}'),
    (${kept}, 'kept@example.com', '{"role":"patient","full_name":"Kept"}')`);
  await db.exec(`insert into food_logs (user_id, logged_at, meal, name, serving_desc, kcal, source) values
    (${gone}, now(), 'lunch', 'Apple', '1 medium', 95, 'manual'),
    (${kept}, now(), 'lunch', 'Pear', '1 medium', 100, 'manual')`);
  const one = async (q) => Object.values((await db.query(q)).rows[0])[0];
  const as = (uid) => `set role authenticated; select set_config('request.jwt.claims', json_build_object('sub', ${uid}, 'role', 'authenticated')::text, false);`;

  await db.exec(`set role anon; select set_config('request.jwt.claims', '', false);`);
  await assert.rejects(db.exec(`select delete_my_account()`), 'anon must not be able to call it');
  await db.exec(`reset role`);

  await db.exec(as(gone));
  await db.exec(`select delete_my_account()`);
  await db.exec(`reset role`);
  assert.equal(Number(await one(`select count(*) from auth.users where id = ${gone}`)), 0);
  assert.equal(Number(await one(`select count(*) from profiles where id = ${gone}`)), 0);
  assert.equal(Number(await one(`select count(*) from food_logs where user_id = ${gone}`)), 0);
  assert.equal(Number(await one(`select count(*) from profiles where id = ${kept}`)), 1);
  assert.equal(Number(await one(`select count(*) from food_logs where user_id = ${kept}`)), 1);
});

test('a doctor deleting their account leaves the plans they wrote with the patient', async () => {
  const db = new PGlite({ extensions: { pgcrypto } });
  await db.exec(sql('./auth_stub.sql'));
  await db.exec(sql('../migrations/0001_init.sql'));
  await db.exec(sql('../migrations/0002_delete_account.sql'));
  await db.exec(sql('../migrations/0003_keep_plans_when_author_deleted.sql'));
  await db.exec(sql('../migrations/0004_doctor_verification.sql'));
  const doc = "'d0000000-0000-4000-8000-00000000000d'";
  const pat = "'e0000000-0000-4000-8000-00000000000e'";
  await db.exec(`insert into auth.users (id, email, raw_user_meta_data) values
    (${doc}, 'doc@example.com', '{"role":"doctor","full_name":"Doc"}'),
    (${pat}, 'pat@example.com', '{"role":"patient","full_name":"Pat"}')`);
  await db.exec(`insert into diet_plans (user_id, author_id, name, is_active) values (${pat}, ${doc}, 'Low sodium', true)`);
  const one = async (q) => Object.values((await db.query(q)).rows[0])[0];

  await db.exec(`set role authenticated; select set_config('request.jwt.claims', json_build_object('sub', ${doc}, 'role', 'authenticated')::text, false);`);
  await db.exec(`select delete_my_account()`);
  await db.exec(`reset role`);
  assert.equal(Number(await one(`select count(*) from profiles where id = ${doc}`)), 0);
  assert.equal(Number(await one(`select count(*) from diet_plans where user_id = ${pat} and author_id is null`)), 1);
});

test('demo seed', async () => {
  const db = new PGlite({ extensions: { pgcrypto } });
  await db.exec(sql('./auth_stub.sql'));
  await db.exec(sql('../migrations/0001_init.sql'));
  for (const m of MIGRATIONS) {
    await db.exec(sql('../migrations/' + m + '.sql'));
  }
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
  assert.equal(await one(`select verified_at is not null from profiles where email = 'doctor@nutravision.demo'`), true);

  // demo_refresh.sql brings stale demo data up to today and leaves other accounts alone.
  await db.exec(`update food_logs set logged_at = logged_at - interval '5 days';
    update workouts set started_at = started_at - interval '5 days';
    update weight_logs set measured_at = measured_at - interval '5 days'`);
  await db.exec(sql('../demo_refresh.sql'));
  const demoMax = `select max(logged_at)::date = current_date from food_logs f join profiles p on p.id = f.user_id where p.email like '%@nutravision.demo'`;
  assert.equal(await one(demoMax), true, 'demo food logs reach today');
  assert.equal(Number(await one(`select count(distinct (logged_at at time zone 'UTC')::date) from food_logs f join profiles p on p.id = f.user_id where p.email = 'maria@nutravision.demo'`)), 30);
  await db.exec(sql('../demo_refresh.sql'));  // re-running is a no-op
  assert.equal(await one(demoMax), true);
  const ex = "'e0000000-0000-4000-8000-000000000001'";
  for (const [tbl, col] of [['food_logs', 'user_id'], ['workouts', 'user_id'], ['weight_logs', 'user_id'], ['care_links', 'patient_id'], ['auth.identities', 'user_id']]) {
    assert.equal(Number(await one(`select count(*) from ${tbl} where ${col} = ${ex}`)), 0, tbl);
  }
});

test('doctors need verification before they reach patients', async () => {
  const db = new PGlite({ extensions: { pgcrypto } });
  await db.exec(sql('./auth_stub.sql'));
  await db.exec(sql('../migrations/0001_init.sql'));
  const old = "'c0000000-0000-4000-8000-00000000000c'";
  await db.exec(`insert into auth.users (id, email, raw_user_meta_data) values
    (${old}, 'old@example.com', '{"role":"doctor","full_name":"Old"}')`);
  for (const m of MIGRATIONS) {
    await db.exec(sql('../migrations/' + m + '.sql'));
  }
  const doc = "'d0000000-0000-4000-8000-00000000000d'";
  const pat = "'e0000000-0000-4000-8000-00000000000e'";
  await db.exec(`insert into auth.users (id, email, raw_user_meta_data) values
    (${doc}, 'doc@example.com', '{"role":"doctor","full_name":"Doc"}'),
    (${pat}, 'pat@example.com', '{"role":"patient","full_name":"Pat"}')`);
  const one = async (q) => Object.values((await db.query(q)).rows[0])[0];
  const as = (uid) => `set role authenticated; select set_config('request.jwt.claims', json_build_object('sub', ${uid}, 'role', 'authenticated')::text, false);`;

  assert.equal(await one(`select verified_at is not null from profiles where id = ${old}`), true, 'existing doctors are grandfathered');
  assert.equal(await one(`select verified_at is null from profiles where id = ${doc}`), true, 'new doctors start unverified');

  // An unverified doctor can't request patients or verify themselves.
  await db.exec(as(doc));
  await assert.rejects(db.exec(`select request_patient('pat@example.com')`), /waiting for license verification/);
  await assert.rejects(db.exec(`update profiles set verified_at = now() where id = ${doc}`), /administrator/);
  await db.exec(`update profiles set specialty = 'Cardiology' where id = ${doc}`);  // other edits still work
  await db.exec('reset role');

  // Verified by an administrator: request, the patient accepts, the doctor sees the patient.
  await db.exec(`update profiles set verified_at = now() where id = ${doc}`);
  await db.exec(as(doc));
  await db.exec(`select request_patient('pat@example.com')`);
  await db.exec(as(pat));
  await db.exec(`select respond_care_link((select id from care_links where patient_id = ${pat}), true)`);
  await db.exec(as(doc));
  assert.equal(Number(await one(`select count(*) from profiles where id = ${pat}`)), 1);

  // A new license number has to be checked again, and until then the patient is hidden.
  await db.exec(`update profiles set license_number = 'NEW-1' where id = ${doc}`);
  assert.equal(await one(`select verified_at is null from profiles where id = ${doc}`), true);
  assert.equal(Number(await one(`select count(*) from profiles where id = ${pat}`)), 0);
  await db.exec('reset role');
});

test('claim_ai_scan counts scans per user per day and stops at the limit', async () => {
  const db = new PGlite({ extensions: { pgcrypto } });
  await db.exec(sql('./auth_stub.sql'));
  await db.exec(sql('../migrations/0001_init.sql'));
  for (const m of MIGRATIONS) await db.exec(sql('../migrations/' + m + '.sql'));
  const a = "'a0000000-0000-4000-8000-00000000000a'";
  const b = "'b0000000-0000-4000-8000-00000000000b'";
  await db.exec(`insert into auth.users (id, email, raw_user_meta_data) values
    (${a}, 'a@example.com', '{"role":"patient"}'), (${b}, 'b@example.com', '{"role":"patient"}')`);
  const one = async (q) => Object.values((await db.query(q)).rows[0])[0];
  const as = (uid) => `set role authenticated; select set_config('request.jwt.claims', json_build_object('sub', ${uid}, 'role', 'authenticated')::text, false);`;

  await db.exec(`set role anon; select set_config('request.jwt.claims', '', false);`);
  await assert.rejects(db.exec(`select claim_ai_scan()`), 'anon cannot claim scans');
  await db.exec('reset role');

  await db.exec(as(a));
  assert.equal(Number(await one(`select claim_ai_scan()`)), 59);
  await assert.rejects(db.exec(`select * from ai_scan_usage`), 'the usage table is not readable directly');
  await db.exec('reset role');
  await db.exec(`update ai_scan_usage set scans = 60 where user_id = ${a}`);
  await db.exec(as(a));
  await assert.rejects(db.exec(`select claim_ai_scan()`), /limit reached/);
  await db.exec(as(b));
  assert.equal(Number(await one(`select claim_ai_scan()`)), 59, 'other users are unaffected');
  await db.exec('reset role');
  assert.equal(Number(await one(`select scans from ai_scan_usage where user_id = ${a}`)), 60, 'a refused scan is not counted');
});

test('vitals, fluids and clinical notes: who can read and write what', async () => {
  const db = new PGlite({ extensions: { pgcrypto } });
  await db.exec(sql('./auth_stub.sql'));
  await db.exec(sql('../migrations/0001_init.sql'));
  for (const m of MIGRATIONS) await db.exec(sql('../migrations/' + m + '.sql'));
  const doc = "'d0000000-0000-4000-8000-00000000000d'";
  const other = "'d0000000-0000-4000-8000-0000000000dd'";
  const pat = "'e0000000-0000-4000-8000-00000000000e'";
  const stranger = "'e0000000-0000-4000-8000-0000000000ee'";
  await db.exec(`insert into auth.users (id, email, raw_user_meta_data) values
    (${doc}, 'doc@example.com', '{"role":"doctor"}'), (${other}, 'other@example.com', '{"role":"doctor"}'),
    (${pat}, 'pat@example.com', '{"role":"patient"}'), (${stranger}, 'stranger@example.com', '{"role":"patient"}')`);
  await db.exec(`update profiles set verified_at = now() where role = 'doctor'`);
  const one = async (q) => Object.values((await db.query(q)).rows[0])[0];
  const as = (uid) => `set role authenticated; select set_config('request.jwt.claims', json_build_object('sub', ${uid}, 'role', 'authenticated')::text, false);`;
  const count = async (q) => Number(await one(q));

  // The patient logs readings and fluids, and sets a fluid limit.
  await db.exec(as(pat));
  await db.exec(`insert into vital_logs (user_id, measured_at, kind, systolic, diastolic, pulse) values (${pat}, now(), 'blood_pressure', 152, 96, 70)`);
  await db.exec(`insert into vital_logs (user_id, measured_at, kind, glucose_mg_dl, glucose_context) values (${pat}, now(), 'glucose', 64, 'bedtime')`);
  await db.exec(`insert into fluid_logs (user_id, logged_at, ml) values (${pat}, now(), 250)`);
  await db.exec(`update profiles set fluid_limit_ml = 1500 where id = ${pat}`);
  await assert.rejects(db.exec(`insert into vital_logs (user_id, measured_at, kind, systolic) values (${pat}, now(), 'blood_pressure', 120)`),
    'a blood pressure reading needs both numbers');
  await assert.rejects(db.exec(`insert into vital_logs (user_id, measured_at, kind, glucose_mg_dl, systolic, diastolic) values (${pat}, now(), 'glucose', 100, 120, 80)`),
    'a glucose reading has no blood pressure');
  await assert.rejects(db.exec(`insert into vital_logs (user_id, measured_at, kind, glucose_mg_dl) values (${stranger}, now(), 'glucose', 100)`),
    'nobody logs for someone else');

  // Nobody else sees them until the patient accepts a doctor.
  await db.exec(as(stranger));
  assert.equal(await count(`select count(*) from vital_logs`), 0);
  await db.exec(as(doc));
  assert.equal(await count(`select count(*) from vital_logs`), 0);
  await assert.rejects(db.exec(`insert into clinical_notes (doctor_id, patient_id, body) values (${doc}, ${pat}, 'hi')`),
    'no notes about a patient who does not share with you');
  await db.exec(`select request_patient('pat@example.com')`);
  await db.exec(as(pat));
  await db.exec(`select respond_care_link((select id from care_links where patient_id = ${pat}), true)`);

  // The linked doctor reads vitals and fluids but can't change them, and keeps private notes.
  await db.exec(as(doc));
  assert.equal(await count(`select count(*) from vital_logs`), 2);
  assert.equal(await count(`select count(*) from fluid_logs`), 1);
  await db.exec(`update vital_logs set systolic = 120 where kind = 'blood_pressure'`);
  assert.equal(await count(`select systolic from vital_logs where kind = 'blood_pressure'`), 152, 'doctor cannot edit readings');
  await assert.rejects(db.exec(`insert into vital_logs (user_id, measured_at, kind, glucose_mg_dl) values (${pat}, now(), 'glucose', 100)`));
  await db.exec(`insert into clinical_notes (doctor_id, patient_id, body) values (${doc}, ${pat}, 'Discussed evening snacks.')`);
  await assert.rejects(db.exec(`insert into clinical_notes (doctor_id, patient_id, body) values (${other}, ${pat}, 'forged')`));
  await assert.rejects(db.exec(`update clinical_notes set body = 'edited'`), 'notes are append-only');
  assert.equal(await count(`select count(*) from clinical_notes`), 1);

  // The patient and other doctors can't read the notes.
  await db.exec(as(pat));
  assert.equal(await count(`select count(*) from clinical_notes`), 0);
  await db.exec(as(other));
  assert.equal(await count(`select count(*) from clinical_notes`), 0);
  assert.equal(await count(`select count(*) from vital_logs`), 0);

  // Revoking hides the readings and the notes from the doctor.
  await db.exec(as(pat));
  await db.exec(`update care_links set status = 'revoked' where patient_id = ${pat}`);
  await db.exec(as(doc));
  assert.equal(await count(`select count(*) from vital_logs`), 0);
  assert.equal(await count(`select count(*) from clinical_notes`), 0);

  // Deleting the account takes all of it.
  await db.exec(as(pat));
  await db.exec(`select delete_my_account()`);
  await db.exec('reset role');
  assert.equal(await count(`select count(*) from vital_logs`), 0);
  assert.equal(await count(`select count(*) from fluid_logs`), 0);
  assert.equal(await count(`select count(*) from clinical_notes`), 0);
});

test('demo vitals load once and move forward with demo_refresh', async () => {
  const db = new PGlite({ extensions: { pgcrypto } });
  await db.exec(sql('./auth_stub.sql'));
  await db.exec(sql('../migrations/0001_init.sql'));
  for (const m of MIGRATIONS) await db.exec(sql('../migrations/' + m + '.sql'));
  await db.exec(sql('../seed.sql'));
  await db.exec(sql('../demo_vitals.sql'));
  await db.exec(sql('../demo_vitals.sql'));  // second run is a no-op
  const one = async (q) => Object.values((await db.query(q)).rows[0])[0];
  assert.equal(Number(await one(`select count(*) from vital_logs where kind = 'blood_pressure'`)), 30);
  assert.equal(Number(await one(`select count(*) from vital_logs where kind = 'glucose'`)), 30 + 10 + 1);
  assert.equal(Number(await one(`select count(*) from vital_logs where kind = 'glucose' and glucose_mg_dl < 70`)), 1);
  assert.ok(Number(await one(`select count(*) from vital_logs where systolic >= 140`)) >= 2);
  assert.equal(Number(await one(`select count(*) from fluid_logs`)), 13 * 4);
  await db.exec(`update food_logs set logged_at = logged_at - interval '3 days';
    update vital_logs set measured_at = measured_at - interval '3 days'`);
  await db.exec(sql('../demo_refresh.sql'));
  assert.equal(await one(`select max(measured_at)::date = current_date from vital_logs where kind = 'blood_pressure'`), true, 'readings reach today with the diary');
});
