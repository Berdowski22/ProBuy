import 'package:flutter/material.dart';

import '../services/auth_service.dart';
import 'authScreen.dart';

class ProfileScreen extends StatelessWidget {
  const ProfileScreen({super.key});

  @override
  Widget build(BuildContext context) {
    final authService = AuthService();
    final user = authService.currentUser;

    return Scaffold(
      appBar: AppBar(title: const Text('Profil')),
      body: Center(
        child: Padding(
          padding: const EdgeInsets.all(24),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              const CircleAvatar(radius: 40, child: Icon(Icons.person, size: 40)),
              const SizedBox(height: 16),
              Text(
                user?.displayName ?? 'Kullanıcı',
                style: Theme.of(context).textTheme.titleLarge,
              ),
              const SizedBox(height: 4),
              Text(user?.email ?? ''),
              const SizedBox(height: 32),
              FilledButton.icon(
                icon: const Icon(Icons.logout),
                label: const Text('Çıkış Yap'),
                onPressed: () async {
                  final navigator = Navigator.of(context);
                  await authService.logout();
                  navigator.pushAndRemoveUntil(
                    MaterialPageRoute(builder: (_) => const AuthScreen()),
                    (_) => false,
                  );
                },
              ),
            ],
          ),
        ),
      ),
    );
  }
}
