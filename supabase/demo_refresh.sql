-- Moves the demo accounts' history forward so its most recent day is today. The seed covers the
-- 30 days before it ran, so after a while the demo opens on an empty "today".
-- Run it in the SQL editor whenever the demo looks stale. Safe to re-run; it only touches
-- @nutravision.demo accounts and does nothing if their data already reaches today.
do $$
declare
  demo uuid[] := array(select id from profiles where email like '%@nutravision.demo');
  shift int;
begin
  select current_date - max(logged_at)::date into shift from food_logs where user_id = any(demo);
  if shift is null or shift <= 0 then
    raise notice 'Demo data is already up to date';
    return;
  end if;
  update food_logs set logged_at = logged_at + make_interval(days => shift) where user_id = any(demo);
  update workouts set started_at = started_at + make_interval(days => shift) where user_id = any(demo);
  update weight_logs set measured_at = measured_at + make_interval(days => shift) where user_id = any(demo);
  raise notice 'Moved demo data forward % days', shift;
end $$;
