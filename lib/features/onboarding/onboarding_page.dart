import 'package:flutter/material.dart';
import '../../app/l10n.dart';
import '../../app/state.dart';
import '../../app/theme.dart';
import '../../core/ui.dart';

/// 4-step first-run wizard. Saves the business profile permanently to SQLite,
/// seeds the initial structure, then opens the main shell.
class OnboardingPage extends StatefulWidget {
  const OnboardingPage({super.key, required this.state});
  final AppState state;

  @override
  State<OnboardingPage> createState() => _OnboardingPageState();
}

class _OnboardingPageState extends State<OnboardingPage> {
  final _name = TextEditingController();
  final _activity = TextEditingController();
  final _address = TextEditingController();
  final _phone = TextEditingController();
  final _email = TextEditingController();
  String language = 'ar';
  String currency = 'DZD';
  String receiptFormat = 'a4';
  bool taxEnabled = false;
  final _taxRate = TextEditingController(text: '19');
  final _prefix = TextEditingController(text: 'F');
  bool saving = false;

  @override
  void dispose() {
    for (final c in [_name, _activity, _address, _phone, _email, _taxRate, _prefix]) {
      c.dispose();
    }
    super.dispose();
  }

  final _formKey = GlobalKey<FormState>();

  Future<void> _finish() async {
    setState(() => saving = true);
    final p = widget.state.profile
      ..name = _name.text.trim()
      ..activity = _activity.text.trim()
      ..address = _address.text.trim()
      ..phone = _phone.text.trim()
      ..email = _email.text.trim()
      ..language = language
      ..currency = currency
      ..receiptFormat = receiptFormat
      ..taxEnabled = taxEnabled
      ..taxRate = int.tryParse(_taxRate.text) ?? 0
      ..invoicePrefix = _prefix.text.trim().isEmpty ? 'F' : _prefix.text.trim();
    await widget.state.completeOnboarding(p);
    if (!mounted) return;
    setState(() => saving = false);
  }

  bool get _canNext => _name.text.trim().isNotEmpty;

  @override
  Widget build(BuildContext context) {
    final steps = [
      (tr('onb.step1'), tr('onb.step1Desc')),
      (tr('onb.step2'), tr('onb.step2Desc')),
      (tr('onb.step3'), tr('onb.step3Desc')),
      (tr('onb.step4'), tr('onb.step4Desc')),
    ];
    return Scaffold(
      backgroundColor: C.bg,
      body: Row(children: [
        // left hero panel
        Container(
          width: 470,
          decoration: const BoxDecoration(gradient: C.gradientPrimary),
          padding: const EdgeInsets.all(48),
          child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
            const SizedBox(height: 36),
            Row(children: [
              Container(
                width: 52, height: 52,
                decoration: BoxDecoration(
                  color: Colors.white.withValues(alpha: .16),
                  borderRadius: BorderRadius.circular(15),
                ),
                child: const Icon(Icons.storefront_rounded, color: Colors.white, size: 27),
              ),
              const SizedBox(width: 14),
              const Expanded(
                child: Text('DzBusiness Pro', style: TextStyle(color: Colors.white, fontSize: 22, fontWeight: FontWeight.w800), maxLines: 1, overflow: TextOverflow.ellipsis),
              ),
            ]),
            const Spacer(),
            Text(tr('onb.welcome'),
                style: const TextStyle(color: Colors.white, fontSize: 34, fontWeight: FontWeight.w800, height: 1.25)),
            const SizedBox(height: 16),
            Text(tr('onb.welcomeDesc'),
                style: TextStyle(color: Colors.white.withValues(alpha: .85), fontSize: 14.5, height: 1.6)),
            const Spacer(),
            ...List.generate(steps.length, (i) {
              final done = i < (_step);
              final active = i == _step;
              return Padding(
                padding: const EdgeInsets.symmetric(vertical: 8),
                child: Row(children: [
                  AnimatedContainer(
                    duration: const Duration(milliseconds: 250),
                    width: 30, height: 30,
                    decoration: BoxDecoration(
                      color: active || done ? Colors.white : Colors.white.withValues(alpha: .14),
                      borderRadius: BorderRadius.circular(9),
                    ),
                    child: Icon(done ? Icons.check : Icons.circle, size: done ? 16 : 5, color: C.primary),
                  ),
                  const SizedBox(width: 12),
                  Expanded(
                    child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                      Text(steps[i].$1,
                          maxLines: 1, overflow: TextOverflow.ellipsis,
                          style: TextStyle(color: Colors.white, fontWeight: active ? FontWeight.w700 : FontWeight.w500, fontSize: 13.5)),
                      Text(steps[i].$2,
                          maxLines: 2, overflow: TextOverflow.ellipsis,
                          style: TextStyle(color: Colors.white.withValues(alpha: .65), fontSize: 11.5)),
                    ]),
                  ),
                ]),
              );
            }),
            const Spacer(),
          ]),
        ),
        // right form
        Expanded(
          child: Form(
            key: _formKey,
            child: Padding(
              padding: const EdgeInsets.symmetric(horizontal: 60, vertical: 40),
              child: AnimatedSwitcher(
                duration: const Duration(milliseconds: 240),
                child: Column(
                  key: ValueKey<int>(_step),
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text('DzBusiness Pro', style: const TextStyle(color: C.textSecondary, fontSize: 12, fontWeight: FontWeight.w700, letterSpacing: 1.5)),
                    const SizedBox(height: 36),
                    if (_step == 0) ..._step1(),
                    if (_step == 1) ..._step2(),
                    if (_step == 2) ..._step3(),
                    if (_step == 3) ..._step4(),
                    const Spacer(),
                    Row(children: [
                      if (_step > 0)
                        AppButton(label: tr('back'), kind: AppButtonKind.ghost, onPressed: () => setState(() => _step--)),
                      const Spacer(),
                      AppButton(
                        label: _step < 3 ? tr('next') : tr('finish'),
                        icon: _step < 3 ? Icons.arrow_forward : Icons.check,
                        onPressed: saving
                            ? null
                            : () {
                                if (_step < 3) {
                                  if (_step == 0 && !_canNext) {
                                    Toasts.show(context, tr('requiredField'), kind: ToastKind.warning);
                                    return;
                                  }
                                  setState(() => _step++);
                                } else {
                                  if (!_canNext) {
                                    Toasts.show(context, tr('requiredField'), kind: ToastKind.warning);
                                    return;
                                  }
                                  _finish();
                                }
                              },
                      ),
                    ]),
                  ],
                ),
              ),
            ),
          ),
        ),
      ]),
    );
  }

  int _step = 0;

  List<Widget> _step1() => [
        Text(tr('onb.step1'), style: const TextStyle(fontSize: 24, fontWeight: FontWeight.w800)),
        const SizedBox(height: 26),
        FieldX(label: tr('businessName'), controller: _name, validator: (v) => (v == null || v.trim().isEmpty) ? tr('requiredField') : null, autofocus: true),
        const SizedBox(height: 16),
        SmartDropdown(
          items: const ['فقط', 'سوبرماركت', 'بوتيك', 'الكترونيات', 'مطعم', 'الطب', 'أخرى', 'Épicerie', 'Boutique', 'Électronique', 'Restaurant', 'Pharmacie', 'Autre'],
          value: _activity.text.isEmpty ? null : _activity.text,
          display: (s) => s,
          onChanged: (v) => setState(() => _activity.text = v ?? ''),
          label: tr('businessActivity'),
          width: 440,
        ),
      ];

  List<Widget> _step2() => [
        Text(tr('onb.step2'), style: const TextStyle(fontSize: 24, fontWeight: FontWeight.w800)),
        const SizedBox(height: 26),
        FieldX(label: tr('address'), controller: _address),
        const SizedBox(height: 16),
        FieldX(label: tr('phone'), controller: _phone, keyboardType: TextInputType.phone),
        const SizedBox(height: 16),
        FieldX(label: tr('email'), controller: _email, keyboardType: TextInputType.emailAddress),
      ];

  List<Widget> _step3() => [
        Text(tr('onb.step3'), style: const TextStyle(fontSize: 24, fontWeight: FontWeight.w800)),
        const SizedBox(height: 26),
        Text(tr('language'), style: const TextStyle(fontSize: 13, fontWeight: FontWeight.w600, color: C.textSecondary)),
        const SizedBox(height: 8),
        SegmentedX<String>(
          options: [('ar', 'العربية'), ('fr', 'Français')],
          selected: language,
          onChanged: (v) => setState(() => language = v),
        ),
        const SizedBox(height: 20),
        Text(tr('currency'), style: const TextStyle(fontSize: 13, fontWeight: FontWeight.w600, color: C.textSecondary)),
        const SizedBox(height: 8),
        SegmentedX<String>(
          options: const [('DZD', 'DZD'), ('EUR', 'EUR')],
          selected: currency,
          onChanged: (v) => setState(() => currency = v),
        ),
      ];

  List<Widget> _step4() => [
        Text(tr('onb.step4'), style: const TextStyle(fontSize: 24, fontWeight: FontWeight.w800)),
        const SizedBox(height: 26),
        FormField<bool>(
          initialValue: taxEnabled,
          builder: (state) => SwitchListTile(
            contentPadding: EdgeInsets.zero,
            title: Text(tr('taxEnabled'), style: const TextStyle(fontSize: 13.5, fontWeight: FontWeight.w600)),
            value: taxEnabled,
            activeThumbColor: C.primary,
            onChanged: (v) { setState(() => taxEnabled = v); state.didChange(v); },
          ),
        ),
        if (taxEnabled) ...[
          const SizedBox(height: 12),
          SizedBox(width: 160, child: FieldX(label: tr('taxRate'), controller: _taxRate, keyboardType: const TextInputType.numberWithOptions(decimal: true)))
        ],
        const SizedBox(height: 20),
        Text(tr('receiptFormat'), style: const TextStyle(fontSize: 13, fontWeight: FontWeight.w600, color: C.textSecondary)),
        const SizedBox(height: 8),
        SegmentedX<String>(
          options: [('a4', tr('receipt.a4')), ('80', tr('receipt.80')), ('58', tr('receipt.58'))],
          selected: receiptFormat,
          onChanged: (v) => setState(() => receiptFormat = v),
        ),
      ];
}
