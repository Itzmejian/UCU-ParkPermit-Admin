import 'package:flutter/material.dart';
import '../admin_service.dart';
import '../ui.dart';
import 'application_detail_page.dart';
import 'common.dart';

/// True for a new application, or an appeal nobody has started yet.
bool needsStartReview(Map<String, dynamic> a) {
  final status = str(a['status']);
  if (status == 'pending') return true;
  if (status == 'appeal_review') {
    final ap = asOne(a['appeals']);
    return ap.isNotEmpty && str(ap['status']) == 'submitted';
  }
  return false;
}

bool _opening = false;

/// Opens one application from anywhere in the website.
///
/// A new application (or a new appeal) first shows "Start the review?" on the
/// screen the admin is on, before any details are shown:
/// - Start review: the status changes, then the details open.
/// - Not now: nothing opens and the admin stays where they were.
///
/// Returns true when the details were opened. With [replace] the current
/// screen is replaced (used for "next application").
Future<bool> openApplication(BuildContext context, String id, {bool replace = false}) async {
  if (_opening) return false;
  _opening = true;
  try {
    final nav = Navigator.of(context);
    // Small loading box while the application is fetched.
    showDialog<void>(
      context: context,
      barrierDismissible: false,
      builder: (_) => const PopScope(
        canPop: false,
        child: Center(
          child: Card(
            child: Padding(
              padding: EdgeInsets.all(22),
              child: Row(
                mainAxisSize: MainAxisSize.min,
                children: [
                  SizedBox(width: 22, height: 22, child: CircularProgressIndicator(strokeWidth: 2.6)),
                  SizedBox(width: 14),
                  Text('Opening application...', style: TextStyle(fontWeight: FontWeight.w600)),
                ],
              ),
            ),
          ),
        ),
      ),
    );
    Map<String, dynamic>? app;
    String? error;
    try {
      app = await AdminService.application(id);
    } catch (e) {
      error = AdminService.friendly(e);
    }
    nav.pop(); // close the loading box
    if (!context.mounted) return false;
    if (app == null) {
      showSnack(context, error ?? 'Could not open the application.');
      return false;
    }

    if (needsStartReview(app)) {
      final start = await showDialog<bool>(
        context: context,
        barrierDismissible: false,
        builder: (_) => StartReviewDialog(app: app!),
      );
      if (start != true || !context.mounted) return false;
      final err = await AdminService.startReview(id);
      if (!context.mounted) return false;
      if (err != null) {
        showSnack(context, err);
        return false;
      }
      final appeal = str(app['status']) == 'appeal_review';
      showSnack(
        context,
        appeal
            ? 'Appeal review started. The applicant now sees "Appeal under review" in the app.'
            : 'Review started. The applicant now sees "Under review" in the app.',
      );
    }

    final route = MaterialPageRoute<bool>(builder: (_) => ApplicationDetailPage(id: id));
    if (replace) {
      nav.pushReplacement(route);
    } else {
      _opening = false;
      await nav.push(route);
    }
    return true;
  } finally {
    _opening = false;
  }
}

/// Asked before a new application or appeal is opened: start the review now?
class StartReviewDialog extends StatelessWidget {
  const StartReviewDialog({super.key, required this.app});

  final Map<String, dynamic> app;

  @override
  Widget build(BuildContext context) {
    final p = asOne(app['applicant']);
    final v = asOne(app['vehicle']);
    final appeal = str(app['status']) == 'appeal_review';
    final ticket = str(asOne(app['appeals'])['ticket_no']);
    return Dialog(
      clipBehavior: Clip.antiAlias,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(18)),
      child: ConstrainedBox(
        constraints: const BoxConstraints(maxWidth: 440),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            Container(
              color: AppColors.navy,
              padding: const EdgeInsets.fromLTRB(22, 22, 22, 18),
              child: Row(
                children: [
                  CircleAvatar(
                    radius: 22,
                    backgroundColor: AppColors.gold,
                    child: Icon(appeal ? Icons.gavel_outlined : Icons.manage_search, color: AppColors.navy),
                  ),
                  const SizedBox(width: 14),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(appeal ? 'Start the appeal review?' : 'Start the review?',
                            style: const TextStyle(color: Colors.white, fontSize: 19, fontWeight: FontWeight.w800)),
                        const SizedBox(height: 2),
                        Text(appeal ? 'The applicant sent corrected documents' : 'New application waiting for review',
                            style: const TextStyle(color: AppColors.blueSoft, fontSize: 13)),
                      ],
                    ),
                  ),
                ],
              ),
            ),
            Container(height: 4, color: AppColors.gold),
            Padding(
              padding: const EdgeInsets.fromLTRB(22, 18, 22, 8),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(str(app['reference_no']),
                      style: const TextStyle(
                          fontFamily: 'monospace', fontWeight: FontWeight.w800, color: AppColors.navy, fontSize: 16)),
                  const SizedBox(height: 4),
                  Text('${str(p['full_name'])}  |  ${str(v['plate_number'])}'
                      '${appeal && ticket.isNotEmpty ? '  |  Appeal $ticket' : ''}',
                      style: const TextStyle(color: AppColors.textMuted)),
                  const SizedBox(height: 14),
                  Text(
                    appeal
                        ? 'The appeal will change to "Under review" and the applicant will see it in the app right away.'
                        : 'The status will change to "Under review" and the applicant will see it in the app right away.',
                  ),
                ],
              ),
            ),
            Padding(
              padding: const EdgeInsets.fromLTRB(16, 8, 16, 16),
              child: Row(
                mainAxisAlignment: MainAxisAlignment.end,
                children: [
                  TextButton(onPressed: () => Navigator.pop(context, false), child: const Text('Not now')),
                  const SizedBox(width: 8),
                  FilledButton.icon(
                    style: FilledButton.styleFrom(backgroundColor: AppColors.navy),
                    onPressed: () => Navigator.pop(context, true),
                    icon: const Icon(Icons.play_arrow_rounded),
                    label: Text(appeal ? 'Start appeal review' : 'Start review'),
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

