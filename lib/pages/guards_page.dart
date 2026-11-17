import 'package:flutter/material.dart';
import '../admin_service.dart';
import '../ui.dart';
import 'common.dart';

/// Guard accounts. The admin invites a guard by name and Gmail; the guard
/// gets a 6-digit code and sets their own password in the app.
class GuardsPage extends StatefulWidget {
  const GuardsPage({super.key});

  @override
  State<GuardsPage> createState() => _GuardsPageState();
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
        'active' => r['active'] == true,
        'inactive' => r['active'] != true,
        _ => true,
      };
      if (!ok) return false;
      if (q.isEmpty) return true;
      return '${r['full_name']} ${r['email']}'.toLowerCase().contains(q);
    }).toList();
  }

  Future<void> _invite() async {
    final sent = await showDialog<String>(
      context: context,
      barrierDismissible: false,
      builder: (_) => const _InviteDialog(),
    );
    if (sent == null || !mounted) return;
    showSnack(context, 'Invite sent to $sent. The guard will get a 6-digit code by email.');
    _load();
  }

  Future<void> _resend(Map<String, dynamic> g) async {
    final ok = await confirmDialog(
      context,
      title: 'Send a new code?',
      message:
          '${str(g['full_name'])} will get a new 6-digit code at ${str(g['email'])}. '
          'They open the app, tap "Activate my guard account" (or "Forgot password?"), '
          'enter the code and choose a new password.',
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

  Future<void> _rename(Map<String, dynamic> g) async {
    final ctrl = TextEditingController(text: str(g['full_name']));
    final name = await showDialog<String>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('Edit guard name'),
        content: SizedBox(
          width: 400,
          child: TextField(
            controller: ctrl,
            autofocus: true,
            textCapitalization: TextCapitalization.words,
            decoration: const InputDecoration(labelText: 'Full name'),
          ),
        ),
        actions: [
          TextButton(onPressed: () => Navigator.pop(ctx), child: const Text('Cancel')),
          FilledButton(onPressed: () => Navigator.pop(ctx, ctrl.text.trim()), child: const Text('Save')),
        ],
      ),
    );
    ctrl.dispose();
    if (name == null || name == str(g['full_name'])) return;
    if (name.length < 2) {
      if (mounted) showSnack(context, "Enter the guard's full name.");
      return;
    }
    final err = await AdminService.setGuard(str(g['user_id']), name, g['active'] == true);
    if (!mounted) return;
    showSnack(context, err ?? 'Name updated.');
    if (err == null) _load();
  }

  Widget _row(Map<String, dynamic> g) {
    final active = g['active'] == true;
    final scans = int.tryParse(str(g['scans'])) ?? 0;
    final last = str(g['last_scan']);
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
              infoCol(str(g['full_name']), str(g['email']), width: 260),
            ],
          ),
          infoCol(
            '$scans scan${scans == 1 ? '' : 's'}',
            last.isEmpty ? 'No scans yet' : 'Last: ${fmtDate(last)}',
            width: 200,
          ),
          active
              ? const Pill('Active', bg: AppColors.successLight, fg: AppColors.success, border: AppColors.success)
              : const Pill('Deactivated', bg: AppColors.errorLight, fg: AppColors.error, border: AppColors.error),
          Wrap(
            spacing: 6,
            runSpacing: 6,
            children: [
              OutlinedButton.icon(
                onPressed: () => _resend(g),
                icon: const Icon(Icons.mark_email_read_outlined, size: 18),
                label: const Text('Resend code'),
              ),
              OutlinedButton.icon(
                onPressed: () => _rename(g),
                icon: const Icon(Icons.edit_outlined, size: 18),
                label: const Text('Edit name'),
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
      emptyText: 'No guards yet. Tap "Invite guard" to add one.',
      onSearch: (q) => setState(() => _query = q),
      searchHint: 'Search name or email',
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

class _InviteDialog extends StatefulWidget {
  const _InviteDialog();

  @override
  State<_InviteDialog> createState() => _InviteDialogState();
}

class _InviteDialogState extends State<_InviteDialog> {
  final _name = TextEditingController();
  final _email = TextEditingController();
  bool _busy = false;
  String? _error;

  @override
  void dispose() {
    _name.dispose();
    _email.dispose();
    super.dispose();
  }

  Future<void> _send() async {
    final name = _name.text.trim();
    final email = _email.text.trim().toLowerCase();
    if (name.length < 2) {
      setState(() => _error = "Enter the guard's full name.");
      return;
    }
    if (!RegExp(r'^[^\s@]+@[^\s@]+\.[^\s@]+$').hasMatch(email)) {
      setState(() => _error = 'Enter a valid email address (for example a Gmail).');
      return;
    }
    setState(() {
      _busy = true;
      _error = null;
    });
    final err = await AdminService.inviteGuard(email, name);
    if (!mounted) return;
    if (err == null || err.startsWith('Guard saved')) {
      if (err != null) showSnack(context, err);
      Navigator.pop(context, email);
      return;
    }
    setState(() {
      _busy = false;
      _error = err;
    });
  }

  @override
  Widget build(BuildContext context) {
    return AlertDialog(
      title: const Text('Invite guard'),
      content: SizedBox(
        width: 440,
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const Text(
              'The guard will receive an email with a 6-digit code. In the app they tap '
              '"Activate my guard account", enter the code and create their own password.',
              style: TextStyle(fontSize: 13, color: AppColors.textMuted),
            ),
            const SizedBox(height: 16),
            TextField(
              controller: _name,
              enabled: !_busy,
              autofocus: true,
              textCapitalization: TextCapitalization.words,
              decoration: const InputDecoration(labelText: 'Full name', hintText: 'Juan Dela Cruz'),
            ),
            const SizedBox(height: 12),
            TextField(
              controller: _email,
              enabled: !_busy,
              keyboardType: TextInputType.emailAddress,
              decoration: const InputDecoration(labelText: 'Email (Gmail)', hintText: 'guard.name@gmail.com'),
              onSubmitted: (_) => _send(),
            ),
            if (_error != null) ...[
              const SizedBox(height: 12),
              Text(_error!, style: const TextStyle(color: AppColors.error, fontSize: 13)),
            ],
          ],
        ),
      ),
      actions: [
        TextButton(onPressed: _busy ? null : () => Navigator.pop(context), child: const Text('Cancel')),
        FilledButton.icon(
          onPressed: _busy ? null : _send,
          icon: _busy
              ? const SizedBox(width: 16, height: 16, child: CircularProgressIndicator(strokeWidth: 2, color: Colors.white))
              : const Icon(Icons.send, size: 18),
          label: Text(_busy ? 'Sending...' : 'Send invite'),
        ),
      ],
    );
  }
}
