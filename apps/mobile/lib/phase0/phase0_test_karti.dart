// FAZ 0 — SİMÜLASYON KARTI ve GÜNLÜK KARTI.
//
// NEDEN AYRI DOSYA: `phase0_screen.dart` 663 satıra çıkmıştı (500 satır kuralı). Bu iki kart
// ekranın "elle deneme" tarafıdır: test numarası seçilir, sahte bir çağrı üretilir ve sonuç
// günlüğe düşer. Gerçek çağrı ölçümüyle aynı yüzeyi paylaşırlar ama farklı bir soruyu
// cevaplarlar — "sistem ayakta mı?" (deneme) ile "sahada ne kadar sürüyor?" (ölçüm).
//
// NEDEN `part`: gerekçe `phase0_kartlar.dart` başlığında.

part of 'phase0_screen.dart';
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
        const SnackBar(content: Text('Numarayı 05xx xxx xx xx biçiminde girin')),
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
                          ? context.sip.danger
                          : (late ? context.sip.warn : context.sip.ok),
                    ),
                    const SizedBox(width: 8),
                    Expanded(
                      child: Text(
                        m.shown ? '${m.ms} ms, ${m.path}' : 'gösterilemedi, ${m.path}',
                        style: Theme.of(context).textTheme.bodyMedium,
                      ),
                    ),
                    if (m.simulated)
                      Text('simüle',
                          style: TextStyle(fontSize: 11, color: context.sip.warn)),
                    if (m.direction == 'out')
                      Text('giden',
                          style: TextStyle(fontSize: 11, color: context.sip.accent)),
                    if (m.locked)
                      Text(' kilitli',
                          style: TextStyle(fontSize: 11, color: context.sip.ink2)),
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
