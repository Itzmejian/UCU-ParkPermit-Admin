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
    if (m.contains('PROTECTED_ACCOUNT')) return 'Admin and guard accounts cannot be removed here.';
    if (m.contains('HAS_STUDENT_DATA')) return 'This email belongs to a student or employee with vehicles. Use a different email.';
    if (m.contains('BAD_EMAIL')) return 'Enter a valid email address.';
    if (m.contains('BAD_NAME')) return "Enter the guard's full name.";
    if (m.contains('NOT_A_GUARD')) return 'This email is not a guard account.';
    if (m.contains('CONFIRM_MISMATCH')) return 'The ID number you typed does not match.';
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

/// Every sticker check made by a guard, newest first.
  static Future<List<Map<String, dynamic>>> gateScans() async {
    final rows = await _c
        .from('gate_scans')
        .select('*, permit:permits(permit_no, vehicle:vehicles(plate_number, make_model))')
        .order('created_at', ascending: false)
        .limit(500);
    return List<Map<String, dynamic>>.from(rows);
  }

// ---------- users ----------

  /// Students and employees (not guards, not this admin).
  static Future<List<Map<String, dynamic>>> users() async {
    final rows = await _c
        .from('profiles')
        .select('*, vehicles(id, plate_number, active), permits(id, valid_until, sticker_status)')
        .order('full_name')
        .limit(3000);
    final guards = await _c.from('guards').select('user_id');
    final skip = <dynamic>{
      for (final g in List<Map<String, dynamic>>.from(guards)) g['user_id'],
      _c.auth.currentUser?.id,
    };
    return [
      for (final r in List<Map<String, dynamic>>.from(rows))
        if (!skip.contains(r['id'])) r,
    ];
  }

  static Future<Map<String, dynamic>> user(String id) async {
    final row = await _c
        .from('profiles')
        .select(
          '*, vehicles(*), permits(*), '
          'applications!applications_applicant_id_fkey(id, reference_no, kind, status, submitted_at, vehicle:vehicles(plate_number))',
        )
        .eq('id', id)
        .single();
    return Map<String, dynamic>.from(row);
  }

  static Future<({String? date, String? error})> scheduleRemoval(String id, int days, String reason) async {
    try {
      final r = await _c.rpc('admin_schedule_removal', params: {
        'p_user': id,
        'p_days': days,
        'p_reason': reason,
      });
      return (date: r?.toString(), error: null);
    } catch (e) {
      return (date: null, error: friendly(e));
    }
  }

  static Future<String?> cancelRemoval(String id) => _run(() async {
        await _c.rpc('admin_cancel_removal', params: {'p_user': id});
      });

  /// Deletes the account and everything in it, then the uploaded files.
  static Future<String?> deleteUser(String id, String confirm) async {
    try {
      await _c.rpc('admin_delete_user', params: {'p_user': id, 'p_confirm': confirm});
    } catch (e) {
      return friendly(e);
    }
    try {
      final files = await _c.storage.from('documents').list(path: id);
      final paths = [for (final f in files) '$id/${f.name}'];
      if (paths.isNotEmpty) await _c.storage.from('documents').remove(paths);
    } catch (_) {
      // The account is already deleted; leftover files can be removed in Supabase Storage.
    }
    return null;
  }

// ---------- my account ----------

  static User? get currentUser => _c.auth.currentUser;

  static String get displayName {
    final n = _c.auth.currentUser?.userMetadata?['full_name'];
    return (n is String && n.trim().isNotEmpty) ? n.trim() : 'Admin';
  }

  static String _authMsg(AuthException e) {
    final m = e.message.toLowerCase();
    if (m.contains('same')) return 'Use a password different from your old one.';
    if (m.contains('weak') || m.contains('at least')) return 'Use at least 8 characters.';
    if (m.contains('rate') || m.contains('seconds') || m.contains('security purposes')) {
      return 'Please wait a minute before trying again.';
    }
    if (m.contains('already') || m.contains('registered')) return 'That email is already used by another account.';
    if (m.contains('expired') || m.contains('invalid') || m.contains('token')) return 'The code is wrong or expired.';
    return e.message;
  }

  /// Checks the current password by logging in again with it.
  static Future<String?> _checkPassword(String current) async {
    final e = email;
    if (e == null) return 'Please log in again.';
    try {
      await _c.auth.signInWithPassword(email: e, password: current);
      return null;
    } on AuthException {
      return 'Your current password is wrong.';
    } catch (_) {
      return 'No internet connection. Please try again.';
    }
  }

  static Future<String?> changePassword(String current, String next) async {
    final bad = await _checkPassword(current);
    if (bad != null) return bad;
    try {
      await _c.auth.updateUser(UserAttributes(password: next));
      return null;
    } on AuthException catch (e) {
      return _authMsg(e);
    } catch (_) {
      return 'No internet connection. Please try again.';
    }
  }

  static Future<String?> changeEmail(String current, String newEmail) async {
    final bad = await _checkPassword(current);
    if (bad != null) return bad;
    try {
      await _c.auth.updateUser(UserAttributes(email: newEmail));
      return null;
    } on AuthException catch (e) {
      return _authMsg(e);
    } catch (_) {
      return 'No internet connection. Please try again.';
    }
  }

  static Future<String?> updateName(String name) async {
    try {
      await _c.auth.updateUser(UserAttributes(data: {'full_name': name}));
      return null;
    } on AuthException catch (e) {
      return _authMsg(e);
    } catch (_) {
      return 'No internet connection. Please try again.';
    }
  }

  // ---------- forgot password (6-digit code by email) ----------

  static Future<String?> sendResetCode(String address) async {
    try {
      await _c.auth.resetPasswordForEmail(address);
      return null;
    } on AuthException catch (e) {
      return _authMsg(e);
    } catch (_) {
      return 'No internet connection. Please try again.';
    }
  }

  static Future<String?> verifyResetCode(String address, String code) async {
    try {
      await _c.auth.verifyOTP(type: OtpType.recovery, email: address, token: code);
      return null;
    } on AuthException catch (e) {
      return _authMsg(e);
    } catch (_) {
      return 'No internet connection. Please try again.';
    }
  }

  static Future<String?> setNewPassword(String next) async {
    try {
      await _c.auth.updateUser(UserAttributes(password: next));
      await signOut();
      return null;
    } on AuthException catch (e) {
      return _authMsg(e);
    } catch (_) {
      return 'No internet connection. Please try again.';
    }
  }

  static Future<String?> resetWithCode(String address, String code, String next) async {
    try {
      await _c.auth.verifyOTP(type: OtpType.recovery, email: address, token: code);
      await _c.auth.updateUser(UserAttributes(password: next));
      await signOut();
      return null;
    } on AuthException catch (e) {
      return _authMsg(e);
    } catch (_) {
      return 'No internet connection. Please try again.';
    }
  }

  static Future<String?> closeTicket(String id) => _run(() async {
        await _c.rpc('admin_close_ticket', params: {'p_id': id});
      });

// ---------- guards ----------

  /// Every guard with their email, status and number of gate scans.
  static Future<List<Map<String, dynamic>>> guards() async {
    final rows = await _c.rpc('admin_list_guards');
    return List<Map<String, dynamic>>.from(rows as List);
  }

  /// Creates the guard's login (if new) and emails them a 6-digit code.
  /// With [resend], only emails a new code. Returns an error message or null.
  static Future<String?> inviteGuard(String email, String name, {bool resend = false}) async {
    try {
      final res = await _c.functions.invoke(
        'invite-guard',
        body: {'email': email.trim(), 'name': name.trim(), 'resend': resend},
      );
      final data = res.data;
      if (data is Map && data['error'] != null && data['ok'] != true) {
        return friendly(data['error'].toString());
      }
      if (data is Map && data['emailSent'] == false) {
        final why = data['error']?.toString().toLowerCase() ?? '';
        if (why.contains('second') || why.contains('rate') || why.contains('security')) {
          return 'Guard saved, but please wait a minute before sending another code.';
        }
        return 'Guard saved, but the email could not be sent. Try "Resend code" later.';
      }
      return null;
    } on FunctionException catch (e) {
      final d = e.details;
      final msg = d is Map && d['error'] != null ? d['error'].toString() : (e.reasonPhrase ?? 'Error ${e.status}');
      if (msg.contains('PROTECTED_ACCOUNT')) return 'This email is an admin account. Use a different email.';
      return friendly(msg);
    } catch (e) {
      return friendly(e);
    }
  }

  static Future<String?> setGuard(String userId, String name, bool active) => _run(() async {
        await _c.rpc('admin_set_guard', params: {'p_user': userId, 'p_name': name, 'p_active': active});
      });
}
