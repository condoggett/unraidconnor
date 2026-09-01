import 'package:flutter/material.dart';

import 'seerr_screen.dart';

class HomeAssistantHubScreen extends StatelessWidget {
  const HomeAssistantHubScreen({super.key, this.status});
  final Map<String, dynamic>? status;

  @override
  Widget build(BuildContext context) => Scaffold(
    appBar: AppBar(title: const Text('Home Assistant')),
    body: ListView(
      padding: const EdgeInsets.all(18),
      children: [
        Text(
          'Home at a glance',
          style: Theme.of(context).textTheme.headlineSmall,
        ),
        const SizedBox(height: 6),
        _ConnectionCard(
          online: status?['online'] == true,
          service: 'Home Assistant',
        ),
        const SizedBox(height: 16),
        Text('Quick access', style: Theme.of(context).textTheme.titleLarge),
        const SizedBox(height: 8),
        const Card(
          child: ListTile(
            leading: Icon(Icons.lightbulb_outline),
            title: Text('Lights & rooms'),
            subtitle: Text(
              'Open your Home Assistant dashboard to control lights and rooms.',
            ),
          ),
        ),
        const Card(
          child: ListTile(
            leading: Icon(Icons.thermostat_outlined),
            title: Text('Heating & climate'),
            subtitle: Text(
              'Your existing Home Assistant climate cards stay in one secure in-app session.',
            ),
          ),
        ),
        const Card(
          child: ListTile(
            leading: Icon(Icons.shield_outlined),
            title: Text('Home security'),
            subtitle: Text('Check your own Home Assistant security dashboard.'),
          ),
        ),
        const SizedBox(height: 14),
        const Card(
          child: ListTile(
            leading: Icon(Icons.lock_outline),
            title: Text('Your sign-in stays private'),
            subtitle: Text(
              'Connor Homelab does not store your Home Assistant password or long-lived Home Assistant token.',
            ),
          ),
        ),
        const SizedBox(height: 18),
        FilledButton.icon(
          onPressed: () =>
              _open(context, 'Home Assistant', 'https://ha.conhomelab.uk'),
          icon: const Icon(Icons.open_in_new),
          label: const Text('Open Home Assistant'),
        ),
      ],
    ),
  );

  static void _open(BuildContext context, String title, String url) =>
      Navigator.of(context).push(
        MaterialPageRoute<void>(
          builder: (_) => HomelabWebAppScreen(title: title, url: url),
        ),
      );
}

class UnraidDashboardScreen extends StatelessWidget {
  const UnraidDashboardScreen({super.key, this.status, required this.admin});
  final Map<String, dynamic>? status;
  final bool admin;

  String _value(Object? value, [String fallback = '—']) =>
      value == null ? fallback : '$value';

  @override
  Widget build(BuildContext context) {
    final memory = status?['memory'] as Map<String, dynamic>?;
    final docker = status?['docker'] as Map<String, dynamic>?;
    final loads = status?['loadAverage'];
    final cpuLoad = loads is List && loads.isNotEmpty ? loads.first : null;
    final stopped = ((docker?['containers'] as List?) ?? const [])
        .whereType<Map>()
        .where((item) => item['state'] != 'running')
        .map((item) => '${item['name']}')
        .toList();
    final uptime = status?['uptimeSeconds'];
    return Scaffold(
      appBar: AppBar(title: const Text('Unraid dashboard')),
      body: ListView(
        padding: const EdgeInsets.all(18),
        children: [
          Text(
            'Server health',
            style: Theme.of(context).textTheme.headlineSmall,
          ),
          const SizedBox(height: 10),
          _ConnectionCard(
            online: status?['online'] == true,
            service: '${status?['hostname'] ?? 'Unraid'}',
          ),
          const SizedBox(height: 10),
          Row(
            children: [
              Expanded(
                child: Card(
                  child: ListTile(
                    title: const Text('CPU load'),
                    subtitle: Text(_value(cpuLoad)),
                  ),
                ),
              ),
              const SizedBox(width: 10),
              Expanded(
                child: Card(
                  child: ListTile(
                    title: const Text('Memory'),
                    subtitle: Text(
                      memory == null ? '—' : '${memory['usedPercent']}% used',
                    ),
                  ),
                ),
              ),
            ],
          ),
          Card(
            child: ListTile(
              leading: const Icon(Icons.memory_outlined),
              title: const Text('Server details'),
              subtitle: Text(
                '${_value(status?['cpuCores'])} CPU cores${uptime == null ? '' : ' · ${_uptime(uptime)} uptime'}',
              ),
            ),
          ),
          Card(
            child: ListTile(
              leading: const Icon(Icons.widgets_outlined),
              title: const Text('Containers'),
              subtitle: Text(
                docker == null
                    ? 'No live inventory.'
                    : '${docker['running']} / ${docker['total']} running',
              ),
            ),
          ),
          const Card(
            child: ListTile(
              leading: Icon(Icons.storage_outlined),
              title: Text('Storage'),
              subtitle: Text(
                'Storage detail will appear here when the status bridge exposes array and pool usage.',
              ),
            ),
          ),
          Card(
            child: ListTile(
              leading: Icon(
                stopped.isEmpty
                    ? Icons.check_circle_outline
                    : Icons.warning_amber_outlined,
              ),
              title: Text(
                stopped.isEmpty
                    ? 'No stopped containers'
                    : '${stopped.length} stopped container${stopped.length == 1 ? '' : 's'}',
              ),
              subtitle: Text(
                stopped.isEmpty
                    ? 'All monitored workloads are running.'
                    : stopped.join(', '),
              ),
            ),
          ),
          const SizedBox(height: 18),
          if (admin)
            const Card(
              child: Padding(
                padding: EdgeInsets.all(14),
                child: Text(
                  'Admin safety: restart actions will be shown here only after a server-side confirmation endpoint is configured. This app never restarts containers automatically.',
                ),
              ),
            ),
          FilledButton.icon(
            onPressed: () => Navigator.of(context).push(
              MaterialPageRoute<void>(
                builder: (_) => const HomelabWebAppScreen(
                  title: 'Unraid',
                  url: 'https://home.conhomelab.uk',
                ),
              ),
            ),
            icon: const Icon(Icons.open_in_new),
            label: const Text('Open Unraid'),
          ),
          const SizedBox(height: 10),
          OutlinedButton.icon(
            onPressed: () => Navigator.of(context).push(
              MaterialPageRoute<void>(
                builder: (_) => const HomelabWebAppScreen(
                  title: 'Unraid Docker',
                  url: 'https://home.conhomelab.uk/Docker',
                ),
              ),
            ),
            icon: const Icon(Icons.widgets_outlined),
            label: const Text('Open Docker apps'),
          ),
        ],
      ),
    );
  }

  String _uptime(Object value) {
    final seconds = int.tryParse('$value') ?? 0;
    final days = seconds ~/ 86400;
    final hours = (seconds % 86400) ~/ 3600;
    return days > 0 ? '${days}d ${hours}h' : '${hours}h';
  }
}

class _ConnectionCard extends StatelessWidget {
  const _ConnectionCard({required this.online, required this.service});
  final bool online;
  final String service;

  @override
  Widget build(BuildContext context) => Card(
    color: online ? const Color(0xff123125) : const Color(0xff25212a),
    child: ListTile(
      leading: Icon(
        online ? Icons.check_circle_outline : Icons.cloud_off_outlined,
        color: online ? const Color(0xff66e59a) : Colors.amber,
      ),
      title: Text(
        online
            ? '$service connection available'
            : '$service status unavailable',
      ),
      subtitle: Text(
        online
            ? 'Secure Homelab connection is online.'
            : 'Try refresh, then open diagnostics if this continues.',
      ),
    ),
  );
}
