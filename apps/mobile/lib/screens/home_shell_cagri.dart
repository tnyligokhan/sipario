// KABUĞUN ÇAĞRI YÜZEYİ — çağrı geçmişi · çağrı kartı · kart eylemleri · bildirim yolları.
//
// NEDEN AYRI DOSYA: `home_shell.dart` 1022 satıra çıkmıştı (500 satır kuralı). Sınır burada
// kendiliğinden duruyordu: bu yüzeyin tamamı TEK bir soruyu cevaplar — "telefon çaldı ya da
// bir bildirime dokunuldu, kabuk nereye gidecek?". Kararı kabuk verir çünkü ne çağrı katmanı
// müşteri ekranını tanır, ne bildirim katmanı sekmeleri.
//
// NEDEN `part` (ayrı kütüphane değil): eylemlerin hepsi kabuğun ÖZEL durumunu okur/yazar
// (`_sekme`, `_yazilabilir`, `_yetki`). Ayrı kütüphane yapmak bu alanları herkese açmayı ya da
// on parametreli fonksiyonlar yazmayı gerektirirdi; `part` mahremiyeti korur (aynı desen:
// `sync_engine.dart` → `sync_cekme.dart`).
//
// ⚠️ `setState` DOĞRUDAN ÇAĞRILMAZ: `@protected`tır ve extension sınıfın kendisi değildir
// (`invalid_use_of_protected_member`). Kabuk tek kapıyı açar: `_durumDegisti`.

part of 'home_shell.dart';

/// Kabuğun ÇAĞRI ve BİLDİRİM yüzeyi.
extension _CagriYuzeyi on _HomeShellState {
  /// Dükkânın çağrı geçmişi. GİRİŞİ ÇEKMECEDEDİR (2026-08-13) — eskiden Ayarlar → Arayan
  /// Tanıma bölümünün içindeydi ve orası yanlış yerdi: bu bir İŞ KAYDIDIR, bir tercih değil.
  /// Ayarların içinde üç dokunuş derinlikteydi; şimdi hangi sekmede olunursa olunsun iki.
  ///
  /// Kapı `cagriGunlugu`dur ve çekmece satırı da aynı ölçütle çizilir; burası ikinci kapı.
  void _cagriGecmisiAc() {
    if (!_yetki.cagriGunlugu) {
      SipToast.goster(context, 'Çağrı geçmişi bu hesaba kapalı.');
      return;
    }
    _git(CagriGunluguSayfasi(
      db: widget.db,
      onGeri: () => Navigator.of(context).maybePop(),
      onAc: _aramayiAc,
    ));
  }

  /// Bir arama satırına dokunulduğunda (s-uygulama.jsx:90 kuralı): kayıtlıysa müşteri defteri,
  /// kayıtsızsa çağrı kartı.
  ///
  /// AYARLAR EKRANINDAN BURAYA TAŞINDI ve taşınırken bir açık kapandı: oradaki kopya müşteri
  /// kartını `yetki` GEÇMEDEN açıyordu, yani `cagriGunlugu` açılmış bir kurye o yoldan yönetici
  /// eylemlerine ulaşıyordu. Kabuk yetkiyi zaten taşıyor; ekranın kabukta yaşaması bu sınıf
  /// hatayı yapısal olarak zorlaştırıyor.
  ///
  /// Kayıt durumu DOKUNMA ANINDA yeniden çözülür: geçmiş satırı çağrı ANINDAKİ eşleşmeyi taşır
  /// ve arayan o çağrıdan sonra müşteri olarak kaydedilmiş olabilir.
  Future<void> _aramayiAc(AramaKaydi arama) async {
    final kisi = await cagriKisiCoz(widget.db, arama.numara);
    if (!mounted) return;

    final musteriId = arama.musteriId ?? kisi.musteriId;
    if (musteriId != null) return _musteriAc(musteriId);

    // Yön GEÇMİŞ SATIRINDAN gelir: kart yönü kendi başına bilemez, verilmezse "GELEN ÇAĞRI"
    // varsayar ve bayi kendi yaptığı aramanın kartında gelen çağrı görürdü.
    final eylem = await cagriKartiGoster(context, kisi: kisi, yon: arama.tip);
    if (eylem != CagriEylemi.kaydet || !mounted) return;

    if (!_yazilabilir) {
      SipToast.goster(context, 'Salt-okunur kip: yeni müşteri eklenemez.');
      return;
    }
    final eklendi = await musteriEkleSheet(context, db: widget.db, onTel: arama.numara);
    if (eklendi != true || !mounted) return;

    final yeni = await cagriKisiCoz(widget.db, arama.numara);
    final yeniId = yeni.musteriId;
    if (yeniId == null || !mounted) return;
    await _musteriAc(yeniId);
  }

  /// Çağrı kartını HAM numaradan açar. Kartın modelini `cagriKisiCoz` kurar (defterden çözer);
  /// kabuk numarayı kendisi yorumlamaz. Çözücü null/hata döndürmez — kayıtsızda kart
  /// "Müşteri Olarak Kaydet" varyantına düşer.
  ///
  /// ESKİDEN doğrudan `CagriKisi.kayitsiz(no)` geçiliyordu: kart HER ZAMAN "Kayıtsız" çıkıyor,
  /// bakiye şeridi / müşteri kodu / adres / "Defteri Aç" dalları hiç çizilemiyordu.
  Future<void> _cagriKartiAc(String numara) async {
    final kisi = await cagriKisiCoz(widget.db, numara);
    if (!mounted) return;
    final eylem = await cagriKartiGoster(context, kisi: kisi);
    if (eylem == null || !mounted) return;
    await _cagriEylemiUygula(eylem, kisi);
  }

  /// Kart KAPANDIKTAN sonra çalışan gezinme. Tasarım `s-uygulama.jsx:111-113`: her eylem
  /// önce `setCagri(null)` ile kartı kapatır, sonra hedefe gider — kart kendini pop ederek
  /// kapandığı için burada kapatacak bir şey kalmaz, yalnız hedefe gidilir.
  ///
  /// ESKİDEN dönen eylem ATILIYORDU (`await cagriKartiGoster(...)`, sonuç kullanılmadan):
  /// "Sipariş Oluştur", "Defteri Aç" ve "Müşteri Olarak Kaydet" yalnız kartı kapatıyor,
  /// hiçbiri bir yere gitmiyordu. Cihazda görüldü, 2026-07-26.
  Future<void> _cagriEylemiUygula(CagriEylemi eylem, CagriKisi kisi) async {
    switch (eylem) {
      case CagriEylemi.kapat:
        return;

      case CagriEylemi.siparis:
        if (!_yazilabilir) {
          SipToast.goster(context, 'Salt-okunur kip: yeni sipariş oluşturulamaz.');
          return;
        }
        // Çağrı kartı native taraftan da gelebilir ve yetkiyi bilmez; kapı BURADA (2026-08-04).
        if (!_yetki.siparisAcma) {
          SipToast.goster(context, 'Bu hesap sipariş oluşturamaz — bayi yetkisi kapalı.');
          return;
        }
        _durumDegisti(() => _sekme = SipSekme.siparis);
        // Kayıtsız numarada `initialCustomerId` null kalır: form müşteri SEÇİMİ adımıyla
        // açılır. Düğme kayıtsız kartta zaten çizilmez ama native köprüsünden bayat bir
        // istek gelebilir (kart çizildikten sonra müşteri silinmiş olabilir).
        await _git(OrderFormScreen(
          db: widget.db,
          writable: _yazilabilir,
          initialCustomerId: kisi.musteriId,
        ));

      case CagriEylemi.defter:
        final musteriId = kisi.musteriId;
        // Numara artık deftere bağlı değilse defter açılamaz — sessiz kalmak yerine kartı
        // gösteriyoruz, bayi oradan "Müşteri Olarak Kaydet"e geçebilir.
        if (musteriId == null) return _cagriKartiAc(kisi.numara);
        _durumDegisti(() => _sekme = SipSekme.musteri);
        await _git(CustomerDetailScreen(
          db: widget.db,
          customerId: musteriId,
          writable: _yazilabilir,
          yetki: _yetki,
        ));

      case CagriEylemi.kaydet:
        if (!_yazilabilir) {
          SipToast.goster(context, 'Salt-okunur kip: yeni müşteri eklenemez.');
          return;
        }
        final eklendi =
            await musteriEkleSheet(context, db: widget.db, onTel: kisi.numara);
        if (eklendi != true || !mounted) return;
        // Tasarım `s-uygulama.jsx:116`: kayıttan sonra müşteri sekmesine geçilir ve YENİ
        // müşterinin defteri açılır. Kimliği çözücüden yeniden okuyoruz — sheet yalnız
        // "kaydedildi" bilgisini döndürür, numara ise az önce deftere yazıldı.
        final yeni = await cagriKisiCoz(widget.db, kisi.numara);
        final yeniId = yeni.musteriId;
        if (yeniId == null || !mounted) return;
        _durumDegisti(() => _sekme = SipSekme.musteri);
        await _git(CustomerDetailScreen(
          db: widget.db,
          customerId: yeniId,
          writable: _yazilabilir,
          yetki: _yetki,
        ));
    }
  }

  /// Native kartın (telefon çalarken çizilen Kotlin kartı) bekleyen eylemini alır ve
  /// Flutter kartıyla AYNI gezinmeyi uygular — iki kartın davranışı tek yerde tanımlı.
  Future<void> _nativeCagriEylemi() async {
    final istek = await bekleyenCagriEylemi();
    if (istek == null || !mounted) return;
    // Numara kart çizildiği andan beri değişmiş olabilir (o çağrıdan sonra kaydedilmiş
    // ya da silinmiş): karar ANLIK defterden verilir, native'in gördüğüne güvenilmez.
    final kisi = await cagriKisiCoz(widget.db, istek.numara);
    if (!mounted) return;
    await _cagriEylemiUygula(istek.eylem, kisi);
  }

  /// "Son Arama" bento kutusuna dokunma (`s-uygulama.jsx:90` `onAramaAc`): numara KAYITLIYSA
  /// müşteri sekmesine geçilip detayı açılır, KAYITSIZSA çağrı kartı gösterilir. Kararı çağrı
  /// günlüğü değil kabuk verir — o katman ne müşteri ekranını ne çağrı kartını tanır.
  Future<void> _aramaAc(AramaKaydi arama) async {
    final musteriId = arama.musteriId;
    if (musteriId == null) {
      // Çağrı günlüğünde eşleşme yoktu ama numara O ARADAN SONRA kaydedilmiş olabilir —
      // çözücü defteri yeniden okur, o hâlde kart dolu varyanta düşer.
      await _cagriKartiAc(arama.numara);
      return;
    }
    _durumDegisti(() => _sekme = SipSekme.musteri);
    await _git(CustomerDetailScreen(
      db: widget.db,
      customerId: musteriId,
      writable: _yazilabilir,
      yetki: _yetki,
    ));
  }

  /// Bildirime dokunulduğunda gidilecek yer (Faz 1 sözlüğü: `gunsonu` · `musteri/<id>`).
  ///
  /// NEDEN BURADA: `yol` bildirim yükünde zaten taşınıyordu ama tüketen uç yoktu — bayi
  /// bildirime dokunuyor, uygulama ana ekranda açılıyor ve "ne vardı?" diye arıyordu.
  /// Taşınan bilgi kullanılmıyorsa taşınmıyor demektir.
  ///
  /// TANINMAYAN YOLDA SESSİZCE ANA EKRAN: sözlük ileride büyüyecek (bkz. çok-müşterili liste
  /// rotası, Faz 2) ve eski sürüm yeni bir yolu görebilir. Bilinmeyen yol bir hata değil,
  /// yalnız bilinmeyen bir hedeftir — patlamak yerine kullanıcıyı bulunduğu yerde bırakır.
  Future<void> _bildirimYoluAc(String yol) async {
    // Sözlüğün ÇÖZÜMÜ sözleşmede (`bildirimYoluCoz`): taslağı üreten kural ile onu tüketen
    // kabuk aynı tanıma bakmalı, iki ayrı ayrıştırma olmamalı.
    final hedef = bildirimYoluCoz(yol);
    if (hedef == null) return;
    if (hedef.tur == 'gunsonu') {
      _durumDegisti(() => _sekme = SipSekme.gunSonu);
      return;
    }
    // Push bildirimleri (sipariş atandı · iptal edildi · teslim edildi) buraya düşer.
    // Kimliksizdir; gerekçe `bildirimYoluCoz` içinde (sipariş detay ekranı yok, olmayan
    // hedefe kimlik taşınmaz).
    if (hedef.tur == 'siparisler') {
      _durumDegisti(() => _sekme = SipSekme.siparis);
      return;
    }
    // "Yeni cihaz girişi" güvenlik bildiriminin hedefi. Uyarıyı görüp ne yapacağını
    // ARAMAK zorunda kalmasın: bağlı telefonların listesi tek dokunuş ötede olmalı.
    if (hedef.tur == 'cihazlar') {
      await _git(CihazlarEkrani(db: widget.db));
      return;
    }
    _durumDegisti(() => _sekme = SipSekme.musteri);
    await _git(CustomerDetailScreen(
      db: widget.db,
      customerId: hedef.id!,
      writable: _yazilabilir,
      yetki: _yetki,
    ));
  }

  /// UYGULAMA İÇİ BİLDİRİM KUTUSU (2026-08-21) — ana ekrandaki zil.
  ///
  /// Ekran, dokunulan satırın YOLUNU döndürür ve gezinmeyi kabuk yapar: sistem bildirimine
  /// dokunmakla listedeki satıra dokunmak AYNI yere gitmeli ([_bildirimYoluAc]). İki ayrı
  /// yönlendirme yazsaydık biri bir gün ötekinden farklı bir ekran açardı.
  Future<void> _bildirimleriAc() async {
    final yol = await Navigator.of(context).push<String>(
      MaterialPageRoute<String>(builder: (_) => BildirimlerEkrani(db: widget.db)),
    );
    if (yol == null || yol.isEmpty || !mounted) return;
    await _bildirimYoluAc(yol);
  }

  /// [YerelBildirimServisi.dokunulanYol] dinleyicisi. Değer tüketildikten sonra SIFIRLANIR:
  /// aksi hâlde aynı yol, sonraki her dinleyici kurulumunda yeniden açılırdı.
  void _bildirimDokunusu() {
    final yol = YerelBildirimServisi.dokunulanYol.value;
    if (yol == null || yol.isEmpty || !mounted) return;
    YerelBildirimServisi.dokunulanYol.value = null;
    unawaited(_bildirimYoluAc(yol));
  }
}
