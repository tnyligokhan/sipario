import 'package:flutter/material.dart';

import '../data/app_database.dart';
import '../repo/day_end_repository.dart';
import 'money.dart';

/// DİLİM 3 — GÜN SONU ekranı (Menü → Gün sonu). TAMAMEN SALT-OKUNUR: hiçbir yazma yok, yalnız
/// DayEndRepository read-model'ini gösterir (kasa özeti · veresiye toplamı · kupon durumu).
/// Gün sınırı SABİT +03:00 (TR); localDate bugünün TR takvim günüdür (cihaz saat dilimi ne olursa olsun).

/// Bugünün TR takvim günü (00:00). Cihaz UTC/yerel farkından bağımsız — DayEndRepository +03:00 offset'iyle
/// tutarlı (occurred_at +3s kaydırılıp gün karşılaştırılır).
DateTime bugunTr({DateTime? now}) {
  final tr = (now ?? DateTime.now()).toUtc().add(const Duration(hours: 3));
  return DateTime(tr.year, tr.month, tr.day);
}

/// Gün sonu özetini tek çağrıda toplar (ekrandan AYRI — saf async testle sınanır). Üç read-model
/// (kasa/borç/kupon) tek değer nesnesinde birleşir; defterle tutarlılık burada doğrulanır.
Future<GunSonuOzet> gunSonuOzeti(AppDatabase db, DateTime localDate) async {
  final repo = DayEndRepository(db);
  final kasa = await repo.kasaOzeti(localDate);
  final borc = await repo.borcDurumu();
  final kupon = await repo.kuponDurumu(localDate);
  return GunSonuOzet(kasa: kasa, borc: borc, kupon: kupon);
}

class GunSonuOzet {
  GunSonuOzet({required this.kasa, required this.borc, required this.kupon});
  final KasaOzeti kasa;
  final BorcDurumu borc;
  final KuponDurumu kupon;
}

class DayEndScreen extends StatelessWidget {
  const DayEndScreen({super.key, required this.db});

  final AppDatabase db;

  @override
  Widget build(BuildContext context) {
    final gun = bugunTr();
    return Scaffold(
      appBar: AppBar(
        title: const Text('Gün sonu'),
        bottom: PreferredSize(
          preferredSize: const Size.fromHeight(20),
          child: Padding(
            padding: const EdgeInsets.only(bottom: 8),
            child: Text('${_ikiHane(gun.day)}.${_ikiHane(gun.month)}.${gun.year}',
                style: Theme.of(context).textTheme.bodySmall),
          ),
        ),
      ),
      body: FutureBuilder<GunSonuOzet>(
        future: gunSonuOzeti(db, gun),
        builder: (context, snap) {
          if (!snap.hasData) return const Center(child: CircularProgressIndicator());
          final o = snap.data!;
          return ListView(
            padding: const EdgeInsets.all(16),
            children: [
              _KasaKarti(kasa: o.kasa),
              const SizedBox(height: 12),
              _BorcKarti(borc: o.borc),
              const SizedBox(height: 12),
              _KuponKarti(kupon: o.kupon),
              const SizedBox(height: 24),
              Center(
                child: Text('Salt-okunur özet — defterden türetilir.',
                    style: Theme.of(context).textTheme.bodySmall),
              ),
            ],
          );
        },
      ),
    );
  }
}

class _KasaKarti extends StatelessWidget {
  const _KasaKarti({required this.kasa});
  final KasaOzeti kasa;

  @override
  Widget build(BuildContext context) {
    return _Kart(
      baslik: 'Kasa (bugün)',
      ikon: Icons.point_of_sale_outlined,
      children: [
        _Satir(etiket: 'Nakit', deger: formatKurus(kasa.nakit)),
        _Satir(etiket: 'Kart', deger: formatKurus(kasa.kart)),
        _Satir(etiket: 'Havale', deger: formatKurus(kasa.havale)),
        const Divider(),
        _Satir(etiket: 'Toplam', deger: formatKurus(kasa.toplam), vurgu: true),
      ],
    );
  }
}

class _BorcKarti extends StatelessWidget {
  const _BorcKarti({required this.borc});
  final BorcDurumu borc;

  @override
  Widget build(BuildContext context) {
    return _Kart(
      baslik: 'Veresiye (açık borç)',
      ikon: Icons.menu_book_outlined,
      children: [
        _Satir(
            etiket: 'Toplam açık borç',
            deger: formatKurus(borc.toplamAcikBorc),
            vurgu: true,
            renk: borc.toplamAcikBorc > 0 ? Theme.of(context).colorScheme.error : null),
        if (borc.borclular.isEmpty)
          const Padding(padding: EdgeInsets.only(top: 8), child: Text('Açık borç yok.'))
        else ...[
          const Divider(),
          for (final b in borc.borclular)
            _Satir(etiket: b.name, deger: formatKurus(b.balanceKurus)),
        ],
      ],
    );
  }
}

class _KuponKarti extends StatelessWidget {
  const _KuponKarti({required this.kupon});
  final KuponDurumu kupon;

  @override
  Widget build(BuildContext context) {
    return _Kart(
      baslik: 'Kupon',
      ikon: Icons.confirmation_number_outlined,
      children: [
        _Satir(etiket: 'Açık kupon (toplam)', deger: '${kupon.toplamAcikKupon} adet', vurgu: true),
        _Satir(etiket: 'Bugün verilen', deger: '${kupon.gunlukVerilen} adet'),
        _Satir(etiket: 'Bugün kullanılan', deger: '${kupon.gunlukKullanilan} adet'),
        if (kupon.eksiBakiyeliler.isNotEmpty) ...[
          const Divider(),
          Padding(
            padding: const EdgeInsets.only(bottom: 4),
            child: Text('Eksi bakiye (düzeltme bekliyor)',
                style: Theme.of(context)
                    .textTheme
                    .bodySmall
                    ?.copyWith(color: Theme.of(context).colorScheme.error)),
          ),
          for (final e in kupon.eksiBakiyeliler)
            _Satir(
              etiket: e.productId.isEmpty ? 'Genel kupon' : 'Ürün kuponu',
              deger: '${e.balanceQty} adet',
              renk: Theme.of(context).colorScheme.error,
            ),
        ],
      ],
    );
  }
}

class _Kart extends StatelessWidget {
  const _Kart({required this.baslik, required this.ikon, required this.children});
  final String baslik;
  final IconData ikon;
  final List<Widget> children;

  @override
  Widget build(BuildContext context) {
    return Card(
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                Icon(ikon, size: 20),
                const SizedBox(width: 8),
                Text(baslik, style: Theme.of(context).textTheme.titleMedium),
              ],
            ),
            const SizedBox(height: 8),
            ...children,
          ],
        ),
      ),
    );
  }
}

class _Satir extends StatelessWidget {
  const _Satir({required this.etiket, required this.deger, this.vurgu = false, this.renk});
  final String etiket;
  final String deger;
  final bool vurgu;
  final Color? renk;

  @override
  Widget build(BuildContext context) {
    final stil = (vurgu
            ? Theme.of(context).textTheme.titleMedium
            : Theme.of(context).textTheme.bodyLarge)
        ?.copyWith(color: renk, fontWeight: vurgu ? FontWeight.bold : null);
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 2),
      child: Row(
        children: [
          Expanded(child: Text(etiket, style: stil)),
          Text(deger, style: stil),
        ],
      ),
    );
  }
}

String _ikiHane(int n) => n.toString().padLeft(2, '0');
