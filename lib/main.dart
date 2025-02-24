import 'dart:convert';
import 'dart:io';

import 'package:flutter/material.dart';
import 'package:flutter_local_notifications/flutter_local_notifications.dart';
import 'package:flutter_webview_plugin/flutter_webview_plugin.dart';
import 'package:firebase_messaging/firebase_messaging.dart';
import 'package:http/http.dart' as http;
import 'package:path_provider/path_provider.dart';
import 'package:permission_handler/permission_handler.dart';
import 'package:flutter_downloader/flutter_downloader.dart';

void main() {
  WidgetsFlutterBinding.ensureInitialized();
  runApp(MyApp());
}

class MyApp extends StatefulWidget {
  @override
  _MyAppState createState() => _MyAppState();
}

class _MyAppState extends State<MyApp> {
  final FirebaseMessaging _firebaseMessaging = FirebaseMessaging.instance;
  final FlutterLocalNotificationsPlugin _flutterLocalNotificationsPlugin = FlutterLocalNotificationsPlugin();
  final FlutterWebviewPlugin _webviewPlugin = FlutterWebviewPlugin();

  @override
  void initState() {
    super.initState();
    _requestPermissions();
    _configureFirebase();
  }

  void _requestPermissions() async {
    await Permission.notification.request();
    await Permission.storage.request();
  }

  void _configureFirebase() async {
    NotificationSettings settings = await _firebaseMessaging.requestPermission();
    if (settings.authorizationStatus == AuthorizationStatus.authorized) {
      String? token = await _firebaseMessaging.getToken();
      if (token != null) {
        _sendTokenToServer(token);
      }
    }
  }

  Future<void> _sendTokenToServer(String token) async {
    final url = Uri.parse('https://sanju.maplein.com/api/webhooks/trigger/app_d1e8203afd9c431890d2ed6e03847a3c/wh_604c016ca4d44fdf98c5d42d518f1a27');
    await http.post(url, body: {'token': token});
  }

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      debugShowCheckedModeBanner: false,
      theme: ThemeData(primarySwatch: Colors.blue),
      home: WebviewScaffold(
        url: "https://sanju.maplein.com",
        withJavascript: true,
        withZoom: true,
        allowFileURLs: true,
        appCacheEnabled: true,
        withLocalStorage: true,
      ),
    );
  }
}
