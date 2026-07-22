import 'package:drift/drift.dart' hide Column;
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

import '../data/app_database.dart';
import '../repo/customer_repository.dart';
import '../screens/customers/customer_form_screen.dart' show normalizePhoneTR;
import 'measurements.dart';
import 'setup_wizard.dart';

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
        title: const Text('Sipario · Faz 0'),
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

class _VerdictCard extends StatelessWidget {
  const _VerdictCard({required this.verdict});
  final Verdict verdict;

  @override
  Widget build(BuildContext context) {
    final color = !verdict.enoughSamples
        ? Colors.blueGrey
        : (verdict.pass ? const Color(0xFF4ECB71) : const Color(0xFFFF6B6B));

    return Card(
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                Icon(Icons.circle, color: color, size: 14),
                const SizedBox(width: 8),
                Text(
                  verdict.label,
                  style: Theme.of(context).textTheme.titleLarge?.copyWith(
                        color: color,
                        fontWeight: FontWeight.bold,
                      ),
                ),
              ],
            ),
            const SizedBox(height: 12),
            Text(
              'Hedef: ${Verdict.requiredCalls} gerçek aramada kart ekranda, '
              'her biri ≤${Verdict.targetMs} ms.',
              style: Theme.of(context).textTheme.bodySmall,
            ),
            const SizedBox(height: 12),
            Wrap(
              spacing: 20,
              runSpacing: 10,
              children: [
                _Stat('Gerçek arama', '${verdict.total}'),
                _Stat('Kaçırılan', '${verdict.missed}',
                    danger: verdict.missed > 0),
                _Stat('Hedef içinde', '${verdict.withinTarget}/${verdict.total}'),
                _Stat('Medyan', verdict.median == null ? '—' : '${verdict.median} ms'),
                _Stat('p95', verdict.p95 == null ? '—' : '${verdict.p95} ms'),
                _Stat('En kötü', verdict.worst == null ? '—' : '${verdict.worst} ms',
                    danger: (verdict.worst ?? 0) > Verdict.targetMs),
                _Stat(
                  'Kilitli ekran',
                  '${verdict.lockedShown}/${verdict.lockedCalls.length}'
                      ' (en az ${Verdict.requiredLockedCalls})',
                  danger: verdict.lockedMissed > 0,
                ),
                _Stat('Overlay / TamEkran / Bildirim',
                    '${verdict.viaOverlay} / ${verdict.viaFullScreen} / ${verdict.viaNotification}'),
                _Stat('Giden arama', '${verdict.outgoing.length} (sayım dışı)'),
              ],
            ),
            if (verdict.simulated.isNotEmpty) ...[
              const SizedBox(height: 10),
              Text(
                '${verdict.simulated.length} simüle çağrı sayıma dahil değil — '
                'süreç zaten ayakta olduğu için asıl maliyeti ölçmez.',
                style: Theme.of(context).textTheme.bodySmall?.copyWith(color: Colors.orange),
              ),
            ],
          ],
        ),
      ),
    );
  }
}

class _Stat extends StatelessWidget {
  const _Stat(this.label, this.value, {this.danger = false});
  final String label;
  final String value;
  final bool danger;

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      mainAxisSize: MainAxisSize.min,
      children: [
        Text(label, style: Theme.of(context).textTheme.labelSmall),
        Text(
          value,
          style: Theme.of(context).textTheme.titleMedium?.copyWith(
                color: danger ? const Color(0xFFFF6B6B) : null,
                fontWeight: FontWeight.w600,
              ),
        ),
      ],
    );
  }
}

class _DeviceCard extends StatelessWidget {
  const _DeviceCard({required this.status});
  final Map<String, dynamic> status;

  @override
  Widget build(BuildContext context) {
    return Card(
      child: ListTile(
        leading: const Icon(Icons.smartphone),
        title: Text('${status['manufacturer'] ?? '?'} ${status['model'] ?? ''}'.trim()),
        subtitle: Text('Android API ${status['sdkInt'] ?? '?'}'),
      ),
    );
  }
}

class _SetupCard extends StatelessWidget {
  const _SetupCard({
    required this.hasRole,
    required this.canOverlay,
    required this.hasContacts,
    required this.canFullScreen,
    required this.batterySteps,
    required this.onRequestRole,
    required this.onRequestOverlay,
    required this.onRequestContacts,
    required this.onRequestFullScreen,
    required this.onOpenBattery,
  });

  final bool hasRole;
  final bool canOverlay;
  final bool hasContacts;
  final bool canFullScreen;
  final List<String> batterySteps;
  final VoidCallback onRequestRole;
  final VoidCallback onRequestOverlay;
  final VoidCallback onRequestContacts;
  final VoidCallback onRequestFullScreen;
  final VoidCallback onOpenBattery;

  @override
  Widget build(BuildContext context) {
    return Card(
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text('Kurulum', style: Theme.of(context).textTheme.titleMedium),
            const SizedBox(height: 4),
            Text(
              'Bu dört adım kurulum sihirbazının taslağıdır; sahada 10 dakikanın '
              'altında bitmesi gerekiyor.',
              style: Theme.of(context).textTheme.bodySmall,
            ),
            const SizedBox(height: 12),
            _Step(
              done: hasRole,
              title: 'Çağrı tarama rolü',
              subtitle: 'Numarayı izin almadan görmemizi sağlar. Zorunlu.',
              action: 'Rolü iste',
              onTap: onRequestRole,
            ),
            _Step(
              done: canOverlay,
              title: 'Diğer uygulamaların üzerinde göster',
              subtitle: 'Kart çağrı ekranının üstüne çizilir. Yoksa bildirime düşer.',
              action: 'İzin ver',
              onTap: onRequestOverlay,
            ),
            _Step(
              done: hasContacts,
              title: 'Rehber erişimi',
              subtitle: 'Telefon rehberinize kayıtlı müşteriler aradığında da kartın '
                  'çıkması için zorunlu. İzin yoksa Android o aramalarda bizi hiç uyandırmaz.',
              action: 'İzin ver',
              onTap: onRequestContacts,
            ),
            _Step(
              done: canFullScreen,
              title: 'Kilit ekranında göster',
              subtitle: 'Telefon kilitliyken kart ancak bu izinle çıkar. Yoksa yalnız '
                  'bildirim görünür — sahada telefon çoğu zaman kilitlidir.',
              action: 'İzin ver',
              onTap: onRequestFullScreen,
            ),
            _Step(
              done: false,
              showCheck: false,
              title: 'Pil / otomatik başlatma',
              subtitle: batterySteps.join('\n'),
              action: 'Ayarları aç',
              onTap: onOpenBattery,
            ),
          ],
        ),
      ),
    );
  }
}

class _Step extends StatelessWidget {
  const _Step({
    required this.done,
    required this.title,
    required this.subtitle,
    required this.action,
    required this.onTap,
    this.showCheck = true,
  });

  final bool done;
  final bool showCheck;
  final String title;
  final String subtitle;
  final String action;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 6),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          if (showCheck)
            Icon(
              done ? Icons.check_circle : Icons.radio_button_unchecked,
              color: done ? const Color(0xFF4ECB71) : Colors.grey,
              size: 20,
            )
          else
            const Icon(Icons.info_outline, color: Colors.amber, size: 20),
          const SizedBox(width: 10),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(title, style: Theme.of(context).textTheme.bodyLarge),
                Text(subtitle, style: Theme.of(context).textTheme.bodySmall),
              ],
            ),
          ),
          if (!done) TextButton(onPressed: onTap, child: Text(action)),
        ],
      ),
    );
  }
}

class _TestCard extends StatefulWidget {
  const _TestCard({
    required this.phones,
    required this.onSimulate,
    required this.onClear,
    required this.onAddPhone,
  });

  final List<Map<String, Object?>> phones;
  final void Function(String phone) onSimulate;
  final VoidCallback onClear;
  final Future<void> Function(String name, String phone) onAddPhone;

  @override
  State<_TestCard> createState() => _TestCardState();
}

class _TestCardState extends State<_TestCard> {
  final _name = TextEditingController(text: 'Test Müşterisi');
  final _phone = TextEditingController();

  @override
  void dispose() {
    _name.dispose();
    _phone.dispose();
    super.dispose();
  }

  Future<void> _submit() async {
    final phone = _phone.text.trim();
    if (normalizePhoneTR(phone) == null) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Geçersiz numara — 05xx xxx xx xx biçiminde girin')),
      );
      return;
    }
    await widget.onAddPhone(_name.text.trim().isEmpty ? 'Test Müşterisi' : _name.text.trim(), phone);
    _phone.clear();
  }

  @override
  Widget build(BuildContext context) {
    return Card(
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text('Test rehberi', style: Theme.of(context).textTheme.titleMedium),
            const SizedBox(height: 4),
            Text(
              'Asıl ölçüm, ARAYACAĞINIZ telefonun numarası buraya eklendikten sonra '
              'gerçek aramayla alınır. Aşağıdaki "Simüle et" düğmeleri yalnız çizim '
              'yolunu denetler, ölçüme girmez.',
              style: Theme.of(context).textTheme.bodySmall,
            ),
            const SizedBox(height: 12),
            Row(
              crossAxisAlignment: CrossAxisAlignment.end,
              children: [
                Expanded(
                  flex: 2,
                  child: TextField(
                    controller: _name,
                    decoration: const InputDecoration(labelText: 'Ad', isDense: true),
                  ),
                ),
                const SizedBox(width: 8),
                Expanded(
                  flex: 3,
                  child: TextField(
                    controller: _phone,
                    keyboardType: TextInputType.phone,
                    decoration: const InputDecoration(
                      labelText: 'Arayacak numara',
                      hintText: '05xx xxx xx xx',
                      isDense: true,
                    ),
                    onSubmitted: (_) => _submit(),
                  ),
                ),
                const SizedBox(width: 8),
                FilledButton(onPressed: _submit, child: const Text('Ekle')),
              ],
            ),
            const SizedBox(height: 10),
            ...widget.phones.map(
              (row) => ListTile(
                dense: true,
                contentPadding: EdgeInsets.zero,
                title: Text(row['name'] as String),
                subtitle: Text(row['phone_e164'] as String),
                trailing: TextButton(
                  onPressed: () => widget.onSimulate(row['phone_e164'] as String),
                  child: const Text('Simüle et'),
                ),
              ),
            ),
            ListTile(
              dense: true,
              contentPadding: EdgeInsets.zero,
              title: const Text('Kayıtlı olmayan numara'),
              subtitle: const Text('+905000000000'),
              trailing: TextButton(
                onPressed: () => widget.onSimulate('+905000000000'),
                child: const Text('Simüle et'),
              ),
            ),
            const Divider(),
            Align(
              alignment: Alignment.centerRight,
              child: TextButton.icon(
                onPressed: widget.onClear,
                icon: const Icon(Icons.delete_outline),
                label: const Text('Ölçümleri sıfırla'),
              ),
            ),
          ],
        ),
      ),
    );
  }
}

/// Test rehberi listesi: arşivsiz müşteriler + telefonları (ada göre). Ekrandan bağımsız
/// fonksiyon — saf async testle sınanır (Dilim 1 deseni). UI eski LocalDb.allPhones satır
/// biçimini bekler: {'name', 'phone_e164'}.
Future<List<Map<String, Object?>>> loadTestPhones(AppDatabase db) async {
  final rows = await (db.select(db.customerPhones).join([
    innerJoin(db.customers, db.customers.id.equalsExp(db.customerPhones.customerId)),
  ])
        ..where(db.customers.deletedAt.isNull() & db.customerPhones.deletedAt.isNull())
        ..orderBy([OrderingTerm.asc(db.customers.name)]))
      .get();
  return [
    for (final r in rows)
      {
        'name': r.readTable(db.customers).name,
        'phone_e164': r.readTable(db.customerPhones).phoneE164,
      },
  ];
}

class _LogCard extends StatelessWidget {
  const _LogCard({required this.measurements});
  final List<Measurement> measurements;

  @override
  Widget build(BuildContext context) {
    if (measurements.isEmpty) {
      return const Card(
        child: Padding(
          padding: EdgeInsets.all(16),
          child: Text('Henüz ölçüm yok. Cihazı başka bir telefondan arayın.'),
        ),
      );
    }

    final recent = measurements.reversed.take(25).toList();
    return Card(
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text('Son ölçümler', style: Theme.of(context).textTheme.titleMedium),
            const SizedBox(height: 8),
            ...recent.map((m) {
              final late = m.shown && m.ms > Verdict.targetMs;
              return Padding(
                padding: const EdgeInsets.symmetric(vertical: 3),
                child: Row(
                  children: [
                    Icon(
                      !m.shown
                          ? Icons.error
                          : (late ? Icons.warning_amber : Icons.check),
                      size: 16,
                      color: !m.shown
                          ? const Color(0xFFFF6B6B)
                          : (late ? Colors.amber : const Color(0xFF4ECB71)),
                    ),
                    const SizedBox(width: 8),
                    Expanded(
                      child: Text(
                        m.shown ? '${m.ms} ms · ${m.path}' : 'gösterilemedi · ${m.path}',
                        style: Theme.of(context).textTheme.bodyMedium,
                      ),
                    ),
                    if (m.simulated)
                      const Text('simüle', style: TextStyle(fontSize: 11, color: Colors.orange)),
                    if (m.direction == 'out')
                      const Text('giden', style: TextStyle(fontSize: 11, color: Colors.lightBlueAccent)),
                    if (m.locked)
                      const Text(' kilitli', style: TextStyle(fontSize: 11, color: Colors.purpleAccent)),
                    const SizedBox(width: 8),
                    Text(
                      m.matched ? 'eşleşti' : 'yeni',
                      style: Theme.of(context).textTheme.labelSmall,
                    ),
                  ],
                ),
              );
            }),
          ],
        ),
      ),
    );
  }
}
