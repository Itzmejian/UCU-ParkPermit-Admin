import 'package:flutter/material.dart';

class AppColors {
  static const navy = Color(0xFF1D3E7C);
  static const navyDark = Color(0xFF0F2552);
  static const ucuGreen = Color(0xFF0D5C3A);
  static const gold = Color(0xFFF5B83D);
  static const goldLight = Color(0xFFFFF1CF);
  static const goldDark = Color(0xFF7A5200);
  static const surface = Color(0xFFF7F8FF);
  static const inputFill = Color(0xFFEEF1FF);
  static const border = Color(0xFFC9D3EA);
  static const blueSoft = Color(0xFFB7C6EC);
  static const textDark = Color(0xFF111C2D);
  static const textMuted = Color(0xFF444650);
  static const textHint = Color(0xFF5F6472);
  static const error = Color(0xFFB91C1C);
  static const errorLight = Color(0xFFFDE4E4);
  static const success = Color(0xFF15803D);
  static const successLight = Color(0xFFDDF5E4);
}

ThemeData buildAdminTheme() {
  OutlineInputBorder border(Color c, [double w = 1]) => OutlineInputBorder(
        borderRadius: BorderRadius.circular(12),
        borderSide: BorderSide(color: c, width: w),
      );
  final shape = RoundedRectangleBorder(borderRadius: BorderRadius.circular(12));
  const buttonText = TextStyle(fontSize: 14, fontWeight: FontWeight.w700);
  return ThemeData(
    useMaterial3: true,
    colorScheme: ColorScheme.fromSeed(
      seedColor: AppColors.navy,
      primary: AppColors.navy,
      secondary: AppColors.gold,
      surface: Colors.white,
    ),
    scaffoldBackgroundColor: AppColors.surface,
    appBarTheme: const AppBarTheme(
      backgroundColor: AppColors.navy,
      foregroundColor: Colors.white,
      elevation: 0,
      scrolledUnderElevation: 0,
      titleTextStyle: TextStyle(fontSize: 18, fontWeight: FontWeight.w800, color: Colors.white),
      iconTheme: IconThemeData(color: Colors.white),
      actionsIconTheme: IconThemeData(color: Colors.white),
    ),
    inputDecorationTheme: InputDecorationTheme(
      filled: true,
      fillColor: AppColors.inputFill,
      border: border(AppColors.border),
      enabledBorder: border(AppColors.border),
      focusedBorder: border(AppColors.navy, 1.6),
      contentPadding: const EdgeInsets.symmetric(horizontal: 14, vertical: 14),
      labelStyle: const TextStyle(color: AppColors.textMuted),
      prefixIconColor: AppColors.textHint,
    ),
    filledButtonTheme: FilledButtonThemeData(
      style: FilledButton.styleFrom(
        backgroundColor: AppColors.navy,
        foregroundColor: Colors.white,
        minimumSize: const Size(0, 46),
        padding: const EdgeInsets.symmetric(horizontal: 20),
        shape: shape,
        textStyle: buttonText,
      ),
    ),
    outlinedButtonTheme: OutlinedButtonThemeData(
      style: OutlinedButton.styleFrom(
        foregroundColor: AppColors.navy,
        minimumSize: const Size(0, 46),
        padding: const EdgeInsets.symmetric(horizontal: 18),
        side: const BorderSide(color: AppColors.navy, width: 1.2),
        shape: shape,
        textStyle: buttonText,
      ),
    ),
    textButtonTheme: TextButtonThemeData(
      style: TextButton.styleFrom(foregroundColor: AppColors.navy, textStyle: buttonText),
    ),
    chipTheme: const ChipThemeData(
      backgroundColor: Colors.white,
      selectedColor: AppColors.goldLight,
      checkmarkColor: AppColors.navy,
      side: BorderSide(color: AppColors.border),
      labelStyle: TextStyle(fontWeight: FontWeight.w700, color: AppColors.textDark),
      shape: StadiumBorder(),
      padding: EdgeInsets.symmetric(horizontal: 8, vertical: 6),
    ),
    dialogTheme: DialogThemeData(
      backgroundColor: Colors.white,
      surfaceTintColor: Colors.transparent,
      elevation: 12,
      barrierColor: const Color(0x8C0B1A3A),
      actionsPadding: const EdgeInsets.fromLTRB(24, 4, 24, 20),
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
      titleTextStyle: const TextStyle(fontSize: 20, fontWeight: FontWeight.w800, color: AppColors.navy),
    ),
    snackBarTheme: SnackBarThemeData(
      behavior: SnackBarBehavior.floating,
      backgroundColor: AppColors.navyDark,
      elevation: 6,
      insetPadding: const EdgeInsets.fromLTRB(16, 0, 16, 18),
      contentTextStyle: const TextStyle(color: Colors.white, fontSize: 14, fontWeight: FontWeight.w600),
      actionTextColor: AppColors.gold,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(14)),
    ),
    dividerTheme: const DividerThemeData(color: AppColors.border),
  );
}

/// The official UCU seal (same image as the app).
class AdminLogo extends StatelessWidget {
  const AdminLogo({super.key, this.size = 44});

  final double size;

  @override
  Widget build(BuildContext context) {
    return Image.asset(
      'assets/images/ucu_logo.png',
      width: size,
      height: size,
      fit: BoxFit.contain,
      errorBuilder: (context, error, stack) =>
          Icon(Icons.local_parking_rounded, size: size * 0.8, color: AppColors.gold),
    );
  }
}

String str(dynamic v) => v == null ? '' : v.toString();

/// Supabase can return a joined row as an object or a one-item list.
Map<String, dynamic> asOne(dynamic v) {
  if (v is Map) return Map<String, dynamic>.from(v);
  if (v is List && v.isNotEmpty && v.first is Map) {
    return Map<String, dynamic>.from(v.first as Map);
  }
  return <String, dynamic>{};
}

List<Map<String, dynamic>> asMany(dynamic v) {
  if (v is List) {
    return [for (final x in v) if (x is Map) Map<String, dynamic>.from(x)];
  }
  if (v is Map) return [Map<String, dynamic>.from(v)];
  return <Map<String, dynamic>>[];
}

const Map<String, String> kStatusLabels = {
  'pending': 'Pending',
  'under_review': 'Under review',
  'appeal_review': 'Appeal review',
  'declined': 'Declined',
  'approved': 'Approved',
};

const Map<String, String> kDocLabels = {
  'drivers_license': "Driver's License",
  'orcr': 'Vehicle OR/CR',
  'ucu_id': 'UCU ID',
};

String roleLabel(dynamic r) => r == 'employee' ? 'Employee' : 'Student';
String vehicleLabel(dynamic t) => t == 'motorcycle' ? 'Motorcycle' : '4-Wheel';

const List<String> _months = [
  'Jan', 'Feb', 'Mar', 'Apr', 'May', 'Jun',
  'Jul', 'Aug', 'Sep', 'Oct', 'Nov', 'Dec',
];

String fmtDate(dynamic iso, {bool time = true}) {
  if (iso == null) return '-';
  final s = iso.toString();
  final d = DateTime.tryParse(s);
  if (d == null) return s;
  final l = d.toLocal();
  final date = '${_months[l.month - 1]} ${l.day}, ${l.year}';
  if (!time || s.length <= 10) return date;
  final h = l.hour % 12 == 0 ? 12 : l.hour % 12;
  final m = l.minute.toString().padLeft(2, '0');
  return '$date, $h:$m ${l.hour < 12 ? 'AM' : 'PM'}';
}

String fmtSize(dynamic bytes) {
  final b = int.tryParse(str(bytes)) ?? 0;
  if (b < 1024 * 1024) return '${(b / 1024).ceil()} KB';
  return '${(b / (1024 * 1024)).toStringAsFixed(1)} MB';
}

class Pill extends StatelessWidget {
  const Pill(
    this.text, {
    super.key,
    this.bg = AppColors.inputFill,
    this.fg = AppColors.navy,
    this.border = AppColors.border,
  });

  final String text;
  final Color bg;
  final Color fg;
  final Color border;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
      decoration: BoxDecoration(
        color: bg,
        borderRadius: BorderRadius.circular(20),
        border: Border.all(color: border),
      ),
      child: Text(
        text.toUpperCase(),
        style: TextStyle(fontSize: 10.5, fontWeight: FontWeight.w800, letterSpacing: 0.5, color: fg),
      ),
    );
  }
}

Widget statusPill(dynamic status) {
  final s = str(status);
  switch (s) {
    case 'approved':
      return const Pill('Approved', bg: AppColors.successLight, fg: AppColors.success, border: AppColors.success);
    case 'declined':
      return const Pill('Declined', bg: AppColors.errorLight, fg: AppColors.error, border: AppColors.error);
    default:
      return Pill(kStatusLabels[s] ?? s, bg: AppColors.goldLight, fg: AppColors.goldDark, border: AppColors.gold);
  }
}

Widget docStatusPill(dynamic status) {
  switch (str(status)) {
    case 'accepted':
      return const Pill('Accepted', bg: AppColors.successLight, fg: AppColors.success, border: AppColors.success);
    case 'rejected':
      return const Pill('Flagged', bg: AppColors.errorLight, fg: AppColors.error, border: AppColors.error);
    case 'replaced':
      return const Pill('Replaced');
    default:
      return const Pill('New', bg: AppColors.goldLight, fg: AppColors.goldDark, border: AppColors.gold);
  }
}

/// Picks an icon for a section from its title.
IconData sectionIcon(String title) {
  final t = title.toLowerCase();
  const map = <String, IconData>{
    'decline': Icons.cancel_outlined,
    'decision': Icons.gavel_outlined,
    'applicant': Icons.person_outline,
    'profile': Icons.person_outline,
    'vehicle': Icons.directions_car_outlined,
    'document': Icons.description_outlined,
    'appeal': Icons.forum_outlined,
    'permit': Icons.badge_outlined,
    'application': Icons.assignment_outlined,
    'password': Icons.lock_outline,
    'email': Icons.mail_outline,
    'account': Icons.manage_accounts_outlined,
    'action': Icons.bolt_outlined,
    'history': Icons.history,
    'sticker': Icons.qr_code_2,
    'scan': Icons.qr_code_scanner,
    'change': Icons.edit_note,
  };
  for (final e in map.entries) {
    if (t.contains(e.key)) return e.value;
  }
  return Icons.info_outline;
}

class SectionCard extends StatelessWidget {
  const SectionCard({
    super.key,
    required this.title,
    required this.children,
    this.trailing,
    this.icon,
  });

  final String title;
  final List<Widget> children;
  final Widget? trailing;
  final IconData? icon;

  @override
  Widget build(BuildContext context) {
    return Container(
      width: double.infinity,
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: AppColors.border),
        boxShadow: const [BoxShadow(color: Color(0x0D1D3E7C), blurRadius: 12, offset: Offset(0, 4))],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Padding(
            padding: const EdgeInsets.fromLTRB(16, 14, 14, 12),
            child: Row(
              children: [
                Container(
                  width: 32,
                  height: 32,
                  decoration: BoxDecoration(color: AppColors.inputFill, borderRadius: BorderRadius.circular(10)),
                  child: Icon(icon ?? sectionIcon(title), size: 18, color: AppColors.navy),
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: Text(
                    title,
                    style: const TextStyle(fontSize: 15, fontWeight: FontWeight.w800, color: AppColors.navy),
                  ),
                ),
                ?trailing,
              ],
            ),
          ),
          const Divider(height: 1, color: AppColors.inputFill),
          Padding(
            padding: const EdgeInsets.fromLTRB(18, 12, 18, 18),
            child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: children),
          ),
        ],
      ),
    );
  }
}

/// Navy banner at the top of a page, same look as the sidebar.
class PageHeader extends StatelessWidget {
  const PageHeader({
    super.key,
    required this.title,
    this.subtitle,
    this.icon = Icons.dashboard_outlined,
    this.count,
    this.actions = const [],
  });

  final String title;
  final String? subtitle;
  final IconData icon;
  final int? count;

  /// Search boxes and buttons shown on the right (below on phones).
  final List<Widget> actions;

  @override
  Widget build(BuildContext context) {
    final head = Row(
      mainAxisSize: MainAxisSize.min,
      children: [
        Container(
          width: 46,
          height: 46,
          decoration: BoxDecoration(color: AppColors.gold, borderRadius: BorderRadius.circular(13)),
          child: Icon(icon, color: AppColors.navy, size: 24),
        ),
        const SizedBox(width: 14),
        Flexible(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            mainAxisSize: MainAxisSize.min,
            children: [
              Row(
                mainAxisSize: MainAxisSize.min,
                children: [
                  Flexible(
                    child: Text(
                      title,
                      overflow: TextOverflow.ellipsis,
                      style: const TextStyle(fontSize: 22, fontWeight: FontWeight.w800, color: Colors.white),
                    ),
                  ),
                  if (count != null) ...[
                    const SizedBox(width: 10),
                    Container(
                      padding: const EdgeInsets.symmetric(horizontal: 9, vertical: 2),
                      decoration: BoxDecoration(
                        color: Colors.white.withValues(alpha: 0.16),
                        borderRadius: BorderRadius.circular(20),
                      ),
                      child: Text(
                        '$count',
                        style: const TextStyle(fontSize: 12, fontWeight: FontWeight.w800, color: Colors.white),
                      ),
                    ),
                  ],
                ],
              ),
              if (subtitle != null) ...[
                const SizedBox(height: 2),
                Text(subtitle!, style: const TextStyle(fontSize: 13, color: AppColors.blueSoft)),
              ],
            ],
          ),
        ),
      ],
    );
    return Container(
      width: double.infinity,
      clipBehavior: Clip.antiAlias,
      decoration: BoxDecoration(
        borderRadius: BorderRadius.circular(18),
        gradient: const LinearGradient(
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
          colors: [AppColors.navy, AppColors.navyDark],
        ),
        boxShadow: const [BoxShadow(color: Color(0x261D3E7C), blurRadius: 16, offset: Offset(0, 6))],
      ),
      child: Column(
        children: [
          Padding(
            padding: const EdgeInsets.fromLTRB(18, 16, 14, 16),
            child: LayoutBuilder(
              builder: (context, c) {
                if (actions.isEmpty) return Align(alignment: Alignment.centerLeft, child: head);
                if (c.maxWidth < 760) {
                  return Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      head,
                      const SizedBox(height: 12),
                      Wrap(spacing: 8, runSpacing: 8, crossAxisAlignment: WrapCrossAlignment.center, children: actions),
                    ],
                  );
                }
                return Row(
                  children: [
                    Expanded(child: head),
                    const SizedBox(width: 12),
                    Wrap(spacing: 8, runSpacing: 8, crossAxisAlignment: WrapCrossAlignment.center, children: actions),
                  ],
                );
              },
            ),
          ),
          Container(height: 4, color: AppColors.gold),
        ],
      ),
    );
  }
}

/// A search box that sits inside the navy page header.
Widget headerSearch(BuildContext context, {required ValueChanged<String> onChanged, String hint = 'Search'}) {
  return SizedBox(
    width: searchWidth(context),
    child: TextField(
      onChanged: onChanged,
      style: const TextStyle(color: AppColors.textDark),
      decoration: InputDecoration(
        hintText: hint,
        prefixIcon: const Icon(Icons.search),
        isDense: true,
        fillColor: Colors.white,
        enabledBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(12),
          borderSide: BorderSide.none,
        ),
      ),
    ),
  );
}

/// A round refresh button for the navy page header.
Widget headerRefresh(VoidCallback onPressed) {
  return IconButton(
    tooltip: 'Refresh',
    onPressed: onPressed,
    style: IconButton.styleFrom(backgroundColor: Colors.white.withValues(alpha: 0.14)),
    icon: const Icon(Icons.refresh, color: Colors.white),
  );
}

/// Less space around pages on phones.
double pagePadding(BuildContext context) =>
    MediaQuery.sizeOf(context).width < 600 ? 16 : 24;

/// A search box that never gets wider than the screen.
double searchWidth(BuildContext context) {
  final w = MediaQuery.sizeOf(context).width - 64;
  return w < 320 ? w : 320;
}

class InfoRow extends StatelessWidget {
  const InfoRow(this.label, this.value, {super.key, this.mono = false});

  final String label;
  final String value;
  final bool mono;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(vertical: 9),
      decoration: const BoxDecoration(
        border: Border(bottom: BorderSide(color: AppColors.inputFill)),
      ),
      child: LayoutBuilder(
        builder: (context, c) {
          final labelText = Text(label, style: const TextStyle(fontSize: 13, color: AppColors.textHint));
          final valueText = SelectableText(
            value.trim().isEmpty ? '-' : value,
            style: TextStyle(
              fontSize: 14,
              fontWeight: FontWeight.w700,
              color: AppColors.textDark,
              fontFamily: mono ? 'monospace' : null,
            ),
          );
          if (c.maxWidth < 420) {
            return Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [labelText, const SizedBox(height: 2), valueText],
            );
          }
          return Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              SizedBox(width: 160, child: labelText),
              Expanded(child: valueText),
            ],
          );
        },
      ),
    );
  }
}

class PageTitle extends StatelessWidget {
  const PageTitle(this.text, {super.key, this.subtitle, this.icon});

  final String text;
  final String? subtitle;
  final IconData? icon;

  @override
  Widget build(BuildContext context) {
    return PageHeader(title: text, subtitle: subtitle, icon: icon ?? Icons.description_outlined);
  }
}


/// Navy header for every pop-up: icon, title, optional line under it and a
/// gold strip. Use it as the `title` of an AlertDialog with
/// `titlePadding: EdgeInsets.zero` and `clipBehavior: Clip.antiAlias`.
class DialogHeader extends StatelessWidget {
  const DialogHeader({
    super.key,
    required this.icon,
    required this.title,
    this.subtitle,
    this.tone = 'info',
    this.trailing,
  });

  final IconData icon;
  final String title;
  final String? subtitle;

  /// info (gold icon), success (green), danger (red) or warning.
  final String tone;
  final Widget? trailing;

  @override
  Widget build(BuildContext context) {
    final (bg, fg) = switch (tone) {
      'success' => (AppColors.successLight, AppColors.success),
      'danger' => (AppColors.errorLight, AppColors.error),
      'warning' => (AppColors.goldLight, AppColors.goldDark),
      _ => (AppColors.gold, AppColors.navy),
    };
    return Column(
      mainAxisSize: MainAxisSize.min,
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        Container(
          color: AppColors.navy,
          padding: const EdgeInsets.fromLTRB(22, 20, 18, 18),
          child: Row(
            children: [
              Container(
                width: 44,
                height: 44,
                decoration: BoxDecoration(color: bg, shape: BoxShape.circle),
                child: Icon(icon, color: fg, size: 24),
              ),
              const SizedBox(width: 14),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      title,
                      style: const TextStyle(fontSize: 18.5, fontWeight: FontWeight.w800, color: Colors.white),
                    ),
                    if (subtitle != null && subtitle!.isNotEmpty) ...[
                      const SizedBox(height: 2),
                      Text(subtitle!, style: const TextStyle(fontSize: 13, color: AppColors.blueSoft)),
                    ],
                  ],
                ),
              ),
              if (trailing != null) ...[const SizedBox(width: 10), trailing!],
            ],
          ),
        ),
        Container(height: 4, color: tone == 'danger' ? AppColors.error : AppColors.gold),
      ],
    );
  }
}
