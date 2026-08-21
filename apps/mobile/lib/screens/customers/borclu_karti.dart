// BORÇLULAR listesinin tek kartı: ad + toplam borç · ödenmemiş siparişleri · "Tahsilat Al" ·
// "Hatırlat".
//
// NEDEN AYRI DOSYA: `borclular_ekrani.dart` 533 satıra çıkmıştı (500 satır kuralı). Sınır kendini
// gösteriyordu: o dosyanın üst yarısı VERİDİR (borçlu kümesi, sipariş eşleme, saf `borcluListesiKur`)
// ve saf async testle sınanır; bu dosya ise tek bir müşterinin kartını çizer ve kartın üç eylemini
// (müşteri detayı · tahsilat · WhatsApp hatırlatma) yürütür. Kart kendi veri akışını KURMAZ —
// ihtiyacı olan her şey (telefon, IBAN, şablon) yukarıdaki akışlardan hazır iner.

import 'package:flutter/material.dart';

import '../../data/app_database.dart';
import '../../theme/components/atoms.dart';
import '../../theme/components/overlays.dart';
import '../../theme/icons.dart';
import '../../theme/tokens.dart';
import '../../theme/typography.dart';
import '../isletme/iban.dart' show ibanNormal;
import '../orders/musteri_eylemleri.dart' show whatsappAc;
import '../orders/order_detail_screen.dart' show siparisDetaySheetAc;
import '../orders/order_queries.dart' show saatBicimi;
import '../team.dart';
import 'borc_hatirlatma.dart';
import 'borclular_verisi.dart';
import 'customer_detail_screen.dart';
import 'customer_sheets.dart' show borcTahsilatiAc;

/// Bir borçlunun kartı: ad + toplam borç · ödenmemiş siparişleri · "Tahsilat Al".
class BorcluKarti extends StatelessWidget {
  const BorcluKarti({
    super.key,
    required this.db,
    required this.veri,
    required this.writable,
    required this.yetki,
    required this.canAssign,
    this.telefon,
    this.iban,
    this.isletmeAdi,
    this.ibanAliciAdi,
    this.sablon,
  });

  final AppDatabase db;
  final BorcluMusteri veri;
  final bool writable;
  final RolYetkileri yetki;
  final bool canAssign;

  /// Müşterinin birincil telefonu (E.164). Yoksa hatırlatma gönderilemez.
  final String? telefon;

  /// Bayinin IBAN'ı ve unvanı — mesajın içine girer (İşletme Profili'nden).
  final String? iban;
  final String? isletmeAdi;

  /// Hesap sahibinin ad soyadı (boşsa işletme adına düşülür) ve bayinin kendi mesaj şablonu
  /// (boşsa varsayılan metin) — ikisi de İşletme Profili'nden gelir.
  final String? ibanAliciAdi;
  final String? sablon;

  Future<void> _musteriAc(BuildContext context) => Navigator.of(context).push(
        MaterialPageRoute(
          builder: (_) => CustomerDetailScreen(
            db: db,
            customerId: veri.musteri.id,
            writable: writable,
            yetki: yetki,
          ),
        ),
      );

  Future<void> _tahsilat(BuildContext context) async {
    if (!writable) {
      SipToast.goster(context, 'Aboneliğiniz sona erdiği için yeni kayıt eklenemiyor.');
      return;
    }
    final ok = await borcTahsilatiAc(context, db: db, customerId: veri.musteri.id);
    if (ok == true && context.mounted) SipToast.goster(context, 'Tahsilat kaydedildi');
  }

  /// Tek tuşla WhatsApp hatırlatması (kullanıcı isteği 2026-08-04).
  ///
  /// Ön koşullar SESSİZCE DEĞİL, dokunuşta söylenir (tasarımın "dokunuşu yutma" ilkesi): eksik
  /// telefon ve tanımsız IBAN iki AYRI sorundur ve çözümleri de ayrıdır — tek bir soluk düğme
  /// bayiye hangisini düzelteceğini söylemezdi.
  ///
  /// SALT-OKUNUR KİP ENGELLEMEZ: bu bir YAZMA değil, mesaj hazırlama eylemidir. Abonelik bittiğinde
  /// bile bayi alacağını isteyebilmeli — kilit yeni kayıt girişini durdurur, tahsilatı değil.
  Future<void> _hatirlat(BuildContext context) async {
    if (!yetki.borcHatirlatma) {
      SipToast.goster(context, 'Hatırlatma gönderme yetkiniz yok.');
      return;
    }
    if (ibanNormal(iban) == null) {
      SipToast.goster(context, 'Önce Ayarlar → İşletme Profili\'nden IBAN tanımlayın');
      return;
    }
    final mesaj = borcHatirlatmaMesaji(
      musteriAd: veri.musteri.name,
      borcKurus: veri.borcKurus,
      iban: iban,
      isletmeAdi: isletmeAdi,
      ibanAliciAdi: ibanAliciAdi,
      sablon: sablon,
    );
    final gerekce = await whatsappAc(telefon, mesaj: mesaj);
    if (gerekce != null && context.mounted) SipToast.goster(context, gerekce);
  }

  @override
  Widget build(BuildContext context) {
    final t = context.sip;
    return Container(
      decoration: BoxDecoration(color: t.surface, borderRadius: SipRadius.br2),
      padding: const EdgeInsets.fromLTRB(15, 13, 15, 11),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          // Ad + toplam borç. Dokunuş müşteri detayına gider (defterin tamamı oradadır).
          SipDokun(
            onTap: () => _musteriAc(context),
            zemin: t.surface,
            basiliZemin: t.surface2,
            radius: SipRadius.br1,
            child: Row(
              children: [
                Expanded(
                  child: Text(
                    veri.musteri.name,
                    style: SipText.satirAdSip.copyWith(color: t.ink),
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                  ),
                ),
                const SizedBox(width: SipSpace.md),
                Text(sipTutar(veri.borcKurus),
                    style: SipText.satirTutarBuyuk.copyWith(color: t.danger)),
              ],
            ),
          ),
          const SizedBox(height: SipSpace.sm),

          if (veri.siparisler.isEmpty)
            // Borç var ama ödenmemiş sipariş yok: kaynağı sipariş dışı bir defter kaydıdır.
            // Boş bir kart bırakmak yerine sebebi söylenir.
            Text('Ödenmemiş sipariş yok; borç elle girilmiş.',
                style: SipText.metin(12, w: 600).copyWith(color: t.muted))
          else
            for (final s in veri.siparisler)
              _SiparisSatiri(
                siparis: s,
                onTap: () => siparisDetaySheetAc(
                  context,
                  db: db,
                  orderId: s.order.id,
                  writable: writable,
                  canAssign: canAssign,
                  baslik: veri.musteri.name,
                ),
              ),

          // Siparişlere bağlanamayan fark — yalnız varsa. Sessiz kalmak, kartın toplamıyla
          // satırların toplamını tutturamayan bayiye "rakamlar yanlış" dedirtirdi.
          if (veri.siparisler.isNotEmpty && veri.farkKurus > 0)
            Padding(
              padding: const EdgeInsets.only(top: SipSpace.xs),
              child: Text(
                'Bu siparişler dışında ${sipTutar(veri.farkKurus)} borç (defter kaydı)',
                style: SipText.metin(12, w: 600).copyWith(color: t.muted),
              ),
            ),

          const SizedBox(height: SipSpace.md),
          Row(
            children: [
              Expanded(
                child: SipDokun(
                  onTap: () => _tahsilat(context),
                  zemin: t.surface2,
                  basiliZemin: t.line,
                  radius: SipRadius.br2,
                  olcekle: true,
                  child: SizedBox(
                    height: 40,
                    child: Row(
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: [
                        SipIcon(SipIcons.wallet, boyut: 15, kalinlik: 2.2, renk: t.ink2),
                        const SizedBox(width: 7),
                        Flexible(
                          child: Text('Tahsilat Al (${sipTutar(veri.borcKurus)})',
                              style: SipText.metin(13, w: 700).copyWith(color: t.ink2),
                              maxLines: 1,
                              overflow: TextOverflow.ellipsis),
                        ),
                      ],
                    ),
                  ),
                ),
              ),
              const SizedBox(width: SipSpace.sm),
              // "Hatırlat" — WhatsApp'ı hazır metinle açar. Ön koşulu (IBAN/telefon) eksik olsa
              // da ÇİZİLİR ve dokunulabilir kalır: sebebini söyleyen bir düğme, sessizce yok olan
              // ya da açıklamasız soluk duran bir düğmeden iyidir.
              Semantics(
                button: true,
                label: 'Hatırlat',
                child: SipDokun(
                  onTap: () => _hatirlat(context),
                  zemin: t.surface2,
                  basiliZemin: t.line,
                  radius: SipRadius.br2,
                  olcekle: true,
                  child: SizedBox(
                    height: 40,
                    child: Padding(
                      padding: const EdgeInsets.symmetric(horizontal: 13),
                      child: Row(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          // WhatsApp yeşili — marka rengi, jetonlaştırılmaz (eylem şeridiyle aynı).
                          SipIcon(SipIcons.wa,
                              boyut: 15, kalinlik: 1.9, renk: const Color(0xFF1FA855)),
                          const SizedBox(width: 7),
                          Text('Hatırlat',
                              style: SipText.metin(13, w: 700).copyWith(color: t.ink2)),
                        ],
                      ),
                    ),
                  ),
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }
}

/// Kart içindeki tek sipariş satırı: tarih/saat · kalan borç. Dokunuş sipariş detayını açar.
class _SiparisSatiri extends StatelessWidget {
  const _SiparisSatiri({required this.siparis, required this.onTap});

  final BorcluSiparis siparis;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final t = context.sip;
    return SipDokun(
      onTap: onTap,
      zemin: t.surface,
      basiliZemin: t.surface2,
      radius: SipRadius.br1,
      padding: const EdgeInsets.symmetric(vertical: 5),
      child: Row(
        children: [
          SipIcon(SipIcons.box, boyut: 13, kalinlik: 2.1, renk: t.muted),
          const SizedBox(width: SipSpace.md),
          Expanded(
            child: Text(saatBicimi(siparis.order.occurredAt),
                style: SipText.metin(12.5, w: 600).copyWith(color: t.ink2)),
          ),
          Text(sipTutar(siparis.kalanKurus),
              style: SipText.metin(12.5, w: 700).copyWith(color: t.danger)),
          const SizedBox(width: SipSpace.xs),
          SipIcon(SipIcons.right, boyut: 13, kalinlik: 2.2, renk: t.muted),
        ],
      ),
    );
  }
}
