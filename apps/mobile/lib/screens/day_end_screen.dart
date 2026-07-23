import 'package:flutter/material.dart';

import '../data/app_database.dart';
import '../repo/day_end_repository.dart';
import '../theme/tokens.dart';
import '../theme/typography.dart';
import 'money.dart';

/// DİLİM 3 — GÜN SONU ekranı (Menü → Gün sonu). TAMAMEN SALT-OKUNUR: hiçbir yazma yok, yalnız
/// DayEndRepository read-model'ini gösterir (kasa özeti · veresiye toplamı · kupon durumu).
/// Gün sınırı SABİT +03:00 (TR); localDate bugünün TR takvim günüdür (cihaz saat dilimi ne olursa olsun).
///
/// Görsel: yeniden tasarım — SafeArea + ekran başlığı + tarih satırı + kartlar (handoff dili;
/// müşteri/sipariş listeleriyle aynı yüzey/kenar/köşe). Aksiyon/FAB YOK (salt-okunur ekran).
/// Durum yönetimi/veri akışı (FutureBuilder → gunSonuOzeti) DEĞİŞMEDİ; yalnız görünüm yenilendi.

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
      backgroundColor: SipColors.bg,
      body: SafeArea(
        bottom: false,
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            Padding(
              padding: const EdgeInsets.fromLTRB(18, 8, 18, 14),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  const Text('Gün sonu', style: SipText.screenTitle),
                  const SizedBox(height: 6),
                  Text(
                    '${_ikiHane(gun.day)}.${_ikiHane(gun.month)}.${gun.year}',
                    style: SipText.secondary,
                  ),
                ],
              ),
            ),
            Expanded(
              child: FutureBuilder<GunSonuOzet>(
                future: gunSonuOzeti(db, gun),
                builder: (context, snap) {
                  if (!snap.hasData) return const Center(child: CircularProgressIndicator());
                  final o = snap.data!;
                  return ListView(
                    padding: const EdgeInsets.fromLTRB(14, 2, 14, 24),
                    children: [
                      _KasaKarti(kasa: o.kasa),
                      const SizedBox(height: SipSpace.gap),
                      _BorcKarti(borc: o.borc),
                      const SizedBox(height: SipSpace.gap),
                      _KuponKarti(kupon: o.kupon),
                      const SizedBox(height: SipSpace.xl),
                      Center(
                        child: Text('Salt-okunur özet — defterden türetilir.',
                            style: SipText.muted),
                      ),
                    ],
                  );
                },
              ),
            ),
          ],
        ),
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
        const _Ayrac(),
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
    // Açık borç > 0 ise KIRMIZI — borçluyu bir bakışta ayırt et (handoff kırmızı bakiye dili).
    final borcVar = borc.toplamAcikBorc > 0;
    return _Kart(
      baslik: 'Veresiye (açık borç)',
      ikon: Icons.menu_book_outlined,
      children: [
        _Satir(
          etiket: 'Toplam açık borç',
          deger: formatKurus(borc.toplamAcikBorc),
          vurgu: true,
          renk: borcVar ? SipColors.debt : null,
        ),
        if (borc.borclular.isEmpty)
          const Padding(
            padding: EdgeInsets.only(top: SipSpace.sm),
            child: Text('Açık borç yok.', style: SipText.secondary),
          )
        else ...[
          const _Ayrac(),
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
          const _Ayrac(),
          Padding(
            padding: const EdgeInsets.only(bottom: SipSpace.xs),
            child: Text('Eksi bakiye (düzeltme bekliyor)',
                style: SipText.muted.copyWith(color: SipColors.debt)),
          ),
          // Eksi kupon bakiyesi KIRMIZI — düzeltme bekleyen satırlar dikkat çeksin.
          for (final e in kupon.eksiBakiyeliler)
            _Satir(
              etiket: e.productId.isEmpty ? 'Genel kupon' : 'Ürün kuponu',
              deger: '${e.balanceQty} adet',
              renk: SipColors.debt,
            ),
        ],
      ],
    );
  }
}

/// Özet kartı — yüzey s1 + ince kenar (line) + yumuşak köşe (card); başlıkta vurgu ikonu +
/// kart başlığı. Liste kartlarıyla AYNI dil, ama salt-okunur (InkWell/aksiyon yok).
class _Kart extends StatelessWidget {
  const _Kart({required this.baslik, required this.ikon, required this.children});
  final String baslik;
  final IconData ikon;
  final List<Widget> children;

  @override
  Widget build(BuildContext context) {
    return Container(
      decoration: BoxDecoration(
        color: SipColors.s1,
        borderRadius: SipRadius.cardBr,
        border: Border.all(color: SipColors.line),
      ),
      padding: const EdgeInsets.fromLTRB(16, 15, 16, 15),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Icon(ikon, size: 19, color: SipColors.accFg),
              const SizedBox(width: 9),
              Text(baslik, style: SipText.cardTitle),
            ],
          ),
          const SizedBox(height: SipSpace.md),
          ...children,
        ],
      ),
    );
  }
}

/// Kart içi etiket/tutar satırı — sol etiket (ikincil), sağ tutar (tabular). `vurgu` toplamları
/// büyütür (amount stili); `renk` verilirse tutar o renge boyanır (kırmızı = borç/eksi bakiye).
class _Satir extends StatelessWidget {
  const _Satir({required this.etiket, required this.deger, this.vurgu = false, this.renk});
  final String etiket;
  final String deger;
  final bool vurgu;
  final Color? renk;

  @override
  Widget build(BuildContext context) {
    final etiketStil = vurgu
        ? SipText.secondary.copyWith(color: SipColors.t1, fontWeight: FontWeight.w600)
        : SipText.secondary;
    final degerStil = (vurgu
            ? SipText.amount
            : SipText.secondary.copyWith(color: SipColors.t1, fontWeight: FontWeight.w600))
        .copyWith(color: renk);
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: SipSpace.xs),
      child: Row(
        children: [
          Expanded(child: Text(etiket, style: renk != null ? etiketStil.copyWith(color: renk) : etiketStil)),
          const SizedBox(width: 10),
          Text(deger, style: degerStil),
        ],
      ),
    );
  }
}

/// Kart içi ince ayraç — token kenar rengiyle (temaya bağlı Divider yerine; bu ekran düz
/// MaterialApp altında da çizilir, renk doğrudan token'dan gelir).
class _Ayrac extends StatelessWidget {
  const _Ayrac();

  @override
  Widget build(BuildContext context) {
    return Container(
      height: 1,
      margin: const EdgeInsets.symmetric(vertical: SipSpace.sm),
      color: SipColors.line,
    );
  }
}

String _ikiHane(int n) => n.toString().padLeft(2, '0');
