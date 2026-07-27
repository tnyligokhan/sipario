// Müşteri para sheet'leri — Tahsilat (CSS `.kd-row`/`.kd-input`/`.th-chip`/`.odeme-b`) ve
// Bakiye Düzeltme. Kaynak: s-musteriler.jsx `MusteriDetay` içindeki iki Sheet.
//
// KIRMIZI ÇİZGİ #2 — defter APPEND-ONLY: hiçbir sheet `customers.balance_kurus`'a dokunmaz.
// Bakiye defterden yeniden hesaplanır (ledger_ops.recomputeCustomerBalance), biz yalnız YENİ
// kayıt yazarız. Tahsilat `payment(−)`, düzeltme `correction(imzalı)`.
// Para: kullanıcı yazımı ↔ kuruş dönüşümü YALNIZ money.dart (parseKurus) üzerinden.
//
// FAZLA TAHSİLAT SERBEST (2026-07-27, saha eksiği 5b): tahsilat açık borçtan fazla olabilir,
// müşteri alacaklı duruma geçer. Eskiden reddediliyordu; sahada müşteri 500 ₺ borcuna 600 ₺
// verdiğinde bayinin elinde iki kötü seçenek kalıyordu — ya 500 yazıp 100'ü kayıt dışı bırakmak,
// ya da farkı `correction` ile işlemek. İkisi de KASAYI yanlış gösterir: kasa toplamı `payment`
// satırlarından çıkar, `correction` oraya girmez. Kasaya giren para deftere girer; alacaklı
// bakiye zaten modelde var (`credit`/`correction` onu üretebiliyordu).
//
// ALAN KURUŞ KABUL EDER, ÇİPLER TAM LİRA YUVARLAR (2026-07-27). Tasarım (s-musteriler.jsx:88,157)
// alanı `\D` ile süzüyordu. Kaldırıldı çünkü gerekçesi tahsilatın YALNIZ BİR TİPİNİ kapsıyordu:
// "kasadan sayılan nakit tam liradır" doğru, ama `payment_type` nakit|kart|havale'dir — kartla
// veya havaleyle 85,50 ₺ tahsil etmek olağandır ve borcu TAM kapatır. Tam lira kısıtı orada
// karşılıksızdı ve kuruşlu borcu kapatmayı imkânsız kılıyordu.
//
// Çipler ise TAM LİRA yuvarlamaya devam eder — onlar kısayoldur, kasada sayılan yuvarlak rakamı
// önerirler; kuruş isteyen alana yazar. TEK İSTİSNA "Tamamı" çipi: adı bir kesinlik iddiasıdır,
// borcun tamamını kuruşuyla doldurur (yoksa "Tamamı" borcu kapatmayan bir tutar yazardı).

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

import '../../data/app_database.dart';
import '../../data/ids.dart';
import '../../repo/ledger_ops.dart';
import '../../repo/ledger_repository.dart';
import '../../theme/components/atoms.dart';
import '../../theme/components/overlays.dart';
import '../../theme/icons.dart';
import '../../theme/tokens.dart';
import '../../theme/typography.dart';
import '../money.dart';
import 'customer_widgets.dart';

/// Tahsilat sheet'i — açık borç gösterir, tutar + ödeme tipi alır, deftere `payment` yazar.
/// `true` dönerse kayıt yapıldı.
Future<bool?> tahsilatSheet(
  BuildContext context, {
  required AppDatabase db,
  required String customerId,
  required int bakiyeKurus,
}) {
  return sipSheet<bool>(
    context,
    baslik: 'Tahsilat Al',
    govde: (ctx) => _TahsilatGovde(db: db, customerId: customerId, bakiyeKurus: bakiyeKurus),
  );
}

/// SİPARİŞ DIŞI BORÇ TAHSİLATININ TEK GİRİŞ NOKTASI — çağıran yalnız müşteri kimliğini bilir.
///
/// [tahsilatSheet] açık bakiyeyi PARAMETRE olarak ister; bu da onu ancak müşteri kaydını elinde
/// tutan ekranların (müşteri detayı) çağırabilmesi demekti. Sipariş listesindeki "Borçlu" sekmesi
/// elinde `OrderListItem` tutar, `Customer` değil — bakiyeyi kendi başına okumak zorunda kalırdı
/// ve iki ekran ayrı ayrı okuyunca "hangisi güncel" sorusu doğardı. Burası bakiyeyi ÇAĞRI ANINDA
/// defter önbelleğinden okur (tek atış, akış değil: sheet açılmadan başlık ve tutar gerekiyor).
///
/// Müşteri bulunamazsa sheet AÇILMAZ ve `null` döner. `true` = tahsilat deftere yazıldı.
Future<bool?> borcTahsilatiAc(
  BuildContext context, {
  required AppDatabase db,
  required String customerId,
}) async {
  final musteri = await (db.select(db.customers)..where((t) => t.id.equals(customerId)))
      .getSingleOrNull();
  if (musteri == null || !context.mounted) return null;
  return sipSheet<bool>(
    context,
    // Başlıkta müşterinin adı: borçlu listesinden gelen kullanıcı hangi kaydı işlediğini
    // sheet'in içinde bir daha görmüyor (müşteri detayında olduğu gibi arkada duran ekran yok).
    baslik: musteri.name,
    govde: (ctx) => _TahsilatGovde(
      db: db,
      customerId: customerId,
      bakiyeKurus: musteri.balanceKurus,
    ),
  );
}

/// Bakiye düzeltme sheet'i — imzalı tutar + ZORUNLU açıklama, deftere `correction` yazar.
Future<bool?> duzeltmeSheet(
  BuildContext context, {
  required AppDatabase db,
  required String customerId,
  required int bakiyeKurus,
}) {
  return sipSheet<bool>(
    context,
    baslik: 'Bakiye Düzeltme',
    govde: (ctx) => _DuzeltmeGovde(db: db, customerId: customerId, bakiyeKurus: bakiyeKurus),
  );
}

// ═══════════════════════════════════════════════════════════════════════════════════════════
// Tahsilat
// ═══════════════════════════════════════════════════════════════════════════════════════════

/// "Yarısı" çipinin önerdiği tutar — tasarım `Math.round(borc/200)` TL (s-musteriler.jsx:160).
/// Kısayol olduğu için TAM LİRAYA yuvarlar: 85,50 ₺ borçta 43 (42,75 değil). Kuruş isteyen
/// kullanıcı alana kendisi yazar.
String yarisiTamLira(int borcKurus) => (borcKurus / 200).round().toString();

/// Tahsilat sonrası müşterinin bakiyesi (imzalı kuruş: + borç, − alacak).
///
/// Ekrandan AYRI saf fonksiyon — uyarı metninin dayanağı budur ve testi widget kurmadan yazılır.
/// Defterin kendi hesabıyla aynı işi yapar: `payment` satırı bakiyeye `−tahsil` olarak girer.
int tahsilatSonrasiBakiye(int bakiyeKurus, int tahsilKurus) => bakiyeKurus - tahsilKurus;

/// Girilen tahsilat tutarının hata metni; geçerliyse `null`.
///
/// Açık borçtan FAZLASI hatadır SAYILMAZ (dosya başlığındaki karar) — yalnız uyarı doğurur.
/// Tek kural: para gerçekten alınmış olmalı, yani tutar 0'dan büyük olmalı.
String? tahsilatHatasi(int? tahsilKurus) =>
    (tahsilKurus == null || tahsilKurus <= 0) ? 'Tutar girin' : null;

class _TahsilatGovde extends StatefulWidget {
  const _TahsilatGovde({required this.db, required this.customerId, required this.bakiyeKurus});

  final AppDatabase db;
  final String customerId;
  final int bakiyeKurus;

  @override
  State<_TahsilatGovde> createState() => _TahsilatGovdeState();
}

class _TahsilatGovdeState extends State<_TahsilatGovde> {
  late final int _borc = widget.bakiyeKurus > 0 ? widget.bakiyeKurus : 0;

  /// Ön dolgu açık borcun TAMAMIDIR, kuruşuyla — en sık iş "borcu tam kapat"tır ve kart/havale
  /// tahsilatında kuruş gerçektir (dosya başlığı).
  late final TextEditingController _tutar =
      TextEditingController(text: _borc > 0 ? tutarGirdisi(_borc) : '');
  String _odeme = 'nakit';
  String? _hata;
  bool _calisiyor = false;

  @override
  void dispose() {
    _tutar.dispose();
    super.dispose();
  }

  Future<void> _kaydet() async {
    final kurus = parseKurus(_tutar.text);
    final hata = tahsilatHatasi(kurus);
    if (hata != null) {
      setState(() => _hata = hata);
      return;
    }
    setState(() => _calisiyor = true);
    await LedgerRepository(widget.db).tahsilat(widget.customerId, kurus!, _odeme);
    if (mounted) Navigator.of(context).pop(true);
  }

  @override
  Widget build(BuildContext context) {
    final t = context.sip;
    final girilen = parseKurus(_tutar.text);
    // Fazla tahsilat REDDEDİLMEZ (dosya başlığı), ama sessiz de geçilmez: bakiyeyi eksiye
    // düşüren tutar kullanıcıya söylenir — yanlış yazılmış bir hane böyle yakalanır.
    final alacakKurus = girilen == null ? 0 : -tahsilatSonrasiBakiye(_borc, girilen);
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        SipTutarSatiri(
          etiket: 'Açık borç',
          kurus: _borc,
          renk: _borc > 0 ? t.danger : t.ok,
        ),
        if (_borc == 0)
          SipDurumSeridi(
            metin: 'Bu müşterinin açık borcu yok.',
            ikon: SipIcons.check,
            renk: t.ok,
            zemin: t.okSoft,
          )
        else ...[
          const SipFormEtiket('Tahsil edilecek tutar (₺)', ustBosluk: SipSpace.x2),
          SipInput(
            controller: _tutar,
            // Rakam + ayraç: kartla/havaleyle kuruşlu tahsilat olağandır (dosya başlığı).
            // Hangi ayracın geleceği klavyeye göre değişir, ikisi de kabul edilir; TR yazımını
            // `parseKurus` çözer ve çözemezse SESSİZ YUVARLAMA yapmadan null döner.
            klavye: const TextInputType.numberWithOptions(decimal: true),
            girdiFiltreleri: [FilteringTextInputFormatter.allow(RegExp(r'[0-9,.]'))],
            ipucu: '0',
            hizalama: TextAlign.start,
            stil: SipText.tutar(22),
            yukseklik: 56,
            hata: _hata != null,
            otomatikOdak: true,
            // Her tuşta yeniden çizilir: "Tamamı" çipinin seçili görünmesi ve fazla-tahsilat
            // uyarısı yazılan tutardan türer; yalnız hata varken çizmek ikisini de dondururdu.
            onChanged: (_) => setState(() => _hata = null),
          ),
          if (_hata != null) SipHataSatiri(metin: _hata!),
          Padding(
            padding: const EdgeInsets.only(top: SipSpace.lg),
            child: Row(
              children: [
                Expanded(
                  child: SipCip(
                    etiket: 'Tamamı · ${sipTutar(_borc)}',
                    // "Tamamı" KURUŞUYLA doldurur — adı bir kesinlik iddiası: tam liraya
                    // yuvarlasaydı 85,50 ₺ borçta 85 yazıp borcu kapatmazdı (ve çip, kendi
                    // yazdığı değerle `secili` görünmezdi).
                    secili: girilen == _borc,
                    onTap: () => setState(() {
                      _tutar.text = tutarGirdisi(_borc);
                      _hata = null;
                    }),
                  ),
                ),
                if (_borc >= 200) ...[
                  const SizedBox(width: SipSpace.md),
                  Expanded(
                    child: SipCip(
                      etiket: 'Yarısı',
                      secili: false,
                      // Kısayol → TAM LİRA (bkz. [yarisiTamLira]); alan kuruş kabul etse de çip
                      // kasada sayılan yuvarlak rakamı önerir.
                      onTap: () => setState(() {
                        _tutar.text = yarisiTamLira(_borc);
                        _hata = null;
                      }),
                    ),
                  ),
                ],
              ],
            ),
          ),
          if (alacakKurus > 0)
            SipHataSatiri(
              metin: 'Bu tahsilat açık borcu aşıyor — müşteri '
                  '${sipTutar(alacakKurus)} alacaklı duruma geçecek.',
              renk: t.warn,
              ikon: SipIcons.info,
            ),
          const SipFormEtiket('Ödeme tipi'),
          SipOdemeSecici(secili: _odeme, onSec: (k) => setState(() => _odeme = k)),
          const SizedBox(height: 18),
          SipButon(
            etiket: 'Tahsilatı Kaydet',
            ikon: SipIcons.check,
            yukleniyor: _calisiyor,
            onTap: _kaydet,
          ),
        ],
      ],
    );
  }
}

// ═══════════════════════════════════════════════════════════════════════════════════════════
// Bakiye düzeltme
// ═══════════════════════════════════════════════════════════════════════════════════════════

class _DuzeltmeGovde extends StatefulWidget {
  const _DuzeltmeGovde({required this.db, required this.customerId, required this.bakiyeKurus});

  final AppDatabase db;
  final String customerId;
  final int bakiyeKurus;

  @override
  State<_DuzeltmeGovde> createState() => _DuzeltmeGovdeState();
}

class _DuzeltmeGovdeState extends State<_DuzeltmeGovde> {
  final _tutar = TextEditingController();
  final _not = TextEditingController();
  bool _ekle = true;
  String? _tutarHatasi;
  String? _notHatasi;
  bool _calisiyor = false;

  @override
  void dispose() {
    _tutar.dispose();
    _not.dispose();
    super.dispose();
  }

  int get _kurus => parseKurus(_tutar.text) ?? 0;

  Future<void> _kaydet() async {
    final kurus = _kurus;
    final not = _not.text.trim();
    setState(() {
      _tutarHatasi = kurus <= 0 ? 'Tutar 0’dan büyük olmalı' : null;
      _notHatasi =
          not.length < 2 ? 'Açıklama girin — düzeltmenin nedeni deftere yazılır' : null;
    });
    if (_tutarHatasi != null || _notHatasi != null) return;

    setState(() => _calisiyor = true);
    await bakiyeDuzeltmesiYaz(widget.db, widget.customerId, _ekle ? kurus : -kurus, not);
    if (mounted) Navigator.of(context).pop(true);
  }

  @override
  Widget build(BuildContext context) {
    final t = context.sip;
    final b = widget.bakiyeKurus;
    final alacakliOlacak = !_ekle && _kurus > 0 && _kurus > (b > 0 ? b : 0);
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        SipTutarSatiri(
          etiket: 'Mevcut bakiye',
          kurus: b,
          renk: t.bakiyeRenk(b),
          sifirMetni: 'Temiz',
          etiketEkle: true,
        ),
        const SipFormEtiket('İşlem', ustBosluk: SipSpace.md),
        Row(
          children: [
            Expanded(
              child: SipSecimKutusu(
                etiket: 'Borç Ekle (+)',
                secili: _ekle,
                onTap: () => setState(() {
                  _ekle = true;
                  _tutarHatasi = null;
                }),
              ),
            ),
            const SizedBox(width: 7),
            Expanded(
              child: SipSecimKutusu(
                etiket: 'Borç Azalt (−)',
                secili: !_ekle,
                onTap: () => setState(() {
                  _ekle = false;
                  _tutarHatasi = null;
                }),
              ),
            ),
          ],
        ),
        const SipFormEtiket('Tutar (₺)'),
        SipInput(
          controller: _tutar,
          // Tasarım `inputMode="numeric"` + `replace(/\D/g,'')` (s-musteriler.jsx:188).
          klavye: TextInputType.number,
          girdiFiltreleri: [FilteringTextInputFormatter.digitsOnly],
          ipucu: '0',
          stil: SipText.tutar(17),
          hata: _tutarHatasi != null,
          onChanged: (_) => setState(() => _tutarHatasi = null),
        ),
        if (_tutarHatasi != null) SipHataSatiri(metin: _tutarHatasi!),
        const SipFormEtiket('Açıklama (zorunlu)'),
        SipInput(
          controller: _not,
          ipucu: 'Ör. eksik yazılan tutar, iade, pazarlık…',
          hata: _notHatasi != null,
          onChanged: (_) => setState(() => _notHatasi = null),
        ),
        if (_notHatasi != null) SipHataSatiri(metin: _notHatasi!),
        if (alacakliOlacak)
          Padding(
            padding: const EdgeInsets.only(top: SipSpace.md),
            child: SipHataSatiri(
              metin: 'Bu düzeltmeyle müşteri alacaklı duruma geçecek.',
              renk: t.warn,
              ikon: SipIcons.info,
            ),
          ),
        const SizedBox(height: 18),
        SipButon(
          etiket: 'Düzeltmeyi Kaydet',
          ikon: SipIcons.check,
          yukleniyor: _calisiyor,
          onTap: _kaydet,
        ),
      ],
    );
  }
}

/// Serbest bakiye düzeltmesi — mevcut bir kaydı TERS ÇEVİRMEZ, imzalı yeni bir `correction`
/// satırı ekler (append-only). Outbox olayı ve bakiye önbelleği [writeLedgerEntry] içinde,
/// AYNI transaction'da kurulur.
///
/// GEÇİCİ: `LedgerRepository.duzeltme()` bir `reversesEntryId` zorunlu kılıyor; serbest düzeltme
/// için repo metodu `backend` ajanından istendi (`bakiyeDuzelt`). O gelince burası ona devreder.
Future<String> bakiyeDuzeltmesiYaz(
  AppDatabase db,
  String customerId,
  int imzaliKurus,
  String not,
) async {
  final meta = await db.syncState();
  final at = correctedNowIso(meta.serverTimeOffsetMs);
  late String id;
  await db.transaction(() async {
    id = await writeLedgerEntry(
      db,
      entryType: 'correction',
      amountKurus: imzaliKurus,
      customerId: customerId,
      collectedByUserId: meta.userId,
      note: not,
      occurredAt: at,
      deviceId: meta.deviceId,
    );
  });
  return id;
}
