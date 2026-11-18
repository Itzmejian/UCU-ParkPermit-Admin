import 'package:flutter/material.dart';
import '../admin_service.dart';
import '../ui.dart';
import 'common.dart';

class AccountPage extends StatefulWidget {
  const AccountPage({super.key, required this.onChanged});

  /// Lets the sidebar show the new name or email.
  final VoidCallback onChanged;

  @override
  State<AccountPage> createState() => _AccountPageState();
}

class _AccountPageState extends State<AccountPage> {
  final _name = TextEditingController(text: AdminService.displayName == 'Admin' ? '' : AdminService.displayName);
  final _curPw = TextEditingController();
  final _newPw = TextEditingController();
  final _newPw2 = TextEditingController();
  bool _busy = false;
  String? _pwError;

  @override
  void dispose() {
    for (final c in [_name, _curPw, _newPw, _newPw2]) {
      c.dispose();
    }
    super.dispose();
  }

  Future<void> _saveName() async {
    final n = _name.text.trim();
    if (n.length < 2) {
      showSnack(context, 'Enter your full name.');
      return;
    }
    setState(() => _busy = true);
    final err = await AdminService.updateName(n);
    if (!mounted) return;
    setState(() => _busy = false);
    showSnack(context, err ?? 'Name saved.');
    if (err == null) widget.onChanged();
  }

  Future<void> _savePassword() async {
    setState(() => _pwError = null);
    if (_curPw.text.isEmpty) return setState(() => _pwError = 'Enter your current password.');
    if (_newPw.text.length < 8) return setState(() => _pwError = 'The new password needs at least 8 characters.');
    if (_newPw.text != _newPw2.text) return setState(() => _pwError = 'The new passwords do not match.');
    setState(() => _busy = true);
    final err = await AdminService.changePassword(_curPw.text, _newPw.text);
    if (!mounted) return;
    setState(() {
      _busy = false;
      _pwError = err;
    });
    if (err == null) {
      _curPw.clear();
      _newPw.clear();
      _newPw2.clear();
      showSnack(context, 'Password changed. Use the new password next time you log in.');
    }
  }

  Widget _pwField(TextEditingController c, String label) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 12),
      child: TextField(
        controller: c,
        obscureText: true,
        decoration: InputDecoration(labelText: label, prefixIcon: const Icon(Icons.lock_outline)),
      ),
    );
  }

  Widget _error(String? e) => e == null
      ? const SizedBox.shrink()
      : Padding(
          padding: const EdgeInsets.only(bottom: 12),
          child: Text(e, style: const TextStyle(color: AppColors.error)),
        );

  @override
  Widget build(BuildContext context) {
    final u = AdminService.currentUser;
    final wide = MediaQuery.sizeOf(context).width >= 1100;
    final name = AdminService.displayName;

    final account = SectionCard(
      title: 'Account',
      children: [
        Container(
          margin: const EdgeInsets.only(bottom: 8),
          padding: const EdgeInsets.all(14),
          decoration: BoxDecoration(
            color: AppColors.inputFill,
            borderRadius: BorderRadius.circular(14),
          ),
          child: Row(
            children: [
              CircleAvatar(
                radius: 26,
                backgroundColor: AppColors.navy,
                child: Text(
                  name.isEmpty ? 'A' : name[0].toUpperCase(),
                  style: const TextStyle(color: AppColors.gold, fontSize: 22, fontWeight: FontWeight.w800),
                ),
              ),
              const SizedBox(width: 14),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(name, style: const TextStyle(fontSize: 17, fontWeight: FontWeight.w800, color: AppColors.navy)),
                    Text(AdminService.email ?? '', style: const TextStyle(color: AppColors.textMuted)),
                  ],
                ),
              ),
              const Pill('Admin', bg: AppColors.goldLight, fg: AppColors.goldDark, border: AppColors.gold),
            ],
          ),
        ),
        InfoRow('Role', 'Security Office Admin'),
        InfoRow('Last log in', fmtDate(u?.lastSignInAt)),
        InfoRow('Account created', fmtDate(u?.createdAt, time: false)),
        const SizedBox(height: 16),
        Row(
          children: [
            Expanded(
              child: TextField(
                controller: _name,
                decoration: const InputDecoration(labelText: 'Your name', prefixIcon: Icon(Icons.person_outline)),
              ),
            ),
            const SizedBox(width: 10),
            OutlinedButton(onPressed: _busy ? null : _saveName, child: const Text('Save Name')),
          ],
        ),
      ],
    );

    final password = SectionCard(
      title: 'Change password',
      children: [
        const Padding(
          padding: EdgeInsets.only(bottom: 12),
          child: Text(
            'Use at least 8 characters. Forgot it? Use "Forgot password?" on the login page.',
            style: TextStyle(color: AppColors.textMuted),
          ),
        ),
        _pwField(_curPw, 'Current password'),
        _pwField(_newPw, 'New password (at least 8 characters)'),
        _pwField(_newPw2, 'Confirm new password'),
        _error(_pwError),
        Align(
          alignment: Alignment.centerLeft,
          child: FilledButton.icon(
            onPressed: _busy ? null : _savePassword,
            icon: const Icon(Icons.lock_reset, size: 18),
            label: const Text('Change Password'),
          ),
        ),
      ],
    );

    return ListView(
      padding: EdgeInsets.all(pagePadding(context)),
      children: [
        const PageTitle('My account', icon: Icons.manage_accounts_outlined, subtitle: 'Your Security Office login. Keep your password private.'),
        const SizedBox(height: 16),
        if (wide)
          Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Expanded(child: account),
              const SizedBox(width: 16),
              Expanded(child: password),
            ],
          )
        else ...[
          account,
          const SizedBox(height: 16),
          password,
        ],
        if (_busy)
          const Padding(
            padding: EdgeInsets.only(top: 16),
            child: LinearProgressIndicator(),
          ),
      ],
    );
  }
}
