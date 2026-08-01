import 'package:flutter/material.dart';

/// The application's entry-point screen.
///
/// Acts as a simple launcher: shows the app identity and the single action
/// that starts the cold-calling workflow (navigating to the contact list).
class HomeScreen extends StatelessWidget {
  const HomeScreen({super.key});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Cold Call Assistant'),
        centerTitle: true,
      ),
      body: Center(
        child: Padding(
          padding: const EdgeInsets.all(32.0),
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              const Icon(
                Icons.contact_phone_rounded,
                size: 96,
                color: Colors.blue,
              ),
              const SizedBox(height: 24),
              const Text(
                'Cold Call Assistant',
                style: TextStyle(
                  fontSize: 26,
                  fontWeight: FontWeight.bold,
                ),
              ),
              const SizedBox(height: 8),
              const Text(
                'Manage and call your prospects\none after another.',
                textAlign: TextAlign.center,
                style: TextStyle(
                  fontSize: 15,
                  color: Colors.grey,
                ),
              ),
              const SizedBox(height: 48),
              ElevatedButton.icon(
                style: ElevatedButton.styleFrom(
                  padding: const EdgeInsets.symmetric(
                    horizontal: 32,
                    vertical: 16,
                  ),
                  backgroundColor: Colors.blue,
                  foregroundColor: Colors.white,
                  textStyle: const TextStyle(
                    fontSize: 18,
                    fontWeight: FontWeight.bold,
                  ),
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(30),
                  ),
                ),
                onPressed: () => Navigator.pushNamed(context, '/contacts'),
                icon: const Icon(Icons.people_alt_rounded),
                label: const Text('View Contacts'),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
