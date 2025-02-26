import 'package:flutter/material.dart';
import 'package:webview_flutter/webview_flutter.dart';
import 'package:firebase_core/firebase_core.dart';
import 'package:firebase_messaging/firebase_messaging.dart';
import 'package:http/http.dart' as http;
import 'package:path_provider/path_provider.dart';
import 'package:permission_handler/permission_handler.dart';
import 'package:open_filex/open_filex.dart';


void main() async {
  WidgetsFlutterBinding.ensureInitialized();
  await Firebase.initializeApp();
  runApp(const MyApp());
}

class MyApp extends StatelessWidget {
  const MyApp({super.key});

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      title: 'WebView App',
      theme: ThemeData(
        primarySwatch: Colors.blue,
      ),
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
  final FirebaseMessaging _firebaseMessaging = FirebaseMessaging.instance;

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
      ..setUserAgent("random")
      ..loadRequest(Uri.parse('https://sanju.maplein.com')) // Replace with your URL
      ..setNavigationDelegate(
        NavigationDelegate(
          onProgress: (int progress) {},
          onPageStarted: (String url) {},
          onPageFinished: (String url) {},
          onWebResourceError: (WebResourceError error) {},
          onNavigationRequest: (NavigationRequest request) {
          if (request.url.contains('download')) {
            _handleDownload(request.url);
            return NavigationDecision.prevent;
          }
          return NavigationDecision.navigate;
        },
        ),
      );
  }

  void _setupFirebase() async {
    await _firebaseMessaging.subscribeToTopic('allusers');
    await _firebaseMessaging.setAutoInitEnabled(true);
    NotificationSettings settings = await _firebaseMessaging.requestPermission(
      alert: true,
      announcement: false,
      badge: true,
      carPlay: false,
      criticalAlert: false,
      provisional: false,
      sound: true,
    );
        if (settings.authorizationStatus == AuthorizationStatus.authorized) {
          
      String? token = await _firebaseMessaging.getToken();
      if (token != null) _sendTokenToServer(token);
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

    print('Permission granted: ${settings.authorizationStatus}');

    FirebaseMessaging.onMessage.listen((RemoteMessage message) {
      print('Got a message whilst in the foreground!');
      if (message.notification != null) {
        showDialog(
          context: context,
          builder: (context) => AlertDialog(
            title: Text(message.notification?.title ?? ''),
            content: Text(message.notification?.body ?? ''),
            actions: [
              TextButton(
                onPressed: () => Navigator.of(context).pop(),
                child: const Text('OK'),
              )
            ],
          ),
        );
      }
    });

    FirebaseMessaging.onMessageOpenedApp.listen((RemoteMessage message) {
      print('Message opened from terminated state:');
      print(message.data);
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

  @override
  Widget build(BuildContext context) {
return SafeArea(
     child: PopScope(
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
       ),
    );
  }
}
