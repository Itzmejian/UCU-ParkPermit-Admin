import 'package:flutter/material.dart';
import 'package:qr_flutter/qr_flutter.dart';
import 'package:web/web.dart' as web;
import '../ui.dart';

/// A printable permit sticker. The guard scans its QR code to verify it.
class StickerPage extends StatelessWidget {
  const StickerPage({super.key, required this.permit});

  final Map<String, dynamic> permit;

  @override
  Widget build(BuildContext context) {
    final v = asOne(permit['vehicle']);
    final z = asOne(permit['zone']);
    final token = str(permit['qr_token']);
    return Scaffold(
      backgroundColor: Colors.white,
      appBar: AppBar(
        title: const Text('Permit sticker', style: TextStyle(fontWeight: FontWeight.w800)),
        actions: [
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
          child: Container(
            width: 360,
            padding: const EdgeInsets.all(20),
            decoration: BoxDecoration(
              color: Colors.white,
              borderRadius: BorderRadius.circular(18),
              border: Border.all(color: AppColors.navy, width: 3),
            ),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                const Text(
                  'UCU PARKING PERMIT',
                  style: TextStyle(fontSize: 18, fontWeight: FontWeight.w900, letterSpacing: 1, color: AppColors.navy),
                ),
                const Text('Urdaneta City University', style: TextStyle(fontSize: 12, color: AppColors.textMuted)),
                const SizedBox(height: 14),
                if (token.isEmpty)
                  const Padding(
                    padding: EdgeInsets.all(24),
                    child: Text('No QR code yet. Run SQL Part 9 first.', style: TextStyle(color: AppColors.error)),
                  )
                else
                  QrImageView(data: 'UCUPP:$token', size: 220, backgroundColor: Colors.white),
                const SizedBox(height: 10),
                Text(
                  str(permit['permit_no']),
                  style: const TextStyle(fontFamily: 'monospace', fontSize: 18, fontWeight: FontWeight.w800, color: AppColors.navy),
                ),
                Text(
                  str(v['plate_number']),
                  style: const TextStyle(fontFamily: 'monospace', fontSize: 28, fontWeight: FontWeight.w900, color: AppColors.textDark),
                ),
                const SizedBox(height: 4),
                Text(
                  '${str(z['name'])}  |  Valid until ${fmtDate(permit['valid_until'], time: false)}',
                  style: const TextStyle(fontSize: 13, color: AppColors.textMuted),
                ),
                const SizedBox(height: 10),
                const Text(
                  'Scan to verify. Not transferable.',
                  style: TextStyle(fontSize: 11.5, color: AppColors.textHint),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}