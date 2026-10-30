import 'package:flutter/material.dart';
import '../admin_service.dart';
import '../ui.dart';
import 'common.dart';

class ScanLogPage extends StatefulWidget {
  const ScanLogPage({super.key});

  @override
  State<ScanLogPage> createState() => _ScanLogPageState();
}

class _ScanLogPageState extends State<ScanLogPage> {
  String _filter = 'all';
  List<Map<String, dynamic>> _rows = [];
  bool _loading = true;
  String? _error;

  static const Map<String, String> _filters = {
    'all': 'All',
    'valid': 'Valid',
    'problem': 'Problems',
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

  Widget _row(Map<String, dynamic> s) {
    final p = asOne(s['permit']);
    final v = asOne(p['vehicle']);
    final found = p.isNotEmpty;
    return RowCard(
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
    final rows = switch (_filter) {
      'valid' => _rows.where((s) => s['result'] == 'valid').toList(),
      'problem' => _rows.where((s) => s['result'] != 'valid').toList(),
      _ => _rows,
    };
    return ListPageFrame(
      title: 'Gate scans',
      filters: _filters,
      selected: _filter,
      onFilter: (f) => setState(() => _filter = f),
      onRefresh: _load,
      loading: _loading,
      error: _error,
      emptyText: 'No scans yet.',
      children: [for (final s in rows) _row(s)],
    );
  }
}