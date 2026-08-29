const { app } = require('@azure/functions');

app.http('status', {
  methods: ['GET'],
  authLevel: 'anonymous',
  handler: async (request) => {
    const endpoint = process.env.UNRAID_STATUS_URL;
    const token = (process.env.UNRAID_STATUS_API_KEY || '').trim();
    if (!endpoint) return { status: 503, jsonBody: { configured: false, message: 'Status bridge is not configured yet.' } };
    try {
      const response = await fetch(endpoint, { headers: token ? { Authorization: `Bearer ${token}` } : {} });
      if (!response.ok) return { status: 502, jsonBody: { configured: true, online: false, bridgeStatus: response.status, message: 'Status bridge unavailable.' } };
      const data = await response.json();
      return { jsonBody: { configured: true, ...data } };
    } catch {
      return { status: 502, jsonBody: { configured: true, online: false, message: 'Status bridge unavailable.' } };
    }
  }
});
