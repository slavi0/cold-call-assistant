import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../providers/contact_provider.dart';
import '../models/contact_model.dart';
import '../../calls/providers/calling_sequence_provider.dart';
import '../../contact_sources/models/contact_source.dart';

/// Displays the list of contacts for a specific [ContactSource] (or all contacts
/// if no source is passed) and initiates the calling workflow.
///
/// Navigation:
/// - Tapping a contact → opens [ContactDetailScreen] in single-call mode.
/// - "Start Calling" → opens [ContactDetailScreen] in sequence mode for the
///   filtered contacts of the active source.
class ContactsScreen extends StatelessWidget {
  const ContactsScreen({super.key});

  @override
  Widget build(BuildContext context) {
    // Extract optional ContactSource passed as route arguments
    final source = ModalRoute.of(context)?.settings.arguments as ContactSource?;
    final title = source != null ? source.displayName : 'Contacts';

    return Scaffold(
      appBar: AppBar(
        title: Text(title),
        centerTitle: true,
      ),
      body: Consumer<ContactProvider>(
        builder: (context, contactProvider, child) {
          if (contactProvider.isLoading) {
            return const Center(child: CircularProgressIndicator());
          }

          if (contactProvider.errorMessage != null) {
            return Center(
              child: Padding(
                padding: const EdgeInsets.all(24.0),
                child: Text(
                  contactProvider.errorMessage!,
                  style: const TextStyle(color: Colors.red, fontSize: 16),
                  textAlign: TextAlign.center,
                ),
              ),
            );
          }

          // Filter contacts strictly for the active source if one was passed
          final contacts = source != null
              ? contactProvider.getContactsForSource(source.id)
              : contactProvider.contacts;

          if (contacts.isEmpty) {
            return _EmptyContactsView(sourceDisplayName: source?.displayName);
          }

          return Column(
            children: [
              Expanded(
                child: ListView.separated(
                  itemCount: contacts.length,
                  separatorBuilder: (_, _) => const Divider(height: 1),
                  itemBuilder: (context, index) {
                    final contact = contacts[index];
                    return _ContactListTile(
                      contact: contact,
                      onTap: () => _openContactDetail(context, contact),
                    );
                  },
                ),
              ),
              _StartCallingButton(contacts: contacts),
            ],
          );
        },
      ),
    );
  }

  void _openContactDetail(BuildContext context, ContactModel contact) {
    Navigator.pushNamed(
      context,
      '/contact-detail',
      arguments: contact.id,
    );
  }
}

// ── Private sub-widgets ────────────────────────────────────────────────────

class _ContactListTile extends StatelessWidget {
  const _ContactListTile({
    required this.contact,
    required this.onTap,
  });

  final ContactModel contact;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return ListTile(
      leading: CircleAvatar(
        backgroundColor: Colors.blue.shade100,
        child: Text(
          contact.name.isNotEmpty ? contact.name[0].toUpperCase() : '?',
          style: TextStyle(
            color: Colors.blue.shade800,
            fontWeight: FontWeight.bold,
          ),
        ),
      ),
      title: Text(
        contact.name,
        style: const TextStyle(fontWeight: FontWeight.w600),
      ),
      subtitle: Text(contact.phoneNumber ?? '—'),
      trailing: const Icon(Icons.chevron_right),
      onTap: onTap,
    );
  }
}

class _StartCallingButton extends StatelessWidget {
  const _StartCallingButton({required this.contacts});

  final List<ContactModel> contacts;

  @override
  Widget build(BuildContext context) {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.fromLTRB(24, 12, 24, 24),
      child: ElevatedButton.icon(
        style: ElevatedButton.styleFrom(
          padding: const EdgeInsets.symmetric(vertical: 16),
          backgroundColor: Colors.green,
          foregroundColor: Colors.white,
          textStyle: const TextStyle(
            fontSize: 17,
            fontWeight: FontWeight.bold,
          ),
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(12),
          ),
        ),
        onPressed: contacts.isEmpty
            ? null
            : () => _startCallingSequence(context),
        icon: const Icon(Icons.play_arrow_rounded),
        label: Text('Start Calling (${contacts.length} contacts)'),
      ),
    );
  }

  void _startCallingSequence(BuildContext context) {
    // Start the sequence in the provider using only the active contacts
    context.read<CallingSequenceProvider>().startSequence(contacts);

    // Navigate to the first contact's detail screen using its ID
    Navigator.pushNamed(
      context,
      '/contact-detail',
      arguments: contacts.first.id,
    );
  }
}

class _EmptyContactsView extends StatelessWidget {
  const _EmptyContactsView({this.sourceDisplayName});

  final String? sourceDisplayName;

  @override
  Widget build(BuildContext context) {
    final title = sourceDisplayName != null
        ? 'No contacts found for "$sourceDisplayName"'
        : 'No contacts found';

    return Center(
      child: Padding(
        padding: const EdgeInsets.all(32.0),
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(
              Icons.people_outline_rounded,
              size: 72,
              color: Colors.grey.shade400,
            ),
            const SizedBox(height: 20),
            Text(
              title,
              style: const TextStyle(
                fontSize: 18,
                fontWeight: FontWeight.bold,
              ),
              textAlign: TextAlign.center,
            ),
            const SizedBox(height: 8),
            Text(
              'Import contacts from this source in Settings to start calling.',
              style: TextStyle(
                fontSize: 14,
                color: Colors.grey.shade600,
              ),
              textAlign: TextAlign.center,
            ),
          ],
        ),
      ),
    );
  }
}
