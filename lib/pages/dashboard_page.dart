import 'package:flutter/material.dart';
import '../admin_service.dart';
import '../ui.dart';
import 'start_review.dart';

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
  int _scansToday = 0;
  int _problemsToday = 0;
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
      var scans = <Map<String, dynamic>>[];
      try {
        scans = await AdminService.gateScans();
      } catch (_) {}
      if (!mounted) return;
      final now = DateTime.now();
      final today = scans.where((x) {
        final d = DateTime.tryParse(str(x['created_at']))?.toLocal();
        return d != null && d.year == now.year && d.month == now.month && d.day == now.day;
      }).toList();
      setState(() {
        _counts = counts;
        _scansToday = today.length;
        _problemsToday = today.where((x) => x['result'] != 'valid').length;
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
    final opened = await openApplication(context, id);
    if (opened && mounted) _load();
  }

  /// Opens the oldest application that still needs a decision.
  Future<void> _reviewNext() async {
    String? id;
    try {
      id = await AdminService.nextWaiting('00000000-0000-0000-0000-000000000000');
    } catch (_) {}
    if (!mounted) return;
    if (id == null) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('No applications are waiting. Nice work!')),
      );
      return;
    }
    _openApp(id);
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

  Widget Function(bool) _stat(String label, int count, IconData icon, Color color, int page, String? filter) {
    return (compact) => _StatCard(
      compact: compact,
      label: label,
      count: count,
      loading: _loading,
      icon: icon,
      color: color,
      onTap: () => widget.onOpen(page, filter),
    );
  }

  /// Cards in even columns that always fill the full width.
  Widget _grid(List<Widget Function(bool)> cards, {int maxColumns = 4}) {
    return LayoutBuilder(
      builder: (context, c) {
        final w = c.maxWidth;
        var cols = w >= 900 ? 4 : (w >= 640 ? 3 : 2);
        if (cols > maxColumns) cols = maxColumns;
        if (cols > cards.length) cols = cards.length;
        final compact = (w - 14 * (cols - 1)) / cols < 200;
        final rows = <Widget>[];
        for (var i = 0; i < cards.length; i += cols) {
          final slice = cards.sublist(i, (i + cols).clamp(0, cards.length));
          rows.add(Padding(
            padding: EdgeInsets.only(bottom: i + cols < cards.length ? 14 : 0),
            child: IntrinsicHeight(
              child: Row(
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  for (var j = 0; j < cols; j++) ...[
                    if (j > 0) const SizedBox(width: 14),
                    Expanded(child: j < slice.length ? slice[j](compact) : const SizedBox.shrink()),
                  ],
                ],
              ),
            ),
          ));
        }
        return Column(children: rows);
      },
    );
  }

  List<Widget> _sections() {
    return [
      _caption('Applications', Icons.assignment_outlined, _sum(['pending', 'under_review', 'appeal_review'])),
      const SizedBox(height: 14),
      _grid([
        _stat('New applications', _counts['pending'] ?? 0, Icons.inbox_outlined, AppColors.goldDark, 1, 'pending'),
        _stat('Under review', _counts['under_review'] ?? 0, Icons.manage_search, AppColors.navy, 1, 'under_review'),
        _stat('Appeals to review', _counts['appeal_review'] ?? 0, Icons.gavel_outlined, AppColors.error, 1, 'appeal_review'),
      ], maxColumns: 3),
      const SizedBox(height: 26),
      _caption('Permits and stickers', Icons.badge_outlined, _sum(['preparing', 'ready', 'plate_changes', 'replacements'])),
      const SizedBox(height: 14),
      _grid([
        _stat('Stickers to prepare', _counts['preparing'] ?? 0, Icons.print_outlined, AppColors.navy, 2, 'preparing'),
        _stat('Ready for pickup', _counts['ready'] ?? 0, Icons.inventory_2_outlined, AppColors.success, 2, 'ready'),
        _stat('Plate changes', _counts['plate_changes'] ?? 0, Icons.pin_outlined, AppColors.goldDark, 3, null),
        _stat('Replacements', _counts['replacements'] ?? 0, Icons.sync_outlined, AppColors.goldDark, 4, 'requested'),
      ]),
      const SizedBox(height: 26),
      _caption('Support and gate', Icons.support_agent_outlined, _sum(['tickets']) + _problemsToday),
      const SizedBox(height: 14),
      _grid([
        _stat('Open support messages', _counts['tickets'] ?? 0, Icons.support_agent_outlined, AppColors.navy, 5, 'open'),
        _stat('Gate scans today', _scansToday, Icons.qr_code_scanner, AppColors.success, 6, 'today'),
        _stat('Gate problems today', _problemsToday, Icons.report_gmailerrorred_outlined, AppColors.error, 6, 'problem'),
      ], maxColumns: 3),
    ];
  }

  Widget _todoTile(Map<String, dynamic> a) {
    final p = asOne(a['applicant']);
    final v = asOne(a['vehicle']);
    return Material(
      color: AppColors.surface,
      borderRadius: BorderRadius.circular(12),
      child: InkWell(
        borderRadius: BorderRadius.circular(12),
        onTap: () => _openApp(str(a['id'])),
        child: Container(
          padding: const EdgeInsets.fromLTRB(12, 10, 8, 10),
          decoration: BoxDecoration(
            borderRadius: BorderRadius.circular(12),
            border: Border.all(color: AppColors.border),
          ),
          child: Row(
            children: [
              CircleAvatar(
                radius: 18,
                backgroundColor: AppColors.inputFill,
                child: Icon(
                  v['vehicle_type'] == 'motorcycle' ? Icons.two_wheeler : Icons.directions_car_outlined,
                  size: 18,
                  color: AppColors.navy,
                ),
              ),
              const SizedBox(width: 10),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(str(p['full_name']).isEmpty ? '(no name)' : str(p['full_name']),
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                        style: const TextStyle(fontWeight: FontWeight.w700, color: AppColors.textDark)),
                    Text('${str(a['reference_no'])}  |  ${str(v['plate_number'])}',
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                        style: const TextStyle(fontSize: 12, color: AppColors.textHint, fontFamily: 'monospace')),
                  ],
                ),
              ),
              const SizedBox(width: 8),
              statusPill(a['status']),
              const Icon(Icons.chevron_right, color: AppColors.textHint),
            ],
          ),
        ),
      ),
    );
  }

  Widget _todoCard() {
    return SectionCard(
      title: 'Needs your action',
      trailing: TextButton(onPressed: () => widget.onOpen(1, null), child: const Text('See all')),
      children: [
        if (_loading)
          const Padding(padding: EdgeInsets.all(20), child: Center(child: CircularProgressIndicator()))
        else if (_todo.isEmpty)
          Container(
            width: double.infinity,
            padding: const EdgeInsets.symmetric(vertical: 22, horizontal: 12),
            decoration: BoxDecoration(color: AppColors.successLight, borderRadius: BorderRadius.circular(12)),
            child: const Column(
              children: [
                Icon(Icons.task_alt, size: 36, color: AppColors.success),
                SizedBox(height: 8),
                Text('Nothing to review right now.',
                    style: TextStyle(fontWeight: FontWeight.w700, color: AppColors.success)),
                SizedBox(height: 2),
                Text('New applications will appear here.', style: TextStyle(fontSize: 12.5, color: AppColors.textMuted)),
              ],
            ),
          )
        else
          for (final a in _todo)
            Padding(padding: const EdgeInsets.only(bottom: 8), child: _todoTile(a)),
      ],
    );
  }

  Widget _quickActions() {
    Widget action(IconData icon, String label, String sub, VoidCallback onTap) {
      return Padding(
        padding: const EdgeInsets.only(bottom: 8),
        child: Material(
          color: AppColors.inputFill,
          borderRadius: BorderRadius.circular(12),
          child: InkWell(
            borderRadius: BorderRadius.circular(12),
            onTap: onTap,
            child: Padding(
              padding: const EdgeInsets.all(12),
              child: Row(
                children: [
                  Container(
                    width: 36,
                    height: 36,
                    decoration: BoxDecoration(color: AppColors.navy, borderRadius: BorderRadius.circular(10)),
                    child: Icon(icon, size: 18, color: AppColors.gold),
                  ),
                  const SizedBox(width: 12),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(label, style: const TextStyle(fontWeight: FontWeight.w700, color: AppColors.navy)),
                        Text(sub, style: const TextStyle(fontSize: 12, color: AppColors.textMuted)),
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

    return SectionCard(
      title: 'Quick actions',
      icon: Icons.bolt_outlined,
      children: [
        action(Icons.play_arrow_rounded, 'Review the next application', 'Opens the oldest one waiting', _reviewNext),
        action(Icons.print_outlined, 'Prepare stickers', 'Approved permits waiting for a sticker', () => widget.onOpen(2, 'preparing')),
        action(Icons.shield_outlined, 'Manage guards', 'Invite, edit or remove guard accounts', () => widget.onOpen(8, null)),
        action(Icons.qr_code_scanner, 'See gate scans', 'Every sticker check at the gate', () => widget.onOpen(6, null)),
      ],
    );
  }

  @override
  Widget build(BuildContext context) {
    return LayoutBuilder(
      builder: (context, c) {
        final wide = c.maxWidth >= 1200;
        final pad = pagePadding(context);
        final List<Widget> body;
        if (_error != null) {
          body = [
            Container(
              padding: const EdgeInsets.all(16),
              decoration: BoxDecoration(color: AppColors.errorLight, borderRadius: BorderRadius.circular(12)),
              child: Row(
                children: [
                  const Icon(Icons.cloud_off_outlined, color: AppColors.error),
                  const SizedBox(width: 10),
                  Expanded(child: Text(_error!, style: const TextStyle(color: AppColors.error))),
                  TextButton(onPressed: _load, child: const Text('Try again')),
                ],
              ),
            ),
          ];
        } else if (wide) {
          body = [
            Row(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Expanded(flex: 8, child: Column(children: _sections())),
                const SizedBox(width: 22),
                Expanded(
                  flex: 4,
                  child: Column(
                    children: [_todoCard(), const SizedBox(height: 16), _quickActions()],
                  ),
                ),
              ],
            ),
          ];
        } else {
          body = [
            ..._sections(),
            const SizedBox(height: 26),
            _todoCard(),
            const SizedBox(height: 16),
            _quickActions(),
          ];
        }
        return RefreshIndicator(
          onRefresh: _load,
          child: ListView(
            padding: EdgeInsets.all(pad),
            children: [
              _banner(c.maxWidth >= 800),
              const SizedBox(height: 24),
              ...body,
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
    required this.compact,
    required this.label,
    required this.count,
    required this.loading,
    required this.icon,
    required this.color,
    required this.onTap,
  });

  /// Small layout (icon on top) for narrow cards, for example on phones.
  final bool compact;
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
          child: Builder(
            builder: (context) {
              final narrow = widget.compact;
              final count = Text(
                widget.loading ? '-' : '${widget.count}',
                style: TextStyle(
                  fontSize: narrow ? 24 : 28,
                  fontWeight: FontWeight.w800,
                  color: active ? c : AppColors.textDark,
                ),
              );
              final label = Text(widget.label, style: const TextStyle(fontSize: 13, color: AppColors.textMuted));
              final iconBox = Container(
                width: narrow ? 38 : 46,
                height: narrow ? 38 : 46,
                decoration: BoxDecoration(
                  color: c.withValues(alpha: 0.12),
                  borderRadius: BorderRadius.circular(12),
                ),
                child: Icon(widget.icon, color: c, size: narrow ? 20 : 24),
              );
              final content = narrow
                  ? Padding(
                      padding: const EdgeInsets.fromLTRB(12, 12, 10, 12),
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Row(
                            children: [
                              iconBox,
                              const Spacer(),
                              Icon(Icons.arrow_forward_ios_rounded, size: 13, color: _hover ? AppColors.navy : AppColors.textHint),
                            ],
                          ),
                          const SizedBox(height: 10),
                          count,
                          label,
                        ],
                      ),
                    )
                  : Padding(
                      padding: const EdgeInsets.fromLTRB(16, 16, 12, 16),
                      child: Row(
                        children: [
                          iconBox,
                          const SizedBox(width: 14),
                          Expanded(
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              mainAxisAlignment: MainAxisAlignment.center,
                              children: [count, label],
                            ),
                          ),
                          Icon(Icons.arrow_forward_ios_rounded, size: 14, color: _hover ? AppColors.navy : AppColors.textHint),
                        ],
                      ),
                    );
              return Stack(
                children: [
                  Positioned(left: 0, top: 0, bottom: 0, child: Container(width: 5, color: active ? c : AppColors.inputFill)),
                  Padding(padding: const EdgeInsets.only(left: 5), child: content),
                ],
              );
            },
          ),
        ),
      ),
    );
  }
}
