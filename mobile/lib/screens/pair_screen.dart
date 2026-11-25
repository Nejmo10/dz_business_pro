import 'package:flutter/material.dart';

import '../api.dart';
import '../l10n.dart';
import '../main.dart' show DzMobileApp;
import '../store.dart';
import '../ui_kit.dart';
import 'home_screen.dart';

/// First screen: pair with the desktop server (host + 6-digit pairing code).
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

  Future<void> _connect() async {
    setState(() { busy = true; error = null; });
    final h = host.text.trim().replaceAll('http://', '');
    final c = code.text.trim();
    if (h.isEmpty || !RegExp(r'^\d{6}$').hasMatch(c)) {
      setState(() { busy = false; error = t('pair.fail'); });
      return;
    }
    final api = ApiClient(baseUrl: 'http://$h', token: c);
    try {
      final st = await api.status();
      if (st['ok'] != true) throw ApiError('bad', t('pair.fail'));
      await Store.save(h, c);
      if (!mounted) return;
      Navigator.of(context).pushReplacement(MaterialPageRoute<void>(builder: (_) => const HomeScreen()));
    } on ApiError catch (e) {
      if (!mounted) return;
      setState(() { busy = false; error = e.message(gAr); });
    } catch (_) {
      if (!mounted) return;
      setState(() { busy = false; error = t('pair.fail'); });
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: Text(t('app'), style: const TextStyle(fontWeight: FontWeight.w800, color: C.textPrimary)),
        actions: [
          TextButton(
            onPressed: () async {
              final nav = Navigator.of(context);
              gAr = !gAr;
              await Store.saveLanguage(gAr);
              if (!mounted) return;
              nav.pushReplacement(MaterialPageRoute<void>(builder: (_) => const DzMobileApp()));
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
              Icon(Icons.storefront_rounded, size: 60, color: C.primary.withValues(alpha: .8)),
              const SizedBox(height: 10),
              Text(t('pair.title'), textAlign: TextAlign.center,
                  style: const TextStyle(fontSize: 19, fontWeight: FontWeight.w800, color: C.textPrimary)),
              const SizedBox(height: 10),
              Text(t('pair.desc'), textAlign: TextAlign.center,
                  style: const TextStyle(fontSize: 12, color: C.textSecondary, height: 1.6)),
              const SizedBox(height: 22),
              MCard(
                child: Column(children: [
                  TextFormField(controller: host, keyboardType: TextInputType.url,
                      decoration: InputDecoration(labelText: t('pair.host'))),
                  const SizedBox(height: 12),
                  TextFormField(controller: code, keyboardType: TextInputType.number, maxLength: 6,
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
                            onPressed: _connect,
                            icon: const Icon(Icons.link_rounded),
                            label: Text(t('pair.connect'),
                                style: const TextStyle(fontWeight: FontWeight.w800)),
                          ),
                  ),
                ]),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
