import 'dart:async';
import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'CreatePasswordScreen.dart';
import 'package:flutter_gen/gen_l10n/app_localizations.dart';

class VerifyEmailScreen extends StatefulWidget {
  final String verificationCode;
  final String email;

  VerifyEmailScreen({required this.verificationCode, required this.email});

  @override
  _VerifyEmailScreenState createState() => _VerifyEmailScreenState();
}

class _VerifyEmailScreenState extends State<VerifyEmailScreen> {
  final TextEditingController codeController = TextEditingController();
  bool isLoading = false;

  String fullMessage = "";
  String displayedMessage = "";
  int _charIndex = 0;
  Timer? _typingTimer;

  @override
  void initState() {
    super.initState();
    // On attend que le widget soit monté avant d'accéder à context
    WidgetsBinding.instance.addPostFrameCallback((_) {
      setState(() {
        fullMessage = AppLocalizations.of(context)!.checkSpamMessage;
      });
      startTypingEffect();
    });
  }

  void startTypingEffect() {
    _typingTimer = Timer.periodic(const Duration(milliseconds: 50), (timer) {
      if (_charIndex < fullMessage.length) {
        setState(() {
          displayedMessage += fullMessage[_charIndex];
          _charIndex++;
        });
      } else {
        _typingTimer?.cancel();
      }
    });
  }

  @override
  void dispose() {
    _typingTimer?.cancel();
    codeController.dispose();
    super.dispose();
  }

  Future<void> verifyCode() async {
    setState(() {
      isLoading = true;
    });

    try {
      DocumentSnapshot doc = await FirebaseFirestore.instance
          .collection('PasswordResetCodes')
          .doc(widget.email)
          .get();

      if (doc.exists) {
        String savedCode = doc['code'];

        if (savedCode == codeController.text.trim()) {
          Navigator.pushReplacement(
            context,
            MaterialPageRoute(
              builder: (context) => CreatePasswordScreen(email: widget.email),
            ),
          );
        } else {
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(content: Text(AppLocalizations.of(context)!.invalidCode)),
          );
        }
      } else {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text(AppLocalizations.of(context)!.codeNotFound)),
        );
      }
    } catch (e) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
            content: Text(
                "${AppLocalizations.of(context)!.error} : ${e.toString()}")),
      );
    } finally {
      setState(() {
        isLoading = false;
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    final local = AppLocalizations.of(context)!;

    return Scaffold(
      appBar: AppBar(
        title: Text(
          local.verificationTitle,
          style: const TextStyle(fontSize: 24, color: Colors.black87),
        ),
        backgroundColor: const Color(0xFF5677A3),
        elevation: 0,
      ),
      body: Container(
        width: double.infinity,
        height: double.infinity,
        decoration: const BoxDecoration(
          gradient: LinearGradient(
            begin: Alignment.topCenter,
            end: Alignment.bottomCenter,
            colors: [
              Color(0xFFA3BED8),
              Color(0xFFD1D9E6),
              Color(0xFFF0F4F8),
            ],
          ),
        ),
        child: SingleChildScrollView(
          padding: const EdgeInsets.all(20.0),
          child: Column(
            children: [
              const SizedBox(height: 50),
              const Icon(Icons.verified_user_rounded,
                  size: 80, color: Colors.black87),
              const SizedBox(height: 20),
              Text(
                local.verifyYourEmail,
                style: const TextStyle(
                  fontSize: 24,
                  fontWeight: FontWeight.w700,
                  color: Colors.black87,
                ),
              ),
              const SizedBox(height: 15),
              Text(
                local.codeSentTo,
                style: const TextStyle(fontSize: 16, color: Colors.black87),
                textAlign: TextAlign.center,
              ),
              const SizedBox(height: 5),
              Text(
                widget.email,
                style: const TextStyle(
                  fontSize: 18,
                  fontWeight: FontWeight.bold,
                  color: Color(0xFF425B78),
                ),
                textAlign: TextAlign.center,
              ),
              const SizedBox(height: 30),
              TextField(
                controller: codeController,
                keyboardType: TextInputType.number,
                style: const TextStyle(color: Colors.black),
                decoration: InputDecoration(
                  labelText: local.enterVerificationCode,
                  labelStyle: const TextStyle(color: Colors.black),
                  prefixIcon: const Icon(Icons.pin, color: Colors.black54),
                  border: OutlineInputBorder(
                    borderRadius: BorderRadius.circular(12),
                  ),
                  enabledBorder: OutlineInputBorder(
                    borderRadius: BorderRadius.circular(12),
                    borderSide: const BorderSide(color: Colors.black26),
                  ),
                  focusedBorder: OutlineInputBorder(
                    borderRadius: BorderRadius.circular(12),
                    borderSide: const BorderSide(color: Color(0x998BB1FF)),
                  ),
                  filled: true,
                  fillColor: Colors.white.withOpacity(0.95),
                ),
              ),
              const SizedBox(height: 30),
              isLoading
                  ? const CircularProgressIndicator()
                  : ElevatedButton.icon(
                onPressed: verifyCode,
                icon: const Icon(Icons.verified, color: Colors.white),
                label: Text(
                  local.verify,
                  style: const TextStyle(
                      fontSize: 16, fontWeight: FontWeight.bold),
                ),
                style: ElevatedButton.styleFrom(
                  backgroundColor: const Color(0xFF5677A3),
                  foregroundColor: Colors.black87,
                  padding: const EdgeInsets.symmetric(
                      horizontal: 40, vertical: 14),
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(30),
                  ),
                  elevation: 5,
                ),
              ),
              const SizedBox(height: 30),
              Text(
                displayedMessage,
                style: const TextStyle(
                  fontSize: 14,
                  color: Colors.black87,
                  fontWeight: FontWeight.w500,
                ),
                textAlign: TextAlign.center,
              ),
            ],
          ),
        ),
      ),
    );
  }
}
