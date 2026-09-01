import 'dart:convert';
import 'dart:io';

import 'package:crypto/crypto.dart';
import 'package:dio/dio.dart';
import 'package:firebase_core/firebase_core.dart';
import 'package:firebase_messaging/firebase_messaging.dart';
import 'package:flutter/material.dart';
import 'package:flutter_local_notifications/flutter_local_notifications.dart';
import 'package:http/http.dart' as http;
import 'package:open_filex/open_filex.dart';
import 'package:package_info_plus/package_info_plus.dart';
import 'package:path_provider/path_provider.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

import 'notification_screens.dart';
import 'seerr_screen.dart';

const _supabaseUrl = 'https://yrvmanmrzxceqahopfec.supabase.co';
const _supabaseKey = 'sb_publishable_a1KjGdyaOL4ynlIUJKXhog_cu6xa2oe';
const _portalUrl = 'https://conhomelab.uk';

final _localNotifications = FlutterLocalNotificationsPlugin();
const _notificationChannel = AndroidNotificationChannel(
  'homelab_updates',
  'Homelab updates',
  description: 'Updates from Connor Homelab',
  importance: Importance.high,
);

Future<void> _configureNotifications() async {
  const initializationSettings = InitializationSettings(
    android: AndroidInitializationSettings('@mipmap/ic_launcher'),
  );
  await _localNotifications.initialize(initializationSettings);
  await _localNotifications
      .resolvePlatformSpecificImplementation<
          AndroidFlutterLocalNotificationsPlugin>()
      ?.createNotificationChannel(_notificationChannel);

  FirebaseMessaging.onMessage.listen((message) {
    final notification = message.notification;
    if (notification == null) return;
    _localNotifications.show(
      notification.hashCode,
      notification.title ?? 'Connor Homelab',
      notification.body ?? '',
      const NotificationDetails(
        android: AndroidNotificationDetails(
          'homelab_updates',
          'Homelab updates',
          channelDescription: 'Updates from Connor Homelab',
          importance: Importance.high,
          priority: Priority.high,
          icon: '@mipmap/ic_launcher',
        ),
      ),
    );
  });
}

Future<void> main() async {
  WidgetsFlutterBinding.ensureInitialized();
  await Firebase.initializeApp();
  await _configureNotifications();
  await Supabase.initialize(url: _supabaseUrl, publishableKey: _supabaseKey);
  runApp(const HomelabApp());
}

class HomelabApp extends StatelessWidget {
  const HomelabApp({super.key});

  @override
  Widget build(BuildContext context) => MaterialApp(
        title: 'Connor Homelab',
        debugShowCheckedModeBanner: false,
        theme: ThemeData(
          useMaterial3: true,
          brightness: Brightness.dark,
          colorScheme: ColorScheme.fromSeed(
            seedColor: const Color(0xff72d8ff), brightness: Brightness.dark,
            surface: const Color(0xff101a26),
          ),
          scaffoldBackgroundColor: const Color(0xff09111b),
        ),
        home: const SessionGate(),
      );
}

class SessionGate extends StatelessWidget {
  const SessionGate({super.key});

  @override
  Widget build(BuildContext context) => StreamBuilder<AuthState>(
        stream: Supabase.instance.client.auth.onAuthStateChange,
        builder: (context, snapshot) {
          final session = snapshot.data?.session ?? Supabase.instance.client.auth.currentSession;
          return session == null ? const LoginScreen() : const DashboardScreen();
        },
      );
}

class LoginScreen extends StatefulWidget {
  const LoginScreen({super.key});

  @override
  State<LoginScreen> createState() => _LoginScreenState();
}

class _LoginScreenState extends State<LoginScreen> {
  final _email = TextEditingController();
  final _password = TextEditingController();
  bool _busy = false;
  bool _showPassword = false;
  String? _message;

  @override
  void dispose() {
    _email.dispose();
    _password.dispose();
    super.dispose();
  }

  Future<void> _signIn() async {
    setState(() { _busy = true; _message = null; });
    try {
      await Supabase.instance.client.auth.signInWithPassword(email: _email.text.trim(), password: _password.text);
    } on AuthException catch (error) {
      setState(() => _message = error.message);
    } finally {
      if (mounted) setState(() => _busy = false);
    }
  }

  Future<void> _reset() async {
    if (_email.text.trim().isEmpty) {
      setState(() => _message = 'Enter your email address first.');
      return;
    }
    setState(() { _busy = true; _message = null; });
    try {
      await Supabase.instance.client.auth.resetPasswordForEmail(_email.text.trim(), redirectTo: _portalUrl);
      setState(() => _message = 'Password reset email sent.');
    } on AuthException catch (error) {
      setState(() => _message = error.message);
    } finally {
      if (mounted) setState(() => _busy = false);
    }
  }

  @override
  Widget build(BuildContext context) => Scaffold(
        body: SafeArea(
          child: Center(
            child: SingleChildScrollView(
              padding: const EdgeInsets.all(24),
              child: ConstrainedBox(
                constraints: const BoxConstraints(maxWidth: 430),
                child: Card(
                  child: Padding(
                    padding: const EdgeInsets.all(28),
                    child: Column(mainAxisSize: MainAxisSize.min, children: [
                      const Icon(Icons.hub_outlined, size: 56, color: Color(0xff72d8ff)),
                      const SizedBox(height: 16),
                      Text('Connor Homelab', style: Theme.of(context).textTheme.headlineSmall),
                      const SizedBox(height: 6),
                      Text('Your family’s private home services', style: Theme.of(context).textTheme.bodyMedium),
                      const SizedBox(height: 28),
                      TextField(controller: _email, keyboardType: TextInputType.emailAddress, autofillHints: const [AutofillHints.username], decoration: const InputDecoration(labelText: 'Email address', prefixIcon: Icon(Icons.person_outline))),
                      const SizedBox(height: 14),
                      TextField(controller: _password, obscureText: !_showPassword, autofillHints: const [AutofillHints.password], onSubmitted: (_) => _busy ? null : _signIn(), decoration: InputDecoration(labelText: 'Password', prefixIcon: const Icon(Icons.lock_outline), suffixIcon: IconButton(icon: Icon(_showPassword ? Icons.visibility_off : Icons.visibility), onPressed: () => setState(() => _showPassword = !_showPassword)))),
                      if (_message != null) Padding(padding: const EdgeInsets.only(top: 14), child: Text(_message!, textAlign: TextAlign.center, style: TextStyle(color: Theme.of(context).colorScheme.error))),
                      const SizedBox(height: 22),
                      FilledButton.icon(onPressed: _busy ? null : _signIn, icon: _busy ? const SizedBox.square(dimension: 18, child: CircularProgressIndicator(strokeWidth: 2)) : const Icon(Icons.login), label: const Text('Sign in'), style: FilledButton.styleFrom(minimumSize: const Size.fromHeight(50))),
                      TextButton(onPressed: _busy ? null : _reset, child: const Text('Forgot password?')),
                    ]),
                  ),
                ),
              ),
            ),
          ),
        ),
      );
}

class DashboardScreen extends StatefulWidget {
  const DashboardScreen({super.key});

  @override
  State<DashboardScreen> createState() => _DashboardScreenState();
}

class _DashboardScreenState extends State<DashboardScreen> {
  final _client = Supabase.instance.client;
  bool _loading = true;
  String? _error;
  String _name = 'Homelab user';
  bool _admin = false;
  List<Map<String, dynamic>> _apps = [];
  Map<String, dynamic>? _status;
  Set<String> _favourites = {};
  Set<String> _hidden = {};

  @override
  void initState() { super.initState(); _load(); }

  Future<void> _load() async {
    setState(() { _loading = true; _error = null; });
    try {
      final user = _client.auth.currentUser!;
      await _registerForNotifications(user.id);
      final profile = await _client.from('profiles').select('display_name, role').eq('id', user.id).maybeSingle();
      final admin = profile?['role'] == 'admin';
      final allApps = await _client.from('apps').select('id, name, description, url, icon, sort_order').eq('enabled', true).order('sort_order');
      final rows = admin ? <dynamic>[] : await _client.from('user_app_access').select('app_id').eq('user_id', user.id);
      final allowed = rows.map((row) => row['app_id'] as String).toSet();
      final apps = (allApps as List).cast<Map<String, dynamic>>().where((app) => admin || allowed.contains(app['id'])).toList();
      final preferences = await _client.from('user_preferences').select('favourite_app_ids, hidden_app_ids').eq('user_id', user.id).maybeSingle();
      final favourites = ((preferences?['favourite_app_ids'] as List?) ?? const []).map((id) => '$id').toSet();
      final hidden = ((preferences?['hidden_app_ids'] as List?) ?? const []).map((id) => '$id').toSet();
      // Seerr is the family-facing media-request service, so it is the first
      // destination for non-admin family accounts whenever it is assigned.
      if (!admin) {
        apps.sort((left, right) {
          final leftPriority = left['id'] == 'requests' ? 0 : 1;
          final rightPriority = right['id'] == 'requests' ? 0 : 1;
          return leftPriority != rightPriority
              ? leftPriority.compareTo(rightPriority)
              : (left['sort_order'] as int).compareTo(right['sort_order'] as int);
        });
      }
      apps.sort((left, right) {
        final leftFavourite = favourites.contains(left['id']) ? 0 : 1;
        final rightFavourite = favourites.contains(right['id']) ? 0 : 1;
        return leftFavourite != rightFavourite
            ? leftFavourite.compareTo(rightFavourite)
            : (left['sort_order'] as int).compareTo(right['sort_order'] as int);
      });
      final status = await _fetchStatus();
      if (!mounted) return;
      setState(() {
        final displayName = profile?['display_name'] as String?;
        _name = displayName?.trim().isNotEmpty == true ? displayName! : user.email ?? _name;
        _admin = admin;
        _apps = apps;
        _status = status;
        _favourites = favourites;
        _hidden = hidden;
      });
    } catch (error) {
      if (mounted) setState(() => _error = 'Could not load your Homelab: $error');
    } finally {
      if (mounted) setState(() => _loading = false);
    }
  }

  Future<void> _registerForNotifications(String userId) async {
    try {
      final settings = await FirebaseMessaging.instance.requestPermission();
      if (settings.authorizationStatus == AuthorizationStatus.denied) return;
      final token = await FirebaseMessaging.instance.getToken();
      if (token == null) return;
      await _client.from('user_devices').upsert({
        'user_id': userId,
        'token': token,
        'platform': 'android',
        'updated_at': DateTime.now().toUtc().toIso8601String(),
      });
    } catch (_) {
      // Notifications are optional; a failed registration must not block apps.
    }
  }

  Future<Map<String, dynamic>?> _fetchStatus() async {
    try {
      final response = await http.get(Uri.parse('$_portalUrl/api/status')).timeout(const Duration(seconds: 8));
      if (response.statusCode == 200) return jsonDecode(response.body) as Map<String, dynamic>;
    } catch (_) {}
    return null;
  }

  Future<void> _openApp(Map<String, dynamic> app) async {
    await Navigator.of(context).push(MaterialPageRoute<void>(
      builder: (_) => HomelabWebAppScreen(
        title: app['name'] as String,
        url: app['url'] as String,
      ),
    ));
    try {
      await _client.from('audit_events').insert({'user_id': _client.auth.currentUser!.id, 'event_type': 'app_opened', 'app_id': app['id']});
    } catch (_) {}
  }

  Future<void> _personalise() async {
    final favourites = {..._favourites};
    final hidden = {..._hidden};
    final messenger = ScaffoldMessenger.of(context);
    await showDialog<void>(context: context, builder: (context) => StatefulBuilder(builder: (context, setDialogState) => AlertDialog(
      title: const Text('Personalise your dashboard'),
      content: SizedBox(width: 420, child: SingleChildScrollView(child: Column(mainAxisSize: MainAxisSize.min, children: _apps.map((app) {
        final id = app['id'] as String;
        return ListTile(
          title: Text(app['name'] as String),
          subtitle: Text(hidden.contains(id) ? 'Hidden from your home screen' : favourites.contains(id) ? 'Pinned to the top' : 'Shown normally'),
          trailing: PopupMenuButton<String>(
            onSelected: (choice) => setDialogState(() {
              if (choice == 'favourite') { favourites.add(id); hidden.remove(id); }
              if (choice == 'normal') { favourites.remove(id); hidden.remove(id); }
              if (choice == 'hide') { hidden.add(id); favourites.remove(id); }
            }),
            itemBuilder: (_) => const [
              PopupMenuItem(value: 'favourite', child: Text('Pin to top')),
              PopupMenuItem(value: 'normal', child: Text('Show normally')),
              PopupMenuItem(value: 'hide', child: Text('Hide')),
            ],
          ),
        );
      }).toList()))),
      actions: [
        TextButton(onPressed: () => Navigator.pop(context), child: const Text('Cancel')),
        FilledButton(onPressed: () async {
          await _client.from('user_preferences').upsert({
            'user_id': _client.auth.currentUser!.id,
            'favourite_app_ids': favourites.toList(),
            'hidden_app_ids': hidden.toList(),
            'updated_at': DateTime.now().toUtc().toIso8601String(),
          });
          if (!context.mounted) return;
          Navigator.pop(context);
          messenger.showSnackBar(const SnackBar(content: Text('Your dashboard preferences were saved.')));
          _load();
        }, child: const Text('Save')),
      ],
    )));
  }

  Future<void> _checkForUpdates() async {
    final messenger = ScaffoldMessenger.of(context);
    messenger.showSnackBar(const SnackBar(content: Text('Checking for updates…')));
    try {
      final installed = await PackageInfo.fromPlatform();
      final response = await http.get(Uri.parse('$_portalUrl/app-update.json')).timeout(const Duration(seconds: 8));
      if (response.statusCode != 200) throw Exception();
      final release = jsonDecode(response.body) as Map<String, dynamic>;
      final latest = int.tryParse('${release['versionCode']}') ?? 0;
      final current = int.tryParse(installed.buildNumber) ?? 0;
      if (!mounted) return;
      if (latest <= current) {
        messenger.hideCurrentSnackBar();
        messenger.showSnackBar(const SnackBar(content: Text('You have the latest version.')));
        return;
      }
      await showDialog<void>(context: context, builder: (context) => AlertDialog(
        title: Text('Update ${release['version'] ?? ''} available'),
        content: Text('${release['notes'] ?? 'A new Homelab app update is ready.'}\n\nAndroid will ask you to confirm the install.'),
        actions: [
          TextButton(onPressed: () => Navigator.pop(context), child: const Text('Later')),
          FilledButton(onPressed: release['downloadUrl'] == null ? null : () { Navigator.pop(context); _downloadAndInstallUpdate(release); }, child: const Text('Download update')),
        ],
      ));
    } catch (_) {
      messenger.hideCurrentSnackBar();
      messenger.showSnackBar(const SnackBar(content: Text('No published app update yet.')));
    }
  }

  Future<void> _downloadAndInstallUpdate(Map<String, dynamic> release) async {
    final messenger = ScaffoldMessenger.of(context);
    final url = Uri.tryParse('${release['downloadUrl']}');
    final expectedHash = '${release['sha256'] ?? ''}'.trim().toLowerCase();
    final trustedRelease = url != null &&
        url.scheme == 'https' &&
        url.host == 'github.com' &&
        url.path.startsWith('/condoggett/unraidconnor/releases/download/');
    if (!trustedRelease || !RegExp(r'^[a-f0-9]{64}$').hasMatch(expectedHash)) {
      messenger.showSnackBar(const SnackBar(content: Text('This update is not a verified Connor Homelab release.')));
      return;
    }
    try {
      messenger.showSnackBar(const SnackBar(content: Text('Downloading verified update…')));
      final directory = await getApplicationDocumentsDirectory();
      final version = '${release['version'] ?? 'latest'}'.replaceAll(RegExp(r'[^0-9A-Za-z._-]'), '_');
      final apk = File('${directory.path}/Connor-Homelab-$version.apk');
      await Dio().download(url.toString(), apk.path);
      final actualHash = await sha256.bind(apk.openRead()).first;
      if (actualHash.toString().toLowerCase() != expectedHash) {
        await apk.delete();
        throw Exception('The download did not pass its security check.');
      }
      if (!mounted) return;
      messenger.hideCurrentSnackBar();
      messenger.showSnackBar(const SnackBar(content: Text('Download complete. Confirm Android’s install prompt to update.')));
      final result = await OpenFilex.open(apk.path, type: 'application/vnd.android.package-archive');
      if (result.type != ResultType.done && mounted) {
        messenger.showSnackBar(const SnackBar(content: Text('Allow Connor Homelab to install unknown apps, then try Update again.')));
      }
    } catch (error) {
      if (mounted) {
        messenger.hideCurrentSnackBar();
        messenger.showSnackBar(SnackBar(content: Text('Update failed: $error')));
      }
    }
  }

  @override
  Widget build(BuildContext context) => Scaffold(
        appBar: AppBar(title: const Text('Connor Homelab'), actions: [
          IconButton(onPressed: () => Navigator.of(context).push(MaterialPageRoute<void>(builder: (_) => const NotificationHistoryScreen())), tooltip: 'Notification history', icon: const Icon(Icons.notifications_outlined)),
          IconButton(onPressed: () => Navigator.of(context).push(MaterialPageRoute<void>(builder: (_) => const NotificationSettingsScreen())), tooltip: 'Notification settings', icon: const Icon(Icons.notifications_active_outlined)),
          IconButton(onPressed: _personalise, tooltip: 'Personalise dashboard', icon: const Icon(Icons.tune)),
          IconButton(onPressed: _checkForUpdates, tooltip: 'Check for updates', icon: const Icon(Icons.system_update_outlined)),
          IconButton(onPressed: () => _client.auth.signOut(), tooltip: 'Sign out', icon: const Icon(Icons.logout)),
        ]),
        body: RefreshIndicator(
          onRefresh: _load,
          child: _loading ? const Center(child: CircularProgressIndicator()) : ListView(padding: const EdgeInsets.all(18), children: [
            Text('Welcome back, $_name', style: Theme.of(context).textTheme.headlineSmall),
            const SizedBox(height: 5),
            Text(_admin ? 'Administrator · Full Homelab access' : 'Your family Homelab services'),
            const SizedBox(height: 18),
            _StatusCard(status: _status),
            if (_error != null) Padding(padding: const EdgeInsets.only(top: 14), child: Text(_error!, style: TextStyle(color: Theme.of(context).colorScheme.error))),
            const SizedBox(height: 24),
            Text('Your apps', style: Theme.of(context).textTheme.titleLarge),
            const SizedBox(height: 10),
            if (_apps.isEmpty) const Card(child: Padding(padding: EdgeInsets.all(18), child: Text('No apps have been assigned to this account yet. Ask an admin to grant access.'))),
            ..._apps.where((app) => !_hidden.contains(app['id'])).map((app) => Card(child: ListTile(leading: CircleAvatar(child: Text((app['icon'] as String?)?.isNotEmpty == true ? app['icon'] as String : '•')), title: Text(app['name'] as String), subtitle: Text((app['description'] as String?) ?? ''), trailing: const Icon(Icons.arrow_forward_ios), onTap: () => _openApp(app)))),
            const SizedBox(height: 18),
            OutlinedButton.icon(onPressed: _checkForUpdates, icon: const Icon(Icons.system_update_outlined), label: const Text('Check for app updates')),
            const SizedBox(height: 10),
            Text('Pull down to refresh your status and app access.', textAlign: TextAlign.center, style: Theme.of(context).textTheme.bodySmall),
          ]),
        ),
      );
}

class _StatusCard extends StatelessWidget {
  const _StatusCard({this.status});
  final Map<String, dynamic>? status;

  @override
  Widget build(BuildContext context) {
    final online = status?['online'] == true;
    final memory = status?['memory'] as Map<String, dynamic>?;
    final usage = memory?['usedPercent'];
    return Card(
      color: online ? const Color(0xff123125) : const Color(0xff25212a),
      child: Padding(
        padding: const EdgeInsets.all(18),
        child: Row(children: [
          Icon(online ? Icons.check_circle : Icons.cloud_off, color: online ? const Color(0xff66e59a) : Colors.amber, size: 34),
          const SizedBox(width: 14),
          Expanded(child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
            Text(online ? 'Unraid is online' : 'Unraid status unavailable', style: Theme.of(context).textTheme.titleMedium),
            const SizedBox(height: 3),
            Text(online ? '${status?['hostname'] ?? 'Tower'} · ${status?['cpuCores'] ?? '?'} CPU cores${usage == null ? '' : ' · $usage% memory'}' : 'Pull down to try again.'),
          ])),
        ]),
      ),
    );
  }
}
