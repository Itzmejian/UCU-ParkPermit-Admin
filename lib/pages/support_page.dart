import 'package:flutter/material.dart';
import '../admin_service.dart';
import '../ui.dart';
import 'common.dart';
import 'review_widgets.dart';
import 'ticket_page.dart';

class SupportPage extends StatefulWidget {
  const SupportPage({super.key, this.initialFilter});

  final String? initialFilter;

  @override
  State<SupportPage> createState() => _SupportPageState();
}

class _SupportPageState extends State<SupportPage> {
  late String _filter = widget.initialFilter ?? 'open';
  List<Map<String, dynamic>> _rows = [];
  bool _loading = true;
  String? _error;

  static const Map<String, String> _filters = {
    'open': 'Open',
    'answered': 'Answered',
    'closed': 'Closed',
    'all': 'All',
  };

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
      final rows = await AdminService.tickets();
      if (!mounted) return;
      setState(() {
        _rows = rows;
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

  Future<void> _open(List<Map<String, dynamic>> rows, int index) async {
    // Open messages work as a queue: the next one opens after you reply.
    final t = rows[index];
    final queue = t['status'] == 'open' ? _rows.where((x) => x['status'] == 'open').toList() : [t];
    final start = queue.indexWhere((x) => x['id'] == t['id']);
    await Navigator.push(
      context,
      MaterialPageRoute(builder: (_) => TicketPage(queue: queue, index: start < 0 ? 0 : start)),
    );
    _load();
  }

  Widget _statusPill(String s) => switch (s) {
        'answered' => statePill('Answered', 'success'),
        'closed' => statePill('Closed', 'gray'),
        _ => statePill('Open', 'warning'),
      };

  Widget _row(List<Map<String, dynamic>> rows, int i) {
    final t = rows[i];
    final u = asOne(t['user']);
    final hasReply = str(t['reply']).isNotEmpty;
    return RowCard(
      onTap: () => _open(rows, i),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Wrap(
            spacing: 24,
            runSpacing: 12,
            crossAxisAlignment: WrapCrossAlignment.center,
            children: [
              infoCol(str(t['ticket_no']), fmtDate(t['created_at']), mono: true),
              infoCol(str(u['full_name']), str(u['email']), width: 260),
              Pill(str(t['topic'])),
              _statusPill(str(t['status'])),
            ],
          ),
          const SizedBox(height: 10),
          Text(str(t['subject']), style: const TextStyle(fontWeight: FontWeight.w800, color: AppColors.textDark)),
          const SizedBox(height: 4),
          Text(
            str(t['message']),
            maxLines: 2,
            overflow: TextOverflow.ellipsis,
            style: const TextStyle(color: AppColors.textMuted),
          ),
          if (hasReply) ...[
            const SizedBox(height: 8),
            Row(
              children: [
                const Icon(Icons.reply, size: 16, color: AppColors.success),
                const SizedBox(width: 6),
                Text('Replied ${fmtDate(t['replied_at'])}',
                    style: const TextStyle(fontSize: 12, fontWeight: FontWeight.w700, color: AppColors.success)),
              ],
            ),
          ],
        ],
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final rows = _filter == 'all' ? _rows : _rows.where((t) => t['status'] == _filter).toList();
    return ListPageFrame(
      title: 'Support',
      filters: _filters,
      selected: _filter,
      onFilter: (f) => setState(() => _filter = f),
      onRefresh: _load,
      loading: _loading,
      error: _error,
      emptyText: 'No messages here.',
      children: [for (var i = 0; i < rows.length; i++) _row(rows, i)],
    );
  }
}