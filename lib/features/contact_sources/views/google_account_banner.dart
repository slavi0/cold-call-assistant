import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../providers/contact_source_provider.dart';

/// Shows the currently signed-in Google account, or a Sign In button.
///
/// Placed at the top of [ContactSourcesScreen] and [GoogleSheetsConfigScreen]
/// to give the user constant visibility of their auth state without duplicating
/// sign-in UI logic in both screens.
class GoogleAccountBanner extends StatelessWidget {
  const GoogleAccountBanner({super.key});

  @override
  Widget build(BuildContext context) {
    return Consumer<ContactSourceProvider>(
      builder: (context, provider, _) {
        final signedIn = provider.isSignedInToGoogle;

        return AnimatedContainer(
          duration: const Duration(milliseconds: 200),
          margin: const EdgeInsets.only(bottom: 16),
          padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
          decoration: BoxDecoration(
            color: signedIn
                ? Colors.green.shade50
                : Theme.of(context)
                    .colorScheme
                    .surfaceContainerHighest
                    .withValues(alpha: 0.5),
            borderRadius: BorderRadius.circular(12),
            border: Border.all(
              color: signedIn ? Colors.green.shade200 : Colors.grey.shade300,
            ),
          ),
          child: Row(
            children: [
              Icon(
                signedIn
                    ? Icons.check_circle_rounded
                    : Icons.account_circle_rounded,
                size: 20,
                color:
                    signedIn ? Colors.green.shade700 : Colors.grey.shade500,
              ),
              const SizedBox(width: 10),
              Expanded(
                child: Text(
                  signedIn
                      ? provider.googleAccountEmail ?? 'Signed in'
                      : 'Not signed in to Google',
                  style: TextStyle(
                    fontSize: 13,
                    color: signedIn
                        ? Colors.green.shade800
                        : Colors.grey.shade600,
                  ),
                  overflow: TextOverflow.ellipsis,
                ),
              ),
              const SizedBox(width: 8),
              if (provider.isSigningIn)
                const SizedBox(
                  width: 18,
                  height: 18,
                  child: CircularProgressIndicator(strokeWidth: 2),
                )
              else if (signedIn)
                TextButton(
                  onPressed: () =>
                      context.read<ContactSourceProvider>().signOutFromGoogle(),
                  style: TextButton.styleFrom(
                    foregroundColor: Colors.grey.shade600,
                    padding: const EdgeInsets.symmetric(horizontal: 8),
                    minimumSize: const Size(0, 32),
                    tapTargetSize: MaterialTapTargetSize.shrinkWrap,
                  ),
                  child: const Text('Sign out', style: TextStyle(fontSize: 12)),
                )
              else
                TextButton(
                  onPressed: () =>
                      context.read<ContactSourceProvider>().signInToGoogle(),
                  style: TextButton.styleFrom(
                    foregroundColor: Colors.green.shade700,
                    padding: const EdgeInsets.symmetric(horizontal: 8),
                    minimumSize: const Size(0, 32),
                    tapTargetSize: MaterialTapTargetSize.shrinkWrap,
                  ),
                  child: const Text('Sign in', style: TextStyle(fontSize: 12)),
                ),
            ],
          ),
        );
      },
    );
  }
}
