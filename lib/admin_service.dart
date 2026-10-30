import 'package:supabase_flutter/supabase_flutter.dart';

/// Everything the admin website reads and does. Every action is a database
/// function that checks that the logged-in user is an admin.
class AdminService {
  AdminService._();

  static SupabaseClient get _c => Supabase.instance.client;

  static String? get email => _c.auth.currentUser?.email;

  static String friendly(Object e) {
    final m = e is PostgrestException ? e.message : e.toString();
    if (m.contains('NOT_ADMIN')) return 'Your account is not allowed to do this.';
    if (m.contains('WRONG_STATUS')) return 'This was already changed. Refresh the page.';
    if (m.contains('NOTHING_FLAGGED')) return 'Flag at least one document or write a note.';
    if (m.contains('NOT_FOUND')) return 'Record not found. Refresh the page.';
    if (m.contains('BAD_INPUT')) return 'Please check what you entered.';
    if (m.toLowerCase().contains('failed to fetch') ||
        m.toLowerCase().contains('socket')) {
      return 'No internet connection. Please try again.';
    }
    return m;
  }

  // ---------- login ----------

  static Future<bool> currentUserIsAdmin() async {
    if (_c.auth.currentUser == null) return false;
    try {
      final r = await _c.rpc('is_admin');
      return r == true;
    } catch (_) {
      return false;
    }
  }

  /// Returns an error message, or null when logged in as an admin.
  static Future<String?> signIn(String email, String password) async {
    try {
      await _c.auth.signInWithPassword(email: email, password: password);
    } on AuthException catch (e) {
      return e.message.toLowerCase().contains('invalid')
          ? 'Wrong email or password.'
          : e.message;
    } catch (_) {
      return 'Could not log in. Check your internet connection.';
    }
    if (!await currentUserIsAdmin()) {
      await signOut();
      return 'This account is not a Security Office admin.';
    }
    return null;
  }

  static Future<void> signOut() async {
    try {
      await _c.auth.signOut();
    } catch (_) {}
  }

  // ---------- applications ----------

  static const String _listCols =
      'id, reference_no, kind, status, submitted_at, '
      'vehicle:vehicles(plate_number, make_model, vehicle_type), '
      'applicant:profiles!applications_applicant_id_fkey(full_name, role, id_number)';

  static Future<List<Map<String, dynamic>>> applications({String? status}) async {
    var q = _c.from('applications').select(_listCols);
    if (status != null) q = q.eq('status', status);
    final rows = await q.order('submitted_at', ascending: false).limit(500);
    return List<Map<String, dynamic>>.from(rows);
  }

  static Future<Map<String, dynamic>> application(String id) async {
    final row = await _c
        .from('applications')
        .select(
          '*, vehicle:vehicles(*), '
          'applicant:profiles!applications_applicant_id_fkey(*), '
          'documents(*), appeals(*), permits(*)',
        )
        .eq('id', id)
        .single();
    return Map<String, dynamic>.from(row);
  }

  static Future<List<Map<String, dynamic>>> zones(String vehicleType) async {
    final rows = await _c
        .from('parking_zones')
        .select('code, name, vehicle_type')
        .eq('vehicle_type', vehicleType)
        .order('code');
    return List<Map<String, dynamic>>.from(rows);
  }

  static Future<String> documentUrl(String path) {
    return _c.storage.from('documents').createSignedUrl(path, 600);
  }

  // ---------- dashboard ----------

  static Future<int> _count(String table, String column, Object value) async {
    final rows = await _c.from(table).select('id').eq(column, value);
    return (rows as List).length;
  }

  static Future<Map<String, int>> dashboardCounts() async {
    final r = await Future.wait<int>([
      _count('applications', 'status', 'pending'),
      _count('applications', 'status', 'under_review'),
      _count('applications', 'status', 'appeal_review'),
      _count('permits', 'sticker_status', 'preparing'),
      _count('permits', 'sticker_status', 'ready'),
      _count('vehicles', 'pending_verification', true),
      _count('sticker_replacements', 'status', 'requested'),
      _count('support_tickets', 'status', 'open'),
    ]);
    return {
      'pending': r[0],
      'under_review': r[1],
      'appeal_review': r[2],
      'preparing': r[3],
      'ready': r[4],
      'plate_changes': r[5],
      'replacements': r[6],
      'tickets': r[7],
    };
  }

  // ---------- actions ----------

  static Future<String?> _run(Future<void> Function() action) async {
    try {
      await action();
      return null;
    } catch (e) {
      return friendly(e);
    }
  }

  static Future<String?> startReview(String appId) => _run(() async {
        await _c.rpc('admin_start_review', params: {'p_app_id': appId});
      });

  /// Returns the new permit number, or an error.
  static Future<({String? permitNo, String? error})> approve(
    String appId,
    String? zoneCode,
  ) async {
    try {
      final r = await _c.rpc('admin_approve', params: {
        'p_app_id': appId,
        'p_zone_code': zoneCode,
      });
      return (permitNo: r?.toString(), error: null);
    } catch (e) {
      return (permitNo: null, error: friendly(e));
    }
  }

  static Future<String?> decline(
    String appId,
    List<Map<String, String>> flags,
    String note,
  ) =>
      _run(() async {
        await _c.rpc('admin_decline', params: {
          'p_app_id': appId,
          'p_flags': flags,
          'p_note': note,
        });
      });
}