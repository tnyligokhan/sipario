// Müşteri detayındaki DEFTER bölümü — CSS `.defter` / `.dhar*`, kaynak s-musteriler.jsx
// `MusteriDetay` hareket listesi.
//
// Sorgu mantığı ekrandan AYRI top-level fonksiyonlardadır (watchLedger) — saf
// async testle sınanır (widget-test sahte zamanı drift akışlarında güvenilmez; Dilim 1/2 dersi).
// Para HER YERDE int kuruş.
// Silme/EZME YOK (kırmızı çizgi #2): bir hareketi "geri almak" ancak ters kayıtla olur
// (LedgerRepository.duzeltme) — kaynak satır defterde durur. Bu bölüm hiçbir kaydı ne siler
// ne değiştirir; yalnız okur (düzeltme sheet'i başlıktaki bağlantıdan açılır).

import 'package:drift/drift.dart' hide Column;
import 'package:flutter/material.dart';

import '../../data/app_database.dart';
import '../../theme/components/atoms.dart';
import '../../theme/components/states.dart';
import '../../theme/icons.dart';
import '../../theme/tokens.dart';
import '../../theme/typography.dart';
import 'customer_widgets.dart';

/// Müşterinin defter hareketleri — en yeni önce. occurred_at eşitse id (uuid7) son tiebreak.
Stream<List<LedgerEntry>> watchLedger(AppDatabase db, String customerId) {
  final q = db.select(db.ledgerEntries)..where((t) => t.customerId.equals(customerId));
  q.orderBy([(t) => OrderingTerm.desc(t.occurredAt), (t) => OrderingTerm.desc(t.id)]);
  return q.watch();
}

/// Hareket tipinin Türkçe etiketi — s-musteriler.jsx `HAREKET_META` (58-63): tasarımın dört
/// sözcüğü **Borç · Tahsilat · Alacak · Düzeltme**'dir. Sipariş borcu ayrı bir etiket DEĞİL
/// (tasarımda yok; siparişin kendisi `relatedOrderId` ile deftere bağlı kalır). Ödeme tipi de
/// burada yok, ROZETE ayrıldı (CSS `.dhar-odeme`).
String defterTipEtiketi(LedgerEntry e) => switch (e.entryType) {
      'debit' => 'Borç',
      'payment' => 'Tahsilat',
      'credit' => 'Alacak',
      'correction' => 'Düzeltme',
      _ => e.entryType,
    };

/// Tek satırlık tam etiket (tip + ödeme tipi) — onay diyaloğu ve testler için.
/// DB değeri değişmez: 'debit'/'payment'/… olduğu gibi durur.
String defterHareketEtiketi(LedgerEntry e) {
  final tip = e.paymentType != null ? ' · ${odemeEtiketi(e.paymentType!)}' : '';
  return switch (e.entryType) {
    'debit' => defterTipEtiketi(e),
    'credit' => defterTipEtiketi(e),
    _ => '${defterTipEtiketi(e)}$tip',
  };
}

/// İmzalı tutar metni: +borç, −ödeme (sipTutar negatifi zaten U+2212 ile yazar).
String imzaliTutarText(int amountKurus) =>
    amountKurus > 0 ? '+${sipTutar(amountKurus)}' : sipTutar(amountKurus);

/// Hareketin rengi — s-musteriler.jsx `HAREKET_META`: borç danger, tahsilat/alacak ok,
/// düzeltme nötr (yönü tutarın işaretinde okunur).
Color hareketRengi(SipTokens t, LedgerEntry e) => switch (e.entryType) {
      'debit' => t.danger,
      'payment' || 'credit' => t.ok,
      _ => t.muted,
    };

/// Hareket ikonu — `HAREKET_META.ikon`.
String hareketIkonu(String entryType) => switch (entryType) {
      'debit' => SipIcons.box,
      'payment' || 'credit' => SipIcons.wallet,
      'correction' => SipIcons.edit,
      _ => SipIcons.receipt,
    };

/// Defter bölümü — müşteri detayının listesine gömülür (kendi başına scroll AÇMAZ).
/// Tahsilat düğmesi burada DEĞİL: tasarımda hızlı eylem ızgarasında (CSS `.md-akslar`) duruyor.
/// Başlığın sağındaki "± Bakiye Düzeltme" bağlantısı (CSS `.md-duzelt-link`) buraya aittir.
class CustomerLedgerSection extends StatelessWidget {
  const CustomerLedgerSection({
    super.key,
    required this.db,
    required this.customerId,
    this.writable = true,
    this.onDuzelt,
  });

  final AppDatabase db;
  final String customerId;

  /// KULLANILMIYOR — korundu: satıra dokunup ters kayıt atma kalktı (tasarımda `.dhar`
  /// tıklanmaz bir div), bölüm artık hiçbir şey yazmıyor. Salt-okunur/yetki kapıları
  /// [onDuzelt]'i veren ekrandadır. Parametre, kipi geçirerek bu bölümü kuran mevcut çağrı
  /// yerleri derlenmeye devam etsin diye duruyor.
  final bool writable;

  /// Başlığın sağındaki "± Bakiye Düzeltme" bağlantısı (s-musteriler.jsx:125). null ise
  /// bağlantı çizilmez.
  final VoidCallback? onDuzelt;

  @override
  Widget build(BuildContext context) {
    final t = context.sip;
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        SipBolumBaslik(
          'Defter Hareketleri',
          sag: onDuzelt == null
              ? null
              // CSS `.md-duzelt-link` — accent, 12/700, `padding: 4px 0`.
              : SipDokun(
                  onTap: onDuzelt,
                  radius: SipRadius.br1,
                  padding: const EdgeInsets.symmetric(vertical: SipSpace.xs),
                  child: Text(
                    '± Bakiye Düzeltme',
                    style: SipText.metin(12, w: 700).copyWith(color: t.accent),
                  ),
                ),
        ),
        StreamBuilder<List<LedgerEntry>>(
          stream: watchLedger(db, customerId),
          builder: (context, snap) {
            final entries = snap.data;
            if (entries == null) return const SipIskelet(adet: 3);
            if (entries.isEmpty) {
              return const SipBosDurum(
                ikon: SipIcons.book,
                baslik: 'Hareket yok',
                aciklama: 'Bu müşteriyle henüz kayıt oluşmadı.',
              );
            }
            return Column(
              children: [
                for (var i = 0; i < entries.length; i++)
                  Padding(
                    padding: EdgeInsets.only(top: i == 0 ? 0 : SipSpace.sm),
                    child: _HareketSatiri(e: entries[i]),
                  ),
              ],
            );
          },
        ),
      ],
    );
  }
}

/// CSS `.dhar` — ikon + tip (+ ödeme rozeti) + saat/not + imzalı tutar.
///
/// TIKLANMAZ: tasarımda `.dhar` bir div'dir (s-musteriler.jsx:132), satıra dokunmakla ters kayıt
/// atılmaz. Append-only kırmızı çizgisi değişmedi — düzeltme başlıktaki "± Bakiye Düzeltme"
/// sheet'iyle yapılır ve kaynak satır defterde durur.
class _HareketSatiri extends StatelessWidget {
  const _HareketSatiri({required this.e});

  final LedgerEntry e;

  @override
  Widget build(BuildContext context) {
    final t = context.sip;
    final renk = hareketRengi(t, e);
    final not = e.note;
    final alt = [
      defterSaati(e.occurredAt),
      if (not != null && not.isNotEmpty) not,
    ].join(' · ');

    return Container(
      decoration: BoxDecoration(color: t.surface, borderRadius: SipRadius.br2),
      padding: const EdgeInsets.symmetric(horizontal: SipSpace.x2, vertical: SipSpace.xl),
      child: Row(
        children: [
          Container(
            width: 34,
            height: 34,
            alignment: Alignment.center,
            decoration: BoxDecoration(
              // CSS: color-mix(in srgb, <renk> 12%, transparent)
              color: renk.withValues(alpha: 0.12),
              borderRadius: SipRadius.brHap,
            ),
            child: SipIcon(hareketIkonu(e.entryType), boyut: 17, kalinlik: 2, renk: renk),
          ),
          const SizedBox(width: SipSpace.xl),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  children: [
                    Flexible(
                      child: Text(
                        defterTipEtiketi(e),
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                        style: SipText.govdeKalin.copyWith(color: t.ink),
                      ),
                    ),
                    if (e.paymentType != null) ...[
                      const SizedBox(width: 7),
                      _OdemeRozeti(tip: e.paymentType!),
                    ],
                  ],
                ),
                const SizedBox(height: 2),
                Text(
                  alt,
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: SipText.metin(11.5).copyWith(color: t.muted),
                ),
              ],
            ),
          ),
          const SizedBox(width: SipSpace.md),
          Text(
            imzaliTutarText(e.amountKurus),
            // CSS `.dhar-amt` — font-d 700, 13.5.
            style: SipText.tutar(13.5).copyWith(color: renk),
          ),
        ],
      ),
    );
  }
}

/// CSS `.dhar-odeme` — hareketin ödeme tipi rozeti (BÜYÜK HARF).
class _OdemeRozeti extends StatelessWidget {
  const _OdemeRozeti({required this.tip});

  final String tip;

  @override
  Widget build(BuildContext context) {
    final t = context.sip;
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 7, vertical: 2),
      decoration: BoxDecoration(color: t.surface2, borderRadius: SipRadius.brHap),
      child: Text(
        trBuyuk(odemeEtiketi(tip)),
        style: SipText.rozetOdeme.copyWith(color: t.muted),
      ),
    );
  }
}
