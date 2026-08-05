import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../models/contact_source.dart';
import '../providers/contact_source_provider.dart';

/// Displays and manages the list of configured contact sources.
///
/// This is the main settings screen for the contact import system.
/// Users can add new sources, edit existing ones, and remove sources they
/// no longer need.
///
/// ## Adding a new source type to the UI
/// 1. Add a new `_SourceOption` entry in [_AddSourceBottomSheet].
/// 2. Add a case to `_SourceTile._sourceIcon` and `_SourceTile._sourceSubtitle`
///    for the new [ContactSource] subtype.
/// 3. Add a navigation case to `_SourceTile._openConfigScreen`.
/// The compiler will flag any incomplete switch cases automatically.
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

          if (provider.sources.isEmpty) {
            return const _EmptyState();
          }

          return ListView.separated(
            padding: const EdgeInsets.all(16),
            itemCount: provider.sources.length,
            separatorBuilder: (_, _) => const SizedBox(height: 8),
            itemBuilder: (context, index) {
              final source = provider.sources[index];
              return _SourceTile(source: source);
            },
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
            Icon(
              Icons.cloud_off_rounded,
              size: 80,
              color: Colors.grey.shade300,
            ),
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
          trailing: const Icon(Icons.chevron_right),
          onTap: () => _openConfigScreen(context),
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
      GoogleSheetsSource(worksheetName: final ws) => 'Google Sheets · $ws',
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
    // Exhaustive switch — adding a new source type will produce a compile
    // error here until the corresponding config screen and route are added.
    switch (source) {
      case GoogleSheetsSource():
        Navigator.pushNamed(
          context,
          '/settings/google-sheets',
          arguments: source,
        );
    }
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
            // Future providers are listed here to communicate the roadmap.
            // Enable them in a future phase by replacing _ComingSoonOption
            // with a _SourceOption that navigates to the config screen.
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
      tileColor:
          Theme.of(context).colorScheme.surfaceContainerHighest.withValues(alpha: 0.4),
      onTap: onTap,
    );
  }
}

class _ComingSoonOption extends StatelessWidget {
  const _ComingSoonOption({
    required this.icon,
    required this.label,
  });

  final IconData icon;
  final String label;

  @override
  Widget build(BuildContext context) {
    return ListTile(
      leading: CircleAvatar(
        backgroundColor: Colors.grey.shade100,
        child: Icon(icon, color: Colors.grey.shade400),
      ),
      title: Text(
        label,
        style: TextStyle(color: Colors.grey.shade400),
      ),
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
