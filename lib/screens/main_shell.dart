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
  int _previousIndex = 0;

  final GlobalKey<TripsScreenState> _tripsKey = GlobalKey<TripsScreenState>();
  final GlobalKey<ProfileScreenState> _profileKey = GlobalKey<ProfileScreenState>();

  late final List<Widget> _screens;

  @override
  void initState() {
    super.initState();
    _screens = [
      const ExploreScreen(),
      TripsScreen(key: _tripsKey),
      const FeedScreen(),
      ProfileScreen(key: _profileKey),
    ];
  }

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
    _previousIndex = _currentIndex;
    setState(() {
      _currentIndex = index;
    });
    
    // Trigger refresh when tab is selected and was previously on a different tab
    if (_previousIndex != index) {
      switch (index) {
        case 1:
          _tripsKey.currentState?.refreshData();
          break;
        case 3:
          _profileKey.currentState?.refreshData();
          break;
      }
    }
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
