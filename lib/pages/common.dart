import 'package:flutter/material.dart';
import '../ui.dart';

Future<bool> confirmDialog(
  BuildContext context, {
  required String title,
  required String message,
  required String action,
  Color color = AppColors.navy,
}) async {
  final ok = await showDialog<bool>(
    context: context,
    builder: (ctx) => AlertDialog(
      title: Text(title),
      content: SizedBox(width: 440, child: Text(message)),
      actions: [
        TextButton(onPressed: () => Navigator.pop(ctx, false), child: const Text('Cancel')),
        FilledButton(
          style: FilledButton.styleFrom(backgroundColor: color),
          onPressed: () => Navigator.pop(ctx, true),
          child: Text(action),
        ),
      ],
    ),
  );
  return ok == true;
}

void showSnack(BuildContext context, String message) {
  ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(message)));
}

/// Title, search, filter chips and the list, with loading and error states.
class ListPageFrame extends StatelessWidget {
  const ListPageFrame({
    super.key,
    required this.title,
    required this.filters,
    required this.selected,
    required this.onFilter,
    required this.onRefresh,
    required this.loading,
    required this.error,
    required this.emptyText,
    required this.children,
    this.onSearch,
    this.searchHint,
  });

  final String title;
  final Map<String, String> filters;
  final String selected;
  final ValueChanged<String> onFilter;
  final VoidCallback onRefresh;
  final bool loading;
  final String? error;
  final String emptyText;
  final List<Widget> children;
  final ValueChanged<String>? onSearch;
  final String? searchHint;

  @override
  Widget build(BuildContext context) {
    Widget body;
    if (loading) {
      body = const Center(child: CircularProgressIndicator());
    } else if (error != null) {
      body = Center(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Text(error!, style: const TextStyle(color: AppColors.error)),
            const SizedBox(height: 8),
            OutlinedButton(onPressed: onRefresh, child: const Text('Try again')),
          ],
        ),
      );
    } else if (children.isEmpty) {
      body = Center(
        child: Text(emptyText, style: const TextStyle(color: AppColors.textMuted)),
      );
    } else {
      body = ListView.separated(
        itemCount: children.length,
        separatorBuilder: (context, index) => const SizedBox(height: 8),
        itemBuilder: (context, i) => children[i],
      );
    }

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
              PageTitle(title),
              if (onSearch != null)
                SizedBox(
                  width: 320,
                  child: TextField(
                    onChanged: onSearch,
                    decoration: InputDecoration(
                      hintText: searchHint ?? 'Search',
                      prefixIcon: const Icon(Icons.search),
                      isDense: true,
                    ),
                  ),
                ),
              IconButton(tooltip: 'Refresh', icon: const Icon(Icons.refresh), onPressed: onRefresh),
            ],
          ),
          const SizedBox(height: 14),
          Wrap(
            spacing: 8,
            runSpacing: 8,
            children: [
              for (final e in filters.entries)
                ChoiceChip(
                  label: Text(e.value),
                  selected: selected == e.key,
                  onSelected: (_) => onFilter(e.key),
                ),
            ],
          ),
          const SizedBox(height: 14),
          Expanded(child: body),
        ],
      ),
    );
  }
}

class RowCard extends StatelessWidget {
  const RowCard({super.key, required this.child});

  final Widget child;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(14),
        border: Border.all(color: AppColors.border),
      ),
      child: child,
    );
  }
}

/// A small two-line block: main text and a smaller line under it.
Widget infoCol(String main, String sub, {bool mono = false, Color? subColor, double width = 220}) {
  return SizedBox(
    width: width,
    child: Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          main.isEmpty ? '-' : main,
          style: TextStyle(
            fontWeight: FontWeight.w700,
            color: AppColors.textDark,
            fontFamily: mono ? 'monospace' : null,
          ),
        ),
        Text(sub, style: TextStyle(fontSize: 12, color: subColor ?? AppColors.textHint)),
      ],
    ),
  );
}