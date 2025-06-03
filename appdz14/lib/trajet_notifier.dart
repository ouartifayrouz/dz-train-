import 'dart:async';
import 'package:dztrainfay/services/trajet_service.dart';
import 'package:shared_preferences/shared_preferences.dart';

class TrajetNotifier {
  final TrajetService trajetService = TrajetService();

  Future<void> checkAndNotify(String username) async {
    final prefs = await SharedPreferences.getInstance();
    final trajets = await trajetService.getTrajetsPartantDans10Minutes();

    for (var trajetDoc in trajets) {
      final data = trajetDoc.data() as Map<String, dynamic>;

      // Clé unique pour ce trajet (par ex. id du document Firestore)
      final notifKey = 'notif_sent_${trajetDoc.id}';

      // Vérifie si la notif a déjà été envoyée
      final alreadySent = prefs.getBool(notifKey) ?? false;
      if (!alreadySent) {
        await trajetService.sendTrajetNotification(username, data);

        // Marque la notif comme envoyée
        await prefs.setBool(notifKey, true);
      }
    }
  }
}
