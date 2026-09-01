import 'package:flutter/material.dart';

// Family-facing notification history, media availability and release notes.
// Keep notification routing itself in main.dart so taps work before a screen is
// open; this file only renders the destination views.
import 'package:supabase_flutter/supabase_flutter.dart';

class NotificationSettingsScreen extends StatefulWidget {
  const NotificationSettingsScreen({super.key});

  @override
  State<NotificationSettingsScreen> createState() =>
      _NotificationSettingsScreenState();
}

class _NotificationSettingsScreenState
    extends State<NotificationSettingsScreen> {
  final _client = Supabase.instance.client;
  bool _loading = true;
  bool _saving = false;
  bool _unraid = true;
  bool _homeAssistant = true;
  bool _appServices = true;
  bool _appUpdates = true;
  bool _quietHours = false;
  TimeOfDay _quietStart = const TimeOfDay(hour: 22, minute: 0);
  TimeOfDay _quietEnd = const TimeOfDay(hour: 7, minute: 0);

  @override
  void initState() {
    super.initState();
    _load();
  }

  TimeOfDay _time(String? value, TimeOfDay fallback) {
    final parts = value?.split(':');
    if (parts == null || parts.length < 2) return fallback;
    return TimeOfDay(
      hour: int.tryParse(parts[0]) ?? fallback.hour,
      minute: int.tryParse(parts[1]) ?? fallback.minute,
    );
  }

  String _format(TimeOfDay value) =>
      '${value.hour.toString().padLeft(2, '0')}:${value.minute.toString().padLeft(2, '0')}:00';

  Future<void> _load() async {
    try {
      final row = await _client
          .from('notification_preferences')
          .select()
          .eq('user_id', _client.auth.currentUser!.id)
          .maybeSingle();
      if (row != null && mounted) {
        setState(() {
          _unraid = row['unraid_health'] as bool? ?? true;
          _homeAssistant = row['home_assistant'] as bool? ?? true;
          _appServices = row['app_services'] as bool? ?? true;
          _appUpdates = row['app_updates'] as bool? ?? true;
          _quietHours = row['quiet_hours_enabled'] as bool? ?? false;
          _quietStart = _time(row['quiet_start'] as String?, _quietStart);
          _quietEnd = _time(row['quiet_end'] as String?, _quietEnd);
        });
      }
    } catch (_) {
      // Defaults are useful before a newly signed-in user has saved settings.
    } finally {
      if (mounted) setState(() => _loading = false);
    }
  }

  Future<void> _pickTime(bool start) async {
    final value = await showTimePicker(
      context: context,
      initialTime: start ? _quietStart : _quietEnd,
    );
    if (value != null && mounted)
      setState(() {
        if (start) {
          _quietStart = value;
        } else {
          _quietEnd = value;
        }
      });
  }

  Future<void> _save() async {
    setState(() => _saving = true);
    try {
      await _client.from('notification_preferences').upsert({
        'user_id': _client.auth.currentUser!.id,
        'unraid_health': _unraid,
        'home_assistant': _homeAssistant,
        'app_services': _appServices,
        'app_updates': _appUpdates,
        'quiet_hours_enabled': _quietHours,
        'quiet_start': _format(_quietStart),
        'quiet_end': _format(_quietEnd),
        'timezone': 'Europe/London',
        'updated_at': DateTime.now().toUtc().toIso8601String(),
      });
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Notification preferences saved.')),
        );
        Navigator.pop(context);
      }
    } catch (error) {
      if (mounted)
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Could not save preferences: $error')),
        );
    } finally {
      if (mounted) setState(() => _saving = false);
    }
  }

  @override
  Widget build(BuildContext context) => Scaffold(
    appBar: AppBar(title: const Text('Notification settings')),
    body: _loading
        ? const Center(child: CircularProgressIndicator())
        : ListView(
            padding: const EdgeInsets.all(18),
            children: [
              Text(
                'Choose what reaches this phone.',
                style: Theme.of(context).textTheme.titleMedium,
              ),
              const SizedBox(height: 10),
              SwitchListTile.adaptive(
                value: _unraid,
                onChanged: (value) => setState(() => _unraid = value),
                title: const Text('Unraid health'),
                subtitle: const Text(
                  'Server recovery, stopped containers and high resource use.',
                ),
              ),
              SwitchListTile.adaptive(
                value: _homeAssistant,
                onChanged: (value) => setState(() => _homeAssistant = value),
                title: const Text('Home Assistant'),
                subtitle: const Text(
                  'The home alerts you choose to send from Home Assistant.',
                ),
              ),
              SwitchListTile.adaptive(
                value: _appServices,
                onChanged: (value) => setState(() => _appServices = value),
                title: const Text('Homelab app services'),
                subtitle: const Text(
                  'Alerts sent by services such as Seerr, media tools, and future connected apps.',
                ),
              ),
              SwitchListTile.adaptive(
                value: _appUpdates,
                onChanged: (value) => setState(() => _appUpdates = value),
                title: const Text('App updates'),
                subtitle: const Text(
                  'Let me know when a new Connor Homelab app version is published.',
                ),
              ),
              const Divider(height: 30),
              SwitchListTile.adaptive(
                value: _quietHours,
                onChanged: (value) => setState(() => _quietHours = value),
                title: const Text('Quiet hours'),
                subtitle: const Text(
                  'Non-critical alerts wait until your quiet hours end.',
                ),
              ),
              if (_quietHours)
                Card(
                  child: Column(
                    children: [
                      ListTile(
                        title: const Text('Quiet hours start'),
                        trailing: Text(_quietStart.format(context)),
                        onTap: () => _pickTime(true),
                      ),
                      ListTile(
                        title: const Text('Quiet hours end'),
                        trailing: Text(_quietEnd.format(context)),
                        onTap: () => _pickTime(false),
                      ),
                    ],
                  ),
                ),
              const SizedBox(height: 24),
              FilledButton.icon(
                onPressed: _saving ? null : _save,
                icon: const Icon(Icons.save),
                label: Text(_saving ? 'Saving…' : 'Save preferences'),
              ),
            ],
          ),
  );
}

class NotificationHistoryScreen extends StatefulWidget {
  const NotificationHistoryScreen({super.key});

  @override
  State<NotificationHistoryScreen> createState() =>
      _NotificationHistoryScreenState();
}

class NowAvailableScreen extends StatefulWidget {
  const NowAvailableScreen({super.key});

  @override
  State<NowAvailableScreen> createState() => _NowAvailableScreenState();
}

class _NowAvailableScreenState extends State<NowAvailableScreen> {
  final _client = Supabase.instance.client;
  bool _loading = true;
  List<Map<String, dynamic>> _items = [];

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
      final items = (rows as List).cast<Map<String, dynamic>>().where((item) {
        final text = '${item['title']} ${item['body']} ${item['data']}';
        return text.toLowerCase().contains('available');
      }).toList();
      if (mounted) setState(() => _items = items);
    } finally {
      if (mounted) setState(() => _loading = false);
    }
  }

  @override
  Widget build(BuildContext context) => Scaffold(
    appBar: AppBar(title: const Text('Now available')),
    body: _loading
        ? const Center(child: CircularProgressIndicator())
        : _items.isEmpty
        ? const Center(
            child: Padding(
              padding: EdgeInsets.all(24),
              child: Text(
                'Nothing has been marked available yet. When Seerr sends an availability notification, it will appear here.',
              ),
            ),
          )
        : ListView.separated(
            padding: const EdgeInsets.all(16),
            itemCount: _items.length,
            separatorBuilder: (_, _) => const SizedBox(height: 8),
            itemBuilder: (_, index) {
              final item = _items[index];
              return Card(
                child: ListTile(
                  leading: const CircleAvatar(
                    child: Icon(Icons.movie_outlined),
                  ),
                  title: Text('${item['title']}'),
                  subtitle: Text('${item['body'] ?? ''}'),
                  trailing: const Icon(Icons.check_circle_outline),
                ),
              );
            },
          ),
  );
}

class ReleaseNotesScreen extends StatelessWidget {
  const ReleaseNotesScreen({super.key});

  @override
  Widget build(BuildContext context) => Scaffold(
    appBar: AppBar(title: const Text('What’s new')),
    body: ListView(
      padding: const EdgeInsets.all(18),
      children: const [
        _ReleaseNote(
          version: '3.7.0',
          changes: [
            'New Dashboard Builder: hold and drag your assigned services into the order you prefer.',
            'New Help & Privacy centre explains service access, media requests, local app data, diagnostics and updates.',
            'Final family handover release with clearer source guidance and a complete owner handover pack.',
          ],
        ),
        _ReleaseNote(
          version: '3.6.0',
          changes: [
            'New admin Family Access centre: safely choose a family member and grant or remove their assigned services from the app.',
            'Family Control Centre brings your personalised dashboard, media, activity, health, maintenance and help tools together for modern Android phones.',
            'Designed for Android 15, 16 and Android 17 compatibility, including modern edge-to-edge navigation.',
          ],
        ),
        _ReleaseNote(
          version: '3.5.0',
          changes: [
            'A more personal family dashboard: choose Classic, Compact or Glass cards, alongside your theme, layout and pinned services.',
            'Improved everyday app experience with recent services, clearer offline/maintenance information, service shortcuts and automatic verified updates.',
            'A new publishing and diagnosis guide makes future Android updates easier to build, release and troubleshoot safely.',
          ],
        ),
        _ReleaseNote(
          version: '3.4.1',
          changes: [
            'Technical and family guides are now maintained in the project, alongside clearer source-file comments.',
            'Android home-screen service shortcuts were packaged correctly for current Android versions.',
          ],
        ),
        _ReleaseNote(
          version: '3.4.0',
          changes: [
            'The app now checks for a newer verified update automatically when you open it, and only prompts when one is available.',
            'Hold the Connor Homelab app icon for direct in-app shortcuts to Home Assistant, Seerr, Immich and Unraid.',
            'Unraid’s last successful status is kept privately on your device and shown clearly if the portal is temporarily offline.',
          ],
        ),
        _ReleaseNote(
          version: '3.3.0',
          changes: [
            'New bottom navigation for Home, Media, Activity, Services and Profile.',
            'Searchable Services catalogue groups your assigned apps into Home, Media, Photos, Homelab and Utilities.',
            'Getting started guide for family members new to Connor Homelab.',
          ],
        ),
        _ReleaseNote(
          version: '3.2.0',
          changes: [
            'Schedule maintenance notices with start and end times; banners appear and hide automatically in the app.',
            'Immich highlights now have a private activity summary, refresh support and timestamps.',
            'New Update centre shows installed/latest versions and opens verified updates.',
            'Connection diagnostics now separately check app sign-in, portal reachability and the Unraid tunnel.',
          ],
        ),
        _ReleaseNote(
          version: '3.1.0',
          changes: [
            'Home Assistant is now a clearer in-app home hub with secure-session status and quick access.',
            'Unraid hub now shows connection state, CPU, memory, uptime, containers and a Docker shortcut.',
            'In-app service pages now explain connection problems and offer a retry action.',
          ],
        ),
        _ReleaseNote(
          version: '3.0.0',
          changes: [
            'Your profile: personal name, icon, theme, dashboard layout and phone-lock choice.',
            'Maintenance centre for planned homelab work, with admin-only notice publishing.',
            'Latest-for-you activity on the home screen alongside your private services.',
            'V3 settings are protected by Supabase row-level security.',
          ],
        ),
        _ReleaseNote(
          version: '2.7.1',
          changes: [
            'Choose a personal Ocean, Forest, Violet or Sunset dashboard theme.',
            'Choose a standard, compact or media-first home layout.',
            'Optional biometric / phone-PIN app lock when returning to the app.',
            'Maintenance notices and clearer connection diagnostics.',
          ],
        ),
        _ReleaseNote(
          version: '2.7.0',
          changes: [
            'Personal Immich highlight and activity views.',
            'Foundations for family-aware notifications and service identities.',
          ],
        ),
        _ReleaseNote(
          version: '2.5.0',
          changes: [
            'Personal dashboard with pinned services and recently used apps.',
            'Improved family-friendly dashboard layout.',
          ],
        ),
        _ReleaseNote(
          version: '2.4.9',
          changes: [
            'Back navigation stays inside Home Assistant, Seerr, Immich and other services.',
            'Reliable update checks and native update notifications.',
            'Seerr webhook notifications supported.',
          ],
        ),
      ],
    ),
  );
}

class _ReleaseNote extends StatelessWidget {
  const _ReleaseNote({required this.version, required this.changes});
  final String version;
  final List<String> changes;

  @override
  Widget build(BuildContext context) => Card(
    child: Padding(
      padding: const EdgeInsets.all(16),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(version, style: Theme.of(context).textTheme.titleLarge),
          const SizedBox(height: 8),
          ...changes.map(
            (change) => Padding(
              padding: const EdgeInsets.only(bottom: 6),
              child: Text('• $change'),
            ),
          ),
        ],
      ),
    ),
  );
}

class _NotificationHistoryScreenState extends State<NotificationHistoryScreen> {
  final _client = Supabase.instance.client;
  bool _loading = true;
  List<Map<String, dynamic>> _items = [];

  @override
  void initState() {
    super.initState();
    _load();
  }

  Future<void> _load() async {
    try {
      final rows = await _client
          .from('notifications')
          .select('id, title, body, category, created_at, read_at')
          .order('created_at', ascending: false)
          .limit(100);
      if (mounted)
        setState(() => _items = (rows as List).cast<Map<String, dynamic>>());
    } catch (error) {
      if (mounted)
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Could not load notifications: $error')),
        );
    } finally {
      if (mounted) setState(() => _loading = false);
    }
  }

  IconData _icon(String category) => switch (category) {
    'unraid' => Icons.dns_outlined,
    'home_assistant' => Icons.home_outlined,
    'app_update' => Icons.system_update_outlined,
    'app' => Icons.apps_outlined,
    _ => Icons.notifications_outlined,
  };

  String _date(String? value) {
    final date = DateTime.tryParse(value ?? '')?.toLocal();
    if (date == null) return '';
    return '${date.day}/${date.month} ${date.hour.toString().padLeft(2, '0')}:${date.minute.toString().padLeft(2, '0')}';
  }

  Future<void> _markRead(Map<String, dynamic> item) async {
    if (item['read_at'] != null) return;
    await _client
        .from('notifications')
        .update({'read_at': DateTime.now().toUtc().toIso8601String()})
        .eq('id', item['id']);
    if (mounted)
      setState(() => item['read_at'] = DateTime.now().toIso8601String());
  }

  @override
  Widget build(BuildContext context) => Scaffold(
    appBar: AppBar(title: const Text('Notification history')),
    body: RefreshIndicator(
      onRefresh: _load,
      child: _loading
          ? const Center(child: CircularProgressIndicator())
          : _items.isEmpty
          ? ListView(
              children: const [
                SizedBox(height: 180),
                Center(child: Text('No notifications yet.')),
              ],
            )
          : ListView.separated(
              padding: const EdgeInsets.all(12),
              itemCount: _items.length,
              separatorBuilder: (_, _) => const Divider(height: 1),
              itemBuilder: (_, index) {
                final item = _items[index];
                final unread = item['read_at'] == null;
                return ListTile(
                  leading: CircleAvatar(
                    child: Icon(_icon('${item['category']}')),
                  ),
                  title: Text(
                    '${item['title']}',
                    style: unread
                        ? const TextStyle(fontWeight: FontWeight.bold)
                        : null,
                  ),
                  subtitle: Text(
                    '${item['body'] ?? ''}\n${_date(item['created_at'] as String?)}',
                  ),
                  isThreeLine: true,
                  onTap: () => _markRead(item),
                );
              },
            ),
    ),
  );
}
