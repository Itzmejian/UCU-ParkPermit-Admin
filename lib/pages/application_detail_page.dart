import 'dart:ui_web' as ui_web;

import 'package:flutter/material.dart';
import 'package:web/web.dart' as web;
import '../admin_service.dart';
import '../ui.dart';
import 'common.dart';
import 'start_review.dart';

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

  void _snack(String m) => showSnack(context, m);

  bool _needsStart(Map<String, dynamic> a) => needsStartReview(a);

  bool _isAppeal(Map<String, dynamic> a) => str(a['status']) == 'appeal_review';

  Future<void> _startReview() async {
    setState(() => _busy = true);
    final err = await AdminService.startReview(widget.id);
    if (!mounted) return;
    setState(() => _busy = false);
    final appeal = _app != null && _isAppeal(_app!);
    _snack(err ??
        (appeal
            ? 'Appeal review started. The applicant now sees "Appeal under review" in the app.'
            : 'Review started. The applicant now sees "Under review" in the app.'));
    _load();
  }

  /// After a decision, open the next application that is still waiting.
  /// A new one asks "Start the review?" first; "Not now" goes back to the list.
  Future<void> _goNext(String message) async {
    String? next;
    try {
      next = await AdminService.nextWaiting(widget.id);
    } catch (_) {}
    if (!mounted) return;
    if (next == null) {
      _snack('$message No more applications are waiting.');
      Navigator.pop(context, true);
      return;
    }
    _snack('$message Next application is ready.');
    final opened = await openApplication(context, next, replace: true);
    if (!opened && mounted) Navigator.pop(context, true);
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
    if (r.error != null) {
      _snack(r.error!);
      _load();
      return;
    }
    _goNext('Approved. Permit ${r.permitNo} was issued.');
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
    if (err != null) {
      _snack(err);
      _load();
      return;
    }
    _goNext('Declined. The applicant can file an appeal.');
  }

  // ---------- right side: decision ----------

  Widget _decisionCard(Map<String, dynamic> a) {
    final status = str(a['status']);
    final waiting = const ['pending', 'under_review', 'appeal_review'].contains(status);
    if (!waiting) {
      final approved = status == 'approved';
      return SectionCard(
        title: 'Result',
        icon: approved ? Icons.verified_outlined : Icons.cancel_outlined,
        children: [
          Row(
            children: [
              statusPill(status),
              const SizedBox(width: 10),
              Expanded(
                child: Text(
                  approved
                      ? 'Approved on ${fmtDate(a['reviewed_at'])}.'
                      : 'Declined on ${fmtDate(a['declined_at'] ?? a['reviewed_at'])}.',
                  style: const TextStyle(color: AppColors.textMuted),
                ),
              ),
            ],
          ),
          if (status == 'declined' && str(a['officer_note']).isNotEmpty) ...[
            const SizedBox(height: 10),
            InfoRow('Note to applicant', str(a['officer_note'])),
          ],
        ],
      );
    }
    final needsStart = _needsStart(a);
    final text = switch (status) {
      'pending' => 'This application is not under review yet. Start the review so the applicant sees "Under review" in the app.',
      'appeal_review' when needsStart =>
        'The applicant appealed and uploaded new files. Start the review so the applicant sees "Appeal under review" in the app.',
      'appeal_review' => 'Appeal under review. Check the new files, then approve or decline.',
      _ => 'Under review. Check the documents against the details, then approve or decline.',
    };
    return SectionCard(
      title: 'Your decision',
      children: [
        Text(text, style: const TextStyle(color: AppColors.textMuted)),
        const SizedBox(height: 14),
        if (needsStart)
          SizedBox(
            width: double.infinity,
            child: FilledButton.icon(
              style: FilledButton.styleFrom(
                backgroundColor: AppColors.navy,
                padding: const EdgeInsets.symmetric(vertical: 16),
              ),
              onPressed: _busy ? null : _startReview,
              icon: const Icon(Icons.manage_search),
              label: Text(status == 'appeal_review' ? 'Start appeal review' : 'Start review'),
            ),
          )
        else
          Row(
            children: [
              Expanded(
                child: FilledButton.icon(
                  style: FilledButton.styleFrom(
                    backgroundColor: AppColors.success,
                    padding: const EdgeInsets.symmetric(vertical: 16),
                  ),
                  onPressed: _busy ? null : _approve,
                  icon: const Icon(Icons.check_circle_outline),
                  label: const Text('Approve'),
                ),
              ),
              const SizedBox(width: 10),
              Expanded(
                child: OutlinedButton.icon(
                  style: OutlinedButton.styleFrom(
                    foregroundColor: AppColors.error,
                    side: const BorderSide(color: AppColors.error),
                    padding: const EdgeInsets.symmetric(vertical: 16),
                  ),
                  onPressed: _busy ? null : _decline,
                  icon: const Icon(Icons.cancel_outlined),
                  label: const Text('Decline'),
                ),
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

  Widget _documents(List<Map<String, dynamic>> docs) {
    return SectionCard(
      title: 'Documents',
      children: [
        if (docs.isEmpty)
          const Text('No documents.', style: TextStyle(color: AppColors.textMuted))
        else
          for (final d in docs) _DocPreview(key: ValueKey(str(d['id'])), doc: d),
      ],
    );
  }

  // ---------- left side: details ----------

  List<Widget> _details(Map<String, dynamic> a) {
    final p = asOne(a['applicant']);
    final v = asOne(a['vehicle']);
    final appeal = asOne(a['appeals']);
    final permit = asOne(a['permits']);
    final isStudent = p['role'] != 'employee';
    final address = [p['street'], p['barangay'], p['city'], p['province']]
        .map(str)
        .where((x) => x.trim().isNotEmpty)
        .join(', ');
    return [
      Wrap(
        spacing: 10,
        runSpacing: 8,
        crossAxisAlignment: WrapCrossAlignment.center,
        children: [
          SelectableText(str(a['reference_no']),
              style: const TextStyle(
                  fontFamily: 'monospace', fontSize: 24, fontWeight: FontWeight.w800, color: AppColors.navy)),
          Pill(a['kind'] == 'renewal' ? 'Renewal' : 'New application'),
        ],
      ),
      const SizedBox(height: 4),
      Text('Submitted ${fmtDate(a['submitted_at'])}'
          '${a['reviewed_at'] == null ? '' : '  |  Reviewed ${fmtDate(a['reviewed_at'])}'}',
          style: const TextStyle(color: AppColors.textHint)),
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
    ];
  }

  Widget _content(Map<String, dynamic> a) {
    final docs = asMany(a['documents'])
      ..sort((x, y) => str(x['created_at']).compareTo(str(y['created_at'])));
    final pad = pagePadding(context);
    return LayoutBuilder(
      builder: (context, c) {
        if (c.maxWidth < 1000) {
          return ListView(
            padding: EdgeInsets.all(pad),
            children: [
              ..._details(a).take(3),
              _decisionCard(a),
              const SizedBox(height: 16),
              ..._details(a).skip(3),
              const SizedBox(height: 16),
              _documents(docs),
            ],
          );
        }
        return Row(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Expanded(
              flex: 5,
              child: ListView(
                padding: EdgeInsets.fromLTRB(pad, pad, pad / 2, pad),
                children: _details(a),
              ),
            ),
            Expanded(
              flex: 6,
              child: ListView(
                padding: EdgeInsets.fromLTRB(pad / 2, pad, pad, pad),
                children: [
                  _decisionCard(a),
                  const SizedBox(height: 16),
                  _documents(docs),
                ],
              ),
            ),
          ],
        );
      },
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Review application', style: TextStyle(fontWeight: FontWeight.w800)),
      ),
      body: _loading && _app == null
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

/// One document, shown right on the page (picture or PDF), no new tab.
class _DocPreview extends StatefulWidget {
  const _DocPreview({super.key, required this.doc});

  final Map<String, dynamic> doc;

  @override
  State<_DocPreview> createState() => _DocPreviewState();
}

class _DocPreviewState extends State<_DocPreview> {
  late final Future<String> _url = AdminService.documentUrl(str(widget.doc['file_path']));

  bool get _isPdf => str(widget.doc['file_name']).toLowerCase().endsWith('.pdf');

  Widget _viewer(String url, {required bool large}) {
    if (_isPdf) return _PdfFrame(url: url);
    final img = Image.network(
      url,
      fit: BoxFit.contain,
      webHtmlElementStrategy: WebHtmlElementStrategy.fallback,
      loadingBuilder: (context, child, p) =>
          p == null ? child : const Center(child: CircularProgressIndicator()),
      errorBuilder: (context, e, s) => const Center(
        child: Text('Could not load the picture.', style: TextStyle(color: AppColors.error)),
      ),
    );
    return large ? InteractiveViewer(maxScale: 5, child: img) : img;
  }

  void _enlarge(String url) {
    final size = MediaQuery.sizeOf(context);
    showDialog<void>(
      context: context,
      builder: (ctx) => Dialog(
        insetPadding: const EdgeInsets.all(24),
        clipBehavior: Clip.antiAlias,
        child: SizedBox(
          width: size.width * 0.9,
          height: size.height * 0.88,
          child: Column(
            children: [
              Container(
                color: AppColors.navy,
                padding: const EdgeInsets.fromLTRB(18, 8, 8, 8),
                child: Row(
                  children: [
                    Expanded(
                      child: Text(kDocLabels[str(widget.doc['kind'])] ?? str(widget.doc['kind']),
                          style: const TextStyle(color: Colors.white, fontWeight: FontWeight.w800)),
                    ),
                    if (!_isPdf)
                      const Text('Scroll to zoom', style: TextStyle(color: Colors.white70, fontSize: 12)),
                    IconButton(
                      tooltip: 'Close',
                      onPressed: () => Navigator.pop(ctx),
                      icon: const Icon(Icons.close, color: Colors.white),
                    ),
                  ],
                ),
              ),
              Expanded(child: Container(color: const Color(0xFFF1F3F8), child: _viewer(url, large: true))),
            ],
          ),
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final d = widget.doc;
    return Container(
      margin: const EdgeInsets.only(bottom: 14),
      decoration: BoxDecoration(
        color: AppColors.surface,
        borderRadius: BorderRadius.circular(14),
        border: Border.all(color: AppColors.border),
      ),
      clipBehavior: Clip.antiAlias,
      child: FutureBuilder<String>(
        future: _url,
        builder: (context, snap) {
          final url = snap.data;
          return Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              Padding(
                padding: const EdgeInsets.fromLTRB(14, 12, 8, 10),
                child: Row(
                  children: [
                    Icon(_isPdf ? Icons.picture_as_pdf_outlined : Icons.image_outlined, color: AppColors.navy),
                    const SizedBox(width: 10),
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
                        ],
                      ),
                    ),
                    if (url != null)
                      TextButton.icon(
                        onPressed: () => _enlarge(url),
                        icon: const Icon(Icons.zoom_out_map, size: 18),
                        label: const Text('Enlarge'),
                      ),
                  ],
                ),
              ),
              if (str(d['reviewer_remark']).isNotEmpty)
                Padding(
                  padding: const EdgeInsets.fromLTRB(14, 0, 14, 10),
                  child: Text('Remark: ${str(d['reviewer_remark'])}',
                      style: const TextStyle(fontSize: 12.5, color: AppColors.error)),
                ),
              Container(
                height: 360,
                color: const Color(0xFFF1F3F8),
                child: snap.hasError
                    ? const Center(
                        child: Text('Could not load the file.', style: TextStyle(color: AppColors.error)),
                      )
                    : url == null
                        ? const Center(child: CircularProgressIndicator())
                        : GestureDetector(
                            onTap: _isPdf ? null : () => _enlarge(url),
                            child: MouseRegion(
                              cursor: _isPdf ? MouseCursor.defer : SystemMouseCursors.zoomIn,
                              child: _viewer(url, large: false),
                            ),
                          ),
              ),
            ],
          );
        },
      ),
    );
  }
}

/// Shows a PDF inside the page with the browser's own PDF viewer.
class _PdfFrame extends StatefulWidget {
  const _PdfFrame({required this.url});

  final String url;

  @override
  State<_PdfFrame> createState() => _PdfFrameState();
}

class _PdfFrameState extends State<_PdfFrame> {
  static int _next = 0;
  late final String _viewType = 'pdf-frame-${_next++}';

  @override
  void initState() {
    super.initState();
    ui_web.platformViewRegistry.registerViewFactory(_viewType, (int id) {
      final frame = web.HTMLIFrameElement()
        ..src = widget.url
        ..style.border = '0'
        ..style.width = '100%'
        ..style.height = '100%';
      return frame;
    });
  }

  @override
  Widget build(BuildContext context) => HtmlElementView(viewType: _viewType);
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
      titlePadding: EdgeInsets.zero,
      clipBehavior: Clip.antiAlias,
      title: const DialogHeader(icon: Icons.verified_outlined, title: 'Approve application', subtitle: 'Choose the parking zone for this vehicle', tone: 'success'),
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
      titlePadding: EdgeInsets.zero,
      clipBehavior: Clip.antiAlias,
      title: const DialogHeader(icon: Icons.cancel_outlined, title: 'Decline application', subtitle: 'Mark the documents that need to be fixed', tone: 'danger'),
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