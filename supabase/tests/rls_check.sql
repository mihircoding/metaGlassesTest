begin;
create schema rls_test;   -- rolled back at the end; a real schema so the authenticated role can call the helpers
grant usage on schema rls_test to authenticated;
create function rls_test.ok(cond boolean, label text) returns void language plpgsql as $$
begin if cond is not true then raise exception 'RLS check failed: %', label; end if; end $$;
create function rls_test.as_user(uid uuid) returns void language sql as $$
  select set_config('request.jwt.claims', json_build_object('sub', uid, 'role', 'authenticated')::text, true); $$;

insert into auth.users (id, email, raw_user_meta_data) values
  ('d1000000-0000-4000-8000-000000000001', 'rls-doctor@test.local',   '{"role":"doctor","full_name":"Dr RLS"}'),
  ('d1000000-0000-4000-8000-000000000002', 'rls-doctor2@test.local',  '{"role":"doctor","full_name":"Dr Other"}'),
  ('a1000000-0000-4000-8000-000000000001', 'rls-patient@test.local',  '{"role":"patient","full_name":"Pat RLS"}'),
  ('a1000000-0000-4000-8000-000000000002', 'rls-stranger@test.local', '{"role":"patient","full_name":"Stranger"}');
set local role authenticated;

select rls_test.as_user('a1000000-0000-4000-8000-000000000001');
insert into food_logs (user_id, logged_at, meal, name, serving_desc, kcal, source)
  values (auth.uid(), now(), 'lunch', 'Apple', '1 medium', 95, 'manual');
select rls_test.ok((select count(*) from food_logs) = 1, 'patient sees own log');
do $$ begin
  begin update profiles set role = 'doctor' where id = auth.uid(); exception when others then return; end;
  raise exception 'RLS check failed: role change allowed'; end $$;
do $$ begin
  begin insert into care_links (doctor_id, patient_id, status) values ('d1000000-0000-4000-8000-000000000002', auth.uid(), 'accepted');
  exception when others then return; end;
  raise exception 'RLS check failed: patient inserted a link'; end $$;

select rls_test.as_user('a1000000-0000-4000-8000-000000000002');
select rls_test.ok((select count(*) from food_logs) = 0, 'stranger sees no logs');

select rls_test.as_user('d1000000-0000-4000-8000-000000000001');
select rls_test.ok((select count(*) from food_logs) = 0, 'unlinked doctor sees no logs');
select rls_test.ok((select count(*) from profiles where id = 'a1000000-0000-4000-8000-000000000001') = 0, 'unlinked doctor cannot read profile');
select request_patient('  RLS-Patient@Test.Local ');
select rls_test.ok((select status from care_links where patient_id = 'a1000000-0000-4000-8000-000000000001') = 'pending', 'request is pending');
select rls_test.ok((select count(*) from food_logs) = 0, 'pending link grants nothing');
do $$ begin
  begin perform request_patient('rls-doctor2@test.local'); exception when others then return; end;
  raise exception 'RLS check failed: requested a doctor'; end $$;
do $$ begin
  begin insert into recommendations (doctor_id, patient_id, kind, payload, message)
        values (auth.uid(), 'a1000000-0000-4000-8000-000000000001', 'note', '{}', 'hi');
  exception when others then return; end;
  raise exception 'RLS check failed: recommended without link'; end $$;

select rls_test.as_user('a1000000-0000-4000-8000-000000000001');
select rls_test.ok((select count(*) from profiles where role = 'doctor') = 1, 'patient sees only the requesting doctor');
select respond_care_link((select id from care_links where patient_id = auth.uid()), true);

select rls_test.as_user('d1000000-0000-4000-8000-000000000001');
select rls_test.ok((select count(*) from food_logs) = 1, 'linked doctor reads logs');
update food_logs set kcal = 1;
select rls_test.ok((select kcal from food_logs limit 1) = 95, 'doctor cannot edit logs');
insert into recommendations (doctor_id, patient_id, kind, payload, message) values
  (auth.uid(), 'a1000000-0000-4000-8000-000000000001', 'targets',
   '{"targets":{"kcal_target":1800,"protein_g":110,"carbs_g":180,"fat_g":60,"sat_fat_g":12,"sodium_mg":1500,"fiber_g":30}}', 'Lower sodium'),
  (auth.uid(), 'a1000000-0000-4000-8000-000000000001', 'diet_plan',
   '{"diet_plan":{"name":"DASH week 1","condition_id":"hypertension","notes":"","targets":{"kcal_target":1800,"protein_g":110,"carbs_g":180,"fat_g":60,"sat_fat_g":12,"sodium_mg":1500,"fiber_g":30},"meals":[]}}', 'Try this');

select rls_test.as_user('a1000000-0000-4000-8000-000000000001');
select accept_recommendation((select id from recommendations where kind = 'targets'));
select rls_test.ok((select kcal_target = 1800 and sodium_mg = 1500 and targets_source = 'doctor' from profiles where id = auth.uid()), 'targets applied');
select accept_recommendation((select id from recommendations where kind = 'diet_plan'));
select rls_test.ok((select count(*) from diet_plans where is_active) = 1, 'one active plan');
select rls_test.ok((select author_id from diet_plans where is_active) = 'd1000000-0000-4000-8000-000000000001', 'plan authored by doctor');
update diet_plans set is_active = false where is_active;
select rls_test.ok((select count(*) from diet_plans where is_active) = 0, 'patient can deactivate doctor plan');
update diet_plans set is_active = true where user_id = auth.uid();
select rls_test.ok((select count(*) from diet_plans where is_active) = 1, 'patient can re-activate plan');
do $$ begin
  begin update diet_plans set author_id = auth.uid(); exception when others then return; end;
  raise exception 'RLS check failed: patient changed plan author'; end $$;
do $$ begin
  begin perform accept_recommendation((select id from recommendations where kind = 'targets')); exception when others then return; end;
  raise exception 'RLS check failed: accepted twice'; end $$;
update care_links set status = 'revoked' where patient_id = auth.uid();

select rls_test.as_user('d1000000-0000-4000-8000-000000000001');
select rls_test.ok((select count(*) from food_logs) = 0, 'revoked doctor sees nothing');
select request_patient('rls-patient@test.local');
select rls_test.ok((select status from care_links where patient_id = 'a1000000-0000-4000-8000-000000000001') = 'pending', 're-request resets to pending');
reset role;
rollback;
