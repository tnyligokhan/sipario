// KURYELER ekranı — Modern, ferah ve kullanışlı Sipario 3.0 tasarımı.
//
// Liste: ad (+ PASİF rozeti) · telefon · kullanıcı adı · durum rozeti · chevron.
// Satıra dokununca ad/telefon/aktiflik/giriş bilgileri düzenlenir.
//
// YETKİLER: Ekran kalabalığını önlemek için kurye yetkileri ayrı bir sayfaya (KuryeYetkileriEkrani)
// taşındı; bu ekrandan üstteki "Yetkiler" butonu veya Yetki Matrisi kartı ile doğrudan erişilir.

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

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
import 'kurye_yetkileri_ekrani.dart';

/// Salt-okunur kip uyarısı — ürün/muaf ekranlarındaki eşdeğerleriyle aynı dil.
const String kuryeSaltOkunurUyarisi = 'Salt-okunur kip: kurye kaydı değiştirilemez.';

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
    throw TeamApiException('Oturum bulunamadı — çıkış yapıp yeniden girin.');
  }

  return TeamApi(baseUrl: Session.baseUrlOf(meta), token: token)
      .kimlikGuncelle(userId, username: username, password: password);
}

class KuryelerEkrani extends StatelessWidget {
  const KuryelerEkrani({
    super.key,
    required this.db,
    this.writable = true,
    this.rol,
  });

  final AppDatabase db;

  /// Abonelik salt-okunur kipinde false — liste okunur, düzenlenemez.
  final bool writable;

  /// Oturumdaki rol; kurye bu ekranı göremez (K2).
  final String? rol;

  void _yetkileriAc(BuildContext context) {
    Navigator.of(context).push(
      MaterialPageRoute<void>(
        builder: (_) => KuryeYetkileriEkrani(
          db: db,
          writable: writable,
          rol: rol,
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
                        : '$aktif aktif · ${kuryeler.length} kayıtlı',
                    onGeri: () => Navigator.of(context).maybePop(),
                    sag: [
                      SipMetinButon(
                        etiket: 'Yetkiler',
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
  });

  final CourierRepository repo;
  final List<User> kuryeler;
  final int aktifSayi;
  final bool writable;
  final VoidCallback onYetkileriAc;

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
            ? 'Giriş bilgileri güncellendi — kuryenin oturumu kapandı, yeni parolayla girmeli'
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
          metin: 'Yeni kurye hesabı yönetim panelinden açılır — bu ekrandan kurye EKLENEMEZ. '
              'Buradan ad, telefon ve aktiflik düzenlenir; kurye silinmez, pasife alınır.',
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
                child: _ModernKuryeKarti(
                  kurye: kuryeler[i],
                  onTap: () => _ac(context, kuryeler[i]),
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
                  'Tüm kuryeler için geçerli dinamik kuralları yönet',
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

/// Modern Kurye Kartı — Temiz avatar, durum noktası, telefon, kullanıcı adı ve rozet
class _ModernKuryeKarti extends StatelessWidget {
  const _ModernKuryeKarti({required this.kurye, required this.onTap});

  final User kurye;
  final VoidCallback onTap;

  String _basHarfler(String ad) {
    final temiz = ad.trim();
    if (temiz.isEmpty) return 'K';
    final parcalar = temiz.split(RegExp(r'\s+'));
    if (parcalar.length >= 2) {
      return (parcalar[0][0] + parcalar[1][0]).toUpperCase();
    }
    return temiz.substring(0, temiz.length.clamp(1, 2)).toUpperCase();
  }

  @override
  Widget build(BuildContext context) {
    final t = context.sip;
    final aktif = kuryeAktifMi(kurye);
    final tel = (kurye.phone ?? '').trim();
    final nick = kurye.username.trim();

    return Opacity(
      opacity: aktif ? 1.0 : 0.65,
      child: SipDokun(
        onTap: onTap,
        zemin: t.surface,
        basiliZemin: t.surface2,
        radius: SipRadius.br3,
        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
        child: Row(
          children: [
            // Sol Avatar & Durum Göstergesi
            Stack(
              clipBehavior: Clip.none,
              children: [
                Container(
                  width: 44,
                  height: 44,
                  decoration: BoxDecoration(
                    color: aktif ? t.accentSoft : t.surface2,
                    shape: BoxShape.circle,
                  ),
                  alignment: Alignment.center,
                  child: Text(
                    _basHarfler(kurye.name),
                    style: SipText.metin(14, w: 700).copyWith(
                      color: aktif ? t.accent : t.muted,
                    ),
                  ),
                ),
                // Aktif/Pasif Noktası
                Positioned(
                  right: 0,
                  bottom: 0,
                  child: Container(
                    width: 12,
                    height: 12,
                    decoration: BoxDecoration(
                      color: aktif ? t.ok : t.muted,
                      shape: BoxShape.circle,
                      border: Border.all(color: t.surface, width: 2),
                    ),
                  ),
                ),
              ],
            ),
            const SizedBox(width: SipSpace.md),

            // Orta Bilgi Alanı
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                mainAxisSize: MainAxisSize.min,
                children: [
                  // İsim & Durum Rozeti
                  Row(
                    children: [
                      Flexible(
                        child: Text(
                          kurye.name,
                          style: SipText.metin(14.5, w: 700).copyWith(
                            color: t.ink,
                          ),
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                        ),
                      ),
                      if (!aktif) ...[
                        const SizedBox(width: 8),
                        Container(
                          padding: const EdgeInsets.symmetric(horizontal: 7, vertical: 2),
                          decoration: BoxDecoration(
                            color: t.surface2,
                            borderRadius: SipRadius.brHap,
                          ),
                          child: Text(
                            'PASİF',
                            style: SipText.metin(10, w: 700).copyWith(
                              color: t.muted,
                            ),
                          ),
                        ),
                      ],
                    ],
                  ),
                  const SizedBox(height: 3),

                  // Telefon & Kullanıcı Adı
                  Row(
                    children: [
                      if (tel.isNotEmpty) ...[
                        SipIcon(SipIcons.phone, boyut: 11, kalinlik: 2, renk: t.muted),
                        const SizedBox(width: 4),
                        Text(
                          sipTelefon(tel),
                          style: SipText.metin(12, w: 500).copyWith(color: t.ink2),
                        ),
                      ] else ...[
                        Text(
                          'Telefon yok',
                          style: SipText.metin(12, w: 500).copyWith(color: t.muted),
                        ),
                      ],
                      if (nick.isNotEmpty) ...[
                        Text(
                          ' · ',
                          style: SipText.metin(12, w: 700).copyWith(color: t.line2),
                        ),
                        Flexible(
                          child: Text(
                            '@$nick',
                            style: SipText.metin(11.5, w: 600).copyWith(color: t.muted),
                            maxLines: 1,
                            overflow: TextOverflow.ellipsis,
                          ),
                        ),
                      ],
                    ],
                  ),
                ],
              ),
            ),
            const SizedBox(width: SipSpace.sm),

            // Sağ Düzenleme Oku
            SipIcon(
              SipIcons.right,
              boyut: 16,
              kalinlik: 2.0,
              renk: t.muted,
            ),
          ],
        ),
      ),
    );
  }
}

// ═══════════════════════════════════════════════════════════════════════════════════════════
// Düzenleme sheet'i — CSS `.sb-form`
// ═══════════════════════════════════════════════════════════════════════════════════════════

@immutable
class KuryeGirdisi {
  const KuryeGirdisi({
    required this.ad,
    required this.telefon,
    required this.aktif,
    required this.kullaniciAdi,
    this.parola,
  });

  final String ad;
  final String? telefon;
  final bool aktif;
  final String kullaniciAdi;
  final String? parola;
}

Future<KuryeGirdisi?> kuryeFormuAc(
  BuildContext context, {
  required User kurye,
  required List<User> tumKuryeler,
}) {
  return sipSheet<KuryeGirdisi>(
    context,
    baslik: 'Kuryeyi Düzenle',
    govde: (ctx) => _KuryeFormu(kurye: kurye, tumKuryeler: tumKuryeler),
  );
}

class _KuryeFormu extends StatefulWidget {
  const _KuryeFormu({required this.kurye, required this.tumKuryeler});

  final User kurye;
  final List<User> tumKuryeler;

  @override
  State<_KuryeFormu> createState() => _KuryeFormuState();
}

class _KuryeFormuState extends State<_KuryeFormu> {
  late final TextEditingController _ad = TextEditingController(text: widget.kurye.name);
  late final TextEditingController _telefon =
      TextEditingController(text: widget.kurye.phone ?? '');

  late final TextEditingController _kullaniciAdi =
      TextEditingController(text: widget.kurye.username);

  final TextEditingController _parola = TextEditingController();

  late bool _aktif = kuryeAktifMi(widget.kurye);

  Map<String, String> _hata = const {};

  @override
  void dispose() {
    _ad.dispose();
    _telefon.dispose();
    _kullaniciAdi.dispose();
    _parola.dispose();
    super.dispose();
  }

  void _temizle() {
    if (_hata.isNotEmpty) setState(() => _hata = const {});
  }

  void _kaydet() {
    final hatalar = kuryeFormHatalari(
      ad: _ad.text,
      telefon: _telefon.text,
      aktif: _aktif,
      duzenlenenId: widget.kurye.id,
      tumKuryeler: widget.tumKuryeler,
      kullaniciAdi: _kullaniciAdi.text,
      parola: _parola.text,
    );
    if (hatalar.isNotEmpty) {
      setState(() => _hata = hatalar);
      return;
    }
    final tel = _telefon.text.trim();
    final parola = _parola.text;
    Navigator.of(context).pop(KuryeGirdisi(
      ad: _ad.text.trim(),
      telefon: tel.isEmpty ? null : tel,
      aktif: _aktif,
      kullaniciAdi: _kullaniciAdi.text.trim().toLowerCase(),
      parola: parola.isEmpty ? null : parola,
    ));
  }

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        const SipFormEtiket('AD', ustBosluk: 2),
        SipInput(
          controller: _ad,
          ipucu: 'Ör. Emre',
          hata: _hata.containsKey('ad'),
          otomatikOdak: true,
          onChanged: (_) => _temizle(),
        ),
        if (_hata['ad'] != null) AlanNotu(_hata['ad']!),

        const SipFormEtiket('TELEFON'),
        SipInput(
          controller: _telefon,
          ipucu: '05XX XXX XX XX',
          klavye: TextInputType.phone,
          girdiFiltreleri: [FilteringTextInputFormatter.allow(RegExp(r'[0-9 +()-]'))],
          stil: SipText.tutar(15, w: 500),
          hata: _hata.containsKey('telefon'),
          onChanged: (_) => _temizle(),
        ),
        if (_hata['telefon'] != null) AlanNotu(_hata['telefon']!),

        AktifToggle(
          acik: _aktif,
          etiket: _aktif ? 'Aktif — sipariş atanabilir' : 'Pasif — atama kapalı',
          onDegis: (v) => setState(() {
            _aktif = v;
            _hata = const {};
          }),
        ),
        if (_hata['aktif'] != null) AlanNotu(_hata['aktif']!),

        // ── GİRİŞ BİLGİLERİ ───────────────────────────────────────────────
        const SipBolumBaslik('Giriş Bilgileri', ustBosluk: 20),
        const SipFormEtiket('KULLANICI ADI', ustBosluk: 2),
        SipInput(
          controller: _kullaniciAdi,
          ipucu: 'Ör. emre',
          hata: _hata.containsKey('kullaniciAdi'),
          girdiFiltreleri: [FilteringTextInputFormatter.allow(RegExp(r'[a-zA-Z0-9._-]'))],
          onChanged: (_) => _temizle(),
        ),
        if (_hata['kullaniciAdi'] != null) AlanNotu(_hata['kullaniciAdi']!),

        const SipFormEtiket('YENİ PAROLA'),
        SipInput(
          controller: _parola,
          ipucu: 'Değiştirmeyecekseniz boş bırakın',
          hata: _hata.containsKey('parola'),
          onChanged: (_) => _temizle(),
        ),
        if (_hata['parola'] != null)
          AlanNotu(_hata['parola']!)
        else
          const AlanNotu(
            'Parola değiştirilirse kuryenin açık oturumu kapanır ve yeni parolayla girmesi '
            'gerekir. Giriş bilgileri yalnız internet varken değiştirilebilir.',
            tur: AlanNotuTuru.bilgi,
          ),

        const SizedBox(height: SipSpace.x3),
        SipButon(etiket: 'Kaydet', onTap: _kaydet),
      ],
    );
  }
}

/// Kurye formu doğrulaması — saf test edilebilir.
Map<String, String> kuryeFormHatalari({
  required String ad,
  required String telefon,
  required bool aktif,
  required String duzenlenenId,
  required List<User> tumKuryeler,
  String? kullaniciAdi,
  String? parola,
}) {
  final hatalar = <String, String>{};
  final temizAd = ad.trim();
  final digerleri = tumKuryeler.where((k) => k.id != duzenlenenId);

  if (temizAd.length < 2) {
    hatalar['ad'] = 'Kurye adı girin (en az 2 karakter)';
  } else if (digerleri.any((k) => trKucuk(k.name) == trKucuk(temizAd))) {
    hatalar['ad'] = 'Bu adla kayıtlı kurye zaten var';
  }

  final haneler = telefon.replaceAll(RegExp(r'\D'), '');
  if (telefon.trim().isNotEmpty && (haneler.length < 10 || haneler.length > 11)) {
    hatalar['telefon'] = 'Geçerli telefon girin (10-11 hane) ya da boş bırakın';
  }

  if (!aktif && !digerleri.any(kuryeAktifMi)) {
    hatalar['aktif'] = 'Son aktif kurye pasif yapılamaz — sipariş atanacak kimse kalmaz';
  }

  if (kullaniciAdi != null && kullaniciAdi.trim().isNotEmpty) {
    final k = kullaniciAdi.trim().toLowerCase();
    if (!RegExp(r'^[a-z0-9._-]{3,60}$').hasMatch(k)) {
      hatalar['kullaniciAdi'] =
          'Kullanıcı adı en az 3 karakter; harf, rakam, nokta, tire ve alt çizgi kullanılabilir';
    }
  }

  if (parola != null && parola.isNotEmpty && parola.length < 4) {
    hatalar['parola'] = 'Parola en az 4 karakter olmalı';
  }

  return hatalar;
}
