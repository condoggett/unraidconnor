import { createClient } from 'npm:@supabase/supabase-js@2';
import { cert, getApps, initializeApp } from 'npm:firebase-admin/app';
import { getMessaging } from 'npm:firebase-admin/messaging';

type Preference = {
  user_id: string;
  unraid_health?: boolean;
  home_assistant?: boolean;
  app_updates?: boolean;
  app_services?: boolean;
  quiet_hours_enabled?: boolean;
  quiet_start?: string;
  quiet_end?: string;
  timezone?: string;
};

const categoryColumn: Record<string, keyof Preference | undefined> = {
  unraid: 'unraid_health',
  home_assistant: 'home_assistant',
  app_update: 'app_updates',
  app: 'app_services',
};

function isQuiet(preference: Preference, priority: string): boolean {
  if (priority === 'critical' || !preference.quiet_hours_enabled) return false;
  const start = preference.quiet_start?.slice(0, 5) ?? '22:00';
  const end = preference.quiet_end?.slice(0, 5) ?? '07:00';
  try {
    const pieces = new Intl.DateTimeFormat('en-GB', { timeZone: preference.timezone || 'Europe/London', hour: '2-digit', minute: '2-digit', hourCycle: 'h23' })
      .formatToParts(new Date());
    const now = `${pieces.find((part) => part.type === 'hour')?.value}:${pieces.find((part) => part.type === 'minute')?.value}`;
    return start <= end ? now >= start && now < end : now >= start || now < end;
  } catch {
    return false;
  }
}

Deno.serve(async (request) => {
  if (request.headers.get('x-notification-secret') !== Deno.env.get('NOTIFICATION_WEBHOOK_SECRET')) {
    return new Response('Unauthorized', { status: 401 });
  }
  const payload = await request.json().catch(() => ({}));
  const { user_id, audience, category = 'test', title, body, data = {}, priority = 'normal' } = payload;
  if ((!user_id && audience !== 'subscribed') || !title || !body || !['unraid', 'home_assistant', 'app_update', 'app', 'test'].includes(category)) {
    return Response.json({ error: 'user_id or audience=subscribed, valid category, title and body are required' }, { status: 400 });
  }

  if (!getApps().length) {
    initializeApp({ credential: cert(JSON.parse(Deno.env.get('FIREBASE_SERVICE_ACCOUNT') ?? '{}')) });
  }
  const supabase = createClient(Deno.env.get('SUPABASE_URL') ?? '', Deno.env.get('SUPABASE_SERVICE_ROLE_KEY') ?? '');
  let users = user_id ? [user_id] : [...new Set((await supabase.from('user_devices').select('user_id')).data?.map((row) => row.user_id) ?? [])];
  // Seerr knows who made a request.  Route its notifications to that Homelab
  // account instead of broadcasting them to every family device.  A pending
  // request is an admin task, so it is deliberately routed only to admins.
  const service = String(data.service ?? '').toLowerCase();
  const event = String(data.event ?? data.notification_type ?? '').toLowerCase();
  const requesterEmail = String(data.requester_email ?? data.requesterEmail ?? '').trim();
  if (!user_id && category === 'app' && service === 'seerr') {
    const pending = event.includes('pending');
    if (pending) {
      const { data: admins } = await supabase.from('profiles').select('id').eq('role', 'admin');
      users = (admins ?? []).map((profile) => profile.id);
    } else if (requesterEmail) {
      const { data: requester } = await supabase.from('profiles').select('id').ilike('email', requesterEmail).maybeSingle();
      users = requester ? [requester.id] : [];
    } else {
      return Response.json({ error: 'Seerr notifications require data.requester_email for personal delivery.' }, { status: 400 });
    }
  }
  const { data: preferences } = await supabase.from('notification_preferences').select('*').in('user_id', users);
  const preferencesByUser = new Map((preferences ?? []).map((row) => [row.user_id, row as Preference]));
  const permittedUsers = users.filter((id) => {
    if (user_id) return true;
    const preference = preferencesByUser.get(id);
    const column = categoryColumn[category];
    return !preference || !column || preference[column] !== false;
  });

  const quietUsers = new Set(permittedUsers.filter((id) => {
    const preference = preferencesByUser.get(id);
    return preference && isQuiet(preference, priority);
  }));
  const recipients = permittedUsers.filter((id) => !quietUsers.has(id));
  if (permittedUsers.length) {
    await supabase.from('notifications').insert(permittedUsers.map((id) => ({ user_id: id, category, title, body, data: { ...data, priority, delivery: quietUsers.has(id) ? 'quiet-hours' : 'sent' } })));
  }
  const { data: devices, error } = recipients.length
    ? await supabase.from('user_devices').select('user_id, token').in('user_id', recipients)
    : { data: [], error: null };
  if (error) return Response.json({ error: error.message }, { status: 500 });
  const results = await Promise.all((devices ?? []).map(async ({ token }) => {
    try {
      await getMessaging().send({ token, notification: { title, body }, data: { ...Object.fromEntries(Object.entries(data).map(([key, value]) => [key, String(value)])), category }, android: { priority: priority === 'critical' ? 'high' : 'normal' } });
      return true;
    } catch {
      return false;
    }
  }));
  return Response.json({ sent: results.filter(Boolean).length, history: permittedUsers.length, quiet: quietUsers.size });
});
