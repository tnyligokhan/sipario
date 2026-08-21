// FAZ 0 ÖLÇÜM EKRANININ KARTLARI — hüküm kartı · istatistik · cihaz · kurulum adımları.
//
// NEDEN AYRI DOSYA: `phase0_screen.dart` 663 satıra çıkmıştı (500 satır kuralı). Buradaki
// widget'ların hiçbiri ölçüm YAPMAZ: verilen sayıları çizerler. Ölçümün kendisi (dinleyici,
// zamanlayıcı, kayıt) ekranın durumunda kalır.
//
// ⚠️ HÜKÜM KARTI KIRMIZI ÇİZGİYİ OKUR: "1 sn altında mı?" sorusunun cevabı BRIEF'in 1 numaralı
// korkusudur (Faz 0'ın şartlı GO kaydı). Eşik burada uydurulmaz, `measurements.dart`tan gelir.
//
// NEDEN `part`: kartlar ekranın ÖZEL parçalarıdır ve dışarıdan kullanılmazlar; ayrı kütüphane
// yapmak hepsini herkese açmayı gerektirirdi (aynı desen: `home_shell.dart`).

part of 'phase0_screen.dart';
class _VerdictCard extends StatelessWidget {
  const _VerdictCard({required this.verdict});
  final Verdict verdict;

  @override
  Widget build(BuildContext context) {
    final t = context.sip;
    final color = !verdict.enoughSamples
        ? t.muted
        : (verdict.pass ? t.ok : t.danger);

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
                '${verdict.simulated.length} simüle çağrı sayıma dahil değil. '
                'Süreç zaten ayakta olduğu için asıl maliyeti ölçmez.',
                style: Theme.of(context)
                    .textTheme
                    .bodySmall
                    ?.copyWith(color: context.sip.warn),
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
                color: danger ? context.sip.danger : null,
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
              subtitle: 'Numaranın izin almadan okunmasını sağlar. Zorunlu.',
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
                  'çıkması için zorunlu. İzin yoksa Android o aramalarda uygulamayı hiç uyandırmaz.',
              action: 'İzin ver',
              onTap: onRequestContacts,
            ),
            _Step(
              done: canFullScreen,
              title: 'Kilit ekranında göster',
              subtitle: 'Telefon kilitliyken kart ancak bu izinle çıkar. Sahada telefon çoğu zaman '
                  'kilitli olduğu için bu izin gerekir.',
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
              color: done ? context.sip.ok : context.sip.muted,
              size: 20,
            )
          else
            Icon(Icons.info_outline, color: context.sip.warn, size: 20),
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

