// KABUĞUN GÖVDESİ — aktif sekmenin ekranı + lütuf (grace) bandı.
//
// NEDEN AYRI DOSYA: `home_shell.dart` 1022 satıra çıkmıştı (500 satır kuralı). `_govde` bir
// KARAR TABLOSUDUR: hangi sekmede hangi ekran, hangi yetkiyle, hangi kapsamla kurulur. Kabuğun
// yaşam döngüsü kodunun arasında dururken okunması zordu; tek başına bakıldığında beş sekmenin
// sözleşmesi tek ekrana sığıyor.
//
// ⚠️ SALT-OKUNUR KİP EN ÜSTTE: abonelik kilitliyse gövde sekmeye BAKMADAN kilit ekranına düşer,
// ama çekmece ve navigasyon erişilebilir kalır (mevcut veri okunabilir olmalı).
//
// NEDEN `part` ve `setState` yerine `_durumDegisti`: gerekçe `home_shell_cagri.dart` başlığında.

part of 'home_shell.dart';

/// Kabuğun GÖVDE yüzeyi — aktif sekmenin ekranını kurar.
extension _GovdeYuzeyi on _HomeShellState {
  Widget _govde(SipSekme sekme, RolYetkileri yetki) {
    if (_kilit) {
      return Column(
        children: [
          SipUst(baslik: 'Sipario', onMenu: () => _durumDegisti(() => _cekmece = true)),
          Expanded(child: SubscriptionLockedScreen(bitis: _validUntil)),
        ],
      );
    }
    return switch (sekme) {
      SipSekme.ana => AnaEkran(
          db: widget.db,
          sahipAdi: _sahipAdi,
          onMenu: () => _durumDegisti(() => _cekmece = true),
          onSekme: _sekmeSec,
          onYeniSiparis: _yeniSiparis,
          onArama: _aramaAc,
          onSiparisAc: _siparisAc,
          onBorclular: _borclularAc,
          borclulariGoster: yetki.toplamBorclulariGorme,
          // Sipariş listesiyle AYNI kapsam: kurye kilitliyse bento de yalnız ona atananları sayar.
          acikSiparisKullanicisi: yetki.tumSiparisleriGorme ? null : _userId,
          sonSenkron: _sonSenkron,
          sonSenkronAt: _sonSenkronAt,
        ),
      // onMenu HER sekmeye geçilir (s-uygulama.jsx: dört ana ekranın dördü de
      // `onMenu={() => setCekmece(true)}` alır). Geçilmezse `SipUst` hamburger yerine ya hiçbir şey
      // ya da geri oku çizer ve çekmece — Ürünler/Kuryeler/Muaf/Ayarlar/çıkış oradadır — yalnız Ana
      // sekmesinden açılabilir hâle gelir.
      SipSekme.musteri => CustomerListScreen(
          db: widget.db,
          writable: _yazilabilir,
          yetki: yetki,
          onMenu: () => _durumDegisti(() => _cekmece = true),
        ),
      SipSekme.siparis => OrderListScreen(
          db: widget.db,
          writable: _yazilabilir,
          userId: _userId,
          // Kurye kısıtlamalarının kaynağı (2026-08-09): `tumSiparisleriGorme` kapalıysa liste
          // oturum kullanıcısına kilitlenir, `gecmisTeslimatlariGorme` kapalıysa gün şeridi
          // çizilmez. İkisi de burada verilir ki rol yorumu TEK yerde kalsın.
          yetki: yetki,
          canAssign: yetki.atama,
          onMenu: () => _durumDegisti(() => _cekmece = true),
        ),
      SipSekme.gunSonu =>
        // `rol` ZORUNLU GİBİ davranılmalı: verilmezse ekran "yetki bilinmiyor" sayar ve HİÇ
        // kapatma sunmaz (`yetkiler(rol: null).gunSonu == false` — K2 sözleşmesi, permissive
        // değil). `kullaniciId` iki iş yapar: kurye ekranı KENDİ kapsamında açar, ve kapatma
        // yetkisinin sahibi odur. Çekmecenin kuryedeki "Kasa Devri" satırı buraya geliyor.
        DayEndScreen(
          db: widget.db,
          onMenu: () => _durumDegisti(() => _cekmece = true),
          rol: _userRole,
          kullaniciId: _userId,
          // Kurye izinleri de geçer (2026-08-09): ekran `gunuKapatma` ve `gecmisHesapArsivi`
          // kapılarını buradan türetiyor. Geçilmezse varsayılan izinlerle karar verir ve
          // bayinin kendi ayarı yok sayılırdı.
          kuryeIzin: _kuryeIzin,
          // Oturum YALNIZ yönetici parolası doğrulaması için geçer (kapanışı geri alma).
          session: widget.session,
        ),
    };
  }
}

/// Abonelik süresi dolmuş ama lütuf penceresi sürüyor — NÖTR bilgi şeridi
/// (mağaza kuralı: fiyat/abone-ol/link YOK).
class _GraceBandi extends StatelessWidget {
  const _GraceBandi();

  @override
  Widget build(BuildContext context) {
    final t = context.sip;
    return Container(
      width: double.infinity,
      color: t.warnSoft,
      padding: const EdgeInsets.symmetric(horizontal: SipSpace.x2, vertical: 7),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          SipIcon(SipIcons.info, boyut: 15, kalinlik: 2.2, renk: t.warn),
          const SizedBox(width: 7),
          Flexible(
            child: Text(
              'Abonelik süreniz doldu görünüyor; bağlantı kurulunca netleşecek.',
              style: SipText.metin(11.5, w: 600).copyWith(color: t.warn),
              textAlign: TextAlign.center,
            ),
          ),
        ],
      ),
    );
  }
}
