import 'package:flutter/material.dart';
import '../admin_service.dart';
import '../ui.dart';
import 'common.dart';
import 'review_widgets.dart';

/// Check one new plate number against the newest OR/CR, then verify it.
/// After a decision the next vehicle in the queue opens.
class PlateChangeReviewPage extends StatefulWidget {
  const PlateChangeReviewPage({super.key, required this.queue, required this.index});

  final List<Map<String, dynamic>> queue;
  final int index;

  @override
  State<PlateChangeReviewPage> createState() => _PlateChangeReviewPageState();
}

class _PlateChangeReviewPageState extends State<PlateChangeReviewPage> {
  Map<String, dynamic> get _v => widget.queue[widget.index];
  late final Future<Map<String, dynamic>?> _orcr = AdminService.latestOrcr(str(_v['id']));
  bool _busy = false;

  void _next(String message) {
    final i = widget.index + 1;
    if (i >= widget.queue.length) {
      showSnack(context, '$message No more plate changes are waiting.');
      Navigator.pop(context, true);
      return;
    }
    showSnack(context, '$message Opening the next one.');
    Navigator.pushReplacement(
      context,
      MaterialPageRoute(builder: (_) => PlateChangeReviewPage(queue: widget.queue, index: i)),
    );
  }

  Future<void> _verify() async {
    final ok = await confirmDialog(
      context,
      title: 'Verify ${str(_v['plate_number'])}?',
      message: 'Only verify when the OR/CR on the right clearly shows this plate number. '
          'The applicant will be notified and the vehicle can use its permit again.',
      action: 'Yes, verify',
      color: AppColors.success,
    );
    if (!ok || !mounted) return;
    setState(() => _busy = true);
    final err = await AdminService.verifyVehicle(str(_v['id']));
    if (!mounted) return;
    setState(() => _busy = false);
    if (err != null) {
      showSnack(context, err);
      return;
    }
    _next('Plate ${str(_v['plate_number'])} verified.');
  }

  void _skip() => _next('Skipped for now.');

  @override
  Widget build(BuildContext context) {
    final v = _v;
    final o = asOne(v['owner']);
    final left = <Widget>[
      ReviewTitle(
        code: str(v['plate_number']),
        subtitle: 'New plate number  |  changed ${fmtDate(v['updated_at'])}',
        pills: [statePill('Waiting for verification', 'warning')],
      ),
      QueueStrip(index: widget.index, total: widget.queue.length, noun: 'Plate change'),
      SectionCard(
        title: 'Vehicle',
        children: [
          InfoRow('New plate number', str(v['plate_number']), mono: true),
          InfoRow('Type', vehicleLabel(v['vehicle_type'])),
          InfoRow('Make / Model', str(v['make_model'])),
          InfoRow('Color', str(v['color'])),
          InfoRow('Model year', str(v['model_year'])),
        ],
      ),
      const SizedBox(height: 16),
      SectionCard(
        title: 'Applicant',
        children: [
          InfoRow('Name', str(o['full_name'])),
          InfoRow('Email', str(o['email'])),
          InfoRow('User type', roleLabel(o['role'])),
          InfoRow('ID number', str(o['id_number']), mono: true),
        ],
      ),
    ];
    final right = <Widget>[
      SectionCard(
        title: 'Your decision',
        children: [
          const NoticeBox(
            'Compare the plate number on the OR/CR with the new plate number. '
            'If they do not match, skip it and contact the applicant.',
          ),
          const SizedBox(height: 14),
          DecisionButtons(
            primaryLabel: 'Verify plate',
            primaryIcon: Icons.verified_outlined,
            onPrimary: _verify,
            secondaryLabel: widget.index + 1 < widget.queue.length ? 'Skip for now' : 'Back to list',
            secondaryIcon: Icons.skip_next_outlined,
            secondaryColor: AppColors.navy,
            onSecondary: widget.index + 1 < widget.queue.length ? _skip : () => Navigator.pop(context),
            busy: _busy,
          ),
        ],
      ),
      const SizedBox(height: 16),
      SectionCard(
        title: 'Documents',
        children: [
          FutureBuilder<Map<String, dynamic>?>(
            future: _orcr,
            builder: (context, snap) {
              if (snap.connectionState != ConnectionState.done) {
                return const Padding(
                  padding: EdgeInsets.all(24),
                  child: Center(child: CircularProgressIndicator()),
                );
              }
              final d = snap.data;
              if (snap.hasError || d == null) {
                return const NoticeBox('No OR/CR was found for this vehicle.', tone: 'error', icon: Icons.error_outline);
              }
              return DocPreview(
                path: str(d['file_path']),
                fileName: str(d['file_name']),
                label: 'Newest OR/CR',
                subtitle: '${str(d['file_name'])}  |  ${fmtSize(d['size_bytes'])}  |  ${fmtDate(d['created_at'])}',
                height: 460,
              );
            },
          ),
        ],
      ),
    ];
    return Scaffold(
      appBar: AppBar(title: const Text('Verify plate change', style: TextStyle(fontWeight: FontWeight.w800))),
      body: ReviewLayout(left: left, right: right),
    );
  }
}
