import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';

// Couleurs personnalisées avec le nouveau design pastel
const LinearGradient backgroundGradient = LinearGradient(
  begin: Alignment.topCenter,
  end: Alignment.bottomCenter,
  colors: [
    Color(0xFFA3BED8), // bleu-gris moyen clair
    Color(0xFFD1D9E6), // gris bleu clair
    Color(0xFFF0F4F8), // blanc cassé très clair
  ],
);

const Color primaryColor = Color(0xFF5677A3); // bleu moyen pour les boutons
const Color primaryColorDark = Color(0xFF425B78); // bleu-gris plus sombre
const Color cardColor = Colors.white; // fond des champs texte
const Color textColor = Colors.black87; // texte principal
const Color subtitleColor = Colors.grey; // texte secondaire

class UpdateNotificationsPage extends StatefulWidget {
  const UpdateNotificationsPage({Key? key}) : super(key: key);

  @override
  _UpdateNotificationsPageState createState() => _UpdateNotificationsPageState();
}

class _UpdateNotificationsPageState extends State<UpdateNotificationsPage> {
  bool _isLoading = false;
  String _statusMessage = '';

  Future<void> addUnreadNotificationsToAllUsers() async {
    setState(() {
      _isLoading = true;
      _statusMessage = 'Démarrage de la mise à jour...';
    });

    final usersRef = FirebaseFirestore.instance.collection('User');
    final querySnapshot = await usersRef.get();

    int updatedCount = 0;
    int skippedCount = 0;

    for (var doc in querySnapshot.docs) {
      final data = doc.data();

      if (!data.containsKey('unreadNotifications')) {
        await usersRef.doc(doc.id).update({'unreadNotifications': 0});
        updatedCount++;
      } else {
        skippedCount++;
      }
    }

    setState(() {
      _isLoading = false;
      _statusMessage =
      'Mise à jour terminée.\nUtilisateurs mis à jour : $updatedCount\nUtilisateurs déjà à jour : $skippedCount';
    });
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Mise à jour notifications'),
        backgroundColor: primaryColorDark,
      ),
      body: Container(
        decoration: const BoxDecoration(gradient: backgroundGradient),
        padding: const EdgeInsets.all(24.0),
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Text(
              'Ajouter le champ "unreadNotifications" à tous les utilisateurs',
              style: TextStyle(
                fontSize: 20,
                fontWeight: FontWeight.bold,
                color: primaryColorDark,
              ),
              textAlign: TextAlign.center,
            ),
            const SizedBox(height: 24),
            if (_isLoading)
              const CircularProgressIndicator()
            else
              SizedBox(
                width: double.infinity,
                child: ElevatedButton(
                  onPressed: addUnreadNotificationsToAllUsers,
                  style: ElevatedButton.styleFrom(
                    backgroundColor: primaryColor,
                    padding: const EdgeInsets.symmetric(vertical: 14.0),
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(12.0),
                    ),
                    elevation: 4,
                  ),
                  child: const Text(
                    'Lancer la mise à jour',
                    style: TextStyle(fontSize: 16),
                  ),
                ),
              ),
            const SizedBox(height: 24),
            if (_statusMessage.isNotEmpty)
              Text(
                _statusMessage,
                style: TextStyle(
                  color: primaryColorDark,
                  fontSize: 16,
                ),
                textAlign: TextAlign.center,
              ),
          ],
        ),
      ),
    );
  }
}
