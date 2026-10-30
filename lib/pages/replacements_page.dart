import 'package:flutter/material.dart';
import '../admin_service.dart';
import '../ui.dart';
import 'common.dart';

class ReplacementsPage extends StatefulWidget {
  const ReplacementsPage({super.key, this.initialFilter});

  final String? initialFilter;

  @override
  State<ReplacementsPage> createState() => _ReplacementsPageState();
}

class _ReplacementsPageState extends State<ReplacementsPage> {
  late String _filter = widget.initialFilter ?? 'requested';
  List<Map<String, dynamic>> _rows = [];
  bool _loading = true;
  String? _error;
  String? _busyId;

  static const Map<String, String> _filters = {
    'requested': 'Waiting',
    'approved': 'Approved',
    'rejected': 'Rejected',
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
      final rows = await AdminService.replacements();
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

  Future<void> _decide(Map<String, dynamic> r, bool approve) async {
    final permit = asOne(r['permit']);
    final ok = await confirmDialog(
      context,
      title: approve ? 'Approve the replacement?' : 'Reject the replacement?',
      message: approve
          ? 'A new sticker for ${str(permit['permit_no'])} will be prepared, and the applicant will be notified.'
          : 'The applicant will be asked to visit the Security Office for details.',
      action: approve ? 'Approve' : 'Reject',
      color: approve ? AppColors.success : AppColors.error,
    );
    if (!ok || !mounted) return;
    setState(() => _busyId = str(r['id']));
    final err = await AdminService.replacementDecision(str(r['id']), approve);
    if (!mounted) return;
    setState(() => _busyId = null);
    showSnack(context, err ?? 'Done. The applicant was notified.');
    _load();
  }

  Widget _statusPill(String s) {
    switch (s) {
      case 'approved':
        return const Pill('Approved', bg: AppColors.successLight, fg: AppColors.success, border: AppColors.success);
      case 'rejected':
        return const Pill('Rejected', bg: AppColors.errorLight, fg: AppColors.error, border: AppColors.error);
      default:
        return const Pill('Waiting', bg: AppColors.goldLight, fg: AppColors.goldDark, border: AppColors.gold);
    }
  }

  Widget _row(Map<String, dynamic> r) {
    final permit = asOne(r['permit']);
    final v = asOne(permit['vehicle']);
    final o = asOne(r['owner']);
    final busy = _busyId == str(r['id']);
    final waiting = r['status'] == 'requested';
    return RowCard(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Wrap(
            spacing: 24,
            runSpacing: 12,
            crossAxisAlignment: WrapCrossAlignment.center,
            children: [
              infoCol(str(permit['permit_no']), fmtDate(r['created_at']), mono: true),
              infoCol(str(o['full_name']), '${roleLabel(o['role'])}  |  ${str(o['id_number'])}'),
              infoCol(str(v['plate_number']), str(v['make_model']), mono: true),
              _statusPill(str(r['status'])),
            ],
          ),
          const SizedBox(height: 10),
          Text('Reason: ${str(r['reason'])}', style: const TextStyle(fontWeight: FontWeight.w700)),
          if (str(r['details']).isNotEmpty)
            Padding(
              padding: const EdgeInsets.only(top: 4),
              child: Text(str(r['details']), style: const TextStyle(color: AppColors.textMuted)),
            ),
          if (waiting) ...[
            const SizedBox(height: 12),
            Wrap(
              spacing: 10,
              children: [
                FilledButton.icon(
                  style: FilledButton.styleFrom(backgroundColor: AppColors.success),
                  onPressed: busy ? null : () => _decide(r, true),
                  icon: const Icon(Icons.check, size: 18),
                  label: const Text('Approve'),
                ),
                OutlinedButton.icon(
                  style: OutlinedButton.styleFrom(
                    foregroundColor: AppColors.error,
                    side: const BorderSide(color: AppColors.error),
                  ),
                  onPressed: busy ? null : () => _decide(r, false),
                  icon: const Icon(Icons.close, size: 18),
                  label: const Text('Reject'),
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
    final rows = _filter == 'all' ? _rows : _rows.where((r) => r['status'] == _filter).toList();
    return ListPageFrame(
      title: 'Sticker replacements',
      filters: _filters,
      selected: _filter,
      onFilter: (f) => setState(() => _filter = f),
      onRefresh: _load,
      loading: _loading,
      error: _error,
      emptyText: 'No replacement requests.',
      children: [for (final r in rows) _row(r)],
    );
  }
}