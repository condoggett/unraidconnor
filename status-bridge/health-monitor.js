const fs = require('fs/promises');
const path = require('path');
const { snapshot } = require('./server');

const intervalMs = Number(process.env.HEALTH_CHECK_INTERVAL_MS || 5 * 60 * 1000);
const memoryWarningPercent = Number(process.env.MEMORY_WARNING_PERCENT || 85);
const loadWarningPerCore = Number(process.env.LOAD_WARNING_PER_CORE || 1.5);
const statePath = process.env.HEALTH_STATE_PATH || '/data/health-state.json';
const notificationUrl = process.env.NOTIFICATION_URL || '';
const notificationSecret = process.env.NOTIFICATION_SECRET || '';
const authorization = process.env.SUPABASE_AUTHORIZATION || '';

async function readState() {
  try {
    return JSON.parse(await fs.readFile(statePath, 'utf8'));
  } catch {
    return { memoryWarning: false, loadWarning: false, stopped: [] };
  }
}

async function writeState(state) {
  await fs.mkdir(path.dirname(statePath), { recursive: true });
  await fs.writeFile(statePath, JSON.stringify(state, null, 2));
}

async function notify(title, body, priority = 'normal', data = {}) {
  if (!notificationUrl || !notificationSecret) {
    console.log('Health monitor is waiting for NOTIFICATION_URL and NOTIFICATION_SECRET.');
    return;
  }
  const headers = { 'content-type': 'application/json', 'x-notification-secret': notificationSecret };
  if (authorization) headers.authorization = authorization;
  const response = await fetch(notificationUrl, {
    method: 'POST',
    headers,
    body: JSON.stringify({ audience: 'subscribed', category: 'unraid', title, body, priority, data }),
  });
  if (!response.ok) console.error(`Notification failed: ${response.status} ${await response.text()}`);
}

function stoppedContainers(status) {
  return status.docker.containers
    .filter((container) => container.name !== 'unraid-status-bridge' && container.state !== 'running')
    .map((container) => container.name)
    .sort();
}

async function checkHealth() {
  const status = await snapshot();
  const previous = await readState();
  const currentStopped = stoppedContainers(status);
  const loadPerCore = status.loadAverage[0] / Math.max(status.cpuCores, 1);
  const next = {
    memoryWarning: status.memory.usedPercent >= memoryWarningPercent,
    loadWarning: loadPerCore >= loadWarningPerCore,
    stopped: currentStopped,
  };

  if (next.memoryWarning && !previous.memoryWarning) {
    await notify('Unraid memory is high', `${status.memory.usedPercent}% memory is in use.`, 'normal', { memoryUsedPercent: status.memory.usedPercent });
  } else if (!next.memoryWarning && previous.memoryWarning) {
    await notify('Unraid memory recovered', `Memory use is back to ${status.memory.usedPercent}%.`, 'normal', { memoryUsedPercent: status.memory.usedPercent });
  }

  if (next.loadWarning && !previous.loadWarning) {
    await notify('Unraid CPU load is high', `One-minute load is ${status.loadAverage[0].toFixed(2)} (${loadPerCore.toFixed(2)} per CPU core).`, 'normal', { loadAverage: status.loadAverage[0], loadPerCore });
  } else if (!next.loadWarning && previous.loadWarning) {
    await notify('Unraid CPU load recovered', `One-minute load is now ${status.loadAverage[0].toFixed(2)}.`, 'normal', { loadAverage: status.loadAverage[0], loadPerCore });
  }

  const newlyStopped = currentStopped.filter((name) => !previous.stopped.includes(name));
  const recovered = previous.stopped.filter((name) => !currentStopped.includes(name));
  if (newlyStopped.length) await notify('Unraid container stopped', newlyStopped.join(', '), 'critical', { containers: newlyStopped });
  if (recovered.length) await notify('Unraid container recovered', recovered.join(', '), 'normal', { containers: recovered });

  await writeState(next);
}

async function run() {
  try {
    await checkHealth();
  } catch (error) {
    console.error('Health check failed:', error.message);
  }
}

run();
setInterval(run, intervalMs);
