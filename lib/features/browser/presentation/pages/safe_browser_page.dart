import 'package:flutter/material.dart';
import 'package:webview_flutter/webview_flutter.dart';

class SafeBrowserPage extends StatefulWidget {
  final String url;
  final String verdict; // 'safe', 'suspicious', 'dangerous'
  final String summary; // Gemini's analysis summary
  final int riskScore;

  const SafeBrowserPage({
    super.key,
    required this.url,
    required this.verdict,
    required this.summary,
    this.riskScore = 0,
  });

  @override
  State<SafeBrowserPage> createState() => _SafeBrowserPageState();
}

class _SafeBrowserPageState extends State<SafeBrowserPage> {
  late final WebViewController _controller;
  bool _isLoading = true;
  bool _bannerDismissed = false;

  @override
  void initState() {
    super.initState();
    _controller = WebViewController()
      ..setJavaScriptMode(JavaScriptMode.unrestricted)
      ..setNavigationDelegate(
        NavigationDelegate(
          onPageStarted: (_) => setState(() => _isLoading = true),
          onPageFinished: (_) => setState(() => _isLoading = false),
        ),
      )
      ..loadRequest(Uri.parse(widget.url));
  }

  Color get _bannerColor {
    switch (widget.verdict) {
      case 'dangerous':
        return Colors.red;
      case 'suspicious':
        return Colors.orange;
      default:
        return Colors.green;
    }
  }

  IconData get _bannerIcon {
    switch (widget.verdict) {
      case 'dangerous':
        return Icons.dangerous;
      case 'suspicious':
        return Icons.warning_amber_rounded;
      default:
        return Icons.verified_user;
    }
  }

  String get _bannerText {
    switch (widget.verdict) {
      case 'dangerous':
        return '⚠️ DANGEROUS — This site is likely a scam';
      case 'suspicious':
        return '⚠️ SUSPICIOUS — Proceed with caution';
      default:
        return '✅ VERIFIED SAFE';
    }
  }

  @override
  Widget build(BuildContext context) {
    final isSafe = widget.verdict == 'safe';

    return Scaffold(
      body: SafeArea(
        child: Column(
          children: [
            // Verdict banner at top
            if (!_bannerDismissed)
              GestureDetector(
                onTap: () {
                  // Show full analysis
                  showModalBottomSheet(
                    context: context,
                    builder: (_) => Padding(
                      padding: const EdgeInsets.all(20),
                      child: Column(
                        mainAxisSize: MainAxisSize.min,
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            isSafe ? 'Verified Safe by Gemini' : 'Security Warning from Gemini',
                            style: Theme.of(context).textTheme.titleLarge,
                          ),
                          const SizedBox(height: 12),
                          Text(widget.summary),
                          const SizedBox(height: 16),
                          Text('URL: ${widget.url}',
                              style: const TextStyle(
                                  fontSize: 12, color: Colors.grey)),
                          const SizedBox(height: 16),
                          Row(
                            children: [
                              Expanded(
                                child: ElevatedButton(
                                  onPressed: () => Navigator.pop(context),
                                  child: const Text('Close'),
                                ),
                              ),
                              const SizedBox(width: 12),
                              Expanded(
                                child: ElevatedButton(
                                  style: ElevatedButton.styleFrom(
                                      backgroundColor: isSafe ? Colors.green : Colors.red),
                                  onPressed: () {
                                    Navigator.pop(context); // close sheet
                                    if (!isSafe) {
                                      Navigator.pop(context); // close browser if not safe
                                    }
                                  },
                                  child: Text(
                                    isSafe ? 'Continue to Site' : 'Leave Site',
                                    style: const TextStyle(color: Colors.white),
                                  ),
                                ),
                              ),
                            ],
                          ),
                        ],
                      ),
                    ),
                  );
                },
                child: Container(
                  width: double.infinity,
                  padding:
                      const EdgeInsets.symmetric(horizontal: 16, vertical: 10),
                  color: _bannerColor,
                  child: Row(
                    children: [
                      Icon(_bannerIcon, color: Colors.white, size: 20),
                      const SizedBox(width: 8),
                      Expanded(
                        child: Text(
                          _bannerText,
                          style: const TextStyle(
                              color: Colors.white,
                              fontWeight: FontWeight.bold,
                              fontSize: 13),
                        ),
                      ),
                      const Text('Tap for details',
                          style: TextStyle(color: Colors.white70, fontSize: 11)),
                      const SizedBox(width: 8),
                      GestureDetector(
                        onTap: () =>
                            setState(() => _bannerDismissed = true),
                        child:
                            const Icon(Icons.close, color: Colors.white, size: 18),
                      ),
                    ],
                  ),
                ),
              ),

            // URL bar
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
              color: Colors.grey[100],
              child: Row(
                children: [
                  IconButton(
                    icon: const Icon(Icons.arrow_back),
                    onPressed: () => Navigator.pop(context),
                    iconSize: 20,
                  ),
                  Icon(
                    widget.url.startsWith('https')
                        ? Icons.lock
                        : Icons.lock_open,
                    size: 16,
                    color: widget.url.startsWith('https')
                        ? Colors.green
                        : Colors.red,
                  ),
                  const SizedBox(width: 8),
                  Expanded(
                    child: Text(
                      widget.url,
                      overflow: TextOverflow.ellipsis,
                      style: const TextStyle(fontSize: 13),
                    ),
                  ),
                  if (_isLoading)
                    const SizedBox(
                      width: 16,
                      height: 16,
                      child: CircularProgressIndicator(strokeWidth: 2),
                    ),
                ],
              ),
            ),

            // WebView
            Expanded(
              child: WebViewWidget(controller: _controller),
            ),
          ],
        ),
      ),
    );
  }
}
