import 'package:flutter/material.dart';
import '../admin_service.dart';
import '../ui.dart';
import 'common.dart';
import 'review_widgets.dart';

/// One sticker replacement request. Details on the left, decision on the right.
class ReplacementReviewPage extends StatefulWidget {
  const ReplacementReviewPage({super.key, required this.queue, required this.index});

  final List<Map<String, dynamic>> queue;
  final int index;

  @override
  State<ReplacementReviewPage> createState() => _ReplacementReviewPageState();
}

class _ReplacementReviewPageState extends State<ReplacementReviewPage> {
  Map<String, dynamic> get _r => widget.queue[widget.index];
  bool _busy = false;

  bool get _waiting => _r['status'] == 'requested';

  void _next(String message) {
    final i = widget.index + 1;
    if (i >= widget.queue.length) {
      showSnack(context, '$message No more requests are waiting.');
      Navigator.pop(context, true);
      return;
    }
    showSnack(context, '$message Opening the next request.');
    Navigator.pushReplacement(
      context,
      MaterialPageRoute(builder: (_) => ReplacementReviewPage(queue: widget.queue, index: i)),
    );
  }

  Future<void> _decide(bool approve) async {
    final permit = asOne(_r['permit']);
    final ok = await confirmDialog(
      context,
      title: approve ? 'Approve this replacement?' : 'Reject this replacement?',
      message: approve
          ? 'A new sticker for ${str(permit['permit_no'])} will be prepared. The old sticker stops working, '
              'and the applicant will be told when the new one is ready.'
          : 'The applicant keeps the current sticker and will be asked to visit the Security Office for details.',
      action: approve ? 'Yes, approve' : 'Yes, reject',
      color: approve ? AppColors.success : AppColors.error,
    );
    if (!ok || !mounted) return;
    setState(() => _busy = true);
    final err = await AdminService.replacementDecision(str(_r['id']), approve);
    if (!mounted) return;
    setState(() => _busy = false);
    if (err != null) {
      showSnack(context, err);
      return;
    }
    _next(approve ? 'Replacement approved.' : 'Replacement rejected.');
  }

  Widget _statusPill() => switch (str(_r['status'])) {
        'approved' => statePill('Approved', 'success'),
        'rejected' => statePill('Rejected', 'error'),
        _ => statePill('Waiting', 'warning'),
      };

  @override
  Widget build(BuildContext context) {
    final r = _r;
    final permit = asOne(r['permit']);
    final v = asOne(permit['vehicle']);
    final o = asOne(r['owner']);
    final left = <Widget>[
      ReviewTitle(
        code: str(permit['permit_no']),
        subtitle: 'Requested ${fmtDate(r['created_at'])}',
        pills: [_statusPill()],
      ),
      if (_waiting) QueueStrip(index: widget.index, total: widget.queue.length, noun: 'Request'),
      SectionCard(
        title: 'Request',
        icon: Icons.sync_outlined,
        children: [
          InfoRow('Reason', str(r['reason'])),
          InfoRow('Details from the applicant', str(r['details'])),
          InfoRow('Current sticker', str(permit['sticker_status']).replaceAll('_', ' ')),
        ],
      ),
      const SizedBox(height: 16),
      SectionCard(
        title: 'Vehicle',
        children: [
          InfoRow('Plate number', str(v['plate_number']), mono: true),
          InfoRow('Make / Model', str(v['make_model'])),
        ],
      ),
      const SizedBox(height: 16),
      SectionCard(
        title: 'Applicant',
        children: [
          InfoRow('Name', str(o['full_name'])),
          InfoRow('User type', roleLabel(o['role'])),
          InfoRow('ID number', str(o['id_number']), mono: true),
        ],
      ),
    ];
    final right = <Widget>[
      SectionCard(
        title: _waiting ? 'Your decision' : 'Result',
        children: _waiting
            ? [
                const NoticeBox(
                  'Approve when the reason is valid (for example the sticker was lost, damaged or the windshield was changed). '
                  'Reject when the request is not needed.',
                ),
                const SizedBox(height: 14),
                DecisionButtons(
                  primaryLabel: 'Approve',
                  primaryIcon: Icons.check_circle_outline,
                  onPrimary: () => _decide(true),
                  secondaryLabel: 'Reject',
                  secondaryIcon: Icons.cancel_outlined,
                  onSecondary: () => _decide(false),
                  busy: _busy,
                ),
              ]
            : [
                NoticeBox(
                  r['status'] == 'approved'
                      ? 'This request was approved. Prepare the new sticker in Permits.'
                      : 'This request was rejected.',
                  tone: r['status'] == 'approved' ? 'success' : 'error',
                  icon: r['status'] == 'approved' ? Icons.verified_outlined : Icons.cancel_outlined,
                ),
              ],
      ),
      const SizedBox(height: 16),
      const SectionCard(
        title: 'What happens next',
        icon: Icons.route_outlined,
        children: [
          InfoRow('1. Approve', 'The old sticker stops working at the gate.'),
          InfoRow('2. Prepare', 'Print the new sticker from Permits, then mark it Ready for pickup.'),
          InfoRow('3. Claim', 'The applicant claims it at the Security Office.'),
        ],
      ),
    ];
    return Scaffold(
      appBar: AppBar(title: const Text('Sticker replacement', style: TextStyle(fontWeight: FontWeight.w800))),
      body: ReviewLayout(left: left, right: right),
    );
  }
}
