import 'package:audioplayers/audioplayers.dart';
import 'package:cloud_firestore/cloud_firestore.dart';

class NotificationListenerService {
  static final NotificationListenerService _instance = NotificationListenerService._internal();

  factory NotificationListenerService() => _instance;

  NotificationListenerService._internal();

  final AudioPlayer _audioPlayer = AudioPlayer();
  Stream<QuerySnapshot>? _notificationStream;
  int _lastNotificationCount = 0;

  void startListening(String username) {
    final collectionRef = FirebaseFirestore.instance
        .collection('notifications')
        .doc(username)
        .collection('user_notifications');

    _notificationStream = collectionRef
        .where('isRead', isEqualTo: false)
        .snapshots();

    _notificationStream!.listen((snapshot) async {
      final currentCount = snapshot.docs.length;

      if (currentCount > _lastNotificationCount) {
        // Une nouvelle notification a été ajoutée
        await _audioPlayer.play(AssetSource('sounds/blood_splash.mp3'));
      }

      _lastNotificationCount = currentCount;
    });
  }

  void stopListening() {
    _notificationStream = null;
    _lastNotificationCount = 0;
  }
}
