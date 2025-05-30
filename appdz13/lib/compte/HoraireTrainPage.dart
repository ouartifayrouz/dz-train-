import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';

class HoraireTrainPage extends StatefulWidget {
  @override
  _HoraireTrainPageState createState() => _HoraireTrainPageState();
}

class _HoraireTrainPageState extends State<HoraireTrainPage> {
  final Color primaryColor = const Color(0x998BB1FF);
  final Color rowColor1 = const Color(0xFFE8ECEAFF);
  final Color rowColor2 = const Color(0xFFDDD7E8FF);
  final Color resetButtonColor = const Color(0xFFF8D2D0);
  final Color applyButtonColor = const Color(0x998BB1FF);
  Map<String, String> trainStatusMap = {};

  TextEditingController _searchController = TextEditingController();
  String _searchFilter = '';

  String _tri = 'Aucun';
  bool _ordreCroissant = true;

  TimeOfDay? _heureMin;
  TimeOfDay? _heureMax;

  bool isOrderSelected = false;
  bool isTriSelected = false;
  bool isTimeRangeSelected = false;

  Color getStatusColor(String statut) {
    switch (statut) {
      case 'en_service':
        return Colors.green;
      case 'en_retard':
        return Colors.orange;
      case 'en_panne':
        return Colors.black;
      default:
        return Colors.grey;
    }
  }
  @override
  void initState() {
    super.initState();
    _loadTrainStatuses();
  }
  Future<void> _loadTrainStatuses() async {
    final snapshot = await FirebaseFirestore.instance.collection('TRAIN').get();
    setState(() {
      trainStatusMap = {
        for (var doc in snapshot.docs)
          doc.id: doc['status'] ?? 'inconnu',
      };
    });
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: Text("Tableau des trajets", style: TextStyle(color: Colors.black87)),
        backgroundColor: primaryColor,
      ),
      body: Padding(
        padding: const EdgeInsets.all(16.0),
        child: Column(
          children: [
            // Barre de recherche + bouton filtre
            Row(
              children: [
                Expanded(
                  flex: 3,
                  child: TextField(
                    controller: _searchController,
                    style: TextStyle(color: Colors.black),
                    decoration: InputDecoration(
                      labelText: 'Recherche...',
                      labelStyle: TextStyle(color: Colors.black),
                      prefixIcon: Icon(Icons.search, color: Colors.black),
                      border: OutlineInputBorder(borderRadius: BorderRadius.circular(12)),
                    ),
                    onChanged: (value) {
                      setState(() {
                        _searchFilter = value.toLowerCase();
                      });
                    },
                  ),
                ),
                SizedBox(width: 10),
                Expanded(
                  flex: 2,
                  child: ElevatedButton(
                    onPressed: () => _showFilterModal(context),
                    child: Text("Filtrer", style: TextStyle(color: Colors.white)),
                    style: ButtonStyle(backgroundColor: MaterialStateProperty.all(primaryColor)),
                  ),
                ),
              ],
            ),

            SizedBox(height: 10),

            // Tableau des trajets
            Expanded(
              child: StreamBuilder<QuerySnapshot>(
                stream: FirebaseFirestore.instance.collection('TRAJET1').snapshots(),
                builder: (context, snapshot) {
                  if (!snapshot.hasData) return Center(child: CircularProgressIndicator());

                  final trajets = snapshot.data!.docs;

                  int? _timeOfDayToMinutes(TimeOfDay? t) =>
                      t != null ? t.hour * 60 + t.minute : null;

                  final int? minMinutes = _heureMin != null ? _timeOfDayToMinutes(_heureMin) : null;
                  final int? maxMinutes = _heureMax != null ? _timeOfDayToMinutes(_heureMax) : null;

                  final filtered = trajets.where((doc) {
                    final data = doc.data() as Map<String, dynamic>;
                    final heureDepartStr = data["Heure_de_Départ"] ?? '';
                    final heureDepartMinutes = _parseTimeToMinutes(heureDepartStr);
                    if (heureDepartMinutes == null) return false;
                    if (minMinutes != null && heureDepartMinutes < minMinutes) return false;
                    if (maxMinutes != null && heureDepartMinutes > maxMinutes) return false;

                    final all = data.values.map((e) => e.toString().toLowerCase()).join(' ');
                    return all.contains(_searchFilter);
                  }).toList();

                  if (_tri == 'Heure') {
                    filtered.sort((a, b) {
                      final dataA = a.data() as Map<String, dynamic>;
                      final dataB = b.data() as Map<String, dynamic>;
                      final haMin = _parseTimeToMinutes(dataA["Heure_de_Départ"] ?? '');
                      final hbMin = _parseTimeToMinutes(dataB["Heure_de_Départ"] ?? '');
                      if (haMin == null || hbMin == null) return 0;
                      return _ordreCroissant ? haMin.compareTo(hbMin) : hbMin.compareTo(haMin);
                    });
                  } else if (_tri == 'Ligne') {
                    filtered.sort((a, b) {
                      final la = a['lineId'] ?? '';
                      final lb = b['lineId'] ?? '';
                      return la.compareTo(lb);
                    });
                  }

                  return SingleChildScrollView(
                    scrollDirection: Axis.horizontal,
                    child: DataTable(
                      headingRowColor: MaterialStateProperty.all(primaryColor),
                      headingTextStyle: TextStyle(color: Colors.black87, fontWeight: FontWeight.bold),
                      columns: const [
                        DataColumn(label: Text('Départ (Heure)')),
                        DataColumn(label: Text("Arrêt (Heure)")),
                        DataColumn(label: Text('Train')),
                        DataColumn(label: Text('Ligne')),
                        DataColumn(label: Text('Jour de Circulation')),
                        DataColumn(label: Text('Statut')),
                      ],
                      rows: List.generate(filtered.length, (index) {
                        final trajet = filtered[index].data() as Map<String, dynamic>;
                        final trainId = trajet['trainId'] ?? '';
                        final statut = trainStatusMap[trainId] ?? 'inconnu';
                        return DataRow(
                          color: MaterialStateColor.resolveWith(
                                (states) => statut == 'en_panne'
                                ? Colors.red.withOpacity(0.8)
                                : (index.isEven ? rowColor1 : rowColor2),
                          ),
                          cells: [
                            DataCell(Text(
                              '${trajet['Depart'] ?? ''} (${trajet["Heure_de_Départ"] ?? ''})',
                            )),
                            DataCell(Text(
                              '${trajet['Aret'] ?? ''} (${trajet["Heure_d\'Arrivée"] ?? ''})',
                            )),

                            DataCell(Text('${trajet['trainId'] ?? ''}')),
                            DataCell(Text('${trajet['lineId'] ?? ''}')),
                            DataCell(Text('${trajet['Jour_de_Circulation'] ?? ''}')),
                            DataCell(Text(
                              statut,
                              style: TextStyle(
                                color: getStatusColor(statut),
                                fontWeight: FontWeight.bold,
                              ),
                            )),
                          ],
                        );
                      }),
                    ),
                  );
                },
              ),
            ),
          ],
        ),
      ),
    );
  }

  Future<void> _showFilterModal(BuildContext context) async {
    showModalBottomSheet(
      context: context,
      builder: (context) {
        return Padding(
          padding: const EdgeInsets.all(16.0),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Text("Ordre de Tri", style: TextStyle(fontWeight: FontWeight.bold)),
              Row(
                children: [
                  ElevatedButton(
                    onPressed: () {
                      setState(() {
                        isOrderSelected = true;
                        isTriSelected = false;
                        _ordreCroissant = true;
                      });
                    },
                    child: Text("Croissant"),
                    style: ButtonStyle(backgroundColor: MaterialStateProperty.all(rowColor2)),
                  ),
                  SizedBox(width: 10),
                  ElevatedButton(
                    onPressed: () {
                      setState(() {
                        isOrderSelected = true;
                        isTriSelected = false;
                        _ordreCroissant = false;
                      });
                    },
                    child: Text("Décroissant"),
                    style: ButtonStyle(backgroundColor: MaterialStateProperty.all(rowColor2)),
                  ),
                ],
              ),
              SizedBox(height: 20),
              Text("Tri", style: TextStyle(fontWeight: FontWeight.bold)),
              Row(
                children: [
                  ElevatedButton(
                    onPressed: () {
                      setState(() {
                        isTriSelected = true;
                        _tri = 'Aucun';
                      });
                    },
                    child: Text("Aucun"),
                    style: ButtonStyle(backgroundColor: MaterialStateProperty.all(rowColor2)),
                  ),
                  SizedBox(width: 10),
                  ElevatedButton(
                    onPressed: () {
                      setState(() {
                        isTriSelected = true;
                        _tri = 'Heure';
                      });
                    },
                    child: Text("Heure"),
                    style: ButtonStyle(backgroundColor: MaterialStateProperty.all(rowColor2)),
                  ),
                  SizedBox(width: 10),
                  ElevatedButton(
                    onPressed: () {
                      setState(() {
                        isTriSelected = true;
                        _tri = 'Ligne';
                      });
                    },
                    child: Text("Ligne"),
                    style: ButtonStyle(backgroundColor: MaterialStateProperty.all(rowColor2)),
                  ),
                ],
              ),
              SizedBox(height: 20),
              Text("Plage Horaire", style: TextStyle(fontWeight: FontWeight.bold)),
              Row(
                children: [
                  Text("Min : "),
                  TextButton(
                    onPressed: () => _selectTime(context, true),
                    child: Text(
                      _heureMin?.format(context) ?? "Sélectionner",
                      style: TextStyle(color: Colors.blue),
                    ),
                  ),
                ],
              ),
              Row(
                children: [
                  Text("Max : "),
                  TextButton(
                    onPressed: () => _selectTime(context, false),
                    child: Text(
                      _heureMax?.format(context) ?? "Sélectionner",
                      style: TextStyle(color: Colors.blue),
                    ),
                  ),
                ],
              ),
              Row(
                children: [
                  ElevatedButton(
                    onPressed: () {
                      setState(() {
                        _searchFilter = '';
                        _tri = 'Aucun';
                        _ordreCroissant = true;
                        _heureMin = null;
                        _heureMax = null;
                      });
                    },
                    child: Text("Réinitialiser"),
                    style: ButtonStyle(backgroundColor: MaterialStateProperty.all(resetButtonColor)),
                  ),
                  SizedBox(width: 10),
                  ElevatedButton(
                    onPressed: () {
                      Navigator.pop(context);
                      setState(() {});
                    },
                    child: Text("Appliquer les filtres"),
                    style: ButtonStyle(backgroundColor: MaterialStateProperty.all(applyButtonColor)),
                  ),
                ],
              ),
            ],
          ),
        );
      },
    );
  }

  Future<void> _selectTime(BuildContext context, bool isMin) async {
    final picked = await showTimePicker(context: context, initialTime: TimeOfDay.now());
    if (picked != null) {
      setState(() {
        if (isMin) {
          _heureMin = picked;
        } else {
          _heureMax = picked;
        }
      });
    }
  }

  int? _parseTimeToMinutes(String heure) {
    final parts = heure.split(':');
    if (parts.length == 2) {
      final hours = int.tryParse(parts[0]);
      final minutes = int.tryParse(parts[1]);
      if (hours != null && minutes != null) {
        return hours * 60 + minutes;
      }
    }
    return null;
  }
}