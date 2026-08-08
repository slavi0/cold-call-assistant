import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../models/contact_model.dart';
import '../models/contact_status.dart';
import '../providers/contact_provider.dart';
import '../../calls/providers/phone_call_provider.dart';
import '../../calls/providers/calling_sequence_provider.dart';
import '../../calls/services/phone_call_service.dart';
import '../../../core/utils/phone_normalizer.dart';

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
///   - After a call ends → opens [PostCallReviewScreen].
/// - *Sequence mode*: user pressed "Start Calling".
///   - After a call ends → opens [PostCallReviewScreen] with sequence context;
///     "Next Contact" on that screen advances the sequence.
///
/// **Return-from-call flow (overlay button)**:
/// When the user taps the floating overlay button after a call, the native side
/// calls back into Flutter via the MethodChannel. [PhoneCallProvider] sets
/// [PhoneCallProvider.pendingReviewContactId]. This screen's [addListener]
/// subscription detects the signal and schedules navigation via
/// [addPostFrameCallback], replacing the old [WidgetsBindingObserver] approach.
class ContactDetailScreen extends StatefulWidget {
  const ContactDetailScreen({super.key});

  @override
  State<ContactDetailScreen> createState() => _ContactDetailScreenState();
}

class _ContactDetailScreenState extends State<ContactDetailScreen> {
  late String _contactId;
  bool _initialized = false;

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    if (!_initialized) {
      _contactId = ModalRoute.of(context)!.settings.arguments as String;
      _initialized = true;

      final provider = context.read<PhoneCallProvider>();

      // Subscribe to overlay button tap notifications.
      // When [PhoneCallProvider.pendingReviewContactId] matches this screen's
      // contact, we navigate to PostCallReviewScreen.
      provider.addListener(_onPhoneCallProviderChanged);

      // Eagerly check the overlay permission so the banner renders correctly
      // without a visible flash.
      provider.refreshOverlayPermission();
    }
  }

  @override
  void dispose() {
    // Remove the listener to avoid callbacks on a disposed State.
    context.read<PhoneCallProvider>().removeListener(_onPhoneCallProviderChanged);
    super.dispose();
  }

  // ── Overlay button tap handler ─────────────────────────────────────────

  void _onPhoneCallProviderChanged() {
    final provider = context.read<PhoneCallProvider>();

    // Only act when the pending navigation belongs to this screen's contact.
    if (provider.pendingReviewContactId != _contactId) return;
    if (!mounted) return;

    // Consume the signal immediately to prevent double-navigation if the
    // listener fires more than once before the frame is rendered.
    provider.clearPendingReview();

    // Schedule navigation after the current frame to avoid calling
    // setState/Navigator inside a build cycle.
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (mounted) _openPostCallReview();
    });
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

  // ── Build ──────────────────────────────────────────────────────────────

  @override
  Widget build(BuildContext context) {
    // Watch the provider so this screen rebuilds whenever the contact is
    // updated (e.g. after returning from PostCallReviewScreen).
    final contact = context.watch<ContactProvider>().findById(_contactId);

    if (contact == null) {
      return const Scaffold(
        body: Center(child: Text('Contact not found.')),
      );
    }

    // Compute previous/next using the live contact list.
    final contacts = context.watch<ContactProvider>().contacts;
    final index = contacts.indexWhere((c) => c.id == _contactId);

    final isSequence =
        context.watch<CallingSequenceProvider>().isSequenceActive;
    final phoneProvider = context.watch<PhoneCallProvider>();

    return Scaffold(
      appBar: AppBar(
        title: Text(contact.name),
        centerTitle: true,
        leading: IconButton(
          icon: const Icon(Icons.arrow_back),
          onPressed: () {
            // Cancel the sequence and dismiss the overlay if the user backs out.
            context.read<CallingSequenceProvider>().cancelSequence();
            context.read<PhoneCallProvider>().dismissOverlay();
            Navigator.pop(context);
          },
        ),
      ),
      body: Column(
        children: [
          // Show the overlay permission banner only during an active sequence
          // and only if the SYSTEM_ALERT_WINDOW permission is not yet granted.
          // The banner is non-blocking — the user can dismiss it and continue
          // calling; they will just need to return to the app manually.
          if (isSequence && !phoneProvider.overlayPermissionGranted)
            _OverlayPermissionBanner(
              onAllow: () => phoneProvider.requestOverlayPermission(),
            ),
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
          _CallButton(contact: contact),
        ],
      ),
    );
  }
}

// ── Private sub-widgets ────────────────────────────────────────────────────

/// Amber banner shown at the top of the screen when the overlay permission
/// has not been granted. Non-blocking — the user can ignore it.
class _OverlayPermissionBanner extends StatelessWidget {
  const _OverlayPermissionBanner({required this.onAllow});

  final VoidCallback onAllow;

  @override
  Widget build(BuildContext context) {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
      color: Colors.amber.shade100,
      child: Row(
        children: [
          const Icon(Icons.info_outline, size: 18, color: Colors.amber),
          const SizedBox(width: 8),
          const Expanded(
            child: Text(
              'Allow "Display over other apps" to show the Return button '
              'above the dialer.',
              style: TextStyle(fontSize: 12),
            ),
          ),
          TextButton(
            onPressed: onAllow,
            child: const Text('Allow'),
          ),
        ],
      ),
    );
  }
}

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
        _InfoRow(
            icon: Icons.public_rounded,
            label: 'Country',
            value: PhoneNormalizer.getCountryName(contact.phoneCountry)),
        if (contact.email != null)
          _InfoRow(
              icon: Icons.email, label: 'Email', value: contact.email!),
        _InfoRow(
          icon: Icons.flag_rounded,
          label: 'Status',
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
  const _CallButton({required this.contact});

  final ContactModel contact;

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
    // Pass contact.id so the overlay service knows which review screen to open.
    final success = await provider.initiateCall(
      contact.phoneNumber!,
      contact.id,
    );

    if (!context.mounted) return;

    if (!success && provider.errorMessage != null) {
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
