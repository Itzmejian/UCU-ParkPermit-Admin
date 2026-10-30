import 'package:flutter/material.dart';
import 'package:url_launcher/url_launcher.dart';
import '../admin_service.dart';
import '../ui.dart';
import 'common.dart';

class PlateChangesPage extends StatefulWidget {
  const PlateChangesPage({super.key});

  @override
  State<PlateChangesPage> createState() => _PlateChangesPageState();
}

class _PlateChangesPageState extends State<PlateChangesPage> {
  List<Map<String, dynamic>> _rows = [];
  bool _loading = true;
  String? _error;
  String? _busyId;

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

  Future<void> _openOrcr(Map<String, dynamic> v) async {
    try {
      final path = await AdminService.latestOrcrPath(str(v['id']));
      if (!mounted) return;
      if (path == null) {
        showSnack(context, 'No OR/CR was found for this vehicle.');
        return;
      }
      final url = await AdminService.documentUrl(path);
      await launchUrl(Uri.parse(url), webOnlyWindowName: '_blank');
    } catch (_) {
      if (!mounted) return;
      showSnack(context, 'Could not open the file.');
    }
  }

  Future<void> _verify(Map<String, dynamic> v) async {
    final ok = await confirmDialog(
      context,
      title: 'Verify the new plate number?',
      message: 'Confirm that the new OR/CR shows the plate ${str(v['plate_number'])}. The applicant will be notified.',
      action: 'Verify',
      color: AppColors.success,
    );
    if (!ok || !mounted) return;
    setState(() => _busyId = str(v['id']));
    final err = await AdminService.verifyVehicle(str(v['id']));
    if (!mounted) return;
    setState(() => _busyId = null);
    showSnack(context, err ?? 'Verified. The applicant was notified.');
    _load();
  }

  Widget _row(Map<String, dynamic> v) {
    final o = asOne(v['owner']);
    final busy = _busyId == str(v['id']);
    return RowCard(
      child: Wrap(
        spacing: 24,
        runSpacing: 12,
        crossAxisAlignment: WrapCrossAlignment.center,
        children: [
          infoCol(str(v['plate_number']), 'New plate number', mono: true),
          infoCol(str(v['make_model']), '${vehicleLabel(v['vehicle_type'])}  |  ${str(v['color'])}'),
          infoCol(str(o['full_name']), '${roleLabel(o['role'])}  |  ${str(o['id_number'])}'),
          infoCol(fmtDate(v['updated_at']), 'Changed on', width: 180),
          OutlinedButton.icon(
            onPressed: () => _openOrcr(v),
            icon: const Icon(Icons.open_in_new, size: 18),
            label: const Text('Open new OR/CR'),
          ),
          FilledButton.icon(
            style: FilledButton.styleFrom(backgroundColor: AppColors.success),
            onPressed: busy ? null : () => _verify(v),
            icon: const Icon(Icons.verified_outlined, size: 18),
            label: const Text('Verify'),
          ),
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
      children: [for (final v in _rows) _row(v)],
    );
  }
}