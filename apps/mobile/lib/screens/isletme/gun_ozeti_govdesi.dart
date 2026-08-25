// GÜN ÖZETİ ekranının GÖVDESİ — tepe bloğu · kasa · gider · veresiye · döküm · kapanışlar.
//
// ══ YENİDEN TASARLANDI (kullanıcı isteği 2026-08-25) ════════════════════════════════════════
// Şikâyet aynen şuydu: *"Gün Özeti sayfası çok uğraştırıcı"*. Üç somut sebebi vardı ve üçü de
// bu turda kapandı:
//
//  1. GEÇMİŞ AYRI EKRANDAYDI. Bayi dünü görmek için başlıktaki "Geçmiş" düğmesine basıp BAŞKA
//     bir ekrana geçiyordu ve o ekran bu ekranla aynı şeyi göstermiyordu (orada "Satılan
//     Ürünler" vardı, burada yoktu; burada gider/ara tahsilat düzenlenebiliyordu, orada değil).
//     İki ekranın bakımı da ayrı yürüyordu. Artık TEK ekran var, gün üstteki şeritten (ve
//     takvimden) seçiliyor; bu gövde HANGİ GÜN olursa olsun aynı bölümleri çiziyor.
//  2. EN ÇOK SORULAN RAKAM EKRANDA YOKTU. "Çekmecede ne olmalı?" sorusunun cevabı nakitten ara
//     tahsilatı, gideri ve kuryelerde kalanı çıkarmayı gerektiriyordu — bayi bunu kafasından
//     yapıyordu. Artık en üstte, tek başına, iri puntoyla yazıyor (`GunOzetiBasligi`).
//  3. GİDER DİYE BİR ŞEY YOKTU. Yetki matrisinde satırı vardı, ürününde yolu yoktu; kasadan
//     çıkan her kuruş akşam "eksik para" olarak görünüyordu.
//
// ══ GÖVDE HİÇBİR KARAR VERMEZ ═══════════════════════════════════════════════════════════════
// Sınır bir tur öncesinden aynen korunuyor: gövde `GunSonuGorunumu`u OLDUĞU GİBİ alır, hiçbir
// para formülü yazmaz ve hiçbir yetki sormaz. Yetki/eylem kapıları EKRANDADIR; buraya null
// gelen bir geri arama "o yol kapalı" demektir ve gövde onu yalnız çizmez.

import 'package:flutter/material.dart';

import '../../data/app_database.dart';
import '../../repo/cash_handover_repository.dart';
import '../../repo/gider_repository.dart';
import '../../theme/components/atoms.dart';
import '../../theme/components/states.dart';
import '../../theme/icons.dart';
import '../../theme/tokens.dart';
import '../team.dart';
import 'gun_gider_bolumu.dart';
import 'gun_kapatma_sheet.dart';
import 'gun_ozeti_basligi.dart';
import 'gun_sonu_kartlari.dart';
import 'gun_sonu_ozet.dart';
import 'gun_tahsilat_detay.dart';
import 'gun_urun_bolumu.dart';
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
    required this.gun,
    required this.bugun,
    required this.onYenile,
    this.kuryeId,
    this.haric,
    this.onAraTahsilatIptal,
    this.onKapanisGeriAl,
    this.onGiderEkle,
    this.onGiderIptal,
    this.giderTazeleme = 0,
    this.geriAlinmisKapanislar = const {},
  });

  final AppDatabase db;
  final GunSonuGorunumu gorunum;

  /// GÖSTERİLEN gün (bugün olmak zorunda değil — 2026-08-25 gün gezinmesi).
  final DateTime gun;

  /// "Bugün/Dün" etiketlerinin referans günü — ekran onu DÜZELTİLMİŞ saatten çözer.
  final DateTime bugun;

  /// Seçili kapsamın adı ("Gün hesabı" ya da kişi adı).
  final String kapsamAdi;

  /// Kapsam gün geneli mi (kişi ya da "Elemanlar" değil)?
  final bool gunKapsami;

  /// Seçili kapsamın kişi kimliği; null = gün hesabı ya da "Elemanlar".
  final String? kuryeId;

  /// "Elemanlar" kapsamı — bu kişi HARİÇ herkes.
  final String? haric;

  /// Kapanış kayıtlarındaki `user_id`leri ada çevirmek için (kayıtta yalnız kimlik durur).
  final List<User> ekip;

  final Future<void> Function() onYenile;

  /// Bir ara tahsilat satırının İPTAL eylemini üreten yapıcı; null ise satırlar dokunulamaz.
  final VoidCallback Function(AraTahsilatKaydi)? onAraTahsilatIptal;

  /// Bir kapanış satırının GERİ ALMA eylemini üreten yapıcı; null ise düğme hiç çizilmez.
  final Future<void> Function(DayClosing)? onKapanisGeriAl;

  /// Gider ekleme kapısı; null ise düğme HİÇ çizilmez (yetki yok · geçmiş gün · kapalı kapsam).
  final VoidCallback? onGiderEkle;

  /// Bir gider satırının İPTAL eylemini üreten yapıcı; null ise satırlar dokunulamaz.
  final VoidCallback Function(GiderSatiri)? onGiderIptal;

  /// Gider dökümünün yeniden okunmasını tetikleyen sayaç.
  final int giderTazeleme;

  /// Geri alınmış kapanışların id'leri — satır rozeti ve "geri al düğmesini gizle" kararı bundan.
  final Set<String> geriAlinmisKapanislar;

  String _kapanisAdi(DayClosing k) =>
      k.userId == null ? 'Gün hesabı' : (kullaniciAdi(ekip, k.userId) ?? 'Kurye');

  /// Ödeme türü dökümünü açar. Kapsam ekranınkiyle AYNI (hem [kuryeId] hem [haric]) — sheet
  /// ikinci bir kapı değil, aynı kapsamın devamıdır ve toplamı kartın rakamına EŞİT olmalıdır.
  void _turDetayi(BuildContext context, String tur) => tahsilatTuruSheetAc(
        context,
        db: db,
        gun: gun,
        odemeTuru: tur,
        kuryeId: kuryeId,
        haric: haric,
        kapsamAdi: gunKapsami ? null : kapsamAdi,
        bugunMu: gorunum.bugunMu,
      );

  /// Seçili kapsamda hiç hareket var mı? Üç kaynağa birden bakılır — yalnız tahsilata bakmak,
  /// parası ertesi gün alınan bir teslimat gününü "boş" gösterirdi.
  bool get _kapsamBos =>
      gorunum.kapsam.kasa.toplam == 0 &&
      gorunum.kapsam.kasa.gider == 0 &&
      gorunum.kapsam.teslimat == 0 &&
      gorunum.gunKapanislari.isEmpty &&
      gorunum.araTahsilatlar.isEmpty;

  @override
  Widget build(BuildContext context) {
    final g = gorunum;
    final kasa = g.kapsam.kasa;

    return SipGovde(
      // Yenileme SENKRONU koşar VE ekranın kendi future'ını tazeler: gün sonu verisi
      // `FutureBuilder`dan geliyor, yani senkron yeni satır yazsa bile ekran kendiliğinden
      // yeniden hesaplamaz (akış tabanlı listelerin aksine).
      onYenile: onYenile,
      children: [
        // ══ DURUM BANDI ════════════════════════════════════════════════════════════════════
        // Kapanmamış GEÇMİŞ gün ayrıca uyarılır (eski Geçmiş ekranından devralındı): kapatılmamış
        // bir günün rakamları gösterilmeye DEVAM eder (kullanıcı kararı 2026-07-29 — bayi
        // kapatmayı unuttuğunda o günün cirosu okunamaz hâle gelmemeli), ama sayım yapılmadığı
        // SÖYLENİR; yoksa ekran mutabık bir gün gibi okunurdu.
        if (g.kapsamKapali)
          KapaliSerit(
            metin: g.gunKapali
                ? (g.bugunMu
                    ? 'Günün hesabı kapatıldı, kayıtlar kilitlendi'
                    : 'Bu günün hesabı kapatıldı')
                : '$kapsamAdi hesabı kapatıldı ve arşivlendi',
          )
        else if (!g.bugunMu && g.kayitVar)
          const SipNotKutusu(
            tur: SipNotTuru.uyari,
            ikon: SipIcons.info,
            metin: 'Bu günün hesabı kapatılmadı',
          ),

        // ══ BOŞ GÜN — YALNIZ GEÇMİŞTE ═══════════════════════════════════════════════════════
        // İKİ AYRI BOŞLUK, İKİ AYRI CÜMLE: "o gün hiç çalışılmadı" ile "o gün bu kişi çalışmadı"
        // aynı şey değil. Tek cümleyle geçilseydi bayi, kuryesi izinliyken günün tamamının boş
        // olduğunu sanırdı. Geçmiş bir günde sıfırlarla dolu bir kasa kartı çizmek daha kötüsü —
        // kasayı eksik sandırırdı.
        //
        // ⚠️ BUGÜN BU KAPIDAN GEÇMEZ ve bu pazarlıksız: gün DEVAM EDİYOR. Sabah 09:00'da henüz
        // sipariş yokken boş durum çizilseydi (a) "Gider Ekle" düğmesi ekranda HİÇ olmazdı —
        // yani gün içinde ilk hareket bir gider olamazdı, (b) gün kapatma çubuğu bağlamsız
        // kalırdı, (c) bayi uygulamanın kendi gününü kaybettiğini sanırdı. Bugünün sıfırları
        // BİLGİDİR; geçmişin sıfırları gürültüdür.
        if (!g.bugunMu && !g.kayitVar)
          const SipBosDurum(
            ikon: SipIcons.takvim,
            baslik: 'Bu güne ait hareket yok',
            aciklama: 'Bu gün sipariş, tahsilat ya da gider kaydedilmemiş',
          )
        else if (!g.bugunMu && _kapsamBos)
          SipBosDurum(
            ikon: SipIcons.takvim,
            baslik: '$kapsamAdi bu gün çalışmamış',
            aciklama: 'Bu günün diğer kayıtlarını görmek için kapsamı "Tümü" yapın',
          )
        else ...[
          // ══ TEPE BLOĞU ══════════════════════════════════════════════════════════════════
          GunOzetiBasligi(
            beklenen: g.beklenenNakit,
            tahsilat: kasa.toplam,
            gider: kasa.gider,
            teslimat: g.kapsam.teslimat,
            veresiye: g.kapsam.veresiye,
            kapsamKapali: g.kapsamKapali,
            gunKapali: g.gunKapali,
          ),

          // ══ KASA ÖZETİ ══════════════════════════════════════════════════════════════════
          SipBolumBaslik(
            gunKapsami ? 'Kasa Özeti' : '$kapsamAdi için kasa özeti',
            ustBosluk: 18,
          ),
          // ÖDEME TÜRÜ SATIRLARI DOKUNULABİLİR (kullanıcı isteği 2026-08-11): açılan döküm kasa
          // kartıyla AYNI süzgeçten geçer, yani listenin toplamı buradaki rakama eşittir — iki
          // yerde iki ayrı para gösterilmez.
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
              // ESKİ BORÇ TAHSİLATI — toplamın İÇİNDE, ama ayrı yazılı (saha isteği 2026-08-18).
              // Etikette "dahil" sözcüğü ZORUNLU: satır toplamın altında, iskonto/gider
              // satırlarıyla aynı yerde duruyor ve oradaki para kasaya GİRMEDİ, buradaki GİRDİ.
              if (g.kapsam.eskiBorcTahsilati > 0)
                DegerSatiri(
                  etiket: 'Eski borç tahsilatı (toplama dahil)',
                  deger: sipTutar(g.kapsam.eskiBorcTahsilati),
                  degerRengi: context.sip.ink2,
                ),
              // İSKONTO TOPLAMIN ALTINDA DURUR ve yalnız varsa çizilir (kullanıcı isteği
              // 2026-07-30). Üstünde dursaydı toplamın bir bileşeni gibi okunurdu; oysa kırılan
              // para kasaya HİÇ girmedi.
              if (g.kapsam.iskonto > 0)
                DegerSatiri(
                  etiket: 'İskonto (kasaya girmedi)',
                  deger: sipTutar(g.kapsam.iskonto),
                  degerRengi: context.sip.warn,
                ),
              // GİDER DE TOPLAMIN ALTINDA (2026-08-25): "Toplam tahsilat" bir TAHSİLAT
              // toplamıdır ve gider bir tahsilat değildir — üç kovanın içine karıştırılamaz.
              // Ama hemen altında yazmak ZORUNLU: nakit satırı ile akşam sayılacak para
              // arasındaki farkı açıklayan iki şeyden biri budur (diğeri ara tahsilat).
              //
              // "Kasadan çıktı" sözcükleri, bir üstteki "kasaya girmedi" ile KASTEN farklı:
              // iskonto hiç girmemiş bir paradır, gider girmiş ve çıkmış bir paradır. İkisi de
              // toplamı azaltır ama aynı cümleyle anlatılamaz.
              if (kasa.gider != 0)
                DegerSatiri(
                  etiket: 'Gider (kasadan çıktı)',
                  deger: '− ${sipTutar(kasa.gider)}',
                  degerRengi: context.sip.warn,
                ),
            ],
          ),

          // ══ GİDERLER ═══════════════════════════════════════════════════════════════════
          // Kasa kartının HEMEN ALTINDA (ara tahsilatla aynı gerekçe): yukarıdaki nakit rakamı
          // ile akşam sayılacak para arasındaki farkı açıklayan iki bölümden biri budur.
          GunGiderBolumu(
            db: db,
            gun: gun,
            toplamKurus: kasa.gider,
            bugunMu: g.bugunMu,
            kuryeId: kuryeId,
            haric: haric,
            // Ad, TEK KİŞİ kapsamı dışında her yerde yazılır: "Elemanlar" birden çok kişiyi
            // kapsar ve orada kimin harcadığı ancak satırda okunur. Kişi kapsamında tekrar
            // etmek gürültüdür — kimin olduğu zaten başlıkta yazıyor.
            adYaz: kuryeId == null,
            onEkle: onGiderEkle,
            onIptal: onGiderIptal,
            yenilemeAnahtari: giderTazeleme,
          ),

          // ══ ARA TAHSİLATLAR ════════════════════════════════════════════════════════════
          if (g.araTahsilatlar.isNotEmpty) ...[
            const SipBolumBaslik('Ara Tahsilatlar', ustBosluk: 18),
            AraTahsilatKarti(
              kayitlar: g.araTahsilatlar,
              toplamKurus: g.araTahsilatToplamiKurus,
              // Kişi kapsamı DIŞINDA ad yazılır ("Elemanlar" birden çok kişiyi kapsar).
              kuryeAdiYaz: kuryeId == null,
              onIptal: onAraTahsilatIptal,
            ),
          ],

          // ══ VERESİYE ═══════════════════════════════════════════════════════════════════
          // GÜNÜN veresiyesi, birikmiş borcun ÜSTÜNDE durur (saha isteği 2026-08-18): bayi önce
          // O GÜN ne olduğunu okur, sonra toplam yükü. Kişi kapsamında da çizilir — kurye kendi
          // teslim ettiği siparişin ne kadarını borca yazdığını bilmek zorundadır, çünkü akşam
          // kasada o para EKSİK çıkacak ve farkın açıklaması budur.
          GunVeresiyeBolumu(
            db: db,
            gun: gun,
            kuryeId: kuryeId,
            haric: haric,
            bugunMu: g.bugunMu,
            toplamKurus: g.kapsam.veresiye,
          ),

          // AÇIK VERESİYE YALNIZ BUGÜN ÇİZİLİR. `customers.balance_kurus` ANLIK durumdur ve
          // geçmişe sarılamaz (bkz. `gunSonuGorunumu` doc'u): üç gün önceki günde göstermek, o
          // günün borcu sanılacak bir rakam basmak olurdu.
          if (gunKapsami && g.bugunMu) ...[
            const SipBolumBaslik('Açık Veresiye', ustBosluk: 18),
            VeresiyeKarti(borc: g.ozet.borc),
          ],

          // ══ DÖKÜMLER ═══════════════════════════════════════════════════════════════════
          GunTeslimatlariBolumu(
            db: db,
            gun: gun,
            kuryeId: kuryeId,
            haric: haric,
            bugunMu: g.bugunMu,
          ),

          // SATILAN ÜRÜNLER ARTIK BUGÜN İÇİN DE VAR (2026-08-25). Eskiden yalnız Geçmiş
          // ekranında çiziliyordu — yani bayi "bugün kaç damacana sattım" sorusunu ancak ERTESİ
          // GÜN sorabiliyordu. Bölümün gün geneli olması dışında bir sebebi yoktu.
          //
          // YALNIZ GÜN KAPSAMINDA: `satilanUrunler` kurye süzgeci almıyor; kişi kapsamında
          // basılsaydı o kişinin sattıkları sanılırdı — kasa kartı kişiye ait, döküm günün
          // tamamına.
          if (gunKapsami) GunUrunBolumu(db: db, gun: gun),

          // ══ KAPANIŞLAR ═════════════════════════════════════════════════════════════════
          if (g.gunKapanislari.isNotEmpty) ...[
            SipBolumBaslik(
              g.bugunMu ? 'Bugünün Kapanışları' : 'Kapanış Kayıtları',
              ustBosluk: 18,
            ),
            for (var i = 0; i < g.gunKapanislari.length; i++)
              // GERİ ALMA SATIRLARI LİSTEDE ÇİZİLMEZ (2026-08-18). Repo onları döndürür — arşiv
              // ham gerçeği taşımalı — ama "0,00 ₺ · 0 teslimat" diye bir kapanış göstermek
              // anlamsız olurdu: o satır bir kapanış değil, bir kapanışın İPTALİDİR ve anlamı
              // ancak geri aldığı satırın üstündeki rozetle okunur.
              if (g.gunKapanislari[i].reversesClosingId == null)
                Padding(
                  padding: EdgeInsets.only(top: i == 0 ? 0 : 6),
                  child: ArsivSatiri(
                    kapanis: g.gunKapanislari[i],
                    kapsamAdi: _kapanisAdi(g.gunKapanislari[i]),
                    bugun: bugun,
                    geriAlinmis:
                        geriAlinmisKapanislar.contains(g.gunKapanislari[i].id),
                    onTap: () => arsivDetaySheet(
                      context,
                      g.gunKapanislari[i],
                      kapsamAdi: _kapanisAdi(g.gunKapanislari[i]),
                      bugun: bugun,
                      geriAlinmis:
                          geriAlinmisKapanislar.contains(g.gunKapanislari[i].id),
                      onGeriAl: onKapanisGeriAl == null
                          ? null
                          : () => onKapanisGeriAl!(g.gunKapanislari[i]),
                    ),
                  ),
                ),
          ],
        ],
      ],
    );
  }
}
