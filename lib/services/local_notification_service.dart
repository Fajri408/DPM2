import 'package:flutter/material.dart';
import 'package:flutter_local_notifications/flutter_local_notifications.dart';
import 'package:seclick/services/api_service.dart';


class LocalNotificationService {
  // Singleton
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

    await _plugin.initialize(initSettings);
    await _plugin
        .resolvePlatformSpecificImplementation<AndroidFlutterLocalNotificationsPlugin>()
        ?.requestNotificationsPermission(); // Untuk Android 13+
  }

  Future<void> showNotification({
    int id = 0,
    String? title,
    String? body,
  }) async {
    const AndroidNotificationDetails androidDetails = AndroidNotificationDetails(
      'seclick_channel_id',
      'SeClick Guard',
      channelDescription: 'Menampilkan hasil deteksi tautan',
      importance: Importance.max,
      priority: Priority.high,
      icon: "ic_status_bar",
    );

    const NotificationDetails details = NotificationDetails(
      android: androidDetails,
    );

    await _plugin.show(id, title, body, details);
  }
}


//final FlutterLocalNotificationsPlugin flutterLocalNotificationsPlugin = FlutterLocalNotificationsPlugin();
//
//Future<void> initLocalNotif() async {
//  const AndroidInitializationSettings initializationSettingsAndroid =
//    AndroidInitializationSettings('@mipmap/ic_launcher');
//
//  const InitializationSettings initializationSettings =
//    InitializationSettings(android: initializationSettingsAndroid);
//
//  await flutterLocalNotificationsPlugin.initialize( initializationSettings);
//}
//
//Future<void> showResultNotif(String title, String body) async {
//  const AndroidNotificationDetails androidPlatformChannelSpecifics =
//    AndroidNotificationDetails(
//    "seclick_channel_id",
//    "SeClick Guard",
//    channelDescription: "Menampilkan hasil deteksi tautan",
//    importance: Importance.max,
//    priority: Priority.high,
//    showWhen: false,
//  );
//
//  const NotificationDetails platformChannelSpecifics =
//    NotificationDetails(android: androidPlatformChannelSpecifics);
//
//  await flutterLocalNotificationsPlugin.show(0, title, body, platformChannelSpecifics);
//}
//
Future<void> handleNotificationData(String textFromNotif) async {
  String body = "";
  final response = await ApiService.checkUrl(textFromNotif);

  if (response.phishingPercentage > response.safePercentage) {
    body = "Tautan ${response.url} kemungkinan berbahaya";
  } else {
    body = "Tautan ${response.url} Aman";
  }

  debugPrint("Hasil deteksi $body");
  await LocalNotificationService().showNotification(title: 'Hasil Analisis', body: body);
}
