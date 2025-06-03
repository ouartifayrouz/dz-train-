import 'dart:async';
import 'dart:math';
import 'dart:ui' as ui;
import 'package:flutter/services.dart';
import 'package:flutter/material.dart';
import 'package:google_maps_flutter/google_maps_flutter.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'liste_trajets_screen.dart';
import 'home_screen.dart';
class NouvelleSimulationPage extends StatefulWidget {
  final Trajet trajet;
  final String departure;
  final String destination;
  final DateTime date;

  const NouvelleSimulationPage({
    super.key,
    required this.trajet,
    required this.departure,
    required this.destination,
    required this.date,
  });

  @override
  _NouvelleSimulationPageState createState() => _NouvelleSimulationPageState();
}

class _NouvelleSimulationPageState extends State<NouvelleSimulationPage> {
  GoogleMapController? _controller;
  List<LatLng> fullPath = [];
  List<Map<String, dynamic>> gares = []; // {nom, coord}
  Marker? _trainMarker;
  int currentIndex = 0;
  int? indexInitialTrain; // ← pour démarrer l'animation depuis la bonne position

  int currentGareIndex = 0;
  late BitmapDescriptor trainIcon;
  Timer? _timer;

  bool alerteAffichee = false; // pour éviter plusieurs alertes
  late LatLng gareDepartPos;

  DateTime? _heureDepartReelle;
  bool simulationLancee = false;
  Duration _tempsRestant = Duration.zero;
  Timer? _minuteurAvantDepart;
  bool finTrajetAffichee = false;


  @override
  void initState() {
    super.initState();
    chargerIconTrain().then((_) {
      chargerGaresEtPoints().then((_) {

        _verifierEtDemarrer();

      });
    });
  }
  void _verifierEtDemarrer() {
    final now = DateTime.now();
    final aujourdHui = DateTime(now.year, now.month, now.day);

    // Trouver la gare avec l'id le plus petit
    final premiereGare = widget.trajet.garesIntermediaires
        .reduce((a, b) => a.id < b.id ? a : b);

    // Récupérer l'heure de passage dans cette gare
    DateTime heurePassagePremiereGare = _parseHeure(premiereGare.heurePassage);
    _heureDepartReelle = DateTime(
      aujourdHui.year,
      aujourdHui.month,
      aujourdHui.day,
      heurePassagePremiereGare.hour,
      heurePassagePremiereGare.minute,
    );

    final difference = _heureDepartReelle!.difference(now);

    if (difference.inSeconds <= 0) {
      // L'heure est passée ou actuelle, on démarre directement
      lancerSimulation();
      simulationLancee = true;
    } else {
      // Afficher le compte à rebours
      _tempsRestant = difference;
      _demarrerMinuteurAvantDepart();
    }
  }
  Future<void> _afficherFinTrajet() async {
    await showDialog(
      context: context,
      barrierDismissible: false,
      builder: (context) => AlertDialog(
        title: const Text("✅ Trajet terminé",style: const TextStyle(color: Colors.black87, fontSize: 16, fontWeight: FontWeight.bold),),
        content: Text("Le train est arrivé à destination : ${widget.trajet.gareArrivee}.\nMerci d’avoir voyagé avec nous."),
        actions: [
          TextButton(
            onPressed: () {
              Navigator.of(context).pop();
              Navigator.pushReplacement(
                context,
                MaterialPageRoute(
                  builder: (_) => ListeTrajetsScreen(
                    departure: widget.departure,
                    destination: widget.destination,
                    date: widget.date,
                    message: "Fin du trajet. Merci et à bientôt !",
                  ),
                ),
              );
            },
            child: const Text("OK"),
          ),
        ],
      ),
    );
  }


  void _demarrerMinuteurAvantDepart() {
    _minuteurAvantDepart = Timer.periodic(const Duration(seconds: 1), (timer) {
      setState(() {
        _tempsRestant = _tempsRestant! - const Duration(seconds: 1);
      });

      if (_tempsRestant!.inSeconds <= 0) {
        timer.cancel();
        lancerSimulation();
        simulationLancee = true;
      }
    });
  }

  Future<void> chargerIconTrain() async {
    final data = await rootBundle.load('assets/images/train_icon.png');
    final codec = await ui.instantiateImageCodec(
      data.buffer.asUint8List(),
      targetWidth: 60,
      targetHeight: 60,
    );
    final frame = await codec.getNextFrame();
    final image = frame.image;
    final byteData = await image.toByteData(format: ui.ImageByteFormat.png);
    trainIcon = BitmapDescriptor.fromBytes(byteData!.buffer.asUint8List());
  }

  DateTime _parseHeure(String heure) {
    final parts = heure.split(":");
    return DateTime(0, 1, 1, int.parse(parts[0]), int.parse(parts[1]));
  }

  Future<void> chargerGaresEtPoints() async {
    gares.clear();
    fullPath.clear();

    final orderedGares = widget.trajet.garesIntermediaires
        .where((g) => g.id <= (widget.trajet.idArrivee ?? 999999))
        .toList()
      ..sort((a, b) => a.id.compareTo(b.id));

    final noms = orderedGares.map((g) => g.gare).toList();

    if (!noms.contains(widget.trajet.gareDepart)) {
      noms.insert(0, widget.trajet.gareDepart);
    }

    if (!noms.contains(widget.trajet.gareArrivee)) {
      noms.add(widget.trajet.gareArrivee);
    }

    for (String nom in noms) {
      final snap = await FirebaseFirestore.instance
          .collection('Gare')
          .where('name', isEqualTo: nom)
          .get();

      if (snap.docs.isNotEmpty) {
        final data = snap.docs.first.data();
        final lat = data['location']['lat'];
        final lng = data['location']['lng'];
        gares.add({"nom": nom, "coord": LatLng(lat, lng)});
      }
    }

    // Trouver la position de la vraie gare de départ
    final depart = gares.firstWhere(
          (g) => g["nom"] == widget.trajet.gareDepart,
      orElse: () => {"nom": "", "coord": LatLng(0, 0)},
    );
    gareDepartPos = depart["coord"];

    // Interpolation fluide
    const steps = 30;
    for (int i = 0; i < gares.length - 1; i++) {
      final p1 = gares[i]["coord"];
      final p2 = gares[i + 1]["coord"];

      for (int j = 0; j < steps; j++) {
        final lat = p1.latitude + (p2.latitude - p1.latitude) * (j / steps);
        final lng = p1.longitude + (p2.longitude - p1.longitude) * (j / steps);
        fullPath.add(LatLng(lat, lng));
      }
    }
    fullPath.add(gares.last["coord"]);
    final now = DateTime.now();
    final aujourdHui = DateTime(now.year, now.month, now.day);

// Étape 1 : Obtenir la gare avec l'ID minimal
    final gareMin = widget.trajet.garesIntermediaires.reduce((a, b) => a.id < b.id ? a : b);
    final heureMin = DateTime(
      aujourdHui.year,
      aujourdHui.month,
      aujourdHui.day,
      int.parse(gareMin.heurePassage.split(":")[0]),
      int.parse(gareMin.heurePassage.split(":")[1]),
    );

// Étape 2 : Trouver la gare de départ sélectionnée
    final gareDepartTrajet = widget.trajet.garesIntermediaires.firstWhere(
          (g) => g.gare == widget.trajet.gareDepart,
      orElse: () => gareMin,
    );
    final heureDepart = DateTime(
      aujourdHui.year,
      aujourdHui.month,
      aujourdHui.day,
      int.parse(gareDepartTrajet.heurePassage.split(":")[0]),
      int.parse(gareDepartTrajet.heurePassage.split(":")[1]),
    );

// Vérification si maintenant est entre les deux heures
    if (now.isAfter(heureMin) && now.isBefore(heureDepart)) {
      final dureeTotale = heureDepart.difference(heureMin).inSeconds;
      final tempsPasse = now.difference(heureMin).inSeconds;
      final proportion = tempsPasse / dureeTotale;

      // Chercher les index des gares
      final indexMin = gares.indexWhere((g) => g["nom"] == gareMin.gare);
      final indexDepart = gares.indexWhere((g) => g["nom"] == gareDepartTrajet.gare);

      if (indexMin != -1 && indexDepart != -1 && indexMin < indexDepart) {
        // Calculer le nombre total de points entre les deux gares
        final steps = 30;
        final totalPoints = (indexDepart - indexMin) * steps;

        // Index du point approximatif selon la proportion
        final indexTrain = indexMin * steps + (proportion * totalPoints).floor();

        if (indexTrain >= 0 && indexTrain < fullPath.length) {
          indexInitialTrain = indexTrain; // <-- on garde l'index pour lancerSimulation
          setState(() {
            _trainMarker = Marker(
              markerId: const MarkerId("train"),
              position: fullPath[indexTrain],
              icon: trainIcon,
            );
          });
        }

      }
    }

    setState(() {
      _trainMarker = Marker(
        markerId: const MarkerId("train"),
        position: fullPath.first,
        icon: trainIcon,
      );
    });
  }

  // Fonction pour calculer distance entre deux LatLng en mètres (formule haversine)
  double distanceEnMetres(LatLng p1, LatLng p2) {
    const double R = 6371000; // Rayon terre en mètres
    double dLat = _deg2rad(p2.latitude - p1.latitude);
    double dLon = _deg2rad(p2.longitude - p1.longitude);

    double a =
        (sin(dLat / 2) * sin(dLat / 2)) +
            cos(_deg2rad(p1.latitude)) * cos(_deg2rad(p2.latitude)) *
                (sin(dLon / 2) * sin(dLon / 2));
    double c = 2 * atan2(sqrt(a), sqrt(1 - a));
    return R * c;
  }

  double _deg2rad(double deg) {
    return deg * (pi / 180);
  }

  Future<bool> _afficherAlerteSuivi() async {
    bool continuer = false;
    await showDialog(
      context: context,
      barrierDismissible: false,
      builder: (context) => AlertDialog(
        title: const Text("Arrivée en gare de départ" ,style: const TextStyle(color: Colors.black87, fontSize: 16, fontWeight: FontWeight.bold),),
        content: const Text("Le train est arrivé à la gare de départ. Voulez-vous continuer à suivre le train ?"),
        actions: [
          TextButton(
            onPressed: () {
              _timer?.cancel();
              Navigator.pushReplacement(
                context,
                MaterialPageRoute(
                  builder: (_) => ListeTrajetsScreen(
                    departure: widget.departure,
                    destination: widget.destination,
                    date: widget.date,
                    message: "Merci de votre confiance. Nous vous souhaitons un agréable voyage !\nEspérons vous revoir très bientôt.", // ou un message personnalisé si tu veux
                  ),
                ),
              );



            },
            child: const Text("Non"),
          ),
          TextButton(
            onPressed: () {
              continuer = true;
              Navigator.of(context).pop();
            },
            child: const Text("Oui"),
          ),
        ],
      ),
    );
    return continuer;
  }

  Future<void> lancerSimulation() async {


    final horaires = widget.trajet.garesIntermediaires
        .where((g) => g.id <= (widget.trajet.idArrivee ?? 999999))
        .map((g) => _parseHeure(g.heurePassage))
        .toList();

    horaires.insert(0, _parseHeure(widget.trajet.heureDepart));
    horaires.add(_parseHeure(widget.trajet.heureArrivee));

    const pointsParSegment = 30;

    bool suivreTrain = true;

// Démarrer à partir de l’index estimé (si défini)
    int startIndex = indexInitialTrain ?? 0;
    int startSegment = startIndex ~/ pointsParSegment;
    int startOffset = startIndex % pointsParSegment;

    for (int i = startSegment; i < horaires.length - 1 && suivreTrain; i++) {
      final dureeSegment = max(1, horaires[i + 1].difference(horaires[i]).inMinutes);
      final totalMs = dureeSegment * 60000;
      final stepMs = totalMs ~/ pointsParSegment;

      int jStart = (i == startSegment) ? startOffset : 0;

      for (int j = jStart; j < pointsParSegment && suivreTrain; j++) {
        await Future.delayed(Duration(milliseconds: stepMs));

        final pathIndex = i * pointsParSegment + j;
        if (pathIndex < fullPath.length) {
          final posTrain = fullPath[pathIndex];
          setState(() {
            currentIndex = pathIndex;
            currentGareIndex = i;
            _trainMarker = _trainMarker?.copyWith(positionParam: posTrain);
          });
          _controller?.animateCamera(CameraUpdate.newLatLng(posTrain));
          final gareProche = _gareProche();
          if (!finTrajetAffichee && gareProche == widget.trajet.gareArrivee) {
            finTrajetAffichee = true;
            await _afficherFinTrajet();
            break; // Facultatif : arrêter la simulation ici
          }

          if (!alerteAffichee && distanceEnMetres(posTrain, gareDepartPos) < 20) {
            alerteAffichee = true;
            suivreTrain = await _afficherAlerteSuivi();
            if (!suivreTrain) break;
          }
        }
      }
    }


    setState(() {
      currentIndex = fullPath.length - 1;
      currentGareIndex = gares.length - 1;
    });
    // ✅ Afficher boîte de fin de trajet
    await _afficherFinTrajet();
  }
  String _formatDuration(Duration duration) {
    String twoDigits(int n) => n.toString().padLeft(2, "0");
    String hours = twoDigits(duration.inHours);
    String minutes = twoDigits(duration.inMinutes.remainder(60));
    String seconds = twoDigits(duration.inSeconds.remainder(60));
    return "$hours:$minutes:$seconds";
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: fullPath.isEmpty
          ? const Center(child: CircularProgressIndicator())
          : Stack(
        children: [


          GoogleMap(
            initialCameraPosition: CameraPosition(target: fullPath.first, zoom: 13),
            onMapCreated: (controller) => _controller = controller,
            markers: {
              if (_trainMarker != null) _trainMarker!,
              ...gares.asMap().entries.map((entry) {
                final index = entry.key;
                final data = entry.value;
                final hue = index <= currentGareIndex
                    ? BitmapDescriptor.hueGreen
                    : BitmapDescriptor.hueYellow;
                return Marker(
                  markerId: MarkerId("gare_$index"),
                  position: data["coord"],
                  infoWindow: InfoWindow(title: data["nom"]),
                  icon: BitmapDescriptor.defaultMarkerWithHue(hue),
                );
              }),
            },
            polylines: {
              Polyline(
                polylineId: const PolylineId("parcourue"),
                points: fullPath.sublist(0, currentIndex.clamp(0, fullPath.length)),
                color: Colors.green,
                width: 5,
              ),
              Polyline(
                polylineId: const PolylineId("restante"),
                points: fullPath.sublist(currentIndex.clamp(0, fullPath.length - 1)),
                color: const Color(0xFFDFD041),
                width: 5,
              ),
            },
          ),
          if (!simulationLancee && _tempsRestant.inSeconds > 0)
            Positioned(
              top: 30,
              left: 20,
              right: 20,
              child: Container(
                padding: const EdgeInsets.all(12),
                decoration: BoxDecoration(
                  color: Colors.white.withOpacity(0.9),
                  borderRadius: BorderRadius.circular(12),
                  boxShadow: [
                    BoxShadow(color: Colors.black26, blurRadius: 4, offset: Offset(0, 2))
                  ],
                ),
                child: Text(
                  "⏳ Chers voyageurs, il vous reste "
                      "${_tempsRestant.inMinutes.remainder(60).toString().padLeft(2, '0')} minutes "
                      "et ${_tempsRestant.inSeconds.remainder(60).toString().padLeft(2, '0')} secondes "
                      "avant que le train démarre.",
                  style: const TextStyle(fontSize: 16, fontWeight: FontWeight.w500),
                  textAlign: TextAlign.center,
                ),
              ),
            ),

          Positioned(
            bottom: 20,
            left: 20,
            right: 20,
            child: Container(
              padding: const EdgeInsets.all(12),
              decoration: BoxDecoration(
                color: Colors.black.withOpacity(0.8),
                borderRadius: BorderRadius.circular(12),
              ),
              child: Text(
                currentGareIndex < gares.length
                    ? "🚉 Étape actuelle : ${gares[currentGareIndex]["nom"]}"
                    : "✅ Trajet terminé",
                style: const TextStyle(color: Colors.white, fontSize: 16, fontWeight: FontWeight.bold),
                textAlign: TextAlign.center,
              ),
            ),
          ),

        ],
      ),
    );
  }
  String _gareProche() {
    if (currentIndex >= fullPath.length) return "";
    final posTrain = fullPath[currentIndex];
    String gareProche = "";
    double minDist = double.infinity;
    for (var g in gares) {
      final dist = distanceEnMetres(posTrain, g["coord"]);
      if (dist < minDist) {
        minDist = dist;
        gareProche = g["nom"];
      }
    }
    return gareProche;
  }
}
