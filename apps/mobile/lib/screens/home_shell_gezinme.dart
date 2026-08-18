// KABUĞUN GEZİNME YÜZEYİ — sekme seçimi · ekran açma · çekmece girişleri · FAB menüsü · çıkış.
//
// NEDEN AYRI DOSYA: `home_shell.dart` 1022 satıra çıkmıştı (500 satır kuralı). Bu yüzeyin ortak
// paydası tek cümle: "bir yere GİDİLİYOR". Hepsi `_git`ten geçer, hepsi çekmeceyi kapatır ve
// hepsi gitmeden önce yetki kapısını sorar — bu yüzden bir arada dururlar.
//
// ⚠️ İKİ GİRİŞ, TEK KAPI: bir ekrana hem bento kutusundan hem çekmeceden gidiliyorsa ikisi de
// AYNI fonksiyonu çağırır (`_borclularAc` deseni). Ayrı yazmak, iki girişin zamanla farklı
// yetkiyle açılması demektir — bu depoda tam olarak öyle bir açık doğdu (`CustomerDetailScreen`).
//
// NEDEN `part` ve `setState` yerine `_durumDegisti`: gerekçe `home_shell_cagri.dart` başlığında.

part of 'home_shell.dart';

/// Kabuğun GEZİNME yüzeyi.
extension _GezinmeYuzeyi on _HomeShellState {
  void _sekmeSec(SipSekme s) {
    _durumDegisti(() {
      _sekme = s;
      _cekmece = false;
    });
  }

  Future<void> _git(Widget ekran) async {
    _durumDegisti(() => _cekmece = false);
    await Navigator.of(context).push(MaterialPageRoute(builder: (_) => ekran));
    // Dönüşte elle tazeleme YOK: sync_meta akışı, açılan ekranın yaptığı her yazımı zaten
    // yakalar (tema, profil, kontör…). İki yol tutmak ikisinin ayrışması demekti.
  }

  void _cekmeceGirisi(CekmeceGiris g) {
    switch (g) {
      case CekmeceGiris.borclular:
        // Bento kutusuyla AYNI fonksiyon: iki giriş noktası, TEK yetki kapısı. Ayrı yazsaydık
        // ikisi zamanla ayrışırdı — bu depoda aynı ekranın iki girişinin farklı yetkiyle
        // açılması bir güvenlik açığına dönüştü (bkz. `CustomerDetailScreen.yetki`).
        _durumDegisti(() => _cekmece = false);
        _borclularAc();
      case CekmeceGiris.cagriGunlugu:
        _cagriGecmisiAc();
      case CekmeceGiris.harita:
        _git(SiparisHaritaEkrani(db: widget.db, writable: _yazilabilir));
      case CekmeceGiris.hesap:
        _git(HesapEkrani(db: widget.db, session: widget.session, onCikis: _cikis));
      case CekmeceGiris.urunler:
        if (!_yetki.urunYonetimi) {
          SipToast.goster(context, 'Ürün yönetimi yalnız yöneticilere açıktır.');
          return;
        }
        _git(ProductListScreen(db: widget.db, writable: _yazilabilir, rol: _userRole));
      case CekmeceGiris.kuryeler:
        // ⚠️ `rol` GEÇİLMEZSE PATRON DA GİREMEZ. Kapı (`YoneticiKapisi`) izin listesidir ve
        // bilinmeyen rolde KAPANIR (2026-08-17 kararı); geçilmeyen `rol` null demektir, null da
        // "kurye" ile aynı kovada. Bu satır bir vardiya boyunca rolsüz kaldı ve patron kendi
        // kuryelerini yönetemedi. Artık dört korunan ekranda da `rol` ZORUNLU alandır —
        // unutulursa derlenmez, sahada değil burada patlar.
        _git(KuryelerEkrani(db: widget.db, writable: _yazilabilir, rol: _userRole));
      case CekmeceGiris.muaf:
        if (!_yetki.muafTelefonYonetimi) {
          SipToast.goster(context, 'Muaf telefon yönetimi yalnız yöneticilere açıktır.');
          return;
        }
        // `rol` zorunlu — gerekçe yukarıda (kuryeler dalı). Bu satır da aynı açığı taşıyordu.
        _git(MuafEkrani(db: widget.db, writable: _yazilabilir, rol: _userRole));
      case CekmeceGiris.ayarlar:
        _git(AyarlarEkrani(
          db: widget.db,
          rol: _userRole,
          yetki: _yetki,
          writable: _yazilabilir,
          // Hesap sayfası hem çekmeceden hem ayarlar hub'ından açılır; ikisi de AYNI ekranı
          // ve AYNI çıkış akışını kullanır (çıkış onayı + oturum temizliği tek yerde).
          session: widget.session,
          onCikis: _cikis,
          onSihirbaz: _sihirbaziAc,
          koyuTema: _tema,
          onTema: _tema.ayarla,
          // Faz 0 gecikme ölçüm ekranı: TASARIMDA YOK ama arayan-tanımanın 1 sn bütçesini
          // (kırmızı çizgi) ölçen tek araç. Ayarlar satırı `kDebugMode` ile sarmalı, yani
          // üretimde esnafın menüsünde görünmez. Bu geri çağrım OLMADAN satır hiç çizilmez
          // ve `Phase0Screen` erişilemeyen dosyaya döner (çekmece ölü dalı dersi).
          onOlcumler: () => _git(Phase0Screen(db: widget.db)),
        ));
    }
  }

  Future<void> _musteriAc(String musteriId) => _git(CustomerDetailScreen(
        db: widget.db,
        customerId: musteriId,
        writable: _yazilabilir,
        yetki: _yetki,
      ));

  /// Sihirbazı push eder ve BİTİRİLDİYSE tasarımdaki toast'ı basar
  /// (`s-uygulama.jsx:61` `ping('Kurulum tamamlandı')`). Kapatılırsa (çarpı) toast yok.
  Future<void> _sihirbaziAc() async {
    _durumDegisti(() => _cekmece = false);
    var bitti = false;
    await Navigator.of(context).push(MaterialPageRoute(
      builder: (rotaCtx) => IzinSihirbazi(
        onBitti: () {
          bitti = true;
          Navigator.of(rotaCtx).pop();
        },
      ),
    ));
    await kurulumuDamgala(widget.db);
    if (!mounted || !bitti) return;
    SipToast.goster(context, 'Kurulum tamamlandı');
  }

  Future<void> _cikis() async {
    _durumDegisti(() => _cekmece = false);
    // Tasarımda onay yalnız başlık + "Çıkış" düğmesidir (`s-uygulama.jsx:108`), mesaj YOK:
    // "kayıtlarınız cihazda kalır" cümlesi kullanıcının sormadığı bir soruyu cevaplıyordu.
    final ok = await sipOnay(
      context,
      baslik: 'Çıkış yapılsın mı?',
      onayEtiketi: 'Çıkış',
      tehlike: true,
    );
    if (!ok) return;
    await widget.session.logout();
    widget.onLoggedOut();
  }

  void _yeniSiparis() =>
      _git(OrderFormScreen(db: widget.db, writable: _yazilabilir));

  /// FAB menüsü (kullanıcı kararı 2026-07-29): "Müşteri Ekle" · "Sipariş Ekle".
  ///
  /// Eskiden FAB doğrudan sipariş formunu açıyordu ve müşteri ekleme yalnız Müşteriler
  /// ekranının "Yeni"sinde yaşıyordu. Menü İKİ SATIRDIR, üçüncü bir şey EKLENMEZ: FAB'ın değeri
  /// bir dokunuşla en sık iki işi başlatmasıdır, dolan bir menü onu bir alt menüye çevirir.
  ///
  /// Kapı `_yazilabilir` üzerinden ÇAĞIRANDA (FAB pasif çizilir); burada ikinci bir kontrol
  /// yapılmaz — iki yerde ayrı koşul, ayrışabilen iki kural demektir.
  Future<void> _ekleMenusu() async {
    // KURYE YETKİLERİ (2026-08-04): bayi kapattıysa satır HİÇ ÇİZİLMEZ — gizlemek burada
    // doğrudur çünkü yetki kalıcı olarak kapalıdır; her dokunuşta aynı reddi okutmak gürültü
    // olurdu (BRIEF'in "tek kişilik bayide o adım hiç görünmesin" ilkesinin aynısı). İkisi de
    // kapalıysa menü hiç açılmaz, tek bir cümleyle sebep söylenir.
    final yetki = _yetki;
    if (!yetki.musteriDuzenleme && !yetki.siparisAcma) {
      SipToast.goster(context, 'Bu hesap yeni kayıt ekleyemez — bayi yetkisi kapalı.');
      return;
    }

    final secim = await sipSheet<String>(
      context,
      baslik: 'Yeni Ekle',
      govde: (ctx) => Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          if (yetki.musteriDuzenleme)
            SecimSatiri(
              etiket: 'Müşteri Ekle',
              ikon: SipIcons.user,
              secili: false,
              onTap: () => Navigator.of(ctx).pop('musteri'),
            ),
          if (yetki.siparisAcma)
            SecimSatiri(
              etiket: 'Sipariş Ekle',
              ikon: SipIcons.list,
              secili: false,
              onTap: () => Navigator.of(ctx).pop('siparis'),
            ),
        ],
      ),
    );
    if (secim == null || !mounted) return;
    if (secim == 'siparis') return _yeniSiparis();
    final eklendi = await musteriEkleSheet(context, db: widget.db);
    if (eklendi == true && mounted) SipToast.goster(context, 'Müşteri kaydedildi');
  }

  /// "Borçlular" bento kutusu — Genel Yetki Matrisinde kuryelere kısıtlıdır.
  void _borclularAc() {
    if (!_yetki.toplamBorclulariGorme) {
      SipToast.goster(context, 'Toplam borçlular listesi yalnız yöneticilere açıktır.');
      return;
    }
    _git(BorclularEkrani(
      db: widget.db,
      writable: _yazilabilir,
      yetki: _yetki,
      canAssign: _yetki.atama,
    ));
  }

  /// "Son aktivite" satırı: sekmeyi siparişe alır VE detayı açar (`s-uygulama.jsx:89`).
  /// Detay sheet'i sipariş katmanının yüzeyidir — buradan yalnız çağrılır.
  Future<void> _siparisAc(String siparisId) async {
    _durumDegisti(() => _sekme = SipSekme.siparis);
    await siparisDetaySheetAc(
      context,
      db: widget.db,
      orderId: siparisId,
      writable: _yazilabilir,
      canAssign: _yetki.atama,
    );
  }

}
