import 'package:flutter/material.dart';
import 'package:url_launcher/url_launcher.dart';
import '../admin_service.dart';
import '../ui.dart';

class ApplicationDetailPage extends StatefulWidget {
  const ApplicationDetailPage({super.key, required this.id});

  final String id;

  @override
  State<ApplicationDetailPage> createState() => _ApplicationDetailPageState();
}

class _ApplicationDetailPageState extends State<ApplicationDetailPage> {
  Map<String, dynamic>? _app;
  bool _loading = true;
  bool _busy = false;
  String? _error;

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
      final a = await AdminService.application(widget.id);
      if (!mounted) return;
      setState(() {
        _app = a;
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

  void _snack(String m) {
    ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(m)));
  }

  Future<void> _startReview() async {
    setState(() => _busy = true);
    final err = await AdminService.startReview(widget.id);
    if (!mounted) return;
    setState(() => _busy = false);
    _snack(err ?? 'Marked as under review. The applicant was notified.');
    _load();
  }

  Future<void> _approve() async {
    final vehicle = asOne(_app!['vehicle']);
    var zones = <Map<String, dynamic>>[];
    try {
      zones = await AdminService.zones(str(vehicle['vehicle_type']).isEmpty ? 'four_wheel' : str(vehicle['vehicle_type']));
    } catch (_) {}
    if (!mounted) return;
    final zone = await showDialog<String>(
      context: context,
      builder: (_) => _ApproveDialog(zones: zones),
    );
    if (zone == null) return;
    setState(() => _busy = true);
    final r = await AdminService.approve(widget.id, zone.isEmpty ? null : zone);
    if (!mounted) return;
    setState(() => _busy = false);
    _snack(r.error ?? 'Approved. Permit ${r.permitNo} was issued and the applicant was notified.');
    _load();
  }

  Future<void> _decline() async {
    final docs = asMany(_app!['documents'])
        .where((d) => d['review_status'] == 'uploaded')
        .toList();
    final result = await showDialog<_DeclineResult>(
      context: context,
      builder: (_) => _DeclineDialog(docs: docs),
    );
    if (result == null) return;
    setState(() => _busy = true);
    final err = await AdminService.decline(widget.id, result.flags, result.note);
    if (!mounted) return;
    setState(() => _busy = false);
    _snack(err ?? 'Declined. The applicant was notified and can file an appeal.');
    _load();
  }

  Future<void> _openDoc(Map<String, dynamic> d) async {
    try {
      final url = await AdminService.documentUrl(str(d['file_path']));
      await launchUrl(Uri.parse(url), webOnlyWindowName: '_blank');
    } catch (_) {
      _snack('Could not open the file.');
    }
  }

  Widget _actions(Map<String, dynamic> a) {
    final status = str(a['status']);
    if (!const ['pending', 'under_review', 'appeal_review'].contains(status)) {
      return const SizedBox.shrink();
    }
    final text = switch (status) {
      'pending' => 'New application. Start the review, or decide right away.',
      'appeal_review' => 'The applicant appealed and uploaded new files. Check them, then decide.',
      _ => 'Check the documents against the details, then approve or decline.',
    };
    return SectionCard(
      title: 'Your decision',
      children: [
        Text(text, style: const TextStyle(color: AppColors.textMuted)),
        const SizedBox(height: 14),
        Wrap(
          spacing: 10,
          runSpacing: 10,
          children: [
            if (status == 'pending')
              OutlinedButton.icon(
                onPressed: _busy ? null : _startReview,
                icon: const Icon(Icons.manage_search),
                label: const Text('Start Review'),
              ),
            FilledButton.icon(
              style: FilledButton.styleFrom(backgroundColor: AppColors.success),
              onPressed: _busy ? null : _approve,
              icon: const Icon(Icons.check_circle_outline),
              label: const Text('Approve'),
            ),
            OutlinedButton.icon(
              style: OutlinedButton.styleFrom(
                foregroundColor: AppColors.error,
                side: const BorderSide(color: AppColors.error),
              ),
              onPressed: _busy ? null : _decline,
              icon: const Icon(Icons.cancel_outlined),
              label: const Text('Decline'),
            ),
          ],
        ),
        if (_busy)
          const Padding(
            padding: EdgeInsets.only(top: 12),
            child: LinearProgressIndicator(),
          ),
      ],
    );
  }

  Widget _docRow(Map<String, dynamic> d) {
    final isPdf = str(d['file_name']).toLowerCase().endsWith('.pdf');
    return Container(
      margin: const EdgeInsets.only(bottom: 8),
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: AppColors.surface,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: AppColors.border),
      ),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Icon(isPdf ? Icons.picture_as_pdf_outlined : Icons.image_outlined, color: AppColors.navy),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Wrap(
                  spacing: 8,
                  runSpacing: 4,
                  crossAxisAlignment: WrapCrossAlignment.center,
                  children: [
                    Text(kDocLabels[str(d['kind'])] ?? str(d['kind']),
                        style: const TextStyle(fontWeight: FontWeight.w700)),
                    docStatusPill(d['review_status']),
                    if (d['appeal_id'] != null) const Pill('Sent with appeal'),
                  ],
                ),
                const SizedBox(height: 2),
                Text('${str(d['file_name'])}  |  ${fmtSize(d['size_bytes'])}  |  ${fmtDate(d['created_at'])}',
                    style: const TextStyle(fontSize: 12, color: AppColors.textHint)),
                if (str(d['reviewer_remark']).isNotEmpty)
                  Padding(
                    padding: const EdgeInsets.only(top: 4),
                    child: Text('Remark: ${str(d['reviewer_remark'])}',
                        style: const TextStyle(fontSize: 12.5, color: AppColors.error)),
                  ),
              ],
            ),
          ),
          TextButton.icon(
            onPressed: () => _openDoc(d),
            icon: const Icon(Icons.open_in_new, size: 18),
            label: const Text('Open'),
          ),
        ],
      ),
    );
  }

  Widget _content(Map<String, dynamic> a) {
    final p = asOne(a['applicant']);
    final v = asOne(a['vehicle']);
    final docs = asMany(a['documents'])
      ..sort((x, y) => str(x['created_at']).compareTo(str(y['created_at'])));
    final appeal = asOne(a['appeals']);
    final permit = asOne(a['permits']);
    final isStudent = p['role'] != 'employee';
    final address = [p['street'], p['barangay'], p['city'], p['province']]
        .map(str)
        .where((x) => x.trim().isNotEmpty)
        .join(', ');

    return ListView(
      padding: const EdgeInsets.all(24),
      children: [
        Center(
          child: ConstrainedBox(
            constraints: const BoxConstraints(maxWidth: 980),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                Wrap(
                  spacing: 10,
                  runSpacing: 8,
                  crossAxisAlignment: WrapCrossAlignment.center,
                  children: [
                    SelectableText(str(a['reference_no']),
                        style: const TextStyle(
                            fontFamily: 'monospace', fontSize: 24, fontWeight: FontWeight.w800, color: AppColors.navy)),
                    statusPill(a['status']),
                    Pill(a['kind'] == 'renewal' ? 'Renewal' : 'New application'),
                  ],
                ),
                const SizedBox(height: 4),
                Text('Submitted ${fmtDate(a['submitted_at'])}'
                    '${a['reviewed_at'] == null ? '' : '  |  Reviewed ${fmtDate(a['reviewed_at'])}'}',
                    style: const TextStyle(color: AppColors.textHint)),
                const SizedBox(height: 16),
                _actions(a),
                if (a['status'] == 'declined') ...[
                  SectionCard(
                    title: 'Declined',
                    children: [
                      InfoRow('Declined on', fmtDate(a['declined_at'])),
                      InfoRow('Note to applicant', str(a['officer_note'])),
                    ],
                  ),
                ],
                const SizedBox(height: 16),
                SectionCard(
                  title: 'Applicant',
                  children: [
                    InfoRow('Name', str(p['full_name'])),
                    InfoRow('Email', str(p['email'])),
                    InfoRow('User type', roleLabel(p['role'])),
                    InfoRow(isStudent ? 'Student ID' : 'Employee ID', str(p['id_number']), mono: true),
                    if (isStudent) ...[
                      InfoRow('Course', str(p['program'])),
                      InfoRow('Year level', str(p['year_level'])),
                    ] else ...[
                      InfoRow('Employee type', str(p['employee_type'])),
                      InfoRow('Department / Office', str(p['department'])),
                    ],
                    InfoRow('Birthday', fmtDate(p['birthday'], time: false)),
                    InfoRow('Mobile', str(p['phone']).isEmpty ? '' : '+63 ${str(p['phone'])}'),
                    InfoRow('Address', address),
                  ],
                ),
                const SizedBox(height: 16),
                SectionCard(
                  title: 'Vehicle',
                  children: [
                    InfoRow('Type', vehicleLabel(v['vehicle_type'])),
                    InfoRow('Plate number', str(v['plate_number']), mono: true),
                    InfoRow('Make / Model', str(v['make_model'])),
                    InfoRow('Color', str(v['color'])),
                    InfoRow('Model year', str(v['model_year'])),
                  ],
                ),
                const SizedBox(height: 16),
                SectionCard(
                  title: 'Documents',
                  children: [
                    if (docs.isEmpty)
                      const Text('No documents.', style: TextStyle(color: AppColors.textMuted))
                    else
                      for (final d in docs) _docRow(d),
                  ],
                ),
                if (appeal.isNotEmpty) ...[
                  const SizedBox(height: 16),
                  SectionCard(
                    title: 'Appeal',
                    children: [
                      InfoRow('Ticket', str(appeal['ticket_no']), mono: true),
                      InfoRow('Filed on', fmtDate(appeal['created_at'])),
                      InfoRow('Status', str(appeal['status']).replaceAll('_', ' ')),
                      InfoRow('Statement', str(appeal['statement'])),
                    ],
                  ),
                ],
                if (permit.isNotEmpty) ...[
                  const SizedBox(height: 16),
                  SectionCard(
                    title: 'Permit',
                    children: [
                      InfoRow('Permit number', str(permit['permit_no']), mono: true),
                      InfoRow('Sticker', str(permit['sticker_status'])),
                      InfoRow('Valid from', fmtDate(permit['valid_from'], time: false)),
                      InfoRow('Valid until', fmtDate(permit['valid_until'], time: false)),
                    ],
                  ),
                ],
              ],
            ),
          ),
        ),
      ],
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Review application', style: TextStyle(fontWeight: FontWeight.w800)),
        actions: [
          IconButton(tooltip: 'Refresh', icon: const Icon(Icons.refresh), onPressed: _load),
          const SizedBox(width: 8),
        ],
      ),
      body: _loading
          ? const Center(child: CircularProgressIndicator())
          : _error != null
              ? Center(
                  child: Column(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Text(_error!, style: const TextStyle(color: AppColors.error)),
                      const SizedBox(height: 8),
                      OutlinedButton(onPressed: _load, child: const Text('Try again')),
                    ],
                  ),
                )
              : _content(_app!),
    );
  }
}

/// Approve: choose the parking zone. Returns the zone code, '' for the
/// default zone, or null when cancelled.
class _ApproveDialog extends StatefulWidget {
  const _ApproveDialog({required this.zones});

  final List<Map<String, dynamic>> zones;

  @override
  State<_ApproveDialog> createState() => _ApproveDialogState();
}

class _ApproveDialogState extends State<_ApproveDialog> {
  String? _code;

  @override
  void initState() {
    super.initState();
    if (widget.zones.isNotEmpty) _code = str(widget.zones.first['code']);
  }

  @override
  Widget build(BuildContext context) {
    return AlertDialog(
      title: const Text('Approve application'),
      content: SizedBox(
        width: 460,
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const Text(
              'A permit number will be issued, valid for one year, and the applicant will be notified. Choose the parking zone:',
            ),
            const SizedBox(height: 14),
            if (widget.zones.isEmpty)
              const Text('No zones found. The default zone will be used.')
            else
              Wrap(
                spacing: 8,
                runSpacing: 8,
                children: [
                  for (final z in widget.zones)
                    ChoiceChip(
                      label: Text(str(z['name'])),
                      selected: _code == str(z['code']),
                      onSelected: (_) => setState(() => _code = str(z['code'])),
                    ),
                ],
              ),
          ],
        ),
      ),
      actions: [
        TextButton(onPressed: () => Navigator.pop(context), child: const Text('Cancel')),
        FilledButton(
          style: FilledButton.styleFrom(backgroundColor: AppColors.success),
          onPressed: () => Navigator.pop(context, _code ?? ''),
          child: const Text('Approve'),
        ),
      ],
    );
  }
}

class _DeclineResult {
  const _DeclineResult(this.flags, this.note);

  final List<Map<String, String>> flags;
  final String note;
}

/// Decline: flag the documents that must be fixed, with a remark for each.
class _DeclineDialog extends StatefulWidget {
  const _DeclineDialog({required this.docs});

  final List<Map<String, dynamic>> docs;

  @override
  State<_DeclineDialog> createState() => _DeclineDialogState();
}

class _DeclineDialogState extends State<_DeclineDialog> {
  late final List<String> _kinds = {for (final d in widget.docs) str(d['kind'])}.toList();
  final Map<String, bool> _checked = {};
  final Map<String, TextEditingController> _remarks = {};
  final TextEditingController _note = TextEditingController();
  String? _error;

  @override
  void initState() {
    super.initState();
    for (final k in _kinds) {
      _checked[k] = false;
      _remarks[k] = TextEditingController();
    }
  }

  @override
  void dispose() {
    for (final c in _remarks.values) {
      c.dispose();
    }
    _note.dispose();
    super.dispose();
  }

  void _submit() {
    final flags = <Map<String, String>>[
      for (final k in _kinds)
        if (_checked[k] == true)
          {
            'kind': k,
            'remark': _remarks[k]!.text.trim().isEmpty
                ? 'Please upload a clear and valid copy.'
                : _remarks[k]!.text.trim(),
          },
    ];
    final note = _note.text.trim();
    if (flags.isEmpty && note.isEmpty) {
      setState(() => _error = 'Flag at least one document or write a note.');
      return;
    }
    Navigator.pop(context, _DeclineResult(flags, note));
  }

  @override
  Widget build(BuildContext context) {
    return AlertDialog(
      title: const Text('Decline application'),
      content: SizedBox(
        width: 520,
        child: SingleChildScrollView(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              const Text('Tick the documents that must be fixed and say what is wrong. The applicant will see this and can appeal within 7 days.'),
              const SizedBox(height: 10),
              if (_kinds.isEmpty)
                const Text('There are no new documents to flag. Write a note instead.',
                    style: TextStyle(color: AppColors.textMuted)),
              for (final k in _kinds) ...[
                CheckboxListTile(
                  value: _checked[k],
                  onChanged: (v) => setState(() => _checked[k] = v ?? false),
                  title: Text(kDocLabels[k] ?? k),
                  controlAffinity: ListTileControlAffinity.leading,
                  contentPadding: EdgeInsets.zero,
                ),
                if (_checked[k] == true)
                  Padding(
                    padding: const EdgeInsets.only(left: 12, bottom: 8),
                    child: TextField(
                      controller: _remarks[k],
                      maxLines: 2,
                      decoration: const InputDecoration(
                        hintText: 'What is wrong? e.g., The plate number is not readable.',
                      ),
                    ),
                  ),
              ],
              const SizedBox(height: 12),
              TextField(
                controller: _note,
                maxLines: 3,
                decoration: const InputDecoration(
                  labelText: 'Note to the applicant (optional)',
                  hintText: 'e.g., Please upload a clearer copy of your OR/CR.',
                ),
              ),
              if (_error != null) ...[
                const SizedBox(height: 10),
                Text(_error!, style: const TextStyle(color: AppColors.error)),
              ],
            ],
          ),
        ),
      ),
      actions: [
        TextButton(onPressed: () => Navigator.pop(context), child: const Text('Cancel')),
        FilledButton(
          style: FilledButton.styleFrom(backgroundColor: AppColors.error),
          onPressed: _submit,
          child: const Text('Decline'),
        ),
      ],
    );
  }
}