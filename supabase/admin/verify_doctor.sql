-- Run in the Supabase SQL editor (it runs as the table owner, so the verification guard allows it).

-- 1. Doctors waiting for verification. Check each license number with the issuing medical board.
select id, full_name, email, specialty, license_number, created_at
  from profiles where role = 'doctor' and verified_at is null order by created_at;

-- 2. Verify one (replace the email):
-- update profiles set verified_at = now() where role = 'doctor' and email = lower('doctor@example.com');

-- To withdraw verification, which also hides that doctor's patients from them:
-- update profiles set verified_at = null where role = 'doctor' and email = lower('doctor@example.com');
