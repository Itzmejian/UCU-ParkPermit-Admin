import 'package:flutter/material.dart';
import 'package:web/web.dart' as web;
import '../ui.dart';

const String _key = 'ucu_admin_privacy_ok';

bool privacyAcknowledged() {
  try {
    return web.window.sessionStorage.getItem(_key) == '1';
  } catch (_) {
    return false;
  }
}

/// Shown after logging in (once per browser session) and from the footer.
Future<void> showPrivacyDialog(BuildContext context, {bool requireAck = false}) {
  return showDialog<void>(
    context: context,
    barrierDismissible: !requireAck,
    builder: (ctx) => AlertDialog(
      title: const Row(
        children: [
          Icon(Icons.privacy_tip_outlined, color: AppColors.ucuGreen),
          SizedBox(width: 10),
          Expanded(child: Text('Data Privacy Commitment')),
        ],
      ),
      content: const SizedBox(
        width: 520,
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              'This system holds personal information of students and employees: names, ID numbers, addresses, contact numbers, IDs, licenses and vehicle documents.',
              style: TextStyle(height: 1.45),
            ),
            SizedBox(height: 12),
            Text(
              'Use it only for campus parking permits, following Republic Act No. 10173, the Data Privacy Act of 2012. Do not copy, share or download records for any other purpose. Decisions you make are recorded with your account.',
              style: TextStyle(height: 1.45),
            ),
          ],
        ),
      ),
      actions: [
        FilledButton(
          style: FilledButton.styleFrom(backgroundColor: AppColors.ucuGreen),
          onPressed: () {
            try {
              web.window.sessionStorage.setItem(_key, '1');
            } catch (_) {}
            Navigator.pop(ctx);
          },
          child: const Text('I Understand'),
        ),
      ],
    ),
  );
}