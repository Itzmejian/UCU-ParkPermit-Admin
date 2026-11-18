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
      clipBehavior: Clip.antiAlias,
      decoration: BoxDecoration(
        gradient: const LinearGradient(
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
          colors: [AppColors.navy, AppColors.navyDark],
        ),
        borderRadius: BorderRadius.circular(18),
        boxShadow: const [BoxShadow(color: Color(0x261D3E7C), blurRadius: 16, offset: Offset(0, 6))],
      ),
      child: Column(
        children: [
          Padding(
            padding: const EdgeInsets.fromLTRB(26, 22, 26, 24),
            child: _bannerBody(wide),
          ),
          Container(height: 4, color: AppColors.gold),
        ],
      ),
    );
  }

  Widget _bannerBody(bool wide) {
    return Row(
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
        ],
    );
  }

  /// Section title with an icon and how many items are waiting in it.
  Widget _caption(String text, IconData icon, int waiting) {
    return Row(
      children: [
        Container(
          width: 32,
          height: 32,
          decoration: BoxDecoration(color: AppColors.navy, borderRadius: BorderRadius.circular(10)),
          child: Icon(icon, size: 18, color: AppColors.gold),
        ),
        const SizedBox(width: 12),
        Text(
          text,
          style: const TextStyle(fontSize: 16, fontWeight: FontWeight.w800, color: AppColors.navy),
        ),
        const SizedBox(width: 10),
        if (!_loading)
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 9, vertical: 3),
            decoration: BoxDecoration(
              color: waiting > 0 ? AppColors.goldLight : AppColors.successLight,
              borderRadius: BorderRadius.circular(20),
              border: Border.all(color: waiting > 0 ? AppColors.gold : AppColors.success),
            ),
            child: Text(
              waiting > 0 ? '$waiting waiting' : 'All clear',
              style: TextStyle(
                fontSize: 11.5,
                fontWeight: FontWeight.w800,
                color: waiting > 0 ? AppColors.goldDark : AppColors.success,
              ),
            ),
          ),
        const SizedBox(width: 12),
        const Expanded(child: Divider(color: AppColors.border)),
      ],
    );
  }

  int _sum(List<String> keys) => keys.fold(0, (t, k) => t + (_counts[k] ?? 0));

  double get _cardWidth {
    final w = MediaQuery.sizeOf(context).width;
    return w < 600 ? w - 32 : 262;
  }

  Widget _stat(String label, String key, IconData icon, Color color, int page, String? filter) {
    return SizedBox(
      width: _cardWidth,
      child: _StatCard(
        label: label,
        count: _counts[key] ?? 0,
        loading: _loading,
        icon: icon,
        color: color,
        onTap: () => widget.onOpen(page, filter),
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
                _caption('Applications', Icons.assignment_outlined, _sum(['pending', 'under_review', 'appeal_review'])),
                const SizedBox(height: 14),
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
                _caption('Permits and stickers', Icons.badge_outlined, _sum(['preparing', 'ready', 'plate_changes', 'replacements'])),
                const SizedBox(height: 14),
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
                _caption('Support', Icons.support_agent_outlined, _sum(['tickets'])),
                const SizedBox(height: 14),
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

/// One number on the dashboard. Lifts a little when the mouse is over it.
class _StatCard extends StatefulWidget {
  const _StatCard({
    required this.label,
    required this.count,
    required this.loading,
    required this.icon,
    required this.color,
    required this.onTap,
  });

  final String label;
  final int count;
  final bool loading;
  final IconData icon;
  final Color color;
  final VoidCallback onTap;

  @override
  State<_StatCard> createState() => _StatCardState();
}

class _StatCardState extends State<_StatCard> {
  bool _hover = false;

  @override
  Widget build(BuildContext context) {
    final active = widget.count > 0;
    final c = widget.color;
    return MouseRegion(
      cursor: SystemMouseCursors.click,
      onEnter: (_) => setState(() => _hover = true),
      onExit: (_) => setState(() => _hover = false),
      child: GestureDetector(
        onTap: widget.onTap,
        child: AnimatedContainer(
          duration: const Duration(milliseconds: 150),
          transform: Matrix4.translationValues(0, _hover ? -3 : 0, 0),
          clipBehavior: Clip.antiAlias,
          decoration: BoxDecoration(
            color: Colors.white,
            borderRadius: BorderRadius.circular(16),
            border: Border.all(color: active ? c.withValues(alpha: 0.6) : (_hover ? AppColors.navy.withValues(alpha: 0.4) : AppColors.border)),
            boxShadow: [
              BoxShadow(
                color: const Color(0xFF1D3E7C).withValues(alpha: _hover ? 0.12 : 0.05),
                blurRadius: _hover ? 18 : 10,
                offset: const Offset(0, 5),
              ),
            ],
          ),
          child: IntrinsicHeight(
            child: Row(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                Container(width: 5, color: active ? c : AppColors.inputFill),
                Expanded(
                  child: Padding(
                    padding: const EdgeInsets.fromLTRB(16, 16, 12, 16),
                    child: Row(
                      children: [
                        Container(
                          width: 46,
                          height: 46,
                          decoration: BoxDecoration(
                            color: c.withValues(alpha: 0.12),
                            borderRadius: BorderRadius.circular(13),
                          ),
                          child: Icon(widget.icon, color: c),
                        ),
                        const SizedBox(width: 14),
                        Expanded(
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Text(
                                widget.loading ? '-' : '${widget.count}',
                                style: TextStyle(
                                  fontSize: 28,
                                  fontWeight: FontWeight.w800,
                                  color: active ? c : AppColors.textDark,
                                ),
                              ),
                              Text(widget.label, style: const TextStyle(fontSize: 13, color: AppColors.textMuted)),
                            ],
                          ),
                        ),
                        Icon(Icons.arrow_forward_ios_rounded, size: 14, color: _hover ? AppColors.navy : AppColors.textHint),
                      ],
                    ),
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}
