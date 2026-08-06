import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../models/contact_source.dart';
import '../providers/contact_import_provider.dart';
import '../providers/contact_source_provider.dart';
import '../../contacts/providers/contact_provider.dart';
import 'google_account_banner.dart';

/// Displays and manages the list of configured contact sources.
///
/// This is the main settings screen for the contact import system.
/// Each tile provides an **Edit** and an **Import** action.
///
/// ## Adding a new source type to the UI
/// 1. Add a `_SourceOption` entry in [_AddSourceBottomSheet].
/// 2. Handle the new subtype in `_SourceTile._sourceIcon`,
///    `_SourceTile._sourceSubtitle`, and `_SourceTile._openConfigScreen`.
/// The compiler enforces exhaustiveness on every switch.
class ContactSourcesScreen extends StatelessWidget {
  const ContactSourcesScreen({super.key});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Contact Sources'),
        centerTitle: true,
      ),
      body: Consumer<ContactSourceProvider>(
        builder: (context, provider, child) {
          if (provider.isLoading) {
            return const Center(child: CircularProgressIndicator());
          }

          if (provider.errorMessage != null) {
            return Center(
              child: Padding(
                padding: const EdgeInsets.all(24),
                child: Text(
                  provider.errorMessage!,
                  style: const TextStyle(color: Colors.red),
                  textAlign: TextAlign.center,
                ),
              ),
            );
          }

          return Column(
            children: [
              // Sign-in banner is always visible so the user can manage their
              // Google account without navigating elsewhere.
              const Padding(
                padding: EdgeInsets.fromLTRB(16, 16, 16, 0),
                child: GoogleAccountBanner(),
              ),
              Expanded(
                child: provider.sources.isEmpty
                    ? const _EmptyState()
                    : ListView.separated(
                        padding: const EdgeInsets.all(16),
                        itemCount: provider.sources.length,
                        separatorBuilder: (_, _) =>
                            const SizedBox(height: 8),
                        itemBuilder: (context, index) {
                          final source = provider.sources[index];
                          return _SourceTile(source: source);
                        },
                      ),
              ),
            ],
          );
        },
      ),
      floatingActionButton: FloatingActionButton.extended(
        onPressed: () => _showAddSourceSheet(context),
        icon: const Icon(Icons.add),
        label: const Text('Add Source'),
      ),
    );
  }

  void _showAddSourceSheet(BuildContext context) {
    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
      ),
      builder: (_) => const _AddSourceBottomSheet(),
    );
  }
}

// ── Private widgets ───────────────────────────────────────────────────────────

class _EmptyState extends StatelessWidget {
  const _EmptyState();

  @override
  Widget build(BuildContext context) {
    return Center(
      child: Padding(
        padding: const EdgeInsets.all(40),
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(Icons.cloud_off_rounded, size: 80, color: Colors.grey.shade300),
            const SizedBox(height: 20),
            const Text(
              'No contact sources',
              style: TextStyle(fontSize: 20, fontWeight: FontWeight.bold),
            ),
            const SizedBox(height: 10),
            Text(
              'Add a source to import contacts from Google Sheets\nor another CRM in the future.',
              textAlign: TextAlign.center,
              style: TextStyle(color: Colors.grey.shade600, fontSize: 15),
            ),
            const SizedBox(height: 32),
            OutlinedButton.icon(
              onPressed: () => showModalBottomSheet(
                context: context,
                isScrollControlled: true,
                shape: const RoundedRectangleBorder(
                  borderRadius:
                      BorderRadius.vertical(top: Radius.circular(20)),
                ),
                builder: (_) => const _AddSourceBottomSheet(),
              ),
              icon: const Icon(Icons.add),
              label: const Text('Add your first source'),
            ),
          ],
        ),
      ),
    );
  }
}

class _SourceTile extends StatelessWidget {
  const _SourceTile({required this.source});

  final ContactSource source;

  @override
  Widget build(BuildContext context) {
    return Dismissible(
      key: ValueKey(source.id),
      direction: DismissDirection.endToStart,
      background: Container(
        alignment: Alignment.centerRight,
        padding: const EdgeInsets.only(right: 24),
        decoration: BoxDecoration(
          color: Colors.red.shade400,
          borderRadius: BorderRadius.circular(12),
        ),
        child: const Icon(Icons.delete_rounded, color: Colors.white),
      ),
      confirmDismiss: (_) => _confirmDelete(context),
      onDismissed: (_) =>
          context.read<ContactSourceProvider>().removeSource(source.id),
      child: Card(
        margin: EdgeInsets.zero,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
        child: ListTile(
          contentPadding:
              const EdgeInsets.symmetric(horizontal: 16, vertical: 4),
          leading: CircleAvatar(
            backgroundColor: Colors.green.shade50,
            child: Icon(_sourceIcon(), color: Colors.green.shade700),
          ),
          title: Text(
            source.displayName,
            style: const TextStyle(fontWeight: FontWeight.w600),
          ),
          subtitle: Text(_sourceSubtitle()),
          trailing: Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              // Import button — triggers a full import from this source.
              IconButton(
                icon: const Icon(Icons.download_rounded),
                tooltip: 'Import contacts',
                color: Colors.blue.shade600,
                onPressed: () => _startImport(context),
              ),
              // Edit button — opens the source config screen.
              IconButton(
                icon: const Icon(Icons.edit_rounded),
                tooltip: 'Edit',
                color: Colors.grey.shade600,
                onPressed: () => _openConfigScreen(context),
              ),
            ],
          ),
        ),
      ),
    );
  }

  IconData _sourceIcon() {
    return switch (source) {
      GoogleSheetsSource() => Icons.table_chart_rounded,
    };
  }

  String _sourceSubtitle() {
    return switch (source) {
      GoogleSheetsSource(worksheetName: final ws) =>
        'Google Sheets · $ws',
    };
  }

  Future<bool?> _confirmDelete(BuildContext context) {
    return showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('Remove source?'),
        content: Text(
          'Remove "${source.displayName}"?\n\n'
          'This does not delete any contacts that were already imported.',
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx, false),
            child: const Text('Cancel'),
          ),
          TextButton(
            onPressed: () => Navigator.pop(ctx, true),
            style: TextButton.styleFrom(foregroundColor: Colors.red),
            child: const Text('Remove'),
          ),
        ],
      ),
    );
  }

  void _openConfigScreen(BuildContext context) {
    switch (source) {
      case GoogleSheetsSource():
        Navigator.pushNamed(
          context,
          '/settings/google-sheets',
          arguments: source,
        );
    }
  }

  Future<void> _startImport(BuildContext context) async {
    // Confirm before importing — imports can take several seconds for large sheets.
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('Import contacts?'),
        content: Text(
          'Import contacts from "${source.displayName}"?\n\n'
          'Existing contacts with the same phone number will be skipped.',
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx, false),
            child: const Text('Cancel'),
          ),
          ElevatedButton(
            onPressed: () => Navigator.pop(ctx, true),
            child: const Text('Import'),
          ),
        ],
      ),
    );

    if (confirmed != true || !context.mounted) return;

    final importProvider = context.read<ContactImportProvider>();
    final contactProvider = context.read<ContactProvider>();

    // Show a non-dismissible progress overlay during import.
    if (context.mounted) {
      showDialog(
        context: context,
        barrierDismissible: false,
        builder: (_) => const _ImportProgressDialog(),
      );
    }

    final summary = await importProvider.importFromSource(
      source: source as GoogleSheetsSource,
      contactProvider: contactProvider,
    );

    if (!context.mounted) return;

    // Close the progress overlay.
    Navigator.pop(context);

    if (summary != null) {
      // Navigate to the summary screen.
      Navigator.pushNamed(context, '/import-summary', arguments: summary);
    } else {
      // Show the error as a snackbar — it's a pre-import failure (auth, network).
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(importProvider.errorMessage ?? 'Import failed.'),
          backgroundColor: Colors.red,
          behavior: SnackBarBehavior.floating,
        ),
      );
    }
  }
}

/// Non-dismissible overlay shown while an import is in progress.
class _ImportProgressDialog extends StatelessWidget {
  const _ImportProgressDialog();

  @override
  Widget build(BuildContext context) {
    return Consumer<ContactImportProvider>(
      builder: (context, provider, _) {
        final total = provider.totalRows;
        final processed = provider.processedRows;
        final hasProgress = total > 0;

        return AlertDialog(
          content: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              const CircularProgressIndicator(),
              const SizedBox(height: 20),
              const Text(
                'Importing contacts…',
                style: TextStyle(fontWeight: FontWeight.w500),
              ),
              if (hasProgress) ...[
                const SizedBox(height: 8),
                Text(
                  '$processed / $total rows processed',
                  style: TextStyle(
                    fontSize: 13,
                    color: Colors.grey.shade600,
                  ),
                ),
              ],
            ],
          ),
        );
      },
    );
  }
}

class _AddSourceBottomSheet extends StatelessWidget {
  const _AddSourceBottomSheet();

  @override
  Widget build(BuildContext context) {
    return SafeArea(
      child: Padding(
        padding: const EdgeInsets.fromLTRB(16, 24, 16, 16),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const Text(
              'Choose a contact source',
              style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold),
            ),
            const SizedBox(height: 4),
            Text(
              'Select the system where your contacts are stored.',
              style: TextStyle(fontSize: 13, color: Colors.grey.shade600),
            ),
            const SizedBox(height: 20),
            _SourceOption(
              icon: Icons.table_chart_rounded,
              label: 'Google Sheets',
              color: Colors.green,
              onTap: () {
                Navigator.pop(context);
                Navigator.pushNamed(context, '/settings/google-sheets');
              },
            ),
            const SizedBox(height: 8),
            const _ComingSoonOption(
              icon: Icons.hub_rounded,
              label: 'HubSpot',
            ),
            const _ComingSoonOption(
              icon: Icons.cloud_rounded,
              label: 'GoHighLevel',
            ),
            const _ComingSoonOption(
              icon: Icons.cloud_done_rounded,
              label: 'Salesforce',
            ),
            const _ComingSoonOption(
              icon: Icons.table_rows_rounded,
              label: 'CSV / Excel file',
            ),
            const _ComingSoonOption(
              icon: Icons.grid_on_rounded,
              label: 'Airtable',
            ),
            const SizedBox(height: 8),
          ],
        ),
      ),
    );
  }
}

class _SourceOption extends StatelessWidget {
  const _SourceOption({
    required this.icon,
    required this.label,
    required this.color,
    required this.onTap,
  });

  final IconData icon;
  final String label;
  final Color color;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return ListTile(
      leading: CircleAvatar(
        backgroundColor: color.withValues(alpha: 0.12),
        child: Icon(icon, color: color),
      ),
      title: Text(label, style: const TextStyle(fontWeight: FontWeight.w500)),
      trailing: const Icon(Icons.chevron_right),
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
      tileColor: Theme.of(context)
          .colorScheme
          .surfaceContainerHighest
          .withValues(alpha: 0.4),
      onTap: onTap,
    );
  }
}

class _ComingSoonOption extends StatelessWidget {
  const _ComingSoonOption({required this.icon, required this.label});

  final IconData icon;
  final String label;

  @override
  Widget build(BuildContext context) {
    return ListTile(
      leading: CircleAvatar(
        backgroundColor: Colors.grey.shade100,
        child: Icon(icon, color: Colors.grey.shade400),
      ),
      title: Text(label, style: TextStyle(color: Colors.grey.shade400)),
      trailing: Container(
        padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
        decoration: BoxDecoration(
          color: Colors.grey.shade100,
          borderRadius: BorderRadius.circular(4),
        ),
        child: Text(
          'Coming soon',
          style: TextStyle(fontSize: 11, color: Colors.grey.shade500),
        ),
      ),
      enabled: false,
    );
  }
}
