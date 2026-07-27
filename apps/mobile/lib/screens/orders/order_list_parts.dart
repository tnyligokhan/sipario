// Siparişler ekranının parçaları — liste gövdesi, elle sıralama bandı ve kurye süzgeci sheet'i.
// `order_list_screen.dart` 500 satır sınırını aştığı için buraya ayrıldı; ekran yalnız DURUM ve
// akış birleştirmesi yapar, çizim burada.

import 'package:drift/drift.dart' show OrderingTerm;
import 'package:flutter/material.dart';

import '../../data/app_database.dart';
import '../../theme/components/atoms.dart';
import '../../theme/components/overlays.dart';
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
// Liste — CSS `.sliste`
// ═══════════════════════════════════════════════════════════════════════════════════════════

/// Elle kipinde sürüklenebilir, normalde düz liste. İki kip AYNI satır bileşenini çizer (görsel
/// ayrışmasın); fark yalnız tutamaç ve sürükleme tanıyıcısıdır.
class SiparisListesi extends StatelessWidget {
  const SiparisListesi({
    super.key,
    required this.liste,
    required this.satirlar,
    required this.adresler,
    required this.telefonlar,
    required this.ekip,
    required this.elle,
    required this.tutamacSagda,
    required this.onAc,
    required this.onKuryeAc,
    required this.onBildir,
    required this.onSirala,
  });

  final List<OrderListItem> liste;
  final Map<String, List<OrderLine>> satirlar;
  final Map<String, AdresBilgi> adresler;
  final Map<String, String> telefonlar;
  final List<User> ekip;
  final bool elle;
  final bool tutamacSagda;
  final ValueChanged<OrderListItem> onAc;
  final ValueChanged<OrderListItem>? onKuryeAc;
  final ValueChanged<String> onBildir;
  final ValueChanged<List<OrderListItem>> onSirala;

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
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    if (!elle) {
      return ListView.builder(
        padding: _dolgu,
        itemCount: liste.length,
        itemBuilder: (context, i) => _satir(context, i),
      );
    }
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
