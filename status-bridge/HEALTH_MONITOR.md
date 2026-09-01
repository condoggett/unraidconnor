# Unraid health notifications

The bridge now runs a five-minute health check beside its `/status` endpoint.
It only reports changes: high/recovered memory, high/recovered CPU load, and
stopped/recovered Docker containers.

Rebuild and run it with the existing `STATUS_TOKEN` plus these environment
values:

```text
NOTIFICATION_URL=https://yrvmanmrzxceqahopfec.supabase.co/functions/v1/send-notification
NOTIFICATION_SECRET=<your NOTIFICATION_WEBHOOK_SECRET>
SUPABASE_AUTHORIZATION=Bearer <your Supabase publishable key>
HEALTH_STATE_PATH=/data/health-state.json
```

Persist the monitor state by adding this volume to the existing container:

```text
-v /boot/config/plugins/unraid-status-bridge:/data
```

The monitor defaults are deliberately conservative:

- check interval: 5 minutes
- memory warning: 85%
- one-minute load warning: 1.5 per CPU core

Override them with `HEALTH_CHECK_INTERVAL_MS`, `MEMORY_WARNING_PERCENT`, or
`LOAD_WARNING_PER_CORE` if required.
