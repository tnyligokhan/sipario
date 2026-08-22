// İPTAL ONAY AKIŞI — kuryenin iptal TALEBİ, patronun onay/ret kararı.
//
// ══ NEDEN VAR (kullanıcı isteği 2026-08-22) ═══════════════════════════════════════════════
// "Kurye siparişi iptal ettiğinde, patrona Onayla veya Reddet şeklinde bildirim gitmeli."
//
// Bugüne kadar iptal YALNIZ yöneticinin yetkisiydi (`yetkiler().siparisIptal` = ofis) ve
// kuryenin elinde hiçbir yol yoktu: müşteri kapıda "vazgeçtim" dediğinde kurye patronu arayıp
// anlatmak zorundaydı. Ters uç da kabul edilemezdi — kuryeye doğrudan iptal vermek, teslim
// edilmemiş bir işi kimseye sormadan defterden silmek demekti.
//
// ÇÖZÜM: kurye TALEP açar, sipariş AÇIK KALIR, karar patronundur.
//
// ══ NEDEN AYRI DOSYA ══════════════════════════════════════════════════════════════════════
// `order_detail_screen.dart` 376 satırdı ve bu akış hem bant hem düğme hem üç ayrı onay
// sheet'i getiriyordu (depo sınırı 500). Ayrım da konuya göre doğal: burada YALNIZ iptal
// kararının yüzeyi var, detay ekranı iki widget çağırıyor.

import 'package:flutter/material.dart';

import '../../data/app_database.dart';
import '../../repo/order_repository.dart';
import '../../theme/components/atoms.dart';
import '../../theme/components/overlays.dart';
import '../../theme/icons.dart';
import '../../theme/tokens.dart';
import '../../theme/typography.dart';
import '../team.dart';
import 'order_detail_eylemler.dart' show YumusakTehlikeButonu;
import 'order_queries.dart';

/// Kurye iptal isterken sorulan onay sheet'inin başlığı — testler bunu okur.
const String iptalTalebiBasligi = 'İptal talebi gönderilsin mi?';

/// Yöneticinin doğrudan iptalinde sorulan onay başlığı (mevcut davranış korunur).
const String iptalOnayBasligi = 'Sipariş iptal edilsin mi?';

/// SİPARİŞ DETAYININ İPTAL DÜĞMESİ — etiketi YETKİYE göre değişir.
///
/// Yönetici "İptal Et" görür ve dokunduğunda sipariş iptal olur. İptal yetkisi olmayan
/// (kurye) "İptal İste" görür ve dokunduğunda patronun onayına düşen bir TALEP açılır.
///
/// ⚠️ ETİKET DE KAPININ PARÇASIDIR: eskiden kurye de "İptal Et" görüyor, dokunuyor ve
/// "Sipariş iptal etme yetkiniz yok" reddini okuyordu. Yapamayacağı bir işi vaat eden bir
/// düğme, kullanıcının ekrana olan güvenini reddin kendisinden çok bozar.
class IptalButonu extends StatefulWidget {
  const IptalButonu({super.key, required this.db, required this.orderId, this.onBitti});

  final AppDatabase db;
  final String orderId;

  /// İşlem yazıldıktan sonra (detay sheet'ini kapatmak için).
  final VoidCallback? onBitti;

  @override
  State<IptalButonu> createState() => _IptalButonuState();
}

class _IptalButonuState extends State<IptalButonu> {
  /// null = yetki henüz okunmadı. O aralıkta düğme YİNE ÇİZİLİR ama TALEP kipinde davranır:
  /// bilinmeyen yetkide güvenli taraf, doğrudan iptal değil talep açmaktır.
  RolYetkileri? _yetki;

  @override
  void initState() {
    super.initState();
    _yetkiOku();
  }

  Future<void> _yetkiOku() async {
    final y = await oturumYetkileri(widget.db);
    if (!mounted) return;
    setState(() => _yetki = y);
  }

  bool get _iptalEdebilir => _yetki?.siparisIptal ?? false;

  @override
  Widget build(BuildContext context) => YumusakTehlikeButonu(
        etiket: _iptalEdebilir ? 'İptal Et' : 'İptal İste',
        onTap: () => _iptalEdebilir ? _iptalEt() : _iptalIste(),
      );

  Future<void> _iptalEt() async {
    final onay = await sipOnay(
      context,
      baslik: iptalOnayBasligi,
      mesaj: 'Kayıt silinmez, iptal olarak işaretlenir',
      onayEtiketi: 'İptal Et',
      tehlike: true,
    );
    if (!onay || !mounted) return;
    await OrderRepository(widget.db).cancel(widget.orderId);
    if (!mounted) return;
    SipToast.goster(context, 'Sipariş iptal edildi');
    widget.onBitti?.call();
  }

  Future<void> _iptalIste() async {
    final gerekce = await iptalGerekcesiSor(context);
    // null = vazgeçildi. BOŞ DİZGİ VAZGEÇME DEĞİLDİR: gerekçe yazmadan talep açmak meşrudur
    // (kurye direksiyonda, yazacak hâli olmayabilir) — patron zaten arayıp sorabilir.
    if (gerekce == null || !mounted) return;

    await OrderRepository(widget.db).iptalTalepEt(widget.orderId, gerekce: gerekce);
    if (!mounted) return;
    SipToast.goster(context, 'İptal talebi gönderildi');
    widget.onBitti?.call();
  }
}

/// İptal gerekçesini soran sheet. `null` = vazgeçildi, `''` = gerekçesiz talep.
Future<String?> iptalGerekcesiSor(BuildContext context) {
  final denetleyici = TextEditingController();
  return sipSheet<String>(
    context,
    baslik: iptalTalebiBasligi,
    govde: (ctx) => Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      mainAxisSize: MainAxisSize.min,
      children: [
        Text(
          'Sipariş şimdi iptal olmaz, onaya gönderilir',
          style: SipText.metin(13).copyWith(color: ctx.sip.muted),
        ),
        const SizedBox(height: SipSpace.x2),
        SipInput(
          controller: denetleyici,
          ipucu: 'Sebep, isterseniz',
          satirlar: 2,
        ),
        const SizedBox(height: SipSpace.x2),
        SipButon(
          etiket: 'Talebi Gönder',
          ikon: SipIcons.check,
          onTap: () => Navigator.of(ctx).pop(denetleyici.text.trim()),
        ),
      ],
    ),
  ).whenComplete(denetleyici.dispose);
}

/// BEKLEYEN İPTAL TALEBİ BANDI — sipariş detayının en üstünde.
///
/// İKİ AYRI YÜZ, TEK BİLEŞEN:
///  • İPTAL YETKİSİ OLAN (patron/tezgâh) → "Onayla" ve "Reddet" düğmeleri.
///  • YETKİSİ OLMAYAN (talebi açan kurye) → yalnız "onay bekliyor" bilgisi.
/// İkincisi olmadan kurye talebinin gidip gitmediğini bilemez ve aynı talebi tekrar açardı.
///
/// TALEP YOKSA HİÇBİR ŞEY ÇİZİLMEZ ([SizedBox.shrink]) — boş bir kutu, ekranı sebepsiz uzatır.
class IptalTalebiBandi extends StatelessWidget {
  const IptalTalebiBandi({
    super.key,
    required this.db,
    required this.order,
    this.writable = true,
  });

  final AppDatabase db;
  final Order order;

  /// Abonelik kilidi. Kilitliyken karar düğmeleri çizilmez ama BANT DURUR: patron bekleyen
  /// talebi görmeye devam etmeli, yoksa abonelik yenilendiğinde ondan haberi olmaz.
  final bool writable;

  @override
  Widget build(BuildContext context) {
    // Kapalı siparişte bekleyen talep zaten olamaz (`iptalTalebiCoz` teslim/iptali son olay
    // sayar), ama sorguyu hiç kurmamak daha ucuz.
    if (order.status != 'open') return const SizedBox.shrink();

    return StreamBuilder<IptalTalebi?>(
      stream: watchIptalTalebi(db, order.id),
      builder: (context, snap) {
        final talep = snap.data;
        if (talep == null) return const SizedBox.shrink();
        return _Bant(db: db, order: order, talep: talep, writable: writable);
      },
    );
  }
}

class _Bant extends StatefulWidget {
  const _Bant({
    required this.db,
    required this.order,
    required this.talep,
    required this.writable,
  });

  final AppDatabase db;
  final Order order;
  final IptalTalebi talep;
  final bool writable;

  @override
  State<_Bant> createState() => _BantState();
}

class _BantState extends State<_Bant> {
  /// ⚠️ YETKİ GELECEĞİ `build` İÇİNDE KURULMAZ, `initState`te BİR KEZ kurulur.
  ///
  /// Bant iki akışa (talep · ekip) abone ve her tikte yeniden çiziliyor. `FutureBuilder`ın
  /// geleceğini build'de üretmek, her tikte geleceği SIFIRLAR: "Onayla"/"Reddet" düğmeleri bir
  /// kare kaybolur, sonra geri gelir. Karar düğmesinin gözünün önünde titremesi, patronun
  /// yanlış düğmeye basmasına giden en kısa yoldur.
  late final Future<RolYetkileri> _yetki = oturumYetkileri(widget.db);

  @override
  Widget build(BuildContext context) {
    final t = context.sip;
    final talep = widget.talep;
    final writable = widget.writable;
    final db = widget.db;

    return StreamBuilder<List<User>>(
      stream: watchTeam(db),
      initialData: const [],
      builder: (context, ekipSnap) {
        // AD ÇÖZÜLEMEZSE HİÇ YAZILMAZ, ham kimlik BASILMAZ: çağrı atfındaki kuralın aynısı.
        final ad = kullaniciAdi(ekipSnap.data ?? const [], talep.isteyenUserId);
        final baslik = ad == null ? 'İptal talebi var' : '$ad iptal istedi';

        return FutureBuilder<RolYetkileri>(
          future: _yetki,
          builder: (context, yetkiSnap) {
            // Yetki gelene kadar KARAR DÜĞMESİ ÇİZİLMEZ (güvenli taraf): bir kare boyunca
            // görünen "Onayla" düğmesi, kuryenin kendi talebini onaylayabilmesi demekti.
            final karar = (yetkiSnap.data?.siparisIptal ?? false) && writable;

            // "Onay bekliyor" da yetki BİLİNENE KADAR yazılmaz: yoksa patron bir kare boyunca
            // kendi bekleyeceğini okur, sonra düğmeler belirir. Yanlış bir cümleyi kısa süre
            // göstermek, hiç göstermemekten kötüdür.
            final bekliyorYazilir = yetkiSnap.hasData && !karar;

            return Padding(
              padding: const EdgeInsets.only(top: SipSpace.xl),
              child: Container(
                padding: const EdgeInsets.all(SipSpace.x2),
                decoration: BoxDecoration(color: t.warnSoft, borderRadius: SipRadius.br2),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.stretch,
                  children: [
                    Row(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Padding(
                          padding: const EdgeInsets.only(top: 1),
                          child: SipIcon(SipIcons.alert, boyut: 16, kalinlik: 2, renk: t.warn),
                        ),
                        const SizedBox(width: 9),
                        Expanded(
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Text(baslik,
                                  style: SipText.metin(13, w: 800).copyWith(color: t.warn)),
                              if (talep.gerekce != null) ...[
                                const SizedBox(height: 3),
                                Text(talep.gerekce!,
                                    style: SipText.metin(12.5).copyWith(color: t.warn)),
                              ],
                              if (bekliyorYazilir) ...[
                                const SizedBox(height: 3),
                                Text('Onay bekliyor',
                                    style: SipText.metin(12).copyWith(color: t.warn)),
                              ],
                            ],
                          ),
                        ),
                      ],
                    ),
                    if (karar) ...[
                      const SizedBox(height: SipSpace.xl),
                      Row(
                        children: [
                          Expanded(
                            child: YumusakTehlikeButonu(
                              etiket: 'Reddet',
                              onTap: () => _reddet(context),
                            ),
                          ),
                          const SizedBox(width: SipSpace.md),
                          Expanded(
                            child: SipButon(
                              etiket: 'Onayla',
                              yukseklik: 44,
                              onTap: () => _onayla(context),
                            ),
                          ),
                        ],
                      ),
                    ],
                  ],
                ),
              ),
            );
          },
        );
      },
    );
  }

  /// ONAY = İPTALİN KENDİSİ. Ayrı bir "cancel_approved" olayı AÇILMADI: iptalin tek doğru
  /// kaydı `cancelled`tır ve ikinci bir olay, siparişin durumunu türeten iki ayrı kural
  /// demekti. Onayın izi zaten geçmişte durur (talep → iptal, sırayla).
  Future<void> _onayla(BuildContext context) async {
    final onay = await sipOnay(
      context,
      baslik: 'İptal onaylansın mı?',
      mesaj: 'Sipariş iptal olarak işaretlenir, kayıt silinmez',
      onayEtiketi: 'Onayla',
      tehlike: true,
    );
    if (!onay || !context.mounted) return;
    await OrderRepository(widget.db).cancel(widget.order.id);
    if (!context.mounted) return;
    SipToast.goster(context, 'İptal onaylandı');
  }

  Future<void> _reddet(BuildContext context) async {
    await OrderRepository(widget.db).iptalTalebiniReddet(widget.order.id);
    if (!context.mounted) return;
    SipToast.goster(context, 'İptal talebi reddedildi');
  }
}
