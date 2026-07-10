import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

/// İlk açılış kurulum sihirbazı.
///
/// Korku #3: bayi kuramazsa satış ölür — kurulum→ilk tanıma 10 dakikanın altında
/// kalmalı. Bu sihirbaz gerekli izinleri TEK TEK, sırayla ve gerekçesiyle ister.
///
/// Sıra bilinçli: MIUI'de "Tam ekran bildirimleri" anahtarı, "Arka planda yeni
/// pencere açma" izni verilmeden AÇILAMIYOR (cihazda doğrulandı) — bu yüzden
/// MIUI "Diğer izinler" adımı, tam ekran adımından ÖNCE gelir.
class SetupWizardScreen extends StatefulWidget {
  const SetupWizardScreen({super.key, required this.channel});

  final MethodChannel channel;

  @override
  State<SetupWizardScreen> createState() => _SetupWizardScreenState();
}

class _WizardStep {
  const _WizardStep({
    required this.icon,
    required this.title,
    required this.description,
    required this.actionMethod,
    required this.actionLabel,
    this.statusKey,
    this.checklist = const [],
  });

  final IconData icon;
  final String title;
  final String description;

  /// Yerelden okunabilen izinlerde status anahtarı; null ise durum okunamıyor
  /// (MIUI izinleri, pil) ve kullanıcı "Tamamladım" ile onaylar.
  final String? statusKey;
  final String actionMethod;
  final String actionLabel;
  final List<String> checklist;

  bool isDone(Map<String, dynamic> status) =>
      statusKey != null && status[statusKey] == true;
}

class _SetupWizardScreenState extends State<SetupWizardScreen>
    with WidgetsBindingObserver {
  Map<String, dynamic> _status = const {};
  List<String> _batterySteps = const [];
  int _index = 0;

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addObserver(this);
    _refresh();
  }

  @override
  void dispose() {
    WidgetsBinding.instance.removeObserver(this);
    super.dispose();
  }

  /// İzin ekranından dönüldüğünde durumu tazele; verilen izin adımı
  /// kendiliğinden tamamlanmış gösterilsin.
  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    if (state == AppLifecycleState.resumed) _refresh();
  }

  Future<void> _refresh() async {
    final status =
        await widget.channel.invokeMapMethod<String, dynamic>('status') ?? {};
    final battery =
        await widget.channel.invokeListMethod<String>('batteryGuide') ?? const [];
    if (!mounted) return;
    setState(() {
      _status = status;
      _batterySteps = battery;
    });
  }

  bool get _isMiui {
    final man = (_status['manufacturer'] as String? ?? '').toLowerCase();
    return man == 'xiaomi' || man == 'redmi' || man == 'poco';
  }

  List<_WizardStep> get _steps {
    final sdk = _status['sdkInt'] as int? ?? 0;
    return [
      const _WizardStep(
        icon: Icons.notifications_active_outlined,
        title: 'Bildirimler',
        description:
            'Telefon kilitliyken arayan müşterinin bilgisi bildirimle taşınır. '
            'Bu izin olmadan kilitli ekranda hiçbir şey gösteremeyiz.',
        statusKey: 'hasNotificationPermission',
        actionMethod: 'requestNotificationPermission',
        actionLabel: 'İzin ver',
      ),
      const _WizardStep(
        icon: Icons.phone_callback_outlined,
        title: 'Çağrı tarama',
        description:
            'Telefon çaldığında arayan numarayı görmemizi sağlayan sistem rolü. '
            'Uygulamanın varlık sebebi bu — vermezseniz arayan tanıma çalışmaz.',
        statusKey: 'hasScreeningRole',
        actionMethod: 'requestScreeningRole',
        actionLabel: 'Rolü ver',
      ),
      const _WizardStep(
        icon: Icons.contacts_outlined,
        title: 'Rehber erişimi',
        description:
            'Telefon rehberinize kayıtlı müşteriler aradığında da kartın çıkması '
            'için gerekli. Android, bu izin olmadan rehberdeki numaralarda bizi '
            'hiç uyandırmıyor. Rehberiniz hiçbir yere gönderilmez.',
        statusKey: 'hasContactsPermission',
        actionMethod: 'requestContactsPermission',
        actionLabel: 'İzin ver',
      ),
      const _WizardStep(
        icon: Icons.picture_in_picture_alt_outlined,
        title: 'Üstte gösterme',
        description:
            'Müşteri kartı, telefon uygulamasının üstünde küçük bir pencere '
            'olarak çıkar. Açılan listede Sipario\'yu bulup izni açın, sonra '
            'geri dönün.',
        statusKey: 'canDrawOverlays',
        actionMethod: 'requestOverlayPermission',
        actionLabel: 'Ayarı aç',
      ),
      if (_isMiui)
        const _WizardStep(
          icon: Icons.lock_open_outlined,
          title: 'Xiaomi özel izinleri',
          description:
              'Xiaomi telefonlarda iki izin daha gerekiyor. Açılan ekranda '
              'şunları AÇIK konuma getirin:',
          statusKey: null,
          actionMethod: 'openOtherPermissions',
          actionLabel: 'Ayarları aç',
          checklist: [
            'Kilit ekranında görüntüle: AÇIK',
            'Arka planda çalışırken yeni pencereler açın: AÇIK',
          ],
        ),
      if (sdk >= 34)
        const _WizardStep(
          icon: Icons.fullscreen_outlined,
          title: 'Kilit ekranında göster',
          description:
              'Telefon kilitliyken kartın tam ekran çıkabilmesi için. Açılan '
              'ekranda anahtarı AÇIK konuma getirin, sonra geri dönün.',
          statusKey: 'canUseFullScreenIntent',
          actionMethod: 'requestFullScreenIntent',
          actionLabel: 'Ayarı aç',
        ),
      _WizardStep(
        icon: Icons.battery_saver_outlined,
        title: 'Pil ayarları',
        description:
            'Telefon, pili korumak için uygulamayı arka planda kapatabilir — '
            'o zaman arama geldiğinde kart çıkmaz. Açılan ekranda şu adımları '
            'yapın:',
        statusKey: null,
        actionMethod: 'openBatterySettings',
        actionLabel: 'Ayarları aç',
        checklist: _batterySteps,
      ),
    ];
  }

  Future<void> _runAction(_WizardStep step) async {
    await widget.channel.invokeMethod(step.actionMethod);
    await _refresh();
  }

  void _next() {
    final steps = _steps;
    if (_index < steps.length - 1) {
      setState(() => _index++);
    } else {
      Navigator.of(context).pop(true);
    }
  }

  @override
  Widget build(BuildContext context) {
    final steps = _steps;
    if (_index >= steps.length) {
      // İzin durumu değişince adım listesi kısalmış olabilir.
      _index = steps.length - 1;
    }
    final step = steps[_index];
    final done = step.isDone(_status);
    final manualStep = step.statusKey == null;

    return Scaffold(
      body: SafeArea(
        child: Padding(
          padding: const EdgeInsets.all(24),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                children: [
                  Text('Kurulum',
                      style: Theme.of(context).textTheme.titleLarge),
                  const Spacer(),
                  Text('${_index + 1} / ${steps.length}',
                      style: Theme.of(context).textTheme.labelLarge),
                ],
              ),
              const SizedBox(height: 8),
              LinearProgressIndicator(value: (_index + 1) / steps.length),
              const SizedBox(height: 40),
              Icon(step.icon,
                  size: 56, color: Theme.of(context).colorScheme.primary),
              const SizedBox(height: 20),
              Text(step.title, style: Theme.of(context).textTheme.headlineSmall),
              const SizedBox(height: 12),
              Text(step.description,
                  style: Theme.of(context).textTheme.bodyLarge),
              if (step.checklist.isNotEmpty) ...[
                const SizedBox(height: 12),
                ...step.checklist.map(
                  (item) => Padding(
                    padding: const EdgeInsets.symmetric(vertical: 3),
                    child: Row(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        const Icon(Icons.check_box_outline_blank, size: 18),
                        const SizedBox(width: 8),
                        Expanded(child: Text(item)),
                      ],
                    ),
                  ),
                ),
              ],
              const Spacer(),
              if (done)
                Row(
                  children: [
                    const Icon(Icons.check_circle, color: Color(0xFF4ECB71)),
                    const SizedBox(width: 8),
                    Text('Tamamlandı',
                        style: Theme.of(context)
                            .textTheme
                            .bodyLarge
                            ?.copyWith(color: const Color(0xFF4ECB71))),
                  ],
                ),
              const SizedBox(height: 12),
              SizedBox(
                width: double.infinity,
                child: FilledButton(
                  onPressed: done ? _next : () => _runAction(step),
                  child: Text(done ? 'Devam et' : step.actionLabel),
                ),
              ),
              if (!done && manualStep) ...[
                const SizedBox(height: 8),
                SizedBox(
                  width: double.infinity,
                  child: OutlinedButton(
                    onPressed: _next,
                    child: const Text('Tamamladım, devam et'),
                  ),
                ),
              ],
              if (!done && !manualStep) ...[
                const SizedBox(height: 8),
                SizedBox(
                  width: double.infinity,
                  child: TextButton(
                    onPressed: _next,
                    child: const Text('Şimdilik atla'),
                  ),
                ),
              ],
            ],
          ),
        ),
      ),
    );
  }
}
