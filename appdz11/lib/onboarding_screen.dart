import 'package:flutter/material.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:animated_text_kit/animated_text_kit.dart';
import 'SignInScreen.dart';
import 'package:flutter_gen/gen_l10n/app_localizations.dart';
import 'package:dztrainfay/locale_provider.dart';
import 'package:provider/provider.dart';

class OnboardingScreen extends StatefulWidget {
  @override
  _OnboardingScreenState createState() => _OnboardingScreenState();
}

class _OnboardingScreenState extends State<OnboardingScreen> {
  PageController _controller = PageController();
  bool isLastPage = false;
  bool _languageDialogShown = false; // Pour ne l'afficher qu'une seule fois

  @override
  Widget build(BuildContext context) {
    final local = AppLocalizations.of(context)!;

    return Scaffold(
      body: Stack(
        children: [
          PageView(
            controller: _controller,
            onPageChanged: (index) {
              setState(() {
                isLastPage = index == 3;
              });
            },
            children: [
              buildLanguageSelectionPage(context),
              buildPage(local.page1Title, local.page1Subtitle, 'assets/images/screen1.png'),
              buildPage(local.page2Title, local.page2Subtitle, 'assets/images/screen2.png'),
              buildPage(local.page3Title, local.page3Subtitle, 'assets/images/screen3.png'),
            ],
          ),
          SafeArea(
            child: Align(
              alignment: Alignment.topRight,
              child: IconButton(
                icon: Icon(Icons.language, color: Colors.white),
                onPressed: () => _showLanguageDialog(context),
              ),
            ),
          ),
          Positioned(
            bottom: 30,
            left: 20,
            right: 20,
            child: isLastPage
                ? ElevatedButton(
              onPressed: () async {
                final prefs = await SharedPreferences.getInstance();
                await prefs.setBool('onboarding_seen', true);
                Navigator.pushReplacement(
                  context,
                  MaterialPageRoute(builder: (_) => SignInScreen()),
                );
              },
              child: Text(local.getStarted),
            )
                : Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                TextButton(
                  onPressed: () => _controller.jumpToPage(3),
                  child: Text(local.skip),
                ),
                FloatingActionButton(
                  onPressed: () {
                    _controller.nextPage(
                      duration: Duration(milliseconds: 500),
                      curve: Curves.ease,
                    );
                  },
                  child: Icon(Icons.arrow_forward),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget buildLanguageSelectionPage(BuildContext context) {
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (!_languageDialogShown && _controller.hasClients && _controller.page == 0) {
        _languageDialogShown = true;
        _showLanguageDialogDirect(context);
      }
    });

    return Container(
      decoration: const BoxDecoration(
        gradient: LinearGradient(
          colors: [
            Color(0xFFA0B1A1),
            Color(0xFFB19EA0),
            Color(0xFF958CAC),



          ],
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
        ),
      ),
      child: const Center(
        child: CircularProgressIndicator(color: Colors.white),
      ),
    );
  }

  void _showLanguageDialog(BuildContext context) {
    final localizations = AppLocalizations.of(context)!;

    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        backgroundColor: Colors.black,
        title: Text(
          localizations.chooseLanguage,
          style: TextStyle(color: Colors.white),
        ),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            _buildLangTile("🇫🇷 Français", const Locale('fr')),
            _buildLangTile("🇬🇧 English", const Locale('en')),
            _buildLangTile("🇩🇿 العربية", const Locale('ar')),
          ],
        ),
      ),
    );
  }

  void _showLanguageDialogDirect(BuildContext context) {
    final localizations = AppLocalizations.of(context)!;

    showDialog(
      context: context,
      barrierDismissible: false,
      builder: (context) => AlertDialog(
        backgroundColor: Colors.black,
        title: Text(
          localizations.chooseLanguage,
          style: TextStyle(color: Colors.white),
        ),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            _buildLangTile("🇫🇷 Français", const Locale('fr'), autoNext: true),
            _buildLangTile("🇬🇧 English", const Locale('en'), autoNext: true),
            _buildLangTile("🇩🇿 العربية", const Locale('ar'), autoNext: true),
          ],
        ),
      ),
    );
  }

  Widget _buildLangTile(String label, Locale locale, {bool autoNext = false}) {
    return ListTile(
      title: Text(label, style: TextStyle(color: Colors.white)),
      onTap: () async {
        Provider.of<LocaleProvider>(context, listen: false).setLocale(locale.languageCode);
        final prefs = await SharedPreferences.getInstance();
        await prefs.setString('language', locale.languageCode);
        Navigator.of(context).pop();
        if (autoNext && _controller.hasClients) {
          _controller.animateToPage(
            1,
            duration: const Duration(milliseconds: 500),
            curve: Curves.ease,
          );
        }
      },
    );
  }


  Widget buildPage(String title, String subtitle, String imagePath) {
    return Stack(
      fit: StackFit.expand,
      children: [
        Container(
          decoration: BoxDecoration(
            image: DecorationImage(
              image: AssetImage(imagePath),
              fit: BoxFit.cover,
            ),
          ),
        ),
        Padding(
          padding: EdgeInsets.symmetric(horizontal: 20),
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            crossAxisAlignment: CrossAxisAlignment.center,
            children: [
              AnimatedTextKit(
                animatedTexts: [
                  TypewriterAnimatedText(
                    title,
                    textStyle: TextStyle(
                      fontSize: 28,
                      fontWeight: FontWeight.bold,
                      color: Colors.white,
                      fontFamily: 'Montserrat',
                    ),
                    speed: Duration(milliseconds: 100),
                  ),
                ],
                totalRepeatCount: 1,
              ),
              SizedBox(height: 15),
              AnimatedTextKit(
                animatedTexts: [
                  ScaleAnimatedText(
                    subtitle,
                    textStyle: TextStyle(
                      fontSize: 18,
                      fontWeight: FontWeight.bold,
                      color: Colors.white,
                      fontFamily: 'Montserrat',
                    ),
                    duration: Duration(seconds: 20),
                  ),
                ],
                totalRepeatCount: 1,
              ),
            ],
          ),
        ),
      ],
    );
  }
}
