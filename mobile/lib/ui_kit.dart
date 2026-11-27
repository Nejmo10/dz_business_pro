import 'package:flutter/material.dart';
import 'package:intl/intl.dart';

/// Shared design tokens with the desktop product (Premium Light palette).
class C {
  static const bg = Color(0xFFF5F7FC);
  static const surface = Color(0xFFFFFFFF);
  static const primary = Color(0xFF3867F4);
  static const secondary = Color(0xFF7357E8);
  static const accent = Color(0xFF16B8A6);
  static const success = Color(0xFF16A879);
  static const warning = Color(0xFFF2A93B);
  static const danger = Color(0xFFEF5261);
  static const textPrimary = Color(0xFF192338);
  static const textSecondary = Color(0xFF7B879C);
  static const border = Color(0xFFE8EDF5);
}

/// Amounts travel as integer centimes over the wire; format only at display.
class Money {
  static const int centsPerUnit = 100;

  static String fmt(int minor, {bool ar = false}) {
    final nf = NumberFormat.decimalPatternDigits(
        locale: ar ? 'ar_DZ' : 'fr_DZ', decimalDigits: 2);
    final sign = minor < 0 ? '-' : '';
    return '$sign${nf.format(minor.abs() / centsPerUnit)} DA';
  }
}

String shortDay(String isoDay, bool ar) {
  final d = DateTime.parse('${isoDay}T00:00:00');
  const arDays = ['الاثنين', 'الثلاثاء', 'الأربعاء', 'الخميس', 'الجمعة', 'السبت', 'الأحد'];
  const frDays = ['Lun', 'Mar', 'Mer', 'Jeu', 'Ven', 'Sam', 'Dim'];
  final wd = d.weekday - 1;
  return '${ar ? arDays[wd] : frDays[wd]}\n${d.day}/${d.month}';
}

/// Premium-light card used across all mobile screens.
class MCard extends StatelessWidget {
  const MCard({
    super.key,
    required this.child,
    this.padding = const EdgeInsets.all(14),
    this.color = C.surface,
  });
  final Widget child;
  final EdgeInsets padding;
  final Color color;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: padding,
      decoration: BoxDecoration(
        color: color,
        borderRadius: BorderRadius.circular(14),
        border: Border.all(color: C.border),
        boxShadow: [
          BoxShadow(
            color: const Color(0xFF192338).withValues(alpha: .05),
            blurRadius: 10,
            offset: const Offset(0, 3),
          ),
        ],
      ),
      child: child,
    );
  }
}

class KpiTile extends StatelessWidget {
  const KpiTile({
    super.key,
    required this.title,
    required this.value,
    required this.color,
    this.subtitle,
  });
  final String title;
  final String value;
  final Color color;
  final String? subtitle;

  @override
  Widget build(BuildContext context) {
    return MCard(
      padding: const EdgeInsets.all(12),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(children: [
            Container(width: 8, height: 8, decoration: BoxDecoration(color: color, shape: BoxShape.circle)),
            const SizedBox(width: 6),
            Expanded(
              child: Text(title,
                  maxLines: 1, overflow: TextOverflow.ellipsis,
                  style: const TextStyle(fontSize: 11, color: C.textSecondary)),
            ),
          ]),
          const SizedBox(height: 8),
          AnimatedSwitcher(
            duration: const Duration(milliseconds: 320),
            transitionBuilder: (child, anim) => FadeTransition(
              opacity: anim,
              child: SlideTransition(
                position: Tween<Offset>(
                        begin: const Offset(0, .16), end: Offset.zero)
                    .animate(CurvedAnimation(parent: anim, curve: Curves.easeOutCubic)),
                child: child,
              ),
            ),
            child: Text(value,
                key: ValueKey(value),
                maxLines: 1, overflow: TextOverflow.ellipsis,
                style: TextStyle(fontSize: 17, fontWeight: FontWeight.w800, color: color)),
          ),
          if (subtitle != null) ...[
            const SizedBox(height: 2),
            Text(subtitle!,
                maxLines: 1, overflow: TextOverflow.ellipsis,
                style: const TextStyle(fontSize: 10.5, color: C.textSecondary)),
          ],
        ],
      ),
    );
  }
}

/// Gradient circular avatar carrying the business initial, used in the
/// mobile app bar and pairing header.
class BrandAvatar extends StatelessWidget {
  const BrandAvatar({super.key, this.label = 'D', this.size = 36});
  final String label;
  final double size;

  @override
  Widget build(BuildContext context) {
    return Container(
      width: size, height: size,
      alignment: Alignment.center,
      decoration: const BoxDecoration(
        gradient: LinearGradient(
            begin: Alignment.topLeft, end: Alignment.bottomRight,
            colors: [C.primary, C.secondary]),
        shape: BoxShape.circle,
      ),
      child: Text(label.characters.first.toUpperCase(), style: TextStyle(
          color: Colors.white, fontSize: size * .42, fontWeight: FontWeight.w900)),
    );
  }
}

class StatusBadge extends StatelessWidget {
  const StatusBadge({super.key, required this.text, required this.color});
  final String text;
  final Color color;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
      decoration: BoxDecoration(
        color: color.withValues(alpha: .12),
        borderRadius: BorderRadius.circular(20),
      ),
      child: Text(text,
          style: TextStyle(fontSize: 10.5, color: color, fontWeight: FontWeight.w700)),
    );
  }
}
