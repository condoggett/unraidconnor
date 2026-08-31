import 'package:flutter/material.dart';
import 'package:url_launcher/url_launcher.dart';
import 'package:webview_flutter/webview_flutter.dart';

class SeerrScreen extends StatefulWidget {
  const SeerrScreen({super.key, required this.url});
  final String url;

  @override
  State<SeerrScreen> createState() => _SeerrScreenState();
}

class _SeerrScreenState extends State<SeerrScreen> {
  late final WebViewController _controller;
  int _progress = 0;

  @override
  void initState() {
    super.initState();
    _controller = WebViewController()
      ..setJavaScriptMode(JavaScriptMode.unrestricted)
      ..setNavigationDelegate(NavigationDelegate(
        onProgress: (value) => mounted ? setState(() => _progress = value) : null,
        onNavigationRequest: (request) {
          final uri = Uri.tryParse(request.url);
          if (uri == null || uri.scheme != 'https') return NavigationDecision.prevent;
          return NavigationDecision.navigate;
        },
      ))
      ..loadRequest(Uri.parse(widget.url));
  }

  Future<void> _openOutside() => launchUrl(Uri.parse(widget.url), mode: LaunchMode.externalApplication);

  @override
  Widget build(BuildContext context) => Scaffold(
        appBar: AppBar(
          title: const Text('Seerr'),
          actions: [
            IconButton(onPressed: () => _controller.reload(), icon: const Icon(Icons.refresh), tooltip: 'Refresh'),
            IconButton(onPressed: _openOutside, icon: const Icon(Icons.open_in_browser), tooltip: 'Open in browser'),
          ],
          bottom: _progress < 100 ? PreferredSize(preferredSize: const Size.fromHeight(3), child: LinearProgressIndicator(value: _progress / 100)) : null,
        ),
        body: WebViewWidget(controller: _controller),
      );
}
