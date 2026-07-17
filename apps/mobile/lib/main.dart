import 'package:flutter/material.dart';

import 'auth/session.dart';
import 'data/app_database.dart';
import 'screens/home_shell.dart';
import 'screens/login_screen.dart';
import 'sync/sync_service.dart';

void main() {
  WidgetsFlutterBinding.ensureInitialized();
  final db = AppDatabase.file();
  runApp(SiparioApp(db: db));
}

/// Kök: oturum varsa ana kabuk, yoksa giriş. Faz 0 ölçüm ekranı üründe KALIR (DECISIONS —
/// pilottaki gerçek aramalar sayacı dolduracak); Menü sekmesinden erişilir.
class SiparioApp extends StatefulWidget {
  const SiparioApp({super.key, required this.db});

  final AppDatabase db;

  @override
  State<SiparioApp> createState() => _SiparioAppState();
}

class _SiparioAppState extends State<SiparioApp> {
  late final Session _session = Session(widget.db);
  late final SyncService _sync = SyncService(widget.db);
  bool? _loggedIn; // null = açılış kontrolü sürüyor

  @override
  void initState() {
    super.initState();
    _session.isLoggedIn().then((v) async {
      if (v) await _startSync();
      if (mounted) setState(() => _loggedIn = v);
    });
  }

  Future<void> _startSync() async {
    await _sync.configure();
    _sync.start();
  }

  @override
  void dispose() {
    _sync.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      title: 'Sipario',
      debugShowCheckedModeBanner: false,
      theme: ThemeData(
        colorScheme: ColorScheme.fromSeed(
          seedColor: const Color(0xFF2F6BFF),
          brightness: Brightness.dark,
        ),
        useMaterial3: true,
      ),
      home: switch (_loggedIn) {
        null => const Scaffold(body: Center(child: CircularProgressIndicator())),
        false => LoginScreen(
            session: _session,
            onLoggedIn: () async {
              await _startSync();
              if (mounted) setState(() => _loggedIn = true);
            },
          ),
        true => HomeShell(
            db: widget.db,
            session: _session,
            sync: _sync,
            onLoggedOut: () {
              _sync.stop();
              if (mounted) setState(() => _loggedIn = false);
            },
          ),
      },
    );
  }
}
