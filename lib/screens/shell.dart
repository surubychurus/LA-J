import 'package:flutter/material.dart';
import 'package:lucide_icons_flutter/lucide_icons.dart';
import 'package:provider/provider.dart';

import '../services/app_state.dart';
import '../services/updater.dart';
import 'chat_screen.dart';
import 'home_screen.dart';
import 'news_screen.dart';
import 'photos_screen.dart';
import 'profile_screen.dart';

class Shell extends StatefulWidget {
  const Shell({super.key});
  @override
  State<Shell> createState() => _ShellState();
}

class _ShellState extends State<Shell> {
  int _i = 0;

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) => Updater.checkAndPrompt(context));
  }

  @override
  Widget build(BuildContext context) {
    final u = context.watch<AppState>().user!;
    final pages = [
      HomeScreen(user: u),
      PhotosScreen(user: u),
      ChatScreen(user: u),
      NewsScreen(user: u),
      ProfileScreen(user: u),
    ];
    return Scaffold(
      body: SafeArea(
        child: AnimatedSwitcher(
          duration: const Duration(milliseconds: 220),
          child: KeyedSubtree(key: ValueKey(_i), child: pages[_i]),
        ),
      ),
      bottomNavigationBar: NavigationBar(
        selectedIndex: _i,
        onDestinationSelected: (i) => setState(() => _i = i),
        labelBehavior: NavigationDestinationLabelBehavior.alwaysShow,
        destinations: const [
          NavigationDestination(icon: Icon(LucideIcons.house), selectedIcon: Icon(LucideIcons.house), label: 'Inicio'),
          NavigationDestination(icon: Icon(LucideIcons.image), selectedIcon: Icon(LucideIcons.image), label: 'Fotos'),
          NavigationDestination(icon: Icon(LucideIcons.messageCircle), selectedIcon: Icon(LucideIcons.messageCircle), label: 'Chat'),
          NavigationDestination(icon: Icon(LucideIcons.megaphone), selectedIcon: Icon(LucideIcons.megaphone), label: 'Novedades'),
          NavigationDestination(icon: Icon(LucideIcons.user), selectedIcon: Icon(LucideIcons.user), label: 'Yo'),
        ],
      ),
    );
  }
}
