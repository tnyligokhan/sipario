// SAHTE HARİTA TUVALİ — yerel MapLibre görünümünün widget testi karşılığı (2026-09-28).
//
// Yerel harita bir platform görünümüdür ve widget testinde ÇİZİLEMEZ. Bu fikstür
// `haritaTuvaliUret` dikişine takılır ve iki iş yapar:
//  1. İçeriği sıradan widget'lar olarak çizer: her durak numarasıyla, her kurye adıyla (bayatsa
//     "X dk önce" ile) dokunulabilir bir düğmedir — dokunuş, motorun bildireceği dokunuşun
//     AYNISINI (`HaritaDokunusu`) ekrana iletir.
//  2. Kamera komutlarını KAYDEDER; testler ne istendiğini [komutlar] üzerinden okur.
//
// Durum ve davranış tek nesnede (fikstür sınıfı); `kur()` dikişi takar ve tearDown'da geri alır.

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:sipario/screens/orders/harita_icerigi.dart';
import 'package:sipario/screens/orders/harita_tuvali.dart';

/// Kaydedilen bir kamera komutu.
sealed class KameraKomutu {
  const KameraKomutu();
}

class YakinlastirKomutu extends KameraKomutu {
  const YakinlastirKomutu(this.fark);
  final double fark;
}

class KadrajlaKomutu extends KameraKomutu {
  const KadrajlaKomutu(this.kadraj);
  final HaritaKadraji kadraj;
}

class OdaklaKomutu extends KameraKomutu {
  const OdaklaKomutu(this.nokta, this.zoom);
  final HaritaNoktasi nokta;
  final double zoom;
}

class GorunurAlanaAlKomutu extends KameraKomutu {
  const GorunurAlanaAlKomutu(this.nokta, this.ortulenOran);
  final HaritaNoktasi nokta;
  final double ortulenOran;
}

class SahteHaritaTuvali implements HaritaKamerasi {
  SahteHaritaTuvali._();

  /// Dikişi sahteyle değiştirir; test bitince üretim tuvalini geri takar.
  static SahteHaritaTuvali kur() {
    final sahte = SahteHaritaTuvali._();
    final eski = haritaTuvaliUret;
    haritaTuvaliUret = (ayar) => _SahteTuval(ayar: ayar, sahte: sahte);
    addTearDown(() => haritaTuvaliUret = eski);
    return sahte;
  }

  /// Kameraya verilen komutlar, sırasıyla.
  final List<KameraKomutu> komutlar = [];

  /// Tuvale en son verilen ayar — içerik, tema, kenar boşluğu.
  HaritaTuvaliAyari? sonAyar;

  HaritaIcerigi get icerik => sonAyar!.icerik;

  /// [no] numaralı durak düğmesi.
  Finder durak(int no) => find.byKey(ValueKey('sahte-durak-$no'));

  /// Gruplu haritada [grup] anahtarlı kişinin [no] numaralı durağı.
  Finder grupDuragi(String grup, int no) => find.byKey(ValueKey('sahte-durak-$grup-$no'));

  /// Çizilen bütün durak düğmeleri.
  Finder get duraklar =>
      find.byWidgetPredicate((w) => w.key is ValueKey<String> &&
          (w.key! as ValueKey<String>).value.startsWith('sahte-durak-'));

  /// Adı [ad] olan kurye düğmesi.
  Finder kurye(String ad) => find.byKey(ValueKey('sahte-kurye-$ad'));

  /// Çizilen bütün kurye düğmeleri.
  Finder get kuryeler =>
      find.byWidgetPredicate((w) => w.key is ValueKey<String> &&
          (w.key! as ValueKey<String>).value.startsWith('sahte-kurye-'));

  Finder get cihaz => find.byKey(const ValueKey('sahte-cihaz'));

  @override
  Future<void> yakinlastir(double fark) async => komutlar.add(YakinlastirKomutu(fark));

  @override
  Future<void> kadrajla(HaritaKadraji kadraj) async => komutlar.add(KadrajlaKomutu(kadraj));

  @override
  Future<void> odakla(HaritaNoktasi nokta, double zoom) async =>
      komutlar.add(OdaklaKomutu(nokta, zoom));

  @override
  Future<void> gorunurAlanaAl(HaritaNoktasi nokta, {required double ortulenOran}) async =>
      komutlar.add(GorunurAlanaAlKomutu(nokta, ortulenOran));
}

class _SahteTuval extends StatefulWidget {
  const _SahteTuval({required this.ayar, required this.sahte});

  final HaritaTuvaliAyari ayar;
  final SahteHaritaTuvali sahte;

  @override
  State<_SahteTuval> createState() => _SahteTuvalState();
}

class _SahteTuvalState extends State<_SahteTuval> {
  @override
  void initState() {
    super.initState();
    widget.sahte.sonAyar = widget.ayar;
    // Üretim tuvali de kamerayı stil yüklendikten SONRA verir — eşzamanlı vermek, ekranın
    // "kamera henüz yok" yolunu hiçbir testte koşturmazdı.
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (mounted) widget.ayar.onHazir(widget.sahte);
    });
  }

  @override
  void didUpdateWidget(_SahteTuval eski) {
    super.didUpdateWidget(eski);
    widget.sahte.sonAyar = widget.ayar;
  }

  @override
  Widget build(BuildContext context) {
    final icerik = widget.ayar.icerik;
    void dokun(HaritaDokunusu d) => widget.ayar.onDokunus(d);
    // ORTADA: haritanın köşelerinde kontroller ve atıf durur, üstlerine düşen sahte pin dokunuşu
    // onlara kaptırırdı.
    return Align(
      child: Wrap(
        spacing: 8,
        runSpacing: 8,
        children: [
          for (final d in icerik.duraklar)
            GestureDetector(
              key: ValueKey(d.grup.isEmpty ? 'sahte-durak-${d.no}' : 'sahte-durak-${d.grup}-${d.no}'),
              onTap: () => dokun(DurakDokunusu(d.id)),
              child: SizedBox(width: 40, height: 40, child: Center(child: Text('${d.no}'))),
            ),
          if (icerik.cihaz != null)
            const SizedBox(key: ValueKey('sahte-cihaz'), width: 20, height: 20),
          for (final k in icerik.kuryeler)
            GestureDetector(
              key: ValueKey('sahte-kurye-${k.ad}'),
              onTap: () => dokun(KuryeDokunusu(k.id)),
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  Text(k.ad),
                  if (k.bayatlik.isNotEmpty && !k.taze) Text(k.bayatlik),
                ],
              ),
            ),
        ],
      ),
    );
  }
}
