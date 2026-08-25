// GÜN SEÇME TAKVİMİ — Gün Özeti'nin tarih şeridindeki takvim düğmesiyle açılır (2026-08-25).
//
// ══ NEDEN OKLARIN YANINDA BİR TAKVİM DE VAR ═════════════════════════════════════════════════
// ‹ › okları "dün ne oldu" sorusunu bir dokunuşla cevaplar ve günlük kullanımın %90'ı odur. Ama
// bayi ayın başındaki bir günü sorduğunda ok on kez basılması gereken bir kontrole dönüşür.
// Takvim, oklara RAKİP değil tamamlayıcıdır: uzağa atlamanın tek adımı.
//
// ══ NEDEN MATERIAL `showDatePicker` DEĞİL ═══════════════════════════════════════════════════
// Bu projede `flutter_localizations` bağımlılığı YOK; `showDatePicker` varsayılan İngilizce
// `DefaultMaterialLocalizations` ile çizilir ve ekranda "August 2026 / MON TUE" görünür. Türkçe
// bir uygulamanın ortasında İngilizce bir ay takvimi, çevirisi unutulmuş bir ekran gibi okunur.
// Tek bir ekran için bütün uygulamaya yerelleştirme katmanı eklemek yerine ay ızgarası burada
// çiziliyor — ay ve gün adları zaten `siparis_tarih_seridi.dart`ta tanımlı sözlüğün aynısı.
//
// ══ TAKVİM BİR DURUM HARİTASIDIR, SALT TARİH SEÇİCİ DEĞİL ═══════════════════════════════════
// Her günün altındaki nokta o günün hesabını söyler: YEŞİL kapatılmış, SARI hareket var ama
// kapatılmamış, noktasız o gün hiç çalışılmamış. Bu, "kapanmamış gün" bandının aylık görünümü
// olur — bayi hangi günü atladığını aramak yerine görür. Nokta olmadan takvim yalnız bir tarih
// listesi olurdu ve zaten oklar da onu yapıyor.
//
// GELECEĞE GİDİLMEZ: bugünden sonraki günler soluk ve dokunulamazdır (tarih şeridindeki ileri
// okun kuralının aynısı). Yarının kasası yoktur; boş bir ekranda "veri mi kayboldu" diye
// düşündürmek engellemekten pahalıdır.

import 'package:flutter/material.dart';

import '../../data/app_database.dart';
import '../../data/tr_gun.dart';
import '../../repo/day_closing_repository.dart';
import '../../repo/kapanmamis_gunler.dart';
import '../../theme/components/atoms.dart';
import '../../theme/components/overlays.dart';
import '../../theme/icons.dart';
import '../../theme/tokens.dart';
import '../../theme/typography.dart';

const List<String> _aylar = [
  'Ocak', 'Şubat', 'Mart', 'Nisan', 'Mayıs', 'Haziran',
  'Temmuz', 'Ağustos', 'Eylül', 'Ekim', 'Kasım', 'Aralık',
];

const List<String> _gunBasHarfleri = ['Pt', 'Sa', 'Ça', 'Pe', 'Cu', 'Ct', 'Pz'];

/// Bir günün Gün Özeti açısından hâli — takvimdeki noktanın rengi budur.
enum GunHali {
  /// Hiç kayıt yok (sipariş, defter hareketi, kapanış, devir).
  bos,

  /// Hareket var, hesap KAPATILMAMIŞ.
  acik,

  /// Hesap kapatılmış.
  kapali,
}

/// Takvimin ihtiyaç duyduğu iki küme: hareketli günler + kapatılmış günler (TR gün anahtarı).
///
/// İKİSİ DE MEVCUT TANIMLARDAN GELİR — takvim kendi "hareketli gün" ya da "kapalı gün" kuralını
/// YAZMAZ. Yazsaydı bant bir gün için "kapanmadı" derken takvim onu yeşil gösterebilirdi.
class TakvimVerisi {
  const TakvimVerisi({required this.hareketli, required this.kapali});

  final Set<String> hareketli;
  final Set<String> kapali;

  GunHali hal(DateTime gun) {
    final a = trGunAnahtari(gun);
    if (kapali.contains(a)) return GunHali.kapali;
    if (hareketli.contains(a)) return GunHali.acik;
    return GunHali.bos;
  }
}

Future<TakvimVerisi> takvimVerisi(AppDatabase db) async => TakvimVerisi(
      hareketli: await KapanmamisGunlerRepository(db).hareketliGunler(),
      kapali: await DayClosingRepository(db).kapaliGunAnahtarlari(),
    );

/// Gün seçme takvimini açar; seçilen günü döner, vazgeçilirse null.
Future<DateTime?> gunTakvimiAc(
  BuildContext context, {
  required AppDatabase db,
  required DateTime secili,
  required DateTime bugun,
}) {
  return sipSheet<DateTime>(
    context,
    baslik: 'Gün Seç',
    govde: (ctx) => _TakvimGovdesi(db: db, secili: secili, bugun: bugun),
  );
}

class _TakvimGovdesi extends StatefulWidget {
  const _TakvimGovdesi({required this.db, required this.secili, required this.bugun});

  final AppDatabase db;
  final DateTime secili;
  final DateTime bugun;

  @override
  State<_TakvimGovdesi> createState() => _TakvimGovdesiState();
}

class _TakvimGovdesiState extends State<_TakvimGovdesi> {
  late DateTime _ay = DateTime(widget.secili.year, widget.secili.month);
  late final Future<TakvimVerisi> _veri = takvimVerisi(widget.db);

  /// Bu aya ileri gidilebilir mi? Bugünün ayını geçmek yasaktır.
  bool get _ileriAcik =>
      _ay.isBefore(DateTime(widget.bugun.year, widget.bugun.month));

  void _ayDegis(int fark) {
    setState(() => _ay = DateTime(_ay.year, _ay.month + fark));
  }

  @override
  Widget build(BuildContext context) {
    final t = context.sip;
    // Ayın ilk gününün hafta içi sırası (Pazartesi = 1) → ızgaranın baştaki boşluğu.
    final ilk = DateTime(_ay.year, _ay.month);
    final bosluk = ilk.weekday - 1;
    final gunSayisi = DateTime(_ay.year, _ay.month + 1, 0).day;

    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        Row(
          children: [
            _AyOku(
              ikon: SipIcons.left,
              etiket: 'Önceki ay',
              onTap: () => _ayDegis(-1),
            ),
            Expanded(
              child: Text(
                '${_aylar[_ay.month - 1]} ${_ay.year}',
                textAlign: TextAlign.center,
                style: SipText.metin(14.5, w: 700).copyWith(color: t.ink),
              ),
            ),
            _AyOku(
              ikon: SipIcons.right,
              etiket: 'Sonraki ay',
              soluk: !_ileriAcik,
              onTap: _ileriAcik ? () => _ayDegis(1) : null,
            ),
          ],
        ),
        const SizedBox(height: SipSpace.xl),
        Row(
          children: [
            for (final g in _gunBasHarfleri)
              Expanded(
                child: Text(
                  g,
                  textAlign: TextAlign.center,
                  style: SipText.metin(11, w: 700).copyWith(color: t.muted),
                ),
              ),
          ],
        ),
        const SizedBox(height: SipSpace.md),
        FutureBuilder<TakvimVerisi>(
          future: _veri,
          builder: (ctx, snap) {
            final veri = snap.data;
            return GridView.builder(
              shrinkWrap: true,
              physics: const NeverScrollableScrollPhysics(),
              padding: EdgeInsets.zero,
              gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
                crossAxisCount: 7,
                mainAxisSpacing: 4,
                crossAxisSpacing: 4,
                childAspectRatio: 0.92,
              ),
              itemCount: bosluk + gunSayisi,
              itemBuilder: (ctx, i) {
                if (i < bosluk) return const SizedBox.shrink();
                final gun = DateTime(_ay.year, _ay.month, i - bosluk + 1);
                final gelecek = gun.isAfter(widget.bugun);
                return _GunHucresi(
                  gun: gun,
                  secili: gun == DateTime(widget.secili.year, widget.secili.month,
                      widget.secili.day),
                  bugun: gun == widget.bugun,
                  gelecek: gelecek,
                  // Veri gelmeden NOKTA ÇİZİLMEZ (boş nokta değil, HİÇ nokta): "bu gün
                  // çalışılmadı" ile "henüz bilmiyorum" aynı şey değildir ve yanlış nokta
                  // bayiye kapatmayı unuttuğu bir günü kapatılmış gösterirdi.
                  hal: veri?.hal(gun),
                  onTap: gelecek ? null : () => Navigator.of(ctx).pop(gun),
                );
              },
            );
          },
        ),
        const SizedBox(height: SipSpace.xl),
        // GÖSTERGE ANAHTARI: renk tek başına bilgi taşımaz (renk körlüğü ve küçük nokta) —
        // altındaki iki kelime noktaların ne dediğini söyler.
        Row(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            _Anahtar(renk: t.ok, metin: 'Kapatıldı'),
            const SizedBox(width: SipSpace.x2),
            _Anahtar(renk: t.warn, metin: 'Kapatılmadı'),
          ],
        ),
        const SizedBox(height: SipSpace.x2),
        SipButon(
          etiket: 'Bugüne Dön',
          ikon: SipIcons.takvim,
          tur: SipButonTuru.ikincil,
          onTap: () => Navigator.of(context).pop(widget.bugun),
        ),
      ],
    );
  }
}

class _GunHucresi extends StatelessWidget {
  const _GunHucresi({
    required this.gun,
    required this.secili,
    required this.bugun,
    required this.gelecek,
    required this.hal,
    required this.onTap,
  });

  final DateTime gun;
  final bool secili;
  final bool bugun;
  final bool gelecek;

  /// null = veri henüz gelmedi; nokta çizilmez.
  final GunHali? hal;

  final VoidCallback? onTap;

  @override
  Widget build(BuildContext context) {
    final t = context.sip;
    final nokta = switch (hal) {
      GunHali.kapali => t.ok,
      GunHali.acik => t.warn,
      _ => null,
    };

    return Opacity(
      opacity: gelecek ? 0.28 : 1,
      child: Semantics(
        button: !gelecek,
        selected: secili,
        label: '${gun.day} ${_aylar[gun.month - 1]}',
        child: SipDokun(
          onTap: onTap,
          zemin: secili ? t.accent : (bugun ? t.surface2 : Colors.transparent),
          basiliZemin: secili ? t.accent : t.surface2,
          radius: SipRadius.br2,
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              Text(
                '${gun.day}',
                style: SipText.metin(13.5, w: secili || bugun ? 800 : 600)
                    .copyWith(color: secili ? t.accentInk : t.ink),
              ),
              const SizedBox(height: 3),
              // Nokta yerini HER ZAMAN ayırır (renksizken saydam): aksi hâlde noktalı ve
              // noktasız hücrelerin rakamları farklı yükseklikte durur ve ızgara titrer.
              Container(
                width: 5,
                height: 5,
                decoration: BoxDecoration(
                  shape: BoxShape.circle,
                  color: nokta == null
                      ? Colors.transparent
                      : (secili ? t.accentInk : nokta),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class _AyOku extends StatelessWidget {
  const _AyOku({
    required this.ikon,
    required this.etiket,
    required this.onTap,
    this.soluk = false,
  });

  final String ikon;
  final String etiket;
  final VoidCallback? onTap;
  final bool soluk;

  @override
  Widget build(BuildContext context) {
    final t = context.sip;
    return Opacity(
      opacity: soluk ? 0.4 : 1,
      child: Semantics(
        button: true,
        enabled: !soluk,
        label: etiket,
        child: SipDokun(
          onTap: onTap ?? () {},
          zemin: t.surface2,
          basiliZemin: t.line,
          radius: SipRadius.brHap,
          padding: const EdgeInsets.symmetric(horizontal: SipSpace.lg),
          child: SizedBox(
            height: 38,
            width: 22,
            child: Center(child: SipIcon(ikon, boyut: 16, kalinlik: 2.4, renk: t.ink2)),
          ),
        ),
      ),
    );
  }
}

class _Anahtar extends StatelessWidget {
  const _Anahtar({required this.renk, required this.metin});

  final Color renk;
  final String metin;

  @override
  Widget build(BuildContext context) {
    return Row(
      mainAxisSize: MainAxisSize.min,
      children: [
        Container(
          width: 6,
          height: 6,
          decoration: BoxDecoration(shape: BoxShape.circle, color: renk),
        ),
        const SizedBox(width: 5),
        Text(
          metin,
          style: SipText.metin(11.5, w: 600).copyWith(color: context.sip.muted),
        ),
      ],
    );
  }
}
