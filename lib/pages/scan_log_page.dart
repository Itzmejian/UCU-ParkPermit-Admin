import 'package:flutter/material.dart';
import '../admin_service.dart';
import '../ui.dart';
import 'common.dart';

class ScanLogPage extends StatefulWidget {
  const ScanLogPage({super.key, this.initialFilter});

  final String? initialFilter;

  @override
  State<ScanLogPage> createState() => _ScanLogPageState();
}

class _ScanLogPageState extends State<ScanLogPage> {
  late String _filter = widget.initialFilter ?? 'all';
  List<Map<String, dynamic>> _rows = [];
  bool _loading = true;
  String? _error;
  String _query = '';

  static const Map<String, String> _filters = {
    'all': 'All',
    'valid': 'Valid',
    'problem': 'Problems',
    'today': 'Today',
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
      final rows = await AdminService.gateScans();
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

  Widget _resultPill(String r) {
    switch (r) {
      case 'valid':
        return const Pill('Valid', bg: AppColors.successLight, fg: AppColors.success, border: AppColors.success);
      case 'not_claimed':
        return const Pill('Sticker not claimed', bg: AppColors.goldLight, fg: AppColors.goldDark, border: AppColors.gold);
      case 'expired':
        return const Pill('Expired', bg: AppColors.errorLight, fg: AppColors.error, border: AppColors.error);
      case 'inactive':
        return const Pill('Vehicle removed', bg: AppColors.errorLight, fg: AppColors.error, border: AppColors.error);
      default:
        return const Pill('Not found', bg: AppColors.errorLight, fg: AppColors.error, border: AppColors.error);
    }
  }

  static const Map<String, String> _meaning = {
    'valid': 'The permit is active and the sticker was claimed. The vehicle may enter.',
    'not_claimed': 'The permit is approved but the sticker was not claimed yet. The guard should not allow the sticker.',
    'expired': 'The permit has expired. The applicant must renew it in the app.',
    'inactive': 'The vehicle was removed by its owner, so the permit no longer works.',
    'not_found': 'No permit matched the QR code or the number typed by the guard.',
  };

  void _details(Map<String, dynamic> s) {
    final p = asOne(s['permit']);
    final v = asOne(p['vehicle']);
    final result = str(s['result']);
    showDialog<void>(
      context: context,
      builder: (ctx) => AlertDialog(
        titlePadding: EdgeInsets.zero,
        clipBehavior: Clip.antiAlias,
        title: DialogHeader(
          icon: Icons.qr_code_scanner,
          title: 'Gate scan',
          subtitle: fmtDate(s['created_at']),
          tone: result == 'valid' ? 'success' : 'danger',
          trailing: _resultPill(result),
        ),
        content: SizedBox(
          width: 480,
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Container(
                width: double.infinity,
                padding: const EdgeInsets.all(12),
                decoration: BoxDecoration(
                  color: result == 'valid' ? AppColors.successLight : AppColors.errorLight,
                  borderRadius: BorderRadius.circular(12),
                ),
                child: Text(
                  _meaning[result] ?? _meaning['not_found']!,
                  style: TextStyle(
                    height: 1.4,
                    fontWeight: FontWeight.w600,
                    color: result == 'valid' ? AppColors.success : AppColors.error,
                  ),
                ),
              ),
              const SizedBox(height: 12),
              InfoRow('Date and time', fmtDate(s['created_at'])),
              InfoRow('Guard', str(s['guard_name']).isEmpty ? 'A guard' : str(s['guard_name'])),
              InfoRow('How it was checked', s['method'] == 'qr' ? 'QR scan' : 'Typed by the guard'),
              InfoRow('What was checked', str(s['code_used']), mono: true),
              if (p.isNotEmpty) ...[
                InfoRow('Permit number', str(p['permit_no']), mono: true),
                InfoRow('Plate number', str(v['plate_number']), mono: true),
                InfoRow('Make / Model', str(v['make_model'])),
              ],
            ],
          ),
        ),
        actions: [
          FilledButton(onPressed: () => Navigator.pop(ctx), child: const Text('Close')),
        ],
      ),
    );
  }

  bool _isToday(dynamic iso) {
    final d = DateTime.tryParse(str(iso))?.toLocal();
    final n = DateTime.now();
    return d != null && d.year == n.year && d.month == n.month && d.day == n.day;
  }

  Widget _stat(String label, int value, Color color, IconData icon) {
    return Container(
      width: 200,
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(14),
        border: Border(left: BorderSide(color: color, width: 4)),
        boxShadow: const [BoxShadow(color: Color(0x0D1D3E7C), blurRadius: 10, offset: Offset(0, 3))],
      ),
      child: Row(
        children: [
          Icon(icon, color: color),
          const SizedBox(width: 12),
          Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text('$value', style: TextStyle(fontSize: 22, fontWeight: FontWeight.w800, color: color)),
              Text(label, style: const TextStyle(fontSize: 12, color: AppColors.textHint)),
            ],
          ),
        ],
      ),
    );
  }

  Widget _summary() {
    final today = _rows.where((s) => _isToday(s['created_at'])).toList();
    final ok = today.where((s) => s['result'] == 'valid').length;
    return Wrap(
      spacing: 12,
      runSpacing: 12,
      children: [
        _stat('Scans today', today.length, AppColors.navy, Icons.qr_code_scanner),
        _stat('Valid today', ok, AppColors.success, Icons.verified_outlined),
        _stat('Problems today', today.length - ok, AppColors.error, Icons.report_gmailerrorred_outlined),
      ],
    );
  }

  Widget _row(Map<String, dynamic> s) {
    final p = asOne(s['permit']);
    final v = asOne(p['vehicle']);
    final found = p.isNotEmpty;
    return RowCard(
      onTap: () => _details(s),
      child: Wrap(
        spacing: 24,
        runSpacing: 12,
        crossAxisAlignment: WrapCrossAlignment.center,
        children: [
          infoCol(fmtDate(s['created_at']), 'Scanned by ${str(s['guard_name']).isEmpty ? 'a guard' : str(s['guard_name'])}', width: 240),
          if (found)
            infoCol(str(v['plate_number']), '${str(p['permit_no'])}  |  ${str(v['make_model'])}', mono: true, width: 260)
          else
            infoCol(str(s['code_used']).isEmpty ? '(QR not recognized)' : str(s['code_used']), 'What was checked', mono: true, width: 260),
          _resultPill(str(s['result'])),
          Pill(s['method'] == 'qr' ? 'QR scan' : 'Typed'),
        ],
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    var rows = switch (_filter) {
      'valid' => _rows.where((s) => s['result'] == 'valid').toList(),
      'problem' => _rows.where((s) => s['result'] != 'valid').toList(),
      'today' => _rows.where((s) => _isToday(s['created_at'])).toList(),
      _ => _rows,
    };
    final q = _query.trim().toLowerCase();
    if (q.isNotEmpty) {
      rows = rows.where((s) {
        final p = asOne(s['permit']);
        final v = asOne(p['vehicle']);
        final text = '${p['permit_no']} ${v['plate_number']} ${v['make_model']} ${s['guard_name']} ${s['code_used']}'
            .toLowerCase();
        return text.contains(q);
      }).toList();
    }
    return ListPageFrame(
      title: 'Gate scans',
      filters: _filters,
      selected: _filter,
      onFilter: (f) => setState(() => _filter = f),
      onRefresh: _load,
      loading: _loading,
      error: _error,
      emptyText: q.isEmpty ? 'No scans yet.' : 'No scans match your search.',
      onSearch: (v) => setState(() => _query = v),
      searchHint: 'Search plate, permit or guard',
      top: _rows.isEmpty ? null : _summary(),
      children: [for (final s in rows) _row(s)],
    );
  }
}
