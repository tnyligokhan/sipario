// KAPANIŞI GERİ ALMA — yönetici onayı + ters kayıt (kullanıcı kararı 2026-08-18:
// "patron hata yapabilir, kasayı kapattığında yönetici şifresi ile geriye alabilir,
// hesapta düzeltme yapabilir").
//
// ══ NEDEN AYRI DOSYA ═══════════════════════════════════════════════════════════════════════
// `gun_kapatma_sheet.dart` 465 satırdı (depo sınırı 500) ve bu akış oraya sığmıyordu. Bölme
// çizgisi de doğal: o dosya hesabı KAPATIR, burası kapatılmış olanı AÇAR — ikisi ters yönlü
// akışlardır ve tek ortak noktaları arşiv kaydıdır.
//
// ══ NEDEN PAROLA SORULUYOR ═════════════════════════════════════════════════════════════════
// Telefon çoğu zaman tezgâhın üstünde açık durur. Oturumun patrona ait olması, o an ekrana
// dokunanın patron olduğunu KANITLAMAZ — ve bu düğme günün mutabakatını açan tek düğmedir.
// Yetki kapısı (`yetkiler().gunuKapatma`) "bu HESAP yapabilir mi?" sorusuna cevap verir;
// parola "bu KİŞİ sen misin?" sorusuna. İkisi farklı sorulardır ve burada ikisi de gerekir.
//
// ⚠️ ÇEVRİMİÇİ ZORUNLU. Parola sunucuda doğrulanır (`AuthApi.parolaDogrula`); depoda parola
// SAKLANMAZ ve hash'i istemci üretemez. Bu, ürünün "internetsiz TAM çalışır" sözünün bilinçli
// bir istisnasıdır ve dar tutulmuştur: günlük iş (sipariş, teslim, tahsilat) çevrimdışı akmayı
// sürdürür; çevrimiçi isteyen tek şey, nadir ve düzeltici olan BU eylemdir. Ağ yoksa kullanıcı
// gerekçeyi okur — sessizce "parola yanlış" demek, bayiye kendi parolasını sorgulatırdı.

import 'package:flutter/material.dart';

import '../../auth/auth_api.dart';
import '../../auth/session.dart';
import '../../data/app_database.dart';
import '../../repo/day_closing_repository.dart';
import '../../theme/components/atoms.dart';
import '../../theme/components/overlays.dart';
import '../../theme/icons.dart';
import '../../theme/tokens.dart';
import '../../theme/typography.dart';

/// Yönetici parolasını sorar ve SUNUCUDA doğrular.
///
/// Dönüş: `true` = onaylandı. `false` = vazgeçildi ya da parola yanlış (kullanıcı gerekçeyi
/// sheet'in İÇİNDE görür; çağıran ayrıca toast göstermez — aynı hatayı iki yerde söylemek,
/// kullanıcıya iki ayrı sorun varmış gibi gelir).
Future<bool> yoneticiOnayiIste(
  BuildContext context, {
  required Session session,
  required String eylemMetni,
}) async {
  final sonuc = await sipSheet<bool>(
    context,
    baslik: 'Yönetici Onayı',
    govde: (ctx) => _OnayGovdesi(session: session, eylemMetni: eylemMetni),
  );
  return sonuc ?? false;
}

class _OnayGovdesi extends StatefulWidget {
  const _OnayGovdesi({required this.session, required this.eylemMetni});

  final Session session;
  final String eylemMetni;

  @override
  State<_OnayGovdesi> createState() => _OnayGovdesiState();
}

class _OnayGovdesiState extends State<_OnayGovdesi> {
  final _parola = TextEditingController();
  String? _hata;
  bool _calisiyor = false;

  @override
  void dispose() {
    _parola.dispose();
    super.dispose();
  }

  Future<void> _dogrula() async {
    final girilen = _parola.text;
    if (girilen.isEmpty) {
      setState(() => _hata = 'Parolanızı girin.');
      return;
    }
    setState(() {
      _calisiyor = true;
      _hata = null;
    });

    try {
      final ok = await widget.session.parolaDogrula(girilen);
      if (!mounted) return;
      if (!ok) {
        // ⚠️ PAROLA ALANI TEMİZLENİR: yanlış parola ekranda dururken kullanıcı onu düzeltmeye
        // çalışır ve çoğu zaman aynı yanlışı ikinci kez gönderir (hız sınırı bir deneme daha
        // yer). Boş alan, baştan yazmayı işaret eder.
        _parola.clear();
        setState(() {
          _calisiyor = false;
          _hata = 'Parola hatalı.';
        });
        return;
      }
      Navigator.of(context).pop(true);
    } on AuthException catch (e) {
      if (!mounted) return;
      setState(() {
        _calisiyor = false;
        // AĞ HATASI İLE YANLIŞ PAROLA AYRI CÜMLELERDİR. Aynı metni kullansaydık internetsiz
        // bir bayi kendi parolasını değiştirmeye kalkardı — gerçek arıza ise ağdaydı.
        _hata = e.message;
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    final t = context.sip;
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      mainAxisSize: MainAxisSize.min,
      children: [
        SipNotKutusu(
          metin: widget.eylemMetni,
          ikon: SipIcons.lock,
          tur: SipNotTuru.uyari,
        ),
        const SizedBox(height: SipSpace.xl),
        Text(
          'Oturumdaki hesabın parolası',
          style: SipText.metin(12.5, w: 600).copyWith(color: t.muted),
        ),
        const SizedBox(height: SipSpace.md),
        SipInput(
          controller: _parola,
          ipucu: '••••••••',
          gizli: true,
          aktif: !_calisiyor,
          buyukHarfKipi: TextCapitalization.none,
          onSubmitted: (_) => _dogrula(),
        ),
        if (_hata != null) ...[
          const SizedBox(height: SipSpace.md),
          Text(
            _hata!,
            style: SipText.metin(12.5, w: 600).copyWith(color: t.danger),
          ),
        ],
        const SizedBox(height: SipSpace.x4),
        SipButon(
          etiket: _calisiyor ? 'Doğrulanıyor…' : 'Onayla',
          onTap: _calisiyor ? null : _dogrula,
        ),
      ],
    );
  }
}

/// Kapanışı geri alma AKIŞI: uyarı → yönetici onayı → ters kayıt. `true` dönerse ekran tazelenir.
///
/// KAPI ÜÇLÜ ve üçü de farklı bir şeyi kapatır:
///  1. Çağıran ekran düğmeyi yetkisiz kullanıcıya HİÇ çizmez (`yetkiler().gunuKapatma`).
///  2. Burada onay diyaloğu + PAROLA — kazayla dokunma ve "telefon açık kalmış" hâlleri.
///  3. `DayClosingRepository.geriAl` kendi kapılarını yeniden sorar (zaten geri alınmış mı,
///     gün kapalı mı) — sheet açıkken senkron başka bir cihazın kaydını indirmiş olabilir.
Future<bool> kapanisGeriAl(
  BuildContext context, {
  required AppDatabase db,
  required Session session,
  required DayClosing kapanis,
  required String kapsamAdi,
}) async {
  final kurye = kapanis.userId != null;
  final onay = await sipOnay(
    context,
    baslik: 'Hesap geri alınsın mı?',
    mesaj: '$kapsamAdi hesabı yeniden açılır ve düzeltip tekrar kapatabilirsiniz. '
        'Kapanış kaydı silinmez, arşivde "geri alındı" olarak görünmeye devam eder.'
        '${kurye ? ' Bu kapanışla alınan kasa devri de geri alınır.' : ''}',
    onayEtiketi: 'Devam',
    tehlike: true,
  );
  if (!onay || !context.mounted) return false;

  final onaylandi = await yoneticiOnayiIste(
    context,
    session: session,
    eylemMetni: 'Kapatılmış bir hesabı geri almak üzeresiniz. '
        'Bu işlem için yönetici parolası gerekir.',
  );
  if (!onaylandi || !context.mounted) return false;

  try {
    await DayClosingRepository(db).geriAl(closingId: kapanis.id);
  } on StateError catch (e) {
    if (!context.mounted) return false;
    // `StateError.message` repo'nun Türkçe gerekçesidir ("zaten geri alınmış", "önce gün
    // hesabını geri alın"…) — kullanıcıya AYNEN gösterilir. Genel bir "işlem başarısız"
    // metni, bayiyi tekrar tekrar denemeye iterdi.
    SipToast.goster(context, e.message);
    return false;
  }

  if (!context.mounted) return false;
  SipToast.goster(context, 'Hesap geri alındı. Düzeltip yeniden kapatabilirsiniz.');
  return true;
}
