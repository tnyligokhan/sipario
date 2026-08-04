import 'dart:async';

import '../auth/session.dart';
import '../data/app_database.dart';
import 'sync_api.dart';
import 'sync_engine.dart';

/// Turun neden düştüğü. Bant metni buna dayanır: "çevrimdışı" demek yalnız AĞ yokluğunda
/// doğrudur. Oturum ölmüşse kayıtlar "bağlanınca" gönderilmeyecektir — kullanıcı beklemeyi değil
/// yeniden giriş yapmayı bilmeli. Beklenmedik veri hatası da ağ sorunu değildir.
enum SyncHataTuru {
  yok,

  /// SUNUCUYA HİÇ ULAŞILAMADI: ağ yok, zaman aşımı, soket kapandı. "Çevrimdışı" demek YALNIZ
  /// burada doğrudur. Bekle, kendiliğinden gidecek.
  ag,

  /// 401/403 ya da yerelde token yok. BEKLEMEK ÇÖZMEZ; yeniden giriş gerekir.
  oturum,

  /// Sunucuya ULAŞILDI ama o veremedi: 5xx (arıza) ya da geçici 4xx (408/425/429). Ağ sorunu
  /// DEĞİLDİR — "çevrimdışısın" demek kullanıcıyı telefonunu/wifi'sini kurcalamaya yollardı —
  /// ama kalıcı da değildir: otomatik yeniden denenir.
  sunucu,

  /// Sunucu bize ULAŞTI ve isteğimizi KALICI olarak geri çevirdi (401/403 dışı 4xx: 400/404/
  /// 409/422…) ya da beklenmedik yanıt geldi (tip/şema hatası). Ne ağ ne oturum — kod/sürüm
  /// uyuşmazlığı ya da bozuk kayıt. Kullanıcı bekleyerek çözemez.
  veri,
}

/// Bir senkron turunun özeti (UI durum çubuğu için).
class SyncOutcome {
  const SyncOutcome({
    required this.ok,
    this.pushed = 0,
    this.karantina = 0,
    this.error,
    this.tur = SyncHataTuru.yok,
  });
  final bool ok;
  final int pushed;

  /// Bu turda karantinaya alınan olay sayısı (kayıtlar SİLİNMEDİ, outbox'ta duruyor).
  final int karantina;
  final String? error;

  /// [ok] false ise başarısızlığın CİNSİ. Bant hangi gerçeği yazacağını bundan öğrenir.
  final SyncHataTuru tur;
}

/// Senkron servisini oturuma bağlar ve periyodik koşturur. Motor (SyncEngine) saf kalır;
/// taban adres + token sync_meta'dan OKUNARAK verilir (login sonrası yeniden kurulum gerekmez).
///
/// Hata felsefesi: senkron hatası UYGULAMAYI DURDURMAZ (kırmızı çizgi #3 — offline'da her şey
/// çalışır); hata özetlenip durum akışına yazılır, sonraki tur yeniden dener (outbox zaten bekler).
class SyncService {
  /// [api] YALNIZ TEST İÇİNDİR (üretimde null → HttpSyncApi kurulur). Bu enjeksiyon noktasının
  /// olmaması, 2026-07-27'de sahada yakalanan "senkron takılıp kalıyor" arızasının hiçbir testle
  /// yakalanamamış olmasının sebebiydi: servis kendi taşımasını içeride kuruyordu, dolayısıyla
  /// "istek asılı kalırsa ne olur" sorusu hiç sorulamıyordu.
  SyncService(this.db, {SyncApi? api}) : _testApi = api {
    _engine = SyncEngine(db, api ?? _httpApi(_baseUrl ?? kDefaultApiBaseUrl));
  }

  final AppDatabase db;
  final SyncApi? _testApi;

  /// baseUrl her istekte değil KURULUŞTA okunur; login baseUrl'i değiştirirse [configure]
  /// çağrılır (login ekranı zaten uygulamanın kökünü yeniden kurar).
  SyncApi _httpApi(String baseUrl) => HttpSyncApi(
        baseUrl: baseUrl,
        tokenProvider: () async => (await db.syncState()).authToken,
      );
  late SyncEngine _engine;
  String? _baseUrl;
  Timer? _timer;
  StreamSubscription<void>? _tetikSub;

  /// Devam eden tur (yoksa null). Eşzamanlı çağrılar AYNI tura bağlanır: hem çift tur koşmaz hem
  /// de çağıran gerçek sonucu alır.
  ///
  /// ESKİDEN `bool _running` vardı ve meşgulken `SyncOutcome(ok: true)` dönüyordu — sahadan
  /// bildirilen arızanın merkezi buydu. Zaman aşımı olmayan bir HTTP çağrısı asılı kalınca
  /// `finally` HİÇ çalışmıyor, `_running` sonsuza dek `true` kalıyor ve 2 dakikalık zamanlayıcının
  /// her turu `if (_running) return` ile sessizce yutuluyordu: senkron bir daha ilerlemiyor,
  /// durum akışına hiçbir şey yazılmadığı için gösterge de son "başarısız" değerinde donuyordu.
  /// Uygulamayı kapatıp açmak işe yarıyordu çünkü bu alan bellekteydi. Kalıcı çözüm ÜÇ katmanlı:
  /// (1) taşımada zaman aşımı, (2) burada bayrak yerine future, (3) her yolda durum yayını.
  Future<SyncOutcome>? _tur;

  final _status = StreamController<SyncOutcome>.broadcast();

  /// Son senkron sonuçlarının akışı (UI dinler; başarı/hata çubuğu).
  Stream<SyncOutcome> get status => _status.stream;

  /// Taban adresi sync_meta'dan okuyup motoru kurar; login sonrası ve açılışta çağrılır.
  Future<void> configure() async {
    final meta = await db.syncState();
    _baseUrl = Session.baseUrlOf(meta);
    _engine = SyncEngine(db, _testApi ?? _httpApi(_baseUrl!));
  }

  /// Tek senkron turu: önce push (bekleyen outbox), sonra pull (snapshot/delta).
  /// Eşzamanlı çift çağrı tek tura indirgenir ve İKİSİ DE o turun gerçek sonucunu alır.
  Future<SyncOutcome> syncNow() => _tur ??= _turAt().whenComplete(() => _tur = null);

  Future<SyncOutcome> _turAt() async {
    SyncOutcome outcome;
    try {
      final token = (await db.syncState()).authToken;
      if (token == null) {
        outcome =
            const SyncOutcome(ok: false, error: 'Oturum yok', tur: SyncHataTuru.oturum);
      } else {
        final ozet = await _engine.pushPending();
        // Pull, push kalıcı red yese DE koşar: gelen veriyi kullanıcıdan esirgemek için sebep yok
        // (iki yön birbirinden bağımsız).
        await _engine.pull();
        // Sunucu bir kaydı KALICI olarak reddettiyse tur "başarılı" sayılamaz — o sipariş/tahsilat
        // bu telefonda var, sunucuda YOK. Sessiz kalmak, bu arızanın aylarca görünmemesinin ta
        // kendisiydi. Cins `veri`: ne ağ ne oturum sorunu, sunucuya ulaşıldı ve geri çevrildi.
        outcome = ozet.kaliciRed
            ? SyncOutcome(
                ok: false,
                pushed: ozet.gonderildi,
                karantina: ozet.karantina,
                error: 'Sunucu bazı kayıtları kabul etmedi',
                tur: SyncHataTuru.veri,
              )
            : SyncOutcome(ok: true, pushed: ozet.gonderildi, karantina: ozet.karantina);
      }
    } catch (e) {
      // `on Exception` DEĞİL — bilinçli. Sunucu beklenmedik bir tip/null yollarsa SyncEngine'deki
      // `as String` / `as num` dönüşümleri TypeError atar ve TypeError bir Error'dur, Exception
      // değildir: eski `on Exception catch` onu yakalamıyor, hata `syncNow`dan kaçıyor ve durum
      // akışına HİÇBİR ŞEY yazılmıyordu — gösterge son bilinen değerinde donuyordu. Ağ hatası
      // zaten normal işleyiştir (bodrum/asansör); kısa özet, PII yok (yalnız istisna tipi).
      outcome = SyncOutcome(ok: false, error: e.runtimeType.toString(), tur: hataTuru(e));
    }
    // HER yolda yayınlanır (başarı, ağ hatası, tip hatası, oturumsuzluk). Gösterge yalnız bu
    // akıştan besleniyor; bir yolda sessiz kalmak "çevrimiçiyken çevrimdışı" demektir.
    if (!_status.isClosed) _status.add(outcome);
    return outcome;
  }

  /// Periyodik senkronu başlatır (varsayılan 2 dk — beklenen kopukluklar kısa, BRIEF).
  void start({Duration every = const Duration(minutes: 2)}) {
    _timer?.cancel();
    _timer = Timer.periodic(every, (_) => syncNow());
    // İlk turu hemen at (login/açılış sonrası veri gecikmesin).
    unawaited(syncNow());
  }

  /// Hatanın cinsini belirler (ekrandan AYRI saf fonksiyon — testi widget kurmadan yazılır).
  ///
  /// TEMEL AYRIM: `SyncApiException` demek "sunucuya ULAŞTIK ve bir HTTP yanıtı aldık" demektir.
  /// Ulaşılan bir sunucu için "Çevrimdışı" yazmak yalandır. Eskiden 401/403 dışındaki HER
  /// `SyncApiException` `ag` sayılıyordu: 422 de, 500 de, 404 de "Çevrimdışı · bağlanınca
  /// gönderilecek" diyordu. Bant böylece hem sunucuya ulaşıldığını gizliyor hem de asla
  /// gerçekleşmeyecek bir söz veriyordu — 2026-08-05'te teşhis edilen kalıcı-çevrimdışı
  /// arızasının aylarca görünmemesinin sebebi tam olarak buydu.
  ///
  /// • 401/403 → `oturum` (yeniden giriş gerekir, beklemek çözmez)
  /// • kalıcı 4xx → `veri` (istek geri çevrildi; kullanıcı bekleyerek çözemez)
  /// • 5xx + geçici 4xx → `sunucu` (ayakta ama veremiyor; otomatik yeniden denenir)
  /// • diğer Exception (soket/zaman aşımı) → `ag`
  /// • Error (Exception DEĞİL) → `veri` (beklenmedik payload → tip hatası)
  static SyncHataTuru hataTuru(Object e) {
    if (e is SyncApiException) {
      if (e.oturumHatasi) return SyncHataTuru.oturum;
      return e.kaliciRed ? SyncHataTuru.veri : SyncHataTuru.sunucu;
    }
    return e is Exception ? SyncHataTuru.ag : SyncHataTuru.veri;
  }

  /// Dış tetikleyici: ağ geri geldi / uygulama öne geldi gibi olaylarda tur açar. Zamanlayıcıya
  /// EK'tir, yerine geçmez. Stream olarak alınır ki servis `connectivity_plus`a bağımlı olmasın —
  /// motor saf kalır ve testler platform kanalı olmadan koşar.
  void tetikleyiciBagla(Stream<void> tetik) {
    _tetikSub?.cancel();
    // onError YUTAR: tetik kaynağı bir platform eklentisi olabilir (connectivity_plus) ve o
    // kanal widget testinde ya da desteklenmeyen bir platformda hata yayınlar. Tetik bir
    // İYİLEŞTİRMEDİR — zamanlayıcı ve öne-gelme turu zaten senkronu ayakta tutar; kaynağının
    // susması senkronu ya da uygulamayı DÜŞÜRMEMELİ.
    _tetikSub = tetik.listen((_) => unawaited(syncNow()), onError: (Object _) {});
  }

  void stop() {
    _timer?.cancel();
    _timer = null;
    _tetikSub?.cancel();
    _tetikSub = null;
  }

  void dispose() {
    stop();
    _status.close();
  }
}
