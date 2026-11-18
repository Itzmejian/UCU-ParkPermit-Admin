import 'package:flutter/material.dart';
import '../admin_service.dart';
import '../ui.dart';
import 'common.dart';
import 'replacement_review_page.dart';
import 'review_widgets.dart';

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

  Future<void> _open(List<Map<String, dynamic>> rows, int index) async {
    // Waiting requests open as a queue, so the next one follows after a decision.
    final r = rows[index];
    final queue = r['status'] == 'requested'
        ? _rows.where((x) => x['status'] == 'requested').toList()
        : [r];
    final start = queue.indexWhere((x) => x['id'] == r['id']);
    await Navigator.push(
      context,
      MaterialPageRoute(builder: (_) => ReplacementReviewPage(queue: queue, index: start < 0 ? 0 : start)),
    );
    _load();
  }

  Widget _statusPill(String s) => switch (s) {
        'approved' => statePill('Approved', 'success'),
        'rejected' => statePill('Rejected', 'error'),
        _ => statePill('Waiting', 'warning'),
      };

  Widget _row(List<Map<String, dynamic>> rows, int i) {
    final r = rows[i];
    final permit = asOne(r['permit']);
    final v = asOne(permit['vehicle']);
    final o = asOne(r['owner']);
    return RowCard(
      onTap: () => _open(rows, i),
      child: Wrap(
        spacing: 24,
        runSpacing: 12,
        crossAxisAlignment: WrapCrossAlignment.center,
        children: [
          infoCol(str(permit['permit_no']), fmtDate(r['created_at']), mono: true),
          infoCol(str(o['full_name']), '${roleLabel(o['role'])}  |  ${str(o['id_number'])}'),
          infoCol(str(v['plate_number']), str(v['make_model']), mono: true),
          infoCol(str(r['reason']), 'Reason', width: 200),
          _statusPill(str(r['status'])),
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
      children: [for (var i = 0; i < rows.length; i++) _row(rows, i)],
    );
  }
}