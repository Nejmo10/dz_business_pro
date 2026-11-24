import 'package:flutter/material.dart';
import '../app/l10n.dart';
import '../app/state.dart';
import '../app/theme.dart';
import '../core/ui.dart';
import 'categories/categories_page.dart';
import 'customers/customers_page.dart';
import 'dashboard/dashboard_page.dart';
import 'expenses/expenses_page.dart';
import 'finance/finance_page.dart';
import 'inventory/inventory_page.dart';
import 'invoices/invoices_page.dart';
import 'pos/pos_page.dart';
import 'products/products_page.dart';
import 'purchases/purchases_page.dart';
import 'reports/reports_page.dart';
import 'settings/settings_page.dart';
import 'suppliers/suppliers_page.dart';
import '../data/models/models.dart';

/// Main application shell: collapsible sidebar + premium top bar + workspace.
class HomeShell extends StatefulWidget {
  const HomeShell({super.key, required this.state});
  final AppState state;

  @override
  State<HomeShell> createState() => _HomeShellState();
}

class _HomeShellState extends State<HomeShell> {
  bool expanded = true;
  int module = 0;

  @override
  Widget build(BuildContext context) {
    final pages = <Widget>[
      DashboardPage(onNavigate: _go),
      PosPage(),
      ProductsPage(),
      CategoriesPage(),
      InventoryPage(),
      CustomersPage(),
      SuppliersPage(),
      PurchasesPage(),
      ExpensesPage(),
      InvoicesPage(),
      FinancePage(),
      ReportsPage(),
      SettingsPage(),
    ];
    final groups = _NavGroups();
    return Scaffold(
      body: Row(children: [
        _buildSidebar(groups),
        Expanded(
          child: Column(children: [
            _buildTopBar(),
            Expanded(
              child: Column(crossAxisAlignment: CrossAxisAlignment.stretch, children: [
                Padding(
                  padding: const EdgeInsets.fromLTRB(22, 14, 22, 0),
                  child: Breadcrumbs(trail: [tr('app.title'), tr(groups.moduleKeys[module])]),
                ),
                Expanded(
                  child: Padding(
                    padding: const EdgeInsets.fromLTRB(22, 10, 22, 18),
                    child: AnimatedSwitcher(
                      duration: const Duration(milliseconds: 220),
                      switchInCurve: Curves.easeOut,
                      switchOutCurve: Curves.easeIn,
                      transitionBuilder: (child, anim) => FadeTransition(
                        opacity: anim,
                        child: SlideTransition(
                          position: Tween<Offset>(begin: const Offset(0, .015), end: Offset.zero).animate(anim),
                          child: child,
                        ),
                      ),
                      child: pages[module],
                    ),
                  ),
                ),
              ]),
            ),
          ]),
        ),
      ]),
    );
  }

  void _go(int m) => setState(() => module = m);

  // ------------------------------------------------------------------ sidebar
  Widget _buildSidebar(_NavGroups groups) {
    return AnimatedContainer(
      duration: const Duration(milliseconds: 240),
      curve: Curves.easeInOutCubic,
      width: expanded ? 236 : 74,
      decoration: const BoxDecoration(
        gradient: LinearGradient(
          begin: Alignment.topCenter, end: Alignment.bottomCenter,
          colors: [Color(0xFF111C36), C.sidebar],
        ),
      ),
      child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
        const SizedBox(height: 20),
        Padding(
          padding: EdgeInsetsDirectional.only(start: expanded ? 18 : 15),
          child: Row(mainAxisSize: MainAxisSize.min, children: [
            Container(
              width: 38, height: 38,
              decoration: const BoxDecoration(gradient: C.gradientPrimary, borderRadius: BorderRadius.all(Radius.circular(11))),
              child: const Icon(Icons.storefront_rounded, color: Colors.white, size: 20),
            ),
            if (expanded) ...[
              const SizedBox(width: 11),
              Expanded(
                child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: const [
                  Text('DzBusiness', style: TextStyle(color: Colors.white, fontWeight: FontWeight.w800, fontSize: 15.5, letterSpacing: .2)),
                  Text('PRO 2026', style: TextStyle(color: Color(0xFF7C90BC), fontSize: 9.5, letterSpacing: 2.2)),
                ]),
              ),
            ],
          ]),
        ),
        const SizedBox(height: 18),
        Expanded(child: ListView.builder(
          padding: EdgeInsets.zero,
          itemCount: groups.titles.length,
          itemBuilder: (ctx, i) {
            final g = groups.titles[i];
            return Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
              if (expanded)
                Padding(
                  padding: const EdgeInsetsDirectional.only(start: 18, top: 12, bottom: 4),
                  child: Text(tr(g.key), style: const TextStyle(color: Color(0xFF7C90BC), fontSize: 10.5, fontWeight: FontWeight.w700, letterSpacing: 1.1)),
                )
              else
                Padding(
                  padding: const EdgeInsetsDirectional.only(start: 15, top: 8),
                  child: Container(width: 34, height: 1, color: const Color(0xFF2A3857)),
                ),
              for (final item in g.items) _navItem(item),
            ]);
          },
        )),
        Padding(
          padding: const EdgeInsets.all(12),
          child: _navItem(_NavItem(
            icon: expanded ? Icons.chevron_left_rounded : Icons.chevron_right_rounded,
            label: expanded ? tr('nav.collapsed') : tr('nav.expanded'),
            index: -1,
          )),
        ),
      ]),
    );
  }

  Widget _navItem(_NavItem item) {
    final selected = item.index == module;
    final iconBtn = Tooltip(
      message: expanded ? '' : item.label,
      child: MouseRegion(
        cursor: SystemMouseCursors.click,
        child: AnimatedContainer(
          duration: const Duration(milliseconds: 180),
          height: 40,
          margin: const EdgeInsets.symmetric(horizontal: 10, vertical: 2),
          padding: EdgeInsetsDirectional.only(start: expanded ? 10 : 0),
          decoration: BoxDecoration(
            gradient: selected ? C.gradientPrimary : null,
            color: !selected ? (_hoverIndex == item.index ? C.sidebarHover : Colors.transparent) : null,
            borderRadius: BorderRadius.circular(10),
          ),
          child: Row(
            mainAxisSize: MainAxisSize.min,
            mainAxisAlignment: expanded ? MainAxisAlignment.start : MainAxisAlignment.center,
            children: [
              Icon(item.icon, size: 19, color: selected ? Colors.white : const Color(0xFF9FB0D6)),
              if (expanded) ...[
                const SizedBox(width: 11),
                Expanded(
                  child: Text(item.label, overflow: TextOverflow.ellipsis,
                      style: TextStyle(fontSize: 13, fontWeight: selected ? FontWeight.w600 : FontWeight.w400,
                          color: selected ? Colors.white : const Color(0xFFB9C6E2))),
                ),
              ],
            ],
          ),
        ),
      ),
    );
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 1),
      child: MouseRegion(
        onEnter: (_) => setState(() => _hoverIndex = item.index),
        onExit: (_) => setState(() => _hoverIndex = -1),
        child: GestureDetector(onTap: () {
              if (item.index >= 0) {
                _go(item.index);
              } else {
                setState(() => expanded = !expanded);
              }
            }, child: iconBtn),
      ),
    );
  }

  int _hoverIndex = -1;

  // ------------------------------------------------------------------- topbar
  Widget _buildTopBar() {
    return Container(
      height: 62,
      color: C.surface,
      padding: const EdgeInsets.symmetric(horizontal: 22),
      child: Row(children: [
        _globalSearch(),
        const Spacer(),
        _notifications(),
        const SizedBox(width: 10),
        _languageMenu(),
        const SizedBox(width: 10),
        _profileMenu(),
      ]),
    );
  }

  Widget _globalSearch() {
    return SizedBox(
      width: 330,
      child: SearchFieldX(
        hint: tr('globalSearch'),
        onChanged: (q) async {
          if (q.length < 2) return;
          final products = await widget.state.catalog.products(query: q);
          final customers = await widget.state.people.customers(query: q);
          if (!mounted || (products.isEmpty && customers.isEmpty)) return;
          _openSearchResults(q, products, customers);
        },
      ),
    );
  }

  Future<void> _openSearchResults(String q, List<Product> products, List<Customer> customers) async {
    await showDialog<void>(
      context: context,
      builder: (ctx) => AlertDialog(
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(14)),
        title: Text('${tr('search')}: $q', style: const TextStyle(fontSize: 15, fontWeight: FontWeight.w700)),
        content: SizedBox(
          width: 420,
          child: SingleChildScrollView(
            child: Column(crossAxisAlignment: CrossAxisAlignment.start, mainAxisSize: MainAxisSize.min, children: [
              if (products.isNotEmpty)
                Padding(
                  padding: const EdgeInsets.only(bottom: 6),
                  child: Text(tr('mod.products'), style: const TextStyle(fontSize: 11.5, fontWeight: FontWeight.w700, color: C.textSecondary)),
                ),
              for (final prod in products.take(8))
                ListTile(
                  dense: true,
                  leading: const Icon(Icons.inventory_2_rounded, size: 18, color: C.primary),
                  title: Text(prod.nameFr.isNotEmpty ? prod.nameFr : prod.nameAr, style: const TextStyle(fontSize: 13)),
                  subtitle: Text(prod.sku.isNotEmpty ? prod.sku : tr('stock'), style: const TextStyle(fontSize: 11.5)),
                  onTap: () { Navigator.pop(ctx); _go(2); },
                ),
              if (customers.isNotEmpty)
                Padding(
                  padding: const EdgeInsets.symmetric(vertical: 6),
                  child: Text(tr('mod.customers'), style: const TextStyle(fontSize: 11.5, fontWeight: FontWeight.w700, color: C.textSecondary)),
                ),
              for (final cust in customers.take(8))
                ListTile(
                  dense: true,
                  leading: const Icon(Icons.person_outline_rounded, size: 18, color: C.secondary),
                  title: Text(cust.nameFr.isNotEmpty ? cust.nameFr : cust.nameAr, style: const TextStyle(fontSize: 13)),
                  subtitle: Text(cust.phone, style: const TextStyle(fontSize: 11.5)),
                  onTap: () { Navigator.pop(ctx); _go(5); },
                ),
            ]),
          ),
        ),
        actions: [
          TextButton(onPressed: () => Navigator.pop(ctx), child: Text(tr('close'))),
        ],
      ),
    );
  }

  Widget _notifications() {
    return FutureBuilder<int>(
      future: widget.state.inventory.lowStockCount(),
      builder: (_, snap) {
        final count = snap.data ?? 0;
        return PopupMenuButton<String>(
          tooltip: tr('notifications'),
          icon: Stack(children: [
            const Icon(Icons.notifications_outlined, color: C.textSecondary, size: 22),
            if (count > 0)
              Positioned(
                top: -2, right: -2,
                child: Container(
                  padding: const EdgeInsets.all(2.5),
                  decoration: const BoxDecoration(color: C.danger, shape: BoxShape.circle),
                  child: Text('$count', style: const TextStyle(color: Colors.white, fontSize: 8.5, fontWeight: FontWeight.w700)),
                ),
              ),
          ]),
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
          onSelected: (v) { if (v == 'low') _go(4); },
          itemBuilder: (_) => [
            if (count == 0)
              const PopupMenuItem(enabled: false, child: SizedBox(width: 1, height: 1)),
            if (count > 0)
              PopupMenuItem(
                child: ListTile(
                  contentPadding: EdgeInsets.zero,
                  dense: true,
                  leading: const Icon(Icons.warning_amber_rounded, color: C.warning, size: 20),
                  title: Text('${tr('kpi.lowStock')} : $count', style: const TextStyle(fontSize: 13)),
                ),
              )
            else
              const PopupMenuItem(
                enabled: false,
                child: Padding(
                  padding: EdgeInsets.symmetric(horizontal: 16, vertical: 12),
                  child: SizedBox(),
                ),
              ),
          ],
        );
      },
    );
  }

  Widget _languageMenu() {
    return PopupMenuButton<String>(
      tooltip: tr('language'),
      icon: const Icon(Icons.language_rounded, color: C.textSecondary, size: 21),
      onSelected: (v) async {
        final p = widget.state.profile..language = v;
        gLocale = v;
        await widget.state.saveProfile(p);
      },
      itemBuilder: (_) => [
        PopupMenuItem(value: 'ar', child: Text('العربية', style: const TextStyle(fontSize: 13.5))),
        PopupMenuItem(value: 'fr', child: Text('Français', style: const TextStyle(fontSize: 13.5))),
      ],
    );
  }

  Widget _profileMenu() {
    final name = widget.state.profile.name;
    return PopupMenuButton<String>(
      tooltip: tr('profile'),
      onSelected: (v) { if (v == 'settings') _go(12); },
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
      child: Container(
        height: 34,
        padding: const EdgeInsets.symmetric(horizontal: 10),
        decoration: BoxDecoration(color: C.bg, borderRadius: BorderRadius.circular(10), border: Border.all(color: C.border)),
        child: Row(children: [
          CircleAvatar(
            radius: 11,
            backgroundColor: C.primary.withValues(alpha: .15),
            child: Text(name.isNotEmpty ? name[0].toUpperCase() : 'D',
                style: const TextStyle(fontSize: 12, color: C.primary, fontWeight: FontWeight.w700)),
          ),
          if (MediaQuery.of(context).size.width > 1150) ...[
            const SizedBox(width: 9),
            Text(name.isEmpty ? 'DzBusiness Pro' : name, style: const TextStyle(fontSize: 12.5)),
          ],
          const Icon(Icons.expand_more, size: 16, color: C.textSecondary),
        ]),
      ),
      itemBuilder: (_) => [
        PopupMenuItem(value: 'settings', child: Row(children: [
          const Icon(Icons.settings_outlined, size: 17, color: C.textSecondary),
          const SizedBox(width: 9),
          Text(tr('mod.settings'), style: const TextStyle(fontSize: 13)),
        ])),
      ],
    );
  }
}

class _NavItem {
  const _NavItem({required this.icon, required this.label, required this.index});
  final IconData icon;
  final String label;
  final int index;
}

class _NavGroup {
  const _NavGroup(this.key, this.items);
  final String key;
  final List<_NavItem> items;
}

class _NavGroups {
  late final List<_NavGroup> titles;
  late final List<String> moduleKeys;

  _NavGroups() {
    IconData ic(String k) => switch (k) {
          'dashboard' => Icons.dashboard_rounded,
          'pos' => Icons.point_of_sale_rounded,
          'products' => Icons.inventory_2_rounded,
          'categories' => Icons.category_rounded,
          'inventory' => Icons.warehouse_rounded,
          'customers' => Icons.people_alt_rounded,
          'suppliers' => Icons.local_shipping_rounded,
          'purchases' => Icons.shopping_cart_rounded,
          'expenses' => Icons.receipt_long_rounded,
          'invoices' => Icons.description_rounded,
          'finance' => Icons.account_balance_rounded,
          'reports' => Icons.assessment_rounded,
          _ => Icons.settings_rounded,
        };

    _NavItem it(String k, String modKey, int idx) =>
        _NavItem(icon: ic(k), label: tr(modKey), index: idx);

    titles = [
      _NavGroup('nav.overview', [it('dashboard', 'mod.dashboard', 0)]),
      _NavGroup('nav.commerce', [
        it('pos', 'mod.pos', 1),
        it('products', 'mod.products', 2),
        it('categories', 'mod.categories', 3),
        it('invoices', 'mod.invoices', 9),
      ]),
      _NavGroup('nav.inventory', [
        it('inventory', 'mod.inventory', 4),
        it('purchases', 'mod.purchases', 7),
      ]),
      _NavGroup('nav.people', [
        it('customers', 'mod.customers', 5),
        it('suppliers', 'mod.suppliers', 6),
      ]),
      _NavGroup('nav.finance', [
        it('finance', 'mod.finance', 10),
        it('expenses', 'mod.expenses', 8),
        it('reports', 'mod.reports', 11),
      ]),
      _NavGroup('nav.system', [it('settings', 'mod.settings', 12)]),
    ];
    moduleKeys = [
      'mod.dashboard', 'mod.pos', 'mod.products', 'mod.categories', 'mod.inventory',
      'mod.customers', 'mod.suppliers', 'mod.purchases', 'mod.expenses',
      'mod.invoices', 'mod.finance', 'mod.reports', 'mod.settings',
    ];
  }
}
