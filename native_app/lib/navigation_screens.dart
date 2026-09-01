import 'package:flutter/material.dart';

class ServiceCatalogueScreen extends StatefulWidget {
  const ServiceCatalogueScreen({
    super.key,
    required this.apps,
    required this.onOpen,
  });
  final List<Map<String, dynamic>> apps;
  final Future<void> Function(Map<String, dynamic> app) onOpen;

  @override
  State<ServiceCatalogueScreen> createState() => _ServiceCatalogueScreenState();
}

class _ServiceCatalogueScreenState extends State<ServiceCatalogueScreen> {
  String _query = '';

  String _category(Map<String, dynamic> app) {
    final text = '${app['name']} ${app['description']} ${app['url']}'
        .toLowerCase();
    if (text.contains('home assistant')) return 'Home';
    if (text.contains('immich') || text.contains('photo')) return 'Photos';
    if (text.contains('seerr') ||
        text.contains('plex') ||
        text.contains('radarr') ||
        text.contains('sonarr') ||
        text.contains('media'))
      return 'Media';
    if (text.contains('unraid') ||
        text.contains('docker') ||
        text.contains('tautulli') ||
        text.contains('server'))
      return 'Homelab';
    return 'Utilities';
  }

  @override
  Widget build(BuildContext context) {
    final filtered = widget.apps
        .where(
          (app) => '${app['name']} ${app['description']} ${_category(app)}'
              .toLowerCase()
              .contains(_query.toLowerCase()),
        )
        .toList();
    final categories = <String, List<Map<String, dynamic>>>{};
    for (final app in filtered) {
      categories.putIfAbsent(_category(app), () => []).add(app);
    }
    return Scaffold(
      appBar: AppBar(title: const Text('Your services')),
      body: ListView(
        padding: const EdgeInsets.all(18),
        children: [
          TextField(
            onChanged: (value) => setState(() => _query = value),
            decoration: const InputDecoration(
              prefixIcon: Icon(Icons.search),
              hintText: 'Search your services',
            ),
          ),
          const SizedBox(height: 16),
          if (filtered.isEmpty)
            const Card(
              child: Padding(
                padding: EdgeInsets.all(18),
                child: Text('No assigned service matches that search.'),
              ),
            ),
          ...categories.entries.expand(
            (entry) => [
              Padding(
                padding: const EdgeInsets.only(top: 10, bottom: 6),
                child: Text(
                  entry.key,
                  style: Theme.of(context).textTheme.titleLarge,
                ),
              ),
              ...entry.value.map(
                (app) => Card(
                  child: ListTile(
                    leading: CircleAvatar(child: Text('${app['icon'] ?? '•'}')),
                    title: Text('${app['name']}'),
                    subtitle: Text('${app['description'] ?? ''}'),
                    trailing: const Icon(Icons.arrow_forward_ios),
                    onTap: () => widget.onOpen(app),
                  ),
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }
}

class WelcomeGuideScreen extends StatelessWidget {
  const WelcomeGuideScreen({super.key});

  @override
  Widget build(BuildContext context) => Scaffold(
    appBar: AppBar(title: const Text('Welcome to Connor Homelab')),
    body: ListView(
      padding: const EdgeInsets.all(18),
      children: [
        Text(
          'Everything in one private place.',
          style: Theme.of(context).textTheme.headlineSmall,
        ),
        const SizedBox(height: 14),
        const Card(
          child: ListTile(
            leading: Icon(Icons.apps_outlined),
            title: Text('Your services'),
            subtitle: Text(
              'You only see services assigned to your family account.',
            ),
          ),
        ),
        const Card(
          child: ListTile(
            leading: Icon(Icons.movie_filter_outlined),
            title: Text('Now available'),
            subtitle: Text('Find media that has become available for you.'),
          ),
        ),
        const Card(
          child: ListTile(
            leading: Icon(Icons.notifications_outlined),
            title: Text('Activity and updates'),
            subtitle: Text(
              'Keep track of your personal Homelab notifications and app releases.',
            ),
          ),
        ),
        const Card(
          child: ListTile(
            leading: Icon(Icons.lock_outline),
            title: Text('Your privacy'),
            subtitle: Text(
              'Your services remain protected by their own sign-in. Connor Homelab never stores those service passwords.',
            ),
          ),
        ),
        const SizedBox(height: 20),
        FilledButton(
          onPressed: () => Navigator.pop(context),
          child: const Text('Start exploring'),
        ),
      ],
    ),
  );
}
