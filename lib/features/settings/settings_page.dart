import 'dart:io';

import 'package:file_selector/file_selector.dart';
import 'package:flutter/material.dart';
import 'package:path/path.dart' as p;
import 'package:provider/provider.dart';
import 'package:sqflite_common_ffi/sqflite_ffi.dart';

import '../../app/l10n.dart';
import '../../app/state.dart';
import '../../app/theme.dart';
import '../../core/ui.dart';
import '../../data/database/app_database.dart';
import '../../data/migrations/migrations.dart';
import '../../data/models/models.dart';
import '../../data/repositories/users_repo.dart';

/// Settings: business profile, options, backup/restore, audit log, about.
class SettingsPage extends StatefulWidget {
  const SettingsPage({super.key});
  @override
  State<SettingsPage> createState() => _SettingsPageState();
}

class _SettingsPageState extends State<SettingsPage> {
  final name = TextEditingController();
  final activity = TextEditingController();
  final address = TextEditingController();
  final phone = TextEditingController();
  final email = TextEditingController();
  final taxRate = TextEditingController();
  final prefix = TextEditingController();
  String language = 'ar';
  String currency = 'DZD';
  String receiptFormat = 'a4';
  bool taxEnabled = false;
  bool negativeStock = false;
  bool autoBackup = false;
  bool loaded = false;
  bool saving = false;
  List<AuditEntry> audit = [];

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    if (!loaded) _load();
  }

  String? loadError;

  Future<void> _load() async {
    final st = context.read<AppState>();
    try {
    final pf = st.profile;
    if (name.text.isEmpty && pf.name.isNotEmpty) {
      name.text = pf.name;
      activity.text = pf.activity;
      address.text = pf.address;
      phone.text = pf.phone;
      email.text = pf.email;
      taxRate.text = '${pf.taxRate}';
      prefix.text = pf.invoicePrefix;
      language = pf.language;
      currency = pf.currency;
      receiptFormat = pf.receiptFormat;
      taxEnabled = pf.taxEnabled;
    }
    final results = await Future.wait([
      st.settings.allowNegativeStock(),
      st.settings.backupOnClose(),
      st.settings.auditLog(limit: 60),
    ]);
    if (!mounted) return;
    setState(() {
      negativeStock = results[0] as bool;
      autoBackup = results[1] as bool;
      audit = results[2] as List<AuditEntry>;
      loaded = true;
      loadError = null;
    });
    } catch (e) {
      if (!mounted) return;
      setState(() { loaded = true; loadError = '$e'; });
    }
  }

  @override
  void dispose() {
    for (final c in [name, activity, address, phone, email, taxRate, prefix]) {
      c.dispose();
    }
    super.dispose();
  }

  Future<void> _save() async {
    final st = context.read<AppState>();
    if (name.text.trim().isEmpty) {
      Toasts.show(context, tr('requiredField'), kind: ToastKind.error);
      return;
    }
    setState(() => saving = true);
    final pf = BusinessProfile(
      name: name.text.trim(),
      activity: activity.text.trim(),
      logoPath: st.profile.logoPath,
      address: address.text.trim(),
      phone: phone.text.trim(),
      email: email.text.trim(),
      language: language,
      currency: currency,
      taxEnabled: taxEnabled,
      taxRate: int.tryParse(taxRate.text) ?? 0,
      receiptFormat: receiptFormat,
      invoicePrefix: prefix.text.trim().isEmpty ? 'F' : prefix.text.trim(),
      createdAt: st.profile.createdAt,
    );
    await st.saveProfile(pf);
    if (!mounted) return;
    setState(() => saving = false);
    Toasts.show(context, tr('success'), kind: ToastKind.success);
  }

  @override
  Widget build(BuildContext context) {
    if (!loaded) return const Center(child: CircularProgressIndicator());
    if (loadError != null) return ErrorStateX(message: loadError!, onRetry: _load);
    return SingleChildScrollView(
      padding: const EdgeInsets.only(bottom: 24),
      child: Column(crossAxisAlignment: CrossAxisAlignment.stretch, children: [
        _profileCard(context),
        const SizedBox(height: 16),
        _optionsCard(context),
        const SizedBox(height: 16),
        _usersCard(context),
        const SizedBox(height: 16),
        _backupCard(context),
        const SizedBox(height: 16),
        _resetCard(context),
        const SizedBox(height: 16),
        _auditCard(context),
        const SizedBox(height: 16),
        _aboutCard(context),
      ]),
    );
  }

  // ---------------------------------------------------------------- profile --
  Widget _profileCard(BuildContext context) {
    final st = context.read<AppState>();
    return HoverCard(
      child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
        FormHeader(title: tr('settings.profile'), subtitle: tr('settings.profileHint')),
        const SizedBox(height: 12),
        Wrap(spacing: 10, runSpacing: 10, children: [
          SizedBox(width: 290, child: FieldX(controller: name, label: tr('businessName'))),
          SizedBox(width: 290, child: FieldX(controller: activity, label: tr('businessActivity'))),
          SizedBox(width: 290, child: FieldX(controller: address, label: tr('address'))),
          SizedBox(width: 290, child: FieldX(controller: phone, label: tr('phone'))),
          SizedBox(width: 290, child: FieldX(controller: email, label: tr('email'))),
          SizedBox(width: 290, child: FieldX(controller: prefix, label: tr('invoicePrefix'))),
        ]),
        const SizedBox(height: 12),
        Wrap(spacing: 10, runSpacing: 10, crossAxisAlignment: WrapCrossAlignment.center, children: [
          SizedBox(
            width: 200,
            child: SmartDropdown<String>(
              label: tr('language'),
              items: const ['ar', 'fr'],
              value: language,
              display: (v) => v == 'ar' ? 'العربية' : 'Français',
              onChanged: (v) => setState(() => language = v ?? language),
            ),
          ),
          SizedBox(
            width: 160,
            child: SmartDropdown<String>(
              label: tr('currency'),
              items: const ['DZD'],
              value: currency,
              display: (v) => v,
              onChanged: (v) => setState(() => currency = v ?? currency),
            ),
          ),
          SizedBox(
            width: 220,
            child: SmartDropdown<String>(
              label: tr('receiptFormat'),
              items: const ['a4', '80', '58'],
              value: receiptFormat,
              display: (v) => tr('receipt.$v'),
              onChanged: (v) => setState(() => receiptFormat = v ?? receiptFormat),
            ),
          ),
          Row(mainAxisSize: MainAxisSize.min, children: [
            Switch(
              value: taxEnabled,
              activeThumbColor: C.primary,
              onChanged: (v) => setState(() => taxEnabled = v),
            ),
            Text(tr('taxEnabled'), style: const TextStyle(fontSize: 12.5)),
          ]),
          if (taxEnabled)
            SizedBox(
              width: 120,
              child: FieldX(controller: taxRate, label: tr('taxRate'), keyboardType: TextInputType.number),
            ),
          if (st.profile.logoPath != null && st.profile.logoPath!.isNotEmpty)
            Row(mainAxisSize: MainAxisSize.min, children: [
              Image.file(File(st.profile.logoPath!), width: 34, height: 34, fit: BoxFit.cover),
              const SizedBox(width: 6),
              Text(tr('logo'), style: const TextStyle(fontSize: 12, color: C.textSecondary)),
            ]),
        ]),
        const SizedBox(height: 16),
        FormFooter(submitLabel: tr('save'), onSubmit: saving ? () {} : _save),
      ]),
    );
  }

  // ---------------------------------------------------------------- options --
  Widget _optionsCard(BuildContext context) {
    final st = context.read<AppState>();
    return HoverCard(
      child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
        FormHeader(title: tr('settings.options'), subtitle: tr('settings.optionsHint')),
        Material(
          type: MaterialType.transparency,
          child: SwitchListTile(
          contentPadding: EdgeInsets.zero,
          title: Text(tr('inv.allowNegative'), style: const TextStyle(fontSize: 13.5, fontWeight: FontWeight.w600)),
          subtitle: Text(tr('inv.allowNegativeWarn'), style: const TextStyle(fontSize: 12, color: C.textSecondary)),
          value: negativeStock,
          activeThumbColor: C.primary,
          onChanged: (v) async {
            await st.settings.setAllowNegativeStock(v);
            setState(() => negativeStock = v);
          },
        ),
        ),
        Material(
          type: MaterialType.transparency,
          child: SwitchListTile(
          contentPadding: EdgeInsets.zero,
          title: Text(tr('settings.autoBackup'), style: const TextStyle(fontSize: 13.5, fontWeight: FontWeight.w600)),
          subtitle: Text(tr('settings.autoBackupHint'), style: const TextStyle(fontSize: 12, color: C.textSecondary)),
          value: autoBackup,
          activeThumbColor: C.primary,
          onChanged: (v) async {
            await st.settings.setBackupOnClose(v);
            setState(() => autoBackup = v);
          },
        ),
        ),
        Padding(
          padding: const EdgeInsetsDirectional.only(start: 8, top: 6),
          child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
            Row(children: [
              const Icon(Icons.format_size_rounded, size: 17, color: C.textSecondary),
              const SizedBox(width: 9),
              Text(tr('settings.fontSize'), style: const TextStyle(fontSize: 13.5, fontWeight: FontWeight.w600)),
              const Spacer(),
              Text('${(st.fontScale * 100).round()}%', style: const TextStyle(fontSize: 12.5, fontWeight: FontWeight.w700, color: C.primary)),
            ]),
            SliderTheme(
              data: SliderTheme.of(context).copyWith(trackHeight: 3.5),
              child: Slider(
                value: st.fontScale.clamp(0.9, 1.3),
                min: 0.9,
                max: 1.3,
                divisions: 8,
                activeColor: C.primary,
                label: '${(st.fontScale * 100).round()}%',
                onChanged: (v) async {
                  await st.setFontScale(v);
                  if (mounted) setState(() {});
                },
              ),
            ),
            Text(tr('settings.fontHint'), style: const TextStyle(fontSize: 11.5, color: C.textSecondary)),
          ]),
        ),
      ]),
    );
  }

  // ------------------------------------------------------------------ users --
  Widget _usersCard(BuildContext context) {
    final st = context.read<AppState>();
    return HoverCard(
      child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
        FormHeader(title: tr('users.title'), subtitle: tr('users.subtitle')),
        FutureBuilder<List<User>>(
          future: st.users.list(),
          builder: (_, snap) {
            if (snap.connectionState == ConnectionState.waiting) {
              return const Padding(
                padding: EdgeInsets.symmetric(vertical: 14),
                child: Center(child: SizedBox(width: 18, height: 18, child: CircularProgressIndicator(strokeWidth: 2))),
              );
            }
            final users = snap.data ?? const <User>[];
            return Column(children: [
              if (users.isEmpty)
                EmptyStateX(
                  title: tr('users.title'),
                  body: tr('users.empty'),
                  icon: Icons.manage_accounts_rounded,
                  action: AppButton(label: tr('users.add'), icon: Icons.person_add_alt_1_rounded, onPressed: () => _addUser(st)),
                ),
              for (final u in users)
                Padding(
                  padding: const EdgeInsets.only(bottom: 8),
                  child: Container(
                    padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 9),
                    decoration: BoxDecoration(
                      color: C.bg,
                      border: Border.all(color: C.border),
                      borderRadius: BorderRadius.circular(11),
                    ),
                    child: Row(children: [
                      CircleAvatar(
                        radius: 15,
                        backgroundColor: C.primary.withValues(alpha: .13),
                        child: Text(u.username.isNotEmpty ? u.username[0].toUpperCase() : '?', style: const TextStyle(fontSize: 13, color: C.primary, fontWeight: FontWeight.w700)),
                      ),
                      const SizedBox(width: 11),
                      Flexible(
                        child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                          Text(u.username, maxLines: 1, overflow: TextOverflow.ellipsis,
                              style: const TextStyle(fontSize: 13, fontWeight: FontWeight.w700)),
                          Text('${tr('role')}: ${tr('role.${u.role}')}', maxLines: 1, overflow: TextOverflow.ellipsis,
                              style: const TextStyle(fontSize: 11.5, color: C.textSecondary)),
                        ]),
                      ),
                      const SizedBox(width: 8),
                      BadgeX(text: u.active ? tr('users.active') : tr('users.inactive'), color: u.active ? C.success : C.textSecondary),
                      const Spacer(),
                      IconButtonX(icon: Icons.grid_view_rounded, tooltip: tr('users.changePin'), onPressed: () => _changePin(st, u)),
                      IconButtonX(icon: Icons.block_rounded, tooltip: u.active ? tr('users.inactive') : tr('users.active'),
                          color: u.active ? C.warning : C.success, onPressed: () async {
                            await st.users.setActive(u.id, !u.active);
                            await st.settings.audit(!u.active ? 'user_activate' : 'user_deactivate', 'users', u.id, u.username);
                            st.changed();
                          }),
                      IconButtonX(icon: Icons.delete_outline_rounded, tooltip: tr('delete'), color: C.danger,
                          onPressed: () async {
                            final ok = await confirmDialog(context,
                                title: tr('users.deleteTitle'), body: '${tr('users.deleteWarn')}\n${u.username}');
                            if (!ok) return;
                            await st.users.delete(u.id);
                            await st.settings.audit('user_delete', 'users', u.id, u.username);
                            st.usersEnabled = await st.users.hasUsers();
                            st.changed();
                          }),
                    ]),
                  ),
                ),
              if (users.isNotEmpty)
                Row(children: [
                  AppButton(label: tr('users.add'), icon: Icons.person_add_alt_1_rounded, onPressed: () => _addUser(st)),
                ]),
            ]);
          },
        ),
        const SizedBox(height: 6),
        Text(tr('users.roleHint'), style: const TextStyle(fontSize: 11.5, color: C.textSecondary)),
      ]),
    );
  }

  Future<void> _addUser(AppState st) async {
    final username = TextEditingController();
    final pin = TextEditingController();
    String role = 'seller';
    final roles = ['manager', 'seller', 'accountant', 'stock'];
    final ok = await formDialog<bool>(
      context,
      title: tr('users.add'),
      width: 440,
      body: (ctx) => StatefulBuilder(builder: (ctx, setD) => Column(mainAxisSize: MainAxisSize.min, children: [
            FieldX(controller: username, label: tr('users.name')),
            const SizedBox(height: 12),
            FieldX(controller: pin, label: tr('users.pin'), obscure: true,
                keyboardType: TextInputType.number,
                onSubmitted: (_) => Navigator.of(ctx).pop(true),
                prefix: const Icon(Icons.password_rounded, size: 18)),
            const SizedBox(height: 10),
            SmartDropdown<String>(
              items: roles,
              value: role,
              display: (r) => tr('role.$r'),
              onChanged: (v) => setD(() => role = v ?? 'seller'),
            ),
            const SizedBox(height: 20),
          ])),
    );
    if (ok != true) return;
    final uname = username.text.trim();
    final pinText = pin.text.trim();
    if (uname.isEmpty || pinText.length < 4 || int.tryParse(pinText) == null) {
      Toasts.show(context, tr('users.pinShort'), kind: ToastKind.error);
      return;
    }
    await st.users.create(username: uname, pin: pinText, role: role);
    await st.settings.audit('user_create', 'users', 0, uname);
    st.usersEnabled = true;
    st.changed();
    if (!mounted) return;
    Toasts.show(context, tr('users.added'), kind: ToastKind.success);
  }

  Future<void> _changePin(AppState st, User u) async {
    final pin = TextEditingController();
    final ok = await formDialog<bool>(
      context,
      title: '${tr('users.changePin')} — ${u.username}',
      width: 400,
      body: (ctx) => Column(mainAxisSize: MainAxisSize.min, children: [
            FieldX(controller: pin, label: tr('users.pin'), obscure: true,
                keyboardType: TextInputType.number,
                onSubmitted: (_) => Navigator.of(ctx).pop(true),
                prefix: const Icon(Icons.password_rounded, size: 18)),
            const SizedBox(height: 20),
          ]),
    );
    if (ok != true) return;
    final pinText = pin.text.trim();
    if (pinText.length < 4 || int.tryParse(pinText) == null) {
      Toasts.show(context, tr('users.pinShort'), kind: ToastKind.error);
      return;
    }
    await st.users.changePin(u.id, pinText);
    await st.settings.audit('user_pin_change', 'users', u.id, u.username);
    if (!mounted) return;
    Toasts.show(context, tr('users.changePin'), kind: ToastKind.success);
  }

  // ------------------------------------------------------------ backup/restore
  String get _backupDir {
    final st = context.read<AppState>();
    return p.join(p.dirname(st.dbPath), 'backups');
  }

  Future<String> _makeBackup(String dbPath, String targetPath) async {
    final dir = Directory(_backupDir);
    if (!dir.existsSync()) dir.createSync(recursive: true);
    await AppDatabase.backupFile(AppDatabase.instance.db, targetPath);
    return targetPath;
  }

  Widget _backupCard(BuildContext context) {
    final st = context.read<AppState>();
    return HoverCard(
      child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
        FormHeader(title: tr('settings.backup'), subtitle: tr('settings.backupHint')),
        const SizedBox(height: 12),
        Wrap(spacing: 10, runSpacing: 10, children: [
          AppButton(
            label: tr('settings.backupNow'),
            icon: Icons.backup_outlined,
            kind: AppButtonKind.primary,
            onPressed: () async {
              try {
                final stamp = DateTime.now().toIso8601String().replaceAll(':', '-').substring(0, 19);
                final target = p.join(_backupDir, 'backup_$stamp.db');
                await _makeBackup(st.dbPath, target);
                await st.settings.audit('backup', 'database', 0, p.basename(target));
                if (mounted) Toasts.show(context, tr('success'), kind: ToastKind.success);
              } catch (e) {
                if (mounted) Toasts.show(context, '${tr('error')}: $e', kind: ToastKind.error);
              }
            },
          ),
          AppButton(
            label: tr('settings.restore'),
            icon: Icons.restore_outlined,
            kind: AppButtonKind.danger,
            onPressed: () => _restore(context, st),
          ),
        ]),
      ]),
    );
  }

  Future<void> _restore(BuildContext context, AppState st) async {
    final typeGroup = const XTypeGroup(label: 'SQLite', extensions: ['db', 'sqlite']);
    final file = await openFile(acceptedTypeGroups: [typeGroup]);
    if (file == null || !mounted) return;
    final backupPath = file.path;

    final okConfirm = await confirmDialog(
      context,
      title: tr('settings.restore'),
      body: tr('settings.restoreWarn'),
      danger: true,
    );
    if (!okConfirm) return;

    try {
      final candidate = await openDatabase(backupPath);
      await Migrations.verifyIntegrity(candidate);
      await candidate.close();

      final safety = AppDatabase.safetyPath(st.dbPath);
      await AppDatabase.backupFile(AppDatabase.instance.db, safety);

      await AppDatabase.instance.close();
      final main = File(st.dbPath);
      if (main.existsSync()) main.deleteSync();
      final wal = File('${st.dbPath}-wal');
      if (wal.existsSync()) wal.deleteSync();
      final shm = File('${st.dbPath}-shm');
      if (shm.existsSync()) shm.deleteSync();
      await File(backupPath).copy(st.dbPath);
      await AppDatabase.instance.open(st.dbPath);
      st.reloadFromDb();
      await st.settings.audit('restore', 'database', 0, p.basename(backupPath));
      if (mounted) Toasts.show(context, tr('success'), kind: ToastKind.success);
    } catch (e) {
      if (mounted) Toasts.show(context, '${tr('error')}: $e', kind: ToastKind.error);
    }
  }

  // ------------------------------------------------------- danger/void zone --
  Widget _resetCard(BuildContext context) {
    final st = context.read<AppState>();
    return HoverCard(
      child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
        FormHeader(title: tr('settings.reset'), subtitle: tr('settings.resetHint')),
        const SizedBox(height: 12),
        Wrap(spacing: 10, runSpacing: 10, children: [
          AppButton(
            label: tr('settings.reset'),
            icon: Icons.delete_forever_rounded,
            kind: AppButtonKind.danger,
            onPressed: () => _factoryReset(context, st),
          ),
        ]),
      ]),
    );
  }

  Future<void> _factoryReset(BuildContext context, AppState st) async {
    final ok = await confirmDialog(context,
      title: tr('settings.reset'),
      body: tr('settings.resetWarn'),
      confirmLabel: tr('delete'),
      danger: true,
    );
    if (!ok || !mounted) return;

    final wantBackup = await confirmDialog(context,
      title: tr('areYouSure'),
      body: tr('settings.resetBackupAsk'),
      confirmLabel: tr('yes'),
      danger: false,
    );
    if (wantBackup) {
      final stamp = DateTime.now().toIso8601String().replaceAll(':', '-').substring(0, 19);
      final location = await getSaveLocation(
        suggestedName: 'dzbp_last_backup_$stamp.db',
        acceptedTypeGroups: [const XTypeGroup(label: 'SQLite', extensions: ['db'])],
      );
      if (location == null || !mounted) return;
      await AppDatabase.backupFile(AppDatabase.instance.db, location.path);
    }

    await st.factoryReset();
  }

  // ------------------------------------------------------------------- audit --
  Widget _auditCard(BuildContext context) {
    return HoverCard(
      child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
        FormHeader(title: tr('settings.audit'), subtitle: tr('settings.auditHint')),
        const SizedBox(height: 10),
        if (audit.isEmpty)
          Padding(
            padding: const EdgeInsets.symmetric(vertical: 12),
            child: Text(tr('settings.auditEmpty'), style: const TextStyle(fontSize: 12.5, color: C.textSecondary)),
          )
        else
          TableX(
            columns: [tr('date'), tr('nav.overview'), tr('type'), tr('notes')],
            widths: [2, 2, 2, 4],
            minHeight: 30,
            rows: [
              for (final a in audit.take(25))
                [
                  Text(a.loggedAt.substring(0, 16).replaceAll('T', ' '), style: const TextStyle(fontSize: 12)),
                  Text(a.action, style: const TextStyle(fontSize: 12, fontWeight: FontWeight.w600, color: C.primary)),
                  Text(a.entity, style: const TextStyle(fontSize: 12)),
                  Text(a.details, style: const TextStyle(fontSize: 12, color: C.textSecondary), overflow: TextOverflow.ellipsis),
                ],
            ],
          ),
      ]),
    );
  }

  // ------------------------------------------------------------------ about --
  Widget _aboutCard(BuildContext context) {
    final st = context.read<AppState>();
    return HoverCard(
      child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
        FormHeader(title: tr('settings.about')),
        const SizedBox(height: 8),
        Text('DzBusiness Pro — 1.0.0', style: const TextStyle(fontSize: 13.5, fontWeight: FontWeight.w700)),
        const SizedBox(height: 6),
        Text('${tr('settings.dbPath')}: ${st.dbPath}', style: const TextStyle(fontSize: 11.5, color: C.textSecondary)),
      ]),
    );
  }
}
