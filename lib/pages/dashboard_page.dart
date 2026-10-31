import 'package:flutter/material.dart';
import '../admin_service.dart';
import '../ui.dart';
import 'application_detail_page.dart';
import 'applications_page.dart';

class DashboardPage extends StatefulWidget {
  const DashboardPage({super.key, required this.onOpen});

  /// Opens a page of the menu (by index) with a filter.
  final void Function(int page, String? filter) onOpen;

  @override
  State<DashboardPage> createState() => _DashboardPageState();
}

class _DashboardPageState extends State<DashboardPage> {
  Map<String, int> _counts = {};
  List<Map<String, dynamic>> _todo = [];
  bool _loading = true;
  String? _error;

  @override
  void initState() {
    super.initState();
    _load();
  }

  Future<void> _load() async {
    setState(() {
      _loading = true;
      _error = null;
    });
    try {
      final counts = await AdminService.dashboardCounts();
      final apps = await AdminService.applications();
      if (!mounted) return;
      setState(() {
        _counts = counts;
        _todo = apps
            .where((a) => const ['pending', 'under_review', 'appeal_review'].contains(a['status']))
            .take(8)
            .toList();
        _loading = false;
      });
    } catch (e) {
      if (!mounted) return;
      setState(() {
        _error = AdminService.friendly(e);
        _loading = false;
      });
    }
  }

  Future<void> _openApp(String id) async {
    await Navigator.push(
      context,
      MaterialPageRoute(builder: (_) => ApplicationDetailPage(id: id)),
    );
    _load();
  }

  String get _greeting {
    final h = DateTime.now().hour;
    if (h < 12) return 'Good morning';
    if (h < 18) return 'Good afternoon';
    return 'Good evening';
  }

  int get _waiting =>
      (_counts['pending'] ?? 0) +
      (_counts['under_review'] ?? 0) +
      (_counts['appeal_review'] ?? 0) +
      (_counts['plate_changes'] ?? 0) +
      (_counts['replacements'] ?? 0) +
      (_counts['tickets'] ?? 0);

  Widget _banner(bool wide) {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.fromLTRB(26, 22, 26, 26),
      decoration: BoxDecoration(
        gradient: const LinearGradient(
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
          colors: [AppColors.navy, AppColors.navyDark],
        ),
        borderRadius: BorderRadius.circular(22),
      ),
      child: Row(
        children: [
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Container(
                  padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 5),
                  decoration: BoxDecoration(
                    color: Colors.white.withValues(alpha: 0.15),
                    borderRadius: BorderRadius.circular(20),
                  ),
                  child: const Row(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Icon(Icons.shield_outlined, size: 14, color: Colors.white),
                      SizedBox(width: 6),
                      Text(
                        'SECURITY OFFICE',
                        style: TextStyle(fontSize: 10.5, fontWeight: FontWeight.w800, letterSpacing: 0.8, color: Colors.white),
                      ),
                    ],
                  ),
                ),
                const SizedBox(height: 14),
                Text(
                  '$_greeting!',
                  style: const TextStyle(fontSize: 30, fontWeight: FontWeight.w800, color: Colors.white),
                ),
                const SizedBox(height: 4),
                Text(
                  fmtDate(DateTime.now().toIso8601String(), time: false),
                  style: const TextStyle(fontSize: 14, color: AppColors.blueSoft),
                ),
                const SizedBox(height: 10),
                Text(
                  _loading
                      ? 'Loading what needs your attention...'
                      : (_waiting == 0
                          ? 'All caught up. Nothing is waiting right now.'
                          : '$_waiting item${_waiting == 1 ? '' : 's'} need your attention today.'),
                  style: const TextStyle(fontSize: 15, fontWeight: FontWeight.w600, color: AppColors.gold),
                ),
              ],
            ),
          ),
          if (wide) ...[
            const SizedBox(width: 20),
            const AdminLogo(size: 96),
          ],
          IconButton(
            tooltip: 'Refresh',
            onPressed: _load,
            icon: const Icon(Icons.refresh, color: Colors.white),
          ),
        ],
      ),
    );
  }

  Widget _caption(String text) {
    return Text(
      text,
      style: const TextStyle(fontSize: 11.5, fontWeight: FontWeight.w800, letterSpacing: 0.8, color: AppColors.goldDark),
    );
  }

  double get _cardWidth {
    final w = MediaQuery.sizeOf(context).width;
    return w < 600 ? w - 32 : 262;
  }

  Widget _stat(String label, String key, IconData icon, Color color, int page, String? filter) {
    final n = _counts[key] ?? 0;
    final active = n > 0;
    return SizedBox(
      width: _cardWidth,
      child: Material(
        color: Colors.white,
        borderRadius: BorderRadius.circular(16),
        child: InkWell(
          borderRadius: BorderRadius.circular(16),
          onTap: () => widget.onOpen(page, filter),
          child: Container(
            padding: const EdgeInsets.all(18),
            decoration: BoxDecoration(
              borderRadius: BorderRadius.circular(16),
              border: Border.all(
                color: active ? color.withValues(alpha: 0.7) : AppColors.border,
                width: active ? 1.6 : 1,
              ),
            ),
            child: Row(
              children: [
                Container(
                  width: 48,
                  height: 48,
                  decoration: BoxDecoration(
                    color: color.withValues(alpha: 0.12),
                    shape: BoxShape.circle,
                  ),
                  child: Icon(icon, color: color),
                ),
                const SizedBox(width: 14),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        '$n',
                        style: const TextStyle(fontSize: 28, fontWeight: FontWeight.w800, color: AppColors.textDark),
                      ),
                      Text(label, style: const TextStyle(fontSize: 13, color: AppColors.textMuted)),
                    ],
                  ),
                ),
                const Icon(Icons.chevron_right, color: AppColors.textHint),
              ],
            ),
          ),
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return LayoutBuilder(
      builder: (context, c) {
        return RefreshIndicator(
          onRefresh: _load,
          child: ListView(
            padding: EdgeInsets.all(pagePadding(context)),
            children: [
              _banner(c.maxWidth >= 800),
              const SizedBox(height: 24),
              if (_error != null)
                Text(_error!, style: const TextStyle(color: AppColors.error))
              else ...[
                _caption('APPLICATIONS'),
                const SizedBox(height: 10),
                Wrap(
                  spacing: 16,
                  runSpacing: 16,
                  children: [
                    _stat('New applications', 'pending', Icons.inbox_outlined, AppColors.goldDark, 1, 'pending'),
                    _stat('Under review', 'under_review', Icons.manage_search, AppColors.navy, 1, 'under_review'),
                    _stat('Appeals to review', 'appeal_review', Icons.gavel_outlined, AppColors.error, 1, 'appeal_review'),
                  ],
                ),
                const SizedBox(height: 24),
                _caption('PERMITS AND STICKERS'),
                const SizedBox(height: 10),
                Wrap(
                  spacing: 16,
                  runSpacing: 16,
                  children: [
                    _stat('Stickers to prepare', 'preparing', Icons.print_outlined, AppColors.navy, 2, 'preparing'),
                    _stat('Ready for pickup', 'ready', Icons.inventory_2_outlined, AppColors.success, 2, 'ready'),
                    _stat('Plate changes to verify', 'plate_changes', Icons.pin_outlined, AppColors.goldDark, 3, null),
                    _stat('Replacement requests', 'replacements', Icons.sync_outlined, AppColors.goldDark, 4, 'requested'),
                  ],
                ),
                const SizedBox(height: 24),
                _caption('SUPPORT'),
                const SizedBox(height: 10),
                Wrap(
                  spacing: 16,
                  runSpacing: 16,
                  children: [
                    _stat('Open support tickets', 'tickets', Icons.support_agent_outlined, AppColors.navy, 5, 'open'),
                  ],
                ),
                const SizedBox(height: 28),
                SectionCard(
                  title: 'Needs your action',
                  trailing: TextButton(
                    onPressed: () => widget.onOpen(1, null),
                    child: const Text('See all applications'),
                  ),
                  children: [
                    if (_loading)
                      const Padding(
                        padding: EdgeInsets.all(20),
                        child: Center(child: CircularProgressIndicator()),
                      )
                    else if (_todo.isEmpty)
                      const Padding(
                        padding: EdgeInsets.symmetric(vertical: 12),
                        child: Row(
                          children: [
                            Icon(Icons.check_circle_outline, color: AppColors.success),
                            SizedBox(width: 10),
                            Text('Nothing to review right now.', style: TextStyle(color: AppColors.textMuted)),
                          ],
                        ),
                      )
                    else
                      for (final a in _todo)
                        Padding(
                          padding: const EdgeInsets.only(bottom: 8),
                          child: ApplicationRow(app: a, onTap: () => _openApp(str(a['id']))),
                        ),
                  ],
                ),
              ],
            ],
          ),
        );
      },
    );
  }
}