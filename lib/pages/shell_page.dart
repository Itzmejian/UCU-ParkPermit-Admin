import 'package:flutter/material.dart';
import '../admin_service.dart';
import '../ui.dart';
import 'applications_page.dart';
import 'dashboard_page.dart';
import 'permits_page.dart';
import 'plate_changes_page.dart';
import 'replacements_page.dart';
import 'support_page.dart';

class ShellPage extends StatefulWidget {
  const ShellPage({super.key, required this.onLogout});

  final Future<void> Function() onLogout;

  @override
  State<ShellPage> createState() => _ShellPageState();
}

class _ShellPageState extends State<ShellPage> {
  int _index = 0;
  final Map<int, String?> _filters = {};
  final Map<int, int> _keys = {};

  static const _dests = [
    ('Dashboard', Icons.dashboard_outlined, Icons.dashboard),
    ('Applications', Icons.assignment_outlined, Icons.assignment),
    ('Permits', Icons.badge_outlined, Icons.badge),
    ('Plate changes', Icons.pin_outlined, Icons.pin),
    ('Replacements', Icons.sync_outlined, Icons.sync),
    ('Support', Icons.support_agent_outlined, Icons.support_agent),
  ];

  /// Opens a page with a filter (used by the Dashboard cards).
  void _open(int page, String? filter) {
    setState(() {
      _index = page;
      _filters[page] = filter;
      _keys[page] = (_keys[page] ?? 0) + 1;
    });
  }

  /// Opening a page from the menu reloads it.
  void _select(int page) {
    setState(() {
      _index = page;
      _keys[page] = (_keys[page] ?? 0) + 1;
    });
  }

  Widget _page(int i) {
    final key = ValueKey('page-$i-${_keys[i] ?? 0}');
    return switch (i) {
      0 => DashboardPage(key: key, onOpen: _open),
      1 => ApplicationsPage(key: key, initialStatus: _filters[1]),
      2 => PermitsPage(key: key, initialFilter: _filters[2]),
      3 => PlateChangesPage(key: key),
      4 => ReplacementsPage(key: key, initialFilter: _filters[4]),
      _ => SupportPage(key: key, initialFilter: _filters[5]),
    };
  }

  Future<void> _confirmLogout() async {
    final ok = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('Log out?'),
        content: const Text('You will need to log in again.'),
        actions: [
          TextButton(onPressed: () => Navigator.pop(ctx, false), child: const Text('Cancel')),
          FilledButton(onPressed: () => Navigator.pop(ctx, true), child: const Text('Log out')),
        ],
      ),
    );
    if (ok == true) await widget.onLogout();
  }

  @override
  Widget build(BuildContext context) {
    return LayoutBuilder(
      builder: (context, c) {
        final wide = c.maxWidth >= 900;
        final extended = c.maxWidth >= 1200;
        final appBar = AppBar(
          titleSpacing: 20,
          title: const Row(
            children: [
              Icon(Icons.local_parking_rounded, color: AppColors.navy),
              SizedBox(width: 8),
              Text('UCU ParkPermit', style: TextStyle(fontWeight: FontWeight.w800)),
              SizedBox(width: 10),
              Text('Security Office', style: TextStyle(fontSize: 14, color: AppColors.textMuted)),
            ],
          ),
          actions: [
            if (wide)
              Center(
                child: Text(
                  AdminService.email ?? '',
                  style: const TextStyle(fontSize: 13, color: AppColors.textMuted),
                ),
              ),
            IconButton(tooltip: 'Log out', icon: const Icon(Icons.logout), onPressed: _confirmLogout),
            const SizedBox(width: 8),
          ],
        );
        final body = _page(_index);

        if (wide) {
          return Scaffold(
            appBar: appBar,
            body: Row(
              children: [
                NavigationRail(
                  extended: extended,
                  labelType: extended ? NavigationRailLabelType.none : NavigationRailLabelType.all,
                  selectedIndex: _index,
                  onDestinationSelected: _select,
                  destinations: [
                    for (final d in _dests)
                      NavigationRailDestination(
                        icon: Icon(d.$2),
                        selectedIcon: Icon(d.$3),
                        label: Text(d.$1),
                      ),
                  ],
                ),
                const VerticalDivider(width: 1),
                Expanded(child: body),
              ],
            ),
          );
        }
        return Scaffold(
          appBar: appBar,
          body: body,
          bottomNavigationBar: NavigationBar(
            selectedIndex: _index,
            onDestinationSelected: _select,
            labelBehavior: NavigationDestinationLabelBehavior.onlyShowSelected,
            destinations: [
              for (final d in _dests)
                NavigationDestination(icon: Icon(d.$2), selectedIcon: Icon(d.$3), label: d.$1),
            ],
          ),
        );
      },
    );
  }
}