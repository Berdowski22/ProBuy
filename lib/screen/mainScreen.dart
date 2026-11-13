import 'package:flutter/material.dart';

import '../models/cart_item.dart';
import '../services/cart_service.dart';
import 'cartScreen.dart';
import 'favoritesScreen.dart';
import 'homeScreen.dart';
import 'profileScreen.dart';

class MainScreen extends StatefulWidget {
  const MainScreen({super.key});

  @override
  State<MainScreen> createState() => _MainScreenState();
}

class _MainScreenState extends State<MainScreen> {
  int _selectedIndex = 0;
  final _cartService = CartService();

  late final List<Widget> _pages = [
    const Home(),
    const FavoritesScreen(),
    CartScreen(onGoToProfile: () => setState(() => _selectedIndex = 3)),
    const ProfileScreen(),
  ];

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: IndexedStack(index: _selectedIndex, children: _pages),
      bottomNavigationBar: NavigationBar(
        selectedIndex: _selectedIndex,
        onDestinationSelected: (index) {
          setState(() => _selectedIndex = index);
        },
        destinations: [
          const NavigationDestination(
            icon: Icon(Icons.home_outlined),
            selectedIcon: Icon(Icons.home),
            label: 'Ana Sayfa',
          ),
          const NavigationDestination(
            icon: Icon(Icons.favorite_border),
            selectedIcon: Icon(Icons.favorite),
            label: 'Favoriler',
          ),
          NavigationDestination(
            icon: _cartIcon(Icons.shopping_cart_outlined),
            selectedIcon: _cartIcon(Icons.shopping_cart),
            label: 'Sepet',
          ),
          const NavigationDestination(
            icon: Icon(Icons.person_outline),
            selectedIcon: Icon(Icons.person),
            label: 'Profil',
          ),
        ],
      ),
    );
  }

  Widget _cartIcon(IconData icon) {
    return StreamBuilder<List<CartItem>>(
      stream: _cartService.watchCart(),
      builder: (context, snapshot) {
        final count =
            (snapshot.data ?? []).fold<int>(0, (sum, i) => sum + i.quantity);
        return Badge(
          isLabelVisible: count > 0,
          label: Text('$count'),
          child: Icon(icon),
        );
      },
    );
  }
}
