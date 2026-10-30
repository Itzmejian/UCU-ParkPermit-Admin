import 'package:flutter/material.dart';
import '../admin_service.dart';
import '../ui.dart';
import 'application_detail_page.dart';

class ApplicationsPage extends StatefulWidget {
  const ApplicationsPage({super.key, this.initialStatus});

  final String? initialStatus;

  @override
  State<ApplicationsPage> createState() => _ApplicationsPageState();
}

class _ApplicationsPageState extends State<ApplicationsPage> {
  late String? _status = widget.initialStatus;
  List<Map<String, dynamic>> _rows = [];
  bool _loading = true;
  String? _error;
  String _query = '';

  static const List<String?> _filters = [
    null, 'pending', 'under_review', 'appeal_review', 'declined', 'approved',
  ];

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
      final rows = await AdminService.applications(status: _status);
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
    if (q.isEmpty) return _rows;
    return _rows.where((a) {
      final v = asOne(a['vehicle']);
      final p = asOne(a['applicant']);
      final text = '${a['reference_no']} ${v['plate_number']} ${v['make_model']} '
              '${p['full_name']} ${p['id_number']}'
          .toLowerCase();
      return text.contains(q);
    }).toList();
  }

  Future<void> _open(String id) async {
    await Navigator.push(
      context,
      MaterialPageRoute(builder: (_) => ApplicationDetailPage(id: id)),
    );
    _load();
  }

  @override
  Widget build(BuildContext context) {
    final rows = _visible;
    return Padding(
      padding: const EdgeInsets.all(24),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Wrap(
            spacing: 16,
            runSpacing: 12,
            crossAxisAlignment: WrapCrossAlignment.center,
            children: [
              const PageTitle('Applications'),
              SizedBox(
                width: 320,
                child: TextField(
                  onChanged: (v) => setState(() => _query = v),
                  decoration: const InputDecoration(
                    hintText: 'Search reference, plate, name or ID',
                    prefixIcon: Icon(Icons.search),
                    isDense: true,
                  ),
                ),
              ),
              IconButton(tooltip: 'Refresh', icon: const Icon(Icons.refresh), onPressed: _load),
            ],
          ),
          const SizedBox(height: 14),
          Wrap(
            spacing: 8,
            runSpacing: 8,
            children: [
              for (final f in _filters)
                ChoiceChip(
                  label: Text(f == null ? 'All' : (kStatusLabels[f] ?? f)),
                  selected: _status == f,
                  onSelected: (_) {
                    setState(() => _status = f);
                    _load();
                  },
                ),
            ],
          ),
          const SizedBox(height: 14),
          Expanded(
            child: _loading
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
                    : rows.isEmpty
                        ? const Center(
                            child: Text('No applications found.', style: TextStyle(color: AppColors.textMuted)),
                          )
                        : ListView.separated(
                            itemCount: rows.length,
                            separatorBuilder: (context, index) => const SizedBox(height: 8),
                            itemBuilder: (context, i) => ApplicationRow(
                              app: rows[i],
                              onTap: () => _open(str(rows[i]['id'])),
                            ),
                          ),
          ),
        ],
      ),
    );
  }
}

/// One application in a list.
class ApplicationRow extends StatelessWidget {
  const ApplicationRow({super.key, required this.app, required this.onTap});

  final Map<String, dynamic> app;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final v = asOne(app['vehicle']);
    final p = asOne(app['applicant']);
    final kind = app['kind'] == 'renewal' ? 'Renewal' : 'New';

    final refCol = Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(str(app['reference_no']),
            style: const TextStyle(fontFamily: 'monospace', fontWeight: FontWeight.w800, color: AppColors.navy)),
        Text(fmtDate(app['submitted_at']), style: const TextStyle(fontSize: 12, color: AppColors.textHint)),
      ],
    );
    final personCol = Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(str(p['full_name']).isEmpty ? '(no name)' : str(p['full_name']),
            style: const TextStyle(fontWeight: FontWeight.w700, color: AppColors.textDark)),
        Text('${roleLabel(p['role'])}  |  ${str(p['id_number'])}',
            style: const TextStyle(fontSize: 12, color: AppColors.textHint)),
      ],
    );
    final vehicleCol = Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(str(v['plate_number']),
            style: const TextStyle(fontFamily: 'monospace', fontWeight: FontWeight.w700, color: AppColors.textDark)),
        Text('${vehicleLabel(v['vehicle_type'])}  |  ${str(v['make_model'])}',
            style: const TextStyle(fontSize: 12, color: AppColors.textHint)),
      ],
    );
    final pills = Wrap(
      spacing: 6,
      runSpacing: 6,
      children: [Pill(kind), statusPill(app['status'])],
    );

    return Material(
      color: Colors.white,
      borderRadius: BorderRadius.circular(14),
      child: InkWell(
        borderRadius: BorderRadius.circular(14),
        onTap: onTap,
        child: Container(
          padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
          decoration: BoxDecoration(
            borderRadius: BorderRadius.circular(14),
            border: Border.all(color: AppColors.border),
          ),
          child: LayoutBuilder(
            builder: (context, c) {
              if (c.maxWidth < 700) {
                return Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    refCol,
                    const SizedBox(height: 8),
                    personCol,
                    const SizedBox(height: 8),
                    vehicleCol,
                    const SizedBox(height: 8),
                    pills,
                  ],
                );
              }
              return Row(
                children: [
                  Expanded(flex: 3, child: refCol),
                  Expanded(flex: 3, child: personCol),
                  Expanded(flex: 3, child: vehicleCol),
                  Expanded(flex: 3, child: pills),
                  const Icon(Icons.chevron_right, color: AppColors.textHint),
                ],
              );
            },
          ),
        ),
      ),
    );
  }
}