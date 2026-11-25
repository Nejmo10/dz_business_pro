import 'package:flutter/material.dart';

import '../api.dart';
import '../l10n.dart';
import '../main.dart' show DzMobileApp;
import '../pair_link.dart';
import '../store.dart';
import '../ui_kit.dart';
import 'home_screen.dart';
import 'scanner_screen.dart';

/// First screen: pair with the desktop server.
/// Scan-first (QR from the desktop), manual entry stays available.
class PairScreen extends StatefulWidget {
  const PairScreen({super.key});

  @override
  State<PairScreen> createState() => _PairScreenState();
}

class _PairScreenState extends State<PairScreen> {
  final host = TextEditingController();
  final code = TextEditingController();
  bool busy = false;
  String? error;
  String? scannedBusiness;

  Future<void> _connect(List<String> hosts, String token,
      {String? businessHint}) async {
    if (busy) return;
    final tried = [
      if (hosts.isEmpty) host.text.trim().replaceAll(RegExp(r'^https?://'), ''),
      ...hosts,
    ].where((h) => h.isNotEmpty).toList();
    if (tried.isEmpty) {
      setState(() => error = t('pair.fail'));
      return;
    }
    setState(() { busy = true; error = null; });
    for (final h in tried) {
      final api = ApiClient(baseUrl: 'http://$h', token: token);
      try {
        final st = await api.status();
        if (st['ok'] != true) throw const ApiError('bad', 'bad');
        await Store.save(h, token);
        if (!mounted) return;
        Navigator.of(context).pushReplacement(
            MaterialPageRoute<void>(builder: (_) => const HomeScreen()));
        return;
      } on ApiError catch (e) {
        if (e.code == 'unauthorized') {
          if (!mounted) return;
          setState(() { busy = false; error = e.message(gAr); });
          return;
        }
      } catch (_) {
        // try the next candidate host
      }
    }
    if (!mounted) return;
    setState(() {
      busy = false;
      error = businessHint == null ? t('pair.fail') : t('pair.unreachable');
    });
  }

  Future<void> _scan() async {
    error = null;
    final raw = await Navigator.of(context).push<String>(
      MaterialPageRoute<String>(builder: (_) => const ScannerScreen()),
    );
    if (raw == null) return;
    final link = PairLink.tryParse(raw);
    if (link == null) {
      setState(() => error = t('scan.bad'));
      return;
    }
    if (link.hosts.isEmpty) {
      // Bare token: keep the typed host, just fill the code.
      setState(() { code.text = link.token; scannedBusiness = null; });
      return;
    }
    setState(() {
      code.text = link.token;
      host.text = link.hosts.first;
      scannedBusiness =
          (link.business.isNotEmpty ? link.business : null) ?? scannedBusiness;
    });
    await _connect(link.hosts, link.token, businessHint: link.business);
  }

  Future<void> _manualConnect() => _connect([], code.text.trim());

  bool get _codeValid => RegExp(r'^\d{6}$').hasMatch(code.text.trim());

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: Text(t('app'), style: const TextStyle(
            fontWeight: FontWeight.w800, color: C.textPrimary)),
        actions: [
          TextButton(
            onPressed: () async {
              final nav = Navigator.of(context);
              gAr = !gAr;
              await Store.saveLanguage(gAr);
              if (!mounted) return;
              nav.pushReplacement(
                  MaterialPageRoute<void>(builder: (_) => const DzMobileApp()));
            },
            child: Text(t('lang'), style: const TextStyle(fontWeight: FontWeight.w800)),
          ),
        ],
      ),
      body: Center(
        child: SingleChildScrollView(
          padding: const EdgeInsets.all(20),
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              TweenAnimationBuilder<double>(
                tween: Tween(begin: .0, end: 1),
                duration: const Duration(milliseconds: 550),
                curve: Curves.easeOutBack,
                builder: (context, v, child) => Transform.scale(
                  scale: v,
                  child: Opacity(opacity: v.clamp(0, 1), child: child),
                ),
                child: Container(
                  width: 84, height: 84,
                  alignment: Alignment.center,
                  decoration: const BoxDecoration(
                    gradient: LinearGradient(
                        begin: Alignment.topLeft, end: Alignment.bottomRight,
                        colors: [C.primary, C.secondary]),
                    borderRadius: BorderRadius.all(Radius.circular(24)),
                  ),
                  child: const Icon(Icons.storefront_rounded,
                      size: 42, color: Colors.white),
                ),
              ),
              const SizedBox(height: 10),
              if ((scannedBusiness ?? '').isNotEmpty) ...[
                Text(scannedBusiness!, textAlign: TextAlign.center,
                    style: const TextStyle(fontSize: 13, fontWeight: FontWeight.w800, color: C.secondary)),
                const SizedBox(height: 6),
              ],
              Text(t('pair.title'), textAlign: TextAlign.center,
                  style: const TextStyle(fontSize: 19, fontWeight: FontWeight.w800, color: C.textPrimary)),
              const SizedBox(height: 10),
              Text(t('pair.desc'), textAlign: TextAlign.center,
                  style: const TextStyle(fontSize: 12, color: C.textSecondary, height: 1.6)),
              const SizedBox(height: 22),
              _ScanButton(onPressed: _scan, label: t('pair.scan')),
              const SizedBox(height: 14),
              Theme(
                data: Theme.of(context).copyWith(dividerColor: Colors.transparent),
                child: ExpansionTile(
                  initiallyExpanded: false,
                  shape: const Border(),
                  title: Text(t('pair.manual'),
                      style: const TextStyle(fontSize: 13, fontWeight: FontWeight.w700, color: C.textSecondary)),
                  leading: const Icon(Icons.keyboard_alt_outlined, size: 19, color: C.textSecondary),
                  tilePadding: const EdgeInsets.symmetric(horizontal: 4),
                  children: [
                    Form(
                      child: Column(children: [
                        TextFormField(controller: host, keyboardType: TextInputType.url,
                            decoration: InputDecoration(labelText: t('pair.host'))),
                        const SizedBox(height: 12),
                        TextFormField(controller: code, keyboardType: TextInputType.number, maxLength: 6,
                            onChanged: (_) => setState(() {}),
                            decoration: InputDecoration(labelText: t('pair.code'), counterText: '')),
                        if (error != null) ...[
                          const SizedBox(height: 8),
                          Text(error!, style: const TextStyle(color: C.danger, fontSize: 12)),
                        ],
                        const SizedBox(height: 16),
                        SizedBox(
                          width: double.infinity,
                          height: 46,
                          child: busy
                              ? const Center(child: SizedBox(width: 22, height: 22,
                                  child: CircularProgressIndicator(strokeWidth: 2.4)))
                              : FilledButton.icon(
                                  style: FilledButton.styleFrom(backgroundColor: C.primary),
                                  onPressed: _codeValid ? _manualConnect : null,
                                  icon: const Icon(Icons.link_rounded),
                                  label: Text(t('pair.connect'),
                                      style: const TextStyle(fontWeight: FontWeight.w800)),
                                ),
                        ),
                        const SizedBox(height: 8),
                      ]),
                    ),
                  ],
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

/// Gradient, press-responsive call-to-action for scanning.
class _ScanButton extends StatelessWidget {
  const _ScanButton({required this.onPressed, required this.label});

  final VoidCallback onPressed;
  final String label;

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: onPressed,
      child: AnimatedScale(
        scale: 1,
        duration: const Duration(milliseconds: 120),
        child: DecoratedBox(
          decoration: BoxDecoration(
            gradient: const LinearGradient(
                begin: Alignment.topLeft, end: Alignment.bottomRight,
                colors: [C.primary, C.secondary]),
            borderRadius: BorderRadius.circular(14),
            boxShadow: [
              BoxShadow(
                color: C.primary.withValues(alpha: .32),
                blurRadius: 16,
                offset: const Offset(0, 6),
              ),
            ],
          ),
          child: SizedBox(
            height: 52,
            child: Row(mainAxisAlignment: MainAxisAlignment.center, children: [
              const Icon(Icons.qr_code_scanner_rounded, color: Colors.white),
              const SizedBox(width: 10),
              Text(label, style: const TextStyle(
                  color: Colors.white, fontSize: 15, fontWeight: FontWeight.w800)),
            ]),
          ),
        ),
      ),
    );
  }
}
