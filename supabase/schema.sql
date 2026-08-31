-- Connor Homelab user accounts and per-application permissions.
-- Run this in Supabase SQL Editor after creating the project.

create table if not exists public.profiles (
  id uuid primary key references auth.users(id) on delete cascade,
  display_name text,
  email text not null,
  role text not null default 'user' check (role in ('admin', 'user')),
  created_at timestamptz not null default now(),
  updated_at timestamptz not null default now()
);
create table if not exists public.apps (id text primary key, name text not null, description text, url text not null, icon text, enabled boolean not null default true, sort_order integer not null default 0);
create table if not exists public.user_app_access (user_id uuid not null references public.profiles(id) on delete cascade, app_id text not null references public.apps(id) on delete cascade, granted_at timestamptz not null default now(), primary key (user_id, app_id));
create table if not exists public.audit_events (id bigint generated always as identity primary key, user_id uuid references public.profiles(id) on delete set null, event_type text not null, app_id text references public.apps(id) on delete set null, metadata jsonb not null default '{}'::jsonb, created_at timestamptz not null default now());
create table if not exists public.user_preferences (
  user_id uuid primary key references public.profiles(id) on delete cascade,
  favourite_app_ids jsonb not null default '[]'::jsonb,
  hidden_app_ids jsonb not null default '[]'::jsonb,
  updated_at timestamptz not null default now()
);

insert into public.apps (id, name, description, url, icon, sort_order) values
  ('home-assistant', 'Home Assistant', 'Home control, automations and energy.', 'https://ha.conhomelab.uk', '⌂', 10),
  ('plex', 'Plex', 'Family media playback and libraries.', 'https://plex.conhomelab.uk', '▶', 20),
  ('immich', 'Immich', 'Photo and video library.', 'https://photos.conhomelab.uk', '◉', 30),
  ('nextcloud', 'Nextcloud', 'Files, documents and sync.', 'https://nextcloud.conhomelab.uk', '☁', 40),
  ('requests', 'Seerr', 'Media requests for family and friends.', 'https://requests.conhomelab.uk', '✦', 50),
  ('downloads', 'Downloads', 'Download client and queue management.', 'https://downloads.conhomelab.uk', '↯', 60),
  ('radarr', 'Radarr', 'Movie automation and library management.', 'https://radarr.conhomelab.uk', '▤', 70),
  ('sonarr', 'Sonarr', 'TV automation and library management.', 'https://sonarr.conhomelab.uk', '▤', 80),
  ('backups', 'Backups', 'Backup jobs and restore history.', 'https://backups.conhomelab.uk', '◒', 90),
  ('fileflows', 'FileFlows', 'Media processing and transcoding.', 'https://fileflows.conhomelab.uk', '✧', 100),
  ('maintainerr', 'Maintainerr', 'Media cleanup and library maintenance.', 'https://maintainerr.conhomelab.uk', '◎', 110),
  ('mealie', 'Mealie', 'Recipes and meal planning.', 'https://mealie.conhomelab.uk', '☕', 120)
on conflict (id) do update set name = excluded.name, description = excluded.description, url = excluded.url, icon = excluded.icon, sort_order = excluded.sort_order;

alter table public.profiles enable row level security;
alter table public.apps enable row level security;
alter table public.user_app_access enable row level security;
alter table public.audit_events enable row level security;
alter table public.user_preferences enable row level security;
create or replace function public.is_admin() returns boolean language sql stable security definer set search_path = public as $$ select exists (select 1 from public.profiles where id = auth.uid() and role = 'admin') $$;
create policy "Users read their profile" on public.profiles for select using (id = auth.uid() or public.is_admin());
create policy "Admins manage profiles" on public.profiles for all using (public.is_admin()) with check (public.is_admin());
create policy "Signed in users read enabled apps" on public.apps for select using (auth.uid() is not null and enabled = true);
create policy "Admins manage apps" on public.apps for all using (public.is_admin()) with check (public.is_admin());
create policy "Users read their app access" on public.user_app_access for select using (user_id = auth.uid() or public.is_admin());
create policy "Admins manage app access" on public.user_app_access for all using (public.is_admin()) with check (public.is_admin());
create policy "Users create their audit events" on public.audit_events for insert with check (user_id = auth.uid());
create policy "Users read their audit events" on public.audit_events for select using (user_id = auth.uid() or public.is_admin());
create policy "Users manage their preferences" on public.user_preferences for all using (user_id = auth.uid()) with check (user_id = auth.uid());
create or replace function public.handle_new_user() returns trigger language plpgsql security definer set search_path = public as $$ begin insert into public.profiles (id, email, display_name) values (new.id, coalesce(new.email, ''), coalesce(new.raw_user_meta_data->>'full_name', split_part(coalesce(new.email, ''), '@', 1))) on conflict (id) do update set email = excluded.email; return new; end; $$;
drop trigger if exists on_auth_user_created on auth.users;
create trigger on_auth_user_created after insert on auth.users for each row execute procedure public.handle_new_user();
