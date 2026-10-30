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

  Widget _stat(String label, String key, IconData icon, Color color, int page, String? filter) {
    return SizedBox(
      width: 250,
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
              border: Border.all(color: AppColors.border),
            ),
            child: Row(
              children: [
                Container(
                  width: 46,
                  height: 46,
                  decoration: BoxDecoration(
                    color: color.withValues(alpha: 0.12),
                    borderRadius: BorderRadius.circular(12),
                  ),
                  child: Icon(icon, color: color),
                ),
                const SizedBox(width: 14),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        '${_counts[key] ?? 0}',
                        style: const TextStyle(fontSize: 26, fontWeight: FontWeight.w800, color: AppColors.textDark),
                      ),
                      Text(label, style: const TextStyle(fontSize: 13, color: AppColors.textMuted)),
                    ],
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return RefreshIndicator(
      onRefresh: _load,
      child: ListView(
        padding: const EdgeInsets.all(24),
        children: [
          Row(
            children: [
              const Expanded(child: PageTitle('Dashboard')),
              IconButton(tooltip: 'Refresh', icon: const Icon(Icons.refresh), onPressed: _load),
            ],
          ),
          const SizedBox(height: 16),
          if (_loading)
            const Padding(
              padding: EdgeInsets.all(40),
              child: Center(child: CircularProgressIndicator()),
            )
          else if (_error != null)
            Text(_error!, style: const TextStyle(color: AppColors.error))
          else ...[
            Wrap(
              spacing: 16,
              runSpacing: 16,
              children: [
                _stat('New applications', 'pending', Icons.inbox_outlined, AppColors.goldDark, 1, 'pending'),
                _stat('Under review', 'under_review', Icons.manage_search, AppColors.navy, 1, 'under_review'),
                _stat('Appeals to review', 'appeal_review', Icons.gavel_outlined, AppColors.error, 1, 'appeal_review'),
                _stat('Stickers to prepare', 'preparing', Icons.print_outlined, AppColors.navy, 2, 'preparing'),
                _stat('Stickers ready for pickup', 'ready', Icons.inventory_2_outlined, AppColors.success, 2, 'ready'),
                _stat('Plate changes to verify', 'plate_changes', Icons.pin_outlined, AppColors.goldDark, 3, null),
                _stat('Replacement requests', 'replacements', Icons.sync_outlined, AppColors.goldDark, 4, 'requested'),
                _stat('Open support tickets', 'tickets', Icons.support_agent_outlined, AppColors.navy, 5, 'open'),
              ],
            ),
            const SizedBox(height: 24),
            SectionCard(
              title: 'Needs your action',
              trailing: TextButton(
                onPressed: () => widget.onOpen(1, null),
                child: const Text('See all applications'),
              ),
              children: [
                if (_todo.isEmpty)
                  const Padding(
                    padding: EdgeInsets.symmetric(vertical: 12),
                    child: Text('Nothing to review right now.', style: TextStyle(color: AppColors.textMuted)),
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
  }
}