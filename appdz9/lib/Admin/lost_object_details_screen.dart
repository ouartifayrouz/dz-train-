import 'dart:convert';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter/material.dart';
import 'package:http/http.dart' as http;
import 'package:flutter_gen/gen_l10n/app_localizations.dart';

class LostObjectDetailsScreen extends StatelessWidget {
  final String objectId;

  LostObjectDetailsScreen({required this.objectId});

  Future<void> sendPushNotification(String token, String title, String body) async {
    try {
      await http.post(
        Uri.parse('https://fcm.googleapis.com/fcm/send'),
        headers: {
          'Content-Type': 'application/json',
          'Authorization': 'key=VOTRE_CLE_FCM_SERVEUR', // Remplace avec ta vraie clé
        },
        body: jsonEncode({
          'to': token,
          'notification': {
            'title': title,
            'body': body,
            'sound': 'default',
          },
          'priority': 'high',
        }),
      );
    } catch (e) {
      print('Erreur en envoyant la notification : $e');
    }
  }

  @override
  Widget build(BuildContext context) {
    final localizations = AppLocalizations.of(context)!;

    return Scaffold(
      appBar: AppBar(
        title: Text(localizations.lostObjectDetailsTitle),
        backgroundColor: const Color(0xFF353C67),
      ),
      body: FutureBuilder<DocumentSnapshot>(
        future: FirebaseFirestore.instance
            .collection('lost_objects')
            .doc(objectId)
            .get(),
        builder: (context, snapshot) {
          if (snapshot.hasError) {
            return Center(child: Text("${localizations.error} : ${snapshot.error}"));
          }
          if (!snapshot.hasData || !snapshot.data!.exists) {
            return Center(child: Text(localizations.objectNotFound));
          }

          final data = snapshot.data!.data() as Map<String, dynamic>;

          Future<void> updateStatusAndNotify(String newStatus) async {
            await FirebaseFirestore.instance
                .collection('lost_objects')
                .doc(objectId)
                .update({'status': newStatus});

            final String usernameProprietaire = data['username'];

            await FirebaseFirestore.instance
                .collection('notifications')
                .doc(usernameProprietaire)
                .collection('user_notifications')
                .add({
              'title': localizations.lostObjectStatusUpdateTitle,
              'body': '${localizations.lostObjectStatusUpdateBody} $newStatus.',
              'timestamp': FieldValue.serverTimestamp(),
              'isRead': false,
            });

            final userDoc = await FirebaseFirestore.instance
                .collection('User')
                .doc(usernameProprietaire)
                .get();

            final userToken = userDoc.data()?['fcmToken'];
            if (userToken != null) {
              await sendPushNotification(
                userToken,
                localizations.lostObjectStatusUpdateTitle,
                '${localizations.lostObjectStatusUpdateBody} $newStatus.',
              );
            }
          }

          return Padding(
            padding: const EdgeInsets.all(20),
            child: ListView(
              children: [
                if (data['imageUrl'] != null)
                  Image.network(data['imageUrl'], height: 200, fit: BoxFit.cover),
                const SizedBox(height: 20),
                _buildDetail(localizations.name, data['name'], localizations),
                _buildDetail(localizations.description, data['description'], localizations),
                _buildDetail(localizations.trainLine, data['trainLine'], localizations),
                _buildDetail(localizations.trainNumber, data['trainNumber'], localizations),
                _buildDetail(localizations.date, data['date'], localizations),
                _buildDetail(localizations.status, data['status'], localizations),
                const SizedBox(height: 20),
                ElevatedButton(
                  onPressed: () async {
                    await updateStatusAndNotify(localizations.statusFound);
                    ScaffoldMessenger.of(context).showSnackBar(
                      SnackBar(content: Text(localizations.statusUpdatedToFound)),
                    );
                  },
                  style: ElevatedButton.styleFrom(
                    backgroundColor: const Color(0xFF353C67),
                  ),
                  child: Text(localizations.markAsFound),
                ),
                const SizedBox(height: 10),
                ElevatedButton(
                  onPressed: () async {
                    await updateStatusAndNotify(localizations.statusNotFound);
                    ScaffoldMessenger.of(context).showSnackBar(
                      SnackBar(content: Text(localizations.statusUpdatedToNotFound)),
                    );
                  },
                  style: ElevatedButton.styleFrom(
                    backgroundColor: Colors.red.shade700,
                  ),
                  child: Text(localizations.markAsNotFound),
                ),
              ],
            ),
          );
        },
      ),
    );
  }

  Widget _buildDetail(String title, String? value, AppLocalizations localizations) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 6),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text("$title : ", style: const TextStyle(fontWeight: FontWeight.bold)),
          Expanded(child: Text(value?.isNotEmpty == true ? value! : localizations.notSpecified)),
        ],
      ),
    );
  }
}
