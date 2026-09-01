-- Connor Homelab Releases 3 and 4: personal layouts and service identities.
-- Run once in Supabase SQL Editor. No passwords or third-party API keys are stored here.

create table if not exists public.user_dashboard_settings (
  user_id uuid primary key references public.profiles(id) on delete cascade,
  theme text not null default 'ocean' check (theme in ('ocean', 'forest', 'violet', 'sunset')),
  dashboard_layout text not null default 'standard' check (dashboard_layout in ('standard', 'compact', 'media_first')),
  avatar_icon text not null default 'auto',
  app_lock_enabled boolean not null default false,
  app_lock_timeout_minutes integer not null default 15 check (app_lock_timeout_minutes between 1 and 1440),
  updated_at timestamptz not null default now()
);

create table if not exists public.service_identities (
  id bigint generated always as identity primary key,
  user_id uuid not null references public.profiles(id) on delete cascade,
  service text not null check (service in ('plex', 'tautulli', 'immich', 'nextcloud', 'mealie', 'fileflows')),
  external_identity text not null,
  created_at timestamptz not null default now(),
  unique (service, external_identity)
);

create table if not exists public.maintenance_notices (
  id bigint generated always as identity primary key,
  active boolean not null default false,
  title text not null default 'Scheduled maintenance',
  message text not null default '',
  starts_at timestamptz,
  ends_at timestamptz,
  created_at timestamptz not null default now()
);

alter table public.user_dashboard_settings enable row level security;
alter table public.service_identities enable row level security;
alter table public.maintenance_notices enable row level security;

drop policy if exists "Users manage their dashboard settings" on public.user_dashboard_settings;
create policy "Users manage their dashboard settings" on public.user_dashboard_settings for all using (user_id = auth.uid()) with check (user_id = auth.uid());
drop policy if exists "Users read their service identities" on public.service_identities;
create policy "Users read their service identities" on public.service_identities for select using (user_id = auth.uid() or public.is_admin());
drop policy if exists "Admins manage service identities" on public.service_identities;
create policy "Admins manage service identities" on public.service_identities for all using (public.is_admin()) with check (public.is_admin());
drop policy if exists "Members read active maintenance notices" on public.maintenance_notices;
create policy "Members read active maintenance notices" on public.maintenance_notices for select using (auth.uid() is not null and active = true);
drop policy if exists "Admins manage maintenance notices" on public.maintenance_notices;
create policy "Admins manage maintenance notices" on public.maintenance_notices for all using (public.is_admin()) with check (public.is_admin());
