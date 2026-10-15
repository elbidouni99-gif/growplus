-- Safe repair for the existing GrowPlus tasks table.
-- Run this file once in Supabase SQL Editor. It preserves existing task rows.
alter table public.tasks
  add column if not exists category text not null default 'community',
  add column if not exists reward_points integer not null default 0,
  add column if not exists instructions text not null default '',
  add column if not exists is_active boolean not null default true;

do $$
begin
  if exists (select 1 from information_schema.columns
             where table_schema='public' and table_name='tasks' and column_name='points') then
    execute 'update public.tasks set reward_points = points where reward_points = 0 and points is not null';
  end if;
  if exists (select 1 from information_schema.columns
             where table_schema='public' and table_name='tasks' and column_name='active') then
    execute 'update public.tasks set is_active = active where active is not null';
  end if;
end $$;

-- Show the resulting columns for verification.
select column_name, data_type
from information_schema.columns
where table_schema='public' and table_name='tasks'
order by ordinal_position;
