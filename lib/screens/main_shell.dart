import 'package:flutter/material.dart';
import 'package:larga/screens/explore_screen.dart';
import 'package:larga/screens/trips_screen.dart';
import 'package:larga/screens/feed_screen.dart';
import 'package:larga/screens/profile_screen.dart';

class MainShell extends StatefulWidget {
  const MainShell({super.key});

  @override
  State<MainShell> createState() => _MainShellState();
}

class _MainShellState extends State<MainShell> {
  int _currentIndex = 0;

  final List<Widget> _screens = [
    const ExploreScreen(),
    const TripsScreen(),
    const FeedScreen(),
    const ProfileScreen(),
  ];

  final List<NavigationDestination> _destinations = const [
    NavigationDestination(
      icon: Icon(Icons.explore_outlined),
      selectedIcon: Icon(Icons.explore),
      label: 'Explore',
    ),
    NavigationDestination(
      icon: Icon(Icons.luggage_outlined),
      selectedIcon: Icon(Icons.luggage),
      label: 'Trips',
    ),
    NavigationDestination(
      icon: Icon(Icons.feed_outlined),
      selectedIcon: Icon(Icons.feed),
      label: 'Feed',
    ),
    NavigationDestination(
      icon: Icon(Icons.person_outline),
      selectedIcon: Icon(Icons.person),
      label: 'Profile',
    ),
  ];

  void _onDestinationSelected(int index) {
    setState(() {
      _currentIndex = index;
    });
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: IndexedStack(
        index: _currentIndex,
        children: _screens,
      ),
      bottomNavigationBar: NavigationBar(
        selectedIndex: _currentIndex,
        onDestinationSelected: _onDestinationSelected,
        destinations: _destinations,
        labelBehavior: NavigationDestinationLabelBehavior.alwaysShow,
      ),
    );
  }
}
