// Ana ekranın bento özet ızgarası — s-ana.jsx + Sipario.html `.bento*`.
//
// `ana_ekran.dart`'tan ayrıldı (500 satır sınırı). Dört kutu: Açık Sipariş · Bugün Kasa ·
// Açık Veresiye · Son Arama. İlk üçünün rakamı `ana_ozet.dart`taki read-model'den, dördüncüsü
// `cagri/cagri_gunlugu.dart`taki [sonAramaAkisi]'ndan gelir — demo sabiti yok.

import 'package:flutter/material.dart';

import '../../data/app_database.dart';
import '../../theme/components/atoms.dart';
import '../../theme/tokens.dart';
import '../../theme/typography.dart';
import '../cagri/cagri_gunlugu.dart';
import '../cagri/cagri_model.dart';
import 'alt_nav.dart';
import 'ana_ozet.dart';

/// CSS `.bento` — iki sütunlu özet ızgarası.
class AnaBento extends StatelessWidget {
  const AnaBento({
    super.key,
    required this.db,
    required this.ozet,
    required this.onSekme,
    required this.onArama,
    required this.onBorclular,
    this.borclulariGoster = true,
  });

  final AppDatabase db;
  final AnaOzet ozet;
  final ValueChanged<SipSekme> onSekme;
  final ValueChanged<AramaKaydi> onArama;

  /// "Borçlular" kutusu — borçlu müşteriler ekranını açar. Ekranı KABUK açar (yazma yetkisi
  /// ve rol orada bilinir); bento yalnız niyeti bildirir.
  final VoidCallback onBorclular;

  /// Kutu ÇİZİLSİN Mİ (`yetkiler().toplamBorclulariGorme`).
  ///
  /// ⚠️ 2026-08-09'da düzeltilen kusur: kapı YALNIZ dokunuşta vardı (`home_shell._borclularAc`
  /// bir toast gösterip dönüyordu), ama kutu kuryeye ÇİZİLMEYE devam ediyordu — yani toplam
  /// borç tutarı ve borçlu müşteri sayısı ekranda okunuyordu. "Erişim kapalı, bilgi açık"
  /// bir kısıtlama değildir: rakam zaten sızdıysa listeyi engellemenin bir anlamı kalmaz.
  /// Yetki kapalıysa kutu HİÇ çizilmez ve "Son Arama" satırı tek başına genişler — bu,
  /// BRIEF'in "yetkisi olmayan adım hiç görünmesin" ilkesiyle aynı çizgidedir.
  final bool borclulariGoster;

  @override
  Widget build(BuildContext context) {
    final o = ozet;
    return Column(
      children: [
        IntrinsicHeight(
          child: Row(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              Expanded(
                child: _Kutu(
                  etiket: 'Açık Sipariş',
                  deger: sipSayi(o.acikSiparis),
                  alt: o.acikSiparis > 0 ? 'teslim bekliyor' : 'hepsi tamam',
                  birincil: true,
                  onTap: () => onSekme(SipSekme.siparis),
                ),
              ),
              const SizedBox(width: SipSpace.lg),
              Expanded(
                child: _Kutu(
                  etiket: 'Bugün Kasa',
                  deger: sipTutar(o.bugunTahsilatKurus),
                  kucuk: true,
                  alt: '${o.bugunTeslim} teslimat',
                  // Tasarım koşulsuz gün sonuna gider (`s-ana.jsx:35`). Gün Özeti sekmesi artık
                  // kuryede de açık (alt navigasyon 5 yuva) — rol dalı gerekmiyor.
                  onTap: () => onSekme(SipSekme.gunSonu),
                ),
              ),
            ],
          ),
        ),
        const SizedBox(height: SipSpace.lg),
        IntrinsicHeight(
          child: Row(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              if (borclulariGoster)
                Expanded(
                  child: _Kutu(
                  // "Açık Veresiye" → "Borçlular" (kullanıcı kararı 2026-07-29). Rakam aynı
                  // (tahsil edilmemiş toplam) ama kutunun VAADİ değişti: dokununca müşteriler
                  // sekmesine değil, yalnız borçluları ve ödenmemiş siparişlerini listeleyen
                  // ekrana gider. Eski hedef bayiyi borcu olmayan yüzlerce kaydın arasına
                  // bırakıyordu — kutuya dokunmanın tek sebebi "kim borçlu" sorusudur.
                  etiket: 'Borçlular',
                  deger: sipTutar(o.acikVeresiyeKurus),
                  kucuk: true,
                  // KOŞULSUZ danger — tasarım sınıfı koşulsuz veriyor (`s-ana.jsx:42`
                  // `bento-v kucuk tabular eksi`). Kırmızı burada "alarm" değil KATEGORİ
                  // rengidir: bu kutu tahsil edilmemiş parayı sayar, tutarı ne olursa olsun.
                  // Koşullu yapılsaydı rakam veri yüklenirken nötrden kırmızıya atlıyordu.
                  eksi: true,
                  alt: o.borcluMusteri > 0
                      ? '${o.borcluMusteri} borçlu müşteri'
                      : 'tüm hesaplar temiz',
                  onTap: onBorclular,
                  ),
                ),
              if (borclulariGoster) const SizedBox(width: SipSpace.lg),
              Expanded(child: _SonAramaKutusu(db: db, onArama: onArama)),
            ],
          ),
        ),
      ],
    );
  }
}

/// CSS `.bento-k` — 108 yüksek düz kart; [birincil] accent dolgulu.
class _Kutu extends StatelessWidget {
  const _Kutu({
    required this.etiket,
    required this.deger,
    required this.alt,
    required this.onTap,
    this.birincil = false,
    this.kucuk = false,
    this.eksi = false,
    this.altEksi = false,
    this.tekSatir = false,
    this.sonuk = false,
  });

  final String etiket;
  final String deger;
  final String alt;
  final VoidCallback onTap;
  final bool birincil;
  final bool kucuk;

  /// DEĞER satırı danger olur (CSS `.bento-v.eksi`).
  final bool eksi;

  /// ALT satır danger olur. Sönüklük (`opacity: .6`) burada UYGULANMAZ: bu bayrağın tek işi
  /// dikkat çekmek; %60'a indirilmiş bir kırmızı sinyali yutardı.
  final bool altEksi;

  /// Değer sığmazsa küçültülmez, ÜÇ NOKTAYLA kesilir (CSS `.bento-v` üstündeki
  /// `text-overflow: ellipsis` — rakam değil AD taşıyan kutular içindir).
  final bool tekSatir;

  /// Verisi olmayan kutu (henüz arama yok) — değer sönük yazılır.
  final bool sonuk;

  @override
  Widget build(BuildContext context) {
    final t = context.sip;
    final murekkep = birincil ? t.accentInk : t.ink;
    return SipDokun(
      onTap: onTap,
      zemin: birincil ? t.accent : t.surface,
      basiliZemin: birincil ? t.accent : t.surface2,
      radius: SipRadius.br3,
      padding: const EdgeInsets.all(SipSpace.x3),
      child: ConstrainedBox(
        constraints: const BoxConstraints(minHeight: 108),
        child: Column(
          // ORTALI DÜZEN (kullanıcı isteği 2026-07-29: "yazılar ve rakamlar çok dağınık").
          // Sola dayalı hâlde her kutunun etiketi, rakamı ve alt satırı FARKLI uzunlukta
          // olduğu için ızgara dört ayrı sol kenar üretiyordu; göz hangi rakamın hangi
          // etikete ait olduğunu her seferinde yeniden kuruyordu. Ortalama, dört kutuyu
          // tek bir dikey eksende topluyor.
          crossAxisAlignment: CrossAxisAlignment.center,
          children: [
            Text(
              etiket,
              textAlign: TextAlign.center,
              style: SipText.bentoEtiket
                  .copyWith(color: murekkep.withValues(alpha: 0.72)),
            ),
            const Spacer(),
            Builder(builder: (_) {
              final stil = (kucuk ? SipText.bentoDegerKucuk : SipText.bentoDeger).copyWith(
                color: eksi && !birincil
                    ? t.danger
                    : (sonuk ? murekkep.withValues(alpha: 0.35) : murekkep),
              );
              if (tekSatir) {
                return Text(deger,
                    style: stil,
                    textAlign: TextAlign.center,
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    softWrap: false);
              }
              return FittedBox(
                fit: BoxFit.scaleDown,
                alignment: Alignment.center,
                child: Text(deger, style: stil, maxLines: 1),
              );
            }),
            const SizedBox(height: 2),
            Text(
              alt,
              textAlign: TextAlign.center,
              style: SipText.bentoAlt.copyWith(
                color: altEksi && !birincil
                    ? t.danger
                    : murekkep.withValues(alpha: 0.6),
              ),
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
            ),
          ],
        ),
      ),
    );
  }
}

/// 4. bento kutusu — "Son Arama" (`s-ana.jsx:45`). Yalnız EN SON aramayı gösterir.
///
/// Kayıt yoksa kutu SÖNÜK çizilir ve dokunma bir şey yapmaz — uydurma numara basılmaz.
///
/// CEVAPSIZ ALT SATIRI KIRMIZIDIR — geri alma. `Sipario.html`de `.bento-alt.eksi` kuralı YOK
/// (yalnız `.bento-v.eksi`, `.kd-fark.eksik` ve artık ölü kupon sınıfları tanımlı), ama
/// `s-ana.jsx:48` bu değiştiriciyi cevapsızda koşullu olarak EKLİYOR. Karar (lead, 2026-07-26):
/// bu eksik bir CSS kuralı, bilinçli bir tercih değil — `eksi` tasarımın sözlüğünde "danger"
/// demek ve yazar koşulu silmemiş. "CSS bağlayıcıdır" kuralı ölçü/renk ÇATIŞMALARI içindir;
/// burada CSS sessiz, çatışma yok.
/// Ürün gerekçesi: bu uygulamanın varlık sebebi esnafın sipariş çağrısını kaçırmaması —
/// cevapsız çağrı "kaçırılmış sipariş" demektir, dikkat çekmesi gereken şey tam da budur.
///
/// Renk doğrudan `t.danger`: bento kartı açık gövdede `surface` üstünde durur, tıpkı
/// `.bento-v.eksi`in `var(--danger)`ı doğrudan kullanması gibi (HERO koyu kartlarda gereken
/// açık ton buraya gerekmez).
class _SonAramaKutusu extends StatefulWidget {
  const _SonAramaKutusu({required this.db, required this.onArama});

  final AppDatabase db;
  final ValueChanged<AramaKaydi> onArama;

  /// Tasarımda yalnız `cevapsiz`/diğer ayrımı vardı; `giden` de kendi adıyla yazılır —
  /// "giden" aramayı "gelen" diye göstermek yanlış bilgi olurdu.
  static String yonEtiketi(AramaTipi tip) => switch (tip) {
        AramaTipi.gelen => 'gelen',
        AramaTipi.cevapsiz => 'cevapsız',
        AramaTipi.giden => 'giden',
      };

  @override
  State<_SonAramaKutusu> createState() => _SonAramaKutusuState();
}

class _SonAramaKutusuState extends State<_SonAramaKutusu> {
  /// Akış BİR KEZ kurulur — build'de değil.
  ///
  /// ⚠️ AYNI KUSURUN DÖRDÜNCÜ NÜSHASIYDI (hepsi 2026-08-09'da kapatıldı). Kural şu: `watch*`
  /// fonksiyonları HER ÇAĞRIDA YENİ bir Stream nesnesi döndürür; build'in içinde çağrılırsa
  /// StreamBuilder onu "akış değişti" sayar, aboneliği koparır ve o karede `snap.data` null
  /// olur — kutu bir kare boş/iskelet duruma düşüp geri dolar. Kabuk senkron · kontör ·
  /// sync_meta tiklerinde setState ettiği için bu titreme SIK yaşanır, "arada bir oluyor"
  /// diye teşhisi de zordur.
  ///
  /// BEDELİ ARTIK DÖRT KEZ ÖDENDİ, beşincisi yazılmasın:
  ///  1. `orders/order_list_screen.dart:119-123` — sipariş listesi bir kare iskelete iniyordu
  ///     (deseni tanımlayan yer; ORADAKİ yorum bu kusurun anatomisini anlatır).
  ///  2. `ana_ekran.dart` `_AnaEkranState._ozetiIzle` — "Açık Sipariş" kutusu 0'a düşüyordu.
  ///  3. `ana_ekran.dart` `_SonAktiviteState` — "Bugün henüz hareket yok." parlıyordu.
  ///  4. burası — "Son Arama" kutusu "—/henüz arama yok"a düşüyordu.
  ///
  /// Kapsam girdisi yok (`db` sabittir), bu yüzden önbellek karşılaştırması da gerekmez;
  /// girdiye bağlı akışlarda desen `_ozetiIzle`/`_siparisleriIzle`deki gibi kurulur.
  late final Stream<AramaKaydi?> _sonArama = sonAramaAkisi(widget.db);

  @override
  Widget build(BuildContext context) {
    return StreamBuilder<AramaKaydi?>(
      stream: _sonArama,
      builder: (context, snap) {
        final a = snap.data;
        if (a == null) {
          return _Kutu(
            etiket: 'Son Arama',
            deger: '—',
            kucuk: true,
            sonuk: true,
            alt: 'henüz arama yok',
            onTap: () {},
          );
        }
        return _Kutu(
          etiket: 'Son Arama',
          deger: a.ad ?? sipTelefon(a.numara),
          kucuk: true,
          tekSatir: true, // ad uzunsa küçültülmez, kesilir
          alt: '${_SonAramaKutusu.yonEtiketi(a.tip)} · ${a.saat}',
          altEksi: a.tip == AramaTipi.cevapsiz,
          onTap: () => widget.onArama(a),
        );
      },
    );
  }
}
