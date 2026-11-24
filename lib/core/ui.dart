import 'dart:ui';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:intl/intl.dart';
import '../app/theme.dart';
import '../app/l10n.dart';
import 'money.dart';

/// ===========================================================================
/// DzBusiness Pro design system — reusable premium widgets
/// ===========================================================================

class AppButton extends StatefulWidget {
  const AppButton({
    super.key,
    required this.label,
    this.onPressed,
    this.icon,
    this.kind = AppButtonKind.primary,
    this.width,
    this.height = 42,
    this.tooltip,
  });
  final String label;
  final VoidCallback? onPressed;
  final IconData? icon;
  final AppButtonKind kind;
  final double? width;
  final double height;
  final String? tooltip;

  @override
  State<AppButton> createState() => _AppButtonState();
}

enum AppButtonKind { primary, secondary, danger, ghost, success }

class _AppButtonState extends State<AppButton> {
  bool _hover = false;
  bool _down = false;

  @override
  Widget build(BuildContext context) {
    final enabled = widget.onPressed != null;
    late final Color fg;
    late final Color bgC;
    late final BoxBorder side;
    late final LinearGradient? grad;
    switch (widget.kind) {
      case AppButtonKind.primary:
        fg = Colors.white; bgC = C.primary; side = const Border();
        grad = const LinearGradient(colors: [Color(0xFF3F6EF5), Color(0xFF2F5FE8)]);
      case AppButtonKind.secondary:
        fg = C.primary; bgC = Colors.white; grad = null;
        side = const Border.fromBorderSide(BorderSide(color: C.primary, width: 1.2));
      case AppButtonKind.danger:
        fg = Colors.white; bgC = C.danger; grad = null; side = const Border();
      case AppButtonKind.success:
        fg = Colors.white; bgC = C.success; grad = null; side = const Border();
      case AppButtonKind.ghost:
        fg = C.textPrimary; bgC = Colors.white; grad = null;
        side = const Border.fromBorderSide(BorderSide(color: C.border));
    }
    Widget b = MouseRegion(
      onEnter: (_) => setState(() => _hover = true),
      onExit: (_) => setState(() { _hover = false; _down = false; }),
      child: GestureDetector(
        onTapDown: (_) => setState(() => _down = true),
        onTapCancel: () => setState(() => _down = false),
        onTapUp: (_) => setState(() => _down = false),
        onTap: widget.onPressed,
        child: AnimatedScale(
          scale: _down ? 0.97 : (_hover && enabled ? 1.02 : 1.0),
          duration: const Duration(milliseconds: 130),
          curve: Curves.easeOut,
          child: AnimatedContainer(
            duration: const Duration(milliseconds: 150),
            height: widget.height,
            width: widget.width,
            padding: const EdgeInsets.symmetric(horizontal: 18),
            decoration: BoxDecoration(
              gradient: enabled ? grad : null,
              color: enabled ? bgC : C.border,
              borderRadius: BorderRadius.circular(10),
              border: side,
              boxShadow: enabled
                  ? [BoxShadow(
                      color: (grad != null ? C.primary : bgC).withValues(alpha: _hover ? .32 : .18),
                      blurRadius: _hover ? 14 : 8, offset: const Offset(0, 3))]
                  : null,
            ),
            child: Row(
              mainAxisSize: MainAxisSize.min,
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                if (widget.icon != null) ...[
                  Icon(widget.icon, size: 17, color: fg),
                  const SizedBox(width: 8),
                ],
                Text(widget.label,
                    style: TextStyle(
                        color: enabled ? fg : C.textSecondary,
                        fontSize: 13.5, fontWeight: FontWeight.w600)),
              ],
            ),
          ),
        ),
      ),
    );
    if (widget.tooltip != null) b = Tooltip(message: widget.tooltip!, child: b);
    return b;
  }
}

class IconButtonX extends StatefulWidget {
  const IconButtonX({super.key, required this.icon, this.onPressed, this.color, this.tooltip, this.size = 34});
  final IconData icon;
  final VoidCallback? onPressed;
  final Color? color;
  final String? tooltip;
  final double size;

  @override
  State<IconButtonX> createState() => _IconButtonXState();
}

class _IconButtonXState extends State<IconButtonX> {
  bool _hover = false;
  @override
  Widget build(BuildContext context) {
    final b = MouseRegion(
      cursor: SystemMouseCursors.click,
      onEnter: (_) => setState(() => _hover = true),
      onExit: (_) => setState(() => _hover = false),
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 140),
        width: widget.size, height: widget.size,
        decoration: BoxDecoration(
          color: _hover ? C.bg : Colors.transparent,
          borderRadius: BorderRadius.circular(9),
          border: Border.all(color: _hover ? C.border : Colors.transparent),
        ),
        child: Icon(widget.icon, size: widget.size * 0.52, color: widget.color ?? C.textSecondary),
      ),
    );
    return GestureDetector(onTap: widget.onPressed, child: b);
  }
}

/// Card with hover elevation micro-interaction.
class HoverCard extends StatefulWidget {
  const HoverCard({super.key, required this.child, this.padding = const EdgeInsets.all(16), this.onTap, this.margin = EdgeInsets.zero});
  final Widget child;
  final EdgeInsets padding, margin;
  final VoidCallback? onTap;

  @override
  State<HoverCard> createState() => _HoverCardState();
}

class _HoverCardState extends State<HoverCard> {
  bool _hover = false;
  @override
  Widget build(BuildContext context) {
    final card = MouseRegion(
      cursor: widget.onTap != null ? SystemMouseCursors.click : MouseCursor.defer,
      onEnter: (_) => setState(() => _hover = true),
      onExit: (_) => setState(() => _hover = false),
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 180),
        curve: Curves.easeOut,
        margin: widget.margin,
        padding: widget.padding,
        decoration: BoxDecoration(
          color: C.surface,
          borderRadius: BorderRadius.circular(14),
          border: Border.all(color: _hover ? C.primary.withValues(alpha: .25) : C.border),
          boxShadow: [
            BoxShadow(
              color: C.primary.withValues(alpha: _hover ? .10 : .04),
              blurRadius: _hover ? 22 : 10,
              offset: Offset(0, _hover ? 6 : 2),
            ),
          ],
        ),
        child: widget.child,
      ),
    );
    return widget.onTap == null ? card : GestureDetector(onTap: widget.onTap, child: card);
  }
}

/// KPI stat card with animated counter.
class KpiCard extends StatelessWidget {
  const KpiCard({super.key, required this.title, required this.value, required this.icon, required this.color, this.subtitle});
  final String title, value, icon;
  final Color color;
  final String? subtitle;

  @override
  Widget build(BuildContext context) {
    final isMoney = value.contains('DZD');
    return HoverCard(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(children: [
            Container(
              width: 38, height: 38,
              decoration: BoxDecoration(
                gradient: LinearGradient(colors: [color.withValues(alpha: .18), color.withValues(alpha: .08)]),
                borderRadius: BorderRadius.circular(10),
              ),
              child: Icon(_iconOf(icon), color: color, size: 19),
            ),
            const Spacer(),
            if (subtitle != null)
              Text(subtitle!, style: const TextStyle(fontSize: 11.5, color: C.textSecondary)),
          ]),
          const Spacer(),
          AnimatedNumber(
            value: double.tryParse(
                  value.replaceAll(RegExp(r'[^0-9.\-]'), ''),
                ) ?? 0,
            isMoney: isMoney,
            color: C.textPrimary,
          ),
          const SizedBox(height: 4),
          Text(title, style: const TextStyle(fontSize: 12.5, color: C.textSecondary)),
        ],
      ),
    );
  }

  IconData _iconOf(String k) => switch (k) {
        'revenue' => Icons.trending_up_rounded,
        'sales' => Icons.point_of_sale_rounded,
        'profit' => Icons.savings_rounded,
        'net' => Icons.account_balance_wallet_rounded,
        'expense' => Icons.payments_rounded,
        'products' => Icons.inventory_2_rounded,
        'lowstock' => Icons.warning_amber_rounded,
        'customers' => Icons.person_search_rounded,
        'suppliers' => Icons.local_shipping_rounded,
        _ => Icons.analytics_rounded,
      };
}

/// Integer counter that animates from old value to new value.
class AnimatedNumber extends StatelessWidget {
  const AnimatedNumber({super.key, required this.value, required this.isMoney, this.color = C.textPrimary, this.fontSize = 21});
  final double value;
  final bool isMoney;
  final Color color;
  final double fontSize;

  @override
  Widget build(BuildContext context) {
    return TweenAnimationBuilder<double>(
      tween: Tween(end: value),
      duration: const Duration(milliseconds: 650),
      curve: Curves.easeOutCubic,
      builder: (_, v, __) {
        final f = isMoney ? (NumberFormat.decimalPattern()..minimumFractionDigits = 2)
            : NumberFormat.decimalPattern();
        final txt = isMoney ? '${f.format(v)} DZD' : f.format(v.round());
        return Text(txt,
            style: TextStyle(fontSize: fontSize, fontWeight: FontWeight.w800, color: color, letterSpacing: -0.4));
      },
    );
  }
}

/// Floating-label text field.
class FieldX extends StatelessWidget {
  const FieldX({
    super.key,
    required this.label,
    this.controller,
    this.onChanged,
    this.validator,
    this.keyboardType = TextInputType.text,
    this.prefix,
    this.suffix,
    this.obscure = false,
    this.maxLines = 1,
    this.autofocus = false,
    this.inputFormatters,
    this.onSubmitted,
  });
  final String label;
  final TextEditingController? controller;
  final ValueChanged<String>? onChanged, onSubmitted;
  final String? Function(String?)? validator;
  final TextInputType keyboardType;
  final Widget? prefix, suffix;
  final bool obscure;
  final int maxLines;
  final bool autofocus;
  final List<TextInputFormatter>? inputFormatters;

  @override
  Widget build(BuildContext context) {
    return TextFormField(
      controller: controller,
      onChanged: onChanged,
      onFieldSubmitted: onSubmitted,
      validator: validator,
      autofocus: autofocus,
      obscureText: obscure,
      maxLines: maxLines,
      keyboardType: keyboardType,
      inputFormatters: inputFormatters,
      style: const TextStyle(fontSize: 13.5, color: C.textPrimary),
      decoration: InputDecoration(
        labelText: label,
        floatingLabelBehavior: FloatingLabelBehavior.auto,
        prefixIcon: prefix,
        suffixIcon: suffix,
        isDense: maxLines > 1 ? false : null,
      ),
    );
  }
}

class SearchFieldX extends StatelessWidget {
  const SearchFieldX({super.key, required this.hint, required this.onChanged, this.trailing});
  final String hint;
  final ValueChanged<String> onChanged;
  final List<Widget>? trailing;

  @override
  Widget build(BuildContext context) {
    return Row(children: [
      Expanded(
        child: SizedBox(
          height: 40,
          child: TextField(
            onChanged: onChanged,
            decoration: InputDecoration(
              hintText: hint,
              prefixIcon: const Icon(Icons.search, size: 19, color: C.textSecondary),
              contentPadding: const EdgeInsets.symmetric(vertical: 0, horizontal: 12),
              border: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(10),
                  borderSide: const BorderSide(color: C.border)),
              enabledBorder: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(10),
                  borderSide: const BorderSide(color: C.border)),
              focusedBorder: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(10),
                  borderSide: const BorderSide(color: C.primary, width: 1.4)),
              filled: true, fillColor: C.surface,
            ),
          ),
        ),
      ),
      if (trailing != null) ...trailing!,
    ]);
  }
}

/// Animated, generic dropdown (select) control.
class SmartDropdown<T> extends StatefulWidget {
  const SmartDropdown({super.key, required this.items, required this.value, required this.onChanged, required this.display, this.label, this.width});
  final List<T> items;
  final T? value;
  final ValueChanged<T?> onChanged;
  final String Function(T) display;
  final String? label;
  final double? width;

  @override
  State<SmartDropdown<T>> createState() => _SmartDropdownState<T>();
}

class _SmartDropdownState<T> extends State<SmartDropdown<T>> {
  final _layerLink = LayerLink();
  bool _open = false;
  OverlayEntry? _entry;

  void _toggle() {
    if (_open) {
      _close();
      return;
    }
    final overlay = Overlay.of(context);
    _entry = OverlayEntry(builder: (ctx) {
      return GestureDetector(behavior: HitTestBehavior.translucent, onTap: _close,
        child: Stack(children: [
          CompositedTransformFollower(
            link: _layerLink,
            offset: const Offset(0, 42),
            showWhenUnlinked: false,
            child: Material(
              elevation: 14, borderRadius: BorderRadius.circular(12), color: C.surface,
              child: Container(
                constraints: const BoxConstraints(maxHeight: 260),
                width: widget.width ?? 260,
                decoration: BoxDecoration(
                    border: Border.all(color: C.border),
                    borderRadius: BorderRadius.circular(12)),
                child: TweenAnimationBuilder<double>(
                  tween: Tween(end: 1),
                  duration: const Duration(milliseconds: 160),
                  curve: Curves.easeOut,
                  builder: (_, v, child) => ClipRRect(
                    borderRadius: BorderRadius.circular(12),
                    child: Opacity(opacity: v, child: child),
                  ),
                  child: ListView(
                    padding: const EdgeInsets.symmetric(vertical: 4),
                    shrinkWrap: true,
                    children: [
                      for (final it in widget.items)
                        InkWell(
                          onTap: () { widget.onChanged(it); _close(); },
                          child: Container(
                            padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 11),
                            color: it == widget.value ? C.primary.withValues(alpha: .06) : null,
                            child: Text(widget.display(it),
                                style: const TextStyle(fontSize: 13.5)),
                          ),
                        ),
                    ],
                  ),
                ),
              ),
            ),
          ),
        ]),
      );
    });
    overlay.insert(_entry!);
    setState(() => _open = true);
  }

  void _close() {
    _entry?.remove();
    _entry = null;
    if (mounted) setState(() => _open = false);
  }

  @override
  void dispose() {
    _entry?.remove();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final display = widget.value == null ? (widget.label ?? tr('none')) : widget.display(widget.value as T);
    return CompositedTransformTarget(
      link: _layerLink,
      child: MouseRegion(
        cursor: SystemMouseCursors.click,
        child: GestureDetector(
          onTap: _toggle,
          child: AnimatedContainer(
            duration: const Duration(milliseconds: 150),
            width: widget.width,
            height: 40,
            padding: const EdgeInsets.symmetric(horizontal: 12),
            decoration: BoxDecoration(
              color: C.surface,
              borderRadius: BorderRadius.circular(10),
              border: Border.all(color: _open ? C.primary : C.border, width: _open ? 1.4 : 1),
            ),
            child: Row(children: [
              Expanded(child: Text(display, style: const TextStyle(fontSize: 13.5), overflow: TextOverflow.ellipsis)),
              AnimatedRotation(
                turns: _open ? .5 : 0,
                duration: const Duration(milliseconds: 180),
                child: const Icon(Icons.expand_more, size: 18, color: C.textSecondary),
              ),
            ]),
          ),
        ),
      ),
    );
  }
}

class BadgeX extends StatelessWidget {
  const BadgeX({super.key, required this.text, this.color = C.primary, this.icon});
  final String text;
  final Color color;
  final IconData? icon;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 9, vertical: 4),
      decoration: BoxDecoration(
        color: color.withValues(alpha: .12),
        borderRadius: BorderRadius.circular(20),
      ),
      child: Row(mainAxisSize: MainAxisSize.min, children: [
        if (icon != null) ...[
          Icon(icon, size: 12, color: color),
          const SizedBox(width: 4),
        ],
        Text(text, style: TextStyle(fontSize: 11.5, fontWeight: FontWeight.w600, color: color)),
      ]),
    );
  }
}

/// Loading failure state shown instead of an endless spinner, with retry.
class ErrorStateX extends StatelessWidget {
  const ErrorStateX({super.key, required this.message, required this.onRetry});
  final String message;
  final VoidCallback onRetry;

  @override
  Widget build(BuildContext context) {
    return Center(
      child: Padding(
        padding: const EdgeInsets.all(24),
        child: Column(mainAxisSize: MainAxisSize.min, children: [
          Container(
            width: 74, height: 74,
            decoration: BoxDecoration(
              color: C.danger.withValues(alpha: .10),
              borderRadius: BorderRadius.circular(22),
            ),
            child: const Icon(Icons.error_outline_rounded, size: 34, color: C.danger),
          ),
          const SizedBox(height: 16),
          Text(tr('error.loadFailed'), style: const TextStyle(fontSize: 16, fontWeight: FontWeight.w700)),
          const SizedBox(height: 8),
          ConstrainedBox(
            constraints: const BoxConstraints(maxWidth: 460),
            child: Text(message, textAlign: TextAlign.center,
                style: const TextStyle(fontSize: 12, color: C.textSecondary, height: 1.5),
                maxLines: 6, overflow: TextOverflow.ellipsis),
          ),
          const SizedBox(height: 18),
          AppButton(label: tr('error.retry'), icon: Icons.refresh_rounded, onPressed: onRetry),
        ]),
      ),
    );
  }
}

class EmptyStateX extends StatelessWidget {
  const EmptyStateX({super.key, required this.title, required this.body, this.icon = Icons.inbox_rounded, this.action});
  final String title, body;
  final IconData icon;
  final Widget? action;

  @override
  Widget build(BuildContext context) {
    return Center(
      child: Column(mainAxisSize: MainAxisSize.min, children: [
        Container(
          width: 74, height: 74,
          decoration: BoxDecoration(
            gradient: LinearGradient(colors: [C.primary.withValues(alpha: .12), C.secondary.withValues(alpha: .10)]),
            borderRadius: BorderRadius.circular(22),
          ),
          child: Icon(icon, size: 34, color: C.primary),
        ),
        const SizedBox(height: 16),
        Text(title, style: const TextStyle(fontSize: 16, fontWeight: FontWeight.w700)),
        if (body.isNotEmpty) ...[
          const SizedBox(height: 8),
          ConstrainedBox(
            constraints: const BoxConstraints(maxWidth: 440),
            child: Text(body, textAlign: TextAlign.center,
                style: const TextStyle(fontSize: 13, color: C.textSecondary, height: 1.5)),
          ),
        ],
        if (action != null) ...[const SizedBox(height: 18), action!],
      ]),
    );
  }
}

class SectionHeader extends StatelessWidget {
  const SectionHeader({super.key, required this.title, this.trailing});
  final String title;
  final List<Widget>? trailing;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 10),
      child: Row(children: [
        Text(title, style: const TextStyle(fontSize: 15.5, fontWeight: FontWeight.w700)),
        const Spacer(),
        ...?trailing,
      ]),
    );
  }
}

/// Breadcrumbs bar for context.
class Breadcrumbs extends StatelessWidget {
  const Breadcrumbs({super.key, required this.trail});
  final List<String> trail;

  @override
  Widget build(BuildContext context) {
    return Row(children: [
      for (var i = 0; i < trail.length; i++) ...[
        Text(trail[i], style: TextStyle(fontSize: 12.5,
            color: i == trail.length - 1 ? C.textPrimary : C.textSecondary,
            fontWeight: i == trail.length - 1 ? FontWeight.w600 : FontWeight.w400)),
        if (i < trail.length - 1)
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 6),
            child: Icon(Icons.chevron_right, size: 14, color: C.textSecondary),
          ),
      ],
    ]);
  }
}

/// Simple premium data table.
class TableX extends StatelessWidget {
  const TableX({super.key, required this.columns, required this.widths, required this.rows, this.minHeight = 0});
  final List<String> columns;
  final List<double> widths;
  final List<List<Widget>> rows;
  final double minHeight;

  @override
  Widget build(BuildContext context) {
    final flex = widths.map((w) => w.toInt()).toList();
    return Container(
      constraints: minHeight > 0 ? BoxConstraints(minHeight: minHeight) : null,
      decoration: BoxDecoration(
        color: C.surface,
        borderRadius: BorderRadius.circular(14),
        border: Border.all(color: C.border),
      ),
      child: Column(children: [
        Container(
          padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 11),
          decoration: const BoxDecoration(
            color: Color(0xFFFAFBFE),
            borderRadius: BorderRadius.vertical(top: Radius.circular(14)),
          ),
          child: Row(
              children: [for (var i = 0; i < columns.length; i++)
                Expanded(flex: flex[i], child: Text(columns[i],
                    style: const TextStyle(fontSize: 12, fontWeight: FontWeight.w700, color: C.textSecondary)))]),
        ),
        Divider(height: 1, color: C.border.withValues(alpha: .7)),
        Expanded(
          child: ListView.builder(
            shrinkWrap: minHeight > 0,
            itemCount: rows.length,
            itemBuilder: (_, r) {
              final cell = <Widget>[];
              for (var i = 0; i < rows[r].length; i++) {
                cell.add(Expanded(flex: flex[i], child: Align(
                    alignment: AlignmentDirectional.centerStart, child: rows[r][i])));
              }
              return _RowHover(
                  divider: r < rows.length - 1,
                  child: Padding(
                    padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
                    child: Row(children: cell),
                  ));
            },
          ),
        ),
      ]),
    );
  }
}

class _RowHover extends StatefulWidget {
  const _RowHover({required this.child, required this.divider});
  final Widget child;
  final bool divider;

  @override
  State<_RowHover> createState() => _RowHoverState();
}

class _RowHoverState extends State<_RowHover> {
  bool _hover = false;
  @override
  Widget build(BuildContext context) {
    final ink = Material(
      color: _hover ? C.primary.withValues(alpha: .04) : Colors.transparent,
      child: widget.child,
    );
    return Column(children: [
      MouseRegion(onHover: (_) => setState(() => _hover = true),
          onExit: (_) => setState(() => _hover = false), child: ink),
      if (widget.divider) Divider(height: 1, color: C.border.withValues(alpha: .45)),
    ]);
  }
}

class SegmentedX<T> extends StatelessWidget {
  const SegmentedX({super.key, required this.options, required this.selected, required this.onChanged});
  final List<(T, String)> options;
  final T selected;
  final ValueChanged<T> onChanged;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(3),
      decoration: BoxDecoration(
        color: const Color(0xFFEEF1F8),
        borderRadius: BorderRadius.circular(10),
      ),
      child: Row(mainAxisSize: MainAxisSize.min, children: [
        for (final (value, label) in options)
          GestureDetector(
            onTap: () => onChanged(value),
            child: AnimatedContainer(
              duration: const Duration(milliseconds: 180),
              curve: Curves.easeOut,
              padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 7),
              decoration: BoxDecoration(
                color: selected == value ? C.surface : Colors.transparent,
                borderRadius: BorderRadius.circular(8),
                boxShadow: selected == value
                    ? [BoxShadow(color: Colors.black.withValues(alpha: .06), blurRadius: 6, offset: const Offset(0, 1))]
                    : null,
              ),
              child: Text(label, style: TextStyle(fontSize: 12.5,
                  fontWeight: selected == value ? FontWeight.w700 : FontWeight.w500,
                  color: selected == value ? C.primary : C.textSecondary)),
            ),
          ),
      ]),
    );
  }
}

/// Toast popups (top-center slide-in).
class Toasts {
  static void show(BuildContext context, String msg, {ToastKind kind = ToastKind.success}) {
    final overlay = Overlay.of(context);
    late final OverlayEntry entry;
    final colors = switch (kind) {
      ToastKind.success => C.success,
      ToastKind.error => C.danger,
      ToastKind.warning => C.warning,
      ToastKind.info => C.primary,
    };
    entry = OverlayEntry(
      builder: (_) => Positioned(
        top: 24,
        left: 0, right: 0,
        child: SafeArea(
          child: Align(
            alignment: Alignment.topCenter,
            child: TweenAnimationBuilder<double>(
              tween: Tween(end: 1),
              duration: const Duration(milliseconds: 240),
              curve: Curves.easeOutBack,
              builder: (_, v, child) => Transform.scale(scale: v, child: child),
              child: Material(color: Colors.transparent, child: Container(
                padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
                decoration: BoxDecoration(
                  color: C.surface,
                  borderRadius: BorderRadius.circular(12),
                  border: Border.all(color: colors.withValues(alpha: .45)),
                  boxShadow: [BoxShadow(color: colors.withValues(alpha: .18), blurRadius: 22, offset: const Offset(0, 8))],
                ),
                child: Row(mainAxisSize: MainAxisSize.min, children: [
                  CircleAvatar(radius: 9, backgroundColor: colors, child: Icon(
                      kind == ToastKind.success ? Icons.check : Icons.priority_high,
                      size: 11, color: Colors.white)),
                  const SizedBox(width: 10),
                  Text(msg, style: const TextStyle(fontSize: 13, fontWeight: FontWeight.w600)),
                ]),
              )),
            ),
          ),
        ),
      ),
    );
    overlay.insert(entry);
    Future.delayed(const Duration(milliseconds: 2400), () {
      if (entry.mounted) entry.remove();
    });
  }
}

enum ToastKind { success, error, warning, info }

/// Confirmation dialog with entrance animations.
Future<bool> confirmDialog(BuildContext context, {
  required String title,
  required String body,
  String? confirmLabel,
  bool danger = true,
}) async {
  final res = await showDialog<bool>(
    context: context,
    builder: (ctx) => BackdropFilter(
      filter: ImageFilter.blur(sigmaX: 3, sigmaY: 3),
      child: Dialog(
        child: TweenAnimationBuilder<double>(
          tween: Tween(end: 1),
          duration: const Duration(milliseconds: 200),
          curve: Curves.easeOutBack,
          builder: (_, v, child) => Transform.scale(scale: .92 + .08 * v, child: Opacity(opacity: v.clamp(0, 1), child: child)),
          child: Padding(
            padding: const EdgeInsets.all(24),
            child: Column(mainAxisSize: MainAxisSize.min, crossAxisAlignment: CrossAxisAlignment.start, children: [
              Container(
                width: 44, height: 44,
                decoration: BoxDecoration(
                  color: (danger ? C.danger : C.primary).withValues(alpha: .12),
                  borderRadius: BorderRadius.circular(12),
                ),
                child: Icon(danger ? Icons.warning_amber_rounded : Icons.help_outline_rounded,
                    color: danger ? C.danger : C.primary, size: 22),
              ),
              const SizedBox(height: 14),
              Text(title, style: const TextStyle(fontSize: 16.5, fontWeight: FontWeight.w700)),
              const SizedBox(height: 8),
              Text(body, style: const TextStyle(fontSize: 13, color: C.textSecondary, height: 1.5)),
              const SizedBox(height: 20),
              Row(mainAxisAlignment: MainAxisAlignment.end, children: [
                TextButton(
                  onPressed: () => Navigator.pop(ctx, false),
                  child: Text(tr('cancel'), style: const TextStyle(color: C.textSecondary)),
                ),
                const SizedBox(width: 8),
                AppButton(label: confirmLabel ?? tr('confirm'), kind: danger ? AppButtonKind.danger : AppButtonKind.primary,
                    onPressed: () => Navigator.pop(ctx, true)),
              ]),
            ]),
          ),
        ),
      ),
    ),
  );
  return res ?? false;
}

/// Modal form helper with sticky footer. Returns value passed to Navigator.pop.
Future<T?> formDialog<T>(BuildContext context, {
  required String title,
  required WidgetBuilder body,
  double width = 520,
}) {
  return showDialog<T>(
    context: context,
    builder: (ctx) => Dialog(
      child: ClipRRect(
        borderRadius: BorderRadius.circular(18),
        child: TweenAnimationBuilder<double>(
          tween: Tween(end: 1),
          duration: const Duration(milliseconds: 200),
          curve: Curves.easeOutBack,
          builder: (_, v, child) => Transform.scale(scale: .94 + .06 * v, child: Opacity(opacity: v.clamp(0, 1), child: child)),
          child: Container(
            width: width,
            color: C.surface,
            child: body(ctx),
          ),
        ),
      ),
    ),
  );
}

class FormFooter extends StatelessWidget {
  const FormFooter({super.key, required this.onSubmit, this.submitLabel, this.extraLabel, this.onExtra, this.danger = false, this.enabled = true});
  final VoidCallback onSubmit;
  final String? submitLabel;
  final String? extraLabel;
  final VoidCallback? onExtra;
  final bool danger;
  final bool enabled;

  @override
  Widget build(BuildContext context) {
    return Container(
      color: const Color(0xFFFAFBFE),
      padding: const EdgeInsets.symmetric(horizontal: 22, vertical: 14),
      child: Row(children: [
        if (onExtra != null) ...[
          AppButton(label: extraLabel ?? '', kind: AppButtonKind.secondary, onPressed: onExtra),
          const Spacer(),
        ] else
          const Spacer(),
        TextButton(onPressed: () => Navigator.pop(context), child: Text(tr('cancel'), style: const TextStyle(color: C.textSecondary))),
        const SizedBox(width: 10),
        AppButton(label: submitLabel ?? tr('save'),
            kind: danger ? AppButtonKind.danger : AppButtonKind.primary,
            onPressed: enabled ? onSubmit : null),
      ]),
    );
  }
}

class FormHeader extends StatelessWidget {
  const FormHeader({super.key, required this.title, this.subtitle});
  final String title;
  final String? subtitle;

  @override
  Widget build(BuildContext context) {
    return Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
      Text(title, style: const TextStyle(fontSize: 17, fontWeight: FontWeight.w700)),
      if (subtitle != null && subtitle!.isNotEmpty) ...[
        const SizedBox(height: 4),
        Text(subtitle!, style: const TextStyle(fontSize: 12.5, color: C.textSecondary)),
      ],
    ]);
  }
}

String moneyOf(int cents) => Money.fmt(cents, locale: gLocale);
