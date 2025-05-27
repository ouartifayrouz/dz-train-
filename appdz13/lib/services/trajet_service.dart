import 'package:cloud_firestore/cloud_firestore.dart';

class TrajetService {
  final FirebaseFirestore _firestore = FirebaseFirestore.instance;

  Future<List<QueryDocumentSnapshot>> getTrajetsPartantDans10Minutes() async {
    final now = DateTime.now();
    final snapshot = await _firestore.collection('historique_trajets').get();
    List<QueryDocumentSnapshot> trajetsProches = [];

    for (var doc in snapshot.docs) {
      final data = doc.data() as Map<String, dynamic>;
      final heureDepartStr = data['heureDepart'] as String? ?? '';
      if (heureDepartStr.isEmpty) continue;

      final parts = heureDepartStr.split(':');
      if (parts.length != 2) continue;

      final heure = int.tryParse(parts[0]);
      final minute = int.tryParse(parts[1]);
      if (heure == null || minute == null) continue;

      final departDateTime = DateTime(
          now.year, now.month, now.day, heure, minute
      );
      final diff = departDateTime.difference(now).inMinutes;
      if (diff >= 0 && diff <= 10) {
        trajetsProches.add(doc);
      }
    }
    return trajetsProches;
  }

  Future<void> sendTrajetNotification(String username, Map<String, dynamic> trajet) async {
    final notifRef = _firestore
        .collection('notifications')
        .doc(username)
        .collection('user_notifications');
    await notifRef.add({
      'title': 'Trajet imminent',
      'body': 'Votre trajet de ${trajet['gareDepart']} à ${trajet['gareArrivee']} part dans moins de 10 minutes.',
      'timestamp': FieldValue.serverTimestamp(),
      'isRead': false,
    });
  }
}
