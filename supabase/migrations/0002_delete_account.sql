-- In-app account deletion (App Store guideline 5.1.1(v)).
-- Deleting the auth user cascades to the profile and from there to every row that references it:
-- food, workouts, weights, custom foods, diet plans, care links and recommendations.

create function delete_my_account() returns void
language plpgsql security definer set search_path = public as $$
begin
  if auth.uid() is null then
    raise exception 'Not signed in';
  end if;
  delete from auth.users where id = auth.uid();
end $$;

revoke execute on function delete_my_account() from public, anon;
grant execute on function delete_my_account() to authenticated;
