# Release 4 personal notification connectors

All connectors use the existing notification function and its existing two headers. They send `category: "app"`, `data.service`, and `recipient_email`. The function finds the matching Homelab profile and delivers only to that person's devices; unknown identities never fall back to a broadcast.

```json
{
  "audience": "subscribed",
  "category": "app",
  "title": "Service update",
  "body": "Your personal update is ready.",
  "data": { "service": "service-name", "recipient_email": "member@example.com" }
}
```

Plex and Tautulli often identify a viewer by username, not email. Run `supabase/release3-and-4.sql`, then add each viewer to `service_identities`; this keeps credentials out of the Android app. Immich highlights require a read-only Immich API key. Nextcloud, Mealie and FileFlows each need their own webhook/plugin/workflow to emit an event. Keep any such key on the server or service, never in the Android app.
