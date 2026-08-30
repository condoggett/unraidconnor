import type { CapacitorConfig } from '@capacitor/cli';

const config: CapacitorConfig = {
  appId: 'uk.conhomelab.portal',
  appName: 'Connor Homelab',
  webDir: '../',
  server: { url: 'https://conhomelab.uk', cleartext: false },
  android: { allowMixedContent: false }
};

export default config;
