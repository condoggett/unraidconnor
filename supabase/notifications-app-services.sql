-- Run after notifications.sql to add a shared category for integrated apps.
alter table public.notification_preferences
  add column if not exists app_services boolean not null default true;

alter table public.notifications
  drop constraint if exists notifications_category_check;

alter table public.notifications
  add constraint notifications_category_check
  check (category in ('unraid', 'home_assistant', 'app_update', 'app', 'test'));
