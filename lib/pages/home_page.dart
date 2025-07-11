import 'dart:async';
import 'dart:isolate';
import 'dart:ui';
import 'dart:core';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_notification_listener/flutter_notification_listener.dart';
import 'package:receive_intent/receive_intent.dart';
import 'package:seclick/model/predict_response.dart';
import 'package:seclick/model/log_entry.dart';
import 'package:seclick/pages/history_page.dart';
import 'package:seclick/services/api_service.dart';
import 'package:seclick/services/local_notification_service.dart';
import 'package:seclick/services/local_storage_service.dart';
import 'package:url_launcher/url_launcher.dart';


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
  ReceivePort? port;
  bool _isInitialized = false;
  String _lastAnalyzedUrl = ""; // Store the last analyzed URL
  bool _isOpeningUrl = false; // Track URL opening state
  String _analysisTimestamp = ""; // Store analysis timestamp
  double _phishingPercentage = 0.0; // Store phishing percentage
  double _safePercentage = 0.0; // Store safe percentage

  @override
  void initState() {
    super.initState();
    _initializeServices();
  }

  Future<void> _initializeServices() async {
    try {
      await initPlatformState();
      listenForSharedLink();
      startClipboardWatcher();
      setState(() {
        _isInitialized = true;
      });
    } catch (e) {
      debugPrint("Error initializing services: $e");
      // Show error to user
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text("Error initializing services: $e"),
            backgroundColor: Colors.red,
          ),
        );
      }
    }
  }

  @override
  void dispose() {
    clipBoardTimer?.cancel();
    port?.close();
    super.dispose();
  }

  void listenForSharedLink() async {
    try {
      final intent = await ReceiveIntent.getInitialIntent();
      final sharedText = intent?.extra?['android.intent.extra.TEXT'];

      if (sharedText != null && isValidUrl(sharedText)) {
        _urlController.text = sharedText;
        _checkURL();
      }
    } catch (e) {
      debugPrint("Error getting shared link: $e");
    }
  }

  void startClipboardWatcher() {
    clipBoardTimer = Timer.periodic(const Duration(seconds: 3), (timer) async {
      try {
        final clipboard = await Clipboard.getData('text/plain');
        final text = clipboard?.text;

        if (text != null && isValidUrl(text)) {
          _urlController.text = text;
          _checkURL();

          // Clear clipboard
          await Clipboard.setData(const ClipboardData(text: ""));
        }
      } catch (e) {
        debugPrint("Error checking clipboard: $e");
      }
    });
  }

  @pragma('vm:entry-point')
  static void _callback(NotificationEvent evt) {
    try {
      debugPrint("send evt to ui: $evt");
      final SendPort? send = IsolateNameServer.lookupPortByName("_listener_");
      if (send == null) {
        debugPrint("can't find the sender");
        return;
      }
      send.send(evt);
    } catch (e) {
      debugPrint("Error in notification callback: $e");
    }
  }

  Future<void> initPlatformState() async {
    try {
      NotificationsListener.initialize(callbackHandle: _callback);

      // Remove existing port mapping
      IsolateNameServer.removePortNameMapping("_listener_");
      
      // Create new port
      port = ReceivePort();
      IsolateNameServer.registerPortWithName(port!.sendPort, "_listener_");
      port!.listen((message) => onData(message));

      var hasPermission = (await NotificationsListener.hasPermission) ?? false;
      if (!hasPermission) {
        debugPrint("No permission, opening settings");
        NotificationsListener.openPermissionSettings();
        return;
      }

      await NotificationsListener.startService(
        foreground: true,
        title: "SeClick Guard",
        description: "Analyzing links...",
      );
    } catch (e) {
      debugPrint("Error initializing platform state: $e");
      rethrow;
    }
  }

  void onData(NotificationEvent event) {
    try {
      String? url = extractUrl(event.text ?? '');
      if (url != null) {
        _urlController.text = url;
        debugPrint("Detection Start...");
        if (event.packageName != "com.guard.seclick") {
          LocalNotificationService().handleNotificationData(url);
        }
      }
      debugPrint(event.toString());
    } catch (e) {
      debugPrint("Error processing notification data: $e");
    }
  }

  String? extractUrl(String text) {
    try {
      final urlRegex = RegExp(
        r'((https?:\/\/)?(www\.)?[a-zA-Z0-9\-]+\.[a-zA-Z]{2,}([\/\w\-\.\?\=\#\&]*)*)',
        caseSensitive: false,
      );
      final match = urlRegex.firstMatch(text);
      return match?.group(0);
    } catch (e) {
      debugPrint("Error extracting URL: $e");
      return null;
    }
  }

  bool isValidUrl(String text) {
    try {
      final urlRegex = RegExp(
        r'^https?:\/\/[\w\d\.-]+\.[a-z]{2,}.*$',
        caseSensitive: false,
      );
      return urlRegex.hasMatch(text);
    } catch (e) {
      debugPrint("Error validating URL: $e");
      return false;
    }
  }

  Future<void> _checkURL() async {
    String url = _urlController.text.trim();
    if (url.isEmpty) {
      setState(() {
        _result = "Please enter a URL first!";
      });
      return;
    }

    // Normalisasi URL di field input
    if (!url.startsWith('http://') && !url.startsWith('https://')) {
      url = 'https://' + url;
      _urlController.text = url;
    }

    setState(() {
      _isLoading = true;
      _result = "";
    });

    try {
      // Nembak API lagi untuk analisis URL
      final predictionResponse = await ApiService.checkUrl(url);

      setState(() {
        _result = "Analysis Result:\n Probability Non-Phising: " +
            (predictionResponse.safePercentage?.toStringAsFixed(1) ?? '0.0') + "% \n Probability Phising: " +
            (predictionResponse.phishingPercentage?.toStringAsFixed(1) ?? '0.0') + "%";
        _lastAnalyzedUrl = url;
        _phishingPercentage = predictionResponse.phishingPercentage ?? 0.0;
        _safePercentage = predictionResponse.safePercentage ?? 0.0;
      });

      // Save prediction to local storage
      final entry = LogEntry(
        timestamp: _analysisTimestamp,
        url: url,
        details: "URL analyzed for phishing",
        phishingPercentage: predictionResponse.phishingPercentage ?? 0.0,
        safePercentage: predictionResponse.safePercentage ?? 0.0,
      );
      await LocalStorageService().savePrediction(entry);
    } catch (e) {
      setState(() {
        _result = "Error occurred: $e";
      });
    } finally {
      setState(() {
        _isLoading = false;
      });
    }
  }

  Future<void> _openUrlInBrowser(String url) async {
    setState(() {
      _isOpeningUrl = true;
    });
    
    try {
      // Check if this URL was recently analyzed and found to be phishing
      if (_lastAnalyzedUrl == url && _phishingPercentage > _safePercentage) {
        // Show warning dialog for phishing URLs
        bool? shouldProceed = await showDialog<bool>(
          context: context,
          builder: (BuildContext context) {
            return AlertDialog(
              title: const Row(
                children: [
                  Icon(Icons.warning, color: Colors.red),
                  SizedBox(width: 8),
                  Text('Warning!', style: TextStyle(color: Colors.red)),
                ],
              ),
              content: const Text(
                'This URL was detected as potentially phishing. Are you sure you want to open it?',
                style: TextStyle(fontFamily: 'Lato'),
              ),
              actions: [
                TextButton(
                  onPressed: () => Navigator.of(context).pop(false),
                  child: const Text(
                    'Cancel',
                    style: TextStyle(color: Colors.grey),
                  ),
                ),
                TextButton(
                  onPressed: () => Navigator.of(context).pop(true),
                  child: const Text(
                    'Open Anyway',
                    style: TextStyle(color: Colors.red),
                  ),
                ),
              ],
            );
          },
        );
        
        if (shouldProceed != true) {
          setState(() {
            _isOpeningUrl = false;
          });
          return; // User cancelled
        }
      }
      
      // Ensure URL has protocol
      String urlToOpen = url;
      if (!url.startsWith('http://') && !url.startsWith('https://')) {
        urlToOpen = 'https://$url';
      }
      
      final Uri uri = Uri.parse(urlToOpen);
      if (await canLaunchUrl(uri)) {
        await launchUrl(uri, mode: LaunchMode.externalApplication);
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(
              content: Text('Opening $urlToOpen in browser...'),
              backgroundColor: Colors.blue,
              duration: const Duration(seconds: 2),
            ),
          );
        }
      } else {
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(
              content: Text('Could not open $urlToOpen'),
              backgroundColor: Colors.red,
            ),
          );
        }
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Error opening URL: $e'),
            backgroundColor: Colors.red,
          ),
        );
      }
    } finally {
      setState(() {
        _isOpeningUrl = false;
      });
    }
  }

  Future<void> _copyUrlToClipboard(String url) async {
    try {
      await Clipboard.setData(ClipboardData(text: url));
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('URL copied to clipboard'),
            backgroundColor: Colors.green,
            duration: Duration(seconds: 2),
          ),
        );
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Error copying URL: $e'),
            backgroundColor: Colors.red,
          ),
        );
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      resizeToAvoidBottomInset: true, // Allow content to resize when keyboard appears
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
            MaterialPageRoute(builder: (_) => const HistoryPage()),
          );
        },
        style: ElevatedButton.styleFrom(
          backgroundColor: const Color(0xFF027373),
          padding: const EdgeInsets.symmetric(horizontal: 40, vertical: 14),
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(12),
          ),
        ),
        child: const Text(
          "History",
          style: TextStyle(
            fontFamily: 'Lato',
            fontSize: 18,
            fontWeight: FontWeight.w600,
            color: Colors.white,
          ),
        ),
      ),
      body: !_isInitialized
          ? const Center(child: CircularProgressIndicator())
          : GestureDetector(
              onTap: () {
                // Dismiss keyboard when tapping outside
                FocusScope.of(context).unfocus();
              },
              child: SingleChildScrollView(
                padding: EdgeInsets.only(
                  left: 20,
                  right: 20,
                  top: 20,
                  bottom: MediaQuery.of(context).viewInsets.bottom + 20, // Add extra padding when keyboard is shown
                ),
                child: ConstrainedBox(
                  constraints: BoxConstraints(
                    minHeight: MediaQuery.of(context).size.height - 
                               MediaQuery.of(context).padding.top - 
                               kToolbarHeight - 
                               100, // Account for bottom navigation bar
                  ),
                  child: IntrinsicHeight(
                    child: Column(
                      mainAxisAlignment: MainAxisAlignment.center,
                      crossAxisAlignment: CrossAxisAlignment.center,
                      children: [
                        const SizedBox(height: 20), // Add top padding
                        const Icon(Icons.security, size: 100, color: Colors.blue),
                        const SizedBox(height: 20),
                        const Text(
                          "Enter URL to detect phishing threats.",
                          textAlign: TextAlign.center,
                          style: TextStyle(
                            fontSize: 16,
                            color: Colors.grey,
                            fontFamily: 'Lato',
                          ),
                        ),
                        const SizedBox(height: 20),

                        // URL input field with open button
                        Row(
                          children: [
                            Expanded(
                              child: TextField(
                                controller: _urlController,
                                decoration: InputDecoration(
                                  labelText: "Enter URL",
                                  labelStyle: const TextStyle(fontFamily: 'Lato'),
                                  hintText: "https://example.com",
                                  border: OutlineInputBorder(
                                    borderRadius: BorderRadius.circular(12),
                                  ),
                                  prefixIcon: const Icon(Icons.link),
                                ),
                                keyboardType: TextInputType.url,
                              ),
                            ),
                            
                          ],
                        ),

                        const SizedBox(height: 20),

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
                                  "Check URL",
                                  style: TextStyle(
                                    fontFamily: 'Lato',
                                    fontSize: 18,
                                    fontWeight: FontWeight.w600,
                                    color: Colors.white,
                                  ),
                                ),
                        ),

                        const SizedBox(height: 20),

                        if (_result.isNotEmpty)
                          Column(
                            children: [
                              // Security status indicator
                              Row(
                                mainAxisAlignment: MainAxisAlignment.center,
                                children: [
                                  Icon(
                                    _phishingPercentage > _safePercentage ? Icons.warning : Icons.security,
                                    color: _phishingPercentage > _safePercentage ? Colors.orange : Colors.green,
                                    size: 24,
                                  ),
                                  const SizedBox(width: 8),
                                  Text(
                                    _phishingPercentage > _safePercentage ? "Potentially Unsafe" : "Safe to Visit",
                                    style: TextStyle(
                                      fontSize: 16,
                                      fontWeight: FontWeight.bold,
                                      fontFamily: 'Lato',
                                      color: _phishingPercentage > _safePercentage ? Colors.orange : Colors.green,
                                    ),
                                  ),
                                ],
                              ),
                              const SizedBox(height: 10),
                              // Analysis result text
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

                        const SizedBox(height: 10),

                        // Button to open URL in browser (only show if there's a result and URL)
                        if (_result.isNotEmpty && _lastAnalyzedUrl.isNotEmpty)
                          Row(
                            mainAxisAlignment: MainAxisAlignment.spaceEvenly,
                            children: [
                              
                              // Open in browser button
                              ElevatedButton.icon(
                                onPressed: _isOpeningUrl ? null : () => _openUrlInBrowser(_lastAnalyzedUrl),
                                icon: _isOpeningUrl 
                                    ? const SizedBox(
                                        width: 16,
                                        height: 16,
                                        child: CircularProgressIndicator(color: Colors.white, strokeWidth: 2),
                                      )
                                    : const Icon(Icons.open_in_browser, color: Colors.white),
                                label: Text(
                                  _isOpeningUrl 
                                      ? "Opening..." 
                                      : (_phishingPercentage > _safePercentage ? "Open Anyway" : "Open in Browser"),
                                  style: const TextStyle(
                                    fontFamily: 'Lato',
                                    fontSize: 14,
                                    fontWeight: FontWeight.w600,
                                    color: Colors.white,
                                  ),
                                ),
                                style: ElevatedButton.styleFrom(
                                  backgroundColor: _phishingPercentage > _safePercentage ? Colors.orange : Colors.green,
                                  padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 12),
                                  shape: RoundedRectangleBorder(
                                    borderRadius: BorderRadius.circular(12),
                                  ),
                                ),
                              ),
                            ],
                          ),

                        // Add bottom padding to prevent overflow
                        const SizedBox(height: 40),
                      ],
                    ),
                  ),
                ),
              ),
            ),
    );
  }
}