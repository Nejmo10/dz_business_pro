import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'app/app.dart';
import 'app/state.dart';
import 'core/fonts/font_assets.dart';

Future<void> main() async {
  WidgetsFlutterBinding.ensureInitialized();
  await FontRegistrar.loadBuiltInFonts();
  final state = AppState();
  runApp(
    MultiProvider(
      providers: [
        ChangeNotifierProvider<AppState>.value(value: state),
      ],
      child: DzBusinessApp(state: state),
    ),
  );
}
