import 'package:flutter/material.dart';
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
                localizationsDelegates: const [AppL10n.delegate],
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
