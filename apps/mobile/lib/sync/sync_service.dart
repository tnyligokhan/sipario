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
  ///
  /// [turSuresi] de aynı gerekçeyle enjekte edilebilir: 90 saniyeyi gerçek zamanda bekleyen bir
  /// test yazılamaz, dolayısıyla sınır test edilemez olurdu (bkz. [turUstSinir]).
  SyncService(this.db, {SyncApi? api, this.turSuresi = turUstSinir}) : _testApi = api {
    _engine = SyncEngine(db, api ?? _httpApi(_baseUrl ?? kDefaultApiBaseUrl));
  }

  final AppDatabase db;
  final SyncApi? _testApi;

  /// BİR TURUN ÜST SINIRI. İstek başına zaman aşımı (25 sn) tek başına yetmiyordu: `pull()`
  /// 100 sayfaya kadar döner ve push'un ikili arama bölmesi 24 EK istek harcayabilir — hepsi
  /// tek tek "zamanında" yanıtlansa bile tur dakikalarca sürebilir. Tur sürerken açılan her
  /// yeni tur (yazım tetiği dâhil) `_tur`a bağlanıp SIRAYA girer, yani patronun az önce yazdığı
  /// atama o turun sonunu bekler — düzeltmek istediğimiz gecikme arızasının ta kendisi.
  ///
  /// SINIRIN GÜVENLİ OLMASININ ŞARTI ÖLÇÜLDÜ (2026-08-09): `_applyDelta` HER SAYFAYI kendi
  /// transaction'ında uygular ve sonunda `lastPulledSeq`i yazar; sonraki tur meta'yı yeniden
  /// okuyup imleçten devam eder. Snapshot hiç sayfalanmaz (sunucu `has_more=false`), yani sınır
  /// snapshot'ı keserse HİÇBİR ŞEY uygulanmaz, imleç 0 kalır ve sonraki tur yine snapshot çeker.
  /// Her iki hâlde de GERİ SARMA yok, en fazla TEKRAR var — kesilen tur veri kaybettirmez.
  ///
  /// 90 sn: sağlıklı bir turun (bir push + bir-iki delta sayfası) kat kat üstünde, ama kuryenin
  /// "gelmiyor" demesine yol açacak dakikaların altında.
  static const turUstSinir = Duration(seconds: 90);

  /// Bu servisin tur üst sınırı — üretimde [turUstSinir], testte enjekte edilir.
  final Duration turSuresi;

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

  /// Yazım tetiği AYRI yuvadadır: ağ tetiği ([tetikleyiciBagla]) ile aynı aboneliği paylaşsaydı
  /// biri diğerini iptal ederdi ve iki kaynak da gerekiyor.
  StreamSubscription<int>? _yazimSub;
  Timer? _yazimGecikme;

  /// Bekleyen outbox sayısının SON görülen değeri — tetik yalnız ARTIŞTA açılır (bkz.
  /// [yazimTetigiBagla]). `null` = ilk yayın henüz gelmedi.
  int? _sonBekleyen;

  /// Zamanlayıcının güncel aralığı; ön plan/arka plan geçişinde [aralikAyarla] değiştirir.
  Duration _aralik = arkaPlanAralik;

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
        outcome = await _pushVePull().timeout(turSuresi, onTimeout: _turSiniriAsildi);
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

  /// [turUstSinir]'a takılan turun sonucu.
  ///
  /// SINIRA TAKILMAK BİR HATADIR, "başarılı ama kısa kesildi" değil: gönderilemeyen kayıtlar
  /// cihazda bekliyor, inmeyen sayfalar eksik. `ok: true` demek, kapatmaya çalıştığımız
  /// sessizlik sınıfının aynısı olurdu.
  ///
  /// CİNS `sunucu` — bant kullanıcıya YALAN söylememeli:
  ///  • `ag` ("Bağlantı yok") yanlış olurdu: taşımada istek başına 25 sn kapısı zaten var; ağ
  ///    ölü olsaydı tur 90 sn'ye varmadan `ag` ile düşerdi. Sınıra gelmek "istekler yanıtlanıyor
  ///    ama tur bütçeye sığmıyor" demektir; kullanıcıyı telefonunu/wifi'sini kurcalamaya
  ///    yollamak, 2026-08-05'te kapatılan günahın aynısı olurdu.
  ///  • `veri` ("destekle görüşün") de yanlış: ortada bozuk kayıt ya da sürüm çarpıklığı yok,
  ///    ne kullanıcının ne desteğin yapabileceği bir şey var.
  ///  • `sunucu` ("Sunucu yanıt vermiyor · tekrar denenecek") kalır ve DÜRÜSTTÜR: sunucuya
  ///    ULAŞILDI, işini bu turda bitiremedi, kendiliğinden yeniden denenecek. "Tekrar denenecek"
  ///    sözü burada gerçektir — pull imleci sayfa sayfa kalıcı yazılır, snapshot ise ya tümüyle
  ///    uygulanır ya hiç: GERİ SARMA yok, en fazla TEKRAR var (bkz. [turUstSinir]).
  ///
  /// ⚠️ `.timeout` FIRLATMAZ, DEĞER DÖNDÜRÜR (`onTimeout`) — bilinçli: taşımanın 25 sn'lik kapısı
  /// da `TimeoutException` fırlatıyor ve o `ag` demek ZORUNDA (yarı-açık bağlantı, sunucuya
  /// ulaşılamadı — `sync_zaman_asimi_test` bunu kilitliyor). `on TimeoutException catch` yazsaydık
  /// iki farklı gerçek tek kefeye düşer, "çevrimdışısın" ile "sunucu yavaş" birbirine karışırdı.
  ///
  /// ⚠️ KABUL EDİLEN TAKAS: `Future.timeout` ALTINDAKİ İŞİ İPTAL ETMEZ — kesilen tur arka planda
  /// sayfalarını uygulamayı sürdürür ve bu sırada yeni bir tur başlayabilir. Örtüşme zararsızdır
  /// (her sayfa kendi transaction'ında, yazımlar idempotent/LWW); alternatifi — turu "bitene
  /// kadar" kilitlemek — tam da bu sınırın kaldırmak için var olduğu arızadır.
  static SyncOutcome _turSiniriAsildi() => const SyncOutcome(
        ok: false,
        error: 'Tur zaman aşımı',
        tur: SyncHataTuru.sunucu,
      );

  /// Turun ASIL İŞİ — [_turAt]'tan ayrı bir fonksiyon olması, üstüne tek bir `.timeout` sarmak
  /// içindir; hata sınıflandırması ve durum yayını orada kalır.
  Future<SyncOutcome> _pushVePull() async {
    final ozet = await _engine.pushPending();
    // Pull, push kalıcı red yese DE koşar: gelen veriyi kullanıcıdan esirgemek için sebep yok
    // (iki yön birbirinden bağımsız).
    final atlanan = await _engine.pull();
    // Sunucu bir kaydı KALICI olarak reddettiyse tur "başarılı" sayılamaz — o sipariş/tahsilat
    // bu telefonda var, sunucuda YOK. Sessiz kalmak, bu arızanın aylarca görünmemesinin ta
    // kendisiydi. Cins `veri`: ne ağ ne oturum sorunu, sunucuya ulaşıldı ve geri çevrildi.
    //
    // AYNI KEFEDE: pull'un AYRIŞTIRAMADIĞI satırlar (sürüm çarpıklığı — sunucu şeması ilerledi,
    // bu build o yükü okuyamıyor). Motor artık o satırı atlayıp kuyruğu açık tutuyor; kuyruğu
    // kurtarmanın bedeli SESSİZLİK olamaz — cins yine `veri`, çünkü çare beklemek değil
    // uygulamayı güncellemektir.
    return ozet.kaliciRed || atlanan > 0
        ? SyncOutcome(
            ok: false,
            pushed: ozet.gonderildi,
            karantina: ozet.karantina,
            error: ozet.kaliciRed
                ? 'Sunucu bazı kayıtları kabul etmedi'
                : 'Sunucudan gelen bazı kayıtlar okunamadı',
            tur: SyncHataTuru.veri,
          )
        : SyncOutcome(ok: true, pushed: ozet.gonderildi, karantina: ozet.karantina);
  }

  /// UYGULAMA ÖN PLANDAYKEN tur aralığı (2026-08-09 kararı). Patronun yazımı artık anında push
  /// ediliyor (bkz. [yazimTetigiBagla]) ama KURYE onu ancak kendi pull'unda görür — 2 dakika,
  /// elinde telefonla bekleyen bir kurye için "gelmiyor" demektir ve çözümü "yenilemeye bas"
  /// olamaz. Ekranı açık olan cihaz zaten prizde/kullanımdadır; 30 sn'lik boş bir delta isteği
  /// (değişiklik yoksa yanıt bir avuç bayt) bu maliyeti hak ediyor.
  static const onPlanAralik = Duration(seconds: 30);

  /// ARKA PLANDAYKEN tur aralığı. Kullanıcı ekrana bakmıyorken 30 sn'de bir uyanmak pili boşuna
  /// yakar; beklenen kopukluklar kısa (BRIEF) ve 2 dk baştan beri yeterliydi.
  static const arkaPlanAralik = Duration(minutes: 2);

  /// Periyodik senkronu başlatır. Varsayılan ÖN PLAN aralığıdır: `start()` yalnız açılışta ve
  /// girişten sonra çağrılır, ikisinde de uygulama kullanıcının elindedir. Arka plana geçişte
  /// kabuk [aralikAyarla] ile gevşetir.
  void start({Duration every = onPlanAralik}) {
    _timer?.cancel();
    _aralik = every;
    _timer = Timer.periodic(every, (_) => syncNow());
    // İlk turu hemen at (login/açılış sonrası veri gecikmesin).
    unawaited(syncNow());
  }

  /// Tur aralığını DEĞİŞTİRİR (ön plan ⇄ arka plan). [start]'tan farkı: tur ATMAZ ve durdurulmuş
  /// bir servisi diriltmez.
  ///
  /// Tur atmaması bilinçli: bunu çağıran `resumed` dalı zaten kendi turunu açıyor; burada bir tur
  /// daha atmak her öne gelişte çift istek demekti. Durdurulmuş servisi diriltmemesi de bilinçli:
  /// çıkış yapıldıktan sonra gelen bir yaşam döngüsü olayı senkronu yeniden başlatmamalı
  /// (`stop()` `_timer`ı null bırakır — kapı budur).
  void aralikDegistir(Duration every) {
    if (_aralik == every) return; // gereksiz yeniden kurulum yok (sayaç baştan başlardı)
    _aralik = every;
    if (_timer == null) return; // servis durdurulmuş: aralık saklanır, zamanlayıcı kurulmaz
    _timer!.cancel();
    _timer = Timer.periodic(every, (_) => syncNow());
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

  /// YEREL YAZIM TETİĞİ (2026-08-09 saha arızası): outbox'a kayıt düşünce turu AÇAR.
  ///
  /// ARIZA: patron siparişi kuryeye atıyor, kurye yenilese bile göremiyor; patron uygulamayı alta
  /// alıp öne getirince görüyor. Atama outbox'a düzgün düşüyordu ama hiçbir şey push'u
  /// tetiklemiyordu — tur yalnız zamanlayıcı · ağ değişimi · öne gelme · aşağı çekme ile
  /// açılıyordu ("alta alıp açınca gidiyor" = `resumed` turu). Tutarlılık değil GECİKME arızası.
  ///
  /// KAYNAK BEKLEYEN SAYISI AKIŞIDIR ([AppDatabase.watchBekleyenSayisi]), `enqueueOutbox`ten
  /// çağrı değil: her yazım bir transaction içindedir ve commit'ten önce açılan tur ya kaydı
  /// göremez ya da yazma kilidine girer. Drift'in bildirimi commit SONRASI düşer. Parametre
  /// enjekte edilebilir bırakıldı ki testler sahte bir akışla (ve sahte süreyle) koşabilsin.
  ///
  /// ⚠️ YALNIZ ARTIŞTA TETİKLER — düzeltmenin en kolay kaçırılan yeri: push kayıtları `acked`
  /// yapınca bekleyen sayısı DÜŞER ve akış yine yayın yapar; düşüşe de tur açsaydık her tur bir
  /// sonrakini doğurur, sonsuz döngü olurdu (pil + kota). İlk yayın da tetiklemez, yalnız taban
  /// değeri kurar: açılışta bekleyen kayıt varsa onu zaten [start] gönderiyor.
  ///
  /// Bilinen kör nokta: aynı yayında 1 ekleme + 1 ack olursa sayı sabit kalır ve tetik kaçar.
  /// O kayıt KAYBOLMAZ, en fazla bir sonraki periyodik tura kalır — kabul edilmiş takas.
  ///
  /// [gecikme] PENCEREYİ YENİDEN BAŞLATMAZ — klasik debounce her olayda sayacı sıfırlar ve toplu
  /// bir yazımda (gün kapanışı onlarca satır yazabilir) turu sürekli erteler. Burada İLK artış
  /// pencereyi açar, pencereye düşen artışlar aynı tura biner: tur en geç [gecikme] sonra koşar
  /// ve art arda N yazım TEK tur eder. Varsayılan 800 ms: "anında" hissettirecek kadar kısa, tek
  /// bir işlemin (teslim = 1 sipariş olayı + 3 defter kaydı) parçalarını toplayacak kadar uzun.
  void yazimTetigiBagla({
    Stream<int>? bekleyenSayisi,
    Duration gecikme = const Duration(milliseconds: 800),
  }) {
    _yazimSub?.cancel();
    _sonBekleyen = null;
    // onError YUTAR — [tetikleyiciBagla] ile aynı gerekçe: tetik bir İYİLEŞTİRMEDİR, senkronun
    // şartı değil. Kaynağın susması senkronu ya da uygulamayı düşürmemeli.
    _yazimSub = (bekleyenSayisi ?? db.watchBekleyenSayisi()).listen((sayi) {
      final onceki = _sonBekleyen;
      _sonBekleyen = sayi;
      if (onceki == null || sayi <= onceki) return; // taban kurulumu ya da ack'ten gelen düşüş
      if (_yazimGecikme?.isActive ?? false) return; // pencere zaten açık, bu yazım ona binsin
      _yazimGecikme = Timer(gecikme, () => unawaited(_yazimTuru()));
    }, onError: (Object _) {});
  }

  /// Yazım tetiğinin turu. Süren bir tura BAĞLANMAK yetmez: o turun `pushPending` seçkisi bu
  /// yazımdan ÖNCE alınmış olabilir ve kayıt bir sonraki tura — yani aralık kadar sonrasına —
  /// kalırdı; düzeltmek istediğimiz arızanın ta kendisi. Önce süren tur beklenir, sonra TAZE tur.
  ///
  /// Çağıran hiçbir yerde beklenmez (`unawaited`): yazım yolu ağa ASLA bağlanmaz (kırmızı çizgi
  /// #3). Çevrimdışıyken tur açılır, `SyncHataTuru.ag` ile düşer, kayıt outbox'ta bekler —
  /// bugünkü davranışın aynısı, bedeli bir başarısız istek.
  Future<void> _yazimTuru() async {
    final suren = _tur;
    if (suren != null) await suren;
    await syncNow();
  }

  void stop() {
    _timer?.cancel();
    _timer = null;
    _tetikSub?.cancel();
    _tetikSub = null;
    // Gecikme zamanlayıcısı da BIRAKILIR: çıkış yapıldıktan sonra açılacak bir tur oturumsuzdur
    // (ve widget testinde bekleyen bir Timer testi asardı).
    _yazimSub?.cancel();
    _yazimSub = null;
    _yazimGecikme?.cancel();
    _yazimGecikme = null;
    // Taban da sıfırlanır: yeniden bağlanınca ilk yayın yine yalnız TABAN kurar, tur açmaz —
    // yoksa çıkış/giriş sonrası bekleyen kayıtlar sahte bir "artış" gibi görünürdü.
    _sonBekleyen = null;
  }

  void dispose() {
    stop();
    _status.close();
  }
}
