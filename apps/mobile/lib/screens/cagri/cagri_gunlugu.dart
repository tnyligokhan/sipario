// Çağrı geçmişi listesi — "Son Aramalar".
//
// TASARIM DIŞI EKLEME (bilinçli): nihai tasarımda ayrı bir çağrı günlüğü EKRANI YOKTUR.
// Çağrı geçmişinin tasarımdaki tek yüzeyi ana ekrandaki "Son Arama" bento kutusudur
// (`s-ana.jsx:45`) ve o kutu yalnız EN SON aramayı gösterir — onun verisi için bu dosyadaki
// [sonAramaAkisi] kullanılır. Tam liste ekranı, `call_logs` tablosu zaten geçmiş tuttuğu ve
// bayinin "kim aramıştı" sorusunun makul olduğu için eklendi.
//
// (Eski sürümde bu dosya `s-bugun.jsx`e dayanıyordu; o dosya tasarımın TERK EDİLMİŞ bir ara
// sürümü — `Sipario.html` onu hiç yüklemiyor ve kullandığı sınıfların hiçbiri CSS'te yok.
// Yerini `s-ana.jsx` aldı. Referans alınmaz.)
//
// ÖLÇÜ KAYNAĞI: güncel tasarımın liste satırı kalıbı `.akt-row` (Sipario.html 95–102):
// 30'luk TAM YUVARLAK ikon, r2 köşe, 12/14 iç boşluk, 11 aralık, başlık 13.5/700,
// alt satır 11.5 muted.
//
// DOKUNMA KURALI (`s-uygulama.jsx:90` — `onAramaAc`): numara KAYITLIYSA müşteri detayına
// gidilir, KAYITSIZSA çağrı kartı açılır. Karar çağırana ait; bu ekran yalnız [AramaKaydi]
// döndürür, `lib/screens/customers` ya da çağrı kartını kendisi TANIMAZ.

import '../../sync/yenileme.dart';
import 'package:drift/drift.dart' show OrderingTerm, leftOuterJoin;
import 'package:flutter/material.dart';

import '../../data/app_database.dart';
import '../../repo/call_log_repository.dart';
import '../../theme/components/atoms.dart';
import '../../theme/components/states.dart';
import '../../theme/icons.dart';
import '../../theme/tokens.dart';
import '../../theme/typography.dart';
import 'cagri_kuyrugu.dart';
import 'cagri_model.dart';

/// Tek arama satırı — CSS `.akt-row`.
class AramaSatiri extends StatelessWidget {
  const AramaSatiri({super.key, required this.arama, this.onAc});

  final AramaKaydi arama;
  final ValueChanged<AramaKaydi>? onAc;

  @override
  Widget build(BuildContext context) {
    final t = context.sip;
    final cevapsiz = arama.tip == AramaTipi.cevapsiz;
    final kayitli = arama.kayitli;

    // Alt satır: kayıtlıysa "numara · sonuç", kayıtsızsa yalnız sonuç (numara üstte baskın).
    final numara = sipTelefon(arama.numara);
    final sonuc = arama.sonuc;
    final alt = [
      if (kayitli) numara,
      if (sonuc != null && sonuc.isNotEmpty) sonuc,
    ].join(' · ');

    return SipDokun(
      onTap: onAc == null ? null : () => onAc!(arama),
      zemin: t.surface,
      radius: SipRadius.br2,
      padding: const EdgeInsets.symmetric(horizontal: SipSpace.x2, vertical: SipSpace.xl),
      child: Row(
        children: [
          // CSS `.akt-ic` — 30'luk tam yuvarlak. Cevapsızda danger, diğerlerinde nötr.
          // ÜÇ YÖN ÜÇ AYRI İKON: cevapsız çağrı da `phone` çiziyordu, yani gelenle arasındaki
          // tek fark zeminin rengiydi (2026-07-27 saha bulgusu).
          SipIkonKutu(
            ikon: switch (arama.tip) {
              AramaTipi.giden => SipIcons.phoneCall,
              AramaTipi.cevapsiz => SipIcons.phoneOff,
              AramaTipi.gelen => SipIcons.phone,
            },
            cap: 30,
            ikonBoyut: 15,
            kalinlik: 2.4,
            zemin: cevapsiz ? t.dangerSoft : t.surface2,
            renk: cevapsiz ? t.danger : t.ink2,
          ),
          const SizedBox(width: 11),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              mainAxisSize: MainAxisSize.min,
              children: [
                Text(
                  // CSS `.akt-t`
                  kayitli ? (arama.ad ?? numara) : numara,
                  // Kayıtsız numarada ad yerine numara durur ve sönükleşir.
                  style: SipText.govdeKalin.copyWith(color: kayitli ? t.ink : t.ink2),
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                ),
                // CSS `.akt-s` — yön sözcüğü ayrı bir metindir, `alt`ın içine katılmaz:
                // uzun sonuç metni kısaldığında ilk kaybolacak şey yön olurdu. Bayi listede
                // "kim aramıştı" kadar "ben mi aradım" sorusuna da cevap arar.
                Padding(
                  padding: const EdgeInsets.only(top: 1),
                  child: Row(
                    children: [
                      Text(
                        aramaTipiSozcugu(arama.tip),
                        style: SipText.yardimci.copyWith(
                          color: cevapsiz ? t.danger : t.muted,
                          fontWeight: FontWeight.w700,
                        ),
                      ),
                      if (alt.isNotEmpty) ...[
                        Text(
                          ' · ',
                          style: SipText.yardimci.copyWith(color: t.muted),
                        ),
                        Flexible(
                          child: Text(
                            alt,
                            style: SipText.yardimci.copyWith(color: t.muted),
                            maxLines: 1,
                            overflow: TextOverflow.ellipsis,
                          ),
                        ),
                      ],
                    ],
                  ),
                ),
              ],
            ),
          ),
          const SizedBox(width: SipSpace.lg),
          Text(
            arama.saat,
            style: SipText.saat.copyWith(color: t.muted),
          ),
        ],
      ),
    );
  }
}

/// Çağrı geçmişi ekranı — SAF GÖRÜNÜM (liste dışarıdan verilir).
/// Veriyle bağlanmış hâli için [CagriGunluguSayfasi].
class CagriGunluguEkrani extends StatelessWidget {
  const CagriGunluguEkrani({
    super.key,
    required this.aramalar,
    this.yukleniyor = false,
    this.onGeri,
    this.onAc,
  });

  final List<AramaKaydi> aramalar;
  final bool yukleniyor;
  final VoidCallback? onGeri;
  final ValueChanged<AramaKaydi>? onAc;

  @override
  Widget build(BuildContext context) {
    final t = context.sip;
    // Scaffold + SafeArea: bu ekran tam sayfa olarak PUSH ediliyor (Ayarlar → Çağrı Geçmişi).
    // İkisi de yoktu; başlık durum çubuğunun ALTINA giriyordu ve liste altta gezinme
    // çubuğunun altından taşıyordu (2026-07-28 saha bulgusu). Depodaki diğer tam sayfa
    // ekranlar (day_end_screen, customer_detail) zaten bu deseni kullanıyor.
    return Scaffold(
      backgroundColor: t.bg,
      body: SafeArea(
        bottom: false,
        child: Column(
          children: [
            SipUst(baslik: 'Son Aramalar', onGeri: onGeri),
            Expanded(child: _govde(context)),
          ],
        ),
      ),
    );
  }

  Widget _govde(BuildContext context) {
    if (yukleniyor) return const SipIskelet();
    if (aramalar.isEmpty) {
      return const SipBosDurum(
        baslik: 'Henüz arama yok',
        aciklama:
            'Gelen ve giden çağrılar burada listelenir. Kayıtlı müşteriler adıyla, '
            'diğerleri numarasıyla görünür.',
        ikon: SipIcons.phone,
      );
    }
    return SipGovde(
      // Aşağı çekerek yenile: liste sunucudan senkronla besleniyor (kullanıcı isteği 2026-07-29).
      onYenile: yenile,
      // SafeArea `bottom: false` — liste gezinme çubuğunun ALTINA kayabilsin (kaydırırken
      // içerik oradan geçer) ama SON satır onun altında KALMASIN diye alt boşluğa sistem
      // payı eklenir. Sabit bir boşluk, jest çubuğu olan ve olmayan cihazlarda tutmaz.
      altBosluk: SipSpace.x4 + MediaQuery.viewPaddingOf(context).bottom,
      children: [
        for (var i = 0; i < aramalar.length; i++) ...[
          if (i > 0) const SizedBox(height: SipSpace.sm),
          AramaSatiri(arama: aramalar[i], onAc: onAc),
        ],
      ],
    );
  }
}

// ═══════════════════════════════════════════════════════════════════════════════════════════
// Veri bağlantısı — `call_logs` tablosu
// ═══════════════════════════════════════════════════════════════════════════════════════════

/// Çağrı geçmişini DB'den okuyup ekrana besleyen sayfa.
///
/// Açılışta native çağrı kuyruğunu ([CagriKuyrugu]) boşaltır: telefon çalarken Flutter motoru
/// başlamadığı için çağrılar o an düz metin bir dosyaya birikir, tabloya buradan geçer.
class CagriGunluguSayfasi extends StatefulWidget {
  const CagriGunluguSayfasi({
    super.key,
    required this.db,
    this.limit = 50,
    this.onGeri,
    this.onAc,
  });

  final AppDatabase db;
  final int limit;
  final VoidCallback? onGeri;
  final ValueChanged<AramaKaydi>? onAc;

  @override
  State<CagriGunluguSayfasi> createState() => _CagriGunluguSayfasiState();
}

class _CagriGunluguSayfasiState extends State<CagriGunluguSayfasi> {
  late final Stream<List<AramaKaydi>> _akis =
      aramaKayitlariAkisi(widget.db, limit: widget.limit);

  /// Kuyruk boşaltma bilerek `await` EDİLMEZ: ekran beklemeden çizilir, yeni satırlar
  /// yazıldıkça stream kendiliğinden tazelenir.
  late final Future<int> _bosaltma =
      CagriKuyrugu(CallLogRepository(widget.db)).bosalt();

  @override
  void initState() {
    super.initState();
    _bosaltma.ignore();
  }

  @override
  Widget build(BuildContext context) {
    return StreamBuilder<List<AramaKaydi>>(
      stream: _akis,
      builder: (context, anlik) => CagriGunluguEkrani(
        aramalar: anlik.data ?? const [],
        yukleniyor: anlik.connectionState == ConnectionState.waiting,
        onGeri: widget.onGeri,
        onAc: widget.onAc,
      ),
    );
  }
}

/// `call_logs` + `customers` sol birleşimi → ekranın modeli. Yeni çağrı üstte.
///
/// Müşteri adı JOIN'den gelir: çağrı kaydı yalnız `customer_id` tutar, ad zamanla değişebilir
/// ve listede GÜNCEL ad görünmelidir (defterle aynı kişi olduğu anlaşılsın).
Stream<List<AramaKaydi>> aramaKayitlariAkisi(AppDatabase db, {int limit = 50}) {
  final sorgu = db.select(db.callLogs).join([
    leftOuterJoin(db.customers, db.customers.id.equalsExp(db.callLogs.customerId)),
  ])
    ..where(db.callLogs.deletedAt.isNull())
    ..orderBy([OrderingTerm.desc(db.callLogs.occurredAt)])
    ..limit(limit);

  return sorgu.watch().map((satirlar) {
    final simdi = DateTime.now();
    return [
      for (final s in satirlar)
        aramaKaydinaCevir(
          s.readTable(db.callLogs),
          s.readTableOrNull(db.customers),
          simdi: simdi,
        ),
    ];
  });
}

/// Ana ekrandaki "Son Arama" bento kutusunun verisi (`s-ana.jsx:45`) — yalnız EN SON arama,
/// kayıt yoksa `null` (kutu o zaman sönük çizilir). Tasarımdaki tek çağrı geçmişi yüzeyi
/// budur; kutuya dokunmanın kuralı dosya başındaki DOKUNMA KURALI'dır.
Stream<AramaKaydi?> sonAramaAkisi(AppDatabase db) =>
    aramaKayitlariAkisi(db, limit: 1)
        .map((liste) => liste.isEmpty ? null : liste.first);

/// Tek satırın çevrimi. Sonucu yazılmamış kayıtsız çağrıda tasarımın varsayılan notu
/// ("Kayıtsız numara") gösterilir — satır altı boş kalmasın.
AramaKaydi aramaKaydinaCevir(CallLog c, Customer? musteri, {DateTime? simdi}) {
  return AramaKaydi(
    id: c.id,
    numara: c.phoneE164,
    saat: cagriSaatMetni(DateTime.tryParse(c.occurredAt), simdi: simdi),
    tip: aramaTipiCoz(c.direction),
    musteriId: musteri?.id,
    ad: musteri?.name,
    sonuc: c.outcome ?? (musteri == null ? 'Kayıtsız numara' : null),
  );
}
