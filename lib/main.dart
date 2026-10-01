import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:google_fonts/google_fonts.dart';

import 'screens/home_screen.dart';
import 'theme/solo_colors.dart';

void main() {
  WidgetsFlutterBinding.ensureInitialized();
  SystemChrome.setSystemUIOverlayStyle(
    const SystemUiOverlayStyle(
      statusBarColor: Colors.transparent,
      statusBarIconBrightness: Brightness.light,
      systemNavigationBarColor: SoloColors.background,
      systemNavigationBarIconBrightness: Brightness.light,
    ),
  );
  runApp(const DailyQuestApp());
}

class DailyQuestApp extends StatelessWidget {
  const DailyQuestApp({super.key});

  @override
  Widget build(BuildContext context) {
    final base = ThemeData.dark();
    final text = base.textTheme.apply(
      bodyColor: SoloColors.textPrimary,
      displayColor: SoloColors.textPrimary,
    );
    return MaterialApp(
      title: 'Daily Quest',
      debugShowCheckedModeBanner: false,
      theme: ThemeData(
        brightness: Brightness.dark,
        scaffoldBackgroundColor: SoloColors.background,
        colorScheme: const ColorScheme.dark(
          primary: SoloColors.neonBlue,
          secondary: SoloColors.neonCyan,
          surface: SoloColors.surface,
        ),
        fontFamily: GoogleFonts.oswald().fontFamily,
        textTheme: text,
      ),
      home: const HomeScreen(),
    );
  }
}
