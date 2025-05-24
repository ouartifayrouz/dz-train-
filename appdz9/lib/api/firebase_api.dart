import 'package:flutter_local_notifications/flutter_local_notifications.dart';
import 'package:firebase_messaging/firebase_messaging.dart';
import 'package:flutter/material.dart';

class FirebaseApi {
  final FirebaseMessaging _firebaseMessaging = FirebaseMessaging.instance;
  final FlutterLocalNotificationsPlugin _localNotifications = FlutterLocalNotificationsPlugin();

  Future<void> initNotifications() async {
    // Demande les permissions (iOS & Android 13+)
    await _firebaseMessaging.requestPermission();

    // Configuration de l'icône de notification Android
    const AndroidInitializationSettings androidSettings = AndroidInitializationSettings('@mipmap/ic_launcher');

    // Paramètres d'initialisation (Android uniquement ici)
    const InitializationSettings initializationSettings = InitializationSettings(android: androidSettings);

    // Initialisation du plugin de notifications locales
    await _localNotifications.initialize(initializationSettings);

    // Ecoute les messages reçus quand l'app est au premier plan
    FirebaseMessaging.onMessage.listen((RemoteMessage message) {
      final notification = message.notification;
      if (notification != null) {
        _localNotifications.show(
          notification.hashCode,            // ID unique pour chaque notif
          notification.title,               // Titre de la notification
          notification.body,                // Corps de la notification
          const NotificationDetails(
            android: AndroidNotificationDetails(
              'channel_id',                // ID du canal
              'channel_name',              // Nom du canal
              importance: Importance.max, // Importance max pour les notifications Android
              priority: Priority.high,
              icon: '@mipmap/ic_launcher',
            ),
          ),
        );
      }
    });
  }
}
