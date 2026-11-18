import 'dart:ui_web' as ui_web;

import 'package:flutter/material.dart';
import 'package:web/web.dart' as web;
import '../admin_service.dart';
import '../ui.dart';

/// Details on the left, actions and files on the right. On narrow screens the
/// right side comes first, then the details.
class ReviewLayout extends StatelessWidget {
  const ReviewLayout({super.key, required this.left, required this.right});

  final List<Widget> left;
  final List<Widget> right;

  @override
  Widget build(BuildContext context) {
    final pad = pagePadding(context);
    return LayoutBuilder(
      builder: (context, c) {
        if (c.maxWidth < 1000) {
          return ListView(
            padding: EdgeInsets.all(pad),
            children: [...right, const SizedBox(height: 16), ...left],
          );
        }
        return Row(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Expanded(
              flex: 5,
              child: ListView(padding: EdgeInsets.fromLTRB(pad, pad, pad / 2, pad), children: left),
            ),
            Expanded(
              flex: 6,
              child: ListView(padding: EdgeInsets.fromLTRB(pad / 2, pad, pad, pad), children: right),
            ),
          ],
        );
      },
    );
  }
}

/// Page title on a review screen: big code, pills, and a line under it.
class ReviewTitle extends StatelessWidget {
  const ReviewTitle({super.key, required this.code, required this.subtitle, this.pills = const []});

  final String code;
  final String subtitle;
  final List<Widget> pills;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 16),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Wrap(
            spacing: 10,
            runSpacing: 8,
            crossAxisAlignment: WrapCrossAlignment.center,
            children: [
              SelectableText(code,
                  style: const TextStyle(
                      fontFamily: 'monospace', fontSize: 24, fontWeight: FontWeight.w800, color: AppColors.navy)),
              ...pills,
            ],
          ),
          const SizedBox(height: 4),
          Text(subtitle, style: const TextStyle(color: AppColors.textHint)),
        ],
      ),
    );
  }
}

/// "3 of 5 waiting" strip shown on review screens that work through a queue.
class QueueStrip extends StatelessWidget {
  const QueueStrip({super.key, required this.index, required this.total, required this.noun});

  final int index;
  final int total;
  final String noun;

  @override
  Widget build(BuildContext context) {
    if (total <= 1) return const SizedBox.shrink();
    return Container(
      margin: const EdgeInsets.only(bottom: 16),
      padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
      decoration: BoxDecoration(
        color: AppColors.inputFill,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: AppColors.border),
      ),
      child: Row(
        children: [
          const Icon(Icons.format_list_numbered, size: 18, color: AppColors.navy),
          const SizedBox(width: 10),
          Expanded(
            child: Text('$noun ${index + 1} of $total. The next one opens after you decide.',
                style: const TextStyle(color: AppColors.navy, fontWeight: FontWeight.w600)),
          ),
          SizedBox(
            width: 120,
            child: ClipRRect(
              borderRadius: BorderRadius.circular(4),
              child: LinearProgressIndicator(
                value: (index + 1) / total,
                minHeight: 6,
                backgroundColor: Colors.white,
                color: AppColors.gold,
              ),
            ),
          ),
        ],
      ),
    );
  }
}

/// Two big buttons side by side (for example Approve and Decline).
class DecisionButtons extends StatelessWidget {
  const DecisionButtons({
    super.key,
    required this.primaryLabel,
    required this.primaryIcon,
    required this.onPrimary,
    this.primaryColor = AppColors.success,
    this.secondaryLabel,
    this.secondaryIcon,
    this.onSecondary,
    this.secondaryColor = AppColors.error,
    this.busy = false,
  });

  final String primaryLabel;
  final IconData primaryIcon;
  final VoidCallback? onPrimary;
  final Color primaryColor;
  final String? secondaryLabel;
  final IconData? secondaryIcon;
  final VoidCallback? onSecondary;
  final Color secondaryColor;
  final bool busy;

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        Row(
          children: [
            Expanded(
              child: FilledButton.icon(
                style: FilledButton.styleFrom(
                  backgroundColor: primaryColor,
                  padding: const EdgeInsets.symmetric(vertical: 16),
                ),
                onPressed: busy ? null : onPrimary,
                icon: Icon(primaryIcon),
                label: Text(primaryLabel),
              ),
            ),
            if (secondaryLabel != null) ...[
              const SizedBox(width: 10),
              Expanded(
                child: OutlinedButton.icon(
                  style: OutlinedButton.styleFrom(
                    foregroundColor: secondaryColor,
                    side: BorderSide(color: secondaryColor),
                    padding: const EdgeInsets.symmetric(vertical: 16),
                  ),
                  onPressed: busy ? null : onSecondary,
                  icon: Icon(secondaryIcon ?? Icons.close),
                  label: Text(secondaryLabel!),
                ),
              ),
            ],
          ],
        ),
        if (busy)
          const Padding(
            padding: EdgeInsets.only(top: 12),
            child: LinearProgressIndicator(),
          ),
      ],
    );
  }
}

/// A notice box (info, success or warning) used on review screens.
class NoticeBox extends StatelessWidget {
  const NoticeBox(this.text, {super.key, this.icon = Icons.info_outline, this.tone = 'info'});

  final String text;
  final IconData icon;
  final String tone;

  @override
  Widget build(BuildContext context) {
    final (bg, fg) = switch (tone) {
      'success' => (AppColors.successLight, AppColors.success),
      'error' => (AppColors.errorLight, AppColors.error),
      'warning' => (AppColors.goldLight, AppColors.goldDark),
      _ => (AppColors.inputFill, AppColors.navy),
    };
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: bg,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: fg.withValues(alpha: 0.35)),
      ),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Icon(icon, size: 20, color: fg),
          const SizedBox(width: 10),
          Expanded(child: Text(text, style: TextStyle(color: fg, height: 1.4, fontWeight: FontWeight.w600))),
        ],
      ),
    );
  }
}

/// One uploaded file shown right on the page (picture or PDF), no new tab.
class DocPreview extends StatefulWidget {
  const DocPreview({
    super.key,
    required this.path,
    required this.fileName,
    required this.label,
    this.subtitle = '',
    this.pills = const [],
    this.height = 380,
  });

  final String path;
  final String fileName;
  final String label;
  final String subtitle;
  final List<Widget> pills;
  final double height;

  @override
  State<DocPreview> createState() => _DocPreviewState();
}

class _DocPreviewState extends State<DocPreview> {
  late final Future<String> _url = AdminService.documentUrl(widget.path);

  bool get _isPdf => widget.fileName.toLowerCase().endsWith('.pdf') || widget.path.toLowerCase().endsWith('.pdf');

  Widget _viewer(String url, {required bool large}) {
    if (_isPdf) return PdfFrame(url: url);
    final img = Image.network(
      url,
      fit: BoxFit.contain,
      webHtmlElementStrategy: WebHtmlElementStrategy.fallback,
      loadingBuilder: (context, child, p) => p == null ? child : const Center(child: CircularProgressIndicator()),
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
                      child: Text(widget.label,
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
                              Text(widget.label, style: const TextStyle(fontWeight: FontWeight.w700)),
                              ...widget.pills,
                            ],
                          ),
                          if (widget.subtitle.isNotEmpty) ...[
                            const SizedBox(height: 2),
                            Text(widget.subtitle, style: const TextStyle(fontSize: 12, color: AppColors.textHint)),
                          ],
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
              Container(
                height: widget.height,
                color: const Color(0xFFF1F3F8),
                child: snap.hasError
                    ? const Center(child: Text('Could not load the file.', style: TextStyle(color: AppColors.error)))
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
class PdfFrame extends StatefulWidget {
  const PdfFrame({super.key, required this.url});

  final String url;

  @override
  State<PdfFrame> createState() => _PdfFrameState();
}

class _PdfFrameState extends State<PdfFrame> {
  static int _next = 0;
  late final String _viewType = 'review-pdf-${_next++}';

  @override
  void initState() {
    super.initState();
    ui_web.platformViewRegistry.registerViewFactory(_viewType, (int id) {
      return web.HTMLIFrameElement()
        ..src = widget.url
        ..style.border = '0'
        ..style.width = '100%'
        ..style.height = '100%';
    });
  }

  @override
  Widget build(BuildContext context) => HtmlElementView(viewType: _viewType);
}

/// Colored pill for a sticker replacement or ticket state.
Widget statePill(String text, String tone) {
  return switch (tone) {
    'success' => Pill(text, bg: AppColors.successLight, fg: AppColors.success, border: AppColors.success),
    'error' => Pill(text, bg: AppColors.errorLight, fg: AppColors.error, border: AppColors.error),
    'warning' => Pill(text, bg: AppColors.goldLight, fg: AppColors.goldDark, border: AppColors.gold),
    _ => Pill(text),
  };
}
