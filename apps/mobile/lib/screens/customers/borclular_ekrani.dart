// BORÇLULAR — ana ekrandaki bento kutusunun açtığı liste.
//
// NEDEN VAR (kullanıcı kararı 2026-07-29): kutu "Açık Veresiye" adıyla toplam bir rakam yazıyor
// ve dokununca MÜŞTERİLER sekmesine gidiyordu — yani borcu olmayan yüzlerce müşterinin arasına.
// Bayinin o rakama dokunma sebebi tektir: "kim borçlu, ne kadar, hangi siparişten". Kutu artık
// "Borçlular" adını taşır ve bu ekranı açar: yalnız bakiyesi borçta olan müşteriler, her birinin
// altında ÖDENMEMİŞ siparişleri.
//
// BU DOSYA ARTIK YALNIZ KABUK (500 satır kuralı, 533 satırdan bölündü): başlık · boş durum ·
// akışların bağlanması. Sayıların kuralı `borclular_verisi.dart`ta (widget kurmadan test edilir),
// tek müşterinin kartı ve üç eylemi `borclu_karti.dart`ta. Bölme sınırı keyfi değil: üstteki iki
// dosya birbirini TANIMAZ — veri çizimi, çizim de sorguyu bilmez.
//
// İKİ SAYI AYRI DURUR ve toplanmaz: müşterinin DEFTER bakiyesi ile siparişlerden kalanların
// toplamı eşit olmak ZORUNDA DEĞİLDİR (gerekçe `borclular_verisi.dart` başlığında).

import 'package:flutter/material.dart';

import '../../rehber/rehber_modeli.dart';
import '../../rehber/rehber_sahne.dart';

import '../../data/app_database.dart';
import '../../sync/yenileme.dart';
import '../../theme/components/atoms.dart';
import '../../theme/components/states.dart';
import '../../theme/icons.dart';
import '../../theme/tokens.dart';
import '../orders/order_queries.dart' show watchBirincilTelefonlar, watchSiparisTahsilatlari;
import '../team.dart';
import 'borclu_karti.dart';
import 'borclular_verisi.dart';

// Veri katmanı yeniden dışa aktarılır: `borclular_ekrani.dart`ı içe alan mevcut yollar
// (`home_shell.dart`, `ui_borclular_test.dart`) `borcluListesiKur` gibi saf kuralları aynı
// kapıdan görmeye devam eder — bölme kimsenin import satırını değiştirmez.
export 'borclular_verisi.dart';

class BorclularEkrani extends StatelessWidget {
  const BorclularEkrani({
    super.key,
    required this.db,
    required this.writable,
    required this.yetki,
    this.canAssign = false,
  });

  final AppDatabase db;
  final bool writable;

  /// Rol bazlı yetki (K2) — ZORUNLU (2026-08-13, bkz. `CustomerDetailScreen.yetki`): bu ekran
  /// yetkiyi müşteri kartına aktarır, nullable kaldığı sürece oradaki kapıyı sessizce açardı.
  final RolYetkileri yetki;

  /// Sipariş detayına geçilir (kurye ataması orada K2 kapısıyla açılır).
  final bool canAssign;

  @override
  Widget build(BuildContext context) {
    final t = context.sip;
    return Scaffold(
      backgroundColor: t.bg,
      body: SafeArea(
        bottom: false,
        child: StreamBuilder<List<Customer>>(
          stream: watchBorcluMusteriler(db),
          builder: (context, musteriSnap) {
            final musteriler = musteriSnap.data;
            return Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                SipUst(
                  baslik: 'Borçlular',
                  alt: _altBaslik(musteriler),
                  onGeri: () => Navigator.of(context).maybePop(),
                  sag: const [RehberYardimDugmesi(yuzey: RehberYuzey.borclular)],
                ),
                Expanded(
                  child: musteriler == null
                      ? const SipIskelet(adet: 4)
                      : musteriler.isEmpty
                          ? SipBosDurum(
                              ikon: SipIcons.wallet,
                              baslik: 'Borçlu yok',
                              aciklama: 'Bütün müşterilerin hesabı kapalı',
                            )
                          : _Liste(
                              db: db,
                              musteriler: musteriler,
                              writable: writable,
                              yetki: yetki,
                              canAssign: canAssign,
                            ),
                ),
              ],
            );
          },
        ),
      ),
    );
  }

  /// "3 müşteri · 4.250,00 ₺" — kaç kişi ve ne kadar. Veri gelmeden RAKAM YAZILMAZ.
  static String _altBaslik(List<Customer>? musteriler) {
    if (musteriler == null) return '';
    if (musteriler.isEmpty) return 'Tüm hesaplar temiz';
    final toplam = musteriler.fold<int>(0, (s, c) => s + c.balanceKurus);
    return '${musteriler.length} müşteri, toplam ${sipTutar(toplam)}';
  }
}

class _Liste extends StatelessWidget {
  const _Liste({
    required this.db,
    required this.musteriler,
    required this.writable,
    required this.yetki,
    required this.canAssign,
  });

  final AppDatabase db;
  final List<Customer> musteriler;
  final bool writable;
  final RolYetkileri yetki;
  final bool canAssign;

  @override
  Widget build(BuildContext context) {
    // Sipariş akışı borçlu kümesine göre daraltılır; küme değişince yeniden abone olunur.
    return StreamBuilder<List<Order>>(
      stream: watchBorcluSiparisleri(db, [for (final c in musteriler) c.id]),
      initialData: const [],
      builder: (context, siparisSnap) => StreamBuilder<Map<String, int>>(
        stream: watchSiparisTahsilatlari(db),
        initialData: const {},
        builder: (context, tahsilatSnap) => StreamBuilder<Map<String, String>>(
          // Hatırlatma müşterinin BİRİNCİL telefonuna gider (kart telefon alanı taşımaz —
          // numaralar ayrı tabloda ve bir müşterinin birden çok numarası olabilir).
          stream: watchBirincilTelefonlar(db),
          initialData: const {},
          builder: (context, telefonSnap) => StreamBuilder<TenantSetting?>(
            // IBAN + işletme adı mesajın içine girer; ikisi de işletme profilinden gelir ve
            // bayi Ayarlar'da düzenleyince bu ekran ANINDA doğru metni kurmalı (tek atış okuma
            // bayat kalırdı — "IBAN tanımlı değil" diyen bir düğme, IBAN girildikten sonra da
            // aynı şeyi söylerdi).
            stream: watchIsletmeProfili(db),
            builder: (context, ayarSnap) {
              final liste = borcluListesiKur(
                musteriler,
                siparisSnap.data ?? const [],
                tahsilatSnap.data ?? const {},
              );
              final ayar = ayarSnap.data;
              return RefreshIndicator(
                onRefresh: yenile,
                child: ListView.builder(
                  padding: const EdgeInsets.fromLTRB(
                      SipSpace.govde, 0, SipSpace.govde, SipSpace.x5),
                  physics: const AlwaysScrollableScrollPhysics(),
                  itemCount: liste.length,
                  itemBuilder: (context, i) => Padding(
                    padding: EdgeInsets.only(top: i == 0 ? 0 : SipSpace.md),
                    child: BorcluKarti(
                      db: db,
                      veri: liste[i],
                      writable: writable,
                      yetki: yetki,
                      canAssign: canAssign,
                      telefon: (telefonSnap.data ?? const {})[liste[i].musteri.id],
                      iban: ayar?.iban,
                      isletmeAdi: ayar?.businessName,
                      ibanAliciAdi: ayar?.ibanOwnerName,
                      sablon: ayar?.reminderTemplate,
                    ),
                  ),
                ),
              );
            },
          ),
        ),
      ),
    );
  }
}
