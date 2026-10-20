import 'package:flutter/material.dart';

import '../session.dart';
import '../theme.dart';
import 'login_screen.dart';

class AccountScreen extends StatelessWidget {
  const AccountScreen({super.key});

  @override
  Widget build(BuildContext context) {
    return ListenableBuilder(
      listenable: session,
      builder: (context, _) {
        final loggedIn = session.token != null;
        final role = session.role ?? 'guest';
        return ListView(
          padding: const EdgeInsets.all(20),
          children: [
            Text('Account', style: display(30)),
            const SizedBox(height: 16),
            if (!loggedIn) ...[
              const Text('Log in to reserve rooms and see your bookings.', style: TextStyle(color: C.soft, fontSize: 15)),
              const SizedBox(height: 16),
              FilledButton(
                onPressed: () => Navigator.of(context).push(MaterialPageRoute(builder: (_) => const LoginScreen())),
                child: const Text('Log in'),
              ),
              const SizedBox(height: 10),
              OutlinedButton(
                onPressed: () => Navigator.of(context).push(MaterialPageRoute(builder: (_) => const LoginScreen(startOnSignUp: true))),
                child: const Text('Create an account'),
              ),
            ] else ...[
              Container(
                padding: const EdgeInsets.all(14),
                decoration: BoxDecoration(color: Colors.white, border: Border.all(color: C.line), borderRadius: BorderRadius.circular(8)),
                child: Row(children: [
                  const Icon(Icons.person, color: C.green),
                  const SizedBox(width: 10),
                  Text(role == 'guest' ? 'Guest account' : (role == 'owner' ? 'Owner account' : 'Admin account'), style: const TextStyle(fontWeight: FontWeight.w700)),
                ]),
              ),
              if (role != 'guest')
                Padding(
                  padding: const EdgeInsets.only(top: 12),
                  child: FilledButton.icon(
                    onPressed: () => tabIndex.value = 3,
                    icon: const Icon(Icons.storefront),
                    label: const Text('Manage your properties'),
                  ),
                ),
              const SizedBox(height: 16),
              OutlinedButton(onPressed: () => session.logout(), child: const Text('Log out')),
            ],
          ],
        );
      },
    );
  }
}
