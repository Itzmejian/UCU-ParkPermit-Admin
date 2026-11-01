import 'dart:js_interop';
import 'dart:ui' as ui;
import 'package:flutter/material.dart';
import 'package:flutter/rendering.dart';
import 'package:qr_flutter/qr_flutter.dart';
import 'package:web/web.dart' as web;
import '../ui.dart';

/// A printable permit sticker. The guard scans its QR code to verify it.
/// The color shows the parking zone, so it can be seen from far away.
class StickerPage extends StatefulWidget {
  const StickerPage({super.key, required this.permit});

  final Map<String, dynamic> permit;

  @override
  State<StickerPage> createState() => _StickerPageState();
}

class _StickerPageState extends State<StickerPage> {
  final GlobalKey _stickerKey = GlobalKey();
  bool _saving = false;

  static const Map<String, Color> _zoneColors = {
    'A': Color(0xFF1D3E7C),
    'B': Color(0xFF0D5C3A),
    'C': Color(0xFF6B3FA0),
    'M': Color(0xFFC77700),
  };

  String get _zoneCode => str(asOne(widget.permit['zone'])['code']).toUpperCase();

  Color get _zoneColor => _zoneColors[_zoneCode] ?? AppColors.navy;

  String get _years {
    final from = DateTime.tryParse(str(widget.permit['valid_from']));
    final until = DateTime.tryParse(str(widget.permit['valid_until']));
    if (until == null) return 'VALID PERMIT';
    if (from == null || from.year == until.year) return '${until.year}';
    return '${from.year}–${until.year}';
  }

  Future<void> _download() async {
    setState(() => _saving = true);
    try {
      final boundary = _stickerKey.currentContext!.findRenderObject() as RenderRepaintBoundary;
      final image = await boundary.toImage(pixelRatio: 4);
      final data = await image.toByteData(format: ui.ImageByteFormat.png);
      if (data == null) throw Exception('No image');
      final bytes = data.buffer.asUint8List();
      final blob = web.Blob(<JSAny>[bytes.toJS].toJS, web.BlobPropertyBag(type: 'image/png'));
      final url = web.URL.createObjectURL(blob);
      final a = web.HTMLAnchorElement()
        ..href = url
        ..download = 'sticker-${str(widget.permit['permit_no'])}.png';
      a.click();
      web.URL.revokeObjectURL(url);
    } catch (_) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Could not save the image. Use Print instead.')),
        );
      }
    }
    if (mounted) setState(() => _saving = false);
  }

  Widget _sticker() {
    final p = widget.permit;
    final v = asOne(p['vehicle']);
    final z = asOne(p['zone']);
    final token = str(p['qr_token']);
    final color = _zoneColor;
    final moto = v['vehicle_type'] == 'motorcycle';

    return Container(
      width: 380,
      clipBehavior: Clip.antiAlias,
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(22),
        border: Border.all(color: color, width: 4),
      ),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          Container(
            color: color,
            padding: const EdgeInsets.fromLTRB(16, 14, 16, 14),
            child: Row(
              children: [
                Container(
                  width: 54,
                  height: 54,
                  padding: const EdgeInsets.all(5),
                  decoration: const BoxDecoration(color: Colors.white, shape: BoxShape.circle),
                  child: const AdminLogo(size: 44),
                ),
                const SizedBox(width: 12),
                const Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        'URDANETA CITY UNIVERSITY',
                        style: TextStyle(fontSize: 10.5, fontWeight: FontWeight.w800, letterSpacing: 0.8, color: Colors.white70),
                      ),
                      Text(
                        'PARKING PERMIT',
                        style: TextStyle(fontSize: 21, fontWeight: FontWeight.w900, letterSpacing: 1, color: Colors.white),
                      ),
                    ],
                  ),
                ),
                Column(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    const Text(
                      'ZONE',
                      style: TextStyle(fontSize: 9.5, fontWeight: FontWeight.w800, color: Colors.white70),
                    ),
                    const SizedBox(height: 2),
                    Container(
                      width: 46,
                      height: 46,
                      alignment: Alignment.center,
                      decoration: const BoxDecoration(color: Colors.white, shape: BoxShape.circle),
                      child: Text(
                        _zoneCode.isEmpty ? '-' : _zoneCode,
                        style: TextStyle(fontSize: 24, fontWeight: FontWeight.w900, color: color),
                      ),
                    ),
                  ],
                ),
              ],
            ),
          ),
          Container(
            width: double.infinity,
            color: AppColors.gold,
            padding: const EdgeInsets.symmetric(vertical: 6),
            child: Text(
              _years,
              textAlign: TextAlign.center,
              style: const TextStyle(fontSize: 20, fontWeight: FontWeight.w900, letterSpacing: 3, color: AppColors.navyDark),
            ),
          ),
          Padding(
            padding: const EdgeInsets.fromLTRB(18, 16, 18, 8),
            child: token.isEmpty
                ? const Padding(
                    padding: EdgeInsets.all(24),
                    child: Text('No QR code yet. Run SQL Part 9 first.', style: TextStyle(color: AppColors.error)),
                  )
                : QrImageView(data: 'UCUPP:$token', size: 210, backgroundColor: Colors.white),
          ),
          Text(
            str(v['plate_number']),
            style: const TextStyle(fontFamily: 'monospace', fontSize: 34, fontWeight: FontWeight.w900, color: AppColors.textDark),
          ),
          const SizedBox(height: 2),
          Row(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              Icon(moto ? Icons.two_wheeler : Icons.directions_car, size: 18, color: AppColors.textMuted),
              const SizedBox(width: 6),
              Text(
                str(z['name']).isEmpty ? (moto ? 'Motorcycle' : '4-Wheel Vehicle') : str(z['name']),
                style: const TextStyle(fontSize: 13, color: AppColors.textMuted),
              ),
            ],
          ),
          const SizedBox(height: 8),
          Text(
            str(p['permit_no']),
            style: TextStyle(fontFamily: 'monospace', fontSize: 15, fontWeight: FontWeight.w800, color: color),
          ),
          Text(
            'Valid until ${fmtDate(p['valid_until'], time: false)}',
            style: const TextStyle(fontSize: 13, fontWeight: FontWeight.w600, color: AppColors.textDark),
          ),
          const SizedBox(height: 12),
          Container(
            width: double.infinity,
            color: AppColors.surface,
            padding: const EdgeInsets.symmetric(vertical: 8, horizontal: 12),
            child: const Text(
              'Scan to verify  •  Not transferable  •  UCU Security Office',
              textAlign: TextAlign.center,
              style: TextStyle(fontSize: 10.5, color: AppColors.textHint),
            ),
          ),
        ],
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppColors.surface,
      appBar: AppBar(
        title: const Text('Permit sticker'),
        actions: [
          OutlinedButton.icon(
            onPressed: _saving ? null : _download,
            icon: const Icon(Icons.download_outlined),
            label: const Text('Download PNG'),
          ),
          const SizedBox(width: 8),
          FilledButton.icon(
            onPressed: () => web.window.print(),
            icon: const Icon(Icons.print_outlined),
            label: const Text('Print'),
          ),
          const SizedBox(width: 12),
        ],
      ),
      body: Center(
        child: SingleChildScrollView(
          padding: const EdgeInsets.all(24),
          child: Column(
            children: [
              RepaintBoundary(key: _stickerKey, child: _sticker()),
              const SizedBox(height: 16),
              const Text(
                'Print on waterproof vinyl sticker paper. Keep the QR code at least 3 cm wide.',
                textAlign: TextAlign.center,
                style: TextStyle(fontSize: 12.5, color: AppColors.textHint),
              ),
            ],
          ),
        ),
      ),
    );
  }
}