import 'package:flutter/material.dart';
import '../admin_service.dart';
import '../ui.dart';
import 'common.dart';

class PermitsPage extends StatefulWidget {
  const PermitsPage({super.key, this.initialFilter});

  final String? initialFilter;

  @override
  State<PermitsPage> createState() => _PermitsPageState();
}

class _PermitsPageState extends State<PermitsPage> {
  late String _filter = widget.initialFilter ?? 'all';
  List<Map<String, dynamic>> _rows = [];
  bool _loading = true;
  String? _error;
  String _query = '';
  String? _busyId;

  static const Map<String, String> _filters = {
    'all': 'All',
    'preparing': 'To prepare',
    'ready': 'Ready for pickup',
    'claimed': 'Claimed',
    'expiring': 'Expiring in 30 days',
    'expired': 'Expired',
  };

  DateTime get _today {
    final n = DateTime.now();
    return DateTime(n.year, n.month, n.day);
  }

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
      final rows = await AdminService.permits();
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

  bool _isExpired(Map<String, dynamic> r) {
    final d = DateTime.tryParse(str(r['valid_until']));
    return d != null && d.isBefore(_today);
  }

  bool _isExpiring(Map<String, dynamic> r) {
    final d = DateTime.tryParse(str(r['valid_until']));
    return d != null && !d.isBefore(_today) && !d.isAfter(_today.add(const Duration(days: 30)));
  }

  List<Map<String, dynamic>> get _visible {
    final q = _query.trim().toLowerCase();
    return _rows.where((r) {
      final ok = switch (_filter) {
        'preparing' || 'ready' || 'claimed' => r['sticker_status'] == _filter,
        'expiring' => _isExpiring(r),
        'expired' => _isExpired(r),
        _ => true,
      };
      if (!ok) return false;
      if (q.isEmpty) return true;
      final v = asOne(r['vehicle']);
      final o = asOne(r['owner']);
      return '${r['permit_no']} ${v['plate_number']} ${o['full_name']} ${o['id_number']}'
          .toLowerCase()
          .contains(q);
    }).toList();
  }

  Future<void> _set(Map<String, dynamic> r, String state) async {
    final ready = state == 'ready';
    final ok = await confirmDialog(
      context,
      title: ready ? 'Sticker ready for pickup?' : 'Sticker claimed?',
      message: ready
          ? 'Mark the sticker of ${str(r['permit_no'])} as ready? The applicant will be told to claim it.'
          : 'Mark the sticker of ${str(r['permit_no'])} as claimed? The permit becomes active.',
      action: ready ? 'Mark Ready' : 'Mark Claimed',
      color: ready ? AppColors.navy : AppColors.success,
    );
    if (!ok || !mounted) return;
    setState(() => _busyId = str(r['id']));
    final err = await AdminService.setSticker(str(r['id']), state);
    if (!mounted) return;
    setState(() => _busyId = null);
    showSnack(context, err ?? 'Updated. The applicant was notified.');
    _load();
  }

  Widget _stickerPill(String s) {
    switch (s) {
      case 'ready':
        return const Pill('Ready', bg: AppColors.successLight, fg: AppColors.success, border: AppColors.success);
      case 'claimed':
        return const Pill('Claimed');
      default:
        return const Pill('Preparing', bg: AppColors.goldLight, fg: AppColors.goldDark, border: AppColors.gold);
    }
  }

  Widget _row(Map<String, dynamic> r) {
    final v = asOne(r['vehicle']);
    final o = asOne(r['owner']);
    final z = asOne(r['zone']);
    final state = str(r['sticker_status']);
    final busy = _busyId == str(r['id']);
    final expired = _isExpired(r);
    final expiring = _isExpiring(r);

    Widget? action;
    if (state == 'preparing') {
      action = FilledButton.icon(
        onPressed: busy ? null : () => _set(r, 'ready'),
        icon: const Icon(Icons.inventory_2_outlined, size: 18),
        label: const Text('Mark Ready'),
      );
    } else if (state == 'ready') {
      action = FilledButton.icon(
        style: FilledButton.styleFrom(backgroundColor: AppColors.success),
        onPressed: busy ? null : () => _set(r, 'claimed'),
        icon: const Icon(Icons.check, size: 18),
        label: const Text('Mark Claimed'),
      );
    }

    return RowCard(
      child: Wrap(
        spacing: 24,
        runSpacing: 12,
        crossAxisAlignment: WrapCrossAlignment.center,
        children: [
          infoCol(
            str(r['permit_no']),
            'Valid until ${fmtDate(r['valid_until'], time: false)}',
            mono: true,
            subColor: expired ? AppColors.error : (expiring ? AppColors.goldDark : null),
          ),
          infoCol(str(o['full_name']), '${roleLabel(o['role'])}  |  ${str(o['id_number'])}'),
          infoCol(str(v['plate_number']), '${vehicleLabel(v['vehicle_type'])}  |  ${str(v['make_model'])}', mono: true),
          infoCol(str(z['name']), 'Parking zone', width: 120),
          Wrap(
            spacing: 6,
            runSpacing: 6,
            children: [
              _stickerPill(state),
              if (expired)
                const Pill('Expired', bg: AppColors.errorLight, fg: AppColors.error, border: AppColors.error)
              else if (expiring)
                const Pill('Expiring', bg: AppColors.goldLight, fg: AppColors.goldDark, border: AppColors.gold),
            ],
          ),
          ?action,
        ],
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return ListPageFrame(
      title: 'Permits',
      filters: _filters,
      selected: _filter,
      onFilter: (f) => setState(() => _filter = f),
      onRefresh: _load,
      loading: _loading,
      error: _error,
      emptyText: 'No permits found.',
      onSearch: (v) => setState(() => _query = v),
      searchHint: 'Search permit, plate, name or ID',
      children: [for (final r in _visible) _row(r)],
    );
  }
}