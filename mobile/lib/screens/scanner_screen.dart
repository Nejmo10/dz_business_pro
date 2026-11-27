import 'package:flutter/material.dart';
import 'package:mobile_scanner/mobile_scanner.dart';

import '../l10n.dart';

/// Full-screen QR scanner with a rounded viewfinder cut-out.
/// Pops with the raw string of the first detected QR code.
class ScannerScreen extends StatefulWidget {
  const ScannerScreen({super.key});

  @override
  State<ScannerScreen> createState() => _ScannerScreenState();
}

class _ScannerScreenState extends State<ScannerScreen> {
  final _controller = MobileScannerController(
    formats: const [BarcodeFormat.qrCode],
    torchEnabled: false,
  );
  bool _done = false;

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  void _onDetect(BarcodeCapture capture) {
    if (_done) return;
    for (final b in capture.barcodes) {
      final raw = b.rawValue;
      if (raw != null && raw.isNotEmpty) {
        _done = true;
        Navigator.of(context).pop(raw);
        return;
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.black,
      appBar: AppBar(
        backgroundColor: Colors.transparent,
        foregroundColor: Colors.white,
        title: Text(t('scan.title'),
            style: const TextStyle(fontWeight: FontWeight.w800, color: Colors.white)),
        actions: [
          IconButton(
            tooltip: 'torch',
            icon: const Icon(Icons.flashlight_on_rounded, color: Colors.white),
            onPressed: () => _controller.toggleTorch(),
          ),
        ],
      ),
      body: Stack(children: [
        MobileScanner(controller: _controller, onDetect: _onDetect),
        CustomPaint(painter: _Viewfinder(), child: const SizedBox.expand()),
        Align(
          alignment: Alignment.bottomCenter,
          child: SafeArea(
            child: Padding(
              padding: const EdgeInsets.only(bottom: 26, left: 24, right: 24),
              child: Container(
                padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 10),
                decoration: BoxDecoration(
                  color: Colors.black.withValues(alpha: .45),
                  borderRadius: BorderRadius.circular(24),
                ),
                child: Text(t('scan.hint'),
                    textAlign: TextAlign.center,
                    style: const TextStyle(color: Colors.white, fontSize: 12.5)),
              ),
            ),
          ),
        ),
      ]),
    );
  }
}

class _Viewfinder extends CustomPainter {
  @override
  void paint(Canvas canvas, Size size) {
    final side = size.shortestSide * .68;
    final rect = Rect.fromCenter(
        center: Offset(size.width / 2, size.height / 2 - size.height * .04),
        width: side, height: side);
    final rrect = RRect.fromRectAndRadius(rect, const Radius.circular(26));

    final scrim = Paint()..color = Colors.black.withValues(alpha: .55);
    final full = Path()..addRect(Offset.zero & size);
    final hole = Path()..addRRect(rrect);
    canvas.drawPath(
        Path.combine(PathOperation.difference, full, hole), scrim);

    final frame = Paint()
      ..style = PaintingStyle.stroke
      ..strokeWidth = 4.5
      ..shader = const LinearGradient(colors: [
        Color(0xFF3867F4), Color(0xFF7357E8),
      ]).createShader(rect);
    canvas.drawRRect(rrect, frame);
  }

  @override
  bool shouldRepaint(covariant CustomPainter oldDelegate) => false;
}
