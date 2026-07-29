// KURYELER ekranı — tasarım s-kuryeler.jsx + Sipario.html `.urow*`, `.krow-ic`,
// `.aktif-toggle`, `.ys-bos`.
//
// Liste: ad (+ PASİF rozeti) · telefon · chevron. Satıra dokununca ad/telefon/aktiflik düzenlenir
// ve `users` aynasına iyimser yazılır (CourierRepository → outbox → sunucu).
//
// ══ NEDEN "YENİ KURYE EKLE" YOK ════════════════════════════════════════════════════════════
// Tasarımda kesik çizgili bir ekleme düğmesi var; burada bilinçli olarak ÇİZİLMİYOR.
// `CourierRepository` kullanıcı OLUŞTURAMAZ (dosyanın başındaki sınır notu): yeni kullanıcı
// e-posta+parola üretmeyi gerektirir ve kimlik yüzeyini senkron yolundan açmak yetki yükseltme
// vektörüdür. Kullanıcı açma panel tarafındadır. İşini yapamayacak bir düğme koymak yerine
// nedenini söyleyen bir bilgi bloğu konuldu.
//
// Kurye SİLİNMEZ, pasifleşir: geçmiş atamalarda adının okunabilir kalması gerekir.

import '../../sync/yenileme.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

import '../../data/app_database.dart';
import '../../repo/courier_repository.dart';
import '../../theme/components/atoms.dart';
import '../../theme/components/overlays.dart';
import '../../theme/components/states.dart';
import '../../theme/icons.dart';
import '../../theme/tokens.dart';
import '../../theme/typography.dart';
import 'isletme_atomlari.dart';

/// Salt-okunur kip uyarısı — ürün/muaf ekranlarındaki eşdeğerleriyle aynı dil.
const String kuryeSaltOkunurUyarisi = 'Salt-okunur kip: kurye kaydı değiştirilemez.';

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
                  ),
                  Expanded(
                    child: kuryeler == null
                        ? const SipGovde(children: [SipIskelet(adet: 3)])
                        : _Liste(repo: repo, kuryeler: kuryeler, writable: writable),
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
  const _Liste({required this.repo, required this.kuryeler, required this.writable});

  final CourierRepository repo;
  final List<User> kuryeler;
  final bool writable;

  Future<void> _ac(BuildContext context, User kurye) async {
    if (!writable) {
      SipToast.goster(context, kuryeSaltOkunurUyarisi);
      return;
    }
    final sonuc = await kuryeFormuAc(context, kurye: kurye, tumKuryeler: kuryeler);
    if (sonuc == null || !context.mounted) return;
    await repo.updateProfile(
      kurye.id,
      name: sonuc.ad,
      phone: sonuc.telefon,
      isActive: sonuc.aktif,
    );
    if (context.mounted) SipToast.goster(context, 'Kurye kaydedildi');
  }

  @override
  Widget build(BuildContext context) {
    return SipGovde(
      // Aşağı çekerek yenile: liste sunucudan senkronla besleniyor (kullanıcı isteği 2026-07-29).
      onYenile: yenile,
      children: [
        Padding(
          padding: const EdgeInsets.only(bottom: SipSpace.xl),
          child: SipNotKutusu(
            ikon: SipIcons.info,
            metin: 'Yeni kurye hesabı yönetim panelinden açılır — bu ekrandan kurye EKLENEMEZ. '
                'Buradan ad, telefon ve aktiflik düzenlenir; kurye silinmez, pasife alınır.',
          ),
        ),
        // Boş durum ÇİZİLMEZ (tasarımda yok): liste boşken üstteki not zaten hem neden boş
        // olduğunu hem nereden doldurulacağını söylüyor; ikisi arka arkaya aynı cümleydi.
        Column(
          children: [
            for (var i = 0; i < kuryeler.length; i++)
              Padding(
                padding: EdgeInsets.only(top: i == 0 ? 0 : 7),
                child: _KuryeSatiri(
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

class _KuryeSatiri extends StatelessWidget {
  const _KuryeSatiri({required this.kurye, required this.onTap});

  final User kurye;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final t = context.sip;
    final tel = (kurye.phone ?? '').trim();
    return UrunSatiri(
      // CSS `.krow-ic` — accent-soft yuvarlak içinde kamyonet ikonu.
      bas: SipIkonKutu(
        ikon: SipIcons.truck,
        cap: 36,
        ikonBoyut: 18,
        kalinlik: 1.9,
        radius: SipRadius.hap,
        zemin: t.accentSoft,
        renk: t.accent,
      ),
      ad: kurye.name,
      altSatir: tel.isEmpty ? 'Telefon yok' : sipTelefon(tel),
      pasif: !kuryeAktifMi(kurye),
      onTap: onTap,
    );
  }
}

// ═══════════════════════════════════════════════════════════════════════════════════════════
// Düzenleme sheet'i — CSS `.sb-form`
// ═══════════════════════════════════════════════════════════════════════════════════════════

@immutable
class KuryeGirdisi {
  const KuryeGirdisi({required this.ad, required this.telefon, required this.aktif});

  final String ad;

  /// Boş bırakıldıysa null (kolon nullable — "telefon yok" gerçek bir durum).
  final String? telefon;

  final bool aktif;
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

  late bool _aktif = kuryeAktifMi(widget.kurye);

  Map<String, String> _hata = const {};

  @override
  void dispose() {
    _ad.dispose();
    _telefon.dispose();
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
    );
    if (hatalar.isNotEmpty) {
      setState(() => _hata = hatalar);
      return;
    }
    final tel = _telefon.text.trim();
    Navigator.of(context).pop(KuryeGirdisi(
      ad: _ad.text.trim(),
      telefon: tel.isEmpty ? null : tel,
      aktif: _aktif,
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

        const SizedBox(height: SipSpace.x3),
        SipButon(etiket: 'Kaydet', onTap: _kaydet),
      ],
    );
  }
}

/// Kurye formu doğrulaması — ekrandan BAĞIMSIZ (saf testle sınanır). Alan adı → hata metni.
///
/// Son aktif kurye pasife alınamaz: atama hedefi kalmazsa sipariş ekranı kilitlenir ve
/// kullanıcı buraya dönüp neyin bozulduğunu anlayamaz.
Map<String, String> kuryeFormHatalari({
  required String ad,
  required String telefon,
  required bool aktif,
  required String duzenlenenId,
  required List<User> tumKuryeler,
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

  return hatalar;
}
