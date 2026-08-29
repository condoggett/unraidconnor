const { app } = require('@azure/functions');

app.http('status', {
  methods: ['GET'],
  authLevel: 'anonymous',
  handler: async (request) => {
    const principal = request.headers.get('x-ms-client-principal');
    if (!principal) return { status: 401, jsonBody: { message: 'Sign-in required.' } };
    const endpoint = process.env.UNRAID_STATUS_URL;
    const token = process.env.UNRAID_STATUS_API_KEY;
    if (!endpoint) return { status: 503, jsonBody: { configured: false, message: 'Status bridge is not configured yet.' } };
    try {
      const response = await fetch(endpoint, { headers: token ? { Authorization: `Bearer ${token}` } : {} });
      if (!response.ok) return { status: 502, jsonBody: { configured: true, online: false, message: 'Status bridge unavailable.' } };
      const data = await response.json();
      return { jsonBody: { configured: true, ...data } };
    } catch {
      return { status: 502, jsonBody: { configured: true, online: false, message: 'Status bridge unavailable.' } };
    }
  }
});
