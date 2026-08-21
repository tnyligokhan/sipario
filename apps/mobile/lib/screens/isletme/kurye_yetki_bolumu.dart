// KURYE YETKİLERİ — 13 satırlık Genel Yetki Matrisi TANIMI ve kiracı düzeyi bölüm widget'ı.
//
// [kuryeYetkiSatirlari] TEK KAYNAKTIR ve İKİ KİP birden onu okur:
//   • VARSAYILAN kipi (`tenant_settings`) — `oku`/`yaz`, iki durumlu.
//   • KİŞİ kipi (`users` ezmeleri)        — `ezmeOku`/`ezmeYaz`, üç durumlu (null = devral).
// Listeyi kişi kipi için kopyalamak, 13 satırın etiket/açıklamalarının zamanla ayrışması ve
// aynı yetkinin iki ekranda farklı anlatılması demekti.
//
// AYAR ARTIK YALNIZ KİRACI DÜZEYİNDE DEĞİLDİR (kullanıcı kararı 2026-08-10): `tenant_settings`
// değerleri BAYİ VARSAYILANI / yeni kurye şablonudur; her kurye kendi satırında ezebilir.
//
// YAZMA YOLU MEVCUT: `tenant_settings` LWW upsert'i (outbox → sunucu).

import 'package:flutter/material.dart';

import '../../data/app_database.dart';
import '../../repo/tenant_settings_repository.dart';
import '../../theme/components/atoms.dart';
import '../../theme/components/overlays.dart';
import '../../theme/tokens.dart';
import '../../theme/typography.dart';
import '../team.dart';
import 'isletme_atomlari.dart';

/// Salt-okunur kip uyarısı.
const String yetkiSaltOkunurUyarisi = 'Aboneliğiniz sona erdiği için yetkiler değiştirilemiyor.';

class KuryeYetkiSatiri {
  const KuryeYetkiSatiri({
    required this.anahtar,
    required this.etiket,
    required this.aciklama,
    required this.kategori,
    required this.oku,
    required this.yaz,
    required this.ezmeOku,
    required this.ezmeYaz,
  });

  /// Satırın makine kimliği (ör. `tahsilat`) — testlerin dokunduğu widget anahtarlarının ön eki.
  /// Etiketten TÜRETİLMEZ: etiket kullanıcıya görünen metindir ve değişebilir; anahtar sabittir.
  final String anahtar;

  final String etiket;
  final String aciklama;
  final String kategori;

  /// BAYİ VARSAYILANI okuma/yazma (iki durumlu).
  final bool Function(KuryeIzinleri) oku;
  final KuryeIzinleri Function(KuryeIzinleri, bool) yaz;

  /// KİŞİYE ÖZEL ezme okuma/yazma (üç durumlu). `null` = bayi varsayılanını devral.
  final bool? Function(KuryeIzinEzmeleri) ezmeOku;
  final KuryeIzinEzmeleri Function(KuryeIzinEzmeleri, bool?) ezmeYaz;
}

const List<KuryeYetkiSatiri> kuryeYetkiSatirlari = [
  // 1. Sipariş & Teslimat Yönetimi
  KuryeYetkiSatiri(
    anahtar: 'musteri',
    kategori: 'Sipariş & Teslimat',
    etiket: 'Müşteri ekleyip düzenleyebilir',
    aciklama: 'Yeni müşteri ekler, adres ve telefon düzeltir.',
    oku: _musteriOku,
    yaz: _musteriYaz,
    ezmeOku: _musteriEzmeOku,
    ezmeYaz: _musteriEzmeYaz,
  ),
  KuryeYetkiSatiri(
    anahtar: 'siparis',
    kategori: 'Sipariş & Teslimat',
    etiket: 'Sipariş oluşturabilir',
    aciklama: 'Sahadan yeni sipariş girer.',
    oku: _siparisOku,
    yaz: _siparisYaz,
    ezmeOku: _siparisEzmeOku,
    ezmeYaz: _siparisEzmeYaz,
  ),
  KuryeYetkiSatiri(
    anahtar: 'tum_siparisler',
    kategori: 'Sipariş & Teslimat',
    etiket: 'Tüm siparişleri görebilir',
    aciklama: 'Kapalıyken yalnız kendine atananları görür.',
    oku: _tumSiparislerOku,
    yaz: _tumSiparislerYaz,
    ezmeOku: _tumSiparislerEzmeOku,
    ezmeYaz: _tumSiparislerEzmeYaz,
  ),
  KuryeYetkiSatiri(
    anahtar: 'gecmis_teslimatlar',
    kategori: 'Sipariş & Teslimat',
    etiket: 'Geçmiş gün teslimatlarını görebilir',
    aciklama: 'Önceki günlerin teslimatlarına bakabilir.',
    oku: _gecmisTeslimatlarOku,
    yaz: _gecmisTeslimatlarYaz,
    ezmeOku: _gecmisTeslimatlarEzmeOku,
    ezmeYaz: _gecmisTeslimatlarEzmeYaz,
  ),

  // 2. Kasa, Tahsilat & Finans
  KuryeYetkiSatiri(
    anahtar: 'tahsilat',
    kategori: 'Kasa & Tahsilat',
    etiket: 'Kapıda tahsilat alabilir',
    aciklama: 'Kapıda nakit, kart veya havale tahsil eder.',
    oku: _tahsilatOku,
    yaz: _tahsilatYaz,
    ezmeOku: _tahsilatEzmeOku,
    ezmeYaz: _tahsilatEzmeYaz,
  ),
  KuryeYetkiSatiri(
    anahtar: 'iskonto',
    kategori: 'Kasa & Tahsilat',
    etiket: 'Kapıda iskonto yapabilir',
    aciklama: 'Kapıda fiyat kırabilir.',
    oku: _iskontoOku,
    yaz: _iskontoYaz,
    ezmeOku: _iskontoEzmeOku,
    ezmeYaz: _iskontoEzmeYaz,
  ),
  KuryeYetkiSatiri(
    anahtar: 'saha_gideri',
    kategori: 'Kasa & Tahsilat',
    etiket: 'Saha gideri girebilir',
    aciklama: 'Benzin, tamir gibi masrafları kasadan düşer.',
    oku: _sahaGideriOku,
    yaz: _sahaGideriYaz,
    ezmeOku: _sahaGideriEzmeOku,
    ezmeYaz: _sahaGideriEzmeYaz,
  ),

  // 3. Gün Sonu & Kasa Devri
  KuryeYetkiSatiri(
    anahtar: 'gun_sonu',
    kategori: 'Gün Sonu & Devir',
    etiket: 'Gün sonu özetini görebilir',
    // METİN 2026-08-11'DE GERÇEĞE ÇEKİLDİ: eskiden "Tüm işletmenin günlük ciro/kasa özetini
    // görür" yazıyordu ve bu artık DOĞRU DEĞİL — kurye gün hesabını ("Tümü") hiçbir yetkiyle
    // göremiyor, yalnız kendi kapsamını görüyor. Yetki metni ekranın ne yaptığını söylemezse
    // bayi kapattığı şeyin ne olduğunu bilemez.
    aciklama: 'Yalnız kendi günlük tahsilat ve teslimat dökümünü görür.',
    oku: _gunSonuOku,
    yaz: _gunSonuYaz,
    ezmeOku: _gunSonuEzmeOku,
    ezmeYaz: _gunSonuEzmeYaz,
  ),

  // 4. Müşteri & KVKK / İletişim
  KuryeYetkiSatiri(
    anahtar: 'telefon_maskeleme',
    kategori: 'Müşteri & KVKK',
    etiket: 'Müşteri telefonlarını maskele',
    aciklama: 'Müşteri numarası 0532***12 diye gizlenir; arama yine yapılır.',
    oku: _telefonMaskelemeOku,
    yaz: _telefonMaskelemeYaz,
    ezmeOku: _telefonMaskelemeEzmeOku,
    ezmeYaz: _telefonMaskelemeEzmeYaz,
  ),
  KuryeYetkiSatiri(
    anahtar: 'musteri_gecmis_defteri',
    kategori: 'Müşteri & KVKK',
    etiket: 'Müşteri geçmiş defterini görebilir',
    aciklama: 'Müşterinin geçmiş alışveriş ve ödemelerini görür.',
    oku: _musteriGecmisDefteriOku,
    yaz: _musteriGecmisDefteriYaz,
    ezmeOku: _musteriGecmisDefteriEzmeOku,
    ezmeYaz: _musteriGecmisDefteriEzmeYaz,
  ),
  KuryeYetkiSatiri(
    anahtar: 'borc_hatirlatma',
    kategori: 'Müşteri & KVKK',
    etiket: 'Borç hatırlatma gönderebilir',
    aciklama: 'Müşteriye WhatsApp/SMS ile borç hatırlatması gönderir.',
    oku: _borcHatirlatmaOku,
    yaz: _borcHatirlatmaYaz,
    ezmeOku: _borcHatirlatmaEzmeOku,
    ezmeYaz: _borcHatirlatmaEzmeYaz,
  ),

  // 5. Ürün & Stok
  KuryeYetkiSatiri(
    anahtar: 'stok_pasifleme',
    kategori: 'Ürün & Stok',
    etiket: 'Stokta yok işaretleyebilir',
    aciklama: 'Tükenen ürünü "Stokta yok" işaretler.',
    oku: _stokPasiflemeOku,
    yaz: _stokPasiflemeYaz,
    ezmeOku: _stokPasiflemeEzmeOku,
    ezmeYaz: _stokPasiflemeEzmeYaz,
  ),

  // 6. Çağrı & Sistem
  KuryeYetkiSatiri(
    anahtar: 'cagri_gunlugu',
    kategori: 'Çağrı & Ayarlar',
    etiket: 'Dükkan çağrı günlüğünü görebilir',
    aciklama: 'Dükkâna gelen aramaların geçmişini görür.',
    oku: _cagriGunluguOku,
    yaz: _cagriGunluguYaz,
    ezmeOku: _cagriGunluguEzmeOku,
    ezmeYaz: _cagriGunluguEzmeYaz,
  ),
];

// Okuma yardımcıları
bool _musteriOku(KuryeIzinleri i) => i.musteri;
bool _siparisOku(KuryeIzinleri i) => i.siparis;
bool _tumSiparislerOku(KuryeIzinleri i) => i.tumSiparisler;
bool _gecmisTeslimatlarOku(KuryeIzinleri i) => i.gecmisTeslimatlar;
bool _tahsilatOku(KuryeIzinleri i) => i.tahsilat;
bool _iskontoOku(KuryeIzinleri i) => i.iskonto;
bool _sahaGideriOku(KuryeIzinleri i) => i.sahaGideri;
bool _gunSonuOku(KuryeIzinleri i) => i.gunSonu;
bool _telefonMaskelemeOku(KuryeIzinleri i) => i.telefonMaskeleme;
bool _musteriGecmisDefteriOku(KuryeIzinleri i) => i.musteriGecmisDefteri;
bool _borcHatirlatmaOku(KuryeIzinleri i) => i.borcHatirlatma;
bool _stokPasiflemeOku(KuryeIzinleri i) => i.stokPasifleme;
bool _cagriGunluguOku(KuryeIzinleri i) => i.cagriGunlugu;

// Yazma yardımcıları
KuryeIzinleri _musteriYaz(KuryeIzinleri i, bool v) => _kopyala(i, musteri: v);
KuryeIzinleri _siparisYaz(KuryeIzinleri i, bool v) => _kopyala(i, siparis: v);
KuryeIzinleri _tumSiparislerYaz(KuryeIzinleri i, bool v) => _kopyala(i, tumSiparisler: v);
KuryeIzinleri _gecmisTeslimatlarYaz(KuryeIzinleri i, bool v) => _kopyala(i, gecmisTeslimatlar: v);
KuryeIzinleri _tahsilatYaz(KuryeIzinleri i, bool v) => _kopyala(i, tahsilat: v);
KuryeIzinleri _iskontoYaz(KuryeIzinleri i, bool v) => _kopyala(i, iskonto: v);
KuryeIzinleri _sahaGideriYaz(KuryeIzinleri i, bool v) => _kopyala(i, sahaGideri: v);
KuryeIzinleri _gunSonuYaz(KuryeIzinleri i, bool v) => _kopyala(i, gunSonu: v);
KuryeIzinleri _telefonMaskelemeYaz(KuryeIzinleri i, bool v) => _kopyala(i, telefonMaskeleme: v);
KuryeIzinleri _musteriGecmisDefteriYaz(KuryeIzinleri i, bool v) => _kopyala(i, musteriGecmisDefteri: v);
KuryeIzinleri _borcHatirlatmaYaz(KuryeIzinleri i, bool v) => _kopyala(i, borcHatirlatma: v);
KuryeIzinleri _stokPasiflemeYaz(KuryeIzinleri i, bool v) => _kopyala(i, stokPasifleme: v);
KuryeIzinleri _cagriGunluguYaz(KuryeIzinleri i, bool v) => _kopyala(i, cagriGunlugu: v);

// ── KİŞİYE ÖZEL EZME okuma yardımcıları (null = devral) ─────────────────────────────────────
bool? _musteriEzmeOku(KuryeIzinEzmeleri e) => e.musteri;
bool? _siparisEzmeOku(KuryeIzinEzmeleri e) => e.siparis;
bool? _tumSiparislerEzmeOku(KuryeIzinEzmeleri e) => e.tumSiparisler;
bool? _gecmisTeslimatlarEzmeOku(KuryeIzinEzmeleri e) => e.gecmisTeslimatlar;
bool? _tahsilatEzmeOku(KuryeIzinEzmeleri e) => e.tahsilat;
bool? _iskontoEzmeOku(KuryeIzinEzmeleri e) => e.iskonto;
bool? _sahaGideriEzmeOku(KuryeIzinEzmeleri e) => e.sahaGideri;
bool? _gunSonuEzmeOku(KuryeIzinEzmeleri e) => e.gunSonu;
bool? _telefonMaskelemeEzmeOku(KuryeIzinEzmeleri e) => e.telefonMaskeleme;
bool? _musteriGecmisDefteriEzmeOku(KuryeIzinEzmeleri e) => e.musteriGecmisDefteri;
bool? _borcHatirlatmaEzmeOku(KuryeIzinEzmeleri e) => e.borcHatirlatma;
bool? _stokPasiflemeEzmeOku(KuryeIzinEzmeleri e) => e.stokPasifleme;
bool? _cagriGunluguEzmeOku(KuryeIzinEzmeleri e) => e.cagriGunlugu;

// ── KİŞİYE ÖZEL EZME yazma yardımcıları ─────────────────────────────────────────────────────
KuryeIzinEzmeleri _musteriEzmeYaz(KuryeIzinEzmeleri e, bool? v) => _ezmeKopyala(e, musteri: v);
KuryeIzinEzmeleri _siparisEzmeYaz(KuryeIzinEzmeleri e, bool? v) => _ezmeKopyala(e, siparis: v);
KuryeIzinEzmeleri _tumSiparislerEzmeYaz(KuryeIzinEzmeleri e, bool? v) =>
    _ezmeKopyala(e, tumSiparisler: v);
KuryeIzinEzmeleri _gecmisTeslimatlarEzmeYaz(KuryeIzinEzmeleri e, bool? v) =>
    _ezmeKopyala(e, gecmisTeslimatlar: v);
KuryeIzinEzmeleri _tahsilatEzmeYaz(KuryeIzinEzmeleri e, bool? v) => _ezmeKopyala(e, tahsilat: v);
KuryeIzinEzmeleri _iskontoEzmeYaz(KuryeIzinEzmeleri e, bool? v) => _ezmeKopyala(e, iskonto: v);
KuryeIzinEzmeleri _sahaGideriEzmeYaz(KuryeIzinEzmeleri e, bool? v) =>
    _ezmeKopyala(e, sahaGideri: v);
KuryeIzinEzmeleri _gunSonuEzmeYaz(KuryeIzinEzmeleri e, bool? v) => _ezmeKopyala(e, gunSonu: v);
KuryeIzinEzmeleri _telefonMaskelemeEzmeYaz(KuryeIzinEzmeleri e, bool? v) =>
    _ezmeKopyala(e, telefonMaskeleme: v);
KuryeIzinEzmeleri _musteriGecmisDefteriEzmeYaz(KuryeIzinEzmeleri e, bool? v) =>
    _ezmeKopyala(e, musteriGecmisDefteri: v);
KuryeIzinEzmeleri _borcHatirlatmaEzmeYaz(KuryeIzinEzmeleri e, bool? v) =>
    _ezmeKopyala(e, borcHatirlatma: v);
KuryeIzinEzmeleri _stokPasiflemeEzmeYaz(KuryeIzinEzmeleri e, bool? v) =>
    _ezmeKopyala(e, stokPasifleme: v);
KuryeIzinEzmeleri _cagriGunluguEzmeYaz(KuryeIzinEzmeleri e, bool? v) =>
    _ezmeKopyala(e, cagriGunlugu: v);

/// "Bu alana dokunma" nöbetçisi. Ezmelerde `null` GEÇERLİ bir değerdir (= devral), bu yüzden
/// [_kopyala]'daki `yeni ?? mevcut` deseni burada KULLANILAMAZ: bir yetkiyi varsayılana
/// döndürmek imkânsız hâle gelirdi (null yazmak "değiştirme" diye okunurdu).
const Object _dokunma = Object();

KuryeIzinEzmeleri _ezmeKopyala(
  KuryeIzinEzmeleri e, {
  Object? musteri = _dokunma,
  Object? siparis = _dokunma,
  Object? tahsilat = _dokunma,
  Object? iskonto = _dokunma,
  Object? gunSonu = _dokunma,
  Object? tumSiparisler = _dokunma,
  Object? gecmisTeslimatlar = _dokunma,
  Object? sahaGideri = _dokunma,
  Object? telefonMaskeleme = _dokunma,
  Object? musteriGecmisDefteri = _dokunma,
  Object? borcHatirlatma = _dokunma,
  Object? stokPasifleme = _dokunma,
  Object? cagriGunlugu = _dokunma,
}) =>
    KuryeIzinEzmeleri(
      musteri: identical(musteri, _dokunma) ? e.musteri : musteri as bool?,
      siparis: identical(siparis, _dokunma) ? e.siparis : siparis as bool?,
      tahsilat: identical(tahsilat, _dokunma) ? e.tahsilat : tahsilat as bool?,
      iskonto: identical(iskonto, _dokunma) ? e.iskonto : iskonto as bool?,
      gunSonu: identical(gunSonu, _dokunma) ? e.gunSonu : gunSonu as bool?,
      tumSiparisler:
          identical(tumSiparisler, _dokunma) ? e.tumSiparisler : tumSiparisler as bool?,
      gecmisTeslimatlar: identical(gecmisTeslimatlar, _dokunma)
          ? e.gecmisTeslimatlar
          : gecmisTeslimatlar as bool?,
      sahaGideri: identical(sahaGideri, _dokunma) ? e.sahaGideri : sahaGideri as bool?,
      telefonMaskeleme:
          identical(telefonMaskeleme, _dokunma) ? e.telefonMaskeleme : telefonMaskeleme as bool?,
      musteriGecmisDefteri: identical(musteriGecmisDefteri, _dokunma)
          ? e.musteriGecmisDefteri
          : musteriGecmisDefteri as bool?,
      borcHatirlatma:
          identical(borcHatirlatma, _dokunma) ? e.borcHatirlatma : borcHatirlatma as bool?,
      stokPasifleme:
          identical(stokPasifleme, _dokunma) ? e.stokPasifleme : stokPasifleme as bool?,
      cagriGunlugu: identical(cagriGunlugu, _dokunma) ? e.cagriGunlugu : cagriGunlugu as bool?,
    );

KuryeIzinleri _kopyala(
  KuryeIzinleri i, {
  bool? musteri,
  bool? siparis,
  bool? tahsilat,
  bool? iskonto,
  bool? gunSonu,
  bool? tumSiparisler,
  bool? gecmisTeslimatlar,
  bool? sahaGideri,
  bool? telefonMaskeleme,
  bool? musteriGecmisDefteri,
  bool? borcHatirlatma,
  bool? stokPasifleme,
  bool? cagriGunlugu,
}) =>
    KuryeIzinleri(
      musteri: musteri ?? i.musteri,
      siparis: siparis ?? i.siparis,
      tahsilat: tahsilat ?? i.tahsilat,
      iskonto: iskonto ?? i.iskonto,
      gunSonu: gunSonu ?? i.gunSonu,
      tumSiparisler: tumSiparisler ?? i.tumSiparisler,
      gecmisTeslimatlar: gecmisTeslimatlar ?? i.gecmisTeslimatlar,
      sahaGideri: sahaGideri ?? i.sahaGideri,
      telefonMaskeleme: telefonMaskeleme ?? i.telefonMaskeleme,
      musteriGecmisDefteri: musteriGecmisDefteri ?? i.musteriGecmisDefteri,
      borcHatirlatma: borcHatirlatma ?? i.borcHatirlatma,
      stokPasifleme: stokPasifleme ?? i.stokPasifleme,
      cagriGunlugu: cagriGunlugu ?? i.cagriGunlugu,
    );

/// BAYİ VARSAYILANLARINI düzenleyen gömülü bölüm (kişiye özel ezmeleri DEĞİL — onlar
/// `kurye_kisisel_yetkiler.dart` içindedir).
class KuryeYetkiBolumu extends StatelessWidget {
  const KuryeYetkiBolumu({super.key, required this.db, this.writable = true});

  final AppDatabase db;
  final bool writable;

  Future<void> _degistir(
    BuildContext context,
    KuryeIzinleri mevcut,
    KuryeYetkiSatiri satir,
    bool yeni,
  ) async {
    if (!writable) {
      SipToast.goster(context, yetkiSaltOkunurUyarisi);
      return;
    }
    await TenantSettingsRepository(db).kuryeIzinleriKaydet(satir.yaz(mevcut, yeni));
  }

  @override
  Widget build(BuildContext context) {
    final t = context.sip;
    return StreamBuilder<KuryeIzinleri>(
      stream: watchKuryeIzinleri(db),
      initialData: KuryeIzinleri.varsayilan,
      builder: (context, snap) {
        final izin = snap.data ?? KuryeIzinleri.varsayilan;

        // Kategorilere göre gruplama
        final kategoriler = <String, List<KuryeYetkiSatiri>>{};
        for (final s in kuryeYetkiSatirlari) {
          kategoriler.putIfAbsent(s.kategori, () => []).add(s);
        }

        return Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            const SipBolumBaslik('Kuryeler Ne Yapabilir', ustBosluk: 0),
            Padding(
              padding: const EdgeInsets.only(top: SipSpace.xs, bottom: SipSpace.sm),
              child: Text(
                'Tüm kuryeler için geçerli; kişiye özel ayarla değiştirilebilir. '
                'Patron ve tezgâh hesapları bundan etkilenmez.',
                style: SipText.metin(12, w: 600).copyWith(color: t.muted),
              ),
            ),
            for (final kat in kategoriler.entries) ...[
              Padding(
                padding: const EdgeInsets.only(top: SipSpace.md, bottom: SipSpace.xs),
                child: Text(
                  kat.key,
                  style: SipText.metin(11, w: 700).copyWith(color: t.accent),
                ),
              ),
              for (final satir in kat.value)
                Padding(
                  padding: const EdgeInsets.only(top: SipSpace.sm),
                  child: AktifToggle(
                    acik: satir.oku(izin),
                    etiket: satir.etiket,
                    altEtiket: satir.aciklama,
                    onDegis: (v) => _degistir(context, izin, satir, v),
                  ),
                ),
            ],
            const SizedBox(height: SipSpace.xl),
          ],
        );
      },
    );
  }
}
