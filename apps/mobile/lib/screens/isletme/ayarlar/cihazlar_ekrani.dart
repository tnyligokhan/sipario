// HESAP → CİHAZLAR — "hesabım hangi telefonlarda açık?"
//
// ══ NEDEN VAR (kullanıcı eleştirisi 2026-08-13) ═══════════════════════════════════════════
// *"Hesabım sayfasının varlık amacı ne, hiçbir şeye yaramıyor, neden var?"* Haklıydı: sayfa
// kullanıcının adını ve rolünü yazıyordu — yani çekmecenin başlığında ZATEN yazan şeyi — ve
// altına çekmecede zaten bulunan Çıkış düğmesini koyuyordu. Yeni bir UI ile aynı şeyi tekrar
// etmek, kullanıcının bir önceki vardiyada da uyardığı hatanın ta kendisiydi.
//
// Bir hesap sayfasının cevaplaması gereken, ürünün HİÇBİR yerinde cevaplanmayan soru şudur:
// hesabım nerelerde açık? Bayi telefon değiştirir, kuryeye telefon verir, çalınan telefonu
// merak eder. Bu ekran o soruyu — ve yalnız onu — cevaplar.
//
// ⚠️ UZAKTAN OTURUM KAPATMA HENÜZ YOK ve BİLEREK VAAT EDİLMİYOR: sunucuda oturum jetonu ile
// cihaz kaydı arasında bağ yok (`AuthController` jetonu düz `'mobile'` adıyla üretir), yani bir
// cihazı listeden düşürmek o telefondaki oturumu KAPATMAZ. Yarım çalışan bir "Oturumu kapat"
// düğmesi, güvenlik ekranında olabilecek en kötü şeydir: bayi kapattığını sanır, telefon
// çalışmaya devam eder. Bağ kurulana kadar (PLAN.md · cihaz listesi + uzaktan oturum kapatma)
// ekran yalnız GÖSTERİR.
//
// ⚠️ ÇEVRİMDIŞI ÖNBELLEK YOK: liste sunucunun anlık gerçeğidir. Bayat liste "eski telefonum
// artık bağlı değil" gibi YANLIŞ bir güvenlik izlenimi üretirdi — o yüzden ağ yoksa ekran boş
// liste değil, açık bir uyarı gösterir.

import 'package:flutter/material.dart';

import '../../../auth/session.dart';
import '../../../data/app_database.dart';
import '../../../sync/cihaz_api.dart';
import '../../../theme/components/states.dart';
import '../../../theme/icons.dart';
import '../../../theme/tokens.dart';
import '../../../theme/typography.dart';
import '../isletme_atomlari.dart';

/// Cihazın son görülme zamanı — insan sözcükleriyle. Saf; testle sınanır.
///
/// GÜN GEÇTİKTEN SONRA TARİH YAZILIR, "37 gün önce" DEĞİL: güvenlik sorusunda bayi tarihe bakar
/// ("o telefonu ağustosta vermiştim"), gün sayısını kafasında tarihe çevirmek zorunda kalmamalı.
/// İLERİ tarihli damga (cihaz saati geri alınmış) "az önce" sayılır — "−3 dk önce" veriye
/// güveni sarsar; `cagriSiparisZamanMetni` ile aynı duruş.
String cihazSonGorulmeMetni(DateTime? an, {DateTime? simdi}) {
  if (an == null) return 'Son görülme bilinmiyor';
  final ref = (simdi ?? DateTime.now()).toLocal();
  final fark = ref.difference(an.toLocal());
  if (fark.inMinutes < 1) return 'Az önce';
  if (fark.inMinutes < 60) return '${fark.inMinutes} dk önce';
  if (fark.inHours < 24) return '${fark.inHours} sa önce';
  if (fark.inDays < 7) return '${fark.inDays} gün önce';
  final g = an.toLocal();
  return '${g.day.toString().padLeft(2, '0')}.${g.month.toString().padLeft(2, '0')}.${g.year}';
}

class CihazlarEkrani extends StatefulWidget {
  const CihazlarEkrani({super.key, required this.db, this.apiFabrikasi});

  final AppDatabase db;

  /// Test için enjeksiyon noktası; üretimde null → gerçek [CihazApi].
  final CihazApi Function(String baseUrl, String token)? apiFabrikasi;

  @override
  State<CihazlarEkrani> createState() => _CihazlarEkraniState();
}

class _CihazlarEkraniState extends State<CihazlarEkrani> {
  late Future<_Sonuc> _istek = _yukle();

  Future<_Sonuc> _yukle() async {
    final meta = await widget.db.syncState();
    final token = meta.authToken;
    if (token == null) throw CihazApiException('Oturum bulunamadı.');
    final api = widget.apiFabrikasi != null
        ? widget.apiFabrikasi!(Session.baseUrlOf(meta), token)
        : CihazApi(baseUrl: Session.baseUrlOf(meta), token: token);
    return _Sonuc(cihazlar: await api.listele(), buCihazId: meta.deviceId);
  }

  @override
  Widget build(BuildContext context) {
    final t = context.sip;
    return Scaffold(
      backgroundColor: t.bg,
      body: SafeArea(
        bottom: false,
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            SipUst(baslik: 'Cihazlar', onGeri: () => Navigator.of(context).maybePop()),
            Expanded(
              child: FutureBuilder<_Sonuc>(
                future: _istek,
                builder: (context, snap) {
                  if (snap.connectionState != ConnectionState.done) {
                    return const SipGovde(children: [SipIskelet(adet: 3)]);
                  }
                  if (snap.hasError) return _Hata(hata: snap.error, onTekrar: _tekrar);
                  return _Liste(sonuc: snap.data!);
                },
              ),
            ),
          ],
        ),
      ),
    );
  }

  void _tekrar() => setState(() => _istek = _yukle());
}

class _Sonuc {
  const _Sonuc({required this.cihazlar, required this.buCihazId});
  final List<Cihaz> cihazlar;
  final String? buCihazId;
}

class _Liste extends StatelessWidget {
  const _Liste({required this.sonuc});

  final _Sonuc sonuc;

  @override
  Widget build(BuildContext context) {
    final t = context.sip;
    if (sonuc.cihazlar.isEmpty) {
      return const SipGovde(children: [
        SipBosDurum(baslik: 'Kayıtlı cihaz yok', aciklama: 'Bu hesap henüz hiçbir cihaza bağlanmamış.'),
      ]);
    }

    // BU CİHAZ EN ÜSTTE: bayinin ilk sorusu "hangisi benimki" — listede aramak zorunda kalmamalı.
    final sirali = [...sonuc.cihazlar]..sort((a, b) {
        final ab = a.id == sonuc.buCihazId ? 0 : 1;
        final bb = b.id == sonuc.buCihazId ? 0 : 1;
        return ab.compareTo(bb);
      });

    return SipGovde(
      children: [
        Padding(
          padding: const EdgeInsets.only(top: SipSpace.xl, bottom: SipSpace.md),
          child: Text(
            '${sonuc.cihazlar.length} cihaz bu hesaba bağlı.',
            style: SipText.metin(12.5, w: 600).copyWith(color: t.ink2),
          ),
        ),
        AyarKarti(satirlar: [
          for (final c in sirali)
            AyarSatiri(
              ikon: SipIcons.phone,
              baslik: c.id == sonuc.buCihazId ? '${c.ad} · Bu cihaz' : c.ad,
              altBaslik: [
                cihazSonGorulmeMetni(c.sonGorulme),
                if (c.uygulamaSurumu != null) 'Sürüm ${c.uygulamaSurumu}',
              ].join(' · '),
            ),
        ]),
        // DÜRÜSTLÜK NOTU: ekran ne YAPMADIĞINI söyler. Bunu yazmamak, bayinin listeyi bir
        // güvenlik denetimi sanmasına yol açardı.
        const Padding(
          padding: EdgeInsets.only(top: SipSpace.xl),
          child: AlanNotu(
            'Bu liste yalnız gösterir. Bir cihazın oturumunu uzaktan kapatmak yakında eklenecek; '
            'şimdilik parolayı değiştirmek tüm oturumları düşürür.',
            tur: AlanNotuTuru.bilgi,
          ),
        ),
        const SizedBox(height: SipSpace.x3),
      ],
    );
  }
}

class _Hata extends StatelessWidget {
  const _Hata({required this.hata, required this.onTekrar});

  final Object? hata;
  final VoidCallback onTekrar;

  @override
  Widget build(BuildContext context) {
    final mesaj = hata is CihazApiException
        ? (hata as CihazApiException).mesaj
        : 'Cihaz listesi alınamadı.';
    return SipGovde(children: [
      Padding(
        padding: const EdgeInsets.only(top: SipSpace.x3),
        child: SipBosDurum(
          baslik: 'Liste okunamadı',
          aciklama: mesaj,
          hata: true,
          aksiyon: 'Tekrar dene',
          onAksiyon: onTekrar,
        ),
      ),
    ]);
  }
}
