# Seerr notifications in Connor Homelab

Seerr can send native Connor Homelab notifications through its built-in **Webhook** notification agent. The endpoint is protected by a secret, so do not paste this configuration anywhere public.

## Configure it

1. Open **Seerr** as an administrator, then go to **Settings → Notifications → Webhook**.
2. Turn on the events you want: at least **Request Pending Approval**, **Request Automatically Approved**, **Request Approved**, **Request Declined**, **Request Available**, and **Request Processing Failed**.
3. Set **Webhook URL** to the `NOTIFICATION_URL` in your private `ConnorHomelabNotification.json` file.
4. Set Seerr's **Authorization Header** to the `authorization` value in your private `ConnorHomelabNotification.json` file. This is required by the Supabase Edge Function gateway.
5. Add one custom header:
   - Name: `x-notification-secret`
   - Value: the `secret` value from your private `ConnorHomelabNotification.json` file.
6. Use this JSON payload:

```json
{
  "audience": "subscribed",
  "category": "app",
  "title": "Seerr: {{event}}",
  "body": "{{subject}} — {{event}}",
  "data": {
    "service": "seerr",
    "event": "{{notification_type}}",
    "title": "{{subject}}"
  }
}
```

7. Save, then use Seerr's **Test** button. A native notification should arrive and be recorded in Connor Homelab's notification history.

The app's **Notification settings → Homelab app services** switch controls whether a person receives these messages.
