// SİPARİŞ DETAYININ "BİLGİLENDİRME MESAJI" DÜĞMESİ (kullanıcı isteği 2026-11-06).
//
// Bayinin müşteriye siparişle ilgili yazacağı hazır mesajlar burada durur. Mesaj seçilince metin
// siparişin gerçek bilgileriyle çözülür ve WhatsApp sohbeti hazır metinle açılır.
//
// TEK DÜĞME, ALTTAN AÇILAN LİSTE (kullanıcı isteği 2026-11-06, 1.17.0): mesajlar eskiden ekranda
// hap sırası olarak duruyordu; bayi kendi mesajlarını ekledikçe sıra büyüyor ve aşağıdaki Teslim
// Et'i itiyordu. Düğmenin yeri eylem kümesidir (`order_detail_screen.dart`): mesaj, tahsilat ve
// teslim kapıdaki aynı anın işleridir ve baş parmağın ulaştığı yerde birlikte durur.
//
// MESAJ GÖNDERİLMEZ, HAZIRLANIR: gönder tuşuna bayi basar (`borc_hatirlatma.dart` ile aynı kural).
// Bu yüzden bölüm salt-okunur kipte de açıktır: yazma değil, mesaj hazırlama eylemidir.
//
// YETKİ: Borç Hatırlatma, hatırlatma yetkisi olmayan kuryede HİÇ çizilmez. Öteki mesajlar herkese
// açıktır; "Yola Çıktı" ve "Adreste Ulaşılamadı" zaten en çok kuryenin işine yarar.

import 'dart:math' show max;

import 'package:flutter/material.dart';

import '../../data/app_database.dart';
import '../../data/mesaj_sablonlari.dart';
import '../../repo/tenant_settings_repository.dart';
import '../../theme/components/atoms.dart';
import '../../theme/components/overlays.dart';
import '../../theme/icons.dart';
import '../../theme/tokens.dart';
import '../../theme/typography.dart';
import '../customers/borc_hatirlatma.dart';
import '../customers/borclular_verisi.dart' show musteriHesapOzeti;
import '../isletme/iban.dart' show ibanNormal;
import '../team.dart';
import 'musteri_numara_secici.dart';
import 'order_queries.dart';

/// Bir siparişin mesajlarını çözer. Ekrandan bağımsızdır, doğrudan sınanır.
class SiparisMesajHazirlayici {
  const SiparisMesajHazirlayici({
    required this.db,
    required this.order,
    required this.satirlar,
    this.simdi,
  });

  final AppDatabase db;
  final Order order;
  final List<OrderLine> satirlar;

  /// Yalnız test içindir.
  final DateTime? simdi;

  /// [sablon]u bu siparişin bilgileriyle çözer. Boş kalan değerin satırı mesajdan düşer.
  Future<String> bilgilendirme(String sablon) async {
    final musteri = await _musteri();
    final ayar = await TenantSettingsRepository(db).get();
    final degerler = await _degerler(musteri, ayar);
    return hatirlatmaSablonuUygula(sablon, degerler: degerler);
  }

  /// Borç hatırlatma metni; gönderilemiyorsa [gerekce] dolu gelir.
  Future<({String? mesaj, String? gerekce})> borcHatirlatma() async {
    final musteri = await _musteri();
    if (musteri == null) return (mesaj: null, gerekce: 'Müşteri kaydı bulunamadı');
    if (musteri.balanceKurus <= 0) {
      return (mesaj: null, gerekce: 'Bu müşterinin açık borcu yok');
    }
    final ayar = await TenantSettingsRepository(db).get();
    if (ibanNormal(ayar?.iban) == null) return (mesaj: null, gerekce: ibanEksikUyarisi);

    final mesaj = borcHatirlatmaMesaji(
      musteriAd: musteri.name,
      borcKurus: musteri.balanceKurus,
      iban: ayar?.iban,
      isletmeAdi: ayar?.businessName,
      ibanAliciAdi: ayar?.ibanOwnerName,
      sablon: ayar?.reminderTemplate,
      isletmeTelefonu: ayar?.phone,
      hesap: await musteriHesapOzeti(db, musteri),
      tarih: simdi,
    );
    return (mesaj: mesaj, gerekce: null);
  }

  Future<Customer?> _musteri() async {
    final id = order.customerId;
    if (id == null) return null;
    return (db.select(db.customers)..where((t) => t.id.equals(id))).getSingleOrNull();
  }

  Future<Map<String, String>> _degerler(Customer? musteri, TenantSetting? ayar) async {
    final ad = (musteri?.name ?? '').trim();
    final id = order.customerId;
    final adres = id == null ? null : (await watchBirincilAdresler(db, musteriId: id).first)[id];
    final ekip = await watchTeam(db).first;
    final odeme = order.paymentType;

    return {
      ...hatirlatmaDegerleri(
        // Adı olmayan müşteride "Sayın ," yazmaz; satır da düşmez.
        musteriAd: ad.isEmpty ? 'Müşterimiz' : ad,
        // Alacaklı müşteriye eksi bakiye yazılmaz.
        borcKurus: max(musteri?.balanceKurus ?? 0, 0),
        iban: ayar?.iban,
        isletmeAdi: ayar?.businessName,
        ibanAliciAdi: ayar?.ibanOwnerName,
        isletmeTelefonu: ayar?.phone,
        hesap: musteri == null
            ? const HatirlatmaHesapOzeti()
            : await musteriHesapOzeti(db, musteri),
        tarih: simdi,
      ),
      '*siparisno*': siparisKodu(order.code) ?? '',
      '*siparisozeti*': satirlar.map(_satirMetni).join('\n'),
      '*siparistoplami*': sipTutar(order.totalKurus),
      '*teslimatadresi*': adres?.tamMetin ?? '',
      '*kuryeadi*': kullaniciAdi(ekip, order.assignedUserId) ?? '',
      '*odemetipi*': odeme == null ? '' : odemeTipiEtiketi(odeme),
    };
  }

  /// "2 adet 19 L Su"; tek seferlik kalemde yalnız ad.
  static String _satirMetni(OrderLine l) =>
      serbestMi(l) ? l.productName : '${l.qty} ${l.unit ?? 'adet'} ${l.productName}';
}

class BilgilendirmeMesajiBolumu extends StatefulWidget {
  const BilgilendirmeMesajiBolumu({
    super.key,
    required this.db,
    required this.order,
    required this.satirlar,
    required this.musteriId,
  });

  final AppDatabase db;
  final Order order;
  final List<OrderLine> satirlar;
  final String musteriId;

  @override
  State<BilgilendirmeMesajiBolumu> createState() => _BilgilendirmeMesajiBolumuState();
}

class _BilgilendirmeMesajiBolumuState extends State<BilgilendirmeMesajiBolumu> {
  static const _borcAnahtari = 'borc_hatirlatma';

  // Ayar AKIŞLA okunur: patronun eklediği mesaj senkronla inince açık ekranda da görünsün.
  late final Stream<TenantSetting?> _ayar = TenantSettingsRepository(widget.db).watch();
  late final Future<RolYetkileri> _yetki = oturumYetkileri(widget.db);

  bool _calisiyor = false;

  /// Listeyi açar. Gönderim sayfa KAPANDIKTAN sonra başlar: gerekçe bildirimi (borcu yok, IBAN
  /// eksik) sayfanın arkasında kalmasın.
  Future<void> _sec(List<BilgilendirmeSecenegi> secenekler) async {
    final secim = await sipSheet<BilgilendirmeSecenegi>(
      context,
      baslik: 'Bilgilendirme Mesajı',
      govde: (ctx) => Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          for (final s in secenekler)
            _MesajSatiri(etiket: s.baslik, onTap: () => Navigator.of(ctx).pop(s)),
        ],
      ),
    );
    if (secim != null) await _gonder(secim);
  }

  Future<void> _gonder(BilgilendirmeSecenegi s) async {
    if (_calisiyor) return;
    _calisiyor = true;
    final gerekce = await _hazirlaVeAc(s);
    _calisiyor = false;
    if (gerekce != null && mounted) SipToast.goster(context, gerekce);
  }

  Future<String?> _hazirlaVeAc(BilgilendirmeSecenegi s) async {
    final hazirlayici = SiparisMesajHazirlayici(
      db: widget.db,
      order: widget.order,
      satirlar: widget.satirlar,
    );
    final String mesaj;
    if (s.anahtar == _borcAnahtari) {
      final sonuc = await hazirlayici.borcHatirlatma();
      if (sonuc.gerekce != null) return sonuc.gerekce;
      mesaj = sonuc.mesaj!;
    } else {
      mesaj = await hazirlayici.bilgilendirme(s.sablon);
    }
    if (!mounted) return null;
    return MusteriNumaraSecici(db: widget.db, customerId: widget.musteriId)
        .whatsapp(context, mesaj: mesaj);
  }

  @override
  Widget build(BuildContext context) {
    return StreamBuilder<TenantSetting?>(
      stream: _ayar,
      builder: (context, ayarSnap) => FutureBuilder<RolYetkileri>(
        future: _yetki,
        builder: (context, yetkiSnap) {
          final secenekler = [
            ...MesajSablonlari.coz(ayarSnap.data?.messageTemplatesJson)
                .siparisIcin(widget.order.status),
            if (yetkiSnap.data?.borcHatirlatma ?? false)
              const BilgilendirmeSecenegi(
                anahtar: _borcAnahtari,
                baslik: 'Borç Hatırlatma',
                sablon: '',
              ),
          ];
          if (secenekler.isEmpty) return const SizedBox.shrink();
          return Padding(
            padding: const EdgeInsets.only(top: SipSpace.lg),
            child: SipButon(
              etiket: 'Bilgilendirme Mesajı Gönder',
              tur: SipButonTuru.ikincil,
              ikon: SipIcons.chat,
              yukseklik: 44,
              onTap: () => _sec(secenekler),
            ),
          );
        },
      ),
    );
  }
}

class _MesajSatiri extends StatelessWidget {
  const _MesajSatiri({required this.etiket, required this.onTap});

  final String etiket;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final t = context.sip;
    return Padding(
      padding: const EdgeInsets.only(bottom: SipSpace.sm),
      child: Semantics(
        button: true,
        child: SipDokun(
          onTap: onTap,
          zemin: t.surface2,
          basiliZemin: t.line,
          radius: SipRadius.br2,
          padding: const EdgeInsets.symmetric(horizontal: SipSpace.xl, vertical: 13),
          child: Row(
            children: [
              SipIcon(SipIcons.chat, boyut: 16, kalinlik: 2.1, renk: t.ink2),
              const SizedBox(width: SipSpace.lg),
              Expanded(
                child: Text(etiket, style: SipText.metin(14, w: 700).copyWith(color: t.ink)),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
