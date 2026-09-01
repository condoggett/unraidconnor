import 'dart:convert';

import 'package:flutter/material.dart';
import 'package:http/http.dart' as http;
import 'package:supabase_flutter/supabase_flutter.dart';

import 'seerr_screen.dart';

class ProfileScreen extends StatefulWidget {
  const ProfileScreen({super.key});

  @override
  State<ProfileScreen> createState() => _ProfileScreenState();
}

class MaintenanceCenterScreen extends StatefulWidget {
  const MaintenanceCenterScreen({super.key, required this.admin});
  final bool admin;

  @override
  State<MaintenanceCenterScreen> createState() =>
      _MaintenanceCenterScreenState();
}

class _MaintenanceCenterScreenState extends State<MaintenanceCenterScreen> {
  final _client = Supabase.instance.client;
  bool _loading = true;
  String? _error;
  List<Map<String, dynamic>> _items = [];

  @override
  void initState() {
    super.initState();
    _load();
  }

  Future<void> _load() async {
    setState(() {
      _loading = true;
      _error = null;
    });
    try {
      final rows = widget.admin
          ? await _client
                .from('maintenance_notices')
                .select(
                  'id, active, title, message, starts_at, ends_at, created_at',
                )
                .order('created_at', ascending: false)
                .limit(30)
          : await _client
                .from('maintenance_notices')
                .select(
                  'id, active, title, message, starts_at, ends_at, created_at',
                )
                .eq('active', true)
                .order('created_at', ascending: false)
                .limit(30);
      _items = (rows as List).cast<Map<String, dynamic>>();
    } catch (_) {
      _error = 'Maintenance centre will be available after the V3 Supabase migration is applied.';
    } finally {
      if (mounted) setState(() => _loading = false);
    }
  }

  Future<void> _createNotice() async {
    final title = TextEditingController(text: 'Scheduled maintenance');
    final message = TextEditingController();
    final active = ValueNotifier(true);
    final saved = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Create maintenance notice'),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            TextField(
              controller: title,
              maxLength: 80,
              decoration: const InputDecoration(labelText: 'Title'),
            ),
            TextField(
              controller: message,
              maxLines: 3,
              maxLength: 240,
              decoration: const InputDecoration(
                labelText: 'What will be affected?',
              ),
            ),
            ValueListenableBuilder<bool>(
              valueListenable: active,
              builder: (_, value, _) => SwitchListTile(
                contentPadding: EdgeInsets.zero,
                title: const Text('Show banner now'),
                value: value,
                onChanged: (next) => active.value = next,
              ),
            ),
          ],
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: const Text('Cancel'),
          ),
          FilledButton(
            onPressed: () => Navigator.pop(context, true),
            child: const Text('Publish'),
          ),
        ],
      ),
    );
    if (saved != true) return;
    try {
      await _client.from('maintenance_notices').insert({
        'active': active.value,
        'title': title.text.trim(),
        'message': message.text.trim(),
      });
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Maintenance notice published.')),
        );
        _load();
      }
    } catch (_) {
      if (mounted)
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('Could not publish the maintenance notice.'),
          ),
        );
    } finally {
      title.dispose();
      message.dispose();
      active.dispose();
    }
  }

  @override
  Widget build(BuildContext context) => Scaffold(
    appBar: AppBar(
      title: const Text('Maintenance centre'),
      actions: [
        if (widget.admin)
          IconButton(
            onPressed: _createNotice,
            tooltip: 'Create notice',
            icon: const Icon(Icons.add_alert_outlined),
          ),
      ],
    ),
    body: _loading
        ? const Center(child: CircularProgressIndicator())
        : RefreshIndicator(
            onRefresh: _load,
            child: ListView(
              padding: const EdgeInsets.all(18),
              children: [
                Text(
                  widget.admin
                      ? 'Plan and review service maintenance.'
                      : 'Planned work that may affect your services.',
                  style: Theme.of(context).textTheme.titleMedium,
                ),
                const SizedBox(height: 14),
                if (_error != null)
                  Card(
                    child: Padding(
                      padding: const EdgeInsets.all(16),
                      child: Text(_error!),
                    ),
                  ),
                if (_items.isEmpty && _error == null)
                  const Card(
                    child: Padding(
                      padding: EdgeInsets.all(16),
                      child: Text('No maintenance is currently planned.'),
                    ),
                  ),
                ..._items.map(
                  (item) => Card(
                    color: item['active'] == true
                        ? const Color(0xff4a3518)
                        : null,
                    child: ListTile(
                      leading: Icon(
                        item['active'] == true
                            ? Icons.construction_outlined
                            : Icons.history,
                      ),
                      title: Text('${item['title']}'),
                      subtitle: Text('${item['message'] ?? ''}'),
                      trailing: item['active'] == true
                          ? const Chip(label: Text('Active'))
                          : const Text('Past'),
                    ),
                  ),
                ),
              ],
            ),
          ),
  );
}

class _ProfileScreenState extends State<ProfileScreen> {
  final _client = Supabase.instance.client;
  final _name = TextEditingController();
  bool _loading = true;
  bool _saving = false;
  String _theme = 'ocean';
  String _layout = 'standard';
  String _avatar = 'auto';
  bool _appLock = false;

  static const _avatars = <String, IconData>{
    'auto': Icons.account_circle_outlined,
    'home': Icons.home_outlined,
    'movie': Icons.movie_outlined,
    'game': Icons.sports_esports_outlined,
    'photo': Icons.photo_camera_outlined,
    'star': Icons.star_outline,
  };

  @override
  void initState() {
    super.initState();
    _load();
  }

  @override
  void dispose() {
    _name.dispose();
    super.dispose();
  }

  Future<void> _load() async {
    try {
      final user = _client.auth.currentUser!;
      final profile = await _client
          .from('profiles')
          .select('display_name')
          .eq('id', user.id)
          .maybeSingle();
      final settings = await _client
          .from('user_dashboard_settings')
          .select('theme, dashboard_layout, avatar_icon, app_lock_enabled')
          .eq('user_id', user.id)
          .maybeSingle();
      _name.text = '${profile?['display_name'] ?? user.email ?? ''}';
      _theme = '${settings?['theme'] ?? _theme}';
      _layout = '${settings?['dashboard_layout'] ?? _layout}';
      _avatar = '${settings?['avatar_icon'] ?? _avatar}';
      _appLock = settings?['app_lock_enabled'] == true;
    } catch (_) {
      // The V3 migration may not be live yet; the save message explains it.
    } finally {
      if (mounted) setState(() => _loading = false);
    }
  }

  Future<void> _save() async {
    final name = _name.text.trim();
    if (name.isEmpty) return;
    setState(() => _saving = true);
    try {
      final user = _client.auth.currentUser!;
      await _client.rpc(
        'update_my_profile',
        params: {'new_display_name': name},
      );
      await _client.from('user_dashboard_settings').upsert({
        'user_id': user.id,
        'theme': _theme,
        'dashboard_layout': _layout,
        'avatar_icon': _avatar,
        'app_lock_enabled': _appLock,
        'updated_at': DateTime.now().toUtc().toIso8601String(),
      });
      if (!mounted) return;
      Navigator.pop(context, true);
    } catch (_) {
      if (mounted)
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text(
              'Your V3 profile needs the Supabase migration before it can be saved.',
            ),
          ),
        );
    } finally {
      if (mounted) setState(() => _saving = false);
    }
  }

  @override
  Widget build(BuildContext context) => Scaffold(
    appBar: AppBar(title: const Text('Your profile')),
    body: _loading
        ? const Center(child: CircularProgressIndicator())
        : ListView(
            padding: const EdgeInsets.all(18),
            children: [
              Text(
                'Make Connor Homelab feel like yours.',
                style: Theme.of(context).textTheme.titleMedium,
              ),
              const SizedBox(height: 18),
              TextField(
                controller: _name,
                maxLength: 40,
                decoration: const InputDecoration(
                  labelText: 'Display name',
                  prefixIcon: Icon(Icons.person_outline),
                ),
              ),
              const SizedBox(height: 12),
              Text(
                'Profile icon',
                style: Theme.of(context).textTheme.titleSmall,
              ),
              const SizedBox(height: 8),
              Wrap(
                spacing: 8,
                runSpacing: 8,
                children: _avatars.entries
                    .map(
                      (entry) => ChoiceChip(
                        label: Icon(entry.value),
                        selected: _avatar == entry.key,
                        onSelected: (_) => setState(() => _avatar = entry.key),
                      ),
                    )
                    .toList(),
              ),
              const SizedBox(height: 20),
              DropdownButtonFormField<String>(
                initialValue: _theme,
                decoration: const InputDecoration(labelText: 'Colour theme'),
                items: const [
                  DropdownMenuItem(value: 'ocean', child: Text('Ocean')),
                  DropdownMenuItem(value: 'forest', child: Text('Forest')),
                  DropdownMenuItem(value: 'violet', child: Text('Violet')),
                  DropdownMenuItem(value: 'sunset', child: Text('Sunset')),
                ],
                onChanged: (value) => setState(() => _theme = value ?? _theme),
              ),
              const SizedBox(height: 12),
              DropdownButtonFormField<String>(
                initialValue: _layout,
                decoration: const InputDecoration(
                  labelText: 'Dashboard layout',
                ),
                items: const [
                  DropdownMenuItem(value: 'standard', child: Text('Standard')),
                  DropdownMenuItem(value: 'compact', child: Text('Compact')),
                  DropdownMenuItem(
                    value: 'media_first',
                    child: Text('Media first'),
                  ),
                ],
                onChanged: (value) =>
                    setState(() => _layout = value ?? _layout),
              ),
              const SizedBox(height: 8),
              SwitchListTile(
                contentPadding: EdgeInsets.zero,
                title: const Text('Lock when I leave the app'),
                subtitle: const Text(
                  'Use your phone fingerprint, face or PIN on return.',
                ),
                value: _appLock,
                onChanged: (value) => setState(() => _appLock = value),
              ),
              const SizedBox(height: 22),
              FilledButton.icon(
                onPressed: _saving ? null : _save,
                icon: const Icon(Icons.save_outlined),
                label: const Text('Save my profile'),
              ),
            ],
          ),
  );
}

class ImmichHighlightsScreen extends StatefulWidget {
  const ImmichHighlightsScreen({super.key});
  @override
  State<ImmichHighlightsScreen> createState() => _ImmichHighlightsScreenState();
}

class _ImmichHighlightsScreenState extends State<ImmichHighlightsScreen> {
  final _client = Supabase.instance.client;
  List<Map<String, dynamic>> _items = [];
  bool _loading = true;
  @override
  void initState() {
    super.initState();
    _load();
  }

  Future<void> _load() async {
    try {
      final rows = await _client
          .from('notifications')
          .select('title, body, created_at, data')
          .eq('category', 'app')
          .order('created_at', ascending: false)
          .limit(100);
      _items = (rows as List)
          .cast<Map<String, dynamic>>()
          .where(
            (row) => ('${row['title']} ${row['body']} ${row['data']}')
                .toLowerCase()
                .contains('immich'),
          )
          .toList();
    } catch (_) {
    } finally {
      if (mounted) setState(() => _loading = false);
    }
  }

  @override
  Widget build(BuildContext context) => Scaffold(
    appBar: AppBar(title: const Text('Immich highlights')),
    body: _loading
        ? const Center(child: CircularProgressIndicator())
        : ListView(
            padding: const EdgeInsets.all(18),
            children: [
              Text(
                'Recent photo moments',
                style: Theme.of(context).textTheme.headlineSmall,
              ),
              const SizedBox(height: 8),
              const Text(
                'Your personal Immich events appear here. Photo thumbnails need a read-only Immich integration and are never loaded with a key in the app.',
              ),
              const SizedBox(height: 14),
              if (_items.isEmpty)
                const Card(
                  child: Padding(
                    padding: EdgeInsets.all(16),
                    child: Text(
                      'No Immich highlights yet. Open Immich to browse your library.',
                    ),
                  ),
                ),
              ..._items.map(
                (item) => Card(
                  child: ListTile(
                    leading: const Icon(Icons.photo_library_outlined),
                    title: Text('${item['title']}'),
                    subtitle: Text('${item['body'] ?? ''}'),
                  ),
                ),
              ),
              const SizedBox(height: 12),
              FilledButton.icon(
                onPressed: () => Navigator.of(context).push(
                  MaterialPageRoute<void>(
                    builder: (_) => const HomelabWebAppScreen(
                      title: 'Immich',
                      url: 'https://photos.conhomelab.uk',
                    ),
                  ),
                ),
                icon: const Icon(Icons.open_in_new),
                label: const Text('Open Immich'),
              ),
            ],
          ),
  );
}

class FamilyActivityScreen extends StatefulWidget {
  const FamilyActivityScreen({super.key});
  @override
  State<FamilyActivityScreen> createState() => _FamilyActivityScreenState();
}

class _FamilyActivityScreenState extends State<FamilyActivityScreen> {
  final _client = Supabase.instance.client;
  List<Map<String, dynamic>> _items = [];
  bool _loading = true;
  @override
  void initState() {
    super.initState();
    _load();
  }

  Future<void> _load() async {
    try {
      final rows = await _client
          .from('notifications')
          .select('title, body, category, created_at')
          .order('created_at', ascending: false)
          .limit(100);
      _items = (rows as List).cast<Map<String, dynamic>>();
    } catch (_) {
    } finally {
      if (mounted) setState(() => _loading = false);
    }
  }

  @override
  Widget build(BuildContext context) => Scaffold(
    appBar: AppBar(title: const Text('Your activity')),
    body: _loading
        ? const Center(child: CircularProgressIndicator())
        : RefreshIndicator(
            onRefresh: _load,
            child: ListView(
              padding: const EdgeInsets.all(12),
              children: _items.isEmpty
                  ? [
                      const SizedBox(height: 160),
                      const Center(child: Text('No personal activity yet.')),
                    ]
                  : _items
                        .map(
                          (item) => Card(
                            child: ListTile(
                              leading: const Icon(Icons.bolt_outlined),
                              title: Text('${item['title']}'),
                              subtitle: Text(
                                '${item['body'] ?? ''}\n${item['created_at'] ?? ''}',
                              ),
                              isThreeLine: true,
                            ),
                          ),
                        )
                        .toList(),
            ),
          ),
  );
}

class DiagnosticsScreen extends StatefulWidget {
  const DiagnosticsScreen({super.key});
  @override
  State<DiagnosticsScreen> createState() => _DiagnosticsScreenState();
}

class _DiagnosticsScreenState extends State<DiagnosticsScreen> {
  String _message = 'Checking connection…';
  @override
  void initState() {
    super.initState();
    _check();
  }

  Future<void> _check() async {
    try {
      final response = await http
          .get(Uri.parse('https://conhomelab.uk/api/status'))
          .timeout(const Duration(seconds: 8));
      final status = jsonDecode(response.body) as Map<String, dynamic>;
      if (mounted)
        setState(
          () => _message = status['online'] == true
              ? 'Homelab status bridge is online.'
              : 'The tunnel is reachable but the status bridge is unavailable.',
        );
    } catch (_) {
      if (mounted)
        setState(
          () => _message = 'Cannot reach Connor Homelab. Check your internet connection, Cloudflare Access session, then the homelab tunnel.',
        );
    }
  }

  @override
  Widget build(BuildContext context) => Scaffold(
    appBar: AppBar(title: const Text('Connection diagnostics')),
    body: ListView(
      padding: const EdgeInsets.all(18),
      children: [
        const Icon(Icons.monitor_heart_outlined, size: 56),
        const SizedBox(height: 16),
        Text(_message, style: Theme.of(context).textTheme.titleMedium),
        const SizedBox(height: 18),
        const Card(
          child: ListTile(
            title: Text('How access works'),
            subtitle: Text(
              'The app keeps your Supabase sign-in and in-app Cloudflare session. Individual services keep their own login where required.',
            ),
          ),
        ),
        OutlinedButton.icon(
          onPressed: _check,
          icon: const Icon(Icons.refresh),
          label: const Text('Run check again'),
        ),
      ],
    ),
  );
}
