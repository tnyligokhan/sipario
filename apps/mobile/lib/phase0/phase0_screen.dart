import 'package:drift/drift.dart' hide Column;
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

import '../data/app_database.dart';
import '../repo/customer_repository.dart';
import '../screens/customers/customer_form_screen.dart' show normalizePhoneTR;
import '../theme/tokens.dart';
import 'measurements.dart';
import 'setup_wizard.dart';

// EKRAN ÜÇE BÖLÜNDÜ (2026-08-17, 500 satır kuralı — 663 satırdı): ölçümün kendisi burada,
// çizilen kartlar iki parça dosyada. Kartlar ekranın özel parçaları olduğu için `part`tır.
part 'phase0_kartlar.dart';
part 'phase0_test_karti.dart';

/// Faz 0 kanıt ekranı. Tek işi var: gerçek bir cihazda, gerçek çağrılarla,
/// arayan tanımanın çalıştığını (veya çalışmadığını) rakamla göstermek.
///
/// SAHA BULGUSU (2026-07-22): Bu ekran eskiden sipario.db'yi sqflite `version: 1` ile açıyordu —
/// bu, Drift'in v7 sürüm damgasını 1'e EZİYOR ve bir sonraki açılışta migration'ın yeniden koşup
/// "duplicate column" ile uygulamayı kilitlemesine yol açıyordu (iki gerçek cihazda yaşandı).
/// Ayrıca spike tohum verisi üretim DB'sini kirletiyordu. Artık ürünün KENDİ AppDatabase'ini
/// kullanır: test müşterisi CustomerRepository ile eklenir (outbox → senkrona da girer).
class Phase0Screen extends StatefulWidget {
  const Phase0Screen({super.key, required this.db});

  final AppDatabase db;

  @override
  State<Phase0Screen> createState() => _Phase0ScreenState();
}

class _Phase0ScreenState extends State<Phase0Screen> with WidgetsBindingObserver {
  static const _channel = MethodChannel('sipario/phase0');

  Map<String, dynamic> _status = const {};
  List<String> _batterySteps = const [];
  List<Measurement> _measurements = const [];
  List<Map<String, Object?>> _phones = const [];
  String? _error;
  bool _wizardShown = false;

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addObserver(this);
    _bootstrap();
  }

  @override
  void dispose() {
    WidgetsBinding.instance.removeObserver(this);
    super.dispose();
  }

  /// Kullanıcı izin ekranından döndüğünde durumu tazele — yoksa "verdim ama
  /// görünmüyor" hissi doğuyor ve kurulum sürtünmesi (korku #3) artıyor.
  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    if (state == AppLifecycleState.resumed) _refresh();
  }

  Future<void> _bootstrap() async {
    try {
      _phones = await loadTestPhones(widget.db);
      await _refresh();
    } on PlatformException catch (e) {
      setState(() => _error = 'Platform hatası: ${e.message}');
    } catch (e) {
      setState(() => _error = 'Veritabanı hatası: $e');
    }
  }

  Future<void> _refresh() async {
    final status = await _channel.invokeMapMethod<String, dynamic>('status') ?? {};
    final steps = await _channel.invokeListMethod<String>('batteryGuide') ?? const [];
    final raw = await _channel.invokeMethod<String>('measurements') ?? '[]';
    if (!mounted) return;
    setState(() {
      _status = status;
      _batterySteps = steps;
      _measurements = Measurement.parse(raw);
    });
    _maybeOpenWizard();
  }

  /// Okunabilir izinlerden herhangi biri eksikse ilk açılışta sihirbaz açılır.
  /// Sıfır kurulumda bayinin göreceği ilk şey izin listesi değil, sıralı akıştır.
  void _maybeOpenWizard() {
    if (_wizardShown || _status.isEmpty) return;
    final needsSetup = _status['hasScreeningRole'] != true ||
        _status['canDrawOverlays'] != true ||
        _status['hasContactsPermission'] != true ||
        _status['hasNotificationPermission'] != true;
    if (!needsSetup) return;
    _wizardShown = true;
    WidgetsBinding.instance.addPostFrameCallback((_) async {
      if (!mounted) return;
      await Navigator.of(context).push(
        MaterialPageRoute(
          builder: (_) => SetupWizardScreen(channel: _channel),
          fullscreenDialog: true,
        ),
      );
      await _refresh();
    });
  }

  Future<void> _call(String method, [Map<String, dynamic>? args]) async {
    await _channel.invokeMethod(method, args);
    await _refresh();
  }

  /// Saha ölçümünde arayacak telefonu rehbere ekler; yoksa her arama
  /// "kayıtlı olmayan numara" kartı çıkarır ve eşleşme yolu hiç sınanmaz.
  /// GERÇEK müşteri kaydı açılır (CustomerRepository → outbox → senkron) — ürünle aynı yol.
  Future<void> _addPhone(String name, String phone) async {
    final normalized = normalizePhoneTR(phone);
    if (normalized == null) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Geçersiz telefon numarası')),
      );
      return;
    }
    await CustomerRepository(widget.db)
        .create(name: name, phones: [PhoneInput(phoneE164: normalized, isPrimary: true)]);
    _phones = await loadTestPhones(widget.db);
    if (!mounted) return;
    setState(() {});
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(content: Text('$name rehbere eklendi ($normalized)')),
    );
  }

  @override
  Widget build(BuildContext context) {
    final verdict = Verdict(_measurements);
    final hasRole = _status['hasScreeningRole'] == true;
    final canOverlay = _status['canDrawOverlays'] == true;

    return Scaffold(
      appBar: AppBar(
        title: const Text('Sipario Faz 0'),
        actions: [
          IconButton(
            onPressed: () async {
              await Navigator.of(context).push(
                MaterialPageRoute(
                  builder: (_) => SetupWizardScreen(channel: _channel),
                  fullscreenDialog: true,
                ),
              );
              await _refresh();
            },
            icon: const Icon(Icons.auto_fix_high),
            tooltip: 'Kurulum sihirbazı',
          ),
          IconButton(
            onPressed: _refresh,
            icon: const Icon(Icons.refresh),
            tooltip: 'Yenile',
          ),
        ],
      ),
      body: _error != null
          ? Center(child: Padding(padding: const EdgeInsets.all(24), child: Text(_error!)))
          : ListView(
              padding: const EdgeInsets.all(16),
              children: [
                _VerdictCard(verdict: verdict),
                const SizedBox(height: 16),
                _DeviceCard(status: _status),
                const SizedBox(height: 16),
                _SetupCard(
                  hasRole: hasRole,
                  canOverlay: canOverlay,
                  hasContacts: _status['hasContactsPermission'] == true,
                  canFullScreen: _status['canUseFullScreenIntent'] == true,
                  batterySteps: _batterySteps,
                  onRequestRole: () => _call('requestScreeningRole'),
                  onRequestOverlay: () => _call('requestOverlayPermission'),
                  onRequestContacts: () => _call('requestContactsPermission'),
                  onRequestFullScreen: () => _call('requestFullScreenIntent'),
                  onOpenBattery: () => _call('openBatterySettings'),
                ),
                const SizedBox(height: 16),
                _TestCard(
                  phones: _phones,
                  onSimulate: (phone) => _call('simulateCall', {'phone': phone}),
                  onClear: () => _call('clearMeasurements'),
                  onAddPhone: _addPhone,
                ),
                const SizedBox(height: 16),
                _LogCard(measurements: _measurements),
              ],
            ),
    );
  }
}

