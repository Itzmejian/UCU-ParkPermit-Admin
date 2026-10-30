import 'package:flutter/material.dart';
import '../admin_service.dart';
import '../ui.dart';
import 'applications_page.dart';
import 'dashboard_page.dart';

class ShellPage extends StatefulWidget {
  const ShellPage({super.key, required this.onLogout});

  final Future<void> Function() onLogout;

  @override
  State<ShellPage> createState() => _ShellPageState();
}

class _ShellPageState extends State<ShellPage> {
  int _index = 0;
  String? _appFilter;
  int _appsKey = 0;

  void _openApplications(String? status) {
    setState(() {
      _index = 1;
      _appFilter = status;
      _appsKey++;
    });
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
    final pages = <Widget>[
      DashboardPage(onOpenApplications: _openApplications),
      ApplicationsPage(key: ValueKey('apps-$_appsKey'), initialStatus: _appFilter),
    ];
    const dests = [
      ('Dashboard', Icons.dashboard_outlined, Icons.dashboard),
      ('Applications', Icons.assignment_outlined, Icons.assignment),
    ];

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
            IconButton(
              tooltip: 'Log out',
              icon: const Icon(Icons.logout),
              onPressed: _confirmLogout,
            ),
            const SizedBox(width: 8),
          ],
        );
        final body = IndexedStack(index: _index, children: pages);

        if (wide) {
          return Scaffold(
            appBar: appBar,
            body: Row(
              children: [
                NavigationRail(
                  extended: extended,
                  labelType: extended ? NavigationRailLabelType.none : NavigationRailLabelType.all,
                  selectedIndex: _index,
                  onDestinationSelected: (i) => setState(() => _index = i),
                  destinations: [
                    for (final d in dests)
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
            onDestinationSelected: (i) => setState(() => _index = i),
            destinations: [
              for (final d in dests)
                NavigationDestination(icon: Icon(d.$2), selectedIcon: Icon(d.$3), label: d.$1),
            ],
          ),
        );
      },
    );
  }
}