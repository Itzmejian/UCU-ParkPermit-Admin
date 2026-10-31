import 'package:flutter/material.dart';
import '../admin_service.dart';
import '../ui.dart';
import 'applications_page.dart';
import 'dashboard_page.dart';
import 'permits_page.dart';
import 'plate_changes_page.dart';
import 'replacements_page.dart';
import 'scan_log_page.dart';
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
  Map<String, int> _counts = {};

  static const _dests = [
    ('Dashboard', Icons.dashboard_outlined, Icons.dashboard),
    ('Applications', Icons.assignment_outlined, Icons.assignment),
    ('Permits', Icons.badge_outlined, Icons.badge),
    ('Plate changes', Icons.pin_outlined, Icons.pin),
    ('Replacements', Icons.sync_outlined, Icons.sync),
    ('Support', Icons.support_agent_outlined, Icons.support_agent),
    ('Gate scans', Icons.qr_code_scanner_outlined, Icons.qr_code_scanner),
  ];

  @override
  void initState() {
    super.initState();
    _loadCounts();
  }

  Future<void> _loadCounts() async {
    try {
      final c = await AdminService.dashboardCounts();
      if (mounted) setState(() => _counts = c);
    } catch (_) {}
  }

  int _badge(int i) {
    return switch (i) {
      1 => (_counts['pending'] ?? 0) + (_counts['appeal_review'] ?? 0),
      2 => _counts['preparing'] ?? 0,
      3 => _counts['plate_changes'] ?? 0,
      4 => _counts['replacements'] ?? 0,
      5 => _counts['tickets'] ?? 0,
      _ => 0,
    };
  }

  /// Opens a page with a filter (used by the Dashboard cards).
  void _open(int page, String? filter) {
    setState(() {
      _index = page;
      _filters[page] = filter;
      _keys[page] = (_keys[page] ?? 0) + 1;
    });
    _loadCounts();
  }

  /// Opening a page from the menu reloads it.
  void _select(int page) {
    setState(() {
      _index = page;
      _keys[page] = (_keys[page] ?? 0) + 1;
    });
    _loadCounts();
  }

  Widget _page(int i) {
    final key = ValueKey('page-$i-${_keys[i] ?? 0}');
    return switch (i) {
      0 => DashboardPage(key: key, onOpen: _open),
      1 => ApplicationsPage(key: key, initialStatus: _filters[1]),
      2 => PermitsPage(key: key, initialFilter: _filters[2]),
      3 => PlateChangesPage(key: key),
      4 => ReplacementsPage(key: key, initialFilter: _filters[4]),
      5 => SupportPage(key: key, initialFilter: _filters[5]),
      _ => ScanLogPage(key: key),
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

  String get _initial {
    final e = AdminService.email ?? '';
    return e.isEmpty ? 'A' : e[0].toUpperCase();
  }

  Widget _navItem(int i, bool compact, VoidCallback? onPicked) {
    final d = _dests[i];
    final sel = _index == i;
    final count = _badge(i);
    final icon = Icon(sel ? d.$3 : d.$2, color: sel ? AppColors.navy : Colors.white, size: 22);

    Widget content;
    if (compact) {
      content = Center(
        child: Badge(
          isLabelVisible: count > 0,
          label: Text('$count'),
          backgroundColor: AppColors.gold,
          textColor: AppColors.navy,
          child: icon,
        ),
      );
    } else {
      content = Row(
        children: [
          icon,
          const SizedBox(width: 14),
          Expanded(
            child: Text(
              d.$1,
              style: TextStyle(
                color: sel ? AppColors.navy : Colors.white,
                fontWeight: sel ? FontWeight.w800 : FontWeight.w600,
                fontSize: 14,
              ),
            ),
          ),
          if (count > 0)
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 2),
              decoration: BoxDecoration(color: AppColors.gold, borderRadius: BorderRadius.circular(10)),
              child: Text(
                '$count',
                style: const TextStyle(fontSize: 11, fontWeight: FontWeight.w800, color: AppColors.navy),
              ),
            ),
        ],
      );
    }

    final tile = Material(
      color: sel ? Colors.white : Colors.transparent,
      borderRadius: BorderRadius.circular(12),
      child: InkWell(
        borderRadius: BorderRadius.circular(12),
        onTap: () {
          _select(i);
          onPicked?.call();
        },
        child: Padding(
          padding: EdgeInsets.symmetric(horizontal: compact ? 0 : 14, vertical: 12),
          child: content,
        ),
      ),
    );

    return Padding(
      padding: const EdgeInsets.only(bottom: 4),
      child: compact ? Tooltip(message: d.$1, child: tile) : tile,
    );
  }

  Widget _sidebar({required bool compact, VoidCallback? onPicked}) {
    final line = Divider(color: Colors.white.withValues(alpha: 0.12), height: 1);
    return Container(
      width: compact ? 84 : 260,
      decoration: const BoxDecoration(
        gradient: LinearGradient(
          begin: Alignment.topCenter,
          end: Alignment.bottomCenter,
          colors: [AppColors.navy, AppColors.navyDark],
        ),
      ),
      child: SafeArea(
        child: Column(
          children: [
            Padding(
              padding: EdgeInsets.fromLTRB(compact ? 12 : 20, 22, compact ? 12 : 20, 18),
              child: compact
                  ? const AdminLogo(size: 44)
                  : const Row(
                      children: [
                        AdminLogo(size: 44),
                        SizedBox(width: 12),
                        Expanded(
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Text(
                                'UCU ParkPermit',
                                style: TextStyle(color: Colors.white, fontSize: 17, fontWeight: FontWeight.w800),
                              ),
                              SizedBox(height: 2),
                              Text(
                                'SECURITY OFFICE',
                                style: TextStyle(
                                  color: AppColors.gold,
                                  fontSize: 10.5,
                                  fontWeight: FontWeight.w800,
                                  letterSpacing: 1,
                                ),
                              ),
                            ],
                          ),
                        ),
                      ],
                    ),
            ),
            line,
            const SizedBox(height: 12),
            Expanded(
              child: ListView(
                padding: EdgeInsets.symmetric(horizontal: compact ? 10 : 12),
                children: [for (var i = 0; i < _dests.length; i++) _navItem(i, compact, onPicked)],
              ),
            ),
            line,
            Padding(
              padding: EdgeInsets.all(compact ? 10 : 16),
              child: compact
                  ? IconButton(
                      tooltip: 'Log out',
                      onPressed: _confirmLogout,
                      icon: const Icon(Icons.logout, color: Colors.white70),
                    )
                  : Row(
                      children: [
                        CircleAvatar(
                          radius: 18,
                          backgroundColor: AppColors.gold,
                          child: Text(
                            _initial,
                            style: const TextStyle(color: AppColors.navy, fontWeight: FontWeight.w800),
                          ),
                        ),
                        const SizedBox(width: 10),
                        Expanded(
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              const Text(
                                'Admin',
                                style: TextStyle(color: Colors.white, fontWeight: FontWeight.w800, fontSize: 13),
                              ),
                              Text(
                                AdminService.email ?? '',
                                maxLines: 1,
                                overflow: TextOverflow.ellipsis,
                                style: const TextStyle(color: AppColors.blueSoft, fontSize: 11.5),
                              ),
                            ],
                          ),
                        ),
                        IconButton(
                          tooltip: 'Log out',
                          onPressed: _confirmLogout,
                          icon: const Icon(Icons.logout, color: Colors.white70),
                        ),
                      ],
                    ),
            ),
          ],
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return LayoutBuilder(
      builder: (context, c) {
        final body = _page(_index);
        if (c.maxWidth >= 900) {
          return Scaffold(
            body: Row(
              children: [
                _sidebar(compact: c.maxWidth < 1200),
                Expanded(child: body),
              ],
            ),
          );
        }
        return Scaffold(
          appBar: AppBar(
            backgroundColor: AppColors.navy,
            foregroundColor: Colors.white,
            titleTextStyle: const TextStyle(fontSize: 18, fontWeight: FontWeight.w800, color: Colors.white),
            title: Row(
              children: [
                const AdminLogo(size: 30),
                const SizedBox(width: 10),
                Text(_dests[_index].$1),
              ],
            ),
          ),
          drawer: Drawer(
            width: 270,
            child: Builder(
              builder: (ctx) => _sidebar(
                compact: false,
                onPicked: () => Scaffold.of(ctx).closeDrawer(),
              ),
            ),
          ),
          body: body,
        );
      },
    );
  }
}