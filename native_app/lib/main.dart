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

import 'app_lock.dart';
import 'notification_screens.dart';
import 'release3_screens.dart';
import 'seerr_screen.dart';
import 'service_hubs.dart';

const _supabaseUrl = 'https://yrvmanmrzxceqahopfec.supabase.co';
const _supabaseKey = 'sb_publishable_a1KjGdyaOL4ynlIUJKXhog_cu6xa2oe';
const _portalUrl = 'https://conhomelab.uk';

final _localNotifications = FlutterLocalNotificationsPlugin();
final _navigatorKey = GlobalKey<NavigatorState>();
Map<String, dynamic>? _pendingNotificationRoute;
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
  await _localNotifications.initialize(
    initializationSettings,
    onDidReceiveNotificationResponse: (response) {
      final payload = response.payload;
      if (payload == null || payload.isEmpty) return;
      try {
        _openNotificationRoute(jsonDecode(payload) as Map<String, dynamic>);
      } catch (_) {}
    },
  );
  await _localNotifications
      .resolvePlatformSpecificImplementation<
        AndroidFlutterLocalNotificationsPlugin
      >()
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
      payload: jsonEncode({
        ...message.data,
        '_title': notification.title ?? '',
        '_body': notification.body ?? '',
      }),
    );
  });
  FirebaseMessaging.onMessageOpenedApp.listen(
    (message) => _openNotificationRoute({
      ...message.data,
      '_title': message.notification?.title ?? '',
      '_body': message.notification?.body ?? '',
    }),
  );
}

void _openNotificationRoute(Map<String, dynamic> data) {
  final navigator = _navigatorKey.currentState;
  if (navigator == null) {
    _pendingNotificationRoute = data;
    return;
  }
  final service = '${data['service'] ?? ''}'.toLowerCase();
  final category = '${data['category'] ?? ''}'.toLowerCase();
  final destination =
      service == 'seerr' || service == 'overseerr' || service == 'requests'
      ? const HomelabWebAppScreen(
          title: 'Seerr',
          url: 'https://requests.conhomelab.uk',
        )
      : service == 'home_assistant' ||
            service == 'home-assistant' ||
            category == 'home_assistant'
      ? const HomelabWebAppScreen(
          title: 'Home Assistant',
          url: 'https://ha.conhomelab.uk',
        )
      : service == 'immich' || service == 'photos'
      ? const HomelabWebAppScreen(
          title: 'Immich',
          url: 'https://photos.conhomelab.uk',
        )
      : data['version'] != null || category == 'app_update'
      ? const ReleaseNotesScreen()
      : const NotificationHistoryScreen();
  navigator.push(MaterialPageRoute<void>(builder: (_) => destination));
}

void _flushPendingNotificationRoute() {
  final pending = _pendingNotificationRoute;
  if (pending == null) return;
  _pendingNotificationRoute = null;
  _openNotificationRoute(pending);
}

Future<void> main() async {
  WidgetsFlutterBinding.ensureInitialized();
  await Firebase.initializeApp();
  await _configureNotifications();
  await Supabase.initialize(url: _supabaseUrl, publishableKey: _supabaseKey);
  runApp(const HomelabApp());
  WidgetsBinding.instance.addPostFrameCallback(
    (_) => _flushPendingNotificationRoute(),
  );
  final initialMessage = await FirebaseMessaging.instance.getInitialMessage();
  if (initialMessage != null) {
    _openNotificationRoute({
      ...initialMessage.data,
      '_title': initialMessage.notification?.title ?? '',
      '_body': initialMessage.notification?.body ?? '',
    });
  }
}

class HomelabApp extends StatelessWidget {
  const HomelabApp({super.key});

  @override
  Widget build(BuildContext context) => MaterialApp(
    navigatorKey: _navigatorKey,
    title: 'Connor Homelab',
    debugShowCheckedModeBanner: false,
    theme: ThemeData(
      useMaterial3: true,
      brightness: Brightness.dark,
      colorScheme: ColorScheme.fromSeed(
        seedColor: const Color(0xff72d8ff),
        brightness: Brightness.dark,
        surface: const Color(0xff101a26),
      ),
      // Avoid the optional Material 3 InkSparkle shader. Windows App
      // Control blocks Flutter's local shader compiler on this PC; the
      // standard ripple keeps the same interaction feedback and builds
      // without relaxing any Windows security policy.
      splashFactory: InkRipple.splashFactory,
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
      final session =
          snapshot.data?.session ??
          Supabase.instance.client.auth.currentSession;
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
    setState(() {
      _busy = true;
      _message = null;
    });
    try {
      await Supabase.instance.client.auth.signInWithPassword(
        email: _email.text.trim(),
        password: _password.text,
      );
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
    setState(() {
      _busy = true;
      _message = null;
    });
    try {
      await Supabase.instance.client.auth.resetPasswordForEmail(
        _email.text.trim(),
        redirectTo: _portalUrl,
      );
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
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    const Icon(
                      Icons.hub_outlined,
                      size: 56,
                      color: Color(0xff72d8ff),
                    ),
                    const SizedBox(height: 16),
                    Text(
                      'Connor Homelab',
                      style: Theme.of(context).textTheme.headlineSmall,
                    ),
                    const SizedBox(height: 6),
                    Text(
                      'Your family’s private home services',
                      style: Theme.of(context).textTheme.bodyMedium,
                    ),
                    const SizedBox(height: 28),
                    TextField(
                      controller: _email,
                      keyboardType: TextInputType.emailAddress,
                      autofillHints: const [AutofillHints.username],
                      decoration: const InputDecoration(
                        labelText: 'Email address',
                        prefixIcon: Icon(Icons.person_outline),
                      ),
                    ),
                    const SizedBox(height: 14),
                    TextField(
                      controller: _password,
                      obscureText: !_showPassword,
                      autofillHints: const [AutofillHints.password],
                      onSubmitted: (_) => _busy ? null : _signIn(),
                      decoration: InputDecoration(
                        labelText: 'Password',
                        prefixIcon: const Icon(Icons.lock_outline),
                        suffixIcon: IconButton(
                          icon: Icon(
                            _showPassword
                                ? Icons.visibility_off
                                : Icons.visibility,
                          ),
                          onPressed: () =>
                              setState(() => _showPassword = !_showPassword),
                        ),
                      ),
                    ),
                    if (_message != null)
                      Padding(
                        padding: const EdgeInsets.only(top: 14),
                        child: Text(
                          _message!,
                          textAlign: TextAlign.center,
                          style: TextStyle(
                            color: Theme.of(context).colorScheme.error,
                          ),
                        ),
                      ),
                    const SizedBox(height: 22),
                    FilledButton.icon(
                      onPressed: _busy ? null : _signIn,
                      icon: _busy
                          ? const SizedBox.square(
                              dimension: 18,
                              child: CircularProgressIndicator(strokeWidth: 2),
                            )
                          : const Icon(Icons.login),
                      label: const Text('Sign in'),
                      style: FilledButton.styleFrom(
                        minimumSize: const Size.fromHeight(50),
                      ),
                    ),
                    TextButton(
                      onPressed: _busy ? null : _reset,
                      child: const Text('Forgot password?'),
                    ),
                  ],
                ),
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
  List<String> _recentAppIds = [];
  String _theme = 'ocean';
  String _layout = 'standard';
  String _avatar = 'auto';
  bool _appLockEnabled = false;
  Map<String, dynamic>? _maintenance;
  List<Map<String, dynamic>> _activity = [];

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
      final user = _client.auth.currentUser!;
      await _registerForNotifications(user.id);
      final profile = await _client
          .from('profiles')
          .select('display_name, role')
          .eq('id', user.id)
          .maybeSingle();
      final admin = profile?['role'] == 'admin';
      final allApps = await _client
          .from('apps')
          .select('id, name, description, url, icon, sort_order')
          .eq('enabled', true)
          .order('sort_order');
      final rows = admin
          ? <dynamic>[]
          : await _client
                .from('user_app_access')
                .select('app_id')
                .eq('user_id', user.id);
      final allowed = rows.map((row) => row['app_id'] as String).toSet();
      final apps = (allApps as List)
          .cast<Map<String, dynamic>>()
          .where((app) => admin || allowed.contains(app['id']))
          .toList();
      final preferences = await _client
          .from('user_preferences')
          .select('favourite_app_ids, hidden_app_ids')
          .eq('user_id', user.id)
          .maybeSingle();
      final favourites =
          ((preferences?['favourite_app_ids'] as List?) ?? const [])
              .map((id) => '$id')
              .toSet();
      final hidden = ((preferences?['hidden_app_ids'] as List?) ?? const [])
          .map((id) => '$id')
          .toSet();
      Map<String, dynamic>? dashboardSettings;
      Map<String, dynamic>? maintenance;
      try {
        dashboardSettings = await _client
            .from('user_dashboard_settings')
            .select('theme, dashboard_layout, avatar_icon, app_lock_enabled')
            .eq('user_id', user.id)
            .maybeSingle();
        maintenance = await _client
            .from('maintenance_notices')
            .select('title, message')
            .eq('active', true)
            .order('created_at', ascending: false)
            .limit(1)
            .maybeSingle();
      } catch (_) {
        // The optional Release 3 migration has not been applied yet.
      }
      List<String> recentAppIds = [];
      try {
        final recent = await _client
            .from('audit_events')
            .select('app_id')
            .eq('user_id', user.id)
            .eq('event_type', 'app_opened')
            .order('created_at', ascending: false)
            .limit(12);
        recentAppIds = (recent as List)
            .map((row) => '${row['app_id'] ?? ''}')
            .where((id) => id.isNotEmpty)
            .toSet()
            .toList();
      } catch (_) {
        // The dashboard still works for new accounts with no recent history.
      }
      // Seerr is the family-facing media-request service, so it is the first
      // destination for non-admin family accounts whenever it is assigned.
      if (!admin) {
        apps.sort((left, right) {
          final leftPriority = left['id'] == 'requests' ? 0 : 1;
          final rightPriority = right['id'] == 'requests' ? 0 : 1;
          return leftPriority != rightPriority
              ? leftPriority.compareTo(rightPriority)
              : (left['sort_order'] as int).compareTo(
                  right['sort_order'] as int,
                );
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
      List<Map<String, dynamic>> activity = [];
      try {
        final events = await _client
            .from('notifications')
            .select('title, body, category, created_at')
            .order('created_at', ascending: false)
            .limit(3);
        activity = (events as List).cast<Map<String, dynamic>>();
      } catch (_) {
        // Activity is helpful, but it must never prevent the dashboard loading.
      }
      if (!mounted) return;
      setState(() {
        final displayName = profile?['display_name'] as String?;
        _name = displayName?.trim().isNotEmpty == true
            ? displayName!
            : user.email ?? _name;
        _admin = admin;
        _apps = apps;
        _status = status;
        _favourites = favourites;
        _hidden = hidden;
        _recentAppIds = recentAppIds;
        _theme = '${dashboardSettings?['theme'] ?? 'ocean'}';
        _layout = '${dashboardSettings?['dashboard_layout'] ?? 'standard'}';
        _avatar = '${dashboardSettings?['avatar_icon'] ?? 'auto'}';
        _appLockEnabled = dashboardSettings?['app_lock_enabled'] == true;
        _maintenance = maintenance;
        _activity = activity;
      });
    } catch (error) {
      if (mounted) {
        setState(() => _error = 'Could not load your Homelab: $error');
      }
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
      final response = await http
          .get(Uri.parse('$_portalUrl/api/status'))
          .timeout(const Duration(seconds: 8));
      if (response.statusCode == 200) {
        return jsonDecode(response.body) as Map<String, dynamic>;
      }
    } catch (_) {}
    return null;
  }

  Future<void> _openApp(Map<String, dynamic> app) async {
    await Navigator.of(context).push(
      MaterialPageRoute<void>(
        builder: (_) => HomelabWebAppScreen(
          title: app['name'] as String,
          url: app['url'] as String,
        ),
      ),
    );
    try {
      await _client.from('audit_events').insert({
        'user_id': _client.auth.currentUser!.id,
        'event_type': 'app_opened',
        'app_id': app['id'],
      });
    } catch (_) {}
  }

  Future<void> _personalise() async {
    final favourites = {..._favourites};
    final hidden = {..._hidden};
    final messenger = ScaffoldMessenger.of(context);
    var theme = _theme;
    var layout = _layout;
    var appLock = _appLockEnabled;
    await showDialog<void>(
      context: context,
      builder: (context) => StatefulBuilder(
        builder: (context, setDialogState) => AlertDialog(
          title: const Text('Personalise your dashboard'),
          content: SizedBox(
            width: 420,
            child: SingleChildScrollView(
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  DropdownButtonFormField<String>(
                    initialValue: theme,
                    decoration: const InputDecoration(
                      labelText: 'Colour theme',
                    ),
                    items: const [
                      DropdownMenuItem(value: 'ocean', child: Text('Ocean')),
                      DropdownMenuItem(value: 'forest', child: Text('Forest')),
                      DropdownMenuItem(value: 'violet', child: Text('Violet')),
                      DropdownMenuItem(value: 'sunset', child: Text('Sunset')),
                    ],
                    onChanged: (value) =>
                        setDialogState(() => theme = value ?? theme),
                  ),
                  const SizedBox(height: 12),
                  DropdownButtonFormField<String>(
                    initialValue: layout,
                    decoration: const InputDecoration(labelText: 'Home layout'),
                    items: const [
                      DropdownMenuItem(
                        value: 'standard',
                        child: Text('Standard'),
                      ),
                      DropdownMenuItem(
                        value: 'compact',
                        child: Text('Compact'),
                      ),
                      DropdownMenuItem(
                        value: 'media_first',
                        child: Text('Media first'),
                      ),
                    ],
                    onChanged: (value) =>
                        setDialogState(() => layout = value ?? layout),
                  ),
                  SwitchListTile(
                    contentPadding: EdgeInsets.zero,
                    title: const Text('Lock when you leave the app'),
                    subtitle: const Text(
                      'Uses your phone’s fingerprint, face or PIN.',
                    ),
                    value: appLock,
                    onChanged: (value) => setDialogState(() => appLock = value),
                  ),
                  const Divider(),
                  ..._apps.map((app) {
                    final id = app['id'] as String;
                    return ListTile(
                      title: Text(app['name'] as String),
                      subtitle: Text(
                        hidden.contains(id)
                            ? 'Hidden from your home screen'
                            : favourites.contains(id)
                            ? 'Pinned to the top'
                            : 'Shown normally',
                      ),
                      trailing: PopupMenuButton<String>(
                        onSelected: (choice) => setDialogState(() {
                          if (choice == 'favourite') {
                            favourites.add(id);
                            hidden.remove(id);
                          }
                          if (choice == 'normal') {
                            favourites.remove(id);
                            hidden.remove(id);
                          }
                          if (choice == 'hide') {
                            hidden.add(id);
                            favourites.remove(id);
                          }
                        }),
                        itemBuilder: (_) => const [
                          PopupMenuItem(
                            value: 'favourite',
                            child: Text('Pin to top'),
                          ),
                          PopupMenuItem(
                            value: 'normal',
                            child: Text('Show normally'),
                          ),
                          PopupMenuItem(value: 'hide', child: Text('Hide')),
                        ],
                      ),
                    );
                  }),
                ],
              ),
            ),
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(context),
              child: const Text('Cancel'),
            ),
            FilledButton(
              onPressed: () async {
                await _client.from('user_preferences').upsert({
                  'user_id': _client.auth.currentUser!.id,
                  'favourite_app_ids': favourites.toList(),
                  'hidden_app_ids': hidden.toList(),
                  'updated_at': DateTime.now().toUtc().toIso8601String(),
                });
                try {
                  await _client.from('user_dashboard_settings').upsert({
                    'user_id': _client.auth.currentUser!.id,
                    'theme': theme,
                    'dashboard_layout': layout,
                    'app_lock_enabled': appLock,
                    'updated_at': DateTime.now().toUtc().toIso8601String(),
                  });
                } catch (_) {
                  if (!context.mounted) return;
                  messenger.showSnackBar(
                    const SnackBar(
                      content: Text(
                        'App choices saved. Run the Release 3 Supabase migration to save theme and app-lock choices.',
                      ),
                    ),
                  );
                }
                if (!context.mounted) return;
                Navigator.pop(context);
                messenger.showSnackBar(
                  const SnackBar(
                    content: Text('Your dashboard preferences were saved.'),
                  ),
                );
                _load();
              },
              child: const Text('Save'),
            ),
          ],
        ),
      ),
    );
  }

  IconData _profileIcon() => switch (_avatar) {
    'home' => Icons.home_outlined,
    'movie' => Icons.movie_outlined,
    'game' => Icons.sports_esports_outlined,
    'photo' => Icons.photo_camera_outlined,
    'star' => Icons.star_outline,
    _ => Icons.account_circle_outlined,
  };

  IconData _activityIcon(String category) => switch (category) {
    'unraid' => Icons.dns_outlined,
    'home_assistant' => Icons.home_outlined,
    'app_update' => Icons.system_update_outlined,
    'app' => Icons.apps_outlined,
    _ => Icons.bolt_outlined,
  };

  Future<void> _checkForUpdates() async {
    final messenger = ScaffoldMessenger.of(context);
    messenger.showSnackBar(
      const SnackBar(content: Text('Checking for updates…')),
    );
    try {
      final installed = await PackageInfo.fromPlatform();
      // A versioned URL prevents an old Azure/CDN response masking a new APK.
      final updateUrl = Uri.parse('$_portalUrl/app-update.json').replace(
        queryParameters: {
          'check': DateTime.now().millisecondsSinceEpoch.toString(),
        },
      );
      final response = await http
          .get(updateUrl, headers: const {'Cache-Control': 'no-cache'})
          .timeout(const Duration(seconds: 8));
      if (response.statusCode != 200) throw Exception();
      final release = jsonDecode(
        response.body.trimLeft().replaceFirst('\uFEFF', ''),
      ) as Map<String, dynamic>;
      final latest = int.tryParse('${release['versionCode']}') ?? 0;
      final current = int.tryParse(installed.buildNumber) ?? 0;
      if (!mounted) return;
      if (latest <= current) {
        messenger.hideCurrentSnackBar();
        messenger.showSnackBar(
          const SnackBar(content: Text('You have the latest version.')),
        );
        return;
      }
      await showDialog<void>(
        context: context,
        builder: (context) => AlertDialog(
          title: Text('Update ${release['version'] ?? ''} available'),
          content: Text(
            '${release['notes'] ?? 'A new Homelab app update is ready.'}\n\nAndroid will ask you to confirm the install.',
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(context),
              child: const Text('Later'),
            ),
            FilledButton(
              onPressed: release['downloadUrl'] == null
                  ? null
                  : () {
                      Navigator.pop(context);
                      _downloadAndInstallUpdate(release);
                    },
              child: const Text('Download update'),
            ),
          ],
        ),
      );
    } catch (_) {
      messenger.hideCurrentSnackBar();
      messenger.showSnackBar(
        const SnackBar(content: Text('No published app update yet.')),
      );
    }
  }

  Future<void> _downloadAndInstallUpdate(Map<String, dynamic> release) async {
    final messenger = ScaffoldMessenger.of(context);
    final url = Uri.tryParse('${release['downloadUrl']}');
    final expectedHash = '${release['sha256'] ?? ''}'.trim().toLowerCase();
    final trustedRelease =
        url != null &&
        url.scheme == 'https' &&
        url.host == 'github.com' &&
        url.path.startsWith('/condoggett/unraidconnor/releases/download/');
    if (!trustedRelease || !RegExp(r'^[a-f0-9]{64}$').hasMatch(expectedHash)) {
      messenger.showSnackBar(
        const SnackBar(
          content: Text(
            'This update is not a verified Connor Homelab release.',
          ),
        ),
      );
      return;
    }
    try {
      messenger.showSnackBar(
        const SnackBar(content: Text('Downloading verified update…')),
      );
      final directory = await getApplicationDocumentsDirectory();
      final version = '${release['version'] ?? 'latest'}'.replaceAll(
        RegExp(r'[^0-9A-Za-z._-]'),
        '_',
      );
      final apk = File('${directory.path}/Connor-Homelab-$version.apk');
      await Dio().download(url.toString(), apk.path);
      final actualHash = await sha256.bind(apk.openRead()).first;
      if (actualHash.toString().toLowerCase() != expectedHash) {
        await apk.delete();
        throw Exception('The download did not pass its security check.');
      }
      if (!mounted) return;
      messenger.hideCurrentSnackBar();
      messenger.showSnackBar(
        const SnackBar(
          content: Text(
            'Download complete. Confirm Android’s install prompt to update.',
          ),
        ),
      );
      final result = await OpenFilex.open(
        apk.path,
        type: 'application/vnd.android.package-archive',
      );
      if (result.type != ResultType.done && mounted) {
        messenger.showSnackBar(
          const SnackBar(
            content: Text(
              'Allow Connor Homelab to install unknown apps, then try Update again.',
            ),
          ),
        );
      }
    } catch (error) {
      if (mounted) {
        messenger.hideCurrentSnackBar();
        messenger.showSnackBar(
          SnackBar(content: Text('Update failed: $error')),
        );
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    final visibleApps = _apps
        .where((app) => !_hidden.contains(app['id']))
        .toList();
    final favourites = visibleApps
        .where((app) => _favourites.contains(app['id']))
        .toList();
    final byId = {for (final app in visibleApps) app['id'] as String: app};
    final recent = _recentAppIds
        .map((id) => byId[id])
        .whereType<Map<String, dynamic>>()
        .toList();
    final allApps = visibleApps
        .where((app) => !favourites.contains(app) && !recent.contains(app))
        .toList();
    if (_layout == 'media_first') {
      allApps.sort(
        (a, b) => '${b['name']}'
            .toLowerCase()
            .contains('seerr')
            .toString()
            .compareTo(
              '${a['name']}'.toLowerCase().contains('seerr').toString(),
            ),
      );
    }
    final accent = switch (_theme) {
      'forest' => const Color(0xff72d89a),
      'violet' => const Color(0xffc5a4ff),
      'sunset' => const Color(0xffffb378),
      _ => const Color(0xff72d8ff),
    };
    final horizontalPadding = _layout == 'compact' ? 12.0 : 18.0;
    return AppLock(
      enabled: _appLockEnabled,
      child: Theme(
        data: Theme.of(context).copyWith(
          colorScheme: ColorScheme.fromSeed(
            seedColor: accent,
            brightness: Brightness.dark,
          ),
        ),
        child: Scaffold(
          appBar: AppBar(
            title: const Text('Connor Homelab'),
            actions: [
              IconButton(
                onPressed: () => Navigator.of(context).push(
                  MaterialPageRoute<void>(
                    builder: (_) => const NowAvailableScreen(),
                  ),
                ),
                tooltip: 'Now available',
                icon: const Icon(Icons.movie_filter_outlined),
              ),
              PopupMenuButton<String>(
                tooltip: 'More options',
                onSelected: (choice) {
                  switch (choice) {
                    case 'home':
                      Navigator.of(context).push(
                        MaterialPageRoute<void>(
                          builder: (_) =>
                              HomeAssistantHubScreen(status: _status),
                        ),
                      );
                      break;
                    case 'unraid':
                      Navigator.of(context).push(
                        MaterialPageRoute<void>(
                          builder: (_) => UnraidDashboardScreen(
                            status: _status,
                            admin: _admin,
                          ),
                        ),
                      );
                      break;
                    case 'history':
                      Navigator.of(context).push(
                        MaterialPageRoute<void>(
                          builder: (_) => const NotificationHistoryScreen(),
                        ),
                      );
                      break;
                    case 'activity':
                      Navigator.of(context).push(
                        MaterialPageRoute<void>(
                          builder: (_) => const FamilyActivityScreen(),
                        ),
                      );
                      break;
                    case 'immich':
                      Navigator.of(context).push(
                        MaterialPageRoute<void>(
                          builder: (_) => const ImmichHighlightsScreen(),
                        ),
                      );
                      break;
                    case 'maintenance':
                      Navigator.of(context).push(
                        MaterialPageRoute<void>(
                          builder: (_) =>
                              MaintenanceCenterScreen(admin: _admin),
                        ),
                      );
                      break;
                    case 'diagnostics':
                      Navigator.of(context).push(
                        MaterialPageRoute<void>(
                          builder: (_) => const DiagnosticsScreen(),
                        ),
                      );
                      break;
                    case 'notes':
                      Navigator.of(context).push(
                        MaterialPageRoute<void>(
                          builder: (_) => const ReleaseNotesScreen(),
                        ),
                      );
                      break;
                    case 'notifications':
                      Navigator.of(context).push(
                        MaterialPageRoute<void>(
                          builder: (_) => const NotificationSettingsScreen(),
                        ),
                      );
                      break;
                    case 'personalise':
                      _personalise();
                      break;
                    case 'profile':
                      Navigator.of(context)
                          .push<bool>(
                            MaterialPageRoute<bool>(
                              builder: (_) => const ProfileScreen(),
                            ),
                          )
                          .then((saved) {
                            if (saved == true) _load();
                          });
                      break;
                    case 'update':
                      _checkForUpdates();
                      break;
                    case 'signout':
                      _client.auth.signOut();
                      break;
                  }
                },
                itemBuilder: (context) => [
                  PopupMenuItem(
                    value: 'home',
                    child: ListTile(
                      leading: Icon(Icons.home_outlined),
                      title: Text('Home Assistant'),
                    ),
                  ),
                  PopupMenuItem(
                    value: 'unraid',
                    child: ListTile(
                      leading: Icon(Icons.dns_outlined),
                      title: Text('Unraid dashboard'),
                    ),
                  ),
                  PopupMenuDivider(),
                  PopupMenuItem(
                    value: 'history',
                    child: ListTile(
                      leading: Icon(Icons.notifications_outlined),
                      title: Text('Notification history'),
                    ),
                  ),
                  PopupMenuItem(
                    value: 'activity',
                    child: ListTile(
                      leading: Icon(Icons.bolt_outlined),
                      title: Text('Your activity'),
                    ),
                  ),
                  PopupMenuItem(
                    value: 'immich',
                    child: ListTile(
                      leading: Icon(Icons.photo_library_outlined),
                      title: Text('Immich highlights'),
                    ),
                  ),
                  PopupMenuItem(
                    value: 'maintenance',
                    child: ListTile(
                      leading: Icon(Icons.construction_outlined),
                      title: Text('Maintenance centre'),
                    ),
                  ),
                  PopupMenuItem(
                    value: 'notes',
                    child: ListTile(
                      leading: Icon(Icons.new_releases_outlined),
                      title: Text('What’s new'),
                    ),
                  ),
                  PopupMenuItem(
                    value: 'notifications',
                    child: ListTile(
                      leading: Icon(Icons.notifications_active_outlined),
                      title: Text('Notification settings'),
                    ),
                  ),
                  PopupMenuItem(
                    value: 'profile',
                    child: ListTile(
                      leading: Icon(_profileIcon()),
                      title: const Text('My profile'),
                    ),
                  ),
                  PopupMenuItem(
                    value: 'personalise',
                    child: ListTile(
                      leading: Icon(Icons.tune),
                      title: Text('Personalise dashboard'),
                    ),
                  ),
                  PopupMenuItem(
                    value: 'update',
                    child: ListTile(
                      leading: Icon(Icons.system_update_outlined),
                      title: Text('Check for updates'),
                    ),
                  ),
                  PopupMenuItem(
                    value: 'diagnostics',
                    child: ListTile(
                      leading: Icon(Icons.monitor_heart_outlined),
                      title: Text('Connection diagnostics'),
                    ),
                  ),
                  PopupMenuDivider(),
                  PopupMenuItem(
                    value: 'signout',
                    child: ListTile(
                      leading: Icon(Icons.logout),
                      title: Text('Sign out'),
                    ),
                  ),
                ],
              ),
            ],
          ),
          body: RefreshIndicator(
            onRefresh: _load,
            child: _loading
                ? const Center(child: CircularProgressIndicator())
                : ListView(
                    padding: EdgeInsets.all(horizontalPadding),
                    children: [
                      Row(
                        children: [
                          CircleAvatar(child: Icon(_profileIcon())),
                          const SizedBox(width: 12),
                          Expanded(
                            child: Text(
                              'Welcome back, $_name',
                              style: Theme.of(context).textTheme.headlineSmall,
                            ),
                          ),
                        ],
                      ),
                      const SizedBox(height: 5),
                      Text(
                        _admin
                            ? 'Administrator · Full Homelab access'
                            : 'Your family Homelab services',
                      ),
                      const SizedBox(height: 18),
                      _StatusCard(status: _status),
                      if (_maintenance != null)
                        Padding(
                          padding: const EdgeInsets.only(top: 14),
                          child: Card(
                            color: const Color(0xff4a3518),
                            child: ListTile(
                              leading: const Icon(Icons.construction_outlined),
                              title: Text('${_maintenance!['title']}'),
                              subtitle: Text(
                                '${_maintenance!['message'] ?? 'Some services may be briefly unavailable.'}',
                              ),
                            ),
                          ),
                        ),
                      if (_activity.isNotEmpty) ...[
                        const SizedBox(height: 20),
                        Row(
                          children: [
                            Expanded(
                              child: _SectionHeading(
                                title: 'Latest for you',
                                subtitle: 'Recent homelab activity',
                              ),
                            ),
                            TextButton(
                              onPressed: () => Navigator.of(context).push(
                                MaterialPageRoute<void>(
                                  builder: (_) => const FamilyActivityScreen(),
                                ),
                              ),
                              child: const Text('See all'),
                            ),
                          ],
                        ),
                        const SizedBox(height: 8),
                        ..._activity.map(
                          (event) => Card(
                            child: ListTile(
                              dense: true,
                              leading: Icon(
                                _activityIcon('${event['category'] ?? ''}'),
                              ),
                              title: Text(
                                '${event['title'] ?? 'Homelab activity'}',
                                maxLines: 1,
                                overflow: TextOverflow.ellipsis,
                              ),
                              subtitle: Text(
                                '${event['body'] ?? ''}',
                                maxLines: 1,
                                overflow: TextOverflow.ellipsis,
                              ),
                            ),
                          ),
                        ),
                      ],
                      if (_error != null)
                        Padding(
                          padding: const EdgeInsets.only(top: 14),
                          child: Text(
                            _error!,
                            style: TextStyle(
                              color: Theme.of(context).colorScheme.error,
                            ),
                          ),
                        ),
                      if (favourites.isNotEmpty) ...[
                        const SizedBox(height: 24),
                        const _SectionHeading(
                          title: 'Pinned for you',
                          subtitle: 'Your favourite services',
                        ),
                        const SizedBox(height: 10),
                        SizedBox(
                          height: 132,
                          child: ListView.separated(
                            scrollDirection: Axis.horizontal,
                            itemCount: favourites.length,
                            separatorBuilder: (_, _) =>
                                const SizedBox(width: 10),
                            itemBuilder: (_, index) => _QuickAppTile(
                              app: favourites[index],
                              onTap: () => _openApp(favourites[index]),
                            ),
                          ),
                        ),
                      ],
                      if (recent.isNotEmpty) ...[
                        const SizedBox(height: 24),
                        const _SectionHeading(
                          title: 'Continue where you left off',
                          subtitle: 'Recently opened services',
                        ),
                        const SizedBox(height: 10),
                        SizedBox(
                          height: 132,
                          child: ListView.separated(
                            scrollDirection: Axis.horizontal,
                            itemCount: recent.length,
                            separatorBuilder: (_, _) =>
                                const SizedBox(width: 10),
                            itemBuilder: (_, index) => _QuickAppTile(
                              app: recent[index],
                              onTap: () => _openApp(recent[index]),
                            ),
                          ),
                        ),
                      ],
                      const SizedBox(height: 24),
                      _SectionHeading(
                        title: favourites.isEmpty && recent.isEmpty
                            ? 'Your apps'
                            : 'All apps',
                        subtitle:
                            '${visibleApps.length} service${visibleApps.length == 1 ? '' : 's'} available to you',
                      ),
                      const SizedBox(height: 10),
                      if (visibleApps.isEmpty)
                        const Card(
                          child: Padding(
                            padding: EdgeInsets.all(18),
                            child: Text(
                              'No apps have been assigned to this account yet. Ask an admin to grant access.',
                            ),
                          ),
                        ),
                      ...allApps.map(
                        (app) => Card(
                          child: ListTile(
                            leading: CircleAvatar(
                              child: Text(
                                (app['icon'] as String?)?.isNotEmpty == true
                                    ? app['icon'] as String
                                    : '•',
                              ),
                            ),
                            title: Text(app['name'] as String),
                            subtitle: Text(
                              (app['description'] as String?) ?? '',
                            ),
                            trailing: const Icon(Icons.arrow_forward_ios),
                            onTap: () => _openApp(app),
                          ),
                        ),
                      ),
                      const SizedBox(height: 18),
                      OutlinedButton.icon(
                        onPressed: _checkForUpdates,
                        icon: const Icon(Icons.system_update_outlined),
                        label: const Text('Check for app updates'),
                      ),
                      const SizedBox(height: 10),
                      Text(
                        'Pull down to refresh your status and app access.',
                        textAlign: TextAlign.center,
                        style: Theme.of(context).textTheme.bodySmall,
                      ),
                    ],
                  ),
          ),
        ),
      ),
    );
  }
}

class _SectionHeading extends StatelessWidget {
  const _SectionHeading({required this.title, required this.subtitle});
  final String title;
  final String subtitle;

  @override
  Widget build(BuildContext context) => Column(
    crossAxisAlignment: CrossAxisAlignment.start,
    children: [
      Text(title, style: Theme.of(context).textTheme.titleLarge),
      const SizedBox(height: 2),
      Text(subtitle, style: Theme.of(context).textTheme.bodySmall),
    ],
  );
}

class _QuickAppTile extends StatelessWidget {
  const _QuickAppTile({required this.app, required this.onTap});
  final Map<String, dynamic> app;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final icon = (app['icon'] as String?)?.trim();
    return SizedBox(
      width: 152,
      child: Card(
        clipBehavior: Clip.antiAlias,
        child: InkWell(
          onTap: onTap,
          child: Padding(
            padding: const EdgeInsets.all(16),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                CircleAvatar(
                  child: Text(icon?.isNotEmpty == true ? icon! : '•'),
                ),
                const Spacer(),
                Text(
                  app['name'] as String,
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: Theme.of(context).textTheme.titleSmall,
                ),
                const SizedBox(height: 2),
                const Text('Open service', style: TextStyle(fontSize: 12)),
              ],
            ),
          ),
        ),
      ),
    );
  }
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
        child: Row(
          children: [
            Icon(
              online ? Icons.check_circle : Icons.cloud_off,
              color: online ? const Color(0xff66e59a) : Colors.amber,
              size: 34,
            ),
            const SizedBox(width: 14),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    online ? 'Unraid is online' : 'Unraid status unavailable',
                    style: Theme.of(context).textTheme.titleMedium,
                  ),
                  const SizedBox(height: 3),
                  Text(
                    online
                        ? '${status?['hostname'] ?? 'Tower'} · ${status?['cpuCores'] ?? '?'} CPU cores${usage == null ? '' : ' · $usage% memory'}'
                        : 'Pull down to try again.',
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }
}
