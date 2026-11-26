-- A daily cap on AI photo scans per user. Each scan costs a model call, and the anon key ships in the
-- app, so without this anyone could run up the bill. analyze-food calls claim_ai_scan() with the
-- caller's own token before it calls the model.

create table ai_scan_usage (
  user_id uuid not null references profiles on delete cascade,
  day date not null default current_date,
  scans integer not null default 0,
  primary key (user_id, day)
);
alter table ai_scan_usage enable row level security;  -- no policies: only claim_ai_scan() touches it
revoke all on ai_scan_usage from anon, authenticated;

-- Counts one scan and returns how many are left today. PT401/PT429 become HTTP 401/429 in PostgREST.
create function claim_ai_scan() returns integer
language plpgsql security definer set search_path = public as $$
declare
  daily_limit constant integer := 60;
  used integer;
begin
  if auth.uid() is null then
    raise sqlstate 'PT401' using message = 'Not signed in';
  end if;
  insert into ai_scan_usage (user_id, day, scans) values (auth.uid(), current_date, 1)
  on conflict (user_id, day) do update set scans = ai_scan_usage.scans + 1
  returning scans into used;
  if used > daily_limit then
    raise sqlstate 'PT429' using message = 'Daily AI scan limit reached';
  end if;
  return daily_limit - used;
end $$;

revoke execute on function claim_ai_scan() from public, anon;
grant execute on function claim_ai_scan() to authenticated;
