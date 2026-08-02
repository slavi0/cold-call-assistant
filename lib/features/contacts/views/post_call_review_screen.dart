import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../models/contact_model.dart';
import '../models/contact_status.dart';
import '../providers/contact_provider.dart';
import '../../calls/providers/calling_sequence_provider.dart';

/// Post-call review screen shown after every phone call ends.
///
/// **Route arguments** (passed as `Map<String, dynamic>`):
/// - `contactId` (`String`): ID of the contact that was just called.
/// - `isSequenceMode` (`bool`): whether the user is in a "Start Calling" session.
///
/// **Responsibilities**:
/// - Display the contact's current status and notes.
/// - Allow the salesperson to update status and notes before moving on.
/// - Save changes via [ContactProvider.updateContact] (no Hive access in UI).
/// - In sequence mode: "Next Contact" advances [CallingSequenceProvider] and
///   navigates to the next [ContactDetailScreen].
/// - In browsing mode: "Done" saves and pops back to [ContactDetailScreen].
///
/// **State synchronisation**: the contact is read from [ContactProvider] via
/// [ContactProvider.findById], so edits are immediately visible on screens
/// that watch the provider.
class PostCallReviewScreen extends StatefulWidget {
  const PostCallReviewScreen({super.key});

  @override
  State<PostCallReviewScreen> createState() => _PostCallReviewScreenState();
}

class _PostCallReviewScreenState extends State<PostCallReviewScreen> {
  // ── Route args ─────────────────────────────────────────────────────────
  late String _contactId;
  late bool _isSequenceMode;
  bool _initialized = false;

  // ── Local form state ────────────────────────────────────────────────────
  ContactStatus? _selectedStatus;
  final TextEditingController _notesController = TextEditingController();
  bool _isSaving = false;

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    if (!_initialized) {
      final args =
          ModalRoute.of(context)!.settings.arguments as Map<String, dynamic>;
      _contactId = args['contactId'] as String;
      _isSequenceMode = args['isSequenceMode'] as bool;

      // Pre-populate form fields from the current contact state.
      final contact =
          context.read<ContactProvider>().findById(_contactId);
      if (contact != null) {
        _selectedStatus = contact.status;
        _notesController.text = contact.notes ?? '';
      }

      _initialized = true;
    }
  }

  @override
  void dispose() {
    _notesController.dispose();
    super.dispose();
  }

  // ── Save & navigate ─────────────────────────────────────────────────────

  Future<void> _saveAndContinue() async {
    setState(() => _isSaving = true);

    final contactProvider = context.read<ContactProvider>();
    final contact = contactProvider.findById(_contactId);

    if (contact != null) {
      final notes = _notesController.text.trim();
      final updated = contact.copyWith(
        status: _selectedStatus,
        // Store empty string when notes are cleared; display logic handles it.
        notes: notes,
        // Record when this review was submitted — a reliable proxy for the
        // call timestamp since the review opens immediately after the call.
        lastCalledAt: DateTime.now(),
        updatedAt: DateTime.now(),
      );
      await contactProvider.updateContact(updated);
    }

    if (!mounted) return;
    setState(() => _isSaving = false);

    if (!_isSequenceMode) {
      // Browsing mode: pop back to ContactDetailScreen.
      Navigator.pop(context);
      return;
    }

    // Sequence mode: advance to the next contact.
    final sequenceProvider = context.read<CallingSequenceProvider>();
    final nextContact = sequenceProvider.advanceToNext();

    if (!mounted) return;

    if (nextContact == null) {
      // Sequence complete — return to the contacts list.
      Navigator.popUntil(context, ModalRoute.withName('/contacts'));
    } else {
      // Replace this review screen with the next contact's detail screen.
      Navigator.pushReplacementNamed(
        context,
        '/contact-detail',
        arguments: nextContact.id,
      );
    }
  }

  // ── Build ───────────────────────────────────────────────────────────────

  @override
  Widget build(BuildContext context) {
    // Watch the provider so this screen rebuilds if the contact changes.
    final contact =
        context.watch<ContactProvider>().findById(_contactId);

    if (contact == null) {
      return const Scaffold(
        body: Center(child: Text('Contact not found.')),
      );
    }

    final sequenceProvider = context.watch<CallingSequenceProvider>();
    final progressLabel = _isSequenceMode
        ? 'Contact ${sequenceProvider.currentIndex + 1} of ${sequenceProvider.totalContacts}'
        : null;

    return Scaffold(
      appBar: AppBar(
        title: const Text('Post-Call Review'),
        centerTitle: true,
        // Hide back button in sequence mode to prevent skipping the review.
        automaticallyImplyLeading: !_isSequenceMode,
      ),
      body: Column(
        children: [
          Expanded(
            child: SingleChildScrollView(
              padding: const EdgeInsets.all(24.0),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  _ContactSummaryTile(
                    contact: contact,
                    progressLabel: progressLabel,
                  ),
                  const SizedBox(height: 32),
                  _StatusDropdown(
                    value: _selectedStatus ?? contact.status,
                    onChanged: (status) =>
                        setState(() => _selectedStatus = status),
                  ),
                  const SizedBox(height: 24),
                  _NotesField(controller: _notesController),
                ],
              ),
            ),
          ),
          _ActionButton(
            isSequenceMode: _isSequenceMode,
            isSaving: _isSaving,
            onPressed: _isSaving ? null : _saveAndContinue,
          ),
        ],
      ),
    );
  }
}

// ── Private sub-widgets ────────────────────────────────────────────────────

class _ContactSummaryTile extends StatelessWidget {
  const _ContactSummaryTile({
    required this.contact,
    required this.progressLabel,
  });

  final ContactModel contact;
  final String? progressLabel;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: Theme.of(context).colorScheme.primaryContainer,
        borderRadius: BorderRadius.circular(12),
      ),
      child: Row(
        children: [
          CircleAvatar(
            backgroundColor: Theme.of(context).colorScheme.primary,
            child: Text(
              contact.name.isNotEmpty
                  ? contact.name[0].toUpperCase()
                  : '?',
              style: const TextStyle(
                color: Colors.white,
                fontWeight: FontWeight.bold,
              ),
            ),
          ),
          const SizedBox(width: 16),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  contact.name,
                  style: const TextStyle(
                    fontSize: 18,
                    fontWeight: FontWeight.bold,
                  ),
                ),
                Text(
                  contact.phoneNumber ?? '—',
                  style: const TextStyle(color: Colors.grey),
                ),
                if (progressLabel != null) ...[
                  const SizedBox(height: 2),
                  Text(
                    progressLabel!,
                    style: TextStyle(
                      fontSize: 12,
                      color: Theme.of(context).colorScheme.primary,
                      fontWeight: FontWeight.w600,
                    ),
                  ),
                ],
              ],
            ),
          ),
        ],
      ),
    );
  }
}

class _StatusDropdown extends StatelessWidget {
  const _StatusDropdown({
    required this.value,
    required this.onChanged,
  });

  final ContactStatus value;
  final ValueChanged<ContactStatus?> onChanged;

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        const Text(
          'Call Outcome',
          style: TextStyle(
            fontSize: 14,
            fontWeight: FontWeight.bold,
            color: Colors.grey,
          ),
        ),
        const SizedBox(height: 8),
        DropdownButtonFormField<ContactStatus>(
          initialValue: value,
          decoration: InputDecoration(
            border: OutlineInputBorder(
              borderRadius: BorderRadius.circular(8),
            ),
            contentPadding:
                const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
          ),
          items: ContactStatus.values
              .map(
                (s) => DropdownMenuItem(
                  value: s,
                  child: Text(s.displayLabel),
                ),
              )
              .toList(),
          onChanged: onChanged,
        ),
      ],
    );
  }
}

class _NotesField extends StatelessWidget {
  const _NotesField({required this.controller});

  final TextEditingController controller;

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        const Text(
          'Notes',
          style: TextStyle(
            fontSize: 14,
            fontWeight: FontWeight.bold,
            color: Colors.grey,
          ),
        ),
        const SizedBox(height: 8),
        TextFormField(
          controller: controller,
          minLines: 4,
          maxLines: 8,
          keyboardType: TextInputType.multiline,
          decoration: InputDecoration(
            hintText: 'Add notes about this call…',
            border: OutlineInputBorder(
              borderRadius: BorderRadius.circular(8),
            ),
            contentPadding: const EdgeInsets.all(16),
          ),
        ),
      ],
    );
  }
}

class _ActionButton extends StatelessWidget {
  const _ActionButton({
    required this.isSequenceMode,
    required this.isSaving,
    required this.onPressed,
  });

  final bool isSequenceMode;
  final bool isSaving;
  final VoidCallback? onPressed;

  @override
  Widget build(BuildContext context) {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.fromLTRB(24, 12, 24, 36),
      child: ElevatedButton.icon(
        style: ElevatedButton.styleFrom(
          padding: const EdgeInsets.symmetric(vertical: 16),
          backgroundColor:
              isSequenceMode ? Colors.green : Colors.blue,
          foregroundColor: Colors.white,
          textStyle: const TextStyle(
            fontSize: 17,
            fontWeight: FontWeight.bold,
          ),
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(12),
          ),
        ),
        onPressed: onPressed,
        icon: isSaving
            ? const SizedBox(
                width: 20,
                height: 20,
                child: CircularProgressIndicator(
                  color: Colors.white,
                  strokeWidth: 2,
                ),
              )
            : Icon(isSequenceMode
                ? Icons.skip_next_rounded
                : Icons.check_rounded),
        label: Text(
          isSaving
              ? 'Saving…'
              : isSequenceMode
                  ? 'Next Contact'
                  : 'Done',
        ),
      ),
    );
  }
}
