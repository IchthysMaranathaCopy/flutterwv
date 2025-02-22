import 'dart:async';
import 'dart:io';
import 'package:flutter/material.dart';
import 'package:webview_flutter/webview_flutter.dart';
import 'package:firebase_core/firebase_core.dart';
import 'package:firebase_messaging/firebase_messaging.dart';
import 'package:http/http.dart' as http;
import 'package:path_provider/path_provider.dart';
import 'package:permission_handler/permission_handler.dart';
import 'package:open_filex/open_filex.dart';

// Replace with your server endpoint
const String TOKEN_ENDPOINT = 'https://your-server.com/store-token';
const String INITIAL_URL = 'https://your-website.com';

Future<void> _firebaseMessagingBackgroundHandler(RemoteMessage message) async {
  await Firebase.initializeApp();
  print("Background message: ${message.messageId}");
}

void main() async {
  WidgetsFlutterBinding.ensureInitialized();
  await Firebase.initializeApp();
  FirebaseMessaging.onBackgroundMessage(_firebaseMessagingBackgroundHandler);
  runApp(const MyApp());
}

class MyApp extends StatelessWidget {
  const MyApp({super.key});

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      title: 'Lawffice',
      theme: ThemeData(primarySwatch: Colors.blue),
      home: const WebViewScreen(),
    );
  }
}

class WebViewScreen extends StatefulWidget {
  const WebViewScreen({super.key});

  @override
  State<WebViewScreen> createState() => _WebViewScreenState();
}

class _WebViewScreenState extends State<WebViewScreen> {
  late final WebViewController _controller;
  final FirebaseMessaging _fcm = FirebaseMessaging.instance;
  bool _isLoading = true;

  @override
  void initState() {
    super.initState();
    _initWebView();
    _setupFirebase();
    _requestPermissions();
  }

  void _initWebView() {
    _controller = WebViewController()
      ..setJavaScriptMode(JavaScriptMode.unrestricted)
      ..setNavigationDelegate(NavigationDelegate(
        onProgress: (int progress) => setState(() => _isLoading = progress < 100),
        onPageStarted: (String url) => setState(() => _isLoading = true),
        onPageFinished: (String url) => setState(() => _isLoading = false),
        onWebResourceError: (WebResourceError error) => _showError(error.description),
        onNavigationRequest: (NavigationRequest request) {
          if (request.url.contains('download')) {
            _handleDownload(request.url);
            return NavigationDecision.prevent;
          }
          return NavigationDecision.navigate;
        },
      ))
      ..loadRequest(Uri.parse('https://sanju.maplein.com'))
      ..enableZoom(true)
      ..setBackgroundColor(Colors.white);
  }

  void _setupFirebase() async {
    await _fcm.setAutoInitEnabled(true);
    NotificationSettings settings = await _fcm.requestPermission();
    if (settings.authorizationStatus == AuthorizationStatus.authorized) {
      String? token = await _fcm.getToken();
      if (token != null) _sendTokenToServer(token);
    }

    FirebaseMessaging.onMessage.listen((RemoteMessage message) {
      if (message.notification != null) {
        _showNotification(message.notification!);
      }
    });
  }

  Future<void> _sendTokenToServer(String token) async {
    try {
      final response = await http.post(
        Uri.parse('https://sanju.maplein.com/api/webhooks/trigger/app_d1e8203afd9c431890d2ed6e03847a3c/wh_604c016ca4d44fdf98c5d42d518f1a27'),
        body: {'token': token},
      );
      print('Token sent successfully: ${response.statusCode}');
    } catch (e) {
      print('Error sending token: $e');
      // Implement retry logic here if needed
    }
  }

  Future<void> _handleDownload(String url) async {
    try {
      final status = await Permission.storage.request();
      if (status.isGranted) {
        final filename = url.split('/').last;
        final response = await http.get(Uri.parse(url));
        final directory = await getDownloadsDirectory();
        final file = File('${directory?.path}/$filename');
        
        await file.writeAsBytes(response.bodyBytes);
        OpenFilex.open(file.path);
      }
    } catch (e) {
      _showError('Download failed: $e');
    }
  }

  Future<void> _requestPermissions() async {
    await [
      Permission.storage,
      Permission.camera,
      Permission.microphone,
    ].request();
  }

  void _showNotification(RemoteNotification notification) {
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: Text(notification.title ?? 'Notification'),
        content: Text(notification.body ?? ''),
        actions: [TextButton(onPressed: () => Navigator.pop(context), child: const Text('OK'))],
      ),
    );
  }

  void _showError(String message) {
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(content: Text(message), backgroundColor: Colors.red),
    );
  }

  @override
  Widget build(BuildContext context) {
    return PopScope(
      canPop: false,
      onPopInvoked: (bool didPop) async {
        if (didPop) return;
        
        final canGoBack = await _controller.canGoBack();
        if (canGoBack) {
          _controller.goBack();
        } else {
          if (mounted) Navigator.of(context).pop();
        }
      },
      child: Scaffold(
        appBar: null,
        body: WebViewWidget(controller: _controller),
      ),
    );
  }
}
