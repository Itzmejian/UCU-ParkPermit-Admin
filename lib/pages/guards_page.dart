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

  void _refresh() {
    if (mounted) setState(() {});
  }

  @override
  void initState() {
    super.initState();
    // Keep the ID card preview up to date while typing.
    for (final c in [_first, _middle, _last, _phone]) {
      c.addListener(_refresh);
    }
  }

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

  /// A white card for one group of fields, with a numbered badge.
  Widget _card(int n, IconData icon, String title, List<Widget> children, {Widget? trailing}) {
    return Container(
      width: double.infinity,
      margin: const EdgeInsets.only(bottom: 14),
      padding: const EdgeInsets.fromLTRB(16, 14, 16, 16),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(14),
        border: Border.all(color: AppColors.border),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Container(
                width: 30,
                height: 30,
                decoration: BoxDecoration(color: AppColors.inputFill, borderRadius: BorderRadius.circular(9)),
                child: Icon(icon, size: 17, color: AppColors.navy),
              ),
              const SizedBox(width: 10),
              Text(
                '$n  ',
                style: const TextStyle(fontSize: 12, fontWeight: FontWeight.w800, color: AppColors.goldDark),
              ),
              Expanded(
                child: Text(
                  title,
                  style: const TextStyle(fontSize: 14.5, fontWeight: FontWeight.w800, color: AppColors.navy),
                ),
              ),
              ?trailing,
            ],
          ),
          const SizedBox(height: 14),
          ...children,
        ],
      ),
    );
  }

  Widget _goldChip(String text, {IconData icon = Icons.place_outlined}) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
      decoration: BoxDecoration(
        color: AppColors.goldLight,
        borderRadius: BorderRadius.circular(20),
        border: Border.all(color: AppColors.gold),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(icon, size: 13, color: AppColors.goldDark),
          const SizedBox(width: 4),
          Text(text, style: const TextStyle(fontSize: 11.5, fontWeight: FontWeight.w800, color: AppColors.goldDark)),
        ],
      ),
    );
  }

  /// Navy band at the top, same look as the sidebar.
  Widget _header() {
    return Container(
      padding: const EdgeInsets.fromLTRB(22, 18, 12, 18),
      decoration: const BoxDecoration(
        gradient: LinearGradient(colors: [AppColors.navy, AppColors.navyDark]),
      ),
      child: Row(
        children: [
          Container(
            width: 44,
            height: 44,
            decoration: BoxDecoration(color: AppColors.gold, borderRadius: BorderRadius.circular(12)),
            child: Icon(_isNew ? Icons.person_add_alt_1 : Icons.shield, color: AppColors.navy),
          ),
          const SizedBox(width: 14),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  _isNew ? 'Invite a security guard' : 'Guard details',
                  style: const TextStyle(color: Colors.white, fontSize: 19, fontWeight: FontWeight.w800),
                ),
                const SizedBox(height: 2),
                Text(
                  _isNew
                      ? 'Fill in the details. The guard gets a 6-digit code by email and creates the account in the app.'
                      : 'The guard sees these details in the app and can correct them while creating the account.',
                  style: const TextStyle(color: AppColors.blueSoft, fontSize: 12.5),
                ),
              ],
            ),
          ),
          if (!_isNew) ...[const SizedBox(width: 10), guardStatusPill(_g)],
          IconButton(
            tooltip: 'Close',
            onPressed: _busy ? null : () => Navigator.pop(context),
            icon: const Icon(Icons.close, color: Colors.white70),
          ),
        ],
      ),
    );
  }

  /// A live preview of the guard's ID card.
  Widget _preview() {
    final name = _fullName.isEmpty ? 'Guard name' : _fullName;
    final id = _isNew ? 'UCU-SG-${DateTime.now().year}-####' : str(_g['id_no']);
    final phone = _phone.text.trim();
    final place = [_barangay ?? '', _city ?? '', kProvince].where((s) => s.isNotEmpty).join(', ');
    final age = ageFrom(_birthText);
    Widget line(IconData icon, String text) => Padding(
          padding: const EdgeInsets.only(top: 8),
          child: Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Icon(icon, size: 15, color: AppColors.blueSoft),
              const SizedBox(width: 8),
              Expanded(child: Text(text, style: const TextStyle(color: Colors.white, fontSize: 12.5))),
            ],
          ),
        );
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        const Text(
          'ID CARD PREVIEW',
          style: TextStyle(fontSize: 11.5, fontWeight: FontWeight.w800, letterSpacing: 0.8, color: AppColors.goldDark),
        ),
        const SizedBox(height: 10),
        Container(
          width: double.infinity,
          decoration: BoxDecoration(
            borderRadius: BorderRadius.circular(16),
            gradient: const LinearGradient(
              begin: Alignment.topLeft,
              end: Alignment.bottomRight,
              colors: [AppColors.navy, AppColors.navyDark],
            ),
            boxShadow: const [BoxShadow(color: Color(0x33000000), blurRadius: 18, offset: Offset(0, 8))],
          ),
          child: Column(
            children: [
              Container(height: 5, color: AppColors.gold),
              Padding(
                padding: const EdgeInsets.all(16),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    const Row(
                      children: [
                        AdminLogo(size: 30),
                        SizedBox(width: 8),
                        Expanded(
                          child: Text(
                            'UCU SECURITY OFFICE',
                            style: TextStyle(color: AppColors.gold, fontSize: 10.5, fontWeight: FontWeight.w800, letterSpacing: 0.8),
                          ),
                        ),
                      ],
                    ),
                    const SizedBox(height: 16),
                    Center(
                      child: Container(
                        width: 72,
                        height: 72,
                        decoration: BoxDecoration(
                          shape: BoxShape.circle,
                          color: Colors.white.withValues(alpha: 0.12),
                          border: Border.all(color: AppColors.gold, width: 2),
                        ),
                        child: Center(
                          child: Text(
                            _initials,
                            style: const TextStyle(color: Colors.white, fontSize: 24, fontWeight: FontWeight.w800),
                          ),
                        ),
                      ),
                    ),
                    const SizedBox(height: 12),
                    Center(
                      child: Text(
                        name,
                        textAlign: TextAlign.center,
                        style: const TextStyle(color: Colors.white, fontSize: 16, fontWeight: FontWeight.w800),
                      ),
                    ),
                    const SizedBox(height: 4),
                    const Center(
                      child: Text('SECURITY GUARD', style: TextStyle(color: AppColors.blueSoft, fontSize: 10.5, letterSpacing: 1.2)),
                    ),
                    const SizedBox(height: 12),
                    Center(
                      child: Container(
                        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 5),
                        decoration: BoxDecoration(color: AppColors.gold, borderRadius: BorderRadius.circular(8)),
                        child: Text(
                          id,
                          style: const TextStyle(
                            color: AppColors.navy,
                            fontWeight: FontWeight.w800,
                            fontFamily: 'monospace',
                            fontSize: 12.5,
                          ),
                        ),
                      ),
                    ),
                    const SizedBox(height: 8),
                    Divider(color: Colors.white.withValues(alpha: 0.15)),
                    line(Icons.phone_outlined, phone.isEmpty ? 'Mobile number' : phone),
                    line(Icons.cake_outlined, _birth == null ? 'Birthday' : '${fmtBirthday(_birthText)}${age == null ? '' : ' ($age)'}'),
                    line(Icons.place_outlined, place),
                  ],
                ),
              ),
            ],
          ),
        ),
        const SizedBox(height: 12),
        Text(
          _isNew
              ? 'The Guard ID number is given automatically when you send the invite.'
              : 'The Guard ID never changes.',
          style: const TextStyle(fontSize: 12, color: AppColors.textHint),
        ),
      ],
    );
  }

  String get _initials {
    final a = _first.text.trim();
    final b = _last.text.trim();
    final s = '${a.isEmpty ? '' : a[0]}${b.isEmpty ? '' : b[0]}'.toUpperCase();
    return s.isEmpty ? '?' : s;
  }

  @override
  Widget build(BuildContext context) {
    final scans = int.tryParse(str(_g['scans'])) ?? 0;
    final barangays = _city == null ? const <String>[] : (kPangasinanBarangays[_city] ?? const <String>[]);
    final edited = str(_g['guard_edited_at']);
    final screen = MediaQuery.sizeOf(context);
    final wide = screen.width >= 980;

    final form = Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        if (!_isNew && !wide)
          Padding(
            padding: const EdgeInsets.only(bottom: 10),
            child: InfoRow('Guard ID', str(_g['id_no']), mono: true),
          ),
        if (!_isNew && edited.isNotEmpty)
          Container(
            margin: const EdgeInsets.only(bottom: 14),
            padding: const EdgeInsets.all(12),
            decoration: BoxDecoration(
              color: AppColors.goldLight,
              borderRadius: BorderRadius.circular(12),
              border: Border.all(color: AppColors.gold),
            ),
            child: Row(
              children: [
                const Icon(Icons.edit_note, size: 20, color: AppColors.goldDark),
                const SizedBox(width: 8),
                Expanded(
                  child: Text(
                    'The guard updated these details on ${fmtDate(edited)}.',
                    style: const TextStyle(fontSize: 13, color: AppColors.textDark),
                  ),
                ),
              ],
            ),
          ),
        _card(1, Icons.person_outline, 'Full name', [
          _row([
            _field(_first, 'First name *', hint: 'Juan', caps: TextCapitalization.words, maxLength: 60),
            _field(_middle, 'Middle name', hint: 'Optional', caps: TextCapitalization.words, maxLength: 60),
          ]),
          const SizedBox(height: 12),
          _row([
            _field(_last, 'Last name *', hint: 'Dela Cruz', caps: TextCapitalization.words, maxLength: 60),
            _dropdown(
              label: 'Suffix',
              icon: Icons.short_text,
              value: _suffix,
              items: ['None', ..._suffixes],
              hint: 'None',
              onChanged: (v) => setState(() => _suffix = (v == null || v == 'None') ? null : v),
            ),
          ], flex: const [2, 1]),
        ]),
        _card(2, Icons.contact_mail_outlined, 'Account and contact', [
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
          if (_isNew)
            const Padding(
              padding: EdgeInsets.only(top: 8),
              child: Text(
                'The 6-digit code is sent to this email. The email cannot be changed later.',
                style: TextStyle(fontSize: 12, color: AppColors.textHint),
              ),
            ),
        ]),
        _card(3, Icons.badge_outlined, 'Personal information', [
          _row([
            InkWell(
              borderRadius: BorderRadius.circular(12),
              onTap: _busy ? null : _pickBirthday,
              child: InputDecorator(
                decoration: const InputDecoration(
                  labelText: 'Birthday *',
                  prefixIcon: Icon(Icons.cake_outlined),
                  suffixIcon: Icon(Icons.calendar_month_outlined),
                ),
                child: Text(
                  _birth == null
                      ? 'Choose date'
                      : '${fmtBirthday(_birthText)}${ageFrom(_birthText) == null ? '' : '  (${ageFrom(_birthText)} yrs old)'}',
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
        ]),
        _card(
          4,
          Icons.home_outlined,
          'Home address',
          [
            _row([
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
              _dropdown(
                label: 'Barangay *',
                icon: Icons.location_on_outlined,
                value: _barangay,
                items: barangays,
                hint: _city == null ? 'Choose the city first' : 'Choose barangay',
                enabled: _city != null,
                onChanged: (v) => setState(() => _barangay = v),
              ),
            ]),
            const SizedBox(height: 12),
            _field(_street, 'House no. / Street / Purok (optional)', hint: 'e.g., 123 Rizal St. or Purok 3', icon: Icons.signpost_outlined, caps: TextCapitalization.words),
          ],
          trailing: _goldChip('Pangasinan'),
        ),
        if (!_isNew)
          _card(5, Icons.verified_user_outlined, 'Account status', [
            InfoRow('Invited', str(_g['invited_at']).isEmpty ? '-' : fmtDate(_g['invited_at'])),
            InfoRow(
              'Account created',
              str(_g['activated_at']).isEmpty ? 'Not yet. Waiting for the guard to enter the code.' : fmtDate(_g['activated_at']),
            ),
            InfoRow('Gate scans', '$scans'),
          ]),
      ],
    );

    return Dialog(
      insetPadding: const EdgeInsets.all(20),
      clipBehavior: Clip.antiAlias,
      backgroundColor: AppColors.surface,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
      child: ConstrainedBox(
        constraints: BoxConstraints(maxWidth: wide ? 1040 : 640, maxHeight: screen.height - 40),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            _header(),
            Container(height: 4, color: AppColors.gold),
            Flexible(
              child: SingleChildScrollView(
                padding: const EdgeInsets.fromLTRB(20, 18, 20, 6),
                child: wide
                    ? Row(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Expanded(child: form),
                          const SizedBox(width: 20),
                          SizedBox(width: 300, child: _preview()),
                        ],
                      )
                    : form,
              ),
            ),
            Container(
              padding: const EdgeInsets.fromLTRB(20, 12, 20, 14),
              decoration: const BoxDecoration(
                color: Colors.white,
                border: Border(top: BorderSide(color: AppColors.border)),
              ),
              child: Row(
                children: [
                  Expanded(
                    child: _error != null
                        ? Row(
                            children: [
                              const Icon(Icons.error_outline, size: 18, color: AppColors.error),
                              const SizedBox(width: 6),
                              Expanded(child: Text(_error!, style: const TextStyle(color: AppColors.error, fontSize: 13))),
                            ],
                          )
                        : const Text('* Required', style: TextStyle(fontSize: 12, color: AppColors.textHint)),
                  ),
                  const SizedBox(width: 12),
                  TextButton(
                    onPressed: _busy ? null : () => Navigator.pop(context),
                    child: Text(_isNew ? 'Cancel' : 'Close'),
                  ),
                  const SizedBox(width: 8),
                  FilledButton.icon(
                    style: FilledButton.styleFrom(padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 14)),
                    onPressed: _busy ? null : _submit,
                    icon: _busy
                        ? const SizedBox(width: 16, height: 16, child: CircularProgressIndicator(strokeWidth: 2, color: Colors.white))
                        : Icon(_isNew ? Icons.send : Icons.save_outlined, size: 18),
                    label: Text(_busy ? 'Saving...' : (_isNew ? 'Send invite' : 'Save changes')),
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }
}
