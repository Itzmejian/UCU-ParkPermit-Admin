import 'package:flutter/material.dart';
import '../ui.dart';

Future<bool> confirmDialog(
  BuildContext context, {
  required String title,
  required String message,
  required String action,
  Color color = AppColors.navy,
}) async {
  final tone = color == AppColors.error
      ? 'danger'
      : (color == AppColors.success ? 'success' : 'info');
  final icon = switch (tone) {
    'danger' => Icons.warning_amber_rounded,
    'success' => Icons.check_circle_outline,
    _ => Icons.help_outline,
  };
  final ok = await showDialog<bool>(
    context: context,
    builder: (ctx) => AlertDialog(
      titlePadding: EdgeInsets.zero,
      clipBehavior: Clip.antiAlias,
      title: DialogHeader(icon: icon, title: title, tone: tone),
      content: SizedBox(
        width: 460,
        child: Text(message, style: const TextStyle(height: 1.5, fontSize: 14.5, color: AppColors.textDark)),
      ),
      actions: [
        OutlinedButton(onPressed: () => Navigator.pop(ctx, false), child: const Text('Cancel')),
        FilledButton.icon(
          style: FilledButton.styleFrom(backgroundColor: color),
          onPressed: () => Navigator.pop(ctx, true),
          icon: Icon(tone == 'danger' ? Icons.delete_outline : Icons.check, size: 18),
          label: Text(action),
        ),
      ],
    ),
  );
  return ok == true;
}

/// A short message at the bottom of the screen, with an icon.
void showSnack(BuildContext context, String message) {
  final lower = message.toLowerCase();
  final bad = lower.contains('could not') ||
      lower.contains('error') ||
      lower.contains('failed') ||
      lower.contains('not allowed') ||
      lower.contains('already') ||
      lower.contains('refresh the page') ||
      lower.contains('try again');
  final messenger = ScaffoldMessenger.of(context);
  messenger.hideCurrentSnackBar();
  messenger.showSnackBar(
    SnackBar(
      backgroundColor: bad ? const Color(0xFF8E1F1F) : AppColors.navyDark,
      duration: Duration(seconds: bad ? 6 : 4),
      showCloseIcon: true,
      closeIconColor: Colors.white70,
      content: Row(
        children: [
          Icon(bad ? Icons.error_outline : Icons.check_circle_outline,
              color: bad ? Colors.white : AppColors.gold, size: 20),
          const SizedBox(width: 12),
          Expanded(child: Text(message)),
        ],
      ),
    ),
  );
}

/// Icon and one-line description for each list page.
const Map<String, (IconData, String)> kPageInfo = {
  'Applications': (Icons.assignment_outlined, 'Review new and renewal permit applications.'),
  'Permits': (Icons.badge_outlined, 'Issued permits, stickers and validity.'),
  'Plate changes': (Icons.pin_outlined, 'Vehicles waiting for a new plate number check.'),
  'Sticker replacements': (Icons.sync_outlined, 'Requests for a new sticker.'),
  'Support': (Icons.support_agent_outlined, 'Messages from applicants and guards.'),
  'Gate scans': (Icons.qr_code_scanner_outlined, 'Every sticker check made by a guard.'),
  'Users': (Icons.people_outline, 'Students and employees with an account.'),
  'Guards': (Icons.shield_outlined, 'Security guard accounts for the campus gate.'),
};

/// Title, search, filter chips and the list, with loading and error states.
class ListPageFrame extends StatelessWidget {
  const ListPageFrame({
    super.key,
    required this.title,
    required this.filters,
    required this.selected,
    required this.onFilter,
    required this.onRefresh,
    required this.loading,
    required this.error,
    required this.emptyText,
    required this.children,
    this.onSearch,
    this.searchHint,
    this.actions = const [],
    this.icon,
    this.subtitle,
    this.top,
  });

  /// Optional block between the filters and the list (for example totals).
  final Widget? top;

  final String title;
  final Map<String, String> filters;
  final String selected;
  final ValueChanged<String> onFilter;
  final VoidCallback onRefresh;
  final bool loading;
  final String? error;
  final String emptyText;
  final List<Widget> children;
  final ValueChanged<String>? onSearch;
  final String? searchHint;

  /// Extra buttons next to the title (for example "Invite guard").
  final List<Widget> actions;
  final IconData? icon;
  final String? subtitle;

  @override
  Widget build(BuildContext context) {
    Widget body;
    if (loading) {
      body = const Center(child: CircularProgressIndicator());
    } else if (error != null) {
      body = Center(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            const Icon(Icons.cloud_off_outlined, size: 44, color: AppColors.error),
            const SizedBox(height: 10),
            Text(error!, textAlign: TextAlign.center, style: const TextStyle(color: AppColors.error)),
            const SizedBox(height: 12),
            OutlinedButton.icon(onPressed: onRefresh, icon: const Icon(Icons.refresh, size: 18), label: const Text('Try again')),
          ],
        ),
      );
    } else if (children.isEmpty) {
      body = Center(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Container(
              width: 72,
              height: 72,
              decoration: const BoxDecoration(color: AppColors.inputFill, shape: BoxShape.circle),
              child: Icon(icon ?? kPageInfo[title]?.$1 ?? Icons.inbox_outlined, size: 34, color: AppColors.navy),
            ),
            const SizedBox(height: 14),
            Text(
              emptyText,
              textAlign: TextAlign.center,
              style: const TextStyle(color: AppColors.textMuted, fontWeight: FontWeight.w600),
            ),
          ],
        ),
      );
    } else {
      body = ListView.separated(
        padding: const EdgeInsets.only(bottom: 16),
        itemCount: children.length,
        separatorBuilder: (context, index) => const SizedBox(height: 10),
        itemBuilder: (context, i) => children[i],
      );
    }

    final info = kPageInfo[title];
    return Padding(
      padding: EdgeInsets.all(pagePadding(context)),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          PageHeader(
            title: title,
            subtitle: subtitle ?? info?.$2,
            icon: icon ?? info?.$1 ?? Icons.list_alt,
            count: loading || error != null ? null : children.length,
            actions: [
              if (onSearch != null) headerSearch(context, onChanged: onSearch!, hint: searchHint ?? 'Search'),
              ...actions,
            ],
          ),
          const SizedBox(height: 16),
          if (filters.length > 1) ...[
            Wrap(
              spacing: 8,
              runSpacing: 8,
              children: [
                for (final e in filters.entries)
                  ChoiceChip(
                    label: Text(e.value),
                    selected: selected == e.key,
                    onSelected: (_) => onFilter(e.key),
                  ),
              ],
            ),
            const SizedBox(height: 14),
          ],
          if (top != null && !loading && error == null) ...[
            top!,
            const SizedBox(height: 14),
          ],
          Expanded(child: body),
        ],
      ),
    );
  }
}

class RowCard extends StatefulWidget {
  const RowCard({super.key, required this.child, this.onTap});

  final Widget child;

  /// Opens the item. The whole card becomes clickable.
  final VoidCallback? onTap;

  @override
  State<RowCard> createState() => _RowCardState();
}

class _RowCardState extends State<RowCard> {
  bool _hover = false;

  @override
  Widget build(BuildContext context) {
    final card = MouseRegion(
      cursor: widget.onTap == null ? MouseCursor.defer : SystemMouseCursors.click,
      onEnter: (_) => setState(() => _hover = true),
      onExit: (_) => setState(() => _hover = false),
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 150),
        padding: const EdgeInsets.all(16),
        decoration: BoxDecoration(
          color: Colors.white,
          borderRadius: BorderRadius.circular(14),
          border: Border.all(color: _hover ? AppColors.navy.withValues(alpha: 0.45) : AppColors.border),
          boxShadow: [
            BoxShadow(
              color: const Color(0xFF1D3E7C).withValues(alpha: _hover ? 0.10 : 0.04),
              blurRadius: _hover ? 16 : 8,
              offset: const Offset(0, 4),
            ),
          ],
        ),
        child: widget.onTap == null
            ? widget.child
            : Row(
                children: [
                  Expanded(child: widget.child),
                  const SizedBox(width: 8),
                  const Icon(Icons.chevron_right, color: AppColors.textHint),
                ],
              ),
      ),
    );
    if (widget.onTap == null) return card;
    return GestureDetector(onTap: widget.onTap, behavior: HitTestBehavior.opaque, child: card);
  }
}

/// A small two-line block: main text and a smaller line under it.
Widget infoCol(String main, String sub, {bool mono = false, Color? subColor, double width = 220}) {
  return SizedBox(
    width: width,
    child: Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          main.isEmpty ? '-' : main,
          style: TextStyle(
            fontWeight: FontWeight.w700,
            color: AppColors.textDark,
            fontFamily: mono ? 'monospace' : null,
          ),
        ),
        Text(sub, style: TextStyle(fontSize: 12, color: subColor ?? AppColors.textHint)),
      ],
    ),
  );
}