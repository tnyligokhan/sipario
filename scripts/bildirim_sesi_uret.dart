// BİLDİRİM SESİ ÜRETİCİSİ — on kategorinin on ayrı tonunu ham PCM hesabıyla sentezler.
//
//     dart run scripts/bildirim_sesi_uret.dart
//
// ── NEDEN İNDİRİLMİYOR DA HESAPLANIYOR ────────────────────────────────────────────────────
// İnternetten alınan bir bildirim sesi telifli olabilir ve mağazaya çıkan bir üründe bunun
// bedeli hukukidir. Burada üretilen ses saf matematiktir (sinüs + harmonikler + zarf); telifi
// tamamen bizimdir ve bu dosya o iddianın KANITIDIR — sesin nereden geldiği sorulursa cevap budur.
//
// Ayrıca tekrar üretilebilir: bir ton beğenilmezse aşağıdaki [sesler] tablosundaki satır
// değişir ve komut yeniden koşulur. Elle düzenlenmiş bir ses dosyasında bu mümkün olmazdı.
//
// ── DOKUZ TON, ÇÜNKÜ SESİN VAR OLMA SEBEBİ BİLDİRİMİ GÖREMEMEK ────────────────────────────
// Kurye direksiyonda, esnaf tezgâhta; ikisi de bildirimi DUYAR, ekrana bakmaz. Önceden yalnız
// iki kategorinin (atama · iptal) kendi tonu vardı, kalan yedisi sistem varsayılanını çalıyordu
// — yani "sipariş iptal edildi" ile "gün özeti hazır" telefonun kulağında AYNI sesti.
//
// ⚠️ NOTA DİZİSİ TEK BAŞINA YETMEZ. Telefon hoparlörü dar bantlıdır; yalnız notaları değiştirmek
// dokuz sesi de birbirine benzetir. Bu yüzden iki eksende birden ayrıştırıldılar:
//   1. DESEN — yükselen · alçalan · tekrarlı · çift-tık · inen üçlü…
//   2. TINI ([Tini]) — harmonik içerik. Zil, org, elektronik ve saf sinüs bir dizi aynı notayı
//      çalsa bile kulakta AYRI ÇALGI olarak ayrılır. Ayrım asıl buradan gelir.
//
// ── NEDEN ESKİSİNDEN GÜRÜLTÜLÜ ────────────────────────────────────────────────────────────
// Eski tepe genlik 0.35 idi ("esnafın müşterisiyle konuşmasını bastırmasın"). Sahada bunun
// bedeli ödendi: motor sesinde ve tezgâh gürültüsünde duyulmuyordu, yani hiç çalmamasıyla aynı
// kapıya çıkıyordu. Yeni tepe 0.60 ve her ses ÜRETİMDEN SONRA bu tepeye NORMALİZE edilir
// ([_normalize]) — harmonik eklemek dalganın tepesini büyüttüğü için sabit bir çarpan bazı
// sesleri kırpar, bazılarını kısık bırakırdı. Ölçü kulakla değil, sayıyla tutulur.
//
// ── BİÇİM ─────────────────────────────────────────────────────────────────────────────────
// 22050 Hz, 16-bit, mono WAV. Bildirim sesi için fazlasıyla yeterli (telefon hoparlörü zaten
// bu bandı taşır) ve 44100'ün yarısı kadar yer kaplar. Android `res/raw` WAV'ı doğrudan çalar;
// kodlayıcı bağımlılığı yoktur.
//
// ⚠️ DOSYA ADLARI res/raw KURALINA TABİ: yalnız küçük harf, rakam ve alt çizgi. Büyük harf ya
// da tire koyan bir isim, Android kaynak derleyicisini kırar.
//
// ⚠️ YENİ SES EKLERSEN `android/app/src/main/res/raw/keep.xml` DOSYASINA DA YAZ. Kaynağa
// Android tarafından hiçbir statik referans yoktur (Dart string adıyla ister); kısaltıcı onu
// ölü sayıp atar ve derleme yeşil kalır, yalnız ses çalmaz. Bir kez yaşandı, ölçüldü.

import 'dart:io';
import 'dart:math' as math;
import 'dart:typed_data';

const int _ornekHizi = 22050;

/// Üretilen her sesin tepe genliği (0–1). Gerekçe dosya başlığında.
const double _tepe = 0.60;

// ═══════════════════════════════════════════════════════════════════════════════════════════
// Nota adları — sayı yerine isim, çünkü 1174.66'nın hangi nota olduğu tabloda okunmuyor
// ═══════════════════════════════════════════════════════════════════════════════════════════

const double e5 = 659.25;
const double f5 = 698.46;
const double g5 = 783.99;
const double a5 = 880.00;
const double b5 = 987.77;
const double c6 = 1046.50;
const double cs6 = 1108.73;
const double d6 = 1174.66;
const double e6 = 1318.51;
const double g6 = 1567.98;
const double a6 = 1760.00;
const double c7 = 2093.00;

// ═══════════════════════════════════════════════════════════════════════════════════════════
// Tını — bir sesin "hangi çalgı" olduğu
// ═══════════════════════════════════════════════════════════════════════════════════════════

/// Bir notanın harmonik içeriği ve sönüm hızı.
///
/// [harmonikler] her girdisi (kat, ağırlık) çiftidir: temel frekansın kaç katı ve ne oranda
/// karıştığı. Kat SAYININ TAM OLMASI GEREKMEZ — çanların tınısı tam olarak tam sayı olmayan
/// katlardan gelir (inharmoniklik) ve kulak bunu "metalik" diye okur.
///
/// [sonumKati] zarfın ne kadar hızlı söndüğü: büyük değer = kısa, kuru, vurmalı; küçük = uzun
/// kuyruklu, çınlayan.
class Tini {
  const Tini(this.harmonikler, {required this.sonumKati});

  /// Saf sinüs — en nötr, en az dikkat çeken. "Bir şey oldu" der, "koş" demez.
  static const saf = Tini([(1.0, 1.0)], sonumKati: 4.0);

  /// Çan/zil: inharmonik katlar. Uzun çınlar, kalabalıkta en iyi duyulan tınıdır — bu yüzden
  /// paranın ve yeni işin sesi budur.
  static const zil = Tini(
    [(1.0, 1.0), (2.76, 0.42), (5.40, 0.18), (8.93, 0.07)],
    sonumKati: 2.6,
  );

  /// Org/flüt: yalnız çift katlar, yumuşak. Kapanış ve özet gibi ACELESİ OLMAYAN haberler.
  static const yumusak = Tini([(1.0, 1.0), (2.0, 0.30), (3.0, 0.10)], sonumKati: 3.2);

  /// Elektronik/kare dalga yaklaşımı: yalnız tek katlar. Kuru ve keskin — "bir şey ters gitti"
  /// ailesinin tınısı (iptal · hatırlatma · yeni cihaz).
  static const elektronik = Tini(
    [(1.0, 1.0), (3.0, 0.33), (5.0, 0.20), (7.0, 0.14)],
    sonumKati: 5.0,
  );

  final List<(double, double)> harmonikler;
  final double sonumKati;
}

// ═══════════════════════════════════════════════════════════════════════════════════════════
// Nota ve ses — desen burada tanımlanır
// ═══════════════════════════════════════════════════════════════════════════════════════════

/// Tek nota: frekans + süre + kendinden sonraki sessizlik.
///
/// ARA NEDEN NOTAYA AİT: iki nota bitişik çalınca kulak onları tek kayan ses gibi duyar ve
/// yükselen/alçalan ayrımı kaybolur (kulakla denendi). Ama ara HER YERDE AYNI OLAMAZ — "çift
/// tık" deseni ancak çok kısa arayla tık gibi duyulur, üç notalı bir arpej ise nefes ister.
class Nota {
  const Nota(this.frekans, {this.saniye = 0.13, this.araSaniye = 0.035});

  final double frekans;
  final double saniye;
  final double araSaniye;
}

/// `res/raw` altına yazılacak tek bir bildirim sesi.
///
/// OOP: sesin ADI, DESENİ ve TINISI tek nesnede durur; dışarıya açılan tek yüzey [yaz]dır.
/// Çağıran taraf ne örnekleme hızını, ne zarfı, ne WAV başlığını bilir.
class BildirimSesi {
  const BildirimSesi({
    required this.dosyaAdi,
    required this.aciklama,
    required this.notalar,
    required this.tini,
  });

  /// `res/raw` dosya adı — uzantısız, küçük harf/rakam/alt çizgi.
  final String dosyaAdi;

  /// Hangi kategoriye ait ve neyi anlatıyor. Ton beğenilmezse önce burası okunur.
  final String aciklama;

  final List<Nota> notalar;
  final Tini tini;

  void yaz(String dizin) {
    final ornekler = <double>[];
    for (final n in notalar) {
      ornekler.addAll(_nota(n));
      final ara = (_ornekHizi * n.araSaniye).round();
      if (ara > 0) ornekler.addAll(List<double>.filled(ara, 0));
    }
    File('$dizin/$dosyaAdi.wav').writeAsBytesSync(_wav(_normalize(ornekler)));
  }

  /// Tek nota: harmonik toplamı + üstel sönüm zarfı.
  ///
  /// ZARF ZORUNLU: çıplak bir dalgayı birden kesmek "tık" sesi üretir (dalga sıfırdan farklı
  /// bir noktada kopar). Sönüm hem tıkı önler hem de sese çalgı karakteri verir. Aynı gerekçe
  /// başlangıç için de geçerli — ilk 5 ms yükseliş rampasıdır.
  List<double> _nota(Nota n) {
    final adet = (_ornekHizi * n.saniye).round();
    final cikti = List<double>.filled(adet, 0);
    final agirlikToplami =
        tini.harmonikler.fold<double>(0, (t, h) => t + h.$2);

    for (var i = 0; i < adet; i++) {
      final t = i / _ornekHizi;
      final yukselis = math.min(1.0, t / 0.005);
      final sonum = math.exp(-tini.sonumKati * t / n.saniye);
      var toplam = 0.0;
      for (final (kat, agirlik) in tini.harmonikler) {
        toplam += math.sin(2 * math.pi * n.frekans * kat * t) * agirlik;
      }
      cikti[i] = (toplam / agirlikToplami) * yukselis * sonum;
    }
    return cikti;
  }
}

/// Tepe değeri [_tepe] olacak şekilde ölçekler.
///
/// NEDEN SABİT ÇARPAN DEĞİL: harmonik sayısı sese göre değişiyor ve dalganın tepesi harmonikler
/// aynı anda tepe yaptığında beklenenden büyük çıkıyor. Sabit çarpanla bazı sesler kırpılır
/// (bozulur), bazıları kısık kalırdı — dokuz sesin EŞİT yükseklikte duyulması, hangisinin
/// çaldığını ayırt edebilmenin ön şartıdır.
List<int> _normalize(List<double> ham) {
  var enBuyuk = 0.0;
  for (final v in ham) {
    final m = v.abs();
    if (m > enBuyuk) enBuyuk = m;
  }
  if (enBuyuk == 0) return List<int>.filled(ham.length, 0);
  final carpan = _tepe / enBuyuk;
  return [
    for (final v in ham) (v * carpan * 32767).round().clamp(-32768, 32767),
  ];
}

// ═══════════════════════════════════════════════════════════════════════════════════════════
// On ses — sıra `BildirimKategori` ile aynıdır, karşılaştırılabilsin
// ═══════════════════════════════════════════════════════════════════════════════════════════

const sesler = <BildirimSesi>[
  // ── Kuryenin YOLUNU değiştiren iki olay: en dikkat çekici iki ton ─────────────────────
  //
  // Bu ikisi zıt yönlü OLMAK ZORUNDA. Kurye direksiyondayken ekrana bakmaz; iptali "yeni
  // sipariş" sanırsa yola devam eder ve müşterinin kapısında mahcup olur.
  BildirimSesi(
    dosyaAdi: 'yeni_is',
    aciklama: 'siparisAtandi — "sana iş geldi". YÜKSELEN parlak arpej, zil tınısı.',
    tini: Tini.zil,
    notalar: [Nota(a5), Nota(cs6), Nota(e6, saniye: 0.20, araSaniye: 0)],
  ),
  BildirimSesi(
    dosyaAdi: 'iptal',
    aciklama: 'siparisIptal — "işin geri alındı". ALÇALAN, kuru elektronik tını.',
    tini: Tini.elektronik,
    notalar: [Nota(e6), Nota(c6), Nota(a5, saniye: 0.20, araSaniye: 0)],
  ),

  BildirimSesi(
    dosyaAdi: 'iptal_onayi',
    aciklama: 'siparisIptalOnayi — "senden karar bekleniyor". SORU DESENİ: iki nota YUKARI, '
        'sonuncusu uzun ve asılı kalır — konuşmada soru tonlaması budur ve cevap beklediğini '
        'kelimeye gerek kalmadan söyler. Zil tınısı `yeni_is` ile ortak ama desen farklı: o '
        'üç notalı bir arpej, bu iki notalı ve ikincisi çok daha uzun. '
        '⚠️ `iptal` İLE KARIŞTIRILAMAZ: o alçalır ve kurudur, bu yükselir ve parlaktır — '
        'ikisi karışırsa patron talebi "iptal oldu" sanıp hiç cevap vermez.',
    tini: Tini.zil,
    notalar: [Nota(a5, saniye: 0.10, araSaniye: 0.05), Nota(d6, saniye: 0.34, araSaniye: 0)],
  ),

  // ── Yöneticiye giden olaylar ──────────────────────────────────────────────────────────
  BildirimSesi(
    dosyaAdi: 'teslim',
    aciklama: 'siparisTeslim — "iş tamamlandı". İki nota yukarı, yumuşak ve huzurlu; '
        'yükselen ama yeni_is kadar parlak DEĞİL (teslim koşturmaz, haber verir).',
    tini: Tini.yumusak,
    notalar: [Nota(g5, saniye: 0.11), Nota(d6, saniye: 0.24, araSaniye: 0)],
  ),
  BildirimSesi(
    dosyaAdi: 'kasa',
    aciklama: 'kasaDevri — para. Kısa-uzun ÇİFT TIK ("ka-ching"), yüksek ve metalik. '
        'Desen tek başına ayırt edici: başka hiçbir ses iki nota arasında bu kadar kısa ara '
        'kullanmıyor.',
    tini: Tini.zil,
    notalar: [Nota(g6, saniye: 0.07, araSaniye: 0.012), Nota(c7, saniye: 0.26, araSaniye: 0)],
  ),
  BildirimSesi(
    dosyaAdi: 'yeni_cihaz',
    aciklama: 'yeniCihaz — güvenlik. AYNI notanın üç kez tekrarı, kuru ve keskin. '
        'Tekrar bir alarm işaretidir; ama üç kısa vuruş panik değil "dur ve bak" der.',
    tini: Tini.elektronik,
    notalar: [
      Nota(c6, saniye: 0.075, araSaniye: 0.05),
      Nota(c6, saniye: 0.075, araSaniye: 0.05),
      Nota(c6, saniye: 0.16, araSaniye: 0),
    ],
  ),

  // ── Günün ritmi: acelesi olmayan haberler ─────────────────────────────────────────────
  BildirimSesi(
    dosyaAdi: 'gun_ozeti',
    aciklama: 'gunSonuOzeti — "gün bitti, hesap hazır". İNEN üçlü, yumuşak org tınısı. '
        'İnen desen kapanış duygusu verir; iptalden tınısı ayırır.',
    tini: Tini.yumusak,
    notalar: [Nota(c6, saniye: 0.14), Nota(a5, saniye: 0.14), Nota(e5, saniye: 0.30, araSaniye: 0)],
  ),
  BildirimSesi(
    dosyaAdi: 'kapanis',
    aciklama: 'gunKapanisHatirlatma — "eksik kaldı". Aynı nota iki kez, sonra AŞAĞI. '
        'Dürtükleyen bir desen: bitmemiş bir işi hatırlatır.',
    tini: Tini.elektronik,
    notalar: [
      Nota(b5, saniye: 0.10, araSaniye: 0.045),
      Nota(b5, saniye: 0.10, araSaniye: 0.045),
      Nota(g5, saniye: 0.22, araSaniye: 0),
    ],
  ),
  BildirimSesi(
    dosyaAdi: 'kontor',
    aciklama: 'kullanimHakki — hak azaldı. İki nota, ikincisi BİR TON AŞAĞI ve yumuşak. '
        '⚠️ NÖTR KALMAK ZORUNDA (mağaza kuralı): telaş yaratan bir ton, bayiyi satın almaya '
        'iten bir baskı olurdu.',
    tini: Tini.yumusak,
    notalar: [Nota(a6, saniye: 0.12), Nota(g6, saniye: 0.22, araSaniye: 0)],
  ),
  BildirimSesi(
    dosyaAdi: 'sistem',
    aciklama: 'sistem — uygulama durumu. TEK kısa saf nota; dokuzunun en sessizi ve en '
        'nötrü. Senkron uyarısı işi bölmemeli.',
    tini: Tini.saf,
    notalar: [Nota(f5, saniye: 0.22, araSaniye: 0)],
  ),
];

void main() {
  final hedef =
      Directory('${Directory.current.path}/apps/mobile/android/app/src/main/res/raw');
  hedef.createSync(recursive: true);

  for (final s in sesler) {
    s.yaz(hedef.path);
  }

  stdout.writeln('${sesler.length} ses yazıldı → ${hedef.path}');
  for (final s in sesler) {
    stdout.writeln('  · ${s.dosyaAdi}.wav');
  }
}

/// 16-bit mono PCM'i WAV kabuğuna sarar (RIFF/fmt /data — 44 baytlık standart başlık).
Uint8List _wav(List<int> ornekler) {
  final veriBoyutu = ornekler.length * 2;
  final bayt = BytesBuilder();

  void metin(String s) => bayt.add(s.codeUnits);
  void u32(int v) => bayt.add(Uint8List(4)..buffer.asByteData().setUint32(0, v, Endian.little));
  void u16(int v) => bayt.add(Uint8List(2)..buffer.asByteData().setUint16(0, v, Endian.little));

  metin('RIFF');
  u32(36 + veriBoyutu);
  metin('WAVE');
  metin('fmt ');
  u32(16); // fmt bloğu uzunluğu
  u16(1); // PCM
  u16(1); // mono
  u32(_ornekHizi);
  u32(_ornekHizi * 2); // bayt/saniye
  u16(2); // blok hizası
  u16(16); // bit derinliği
  metin('data');
  u32(veriBoyutu);

  final pcm = Uint8List(veriBoyutu);
  final gorunum = pcm.buffer.asByteData();
  for (var i = 0; i < ornekler.length; i++) {
    gorunum.setInt16(i * 2, ornekler[i], Endian.little);
  }
  bayt.add(pcm);

  return bayt.toBytes();
}
