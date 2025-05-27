import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:intl/intl.dart';
import 'package:percent_indicator/linear_percent_indicator.dart';

class StatsPannesTrainsWidget extends StatefulWidget {
  @override
  _StatsPannesTrainsWidgetState createState() => _StatsPannesTrainsWidgetState();
}

class _StatsPannesTrainsWidgetState extends State<StatsPannesTrainsWidget> {
  Map<String, int> panneCounts = {};
  Map<String, int> serviceCounts = {};
  bool isLoading = true;

  final DateTime startOfWeek = DateTime(2025, 5, 19);
  final DateTime endOfWeek = DateTime(2025, 5, 25);

  @override
  void initState() {
    super.initState();
    fetchStats();
  }

  Future<void> fetchStats() async {
    try {
      final startTimestamp = Timestamp.fromDate(startOfWeek);
      final endTimestamp = Timestamp.fromDate(endOfWeek.add(Duration(hours: 23, minutes: 59, seconds: 59)));

      final snapshot = await FirebaseFirestore.instance
          .collection('TRAIN')
          .where('lastUpdated', isGreaterThanOrEqualTo: startTimestamp)
          .where('lastUpdated', isLessThanOrEqualTo: endTimestamp)
          .get();

      Map<String, int> tempPannes = {};
      Map<String, int> tempServices = {};

      for (var doc in snapshot.docs) {
        final data = doc.data();
        final trainId = data['numtrain'] ?? 'Inconnu';
        final status = data['status'];

        if (status == 'en_service') {
          tempServices[trainId] = (tempServices[trainId] ?? 0) + 1;
        } else if (status == 'en_panne') {
          tempPannes[trainId] = (tempPannes[trainId] ?? 0) + 1;
        }
      }

      setState(() {
        panneCounts = tempPannes;
        serviceCounts = tempServices;
        isLoading = false;
      });
    } catch (e) {
      print("Erreur lors du chargement des pannes : $e");
      setState(() => isLoading = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final allTrains = {
      ...panneCounts.keys,
      ...serviceCounts.keys,
    }.toList()
      ..sort();

    if (isLoading) return Center(child: CircularProgressIndicator());
    if (allTrains.isEmpty) return Text("Aucune donnée de panne disponible pour cette semaine.");

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text("Taux de panne des trains", style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold)),
        const SizedBox(height: 16),
        ListView.builder(
          shrinkWrap: true,
          physics: NeverScrollableScrollPhysics(),
          itemCount: allTrains.length,
          itemBuilder: (context, index) {
            final trainId = allTrains[index];
            final pannes = panneCounts[trainId] ?? 0;
            final services = serviceCounts[trainId] ?? 0;
            final total = pannes + services;
            final pourcentage = total == 0 ? 0.0 : pannes / total;

            return Padding(
              padding: const EdgeInsets.symmetric(vertical: 8),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text("Train $trainId", style: TextStyle(fontWeight: FontWeight.bold)),
                  const SizedBox(height: 4),
                  LinearPercentIndicator(
                    lineHeight: 14.0,
                    percent: pourcentage.clamp(0.0, 1.0),
                    center: Text("${(pourcentage * 100).toStringAsFixed(1)}%", style: TextStyle(fontSize: 12)),
                    backgroundColor: Colors.grey.shade300,
                    progressColor: pourcentage > 0.5 ? Colors.redAccent : Colors.amber,
                    barRadius: Radius.circular(8),
                  ),
                  const SizedBox(height: 4),
                  Text("$pannes panne(s) / $total total"),
                ],
              ),
            );
          },
        ),
      ],
    );
  }
}
