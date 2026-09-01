import 'package:flutter/material.dart';

import 'seerr_screen.dart';

class HomeAssistantHubScreen extends StatelessWidget {
  const HomeAssistantHubScreen({super.key, this.status});
  final Map<String, dynamic>? status;

  @override
  Widget build(BuildContext context) => Scaffold(
        appBar: AppBar(title: const Text('Home Assistant')),
        body: ListView(padding: const EdgeInsets.all(18), children: [
          Text('Home at a glance', style: Theme.of(context).textTheme.headlineSmall),
          const SizedBox(height: 8),
          const Card(child: ListTile(leading: Icon(Icons.lock_outline), title: Text('Your secure Home Assistant session'), subtitle: Text('Open Home Assistant to use your own dashboards, lights, heating and scenes. Your normal Home Assistant login stays private.'))),
          const SizedBox(height: 12),
          Card(child: ListTile(leading: const Icon(Icons.bolt_outlined), title: const Text('Favourite scenes'), subtitle: const Text('Scene controls will appear here after a read-only Home Assistant connection is configured.'), trailing: const Icon(Icons.tune))),
          Card(child: ListTile(leading: const Icon(Icons.monitor_heart_outlined), title: const Text('Homelab connection'), subtitle: Text(status?['online'] == true ? 'Homelab status bridge is online.' : 'Status bridge is unavailable right now.'))),
          const SizedBox(height: 18),
          FilledButton.icon(onPressed: () => Navigator.of(context).push(MaterialPageRoute<void>(builder: (_) => const HomelabWebAppScreen(title: 'Home Assistant', url: 'https://ha.conhomelab.uk'))), icon: const Icon(Icons.open_in_new), label: const Text('Open Home Assistant')),
        ]),
      );
}

class UnraidDashboardScreen extends StatelessWidget {
  const UnraidDashboardScreen({super.key, this.status, required this.admin});
  final Map<String, dynamic>? status;
  final bool admin;

  String _value(Object? value, [String fallback = '—']) => value == null ? fallback : '$value';

  @override
  Widget build(BuildContext context) {
    final memory = status?['memory'] as Map<String, dynamic>?;
    final docker = status?['docker'] as Map<String, dynamic>?;
    final stopped = ((docker?['containers'] as List?) ?? const []).whereType<Map>().where((item) => item['state'] != 'running').map((item) => '${item['name']}').toList();
    return Scaffold(
      appBar: AppBar(title: const Text('Unraid dashboard')),
      body: ListView(padding: const EdgeInsets.all(18), children: [
        Text('Server health', style: Theme.of(context).textTheme.headlineSmall),
        const SizedBox(height: 10),
        Row(children: [Expanded(child: Card(child: ListTile(title: const Text('CPU load'), subtitle: Text(_value((status?['loadAverage'] as List?)?.isNotEmpty == true ? status?['loadAverage'][0] : null))))), const SizedBox(width: 10), Expanded(child: Card(child: ListTile(title: const Text('Memory'), subtitle: Text(memory == null ? '—' : '${memory['usedPercent']}% used'))))]),
        Card(child: ListTile(leading: const Icon(Icons.widgets_outlined), title: const Text('Containers'), subtitle: Text(docker == null ? 'No live inventory.' : '${docker['running']} / ${docker['total']} running'))),
        Card(child: ListTile(leading: Icon(stopped.isEmpty ? Icons.check_circle_outline : Icons.warning_amber_outlined), title: Text(stopped.isEmpty ? 'No stopped containers' : '${stopped.length} stopped container${stopped.length == 1 ? '' : 's'}'), subtitle: Text(stopped.isEmpty ? 'All monitored workloads are running.' : stopped.join(', ')))),
        const SizedBox(height: 18),
        if (admin) const Card(child: Padding(padding: EdgeInsets.all(14), child: Text('Admin safety: restart actions will be shown here only after a server-side confirmation endpoint is configured. This app never restarts containers automatically.'))),
        FilledButton.icon(onPressed: () => Navigator.of(context).push(MaterialPageRoute<void>(builder: (_) => const HomelabWebAppScreen(title: 'Unraid', url: 'https://home.conhomelab.uk'))), icon: const Icon(Icons.open_in_new), label: const Text('Open Unraid')),
      ]),
    );
  }
}
