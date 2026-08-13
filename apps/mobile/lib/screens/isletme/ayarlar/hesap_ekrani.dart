// HESAP — oturumu açık kullanıcının kendi kimliği ve oturum eylemleri.
//
// NEDEN AYRI BİR SAYFA (kullanıcı isteği 2026-08-13): uygulamada "hesap" diye bir kavram HİÇ
// YOKTU. Kullanıcı kendi adını, rolünü, hangi firmaya bağlı olduğunu hiçbir yerde göremiyordu;
// yapabildiği tek şey çekmecenin dibindeki güç düğmesiyle çıkmaktı. Oysa bu ekranın cevapladığı
// sorular günlük destek çağrılarının ta kendisi: "ben kim olarak girmişim", "bu telefon hangi
// bayiye bağlı", "yanlış hesapla girmişim galiba".
//
// MAĞAZA KURALI (pazarlıksız, `ayarlar_ekrani.dart` ile aynı): burada abonelik · ödeme · satın
// alma · fiyat · üyelik bağlantısı OLAMAZ. Lisans bilgisi Hakkında sayfasında NÖTR bir satır
// olarak durur; buraya bir "planını yükselt" izi bile düşemez.
//
// PAROLA DEĞİŞTİRME BURADA YOK ve bu bir eksiklik olarak KAYITLIDIR: mobilde kendi parolasını
// değiştirme yolu yok, API'de de uç nokta yok (`routes/api.php` taranmıştır). Kurye parolasını
// unutursa tek çare patronun Kuryeler ekranından kimliğini değiştirmesi. Kullanıcı kararıyla
// bu vardiyada ERTELENDİ; PLAN.md'de sıradaki işler arasında.

import 'package:flutter/material.dart';

import '../../../auth/session.dart';
import '../../../data/app_database.dart';
import '../../../theme/components/atoms.dart';
import '../../../theme/components/states.dart';
import '../../../theme/icons.dart';
import '../../../theme/tokens.dart';
import '../isletme_atomlari.dart';

/// Rolün ekranda okunan adı. Çekmecedeki `SipCekmece.rolAdi` ile AYNI sözcükleri kullanır —
/// iki yüzey aynı kişiye iki farklı unvan derse bayi hangisinin doğru olduğunu sorar.
String hesapRolAdi(String? rol) => switch (rol) {
      'patron' => 'Yönetici',
      'operator' => 'Operatör',
      'kurye' => 'Kurye',
      _ => 'Tanımsız',
    };

/// Rolün ne yapabildiğini bir cümlede anlatan alt satır.
///
/// NEDEN VAR: "Kurye" kelimesi tek başına bir yetki listesi değildir ve bayi çoğu zaman
/// kuryesine neyin açık olduğunu buradan hatırlamak ister. Cümle YETKİ İDDİA ETMEZ — matris
/// bayi ayarlarına göre değişir (`KuryeIzinleri`), o yüzden metin kapsamı anlatır, tek tek
/// yetkileri saymaz. Saysaydı, izinler değiştiği gün sessizce yalan söylerdi.
String hesapRolAciklamasi(String? rol) => switch (rol) {
      'patron' => 'Tüm ekranlar ve işletme ayarları açık',
      'operator' => 'İşletme ayarları dışında yönetici yetkileri',
      'kurye' => 'Yetkileri bayi belirler — Kuryeler ekranından değiştirilir',
      _ => 'Oturum bilgisi çözülemedi',
    };

class HesapEkrani extends StatelessWidget {
  const HesapEkrani({
    super.key,
    required this.db,
    required this.session,
    required this.onCikis,
  });

  final AppDatabase db;
  final Session session;

  /// Çıkış akışı KABUĞUNDUR (onay diyaloğu + `session.logout()` + oturum ekranına dönüş).
  /// Burada tekrarlanmaz: iki ayrı çıkış yolu, ikisinin bir gün ayrışması demektir.
  final VoidCallback onCikis;

  @override
  Widget build(BuildContext context) {
    final t = context.sip;
    return Scaffold(
      backgroundColor: t.bg,
      body: SafeArea(
        bottom: false,
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            SipUst(baslik: 'Hesap', onGeri: () => Navigator.of(context).maybePop()),
            Expanded(
              // AKIŞTAN okunur, tek atıştan DEĞİL: `sync_meta` sunucu sahipli alanlar taşır
              // (rol, firma adı) ve senkron sırasında değişebilir. Tek atış okuma bu depoda
              // birden çok kez bayat ekran üretti.
              child: StreamBuilder<SyncMetaData>(
                stream: db.watchSyncState(),
                builder: (context, snap) => _Govde(meta: snap.data, onCikis: onCikis),
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _Govde extends StatelessWidget {
  const _Govde({required this.meta, required this.onCikis});

  final SyncMetaData? meta;
  final VoidCallback onCikis;

  @override
  Widget build(BuildContext context) {
    final kullanici = (meta?.userName ?? '').trim();
    final firma = (meta?.tenantName ?? '').trim();
    final rol = meta?.userRole;

    return SipGovde(
      children: [
        const SipBolumBaslik('Oturum', ustBosluk: 18),
        AyarKarti(satirlar: [
          AyarSatiri(
            ikon: SipIcons.user,
            // Ad boşsa KİMLİK UYDURULMAZ: "Kullanıcı" gibi bir yer tutucu, yanlış hesapla
            // girmiş bayiye doğru hesapta olduğunu düşündürürdü.
            baslik: kullanici.isEmpty ? 'Kullanıcı adı çözülemedi' : kullanici,
            altBaslik: hesapRolAdi(rol),
          ),
          AyarSatiri(
            ikon: SipIcons.home,
            baslik: firma.isEmpty ? 'Firma çözülemedi' : firma,
            altBaslik: hesapRolAciklamasi(rol),
          ),
        ]),

        const SipBolumBaslik('Güvenlik', ustBosluk: 18),
        AyarKarti(satirlar: [
          // ÇIKIŞ BURADA DA VAR ve çekmecenin dibindeki güç düğmesiyle AYNI akışı çağırır.
          // İki giriş noktası bilinçli: çekmecedeki ikon tek başına ne yaptığını söylemiyor
          // (metinsiz bir güç simgesi), buradaki satır ise adıyla duruyor. İkisi de tek
          // fonksiyona bağlı — onay diyaloğu ve oturum temizliği tek yerde.
          AyarSatiri(
            ikon: SipIcons.power,
            baslik: 'Çıkış Yap',
            altBaslik: 'Kayıtlarınız bu cihazda kalır',
            onTap: onCikis,
          ),
        ]),

        // Kurye/operatör hesaplarının e-postası SENTETİKTİR (sunucu tarafında `Parola.php`
        // bunu açıkça söyler), yani e-postayla parola sıfırlama onlar için hiçbir zaman
        // çalışamaz. Bu yüzden buraya "parolamı unuttum" koymak yerine GERÇEĞİ yazıyoruz:
        // parolayı kimin değiştirebileceğini söylemek, çalışmayan bir düğmeden iyidir.
        Padding(
          padding: const EdgeInsets.only(top: SipSpace.xl),
          child: AlanNotu(
            rol == 'patron'
                ? 'Parolanızı sipario.com.tr üzerinden değiştirebilirsiniz.'
                : 'Parolanızı bayi yöneticiniz belirler; değiştirmek için ona başvurun.',
            tur: AlanNotuTuru.bilgi,
          ),
        ),
        const SizedBox(height: SipSpace.x3),
      ],
    );
  }
}
