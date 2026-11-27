import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../../app/l10n.dart';
import '../../app/state.dart';
import '../../app/theme.dart';
import '../../core/ui.dart';
import '../../data/models/models.dart';

/// Categories and brands manager.
class CategoriesPage extends StatefulWidget {
  const CategoriesPage({super.key});
  @override
  State<CategoriesPage> createState() => _CategoriesPageState();
}

class _CategoriesPageState extends State<CategoriesPage> {
  bool brandsTab = false;
  bool loading = true;
  String? loadError;
  List<Category> categories = [];
  List<Brand> brands = [];

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    if (loading) _reload();
  }

  Future<void> _reload() async {
    final st = context.read<AppState>();
    try {
      final res = await Future.wait([st.catalog.categories(), st.catalog.brands()]);
      if (!mounted) return;
      setState(() {
        categories = res[0] as List<Category>;
        brands = res[1] as List<Brand>;
        loading = false;
        loadError = null;
      });
    } catch (e) {
      if (!mounted) return;
      setState(() { loading = false; loadError = '$e'; });
    }
  }

  @override
  Widget build(BuildContext context) {
    final items = brandsTab
        ? [for (final b in brands) (b.id, b.nameAr, b.nameFr, b.count)]
        : [for (final c in categories) (c.id, c.nameAr, c.nameFr, c.count)];
    return Column(crossAxisAlignment: CrossAxisAlignment.stretch, children: [
      Row(children: [
        SegmentedX<bool>(options: [(false, tr('category')), (true, tr('brand'))],
            selected: brandsTab, onChanged: (v) => setState(() => brandsTab = v)),
        const Spacer(),
        AppButton(label: tr('add'), icon: Icons.add, onPressed: () => _add(context)),
      ]),
      const SizedBox(height: 14),
      Expanded(
        child: loading
            ? const Center(child: CircularProgressIndicator())
            : loadError != null
                ? ErrorStateX(message: loadError!, onRetry: _reload)
                : items.isEmpty
                ? EmptyStateX(title: tr('none'), body: tr('cats.emptyHint'), icon: Icons.category_outlined)
                : TableX(
                    columns: [tr('name'), tr('qty'), tr('actions')],
                    widths: [4, 1, 1],
                    rows: [
                      for (final (id, nameAr, nameFr, count) in items)
                        [
                          Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                            Text(nameFr, style: const TextStyle(fontSize: 13, fontWeight: FontWeight.w600)),
                            Text(nameAr, style: const TextStyle(fontSize: 11.5, color: C.textSecondary)),
                          ]),
                          Text('$count', style: const TextStyle(fontSize: 13)),
                          Row(children: [
                            IconButtonX(icon: Icons.edit_outlined, size: 30, tooltip: tr('edit'),
                                onPressed: () => _rename(context, id, nameAr, nameFr)),
                            IconButtonX(icon: Icons.delete_outline, size: 30, color: C.danger, tooltip: tr('delete'),
                                onPressed: () => _remove(context, id)),
                          ]),
                        ],
                    ],
                  ),
      ),
    ]);
  }

  Future<void> _add(BuildContext context) async {
    final c1 = TextEditingController(); final c2 = TextEditingController();
    await formDialog<void>(context, width: 420, title: brandsTab ? tr('brand') : tr('category'), body: (ctx) => Column(mainAxisSize: MainAxisSize.min, children: [
      Padding(
        padding: const EdgeInsets.fromLTRB(22, 16, 22, 0),
        child: Column(children: [
          FieldX(controller: c2, label: '${tr('name')} (FR)'),
          const SizedBox(height: 10),
          FieldX(controller: c1, label: '${tr('name')} (AR)'),
        ]),
      ),
      const SizedBox(height: 16),
      FormFooter(onSubmit: () async {
        if (c2.text.trim().isEmpty && c1.text.trim().isEmpty) return;
        final st = context.read<AppState>();
        if (brandsTab) {
          await st.catalog.addBrand(c1.text.trim(), c2.text.trim());
        } else {
          await st.catalog.addCategory(c1.text.trim(), c2.text.trim());
        }
        if (ctx.mounted) Navigator.pop(ctx);
        _reload();
      }),
    ]));
  }

  Future<void> _rename(BuildContext context, int id, String nameAr, String nameFr) async {
    final c1 = TextEditingController(text: nameAr); final c2 = TextEditingController(text: nameFr);
    await formDialog<void>(context, width: 420, title: tr('edit'), body: (ctx) => Column(mainAxisSize: MainAxisSize.min, children: [
      Padding(
        padding: const EdgeInsets.fromLTRB(22, 16, 22, 0),
        child: Column(children: [
          FieldX(controller: c2, label: '${tr('name')} (FR)'),
          const SizedBox(height: 10),
          FieldX(controller: c1, label: '${tr('name')} (AR)'),
        ]),
      ),
      const SizedBox(height: 16),
      FormFooter(onSubmit: () async {
        final st = context.read<AppState>();
        if (brandsTab) {
          await st.catalog.updateBrand(id, c1.text.trim(), c2.text.trim());
        } else {
          await st.catalog.updateCategory(id, c1.text.trim(), c2.text.trim());
        }
        if (ctx.mounted) Navigator.pop(ctx);
        _reload();
      }),
    ]));
  }

  Future<void> _remove(BuildContext context, int id) async {
    final ok = await confirmDialog(context, title: tr('delete'), body: tr('cats.deleteWarn'), danger: true);
    if (!ok) return;
    final st = context.read<AppState>();
    if (brandsTab) {
      await st.catalog.deleteBrand(id);
    } else {
      await st.catalog.deleteCategory(id);
    }
    st.changed();
    _reload();
  }
}
