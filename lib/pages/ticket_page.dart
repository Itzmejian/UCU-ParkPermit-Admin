import 'package:flutter/material.dart';
import '../admin_service.dart';
import '../ui.dart';
import 'common.dart';
import 'review_widgets.dart';

/// One support message. The message is on the left, the reply box on the right.
class TicketPage extends StatefulWidget {
  const TicketPage({super.key, required this.queue, required this.index});

  final List<Map<String, dynamic>> queue;
  final int index;

  @override
  State<TicketPage> createState() => _TicketPageState();
}

class _TicketPageState extends State<TicketPage> {
  Map<String, dynamic> get _t => widget.queue[widget.index];
  late final TextEditingController _reply = TextEditingController(text: str(_t['reply']));
  bool _busy = false;
  String? _error;

  bool get _closed => _t['status'] == 'closed';
  bool get _hasReply => str(_t['reply']).isNotEmpty;

  static const List<String> _quick = [
    'Thank you for your message. We are checking this and will update you soon.',
    'Please visit the Campus Security Office during office hours so we can help you in person.',
    'Your concern has been resolved. Thank you for your patience.',
  ];

  @override
  void dispose() {
    _reply.dispose();
    super.dispose();
  }

  void _next(String message) {
    final i = widget.index + 1;
    if (i >= widget.queue.length) {
      showSnack(context, '$message No more open messages.');
      Navigator.pop(context, true);
      return;
    }
    showSnack(context, '$message Opening the next message.');
    Navigator.pushReplacement(
      context,
      MaterialPageRoute(builder: (_) => TicketPage(queue: widget.queue, index: i)),
    );
  }

  Future<void> _send() async {
    final text = _reply.text.trim();
    if (text.length < 5) {
      setState(() => _error = 'Write a reply first (at least 5 characters).');
      return;
    }
    setState(() => _error = null);
    final u = asOne(_t['user']);
    final ok = await confirmDialog(
      context,
      title: 'Send this reply?',
      message: '${str(u['full_name']).isEmpty ? 'The sender' : str(u['full_name'])} will see your reply in the app notifications.',
      action: 'Send reply',
    );
    if (!ok || !mounted) return;
    setState(() => _busy = true);
    final err = await AdminService.replyTicket(str(_t['id']), text);
    if (!mounted) return;
    setState(() => _busy = false);
    if (err != null) {
      showSnack(context, err);
      return;
    }
    _next('Reply sent.');
  }

  Future<void> _close() async {
    final ok = await confirmDialog(
      context,
      title: 'Close ${str(_t['ticket_no'])}?',
      message: 'Close the message only when the concern is resolved. A closed message cannot be replied to.',
      action: 'Close message',
    );
    if (!ok || !mounted) return;
    setState(() => _busy = true);
    final err = await AdminService.closeTicket(str(_t['id']));
    if (!mounted) return;
    setState(() => _busy = false);
    if (err != null) {
      showSnack(context, err);
      return;
    }
    _next('Message closed.');
  }

  Widget _statusPill() => switch (str(_t['status'])) {
        'answered' => statePill('Answered', 'success'),
        'closed' => statePill('Closed', 'gray'),
        _ => statePill('Open', 'warning'),
      };

  Widget _bubble({required String who, required String when, required String text, required bool mine}) {
    return Align(
      alignment: mine ? Alignment.centerRight : Alignment.centerLeft,
      child: Container(
        constraints: const BoxConstraints(maxWidth: 560),
        margin: const EdgeInsets.only(bottom: 12),
        padding: const EdgeInsets.all(14),
        decoration: BoxDecoration(
          color: mine ? AppColors.navy : AppColors.inputFill,
          borderRadius: BorderRadius.only(
            topLeft: const Radius.circular(16),
            topRight: const Radius.circular(16),
            bottomLeft: Radius.circular(mine ? 16 : 4),
            bottomRight: Radius.circular(mine ? 4 : 16),
          ),
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text('$who  |  $when',
                style: TextStyle(
                    fontSize: 12, fontWeight: FontWeight.w700, color: mine ? AppColors.gold : AppColors.navy)),
            const SizedBox(height: 6),
            SelectableText(text,
                style: TextStyle(height: 1.45, color: mine ? Colors.white : AppColors.textDark)),
          ],
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final t = _t;
    final u = asOne(t['user']);
    final left = <Widget>[
      ReviewTitle(
        code: str(t['ticket_no']),
        subtitle: 'Sent ${fmtDate(t['created_at'])}',
        pills: [Pill(str(t['topic'])), _statusPill()],
      ),
      if (!_closed) QueueStrip(index: widget.index, total: widget.queue.length, noun: 'Message'),
      SectionCard(
        title: str(t['subject']).isEmpty ? 'Message' : str(t['subject']),
        icon: Icons.forum_outlined,
        children: [
          _bubble(
            who: str(u['full_name']).isEmpty ? 'Sender' : str(u['full_name']),
            when: fmtDate(t['created_at']),
            text: str(t['message']),
            mine: false,
          ),
          if (_hasReply)
            _bubble(
              who: 'Security Office',
              when: fmtDate(t['replied_at']),
              text: str(t['reply']),
              mine: true,
            ),
        ],
      ),
      const SizedBox(height: 16),
      SectionCard(
        title: 'Sender',
        children: [
          InfoRow('Name', str(u['full_name'])),
          InfoRow('Email', str(u['email'])),
          InfoRow('User type', u['role'] == 'guard' ? 'Guard' : roleLabel(u['role'])),
        ],
      ),
    ];
    final right = <Widget>[
      SectionCard(
        title: _closed ? 'Closed' : (_hasReply ? 'Update your reply' : 'Your reply'),
        icon: Icons.reply_outlined,
        children: _closed
            ? const [NoticeBox('This message is closed. No more replies can be sent.', icon: Icons.lock_outline)]
            : [
                const Text('Quick replies', style: TextStyle(fontSize: 12.5, fontWeight: FontWeight.w700, color: AppColors.textHint)),
                const SizedBox(height: 8),
                Wrap(
                  spacing: 8,
                  runSpacing: 8,
                  children: [
                    for (final q in _quick)
                      ActionChip(
                        label: Text(q.length > 42 ? '${q.substring(0, 42)}...' : q),
                        tooltip: q,
                        onPressed: () => setState(() => _reply.text = q),
                      ),
                  ],
                ),
                const SizedBox(height: 12),
                TextField(
                  controller: _reply,
                  minLines: 6,
                  maxLines: 10,
                  maxLength: 1000,
                  decoration: InputDecoration(
                    hintText: 'Write your reply. The sender will see it in the app notifications.',
                    errorText: _error,
                  ),
                ),
                const SizedBox(height: 8),
                DecisionButtons(
                  primaryLabel: _hasReply ? 'Send updated reply' : 'Send reply',
                  primaryIcon: Icons.send_outlined,
                  primaryColor: AppColors.navy,
                  onPrimary: _send,
                  secondaryLabel: 'Close message',
                  secondaryIcon: Icons.done_all,
                  secondaryColor: AppColors.textMuted,
                  onSecondary: _close,
                  busy: _busy,
                ),
              ],
      ),
    ];
    return Scaffold(
      appBar: AppBar(title: const Text('Support message', style: TextStyle(fontWeight: FontWeight.w800))),
      body: ReviewLayout(left: left, right: right),
    );
  }
}
