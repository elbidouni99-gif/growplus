-- GrowPlus database setup
-- Run once in Supabase SQL Editor for project cnjahjgtfwrgtzyhrxak.
-- Does not modify or delete existing profiles rows.

create extension if not exists pgcrypto;

alter table public.profiles
  add column if not exists display_name text,
  add column if not exists points_balance bigint not null default 0,
  add column if not exists total_earned_points bigint not null default 0,
  add column if not exists updated_at timestamptz not null default now();

create table if not exists public.tasks (
  id uuid primary key default gen_random_uuid(),
  title text not null,
  description text not null default '',
  category text not null default 'community',
  reward_points integer not null default 0 check (reward_points between 0 and 100000),
  instructions text not null default '',
  is_active boolean not null default true,
  created_at timestamptz not null default now()
);

-- Upgrade an existing legacy tasks table (which may use points/active).
alter table public.tasks
  add column if not exists category text not null default 'community',
  add column if not exists reward_points integer not null default 0,
  add column if not exists instructions text not null default '',
  add column if not exists is_active boolean not null default true;

-- Preserve legacy task rewards and activation flags where those columns exist.
do $
begin
  if exists (
    select 1 from information_schema.columns
    where table_schema='public' and table_name='tasks' and column_name='points'
  ) then
    execute 'update public.tasks set reward_points = points where reward_points = 0 and points is not null';
  end if;
  if exists (
    select 1 from information_schema.columns
    where table_schema='public' and table_name='tasks' and column_name='active'
  ) then
    execute 'update public.tasks set is_active = active where active is not null';
  end if;
end $;

create table if not exists public.task_submissions (
  id uuid primary key default gen_random_uuid(),
  user_id uuid not null references auth.users(id) on delete cascade,
  task_id uuid not null references public.tasks(id) on delete restrict,
  proof_url text,
  note text not null default '',
  status text not null default 'pending' check (status in ('pending','approved','rejected')),
  reward_points integer not null default 0 check (reward_points >= 0),
  reviewed_at timestamptz,
  created_at timestamptz not null default now(),
  unique(user_id, task_id)
);

create table if not exists public.withdrawal_requests (
  id uuid primary key default gen_random_uuid(),
  user_id uuid not null references auth.users(id) on delete cascade,
  amount numeric(12,2) not null check (amount > 0),
  currency text not null default 'MAD' check (currency in ('MAD','USD','EUR')),
  method text not null check (method in ('bank_transfer','paypal','other')),
  payout_details text not null,
  status text not null default 'pending' check (status in ('pending','approved','rejected','paid')),
  admin_note text,
  created_at timestamptz not null default now(),
  reviewed_at timestamptz
);

create table if not exists public.points_ledger (
  id uuid primary key default gen_random_uuid(),
  user_id uuid not null references auth.users(id) on delete cascade,
  points_delta integer not null,
  reason text not null,
  submission_id uuid references public.task_submissions(id) on delete set null,
  created_at timestamptz not null default now()
);

alter table public.tasks enable row level security;
alter table public.task_submissions enable row level security;
alter table public.withdrawal_requests enable row level security;
alter table public.points_ledger enable row level security;
alter table public.profiles enable row level security;

drop policy if exists "Active tasks are visible to signed-in users" on public.tasks;
create policy "Active tasks are visible to signed-in users" on public.tasks
  for select to authenticated using (is_active = true);

drop policy if exists "Users can read their own submissions" on public.task_submissions;
create policy "Users can read their own submissions" on public.task_submissions
  for select to authenticated using (auth.uid() = user_id);
drop policy if exists "Users can submit their own tasks" on public.task_submissions;
create policy "Users can submit their own tasks" on public.task_submissions
  for insert to authenticated with check (auth.uid() = user_id and status = 'pending' and reward_points = 0);

drop policy if exists "Users can read their own withdrawals" on public.withdrawal_requests;
create policy "Users can read their own withdrawals" on public.withdrawal_requests
  for select to authenticated using (auth.uid() = user_id);
drop policy if exists "Users can request withdrawals" on public.withdrawal_requests;
create policy "Users can request withdrawals" on public.withdrawal_requests
  for insert to authenticated with check (auth.uid() = user_id and status = 'pending');

drop policy if exists "Users can read their own points ledger" on public.points_ledger;
create policy "Users can read their own points ledger" on public.points_ledger
  for select to authenticated using (auth.uid() = user_id);

drop policy if exists "Users can read their own profile" on public.profiles;
create policy "Users can read their own profile" on public.profiles
  for select to authenticated using (auth.uid() = id);
drop policy if exists "Users can insert their own profile" on public.profiles;
create policy "Users can insert their own profile" on public.profiles
  for insert to authenticated with check (auth.uid() = id);
drop policy if exists "Users can update their own profile" on public.profiles;
create policy "Users can update their own profile" on public.profiles
  for update to authenticated using (auth.uid() = id) with check (auth.uid() = id);

-- Restrict profile updates so users cannot change their own points balance.
revoke update on public.profiles from authenticated;
grant update (display_name) on public.profiles to authenticated;

-- Only trusted administrators should approve submissions or withdrawals.
-- Admin approval should be implemented with a server-side Edge Function or
-- a restricted database role, never by exposing a service-role key in the website.

insert into public.tasks (title, description, category, reward_points, instructions)
select v.title, v.description, v.category, v.reward_points, v.instructions
from (values
 ('Complete your profile','Add a display name and check your account details.','profile',10,'Complete your profile honestly.'),
 ('Share useful feedback','Send constructive feedback about GrowPlus.','community',15,'Write a short, genuine suggestion.'),
 ('Explore creator resources','Review the creator growth tips and learning resources.','learning',10,'Review the available resources and share one takeaway.')
) as v(title, description, category, reward_points, instructions)
where not exists (select 1 from public.tasks t where t.title = v.title);

create index if not exists task_submissions_user_id_idx on public.task_submissions(user_id);
create index if not exists withdrawal_requests_user_id_idx on public.withdrawal_requests(user_id);
create index if not exists points_ledger_user_id_idx on public.points_ledger(user_id);
