// KURYE YETKİLERİ EKRANI — Sipario Genel Yetki Matrisi Tablosuna tam uyumlu
// kurye izin yönetim ekranı.
//
// Ayarlar kiracı düzeyindedir (tenant_settings) — tüm kuryeler için ortaktır.
// Hızlı şablonlar (Varsayılan, Tam Yetkili, Kısıtlı Saha) ile tek tıkla toplu ayar yapılabilir.

import 'package:flutter/material.dart';

import '../../data/app_database.dart';
import '../../repo/tenant_settings_repository.dart';
import '../../theme/components/atoms.dart';
import '../../theme/components/overlays.dart';
import '../../theme/components/states.dart';
import '../../theme/icons.dart';
import '../../theme/tokens.dart';
import '../../theme/typography.dart';
import '../team.dart';
import 'atomlar/rol_kapisi.dart';
import 'kurye_yetki_bolumu.dart';

class KuryeYetkileriEkrani extends StatelessWidget {
  const KuryeYetkileriEkrani({
    super.key,
    required this.db,
    this.writable = true,
    this.rol,
  });

  final AppDatabase db;
  final bool writable;
  final String? rol;

  @override
  Widget build(BuildContext context) {
    final t = context.sip;
    return YoneticiKapisi(
      rol: rol,
      baslik: 'Kurye Yetkileri',
      child: Scaffold(
        backgroundColor: t.bg,
        body: SafeArea(
          bottom: false,
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              SipUst(
                baslik: 'Kurye Yetkileri',
                alt: 'Genel Yetki Matrisi · 13 İzin',
                onGeri: () => Navigator.of(context).maybePop(),
              ),
              Expanded(
                child: StreamBuilder<KuryeIzinleri>(
                  stream: watchKuryeIzinleri(db),
                  initialData: KuryeIzinleri.varsayilan,
                  builder: (context, snap) {
                    final izin = snap.data ?? KuryeIzinleri.varsayilan;
                    return _YetkilerGovdesi(
                      db: db,
                      izin: izin,
                      writable: writable,
                    );
                  },
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class _YetkilerGovdesi extends StatelessWidget {
  const _YetkilerGovdesi({
    required this.db,
    required this.izin,
    required this.writable,
  });

  final AppDatabase db;
  final KuryeIzinleri izin;
  final bool writable;

  Future<void> _sablonUygula(
    BuildContext context,
    String sablonAdi,
    KuryeIzinleri yeniIzinler,
  ) async {
    if (!writable) {
      SipToast.goster(context, yetkiSaltOkunurUyarisi);
      return;
    }
    await TenantSettingsRepository(db).kuryeIzinleriKaydet(yeniIzinler);
    if (context.mounted) {
      SipToast.goster(context, '$sablonAdi şablonu uygulandı');
    }
  }

  Future<void> _tekilDegistir(
    BuildContext context,
    KuryeYetkiSatiri satir,
    bool yeniDeger,
  ) async {
    if (!writable) {
      SipToast.goster(context, yetkiSaltOkunurUyarisi);
      return;
    }
    await TenantSettingsRepository(db).kuryeIzinleriKaydet(satir.yaz(izin, yeniDeger));
  }

  @override
  Widget build(BuildContext context) {
    // Kategorilere göre grupla
    final kategoriler = <String, List<KuryeYetkiSatiri>>{};
    for (final s in kuryeYetkiSatirlari) {
      kategoriler.putIfAbsent(s.kategori, () => []).add(s);
    }

    return SingleChildScrollView(
      padding: const EdgeInsets.fromLTRB(
        SipSpace.govde,
        SipSpace.sm,
        SipSpace.govde,
        SipSpace.x6,
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          // Bilgilendirme Kutusu
          const SipNotKutusu(
            ikon: SipIcons.lock,
            tur: SipNotTuru.bilgi,
            onEtiket: 'Yetki Kuralı:',
            metin: 'Bu ayarlar dükkandaki TÜM kuryeler için geçerlidir. '
                'Patron ve operatör hesapları kısıtlamasız tam yetkilidir.',
          ),
          const SizedBox(height: SipSpace.lg),

          // Hızlı Şablonlar (Presets)
          const SipBolumBaslik('Hızlı Şablonlar', ustBosluk: 6, altBosluk: 8),
          _HizliSablonlar(
            onVarsayilan: () => _sablonUygula(
              context,
              'Önerilen Varsayılan',
              KuryeIzinleri.varsayilan,
            ),
            onTamYetki: () => _sablonUygula(
              context,
              'Tam Yetkili Kurye',
              const KuryeIzinleri(
                musteri: true,
                siparis: true,
                tahsilat: true,
                iskonto: true,
                gunSonu: true,
                tumSiparisler: true,
                gecmisTeslimatlar: true,
                sahaGideri: true,
                telefonMaskeleme: false,
                musteriGecmisDefteri: true,
                borcHatirlatma: true,
                stokPasifleme: true,
                cagriGunlugu: true,
              ),
            ),
            onKisitli: () => _sablonUygula(
              context,
              'Kısıtlı Saha',
              const KuryeIzinleri(
                musteri: false,
                siparis: false,
                tahsilat: true,
                iskonto: false,
                gunSonu: false,
                tumSiparisler: false,
                gecmisTeslimatlar: false,
                sahaGideri: false,
                telefonMaskeleme: true,
                musteriGecmisDefteri: false,
                borcHatirlatma: false,
                stokPasifleme: false,
                cagriGunlugu: false,
              ),
            ),
          ),
          const SizedBox(height: SipSpace.md),

          // Yetki Kategorileri
          for (final kat in kategoriler.entries) ...[
            _KategoriKarti(
              kategoriAdi: kat.key,
              satirlar: kat.value,
              izin: izin,
              onDegis: (satir, val) => _tekilDegistir(context, satir, val),
            ),
            const SizedBox(height: SipSpace.md),
          ],
        ],
      ),
    );
  }
}

/// Hızlı yetki şablonları çipleri / butonları
class _HizliSablonlar extends StatelessWidget {
  const _HizliSablonlar({
    required this.onVarsayilan,
    required this.onTamYetki,
    required this.onKisitli,
  });

  final VoidCallback onVarsayilan;
  final VoidCallback onTamYetki;
  final VoidCallback onKisitli;

  @override
  Widget build(BuildContext context) {
    final t = context.sip;
    return Row(
      children: [
        Expanded(
          child: _SablonCipi(
            ikon: SipIcons.check,
            baslik: 'Varsayılan',
            alt: 'Önerilen',
            renk: t.accent,
            zemin: t.accentSoft,
            onTap: onVarsayilan,
          ),
        ),
        const SizedBox(width: SipSpace.sm),
        Expanded(
          child: _SablonCipi(
            ikon: SipIcons.bolt,
            baslik: 'Tam Yetki',
            alt: 'Geniş İnisiyatif',
            renk: t.ok,
            zemin: t.okSoft,
            onTap: onTamYetki,
          ),
        ),
        const SizedBox(width: SipSpace.sm),
        Expanded(
          child: _SablonCipi(
            ikon: SipIcons.lock,
            baslik: 'Kısıtlı',
            alt: 'Yalnız Teslimat',
            renk: t.warn,
            zemin: t.warnSoft,
            onTap: onKisitli,
          ),
        ),
      ],
    );
  }
}

class _SablonCipi extends StatelessWidget {
  const _SablonCipi({
    required this.ikon,
    required this.baslik,
    required this.alt,
    required this.renk,
    required this.zemin,
    required this.onTap,
  });

  final String ikon;
  final String baslik;
  final String alt;
  final Color renk;
  final Color zemin;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final t = context.sip;
    return SipDokun(
      onTap: onTap,
      zemin: t.surface,
      basiliZemin: zemin,
      radius: SipRadius.br2,
      padding: const EdgeInsets.symmetric(horizontal: SipSpace.sm, vertical: SipSpace.md),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          SipIkonKutu(
            ikon: ikon,
            cap: 28,
            ikonBoyut: 14,
            kalinlik: 2.0,
            radius: SipRadius.hap,
            zemin: zemin,
            renk: renk,
          ),
          const SizedBox(height: 5),
          Text(
            baslik,
            style: SipText.metin(12, w: 700).copyWith(color: t.ink),
            maxLines: 1,
            overflow: TextOverflow.ellipsis,
          ),
          Text(
            alt,
            style: SipText.metin(10, w: 600).copyWith(color: t.muted),
            maxLines: 1,
            overflow: TextOverflow.ellipsis,
          ),
        ],
      ),
    );
  }
}

/// Kategoriye göre ikon seçici
String _kategoriIkonu(String kategori) {
  return switch (kategori) {
    'Sipariş & Teslimat' => SipIcons.truck,
    'Kasa & Tahsilat' => SipIcons.wallet,
    'Gün Sonu & Devir' => SipIcons.clock,
    'Müşteri & KVKK' => SipIcons.phone,
    'Ürün & Stok' => SipIcons.box,
    'Çağrı & Ayarlar' => SipIcons.settings,
    _ => SipIcons.settings,
  };
}

/// Tek bir yetki kategorisi kartı
class _KategoriKarti extends StatelessWidget {
  const _KategoriKarti({
    required this.kategoriAdi,
    required this.satirlar,
    required this.izin,
    required this.onDegis,
  });

  final String kategoriAdi;
  final List<KuryeYetkiSatiri> satirlar;
  final KuryeIzinleri izin;
  final void Function(KuryeYetkiSatiri, bool) onDegis;

  @override
  Widget build(BuildContext context) {
    final t = context.sip;
    final acikAdet = satirlar.where((s) => s.oku(izin)).length;
    final toplamAdet = satirlar.length;
    final ikon = _kategoriIkonu(kategoriAdi);

    return Container(
      padding: const EdgeInsets.symmetric(horizontal: SipSpace.md, vertical: SipSpace.md),
      decoration: BoxDecoration(
        color: t.surface,
        borderRadius: SipRadius.br3,
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          // Kategori Başlık Satırı
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: SipSpace.sm, vertical: SipSpace.xs),
            child: Row(
              children: [
                SipIkonKutu(
                  ikon: ikon,
                  cap: 28,
                  ikonBoyut: 14,
                  kalinlik: 2.0,
                  radius: SipRadius.hap,
                  zemin: t.accentSoft,
                  renk: t.accent,
                ),
                const SizedBox(width: SipSpace.md),
                Expanded(
                  child: Text(
                    kategoriAdi,
                    style: SipText.metin(13.5, w: 700).copyWith(color: t.ink),
                  ),
                ),
                Container(
                  padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
                  decoration: BoxDecoration(
                    color: acikAdet > 0 ? t.okSoft : t.surface2,
                    borderRadius: SipRadius.brHap,
                  ),
                  child: Text(
                    '$acikAdet/$toplamAdet Açık',
                    style: SipText.metin(10.5, w: 700).copyWith(
                      color: acikAdet > 0 ? t.ok : t.muted,
                    ),
                  ),
                ),
              ],
            ),
          ),
          const SizedBox(height: SipSpace.xs),

          // Yetki Satırları
          for (var i = 0; i < satirlar.length; i++) ...[
            if (i > 0)
              Padding(
                padding: const EdgeInsets.symmetric(horizontal: SipSpace.sm),
                child: Divider(color: t.line, height: 1),
              ),
            _YetkiSatiri(
              satir: satirlar[i],
              acik: satirlar[i].oku(izin),
              onDegis: (val) => onDegis(satirlar[i], val),
            ),
          ],
        ],
      ),
    );
  }
}

/// Tekil yetki satırı (toggle ile)
class _YetkiSatiri extends StatelessWidget {
  const _YetkiSatiri({
    required this.satir,
    required this.acik,
    required this.onDegis,
  });

  final KuryeYetkiSatiri satir;
  final bool acik;
  final ValueChanged<bool> onDegis;

  @override
  Widget build(BuildContext context) {
    final t = context.sip;
    return SipDokun(
      onTap: () => onDegis(!acik),
      radius: SipRadius.br2,
      padding: const EdgeInsets.symmetric(horizontal: SipSpace.sm, vertical: SipSpace.md),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Padding(
            padding: const EdgeInsets.only(top: 2),
            child: SipKnob(acik: acik),
          ),
          const SizedBox(width: SipSpace.md),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              mainAxisSize: MainAxisSize.min,
              children: [
                Text(
                  satir.etiket,
                  style: SipText.metin(13, w: 600).copyWith(
                    color: acik ? t.ink : t.ink2,
                  ),
                ),
                const SizedBox(height: 2),
                Text(
                  satir.aciklama,
                  style: SipText.metin(11, w: 500).copyWith(color: t.muted),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}
