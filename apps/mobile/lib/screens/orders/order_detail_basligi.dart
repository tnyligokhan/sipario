// Sipariş detayının ÜST ŞERİDİ — CSS `.sdx-head`: kod rozetleri · durum/süre pili · kurye çipi ·
// saat. Kaynak: s-siparisler.jsx `SiparisDetay`.
//
// NEDEN AYRI DOSYA: `order_detail_screen.dart` 558 satıra çıkmıştı (500 satır kuralı) ve dosyanın
// içinde iki ayrı iş vardı — biri siparişin GÖVDESİNİ (kalemler, not, adres, teslim/iptal) kurar,
// diğeri künyesini çizip kurye atamasını yürütür. Şerit gövdeden hiçbir şey okumaz: girdisi
// `Order` kaydı ve iki yetki bayrağı; bu yüzden sınır tam buradaydı. Eylem düğmelerinin
// `order_detail_eylemler.dart`a alınmasının aynı gerekçesi.

import 'package:flutter/material.dart';

import '../../data/app_database.dart';
import '../../repo/order_repository.dart';
import '../../theme/components/atoms.dart';
import '../../theme/components/overlays.dart';
import '../../theme/icons.dart';
import '../../theme/tokens.dart';
import '../../theme/typography.dart';
import '../team.dart';
import 'gecen_sure_pili.dart';
import 'order_queries.dart';
import 'order_sheets.dart';

/// CSS `.sdx-head` — kod rozeti · durum pili · kurye · saat.
class SiparisDetayBasligi extends StatelessWidget {
  const SiparisDetayBasligi({
    super.key,
    required this.db,
    required this.order,
    required this.canAssign,
    required this.duzenlenebilir,
  });

  final AppDatabase db;
  final Order order;
  final bool canAssign;
  final bool duzenlenebilir;

  @override
  Widget build(BuildContext context) {
    final t = context.sip;
    // DETAYDA İKİ KOD DA GÖRÜNÜR — ayar yalnız LİSTEDEKİ dar alanı paylaştırır. Burada yer var
    // ve bayi tam olarak "hangi sipariş, kimin" sorusunu sormak için bu ekrana giriyor; birini
    // ayara feda etmek, tercihini değiştirmeden ulaşamayacağı bir bilgi yaratırdı.
    final siparisKod = siparisKodu(order.code);

    return StreamBuilder<List<User>>(
      stream: watchTeam(db),
      initialData: const [],
      builder: (context, snap) {
        final ekip = snap.data ?? const <User>[];
        final kuryeAd = kullaniciAdi(ekip, order.assignedUserId);
        return Row(
          children: [
            Expanded(
              child: Wrap(
                spacing: 7,
                runSpacing: 6,
                crossAxisAlignment: WrapCrossAlignment.center,
                children: [
                  if (siparisKod != null) _KodRozeti(metin: siparisKod),
                  // Müşteri kodu canlı okunur: müşteri kaydı senkronla sonradan kod alabilir
                  // (çevrimdışı eklenmiş müşteri) ve detay açıkken tazelenmelidir.
                  if (order.customerId != null)
                    StreamBuilder<Customer?>(
                      stream: watchMusteri(db, order.customerId!),
                      builder: (context, mSnap) {
                        final mKod = musteriKodu(mSnap.data?.code);
                        return mKod == null
                            ? const SizedBox.shrink()
                            : _KodRozeti(metin: mKod, sonuk: true);
                      },
                    ),
                  if (order.status == 'open')
                    GecenSurePili(occurredAt: order.occurredAt)
                  else
                    SipDurumPili(durum: order.status),
                  if (kuryeAd != null)
                    SipDokun(
                      onTap: duzenlenebilir && canAssign ? () => _kuryeSec(context, ekip) : null,
                      zemin: t.surface2,
                      basiliZemin: t.line,
                      radius: SipRadius.brHap,
                      kenarlik: Border.all(color: t.line2),
                      padding: const EdgeInsets.symmetric(
                          horizontal: SipSpace.lg, vertical: SipSpace.xs),
                      child: Row(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          SipIcon(SipIcons.truck, boyut: 13, kalinlik: 2.2, renk: t.ink2),
                          const SizedBox(width: 5),
                          Text(kuryeAd, style: SipText.kuryeCip.copyWith(color: t.ink2)),
                          if (duzenlenebilir && canAssign) ...[
                            const SizedBox(width: 5),
                            SipIcon(SipIcons.down, boyut: 12, kalinlik: 2.4, renk: t.muted),
                          ],
                        ],
                      ),
                    )
                  // ATANMAMIŞ açık siparişte "Kurye ata" çipi (saha 2026-08-01: "açık siparişe
                  // kurye ataması yapamıyorum"). Önceki karar çipi yalnız DOLUYKEN çiziyordu
                  // ("kurye adı yoksa bu bayi atama kullanmıyor demektir") — ama form "sonra da
                  // atanabilir" der oldu ve atanmamış siparişin hiçbir yüzeyinde atama yolu
                  // kalmamıştı. Tek-kişilik ilkesi DURUYOR: [canAssign] `yetkiler().atama`dan
                  // gelir (yönetici VE aktif kurye var) — kuryesiz bayide bu çip hiç çizilmez.
                  else if (order.status == 'open' && duzenlenebilir && canAssign)
                    SipDokun(
                      onTap: () => _kuryeSec(context, ekip),
                      zemin: t.surface2,
                      basiliZemin: t.line,
                      radius: SipRadius.brHap,
                      kenarlik: Border.all(color: t.line2),
                      padding: const EdgeInsets.symmetric(
                          horizontal: SipSpace.lg, vertical: SipSpace.xs),
                      child: Row(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          SipIcon(SipIcons.truck, boyut: 13, kalinlik: 2.2, renk: t.muted),
                          const SizedBox(width: 5),
                          Text('Kurye ata',
                              style: SipText.kuryeCip.copyWith(color: t.muted)),
                          const SizedBox(width: 5),
                          SipIcon(SipIcons.down, boyut: 12, kalinlik: 2.4, renk: t.muted),
                        ],
                      ),
                    ),
                ],
              ),
            ),
            const SizedBox(width: SipSpace.sm),
            Row(
              mainAxisSize: MainAxisSize.min,
              children: [
                SipIcon(SipIcons.clock, boyut: 12, kalinlik: 2, renk: t.muted),
                const SizedBox(width: SipSpace.xs),
                Text(saatBicimi(order.occurredAt),
                    style: SipText.saat.copyWith(color: t.muted)),
              ],
            ),
          ],
        );
      },
    );
  }

  Future<void> _kuryeSec(BuildContext context, List<User> ekip) async {
    // ATAMA HEDEFLERİ: kuryeler değil TÜM aktif personel (2026-08-20) — patron malı kendi
    // götürecekse kendini seçebilmeli. Oturumdaki kişi "(siz)" ile işaretlensin diye kimliği
    // de okunur.
    final hedefler = await watchAtamaHedefleri(db).first;
    final benimId = (await db.syncState()).userId;
    if (!context.mounted) return;
    if (hedefler.isEmpty) {
      SipToast.goster(context, 'Atanacak aktif personel yok');
      return;
    }
    final secili = await kuryeSecSheet(
      context,
      kuryeler: hedefler,
      seciliId: order.assignedUserId,
      benimId: benimId,
    );
    if (secili == null || secili == order.assignedUserId || !context.mounted) return;
    await OrderRepository(db).assign(order.id, secili);
    if (!context.mounted) return;
    SipToast.goster(context, 'Görevli değiştirildi: ${kullaniciAdi(hedefler, secili) ?? ''}');
  }
}

/// Kod rozeti — sipariş kodu (#248) ve müşteri kodu (102) aynı kalıptan çizilir.
/// [sonuk] ikinci kodu (müşteri) hafifletir: bu ekranın konusu SİPARİŞTİR, müşteri kodu bağlamdır.
class _KodRozeti extends StatelessWidget {
  const _KodRozeti({required this.metin, this.sonuk = false});

  final String metin;
  final bool sonuk;

  @override
  Widget build(BuildContext context) {
    final t = context.sip;
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 7, vertical: 3),
      decoration: BoxDecoration(
        color: sonuk ? t.surface2 : t.accentSoft,
        borderRadius: BorderRadius.circular(7),
      ),
      child: Text(metin,
          style: SipText.siparisKod.copyWith(color: sonuk ? t.muted : t.accent)),
    );
  }
}
