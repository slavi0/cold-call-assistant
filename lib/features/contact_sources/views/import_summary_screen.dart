import 'package:flutter/material.dart';

import '../models/contact_import_summary.dart';

/// Displays the result of a completed contact import operation.
///
/// **Route argument**: the [ContactImportSummary] to display.
/// Navigate here with:
/// ```dart
/// Navigator.pushNamed(context, '/import-summary', arguments: summary);
/// ```
class ImportSummaryScreen extends StatelessWidget {
  const ImportSummaryScreen({super.key});

  @override
  Widget build(BuildContext context) {
    final summary =
        ModalRoute.of(context)!.settings.arguments as ContactImportSummary;
    final success = summary.isSuccess;

    return Scaffold(
      appBar: AppBar(
        title: const Text('Import Complete'),
        centerTitle: true,
        automaticallyImplyLeading: false,
      ),
      body: ListView(
        padding: const EdgeInsets.all(24),
        children: [
          // ── Hero icon ─────────────────────────────────────────────────────
          Center(
            child: Icon(
              success
                  ? (summary.hasErrors
                      ? Icons.warning_rounded
                      : Icons.check_circle_rounded)
                  : Icons.error_rounded,
              size: 80,
              color: success
                  ? (summary.hasErrors ? Colors.orange : Colors.green)
                  : Colors.red,
            ),
          ),
          const SizedBox(height: 16),
          Center(
            child: Text(
              summary.sourceDisplayName,
              style: const TextStyle(
                fontSize: 20,
                fontWeight: FontWeight.bold,
              ),
              textAlign: TextAlign.center,
            ),
          ),
          const SizedBox(height: 4),
          Center(
            child: Text(
              'Completed at ${_formatTime(summary.completedAt)}  ·  '
              '${summary.totalRows} row(s) read',
              style: TextStyle(fontSize: 13, color: Colors.grey.shade600),
              textAlign: TextAlign.center,
            ),
          ),
          const SizedBox(height: 32),

          // ── Stat cards ────────────────────────────────────────────────────
          _StatCard(
            icon: Icons.person_add_rounded,
            label: 'Contacts imported',
            value: summary.imported,
            color: Colors.green,
          ),
          const SizedBox(height: 12),
          _StatCard(
            icon: Icons.skip_next_rounded,
            label: 'Skipped (already exist)',
            value: summary.skipped,
            color: Colors.blue,
          ),
          const SizedBox(height: 12),
          _StatCard(
            icon: Icons.warning_amber_rounded,
            label: 'Failed rows',
            value: summary.failed,
            color: summary.failed > 0 ? Colors.red : Colors.grey,
          ),

          // ── Error list ────────────────────────────────────────────────────
          if (summary.errors.isNotEmpty) ...[
            const SizedBox(height: 24),
            _ExpandableErrorList(errors: summary.errors),
          ],

          const SizedBox(height: 36),

          ElevatedButton(
            onPressed: () => Navigator.popUntil(
              context,
              ModalRoute.withName('/settings'),
            ),
            style: ElevatedButton.styleFrom(
              padding: const EdgeInsets.symmetric(vertical: 14),
            ),
            child: const Text('Done'),
          ),
          const SizedBox(height: 8),
        ],
      ),
    );
  }

  String _formatTime(DateTime dt) {
    final h = dt.hour.toString().padLeft(2, '0');
    final m = dt.minute.toString().padLeft(2, '0');
    return '$h:$m';
  }
}

// ── Private widgets ───────────────────────────────────────────────────────────

class _StatCard extends StatelessWidget {
  const _StatCard({
    required this.icon,
    required this.label,
    required this.value,
    required this.color,
  });

  final IconData icon;
  final String label;
  final int value;
  final Color color;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 16),
      decoration: BoxDecoration(
        color: color.withValues(alpha: 0.08),
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: color.withValues(alpha: 0.2)),
      ),
      child: Row(
        children: [
          Icon(icon, color: color, size: 26),
          const SizedBox(width: 14),
          Expanded(
            child: Text(label, style: const TextStyle(fontSize: 15)),
          ),
          Text(
            value.toString(),
            style: TextStyle(
              fontSize: 24,
              fontWeight: FontWeight.bold,
              color: color,
            ),
          ),
        ],
      ),
    );
  }
}

class _ExpandableErrorList extends StatefulWidget {
  const _ExpandableErrorList({required this.errors});

  final List<String> errors;

  @override
  State<_ExpandableErrorList> createState() => _ExpandableErrorListState();
}

class _ExpandableErrorListState extends State<_ExpandableErrorList> {
  bool _expanded = false;

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        InkWell(
          onTap: () => setState(() => _expanded = !_expanded),
          borderRadius: BorderRadius.circular(8),
          child: Padding(
            padding: const EdgeInsets.symmetric(vertical: 8),
            child: Row(
              children: [
                Icon(
                  _expanded ? Icons.expand_less : Icons.expand_more,
                  color: Colors.red,
                  size: 20,
                ),
                const SizedBox(width: 8),
                Text(
                  '${_expanded ? "Hide" : "Show"} '
                  '${widget.errors.length} error(s)',
                  style: const TextStyle(
                    color: Colors.red,
                    fontWeight: FontWeight.w500,
                  ),
                ),
              ],
            ),
          ),
        ),
        if (_expanded)
          Container(
            padding: const EdgeInsets.all(12),
            decoration: BoxDecoration(
              color: Colors.red.shade50,
              borderRadius: BorderRadius.circular(8),
            ),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: widget.errors
                  .map(
                    (err) => Padding(
                      padding: const EdgeInsets.only(bottom: 6),
                      child: Text(
                        '• $err',
                        style: const TextStyle(fontSize: 13, height: 1.4),
                      ),
                    ),
                  )
                  .toList(),
            ),
          ),
      ],
    );
  }
}
