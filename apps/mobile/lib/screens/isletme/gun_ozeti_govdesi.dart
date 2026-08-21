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
import '../../repo/cash_handover_repository.dart';
import '../../theme/components/atoms.dart';
import '../../theme/components/states.dart';
import '../../theme/tokens.dart';
import '../team.dart';
import 'gun_kapatma_sheet.dart';
import 'gun_sonu_kartlari.dart';
import 'gun_sonu_ozet.dart';
import 'gun_tahsilat_detay.dart';
import 'gun_veresiye_detay.dart';
import 'isletme_atomlari.dart';

class GunOzetiGovdesi extends StatelessWidget {
  const GunOzetiGovdesi({
    super.key,
    required this.db,
    required this.gorunum,
    required this.kapsamAdi,
    required this.gunKapsami,
    required this.ekip,
    required this.bugun,
    required this.onYenile,
    this.kuryeId,
    this.onAraTahsilatIptal,
    this.onKapanisGeriAl,
    this.geriAlinmisKapanislar = const {},
  });

  /// Bir kapanış satırının GERİ ALMA eylemini üreten yapıcı (2026-08-18). null ise düğme hiç
  /// çizilmez — yetki ve oturum kapısı EKRANDADIR, gövde onu yalnız taşır ([onAraTahsilatIptal]
  /// ile aynı sözleşme: gövde karar vermez).
  final Future<void> Function(DayClosing)? onKapanisGeriAl;

  /// Geri alınmış kapanışların id'leri — satır rozeti ve "geri al düğmesini gizle" kararı bundan.
  /// Küme EKRANDAN gelir; "geçerli kapanış" tanımı `DayClosingRepository`de TEK yerde durur.
  final Set<String> geriAlinmisKapanislar;

  /// Bir ara tahsilat satırının İPTAL eylemini üreten yapıcı (kullanıcı kararı 2026-08-13).
  /// null ise satırlar dokunulamaz — yetki kapısı EKRANDADIR, gövde onu yalnız taşır.
  ///
  /// Gövdenin hiçbir karar vermemesi bu dosyanın sözleşmesidir (bkz. başlık notu): burada
  /// `yetkiler()` çağırsaydık aynı yetki iki yerde çözülür ve biri geride kalırdı.
  final VoidCallback Function(AraTahsilatKaydi)? onAraTahsilatIptal;

  /// Tahsilat dökümü kendi sorgusunu koşar (özet `FutureBuilder`ından gelmez): döküm yalnız
  /// açıldığında ve yalnız istenen türde okunur.
  final AppDatabase db;

  /// Seçili kapsamın kurye kimliği; `null` = gün hesabı.
  final String? kuryeId;

  final Future<void> Function() onYenile;
  final GunSonuGorunumu gorunum;

  /// "Bugün/Dün" etiketlerinin referans günü — ekran onu DÜZELTİLMİŞ saatten çözer.
  final DateTime bugun;

  /// Seçili kapsamın adı ("Gün hesabı" ya da kurye adı).
  final String kapsamAdi;

  final bool gunKapsami;

  /// Kapanış kayıtlarındaki `user_id`leri ada çevirmek için (kayıtta yalnız kimlik durur).
  final List<User> ekip;

  String _kapanisAdi(DayClosing k) =>
      k.userId == null ? 'Gün hesabı' : (kullaniciAdi(ekip, k.userId) ?? 'Kurye');

  /// Ödeme türü dökümünü açar. Kapsam ekranınkiyle AYNI ([kuryeId]) — kurye kendi kapsamı
  /// dışındaki bir tahsilatı buradan da göremez; sheet ikinci bir kapı değil, aynı kapsamın
  /// devamıdır.
  void _turDetayi(BuildContext context, String tur) => tahsilatTuruSheetAc(
        context,
        db: db,
        gun: bugun,
        odemeTuru: tur,
        kuryeId: kuryeId,
        kapsamAdi: gunKapsami ? null : kapsamAdi,
      );

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
                ? 'Günün hesabı kapatıldı, kayıtlar kilitlendi.'
                : '$kapsamAdi hesabı kapatıldı ve arşivlendi.',
          ),

        SipBolumBaslik(
          gunKapsami ? 'Kasa Özeti' : '$kapsamAdi için kasa özeti',
          ustBosluk: 18,
        ),
        // ÖDEME TÜRÜ SATIRLARI DOKUNULABİLİR (kullanıcı isteği 2026-08-11): "havalelere
        // tıklayınca o günkü havale siparişlerin detayları açılacak". Açılan döküm kasa
        // kartıyla AYNI süzgeçten geçer (`DayEndRepository._kasayaDokunanlar`), yani listenin
        // toplamı buradaki rakama eşittir — iki yerde iki ayrı para gösterilmez.
        DegerKarti(
          satirlar: [
            DegerSatiri(
              etiket: 'Nakit',
              deger: sipTutar(kasa.nakit),
              onTap: () => _turDetayi(context, 'nakit'),
            ),
            DegerSatiri(
              etiket: 'Kart',
              deger: sipTutar(kasa.kart),
              onTap: () => _turDetayi(context, 'kart'),
            ),
            DegerSatiri(
              etiket: 'Havale',
              deger: sipTutar(kasa.havale),
              onTap: () => _turDetayi(context, 'havale'),
            ),
            DegerSatiri(
              etiket: 'Toplam tahsilat (${g.kapsam.teslimat} teslimat)',
              deger: sipTutar(kasa.toplam),
              toplam: true,
            ),
            // ESKİ BORÇ TAHSİLATI — toplamın İÇİNDE, ama ayrı yazılı (saha isteği 2026-08-18:
            // "geçmişten kalan bir siparişin tahsilatını yaptıysa bunu ayrı belirtmeli, hesaba
            // yine dahil etsin"). Etikette "dahil" sözcüğü ZORUNLU: satır toplamın altında
            // duruyor ve iskonto satırıyla aynı yerde; oradaki para kasaya GİRMEDİ, buradaki
            // GİRDİ. İki komşu satırın zıt anlamını kelime taşımazsa bayi ikisini de yanlış
            // okur ve toplamdan bir kez daha düşmeye çalışır.
            if (g.kapsam.eskiBorcTahsilati > 0)
              DegerSatiri(
                etiket: 'Eski borç tahsilatı (toplama dahil)',
                deger: sipTutar(g.kapsam.eskiBorcTahsilati),
                degerRengi: context.sip.ink2,
              ),
            // ⚠️ "BUGÜN YAZILAN VERESİYE" BURAYA KONMADI, bilinçli: aşağıdaki "Günün
            // Veresiyeleri" bölümü aynı rakamı zaten TOPLAM olarak taşıyor ve hemen birkaç
            // satır aşağıda duruyor. İkisini birden yazmak, tek ekran içinde aynı sayıyı iki
            // kez göstermek olurdu — ve bu depoda aynı sayının iki yerde durması her seferinde
            // ikisinin ayrışmasıyla bitti. Eski borç tahsilatının burada yazılmasının sebebi
            // farklıdır: o rakam TOPLAMIN İÇİNDEDİR ve başka hiçbir yerde açıklanamaz.
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
            onIptal: onAraTahsilatIptal,
          ),
        ],

        // BUGÜNÜN VERESİYESİ, birikmiş borcun ÜSTÜNDE durur (saha isteği 2026-08-18).
        // Sıra bilinçli: bayi önce BUGÜN ne olduğunu okur, sonra toplam yükü. Tersi olsaydı
        // günün rakamı yine 48.000 ₺'lik bir yığının altında kalırdı — şikâyetin kendisi
        // "bugünkü veresiye görünmüyor"du, "veresiye diye bir şey yok" değil.
        //
        // KURYE KAPSAMINDA DA ÇİZİLİR (birikmiş borç kartının aksine): kurye kendi teslim
        // ettiği siparişin ne kadarını borca yazdığını bilmek zorundadır, çünkü akşam kasada
        // o para EKSİK çıkacak ve farkın açıklaması budur.
        GunVeresiyeBolumu(
          db: db,
          gun: bugun,
          kuryeId: kuryeId,
          toplamKurus: g.kapsam.veresiye,
        ),

        if (gunKapsami) ...[
          const SipBolumBaslik('Açık Veresiye', ustBosluk: 18),
          VeresiyeKarti(borc: g.ozet.borc),
        ],

        // GÜNÜN TESLİMATLARI — aç/kapa anahtarlı detaylı döküm (kullanıcı isteği 2026-08-11).
        // Kapanışların ÜSTÜNDE durur: kapanış bir SONUÇTUR, döküm ise o sonucu üreten
        // kayıtlardır; bayi önce parayı, sonra mutabakatı okur.
        GunTeslimatlariBolumu(db: db, gun: bugun, kuryeId: kuryeId),

        // BUGÜNÜN kapanışları burada kalır (Geçmiş ekranı yalnız GEÇMİŞ günleri taşır).
        // Kaldırılsaydı, kuryesinin devrini az önce kapatan patron farkı ancak ERTESİ GÜN
        // görebilirdi — mutabakatın kanıtı kapatıldığı anda görünmek zorunda.
        if (g.gunKapanislari.isNotEmpty) ...[
          const SipBolumBaslik('Bugünün Kapanışları', ustBosluk: 18),
          for (var i = 0; i < g.gunKapanislari.length; i++)
            // GERİ ALMA SATIRLARI LİSTEDE ÇİZİLMEZ (2026-08-18). Repo onları döndürür — arşiv
            // ham gerçeği taşımalı — ama kullanıcıya "0,00 ₺ · 0 teslimat" diye bir kapanış
            // göstermek anlamsız olurdu: o satır bir kapanış değil, bir kapanışın İPTALİDİR ve
            // anlamı ancak geri aldığı satırın üstündeki rozetle okunur.
            if (g.gunKapanislari[i].reversesClosingId == null)
              Padding(
                padding: EdgeInsets.only(top: i == 0 ? 0 : 6),
                child: ArsivSatiri(
                  kapanis: g.gunKapanislari[i],
                  kapsamAdi: _kapanisAdi(g.gunKapanislari[i]),
                  bugun: bugun,
                  geriAlinmis: geriAlinmisKapanislar.contains(g.gunKapanislari[i].id),
                  onTap: () => arsivDetaySheet(
                    context,
                    g.gunKapanislari[i],
                    kapsamAdi: _kapanisAdi(g.gunKapanislari[i]),
                    bugun: bugun,
                    geriAlinmis: geriAlinmisKapanislar.contains(g.gunKapanislari[i].id),
                    onGeriAl: onKapanisGeriAl == null
                        ? null
                        : () => onKapanisGeriAl!(g.gunKapanislari[i]),
                  ),
                ),
              ),
        ],
      ],
    );
  }
}
