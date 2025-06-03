import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:fl_chart/fl_chart.dart';
import 'package:intl/intl.dart';

class StatsTrainsWidget extends StatefulWidget {
  @override
  _StatsTrainsWidgetState createState() => _StatsTrainsWidgetState();
}

class _StatsTrainsWidgetState extends State<StatsTrainsWidget> {
  Map<String, int> trainCounts = {};
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
      final snapshot = await FirebaseFirestore.instance
          .collection('choix_trajets')
          .where("date", isGreaterThanOrEqualTo: DateFormat('yyyy-MM-dd').format(startOfWeek))
          .where("date", isLessThanOrEqualTo: DateFormat('yyyy-MM-dd').format(endOfWeek))
          .get();

      print("Docs dans choix_trajets : ${snapshot.docs.length}");

      Map<String, int> tempCounts = {};

      for (var doc in snapshot.docs) {
        final data = doc.data();
        int trajetId = data['trajetId'];
        int count = data['count'] ?? 0;

        final query = await FirebaseFirestore.instance
            .collection('TRAJET1')
            .where('ID', isEqualTo: trajetId)
            .limit(1)
            .get();

        if (query.docs.isNotEmpty) {
          final trajetData = query.docs.first.data();
          final trainId = trajetData['trainId'] ?? 'Inconnu';
          tempCounts[trainId] = (tempCounts[trainId] ?? 0) + count;
        } else {
          print("❌ Aucun trajet trouvé pour trajetId = $trajetId");
        }
      }

      print("Résultat trains : $tempCounts");

      setState(() {
        trainCounts = tempCounts;
        isLoading = false;
      });
    } catch (e) {
      print("❌ Erreur chargement stats trains : $e");
      setState(() {
        isLoading = false;
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    final total = trainCounts.values.fold(0, (a, b) => a + b);
    final colors = [
      Color(0xFFC4DCB9), // vert clair
      Color(0xFFFCFF88), // jaune
      Color(0xFFF4D9DE), // bleu clair
      Color(0xFF998BB1), // orange doux
      Color(0xFF859DB1), // violet doux
      Color(0xFF7F9583), // bleu pastel
    ];


    print("isLoading = $isLoading, trainCounts = $trainCounts");

    if (isLoading) return Center(child: CircularProgressIndicator());
    if (trainCounts.isEmpty) return Center(child: Text("Aucune donnée disponible pour les trains."));

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text("Répartition des trains", style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold)),
        const SizedBox(height: 16),
        SizedBox(
          height: 220,
          child: PieChart(
            PieChartData(
              sections: trainCounts.entries.toList().asMap().entries.map((entry) {
                int index = entry.key;
                String trainId = entry.value.key;
                int count = entry.value.value;
                double pourcentage = total == 0 ? 0 : (count / total) * 100;

                return PieChartSectionData(
                  value: count.toDouble(),
                  color: colors[index % colors.length],
                  title: "${pourcentage.toStringAsFixed(1)}%",
                  radius: 80,
                  titleStyle: TextStyle(color: Colors.black87, fontWeight: FontWeight.bold, fontSize: 14),
                );
              }).toList(),
              sectionsSpace: 2,
              centerSpaceRadius: 40,
            ),
          ),
        ),
        const SizedBox(height: 16),
        ListView.builder(
          shrinkWrap: true,
          physics: NeverScrollableScrollPhysics(),
          itemCount: trainCounts.length,
          itemBuilder: (context, index) {
            final trainId = trainCounts.keys.elementAt(index);
            final count = trainCounts[trainId]!;
            final percent = total == 0 ? 0 : (count / total) * 100;

            return ListTile(
              leading: CircleAvatar(
                backgroundColor: colors[index % colors.length],
                radius: 10,
              ),
              title: Text("Train : $trainId"),
              subtitle: Text("${percent.toStringAsFixed(1)}% ($count sélections)"),
            );
          },
        ),
      ],
    );
  }
}
