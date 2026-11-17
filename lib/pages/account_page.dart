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
  final _newEmail = TextEditingController();
  final _emailPw = TextEditingController();
  bool _busy = false;
  String? _pwError;
  String? _emailError;

  @override
  void dispose() {
    for (final c in [_name, _curPw, _newPw, _newPw2, _newEmail, _emailPw]) {
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

  Future<void> _saveEmail() async {
    setState(() => _emailError = null);
    final e = _newEmail.text.trim();
    if (!RegExp(r'^[^@\s]+@[^@\s]+\.[^@\s]+$').hasMatch(e)) {
      return setState(() => _emailError = 'Enter a valid email address.');
    }
    if (e.toLowerCase() == (AdminService.email ?? '').toLowerCase()) {
      return setState(() => _emailError = 'That is already your email.');
    }
    if (_emailPw.text.isEmpty) return setState(() => _emailError = 'Enter your current password.');
    setState(() => _busy = true);
    final err = await AdminService.changeEmail(_emailPw.text, e);
    if (!mounted) return;
    setState(() {
      _busy = false;
      _emailError = err;
    });
    if (err == null) {
      _newEmail.clear();
      _emailPw.clear();
      await showDialog<void>(
        context: context,
        builder: (ctx) => AlertDialog(
          title: const Text('Check your email'),
          content: Text(
            'We sent a confirmation link to $e. Your login email changes only after you open that link. Until then, keep using ${AdminService.email ?? 'your current email'}.',
          ),
          actions: [FilledButton(onPressed: () => Navigator.pop(ctx), child: const Text('OK'))],
        ),
      );
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
    final password = SectionCard(
      title: 'Change password',
      children: [
        _pwField(_curPw, 'Current password'),
        _pwField(_newPw, 'New password (at least 8 characters)'),
        _pwField(_newPw2, 'Confirm new password'),
        _error(_pwError),
        Align(
          alignment: Alignment.centerLeft,
          child: FilledButton(onPressed: _busy ? null : _savePassword, child: const Text('Change Password')),
        ),
      ],
    );
    final email = SectionCard(
      title: 'Change email',
      children: [
        const Padding(
          padding: EdgeInsets.only(bottom: 12),
          child: Text(
            'Use an email the Security Office can open. Password reset codes are sent there.',
            style: TextStyle(color: AppColors.textMuted),
          ),
        ),
        Padding(
          padding: const EdgeInsets.only(bottom: 12),
          child: TextField(
            controller: _newEmail,
            keyboardType: TextInputType.emailAddress,
            decoration: const InputDecoration(labelText: 'New email', prefixIcon: Icon(Icons.mail_outline)),
          ),
        ),
        _pwField(_emailPw, 'Current password'),
        _error(_emailError),
        Align(
          alignment: Alignment.centerLeft,
          child: OutlinedButton(onPressed: _busy ? null : _saveEmail, child: const Text('Change Email')),
        ),
      ],
    );

    return ListView(
      padding: EdgeInsets.all(pagePadding(context)),
      children: [
        const PageTitle('My account', subtitle: 'Your Security Office login. Keep your email and password private.'),
        const SizedBox(height: 16),
        SectionCard(
          title: 'Account',
          children: [
            InfoRow('Email', AdminService.email ?? ''),
            InfoRow('Role', 'Security Office Admin'),
            InfoRow('Last log in', fmtDate(u?.lastSignInAt)),
            InfoRow('Account created', fmtDate(u?.createdAt, time: false)),
            const SizedBox(height: 14),
            Wrap(
              spacing: 10,
              runSpacing: 10,
              crossAxisAlignment: WrapCrossAlignment.center,
              children: [
                SizedBox(
                  width: 320,
                  child: TextField(
                    controller: _name,
                    decoration: const InputDecoration(labelText: 'Your name', prefixIcon: Icon(Icons.person_outline)),
                  ),
                ),
                OutlinedButton(onPressed: _busy ? null : _saveName, child: const Text('Save Name')),
              ],
            ),
          ],
        ),
        const SizedBox(height: 16),
        if (wide)
          Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Expanded(child: password),
              const SizedBox(width: 16),
              Expanded(child: email),
            ],
          )
        else ...[
          password,
          const SizedBox(height: 16),
          email,
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