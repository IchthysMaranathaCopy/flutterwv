import 'dart:async';
import 'dart:io';
import 'package:flutter/material.dart';
import 'package:webview_flutter/webview_flutter.dart';
import 'package:firebase_core/firebase_core.dart';
import 'package:firebase_messaging/firebase_messaging.dart';
import 'package:http/http.dart' as http;
import 'package:path_provider/path_provider.dart';
import 'package:permission_handler/permission_handler.dart';
import 'package:url_launcher/url_launcher.dart';

Future<void> _firebaseMessagingBackgroundHandler(RemoteMessage message) async {
  await Firebase.initializeApp();
  print('Handling a background message ${message.messageId}');
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
      title: 'WebView App',
      theme: ThemeData(
        primarySwatch: Colors.blue,
      ),
      home: const MyHomePage(),
    );
  }
}

class MyHomePage extends StatefulWidget {
  const MyHomePage({super.key});

  @override
  State<MyHomePage> createState() => _MyHomePageState();
}

class _MyHomePageState extends State<MyHomePage> {
  late WebViewController _controller;
  final Completer<WebViewController> _controllerCompleter =
      Completer<WebViewController>();
  String initialUrl = 'https://sanju.maplein.com'; // Replace with your URL
  String fcmTokenUrl = 'https://sanju.maplein.com/api/webhooks/trigger/app_d1e8203afd9c431890d2ed6e03847a3c/wh_604c016ca4d44fdf98c5d42d518f1a27'; // Replace with your FCM token upload URL

  @override
  void initState() {
    super.initState();
    _setupFirebase();
    if (Platform.isAndroid) WebView.platform = AndroidWebView();
  }

  Future<void> _setupFirebase() async {
    FirebaseMessaging messaging = FirebaseMessaging.instance;

    NotificationSettings settings = await messaging.requestPermission(
      alert: true,
      announcement: false,
      badge: true,
      carPlay: false,
      criticalAlert: false,
      provisional: false,
      sound: true,
    );

    if (settings.authorizationStatus == AuthorizationStatus.authorized) {
      print('User granted permission!');
    } else if (settings.authorizationStatus ==
        AuthorizationStatus.provisional) {
      print('User granted provisional permission');
    } else {
      print('User declined or has not accepted permission');
    }

    FirebaseMessaging.instance.getToken().then((token) {
      _sendFcmToken(token);
    });

    FirebaseMessaging.instance.onTokenRefresh.listen((token) {
      _sendFcmToken(token);
    });

    FirebaseMessaging.onMessage.listen((RemoteMessage message) {
      print('Got a message whilst in the foreground!');
      print('Message data: ${message.data}');

      if (message.notification != null) {
        print('Message also contained a notification: ${message.notification}');
      }
    });
  }

  Future<void> _sendFcmToken(String? token) async {
    if (token == null) return;
    try {
      final response = await http.post(
        Uri.parse(fcmTokenUrl),
        body: {'token': token},
      );
      if (response.statusCode == 200) {
        print('FCM token sent successfully');
      } else {
        print('Failed to send FCM token: ${response.statusCode}');
      }
    } catch (e) {
      print('Error sending FCM token: $e');
    }
  }

  @override
  Widget build(BuildContext context) {
    return WillPopScope(
      onWillPop: () async {
        if (await _controller.canGoBack()) {
          _controller.goBack();
          return false;
        }
        return true;
      },
      child: Scaffold(
        body: SafeArea(
          child: WebView(
            initialUrl: initialUrl,
            javascriptMode: JavascriptMode.unrestricted,
            onWebViewCreated: (WebViewController webViewController) {
              _controllerCompleter.complete(webViewController);
              _controller = webViewController;
            },
            navigationDelegate: (NavigationRequest request) async {

              if (request.url.startsWith('http') || request.url.startsWith('https')) {
                return NavigationDecision.navigate;
              }else if(request.url.startsWith('mailto:') || request.url.startsWith('tel:')){
                if (await canLaunchUrl(Uri.parse(request.url))) {
                  await launchUrl(Uri.parse(request.url));
                  return NavigationDecision.prevent;
                } else {
                  return NavigationDecision.prevent;
                }
              }

              return NavigationDecision.navigate;
            },

            javascriptChannels: <JavascriptChannel>{
              JavascriptChannel(
                name: 'DownloadChannel',
                onMessageReceived: (JavascriptMessage message) async {
                  final url = message.message;
                  await _downloadFile(url);
                },
              ),
            },
            onPageFinished: (String url) {
              // You can add logic here if needed
            },
            onWebResourceError: (WebResourceError error) {
              print("Web resource error: ${error.description}");
            },
            gestureNavigationEnabled: true,
            allowsInlineMediaPlayback: true,
          ),
        ),
      ),
    );
  }

  Future<void> _downloadFile(String url) async {
    if (Platform.isAndroid) {
      final status = await Permission.storage.request();
      if (status.isGranted) {
        final httpClient = http.Client();
        final request = await httpClient.get(Uri.parse(url));
        final bytes = request.bodyBytes;

        final filename = url.split('/').last;
        final directory = await getExternalStorageDirectory();
        final file = File('${directory?.path}/$filename');
        await file.writeAsBytes(bytes);

        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Downloaded $filename to ${directory?.path}')),
        );
      } else {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Storage permission denied')),
        );
      }
    } else {
      // Implement for iOS if needed
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Download not supported on iOS')),
      );
    }
  }
}
