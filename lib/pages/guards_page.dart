import 'package:flutter/material.dart';
import '../admin_service.dart';
import '../ui.dart';
import 'common.dart';

/// Guard accounts. The admin enters the guard's details and Gmail; the guard
/// gets a 6-digit code, checks these details in the app and sets a password.
class GuardsPage extends StatefulWidget {
  const GuardsPage({super.key});

  @override
  State<GuardsPage> createState() => _GuardsPageState();
}

const List<String> kGuardShifts = [
  'Morning (6:00 AM - 2:00 PM)',
  'Afternoon (2:00 PM - 10:00 PM)',
  'Night (10:00 PM - 6:00 AM)',
  'Day (7:00 AM - 7:00 PM)',
  'Rotating',
];

bool _isPending(Map<String, dynamic> g) => g['active'] == true && str(g['activated_at']).isEmpty;

Widget guardStatusPill(Map<String, dynamic> g) {
  if (g['active'] != true) {
    return const Pill('Deactivated', bg: AppColors.errorLight, fg: AppColors.error, border: AppColors.error);
  }
  if (_isPending(g)) {
    return const Pill('Waiting for guard', bg: AppColors.goldLight, fg: AppColors.goldDark, border: AppColors.gold);
  }
  return const Pill('Active', bg: AppColors.successLight, fg: AppColors.success, border: AppColors.success);
}

class _GuardsPageState extends State<GuardsPage> {
  String _filter = 'all';
  List<Map<String, dynamic>> _rows = [];
  bool _loading = true;
  String? _error;
  String _query = '';

  static const Map<String, String> _filters = {
    'all': 'All',
    'active': 'Active',
    'pending': 'Waiting for guard',
    'inactive': 'Deactivated',
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
      final rows = await AdminService.guards();
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

  List<Map<String, dynamic>> get _visible {
    final q = _query.trim().toLowerCase();
    return _rows.where((r) {
      final ok = switch (_filter) {
        'active' => r['active'] == true && !_isPending(r),
        'pending' => _isPending(r),
        'inactive' => r['active'] != true,
        _ => true,
      };
      if (!ok) return false;
      if (q.isEmpty) return true;
      return '${r['full_name']} ${r['email']} ${r['id_no']} ${r['post']}'.toLowerCase().contains(q);
    }).toList();
  }

  Future<void> _invite() async {
    final sent = await showDialog<String>(
      context: context,
      barrierDismissible: false,
      builder: (_) => const _GuardFormDialog(),
    );
    if (sent == null || !mounted) return;
    showSnack(context, 'Invite sent to $sent. The guard will get a 6-digit code by email.');
    _load();
  }

  Future<void> _details(Map<String, dynamic> g) async {
    final saved = await showDialog<bool>(
      context: context,
      barrierDismissible: false,
      builder: (_) => _GuardFormDialog(guard: g),
    );
    if (saved == true && mounted) {
      showSnack(context, 'Guard details saved.');
      _load();
    }
  }

  Future<void> _resend(Map<String, dynamic> g) async {
    final ok = await confirmDialog(
      context,
      title: 'Send a new code?',
      message:
          '${str(g['full_name'])} will get a new 6-digit code at ${str(g['email'])}. '
          'In the app they tap "Create guard account" (or "Forgot password?" if they already have one), '
          'enter the code, check their details and set a password.',
      action: 'Send code',
    );
    if (!ok) return;
    final err = await AdminService.inviteGuard(str(g['email']), str(g['full_name']), resend: true);
    if (!mounted) return;
    showSnack(context, err ?? 'New code sent to ${str(g['email'])}.');
  }

  Future<void> _toggle(Map<String, dynamic> g) async {
    final active = g['active'] == true;
    final ok = await confirmDialog(
      context,
      title: active ? 'Deactivate this guard?' : 'Activate this guard?',
      message: active
          ? '${str(g['full_name'])} will no longer be able to log in to the guard module or check stickers. '
              'Their past gate scans are kept.'
          : '${str(g['full_name'])} will be able to log in to the guard module again.',
      action: active ? 'Deactivate' : 'Activate',
      color: active ? AppColors.error : AppColors.navy,
    );
    if (!ok) return;
    final err = await AdminService.setGuard(str(g['user_id']), str(g['full_name']), !active);
    if (!mounted) return;
    showSnack(context, err ?? (active ? 'Guard deactivated.' : 'Guard activated.'));
    if (err == null) _load();
  }

  Widget _row(Map<String, dynamic> g) {
    final active = g['active'] == true;
    final scans = int.tryParse(str(g['scans'])) ?? 0;
    final last = str(g['last_scan']);
    final post = [str(g['post']), str(g['shift'])].where((s) => s.isNotEmpty).join('  |  ');
    return RowCard(
      child: Wrap(
        spacing: 24,
        runSpacing: 12,
        crossAxisAlignment: WrapCrossAlignment.center,
        children: [
          Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              CircleAvatar(
                radius: 20,
                backgroundColor: active ? AppColors.navy : AppColors.border,
                child: const Icon(Icons.shield_outlined, color: Colors.white, size: 20),
              ),
              const SizedBox(width: 12),
              infoCol(str(g['full_name']), str(g['email']), width: 250),
            ],
          ),
          infoCol(
            str(g['id_no']).isEmpty ? 'No guard ID' : 'ID ${str(g['id_no'])}',
            post.isEmpty ? 'No post or shift yet' : post,
            width: 250,
          ),
          infoCol(
            '$scans scan${scans == 1 ? '' : 's'}',
            last.isEmpty ? 'No scans yet' : 'Last: ${fmtDate(last)}',
            width: 170,
          ),
          guardStatusPill(g),
          Wrap(
            spacing: 6,
            runSpacing: 6,
            children: [
              OutlinedButton.icon(
                onPressed: () => _details(g),
                icon: const Icon(Icons.badge_outlined, size: 18),
                label: const Text('Details'),
              ),
              OutlinedButton.icon(
                onPressed: () => _resend(g),
                icon: const Icon(Icons.mark_email_read_outlined, size: 18),
                label: const Text('Resend code'),
              ),
              OutlinedButton.icon(
                style: OutlinedButton.styleFrom(foregroundColor: active ? AppColors.error : AppColors.success),
                onPressed: () => _toggle(g),
                icon: Icon(active ? Icons.block : Icons.check_circle_outline, size: 18),
                label: Text(active ? 'Deactivate' : 'Activate'),
              ),
            ],
          ),
        ],
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return ListPageFrame(
      title: 'Guards',
      filters: _filters,
      selected: _filter,
      onFilter: (f) => setState(() => _filter = f),
      onRefresh: _load,
      loading: _loading,
      error: _error,
      emptyText: 'No guards here. Tap "Invite guard" to add one.',
      onSearch: (q) => setState(() => _query = q),
      searchHint: 'Search name, email, ID or post',
      actions: [
        FilledButton.icon(
          onPressed: _invite,
          icon: const Icon(Icons.person_add_alt_1, size: 18),
          label: const Text('Invite guard'),
        ),
      ],
      children: [for (final g in _visible) _row(g)],
    );
  }
}

/// Invite a new guard (no [guard]) or view and edit an existing guard.
class _GuardFormDialog extends StatefulWidget {
  const _GuardFormDialog({this.guard});

  final Map<String, dynamic>? guard;

  @override
  State<_GuardFormDialog> createState() => _GuardFormDialogState();
}

class _GuardFormDialogState extends State<_GuardFormDialog> {
  late final Map<String, dynamic> _g = widget.guard ?? const {};
  late final _name = TextEditingController(text: str(_g['full_name']));
  late final _email = TextEditingController(text: str(_g['email']));
  late final _idNo = TextEditingController(text: str(_g['id_no']));
  late final _phone = TextEditingController(text: str(_g['phone']));
  late final _post = TextEditingController(text: str(_g['post']));
  late final _address = TextEditingController(text: str(_g['address']));
  late String? _shift = str(_g['shift']).isEmpty ? null : str(_g['shift']);
  bool _busy = false;
  String? _error;

  bool get _isNew => widget.guard == null;

  @override
  void dispose() {
    for (final c in [_name, _email, _idNo, _phone, _post, _address]) {
      c.dispose();
    }
    super.dispose();
  }

  Map<String, String> get _details => {
        'id_no': _idNo.text.trim(),
        'phone': _phone.text.trim().replaceAll(' ', ''),
        'post': _post.text.trim(),
        'shift': _shift ?? '',
        'address': _address.text.trim(),
      };

  String? _check() {
    if (_name.text.trim().length < 2) return "Enter the guard's full name.";
    if (_isNew && !RegExp(r'^[^\s@]+@[^\s@]+\.[^\s@]+$').hasMatch(_email.text.trim())) {
      return 'Enter a valid email address (for example a Gmail).';
    }
    final phone = _phone.text.trim().replaceAll(' ', '');
    if (phone.isNotEmpty && !RegExp(r'^(09\d{9}|\+639\d{9})$').hasMatch(phone)) {
      return 'Mobile number should look like 09XXXXXXXXX.';
    }
    return null;
  }

  Future<void> _submit() async {
    final bad = _check();
    if (bad != null) {
      setState(() => _error = bad);
      return;
    }
    setState(() {
      _busy = true;
      _error = null;
    });
    final String? err;
    if (_isNew) {
      err = await AdminService.inviteGuard(_email.text.trim().toLowerCase(), _name.text.trim(), details: _details);
    } else {
      err = await AdminService.updateGuard(
        str(_g['user_id']),
        {'name': _name.text.trim(), ..._details},
        _g['active'] == true,
      );
    }
    if (!mounted) return;
    if (err == null || err.startsWith('Guard saved')) {
      if (err != null) showSnack(context, err);
      Navigator.pop<Object>(context, _isNew ? _email.text.trim().toLowerCase() : true);
      return;
    }
    setState(() {
      _busy = false;
      _error = err;
    });
  }

  Widget _field(
    TextEditingController c,
    String label, {
    String? hint,
    IconData? icon,
    bool enabled = true,
    TextInputType? type,
    TextCapitalization caps = TextCapitalization.none,
    int maxLines = 1,
  }) {
    return TextField(
      controller: c,
      enabled: enabled && !_busy,
      keyboardType: type,
      textCapitalization: caps,
      maxLines: maxLines,
      decoration: InputDecoration(labelText: label, hintText: hint, prefixIcon: icon == null ? null : Icon(icon)),
    );
  }

  Widget _pair(Widget a, Widget b) {
    return LayoutBuilder(
      builder: (context, c) {
        if (c.maxWidth < 460) {
          return Column(children: [a, const SizedBox(height: 12), b]);
        }
        return Row(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [Expanded(child: a), const SizedBox(width: 12), Expanded(child: b)],
        );
      },
    );
  }

  @override
  Widget build(BuildContext context) {
    final shifts = [...kGuardShifts, if (_shift != null && !kGuardShifts.contains(_shift)) _shift!];
    final scans = int.tryParse(str(_g['scans'])) ?? 0;
    return AlertDialog(
      title: Row(
        children: [
          Expanded(child: Text(_isNew ? 'Invite guard' : 'Guard details')),
          if (!_isNew) guardStatusPill(_g),
        ],
      ),
      content: SizedBox(
        width: 560,
        child: SingleChildScrollView(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                _isNew
                    ? 'Enter the guard\'s details. They will get an email with a 6-digit code. In the app they tap '
                        '"Create guard account", enter the code, check these details and create their own password.'
                    : 'The guard sees these details when they create their account in the app.',
                style: const TextStyle(fontSize: 13, color: AppColors.textMuted),
              ),
              const SizedBox(height: 16),
              _field(_name, 'Full name *', hint: 'Juan Dela Cruz', icon: Icons.person_outline, caps: TextCapitalization.words),
              const SizedBox(height: 12),
              _field(
                _email,
                'Email (Gmail) *',
                hint: 'guard.name@gmail.com',
                icon: Icons.mail_outline,
                type: TextInputType.emailAddress,
                enabled: _isNew,
              ),
              const SizedBox(height: 12),
              _pair(
                _field(_idNo, 'Guard ID no.', hint: 'SG-2026-001', icon: Icons.badge_outlined),
                _field(_phone, 'Mobile number', hint: '09XXXXXXXXX', icon: Icons.phone_outlined, type: TextInputType.phone),
              ),
              const SizedBox(height: 12),
              _pair(
                _field(_post, 'Assigned post / gate', hint: 'Main Gate', icon: Icons.location_on_outlined, caps: TextCapitalization.words),
                InputDecorator(
                  decoration: const InputDecoration(
                    labelText: 'Shift',
                    prefixIcon: Icon(Icons.schedule),
                    contentPadding: EdgeInsets.symmetric(horizontal: 12, vertical: 4),
                  ),
                  child: DropdownButtonHideUnderline(
                    child: DropdownButton<String>(
                      value: _shift,
                      isExpanded: true,
                      hint: const Text('Choose shift'),
                      items: [
                        for (final s in shifts) DropdownMenuItem(value: s, child: Text(s, overflow: TextOverflow.ellipsis)),
                      ],
                      onChanged: _busy ? null : (v) => setState(() => _shift = v),
                    ),
                  ),
                ),
              ),
              const SizedBox(height: 12),
              _field(_address, 'Home address', hint: 'Barangay, City, Pangasinan', icon: Icons.home_outlined, caps: TextCapitalization.words, maxLines: 2),
              if (!_isNew) ...[
                const SizedBox(height: 16),
                InfoRow('Invited', str(_g['invited_at']).isEmpty ? '-' : fmtDate(_g['invited_at'])),
                InfoRow(
                  'Account created',
                  str(_g['activated_at']).isEmpty ? 'Not yet. Waiting for the guard to enter the code.' : fmtDate(_g['activated_at']),
                ),
                InfoRow('Gate scans', '$scans'),
              ],
              if (_error != null) ...[
                const SizedBox(height: 12),
                Text(_error!, style: const TextStyle(color: AppColors.error, fontSize: 13)),
              ],
            ],
          ),
        ),
      ),
      actions: [
        TextButton(onPressed: _busy ? null : () => Navigator.pop(context), child: Text(_isNew ? 'Cancel' : 'Close')),
        FilledButton.icon(
          onPressed: _busy ? null : _submit,
          icon: _busy
              ? const SizedBox(width: 16, height: 16, child: CircularProgressIndicator(strokeWidth: 2, color: Colors.white))
              : Icon(_isNew ? Icons.send : Icons.save_outlined, size: 18),
          label: Text(_busy ? 'Saving...' : (_isNew ? 'Send invite' : 'Save changes')),
        ),
      ],
    );
  }
}
