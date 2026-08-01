import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../models/contact_model.dart';
import '../../calls/providers/phone_call_provider.dart';
import '../../calls/providers/calling_sequence_provider.dart';
import '../../calls/services/phone_call_service.dart';

/// Displays a single contact's details and provides a "Call" button.
///
/// Supports two modes:
/// - **Single-call mode**: user tapped a contact from the list. When the call
///   ends the user stays on this screen (normal back-navigation applies).
/// - **Sequence mode**: user pressed "Start Calling". When [didChangeAppLifecycleState]
///   fires `resumed`, [CallingSequenceProvider.advanceToNext] is called:
///   - If there is a next contact, this screen replaces itself with the next
///     contact's detail screen via [Navigator.pushReplacement].
///   - If the sequence is complete, this screen pops back to [ContactsScreen].
///
/// The [WidgetsBindingObserver] is used (same pattern as the old PhoneCallScreen)
/// to detect when the user returns from the system Phone app.
class ContactDetailScreen extends StatefulWidget {
  const ContactDetailScreen({super.key});

  @override
  State<ContactDetailScreen> createState() => _ContactDetailScreenState();
}

class _ContactDetailScreenState extends State<ContactDetailScreen>
    with WidgetsBindingObserver {
  late ContactModel _contact;
  bool _initialized = false;
  bool _callWasInitiated = false;

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    if (!_initialized) {
      // Route argument is the ContactModel for this screen.
      _contact =
          ModalRoute.of(context)!.settings.arguments as ContactModel;
      _initialized = true;
    }
  }

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addObserver(this);
  }

  @override
  void dispose() {
    WidgetsBinding.instance.removeObserver(this);
    super.dispose();
  }

  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    if (state == AppLifecycleState.resumed && _callWasInitiated) {
      _callWasInitiated = false;
      // Always reset telephony state first.
      context.read<PhoneCallProvider>().handleAppResumed();
      // Then check if we are in sequence mode.
      _handleCallEnded();
    }
  }

  void _handleCallEnded() {
    final sequenceProvider = context.read<CallingSequenceProvider>();

    if (!sequenceProvider.isSequenceActive) {
      // Single-call mode: nothing extra to do — user stays on this screen.
      return;
    }

    final nextContact = sequenceProvider.advanceToNext();

    if (nextContact == null) {
      // Sequence complete — pop back to ContactsScreen.
      Navigator.popUntil(context, ModalRoute.withName('/contacts'));
    } else {
      // Replace the current screen with the next contact's detail screen.
      // Using pushReplacement prevents the back-stack from growing indefinitely
      // during a long calling session.
      Navigator.pushReplacementNamed(
        context,
        '/contact-detail',
        arguments: nextContact,
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: Text(_contact.name),
        centerTitle: true,
        leading: IconButton(
          icon: const Icon(Icons.arrow_back),
          onPressed: () {
            // If the user manually navigates back during a sequence, cancel it.
            context.read<CallingSequenceProvider>().cancelSequence();
            Navigator.pop(context);
          },
        ),
      ),
      body: Column(
        children: [
          Expanded(
            child: SingleChildScrollView(
              padding: const EdgeInsets.all(24.0),
              child: _ContactInfoCard(contact: _contact),
            ),
          ),
          _CallButton(
            contact: _contact,
            onCallInitiated: () => setState(() => _callWasInitiated = true),
          ),
        ],
      ),
    );
  }
}

// ── Private sub-widgets ────────────────────────────────────────────────────

class _ContactInfoCard extends StatelessWidget {
  const _ContactInfoCard({required this.contact});

  final ContactModel contact;

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Center(
          child: CircleAvatar(
            radius: 48,
            backgroundColor: Colors.blue.shade100,
            child: Text(
              contact.name.isNotEmpty ? contact.name[0].toUpperCase() : '?',
              style: TextStyle(
                fontSize: 40,
                fontWeight: FontWeight.bold,
                color: Colors.blue.shade800,
              ),
            ),
          ),
        ),
        const SizedBox(height: 16),
        Center(
          child: Text(
            contact.name,
            style: const TextStyle(
              fontSize: 24,
              fontWeight: FontWeight.bold,
            ),
          ),
        ),
        if (contact.company != null) ...[
          const SizedBox(height: 4),
          Center(
            child: Text(
              contact.company!,
              style: const TextStyle(fontSize: 16, color: Colors.grey),
            ),
          ),
        ],
        const SizedBox(height: 32),
        _InfoRow(icon: Icons.phone, label: 'Phone', value: contact.phoneNumber ?? '—'),
        if (contact.email != null)
          _InfoRow(icon: Icons.email, label: 'Email', value: contact.email!),
        _InfoRow(
          icon: Icons.flag_rounded,
          label: 'Status',
          value: _statusLabel(contact.status.name),
        ),
        if (contact.notes != null && contact.notes!.isNotEmpty) ...[
          const SizedBox(height: 16),
          const Text(
            'Notes',
            style: TextStyle(fontWeight: FontWeight.bold, fontSize: 14),
          ),
          const SizedBox(height: 4),
          Text(contact.notes!, style: const TextStyle(color: Colors.grey)),
        ],
      ],
    );
  }

  String _statusLabel(String raw) {
    // Convert camelCase enum name to readable label.
    return raw
        .replaceAllMapped(RegExp(r'[A-Z]'), (m) => ' ${m.group(0)}')
        .trim()
        .replaceFirst(raw[0], raw[0].toUpperCase());
  }
}

class _InfoRow extends StatelessWidget {
  const _InfoRow({
    required this.icon,
    required this.label,
    required this.value,
  });

  final IconData icon;
  final String label;
  final String value;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 8),
      child: Row(
        children: [
          Icon(icon, size: 20, color: Colors.blue),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(label,
                    style: const TextStyle(
                        fontSize: 12, color: Colors.grey)),
                Text(value,
                    style: const TextStyle(fontSize: 16)),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

class _CallButton extends StatelessWidget {
  const _CallButton({
    required this.contact,
    required this.onCallInitiated,
  });

  final ContactModel contact;

  /// Callback invoked immediately after the call is initiated so the parent
  /// state can set `_callWasInitiated = true` and respond to lifecycle events.
  final VoidCallback onCallInitiated;

  @override
  Widget build(BuildContext context) {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.fromLTRB(24, 12, 24, 36),
      child: Consumer<PhoneCallProvider>(
        builder: (context, provider, child) {
          return ElevatedButton.icon(
            style: ElevatedButton.styleFrom(
              padding: const EdgeInsets.symmetric(vertical: 16),
              backgroundColor: Colors.green,
              foregroundColor: Colors.white,
              textStyle: const TextStyle(
                fontSize: 18,
                fontWeight: FontWeight.bold,
              ),
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(12),
              ),
            ),
            onPressed: provider.isLoading || contact.phoneNumber == null
                ? null
                : () => _handleCallPressed(context, provider),
            icon: provider.isLoading
                ? const SizedBox(
                    width: 20,
                    height: 20,
                    child: CircularProgressIndicator(
                      color: Colors.white,
                      strokeWidth: 2,
                    ),
                  )
                : const Icon(Icons.phone),
            label: Text(
              provider.isLoading ? 'Initiating Call...' : 'Call',
            ),
          );
        },
      ),
    );
  }

  Future<void> _handleCallPressed(
    BuildContext context,
    PhoneCallProvider provider,
  ) async {
    final phoneNumber = contact.phoneNumber!;
    final success = await provider.initiateCall(phoneNumber);

    if (!context.mounted) return;

    if (success) {
      // Notify parent that a call was launched so lifecycle events are handled.
      onCallInitiated();
    } else if (provider.errorMessage != null) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(provider.errorMessage!),
          backgroundColor: Colors.red,
          behavior: SnackBarBehavior.floating,
        ),
      );
    }

    if (success &&
        provider.lastCallResult == CallLaunchResult.fallbackDialerOpened) {
      if (!context.mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text(
            'Direct calling permission denied. Opened system dialer instead.',
          ),
          backgroundColor: Colors.orange,
          behavior: SnackBarBehavior.floating,
        ),
      );
    }
  }
}
