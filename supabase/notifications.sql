-- Connor Homelab notifications: run this after supabase/schema.sql.
-- Each user controls their own delivery categories and quiet hours.  The Edge
-- Function writes notification history with the service-role key, while RLS
-- ensures members can only read and mark their own alerts as read.

create table if not exists public.notification_preferences (
  user_id uuid primary key references public.profiles(id) on delete cascade,
  unraid_health boolean not null default true,
  home_assistant boolean not null default true,
  app_updates boolean not null default true,
  quiet_hours_enabled boolean not null default false,
  quiet_start time not null default time '22:00',
  quiet_end time not null default time '07:00',
  timezone text not null default 'Europe/London',
  updated_at timestamptz not null default now()
);

create table if not exists public.notifications (
  id uuid primary key default gen_random_uuid(),
  user_id uuid not null references public.profiles(id) on delete cascade,
  category text not null check (category in ('unraid', 'home_assistant', 'app_update', 'test')),
  title text not null,
  body text not null,
  data jsonb not null default '{}'::jsonb,
  read_at timestamptz,
  created_at timestamptz not null default now()
);

create index if not exists notifications_user_created_idx on public.notifications (user_id, created_at desc);

alter table public.notification_preferences enable row level security;
alter table public.notifications enable row level security;

drop policy if exists "Users manage their notification preferences" on public.notification_preferences;
create policy "Users manage their notification preferences"
  on public.notification_preferences for all
  using (user_id = auth.uid())
  with check (user_id = auth.uid());

drop policy if exists "Users read their notifications" on public.notifications;
create policy "Users read their notifications"
  on public.notifications for select
  using (user_id = auth.uid() or public.is_admin());

drop policy if exists "Users mark their notifications read" on public.notifications;
create policy "Users mark their notifications read"
  on public.notifications for update
  using (user_id = auth.uid())
  with check (user_id = auth.uid());
