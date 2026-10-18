import 'package:firebase_core/firebase_core.dart';
import 'package:flutter/material.dart';
import 'package:intl/date_symbol_data_local.dart';
import 'package:provider/provider.dart';

import 'firebase_options.dart';
import 'screens/auth_screens.dart';
import 'screens/shell.dart';
import 'services/app_state.dart';
import 'theme.dart';

Future<void> main() async {
  WidgetsFlutterBinding.ensureInitialized();
  await initializeDateFormatting('es');
  await Firebase.initializeApp(options: DefaultFirebaseOptions.currentPlatform);
  runApp(ChangeNotifierProvider(create: (_) => AppState(), child: const App()));
}

class App extends StatelessWidget {
  const App({super.key});

  @override
  Widget build(BuildContext context) {
    final s = context.watch<AppState>();
    return MaterialApp(
      title: '2214',
      debugShowCheckedModeBanner: false,
      theme: buildTheme(Brightness.light),
      darkTheme: buildTheme(Brightness.dark),
      themeMode: s.themeMode,
      home: switch (s.status) {
        AuthStatus.loading => const Scaffold(body: Center(child: CircularProgressIndicator())),
        AuthStatus.signedOut => const LoginScreen(),
        AuthStatus.ready =>
          s.user == null || !s.user!.aprobado ? const PendingScreen() : const Shell(),
      },
    );
  }
}
