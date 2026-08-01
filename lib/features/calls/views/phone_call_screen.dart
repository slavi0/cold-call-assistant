import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../providers/phone_call_provider.dart';
import '../services/phone_call_service.dart';

/// Screen displaying the phone call initiation interface.
///
/// Registers [WidgetsBindingObserver] to monitor app lifecycle events (`resumed`)
/// so the screen automatically refreshes state when returning from a phone call.
class PhoneCallScreen extends StatefulWidget {
  const PhoneCallScreen({super.key});

  static const String targetPhoneNumber = '+33177455329';

  @override
  State<PhoneCallScreen> createState() => _PhoneCallScreenState();
}

class _PhoneCallScreenState extends State<PhoneCallScreen>
    with WidgetsBindingObserver {
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
    if (state == AppLifecycleState.resumed) {
      // Delegate lifecycle resumption to provider per MVVM rules
      context.read<PhoneCallProvider>().handleAppResumed();
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Cold Call Assistant'),
        centerTitle: true,
      ),
      body: Center(
        child: Padding(
          padding: const EdgeInsets.all(24.0),
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              const Icon(
                Icons.contact_phone_rounded,
                size: 80,
                color: Colors.blue,
              ),
              const SizedBox(height: 24),
              const Text(
                'Target Contact',
                style: TextStyle(
                  fontSize: 16,
                  color: Colors.grey,
                  fontWeight: FontWeight.w500,
                ),
              ),
              const SizedBox(height: 8),
              const Text(
                PhoneCallScreen.targetPhoneNumber,
                style: TextStyle(
                  fontSize: 28,
                  fontWeight: FontWeight.bold,
                  letterSpacing: 1.2,
                ),
              ),
              const SizedBox(height: 40),
              Consumer<PhoneCallProvider>(
                builder: (context, provider, child) {
                  return ElevatedButton.icon(
                    style: ElevatedButton.styleFrom(
                      padding: const EdgeInsets.symmetric(
                        horizontal: 32,
                        vertical: 16,
                      ),
                      backgroundColor: Colors.green,
                      foregroundColor: Colors.white,
                      textStyle: const TextStyle(
                        fontSize: 18,
                        fontWeight: FontWeight.bold,
                      ),
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(30),
                      ),
                    ),
                    onPressed: provider.isLoading
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
                      provider.isLoading ? 'Initiating Call...' : 'Call Now',
                    ),
                  );
                },
              ),
            ],
          ),
        ),
      ),
    );
  }

  Future<void> _handleCallPressed(
    BuildContext context,
    PhoneCallProvider provider,
  ) async {
    final success = await provider.initiateCall(PhoneCallScreen.targetPhoneNumber);

    if (!context.mounted) return;

    if (!success && provider.errorMessage != null) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(provider.errorMessage!),
          backgroundColor: Colors.red,
          behavior: SnackBarBehavior.floating,
        ),
      );
    } else if (success &&
        provider.lastCallResult == CallLaunchResult.fallbackDialerOpened) {
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
