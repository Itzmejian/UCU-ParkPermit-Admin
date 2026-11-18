import 'package:flutter/material.dart';
import '../admin_service.dart';
import '../ui.dart';
import '../pangasinan_address.dart';
import 'common.dart';

/// Guard accounts. The admin enters the guard's personal details and Gmail;
/// the Guard ID is made automatically. The guard gets a 6-digit code, checks
/// these details in the app and sets a password.
class GuardsPage extends StatefulWidget {
  const GuardsPage({super.key});

  @override
  State<GuardsPage> createState() => _GuardsPageState();
}

const _months = ['Jan', 'Feb', 'Mar', 'Apr', 'May', 'Jun', 'Jul', 'Aug', 'Sep', 'Oct', 'Nov', 'Dec'];

/// "1995-03-07" -> "Mar 7, 1995"
String fmtBirthday(dynamic v) {
  final d = DateTime.tryParse(str(v));
  if (d == null) return '';
  return '${_months[d.month - 1]} ${d.day}, ${d.year}';
}

int? ageFrom(dynamic v) {
  final d = DateTime.tryParse(str(v));
  if (d == null) return null;
  final now = DateTime.now();
  var age = now.year - d.year;
  if (now.month < d.month || (now.month == d.month && now.day < d.day)) age--;
  return age;
}

String fullAddress(Map<String, dynamic> g) =>
    [str(g['address']), str(g['barangay']), str(g['city']), str(g['province'])].where((s) => s.isNotEmpty).join(', ');

bool _isPending(Map<String, dynamic> g) => str(g['activated_at']).isEmpty;

Widget guardStatusPill(Map<String, dynamic> g) {
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
        'active' => !_isPending(r),
        'pending' => _isPending(r),
        _ => true,
      };
      if (!ok) return false;
      if (q.isEmpty) return true;
      return '${r['full_name']} ${r['email']} ${r['id_no']} ${r['phone']}'.toLowerCase().contains(q);
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
    final saved = await showDialog<String>(
      context: context,
      barrierDismissible: false,
      builder: (_) => _GuardFormDialog(guard: g),
    );
    if (saved != null && mounted) {
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

  Future<void> _delete(Map<String, dynamic> g) async {
    final id = str(g['id_no']);
    final ctrl = TextEditingController();
    String? err;
    var busy = false;
    final deleted = await showDialog<bool>(
      context: context,
      barrierDismissible: false,
      builder: (ctx) => StatefulBuilder(
        builder: (ctx, setD) {
          return AlertDialog(
            title: const Text('Delete this guard?'),
            content: SizedBox(
              width: 440,
              child: Column(
                mainAxisSize: MainAxisSize.min,
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    '${str(g['full_name'])} (${str(g['email'])}) will be removed and can no longer log in '
                    'to the guard module. This cannot be undone.\n\n'
                    'Their past gate scans stay in the Gate scans log with their name.',
                  ),
                  const SizedBox(height: 14),
                  Text('Type the Guard ID $id to confirm:', style: const TextStyle(fontWeight: FontWeight.w700)),
                  const SizedBox(height: 8),
                  TextField(
                    controller: ctrl,
                    autofocus: true,
                    decoration: InputDecoration(hintText: id, isDense: true),
                  ),
                  if (err != null) ...[
                    const SizedBox(height: 8),
                    Text(err!, style: const TextStyle(color: AppColors.error, fontSize: 13)),
                  ],
                ],
              ),
            ),
            actions: [
              TextButton(onPressed: () => Navigator.pop(ctx, false), child: const Text('Cancel')),
              FilledButton(
                style: FilledButton.styleFrom(backgroundColor: AppColors.error),
                onPressed: busy
                    ? null
                    : () async {
                        if (ctrl.text.trim().toUpperCase() != id.toUpperCase()) {
                          setD(() => err = 'Type $id exactly.');
                          return;
                        }
                        setD(() => busy = true);
                        final e = await AdminService.deleteGuard(str(g['user_id']), ctrl.text.trim());
                        if (!ctx.mounted) return;
                        if (e != null) {
                          setD(() {
                            busy = false;
                            err = e;
                          });
                          return;
                        }
                        Navigator.pop(ctx, true);
                      },
                child: Text(busy ? 'Deleting...' : 'Delete guard'),
              ),
            ],
          );
        },
      ),
    );
    ctrl.dispose();
    if (deleted == true && mounted) {
      showSnack(context, '${str(g['full_name'])} was deleted.');
      _load();
    }
  }

  Widget _row(Map<String, dynamic> g) {
    final scans = int.tryParse(str(g['scans'])) ?? 0;
    final last = str(g['last_scan']);
    final phone = str(g['phone']);
    return RowCard(
      child: Wrap(
        spacing: 24,
        runSpacing: 12,
        crossAxisAlignment: WrapCrossAlignment.center,
        children: [
          Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              const CircleAvatar(
                radius: 20,
                backgroundColor: AppColors.navy,
                child: Icon(Icons.shield_outlined, color: Colors.white, size: 20),
              ),
              const SizedBox(width: 12),
              infoCol(str(g['full_name']), str(g['email']), width: 250),
            ],
          ),
          infoCol(str(g['id_no']), phone.isEmpty ? 'No mobile number' : phone, mono: true, width: 190),
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
                style: OutlinedButton.styleFrom(foregroundColor: AppColors.error),
                onPressed: () => _delete(g),
                icon: const Icon(Icons.delete_outline, size: 18),
                label: const Text('Delete'),
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
      searchHint: 'Search name, email, ID or mobile',
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
/// Pops with the email (invite) or 'saved' (edit).
class _GuardFormDialog extends StatefulWidget {
  const _GuardFormDialog({this.guard});

  final Map<String, dynamic>? guard;

  @override
  State<_GuardFormDialog> createState() => _GuardFormDialogState();
}

class _GuardFormDialogState extends State<_GuardFormDialog> {
  late final Map<String, dynamic> _g = widget.guard ?? const {};
  late final _first = TextEditingController(text: str(_g['first_name']));
  late final _middle = TextEditingController(text: str(_g['middle_name']));
  late final _last = TextEditingController(text: str(_g['last_name']));
  late final _email = TextEditingController(text: str(_g['email']));
  late final _phone = TextEditingController(text: str(_g['phone']));
  late final _street = TextEditingController(text: str(_g['address']));
  late String? _suffix = str(_g['suffix']).isEmpty ? null : str(_g['suffix']);
  late DateTime? _birth = DateTime.tryParse(str(_g['birthdate']));
  late String? _sex = str(_g['sex']).isEmpty ? null : str(_g['sex']);
  late String? _city = matchPangasinanCity(str(_g['city']));
  late String? _barangay = _city == null ? null : matchPangasinanBarangay(_city!, str(_g['barangay']));
  bool _busy = false;
  String? _error;

  static const _suffixes = ['Jr.', 'Sr.', 'II', 'III', 'IV', 'V'];

  bool get _isNew => widget.guard == null;

  @override
  void dispose() {
    for (final c in [_first, _middle, _last, _email, _phone, _street]) {
      c.dispose();
    }
    super.dispose();
  }

  String get _birthText {
    final b = _birth;
    if (b == null) return '';
    return '${b.year.toString().padLeft(4, '0')}-${b.month.toString().padLeft(2, '0')}-${b.day.toString().padLeft(2, '0')}';
  }

  String get _fullName => [_first.text.trim(), _middle.text.trim(), _last.text.trim(), _suffix ?? '']
      .where((s) => s.isNotEmpty)
      .join(' ');

  Map<String, String> get _details => {
        'first_name': _first.text.trim(),
        'middle_name': _middle.text.trim(),
        'last_name': _last.text.trim(),
        'suffix': _suffix ?? '',
        'phone': _phone.text.trim().replaceAll(' ', ''),
        'birthdate': _birthText,
        'sex': _sex ?? '',
        'street': _street.text.trim(),
        'barangay': _barangay ?? '',
        'city': _city ?? '',
      };

  Future<void> _pickBirthday() async {
    final now = DateTime.now();
    final latest = DateTime(now.year - 18, now.month, now.day);
    final picked = await showDatePicker(
      context: context,
      initialDate: _birth ?? DateTime(now.year - 30, 1, 1),
      firstDate: DateTime(1940),
      lastDate: latest,
      helpText: 'Guard birthday',
      initialEntryMode: DatePickerEntryMode.calendarOnly,
    );
    if (picked != null) setState(() => _birth = picked);
  }

  String? _check() {
    if (_first.text.trim().isEmpty) return 'Enter the first name.';
    if (_last.text.trim().isEmpty) return 'Enter the last name.';
    if (_isNew && !RegExp(r'^[^\s@]+@[^\s@]+\.[^\s@]+$').hasMatch(_email.text.trim())) {
      return 'Enter a valid email address (for example a Gmail).';
    }
    if (!RegExp(r'^09\d{9}$').hasMatch(_phone.text.trim().replaceAll(' ', ''))) {
      return 'Enter the mobile number (09XXXXXXXXX).';
    }
    if (_birth == null) return 'Choose the birthday.';
    if (_sex == null) return 'Choose the sex.';
    if (_city == null) return 'Choose the city or municipality.';
    if (_barangay == null) return 'Choose the barangay.';
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
      err = await AdminService.inviteGuard(_email.text.trim().toLowerCase(), _fullName, details: _details);
    } else {
      err = await AdminService.updateGuard(str(_g['user_id']), _details);
    }
    if (!mounted) return;
    if (err == null || err.startsWith('Guard saved')) {
      if (err != null) showSnack(context, err);
      Navigator.pop(context, _isNew ? _email.text.trim().toLowerCase() : 'saved');
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
    int? maxLength,
  }) {
    return TextField(
      controller: c,
      enabled: enabled && !_busy,
      keyboardType: type,
      textCapitalization: caps,
      maxLength: maxLength,
      decoration: InputDecoration(
        labelText: label,
        hintText: hint,
        counterText: '',
        prefixIcon: icon == null ? null : Icon(icon),
      ),
    );
  }

  /// A dropdown that looks like the text fields.
  Widget _dropdown({
    required String label,
    required IconData icon,
    required String? value,
    required List<String> items,
    required ValueChanged<String?> onChanged,
    String hint = 'Choose',
    bool enabled = true,
  }) {
    return InputDecorator(
      decoration: InputDecoration(
        labelText: label,
        prefixIcon: Icon(icon),
        enabled: enabled && !_busy,
        contentPadding: const EdgeInsets.symmetric(horizontal: 12, vertical: 4),
      ),
      child: DropdownButtonHideUnderline(
        child: DropdownButton<String>(
          value: value,
          isExpanded: true,
          menuMaxHeight: 360,
          hint: Text(hint, style: const TextStyle(color: AppColors.textHint)),
          items: [
            for (final s in items) DropdownMenuItem(value: s, child: Text(s, overflow: TextOverflow.ellipsis)),
          ],
          onChanged: (_busy || !enabled) ? null : onChanged,
        ),
      ),
    );
  }

  Widget _row(List<Widget> children, {List<int>? flex}) {
    return LayoutBuilder(
      builder: (context, c) {
        if (c.maxWidth < 460) {
          return Column(
            children: [
              for (var i = 0; i < children.length; i++) ...[
                if (i > 0) const SizedBox(height: 12),
                children[i],
              ],
            ],
          );
        }
        return Row(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            for (var i = 0; i < children.length; i++) ...[
              if (i > 0) const SizedBox(width: 12),
              Expanded(flex: flex?[i] ?? 1, child: children[i]),
            ],
          ],
        );
      },
    );
  }

  Widget _section(String text) => Padding(
        padding: const EdgeInsets.only(top: 18, bottom: 10),
        child: Text(
          text.toUpperCase(),
          style: const TextStyle(fontSize: 11.5, fontWeight: FontWeight.w800, letterSpacing: 0.8, color: AppColors.goldDark),
        ),
      );

  @override
  Widget build(BuildContext context) {
    final scans = int.tryParse(str(_g['scans'])) ?? 0;
    final age = ageFrom(_birthText);
    final barangays = _city == null ? const <String>[] : (kPangasinanBarangays[_city] ?? const <String>[]);
    final edited = str(_g['guard_edited_at']);
    return AlertDialog(
      title: Row(
        children: [
          Expanded(child: Text(_isNew ? 'Invite guard' : 'Guard details')),
          if (!_isNew) guardStatusPill(_g),
        ],
      ),
      content: SizedBox(
        width: 620,
        child: SingleChildScrollView(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                _isNew
                    ? 'Enter the guard\'s details. The Guard ID is made automatically. The guard will get an email '
                        'with a 6-digit code. In the app they tap "Create guard account", enter the code, check '
                        '(and fix) these details, then create their own password.'
                    : 'The guard sees these details in the app and can correct them while creating the account.',
                style: const TextStyle(fontSize: 13, color: AppColors.textMuted),
              ),
              if (!_isNew) ...[
                const SizedBox(height: 12),
                InfoRow('Guard ID', str(_g['id_no']), mono: true),
                if (edited.isNotEmpty)
                  Container(
                    margin: const EdgeInsets.only(top: 10),
                    padding: const EdgeInsets.all(10),
                    decoration: BoxDecoration(
                      color: AppColors.goldLight,
                      borderRadius: BorderRadius.circular(10),
                      border: Border.all(color: AppColors.gold),
                    ),
                    child: Row(
                      children: [
                        const Icon(Icons.edit_note, size: 18, color: AppColors.goldDark),
                        const SizedBox(width: 8),
                        Expanded(
                          child: Text(
                            'The guard updated these details on ${fmtDate(edited)}.',
                            style: const TextStyle(fontSize: 12.5, color: AppColors.textDark),
                          ),
                        ),
                      ],
                    ),
                  ),
              ],
              _section('Name'),
              _row([
                _field(_first, 'First name *', hint: 'Juan', icon: Icons.person_outline, caps: TextCapitalization.words, maxLength: 60),
                _field(_middle, 'Middle name', hint: 'Optional', caps: TextCapitalization.words, maxLength: 60),
              ]),
              const SizedBox(height: 12),
              _row([
                _field(_last, 'Last name *', hint: 'Dela Cruz', icon: Icons.badge_outlined, caps: TextCapitalization.words, maxLength: 60),
                _dropdown(
                  label: 'Suffix',
                  icon: Icons.short_text,
                  value: _suffix,
                  items: ['None', ..._suffixes],
                  hint: 'None',
                  onChanged: (v) => setState(() => _suffix = (v == null || v == 'None') ? null : v),
                ),
              ], flex: const [2, 1]),
              _section('Account and contact'),
              _row([
                _field(
                  _email,
                  'Email (Gmail) *',
                  hint: 'guard.name@gmail.com',
                  icon: Icons.mail_outline,
                  type: TextInputType.emailAddress,
                  enabled: _isNew,
                ),
                _field(_phone, 'Mobile number *', hint: '09XXXXXXXXX', icon: Icons.phone_outlined, type: TextInputType.phone, maxLength: 11),
              ]),
              _section('Personal information'),
              _row([
                InkWell(
                  onTap: _busy ? null : _pickBirthday,
                  child: InputDecorator(
                    decoration: const InputDecoration(
                      labelText: 'Birthday *',
                      prefixIcon: Icon(Icons.cake_outlined),
                      suffixIcon: Icon(Icons.calendar_month_outlined),
                    ),
                    child: Text(
                      _birth == null ? 'Choose date' : '${fmtBirthday(_birthText)}${age == null ? '' : '  ($age yrs old)'}',
                      style: TextStyle(color: _birth == null ? AppColors.textHint : AppColors.textDark),
                    ),
                  ),
                ),
                _dropdown(
                  label: 'Sex *',
                  icon: Icons.wc_outlined,
                  value: _sex,
                  items: const ['Male', 'Female'],
                  onChanged: (v) => setState(() => _sex = v),
                ),
              ]),
              _section('Home address'),
              _row([
                InputDecorator(
                  decoration: const InputDecoration(
                    labelText: 'Province',
                    prefixIcon: Icon(Icons.map_outlined),
                    suffixIcon: Icon(Icons.lock_outline, size: 18),
                  ),
                  child: const Text(kProvince),
                ),
                _dropdown(
                  label: 'City / Municipality *',
                  icon: Icons.location_city_outlined,
                  value: _city,
                  items: kPangasinanCities,
                  hint: 'Choose city or municipality',
                  onChanged: (v) => setState(() {
                    if (v != _city) _barangay = null;
                    _city = v;
                  }),
                ),
              ]),
              const SizedBox(height: 12),
              _row([
                _dropdown(
                  label: 'Barangay *',
                  icon: Icons.location_on_outlined,
                  value: _barangay,
                  items: barangays,
                  hint: _city == null ? 'Choose the city first' : 'Choose barangay',
                  enabled: _city != null,
                  onChanged: (v) => setState(() => _barangay = v),
                ),
                _field(_street, 'Street / Purok (optional)', hint: 'e.g., 123 Rizal St. or Purok 3', icon: Icons.home_outlined, caps: TextCapitalization.words),
              ]),
              const Padding(
                padding: EdgeInsets.only(top: 6),
                child: Text('Only addresses in Pangasinan are accepted.', style: TextStyle(fontSize: 12, color: AppColors.textHint)),
              ),
              if (!_isNew) ...[
                _section('Account status'),
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
