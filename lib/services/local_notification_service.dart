import 'package:flutter/material.dart';
import 'package:flutter_local_notifications/flutter_local_notifications.dart';
import 'package:seclick/services/api_service.dart';
import 'package:seclick/services/local_storage_service.dart';
import 'package:seclick/model/log_entry.dart';
import 'package:intl/intl.dart';
import 'package:url_launcher/url_launcher.dart';


class LocalNotificationService {
  static final LocalNotificationService _instance = LocalNotificationService._internal();
  factory LocalNotificationService() => _instance;
  LocalNotificationService._internal();

  final FlutterLocalNotificationsPlugin _plugin = FlutterLocalNotificationsPlugin();

  Future<void> init() async {
    const AndroidInitializationSettings androidInitSettings =
        AndroidInitializationSettings('@mipmap/ic_launcher');

    const InitializationSettings initSettings = InitializationSettings(
      android: androidInitSettings,
    );

    await _plugin.initialize(
  initSettings,
  onDidReceiveNotificationResponse: (NotificationResponse response) async {
    final String? actionId = response.actionId;
    final String? payload = response.payload;

    debugPrint("Notification action: $actionId | payload: $payload");

    if (actionId == 'open_url' && payload != null) {
      final Uri url = Uri.parse(payload);
      if (await canLaunchUrl(url)) {
        await launchUrl(url, mode: LaunchMode.externalApplication);
      } else {
        debugPrint('Cannot launch URL: $url');
      }
    } else {
      debugPrint('ℹNotification tapped, not action button. No URL launched.');
    }
  },
);


    // Request permission for Android 13+
    await _plugin
        .resolvePlatformSpecificImplementation<AndroidFlutterLocalNotificationsPlugin>()
        ?.requestNotificationsPermission();
  }

  Future<void> showNotification({
    int id = 0,
    String? title,
    String? body,
    String? url,
    double? phishingProbability,
    double? safeProbability,
  }) async {
    try {
      String notificationBody = body ?? '';

      // Generate multiline message if probability given
      if (phishingProbability != null && safeProbability != null && url != null) {
        final isPhishing = phishingProbability > safeProbability;
        notificationBody =
            '🔍 Analysis Result for: $url\n\n'
            '${isPhishing ? '🚨 *Potential Phishing Detected!*' : '✅ Safe Link Detected'}\n\n'
            '📊 Probability:\n'
            '• Phishing: ${phishingProbability.toStringAsFixed(1)}%\n'
            '• Safe: ${safeProbability.toStringAsFixed(1)}%';
      }

      final AndroidNotificationDetails androidDetails = AndroidNotificationDetails(
        'seclick_channel_id',
        'SeClick Guard',
        channelDescription: 'Displays link detection results',
        importance: Importance.max,
        priority: Priority.high,
        icon: '@mipmap/ic_launcher',
        color: const Color(0xFF027373),
        styleInformation: BigTextStyleInformation(
          notificationBody,
          htmlFormatBigText: false,
          contentTitle: title,
          summaryText: 'Tap to open',
        ),
        actions: url != null
            ? [
                AndroidNotificationAction(
                  'open_url',
                  'Open Link',
                  showsUserInterface: true,
                )
              ]
            : null,
      );

      final NotificationDetails details = NotificationDetails(android: androidDetails);

      await _plugin.show(
        id,
        title,
        notificationBody,
        details,
        payload: url,
      );
    } catch (e) {
      debugPrint('Error showing notification: $e');
    }
  }



  Future<void> handleNotificationData(String textFromNotif) async {
    try {
      final response = await ApiService.checkUrl(textFromNotif);
      final isPhishing = response.phishingPercentage > response.safePercentage;
      
      String body = 
    '🔍 *Analysis Result for:* ${response.url}\n'
    '\n'
    '${isPhishing ? '🚨 Warning: Potential Phishing Link' : '✅ Safe Link Detected'}\n'
    '\n'
    '📊 Probability Analysis:\n'
    '• Phishing: ${response.phishingPercentage.toStringAsFixed(1)}%\n'
    '• Safe: ${response.safePercentage.toStringAsFixed(1)}%';


      // Save to local storage
      final now = DateTime.now();
      final timestamp = DateFormat('yyyy-MM-dd HH:mm:ss').format(now);
      
      final logEntry = LogEntry(
        timestamp: timestamp,
        url: response.url,
        details: isPhishing ? "Dangerous Link" : "Safe Link",
        phishingPercentage: response.phishingPercentage,
        safePercentage: response.safePercentage,
      );
      
      await LocalStorageService().savePrediction(logEntry);

      debugPrint("Detection result: $body");
      await LocalNotificationService().showNotification(
        title: 'Link Analysis Result',
        body: body,
        url: response.url,
        phishingProbability: response.phishingPercentage,
        safeProbability: response.safePercentage,
      );
    } catch (e) {
      debugPrint('Error handling notification data: $e');
    }
  }
}