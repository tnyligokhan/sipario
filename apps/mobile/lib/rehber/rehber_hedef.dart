// REHBER HEDEFİ — turun spot tutacağı gerçek widget'ı adıyla kaydeder.
//
// PROBLEM: tur, ekrandaki bir kutunun ÜSTÜNE delik açar; bunun için o kutunun ekrandaki
// dikdörtgenini bilmesi gerekir. Klasik çözüm her ekranın `GlobalKey` taşıyıp turu besleyen
// bir kanal açmasıdır — yirmi ekranda yirmi kanal demek.
//
// ÇÖZÜM: hedef KENDİNİ kaydeder. Ekranda tek satırlık bir sarmalayıcı vardır:
//
//     RehberHedef(id: 'ana.bento', child: AnaBento(...))
//
// Kutu ağaca girdiğinde kayda yazılır, çıktığında silinir. Tur yalnız ADI bilir.
//
// ⚠️ BUNUN EN ÖNEMLİ YAN ETKİSİ — ROL VE ÖZELLİK FİLTRESİ BEDAVA GELİR: kuryede çizilmeyen
// "Borçlular" kutusu kayda hiç girmez, dolayısıyla onu anlatan tur adımı kendiliğinden atlanır.
// Turda ayrıca rol koşulu yazmak (ve iki koşulun zamanla ayrışması) böylece gereksizleşir.
//
// AYNI AD İKİ KEZ MONTE OLABİLİR: rota yığınında altta kalan ekran hâlâ ağaçtadır (Navigator
// alttaki rotayı `dispose` etmez). Bu yüzden kayıt ad başına LİSTE tutar ve SON monte olan
// kazanır — spot her zaman üstteki ekranın kutusuna düşer.

import 'package:flutter/widgets.dart';

/// Ad → o adı taşıyan (belki birden çok) widget'ın anahtarları.
///
/// Global mutable durum, `tutamacSagdaTercihi` deseninin aynısı: ekranlar ile tur arasında
/// tek yönlü, dar bir kanal. Testler [RehberKayit.temizle] ile sıfırlar.
abstract final class RehberKayit {
  static final Map<String, List<GlobalKey>> _kayit = <String, List<GlobalKey>>{};

  static void ekle(String id, GlobalKey anahtar) =>
      (_kayit[id] ??= <GlobalKey>[]).add(anahtar);

  static void cikar(String id, GlobalKey anahtar) {
    final liste = _kayit[id];
    if (liste == null) return;
    liste.remove(anahtar);
    if (liste.isEmpty) _kayit.remove(id);
  }

  /// Hedefin ekrandaki dikdörtgeni; monte değilse, ölçülmediyse ya da sıfır boyutluysa `null`.
  ///
  /// Sıfır boyut da `null` sayılır: `Offstage`/`Visibility` ile gizlenmiş bir kutunun etrafına
  /// delik açmak, ekranın ortasında sebepsiz bir kare bırakırdı.
  static Rect? kutu(String id) {
    final liste = _kayit[id];
    if (liste == null) return null;
    // SON monte olan kazanır (üstteki ekran); geriye doğru ilk ölçülebilen döner.
    for (final anahtar in liste.reversed) {
      final ctx = anahtar.currentContext;
      if (ctx == null) continue;
      final nesne = ctx.findRenderObject();
      if (nesne is! RenderBox || !nesne.hasSize || !nesne.attached) continue;
      if (nesne.size.isEmpty) continue;
      final sol = nesne.localToGlobal(Offset.zero);
      return sol & nesne.size;
    }
    return null;
  }

  /// Ad kayıtlı ve ölçülebilir mi.
  static bool varMi(String id) => kutu(id) != null;

  /// Yalnız test: kayıt tablosunu boşaltır.
  @visibleForTesting
  static void temizle() => _kayit.clear();
}

/// Turun işaret edebileceği bir yüzeyi [id] adıyla kaydeder.
///
/// Çizime hiçbir şey EKLEMEZ: yerleşimi, boyutu ve semantiği değiştirmez, yalnız bir anahtar
/// takar. Var olan bir ekrana eklenmesi tek satırlık bir sarmalamadır ve o ekranın testlerini
/// kırmaz.
class RehberHedef extends StatefulWidget {
  const RehberHedef({super.key, required this.id, required this.child});

  /// Tur adımlarının kullandığı ad. Kalıp `<ekran>.<parça>` — `ana.bento`, `siparis.fab`.
  final String id;

  final Widget child;

  @override
  State<RehberHedef> createState() => _RehberHedefState();
}

class _RehberHedefState extends State<RehberHedef> {
  final GlobalKey _anahtar = GlobalKey();

  @override
  void initState() {
    super.initState();
    RehberKayit.ekle(widget.id, _anahtar);
  }

  @override
  void didUpdateWidget(RehberHedef eski) {
    super.didUpdateWidget(eski);
    if (eski.id == widget.id) return;
    RehberKayit.cikar(eski.id, _anahtar);
    RehberKayit.ekle(widget.id, _anahtar);
  }

  @override
  void dispose() {
    RehberKayit.cikar(widget.id, _anahtar);
    super.dispose();
  }

  // KeyedSubtree: anahtar ÇOCUĞUN kendisine takılır, araya bir kutu girmez — yerleşim
  // (Expanded/Flexible gibi ata beklentileri dahil) hiç değişmez.
  @override
  Widget build(BuildContext context) => KeyedSubtree(key: _anahtar, child: widget.child);
}
