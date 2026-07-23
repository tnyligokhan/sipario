import 'package:flutter/material.dart';

import 'auth/session.dart';
import 'data/app_database.dart';
import 'screens/home_shell.dart';
import 'screens/login_screen.dart';
import 'sync/sync_service.dart';
import 'theme/app_theme.dart';

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

  String? _startupError;

  @override
  void initState() {
    super.initState();
    // Açılış hatası SPINNER'DA BIRAKMAZ (2026-07-22 saha bulgusu: migration hatası isLoggedIn'i
    // hiç döndürmeyince iki cihaz sonsuz loading'de kaldı). Hata ekrana çıkar — sessiz kilit yok.
    _session.isLoggedIn().then((v) async {
      if (v) await _startSync();
      if (mounted) setState(() => _loggedIn = v);
    }).catchError((Object e) {
      if (mounted) setState(() => _startupError = e.toString());
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
      theme: SipTheme.dark(),
      home: switch (_loggedIn) {
        null when _startupError != null => Scaffold(
            body: Center(
              child: Padding(
                padding: const EdgeInsets.all(24),
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    const Icon(Icons.error_outline, size: 40),
                    const SizedBox(height: 12),
                    const Text('Uygulama açılamadı. Lütfen destek ile iletişime geçin.',
                        textAlign: TextAlign.center),
                    const SizedBox(height: 8),
                    Text(_startupError!,
                        style: const TextStyle(fontSize: 11), textAlign: TextAlign.center),
                  ],
                ),
              ),
            ),
          ),
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
