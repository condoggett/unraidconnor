import 'dart:convert';

import 'package:flutter/material.dart';
import 'package:http/http.dart' as http;
import 'package:supabase_flutter/supabase_flutter.dart';

import 'seerr_screen.dart';

class ImmichHighlightsScreen extends StatefulWidget {
  const ImmichHighlightsScreen({super.key});
  @override State<ImmichHighlightsScreen> createState() => _ImmichHighlightsScreenState();
}

class _ImmichHighlightsScreenState extends State<ImmichHighlightsScreen> {
  final _client = Supabase.instance.client;
  List<Map<String, dynamic>> _items = [];
  bool _loading = true;
  @override void initState() { super.initState(); _load(); }
  Future<void> _load() async {
    try {
      final rows = await _client.from('notifications').select('title, body, created_at, data').eq('category', 'app').order('created_at', ascending: false).limit(100);
      _items = (rows as List).cast<Map<String, dynamic>>().where((row) => ('${row['title']} ${row['body']} ${row['data']}').toLowerCase().contains('immich')).toList();
    } catch (_) {} finally { if (mounted) setState(() => _loading = false); }
  }
  @override Widget build(BuildContext context) => Scaffold(appBar: AppBar(title: const Text('Immich highlights')), body: _loading ? const Center(child: CircularProgressIndicator()) : ListView(padding: const EdgeInsets.all(18), children: [
    Text('Recent photo moments', style: Theme.of(context).textTheme.headlineSmall),
    const SizedBox(height: 8),
    const Text('Your personal Immich events appear here. Photo thumbnails need a read-only Immich integration and are never loaded with a key in the app.'),
    const SizedBox(height: 14),
    if (_items.isEmpty) const Card(child: Padding(padding: EdgeInsets.all(16), child: Text('No Immich highlights yet. Open Immich to browse your library.'))),
    ..._items.map((item) => Card(child: ListTile(leading: const Icon(Icons.photo_library_outlined), title: Text('${item['title']}'), subtitle: Text('${item['body'] ?? ''}')))),
    const SizedBox(height: 12),
    FilledButton.icon(onPressed: () => Navigator.of(context).push(MaterialPageRoute<void>(builder: (_) => const HomelabWebAppScreen(title: 'Immich', url: 'https://photos.conhomelab.uk'))), icon: const Icon(Icons.open_in_new), label: const Text('Open Immich')),
  ]));
}

class FamilyActivityScreen extends StatefulWidget {
  const FamilyActivityScreen({super.key});
  @override State<FamilyActivityScreen> createState() => _FamilyActivityScreenState();
}
class _FamilyActivityScreenState extends State<FamilyActivityScreen> {
  final _client = Supabase.instance.client; List<Map<String, dynamic>> _items = []; bool _loading = true;
  @override void initState() { super.initState(); _load(); }
  Future<void> _load() async { try { final rows = await _client.from('notifications').select('title, body, category, created_at').order('created_at', ascending: false).limit(100); _items = (rows as List).cast<Map<String, dynamic>>(); } catch (_) {} finally { if (mounted) setState(() => _loading = false); } }
  @override Widget build(BuildContext context) => Scaffold(appBar: AppBar(title: const Text('Your activity')), body: _loading ? const Center(child: CircularProgressIndicator()) : RefreshIndicator(onRefresh: _load, child: ListView(padding: const EdgeInsets.all(12), children: _items.isEmpty ? [const SizedBox(height: 160), const Center(child: Text('No personal activity yet.'))] : _items.map((item) => Card(child: ListTile(leading: const Icon(Icons.bolt_outlined), title: Text('${item['title']}'), subtitle: Text('${item['body'] ?? ''}\n${item['created_at'] ?? ''}'), isThreeLine: true))).toList())));
}

class DiagnosticsScreen extends StatefulWidget { const DiagnosticsScreen({super.key}); @override State<DiagnosticsScreen> createState() => _DiagnosticsScreenState(); }
class _DiagnosticsScreenState extends State<DiagnosticsScreen> {
  String _message = 'Checking connection…';
  @override void initState() { super.initState(); _check(); }
  Future<void> _check() async { try { final response = await http.get(Uri.parse('https://conhomelab.uk/api/status')).timeout(const Duration(seconds: 8)); final status = jsonDecode(response.body) as Map<String, dynamic>; if (mounted) setState(() => _message = status['online'] == true ? 'Homelab status bridge is online.' : 'The tunnel is reachable but the status bridge is unavailable.'); } catch (_) { if (mounted) setState(() => _message = 'Cannot reach Connor Homelab. Check your internet connection, Cloudflare Access session, then the homelab tunnel.'); } }
  @override Widget build(BuildContext context) => Scaffold(appBar: AppBar(title: const Text('Connection diagnostics')), body: ListView(padding: const EdgeInsets.all(18), children: [const Icon(Icons.monitor_heart_outlined, size: 56), const SizedBox(height: 16), Text(_message, style: Theme.of(context).textTheme.titleMedium), const SizedBox(height: 18), const Card(child: ListTile(title: Text('How access works'), subtitle: Text('The app keeps your Supabase sign-in and in-app Cloudflare session. Individual services keep their own login where required.'))), OutlinedButton.icon(onPressed: _check, icon: const Icon(Icons.refresh), label: const Text('Run check again'))]));
}
