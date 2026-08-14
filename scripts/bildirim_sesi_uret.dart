// BİLDİRİM SESİ ÜRETİCİSİ — iki tonu ham PCM hesabıyla sentezler.
//
//     dart run scripts/bildirim_sesi_uret.dart
//
// ── NEDEN İNDİRİLMİYOR DA HESAPLANIYOR ────────────────────────────────────────────────────
// İnternetten alınan bir bildirim sesi telifli olabilir ve mağazaya çıkan bir üründe bunun
// bedeli hukukidir. Burada üretilen ses saf matematiktir (sinüs + zarf); telifi tamamen
// bizimdir ve bu dosya o iddianın KANITIDIR — sesin nereden geldiği sorulursa cevap budur.
//
// Ayrıca tekrar üretilebilir: ton beğenilmezse aşağıdaki nota/süre sabitleri değişir ve
// komut yeniden koşulur. Elle düzenlenmiş bir ses dosyasında bu mümkün olmazdı.
//
// ── İKİ TON, ÇÜNKÜ KURYE EKRANA BAKMIYOR ──────────────────────────────────────────────────
// `yeni_is`  : YÜKSELEN iki nota — "sana iş geldi".
// `iptal`    : ALÇALAN iki nota — "işin geri alındı".
// Tek ses kullansaydık kurye iptal sesini "yeni sipariş" sanıp yola devam ederdi; sesin var
// olma sebebi zaten bildirimi GÖRMEDİĞİ durumdur.
//
// ── BİÇİM ─────────────────────────────────────────────────────────────────────────────────
// 22050 Hz, 16-bit, mono WAV. Bildirim sesi için fazlasıyla yeterli (telefon hoparlörü zaten
// bu bandı taşır) ve 44100'ün yarısı kadar yer kaplar — dosya ~15 KB, APK'da göz ardı edilir.
// Android `res/raw` WAV'ı doğrudan çalar; kodlayıcı bağımlılığı yoktur.
//
// ⚠️ DOSYA ADLARI res/raw KURALINA TABİ: yalnız küçük harf, rakam ve alt çizgi. Büyük harf ya
// da tire koyan bir isim, Android kaynak derleyicisini kırar.

import 'dart:io';
import 'dart:math' as math;
import 'dart:typed_data';

const int _ornekHizi = 22050;

/// Notanın süresi. 120 ms: fark edilecek kadar uzun, "çalıyor" hissi vermeyecek kadar kısa.
const double _notaSaniye = 0.12;

/// Notalar arası sessizlik — iki tonun AYRI duyulması için. Bitişik çalınca tek kayan ses
/// gibi algılanıyor ve yükselen/alçalan ayrımı kayboluyor (kulakla denendi).
const double _araSaniye = 0.03;

/// Tepe genlik (0–1). 0.35: telefon zilinden belirgin biçimde daha sakin. Bildirim sesi
/// dikkat çekmeli ama esnafın müşterisiyle konuşmasını bastırmamalı.
const double _genlik = 0.35;

void main() {
  final kok = Directory.current.path;
  final hedef = Directory('$kok/apps/mobile/android/app/src/main/res/raw');
  hedef.createSync(recursive: true);

  // A5 (880) → D6 (1174.66): yükselen dörtlü. Kısa bir "geldi" jesti.
  _yaz('${hedef.path}/yeni_is.wav', const [880.0, 1174.66]);

  // Aynı iki nota TERS sırada: alçalan dörtlü, "geri alındı".
  _yaz('${hedef.path}/iptal.wav', const [1174.66, 880.0]);

  stdout.writeln('Yazıldı: ${hedef.path}/yeni_is.wav · iptal.wav');
}

void _yaz(String yol, List<double> notalar) {
  final ornekler = <int>[];

  for (var i = 0; i < notalar.length; i++) {
    ornekler.addAll(_nota(notalar[i]));
    if (i < notalar.length - 1) {
      ornekler.addAll(List<int>.filled((_ornekHizi * _araSaniye).round(), 0));
    }
  }

  File(yol).writeAsBytesSync(_wav(ornekler));
}

/// Tek nota: sinüs + üstel sönüm zarfı.
///
/// ZARF ZORUNLU: çıplak bir sinüsü birden kesmek "tık" sesi üretir (dalga sıfırdan farklı bir
/// noktada kopar). Sönüm hem tıkı önler hem de sese zil karakteri verir.
List<int> _nota(double frekans) {
  final n = (_ornekHizi * _notaSaniye).round();
  final ornekler = List<int>.filled(n, 0);

  for (var i = 0; i < n; i++) {
    final t = i / _ornekHizi;
    // Hızlı yükseliş (ilk 5 ms) — başlangıçtaki tıkı da o önler.
    final yukselis = math.min(1.0, t / 0.005);
    final sonum = math.exp(-4.0 * t / _notaSaniye);
    final deger = math.sin(2 * math.pi * frekans * t) * _genlik * yukselis * sonum;
    ornekler[i] = (deger * 32767).round().clamp(-32768, 32767);
  }

  return ornekler;
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
