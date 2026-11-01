import 'package:flutter/material.dart';
import '../admin_service.dart';
import '../ui.dart';
import 'common.dart';
import 'user_detail_page.dart';

class UsersPage extends StatefulWidget {
  const UsersPage({super.key});

  @override
  State<UsersPage> createState() => _UsersPageState();
}

class _UsersPageState extends State<UsersPage> {
  String _filter = 'all';
  List<Map<String, dynamic>> _rows = [];
  bool _loading = true;
  String? _error;
  String _query = '';

  static const Map<String, String> _filters = {
    'all': 'All',
    'student': 'Students',
    'employee': 'Employees',
    'scheduled': 'Removal scheduled',
    'inactive': 'Inactive',
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
      final rows = await AdminService.users();
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
        'student' => r['role'] != 'employee',
        'employee' => r['role'] == 'employee',
        'scheduled' => r['account_status'] == 'scheduled',
        'inactive' => r['account_status'] == 'inactive',
        _ => true,
      };
      if (!ok) return false;
      if (q.isEmpty) return true;
      return '${r['full_name']} ${r['email']} ${r['id_number']}'.toLowerCase().contains(q);
    }).toList();
  }

  Future<void> _open(String id) async {
    await Navigator.push(context, MaterialPageRoute(builder: (_) => UserDetailPage(id: id)));
    _load();
  }

  Widget _row(Map<String, dynamic> r) {
    final vehicles = asMany(r['vehicles']).where((v) => v['active'] != false).length;
    final unit = r['role'] == 'employee' ? str(r['department']) : str(r['program']);
    return Material(
      color: Colors.white,
      borderRadius: BorderRadius.circular(14),
      child: InkWell(
        borderRadius: BorderRadius.circular(14),
        onTap: () => _open(str(r['id'])),
        child: Container(
          padding: const EdgeInsets.all(16),
          decoration: BoxDecoration(
            borderRadius: BorderRadius.circular(14),
            border: Border.all(color: AppColors.border),
          ),
          child: Wrap(
            spacing: 24,
            runSpacing: 12,
            crossAxisAlignment: WrapCrossAlignment.center,
            children: [
              infoCol(str(r['full_name']).isEmpty ? '(no name yet)' : str(r['full_name']), str(r['email']), width: 260),
              infoCol('${roleLabel(r['role'])}  |  ${str(r['id_number'])}', unit),
              infoCol('$vehicles vehicle${vehicles == 1 ? '' : 's'}', permitSummary(r['permits']), width: 180),
              accountPill(r),
            ],
          ),
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return ListPageFrame(
      title: 'Users',
      filters: _filters,
      selected: _filter,
      onFilter: (f) => setState(() => _filter = f),
      onRefresh: _load,
      loading: _loading,
      error: _error,
      emptyText: 'No users found.',
      onSearch: (v) => setState(() => _query = v),
      searchHint: 'Search name, email or ID',
      children: [for (final r in _visible) _row(r)],
    );
  }
}

/// "Active permit", "Expired permit" or "No permit".
String permitSummary(dynamic permits) {
  final list = asMany(permits);
  if (list.isEmpty) return 'No permit';
  final now = DateTime.now();
  final today = DateTime(now.year, now.month, now.day);
  final active = list.any((p) {
    final d = DateTime.tryParse(str(p['valid_until']));
    return d != null && !d.isBefore(today);
  });
  return active ? 'Active permit' : 'Expired permit';
}

Widget accountPill(Map<String, dynamic> r) {
  switch (str(r['account_status'])) {
    case 'scheduled':
      return Pill(
        'Removal on ${fmtDate(r['removal_date'], time: false)}',
        bg: AppColors.goldLight,
        fg: AppColors.goldDark,
        border: AppColors.gold,
      );
    case 'inactive':
      return const Pill('Inactive', bg: AppColors.errorLight, fg: AppColors.error, border: AppColors.error);
    default:
      return const Pill('Active', bg: AppColors.successLight, fg: AppColors.success, border: AppColors.success);
  }
}