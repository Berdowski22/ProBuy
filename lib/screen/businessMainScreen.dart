import 'package:flutter/material.dart';

import '../services/auth_service.dart';
import '../widgets/confirm_dialog.dart';
import 'authScreen.dart';
import 'businessOrdersScreen.dart';
import 'businessProductsScreen.dart';

class BusinessMainScreen extends StatefulWidget {
  const BusinessMainScreen({super.key});

  @override
  State<BusinessMainScreen> createState() => _BusinessMainScreenState();
}

class _BusinessMainScreenState extends State<BusinessMainScreen> {
  int _index = 0;

  static const _pages = [
    BusinessProductsScreen(),
    BusinessOrdersScreen(),
    _BusinessAccountScreen(),
  ];

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: IndexedStack(index: _index, children: _pages),
      bottomNavigationBar: NavigationBar(
        selectedIndex: _index,
        onDestinationSelected: (i) => setState(() => _index = i),
        destinations: const [
          NavigationDestination(
            icon: Icon(Icons.inventory_2_outlined),
            selectedIcon: Icon(Icons.inventory_2),
            label: 'Ürünler',
          ),
          NavigationDestination(
            icon: Icon(Icons.receipt_long_outlined),
            selectedIcon: Icon(Icons.receipt_long),
            label: 'Siparişler',
          ),
          NavigationDestination(
            icon: Icon(Icons.storefront_outlined),
            selectedIcon: Icon(Icons.storefront),
            label: 'Hesap',
          ),
        ],
      ),
    );
  }
}

class _BusinessAccountScreen extends StatelessWidget {
  const _BusinessAccountScreen();

  Future<void> _logout(BuildContext context) async {
    final navigator = Navigator.of(context);
    final ok = await confirmAction(
      context,
      title: 'Çıkış yap',
      message: 'Hesabınızdan çıkış yapmak istediğinizden emin misiniz?',
      confirmText: 'Çıkış Yap',
      icon: Icons.logout,
    );
    if (!ok) return;
    await AuthService().logout();
    navigator.pushAndRemoveUntil(
      MaterialPageRoute(builder: (_) => const AuthScreen()),
      (_) => false,
    );
  }

  @override
  Widget build(BuildContext context) {
    final user = AuthService().currentUser;
    return Scaffold(
      appBar: AppBar(title: const Text('İşletme Hesabı')),
      body: Padding(
        padding: const EdgeInsets.all(24),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            const Center(
              child: CircleAvatar(
                radius: 40,
                child: Icon(Icons.storefront, size: 40),
              ),
            ),
            const SizedBox(height: 16),
            Text(
              user?.displayName ?? 'İşletme',
              textAlign: TextAlign.center,
              style: Theme.of(context).textTheme.titleLarge,
            ),
            Text(user?.email ?? '', textAlign: TextAlign.center),
            const SizedBox(height: 24),
            OutlinedButton.icon(
              icon: const Icon(Icons.logout),
              label: const Text('Çıkış Yap'),
              onPressed: () => _logout(context),
            ),
          ],
        ),
      ),
    );
  }
}
