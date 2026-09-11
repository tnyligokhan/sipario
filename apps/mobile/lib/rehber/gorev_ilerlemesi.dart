// KATMAN A'NIN VERİSİ — görev kartının maddeleri hangi durumda.
//
// ⚠️ KULLANICI HİÇBİR MADDEYİ ELLE İŞARETLEMEZ. Bunun sebebi kolaycılık değil: elle
// işaretlenen liste, işi yapmadan da "bitti" gösterilebilir ve o an bir öğretme aracı
// olmaktan çıkıp bir süs olur. Her madde VERİDEN türer — ürün var mı, müşteri var mı,
// sipariş girilmiş mi. Bu aynı zamanda listenin bayinin gerçek durumuyla hep uyumlu
// kalmasını sağlar: bayi ürünlerini tek tek silerse madde geri açılır ve bu doğrudur.
//
// SALT-OKUNUR read-model: hiçbir tabloya yazmaz (`shell/ana_ozet.dart` deseninin ikizi).
// `lib/repo/` başka ajanın alanı olduğu için sorgular burada yaşar.

import 'package:drift/drift.dart';

import '../data/app_database.dart';
import 'rehber_modeli.dart';

/// Görev kartının anlık durumu.
class GorevDurumu {
  const GorevDurumu({this.bitenler = const <RehberGorev>{}, this.kitle = const []});

  /// Tamamlanmış maddeler.
  final Set<RehberGorev> bitenler;

  /// Bu role gösterilen maddelerin tamamı, çizim sırasıyla.
  final List<RehberGorev> kitle;

  bool bittiMi(RehberGorev g) => bitenler.contains(g);

  /// Kaç madde bitti (isteğe bağlılar dahil — bayi kuryesini eklediyse sayacın artması
  /// doğrudur, "isteğe bağlı" olmak "sayılmaz" demek değildir).
  int get sayac => kitle.where(bitenler.contains).length;

  int get toplam => kitle.length;

  /// Kart artık gizlenebilir mi. İSTEĞE BAĞLI MADDELER BEKLENMEZ: BRIEF'in "tek kişilik bayi
  /// çoktur" gerçeği yüzünden kurye satırı hiç bitmeyebilir ve kart sonsuza kadar ekranda
  /// kalırdı — bu, listeyi bir yol göstericiden bir sitem'e çevirirdi.
  bool get tamamlandi =>
      kitle.isNotEmpty &&
      kitle.where((g) => !g.istegeBagli).every(bitenler.contains);
}

/// Görev kartının canlı akışı.
///
/// [kuryeMi] hangi madde kümesinin sorulacağını belirler; kuryenin maddeleri KENDİ işine
/// bakar, o yüzden [kullaniciId] gerekir. Kimlik henüz çözülmediyse (kabukta asenkron iner)
/// hiçbir madde bitmiş sayılmaz — yanlışlıkla "bitti" göstermektense boş göstermek doğrudur.
Stream<GorevDurumu> watchGorevDurumu(
  AppDatabase db, {
  required bool kuryeMi,
  String? kullaniciId,
}) =>
    kuryeMi ? _kurye(db, kullaniciId ?? '') : _yonetici(db);

Stream<GorevDurumu> _yonetici(AppDatabase db) {
  final kitle = RehberGorev.kitleIcin(kuryeMi: false);
  return db
      .customSelect(
        '''
        SELECT
          (SELECT COUNT(*) FROM sync_meta
             WHERE id = 1 AND setup_completed_at IS NOT NULL)      AS arayan,
          (SELECT COUNT(*) FROM products  WHERE deleted_at IS NULL) AS urun,
          (SELECT COUNT(*) FROM customers WHERE deleted_at IS NULL) AS musteri,
          (SELECT COUNT(*) FROM orders    WHERE deleted_at IS NULL) AS siparis,
          (SELECT COUNT(*) FROM users
             WHERE role = 'kurye' AND status = 'active')           AS kurye
        ''',
        readsFrom: {db.syncMeta, db.products, db.customers, db.orders, db.users},
      )
      .watchSingle()
      .map((r) => GorevDurumu(
            kitle: kitle,
            bitenler: {
              // ARAYAN TANIMA = KURULUM SİHİRBAZININ DAMGASI (`sync_meta.setup_completed_at`).
              // Sihirbaz ATLANDIĞINDA da yazılır — yani bu madde "izinleri verdin" demez,
              // "kurulumdan geçtin" der. Daha katı bir ölçüt (izinlerin gerçekten verili
              // olması) platform kanalına uzanırdı; bir görev listesinin bunun için her
              // karede telefona soru sorması doğru olmaz.
              if (r.read<int>('arayan') > 0) RehberGorev.arayanTanima,
              if (r.read<int>('urun') > 0) RehberGorev.urun,
              if (r.read<int>('musteri') > 0) RehberGorev.musteri,
              if (r.read<int>('siparis') > 0) RehberGorev.siparis,
              if (r.read<int>('kurye') > 0) RehberGorev.kurye,
            },
          ));
}

Stream<GorevDurumu> _kurye(AppDatabase db, String kullaniciId) {
  final kitle = RehberGorev.kitleIcin(kuryeMi: true);
  return db
      .customSelect(
        '''
        SELECT
          (SELECT COUNT(*) FROM orders
             WHERE deleted_at IS NULL AND status = 'delivered'
               AND delivered_by_user_id = ?)                       AS teslimat,
          (SELECT COUNT(*) FROM ledger_entries
             WHERE payment_type IS NOT NULL
               AND collected_by_user_id = ?)                       AS tahsilat,
          (SELECT COUNT(*) FROM cash_handovers
             WHERE from_user_id = ?)                               AS devir
        ''',
        variables: [
          Variable<String>(kullaniciId),
          Variable<String>(kullaniciId),
          Variable<String>(kullaniciId),
        ],
        readsFrom: {db.orders, db.ledgerEntries, db.cashHandovers},
      )
      .watchSingle()
      .map((r) => GorevDurumu(
            kitle: kitle,
            bitenler: {
              if (r.read<int>('teslimat') > 0) RehberGorev.teslimat,
              if (r.read<int>('tahsilat') > 0) RehberGorev.tahsilat,
              // İPTAL EDİLMİŞ DEVİR DE SAYILIR: ters kayıt da bir devirdir ve kurye o akışı
              // bir kez yaşamıştır. Görev listesi bir muhasebe toplamı değil, bir öğrenme
              // izidir — burada `reverses_handover_id IS NULL` süzmek yanlış olurdu.
              if (r.read<int>('devir') > 0) RehberGorev.kasaDevri,
            },
          ));
}
