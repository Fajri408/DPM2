import 'dart:async';
import 'dart:isolate';
import 'dart:ui';
import 'dart:core';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_notification_listener/flutter_notification_listener.dart';
import 'package:receive_intent/receive_intent.dart';
import 'package:seclick/model/predict_response.dart';
import 'package:seclick/pages/history_page.dart';
import 'package:seclick/services/api_service.dart';
import 'package:seclick/services/local_notification_service.dart';

class HomePage extends StatefulWidget {
  const HomePage({super.key});

  @override
  State<HomePage> createState() => _HomePageState();
}

class _HomePageState extends State<HomePage> {
  final TextEditingController _urlController = TextEditingController();
  String _result = "";
  bool _isLoading = false;
  Timer? clipBoardTimer;
  ReceivePort port = ReceivePort();

  @override
  void initState() {
    initPlatformState();
    super.initState();
    listenForSharedLink();
    startClipboardWatcher();
  }

  @override
  void dispose() {
    clipBoardTimer?.cancel();
    super.dispose();
  }

  void listenForSharedLink() async {
    final intent = await ReceiveIntent.getInitialIntent();
    final sharedText = intent?.extra?['android.intent.extra.TEXT'];

    if (sharedText != null && isValidUrl(sharedText)) {
      _urlController.text = sharedText;
      _checkURL();
    }
  }

  void startClipboardWatcher() {
    clipBoardTimer = Timer.periodic(const Duration(seconds: 3), (timer) async {
      final clipboard = await Clipboard.getData('text/plain');
      final text = clipboard?.text;

      debugPrint("Checking clipboard");
      if (text != null && isValidUrl(text)) {
        debugPrint("Setting url from clipboard");
        _urlController.text = text;
        _checkURL();

        // Remove tautan from clipboard
        await Clipboard.setData(const ClipboardData(text: ""));
      }
    });
  }

  // we must use static method, to handle in background
  @pragma('vm:entry-point') // prevent dart from stripping out this function on release build in Flutter 3.x
  static void _callback(NotificationEvent evt) {
    debugPrint("send evt to ui: $evt");
    final SendPort? send = IsolateNameServer.lookupPortByName("_listener_");
    if (send == null) debugPrint("can't find the sender");
    send?.send(evt);
  }

  Future<void> initPlatformState() async {
    NotificationsListener.initialize(callbackHandle: _callback);

    // this can fix restart<debug> can't handle error
    IsolateNameServer.removePortNameMapping("_listener_");
    IsolateNameServer.registerPortWithName(port.sendPort, "_listener_");
    port.listen((message) => onData(message));

    var hasPermisson = (await NotificationsListener.hasPermission) ?? false;
    if (!hasPermisson) {
      debugPrint("No permission, so open settings");
      NotificationsListener.openPermissionSettings();
      return;
    }

    await NotificationsListener.startService(
      foreground: true,
      title: "SeClick Guard",
      description: "Analisis tautan...",
    );
  }

  void onData(NotificationEvent event) {
    // Parsing to form
    String? url = extractUrl(event.text ?? '');
    if (url != null) {
      _urlController.text = url;
      debugPrint("Detection Start...");
      if (event.packageName != "com.guard.seclick") {
        handleNotificationData(url);
      }
    }
    debugPrint(event.toString());
  }

  String? extractUrl(String text) {
    final urlRegex = RegExp(r'((https?:\/\/)?(www\.)?[a-zA-Z0-9\-]+\.[a-zA-Z]{2,}([\/\w\-\.\?\=\#\&]*)*)',
      caseSensitive: false);
    final match = urlRegex.firstMatch(text);
    return match?.group(0);
  }

  //List<String> extractUrl(String text) {
  //  final urlRegex = RegExp(r'((https?:\/\/)?(www\.)?[a-zA-Z0-9\-]+\.[a-zA-Z]{2,}([\/\w\-\.\?\=\#\&]*)*)',
  //    caseSensitive: false);
  //  return urlRegex.allMatches(text).map((match) => match.group(0)!).toList();
  //}

  bool isValidUrl(String text) {
    final urlRegex = RegExp(r'^https?:\/\/[\w\d\.-]+\.[a-z]{2,}.*$', caseSensitive: false);
    return urlRegex.hasMatch(text);
  }

  Future<void> _checkURL() async {
    String url = _urlController.text.trim();
    if (url.isEmpty) {
      setState(() {
        _result = "Harap masukkan URL terlebih dahulu!";
      });
      return;
    }

    setState(() {
      _isLoading = true;
      _result = "";
    });

    try {
      PredictResponse response = await ApiService.checkUrl(url);
      setState(() {
        _result = "Hasil Analisis:\n Aman: ${response.safePercentage}% \n Berbahaya: ${response.phishingPercentage}%";
        _isLoading = false;
      });
    } catch (e) {
      setState(() {
        _result = "Terjadi kesalahan: $e";
      });
    } finally {
      setState(() {
        _isLoading = false;
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text("Phishing Detector"),
        centerTitle: true,
        backgroundColor: const Color(0xFF027373),
        foregroundColor: Colors.white,
        titleTextStyle: const TextStyle(
          fontFamily: 'Lato',
          fontSize: 20,
          fontWeight: FontWeight.bold,
          color: Colors.white,
        ),
      ),
      bottomNavigationBar: ElevatedButton(
        onPressed: () {
          Navigator.push(
          context,
          MaterialPageRoute(builder: (_) => const HistoryPage()));
        },
        style: ElevatedButton.styleFrom(
            backgroundColor: const Color(0xFF027373),
            padding: const EdgeInsets.symmetric(horizontal: 40, vertical: 14),
            shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(12),
          ),
        ),
        child: const Text(
          "Riwayat",
          style: TextStyle(
            fontFamily: 'Lato',
            fontSize: 18,
            fontWeight: FontWeight.w600,
            color: Colors.white,
          ),
        ),
      ),
      body: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 20),
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          crossAxisAlignment: CrossAxisAlignment.center,
          children: [
            const Icon(Icons.security, size: 100, color: Colors.blue),
            const SizedBox(height: 20),
            const Text(
              "Masukkan URL untuk mendeteksi ancaman phishing.",
              textAlign: TextAlign.center,
              style: TextStyle(
                  fontSize: 16, color: Colors.grey, fontFamily: 'Lato'),
            ),
            const SizedBox(height: 20),

            // **TextField untuk Input URL**
            TextField(
              controller: _urlController,
              decoration: InputDecoration(
                labelText: "Masukkan URL",
                labelStyle: const TextStyle(fontFamily: 'Lato'),
                hintText: "https://example.com",
                border: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(12),
                ),
                prefixIcon: const Icon(Icons.link),
              ),
              keyboardType: TextInputType.url,
            ),

            const SizedBox(height: 20),

            // **Tombol untuk Mengirim URL**
            ElevatedButton(
              onPressed: _isLoading ? null : _checkURL,
              style: ElevatedButton.styleFrom(
                backgroundColor: const Color(0xFF027373),
                padding: const EdgeInsets.symmetric(horizontal: 40, vertical: 14),
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(12),
                ),
              ),
              child: _isLoading
                  ? const CircularProgressIndicator(color: Colors.white)
                  : const Text(
                      "Cek URL",
                      style: TextStyle(
                        fontFamily: 'Lato',
                        fontSize: 18,
                        fontWeight: FontWeight.w600,
                        color: Colors.white,
                      ),
                    ),
            ),

            const SizedBox(height: 20),

            // **Menampilkan hasil analisis**
            Text(
              _result,
              textAlign: TextAlign.center,
              style: const TextStyle(
                fontSize: 16,
                fontWeight: FontWeight.bold,
                fontFamily: 'Lato',
                color: Colors.black,
              ),
            ),
          ],
        ),
      ),
    );
  }
}
