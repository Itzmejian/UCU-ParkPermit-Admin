import 'dart:math' as math;
import 'package:flutter/material.dart';
import '../admin_service.dart';
import '../ui.dart';

class LoginPage extends StatefulWidget {
  const LoginPage({super.key, required this.onLoggedIn});

  final VoidCallback onLoggedIn;

  @override
  State<LoginPage> createState() => _LoginPageState();
}

class _LoginPageState extends State<LoginPage> {
  final _email = TextEditingController();
  final _password = TextEditingController();
  bool _loading = false;
  bool _hide = true;
  String? _error;

  @override
  void dispose() {
    _email.dispose();
    _password.dispose();
    super.dispose();
  }

  Future<void> _login() async {
    final email = _email.text.trim();
    if (email.isEmpty || _password.text.isEmpty) {
      setState(() => _error = 'Enter your email and password.');
      return;
    }
    setState(() {
      _loading = true;
      _error = null;
    });
    final err = await AdminService.signIn(email, _password.text);
    if (!mounted) return;
    if (err != null) {
      setState(() {
        _loading = false;
        _error = err;
      });
      return;
    }
    widget.onLoggedIn();
  }

  Future<void> _forgot() async {
    final done = await showDialog<bool>(
      context: context,
      builder: (_) => _ForgotDialog(email: _email.text.trim()),
    );
    if (done == true && mounted) {
      setState(() => _error = null);
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Password changed. Log in with your new password.')),
      );
    }
  }

  Widget _brandPanel() {
    return Container(
      decoration: const BoxDecoration(
        gradient: LinearGradient(
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
          colors: [AppColors.navy, AppColors.navyDark],
        ),
      ),
      child: Stack(
        fit: StackFit.expand,
        children: [
          CustomPaint(painter: _RaysPainter()),
          Padding(
            padding: const EdgeInsets.all(48),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                const Spacer(),
                const AdminLogo(size: 110),
                const SizedBox(height: 28),
                const Text(
                  'URDANETA CITY UNIVERSITY',
                  style: TextStyle(fontSize: 13, fontWeight: FontWeight.w800, letterSpacing: 1.2, color: AppColors.gold),
                ),
                const SizedBox(height: 6),
                const Text(
                  'ParkPermit',
                  style: TextStyle(fontSize: 46, fontWeight: FontWeight.w900, color: Colors.white),
                ),
                const Text(
                  'Security Office Portal',
                  style: TextStyle(fontSize: 20, fontWeight: FontWeight.w600, color: AppColors.blueSoft),
                ),
                const SizedBox(height: 28),
                for (final t in const [
                  'Review vehicle permit applications',
                  'Release and track parking stickers',
                  'See every sticker check at the gate',
                ])
                  Padding(
                    padding: const EdgeInsets.only(bottom: 12),
                    child: Row(
                      children: [
                        const Icon(Icons.check_circle, size: 20, color: AppColors.gold),
                        const SizedBox(width: 12),
                        Text(t, style: const TextStyle(fontSize: 15, color: Colors.white)),
                      ],
                    ),
                  ),
                const Spacer(),
                Container(
                  width: 120,
                  height: 4,
                  decoration: BoxDecoration(
                    borderRadius: BorderRadius.circular(2),
                    gradient: const LinearGradient(colors: [AppColors.ucuGreen, AppColors.gold, Colors.white]),
                  ),
                ),
                const SizedBox(height: 12),
                const Text(
                  'Bright future starts here.',
                  style: TextStyle(fontSize: 16, fontStyle: FontStyle.italic, fontWeight: FontWeight.w600, color: AppColors.gold),
                ),
                const SizedBox(height: 4),
                const Text(
                  'Owned and operated by the City Government of Urdaneta',
                  style: TextStyle(fontSize: 12.5, color: AppColors.blueSoft),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

/// On phones: a navy header with the seal, like the desktop panel.
  Widget _mobileHeader() {
    return Container(
      width: double.infinity,
      clipBehavior: Clip.antiAlias,
      decoration: const BoxDecoration(
        gradient: LinearGradient(
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
          colors: [AppColors.navy, AppColors.navyDark],
        ),
        borderRadius: BorderRadius.vertical(bottom: Radius.circular(28)),
      ),
      child: Stack(
        children: [
          Positioned.fill(child: CustomPaint(painter: _RaysPainter())),
          Padding(
            padding: const EdgeInsets.fromLTRB(24, 28, 24, 28),
            child: Row(
              children: [
                Container(
                  width: 66,
                  height: 66,
                  padding: const EdgeInsets.all(7),
                  decoration: const BoxDecoration(color: Colors.white, shape: BoxShape.circle),
                  child: const AdminLogo(size: 52),
                ),
                const SizedBox(width: 14),
                const Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        'URDANETA CITY UNIVERSITY',
                        style: TextStyle(fontSize: 10.5, fontWeight: FontWeight.w800, letterSpacing: 1, color: AppColors.gold),
                      ),
                      SizedBox(height: 2),
                      Text(
                        'ParkPermit',
                        style: TextStyle(fontSize: 28, fontWeight: FontWeight.w900, color: Colors.white),
                      ),
                      Text(
                        'Security Office Portal',
                        style: TextStyle(fontSize: 14, fontWeight: FontWeight.w600, color: AppColors.blueSoft),
                      ),
                    ],
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _form(bool showLogo) {
    return Align(
      alignment: MediaQuery.sizeOf(context).width >= 900 ? Alignment.center : Alignment.topCenter,
      child: SingleChildScrollView(
        padding: const EdgeInsets.all(28),
        child: ConstrainedBox(
          constraints: const BoxConstraints(maxWidth: 400),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              if (showLogo) ...[
                const Center(child: AdminLogo(size: 84)),
                const SizedBox(height: 16),
              ],
              const Text(
                'Welcome back',
                textAlign: TextAlign.center,
                style: TextStyle(fontSize: 28, fontWeight: FontWeight.w800, color: AppColors.navy),
              ),
              const SizedBox(height: 6),
              const Text(
                'Log in with your Security Office account.',
                textAlign: TextAlign.center,
                style: TextStyle(fontSize: 14, color: AppColors.textMuted),
              ),
              const SizedBox(height: 26),
              const Text('Email', style: TextStyle(fontWeight: FontWeight.w700, color: AppColors.textDark)),
              const SizedBox(height: 6),
              TextField(
                controller: _email,
                keyboardType: TextInputType.emailAddress,
                decoration: const InputDecoration(
                  hintText: 'Email',
                  prefixIcon: Padding(
                    padding: EdgeInsets.only(left: 14, right: 10),
                    child: Icon(Icons.mail_outline),
                  ),
                ),
              ),
              const SizedBox(height: 16),
              const Text('Password', style: TextStyle(fontWeight: FontWeight.w700, color: AppColors.textDark)),
              const SizedBox(height: 6),
              TextField(
                controller: _password,
                obscureText: _hide,
                onSubmitted: (_) => _login(),
                decoration: InputDecoration(
                  hintText: 'Password',
                  prefixIcon: const Padding(
                    padding: EdgeInsets.only(left: 14, right: 10),
                    child: Icon(Icons.lock_outline),
                  ),
                  suffixIcon: IconButton(
                    icon: Icon(_hide ? Icons.visibility_outlined : Icons.visibility_off_outlined),
                    onPressed: () => setState(() => _hide = !_hide),
                  ),
                ),
              ),
              if (_error != null) ...[
                const SizedBox(height: 14),
                Container(
                  padding: const EdgeInsets.all(12),
                  decoration: BoxDecoration(
                    color: AppColors.errorLight,
                    borderRadius: BorderRadius.circular(12),
                    border: Border.all(color: AppColors.error),
                  ),
                  child: Text(_error!, style: const TextStyle(color: AppColors.error, fontSize: 13)),
                ),
              ],
              const SizedBox(height: 22),
              SizedBox(
                height: 52,
                child: FilledButton(
                  onPressed: _loading ? null : _login,
                  child: _loading
                      ? const SizedBox(
                          width: 22,
                          height: 22,
                          child: CircularProgressIndicator(strokeWidth: 2.5, color: Colors.white),
                        )
                      : const Row(
                          mainAxisAlignment: MainAxisAlignment.center,
                          children: [
                            Text('Log In', style: TextStyle(fontSize: 16, fontWeight: FontWeight.w800)),
                            SizedBox(width: 8),
                            Icon(Icons.arrow_forward, size: 18),
                          ],
                        ),
                ),
              ),
              Center(
                child: TextButton(onPressed: _forgot, child: const Text('Forgot password?')),
              ),
              const SizedBox(height: 12),
              Container(
                padding: const EdgeInsets.all(12),
                decoration: BoxDecoration(
                  color: AppColors.ucuGreen.withValues(alpha: 0.06),
                  borderRadius: BorderRadius.circular(12),
                  border: Border.all(color: AppColors.ucuGreen.withValues(alpha: 0.35)),
                ),
                child: const Row(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Icon(Icons.privacy_tip_outlined, size: 18, color: AppColors.ucuGreen),
                    SizedBox(width: 10),
                    Expanded(
                      child: Text(
                        'For authorized Security Office staff only. Personal data is handled under the Data Privacy Act of 2012 (RA 10173).',
                        style: TextStyle(fontSize: 12, height: 1.4, color: AppColors.textMuted),
                      ),
                    ),
                  ],
                ),
              ),
              const SizedBox(height: 18),
              const Row(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  Icon(Icons.shield_outlined, size: 16, color: AppColors.navy),
                  SizedBox(width: 6),
                  Text(
                    'URDANETA CITY UNIVERSITY SECURITY OFFICE',
                    style: TextStyle(fontSize: 11, fontWeight: FontWeight.w800, letterSpacing: 0.6, color: AppColors.navy),
                  ),
                ],
              ),
            ],
          ),
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.white,
      body: Column(
        children: [
          Container(
            height: 4,
            decoration: const BoxDecoration(
              gradient: LinearGradient(colors: [AppColors.ucuGreen, AppColors.gold, AppColors.navy]),
            ),
          ),
          Expanded(
            child: LayoutBuilder(
              builder: (context, c) {
                if (c.maxWidth >= 900) {
                  return Row(
                    children: [
                      Expanded(child: _brandPanel()),
                      Expanded(child: _form(false)),
                    ],
                  );
                }
                return Column(
                  children: [
                    _mobileHeader(),
                    Expanded(child: _form(false)),
                  ],
                );
              },
            ),
          ),
        ],
      ),
    );
  }
}

/// Faint gold rays from the corner, like the sun in the UCU logo.
class _RaysPainter extends CustomPainter {
  @override
  void paint(Canvas canvas, Size size) {
    final center = Offset(size.width * 1.02, size.height * 1.02);
    final paint = Paint()..color = AppColors.gold.withValues(alpha: 0.07);
    final r = size.longestSide * 1.4;
    const slice = (math.pi / 2) / 18;
    for (var i = 0; i < 9; i++) {
      final a1 = math.pi + i * 2 * slice;
      final a2 = a1 + slice;
      final path = Path()
        ..moveTo(center.dx, center.dy)
        ..lineTo(center.dx + r * math.cos(a1), center.dy + r * math.sin(a1))
        ..lineTo(center.dx + r * math.cos(a2), center.dy + r * math.sin(a2))
        ..close();
      canvas.drawPath(path, paint);
    }
  }

  @override
  bool shouldRepaint(covariant CustomPainter oldDelegate) => false;
}

/// Forgot password: email, then the 6-digit code, then a new password.
class _ForgotDialog extends StatefulWidget {
  const _ForgotDialog({required this.email});

  final String email;

  @override
  State<_ForgotDialog> createState() => _ForgotDialogState();
}

class _ForgotDialogState extends State<_ForgotDialog> {
  late final TextEditingController _email = TextEditingController(text: widget.email);
  final _code = TextEditingController();
  final _pw = TextEditingController();
  final _pw2 = TextEditingController();
  int _step = 0; // 0 = email, 1 = code, 2 = new password
  bool _busy = false;
  bool _hide = true;
  String? _error;

  @override
  void dispose() {
    for (final c in [_email, _code, _pw, _pw2]) {
      c.dispose();
    }
    super.dispose();
  }

  Future<void> _send() async {
    final e = _email.text.trim();
    if (!e.contains('@')) return setState(() => _error = 'Enter your admin email.');
    setState(() {
      _busy = true;
      _error = null;
    });
    final err = await AdminService.sendResetCode(e);
    if (!mounted) return;
    setState(() {
      _busy = false;
      _error = err;
      if (err == null) {
        _step = 1;
        _code.clear();
      }
    });
  }

  Future<void> _verify() async {
    if (!RegExp(r'^\d{6}$').hasMatch(_code.text.trim())) {
      return setState(() => _error = 'Enter the 6-digit code.');
    }
    setState(() {
      _busy = true;
      _error = null;
    });
    final err = await AdminService.verifyResetCode(_email.text.trim(), _code.text.trim());
    if (!mounted) return;
    setState(() {
      _busy = false;
      _error = err;
      if (err == null) _step = 2;
    });
  }

  Future<void> _save() async {
    if (_pw.text.length < 8) return setState(() => _error = 'The new password needs at least 8 characters.');
    if (_pw.text != _pw2.text) return setState(() => _error = 'The new passwords do not match.');
    setState(() {
      _busy = true;
      _error = null;
    });
    final err = await AdminService.setNewPassword(_pw.text);
    if (!mounted) return;
    if (err == null) {
      Navigator.pop(context, true);
      return;
    }
    setState(() {
      _busy = false;
      _error = err;
    });
  }

  Future<void> _cancel() async {
    // After the code is verified the user is logged in, so log out again.
    if (_step == 2) await AdminService.signOut();
    if (mounted) Navigator.pop(context);
  }

  String get _title => switch (_step) {
        0 => 'Forgot password',
        1 => 'Enter the code',
        _ => 'Create a new password',
      };

  String get _text => switch (_step) {
        0 => 'Enter your admin email. We will send a 6-digit code to reset your password.',
        1 => 'We sent a 6-digit code to ${_email.text.trim()}. Check your inbox and spam folder.',
        _ => 'Your code is verified. Choose a new password for your admin account.',
      };

  @override
  Widget build(BuildContext context) {
    return AlertDialog(
      title: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            'STEP ${_step + 1} OF 3',
            style: const TextStyle(fontSize: 11, fontWeight: FontWeight.w800, letterSpacing: 0.8, color: AppColors.textHint),
          ),
          const SizedBox(height: 4),
          Text(_title),
        ],
      ),
      content: SizedBox(
        width: 420,
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            Text(_text, style: const TextStyle(color: AppColors.textMuted)),
            const SizedBox(height: 14),
            if (_step == 0)
              TextField(
                controller: _email,
                keyboardType: TextInputType.emailAddress,
                onSubmitted: (_) => _send(),
                decoration: const InputDecoration(labelText: 'Email', prefixIcon: Icon(Icons.mail_outline)),
              )
            else if (_step == 1)
              TextField(
                controller: _code,
                autofocus: true,
                keyboardType: TextInputType.number,
                maxLength: 6,
                onSubmitted: (_) => _verify(),
                textAlign: TextAlign.center,
                style: const TextStyle(fontSize: 24, fontWeight: FontWeight.w800, letterSpacing: 8),
                decoration: const InputDecoration(labelText: '6-digit code', counterText: ''),
              )
            else ...[
              TextField(
                controller: _pw,
                autofocus: true,
                obscureText: _hide,
                decoration: InputDecoration(
                  labelText: 'New password (at least 8 characters)',
                  prefixIcon: const Icon(Icons.lock_outline),
                  suffixIcon: IconButton(
                    icon: Icon(_hide ? Icons.visibility_outlined : Icons.visibility_off_outlined),
                    onPressed: () => setState(() => _hide = !_hide),
                  ),
                ),
              ),
              const SizedBox(height: 12),
              TextField(
                controller: _pw2,
                obscureText: _hide,
                onSubmitted: (_) => _save(),
                decoration: const InputDecoration(labelText: 'Confirm new password', prefixIcon: Icon(Icons.lock_outline)),
              ),
            ],
            if (_error != null) ...[
              const SizedBox(height: 12),
              Text(_error!, style: const TextStyle(color: AppColors.error)),
            ],
            if (_busy) ...[
              const SizedBox(height: 12),
              const LinearProgressIndicator(),
            ],
          ],
        ),
      ),
      actions: [
        TextButton(onPressed: _busy ? null : _cancel, child: const Text('Cancel')),
        if (_step == 1) TextButton(onPressed: _busy ? null : _send, child: const Text('Resend code')),
        FilledButton(
          onPressed: _busy ? null : switch (_step) { 0 => _send, 1 => _verify, _ => _save },
          child: Text(switch (_step) { 0 => 'Send Code', 1 => 'Verify Code', _ => 'Save New Password' }),
        ),
      ],
    );
  }
}