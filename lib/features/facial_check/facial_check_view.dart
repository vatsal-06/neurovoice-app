import 'dart:convert';
import 'dart:io';

import 'package:neurovoice_app/core/models/face_result.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:hive/hive.dart';
import 'package:webview_flutter/webview_flutter.dart';
import 'package:webview_flutter_android/webview_flutter_android.dart';
import 'package:webview_flutter_wkwebview/webview_flutter_wkwebview.dart';

class FacialCheckView extends StatefulWidget {
  const FacialCheckView({super.key});

  @override
  State<FacialCheckView> createState() => _FacialCheckViewState();
}

class _FacialCheckViewState extends State<FacialCheckView> {
  late final WebViewController _controller;
  bool _isLoading = true;

  static const String facialCheckUrl =
      'https://level2-mediapipe-website.onrender.com';

  @override
  void initState() {
    super.initState();

    /// ✅ PLATFORM-SAFE CREATION PARAMS
    final PlatformWebViewControllerCreationParams params =
        PlatformWebViewControllerCreationParams();

    /// ✅ iOS: ENABLE INLINE VIDEO (PREVENT FULLSCREEN HIJACK)
    final PlatformWebViewControllerCreationParams effectiveParams =
        (!kIsWeb && Platform.isIOS)
        ? WebKitWebViewControllerCreationParams(
            allowsInlineMediaPlayback: true,
            mediaTypesRequiringUserAction: const <PlaybackMediaTypes>{},
          )
        : params;

    _controller = WebViewController.fromPlatformCreationParams(effectiveParams)
      ..setJavaScriptMode(JavaScriptMode.unrestricted)
      ..setBackgroundColor(Colors.white)
      ..setNavigationDelegate(
        NavigationDelegate(
          onPageStarted: (_) {
            setState(() => _isLoading = true);
          },
          onPageFinished: (_) {
            setState(() => _isLoading = false);
          },
          onWebResourceError: (error) {
            debugPrint('WebView error: $error');
          },
        ),
      )
      ..addJavaScriptChannel(
        'assessmentResult',
        onMessageReceived: (message) async {
          debugPrint('🧠 Facial result received: ${message.message}');

          final decoded = jsonDecode(message.message);
          final result = FacialResult.fromJson(decoded);

          final box = Hive.box('facial_results');
          await box.add(result.toJson());

          debugPrint('✅ Result saved to Hive');
        },
      )
      ..loadRequest(Uri.parse(facialCheckUrl));

    /// ✅ ANDROID: allow camera autoplay
    if (!kIsWeb && Platform.isAndroid) {
      final androidController =
          _controller.platform as AndroidWebViewController;
      androidController.setMediaPlaybackRequiresUserGesture(false);
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.white,
      appBar: AppBar(
        title: const Text('Facial Assessment'),
        centerTitle: true,
        elevation: 0,
        backgroundColor: Colors.white,
        foregroundColor: Colors.black,
      ),
      body: Stack(
        children: [
          WebViewWidget(controller: _controller),

          if (_isLoading)
            Container(
              color: Colors.white,
              child: const Center(
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    CircularProgressIndicator(),
                    SizedBox(height: 16),
                    Text(
                      'Initializing camera & facial analysis…',
                      style: TextStyle(fontSize: 14),
                    ),
                  ],
                ),
              ),
            ),
        ],
      ),
    );
  }
}
