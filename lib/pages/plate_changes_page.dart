import 'package:flutter/material.dart';
import '../admin_service.dart';
import '../ui.dart';
import 'common.dart';
import 'plate_change_review_page.dart';
import 'review_widgets.dart';

class PlateChangesPage extends StatefulWidget {
  const PlateChangesPage({super.key});

  @override
  State<PlateChangesPage> createState() => _PlateChangesPageState();
}

class _PlateChangesPageState extends State<PlateChangesPage> {
  List<Map<String, dynamic>> _rows = [];
  bool _loading = true;
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
      final rows = await AdminService.plateChanges();
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

  Future<void> _review(int index) async {
    await Navigator.push(
      context,
      MaterialPageRoute(builder: (_) => PlateChangeReviewPage(queue: _rows, index: index)),
    );
    _load();
  }

  Widget _row(int i) {
    final v = _rows[i];
    final o = asOne(v['owner']);
    return RowCard(
      onTap: () => _review(i),
      child: Wrap(
        spacing: 24,
        runSpacing: 12,
        crossAxisAlignment: WrapCrossAlignment.center,
        children: [
          infoCol(str(v['plate_number']), 'New plate number', mono: true),
          infoCol(str(v['make_model']), '${vehicleLabel(v['vehicle_type'])}  |  ${str(v['color'])}'),
          infoCol(str(o['full_name']), '${roleLabel(o['role'])}  |  ${str(o['id_number'])}'),
          infoCol(fmtDate(v['updated_at']), 'Changed on', width: 180),
          statePill('Waiting', 'warning'),
        ],
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return ListPageFrame(
      title: 'Plate changes',
      filters: const {'pending': 'Waiting for verification'},
      selected: 'pending',
      onFilter: (_) {},
      onRefresh: _load,
      loading: _loading,
      error: _error,
      emptyText: 'No plate changes to verify.',
      children: [for (var i = 0; i < _rows.length; i++) _row(i)],
    );
  }
}