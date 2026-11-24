-- A diet plan belongs to the patient it was written for. When its author (a doctor) deletes their
-- account, keep the plan and forget the author instead of deleting the patient's plan with them.

alter table diet_plans alter column author_id drop not null;
alter table diet_plans drop constraint diet_plans_author_id_fkey;
alter table diet_plans add constraint diet_plans_author_id_fkey
  foreign key (author_id) references profiles on delete set null;
