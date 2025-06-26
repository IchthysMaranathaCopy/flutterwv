import 'package:flutter/material.dart';
import 'package:webview_flutter/webview_flutter.dart';
import 'package:firebase_core/firebase_core.dart';
import 'package:firebase_messaging/firebase_messaging.dart';
import 'package:http/http.dart' as http;
import 'package:path_provider/path_provider.dart';
import 'package:permission_handler/permission_handler.dart';
import 'package:open_filex/open_filex.dart';
import 'dart:async';
import 'dart:io';
import 'dart:convert';
import 'package:webview_flutter_android/webview_flutter_android.dart';
import 'package:file_picker/file_picker.dart';


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
  String? _downloadFilename;
  String? _pendingDownloadUrl;

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
      ..addJavaScriptChannel('DownloadInterceptor', 
      onMessageReceived: (message) {
        final data = jsonDecode(message.message);
        _handleFileDownload(data['url'], filename: data['filename']);
      })
      ..setUserAgent("random")
      ..loadRequest(Uri.parse('https://lawffice.maplein.com')) // Replace with your URL
      ..setNavigationDelegate(
        NavigationDelegate(
          onProgress: (int progress) {},
          onPageStarted: (String url) {},
          onPageFinished: (String url) {
            _injectDownloadInterceptor();
          },
          onWebResourceError: (WebResourceError error) {},
          onNavigationRequest: (NavigationRequest request) {
          if (_pendingDownloadUrl == request.url) {
          _pendingDownloadUrl = null;
          return NavigationDecision.prevent;
        }
          return NavigationDecision.navigate;
        },
        ),
      );
    addFileSelectionListener();
  }
    void addFileSelectionListener() async {
    if (Platform.isAndroid) {
      final androidController = _controller.platform as AndroidWebViewController;
      await androidController.setOnShowFileSelector(_androidFilePicker);
    }
  }

  void _refresh() {
    _controller.reload(); // Reload the WebView
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
void _injectDownloadInterceptor() {
  _controller.runJavaScript('''
    (function() {
      const interceptSelector = 'a[download]';
      
      function handleDownloadClick(e) {
        const link = e.target.closest(interceptSelector);
        if (!link) return;
        if (!link.getAttribute('download')) return;
        
        e.preventDefault();
        e.stopImmediatePropagation();
        
        DownloadInterceptor.postMessage(JSON.stringify({
          url: link.href,
          filename: link.getAttribute('download')
        }));
        return false;
      }

      document.body.addEventListener('click', handleDownloadClick, true);
      window.addEventListener('beforeunload', () => {
        document.body.removeEventListener('click', handleDownloadClick, true);
      });
    })();
  ''');
}

  Future<void> _handleFileDownload(String url, {String? filename}) async {
  try {
    if (_pendingDownloadUrl == url) return;
    _pendingDownloadUrl = url;
    
    filename ??= 'file';
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(content: Text('Downloading $filename...')),
    );

    final response = await http.get(Uri.parse(url));
    final directory = Directory('/storage/emulated/0/Download');
    final file = File('${directory?.path}/$filename');
    
    await file.writeAsBytes(response.bodyBytes);
    _pendingDownloadUrl = null;
    
    OpenFilex.open(file.path);
  } catch (e) {
    _pendingDownloadUrl = null;
    _showError('Download failed: $e');
  }
}
    Future<List<String>> _androidFilePicker(FileSelectorParams params) async {
    final result = await FilePicker.platform.pickFiles();

    if (result != null && result.files.single.path != null) {
      final file = File(result.files.single.path!);
      return [file.uri.toString()];
    }
    return [];
  }


  Future<void> _requestPermissions() async {
    await [
      Permission.storage,
      Permission.camera,
      Permission.microphone,
    ].request();
  }
  void _showError(String message) {
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(content: Text(message), backgroundColor: Colors.red),
    );
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
      body: Stack(
        children: [WebViewWidget(controller: _controller),
          Positioned(
            top: 20, // Position below AppBar
            left: 0,
            right: 0,
            child: Center(
              child: FloatingActionButton(
                mini: true, // Smaller size
                backgroundColor: Colors.white,
                onPressed: _refresh,
                child: const Icon(Icons.refresh, color: Colors.blue),
              ),
            ),
          ),
        ],
      ),
        ),
       ),
    );
  }
}
