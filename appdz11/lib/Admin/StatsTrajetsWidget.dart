import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:fl_chart/fl_chart.dart';
import 'package:intl/intl.dart';

class StatsTrajetsWidget extends StatefulWidget {
  @override
  _StatsTrajetsWidgetState createState() => _StatsTrajetsWidgetState();
}

class _StatsTrajetsWidgetState extends State<StatsTrajetsWidget> {
  Map<int, int> totalParTrajet = {};        // trajetId → count
  Map<int, String> lineIdParTrajet = {};    // trajetId → lineId
  Map<String, int> totalParLigneId = {};    // lineId → count

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

      Map<int, int> tempTotals = {};

      for (var doc in snapshot.docs) {
        final data = doc.data();
        int trajetId = data['trajetId'];
        int count = data['count'] ?? 0;
        tempTotals[trajetId] = (tempTotals[trajetId] ?? 0) + count;
      }

      Map<int, String> tempLineIds = {};
      for (int trajetId in tempTotals.keys) {
        final query = await FirebaseFirestore.instance
            .collection('TRAJET1')
            .where('ID', isEqualTo: trajetId)
            .limit(1)
            .get();

        if (query.docs.isNotEmpty) {
          final data = query.docs.first.data();
          tempLineIds[trajetId] = data['lineId'] ?? 'inconnu';
        } else {
          tempLineIds[trajetId] = 'inconnu';
        }
      }

      // Regrouper les trajets par lineId
      Map<String, int> tempLineTotals = {};
      tempTotals.forEach((trajetId, count) {
        String lineId = tempLineIds[trajetId] ?? 'inconnu';
        tempLineTotals[lineId] = (tempLineTotals[lineId] ?? 0) + count;
      });

      setState(() {
        totalParTrajet = tempTotals;
        lineIdParTrajet = tempLineIds;
        totalParLigneId = tempLineTotals;
        isLoading = false;
      });
    } catch (e) {
      print("Erreur lors du chargement des trajets : $e");
    }
  }

  @override
  Widget build(BuildContext context) {
    final totalCount = totalParLigneId.values.fold(0, (a, b) => a + b);
    final colors = [
      Color(0xFFD3EAC1),
      Color(0xFFFBFDA0),
      Color(0xFFF4D9DE),
      Color(0xFF998BB1),
      Color(0xFF859DB1),
      Color(0xFF7F9583),
    ];

    if (isLoading) return Center(child: CircularProgressIndicator());
    if (totalParLigneId.isEmpty) {
      return Text("Aucune donnée disponible pour cette semaine.");
    }

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text("Répartition par ligne :", style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold)),
        const SizedBox(height: 16),
        SizedBox(
          height: 220,
          child: PieChart(
            PieChartData(
              sections: totalParLigneId.entries.toList().asMap().entries.map((entry) {
                int index = entry.key;
                String lineId = entry.value.key;
                int count = entry.value.value;
                double percent = totalCount == 0 ? 0 : (count / totalCount) * 100;

                return PieChartSectionData(
                  value: count.toDouble(),
                  color: colors[index % colors.length],
                  title: "${percent.toStringAsFixed(1)}%",
                  titleStyle: TextStyle(color: Colors.black87, fontWeight: FontWeight.bold, fontSize: 14),
                  radius: 70,
                );
              }).toList(),
              centerSpaceRadius: 40,
              sectionsSpace: 2,
            ),
          ),
        ),
        const SizedBox(height: 16),
        ...totalParLigneId.entries.toList().asMap().entries.map((entry) {
          int index = entry.key;
          String lineId = entry.value.key;
          int count = entry.value.value;
          double percent = totalCount == 0 ? 0 : (count / totalCount) * 100;

          return Padding(
            padding: const EdgeInsets.symmetric(vertical: 4),
            child: Row(
              children: [
                CircleAvatar(
                  radius: 6,
                  backgroundColor: colors[index % colors.length],
                ),
                const SizedBox(width: 10),
                Expanded(child: Text("Ligne $lineId")),
                Text("${percent.toStringAsFixed(1)}% ($count fois)"),
              ],
            ),
          );
        }),
      ],
    );
  }
}
