// Siparişler ekranının parçaları — liste gövdesi, elle sıralama bandı ve kurye süzgeci sheet'i.
// `order_list_screen.dart` 500 satır sınırını aştığı için buraya ayrıldı; ekran yalnız DURUM ve
// akış birleştirmesi yapar, çizim burada.

import 'package:drift/drift.dart' show OrderingTerm;
import 'package:flutter/material.dart';

import '../../data/app_database.dart';
import '../../sync/yenileme.dart';
import '../../theme/components/atoms.dart';
import '../../theme/components/overlays.dart';
import '../../theme/components/states.dart';
import '../../theme/icons.dart';
import '../../theme/tokens.dart';
import '../../theme/typography.dart';
import 'order_queries.dart';
import 'order_row.dart';
import 'order_sheets.dart' show SecimSatiri;
import '../team.dart';

/// Kurye süzgeci sheet'inin "hepsi" yanıtı. `null` VAZGEÇMEK demektir; ikisi ayrı olmalı,
/// yoksa sheet'i kapatan kullanıcının süzgeci sessizce sıfırlanırdı.
const String kTumKuryeler = '__tumu__';

/// Kurye süzgecinde listelenecek kişiler.
///
/// `watchAktifKuryeler` (team.dart) YALNIZ `role = 'kurye'` döner; kullanıcının açık notu ise
/// "patronun kendisi de aslında bir kurye olarak görünmeli" — tek/iki kişilik bayide teslimatı
/// patron yapar ve siparişler ona atanır. Bu yüzden süzgeç adayları aktif patron/operator/kurye
/// kullanıcılarının HEPSİDİR; ATAMA sorgusu (kurye seçme sheet'i) DEĞİŞMEDİ — orada hâlâ yalnız
/// kuryeler var, bu yalnız GÖRÜNTÜLEME süzgecidir.
Stream<List<User>> watchKuryeSuzgecAdaylari(AppDatabase db) => (db.select(db.users)
      ..where((t) => t.status.equals('active'))
      ..where((t) => t.role.isIn(const ['kurye', 'patron', 'operator']))
      ..orderBy([(t) => OrderingTerm.asc(t.name)]))
    .watch();

/// Kurye süzgeci kime görünür? Yalnız PATRONA (kurye zaten kendi işini görür, ona süzgeç
/// gürültüdür). Rol `sync_meta.user_role`dan gelir — giriş yanıtı yazar, senkron tazeler.
///
/// Operatöre de açmak istenirse tek satır: `rol == 'patron' || rol == 'operator'`. Bilerek
/// yapılmadı — talep "patron" diyor, kapı gereğinden geniş açılmıyor.
bool kuryeSuzgeciGorunur(String? rol) => rol == 'patron';

/// Seçili süzgecin başlıkta görünen adı. Seçim yoksa nötr "Kurye".
String kuryeSuzgecEtiketi(String? seciliId, List<User> adaylar) {
  if (seciliId == null) return 'Kurye';
  if (seciliId == kAtanmamisKurye) return 'Atanmamış';
  for (final u in adaylar) {
    if (u.id == seciliId) return u.name;
  }
  return 'Kurye'; // kullanıcı listeden düşmüş (pasifleşmiş) — etiket uydurulmaz
}

/// Sürükle-bırak tutamacının tarafı — `true` SAĞ (varsayılan), `false` SOL.
///
/// SAHA HATASI 4: tasarım tutamacı sola koyuyordu; telefonu sağ eliyle tutan bayinin başparmağı
/// ekranın soluna yetişmiyor. Varsayılan SAĞ, sol elini kullananlar için tercih [ElleBant]ta.
///
/// KALICIDIR: değeri `tutamac_deposu.dart` diske yazar ve açılışta (`main.dart`) buraya basar.
/// Değişken o okumanın RAM'deki aynasıdır — ekranlar senkron okumak zorunda (build sırasında
/// `await` edilemez), disk erişimi açılışta bir kez olur.
///
/// Bu dosya depoyu İMPORT ETMEZ (tersi geçerli): çizim katmanı `dart:io`ya bağlanmasın, widget
/// testleri platform kanalı olmadan koşabilsin.
bool tutamacSagdaTercihi = true;

// ═══════════════════════════════════════════════════════════════════════════════════════════
// Gövde — yedi akış tek listede birleşir
// ═══════════════════════════════════════════════════════════════════════════════════════════

/// Sipariş akışını YARDIMCI akışlarla (ekip · satırlar · tahsilatlar · kod tercihi · adresler ·
/// telefonlar) birleştirip [SiparisListesi]ye verir.
///
/// NEDEN STATEFUL: yardımcı akışlar `late final` alanlarda BİR KEZ kurulur. `build` içinde
/// kurulsalardı her `setState`te yeni birer Stream nesnesi doğar, StreamBuilder aboneliği
/// koparır ve liste bir kare iskelete inerdi (ekranda ödenen ders; sipariş akışının önbelleği
/// de aynı sebeple var). Widget yeniden kurulsa da State aynı kaldığı için alanlar korunur.
///
/// Sipariş akışı DIŞARIDAN gelir ([siparisler]): filtre/kurye/gün değişince onu yeniden kurmak
/// ekranın işidir — kapsamı bilen odur.
class SiparisListesiGovdesi extends StatefulWidget {
  const SiparisListesiGovdesi({
    super.key,
    required this.db,
    required this.siparisler,
    required this.sirala,
    required this.bos,
    required this.elle,
    required this.tutamacSagda,
    required this.onAc,
    required this.onKuryeAc,
    required this.onBildir,
    required this.onSirala,
    required this.onTekrar,
    this.onTeslim,
  });

  final AppDatabase db;

  /// Filtre/kurye/gün kapsamındaki sipariş akışı — ekran önbellekler.
  final Stream<List<OrderListItem>> siparisler;

  /// Ham listeyi seçili kipe göre sıralar (`siparisleriSirala` + elle sırası) — kip ve sürükleme
  /// sırası ekranın durumudur, bu yüzden karar dışarıda verilir.
  final List<OrderListItem> Function(List<OrderListItem> ham) sirala;

  /// Boş durum. Metni ekran kurar: süzgece ve sekmeye bağlıdır.
  final Widget bos;

  final bool elle;
  final bool tutamacSagda;
  final void Function(OrderListItem) onAc;
  final void Function(OrderListItem)? onKuryeAc;
  final void Function(String mesaj) onBildir;
  final Future<void> Function(List<OrderListItem>) onSirala;

  /// "Tekrar dene" — ekran akışı YENİDEN KURMALI (önbellekli akışa boş bir setState ile geri
  /// abone olmak aynı ölü akışa dönmek olurdu; düğme hiçbir şey yapmazdı).
  final VoidCallback onTekrar;

  /// Satırın "Teslim" düğmesi — akışı EKRAN yürütür (yetki okuma, sheet, toast oradadır).
  final void Function(OrderListItem)? onTeslim;

  @override
  State<SiparisListesiGovdesi> createState() => _SiparisListesiGovdesiState();
}

class _SiparisListesiGovdesiState extends State<SiparisListesiGovdesi> {
  late final Stream<List<User>> _ekip = watchTeam(widget.db);
  late final Stream<Map<String, List<OrderLine>>> _satirlar =
      watchOrderLinesByOrder(widget.db);
  late final Stream<Map<String, int>> _tahsilatlar = watchSiparisTahsilatlari(widget.db);
  late final Stream<String> _kodTercihi = watchSiparisKoduTercihi(widget.db);
  late final Stream<Map<String, AdresBilgi>> _adresler = watchBirincilAdresler(widget.db);
  late final Stream<Map<String, String>> _telefonlar = watchBirincilTelefonlar(widget.db);

  @override
  Widget build(BuildContext context) {
    return StreamBuilder<List<User>>(
      stream: _ekip,
      initialData: const [],
      builder: (context, ekipSnap) => StreamBuilder<Map<String, List<OrderLine>>>(
        stream: _satirlar,
        initialData: const {},
        builder: (context, satirSnap) => StreamBuilder<String>(
          stream: _kodTercihi,
          initialData: 'musteri',
          builder: (context, kodSnap) => StreamBuilder<Map<String, int>>(
            stream: _tahsilatlar,
            initialData: const {},
            builder: (context, tahsilatSnap) => StreamBuilder<Map<String, AdresBilgi>>(
              stream: _adresler,
              initialData: const {},
              builder: (context, adresSnap) => StreamBuilder<Map<String, String>>(
                stream: _telefonlar,
                initialData: const {},
                builder: (context, telSnap) => StreamBuilder<List<OrderListItem>>(
                  stream: widget.siparisler,
                  builder: (context, snap) {
                    if (snap.hasError) return SipHataEkran(onTekrar: widget.onTekrar);
                    final ham = snap.data;
                    if (ham == null) return const SipIskelet(adet: 4);
                    if (ham.isEmpty) return widget.bos;

                    return SiparisListesi(
                      liste: widget.sirala(ham),
                      satirlar: satirSnap.data ?? const {},
                      tahsilatlar: tahsilatSnap.data ?? const {},
                      kodTercihi: kodSnap.data ?? 'musteri',
                      adresler: adresSnap.data ?? const {},
                      telefonlar: telSnap.data ?? const {},
                      ekip: ekipSnap.data ?? const [],
                      elle: widget.elle,
                      tutamacSagda: widget.tutamacSagda,
                      onAc: widget.onAc,
                      onKuryeAc: widget.onKuryeAc,
                      onBildir: widget.onBildir,
                      onSirala: widget.onSirala,
                      onTeslim: widget.onTeslim,
                    );
                  },
                ),
              ),
            ),
          ),
        ),
      ),
    );
  }
}

// ═══════════════════════════════════════════════════════════════════════════════════════════
// Liste — CSS `.sliste`
// ═══════════════════════════════════════════════════════════════════════════════════════════

/// Elle kipinde sürüklenebilir, normalde düz liste. İki kip AYNI satır bileşenini çizer (görsel
/// ayrışmasın); fark yalnız tutamaç ve sürükleme tanıyıcısıdır.
class SiparisListesi extends StatelessWidget {
  const SiparisListesi({
    super.key,
    required this.liste,
    required this.satirlar,
    this.tahsilatlar = const {},
    this.kodTercihi = 'musteri',
    required this.adresler,
    required this.telefonlar,
    required this.ekip,
    required this.elle,
    required this.tutamacSagda,
    required this.onAc,
    required this.onKuryeAc,
    required this.onBildir,
    required this.onSirala,
    this.onTeslim,
  });

  final List<OrderListItem> liste;
  final Map<String, List<OrderLine>> satirlar;

  /// orderId → o siparişe işlenmiş tahsilat (pozitif kuruş). Eksik anahtar 0 sayılır —
  /// akış henüz gelmemişken satır "borç yok" gösterir, uydurma bir rakam GÖSTERMEZ.
  final Map<String, int> tahsilatlar;

  /// Satır rozetinde hangi kod görünsün (`musteri` | `siparis`) — bayi ayarı.
  final String kodTercihi;

  final Map<String, AdresBilgi> adresler;
  final Map<String, String> telefonlar;
  final List<User> ekip;
  final bool elle;
  final bool tutamacSagda;
  final ValueChanged<OrderListItem> onAc;
  final ValueChanged<OrderListItem>? onKuryeAc;
  final ValueChanged<String> onBildir;
  final ValueChanged<List<OrderListItem>> onSirala;

  /// Satırın "Teslim" düğmesi. `null` = salt-okunur kip (düğme hiç çizilmez).
  final ValueChanged<OrderListItem>? onTeslim;

  static const _dolgu = EdgeInsets.fromLTRB(SipSpace.govde, 0, SipSpace.govde, 96);

  Widget _satir(BuildContext context, int i, {Key? key}) {
    final item = liste[i];
    final musteriId = item.order.customerId;
    return Padding(
      key: key,
      padding: EdgeInsets.only(top: i == 0 ? 0 : SipSpace.md),
      child: SiparisSatiri(
        item: item,
        satirlar: satirlar[item.order.id] ?? const [],
        tahsilKurus: tahsilatlar[item.order.id] ?? 0,
        musteriCode: item.customerCode,
        kodTercihi: kodTercihi,
        kuryeAdi: kullaniciAdi(ekip, item.order.assignedUserId),
        adres: musteriId == null ? null : adresler[musteriId],
        telefon: musteriId == null ? null : telefonlar[musteriId],
        elle: elle,
        tutamacSagda: tutamacSagda,
        tutamac: elle
            ? (child) => ReorderableDragStartListener(index: i, child: child)
            : null,
        onAc: () => onAc(item),
        onKuryeAc: onKuryeAc == null ? null : () => onKuryeAc!(item),
        onBildir: onBildir,
        onTeslim: onTeslim == null ? null : () => onTeslim!(item),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    if (!elle) {
      return RefreshIndicator(
        onRefresh: yenile,
        child: ListView.builder(
          padding: _dolgu,
          physics: const AlwaysScrollableScrollPhysics(),
          itemCount: liste.length,
          itemBuilder: (context, i) => _satir(context, i),
        ),
      );
    }
    // ELLE SIRALAMA kipinde yenileme YOK: aşağı çekme ile sürükleme aynı jesttir ve ikisi
    // birlikte açıkken kullanıcı sırayı bozmadan listeyi kaydıramaz.
    return ReorderableListView.builder(
      padding: _dolgu,
      buildDefaultDragHandles: false, // tutamaç tasarımda `.srow-grip`, satırın tamamı değil
      itemCount: liste.length,
      itemBuilder: (context, i) =>
          _satir(context, i, key: ValueKey(liste[i].order.id)),
      onReorder: (eski, yeni) {
        final kopya = [...liste];
        final tasinan = kopya.removeAt(eski);
        kopya.insert(yeni > eski ? yeni - 1 : yeni, tasinan);
        onSirala(kopya);
      },
    );
  }
}

// ═══════════════════════════════════════════════════════════════════════════════════════════
// Elle sıralama bandı — CSS `.elle-bant`
// ═══════════════════════════════════════════════════════════════════════════════════════════

/// Sürükle-bırak açıkken görünen açıklama bandı + tutamaç tarafı anahtarı.
///
/// Anahtar BURADA durur çünkü tutamaç yalnız bu kipte görünür: ayarlar ekranında saklı bir
/// tercihi kullanıcı, tutamacı gördüğü anda arayamaz. Sol elini kullanan bayi tutamacı görür,
/// yanındaki düğmeyle karşı tarafa alır.
class ElleBant extends StatelessWidget {
  const ElleBant({super.key, required this.tutamacSagda, required this.onTarafDegis});

  final bool tutamacSagda;
  final ValueChanged<bool> onTarafDegis;

  @override
  Widget build(BuildContext context) {
    final t = context.sip;
    return Container(
      margin: const EdgeInsets.fromLTRB(SipSpace.govde, 0, SipSpace.govde, SipSpace.lg),
      padding: const EdgeInsets.symmetric(horizontal: 13, vertical: 9),
      decoration: BoxDecoration(color: t.accentSoft, borderRadius: SipRadius.br2),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Row(
            children: [
              SipIcon(SipIcons.info, boyut: 14, kalinlik: 2, renk: t.accent),
              const SizedBox(width: 7),
              Expanded(
                child: Text(
                  'Tutamaçtan sürükleyip bırak, bitince “Bitti”ye bas.',
                  style: SipText.metin(12, w: 600).copyWith(color: t.accent),
                ),
              ),
            ],
          ),
          const SizedBox(height: SipSpace.md),
          Align(
            alignment: tutamacSagda ? Alignment.centerRight : Alignment.centerLeft,
            child: _TarafDugmesi(
              sagda: tutamacSagda,
              onTap: () => onTarafDegis(!tutamacSagda),
            ),
          ),
        ],
      ),
    );
  }
}

/// "Tutamaç sağda ⇄" — dokunma hedefi 44 (DESIGN_SYSTEM alt sınırı).
class _TarafDugmesi extends StatelessWidget {
  const _TarafDugmesi({required this.sagda, required this.onTap});

  final bool sagda;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final t = context.sip;
    return Semantics(
      button: true,
      label: sagda ? 'Tutamacı sola al' : 'Tutamacı sağa al',
      child: SipDokun(
        onTap: onTap,
        zemin: t.surface,
        basiliZemin: t.surface2,
        radius: SipRadius.brHap,
        padding: const EdgeInsets.symmetric(horizontal: SipSpace.x2),
        child: SizedBox(
          height: 44,
          child: Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              SipIcon(sagda ? SipIcons.left : SipIcons.right,
                  boyut: 15, kalinlik: 2.2, renk: t.accent),
              const SizedBox(width: SipSpace.sm),
              Text(
                sagda ? 'Tutamaç sağda' : 'Tutamaç solda',
                style: SipText.metin(12, w: 700).copyWith(color: t.accent),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

// ═══════════════════════════════════════════════════════════════════════════════════════════
// Kurye süzgeci sheet'i — saha hatası 6
// ═══════════════════════════════════════════════════════════════════════════════════════════

/// "Kuryeye Göre" sheet'i. Dönen değer: [kTumKuryeler] · kullanıcı id'si · [kAtanmamisKurye];
/// `null` = vazgeçildi.
///
/// Patronun kendisi de listede durur (kullanıcı kararı) — tek kişilik bayide teslimatı o yapar
/// ve siparişler ona atanır; onu listeden çıkarmak kendi işini süzemez hâle getirirdi.
Future<String?> kuryeSuzgecSheet(
  BuildContext context, {
  required List<User> adaylar,
  required String? seciliId,
}) =>
    sipSheet<String>(
      context,
      baslik: 'Kuryeye Göre',
      govde: (ctx) => Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          SecimSatiri(
            etiket: 'Tüm kuryeler',
            ikon: SipIcons.users,
            secili: seciliId == null,
            onTap: () => Navigator.of(ctx).pop(kTumKuryeler),
          ),
          for (final k in adaylar)
            SecimSatiri(
              etiket: k.name,
              ikon: SipIcons.truck,
              secili: k.id == seciliId,
              onTap: () => Navigator.of(ctx).pop(k.id),
            ),
          SecimSatiri(
            etiket: 'Atanmamış',
            ikon: SipIcons.user,
            secili: seciliId == kAtanmamisKurye,
            onTap: () => Navigator.of(ctx).pop(kAtanmamisKurye),
          ),
        ],
      ),
    );
