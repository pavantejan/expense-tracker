import 'package:flutter/material.dart';

import '../features/automate/automate_page.dart';
import '../features/dashboard/dashboard_page.dart';
import '../features/manage/manage_page.dart';
import '../features/track/track_page.dart';
import '../features/understand/understand_page.dart';

/// The five primary destinations (blueprint section 12.1). Each tab
/// keeps its own navigation stack and scroll state.
class HomeShell extends StatefulWidget {
  const HomeShell({super.key});

  @override
  State<HomeShell> createState() => _HomeShellState();
}

class _HomeShellState extends State<HomeShell> {
  int _index = 0;
  final _navigatorKeys = List.generate(5, (_) => GlobalKey<NavigatorState>());

  static const _pages = <Widget>[
    DashboardPage(),
    TrackPage(),
    ManagePage(),
    UnderstandPage(),
    AutomatePage(),
  ];

  void _select(int index) {
    if (index == _index) {
      // Re-tapping a tab returns to its landing page.
      _navigatorKeys[index].currentState?.popUntil((r) => r.isFirst);
      return;
    }
    setState(() => _index = index);
  }

  @override
  Widget build(BuildContext context) {
    return PopScope(
      canPop: false,
      onPopInvokedWithResult: (didPop, _) {
        if (didPop) {
          return;
        }
        final navigator = _navigatorKeys[_index].currentState;
        if (navigator != null && navigator.canPop()) {
          navigator.pop();
        } else if (_index != 0) {
          setState(() => _index = 0);
        } else {
          Navigator.of(context).maybePop();
        }
      },
      child: Scaffold(
        body: IndexedStack(
          index: _index,
          children: [
            for (var i = 0; i < _pages.length; i++)
              Navigator(
                key: _navigatorKeys[i],
                onGenerateRoute: (_) =>
                    MaterialPageRoute<void>(builder: (_) => _pages[i]),
              ),
          ],
        ),
        bottomNavigationBar: NavigationBar(
          selectedIndex: _index,
          onDestinationSelected: _select,
          destinations: const [
            NavigationDestination(
              icon: Icon(Icons.home_outlined),
              selectedIcon: Icon(Icons.home_rounded),
              label: 'Home',
            ),
            NavigationDestination(
              icon: Icon(Icons.receipt_long_outlined),
              selectedIcon: Icon(Icons.receipt_long_rounded),
              label: 'Track',
            ),
            NavigationDestination(
              icon: Icon(Icons.account_balance_wallet_outlined),
              selectedIcon: Icon(Icons.account_balance_wallet_rounded),
              label: 'Manage',
            ),
            NavigationDestination(
              icon: Icon(Icons.insights_outlined),
              selectedIcon: Icon(Icons.insights_rounded),
              label: 'Understand',
            ),
            NavigationDestination(
              icon: Icon(Icons.autorenew_outlined),
              selectedIcon: Icon(Icons.autorenew_rounded),
              label: 'Automate',
            ),
          ],
        ),
      ),
    );
  }
}
