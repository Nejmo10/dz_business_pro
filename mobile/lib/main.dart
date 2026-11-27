import 'package:flutter/material.dart';

import 'l10n.dart';
import 'screens/home_screen.dart';
import 'screens/pair_screen.dart';
import 'store.dart';
import 'ui_kit.dart';

Future<void> main() async {
  WidgetsFlutterBinding.ensureInitialized();
  await Store.load();
  runApp(const DzMobileApp());
}

class DzMobileApp extends StatelessWidget {
  const DzMobileApp({super.key});

  @override
  Widget build(BuildContext context) {
    final hasPairing = Store.host != null && Store.token != null;
    return MaterialApp(
      title: 'DzBusiness Pro Mobile',
      debugShowCheckedModeBanner: false,
      theme: ThemeData(
        useMaterial3: true,
        scaffoldBackgroundColor: C.bg,
        colorScheme: ColorScheme.fromSeed(seedColor: C.primary),
        appBarTheme: const AppBarTheme(
          backgroundColor: C.bg,
          surfaceTintColor: Colors.transparent,
          elevation: 0,
          centerTitle: false,
        ),
        navigationBarTheme: NavigationBarThemeData(
          backgroundColor: C.surface,
          indicatorColor: C.primary.withValues(alpha: .13),
          labelTextStyle: WidgetStateProperty.all(const TextStyle(
              fontSize: 11.5, fontWeight: FontWeight.w700, color: C.textPrimary)),
        ),
        inputDecorationTheme: InputDecorationTheme(
          filled: true,
          fillColor: C.surface,
          contentPadding: const EdgeInsets.symmetric(horizontal: 14, vertical: 13),
          border: OutlineInputBorder(
              borderRadius: BorderRadius.circular(12),
              borderSide: const BorderSide(color: C.border)),
          enabledBorder: OutlineInputBorder(
              borderRadius: BorderRadius.circular(12),
              borderSide: const BorderSide(color: C.border)),
          focusedBorder: OutlineInputBorder(
              borderRadius: BorderRadius.circular(12),
              borderSide: const BorderSide(color: C.primary, width: 1.6)),
          labelStyle: const TextStyle(color: C.textSecondary, fontSize: 13),
        ),
      ),
      locale: Locale(gAr ? 'ar' : 'fr'),
      supportedLocales: const [Locale('ar'), Locale('fr')],
      builder: (context, child) => Directionality(
        textDirection: gAr ? TextDirection.rtl : TextDirection.ltr,
        child: child ?? const SizedBox.shrink(),
      ),
      home: hasPairing ? const HomeScreen() : const PairScreen(),
    );
  }
}
