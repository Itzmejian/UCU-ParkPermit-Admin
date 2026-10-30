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

Future<void> _changeValidity(Map<String, dynamic> r) async {
    final id = str(r['id']);
    var history = <Map<String, dynamic>>[];
    try {
      history = await AdminService.permitChanges(id);
    } catch (_) {}
    if (!mounted) return;
    final result = await showDialog<_ValidityResult>(
      context: context,
      builder: (_) => _ValidityDialog(
        permitNo: str(r['permit_no']),
        current: DateTime.tryParse(str(r['valid_until'])),
        history: history,
      ),
    );
    if (result == null || !mounted) return;
    setState(() => _busyId = id);
    final err = await AdminService.setValidity(id, result.date, result.reason);
    if (!mounted) return;
    setState(() => _busyId = null);
    showSnack(context, err ?? 'Validity changed. It was recorded and the applicant was notified.');
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
          OutlinedButton.icon(
            onPressed: busy ? null : () => _changeValidity(r),
            icon: const Icon(Icons.event_outlined, size: 18),
            label: const Text('Change validity'),
          ),
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

class _ValidityResult {
  const _ValidityResult(this.date, this.reason);

  final DateTime date;
  final String reason;
}

/// Change a permit's "valid until" date. A reason is required, and the
/// change is kept in the history (it cannot be deleted).
class _ValidityDialog extends StatefulWidget {
  const _ValidityDialog({
    required this.permitNo,
    required this.current,
    required this.history,
  });

  final String permitNo;
  final DateTime? current;
  final List<Map<String, dynamic>> history;

  @override
  State<_ValidityDialog> createState() => _ValidityDialogState();
}

class _ValidityDialogState extends State<_ValidityDialog> {
  DateTime? _date;
  final TextEditingController _reason = TextEditingController();
  String? _error;

  DateTime get _today {
    final n = DateTime.now();
    return DateTime(n.year, n.month, n.day);
  }

  DateTime get _base => widget.current ?? _today;

  @override
  void dispose() {
    _reason.dispose();
    super.dispose();
  }

  String _fmt(DateTime d) => fmtDate(
        '${d.year.toString().padLeft(4, '0')}-${d.month.toString().padLeft(2, '0')}-${d.day.toString().padLeft(2, '0')}',
        time: false,
      );

  Future<void> _pick() async {
    final first = _today.subtract(const Duration(days: 365));
    final last = _today.add(const Duration(days: 730));
    var init = _date ?? _base;
    if (init.isBefore(first)) init = first;
    if (init.isAfter(last)) init = last;
    final picked = await showDatePicker(
      context: context,
      initialDate: init,
      firstDate: first,
      lastDate: last,
      helpText: 'New "valid until" date',
    );
    if (picked != null) setState(() => _date = picked);
  }

  void _save() {
    final reason = _reason.text.trim();
    if (_date == null) {
      setState(() => _error = 'Choose the new date.');
      return;
    }
    if (reason.length < 5) {
      setState(() => _error = 'Write the reason (at least 5 characters).');
      return;
    }
    Navigator.pop(context, _ValidityResult(_date!, reason));
  }

  @override
  Widget build(BuildContext context) {
    final quick = <(String, DateTime)>[
      ('+1 month', DateTime(_base.year, _base.month + 1, _base.day)),
      ('+6 months', DateTime(_base.year, _base.month + 6, _base.day)),
      ('Expire now', _today.subtract(const Duration(days: 1))),
    ];
    return AlertDialog(
      title: Text('Change validity of ${widget.permitNo}'),
      content: SizedBox(
        width: 540,
        child: SingleChildScrollView(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                'Currently valid until ${widget.current == null ? '-' : _fmt(widget.current!)}.',
                style: const TextStyle(color: AppColors.textMuted),
              ),
              const SizedBox(height: 14),
              Wrap(
                spacing: 8,
                runSpacing: 8,
                crossAxisAlignment: WrapCrossAlignment.center,
                children: [
                  for (final q in quick)
                    ActionChip(label: Text(q.$1), onPressed: () => setState(() => _date = q.$2)),
                  OutlinedButton.icon(
                    onPressed: _pick,
                    icon: const Icon(Icons.calendar_month_outlined, size: 18),
                    label: const Text('Pick a date'),
                  ),
                ],
              ),
              const SizedBox(height: 12),
              Text(
                _date == null ? 'New date: not chosen yet' : 'New date: ${_fmt(_date!)}',
                style: const TextStyle(fontWeight: FontWeight.w700, color: AppColors.navy),
              ),
              const SizedBox(height: 12),
              TextField(
                controller: _reason,
                maxLines: 2,
                maxLength: 200,
                decoration: const InputDecoration(
                  labelText: 'Reason (required)',
                  hintText: 'e.g., Extended because of late enrollment.',
                ),
              ),
              const Text(
                'This change is recorded with your account and cannot be deleted. The applicant will be notified.',
                style: TextStyle(fontSize: 12, color: AppColors.textHint),
              ),
              if (_error != null) ...[
                const SizedBox(height: 8),
                Text(_error!, style: const TextStyle(color: AppColors.error)),
              ],
              const SizedBox(height: 18),
              const Text(
                'HISTORY',
                style: TextStyle(
                  fontSize: 11.5,
                  fontWeight: FontWeight.w800,
                  letterSpacing: 0.8,
                  color: AppColors.goldDark,
                ),
              ),
              const SizedBox(height: 6),
              if (widget.history.isEmpty)
                const Text('No changes yet.', style: TextStyle(color: AppColors.textMuted))
              else
                for (final h in widget.history)
                  Container(
                    width: double.infinity,
                    margin: const EdgeInsets.only(bottom: 8),
                    padding: const EdgeInsets.all(10),
                    decoration: BoxDecoration(
                      color: AppColors.surface,
                      borderRadius: BorderRadius.circular(10),
                      border: Border.all(color: AppColors.border),
                    ),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          '${fmtDate(h['created_at'])}  |  ${str(asOne(h['admin'])['email'])}',
                          style: const TextStyle(fontSize: 12, color: AppColors.textHint),
                        ),
                        Text(
                          'From ${fmtDate(h['old_valid_until'], time: false)} to ${fmtDate(h['new_valid_until'], time: false)}',
                          style: const TextStyle(fontWeight: FontWeight.w700),
                        ),
                        Text('Reason: ${str(h['reason'])}'),
                      ],
                    ),
                  ),
            ],
          ),
        ),
      ),
      actions: [
        TextButton(onPressed: () => Navigator.pop(context), child: const Text('Cancel')),
        FilledButton(onPressed: _save, child: const Text('Save change')),
      ],
    );
  }
}