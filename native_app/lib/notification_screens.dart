import 'package:flutter/material.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

class NotificationSettingsScreen extends StatefulWidget {
  const NotificationSettingsScreen({super.key});

  @override
  State<NotificationSettingsScreen> createState() => _NotificationSettingsScreenState();
}

class _NotificationSettingsScreenState extends State<NotificationSettingsScreen> {
  final _client = Supabase.instance.client;
  bool _loading = true;
  bool _saving = false;
  bool _unraid = true;
  bool _homeAssistant = true;
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
    return TimeOfDay(hour: int.tryParse(parts[0]) ?? fallback.hour, minute: int.tryParse(parts[1]) ?? fallback.minute);
  }

  String _format(TimeOfDay value) => '${value.hour.toString().padLeft(2, '0')}:${value.minute.toString().padLeft(2, '0')}:00';

  Future<void> _load() async {
    try {
      final row = await _client.from('notification_preferences').select().eq('user_id', _client.auth.currentUser!.id).maybeSingle();
      if (row != null && mounted) {
        setState(() {
          _unraid = row['unraid_health'] as bool? ?? true;
          _homeAssistant = row['home_assistant'] as bool? ?? true;
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
    final value = await showTimePicker(context: context, initialTime: start ? _quietStart : _quietEnd);
    if (value != null && mounted) setState(() { if (start) { _quietStart = value; } else { _quietEnd = value; } });
  }

  Future<void> _save() async {
    setState(() => _saving = true);
    try {
      await _client.from('notification_preferences').upsert({
        'user_id': _client.auth.currentUser!.id,
        'unraid_health': _unraid,
        'home_assistant': _homeAssistant,
        'app_updates': _appUpdates,
        'quiet_hours_enabled': _quietHours,
        'quiet_start': _format(_quietStart),
        'quiet_end': _format(_quietEnd),
        'timezone': 'Europe/London',
        'updated_at': DateTime.now().toUtc().toIso8601String(),
      });
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('Notification preferences saved.')));
        Navigator.pop(context);
      }
    } catch (error) {
      if (mounted) ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text('Could not save preferences: $error')));
    } finally {
      if (mounted) setState(() => _saving = false);
    }
  }

  @override
  Widget build(BuildContext context) => Scaffold(
        appBar: AppBar(title: const Text('Notification settings')),
        body: _loading
            ? const Center(child: CircularProgressIndicator())
            : ListView(padding: const EdgeInsets.all(18), children: [
                Text('Choose what reaches this phone.', style: Theme.of(context).textTheme.titleMedium),
                const SizedBox(height: 10),
                SwitchListTile.adaptive(value: _unraid, onChanged: (value) => setState(() => _unraid = value), title: const Text('Unraid health'), subtitle: const Text('Server recovery, stopped containers and high resource use.')),
                SwitchListTile.adaptive(value: _homeAssistant, onChanged: (value) => setState(() => _homeAssistant = value), title: const Text('Home Assistant'), subtitle: const Text('The home alerts you choose to send from Home Assistant.')),
                SwitchListTile.adaptive(value: _appUpdates, onChanged: (value) => setState(() => _appUpdates = value), title: const Text('App updates'), subtitle: const Text('Let me know when a new Connor Homelab app version is published.')),
                const Divider(height: 30),
                SwitchListTile.adaptive(value: _quietHours, onChanged: (value) => setState(() => _quietHours = value), title: const Text('Quiet hours'), subtitle: const Text('Non-critical alerts wait until your quiet hours end.')),
                if (_quietHours) Card(child: Column(children: [
                  ListTile(title: const Text('Quiet hours start'), trailing: Text(_quietStart.format(context)), onTap: () => _pickTime(true)),
                  ListTile(title: const Text('Quiet hours end'), trailing: Text(_quietEnd.format(context)), onTap: () => _pickTime(false)),
                ])),
                const SizedBox(height: 24),
                FilledButton.icon(onPressed: _saving ? null : _save, icon: const Icon(Icons.save), label: Text(_saving ? 'Saving…' : 'Save preferences')),
              ]),
      );
}

class NotificationHistoryScreen extends StatefulWidget {
  const NotificationHistoryScreen({super.key});

  @override
  State<NotificationHistoryScreen> createState() => _NotificationHistoryScreenState();
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
      final rows = await _client.from('notifications').select('id, title, body, category, created_at, read_at').order('created_at', ascending: false).limit(100);
      if (mounted) setState(() => _items = (rows as List).cast<Map<String, dynamic>>());
    } catch (error) {
      if (mounted) ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text('Could not load notifications: $error')));
    } finally {
      if (mounted) setState(() => _loading = false);
    }
  }

  IconData _icon(String category) => switch (category) {
        'unraid' => Icons.dns_outlined,
        'home_assistant' => Icons.home_outlined,
        'app_update' => Icons.system_update_outlined,
        _ => Icons.notifications_outlined,
      };

  String _date(String? value) {
    final date = DateTime.tryParse(value ?? '')?.toLocal();
    if (date == null) return '';
    return '${date.day}/${date.month} ${date.hour.toString().padLeft(2, '0')}:${date.minute.toString().padLeft(2, '0')}';
  }

  Future<void> _markRead(Map<String, dynamic> item) async {
    if (item['read_at'] != null) return;
    await _client.from('notifications').update({'read_at': DateTime.now().toUtc().toIso8601String()}).eq('id', item['id']);
    if (mounted) setState(() => item['read_at'] = DateTime.now().toIso8601String());
  }

  @override
  Widget build(BuildContext context) => Scaffold(
        appBar: AppBar(title: const Text('Notification history')),
        body: RefreshIndicator(
          onRefresh: _load,
          child: _loading
              ? const Center(child: CircularProgressIndicator())
              : _items.isEmpty
                  ? ListView(children: const [SizedBox(height: 180), Center(child: Text('No notifications yet.'))])
                  : ListView.separated(
                      padding: const EdgeInsets.all(12),
                      itemCount: _items.length,
                      separatorBuilder: (_, _) => const Divider(height: 1),
                      itemBuilder: (_, index) {
                        final item = _items[index];
                        final unread = item['read_at'] == null;
                        return ListTile(
                          leading: CircleAvatar(child: Icon(_icon('${item['category']}'))),
                          title: Text('${item['title']}', style: unread ? const TextStyle(fontWeight: FontWeight.bold) : null),
                          subtitle: Text('${item['body'] ?? ''}\n${_date(item['created_at'] as String?)}'),
                          isThreeLine: true,
                          onTap: () => _markRead(item),
                        );
                      },
                    ),
        ),
      );
}
