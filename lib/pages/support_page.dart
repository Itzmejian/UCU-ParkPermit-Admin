import 'package:flutter/material.dart';
import '../admin_service.dart';
import '../ui.dart';
import 'common.dart';

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
  String? _busyId;

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

  Future<void> _reply(Map<String, dynamic> t) async {
    final ctrl = TextEditingController(text: str(t['reply']));
    final text = await showDialog<String>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: Text('Reply to ${str(t['ticket_no'])}'),
        content: SizedBox(
          width: 520,
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(str(t['subject']), style: const TextStyle(fontWeight: FontWeight.w700)),
              const SizedBox(height: 6),
              Text(str(t['message']), style: const TextStyle(color: AppColors.textMuted)),
              const SizedBox(height: 14),
              TextField(
                controller: ctrl,
                maxLines: 6,
                maxLength: 1000,
                decoration: const InputDecoration(
                  hintText: 'Write your reply. The applicant will see it in their notifications.',
                ),
              ),
            ],
          ),
        ),
        actions: [
          TextButton(onPressed: () => Navigator.pop(ctx), child: const Text('Cancel')),
          FilledButton(
            onPressed: () => Navigator.pop(ctx, ctrl.text.trim()),
            child: const Text('Send reply'),
          ),
        ],
      ),
    );
    if (text == null || text.isEmpty || !mounted) return;
    setState(() => _busyId = str(t['id']));
    final err = await AdminService.replyTicket(str(t['id']), text);
    if (!mounted) return;
    setState(() => _busyId = null);
    showSnack(context, err ?? 'Reply sent. The applicant was notified.');
    _load();
  }

  Future<void> _close(Map<String, dynamic> t) async {
    final ok = await confirmDialog(
      context,
      title: 'Close this ticket?',
      message: 'Close ${str(t['ticket_no'])} when the concern is resolved.',
      action: 'Close ticket',
    );
    if (!ok || !mounted) return;
    setState(() => _busyId = str(t['id']));
    final err = await AdminService.closeTicket(str(t['id']));
    if (!mounted) return;
    setState(() => _busyId = null);
    showSnack(context, err ?? 'Ticket closed.');
    _load();
  }

  Widget _statusPill(String s) {
    switch (s) {
      case 'answered':
        return const Pill('Answered', bg: AppColors.successLight, fg: AppColors.success, border: AppColors.success);
      case 'closed':
        return const Pill('Closed');
      default:
        return const Pill('Open', bg: AppColors.goldLight, fg: AppColors.goldDark, border: AppColors.gold);
    }
  }

  Widget _row(Map<String, dynamic> t) {
    final u = asOne(t['user']);
    final busy = _busyId == str(t['id']);
    final closed = t['status'] == 'closed';
    final hasReply = str(t['reply']).isNotEmpty;
    return RowCard(
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
          SelectableText(str(t['message']), style: const TextStyle(color: AppColors.textMuted)),
          if (hasReply) ...[
            const SizedBox(height: 10),
            Container(
              width: double.infinity,
              padding: const EdgeInsets.all(12),
              decoration: BoxDecoration(
                color: AppColors.inputFill,
                borderRadius: BorderRadius.circular(10),
                border: Border.all(color: AppColors.border),
              ),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text('Your reply  |  ${fmtDate(t['replied_at'])}',
                      style: const TextStyle(fontSize: 12, fontWeight: FontWeight.w700, color: AppColors.navy)),
                  const SizedBox(height: 4),
                  Text(str(t['reply'])),
                ],
              ),
            ),
          ],
          if (!closed) ...[
            const SizedBox(height: 12),
            Wrap(
              spacing: 10,
              children: [
                FilledButton.icon(
                  onPressed: busy ? null : () => _reply(t),
                  icon: const Icon(Icons.reply, size: 18),
                  label: Text(hasReply ? 'Edit reply' : 'Reply'),
                ),
                OutlinedButton.icon(
                  onPressed: busy ? null : () => _close(t),
                  icon: const Icon(Icons.done_all, size: 18),
                  label: const Text('Close ticket'),
                ),
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
      children: [for (final t in rows) _row(t)],
    );
  }
}