import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../models/contact_source.dart';
import '../providers/contact_source_provider.dart';
import '../providers/sync_provider.dart';
import '../../contacts/providers/contact_provider.dart';
import '../../contacts/services/contact_service.dart';

/// Screen allowing the user to select a configured [ContactSource] to browse
/// its imported contacts and initiate a calling session.
///
/// Workflow:
/// Main Menu → SelectSourceScreen → ContactsScreen (filtered by selected source).
class SelectSourceScreen extends StatelessWidget {
  const SelectSourceScreen({super.key});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Select Contact Source'),
        centerTitle: true,
        actions: [
          IconButton(
            icon: const Icon(Icons.settings_rounded),
            tooltip: 'Configure Sources',
            onPressed: () => Navigator.pushNamed(context, '/settings'),
          ),
        ],
      ),
      body: Consumer2<ContactSourceProvider, ContactProvider>(
        builder: (context, sourceProvider, contactProvider, child) {
          if (sourceProvider.isLoading) {
            return const Center(child: CircularProgressIndicator());
          }

          if (sourceProvider.errorMessage != null) {
            return Center(
              child: Padding(
                padding: const EdgeInsets.all(24.0),
                child: Text(
                  sourceProvider.errorMessage!,
                  style: const TextStyle(color: Colors.red, fontSize: 16),
                  textAlign: TextAlign.center,
                ),
              ),
            );
          }

          final sources = sourceProvider.sources;

          if (sources.isEmpty) {
            return _EmptySourcesView();
          }

          return ListView.separated(
            padding: const EdgeInsets.symmetric(vertical: 8),
            itemCount: sources.length,
            separatorBuilder: (_, _) => const Divider(height: 1),
            itemBuilder: (context, index) {
              final source = sources[index];
              final count = contactProvider.getContactCountForSource(source.id);
              return _SourceListTile(
                source: source,
                contactCount: count,
                onTap: () => _onSourceSelected(context, source),
                onDelete: () => _onDeleteSource(context, source, count, contactProvider),
              );
            },
          );
        },
      ),
    );
  }

  void _onSourceSelected(BuildContext context, ContactSource source) {
    Navigator.pushNamed(
      context,
      '/contacts',
      arguments: source,
    );
  }

  Future<void> _onDeleteSource(
    BuildContext context,
    ContactSource source,
    int contactCount,
    ContactProvider contactProvider,
  ) async {
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (_) => _DeleteSourceDialog(
        source: source,
        contactCount: contactCount,
      ),
    );
    if (confirmed != true || !context.mounted) return;

    try {
      await context.read<ContactSourceProvider>().deleteSourceWithContacts(
            source,
            context.read<ContactService>(),
            context.read<SyncProvider>(),
          );
      if (context.mounted) {
        await context.read<ContactProvider>().reload();
      }
    } catch (_) {
      if (context.mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(
              'Failed to delete "${source.displayName}". Please try again.',
            ),
            backgroundColor: Colors.red.shade700,
          ),
        );
      }
    }
  }
}

// ── Private sub-widgets ────────────────────────────────────────────────────

class _SourceListTile extends StatelessWidget {
  const _SourceListTile({
    required this.source,
    required this.contactCount,
    required this.onTap,
    required this.onDelete,
  });

  final ContactSource source;
  final int contactCount;
  final VoidCallback onTap;
  final VoidCallback onDelete;

  @override
  Widget build(BuildContext context) {
    final typeLabel = switch (source) {
      GoogleSheetsSource() => 'Google Sheets',
    };

    return ListTile(
      contentPadding: const EdgeInsets.symmetric(horizontal: 20, vertical: 8),
      leading: CircleAvatar(
        radius: 24,
        backgroundColor: Colors.blue.shade50,
        child: Icon(
          switch (source) {
            GoogleSheetsSource() => Icons.table_chart_rounded,
          },
          color: Colors.blue.shade700,
        ),
      ),
      title: Text(
        source.displayName,
        style: const TextStyle(
          fontWeight: FontWeight.bold,
          fontSize: 16,
        ),
      ),
      subtitle: Padding(
        padding: const EdgeInsets.only(top: 4.0),
        child: Text(
          typeLabel,
          style: TextStyle(
            color: Colors.grey.shade600,
            fontSize: 13,
          ),
        ),
      ),
      trailing: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
            decoration: BoxDecoration(
              color: contactCount > 0
                  ? Colors.blue.shade50
                  : Colors.grey.shade200,
              borderRadius: BorderRadius.circular(12),
            ),
            child: Text(
              '$contactCount ${contactCount == 1 ? 'contact' : 'contacts'}',
              style: TextStyle(
                fontSize: 12,
                fontWeight: FontWeight.bold,
                color: contactCount > 0
                    ? Colors.blue.shade800
                    : Colors.grey.shade600,
              ),
            ),
          ),
          const SizedBox(width: 4),
          // Delete button — opens confirmation dialog before deleting.
          IconButton(
            icon: Icon(Icons.delete_outline_rounded, color: Colors.red.shade400),
            tooltip: 'Delete source',
            onPressed: onDelete,
          ),
          const Icon(Icons.chevron_right_rounded, color: Colors.grey),
        ],
      ),
      onTap: onTap,
    );
  }
}

class _EmptySourcesView extends StatelessWidget {
  @override
  Widget build(BuildContext context) {
    return Center(
      child: Padding(
        padding: const EdgeInsets.all(32.0),
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(
              Icons.folder_off_rounded,
              size: 80,
              color: Colors.grey.shade400,
            ),
            const SizedBox(height: 24),
            const Text(
              'No Contact Sources Configured',
              style: TextStyle(
                fontSize: 20,
                fontWeight: FontWeight.bold,
              ),
              textAlign: TextAlign.center,
            ),
            const SizedBox(height: 12),
            Text(
              'Add a contact source in Settings to import prospects and start calling.',
              style: TextStyle(
                fontSize: 14,
                color: Colors.grey.shade600,
              ),
              textAlign: TextAlign.center,
            ),
            const SizedBox(height: 32),
            ElevatedButton.icon(
              style: ElevatedButton.styleFrom(
                padding: const EdgeInsets.symmetric(
                  horizontal: 24,
                  vertical: 12,
                ),
                backgroundColor: Colors.blue,
                foregroundColor: Colors.white,
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(12),
                ),
              ),
              onPressed: () => Navigator.pushNamed(context, '/settings'),
              icon: const Icon(Icons.settings_rounded),
              label: const Text('Configure Sources'),
            ),
          ],
        ),
      ),
    );
  }
}

/// A confirmation dialog for deleting a [ContactSource] and all its locally
/// imported contacts.
///
/// Clearly communicates:
/// - The source name being deleted.
/// - How many contacts will be removed locally.
/// - That the original Google Sheet / external source is NOT modified.
/// - That the action cannot be undone locally.
class _DeleteSourceDialog extends StatelessWidget {
  const _DeleteSourceDialog({
    required this.source,
    required this.contactCount,
  });

  final ContactSource source;
  final int contactCount;

  @override
  Widget build(BuildContext context) {
    final contactLine = contactCount > 0
        ? '$contactCount ${contactCount == 1 ? 'locally stored contact' : 'locally stored contacts'} will also be removed.\n\n'
        : '';

    final sourceTypeNote = switch (source) {
      GoogleSheetsSource() =>
        'The original Google Sheet will not be changed.',
    };

    return AlertDialog(
      title: Text('Delete "${source.displayName}"?'),
      content: Text(
        '$contactLine$sourceTypeNote\n\n'
        'This action cannot be undone locally.',
      ),
      actions: [
        TextButton(
          onPressed: () => Navigator.pop(context, false),
          child: const Text('Cancel'),
        ),
        TextButton(
          onPressed: () => Navigator.pop(context, true),
          style: TextButton.styleFrom(foregroundColor: Colors.red),
          child: const Text('Delete Source'),
        ),
      ],
    );
  }
}
