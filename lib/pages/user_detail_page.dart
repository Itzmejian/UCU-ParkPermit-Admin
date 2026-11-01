import 'package:flutter/material.dart';
import '../admin_service.dart';
import '../ui.dart';
import 'application_detail_page.dart';
import 'common.dart';
import 'users_page.dart';

class UserDetailPage extends StatefulWidget {
  const UserDetailPage({super.key, required this.id});

  final String id;

  @override
  State<UserDetailPage> createState() => _UserDetailPageState();
}

class _UserDetailPageState extends State<UserDetailPage> {
  Map<String, dynamic>? _u;
  bool _loading = true;
  bool _busy = false;
  String? _error;

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
      final u = await AdminService.user(widget.id);
      if (!mounted) return;
      setState(() {
        _u = u;
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

  Future<void> _schedule() async {
    final result = await showDialog<(int, String)>(
      context: context,
      builder: (_) => const _ScheduleDialog(),
    );
    if (result == null || !mounted) return;
    setState(() => _busy = true);
    final r = await AdminService.scheduleRemoval(widget.id, result.$1, result.$2);
    if (!mounted) return;
    setState(() => _busy = false);
    showSnack(context, r.error ?? 'Removal scheduled on ${fmtDate(r.date, time: false)}. The user was notified.');
    _load();
  }

  Future<void> _cancel(bool inactive) async {
    final ok = await confirmDialog(
      context,
      title: inactive ? 'Reactivate this account?' : 'Cancel the removal?',
      message: 'The user will be able to use the app again and will be notified.',
      action: inactive ? 'Reactivate' : 'Cancel removal',
      color: AppColors.success,
    );
    if (!ok || !mounted) return;
    setState(() => _busy = true);
    final err = await AdminService.cancelRemoval(widget.id);
    if (!mounted) return;
    setState(() => _busy = false);
    showSnack(context, err ?? 'The account is active again.');
    _load();
  }

  Future<void> _delete() async {
    final u = _u!;
    final key = str(u['id_number']).isNotEmpty ? str(u['id_number']) : str(u['email']);
    final typed = await showDialog<String>(
      context: context,
      builder: (_) => _DeleteDialog(name: str(u['full_name']), confirmKey: key),
    );
    if (typed == null || !mounted) return;
    setState(() => _busy = true);
    final err = await AdminService.deleteUser(widget.id, typed);
    if (!mounted) return;
    setState(() => _busy = false);
    if (err != null) {
      showSnack(context, err);
      return;
    }
    showSnack(context, 'The account and all its data were deleted.');
    Navigator.pop(context, true);
  }

  Widget _actions(Map<String, dynamic> u) {
    final status = str(u['account_status']);
    final text = switch (status) {
      'scheduled' =>
        'This account will become inactive on ${fmtDate(u['removal_date'], time: false)}. It is cancelled automatically if the user applies or renews.${str(u['removal_reason']).isEmpty ? '' : ' Reason: ${str(u['removal_reason'])}'}',
      'inactive' => 'This account is inactive. The user cannot log in.',
      _ => 'Give the user time to renew before the account is removed, or delete it now.',
    };
    return SectionCard(
      title: 'Account',
      trailing: accountPill(u),
      children: [
        Text(text, style: const TextStyle(color: AppColors.textMuted, height: 1.4)),
        const SizedBox(height: 14),
        Wrap(
          spacing: 10,
          runSpacing: 10,
          children: [
            if (status == 'active')
              OutlinedButton.icon(
                onPressed: _busy ? null : _schedule,
                icon: const Icon(Icons.schedule_outlined),
                label: const Text('Schedule removal'),
              )
            else
              FilledButton.icon(
                style: FilledButton.styleFrom(backgroundColor: AppColors.success),
                onPressed: _busy ? null : () => _cancel(status == 'inactive'),
                icon: const Icon(Icons.restore),
                label: Text(status == 'inactive' ? 'Reactivate' : 'Cancel removal'),
              ),
            OutlinedButton.icon(
              style: OutlinedButton.styleFrom(
                foregroundColor: AppColors.error,
                side: const BorderSide(color: AppColors.error),
              ),
              onPressed: _busy ? null : _delete,
              icon: const Icon(Icons.delete_forever_outlined),
              label: const Text('Delete permanently'),
            ),
          ],
        ),
        if (_busy) const Padding(padding: EdgeInsets.only(top: 12), child: LinearProgressIndicator()),
      ],
    );
  }

  Widget _content(Map<String, dynamic> u) {
    final isStudent = u['role'] != 'employee';
    final vehicles = asMany(u['vehicles']);
    final apps = asMany(u['applications'])
      ..sort((a, b) => str(b['submitted_at']).compareTo(str(a['submitted_at'])));
    final permits = asMany(u['permits'])
      ..sort((a, b) => str(b['valid_until']).compareTo(str(a['valid_until'])));
    final address = [u['street'], u['barangay'], u['city'], u['province']]
        .map(str)
        .where((x) => x.trim().isNotEmpty)
        .join(', ');

    return ListView(
      padding: EdgeInsets.all(pagePadding(context)),
      children: [
        Center(
          child: ConstrainedBox(
            constraints: const BoxConstraints(maxWidth: 980),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                PageTitle(
                  str(u['full_name']).isEmpty ? '(no name yet)' : str(u['full_name']),
                  subtitle: '${roleLabel(u['role'])}  |  ${str(u['email'])}',
                ),
                const SizedBox(height: 16),
                _actions(u),
                const SizedBox(height: 16),
                SectionCard(
                  title: 'Profile',
                  children: [
                    InfoRow('Email', str(u['email'])),
                    InfoRow('User type', roleLabel(u['role'])),
                    InfoRow(isStudent ? 'Student ID' : 'Employee ID', str(u['id_number']), mono: true),
                    if (isStudent) ...[
                      InfoRow('Course', str(u['program'])),
                      InfoRow('Year level', str(u['year_level'])),
                    ] else ...[
                      InfoRow('Employee type', str(u['employee_type'])),
                      InfoRow('Department / Office', str(u['department'])),
                    ],
                    InfoRow('Birthday', fmtDate(u['birthday'], time: false)),
                    InfoRow('Mobile', str(u['phone']).isEmpty ? '' : '+63 ${str(u['phone'])}'),
                    InfoRow('Address', address),
                    InfoRow('Registered', fmtDate(u['created_at'])),
                  ],
                ),
                const SizedBox(height: 16),
                SectionCard(
                  title: 'Vehicles (${vehicles.length})',
                  children: [
                    if (vehicles.isEmpty)
                      const Text('No vehicles.', style: TextStyle(color: AppColors.textMuted))
                    else
                      for (final v in vehicles)
                        Padding(
                          padding: const EdgeInsets.only(bottom: 8),
                          child: RowCard(
                            child: Wrap(
                              spacing: 24,
                              runSpacing: 8,
                              crossAxisAlignment: WrapCrossAlignment.center,
                              children: [
                                infoCol(str(v['plate_number']), vehicleLabel(v['vehicle_type']), mono: true),
                                infoCol(str(v['make_model']), '${str(v['color'])}  |  ${str(v['model_year'])}'),
                                if (v['active'] == false)
                                  const Pill('Removed')
                                else if (v['pending_verification'] == true)
                                  const Pill('Plate change pending', bg: AppColors.goldLight, fg: AppColors.goldDark, border: AppColors.gold),
                              ],
                            ),
                          ),
                        ),
                  ],
                ),
                const SizedBox(height: 16),
                SectionCard(
                  title: 'Applications (${apps.length})',
                  children: [
                    if (apps.isEmpty)
                      const Text('No applications.', style: TextStyle(color: AppColors.textMuted))
                    else
                      for (final a in apps)
                        Padding(
                          padding: const EdgeInsets.only(bottom: 8),
                          child: Material(
                            color: Colors.white,
                            borderRadius: BorderRadius.circular(14),
                            child: InkWell(
                              borderRadius: BorderRadius.circular(14),
                              onTap: () async {
                                await Navigator.push(
                                  context,
                                  MaterialPageRoute(builder: (_) => ApplicationDetailPage(id: str(a['id']))),
                                );
                                _load();
                              },
                              child: RowCard(
                                child: Wrap(
                                  spacing: 24,
                                  runSpacing: 8,
                                  crossAxisAlignment: WrapCrossAlignment.center,
                                  children: [
                                    infoCol(str(a['reference_no']), fmtDate(a['submitted_at']), mono: true),
                                    infoCol(str(asOne(a['vehicle'])['plate_number']), a['kind'] == 'renewal' ? 'Renewal' : 'New application', mono: true),
                                    statusPill(a['status']),
                                  ],
                                ),
                              ),
                            ),
                          ),
                        ),
                  ],
                ),
                const SizedBox(height: 16),
                SectionCard(
                  title: 'Permits (${permits.length})',
                  children: [
                    if (permits.isEmpty)
                      const Text('No permits.', style: TextStyle(color: AppColors.textMuted))
                    else
                      for (final p in permits)
                        Padding(
                          padding: const EdgeInsets.only(bottom: 8),
                          child: RowCard(
                            child: Wrap(
                              spacing: 24,
                              runSpacing: 8,
                              crossAxisAlignment: WrapCrossAlignment.center,
                              children: [
                                infoCol(str(p['permit_no']), 'Valid until ${fmtDate(p['valid_until'], time: false)}', mono: true),
                                infoCol(str(p['sticker_status']), 'Sticker', width: 140),
                              ],
                            ),
                          ),
                        ),
                  ],
                ),
              ],
            ),
          ),
        ),
      ],
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('User details'),
        actions: [
          IconButton(tooltip: 'Refresh', icon: const Icon(Icons.refresh), onPressed: _load),
          const SizedBox(width: 8),
        ],
      ),
      body: _loading
          ? const Center(child: CircularProgressIndicator())
          : _error != null
              ? Center(
                  child: Column(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Text(_error!, style: const TextStyle(color: AppColors.error)),
                      const SizedBox(height: 8),
                      OutlinedButton(onPressed: _load, child: const Text('Try again')),
                    ],
                  ),
                )
              : _content(_u!),
    );
  }
}

/// Choose how many days the user has to renew, and why.
class _ScheduleDialog extends StatefulWidget {
  const _ScheduleDialog();

  @override
  State<_ScheduleDialog> createState() => _ScheduleDialogState();
}

class _ScheduleDialogState extends State<_ScheduleDialog> {
  int _days = 30;
  final TextEditingController _reason = TextEditingController();

  @override
  void dispose() {
    _reason.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final date = DateTime.now().add(Duration(days: _days));
    return AlertDialog(
      title: const Text('Schedule removal'),
      content: SizedBox(
        width: 480,
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const Text('How many days does the user have to renew?'),
            const SizedBox(height: 12),
            Wrap(
              spacing: 8,
              runSpacing: 8,
              children: [
                for (final d in const [7, 14, 30, 60])
                  ChoiceChip(
                    label: Text('$d days'),
                    selected: _days == d,
                    onSelected: (_) => setState(() => _days = d),
                  ),
              ],
            ),
            const SizedBox(height: 10),
            Text(
              'The account becomes inactive on ${fmtDate(date.toIso8601String(), time: false)}.',
              style: const TextStyle(fontWeight: FontWeight.w700, color: AppColors.navy),
            ),
            const SizedBox(height: 14),
            TextField(
              controller: _reason,
              maxLength: 200,
              decoration: const InputDecoration(labelText: 'Reason (optional)', hintText: 'e.g., Graduated'),
            ),
            const Text(
              'The user is notified. Applying or renewing before that date cancels the removal.',
              style: TextStyle(fontSize: 12, color: AppColors.textHint),
            ),
          ],
        ),
      ),
      actions: [
        TextButton(onPressed: () => Navigator.pop(context), child: const Text('Cancel')),
        FilledButton(
          onPressed: () => Navigator.pop(context, (_days, _reason.text.trim())),
          child: const Text('Schedule'),
        ),
      ],
    );
  }
}

/// Permanent delete: the admin must type the user's ID number.
class _DeleteDialog extends StatefulWidget {
  const _DeleteDialog({required this.name, required this.confirmKey});

  final String name;
  final String confirmKey;

  @override
  State<_DeleteDialog> createState() => _DeleteDialogState();
}

class _DeleteDialogState extends State<_DeleteDialog> {
  final TextEditingController _typed = TextEditingController();

  @override
  void dispose() {
    _typed.dispose();
    super.dispose();
  }

  bool get _match =>
      _typed.text.trim().toUpperCase() == widget.confirmKey.trim().toUpperCase() &&
      widget.confirmKey.trim().isNotEmpty;

  @override
  Widget build(BuildContext context) {
    return AlertDialog(
      title: const Text('Delete permanently?'),
      content: SizedBox(
        width: 480,
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              'This deletes ${widget.name.isEmpty ? 'this account' : widget.name} and all of its data: profile, vehicles, applications, permits and uploaded files. This cannot be undone.',
              style: const TextStyle(height: 1.4),
            ),
            const SizedBox(height: 14),
            Text('Type ${widget.confirmKey} to confirm:', style: const TextStyle(fontWeight: FontWeight.w700)),
            const SizedBox(height: 6),
            TextField(
              controller: _typed,
              onChanged: (_) => setState(() {}),
              decoration: InputDecoration(hintText: widget.confirmKey),
            ),
          ],
        ),
      ),
      actions: [
        TextButton(onPressed: () => Navigator.pop(context), child: const Text('Cancel')),
        FilledButton(
          style: FilledButton.styleFrom(backgroundColor: AppColors.error),
          onPressed: _match ? () => Navigator.pop(context, _typed.text.trim()) : null,
          child: const Text('Delete'),
        ),
      ],
    );
  }
}