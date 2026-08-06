// GÜN ÖZETİ ekranının GÖVDESİ — kapalı şerit · kasa kartı · ara tahsilatlar · veresiye · kapanışlar.
//
// NEDEN AYRI DOSYA: `day_end_screen.dart` bu bölümle 491 satıra çıkmıştı (depo sınırı 500) ve
// gelen her düzeltme turu onu bir adım daha yaklaştırıyordu. Ekran DURUM ve akışları yönetir
// (yükleme, kapsam seçimi, kapatma, ara tahsilat, yetki kapıları); gövde ise salt gösterimdir —
// verilen görünümü çizer, hiçbir karar vermez ve hiçbir para formülü yazmaz.
//
// SINIR BİLİNÇLİ: gövde `GunSonuGorunumu`u OLDUĞU GİBİ alır. Kendi çıkarmasını yapsaydı, bu
// vardiyada yedi kez yaşanan hata sınıfı (anlamı değişen sayıyı eski kelimesiyle taşımak) bir
// de burada tekrarlanırdı.

import 'package:flutter/material.dart';

import '../../data/app_database.dart';
import '../../theme/components/atoms.dart';
import '../../theme/components/states.dart';
import '../../theme/tokens.dart';
import '../team.dart';
import 'gun_kapatma_sheet.dart';
import 'gun_sonu_kartlari.dart';
import 'gun_sonu_ozet.dart';
import 'isletme_atomlari.dart';

class GunOzetiGovdesi extends StatelessWidget {
  const GunOzetiGovdesi({
    super.key,
    required this.gorunum,
    required this.kapsamAdi,
    required this.gunKapsami,
    required this.ekip,
    required this.onYenile,
  });

  final Future<void> Function() onYenile;
  final GunSonuGorunumu gorunum;

  /// Seçili kapsamın adı ("Gün hesabı" ya da kurye adı).
  final String kapsamAdi;

  final bool gunKapsami;

  /// Kapanış kayıtlarındaki `user_id`leri ada çevirmek için (kayıtta yalnız kimlik durur).
  final List<User> ekip;

  String _kapanisAdi(DayClosing k) =>
      k.userId == null ? 'Gün hesabı' : (kullaniciAdi(ekip, k.userId) ?? 'Kurye');

  @override
  Widget build(BuildContext context) {
    final g = gorunum;
    final kasa = g.kapsam.kasa;

    return SipGovde(
      // Yenileme SENKRONU koşar VE ekranın kendi future'ını tazeler: gün sonu verisi
      // `FutureBuilder`dan geliyor, yani senkron yeni satır yazsa bile ekran kendiliğinden
      // yeniden hesaplamaz (akış tabanlı listelerin aksine). İkisinden biri eksik kalsaydı
      // gösterge döner, hiçbir rakam değişmezdi.
      onYenile: onYenile,
      children: [
        if (g.kapsamKapali)
          KapaliSerit(
            metin: g.gunKapali
                ? 'Günün hesabı kapatıldı — tüm hesaplar kilitli.'
                : '$kapsamAdi hesabı kapatıldı ve arşivlendi.',
          ),

        SipBolumBaslik(
          gunKapsami ? 'Kasa Özeti' : 'Kasa Özeti · $kapsamAdi',
          ustBosluk: 18,
        ),
        DegerKarti(
          satirlar: [
            DegerSatiri(etiket: 'Nakit', deger: sipTutar(kasa.nakit)),
            DegerSatiri(etiket: 'Kart', deger: sipTutar(kasa.kart)),
            DegerSatiri(etiket: 'Havale', deger: sipTutar(kasa.havale)),
            DegerSatiri(
              etiket: 'Toplam Tahsilat · ${g.kapsam.teslimat} teslimat',
              deger: sipTutar(kasa.toplam),
              toplam: true,
            ),
            // İSKONTO TOPLAMIN ALTINDA DURUR ve yalnız varsa çizilir (kullanıcı isteği
            // 2026-07-30). Üstünde dursaydı toplamın bir bileşeni gibi okunurdu; oysa kırılan
            // para kasaya HİÇ girmedi — sayılan nakitle karşılaştırılan rakam üstteki toplamdır.
            // Sıfırken hiç yazılmaz: iskontosuz günler çoğunluktur ve "İskonto 0,00 ₺" satırı her
            // gün kasa kartına cevapsız bir soru eklerdi.
            if (g.kapsam.iskonto > 0)
              DegerSatiri(
                etiket: 'İskonto (kasaya girmedi)',
                deger: sipTutar(g.kapsam.iskonto),
                degerRengi: context.sip.warn,
              ),
          ],
        ),

        // ARA TAHSİLATLAR kasa kartının HEMEN ALTINDA durur (kullanıcı kararı 2026-08-06):
        // yukarıdaki nakit rakamı ile akşam sayılacak para arasındaki farkı açıklayan tek şey
        // budur. Araya başka bölüm girseydi bayi ikisini yan yana okuyamazdı.
        if (g.araTahsilatlar.isNotEmpty) ...[
          const SipBolumBaslik('Ara Tahsilatlar', ustBosluk: 18),
          AraTahsilatKarti(
            kayitlar: g.araTahsilatlar,
            toplamKurus: g.araTahsilatToplamiKurus,
            kuryeAdiYaz: gunKapsami,
          ),
        ],

        if (gunKapsami) ...[
          const SipBolumBaslik('Açık Veresiye', ustBosluk: 18),
          VeresiyeKarti(borc: g.ozet.borc),
        ],

        // BUGÜNÜN kapanışları burada kalır (Geçmiş ekranı yalnız GEÇMİŞ günleri taşır).
        // Kaldırılsaydı, kuryesinin devrini az önce kapatan patron farkı ancak ERTESİ GÜN
        // görebilirdi — mutabakatın kanıtı kapatıldığı anda görünmek zorunda.
        if (g.gunKapanislari.isNotEmpty) ...[
          const SipBolumBaslik('Bugünün Kapanışları', ustBosluk: 18),
          for (var i = 0; i < g.gunKapanislari.length; i++)
            Padding(
              padding: EdgeInsets.only(top: i == 0 ? 0 : 6),
              child: ArsivSatiri(
                kapanis: g.gunKapanislari[i],
                kapsamAdi: _kapanisAdi(g.gunKapanislari[i]),
                onTap: () => arsivDetaySheet(
                  context,
                  g.gunKapanislari[i],
                  kapsamAdi: _kapanisAdi(g.gunKapanislari[i]),
                ),
              ),
            ),
        ],
      ],
    );
  }
}
