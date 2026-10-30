import 'package:flutter/material.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import 'admin_service.dart';
import 'pages/login_page.dart';
import 'pages/shell_page.dart';
import 'supabase_config.dart';
import 'ui.dart';

Future<void> main() async {
  WidgetsFlutterBinding.ensureInitialized();
  await Supabase.initialize(url: kSupabaseUrl, publishableKey: kSupabaseAnonKey);
  runApp(const AdminApp());
}

class AdminApp extends StatelessWidget {
  const AdminApp({super.key});

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      title: 'UCU ParkPermit Admin',
      debugShowCheckedModeBanner: false,
      theme: buildAdminTheme(),
      home: const _Gate(),
    );
  }
}

/// Shows the login page, or the admin pages when an admin is logged in.
class _Gate extends StatefulWidget {
  const _Gate();

  @override
  State<_Gate> createState() => _GateState();
}

class _GateState extends State<_Gate> {
  bool _checking = true;
  bool _isAdmin = false;

  @override
  void initState() {
    super.initState();
    _check();
  }

  Future<void> _check() async {
    final ok = await AdminService.currentUserIsAdmin();
    if (!mounted) return;
    setState(() {
      _isAdmin = ok;
      _checking = false;
    });
  }

  Future<void> _logout() async {
    await AdminService.signOut();
    if (!mounted) return;
    setState(() => _isAdmin = false);
  }

  @override
  Widget build(BuildContext context) {
    if (_checking) {
      return const Scaffold(body: Center(child: CircularProgressIndicator()));
    }
    return _isAdmin
        ? ShellPage(onLogout: _logout)
        : LoginPage(onLoggedIn: () => setState(() => _isAdmin = true));
  }
}