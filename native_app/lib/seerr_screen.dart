import 'package:flutter/material.dart';
import 'package:url_launcher/url_launcher.dart';
import 'package:webview_flutter/webview_flutter.dart';
import 'package:webview_flutter_android/webview_flutter_android.dart';

class HomelabWebAppScreen extends StatefulWidget {
  const HomelabWebAppScreen({super.key, required this.title, required this.url});
  final String title;
  final String url;

  @override
  State<HomelabWebAppScreen> createState() => _HomelabWebAppScreenState();
}

class _HomelabWebAppScreenState extends State<HomelabWebAppScreen> {
  late final WebViewController _controller;
  int _progress = 0;

  @override
  void initState() {
    super.initState();
    _controller = WebViewController()
      ..setJavaScriptMode(JavaScriptMode.unrestricted)
      ..setNavigationDelegate(NavigationDelegate(
        onProgress: (value) {
          if (mounted) setState(() => _progress = value);
        },
        onNavigationRequest: (request) {
          final uri = Uri.tryParse(request.url);
          if (uri == null || uri.scheme != 'https') return NavigationDecision.prevent;
          return NavigationDecision.navigate;
        },
      ));
    _prepareSession();
  }

  Future<void> _prepareSession() async {
    // Cloudflare Access can use a third-party cookie during its secure sign-in
    // hand-off.  Android WebView does not always accept it by default, which
    // made the user appear signed out every time this in-app page opened.
    final platformController = _controller.platform;
    final cookieManager = WebViewCookieManager().platform;
    if (platformController is AndroidWebViewController && cookieManager is AndroidWebViewCookieManager) {
      await cookieManager.setAcceptThirdPartyCookies(platformController, true);
    }
    if (mounted) await _controller.loadRequest(Uri.parse(widget.url));
  }

  Future<void> _openOutside() => launchUrl(Uri.parse(widget.url), mode: LaunchMode.externalApplication);

  Future<bool> _goBackInService() async {
    if (await _controller.canGoBack()) {
      await _controller.goBack();
      return false;
    }
    return true;
  }

  @override
  Widget build(BuildContext context) => PopScope(
        canPop: false,
        onPopInvokedWithResult: (didPop, _) async {
          if (didPop) return;
          final leaveService = await _goBackInService();
          if (!mounted || !leaveService) return;
          Navigator.of(this.context).pop();
        },
        child: Scaffold(
          appBar: AppBar(
            leading: IconButton(
              onPressed: () async {
                final leaveService = await _goBackInService();
                if (!mounted || !leaveService) return;
                Navigator.of(this.context).pop();
              },
              icon: const Icon(Icons.arrow_back),
              tooltip: 'Back',
            ),
            title: Text(widget.title),
            actions: [
              IconButton(onPressed: () => _controller.reload(), icon: const Icon(Icons.refresh), tooltip: 'Refresh'),
              IconButton(onPressed: _openOutside, icon: const Icon(Icons.open_in_browser), tooltip: 'Open in browser'),
            ],
            bottom: _progress < 100 ? PreferredSize(preferredSize: const Size.fromHeight(3), child: LinearProgressIndicator(value: _progress / 100)) : null,
          ),
          body: WebViewWidget(controller: _controller),
        ),
      );
}
