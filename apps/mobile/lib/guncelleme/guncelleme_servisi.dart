// Güncelleme servisi — ağ, dosya ve native köprü. Kararlar `guncelleme_sozlesmesi.dart`ta.
//
// OFFLINE-FIRST ÇİZGİSİ (kırmızı çizgi #3): bu modül açılışı ASLA bloklamaz ve çevrimdışıyken
// hiçbir uyarı üretmez. Her hata sessizce yutulur — güncelleme bir kolaylıktır, bayinin işi
// değildir. Zaman aşımı 5 sn: sinyal çukurundaki kurye bunu hiç fark etmemeli.

import 'dart:async';
import 'dart:io';

import 'package:flutter/foundation.dart';
import 'package:flutter/services.dart';
import 'package:http/http.dart' as http;

import '../bildirim/bildirim_servisi.dart' show bildirimServisi;
import '../bildirim/bildirim_sozlesmesi.dart';
import 'guncelleme_sozlesmesi.dart';

/// Native köprü — kurulum izni, ABI listesi ve kurulum niyeti.
/// Kanal adı `sipario/cagri` deseninin ikizi (bkz. `MainActivity`).
const MethodChannel _kanal = MethodChannel('sipario/guncelleme');

/// İndirme durumu — bant bunu dinler.
enum GuncellemeDurumu { yok, bulundu, iniyor, kuruluyor, hata }

/// Bu çağrıda gerçekten AĞA ÇIKILMALI mı?
///
/// Saf karar (kararlar `guncelleme_sozlesmesi.dart`ta yaşar; bu biri [GuncellemeDurumu]'na
/// bağlı olduğu için burada — çevrimsel import'a değmez). Üç ayrı "hayır" var, üçü de farklı:
///  • [kapali]: mağaza derlemesi / yapı numarası bilinmiyor → hiç sorulmaz.
///  • [durum] `yok` değil: bant zaten duruyor → tekrar sormanın anlamı yok.
///  • [sonKontrol] yakın: kontrol artık ÖNE GELMEDE de koşuyor ve öne gelme SIK olur; her
///    seferinde ağa çıkmak pil/veri yakar, üstelik sürüm dakikada bir değişmez.
///
/// [sonKontrol] son DENEME zamanıdır (başarısız da olsa). Çevrimdışıyken her öne gelmede
/// yeniden denemek hiçbir şey kazandırmaz; bir sonraki pencerede zaten denenir.
bool kontrolGerekli({
  required bool kapali,
  required GuncellemeDurumu durum,
  required DateTime? sonKontrol,
  required DateTime simdi,
  required Duration aralik,
  bool zorla = false,
}) {
  if (kapali) return false;
  if (durum != GuncellemeDurumu.yok) return false;
  if (zorla || sonKontrol == null) return true;
  return simdi.difference(sonKontrol) >= aralik;
}

/// Uygulamanın kullandığı servis (tekil). Testler kendi örneğini kurar.
final GuncellemeServisi guncellemeServisi = GuncellemeServisi();

class GuncellemeServisi {
  GuncellemeServisi({http.Client? istemci, BildirimServisi? bildirim})
      : _istemci = istemci,
        _bildirim = bildirim;

  final http.Client? _istemci;

  /// Yeni sürüm bulunduğunda bildirimi çizecek servis; verilmezse uygulamanın tekili.
  ///
  /// ENJEKTE EDİLEBİLİR OLMASI TEST İÇİN ŞART: tekil `bildirimServisi` gerçek uygulamada
  /// platform kanalına bağlı ve widget testinde eklenti kaydı yoktur. Sahte servisle
  /// değiştirilebilmesi, "bildirim gerçekten üretildi mi" sorusunun ağ ve platform olmadan
  /// cevaplanmasını sağlar — bandın aylarca ağaca bağlanmamış olması tam da bu tür bir
  /// boşluktu (bkz. `guncelleme_banti.dart` kill-switch notu).
  final BildirimServisi? _bildirim;

  /// Bulunan sürüm; yoksa null. Bant bu iki bildirimi dinler.
  final ValueNotifier<SurumBilgisi?> bulunan = ValueNotifier<SurumBilgisi?>(null);

  /// SUNUCUYA GERÇEKTEN ULAŞILAN son kontrolün anı (güncelleme bulunsun ya da bulunmasın).
  ///
  /// Ana ekran bunu "Sürüm güncel" çipini çizmek için okur. Yalnız `durum == yok` bakmak
  /// YETMEZ: hiç kontrol yapılmamış bir uygulamada da durum `yok`tur ve çip, hiç sorulmamış
  /// bir soruya "güncel" diye cevap vermiş olurdu. Çevrimdışı bir denemede de yazılmaz —
  /// ulaşılamayan sunucu hakkında "güncelsiniz" demek yanlış bilgidir.
  final ValueNotifier<DateTime?> sonBasariliKontrol = ValueNotifier<DateTime?>(null);
  final ValueNotifier<GuncellemeDurumu> durum =
      ValueNotifier<GuncellemeDurumu>(GuncellemeDurumu.yok);

  /// 0..1 arası indirme ilerlemesi.
  final ValueNotifier<double> ilerleme = ValueNotifier<double>(0);

  /// En sık bu aralıkla ağa çıkılır (bkz. [sessizKontrol]).
  static const Duration kontrolAraligi = Duration(minutes: 15);

  /// Son DENEME zamanı (başarılı ya da değil). Başarısızlığı da saymak bilinçli: çevrimdışıyken
  /// her öne gelmede tekrar denemek pil yakar ve hiçbir şey kazandırmaz.
  DateTime? _sonKontrol;

  /// [sessizKontrol]'ün kaç kez ÇAĞRILDIĞI (ağa çıkılmasa da artar). Yalnız teşhis/test içindir:
  /// "tetikleyici bağlı mı" sorusunu ağ olmadan cevaplar.
  int istekSayisi = 0;

  /// Açılışta VE uygulama öne geldiğinde çağrılır. `magaza` kanalında ya da yapı numarası
  /// bilinmiyorsa HİÇ AĞA ÇIKMAZ.
  ///
  /// ÖNE GELME TETİKLEYİCİSİ ŞART (2026-07-28 saha bulgusu): kontrol yalnız açılışta koşuyordu
  /// ve bayi "uygulamayı kapatıp açtım" dediğinde aslında SÜREÇ ÖLMÜYOR — son kullanılanlardan
  /// kaydırmak çoğu Android'de (özellikle Xiaomi/Samsung) uygulamayı bellekte bırakır, Dart
  /// isolate'i yaşamaya devam eder ve `initState` bir daha koşmaz. Bandı görmek için "zorla
  /// durdur" gerekiyordu; hiçbir bayi bunu yapmaz. Senkron motoru bu dersi zaten öğrenmişti
  /// (üç tetikleyici: zamanlayıcı · öne gelme · ağın dönüşü) — güncelleme kontrolü ona bağlanmadan
  /// kalmıştı.
  ///
  /// [zorla] aralığı atlar; [kapali] derleme sabitini geçersiz kılar (test yolu — varsayılan
  /// `flutter test` altında kanal `magaza` olduğu için sabit hep "kapalı"dır ve bu metodun
  /// hiçbir davranışı sınanamazdı).
  Future<void> sessizKontrol({bool zorla = false, bool? kapali}) async {
    // Kaç kez SORULDUĞU (ağa çıkılmasa bile). Tetikleyicinin bağlı olduğunu kanıtlar:
    // asıl saha hatası kontrolün hiç ÇAĞRILMAMASIYDI, ağ yanıtıyla değil.
    istekSayisi++;

    final simdi = DateTime.now();
    if (!kontrolGerekli(
      kapali: kapali ?? guncellemeKapaliMi,
      durum: durum.value,
      sonKontrol: _sonKontrol,
      simdi: simdi,
      aralik: kontrolAraligi,
      zorla: zorla,
    )) {
      return;
    }
    _sonKontrol = simdi;

    try {
      final istemci = _istemci ?? http.Client();
      // Adres ÖNBELLEKSİZ istenir: düz adres, yayın yapıldıktan saatler sonra bile CDN'den
      // eski içeriği döndürüyordu (ölçüldü — bkz. `onbelleksizAdres`). Bant düşmemesinin
      // gerçek sebebi buydu ve hiçbir hata üretmiyordu.
      final yanit = await istemci
          .get(onbelleksizAdres(kSurumJsonAdresi, simdi), headers: kOnbelleksizBasliklar)
          .timeout(const Duration(seconds: 5));
      if (yanit.statusCode != 200) return;
      final bilgi = SurumBilgisi.cozumle(yanit.body);
      if (bilgi == null) return;
      // Sunucuya ULAŞILDI ve cevap okundu — güncelleme çıkmasa da bu bir başarıdır ve
      // ekranın "Sürüm güncel" diyebilmesinin tek dayanağıdır.
      sonBasariliKontrol.value = simdi;
      if (!guncellemeVarMi(yerelYapim: kYapim, uzakYapim: bilgi.yapim)) return;
      bulunan.value = bilgi;
      durum.value = GuncellemeDurumu.bulundu;
      await bildir(bilgi);
    } on Object catch (e) {
      // Çevrimdışı, DNS yok, zaman aşımı, bozuk JSON — hepsi aynı: sessizlik.
      debugPrint('Güncelleme kontrolü yapılamadı: $e');
    }
  }

  /// YENİ SÜRÜM BİLDİRİMİ (kullanıcı isteği 2026-08-25).
  ///
  /// NEDEN GEREKLİ: bant müdahalesizdir ve öyle kalmalı, ama bedeli şu — bayi uygulamayı
  /// AÇMADIĞI sürece yeni sürümden haberi olmaz. Bildirim o boşluğu kapatır.
  ///
  /// BİLDİRİM İNDİRMEYİ BAŞLATMAZ, yalnız haber verir. Dokunuş uygulamayı açar ve bandın
  /// "Güncelle" düğmesi orada durur. Sessizce indirmeye başlamak, bayinin mobil verisini
  /// onun kararı olmadan harcamak olurdu (APK ~30 MB).
  ///
  /// KİMLİK YAPIM NUMARASINA BAĞLI: aynı sürüm için ikinci bir bildirim doğmaz, üzerine yazar
  /// (`bildirimKimligi` sözleşmesi). Uygulama gün içinde birkaç kez yeniden başlasa bile bayi
  /// tek satır görür.
  ///
  /// HATA YUTAR: bildirim bir kolaylıktır ve güncelleme akışını düşüremez. `saha` kanalında
  /// izin verilmemiş olabilir, sessiz saat olabilir, bütçe dolmuş olabilir — hiçbiri bandın
  /// çizilmesini engellemez, o zaten `durum` üzerinden çoktan görünür oldu.
  ///
  /// ⚠️ NEDEN `@visibleForTesting` (private değil): `sessizKontrol` üzerinden ulaşılamaz.
  /// `kYapim` bir DERLEME SABİTİDİR ve varsayılan `flutter test` altında 0'dır; `guncellemeVarMi`
  /// yerel yapım 0 iken her zaman false döner (yerel/geliştirme derlemesi bilerek dürtülmez).
  /// Yani taslak testte ancak buradan sınanabilir — ve sınanmalı: bandın aylarca ağaca hiç
  /// bağlanmamış olması, tam olarak "ulaşılamayan yol test edilemez" boşluğundan doğmuştu.
  @visibleForTesting
  Future<void> bildir(SurumBilgisi bilgi) async {
    try {
      await (_bildirim ?? bildirimServisi).goster(BildirimTaslagi(
        kategori: BildirimKategori.guncellemeVar,
        baslik: 'Yeni sürüm hazır',
        // SÜRÜM ADI GÖVDEDE, YAPIM NUMARASI HİÇBİR YERDE — banttaki kuralın aynısı
        // (2026-08-11 kullanıcı kararı: "sadece sürüm yazsın").
        govde: '${bilgi.surum} sürümü indirilebilir',
        detay: 'Uygulamayı açın; en üstteki şeritten "Güncelle" ile kurabilirsiniz.',
        kimlik: bildirimKimligi(BildirimKategori.guncellemeVar, '${bilgi.yapim}'),
        // YOL YOK ve bu bilinçli: bildirime dokunmak uygulamayı ANA EKRANDA açar, bandın
        // tam da durduğu yerde. Sözlüğe yalnız bu bildirim için bir "guncelleme" rotası
        // eklemek, hedefi zaten açılışta görünen bir şey için ikinci bir yol kurmak olurdu.
      ));
    } on Object catch (e) {
      debugPrint('Güncelleme bildirimi gösterilemedi: $e');
    }
  }

  /// İndirir ve kurulum ekranını açar. Bant dokunuşuyla çağrılır.
  ///
  /// Sıra: izin → indir → boyut doğrula → kur. Her adım hata yutar ve durumu `hata`ya çeker;
  /// bayi bandı yeniden deneyebilir.
  Future<void> indirVeKur() async {
    final bilgi = bulunan.value;
    if (bilgi == null || durum.value == GuncellemeDurumu.iniyor) return;

    try {
      // Android 8+ tek seferlik izin: yoksa kullanıcıyı ayara götür ve BEKLE. Dönüşte tekrar
      // sorulur; hâlâ yoksa sessizce vazgeçilir (bayi izni vermek istememiş olabilir).
      if (!await _kurulumIzniVar()) {
        await _kanal.invokeMethod<void>('kurulumIzniIste');
        if (!await _kurulumIzniVar()) {
          durum.value = GuncellemeDurumu.bulundu;
          return;
        }
      }

      durum.value = GuncellemeDurumu.iniyor;
      ilerleme.value = 0;

      final abiler = await _abiler();
      final hedef = bilgi.indirilecek(abiler);
      final dosya = await _indir(hedef.url);
      if (dosya == null) {
        durum.value = GuncellemeDurumu.hata;
        return;
      }

      final bayt = await dosya.length();
      if (!indirmeSaglamMi(inenBayt: bayt, beklenenBayt: hedef.boyut)) {
        // Yarım/bayat indirme: SİL ve kurma. Sonraki açılışta yeniden denenir.
        await dosya.delete().catchError((_) => dosya);
        durum.value = GuncellemeDurumu.hata;
        return;
      }

      durum.value = GuncellemeDurumu.kuruluyor;
      await _kanal.invokeMethod<void>('kur', {'yol': dosya.path});
    } on Object catch (e) {
      debugPrint('Güncelleme kurulamadı: $e');
      durum.value = GuncellemeDurumu.hata;
    }
  }

  Future<bool> _kurulumIzniVar() async {
    try {
      return await _kanal.invokeMethod<bool>('kurulumIzniVar') ?? false;
    } on Object {
      return false;
    }
  }

  Future<List<String>> _abiler() async {
    try {
      final l = await _kanal.invokeListMethod<String>('abiler');
      return l ?? const [];
    } on Object {
      return const [];
    }
  }

  /// APK'yı uygulamanın KENDİ önbelleğine indirir (FileProvider yalnız orayı paylaşır).
  /// Aynı ada yazılır: yarım kalan bir indirme sonrakinde üzerine yazılır, çöp birikmez.
  Future<File?> _indir(String url) async {
    final istemci = _istemci ?? http.Client();
    try {
      // APK de önbelleksiz istenir: bayat bir paket ya boyut kontrolüne takılıp sonsuza dek
      // "bozuk indirme" üretir ya da — boyutlar tesadüfen tutarsa — ESKİ derlemeyi
      // "güncelleme" diye kurdurur. İkincisi teşhis edilemez.
      final istek = http.Request('GET', onbelleksizAdres(url, DateTime.now()))
        ..headers.addAll(kOnbelleksizBasliklar);
      final yanit = await istemci.send(istek).timeout(const Duration(seconds: 30));
      if (yanit.statusCode != 200) return null;

      final dizin = Directory('${Directory.systemTemp.parent.path}/guncelleme');
      final klasor = await _onbellekKlasoru() ?? dizin;
      if (!await klasor.exists()) await klasor.create(recursive: true);
      final dosya = File('${klasor.path}/sipario-guncelleme.apk');
      final akis = dosya.openWrite();

      final toplam = yanit.contentLength ?? 0;
      var inen = 0;
      await for (final parca in yanit.stream) {
        akis.add(parca);
        inen += parca.length;
        if (toplam > 0) ilerleme.value = (inen / toplam).clamp(0, 1);
      }
      await akis.flush();
      await akis.close();
      return dosya;
    } on Object catch (e) {
      debugPrint('APK indirilemedi: $e');
      return null;
    }
  }

  /// Native taraftan uygulamanın önbellek dizini (`cacheDir/guncelleme`).
  /// FileProvider yolu tam olarak burayı işaret ediyor — başka yere yazmak kurulumu bozar.
  Future<Directory?> _onbellekKlasoru() async {
    try {
      final yol = await _kanal.invokeMethod<String>('onbellekYolu');
      return yol == null ? null : Directory(yol);
    } on Object {
      return null;
    }
  }
}
