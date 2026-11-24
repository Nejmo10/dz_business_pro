import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

import '../../app/l10n.dart';
import '../../app/state.dart';
import '../../app/theme.dart';
import '../../core/ui.dart';

/// PIN login gate shown at startup when at least one user account exists.
/// Failed attempts are logged by [UsersRepo.verify].
class LoginPage extends StatefulWidget {
  const LoginPage({super.key, required this.state});
  final AppState state;

  @override
  State<LoginPage> createState() => _LoginPageState();
}

class _LoginPageState extends State<LoginPage> {
  final _username = TextEditingController();
  final _pin = TextEditingController();
  String? error;
  bool busy = false;

  Future<void> _login() async {
    if (busy) return;
    setState(() { busy = true; error = null; });
    final u = await widget.state.users.verify(_username.text, _pin.text);
    if (!mounted) return;
    if (u == null) {
      setState(() { busy = false; error = tr('login.failed'); });
      return;
    }
    widget.state.startSession(u);
  }

  @override
  Widget build(BuildContext context) {
    final width = MediaQuery.of(context).size.width;
    final narrow = width < 700;
    final hero = Container(
      padding: const EdgeInsets.all(40),
      decoration: const BoxDecoration(gradient: C.gradientPrimary),
      child: Column(mainAxisAlignment: MainAxisAlignment.center, crossAxisAlignment: CrossAxisAlignment.start, children: [
        Text(tr('app.title'),
            style: const TextStyle(fontSize: 30, fontWeight: FontWeight.w800, color: Colors.white)),
        const SizedBox(height: 8),
        Text(tr('app.tagline'),
            style: TextStyle(fontSize: 14, color: Colors.white.withValues(alpha: .85))),
        const SizedBox(height: 26),
        Text(tr('users.roleHint'),
            style: TextStyle(fontSize: 12, color: Colors.white.withValues(alpha: .7))),
      ]),
    );
    final form = SingleChildScrollView(
      padding: const EdgeInsets.all(40),
      child: Column(crossAxisAlignment: CrossAxisAlignment.stretch, children: [
        Text(tr('login.title'),
            style: const TextStyle(fontSize: 21, fontWeight: FontWeight.w800, color: C.textPrimary)),
        const SizedBox(height: 20),
        FieldX(controller: _username, label: tr('users.name'), autofocus: true, onSubmitted: (_) => _login()),
        const SizedBox(height: 12),
        FieldX(
          controller: _pin,
          label: tr('users.pin'),
          obscure: true,
          keyboardType: TextInputType.number,
          inputFormatters: [FilteringTextInputFormatter.digitsOnly],
          onSubmitted: (_) => _login(),
        ),
        if (error != null) ...[
          const SizedBox(height: 10),
          Container(
            padding: const EdgeInsets.all(10),
            decoration: BoxDecoration(color: C.danger.withValues(alpha: .08), borderRadius: BorderRadius.circular(8)),
            child: Row(children: [
              const Icon(Icons.lock_outline, size: 16, color: C.danger),
              const SizedBox(width: 8),
              Flexible(child: Text(error!, style: const TextStyle(fontSize: 12, color: C.danger))),
            ]),
          ),
        ],
        const SizedBox(height: 20),
        AppButton(
          label: tr('login.loginBtn'),
          icon: Icons.login_rounded,
          width: double.infinity,
          onPressed: busy ? null : _login,
        ),
      ]),
    );
    return Scaffold(
      backgroundColor: C.bg,
      body: narrow
          ? Center(child: ConstrainedBox(
              constraints: const BoxConstraints(maxWidth: 440),
              child: Card(child: form)))
          : Row(children: [
              SizedBox(width: 420, child: hero),
              Expanded(
                child: Center(
                  child: ConstrainedBox(
                    constraints: const BoxConstraints(maxWidth: 460),
                    child: Card(child: form),
                  ),
                ),
              ),
            ]),
    );
  }
}
