import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../providers/contact_provider.dart';
import '../models/contact_model.dart';
import '../../calls/providers/calling_sequence_provider.dart';

/// Displays the full list of contacts and initiates the calling workflow.
///
/// Two entry points:
/// - Tapping a contact → opens [ContactDetailScreen] in single-call mode.
/// - "Start Calling" → opens [ContactDetailScreen] in sequence mode where
///   the next contact is shown automatically when a call ends.
class ContactsScreen extends StatelessWidget {
  const ContactsScreen({super.key});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Contacts'),
        centerTitle: true,
      ),
      body: Consumer<ContactProvider>(
        builder: (context, contactProvider, child) {
          if (contactProvider.isLoading) {
            return const Center(child: CircularProgressIndicator());
          }

          if (contactProvider.errorMessage != null) {
            return Center(
              child: Text(
                contactProvider.errorMessage!,
                style: const TextStyle(color: Colors.red),
              ),
            );
          }

          final contacts = contactProvider.contacts;

          if (contacts.isEmpty) {
            return const Center(child: Text('No contacts found.'));
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
      arguments: contact,
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
    // Start the sequence in the provider — no navigation logic here.
    context.read<CallingSequenceProvider>().startSequence(contacts);

    // Navigate to the first contact's detail screen.
    Navigator.pushNamed(
      context,
      '/contact-detail',
      arguments: contacts.first,
    );
  }
}
