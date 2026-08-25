// KURYELER ekranı — Modern, ferah ve kullanışlı Sipario 3.0 tasarımı.
//
// Liste: ad (+ PASİF rozeti) · telefon · kullanıcı adı · durum rozeti · chevron.
// Satıra dokununca ad/telefon/aktiflik/giriş bilgileri düzenlenir.
//
// YETKİLER: Ekran kalabalığını önlemek için kurye yetkileri ayrı bir sayfaya (KuryeYetkileriEkrani)
// taşındı. İKİ GİRİŞ VARDIR ve karıştırılmamalıdır:
//   • Üstteki "Varsayılan Yetkiler" / Yetki Matrisi kartı → BAYİ VARSAYILANI (yeni kurye şablonu).
//   • Kurye satırındaki "Yetkiler" çipi → YALNIZ o kuryenin ezmeleri (üç durumlu).
// Kişiye özel ezmesi olan kurye satırında "özel yetki" rozeti çıkar: patron kimin ayrık
// olduğunu listeye bakarak görebilmelidir, tek tek ekran açarak değil.

import 'package:flutter/material.dart';

import '../../auth/session.dart';
import '../../data/app_database.dart';
import '../../repo/courier_repository.dart';
import '../../sync/team_api.dart';
import '../../sync/yenileme.dart';
import '../../theme/components/atoms.dart';
import '../../theme/components/overlays.dart';
import '../../theme/components/states.dart';
import '../../theme/icons.dart';
import '../../theme/tokens.dart';
import '../../theme/typography.dart';
import 'isletme_atomlari.dart';
import 'kurye_formu.dart';

// Form yüzeyi yeniden dışa aktarılır: bölme kimsenin import satırını değiştirmesin.
// `kuryeFormHatalari` saf bir doğrulama kuralıdır ve `isletme_kurallari_test.dart` onu bu
// kapıdan çağırıyor — sözleşme dosya bölünürken korunur (aynı desen: `order_queries.dart`).
export 'kurye_formu.dart';
import 'kurye_karti.dart';
import 'kurye_yetkileri_ekrani.dart';

/// Salt-okunur kip uyarısı — ürün/muaf ekranlarındaki eşdeğerleriyle aynı dil.
const String kuryeSaltOkunurUyarisi = 'Aboneliğiniz sona erdiği için kayıt değiştirilemiyor';

/// Kimlik güncelleme dikişi — testler bunu sahteler.
Future<bool> Function({
  required AppDatabase db,
  required String userId,
  String? username,
  String? password,
}) kuryeKimligiGuncelle = _sunucudaKimlikGuncelle;

Future<bool> _sunucudaKimlikGuncelle({
  required AppDatabase db,
  required String userId,
  String? username,
  String? password,
}) async {
  final meta = await db.syncState();
  final token = meta.authToken;
  if (token == null) {
    throw TeamApiException('Oturumunuz bulunamadı. Çıkış yapıp yeniden girin.');
  }

  return TeamApi(baseUrl: Session.baseUrlOf(meta), token: token)
      .kimlikGuncelle(userId, username: username, password: password);
}

class KuryelerEkrani extends StatelessWidget {
  const KuryelerEkrani({
    super.key,
    required this.db,
    this.writable = true,
    required this.rol,
  });

  final AppDatabase db;

  /// Abonelik salt-okunur kipinde false — liste okunur, düzenlenemez.
  final bool writable;

  /// Oturumdaki rol; kurye bu ekranı göremez (K2).
  final String? rol;

  /// [kurye] verilirse KİŞİ kipi, verilmezse bayi varsayılanı açılır.
  void _yetkileriAc(BuildContext context, {User? kurye}) {
    Navigator.of(context).push(
      MaterialPageRoute<void>(
        builder: (_) => KuryeYetkileriEkrani(
          db: db,
          writable: writable,
          rol: rol,
          userId: kurye?.id,
          kuryeAdi: kurye?.name,
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final t = context.sip;
    final repo = CourierRepository(db);
    return YoneticiKapisi(
      rol: rol,
      baslik: 'Kuryeler',
      child: Scaffold(
        backgroundColor: t.bg,
        body: SafeArea(
          bottom: false,
          child: StreamBuilder<List<User>>(
            stream: repo.watchAll(),
            builder: (context, snap) {
              final kuryeler = snap.data == null ? null : kuryeleriAyikla(snap.data!);
              final aktif = kuryeler?.where(kuryeAktifMi).length ?? 0;
              return Column(
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  SipUst(
                    baslik: 'Kuryeler',
                    alt: kuryeler == null
                        ? null
                        : '${kuryeler.length} kayıtlı, $aktif aktif',
                    onGeri: () => Navigator.of(context).maybePop(),
                    sag: [
                      SipMetinButon(
                        etiket: 'Varsayılan Yetkiler',
                        ikon: SipIcons.lock,
                        onTap: () => _yetkileriAc(context),
                      ),
                    ],
                  ),
                  Expanded(
                    child: kuryeler == null
                        ? const SipGovde(children: [SipIskelet(adet: 3)])
                        : _Liste(
                            repo: repo,
                            kuryeler: kuryeler,
                            aktifSayi: aktif,
                            writable: writable,
                            onYetkileriAc: () => _yetkileriAc(context),
                            onKuryeYetkileriAc: (k) => _yetkileriAc(context, kurye: k),
                          ),
                  ),
                ],
              );
            },
          ),
        ),
      ),
    );
  }
}

/// `users` aynasından yalnız kuryeler (ada göre sıralı — repo zaten sıralı verir).
List<User> kuryeleriAyikla(List<User> ekip) =>
    ekip.where((u) => u.role == 'kurye').toList();

bool kuryeAktifMi(User u) => u.status == 'active';

class _Liste extends StatelessWidget {
  const _Liste({
    required this.repo,
    required this.kuryeler,
    required this.aktifSayi,
    required this.writable,
    required this.onYetkileriAc,
    required this.onKuryeYetkileriAc,
  });

  final CourierRepository repo;
  final List<User> kuryeler;
  final int aktifSayi;
  final bool writable;
  final VoidCallback onYetkileriAc;
  final ValueChanged<User> onKuryeYetkileriAc;

  Future<void> _ac(BuildContext context, User kurye) async {
    if (!writable) {
      SipToast.goster(context, kuryeSaltOkunurUyarisi);
      return;
    }
    final sonuc = await kuryeFormuAc(context, kurye: kurye, tumKuryeler: kuryeler);
    if (sonuc == null || !context.mounted) return;

    // SIRA ÖNEMLİ — önce profil (çevrimdışı çalışır, outbox'a düşer), sonra kimlik (ONLINE).
    await repo.updateProfile(
      kurye.id,
      name: sonuc.ad,
      phone: sonuc.telefon,
      isActive: sonuc.aktif,
    );
    if (!context.mounted) return;

    final yeniAd = (sonuc.kullaniciAdi.isEmpty || sonuc.kullaniciAdi == kurye.username)
        ? null
        : sonuc.kullaniciAdi;
    if (yeniAd == null && sonuc.parola == null) {
      SipToast.goster(context, 'Kurye kaydedildi');
      return;
    }

    try {
      final oturumDustu = await kuryeKimligiGuncelle(
        db: repo.db,
        userId: kurye.id,
        username: yeniAd,
        password: sonuc.parola,
      );
      if (!context.mounted) return;
      SipToast.goster(
        context,
        oturumDustu
            ? 'Giriş bilgileri güncellendi. Kurye yeni parolayla tekrar girmeli'
            : 'Kurye kaydedildi',
      );
    } on TeamApiException catch (e) {
      if (context.mounted) SipToast.goster(context, e.mesaj);
    }
  }

  @override
  Widget build(BuildContext context) {
    final t = context.sip;
    return SipGovde(
      onYenile: yenile,
      children: [
        // 1. Yetki Matrisi Hero / Eylem Kartı
        _YetkiMatrisiHeroKarti(onTap: onYetkileriAc),
        const SizedBox(height: SipSpace.md),

        // 2. Bilgilendirme Notu (Sade ve kompakt)
        const SipNotKutusu(
          ikon: SipIcons.info,
          tur: SipNotTuru.bilgi,
          metin: 'Yeni hesap web panelinden açılır. Burada ad, telefon ve durum düzenlenir.',
        ),
        const SizedBox(height: SipSpace.lg),

        // 3. Kurye Ekip Listesi Başlığı (kurye varsa)
        if (kuryeler.isNotEmpty)
          SipBolumBaslik(
            'Kurye Ekibi',
            ustBosluk: 4,
            altBosluk: 8,
            sag: Text(
              '$aktifSayi / ${kuryeler.length} Aktif',
              style: SipText.metin(12, w: 700).copyWith(color: t.accent),
            ),
          ),

        // 4. Kurye Kartları
        Column(
          children: [
            for (var i = 0; i < kuryeler.length; i++)
              Padding(
                padding: EdgeInsets.only(top: i == 0 ? 0 : 8),
                child: KuryeKarti(
                  kurye: kuryeler[i],
                  onTap: () => _ac(context, kuryeler[i]),
                  onYetkiler: () => onKuryeYetkileriAc(kuryeler[i]),
                ),
              ),
          ],
        ),
      ],
    );
  }
}

/// Kurye Yetkileri Hızlı Erişim Hero Kartı
class _YetkiMatrisiHeroKarti extends StatelessWidget {
  const _YetkiMatrisiHeroKarti({required this.onTap});

  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final t = context.sip;
    return SipDokun(
      onTap: onTap,
      zemin: t.surface,
      basiliZemin: t.surface2,
      radius: SipRadius.br3,
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
      child: Row(
        children: [
          // Sol İkon Kutusu
          SipIkonKutu(
            ikon: SipIcons.lock,
            cap: 42,
            ikonBoyut: 20,
            kalinlik: 2.1,
            radius: SipRadius.hap,
            zemin: t.accentSoft,
            renk: t.accent,
          ),
          const SizedBox(width: SipSpace.md),

          // Orta Metin Alanı
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              mainAxisSize: MainAxisSize.min,
              children: [
                Row(
                  children: [
                    Text(
                      'Kurye Yetki Matrisi',
                      style: SipText.metin(14, w: 700).copyWith(color: t.ink),
                    ),
                    const SizedBox(width: 6),
                    Container(
                      padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                      decoration: BoxDecoration(
                        color: t.accentSoft,
                        borderRadius: SipRadius.brHap,
                      ),
                      child: Text(
                        '13 İzin',
                        style: SipText.metin(9.5, w: 700).copyWith(color: t.accent),
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 3),
                Text(
                  'Tüm kuryeler için geçerli, kişiye özel ayarla değiştirilebilir',
                  style: SipText.metin(11.5, w: 500).copyWith(color: t.muted),
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                ),
              ],
            ),
          ),
          const SizedBox(width: SipSpace.sm),

          // Sağ Ok İkonu
          SipIcon(
            SipIcons.right,
            boyut: 16,
            kalinlik: 2.0,
            renk: t.muted,
          ),
        ],
      ),
    );
  }
}

