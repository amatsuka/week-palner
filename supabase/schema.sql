-- Прогнать целиком в SQL Editor проекта Supabase (Database > SQL Editor > New query).
-- Идемпотентно: можно запускать повторно без ошибок.

create extension if not exists pgcrypto;

create table if not exists public.plans (
  id          uuid primary key default gen_random_uuid(),
  user_id     uuid not null default auth.uid() references auth.users(id) on delete cascade,
  week        text not null,
  items       jsonb not null default '[]'::jsonb,
  updated_at  timestamptz not null default now()
);

create unique index if not exists plans_user_week_idx on public.plans (user_id, week);

alter table public.plans enable row level security;

drop policy if exists "plans_select_own" on public.plans;
create policy "plans_select_own" on public.plans
  for select using (auth.uid() = user_id);

drop policy if exists "plans_insert_own" on public.plans;
create policy "plans_insert_own" on public.plans
  for insert with check (auth.uid() = user_id);

drop policy if exists "plans_update_own" on public.plans;
create policy "plans_update_own" on public.plans
  for update using (auth.uid() = user_id) with check (auth.uid() = user_id);

drop policy if exists "plans_delete_own" on public.plans;
create policy "plans_delete_own" on public.plans
  for delete using (auth.uid() = user_id);

-- роли и задачи (палитра) — одна строка на пользователя, синхронизируется
-- отдельно от плана, чтобы не зависеть от недели
create table if not exists public.role_configs (
  id          uuid primary key default gen_random_uuid(),
  user_id     uuid not null unique default auth.uid() references auth.users(id) on delete cascade,
  roles       jsonb not null default '[]'::jsonb,
  updated_at  timestamptz not null default now()
);

alter table public.role_configs enable row level security;

drop policy if exists "role_configs_select_own" on public.role_configs;
create policy "role_configs_select_own" on public.role_configs
  for select using (auth.uid() = user_id);

drop policy if exists "role_configs_insert_own" on public.role_configs;
create policy "role_configs_insert_own" on public.role_configs
  for insert with check (auth.uid() = user_id);

drop policy if exists "role_configs_update_own" on public.role_configs;
create policy "role_configs_update_own" on public.role_configs
  for update using (auth.uid() = user_id) with check (auth.uid() = user_id);

drop policy if exists "role_configs_delete_own" on public.role_configs;
create policy "role_configs_delete_own" on public.role_configs
  for delete using (auth.uid() = user_id);

-- триггер, обновляющий updated_at при каждом апдейте строки (общий для обеих таблиц)
create or replace function public.set_updated_at()
returns trigger
language plpgsql
as $$
begin
  new.updated_at = now();
  return new;
end;
$$;

drop trigger if exists plans_set_updated_at on public.plans;
create trigger plans_set_updated_at
  before update on public.plans
  for each row execute function public.set_updated_at();

drop trigger if exists role_configs_set_updated_at on public.role_configs;
create trigger role_configs_set_updated_at
  before update on public.role_configs
  for each row execute function public.set_updated_at();

-- если схема уже прогонялась до переименования функции — подчистить старое имя
drop function if exists public.plans_set_updated_at();
