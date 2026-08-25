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
    //
    // ATIF DA BU SATIRDA (kullanıcı isteği 2026-08-13): çağrıyı kim karşıladı. AYRI BİR SATIR
    // AÇILMADI — liste 50 kayda kadar uzuyor ve her kayda üçüncü bir satır eklemek listeyi iki
    // katına çıkarıp taramayı bitirirdi; aynı ritim `AraTahsilatKarti`ta da böyle çözüldü.
    //
    // ⚠️ ATIF UYDURULMAZ: alan eklenmeden önceki kayıtlarda `user_id` NULL'dır ve `device_id`den
    // kişiye geriye dönük eşleme yapmak "o gün o cihazı kim kullandı" varsayımıdır. Kimliği olup
    // adı çözülemeyen satırda da ham UUID basılmaz. İkisinde de hiçbir şey yazılmaz: yanlış bir
    // isim, bir kuryeyi yapmadığı aramadan sorumlu tutar.
    final numara = sipTelefon(arama.numara);
    final sonuc = arama.sonuc;
    final kim = arama.kullaniciAdi;
    final alt = [
      if (kayitli) numara,
      if (sonuc != null && sonuc.isNotEmpty) sonuc,
      if (kim != null && kim.trim().isNotEmpty) kim.trim(),
    ].join(', ');

    return SipDokun(
      onTap: onAc == null ? null : () => onAc!(arama),
      zemin: t.surface,
      radius: SipRadius.br2,
      padding: const EdgeInsets.symmetric(horizontal: SipSpace.x2, vertical: SipSpace.xl),
      child: Row(
        children: [
          // CSS `.akt-ic` — 30'luk tam yuvarlak.
          //
          // ÜÇ YÖN, ÜÇ GERÇEKTEN FARKLI İKON (2026-08-13 saha bulgusu). Önceki hâlde gelen
          // `phone`, giden `phoneCall` çiziliyordu ve ikisi AYNI ahize yolunu paylaşıyor —
          // `phoneCall`ın tek farkı sağ üstteki iki minik sinyal yayı ve 15 punto'da o yaylar
          // görünmüyor. Kullanıcı bunu sahada bildirdi: "giden gelen çağrı ikonları belli
          // değil". Artık ahizenin yanında YÖN OKU var.
          //
          // RENK DE AYIRIYOR ama tek başına taşımıyor: giden çağrı accent, gelen nötr, cevapsız
          // danger. Rengi tek ayırt edici yapmak, renk körlüğünde ve güneş altında (bu ürünün
          // kullanıldığı yer) yönü okunamaz kılardı — ok her koşulda okunur.
          SipIkonKutu(
            ikon: switch (arama.tip) {
              AramaTipi.giden => SipIcons.phoneOut,
              AramaTipi.cevapsiz => SipIcons.phoneOff,
              AramaTipi.gelen => SipIcons.phoneIn,
            },
            cap: 30,
            ikonBoyut: 15,
            kalinlik: 2.4,
            zemin: switch (arama.tip) {
              AramaTipi.cevapsiz => t.dangerSoft,
              AramaTipi.giden => t.accentSoft,
              AramaTipi.gelen => t.surface2,
            },
            renk: switch (arama.tip) {
              AramaTipi.cevapsiz => t.danger,
              AramaTipi.giden => t.accent,
              AramaTipi.gelen => t.ink2,
            },
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
                          ', ',
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
    this.kisiler = const [],
    this.seciliKullaniciId,
    this.onKullaniciSec,
  });

  final List<AramaKaydi> aramalar;
  final bool yukleniyor;
  final VoidCallback? onGeri;
  final ValueChanged<AramaKaydi>? onAc;

  /// Süzgeçte listelenecek kullanıcılar. BOŞSA ya da TEK kişilikse şerit HİÇ çizilmez —
  /// süzülecek bir şey olmayan bir kontrol, dokunulunca hiçbir şey değiştirmeyen ölü bir
  /// kontroldür ve tek kişilik bayide "başkasının çağrıları" diye bir kavram yoktur.
  final List<User> kisiler;

  /// null = herkes.
  final String? seciliKullaniciId;
  final ValueChanged<String?>? onKullaniciSec;

  bool get _suzgecVar => onKullaniciSec != null && kisiler.length > 1;

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
            if (_suzgecVar)
              Padding(
                padding: const EdgeInsets.fromLTRB(
                    SipSpace.govde, 0, SipSpace.govde, SipSpace.lg),
                child: _KullaniciSuzgeci(
                  kisiler: kisiler,
                  secili: seciliKullaniciId,
                  onSec: onKullaniciSec!,
                ),
              ),
            Expanded(child: _govde(context)),
          ],
        ),
      ),
    );
  }

  Widget _govde(BuildContext context) {
    if (yukleniyor) return const SipIskelet();
    if (aramalar.isEmpty) {
      // BOŞ DURUM SÜZGECİ BİLİR: süzülmüş listede "henüz arama yok" demek, bayiye dükkânda hiç
      // çağrı olmadığını söylerdi — oysa yalnız SEÇİLEN KİŞİNİN çağrısı yok. Bu ayrım, süzgecin
      // cevapladığı asıl sorudur ("Emre bugün hiç aramamış mı?").
      if (seciliKullaniciId != null) {
        return const SipBosDurum(
          baslik: 'Bu kullanıcının çağrısı yok',
          aciklama: 'Herkesi görmek için "Tümü"yü seçin',
          ikon: SipIcons.phone,
        );
      }
      return const SipBosDurum(
        baslik: 'Henüz arama yok',
        aciklama: 'Gelen ve giden aramalar burada listelenir',
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
  /// null = herkes. Seçiliyken yalnız o kullanıcının çağrıları listelenir.
  String? _kullaniciId;

  late Stream<List<AramaKaydi>> _akis = _akisKur();

  Stream<List<AramaKaydi>> _akisKur() =>
      aramaKayitlariAkisi(widget.db, limit: widget.limit, kullaniciId: _kullaniciId);

  void _kullaniciSec(String? id) {
    setState(() {
      _kullaniciId = id;
      _akis = _akisKur();
    });
  }

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
    // KİMLER LİSTELENİR: `users` aynasındaki HERKES değil, ÇAĞRISI OLANLAR da değil — aynadaki
    // aktif kullanıcılar. Gerekçe: süzgeç bir keşif aracıdır ("Emre bugün kimi aramış"), ve
    // yalnız çağrısı olanları göstermek "Emre hiç aramamış" sorusunu sorulamaz hâle getirirdi
    // (adı listede olmayan kişi seçilemez).
    return StreamBuilder<List<User>>(
      stream: watchAktifKullanicilar(widget.db),
      builder: (context, kisiSnap) {
        final kisiler = kisiSnap.data ?? const <User>[];
        return StreamBuilder<List<AramaKaydi>>(
          stream: _akis,
          builder: (context, anlik) => CagriGunluguEkrani(
            aramalar: anlik.data ?? const [],
            yukleniyor: anlik.connectionState == ConnectionState.waiting,
            onGeri: widget.onGeri,
            onAc: widget.onAc,
            kisiler: kisiler,
            seciliKullaniciId: _kullaniciId,
            onKullaniciSec: _kullaniciSec,
          ),
        );
      },
    );
  }
}

/// Süzgeçte listelenecek kullanıcılar — aynadaki AKTİF kayıtlar, ada göre.
///
/// `users` sunucu kaynaklı bir önbellektir; pasife alınmış kişi süzgeçte durmaz ama onun ESKİ
/// çağrıları listede kalmaya devam eder (kayıt silinmez). Bu bilinçli: geçmiş, kadro
/// değiştiğinde yeniden yazılmaz.
Stream<List<User>> watchAktifKullanicilar(AppDatabase db) => (db.select(db.users)
      ..where((u) => u.status.equals('active'))
      ..orderBy([(u) => OrderingTerm.asc(u.name)]))
    .watch();

/// `call_logs` + `customers` sol birleşimi → ekranın modeli. Yeni çağrı üstte.
///
/// Müşteri adı JOIN'den gelir: çağrı kaydı yalnız `customer_id` tutar, ad zamanla değişebilir
/// ve listede GÜNCEL ad görünmelidir (defterle aynı kişi olduğu anlaşılsın).
/// [kullaniciId] verilirse YALNIZ o kullanıcının çağrıları; verilmezse bayinin tamamı.
///
/// SÜZGEÇ SORGUDA, EKRANDA DEĞİL (kullanıcı isteği 2026-08-13): patron "şu kuryenin aramaları"
/// diye bakabilmeli. Listeyi çekip Dart tarafında elemek, `limit` ile birleştiğinde sessizce
/// yanlış olurdu — son 50 kaydın içinde o kullanıcıdan 3 tane varsa ekran 3 satır gösterir ve
/// bayi "kuryem hiç aramamış" sanırdı.
Stream<List<AramaKaydi>> aramaKayitlariAkisi(
  AppDatabase db, {
  int limit = 50,
  String? kullaniciId,
}) {
  final sorgu = db.select(db.callLogs).join([
    leftOuterJoin(db.customers, db.customers.id.equalsExp(db.callLogs.customerId)),
    // Çağrıyı karşılayan kullanıcının ADI buradan gelir. JOIN, tıpkı müşteri adında olduğu
    // gibi: kayıt yalnız kimliği tutar, ad `users` aynasında değişebilir ve listede GÜNCEL ad
    // görünmelidir.
    leftOuterJoin(db.users, db.users.id.equalsExp(db.callLogs.userId)),
  ])
    ..where(db.callLogs.deletedAt.isNull())
    ..orderBy([OrderingTerm.desc(db.callLogs.occurredAt)])
    ..limit(limit);

  if (kullaniciId != null) {
    sorgu.where(db.callLogs.userId.equals(kullaniciId));
  }

  return sorgu.watch().map((satirlar) {
    final simdi = DateTime.now();
    return [
      for (final s in satirlar)
        aramaKaydinaCevir(
          s.readTable(db.callLogs),
          s.readTableOrNull(db.customers),
          kullanici: s.readTableOrNull(db.users),
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
AramaKaydi aramaKaydinaCevir(
  CallLog c,
  Customer? musteri, {
  User? kullanici,
  DateTime? simdi,
}) {
  return AramaKaydi(
    id: c.id,
    numara: c.phoneE164,
    saat: cagriSaatMetni(DateTime.tryParse(c.occurredAt), simdi: simdi),
    tip: aramaTipiCoz(c.direction),
    musteriId: musteri?.id,
    ad: musteri?.name,
    sonuc: c.outcome ?? (musteri == null ? 'Kayıtsız numara' : null),
    kullaniciId: c.userId,
    // Ad AYNADAN çözülür; kullanıcı silinmişse ya da ayna henüz inmemişse null kalır ve ekran
    // ham UUID basmaz. Kimliği olup adı olmayan bir satır "bilinmiyor" der — yanlış bir isim
    // yazmaktansa boş bırakmak dürüsttür.
    kullaniciAdi: kullanici?.name,
  );
}

/// Kullanıcıya göre süzme şeridi — "Tümü" + aktif kullanıcılar, yatay kaydırmalı.
///
/// NEDEN SEGMENT DEĞİL: `SipSegment` sabit genişlikte eşit dilimler çizer ve üç kişiden sonra
/// adlar kırpılmaya başlar; bir bayide beş kurye olabilir. Yatay hap şeridi, ad uzunluğu ne
/// olursa olsun okunur kalır ve kaydırma doğal.
class _KullaniciSuzgeci extends StatelessWidget {
  const _KullaniciSuzgeci({
    required this.kisiler,
    required this.secili,
    required this.onSec,
  });

  final List<User> kisiler;
  final String? secili;
  final ValueChanged<String?> onSec;

  @override
  Widget build(BuildContext context) {
    // "Tümü" HER ZAMAN İLK: süzgeçten çıkış yolu, girişten daha kolay bulunabilir olmalı —
    // seçili kişide kalıp geri dönemeyen kullanıcı listenin boş olduğunu sanır.
    final secenekler = <({String? id, String etiket})>[
      (id: null, etiket: 'Tümü'),
      for (final k in kisiler) (id: k.id, etiket: k.name),
    ];

    return SizedBox(
      height: 34,
      child: ListView.separated(
        scrollDirection: Axis.horizontal,
        itemCount: secenekler.length,
        separatorBuilder: (_, _) => const SizedBox(width: 6),
        itemBuilder: (context, i) {
          final t = context.sip;
          final s = secenekler[i];
          final secildi = s.id == secili;
          return SipDokun(
            onTap: () => onSec(s.id),
            zemin: secildi ? t.accent : t.surface,
            basiliZemin: secildi ? t.accent : t.surface2,
            radius: SipRadius.brHap,
            padding: const EdgeInsets.symmetric(horizontal: 14),
            child: Center(
              child: Text(
                s.etiket,
                style: SipText.metin(12.5, w: 700)
                    .copyWith(color: secildi ? t.accentInk : t.ink2),
              ),
            ),
          );
        },
      ),
    );
  }
}
