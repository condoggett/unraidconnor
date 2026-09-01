import 'dart:convert';

import 'package:flutter/material.dart';

// Personalisation, maintenance scheduling, diagnostics and private activity
// screens introduced in V3. Database writes in this file rely on Supabase RLS.
import 'package:http/http.dart' as http;
import 'package:package_info_plus/package_info_plus.dart';
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
      if (!widget.admin) {
        _items = _items.where(_noticeIsLive).toList();
      }
    } catch (_) {
      _error = 'Maintenance centre will be available after the V3 Supabase migration is applied.';
    } finally {
      if (mounted) setState(() => _loading = false);
    }
  }

  bool _noticeIsLive(Map<String, dynamic> notice) {
    if (notice['active'] != true) return false;
    final now = DateTime.now().toUtc();
    final starts = DateTime.tryParse('${notice['starts_at'] ?? ''}')?.toUtc();
    final ends = DateTime.tryParse('${notice['ends_at'] ?? ''}')?.toUtc();
    return (starts == null || !now.isBefore(starts)) &&
        (ends == null || now.isBefore(ends));
  }

  String _noticeState(Map<String, dynamic> notice) {
    if (notice['active'] != true) return 'Draft';
    final now = DateTime.now().toUtc();
    final starts = DateTime.tryParse('${notice['starts_at'] ?? ''}')?.toUtc();
    final ends = DateTime.tryParse('${notice['ends_at'] ?? ''}')?.toUtc();
    if (starts != null && now.isBefore(starts)) return 'Scheduled';
    if (ends != null && !now.isBefore(ends)) return 'Ended';
    return 'Live';
  }

  String _noticeSummary(Map<String, dynamic> notice) {
    var text = '${notice['message'] ?? ''}';
    final starts = DateTime.tryParse('${notice['starts_at'] ?? ''}');
    final ends = DateTime.tryParse('${notice['ends_at'] ?? ''}');
    if (starts != null) text += '\nStarts ${_dateTime(starts, '')}';
    if (ends != null)
      text += '${starts == null ? '\n' : ' · '}Ends ${_dateTime(ends, '')}';
    return text;
  }

  String _dateTime(DateTime? value, String fallback) {
    if (value == null) return fallback;
    final local = value.toLocal();
    return '${local.day.toString().padLeft(2, '0')}/${local.month.toString().padLeft(2, '0')} ${local.hour.toString().padLeft(2, '0')}:${local.minute.toString().padLeft(2, '0')}';
  }

  Future<DateTime?> _pickDateTime(DateTime? initial) async {
    final seed = initial?.toLocal() ?? DateTime.now();
    final date = await showDatePicker(
      context: context,
      firstDate: DateTime.now().subtract(const Duration(days: 1)),
      lastDate: DateTime.now().add(const Duration(days: 730)),
      initialDate: seed,
    );
    if (date == null || !mounted) return null;
    final time = await showTimePicker(
      context: context,
      initialTime: TimeOfDay.fromDateTime(seed),
    );
    if (time == null) return null;
    return DateTime(date.year, date.month, date.day, time.hour, time.minute);
  }

  Future<void> _createNotice() async {
    final title = TextEditingController(text: 'Scheduled maintenance');
    final message = TextEditingController();
    final active = ValueNotifier(true);
    DateTime? startsAt;
    DateTime? endsAt;
    final saved = await showDialog<bool>(
      context: context,
      builder: (context) => StatefulBuilder(
        builder: (context, setDialogState) => AlertDialog(
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
              ListTile(
                contentPadding: EdgeInsets.zero,
                leading: const Icon(Icons.schedule_outlined),
                title: const Text('Start time'),
                subtitle: Text(_dateTime(startsAt, 'Start immediately')),
                onTap: () async {
                  final value = await _pickDateTime(startsAt);
                  if (value != null) setDialogState(() => startsAt = value);
                },
              ),
              ListTile(
                contentPadding: EdgeInsets.zero,
                leading: const Icon(Icons.event_busy_outlined),
                title: const Text('End time'),
                subtitle: Text(_dateTime(endsAt, 'Hide manually')),
                trailing: endsAt == null
                    ? null
                    : IconButton(
                        icon: const Icon(Icons.clear),
                        onPressed: () => setDialogState(() => endsAt = null),
                      ),
                onTap: () async {
                  final value = await _pickDateTime(endsAt ?? startsAt);
                  if (value != null) setDialogState(() => endsAt = value);
                },
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
      ),
    );
    if (saved != true) return;
    try {
      await _client.from('maintenance_notices').insert({
        'active': active.value,
        'title': title.text.trim(),
        'message': message.text.trim(),
        'starts_at': startsAt?.toUtc().toIso8601String(),
        'ends_at': endsAt?.toUtc().toIso8601String(),
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
                ..._items.map((item) {
                  final state = _noticeState(item);
                  return Card(
                    color: state == 'Live' ? const Color(0xff4a3518) : null,
                    child: ListTile(
                      leading: Icon(
                        state == 'Live'
                            ? Icons.construction_outlined
                            : state == 'Scheduled'
                            ? Icons.schedule_outlined
                            : Icons.history,
                      ),
                      title: Text('${item['title']}'),
                      subtitle: Text(_noticeSummary(item)),
                      isThreeLine: item['starts_at'] != null,
                      trailing: Chip(label: Text(state)),
                    ),
                  );
                }),
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

class UpdateCenterScreen extends StatefulWidget {
  const UpdateCenterScreen({super.key, required this.onCheckForUpdates});
  final Future<void> Function() onCheckForUpdates;

  @override
  State<UpdateCenterScreen> createState() => _UpdateCenterScreenState();
}

class _UpdateCenterScreenState extends State<UpdateCenterScreen> {
  String _installed = 'Checking…';
  String? _latest;
  String? _notes;
  bool _loading = true;

  @override
  void initState() {
    super.initState();
    _load();
  }

  Future<void> _load() async {
    setState(() => _loading = true);
    try {
      final info = await PackageInfo.fromPlatform();
      final response = await http
          .get(
            Uri.parse(
              'https://conhomelab.uk/app-update.json?check=${DateTime.now().millisecondsSinceEpoch}',
            ),
          )
          .timeout(const Duration(seconds: 8));
      final release = response.statusCode == 200
          ? jsonDecode(response.body) as Map<String, dynamic>
          : <String, dynamic>{};
      _installed = '${info.version} (${info.buildNumber})';
      _latest = release['version']?.toString();
      _notes = release['notes']?.toString();
    } catch (_) {
      _installed = 'Unavailable';
      _notes = 'Could not check the live release manifest. Use connection diagnostics and try again.';
    } finally {
      if (mounted) setState(() => _loading = false);
    }
  }

  @override
  Widget build(BuildContext context) => Scaffold(
    appBar: AppBar(title: const Text('Update centre')),
    body: _loading
        ? const Center(child: CircularProgressIndicator())
        : RefreshIndicator(
            onRefresh: _load,
            child: ListView(
              padding: const EdgeInsets.all(18),
              children: [
                Text(
                  'Connor Homelab updates',
                  style: Theme.of(context).textTheme.headlineSmall,
                ),
                const SizedBox(height: 12),
                Card(
                  child: ListTile(
                    leading: const Icon(Icons.phone_android_outlined),
                    title: const Text('Installed version'),
                    subtitle: Text(_installed),
                  ),
                ),
                Card(
                  child: ListTile(
                    leading: const Icon(Icons.new_releases_outlined),
                    title: const Text('Latest published version'),
                    subtitle: Text(
                      _latest ?? 'No live release manifest found.',
                    ),
                  ),
                ),
                if (_notes != null)
                  Card(
                    child: Padding(
                      padding: const EdgeInsets.all(16),
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            'Release notes',
                            style: Theme.of(context).textTheme.titleMedium,
                          ),
                          const SizedBox(height: 8),
                          Text(_notes!),
                        ],
                      ),
                    ),
                  ),
                const SizedBox(height: 14),
                FilledButton.icon(
                  onPressed: widget.onCheckForUpdates,
                  icon: const Icon(Icons.system_update_outlined),
                  label: const Text('Check and install update'),
                ),
                const SizedBox(height: 8),
                const Text(
                  'Every update is downloaded from the Connor Homelab GitHub release and checked against its published security hash before Android opens the installer.',
                  textAlign: TextAlign.center,
                ),
              ],
            ),
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
    setState(() => _loading = true);
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

  String _date(Object? value) {
    final date = DateTime.tryParse('${value ?? ''}')?.toLocal();
    if (date == null) return '';
    return '${date.day.toString().padLeft(2, '0')}/${date.month.toString().padLeft(2, '0')} ${date.hour.toString().padLeft(2, '0')}:${date.minute.toString().padLeft(2, '0')}';
  }

  @override
  Widget build(BuildContext context) => Scaffold(
    appBar: AppBar(title: const Text('Immich highlights')),
    body: _loading
        ? const Center(child: CircularProgressIndicator())
        : RefreshIndicator(
            onRefresh: _load,
            child: ListView(
              padding: const EdgeInsets.all(18),
              children: [
                Text(
                  'Recent photo moments',
                  style: Theme.of(context).textTheme.headlineSmall,
                ),
                const SizedBox(height: 8),
                const Text(
                  'Your personal Immich moments appear here. The app never embeds an Immich API key; richer private thumbnails can be added later with a read-only server-side connection.',
                ),
                const SizedBox(height: 14),
                Card(
                  child: ListTile(
                    leading: const CircleAvatar(
                      child: Icon(Icons.auto_awesome_outlined),
                    ),
                    title: Text(
                      '${_items.length} recent photo moment${_items.length == 1 ? '' : 's'}',
                    ),
                    subtitle: const Text(
                      'Pull down to refresh your private photo activity.',
                    ),
                  ),
                ),
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
                      subtitle: Text(
                        '${item['body'] ?? ''}${_date(item['created_at']).isEmpty ? '' : '\n${_date(item['created_at'])}'}',
                      ),
                      isThreeLine: _date(item['created_at']).isNotEmpty,
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
  bool _loading = true;
  List<_DiagnosticItem> _checks = [];
  @override
  void initState() {
    super.initState();
    _check();
  }

  Future<void> _check() async {
    setState(() => _loading = true);
    final checks = <_DiagnosticItem>[];
    checks.add(
      _DiagnosticItem(
        'App sign-in',
        Supabase.instance.client.auth.currentSession != null,
        'Your Supabase family account is signed in.',
      ),
    );
    try {
      final portal = await http
          .get(Uri.parse('https://conhomelab.uk'))
          .timeout(const Duration(seconds: 8));
      checks.add(
        _DiagnosticItem(
          'Portal connection',
          portal.statusCode < 500,
          portal.statusCode < 500
              ? 'Connor Homelab portal is reachable.'
              : 'The portal returned ${portal.statusCode}.',
        ),
      );
    } catch (_) {
      checks.add(
        const _DiagnosticItem(
          'Portal connection',
          false,
          'Cannot reach conhomelab.uk. Check your internet connection.',
        ),
      );
    }
    try {
      final response = await http
          .get(Uri.parse('https://conhomelab.uk/api/status'))
          .timeout(const Duration(seconds: 8));
      final status = jsonDecode(response.body) as Map<String, dynamic>;
      final online = status['online'] == true;
      checks.add(
        _DiagnosticItem(
          'Homelab tunnel and status bridge',
          online,
          online ? 'Unraid status bridge is online.' : 'The portal is reachable, but the Unraid status bridge is unavailable.',
        ),
      );
    } catch (_) {
      checks.add(
        const _DiagnosticItem(
          'Homelab tunnel and status bridge',
          false,
          'Cannot reach the status bridge. Sign in to Cloudflare Access again if prompted, then check the tunnel.',
        ),
      );
    }
    if (mounted)
      setState(() {
        _checks = checks;
        _loading = false;
      });
  }

  @override
  Widget build(BuildContext context) => Scaffold(
    appBar: AppBar(title: const Text('Connection diagnostics')),
    body: _loading
        ? const Center(child: CircularProgressIndicator())
        : ListView(
            padding: const EdgeInsets.all(18),
            children: [
              const Icon(Icons.monitor_heart_outlined, size: 56),
              const SizedBox(height: 16),
              Text(
                _checks.every((item) => item.ok)
                    ? 'Everything looks healthy.'
                    : 'One or more checks need attention.',
                style: Theme.of(context).textTheme.titleMedium,
              ),
              const SizedBox(height: 18),
              ..._checks.map(
                (item) => Card(
                  child: ListTile(
                    leading: Icon(
                      item.ok
                          ? Icons.check_circle_outline
                          : Icons.error_outline,
                      color: item.ok ? const Color(0xff66e59a) : Colors.amber,
                    ),
                    title: Text(item.title),
                    subtitle: Text(item.detail),
                  ),
                ),
              ),
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

class _DiagnosticItem {
  const _DiagnosticItem(this.title, this.ok, this.detail);
  final String title;
  final bool ok;
  final String detail;
}

/// Lets a person reorder the service cards on their own dashboard. The order is
/// stored locally under their signed-in user ID, never shared with other users.
class DashboardBuilderScreen extends StatefulWidget {
  const DashboardBuilderScreen({
    super.key,
    required this.apps,
    required this.initialOrder,
  });
  final List<Map<String, dynamic>> apps;
  final List<String> initialOrder;

  @override
  State<DashboardBuilderScreen> createState() => _DashboardBuilderScreenState();
}

/// Plain-language support and privacy explanation for family members. It avoids
/// exposing technical tokens, URLs or administrative data inside the app.
class HelpPrivacyScreen extends StatelessWidget {
  const HelpPrivacyScreen({super.key});

  @override
  Widget build(BuildContext context) => Scaffold(
    appBar: AppBar(title: const Text('Help & privacy')),
    body: ListView(
      padding: const EdgeInsets.all(18),
      children: const [
        Card(
          child: ListTile(
            leading: Icon(Icons.apps_outlined),
            title: Text('Your services'),
            subtitle: Text(
              'Only services assigned to your account appear. Ask an admin if something is missing.',
            ),
          ),
        ),
        Card(
          child: ListTile(
            leading: Icon(Icons.movie_filter_outlined),
            title: Text('Requesting media'),
            subtitle: Text(
              'Open Seerr, request a film or series, then check Now Available when it has been added.',
            ),
          ),
        ),
        Card(
          child: ListTile(
            leading: Icon(Icons.lock_outline),
            title: Text('What stays on this phone'),
            subtitle: Text(
              'Your app session, personal card layout/style, and a last-known Unraid status reading may be stored locally. No fingerprint data leaves your phone.',
            ),
          ),
        ),
        Card(
          child: ListTile(
            leading: Icon(Icons.wifi_off_outlined),
            title: Text('When something is unavailable'),
            subtitle: Text(
              'Use Connection diagnostics. It distinguishes your sign-in, the portal and the Unraid status bridge.',
            ),
          ),
        ),
        Card(
          child: ListTile(
            leading: Icon(Icons.system_update_outlined),
            title: Text('Updates'),
            subtitle: Text(
              'The app checks signed releases on launch. You can also choose Check for updates from the menu.',
            ),
          ),
        ),
      ],
    ),
  );
}

class _DashboardBuilderScreenState extends State<DashboardBuilderScreen> {
  late final List<Map<String, dynamic>> _apps;

  @override
  void initState() {
    super.initState();
    _apps = [...widget.apps]
      ..sort((left, right) {
        final a = widget.initialOrder.indexOf('${left['id']}');
        final b = widget.initialOrder.indexOf('${right['id']}');
        return (a < 0 ? 9999 : a).compareTo(b < 0 ? 9999 : b);
      });
  }

  @override
  Widget build(BuildContext context) => Scaffold(
    appBar: AppBar(
      title: const Text('Arrange dashboard'),
      actions: [
        TextButton(
          onPressed: () => Navigator.pop(
            context,
            _apps.map((app) => '${app['id']}').toList(),
          ),
          child: const Text('Save'),
        ),
      ],
    ),
    body: Column(
      children: [
        const Padding(
          padding: EdgeInsets.all(18),
          child: Text(
            'Hold and drag services into the order you want to see them.',
          ),
        ),
        Expanded(
          child: ReorderableListView.builder(
            padding: const EdgeInsets.symmetric(horizontal: 18),
            itemCount: _apps.length,
            onReorder: (oldIndex, newIndex) {
              setState(() {
                if (newIndex > oldIndex) newIndex -= 1;
                final app = _apps.removeAt(oldIndex);
                _apps.insert(newIndex, app);
              });
            },
            itemBuilder: (_, index) {
              final app = _apps[index];
              return Card(
                key: ValueKey(app['id']),
                child: ListTile(
                  leading: CircleAvatar(child: Text('${app['icon'] ?? '•'}')),
                  title: Text('${app['name']}'),
                  subtitle: const Text('Drag to move'),
                  trailing: const Icon(Icons.drag_handle),
                ),
              );
            },
          ),
        ),
      ],
    ),
  );
}

/// Admin-only editor for the existing user_app_access table. Supabase RLS is
/// the final authority: a non-admin cannot read or change these records.
class AdminFamilyAccessScreen extends StatefulWidget {
  const AdminFamilyAccessScreen({super.key});

  @override
  State<AdminFamilyAccessScreen> createState() =>
      _AdminFamilyAccessScreenState();
}

class _AdminFamilyAccessScreenState extends State<AdminFamilyAccessScreen> {
  final _client = Supabase.instance.client;
  bool _loading = true;
  String? _error;
  List<Map<String, dynamic>> _people = [];
  List<Map<String, dynamic>> _apps = [];
  Set<String> _access = {};
  String? _selectedUserId;

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
      final people = await _client
          .from('profiles')
          .select('id, display_name, email, role')
          .order('display_name');
      final apps = await _client
          .from('apps')
          .select('id, name, description, icon, sort_order')
          .eq('enabled', true)
          .order('sort_order');
      _people = (people as List).cast<Map<String, dynamic>>();
      _apps = (apps as List).cast<Map<String, dynamic>>();
      _selectedUserId ??= _people.isEmpty
          ? null
          : _people.first['id'] as String;
      await _loadAccess();
    } catch (_) {
      _error = 'This account is not allowed to manage family access.';
    } finally {
      if (mounted) setState(() => _loading = false);
    }
  }

  Future<void> _loadAccess() async {
    final userId = _selectedUserId;
    if (userId == null) return;
    final rows = await _client
        .from('user_app_access')
        .select('app_id')
        .eq('user_id', userId);
    _access = (rows as List).map((row) => '${row['app_id']}').toSet();
  }

  Future<void> _toggle(Map<String, dynamic> app, bool grant) async {
    final userId = _selectedUserId;
    if (userId == null) return;
    final appId = app['id'] as String;
    setState(() {
      if (grant) {
        _access.add(appId);
      } else {
        _access.remove(appId);
      }
    });
    try {
      if (grant) {
        await _client.from('user_app_access').upsert({
          'user_id': userId,
          'app_id': appId,
        });
      } else {
        await _client
            .from('user_app_access')
            .delete()
            .eq('user_id', userId)
            .eq('app_id', appId);
      }
    } catch (_) {
      await _loadAccess();
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Access change could not be saved.')),
        );
      }
    }
  }

  @override
  Widget build(BuildContext context) => Scaffold(
    appBar: AppBar(title: const Text('Manage family access')),
    body: _loading
        ? const Center(child: CircularProgressIndicator())
        : _error != null
        ? Center(
            child: Padding(
              padding: const EdgeInsets.all(24),
              child: Text(_error!),
            ),
          )
        : ListView(
            padding: const EdgeInsets.all(18),
            children: [
              const Text(
                'Choose a family member, then grant only the services they should see. These changes are applied immediately.',
              ),
              const SizedBox(height: 16),
              DropdownButtonFormField<String>(
                value: _selectedUserId,
                decoration: const InputDecoration(labelText: 'Family member'),
                items: _people
                    .map(
                      (person) => DropdownMenuItem(
                        value: person['id'] as String,
                        child: Text(
                          '${person['display_name'] ?? person['email']}${person['role'] == 'admin' ? ' (admin)' : ''}',
                        ),
                      ),
                    )
                    .toList(),
                onChanged: (value) async {
                  setState(() => _selectedUserId = value);
                  await _loadAccess();
                  if (mounted) setState(() {});
                },
              ),
              const SizedBox(height: 18),
              ..._apps.map((app) {
                final granted = _access.contains(app['id']);
                return Card(
                  child: SwitchListTile(
                    secondary: CircleAvatar(
                      child: Text('${app['icon'] ?? '•'}'),
                    ),
                    title: Text(app['name'] as String),
                    subtitle: Text('${app['description'] ?? ''}'),
                    value: granted,
                    onChanged: (value) => _toggle(app, value),
                  ),
                );
              }),
            ],
          ),
  );
}
