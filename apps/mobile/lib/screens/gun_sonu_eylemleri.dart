// GÜN SONU EKRANININ PARA EYLEMLERİ — ara tahsilat · iptali · gider · iptali · günü kapatma.
//
// NEDEN AYRI DOSYA: `day_end_screen.dart` 513 satıra çıkmıştı (500 satır kuralı). Bölme çizgisi
// para ile çizim arasından geçiyor: buradaki üç eylem DEFTERE YAZAR (kasa devri, iptal kaydı,
// gün kapanışı) ve her biri geri alınamaz sonuçlar doğurur; ekranın geri kalanı okur ve çizer.
//
// ⚠️ KAPILAR ÇİFTTİR ve bu bilinçli: düğme zaten çizilmediği hâlde eylem yine yetkiyi sorar.
// Native/bayat bir dokunuş ya da ileride açılacak ikinci bir giriş noktası, çizim kapısını
// atlayabilir — yazma yolunun kendi kapısı olmalı.
//

part of 'day_end_screen.dart';

/// Gün sonu ekranının DEFTERE YAZAN yüzeyi.
extension _GunSonuEylemleri on _DayEndScreenState {
  Future<void> _araTahsilat(List<User> kuryeler, GunSonuGorunumu g) async {
    if (!_araTahsilatAlabilir(g)) return; // düğme zaten çizilmedi; çift kapı (K2 pazarlıksız)
    final tazelensin = await araTahsilatAl(
      context,
      db: widget.db,
      gorunum: g,
      kuryeId: _kuryeId!,
      kuryeAdi: _kapsamAdi(kuryeler),
      alanUserId: widget.kullaniciId,
      bugun: _bugun,
    );
    if (tazelensin && mounted) _tazele();
  }

  /// Bir ara tahsilatı İPTAL eder (kullanıcı kararı 2026-08-13). Kayıt SİLİNMEZ — repo ters
  /// işaretli ikinci bir devir satırı yazar (BRIEF kırmızı çizgi #2).
  Future<void> _araTahsilatiIptalEt(AraTahsilatKaydi k) async {
    if (!_araTahsilatIptalEdebilir) return; // satır zaten dokunulamaz; çift kapı (K2 pazarlıksız)
    final tazelensin = await araTahsilatIptalEt(
      context,
      db: widget.db,
      kayit: k,
      iptalEdenUserId: widget.kullaniciId,
    );
    if (tazelensin && mounted) _tazele();
  }

  /// SAHA GİDERİ EKLER (kullanıcı isteği 2026-08-25) — kasadan çıkan nakdin defter kaydı.
  ///
  /// KAYIT SEÇİLİ KAPSAMA YAZILIR: kişi kapsamındaysa o kişiye, gün hesabındaysa oturumdaki
  /// kullanıcıya. Ayrı bir "kim harcadı" seçicisi YOK — patron Ali'nin benzinini yazmak istiyorsa
  /// kapsamı Ali'ye çevirir, tıpkı ondan ara tahsilat alırken yaptığı gibi. İki ayrı yol açmak,
  /// aynı kararın iki yerden verilmesi olurdu.
  ///
  /// ⚠️ YETKİ KAPISI ÇİFTTİR (K2 pazarlıksız): düğme zaten çizilmedi, eylem yine sorar.
  Future<void> _giderEkle(List<User> kuryeler, GunSonuGorunumu g) async {
    if (!_giderEkleyebilir(g)) return;
    final harcayan = _kuryeId ?? widget.kullaniciId;

    final sonuc = await giderSheet(
      context,
      kapsamAdi: _kuryeId == null ? 'Gün' : _kapsamAdi(kuryeler),
      // Kapsamda ŞU AN görünen nakit — yalnız "bu tutar kasadakinden fazla" uyarısı için.
      // Kayda giden hiçbir rakam bundan türemez.
      mevcutNakit: g.kapsam.kasa.netNakit,
    );
    if (sonuc == null || !mounted) return;

    // ÜÇÜNCÜ KAPI REPODA (ara tahsilattaki desenin aynısı): sheet AÇIKKEN senkron başka bir
    // cihazdan gelen kapanışı indirebilir ve o an ekranın bildiği durum bayattır. Mesaj repo'dan
    // geldiği gibi basılır — NE olduğunu bilirken "bir şeyler ters gitti" demek bilgi saklamaktır.
    try {
      await GiderRepository(widget.db).ekle(
        kurus: sonuc.kurus,
        aciklama: sonuc.aciklama,
        harcayanId: harcayan,
      );
    } on StateError catch (e) {
      if (!mounted) return;
      SipToast.goster(context, e.message);
      _tazele(); // ekranı gerçeğe döndür: kapanmış kapsam artık kilitli görünsün
      return;
    }
    if (!mounted) return;

    SipToast.goster(context, '${sipTutar(sonuc.kurus)} gider kaydedildi');
    _giderTazele();
  }

  /// Bir gideri İPTAL eder. Kayıt SİLİNMEZ — repo ters işaretli ikinci bir gider satırı yazar
  /// (BRIEF kırmızı çizgi #2). Onay adımı ZORUNLU: satır kaydırılan bir listenin ortasında duruyor
  /// ve kazara dokunuş kalıcı bir düzeltme kaydı yazardı.
  Future<void> _giderIptalEt(GiderSatiri s) async {
    if (!_giderIptalEdebilir) return; // satır zaten dokunulamaz; çift kapı
    final onay = await giderIptalOnayi(
      context,
      tutarKurus: s.kurus,
      aciklama: s.aciklama,
    );
    if (!onay || !mounted) return;

    try {
      await GiderRepository(widget.db)
          .iptal(giderId: s.id, iptalEdenUserId: widget.kullaniciId);
    } on StateError catch (e) {
      if (!mounted) return;
      SipToast.goster(context, e.message);
      _giderTazele();
      return;
    }
    if (!mounted) return;

    SipToast.goster(context, '${sipTutar(s.kurus)} gider iptal edildi');
    _giderTazele();
  }

  /// Kapatılmış bir hesabı GERİ ALIR (kullanıcı kararı 2026-08-18). Kayıt SİLİNMEZ — repo ters
  /// bir kapanış satırı yazar ve varsa bağlı kasa devrini de aynı transaction'da geri alır
  /// (BRIEF kırmızı çizgi #2).
  ///
  /// Yetki kapısı BURADA DA sorulur (çift kapı, K2 pazarlıksız): düğme çizilmemiş olsa bile bu
  /// fonksiyon kendi başına güvenli olmalı.
  Future<void> _kapanisiGeriAl(DayClosing kapanis, List<User> kuryeler) async {
    if (!_kapanisGeriAlabilir) return;
    final tazelensin = await kapanisGeriAl(
      context,
      db: widget.db,
      session: widget.session!,
      kapanis: kapanis,
      kapsamAdi: kapanis.userId == null
          ? 'Gün'
          : (kullaniciAdi(kuryeler, kapanis.userId) ?? 'Kurye'),
    );
    if (tazelensin && mounted) _tazele();
  }

  /// GEÇMİŞ BİR GÜNÜ KAPATIR — sayım İSTENMEDEN (kullanıcı isteği 2026-08-21).
  ///
  /// ══ NEDEN YALNIZ GÜN KAPSAMI ═══════════════════════════════════════════════════════════
  /// Kurye kapanışı bir MUTABAKAT PENCERESİNİ kapatır (`CashHandoverRepository._pencere` son
  /// kurye kapanışından başlar). Geçmiş bir güne kurye kapanışı yazmak pencereyi o güne taşır ve
  /// o günden bugüne toplanmış ama teslim edilmemiş para BEKLENENDEN DÜŞER — yani kuryenin
  /// cebindeki gerçek nakit sessizce silinir.
  ///
  /// ══ NEDEN SAYIM YOK ════════════════════════════════════════════════════════════════════
  /// Üç gün önceki kasa bugün sayılamaz. Sayım alınsaydı `diff` arşive KALICI olarak yanlış
  /// donardı (append-only). Kayıt "sayım yapılmadı" (counted=null, fark 0) olarak geçer.
  ///
  /// AÇIK SİPARİŞ ENGELİ DURUYOR ve durmalı: o sipariş hâlâ gerçekten açıktır ve kullanıcı onu
  /// teslim edip ya da iptal edip günü kapatabilir. Aşılabilir olduğu için ölü bir engel değil.
  Future<void> _gecmisGunuKapat(GunSonuGorunumu g) async {
    if (!_kapatmaCubugu(g)) return; // çift kapı (K2 pazarlıksız)

    final onizleme =
        await DayClosingRepository(widget.db).onizle(ClosingScope.day, localDate: _gun);
    if (!mounted) return;

    final sonuc = await gunKapatmaSheet(
      context,
      kapsamAdi: gunTamBasligi(_gun),
      gunHesabi: true,
      beklenen: onizleme.expectedCashKurus,
      tamNakit: onizleme.gunNakitKurus,
      teslimat: onizleme.deliveryCount,
      ortaEtiket:
          onizleme.dusulenKurus < 0 ? 'Kuryelerden devir' : 'Kuryelerde kalan',
      ortaTutar: onizleme.dusulenKurus,
      giderTutar: onizleme.giderKurus,
      sayimIstenmiyor: true,
    );
    if (sonuc == null || !mounted) return;

    try {
      await DayClosingRepository(widget.db).kapat(
        scope: ClosingScope.day,
        countedCashKurus: null, // sayım YOK — sheet de istemedi
        note: sonuc.not.isEmpty ? null : sonuc.not,
        localDate: _gun,
      );
    } on StateError catch (e) {
      if (!mounted) return;
      SipToast.goster(context, e.message);
      _tazele();
      return;
    }
    if (!mounted) return;
    SipToast.goster(context, '${gunTamBasligi(_gun)} kapatıldı');
    _kapanistanSonraTazele();
  }

  Future<void> _kapat(List<User> kuryeler, GunSonuGorunumu g) async {
    // GEÇMİŞ GÜN AYRI BİR AKIŞTIR ve burada AYRIŞIR: sayım istenmez, yalnız gün kapsamı
    // kapatılır ve damga seçili güne yazılır (gerekçeler [_gecmisGunuKapat] üzerinde).
    if (!g.bugunMu) return _gecmisGunuKapat(g);

    if (!_kapatabilir) return; // düğme zaten kapalı; çift kapı (K2 pazarlıksız)
    final kapsamAdi = _kapsamAdi(kuryeler);
    final scope = _kuryeId == null ? ClosingScope.day : ClosingScope.courier;

    // ÜÇ RAKAM DA REPO'DAN GELİR — ekran hiçbirini çıkarmaz, çıkarmamalı da.
    //
    // TARİHÇE (2026-08-06, iki kez ısırdı): önce burada görünüm modelinin "günün nakdi − ara
    // tahsilat" getter'ı kullanılıyordu. O formül GÜN kapsamında doğru, KURYE kapsamında
    // yanlıştı — kurye kapanışı beklenen tutarı kendi mutabakat penceresinden türetiyordu ve
    // ikisini üst üste koymak aynı parayı iki kez düşürüyordu. Sheet'te yazan tutar arşive
    // donan tutardan AYRIŞACAKTI ve kayıtlar append-only olduğu için o fark kalıcı olurdu.
    // Getter o yüzden repo'dan tamamen kaldırıldı; beklenen nakdin tanımı artık tek yerde
    // (`DayClosingRepository.onizle`) yaşıyor ve iki kapsam onu paylaşıyor.
    //
    // Yani buradaki kural sadece üslup değil: bu ekranda para formülü yazmak, sessizce yalan
    // bir arşiv kaydı üretmenin en kısa yoludur.
    // GÜN, YAZMA ANINDA yeniden okunur (`_gun` alanına güvenilmez): ekran akşamdan beri açık
    // durmuş ve gece yarısını geçmiş olabilir. Damga DÜZELTİLMİŞ sunucu saatinden gelir — cihaz
    // saati 40 dk ileriyken 23:40'ta `bugunTr()` yarını verir ve kapanış yanlış güne yazılırdı.
    final gun = await bugunTrDuzeltilmis(widget.db);
    final onizleme = await DayClosingRepository(widget.db)
        .onizle(scope, userId: _kuryeId, localDate: gun);
    // Çerçeve satırı YALNIZ kurye kapsamındadır: gün kapsamında sheet de ekran da TAKVİM GÜNÜ
    // konuşur, açıklanacak bir aralık farkı yoktur.
    final not = _kuryeId == null
        ? null
        : await cerceveNotu(
            widget.db,
            g,
            _kuryeId!,
            gun,
            pencereNakit: onizleme.gunNakitKurus,
            pencereTeslim: onizleme.dusulenKurus,
          );
    if (!mounted) return;

    final sonuc = await gunKapatmaSheet(
      context,
      kapsamAdi: kapsamAdi,
      gunHesabi: _kuryeId == null,
      beklenen: onizleme.expectedCashKurus,
      tamNakit: onizleme.gunNakitKurus,
      teslimat: onizleme.deliveryCount,
      // ETİKETLER KAPSAMDAN DEĞİL, VERİDEN TÜRER. `_kuryeId == null` diye çıkarım yapmıyoruz:
      // düşülen tutarın ne olduğunu repo `dusulenKalem` ile SÖYLÜYOR. Çıkarım yapsaydık, tanım
      // bir daha değiştiğinde (bu vardiyada üç kez değişti) ekran sessizce eski anlamı yazmaya
      // devam ederdi; enum ise yeni bir değer eklendiği an derlemeyi kırar.
      ustEtiket: switch (onizleme.dusulenKalem) {
        // Kurye kapsamında üst satır günün tamamı DEĞİL, o kuryenin PENCERE nakdidir (son
        // kapanışından beri topladığı). Kurye gün içinde bir kez kapatıp yeniden çalışmışsa
        // "Günün nakdi" yazmak yanlış olur — kimlik ancak aynı çerçevede tutar.
        DusulenKalem.teslimEdilen => 'Topladığı',
        DusulenKalem.kuryelerdeKalan => 'Günün nakdi',
      },
      // "Teslim edilen" EDİLGEN biçimdedir ve bilinçlidir: bu sheet'i kurye de patron da açıyor,
      // edilgen biçim ikisinde de doğru okunuyor ("aldığım"/"verdiğim" ayrımına düşmüyor).
      //
      // GÜN KAPSAMINDA İŞARET KELİMEYİ DE DEĞİŞTİRİR. Düşülen tutar orada kuryelerin O GÜNKÜ NET
      // DEĞİŞİMİDİR ve negatif olabilir: kurye dünden taşıdığı nakdi bugün teslim ettiyse kasaya
      // günün kendi nakdinden FAZLASI girer. "Kuryelerde kalan: + 5.000 ₺" cümlesi o durumda
      // düpedüz yalandır — o para kuryede KALMADI, tam tersine kuryeden GELDİ. İşareti düzeltip
      // kelimeyi bırakmak, bu vardiyanın altı kez ısırdığı hatanın aynısı olurdu: anlamı değişen
      // sayıyı eski kelimesiyle taşımak.
      //
      // KURYE kapsamında böyle bir dal YOK ve olmamalı: teslim ancak AYNI pencerede toplanmış
      // paradan yapılabilir (`_pencere` alttan açıktır), yani orada negatif matematiksel olarak
      // imkânsızdır. Dal açsaydık, hiç oluşamayacak bir hâl için test edilemeyen kopya yazardık.
      ortaEtiket: switch (onizleme.dusulenKalem) {
        DusulenKalem.teslimEdilen => 'Teslim edilen',
        DusulenKalem.kuryelerdeKalan => onizleme.dusulenKurus < 0
            ? 'Kuryelerden devir'
            : 'Kuryelerde kalan',
      },
      ortaTutar: onizleme.dusulenKurus,
      // GİDER SATIRI (2026-08-25): beklenen tutar giderden sonraki paradır ve döküm bunu
      // yazmazsa bayi sebepsiz küçülmüş bir rakam görür. Sıfırken satır hiç çizilmez.
      giderTutar: onizleme.giderKurus,
      cerceveNotu: not,
      // TAZELİK HER İKİ KAPSAMA DA geçilir (lead kararı 2026-08-06): kurye kendi telefonundan
      // da ara tahsilat teslim edebildiği için "günü kapatan cihaz zaten tahsilatı alan
      // cihazdır" varsayımı tutmuyor — risk simetrik. Gürültü ayarı sheet'in içinde: gün
      // kapsamında şerit yalnız BAYATKEN çizilir.
      senkron: g.senkron,
    );
    if (sonuc == null || !mounted) return;

    // Kapanış rakamları burada YENİDEN hesaplanmaz: repo submit anında kendi önizlemesini
    // çağırır, böylece arşive donan tutar ekranın gösterdiğiyle aynı koddan çıkar.
    // Fark ≠ 0 kapatmayı ENGELLEMEZ (BRIEF: eksik para görünür kalmalı) — kanıt olarak yazılır.
    //
    // ÜÇÜNCÜ KAPI REPODA (ara tahsilattaki desenin aynısı): kapanmış kapsam `StateError` atar.
    // Ekran düğmeyi zaten kapatıyor, ama sheet AÇIKKEN senkron başka bir cihazdan gelen kapanışı
    // indirebilir — o an ekranın bildiği durum bayattır. Yakalamasaydık kullanıcı, sayımını
    // girip "Kapat"a bastıktan sonra hiçbir açıklama görmeden çöken bir ekranla kalırdı. Mesaj
    // repo'dan geldiği gibi basılır: NE olduğunu bilirken "bir şeyler ters gitti" demek bilgi
    // saklamaktır.
    try {
      await DayClosingRepository(widget.db).kapat(
        scope: scope,
        userId: _kuryeId,
        countedCashKurus: sonuc.sayilan,
        note: sonuc.not.isEmpty ? null : sonuc.not,
        alsoHandover: _kuryeId != null,
        localDate: gun,
      );
    } on StateError catch (e) {
      if (!mounted) return;
      SipToast.goster(context, e.message);
      _tazele(); // ekranı gerçeğe döndür: kapanmış kapsam artık kilitli görünsün
      return;
    }
    if (!mounted) return;

    SipToast.goster(
      context,
      _kuryeId == null
          ? 'Gün kapatıldı ve arşivlendi'
          : '$kapsamAdi hesabı kapatıldı ve arşivlendi',
    );
    // BANT DA TAZELENİR: bugün kapatıldığında "kapanmamış günler" sayacı bir azalır ve eskiden
    // bunu ancak ekran yeniden açıldığında öğreniyordu.
    _kapanistanSonraTazele();
  }
}
