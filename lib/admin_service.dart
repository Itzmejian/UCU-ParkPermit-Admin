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

  static Future<String?> _run(Future<void> Function() action) async {
    try {
      await action();
      return null;
    } catch (e) {
      return friendly(e);
    }
  }

  static Future<String> documentUrl(String path) {
    return _c.storage.from('documents').createSignedUrl(path, 600);
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

  // ---------- permits and stickers ----------

  static Future<List<Map<String, dynamic>>> permits() async {
    final rows = await _c
        .from('permits')
        .select(
          '*, vehicle:vehicles(plate_number, make_model, vehicle_type), '
          'owner:profiles!permits_owner_id_fkey(full_name, role, id_number), '
          'zone:parking_zones(code, name)',
        )
        .order('created_at', ascending: false)
        .limit(1000);
    return List<Map<String, dynamic>>.from(rows);
  }

  static Future<String?> setSticker(String permitId, String state) => _run(() async {
        await _c.rpc('admin_set_sticker', params: {
          'p_permit_id': permitId,
          'p_state': state,
        });
      });

  // ---------- plate changes ----------

  static Future<List<Map<String, dynamic>>> plateChanges() async {
    final rows = await _c
        .from('vehicles')
        .select('*, owner:profiles!vehicles_owner_id_fkey(full_name, role, id_number, email)')
        .eq('pending_verification', true)
        .eq('active', true)
        .order('updated_at', ascending: false);
    return List<Map<String, dynamic>>.from(rows);
  }

  /// The newest OR/CR uploaded for this vehicle, or null.
  static Future<String?> latestOrcrPath(String vehicleId) async {
    final apps = await _c.from('applications').select('id').eq('vehicle_id', vehicleId);
    final ids = [for (final a in List<Map<String, dynamic>>.from(apps)) a['id']];
    if (ids.isEmpty) return null;
    final docs = await _c
        .from('documents')
        .select('file_path')
        .inFilter('application_id', ids)
        .eq('kind', 'orcr')
        .order('created_at', ascending: false)
        .limit(1);
    final list = List<Map<String, dynamic>>.from(docs);
    return list.isEmpty ? null : list.first['file_path']?.toString();
  }

  static Future<String?> verifyVehicle(String vehicleId) => _run(() async {
        await _c.rpc('admin_verify_vehicle', params: {'p_vehicle_id': vehicleId});
      });

  // ---------- sticker replacements ----------

  static Future<List<Map<String, dynamic>>> replacements() async {
    final rows = await _c
        .from('sticker_replacements')
        .select(
          '*, permit:permits(permit_no, sticker_status, vehicle:vehicles(plate_number, make_model)), '
          'owner:profiles!sticker_replacements_owner_id_fkey(full_name, role, id_number)',
        )
        .order('created_at', ascending: false)
        .limit(500);
    return List<Map<String, dynamic>>.from(rows);
  }

  static Future<String?> replacementDecision(String id, bool approve) => _run(() async {
        await _c.rpc('admin_replacement_decision', params: {
          'p_id': id,
          'p_approve': approve,
        });
      });

  // ---------- support tickets ----------

  static Future<List<Map<String, dynamic>>> tickets() async {
    final rows = await _c
        .from('support_tickets')
        .select('*, user:profiles!support_tickets_user_id_fkey(full_name, email, role)')
        .order('created_at', ascending: false)
        .limit(500);
    return List<Map<String, dynamic>>.from(rows);
  }

  static Future<String?> replyTicket(String id, String reply) => _run(() async {
        await _c.rpc('admin_reply_ticket', params: {'p_id': id, 'p_reply': reply});
      });

static String _sqlDate(DateTime d) =>
      '${d.year.toString().padLeft(4, '0')}-${d.month.toString().padLeft(2, '0')}-${d.day.toString().padLeft(2, '0')}';

  static Future<String?> setValidity(String permitId, DateTime until, String reason) => _run(() async {
        await _c.rpc('admin_set_validity', params: {
          'p_permit_id': permitId,
          'p_until': _sqlDate(until),
          'p_reason': reason,
        });
      });

  /// Changes made to a permit's validity, newest first.
  static Future<List<Map<String, dynamic>>> permitChanges(String permitId) async {
    final rows = await _c
        .from('permit_changes')
        .select('*, admin:profiles!permit_changes_changed_by_fkey(full_name, email)')
        .eq('permit_id', permitId)
        .order('created_at', ascending: false);
    return List<Map<String, dynamic>>.from(rows);
  }

  static Future<String?> closeTicket(String id) => _run(() async {
        await _c.rpc('admin_close_ticket', params: {'p_id': id});
      });
}