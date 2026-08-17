// Sipariş LİSTESİNİN eylemleri — harita, kurye süzgeci, satırın kurye çipi, sıralama seçimi ve
// elle sıranın kalıcı yazımı. CSS `.ust-sirala` + araç şeridi.
//
// NEDEN AYRI DOSYA: `order_list_screen.dart` 565 satıra çıkmıştı (500 satır kuralı).
// `order_detail_eylemler.dart` ile aynı sınır: ekran DURUM tutar (seçili sekme, süzgeç, sıra
// kipi) ve akışları birleştirir; buradaki her fonksiyon ise sheet açar, kapıları uygular ve
// sonucu DÖNDÜRÜR — hiçbiri `setState` çağırmaz, ekranın alanlarını görmez. Böylece kapıların
// (kapalı sipariş, salt-okunur kip, aday yokluğu) tek bir yeri olur.

import 'package:flutter/material.dart';

import '../../data/app_database.dart';
import '../../repo/order_repository.dart';
import '../../theme/components/overlays.dart';
import '../team.dart';
import 'order_list_parts.dart';
import 'order_queries.dart';
import 'order_sheets.dart';
import 'siparis_harita.dart';

/// Kurye süzgecinin seçimi: [id] null = "tümü" (süzme yok). [ad] üst başlıkta yazılır ve
/// kimliğiyle BİRLİKTE döner — ekran adı ayrıca sorgulamak zorunda kalmasın.
class KuryeSuzgecSecimi {
  const KuryeSuzgecSecimi({this.id, this.ad});
  final String? id;
  final String? ad;
}

/// Harita ekranı — açık siparişlerin durakları, rota sırasında numaralı. "Oto Sırala" ORADA
/// durur; dönen `true`, orada sıra yazıldığını söyleyen SİNYALDİR.
///
/// Oto sıralamadan sonra liste ELLE kipine ALINMAZ (2026-08-01 kullanıcı şikâyeti: "oto
/// sıralamadan sonra tekrar elle sıralama alanı geliyor, mantıksız"). Kullanıcı sonucu
/// görmek istiyordu, düzenlemek değil; `rota` kipi aynı sırayı tutamaçsız gösterir ve ince
/// ayar isteyen Sırala → "Elle sırala"yı kendisi seçer.
Future<bool> siparisHaritasiAc(
  BuildContext context, {
  required AppDatabase db,
  required bool writable,
  required bool canAssign,
}) async {
  final otoYapildi = await Navigator.of(context).push<bool>(MaterialPageRoute<bool>(
    builder: (_) => SiparisHaritaEkrani(
      db: db,
      writable: writable,
      canAssign: canAssign,
    ),
  ));
  return otoYapildi == true;
}

/// "Kuryeye Göre" süzgeci (saha hatası 6 — patron hiçbir listede kuryeye göre süzemiyordu).
///
/// Aday listesi tek atış okunur: sheet açılırken bir akış tikini beklemek, dokunma ile ekran
/// arasına gereksiz gecikme koyardı. Süzgeç yalnız GÖRÜNÜMÜ değiştirir, hiçbir kayıt yazmaz —
/// bu yüzden salt-okunur kipte de çalışır.
///
/// null döner: vazgeçildi ya da süzülecek aday yok (ikisinde de mevcut süzgeç DEĞİŞMEZ).
Future<KuryeSuzgecSecimi?> kuryeSuzgeciSec(
  BuildContext context, {
  required AppDatabase db,
  required String? seciliId,
}) async {
  final adaylar = await watchKuryeSuzgecAdaylari(db).first;
  if (!context.mounted) return null;
  if (adaylar.isEmpty) {
    SipToast.goster(context, 'Süzülecek kullanıcı yok — ekip henüz senkronlanmadı');
    return null;
  }
  final secim = await kuryeSuzgecSheet(context, adaylar: adaylar, seciliId: seciliId);
  if (secim == null || !context.mounted) return null;
  final id = secim == kTumKuryeler ? null : secim;
  return KuryeSuzgecSecimi(id: id, ad: id == null ? null : kuryeSuzgecEtiketi(id, adaylar));
}

/// Satırın kurye çipi: kapılar → sheet → atama → toast. Ekran durumu tutmaz; atama `assign`
/// olayıyla yazılır ve liste akışı sonucu kendiliğinden gösterir.
///
/// Kapılar SESSİZ DEĞİL: kapalı siparişte ve salt-okunur kipte dokunuş YUTULMAZ, nedeni söylenir
/// (tasarım s-siparisler.jsx:24).
Future<void> siparisKuryesiniDegistir(
  BuildContext context, {
  required AppDatabase db,
  required OrderListItem item,
  required bool writable,
}) async {
  if (item.order.status != 'open') {
    SipToast.goster(context, 'Kapalı siparişte kurye değiştirilemez');
    return;
  }
  if (!writable) {
    SipToast.goster(context, 'Salt-okunur kip: kurye atanamaz.');
    return;
  }
  final kuryeler = await watchAktifKuryeler(db).first;
  if (!context.mounted) return;
  if (kuryeler.isEmpty) {
    SipToast.goster(context, 'Atanacak aktif kurye yok');
    return;
  }
  final secili = await kuryeSecSheet(
    context,
    kuryeler: kuryeler,
    seciliId: item.order.assignedUserId,
    baslik: 'Kurye Seç · ${item.customerName ?? 'Tezgâh satışı'}',
  );
  if (secili == null || secili == item.order.assignedUserId || !context.mounted) return;
  await OrderRepository(db).assign(item.order.id, secili);
  if (!context.mounted) return;
  SipToast.goster(context, 'Kurye değiştirildi: ${kullaniciAdi(kuryeler, secili) ?? ''}');
}

/// Sıralama sheet'i. Elle sıralama `sort_set` OLAYI yazar → salt-okunur kipte sunulmaz (yeni
/// kayıt yasağı). "Rota sırası" için böyle bir kapı YOK: seçmek hiçbir şey yazmaz, kalıcı sırayı
/// gösterir. null = vazgeçildi.
Future<OrderSort?> siralamaSec(
  BuildContext context, {
  required OrderSort secili,
  required bool writable,
}) =>
    siralamaSecSheet(
      context,
      secili: secili,
      secenekler: [
        for (final s in OrderSort.values)
          if (writable || s != OrderSort.elle) s,
      ],
    );

/// Elle sıranın KALICI yazımı. Yazma yolu repo → olay → outbox; `sort_index` yalnız türetilmiş
/// önbellektir. Yalnız DEĞİŞEN satırlar yazılır ([elleSiraYazimi]).
Future<void> elleSirayiYaz(AppDatabase db, List<OrderListItem> yeniSira) async {
  final repo = OrderRepository(db);
  for (final girdi in elleSiraYazimi(yeniSira).entries) {
    await repo.setSortIndex(girdi.key, girdi.value);
  }
}
