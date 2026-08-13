// Çekmecenin DURUM ve KONTROL parçaları — panel `cekmece.dart`ta, gezinme satırları orada.
//
// AYRI DOSYA: çekmece 2026-08-13'te yeniden tasarlanınca üç bölgeye ayrıldı (kimlik+durum ·
// hedefler · kişisel kontroller) ve tek dosya 500 satırı aşıyordu. Bölme çizgisi rastgele
// değil: burada duran hiçbir şey BİR YERE GÖTÜRMEZ — durum gösterir ya da yerinde bir tercihi
// çevirir. `cekmece.dart` ise yalnız hedefleri bilir.

import 'dart:async';

import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';

import '../../theme/components/atoms.dart';
import '../../theme/icons.dart';
import '../../theme/tokens.dart';
import '../../theme/typography.dart';
import '../cagri/arayan_tanima_ayari.dart';

/// Çekmecenin DURUM ŞERİDİ — "verim sunucuya gitti mi?" sorusunun tek cümlelik cevabı.
///
/// NEDEN VAR (2026-08-13 yeniden tasarımı): bu bilgi eskiden başlıkta, rol yazısının yanında,
/// %55 opaklıkta minik gri bir ek cümleydi ("Yönetici · senkron 10:32"). Offline-first bir para
/// uygulamasında bayinin en çok merak ettiği şey bu ve okunacak en son yerdeydi. Karantinaya
/// düşmüş kayıt varsa çekmecede HİÇBİR izi yoktu.
///
/// METİN İDDİA ETMEZ (deponun yazılı kuralı): "veriler güncel" DEMEZ — güncelliği bilemez,
/// yalnız son senkronun ANINI söyler. "Güncel" demek, sunucuda bekleyen bir değişiklik varken
/// de doğru görünürdü.
class CekmeceDurumSeridi extends StatelessWidget {
  const CekmeceDurumSeridi({
    super.key,
    required this.sonSenkron,
    required this.karantina,
    this.onKarantina,
  });

  final DateTime? sonSenkron;

  /// Sunucunun kabul etmediği ve cihazda bekleyen kayıt sayısı.
  final int karantina;

  /// Karantina dökümünü açar; null ise satır dokunulamaz (döküm ekranı henüz yok).
  final VoidCallback? onKarantina;

  static String saat(DateTime d) =>
      '${d.hour.toString().padLeft(2, '0')}:${d.minute.toString().padLeft(2, '0')}';

  @override
  Widget build(BuildContext context) {
    final t = context.sip;

    // KARANTİNA HER ŞEYİN ÖNÜNDE: eylem gerektiren tek durum odur. Senkron saati o an
    // ikincildir — "10:32'de senkron oldum" demek, üç kaydın reddedildiğini gizlerdi.
    final (renk, metin) = karantina > 0
        ? (t.danger, '$karantina kayıt gönderilemedi')
        : sonSenkron == null
            ? (SipTokens.onHeroSoft, 'Henüz senkron olmadı')
            : (t.ok, 'Son senkron ${saat(sonSenkron!)}');

    final govde = Container(
      padding: const EdgeInsets.symmetric(horizontal: 13, vertical: 11),
      decoration: BoxDecoration(
        color: SipTokens.onHeroFill,
        borderRadius: SipRadius.br2,
      ),
      child: Row(
        children: [
          Container(
            width: 8,
            height: 8,
            decoration: BoxDecoration(color: renk, shape: BoxShape.circle),
          ),
          const SizedBox(width: SipSpace.md),
          Expanded(
            child: Text(
              metin,
              style: SipText.metin(12, w: 600).copyWith(color: SipTokens.onHeroStrong),
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
            ),
          ),
          if (karantina > 0 && onKarantina != null)
            const SipIcon(SipIcons.chevR,
                boyut: 15, kalinlik: 2, renk: SipTokens.onHeroFaint),
        ],
      ),
    );

    if (karantina > 0 && onKarantina != null) {
      return SipDokun(
        onTap: onKarantina,
        zemin: Colors.transparent,
        radius: SipRadius.br2,
        child: govde,
      );
    }
    return govde;
  }
}

/// Çekmecenin ayağındaki KOMPAKT ANAHTAR ÇİFTİ — koyu tema + arayan tanıma.
///
/// ══ NEDEN NAV SATIRI DEĞİL, NEDEN AYAKTA ══════════════════════════════════════════════════
/// İlk denemede bunlar gezinme satırlarıyla AYNI biçimde, aynı sütunda duruyordu. İki sorun
/// vardı ve ikisi de gerçek:
///
///  1. BİÇİM YALAN SÖYLÜYORDU. Chevron'lu bir satır "sana bir yer açacağım" der; anahtarlı
///     satır hiçbir yere gitmez, yerinde bir durumu çevirir. Aynı görünümde alt alta dizilmiş
///     dokuz satırın hangisinin nereye götürdüğü ancak sağ uçtaki işarete bakılarak anlaşılıyordu.
///
///  2. YER YANLIŞTI. Çekmece tam boy bir paneldir ve telefonu tutan başparmak ALTTA durur;
///     üst üçte bir, tek elle en zor erişilen bölgedir. Sık çevrilen iki tercihi oraya koymak,
///     her dokunuş için tutuşu değiştirmek demekti. Ayak bölgesi başparmağın dinlendiği yerdir.
///
/// İkisi de CİHAZ tercihidir (senkrona girmez) ve kuryede de açıktır: kapatılan hep DÜKKÂN
/// VERİSİDİR, kişinin kendi telefonu değil.
class CekmeceAnahtarlari extends StatelessWidget {
  const CekmeceAnahtarlari({super.key, this.koyuTema, this.onTema});

  final ValueListenable<bool>? koyuTema;
  final ValueChanged<bool>? onTema;

  @override
  Widget build(BuildContext context) {
    return Row(
      children: [
        if (koyuTema != null && onTema != null)
          Expanded(
            child: ValueListenableBuilder<bool>(
              valueListenable: koyuTema!,
              builder: (context, koyu, _) => CekmeceAnahtarKutusu(
                ikon: SipIcons.moon,
                etiket: 'Koyu Tema',
                acik: koyu,
                onDegis: () => onTema!(!koyu),
              ),
            ),
          ),
        if (koyuTema != null && onTema != null) const SizedBox(width: SipSpace.md),
        const Expanded(child: CekmeceArayanTanimaKutusu()),
      ],
    );
  }
}

/// Tek anahtar kutusu: ikon + kısa etiket. TEK SATIR.
///
/// KÜÇÜLTÜLDÜ (kullanıcı geri bildirimi 2026-08-13: "gözüme büyük göründü"). İlk hâlinde
/// altında ikinci bir satır ("Açık" / "Kapalı") vardı ve kutu 62 punto yüksekliğindeydi.
/// Durumu ZATEN DOLGU SÖYLÜYOR: açıkken accent, kapalıyken sönük hero dolgusu — sözcük,
/// rengin söylediğini tekrar ediyordu. Tek satıra inince kutu ~44 punto oldu ve dokunma
/// hedefi hâlâ 48dp'nin üstünde (dikey iç boşluk 13).
///
/// ERİŞİLEBİLİRLİK KAYBI YOK: durum `Semantics(toggled:)` ile ekran okuyucuya bildiriliyor —
/// yani bilgi renge DEĞİL semantiğe bağlı; renk yalnız görsel kısayol.
class CekmeceAnahtarKutusu extends StatelessWidget {
  const CekmeceAnahtarKutusu({
    super.key,
    required this.ikon,
    required this.etiket,
    required this.acik,
    required this.onDegis,
  });

  final String ikon;
  final String etiket;
  final bool acik;
  final VoidCallback onDegis;

  @override
  Widget build(BuildContext context) {
    final t = context.sip;
    return Semantics(
      toggled: acik,
      button: true,
      child: SipDokun(
        onTap: onDegis,
        // AÇIK HÂL RENKLE SÖYLENİR: küçük bir kutuda 40 punto genişliğinde bir anahtar rayı
        // yer kaplar ve etiketi kırpardı. Dolgu + ikon rengi aynı bilgiyi taşır.
        zemin: acik ? t.accent : SipTokens.onHeroFill,
        basiliZemin: acik ? t.accent : SipTokens.onHeroFill2,
        radius: SipRadius.br2,
        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 13),
        child: Row(
          children: [
            SipIcon(
              ikon,
              boyut: 16,
              kalinlik: 2,
              renk: acik ? t.accentInk : SipTokens.onHeroMid,
            ),
            const SizedBox(width: 8),
            Expanded(
              child: Text(
                etiket,
                style: SipText.metin(12, w: 700).copyWith(
                  color: acik ? t.accentInk : SipTokens.onHeroStrong,
                ),
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
              ),
            ),
          ],
        ),
      ),
    );
  }
}

/// Arayan tanıma anahtarı — durumunu `arayanTanimaDeposu`ndan okur.
///
/// Ayarlar → Uygulama sayfasındaki `ArayanTanimaSatiri` ile AYNI kaynağı kullanır: iki görünüm,
/// tek doğru kaynak. Depo cihaz-yerel bir dosyadır (senkronla değişmez), o yüzden tek atış
/// okuma burada doğrudur.
class CekmeceArayanTanimaKutusu extends StatefulWidget {
  const CekmeceArayanTanimaKutusu({super.key});

  @override
  State<CekmeceArayanTanimaKutusu> createState() => _CekmeceArayanTanimaKutusuState();
}

class _CekmeceArayanTanimaKutusuState extends State<CekmeceArayanTanimaKutusu> {
  /// null → tercih henüz okunmadı; varsayılan (AÇIK) çizilir ki kutu zıplamasın.
  bool? _acik;

  @override
  void initState() {
    super.initState();
    unawaited(_yukle());
  }

  Future<void> _yukle() async {
    final acik = await arayanTanimaDeposu.acikMi();
    if (mounted) setState(() => _acik = acik);
  }

  Future<void> _cevir() async {
    final yeni = !(_acik ?? true);
    setState(() => _acik = yeni);
    await arayanTanimaDeposu.yaz(yeni);
  }

  @override
  Widget build(BuildContext context) => CekmeceAnahtarKutusu(
        ikon: SipIcons.phone,
        etiket: 'Arayan Tanıma',
        acik: _acik ?? true,
        onDegis: _cevir,
      );
}
