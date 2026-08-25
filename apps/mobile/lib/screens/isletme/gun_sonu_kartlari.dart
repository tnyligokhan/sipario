// GÜN SONU ekranının kart parçaları — tasarım s-gunsonu.jsx + Sipario.html
// `.gs-veresiye`, `.gs-vtop`, `.gs-temiz`, `.gs-arow`, `.gs-engel`.
//
// Hepsi salt gösterimdir: gelen değeri çizer, hiçbir para hesabı yapmaz (hesap `gun_sonu_ozet.dart`
// üzerinden repo'lardadır).

import 'package:flutter/material.dart';

import '../../data/app_database.dart';
import '../../data/tr_gun.dart';
import '../../repo/cash_handover_repository.dart';
import '../../repo/day_end_repository.dart';
import '../../theme/components/atoms.dart';
import '../../theme/icons.dart';
import '../../theme/tokens.dart';
import '../../theme/typography.dart';
import 'gun_kapatma_sheet.dart';
import 'isletme_atomlari.dart';

/// CSS `.gs-veresiye` — toplam açık borç + borçlu dökümü (çoktan aza).
class VeresiyeKarti extends StatelessWidget {
  const VeresiyeKarti({super.key, required this.borc});

  final BorcDurumu borc;

  @override
  Widget build(BuildContext context) {
    final t = context.sip;
    return DegerKarti(
      satirlar: [
        // CSS `.gs-vtop`
        DegerSatiri(
          etiket: 'Toplam açık borç',
          deger: sipTutar(borc.toplamAcikBorc),
          degerRengi: borc.toplamAcikBorc > 0 ? t.danger : t.ink,
        ),
        if (borc.borclular.isEmpty)
          // CSS `.gs-temiz`
          Padding(
            padding: const EdgeInsets.symmetric(vertical: 13),
            child: Row(
              children: [
                SipIcon(SipIcons.check, boyut: 16, kalinlik: 2.4, renk: t.ok),
                const SizedBox(width: SipSpace.md),
                Text(
                  'Borçlu müşteri yok',
                  style: SipText.metin(13, w: 700).copyWith(color: t.ok),
                ),
              ],
            ),
          )
        else
          for (final b in borc.borclular)
            DegerSatiri(
              etiket: b.name,
              deger: sipTutar(b.balanceKurus),
              degerRengi: t.danger,
            ),
      ],
    );
  }
}

/// ARA TAHSİLAT satırları (kullanıcı kararı 2026-08-06) — "kim · saat · tutar", eskiden yeniye.
///
/// NEDEN GÖRÜNÜR OLMAK ZORUNDA: kapanışta beklenen nakit artık KALAN nakittir. Bu kart olmasaydı
/// bayi her gün açıklanamayan bir eksik görürdü ("ciro 12.000, kasada 7.000") ve o farkın nereye
/// gittiğini uygulama hiçbir yerde söylemezdi.
///
/// Sıra ESKİDEN YENİYEDİR (repo öyle döner): bu bir arşiv değil, günün akışıdır.
class AraTahsilatKarti extends StatelessWidget {
  const AraTahsilatKarti({
    super.key,
    required this.kayitlar,
    required this.toplamKurus,
    this.kuryeAdiYaz = true,
    this.onIptal,
  });

  final List<AraTahsilatKaydi> kayitlar;

  /// Bir satırın İPTAL eylemini üreten yapıcı (kullanıcı kararı 2026-08-13). null ise hiçbir satır
  /// dokunulabilir DEĞİLDİR — kurye görünümü budur.
  ///
  /// NEDEN DOĞRUDAN `VoidCallback` DEĞİL: eylem kayda bağlıdır (hangi tahsilat iptal edilecek) ve
  /// kart hangi satırın hangi kayda karşılık geldiğini zaten biliyor. Yapıcıyı ekran verir, kart
  /// yalnız çağırır — böylece onay metnini (tutar + kurye + saat) ve yetkiyi kart değil ekran
  /// kurar. Kart hiçbir yetki KARARI vermez, bu dosyanın kuralı budur.
  ///
  /// İPTALLİ SATIR TEKRAR İPTAL EDİLEMEZ: aşağıda yapıcı o satırlar için hiç çağrılmaz. İkinci
  /// bir iptal, parayı ikinci kez geri vermek olurdu.
  final VoidCallback Function(AraTahsilatKaydi)? onIptal;

  /// Toplam REPO'DAN gelir (`GunSonuGorunumu.araTahsilatToplamiKurus`), kart listeyi KENDİ
  /// toplamaz. Bugün ikisi aynı sonucu verirdi; ama bir tur önce ekranda tam olarak iki para
  /// rakamı çelişti ve o zaman da "ikisi zaten aynı" sanılıyordu. Tek kaynak, bedava sigorta.
  final int toplamKurus;

  /// Kurye kapsamında ad HER SATIRDA tekrarlanmaz — kimin olduğu zaten başlıkta yazıyor.
  final bool kuryeAdiYaz;

  @override
  Widget build(BuildContext context) {
    return DegerKarti(
      satirlar: [
        for (final k in kayitlar)
          DegerSatiri(
            // FARK ETİKETE EKLENİR, ayrı satıra değil: sağdaki tutar SAYILAN paradır ve bu kartın
            // ritmi "kim · saat · sayılan"dır. İkinci bir satır açmak, her tahsilatı iki kez
            // okunan bir bloğa çevirirdi. Sıfır farkta hiç yazılmaz — iskonto satırındaki desenin
            // aynısı: farksız tahsilat çoğunluktur ve "fark 0,00 ₺" her satıra cevapsız bir soru
            // eklerdi.
            //
            // İPTAL EDİLMİŞ SATIRDA FARK YAZILMAZ ve "iptal edildi" onun YERİNE geçer: fark,
            // duran bir tahsilatın kuryede ne bıraktığını anlatır ("kuryede kalan 30,00 ₺").
            // Geri alınmış bir tahsilatın yanında o cümle düpedüz yanlıştır — o para kuryede
            // kalmadı, TAMAMI kuryeye geri döndü. Kanıt kaybolmuyor: satırın kendisi (tutarı,
            // saati, kuryesi) üstü çizili olarak yerinde duruyor.
            etiket: [
              if (kuryeAdiYaz && k.kuryeAdi.isNotEmpty) k.kuryeAdi,
              araTahsilatSaati(k.occurredAt),
              if (k.iptalEdildi) 'iptal edildi' else ?araTahsilatFarki(k.diffKurus),
            ].join(', '),
            deger: sipTutar(k.countedCashKurus),
            gecersiz: k.iptalEdildi,
            onTap: k.iptalEdildi ? null : onIptal?.call(k),
            // İşaret chevron DEĞİL: chevron "detay açılır" der, buradaki dokunuş ise bir
            // DÜZELTME başlatır. `ban` (üstü çizili daire) bilinçli olarak `trash` değildir —
            // bu ekranda hiçbir şey SİLİNMİYOR (BRIEF kırmızı çizgi #2); iptal, ters kayıttır.
            sagIkon: SipIcons.ban,
          ),
        // Toplam satırı TEK kayıtta da çizilir — okuyan kişi satırları kafasında toplamasın.
        //
        // ⚠️ BU SAYI KAPANIŞ SHEET'İNDEKİ ORTA SATIR DEĞİLDİR ve ona eşit olmak zorunda da
        // değildir. İKİ AYRI EKSENDE ayrışırlar ve ikisi de bilinçlidir:
        //
        //  1. KÜME EKSENİ (ara vs ara+kapanış): burası yalnız ARA tahsilatları sayar (kapanışa
        //     bağlanmamış devirler); sheet'in düştüğü rakam ARA + KAPANIŞ devirlerini birlikte
        //     kapsar. Bir kurye hesabını kapatıp kasayı teslim ettiğinde sheet'teki sayı büyür,
        //     buradaki DEĞİŞMEZ.
        //
        //  2. ÇERÇEVE EKSENİ (gün vs pencere): bu kart TAKVİM GÜNÜ süzgeçlidir; kurye kapsamında
        //     sheet'in rakamları o kuryenin PENCERESİNDEN gelir (son hesap kapanışından beri,
        //     kapanışı yoksa alttan açık). Emre iki gün önce kapatmış ve dün patron 2.000 almışsa,
        //     BUGÜNÜN kartında hiç ara tahsilat yoktur ama sheet "Teslim edilen 2.000" der. Fark
        //     uydurma değildir: kart günü anlatır, sheet cebi.
        //
        // Bu eksen bir tur boyunca hiçbir yerde AÇIKLANMIYORDU; artık çakışmadıkları günlerde
        // sheet'e kısa bir çerçeve satırı çizilir (`_DayEndScreenState._cerceveNotu`).
        //
        // Ayrım bilinçli: bu kart kullanıcıya OLAYLARI anlatır ("saat 14:30'da Emre'den 60 ₺
        // aldım"), sheet'teki sayı ise ARİTMETİĞİ kapatır (gün nakdi − teslim edilen = beklenen).
        // Etiket o yüzden "ara tahsilat" der — "alınan toplam" deseydi iki farklı rakam aynı
        // kelimeyle anılır ve bayi hangisinin doğru olduğunu sorardı.
        //
        // SAYI, TOPLAMIN SAYDIĞI SATIRLARI sayar — `kayitlar.length` DEĞİL. İptal edilmiş satır
        // listede görünmeye devam eder ama toplama girmez; ikisini ayrı ölçütle yazsaydık kart
        // "2 tahsilat" der, altındaki tutar tek tahsilatı gösterirdi ve bayi hangisinin doğru
        // olduğunu soramazdı (bu ekranda tam olarak bu hata bir kez yaşandı).
        DegerSatiri(
          etiket: '${kayitlar.where((k) => !k.iptalEdildi).length} ara tahsilatın toplamı',
          deger: sipTutar(toplamKurus),
          toplam: true,
        ),
      ],
    );
  }
}

/// UTC damgadan TR saati ("14:30"). Kaydırma `data/tr_gun.dart`taki TEK sabitten gelir —
/// elle yazılmış ikinci bir "+3", aynı tahsilatı iki farklı güne düşürmenin kısa yoludur.
String araTahsilatSaati(DateTime utc) {
  final tr = utc.toUtc().add(kTrOffset);
  return '${tr.hour.toString().padLeft(2, '0')}:${tr.minute.toString().padLeft(2, '0')}';
}

/// Bir ara tahsilattaki FARKIN kart satırına yazılan hâli; fark sıfırsa null (satır yazılmaz).
///
/// BRIEF: "Para kayıtları düzeltilmez, telafi kaydıyla düzeltilir — eksik para KANIT olarak
/// görünür kalmalıdır." `expectedCashKurus`/`diffKurus` kayda yazılıyor ve testleniyordu ama
/// HİÇBİR EKRANDA basılmıyordu: bir ara tahsilattaki −3.000'lik fark hiçbir yerde görünmüyordu.
///
/// TON, ARA TAHSİLAT SHEET'İNİN TONUDUR ve bilinçlidir: burada "EKSİK" damgası YOKTUR. Ara
/// tahsilatta tutar SERBESTTİR (patron para üstü için kuryede para bırakabilir); her farka arıza
/// damgası basmak normal işi hatalı gösterirdi. Fark GÖSTERİLİR, "hata" diye ADLANDIRILMAZ.
String? araTahsilatFarki(int diffKurus) => switch (diffKurus) {
      < 0 => 'kuryede kalan ${sipTutar(-diffKurus)}',
      > 0 => 'beklenenden fazla ${sipTutar(diffKurus)}',
      _ => null,
    };

/// CSS `.gs-arow` — arşiv satırı. [kapsamAdi] gün hesabında "Gün hesabı", kuryede kuryenin adı.
class ArsivSatiri extends StatelessWidget {
  const ArsivSatiri({
    super.key,
    required this.kapanis,
    required this.kapsamAdi,
    required this.bugun,
    this.onTap,
    this.geriAlinmis = false,
  });

  final DayClosing kapanis;
  final String kapsamAdi;

  /// Bu kapanış SONRADAN geri alındı mı (2026-08-18). Satır LİSTEDE KALIR ama artık geçerli
  /// bir mutabakat değildir — para kayıtlarında düzeltme silmeyle değil ters kayıtla yapılır,
  /// yani hata kanıt olarak görünür kalmalı (BRIEF).
  final bool geriAlinmis;

  /// "Bugün/Dün" kelimesinin referans günü — DÜZELTİLMİŞ saatten gelmeli (`bugunTrDuzeltilmis`).
  /// Kaydın GÜNÜ düzeltilmiş saatten çıkıyor; etiketi cihaz saatinden çıkarmak, telefonu ileri
  /// kurulmuş bayiye bugün kapattığı hesabın altında "Dün 09:20" okuturdu.
  final DateTime bugun;

  final VoidCallback? onTap;

  @override
  Widget build(BuildContext context) {
    final t = context.sip;
    final k = kapanis;
    final farkli = k.countedCashKurus != null && k.diffKurus != 0;
    return SipDokun(
      onTap: onTap,
      zemin: t.surface,
      radius: SipRadius.br2,
      padding: const EdgeInsets.symmetric(horizontal: SipSpace.x2, vertical: SipSpace.xl),
      child: Row(
        children: [
          SipIkonKutu(
            // GERİ ALINMIŞ KAPANIŞ KİLİT DEĞİL, AÇIK KAPI ANLATIR: aynı ikonu bırakmak satırı
            // hâlâ kilitli bir hesap gibi gösterirdi ve bu, tam olarak ters bilgidir.
            ikon: geriAlinmis ? SipIcons.info : SipIcons.lock,
            cap: 30,
            ikonBoyut: 15,
            zemin: geriAlinmis ? t.warnSoft : t.surface2,
            renk: geriAlinmis ? t.warn : t.muted,
          ),
          const SizedBox(width: 11),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              mainAxisSize: MainAxisSize.min,
              children: [
                Row(
                  children: [
                    Flexible(
                      child: Text(
                        kapsamAdi,
                        style: SipText.metin(13.5, w: 700).copyWith(color: t.ink),
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                      ),
                    ),
                    if (geriAlinmis) ...[
                      const SizedBox(width: SipSpace.sm),
                      Container(
                        padding: const EdgeInsets.symmetric(horizontal: 7, vertical: 2),
                        decoration: BoxDecoration(
                          color: t.warnSoft,
                          borderRadius: SipRadius.brHap,
                        ),
                        child: Text(
                          'Geri alındı',
                          style: SipText.metin(10, w: 700).copyWith(color: t.warn),
                        ),
                      ),
                    ],
                  ],
                ),
                Padding(
                  padding: const EdgeInsets.only(top: 1),
                  child: Text(
                    '${gunSaatBicimi(k.occurredAt, bugun: bugun)}, ${k.deliveryCount} teslimat'
                    '${farkli ? ', ${sipTutar(k.diffKurus)} fark' : ''}',
                    style: SipText.yardimci.copyWith(color: t.muted),
                  ),
                ),
              ],
            ),
          ),
          const SizedBox(width: SipSpace.md),
          Text(
            sipTutar(k.totalCollectedKurus),
            style: SipText.tutar(13.5).copyWith(
              color: geriAlinmis ? t.muted : t.ink,
              // ÜSTÜ ÇİZİLİ: rakam artık geçerli değil ama okunabilir kalmalı — silmek yerine
              // "bu sayı iptal" demenin en kısa yolu (ara tahsilat iptalinde de aynı dil).
              decoration: geriAlinmis ? TextDecoration.lineThrough : null,
            ),
          ),
          const SizedBox(width: SipSpace.sm),
          SipIcon(SipIcons.chevR, boyut: 16, kalinlik: 2, renk: t.line2),
        ],
      ),
    );
  }
}

/// CSS `.gs-engel` — kapatmayı durduran uyarı.
///
/// ÜÇ engel vardır ve hepsi aynı kutuyu kullanır (en temelden başlayarak):
///  1. [rolEngeli] — kullanıcının bu kapsamı kapatma yetkisi yok (K2): kurye gün hesabını ya da
///     başka bir kuryenin hesabını kapatamaz.
///  2. [acikSiparis] > 0 — o kapsamda hâlâ teslim edilmemiş sipariş var.
///  3. [acikKuryeler] dolu — GÜN hesabı kapatılmak isteniyor ama kuryelerin bir kısmı
///     hesabını kapatmış, bir kısmı kapatmamış (tasarım `gunEngel`). Yarım kalmış devir.
class KapatmaEngeli extends StatelessWidget {
  const KapatmaEngeli({
    super.key,
    this.rolEngeli = false,
    this.acikSiparis = 0,
    this.acikKuryeler = const [],
  });

  final bool rolEngeli;
  final int acikSiparis;
  final List<String> acikKuryeler;

  @override
  Widget build(BuildContext context) {
    // METİN 2026-08-11'DE DEĞİŞTİ. Eskisi "siz yalnız kendi kurye hesabınızı kapatabilirsiniz"
    // diyordu ve o cümle artık YANLIŞ: kurye hiçbir hesabı kapatamıyor (kullanıcı kararı).
    // Yanlış kalsaydı ekran kuryeye var olmayan bir yol tarif eder, kurye onu arar ve
    // bulamayınca uygulamanın bozuk olduğunu düşünürdü.
    //
    // 2026-08-13'te ARA TAHSİLAT DA kuryeden alındı; metin YİNE DE DEĞİŞMİYOR ve bu bilinçli:
    // cümle kuryeye "ne YAPAMAZSIN"ı değil "ne YAPABİLİRSİN"i söylüyor ve o taraf aynı kaldı —
    // kurye hâlâ kendi dökümünü görür. Kaldırılan yolu tarif eden bir cümle eklemek ("ara
    // tahsilat da veremezsiniz"), kuryenin hiç aramadığı bir kapının kapalı olduğunu duyurmak
    // olurdu.
    final metin = rolEngeli
        ? 'Günü işletme sahibi kapatır. Siz kendi tahsilat ve teslimat dökümünüzü görürsünüz.'
        : acikSiparis > 0
            ? 'Önce açık siparişleri kapatın: $acikSiparis açık sipariş var'
            : 'Önce açık kurye hesaplarını kapatın: ${acikKuryeler.join(', ')}';
    return _EngelKutusu(metin: metin);
  }
}

/// CSS `.ys-alt` — Gün Özeti'nin alt çubuğu: kapatma engeli · toplam · eylem düğmeleri
/// (ya da kapsam kapalıysa `.gs-alt-kapali` mührü).
///
/// NEDEN EKRANDAN AYRI DOSYADA: `day_end_screen.dart` ara tahsilat akışıyla 500 satırı aşıyordu.
/// Çubuk salt gösterimdir — hiçbir yetki KARARI vermez, yalnız verilen kararı çizer. İki eylem
/// düğmesinin de görünürlüğü/etkinliği ekranın hesapladığı kapılardan gelir (K2 çift kapı: ekran
/// düğmeyi kapatır VE eylem fonksiyonu yetkiyi yeniden sorar).
class GunOzetiAltCubugu extends StatelessWidget {
  const GunOzetiAltCubugu({
    super.key,
    required this.kapsamKapali,
    required this.gunKapali,
    required this.kuryeAdi,
    required this.kapatabilir,
    required this.acikSiparis,
    required this.gunEngeli,
    required this.acikKuryeAdlari,
    required this.toplam,
    required this.onKapat,
    this.onAraTahsilat,
    this.bugunMu = true,
  });

  /// Görüntülenen gün bugün mü (2026-08-25 gün gezinmesi)? Yalnız toplam etiketini değiştirir —
  /// geçmiş bir günde "Bugünkü tahsilat" yazmak, bayiye o anki kasasını okuduğunu sandırırdı.
  final bool bugunMu;

  final bool kapsamKapali;
  final bool gunKapali;

  /// null ise gün hesabı kapsamı.
  final String? kuryeAdi;

  /// K2: kurye gün hesabını (ve başkasının hesabını) kapatamaz. false ise düğme kapalı çizilir
  /// ve NEDENİ yazılır — sessizce devre dışı bir düğme kullanıcıya hiçbir şey söylemiyordu.
  final bool kapatabilir;

  final int acikSiparis;
  final bool gunEngeli;
  final List<String> acikKuryeAdlari;
  final int toplam;
  final VoidCallback onKapat;

  /// null ise ara tahsilat düğmesi HİÇ ÇİZİLMEZ (tek kişilik bayi, gün kapsamı, KURYE ya da
  /// kapatılmış kapsam). Pasif çizmek yerine hiç çizmemek bilinçli: bu ekranın çoğu kullanıcısı
  /// tek kişilik bayidir ve onlar için "kuryeden ara tahsilat" diye bir kavram yoktur.
  ///
  /// "yetkisiz kullanıcı" 2026-08-13'te "KURYE" oldu ve bu bir kelime düzeltmesinden fazlası:
  /// ara tahsilatı artık YALNIZ yönetici alır (`yetkiler().gunuKapatma`), yani kurye — kendi
  /// kapsamında bile olsa — bu düğmeyi hiç görmez.
  final VoidCallback? onAraTahsilat;

  @override
  Widget build(BuildContext context) {
    final t = context.sip;

    if (kapsamKapali) {
      return AltCubuk(children: [
        SizedBox(
          width: double.infinity,
          child: Row(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              SipIcon(SipIcons.check, boyut: 17, kalinlik: 2.6, renk: t.ok),
              const SizedBox(width: SipSpace.md),
              Flexible(
                child: Text(
                  gunKapali
                      ? 'Gün kapatıldı, arşivde'
                      : '$kuryeAdi hesabı kapatıldı, arşivde',
                  style: SipText.metin(13.5, w: 800).copyWith(color: t.ok),
                ),
              ),
            ],
          ),
        ),
      ]);
    }

    // ÜÇ bağımsız kapı, en temelden başlayarak: rol (bu kapsamı kapatma yetkisi), açık sipariş
    // (her kapsamda) ve yarım kalmış kurye devri (yalnız gün hesabında).
    final engel = !kapatabilir || acikSiparis > 0 || gunEngeli;
    return AltCubuk(children: [
      if (engel)
        SizedBox(
          width: double.infinity,
          child: KapatmaEngeli(
            rolEngeli: !kapatabilir,
            acikSiparis: kapatabilir ? acikSiparis : 0,
            acikKuryeler:
                !kapatabilir || acikSiparis > 0 ? const [] : acikKuryeAdlari,
          ),
        ),
      // Toplam, ara tahsilat düğmesi varken DARALIR: üç öğe 150 punto etiketle yan yana
      // sığmıyordu ve tutar kırpılıyordu (para asla kırpılmaz).
      SizedBox(
        width: onAraTahsilat == null ? 150 : 108,
        child: AltCubukToplam(
          etiket: kuryeAdi == null
              ? (bugunMu ? 'Bugünkü tahsilat' : 'Günün tahsilatı')
              : '$kuryeAdi için tahsilat',
          deger: sipTutar(toplam),
        ),
      ),
      // Ara tahsilat İKİNCİLDİR: günün asıl eylemi kapatmaktır ve iki birincil düğme
      // hangisinin "doğru" olduğunu belirsizleştirirdi.
      if (onAraTahsilat != null)
        SipButon(
          etiket: 'Ara Tahsilat',
          ikon: SipIcons.hand,
          tur: SipButonTuru.ikincil,
          genisle: false,
          yatayPadding: SipSpace.xl,
          onTap: onAraTahsilat,
        ),
      SipButon(
        etiket: kuryeAdi == null ? 'Günü Kapat' : 'Hesabı Kapat',
        ikon: SipIcons.lock,
        genisle: false,
        yatayPadding: onAraTahsilat == null ? SipSpace.x5 : SipSpace.xl,
        onTap: engel ? null : onKapat,
      ),
    ]);
  }
}

class _EngelKutusu extends StatelessWidget {
  const _EngelKutusu({required this.metin});

  final String metin;

  @override
  Widget build(BuildContext context) {
    final t = context.sip;
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: SipSpace.xl, vertical: SipSpace.lg),
      decoration: BoxDecoration(color: t.warnSoft, borderRadius: SipRadius.br1),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Padding(
            padding: const EdgeInsets.only(top: 1),
            child: SipIcon(SipIcons.alert, boyut: 14, kalinlik: 2.2, renk: t.warn),
          ),
          const SizedBox(width: SipSpace.md),
          Expanded(
            child: Text(
              metin,
              style: SipText.metin(12, w: 600, h: 1.45).copyWith(color: t.warn),
            ),
          ),
        ],
      ),
    );
  }
}
