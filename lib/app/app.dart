import 'package:flutter/material.dart';
import 'package:flutter_localizations/flutter_localizations.dart';
import 'package:provider/provider.dart';
import '../features/onboarding/onboarding_page.dart';
import '../features/shell.dart';
import 'l10n.dart';
import 'state.dart';
import 'theme.dart';

/// Root widget: bootstrap the database, decide onboarding vs main shell,
/// apply locale/theme.
class DzBusinessApp extends StatelessWidget {
  const DzBusinessApp({super.key, required this.state});
  final AppState state;

  @override
  Widget build(BuildContext context) {
    return ChangeNotifierProvider<AppState>.value(
      value: state,
      child: Consumer<AppState>(
        builder: (context, st, _) {
          return FutureBuilder<void>(
            future: st.bootstrapDone,
            builder: (context, snap) {
              if (snap.connectionState != ConnectionState.done) {
                return const MaterialApp(
                  home: Scaffold(body: Center(child: CircularProgressIndicator())),
                );
              }
              if (snap.hasError) {
                return MaterialApp(
                  debugShowCheckedModeBanner: false,
                  home: Scaffold(
                    backgroundColor: const Color(0xFFF5F7FC),
                    body: Center(
                      child: Padding(
                        padding: const EdgeInsets.all(32),
                        child: Column(mainAxisSize: MainAxisSize.min, children: [
                          const Icon(Icons.error_outline_rounded, size: 48, color: Color(0xFFEF5261)),
                          const SizedBox(height: 12),
                          const Text('Database error / خطأ في قاعدة البيانات',
                              style: TextStyle(fontWeight: FontWeight.w700, fontSize: 16)),
                          const SizedBox(height: 6),
                          Text('${snap.error}', textAlign: TextAlign.center,
                              style: const TextStyle(fontSize: 12, color: Color(0xFF7B879C))),
                          const SizedBox(height: 16),
                          FilledButton.icon(
                            onPressed: st.retryBootstrap,
                            icon: const Icon(Icons.refresh_rounded),
                            label: const Text('Réessayer / إعادة المحاولة'),
                          ),
                        ]),
                      ),
                    ),
                  ),
                );
              }
              final locale = st.onboardingDone ? st.profile.language : 'fr';
              gLocale = locale;
              gIsArabic = locale == 'ar';
              final theme = buildTheme(locale);
              return MaterialApp(
                title: 'DzBusiness Pro',
                debugShowCheckedModeBanner: false,
                theme: theme,
                locale: Locale(locale),
                supportedLocales: const [Locale('ar'), Locale('fr')],
                localizationsDelegates: const [
                  AppL10n.delegate,
                  GlobalMaterialLocalizations.delegate,
                  GlobalWidgetsLocalizations.delegate,
                  GlobalCupertinoLocalizations.delegate,
                ],
                builder: (context, child) => Directionality(
                  textDirection: locale == 'ar' ? TextDirection.rtl : TextDirection.ltr,
                  child: child ?? const SizedBox.shrink(),
                ),
                home: st.onboardingDone
                    ? HomeShell(state: st)
                    : OnboardingPage(state: st),
              );
            },
          );
        },
      ),
    );
  }
}
