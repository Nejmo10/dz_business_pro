import 'dart:convert';

import 'package:flutter/services.dart';

part 'font_data_inter_reg.dart';
part 'font_data_inter_semi.dart';
part 'font_data_inter_bold.dart';
part 'font_data_cairo_reg.dart';
part 'font_data_cairo_semi.dart';
part 'font_data_cairo_bold.dart';

/// Inter and Cairo ship as base64 constants inside these part files, so the
/// repository is plain text only. [FontRegistrar] registers both families
/// with the engine at startup; the PDF/receipt printer reuses Cairo directly.
class FontRegistrar {
  static const Map<String, Map<String, String>> _raw = {
    'Inter': {'reg': kInterReg, 'semi': kInterSemi, 'bold': kInterBold},
    'Cairo': {'reg': kCairoReg, 'semi': kCairoSemi, 'bold': kCairoBold},
  };

  static bool loaded = false;

  static Future<void> loadBuiltInFonts() async {
    if (loaded) return;
    for (final entry in _raw.entries) {
      final loader = FontLoader(entry.key);
      for (final b64 in entry.value.values) {
        loader.addFont(Future.value(_bytes(b64)));
      }
      await loader.load();
    }
    loaded = true;
  }

  static ByteData cairoRegular() => _bytes(kCairoReg);

  static ByteData cairoBold() => _bytes(kCairoBold);

  static ByteData _bytes(String b64) =>
      ByteData.view(Uint8List.fromList(base64Decode(b64)).buffer);
}
