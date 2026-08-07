// Müşteri detayının üst blokları — CSS `.md-kart` (koyu iletişim kartı), `.md-konum`,
// `.md-bal*` (bakiye kartı), `.md-akslar`/`.mdakt` (hızlı eylem ızgarası).
// Kaynak: s-musteriler.jsx `MusteriDetay`.
//
// Hero (koyu) blokların içindeki metin/ikon rengi `DefaultTextStyle`tan miras alınır; bu yüzden
// bloklar `SipTokens.onHero` ile sarılır ve içeride ayrıca renk verilmez.

import 'package:flutter/material.dart';

import '../../theme/components/atoms.dart';
import '../../theme/icons.dart';
import '../../theme/tokens.dart';
import '../../theme/typography.dart';

/// CSS `.md-kart` — adres + konum çipi + telefon + 3'lü iletişim düğmesi.
class MusteriHeroKart extends StatelessWidget {
  const MusteriHeroKart({
    super.key,
    required this.adres,
    required this.telefon,
    required this.koordinat,
    required this.onKonumAl,
    required this.onAra,
    required this.onWhatsapp,
    required this.onKonum,
    this.konumCalisiyor = false,
    this.onKonumGuncelle,
  });

  /// Birincil adresin gösterim metni; null ise adres bloğu hiç çizilmez.
  final String? adres;
  final String telefon;

  /// "36.8969, 30.7133" — null ise konum alınmamıştır.
  final String? koordinat;

  /// Konum yokken çipe dokunulunca (adres varsa) çağrılır — ADRESTEN aday arar.
  final VoidCallback onKonumAl;

  /// Konum VARKEN çipe dokunulunca çağrılır — CİHAZIN bulunduğu noktayı yazar. Kurye kapının
  /// önündeyken adresten türetilmiş yaklaşık pini gerçeğe oturtmanın tek yolu budur.
  /// null ise kayıtlı çip tıklanmaz kalır (eski davranış).
  final VoidCallback? onKonumGuncelle;

  /// Adres aranıyor ya da cihaz konumu okunuyor.
  final bool konumCalisiyor;

  final VoidCallback onAra;
  final VoidCallback onWhatsapp;
  final VoidCallback onKonum;

  @override
  Widget build(BuildContext context) {
    final t = context.sip;
    return Container(
      margin: const EdgeInsets.only(top: SipSpace.xs),
      padding: const EdgeInsets.all(18),
      decoration: BoxDecoration(color: t.hero, borderRadius: SipRadius.br3),
      child: DefaultTextStyle(
        style: TextStyle(color: SipTokens.onHero, fontFamily: sipFontBody),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            if (adres != null)
              Row(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  const Padding(
                    padding: EdgeInsets.only(top: 2),
                    child: SipIcon(SipIcons.pin,
                        boyut: 17, kalinlik: 2, renk: SipTokens.onHeroMid),
                  ),
                  const SizedBox(width: 9),
                  Expanded(
                    child: Text(
                      adres!,
                      style: SipText.metin(14.5, w: 600, h: 1.45)
                          .copyWith(color: SipTokens.onHero),
                    ),
                  ),
                ],
              ),
            if (adres != null)
              _KonumCipi(
                koordinat: koordinat,
                onKonumAl: onKonumAl,
                onKonumGuncelle: onKonumGuncelle,
                calisiyor: konumCalisiyor,
              ),
            Padding(
              padding: EdgeInsets.only(left: adres != null ? 26 : 0, top: SipSpace.md),
              child: Text(
                telefon,
                style: SipText.tutar(13, w: 500).copyWith(color: SipTokens.onHeroMid),
              ),
            ),
            const SizedBox(height: 15),
            Row(
              children: [
                _IletDugmesi(ikon: SipIcons.phone, etiket: 'Ara', onTap: onAra),
                const SizedBox(width: SipSpace.md),
                _IletDugmesi(ikon: SipIcons.wa, etiket: 'WhatsApp', onTap: onWhatsapp),
                const SizedBox(width: SipSpace.md),
                _IletDugmesi(ikon: SipIcons.pin, etiket: 'Konum', onTap: onKonum),
              ],
            ),
          ],
        ),
      ),
    );
  }
}

/// CSS `.md-konum` — konum kayıtlıysa bilgi çipi, değilse UYARI renginde tıklanır çip.
class _KonumCipi extends StatelessWidget {
  const _KonumCipi({
    required this.koordinat,
    required this.onKonumAl,
    required this.onKonumGuncelle,
    required this.calisiyor,
  });

  final String? koordinat;
  final VoidCallback onKonumAl;
  final VoidCallback? onKonumGuncelle;
  final bool calisiyor;

  @override
  Widget build(BuildContext context) {
    final varMi = koordinat != null;
    return Padding(
      padding: const EdgeInsets.only(top: 9),
      child: Align(
        alignment: Alignment.centerLeft,
        child: SipDokun(
          // Çalışırken dokunuş YUTULUR: iki paralel arama kotayı iki kez yakar ve hangi sonucun
          // geldiği belirsizleşir.
          onTap: calisiyor ? null : (varMi ? onKonumGuncelle : onKonumAl),
          zemin: varMi
              ? SipTokens.onHeroFill2
              // CSS: rgba(255,215,154,.14) — hero üstü uyarı tonu.
              : SipTokens.onHeroWarn.withValues(alpha: 0.14),
          basiliZemin: SipTokens.onHeroFill2,
          radius: SipRadius.brHap,
          padding: const EdgeInsets.symmetric(horizontal: SipSpace.xl, vertical: 7),
          child: Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              if (calisiyor)
                Text('Konum alınıyor…',
                    style: SipText.metin(12, w: 600).copyWith(color: SipTokens.onHeroStrong))
              else if (varMi) ...[
                const SipIcon(SipIcons.check, boyut: 13, kalinlik: 2.6, renk: SipTokens.heroDot),
                const SizedBox(width: SipSpace.sm),
                Text('Konum kayıtlı · ',
                    style: SipText.metin(12, w: 600).copyWith(color: SipTokens.onHeroStrong)),
                Flexible(
                  child: Text(koordinat!,
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: SipText.tutar(12, w: 700).copyWith(color: SipTokens.onHeroStrong)),
                ),
                // Kayıtlı konum artık DEĞİŞTİRİLEBİLİR: adresten türetilen pin sokağı bulur,
                // kapıyı bulmaz — kurye kapının önünde bunu düzeltebilmeli.
                if (onKonumGuncelle != null) ...[
                  const SizedBox(width: SipSpace.sm),
                  const SipIcon(SipIcons.sync, boyut: 12, kalinlik: 2.2, renk: SipTokens.onHeroMid),
                ],
              ] else ...[
                Text('Konum alınmamış — ',
                    style: SipText.metin(12, w: 600).copyWith(color: SipTokens.onHeroStrong)),
                Text('Konum Al',
                    style: SipText.metin(12, w: 800).copyWith(color: SipTokens.onHeroWarn)),
              ],
            ],
          ),
        ),
      ),
    );
  }
}

/// CSS `.md-ilet button` — hero üstünde 42 yüksek hap düğme.
class _IletDugmesi extends StatelessWidget {
  const _IletDugmesi({required this.ikon, required this.etiket, required this.onTap});

  final String ikon;
  final String etiket;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return Expanded(
      child: SipDokun(
        onTap: onTap,
        zemin: SipTokens.onHeroFill2,
        basiliZemin: SipTokens.onHeroFill2,
        radius: SipRadius.brHap,
        child: SizedBox(
          height: 42,
          child: Row(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              SipIcon(ikon, boyut: 16, kalinlik: 2.1, renk: SipTokens.onHero),
              const SizedBox(width: SipSpace.sm),
              Flexible(
                child: Text(
                  etiket,
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: SipText.metin(12.5, w: 700).copyWith(color: SipTokens.onHero),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

/// CSS `.md-bakiye` — İNCE bakiye şeridi: "Bakiye" + tutar/durum, bakiyeye göre soft zemin.
///
/// Tasarım (s-musteriler.jsx:113-116) eski 34 px'lik hero kartını bu şeride indirdi; `.md-bal*`
/// CSS'te kalmış ölü sınıflar. Bakiye 0'da tutar yerine "Temiz" yazılır ve zemin — borç/alacak
/// ayrımı olmadığı için — YEŞİL soft kalır.
class MusteriBakiyeKarti extends StatelessWidget {
  const MusteriBakiyeKarti({super.key, required this.kurus});

  final int kurus;

  @override
  Widget build(BuildContext context) {
    final t = context.sip;
    return Container(
      margin: const EdgeInsets.only(top: SipSpace.lg),
      padding: const EdgeInsets.symmetric(horizontal: SipSpace.x2, vertical: 11),
      width: double.infinity,
      decoration: BoxDecoration(
        color: kurus == 0 ? t.okSoft : t.bakiyeSoft(kurus),
        borderRadius: SipRadius.br2,
      ),
      child: Row(
        children: [
          Text(
            'Bakiye',
            style: SipText.metin(12, w: 600).copyWith(color: t.ink2),
          ),
          const SizedBox(width: 9), // CSS `.md-bakiye { gap: 9px }`
          Flexible(
            child: Text(
              kurus == 0
                  ? 'Temiz'
                  : '${sipTutar(kurus.abs())} ${SipTokens.bakiyeEtiket(kurus)}',
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
              style: SipText.tutar(14).copyWith(color: t.bakiyeRenk(kurus)),
            ),
          ),
        ],
      ),
    );
  }
}

/// CSS `.md-akslar` + `.mdakt` — hızlı eylem ızgarası (verilen eylemler eşit paylaşır).
class MusteriAksiyonlari extends StatelessWidget {
  const MusteriAksiyonlari({super.key, required this.eylemler});

  final List<MusteriEylemi> eylemler;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.only(top: SipSpace.xl),
      child: Row(
        children: [
          for (var i = 0; i < eylemler.length; i++) ...[
            if (i > 0) const SizedBox(width: SipSpace.md),
            Expanded(child: _AksiyonKutusu(eylem: eylemler[i])),
          ],
        ],
      ),
    );
  }
}

class MusteriEylemi {
  const MusteriEylemi({required this.ikon, required this.etiket, required this.onTap});

  final String ikon;
  final String etiket;
  final VoidCallback onTap;
}

/// TEHLİKELİ EYLEMLER — kara listeye alma/çıkarma ve müşteriyi silme.
///
/// NEDEN EN ALTTA VE AYRI BİR BAŞLIK ALTINDA: bu iki eylem hızlı eylem ızgarasının (Sipariş /
/// Tahsilat) yanına konsaydı, günde onlarca kez basılan düğmelerin komşusu olurlardı. Ayırmak
/// yanlış dokunuşu ucuzlatmaz — pahalılaştırır, kasten.
///
/// Silme onay ALIR (çağıran tarafta), kara liste almaz: kara liste tek dokunuşla geri alınabilir,
/// silme ise ürün olarak geri alınamaz.
class MusteriTehlikeliEylemler extends StatelessWidget {
  const MusteriTehlikeliEylemler({
    super.key,
    required this.karaListede,
    required this.karaListeEtiketi,
    required this.silEtiketi,
    required this.onKaraListe,
    required this.onSil,
  });

  final bool karaListede;
  final String karaListeEtiketi;
  final String silEtiketi;
  final VoidCallback onKaraListe;
  final VoidCallback onSil;

  @override
  Widget build(BuildContext context) {
    final t = context.sip;
    return Padding(
      padding: const EdgeInsets.only(top: SipSpace.x3),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            'TEHLİKELİ İŞLEMLER',
            style: SipText.metin(10.5, w: 700).copyWith(color: t.muted, letterSpacing: .6),
          ),
          const SizedBox(height: SipSpace.md),
          // Kara listeye ALMA uyarı, ÇIKARMA nötr renktedir: geri alma bir tehlike değildir ve
          // kırmızı bir "çıkar" düğmesi kullanıcıya yanlış şeyi yaptığını söyler.
          _TehlikeSatiri(
            ikon: SipIcons.ban,
            etiket: karaListeEtiketi,
            renk: karaListede ? t.ink2 : t.warn,
            onTap: onKaraListe,
          ),
          const SizedBox(height: SipSpace.sm),
          _TehlikeSatiri(
            ikon: SipIcons.trash,
            etiket: silEtiketi,
            renk: t.danger,
            onTap: onSil,
          ),
        ],
      ),
    );
  }
}

class _TehlikeSatiri extends StatelessWidget {
  const _TehlikeSatiri({
    required this.ikon,
    required this.etiket,
    required this.renk,
    required this.onTap,
  });

  final String ikon;
  final String etiket;
  final Color renk;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final t = context.sip;
    return SipDokun(
      onTap: onTap,
      zemin: t.surface,
      radius: SipRadius.br2,
      padding: const EdgeInsets.symmetric(horizontal: SipSpace.x2, vertical: 13),
      child: Row(
        children: [
          SipIcon(ikon, boyut: 16, kalinlik: 2.2, renk: renk),
          const SizedBox(width: SipSpace.md),
          Expanded(
            child: Text(
              etiket,
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
              style: SipText.metin(13, w: 600).copyWith(color: renk),
            ),
          ),
        ],
      ),
    );
  }
}

class _AksiyonKutusu extends StatelessWidget {
  const _AksiyonKutusu({required this.eylem});

  final MusteriEylemi eylem;

  @override
  Widget build(BuildContext context) {
    final t = context.sip;
    return SipDokun(
      onTap: eylem.onTap,
      zemin: t.surface,
      radius: SipRadius.br2,
      padding: const EdgeInsets.symmetric(horizontal: SipSpace.xs, vertical: SipSpace.xl),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          SipIcon(eylem.ikon, boyut: 20, kalinlik: 2.3, renk: t.accent),
          const SizedBox(height: SipSpace.sm),
          Text(
            eylem.etiket,
            maxLines: 1,
            overflow: TextOverflow.ellipsis,
            style: SipText.metin(10.5, w: 600).copyWith(color: t.ink2),
          ),
        ],
      ),
    );
  }
}
