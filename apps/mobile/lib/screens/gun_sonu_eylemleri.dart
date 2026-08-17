// GÜN SONU EKRANININ PARA EYLEMLERİ — ara tahsilat · ara tahsilat iptali · günü kapatma.
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

  Future<void> _kapat(List<User> kuryeler, GunSonuGorunumu g) async {
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
    _tazele();
  }
}
