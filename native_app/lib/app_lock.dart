import 'package:flutter/material.dart';
import 'package:local_auth/local_auth.dart';

/// Adds an optional biometric gate when the app returns to the foreground.
/// The setting itself is stored against the signed-in Homelab profile, never in
/// the app package. Android owns the enrolled fingerprint/face data.
class AppLock extends StatefulWidget {
  const AppLock({super.key, required this.enabled, required this.child});
  final bool enabled;
  final Widget child;

  @override
  State<AppLock> createState() => _AppLockState();
}

class _AppLockState extends State<AppLock> with WidgetsBindingObserver {
  final _auth = LocalAuthentication();
  bool _needsUnlock = false;
  bool _unlocking = false;
  String? _error;

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addObserver(this);
  }

  @override
  void didUpdateWidget(covariant AppLock oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (!widget.enabled) {
      setState(() {
        _needsUnlock = false;
        _error = null;
      });
    }
  }

  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    if (widget.enabled &&
        (state == AppLifecycleState.inactive ||
            state == AppLifecycleState.paused)) {
      setState(() => _needsUnlock = true);
    }
  }

  @override
  void dispose() {
    WidgetsBinding.instance.removeObserver(this);
    super.dispose();
  }

  Future<void> _unlock() async {
    if (_unlocking) {
      return;
    }
    setState(() {
      _unlocking = true;
      _error = null;
    });
    try {
      final available =
          await _auth.canCheckBiometrics || await _auth.isDeviceSupported();
      if (!available) {
        throw Exception(
          'Set up a screen lock or fingerprint on this phone first.',
        );
      }
      final ok = await _auth.authenticate(
        localizedReason: 'Unlock Connor Homelab',
        options: const AuthenticationOptions(
          biometricOnly: false,
          stickyAuth: true,
        ),
      );
      if (!mounted) {
        return;
      }
      if (ok) {
        setState(() => _needsUnlock = false);
      } else {
        setState(() => _error = 'Your phone did not unlock the app.');
      }
    } catch (_) {
      if (mounted) {
        setState(
          () => _error = 'Unable to use your phone lock. Set up a screen lock or fingerprint, then try again.',
        );
      }
    } finally {
      if (mounted) {
        setState(() => _unlocking = false);
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    if (!widget.enabled || !_needsUnlock) return widget.child;
    return Scaffold(
      body: SafeArea(
        child: Center(
          child: Padding(
            padding: const EdgeInsets.all(28),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                const Icon(Icons.fingerprint, size: 64),
                const SizedBox(height: 18),
                Text(
                  'Connor Homelab is locked',
                  style: Theme.of(context).textTheme.headlineSmall,
                ),
                const SizedBox(height: 8),
                const Text('Use your phone lock to continue.'),
                if (_error != null)
                  Padding(
                    padding: const EdgeInsets.only(top: 12),
                    child: Text(_error!, textAlign: TextAlign.center),
                  ),
                const SizedBox(height: 20),
                FilledButton.icon(
                  onPressed: _unlocking ? null : _unlock,
                  icon: const Icon(Icons.lock_open),
                  label: const Text('Unlock'),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}
