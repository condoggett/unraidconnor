const http = require('http');
const os = require('os');
const Docker = require('dockerode');

const port = Number(process.env.PORT || 9100);
const token = process.env.STATUS_TOKEN || '';
const docker = new Docker({ socketPath: '/var/run/docker.sock' });

const memory = () => {
  const total = os.totalmem();
  const free = os.freemem();
  return { total, free, used: total - free, usedPercent: Math.round((1 - free / total) * 100) };
};

async function snapshot() {
  let containers = [];
  try {
    containers = (await docker.listContainers({ all: true })).map((container) => ({
      name: (container.Names?.[0] || '').replace(/^\//, ''),
      state: container.State,
      status: container.Status,
      image: container.Image,
    }));
  } catch {
    // The status endpoint remains available even while Docker is restarting.
  }
  return {
    online: true,
    timestamp: new Date().toISOString(),
    hostname: os.hostname(),
    uptimeSeconds: Math.round(os.uptime()),
    loadAverage: os.loadavg(),
    cpuCores: os.cpus().length,
    memory: memory(),
    docker: { total: containers.length, running: containers.filter((container) => container.state === 'running').length, containers },
  };
}

function startServer() {
  http.createServer(async (req, res) => {
    if (req.method !== 'GET' || req.url !== '/status') {
      res.writeHead(404);
      return res.end();
    }
    if (token && req.headers.authorization !== `Bearer ${token}`) {
      res.writeHead(401);
      return res.end(JSON.stringify({ message: 'Unauthorized' }));
    }
    try {
      res.writeHead(200, { 'content-type': 'application/json', 'cache-control': 'no-store' });
      res.end(JSON.stringify(await snapshot()));
    } catch {
      res.writeHead(503);
      res.end(JSON.stringify({ online: false }));
    }
  }).listen(port, '0.0.0.0', () => console.log(`status bridge listening on ${port}`));
}

if (require.main === module) startServer();
module.exports = { snapshot, startServer };
