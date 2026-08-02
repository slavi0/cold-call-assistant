import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../models/contact_model.dart';
import '../models/contact_status.dart';
import '../providers/contact_provider.dart';
import '../../calls/providers/phone_call_provider.dart';
import '../../calls/providers/calling_sequence_provider.dart';
import '../../calls/services/phone_call_service.dart';

/// Displays a single contact's details, a Call button, and Prev/Next navigation.
///
/// **Route argument**: `String` — the contact's ID.
/// The actual [ContactModel] is always read from [ContactProvider.findById] so
/// that any edits made on [PostCallReviewScreen] are immediately visible here
/// without needing to reload or pass updated objects through route arguments.
///
/// **Two navigation contexts**:
/// - *Browsing mode*: user tapped a contact in the list.
///   - Previous/Next buttons navigate through the full contact list.
///   - After a call ends → opens [PostCallReviewScreen]; user stays in the
///     same browsing session afterwards.
/// - *Sequence mode*: user pressed "Start Calling".
///   - Previous/Next buttons still navigate through the full list.
///   - After a call ends → opens [PostCallReviewScreen] with sequence context;
///     "Next Contact" on that screen advances the sequence.
class ContactDetailScreen extends StatefulWidget {
  const ContactDetailScreen({super.key});

  @override
  State<ContactDetailScreen> createState() => _ContactDetailScreenState();
}

class _ContactDetailScreenState extends State<ContactDetailScreen>
    with WidgetsBindingObserver {
  late String _contactId;
  bool _initialized = false;
  bool _callWasInitiated = false;

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    if (!_initialized) {
      _contactId = ModalRoute.of(context)!.settings.arguments as String;
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
      // Reset telephony state first (clears loading/active flags).
      context.read<PhoneCallProvider>().handleAppResumed();
      // Defer navigation until after the first frame is rendered.
      //
      // Root cause of the black screen regression:
      // AppLifecycleState.resumed fires inside Android's onResume() — the
      // activity is transitioning into the foreground but FlutterTextureView
      // has not yet produced a single rendered frame in the resumed state.
      // Calling Navigator.pushNamed synchronously here starts a route-transition
      // animation while the rendering pipeline is still starting up, causing a
      // black screen even with RenderMode.texture + Impeller disabled.
      //
      // addPostFrameCallback guarantees the callback runs after the next frame
      // is fully rasterised, at which point the pipeline is stable and can
      // safely handle a route transition animation.
      WidgetsBinding.instance.addPostFrameCallback((_) {
        if (mounted) {
          _openPostCallReview();
        }
      });
    }
  }

  void _openPostCallReview() {
    final isSequence =
        context.read<CallingSequenceProvider>().isSequenceActive;
    Navigator.pushNamed(
      context,
      '/post-call-review',
      arguments: {
        'contactId': _contactId,
        'isSequenceMode': isSequence,
      },
    );
  }

  @override
  Widget build(BuildContext context) {
    // Watch the provider so this screen rebuilds whenever the contact is updated
    // (e.g. after returning from PostCallReviewScreen).
    final contact =
        context.watch<ContactProvider>().findById(_contactId);

    if (contact == null) {
      return const Scaffold(
        body: Center(child: Text('Contact not found.')),
      );
    }

    // Compute previous/next using the live contact list.
    final contacts = context.watch<ContactProvider>().contacts;
    final index = contacts.indexWhere((c) => c.id == _contactId);

    return Scaffold(
      appBar: AppBar(
        title: Text(contact.name),
        centerTitle: true,
        leading: IconButton(
          icon: const Icon(Icons.arrow_back),
          onPressed: () {
            // Cancel the sequence if the user explicitly backs out.
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
              child: _ContactInfoCard(contact: contact),
            ),
          ),
          // Previous / Next navigation row — always visible.
          _NavigationButtons(
            hasPrevious: index > 0,
            hasNext: index >= 0 && index < contacts.length - 1,
            onPrevious: index > 0
                ? () => Navigator.pushReplacementNamed(
                      context,
                      '/contact-detail',
                      arguments: contacts[index - 1].id,
                    )
                : null,
            onNext: index >= 0 && index < contacts.length - 1
                ? () => Navigator.pushReplacementNamed(
                      context,
                      '/contact-detail',
                      arguments: contacts[index + 1].id,
                    )
                : null,
          ),
          _CallButton(
            contact: contact,
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
        _InfoRow(
            icon: Icons.phone,
            label: 'Phone',
            value: contact.phoneNumber ?? '—'),
        if (contact.email != null)
          _InfoRow(
              icon: Icons.email, label: 'Email', value: contact.email!),
        _InfoRow(
          icon: Icons.flag_rounded,
          label: 'Status',
          // Use the displayLabel extension instead of raw camelCase.
          value: contact.status.displayLabel,
        ),
        if (contact.lastCalledAt != null)
          _InfoRow(
            icon: Icons.access_time_rounded,
            label: 'Last Called',
            value: _formatDate(contact.lastCalledAt!),
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

  String _formatDate(DateTime dt) {
    return '${dt.day.toString().padLeft(2, '0')}/'
        '${dt.month.toString().padLeft(2, '0')}/'
        '${dt.year}  '
        '${dt.hour.toString().padLeft(2, '0')}:'
        '${dt.minute.toString().padLeft(2, '0')}';
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
                    style: const TextStyle(fontSize: 12, color: Colors.grey)),
                Text(value, style: const TextStyle(fontSize: 16)),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

class _NavigationButtons extends StatelessWidget {
  const _NavigationButtons({
    required this.hasPrevious,
    required this.hasNext,
    required this.onPrevious,
    required this.onNext,
  });

  final bool hasPrevious;
  final bool hasNext;
  final VoidCallback? onPrevious;
  final VoidCallback? onNext;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.fromLTRB(16, 8, 16, 4),
      child: Row(
        children: [
          Expanded(
            child: OutlinedButton.icon(
              onPressed: onPrevious,
              icon: const Icon(Icons.chevron_left),
              label: const Text('Previous'),
            ),
          ),
          const SizedBox(width: 12),
          Expanded(
            child: OutlinedButton.icon(
              onPressed: onNext,
              icon: const Icon(Icons.chevron_right),
              iconAlignment: IconAlignment.end,
              label: const Text('Next'),
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
      padding: const EdgeInsets.fromLTRB(24, 8, 24, 36),
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
    final success = await provider.initiateCall(contact.phoneNumber!);

    if (!context.mounted) return;

    if (success) {
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
