// HESAP — oturumu açık kullanıcının kimliği, cihazları ve oturum eylemleri.
//
// ══ SAYFA NEDEN VAR — İKİNCİ CEVAP (kullanıcı eleştirisi 2026-08-13) ══════════════════════
// İlk hâli yalnız kullanıcının adını ve rolünü yazıyordu ve kullanıcı haklı olarak sordu:
// *"Hesabım sayfasının varlık amacı ne, hiçbir şeye yaramıyor, neden var?"* Sayfanın gösterdiği
// her şey (ad, rol, çıkış) çekmecede ZATEN vardı — yani aynı bilgiyi ikinci bir UI ile tekrar
// ediyordu, tam da kullanıcının bir önceki vardiyada uyardığı hata.
//
// Sayfanın hak ettiği varlık nedeni EYLEMDİR, özet değil. Bir hesap sayfasının cevapladığı ve
// ürünün hiçbir yerinde cevaplanmayan soru şuydu: **hesabım hangi telefonlarda açık?** Cihazlar
// satırı bunu getirdi; kimlik satırları artık o eylemin bağlamı, sayfanın gerekçesi değil.
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
import 'cihazlar_ekrani.dart';

/// Rolün ekranda okunan adı. Çekmecedeki `SipCekmece.rolAdi` ile AYNI sözcükleri kullanır —
/// iki yüzey aynı kişiye iki farklı unvan derse bayi hangisinin doğru olduğunu sorar.
String hesapRolAdi(String? rol) => switch (rol) {
      'patron' => 'Patron',
      'operator' => 'Tezgâh',
      'kurye' => 'Kurye',
      _ => 'Bilinmiyor',
    };

/// Rolün ne yapabildiğini bir cümlede anlatan alt satır.
///
/// NEDEN VAR: "Kurye" kelimesi tek başına bir yetki listesi değildir ve bayi çoğu zaman
/// kuryesine neyin açık olduğunu buradan hatırlamak ister. Cümle YETKİ İDDİA ETMEZ — matris
/// bayi ayarlarına göre değişir (`KuryeIzinleri`), o yüzden metin kapsamı anlatır, tek tek
/// yetkileri saymaz. Saysaydı, izinler değiştiği gün sessizce yalan söylerdi.
String hesapRolAciklamasi(String? rol) => switch (rol) {
      'patron' => 'Her şeye erişebilirsiniz',
      'operator' => 'Sipariş ve tahsilat yaparsınız; gün kapatma ve ayarlar patronda',
      'kurye' => 'Yetkilerinizi işletme sahibi belirler',
      _ => 'Oturum bilgisi okunamadı',
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
                builder: (context, snap) =>
                    _Govde(db: db, meta: snap.data, onCikis: onCikis),
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _Govde extends StatelessWidget {
  const _Govde({required this.db, required this.meta, required this.onCikis});

  final AppDatabase db;
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
            baslik: kullanici.isEmpty ? 'Kullanıcı adı okunamadı' : kullanici,
            altBaslik: hesapRolAdi(rol),
          ),
          AyarSatiri(
            ikon: SipIcons.home,
            baslik: firma.isEmpty ? 'Firma adı okunamadı' : firma,
            altBaslik: hesapRolAciklamasi(rol),
          ),
        ]),

        const SipBolumBaslik('Güvenlik', ustBosluk: 18),
        AyarKarti(satirlar: [
          // SAYFANIN ASIL İŞİ: ürünün başka hiçbir yerinde sorulamayan soruyu sorar.
          AyarSatiri(
            ikon: SipIcons.phone,
            baslik: 'Cihazlar',
            altBaslik: 'Hesabınızın açık olduğu telefonlar',
            onTap: () => Navigator.of(context).push(
              MaterialPageRoute<void>(builder: (_) => CihazlarEkrani(db: db)),
            ),
          ),
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
                ? 'Parolanızı sipario.com.tr üzerinden değiştirebilirsiniz'
                : 'Parolanızı işletme sahibi belirler, değiştirmek için ona başvurun',
            tur: AlanNotuTuru.bilgi,
          ),
        ),
        const SizedBox(height: SipSpace.x3),
      ],
    );
  }
}
