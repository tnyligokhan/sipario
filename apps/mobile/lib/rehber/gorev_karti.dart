// KATMAN A — ANA EKRANDAKİ "İLK ADIMLAR" KARTI.
//
// NEDEN TUR DEĞİL DE LİSTE: bir açılış turu, kullanıcının HİÇBİR bağlamının ve hiçbir
// motivasyonunun olmadığı tek anda gösterilir; izlense bile hatırlanmaz. Görev listesi tam
// tersini yapar — kullanıcıyı seyirci değil YAPAN konumuna koyar, bölünebilir, geri
// dönülebilir ve ilerlemesi görünür. BRIEF'in ölçütü de budur: "kurulumdan sonra ~10 dakika
// içinde 'telefon çaldı, ekranda müşteri çıktı' anını yaşamazsa uygulamayı bırakır" —
// o ana götüren şey anlatı değil, sırayla yapılan beş iştir.
//
// KART KENDİLİĞİNDEN KAYBOLUR: zorunlu maddeler bitince çizilmez (bkz. [GorevDurumu.tamamlandi]).
// Kullanıcı erken kapatabilir; Ayarlar → Uygulama → "Rehberi baştan göster" geri getirir.
//
// ⚠️ VERİSİ OLAN BAYİ BU KARTI HİÇ GÖRMEZ: güncellemeyle gelen mevcut bayide ürün, müşteri ve
// sipariş zaten vardır, yani kart ilk karede "tamamlandı" sayılıp çizilmez. Bu istenen
// davranıştır — çalışan bir dükkâna "ilk müşterini kaydet" demek ürünü küçültür.

import 'package:flutter/material.dart';

import '../data/app_database.dart';
import '../theme/components/atoms.dart';
import '../theme/icons.dart';
import '../theme/tokens.dart';
import '../theme/typography.dart';
import 'gorev_ilerlemesi.dart';
import 'rehber_deposu.dart';
import 'rehber_hedef.dart';
import 'rehber_modeli.dart';

class GorevKarti extends StatefulWidget {
  const GorevKarti({
    super.key,
    required this.db,
    required this.kuryeMi,
    required this.onGorev,
    this.kullaniciId,
  });

  final AppDatabase db;

  /// Hangi madde kümesi gösterilecek. Kuryede maddeler kurulum değil İŞ adımlarıdır.
  final bool kuryeMi;

  /// Kurye maddeleri için gerekli — kimlik yoksa hiçbir madde bitmiş sayılmaz.
  final String? kullaniciId;

  /// Maddeye dokunulduğunda. GEZİNME KARARI KABUĞUNDUR (`onArama`, `onBorclular` deseninin
  /// aynısı): bu kart hangi ekranın hangi yetkiyle açılacağını bilmez, yalnız niyeti devreder.
  final ValueChanged<RehberGorev> onGorev;

  @override
  State<GorevKarti> createState() => _GorevKartiState();
}

class _GorevKartiState extends State<GorevKarti> {
  /// Akış BİR KEZ kurulur — build içinde kurulan akış kabuğun her setState'inde aboneliği
  /// koparır ve kart bir kare boyunca boş duruma düşerdi (`ana_ekran.dart`ta iki kez yaşandı).
  Stream<GorevDurumu>? _akis;
  bool? _akisKurye;
  String? _akisKullanici;

  Stream<GorevDurumu> _izle() {
    if (_akis == null ||
        _akisKurye != widget.kuryeMi ||
        _akisKullanici != widget.kullaniciId) {
      _akisKurye = widget.kuryeMi;
      _akisKullanici = widget.kullaniciId;
      _akis = watchGorevDurumu(
        widget.db,
        kuryeMi: widget.kuryeMi,
        kullaniciId: widget.kullaniciId,
      );
    }
    return _akis!;
  }

  Future<void> _kapat() async {
    await rehberDeposu.gorevKartiniKapat();
    if (mounted) setState(() {});
  }

  @override
  Widget build(BuildContext context) {
    if (!rehberDeposu.gorevKartiAcik) return const SizedBox.shrink();
    return StreamBuilder<GorevDurumu>(
      stream: _izle(),
      builder: (context, snap) {
        final d = snap.data;
        // VERİ GELMEDEN ÇİZİLMEZ: yarım saniyelik de olsa "0/5 hiçbir şey yapmadın" göstermek,
        // dolu bir dükkânın ana ekranında yanlış bir cümledir.
        if (d == null || d.tamamlandi || d.kitle.isEmpty) return const SizedBox.shrink();
        return RehberHedef(
          id: 'ana.gorev',
          child: Padding(
            padding: const EdgeInsets.only(bottom: SipSpace.xl),
            child: SipKart(
              padding: const EdgeInsets.fromLTRB(
                  SipSpace.x2, SipSpace.x2, SipSpace.md, SipSpace.md),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                mainAxisSize: MainAxisSize.min,
                children: [
                  _Baslik(durum: d, onKapat: _kapat),
                  const SizedBox(height: SipSpace.md),
                  for (final g in d.kitle)
                    _Satir(
                      gorev: g,
                      bitti: d.bittiMi(g),
                      onTap: () => widget.onGorev(g),
                    ),
                ],
              ),
            ),
          ),
        );
      },
    );
  }
}

/// Başlık şeridi: ad · ilerleme sayacı · kapat.
class _Baslik extends StatelessWidget {
  const _Baslik({required this.durum, required this.onKapat});

  final GorevDurumu durum;
  final VoidCallback onKapat;

  @override
  Widget build(BuildContext context) {
    final t = context.sip;
    return Row(
      children: [
        SipIkonKutu(
          ikon: SipIcons.bolt,
          cap: 30,
          ikonBoyut: 15,
          kalinlik: 2.4,
          zemin: t.accentSoft,
          renk: t.accent,
        ),
        const SizedBox(width: SipSpace.lg),
        Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            mainAxisSize: MainAxisSize.min,
            children: [
              Text('İlk adımlar', style: SipText.metin(14, w: 700).copyWith(color: t.ink)),
              const SizedBox(height: 1),
              Text(
                '${durum.sayac}/${durum.toplam} tamam',
                style: SipText.metin(11.5).copyWith(color: t.muted),
              ),
            ],
          ),
        ),
        SipIkonButon(
          ikon: SipIcons.x,
          ikonBoyut: 18,
          renk: t.muted,
          etiket: 'İlk adımlar listesini kapat',
          onTap: onKapat,
        ),
      ],
    );
  }
}

/// Tek madde: durum yuvarlağı · başlık + alt başlık · ok.
class _Satir extends StatelessWidget {
  const _Satir({required this.gorev, required this.bitti, required this.onTap});

  final RehberGorev gorev;
  final bool bitti;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final t = context.sip;
    return SipDokun(
      // BİTMİŞ MADDE DE DOKUNULABİLİR KALIR: "ürünlerini ekle" bitmiş olsa da bayi oraya
      // gitmek isteyebilir; bitmiş satırı pasifleştirmek listeyi bir engele çevirirdi.
      onTap: onTap,
      radius: SipRadius.br2,
      padding: const EdgeInsets.symmetric(horizontal: SipSpace.md, vertical: SipSpace.lg),
      child: Row(
        children: [
          _Yuvarlak(bitti: bitti),
          const SizedBox(width: SipSpace.xl),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              mainAxisSize: MainAxisSize.min,
              children: [
                Text(
                  gorev.baslik,
                  style: SipText.metin(13.5, w: bitti ? 500 : 700).copyWith(
                    color: bitti ? t.muted : t.ink,
                    // Bitmiş madde üstü çizili: sayaçtan bağımsız olarak, listeye bakan göz
                    // "neyin kaldığını" tek bakışta ayırsın.
                    decoration: bitti ? TextDecoration.lineThrough : null,
                    decorationColor: t.muted,
                  ),
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                ),
                const SizedBox(height: 1),
                Text(
                  gorev.istegeBagli ? '${gorev.altBaslik} · isteğe bağlı' : gorev.altBaslik,
                  style: SipText.metin(11.5).copyWith(color: t.muted),
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                ),
              ],
            ),
          ),
          const SizedBox(width: SipSpace.md),
          SipIcon(SipIcons.chevR, boyut: 16, kalinlik: 2.2, renk: t.muted),
        ],
      ),
    );
  }
}

class _Yuvarlak extends StatelessWidget {
  const _Yuvarlak({required this.bitti});

  final bool bitti;

  @override
  Widget build(BuildContext context) {
    final t = context.sip;
    if (bitti) {
      return SipIkonKutu(
        ikon: SipIcons.check,
        cap: 24,
        ikonBoyut: 13,
        kalinlik: 2.8,
        zemin: t.okSoft,
        renk: t.ok,
      );
    }
    return Container(
      width: 24,
      height: 24,
      decoration: BoxDecoration(
        shape: BoxShape.circle,
        border: Border.all(color: t.line2, width: 2),
      ),
    );
  }
}
