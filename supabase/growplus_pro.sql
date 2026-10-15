-- GrowPlus Pro security + administration upgrade
-- Run AFTER supabase/growplus_setup.sql in Supabase SQL Editor.
-- Then add your own auth user to public.growplus_admins using the instructions in ADMIN_SETUP.md.
-- Never put a Supabase service-role key in browser code.

create extension if not exists pgcrypto;

create table if not exists public.growplus_admins (
  user_id uuid primary key references auth.users(id) on delete cascade,
  created_at timestamptz not null default now()
);

create table if not exists public.admin_audit_log (
  id bigint generated always as identity primary key,
  admin_id uuid not null references auth.users(id),
  action text not null,
  target_type text not null,
  target_id uuid,
  details jsonb not null default '{}'::jsonb,
  created_at timestamptz not null default now()
);

alter table public.growplus_admins enable row level security;
alter table public.admin_audit_log enable row level security;

drop policy if exists "Admins can view admin roster" on public.growplus_admins;
create policy "Admins can view admin roster" on public.growplus_admins
 for select to authenticated using (exists(select 1 from public.growplus_admins a where a.user_id=auth.uid()));

drop policy if exists "Admins can view audit log" on public.admin_audit_log;
create policy "Admins can view audit log" on public.admin_audit_log
 for select to authenticated using (exists(select 1 from public.growplus_admins a where a.user_id=auth.uid()));

drop policy if exists "Admins can view all submissions" on public.task_submissions;
create policy "Admins can view all submissions" on public.task_submissions
 for select to authenticated using (exists(select 1 from public.growplus_admins a where a.user_id=auth.uid()));

drop policy if exists "Admins can view all withdrawals" on public.withdrawal_requests;
create policy "Admins can view all withdrawals" on public.withdrawal_requests
 for select to authenticated using (exists(select 1 from public.growplus_admins a where a.user_id=auth.uid()));

drop policy if exists "Admins can manage tasks" on public.tasks;
create policy "Admins can manage tasks" on public.tasks
 for all to authenticated using (exists(select 1 from public.growplus_admins a where a.user_id=auth.uid()))
 with check (exists(select 1 from public.growplus_admins a where a.user_id=auth.uid()));

create or replace function public.growplus_is_admin()
returns boolean language sql stable security definer
set search_path = '' as $$
 select exists(select 1 from public.growplus_admins where user_id = (select auth.uid()));
$$;
revoke all on function public.growplus_is_admin() from public;
grant execute on function public.growplus_is_admin() to authenticated;

create or replace function public.growplus_review_submission(
 p_submission_id uuid, p_decision text, p_admin_note text default ''
) returns jsonb
language plpgsql security definer set search_path = '' as $$
declare
 s public.task_submissions%rowtype;
 actor uuid := auth.uid();
 task_reward integer := 0;
begin
 if actor is null or not exists(select 1 from public.growplus_admins a where a.user_id=actor) then
   raise exception 'Administrator access required';
 end if;
 if p_decision not in ('approved','rejected') then raise exception 'Decision must be approved or rejected'; end if;
 select * into s from public.task_submissions where id=p_submission_id for update;
 if not found then raise exception 'Submission not found'; end if;
 if s.status <> 'pending' then raise exception 'Only pending submissions can be reviewed'; end if;
 if p_decision='approved' then
   select coalesce(t.reward_points,0) into task_reward from public.tasks t where t.id=s.task_id;
   task_reward := coalesce(task_reward,0);
 end if;
 update public.task_submissions set status=p_decision, reviewed_at=now(),
   reward_points=case when p_decision='approved' then task_reward else 0 end
 where id=s.id;
 if p_decision='approved' then
   update public.profiles set points_balance=coalesce(points_balance,0)+task_reward,
     total_earned_points=coalesce(total_earned_points,0)+task_reward, updated_at=now()
   where id=s.user_id;
   insert into public.points_ledger(user_id,points_delta,reason,submission_id)
   values(s.user_id,task_reward,'Task approved',s.id);
 end if;
 insert into public.admin_audit_log(admin_id,action,target_type,target_id,details)
 values(actor,'submission_'||p_decision,'task_submission',s.id,
   jsonb_build_object('user_id',s.user_id,'note',left(coalesce(p_admin_note,''),1000),'points',case when p_decision='approved' then task_reward else 0 end));
 return jsonb_build_object('ok',true,'status',p_decision,'points',case when p_decision='approved' then task_reward else 0 end);
end; $$;

create or replace function public.growplus_review_withdrawal(
 p_request_id uuid, p_decision text, p_admin_note text default ''
) returns jsonb
language plpgsql security definer set search_path = '' as $$
declare
 w public.withdrawal_requests%rowtype;
 actor uuid := auth.uid();
begin
 if actor is null or not exists(select 1 from public.growplus_admins a where a.user_id=actor) then
   raise exception 'Administrator access required';
 end if;
 if p_decision not in ('approved','rejected','paid') then raise exception 'Invalid withdrawal decision'; end if;
 select * into w from public.withdrawal_requests where id=p_request_id for update;
 if not found then raise exception 'Withdrawal request not found'; end if;
 if (p_decision='paid' and w.status <> 'approved') or (p_decision in ('approved','rejected') and w.status <> 'pending') then
   raise exception 'Invalid status transition';
 end if;
 update public.withdrawal_requests set status=p_decision, admin_note=left(coalesce(p_admin_note,''),1000), reviewed_at=now()
 where id=w.id;
 insert into public.admin_audit_log(admin_id,action,target_type,target_id,details)
 values(actor,'withdrawal_'||p_decision,'withdrawal_request',w.id,
   jsonb_build_object('user_id',w.user_id,'amount',w.amount,'currency',w.currency,'note',left(coalesce(p_admin_note,''),1000)));
 return jsonb_build_object('ok',true,'status',p_decision);
end; $$;

revoke all on function public.growplus_review_submission(uuid,text,text) from public;
revoke all on function public.growplus_review_withdrawal(uuid,text,text) from public;
grant execute on function public.growplus_review_submission(uuid,text,text) to authenticated;
grant execute on function public.growplus_review_withdrawal(uuid,text,text) to authenticated;

create index if not exists admin_audit_log_created_at_idx on public.admin_audit_log(created_at desc);
create index if not exists task_submissions_status_idx on public.task_submissions(status,created_at);
create index if not exists withdrawal_requests_status_idx on public.withdrawal_requests(status,created_at);

-- Security note: browser users can only invoke review RPCs if their auth.uid() is in growplus_admins.


-- Minimal AI usage log. The edge function enforces a per-user daily quota.
create table if not exists public.growplus_ai_usage (
 id bigint generated always as identity primary key,
 user_id uuid not null references auth.users(id) on delete cascade,
 created_at timestamptz not null default now()
);
alter table public.growplus_ai_usage enable row level security;
drop policy if exists "Users can read own AI usage" on public.growplus_ai_usage;
create policy "Users can read own AI usage" on public.growplus_ai_usage
 for select to authenticated using (auth.uid() = user_id);
drop policy if exists "Users can insert own AI usage" on public.growplus_ai_usage;
create policy "Users can insert own AI usage" on public.growplus_ai_usage
 for insert to authenticated with check (auth.uid() = user_id);
create index if not exists growplus_ai_usage_user_created_idx on public.growplus_ai_usage(user_id,created_at desc);
