-- Doctors start unverified. Until an administrator checks their license and sets verified_at
-- (supabase/admin/verify_doctor.sql), they can't request patients, and clearing verified_at
-- cuts off a doctor's access to the patients they already have.

alter table profiles add column verified_at timestamptz;

-- Every doctor account before this migration was made by us for the demo and testing.
update profiles set verified_at = now() where role = 'doctor';

-- Signed-in users can't verify themselves, and a changed license number has to be checked again.
-- Security-definer functions and the SQL editor run as the table owner and skip this.
create function guard_verification() returns trigger
language plpgsql set search_path = public as $$
begin
  if current_user in ('authenticated', 'anon') then
    if tg_op = 'INSERT' then
      new.verified_at := null;
    elsif new.verified_at is distinct from old.verified_at then
      raise exception 'Only an administrator can change verification';
    elsif new.license_number is distinct from old.license_number then
      new.verified_at := null;
    end if;
  end if;
  return new;
end $$;

create trigger profiles_guard_verification before insert or update on profiles
  for each row execute function guard_verification();

create or replace function is_doctor_of(p uuid) returns boolean
language sql stable security definer set search_path = public as $$
  select exists (select 1 from care_links l join profiles d on d.id = l.doctor_id
                 where l.doctor_id = auth.uid() and l.patient_id = p and l.status = 'accepted'
                   and d.verified_at is not null) $$;

create or replace function request_patient(patient_email text) returns care_links
language plpgsql security definer set search_path = public as $$
#variable_conflict use_column
declare
  pid uuid;
  link care_links;
begin
  if not exists (select 1 from profiles where id = auth.uid() and role = 'doctor') then
    raise exception 'Only doctors can send requests';
  end if;
  if not exists (select 1 from profiles where id = auth.uid() and verified_at is not null) then
    raise exception 'Your account is waiting for license verification';
  end if;
  select p.id into pid from profiles p join auth.users u on u.id = p.id
   where lower(u.email) = lower(trim(request_patient.patient_email)) and p.role = 'patient';
  if pid is null then raise exception 'No patient with that email'; end if;

  -- an accepted link is left alone; declined/revoked/pending are reset to pending
  insert into care_links (doctor_id, patient_id, patient_email, status)
  values (auth.uid(), pid, trim(request_patient.patient_email), 'pending')
  on conflict (doctor_id, patient_id) do update
    set status = 'pending', responded_at = null, patient_email = excluded.patient_email
    where care_links.status <> 'accepted';

  select * into link from care_links where doctor_id = auth.uid() and patient_id = pid;
  return link;
end $$;

revoke execute on function guard_verification() from public, anon;
