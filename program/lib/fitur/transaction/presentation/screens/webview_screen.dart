import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import 'package:webview_flutter/webview_flutter.dart';

class WebViewScreen extends StatefulWidget {
  final String url;
  const WebViewScreen({super.key, required this.url});

  @override
  State<WebViewScreen> createState() => _WebViewScreenState();
}

class _WebViewScreenState extends State<WebViewScreen> {
  late final WebViewController _controller;
  int _loadingPercentage = 0;
  bool _paymentCompleted = false;

  @override
  void initState() {
    super.initState();
    _controller = WebViewController()
      ..setJavaScriptMode(JavaScriptMode.unrestricted)
      ..setNavigationDelegate(
        NavigationDelegate(
          onProgress: (int progress) {
            if (mounted) setState(() => _loadingPercentage = progress);
          },
          onPageFinished: (String url) {
            if (mounted) setState(() => _loadingPercentage = 100);
          },
          onNavigationRequest: (NavigationRequest request) {
            // Deteksi halaman sukses Xendit
            if (request.url.startsWith('https://ngoper.app/topup/success')) {
              _paymentCompleted = true;
              // Kembali dengan status success (true)
              if (mounted) {
                context.pop(true);
              }
              return NavigationDecision.prevent;
            }
            return NavigationDecision.navigate;
          },
        ),
      )
      ..loadRequest(Uri.parse(widget.url));
  }

  @override
  Widget build(BuildContext context) {
    return PopScope(
      canPop: true,
      onPopInvoked: (bool didPop) {
        // Jika user menekan tombol back dan pembayaran belum selesai
        // kirim false sebagai hasil
        if (didPop && !_paymentCompleted) {
          // Context.pop sudah dipanggil oleh sistem, kita hanya perlu
          // memastikan nilai yang dikirim adalah false
          Future.microtask(() {
            if (mounted && Navigator.canPop(context)) {
              Navigator.of(context).pop(false);
            }
          });
        }
      },
      child: Scaffold(
        appBar: AppBar(
          title: const Text('Pembayaran'),
          leading: IconButton(
            icon: const Icon(Icons.close),
            onPressed: () {
              // Kirim false karena user membatalkan
              context.pop(false);
            },
          ),
        ),
        body: Stack(
          children: [
            WebViewWidget(controller: _controller),
            if (_loadingPercentage < 100)
              LinearProgressIndicator(value: _loadingPercentage / 100),
          ],
        ),
      ),
    );
  }
}