import 'package:flutter/material.dart';
import 'package:url_launcher/url_launcher.dart';
import 'package:webview_flutter/webview_flutter.dart';
import 'package:webview_flutter_android/webview_flutter_android.dart';

class HomelabWebAppScreen extends StatefulWidget {
  const HomelabWebAppScreen({
    super.key,
    required this.title,
    required this.url,
  });
  final String title;
  final String url;

  @override
  State<HomelabWebAppScreen> createState() => _HomelabWebAppScreenState();
}

class _HomelabWebAppScreenState extends State<HomelabWebAppScreen> {
  late final WebViewController _controller;
  int _progress = 0;
  String? _error;

  @override
  void initState() {
    super.initState();
    _controller = WebViewController()
      ..setJavaScriptMode(JavaScriptMode.unrestricted)
      ..setNavigationDelegate(
        NavigationDelegate(
          onProgress: (value) {
            if (mounted) setState(() => _progress = value);
          },
          onPageStarted: (_) {
            if (mounted) setState(() => _error = null);
          },
          onWebResourceError: (error) {
            if (mounted && error.isForMainFrame)
              setState(() => _error = error.description);
          },
          onNavigationRequest: (request) {
            final uri = Uri.tryParse(request.url);
            if (uri == null || uri.scheme != 'https')
              return NavigationDecision.prevent;
            return NavigationDecision.navigate;
          },
        ),
      );
    _prepareSession();
  }

  Future<void> _prepareSession() async {
    // Cloudflare Access can use a third-party cookie during its secure sign-in
    // hand-off.  Android WebView does not always accept it by default, which
    // made the user appear signed out every time this in-app page opened.
    final platformController = _controller.platform;
    final cookieManager = WebViewCookieManager().platform;
    if (platformController is AndroidWebViewController &&
        cookieManager is AndroidWebViewCookieManager) {
      await cookieManager.setAcceptThirdPartyCookies(platformController, true);
    }
    if (mounted) await _controller.loadRequest(Uri.parse(widget.url));
  }

  Future<void> _openOutside() =>
      launchUrl(Uri.parse(widget.url), mode: LaunchMode.externalApplication);

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
          // The normal Back button follows the service's own history. A
          // login redirect can have several history entries, so always
          // provide an explicit escape route back to the app dashboard.
          IconButton(
            onPressed: () => Navigator.of(this.context).pop(),
            icon: const Icon(Icons.close),
            tooltip: 'Return to Homelab',
          ),
          IconButton(
            onPressed: () => _controller.reload(),
            icon: const Icon(Icons.refresh),
            tooltip: 'Refresh',
          ),
          IconButton(
            onPressed: _openOutside,
            icon: const Icon(Icons.open_in_browser),
            tooltip: 'Open in browser',
          ),
        ],
        bottom: _progress < 100
            ? PreferredSize(
                preferredSize: const Size.fromHeight(3),
                child: LinearProgressIndicator(value: _progress / 100),
              )
            : null,
      ),
      body: Stack(
        children: [
          WebViewWidget(controller: _controller),
          if (_error != null)
            Align(
              alignment: Alignment.bottomCenter,
              child: SafeArea(
                child: Padding(
                  padding: const EdgeInsets.all(12),
                  child: Card(
                    child: Padding(
                      padding: const EdgeInsets.all(12),
                      child: Row(
                        children: [
                          const Icon(Icons.cloud_off_outlined),
                          const SizedBox(width: 10),
                          const Expanded(
                            child: Text(
                              'This service could not be reached. Check your internet, then your Cloudflare session or Homelab tunnel.',
                            ),
                          ),
                          TextButton(
                            onPressed: () => _controller.reload(),
                            child: const Text('Retry'),
                          ),
                        ],
                      ),
                    ),
                  ),
                ),
              ),
            ),
        ],
      ),
    ),
  );
}
