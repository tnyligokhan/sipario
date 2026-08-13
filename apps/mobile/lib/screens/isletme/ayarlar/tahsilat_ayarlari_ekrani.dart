// AYARLAR → TAHSİLAT — paranın nasıl tahsil edildiğine dair ayarlar.
//
// ══ NEDEN İŞLETME PROFİLİNDEN ÇIKTI (kullanıcı eleştirisi 2026-08-13) ══════════════════════
// IBAN, IBAN alıcı adı ve fiş notu, "İşletme Profili" adlı TEK bir devasa formun içinde
// duruyordu — ad, yetkili, telefon, adres, vergi dairesi ve çalışma saatleriyle aynı sayfada.
// Kullanıcının tespiti şuydu: bunların İşletme kimliğiyle hiçbir ilgisi yok.
//
// Doğruydu. "İşletme" sorusu **biz kimiz**dir (unvan, iletişim, vergi, saatler). IBAN ise
// **parayı nasıl alıyoruz** sorusudur ve zamanla büyüyecek bir başlıktır: fiş/makbuz, ikinci
// hesap, ödeme yöntemleri hep buraya girer. Tek forma sıkıştırmak, her yeni ayarı bir öncekinin
// üstüne yığmak demekti.
//
// ⚠️ KISMİ KAYIT GÜVENLİDİR: `TenantSettingsRepository.save` artık `Value.absent()` sentineli
// kullanıyor, yani bu ekran YALNIZ kendi alanlarını gönderir ve işletme adına, vergi numarasına
// ya da kurye yetkilerine DOKUNMAZ. Bölme ancak bu temel değiştikten sonra güvenli oldu —
// öncesinde her ekran diğer 14 alanı elle taşımak zorundaydı (gerekçe repo doc'unda).

import 'package:drift/drift.dart' show Value;
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

import '../../../data/app_database.dart';
import '../../../repo/tenant_settings_repository.dart';
import '../../../theme/components/atoms.dart';
import '../../../theme/components/overlays.dart';
import '../../../theme/components/states.dart';
import '../../../theme/tokens.dart';
import '../../../theme/typography.dart';
import '../iban.dart';
import '../isletme_atomlari.dart';
import '../isletme_profili_ekrani.dart' show profilSaltOkunurUyarisi;

class TahsilatAyarlariEkrani extends StatefulWidget {
  const TahsilatAyarlariEkrani({super.key, required this.db, this.writable = true});

  final AppDatabase db;
  final bool writable;

  @override
  State<TahsilatAyarlariEkrani> createState() => _TahsilatAyarlariEkraniState();
}

class _TahsilatAyarlariEkraniState extends State<TahsilatAyarlariEkrani> {
  late final _repo = TenantSettingsRepository(widget.db);
  late final Future<TenantSetting?> _veri = _repo.get();

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
            SipUst(baslik: 'Tahsilat', onGeri: () => Navigator.of(context).maybePop()),
            Expanded(
              child: FutureBuilder<TenantSetting?>(
                future: _veri,
                builder: (context, snap) {
                  if (snap.connectionState != ConnectionState.done) {
                    return const SipGovde(children: [SipIskelet(adet: 3)]);
                  }
                  return _Form(repo: _repo, satir: snap.data, writable: widget.writable);
                },
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _Form extends StatefulWidget {
  const _Form({required this.repo, required this.satir, required this.writable});

  final TenantSettingsRepository repo;
  final TenantSetting? satir;
  final bool writable;

  @override
  State<_Form> createState() => _FormState();
}

class _FormState extends State<_Form> {
  late final _iban = TextEditingController(text: ibanOkunur(widget.satir?.iban));
  late final _alici = TextEditingController(text: widget.satir?.ibanOwnerName ?? '');
  late final _fisNotu = TextEditingController(text: widget.satir?.receiptNote ?? '');

  String? _ibanHata;
  bool _kaydediyor = false;

  @override
  void dispose() {
    _iban.dispose();
    _alici.dispose();
    _fisNotu.dispose();
    super.dispose();
  }

  Future<void> _kaydet() async {
    if (_kaydediyor) return;
    if (!widget.writable) {
      SipToast.goster(context, profilSaltOkunurUyarisi);
      return;
    }

    final hata = ibanHatasi(_iban.text);
    if (hata != null) {
      setState(() => _ibanHata = hata);
      return;
    }

    setState(() => _kaydediyor = true);
    // YALNIZ BU EKRANIN ALANLARI gönderilir. Fiş notu BİLEREK dışarıda: alan pasif olduğu için
    // kullanıcı onu değiştiremez ve göndermek, "dokunulmayan alan taşınır" kuralını gereksiz
    // yere sınamak olurdu.
    await widget.repo.save(
      iban: Value(ibanNormal(_iban.text.trim())),
      ibanOwnerName: Value(_bosNull(_alici.text)),
    );
    if (!mounted) return;
    setState(() => _kaydediyor = false);
    SipToast.goster(context, 'Tahsilat bilgileri kaydedildi');
  }

  String? _bosNull(String s) => s.trim().isEmpty ? null : s.trim();

  @override
  Widget build(BuildContext context) {
    return SipGovde(
      children: [
        const SipBolumBaslik('Havale / EFT', ustBosluk: 18),
        const SipFormEtiket('IBAN', ustBosluk: 2),
        SipInput(
          controller: _iban,
          ipucu: 'TR00 0000 0000 0000 0000 0000 00',
          stil: SipText.tutar(15, w: 500),
          girdiFiltreleri: [IbanBicimi()],
          hata: _ibanHata != null,
          onChanged: (_) {
            if (_ibanHata != null) setState(() => _ibanHata = null);
          },
        ),
        if (_ibanHata != null) AlanNotu(_ibanHata!, tur: AlanNotuTuru.uyari),
        // ALICI ADI IBAN'IN HEMEN ALTINDA (kullanıcı isteği 2026-08-06): hesap sahibi çoğu zaman
        // ŞAHIS adıdır ve işletme adıyla aynı değildir; banka uygulaması havale ekranında ad
        // soyad ister, müşteri "Merkez Su Bayii" yazınca işlemi tamamlayamaz.
        const SipFormEtiket('IBAN ALICI ADI'),
        SipInput(controller: _alici, ipucu: 'Hesap sahibi — ad soyad'),
        if (_ibanHata == null)
          const AlanNotu(
            'Borçlulara gönderilen WhatsApp hatırlatmasında bu IBAN ve alıcı adı yazar.',
            tur: AlanNotuTuru.bilgi,
          ),

        // FİŞ BURAYA TAŞINDI, İŞLETME KİMLİĞİNDEN ÇIKTI (kullanıcı eleştirisi 2026-08-13):
        // fiş bir tahsilat belgesidir, dükkânın kimlik bilgisi değil. Alan hâlâ PASİF —
        // `receipt_note` kolonunu okuyan hiçbir çıktı yok (gerekçe `CokYakindaBaslik`ta).
        const CokYakindaBaslik('Fiş Alt Notu'),
        SipInput(
          controller: _fisNotu,
          ipucu: 'Teslim fişi özelliğiyle birlikte açılacak',
          satirlar: 2,
          aktif: false,
        ),

        Padding(
          padding: const EdgeInsets.only(top: SipSpace.govde),
          child: SipButon(etiket: 'Kaydet', onTap: _kaydet, yukleniyor: _kaydediyor),
        ),
      ],
    );
  }
}

/// IBAN alanı biçimlendirici: harfleri büyütür, IBAN'da yeri olmayan karakterleri düşürür.
///
/// Boşluğa İZİN VERİLİR (silinmez): bayi hesabını bankadan gördüğü gibi "TR12 3456 …" yazar ve
/// kendi yazdığını okuyabilmelidir. Boşluk yalnız KAYDEDERKEN atılır — saklama biçimi tektir.
///
/// İŞLETME PROFİLİNDEN BURAYA TAŞINDI (2026-08-13): IBAN'ın yazıldığı tek ekran artık burası.
class IbanBicimi extends TextInputFormatter {
  @override
  TextEditingValue formatEditUpdate(TextEditingValue eski, TextEditingValue yeni) {
    final temiz = yeni.text.toUpperCase().replaceAll(RegExp(r'[^0-9A-Z ]'), '');
    if (temiz == yeni.text) return yeni;
    // İmleç, düşen karakter sayısı kadar geri alınır; yoksa kullanıcı yazdıkça imleç sona atlar.
    final fark = yeni.text.length - temiz.length;
    final konum = (yeni.selection.baseOffset - fark).clamp(0, temiz.length);
    return TextEditingValue(
      text: temiz,
      selection: TextSelection.collapsed(offset: konum),
    );
  }
}
