// KURYE YETKİLERİ — Kuryeler ekranının üstündeki dinamik on/off yetki anahtarları.
// Sipario Genel Yetki Matrisi Tablosuna tam uyumludur.
//
// AYAR KİRACI DÜZEYİNDEDİR (kurye başına değil) — 1–3 kişilik bayide kişi bazlı yetki, her yeni
// kuryede unutulan bir kurulum adımı doğururdu.
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
const String yetkiSaltOkunurUyarisi = 'Salt-okunur kip: yetkiler değiştirilemez.';

class KuryeYetkiSatiri {
  const KuryeYetkiSatiri({
    required this.etiket,
    required this.aciklama,
    required this.kategori,
    required this.oku,
    required this.yaz,
  });

  final String etiket;
  final String aciklama;
  final String kategori;
  final bool Function(KuryeIzinleri) oku;
  final KuryeIzinleri Function(KuryeIzinleri, bool) yaz;
}

const List<KuryeYetkiSatiri> kuryeYetkiSatirlari = [
  // 1. Sipariş & Teslimat Yönetimi
  KuryeYetkiSatiri(
    kategori: 'Sipariş & Teslimat',
    etiket: 'Müşteri ekleyip düzenleyebilir',
    aciklama: 'Yeni müşteri kaydı ve adres/telefon düzeltmesi. Silme ve kara liste yöneticiye özeldir.',
    oku: _musteriOku,
    yaz: _musteriYaz,
  ),
  KuryeYetkiSatiri(
    kategori: 'Sipariş & Teslimat',
    etiket: 'Sipariş oluşturabilir',
    aciklama: 'Sahadan yeni sipariş girer. Kapalıyken yalnız kendine atanan işi teslim eder.',
    oku: _siparisOku,
    yaz: _siparisYaz,
  ),
  KuryeYetkiSatiri(
    kategori: 'Sipariş & Teslimat',
    etiket: 'Tüm siparişleri görebilir',
    aciklama: 'Kapalıyken kurye yalnız kendine atanan aktif siparişleri görür; açıkken dükkanın tüm siparişlerini listeler.',
    oku: _tumSiparislerOku,
    yaz: _tumSiparislerYaz,
  ),
  KuryeYetkiSatiri(
    kategori: 'Sipariş & Teslimat',
    etiket: 'Geçmiş gün teslimatlarını görebilir',
    aciklama: 'Önceki günlere gidip teslimat kayıtlarını inceleme yetkisidir. Varsayılanı pasiftir.',
    oku: _gecmisTeslimatlarOku,
    yaz: _gecmisTeslimatlarYaz,
  ),

  // 2. Kasa, Tahsilat & Finans
  KuryeYetkiSatiri(
    kategori: 'Kasa & Tahsilat',
    etiket: 'Kapıda tahsilat alabilir',
    aciklama: 'Teslimat sırasında Nakit, POS veya Havale ödemesi alarak kasaya kaydeder.',
    oku: _tahsilatOku,
    yaz: _tahsilatYaz,
  ),
  KuryeYetkiSatiri(
    kategori: 'Kasa & Tahsilat',
    etiket: 'Kapıda iskonto yapabilir',
    aciklama: 'Teslimde tutarı kırabilir. Kırılan para kasaya girmez, gün sonunda ayrı görünür.',
    oku: _iskontoOku,
    yaz: _iskontoYaz,
  ),
  KuryeYetkiSatiri(
    kategori: 'Kasa & Tahsilat',
    etiket: 'Saha gideri girebilir',
    aciklama: 'Benzin, tamir vb. saha masraflarını kasadan düşerek sisteme işler.',
    oku: _sahaGideriOku,
    yaz: _sahaGideriYaz,
  ),

  // 3. Gün Sonu & Kasa Devri
  KuryeYetkiSatiri(
    kategori: 'Gün Sonu & Devir',
    etiket: 'Gün sonu özetini görebilir',
    aciklama: 'Tüm işletmenin günlük ciro/kasa özetini görür. Kapalıyken yalnız kendi devrini görebilir.',
    oku: _gunSonuOku,
    yaz: _gunSonuYaz,
  ),

  // 4. Müşteri & KVKK / İletişim
  KuryeYetkiSatiri(
    kategori: 'Müşteri & KVKK',
    etiket: 'Müşteri telefonlarını maskele',
    aciklama: 'Kurye ekranında müşteri numarası 0532***12 olarak gizlenir; uygulama üzerinden tek tıkla arama yapılabilir.',
    oku: _telefonMaskelemeOku,
    yaz: _telefonMaskelemeYaz,
  ),
  KuryeYetkiSatiri(
    kategori: 'Müşteri & KVKK',
    etiket: 'Müşteri geçmiş defterini görebilir',
    aciklama: 'Müşterinin dükkanla olan geçmiş tüm alışveriş ve ödeme hareketlerini inceleme yetkisidir.',
    oku: _musteriGecmisDefteriOku,
    yaz: _musteriGecmisDefteriYaz,
  ),
  KuryeYetkiSatiri(
    kategori: 'Müşteri & KVKK',
    etiket: 'Borç hatırlatma gönderebilir',
    aciklama: 'Müşteriye WhatsApp veya SMS ile borç bakiyesi ve IBAN ödeme hatırlatması gönderebilme yetkisidir.',
    oku: _borcHatirlatmaOku,
    yaz: _borcHatirlatmaYaz,
  ),

  // 5. Ürün & Stok
  KuryeYetkiSatiri(
    kategori: 'Ürün & Stok',
    etiket: 'Stokta yok işaretleyebilir',
    aciklama: 'Sahada tükenen bir ürünü geçici olarak "Stokta Yok" durumuna alabilme yetkisidir.',
    oku: _stokPasiflemeOku,
    yaz: _stokPasiflemeYaz,
  ),

  // 6. Çağrı & Sistem
  KuryeYetkiSatiri(
    kategori: 'Çağrı & Ayarlar',
    etiket: 'Dükkan çağrı günlüğünü görebilir',
    aciklama: 'Dükkana gelen tüm telefon aramalarının geçmişini inceleme yetkisidir.',
    oku: _cagriGunluguOku,
    yaz: _cagriGunluguYaz,
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
                'Bu ayarlar TÜM kuryeler için geçerlidir. Patron ve operatör bunlardan etkilenmez.',
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
