// KİŞİYE ÖZEL KURYE YETKİLERİ — `KuryeYetkileriEkrani`nin KİŞİ KİPİ gövdesi.
//
// Ayrı dosya, bilinçli: iki kip tek dosyada 500 satırı aşıyordu ve iki kipin kurgusu farklı
// (biri iki durumlu şablon, diğeri üç durumlu ezme). 13 satırın TANIMI paylaşılır
// (`kuryeYetkiSatirlari`), sunumu ayrışır.
//
// ÜÇ DURUM: Varsayılan (devral) · Açık · Kapalı. "Varsayılan" seçiliyken satırın rozeti
// DEVRALINAN GERÇEK DEĞERİ yazar ("Varsayılan · kapalı") — yoksa patron neyi devraldığını
// göremez ve bayi varsayılanını değiştirdiğinde kuryenin yetkisinin neden oynadığını anlayamaz.
//
// YAZMA YOLU: `CourierRepository.kuryeIzinEzmeleriKaydet` (users LWW upsert → outbox → sunucu).

import 'package:flutter/material.dart';

import '../../data/app_database.dart';
import '../../repo/courier_repository.dart';
import '../../theme/components/atoms.dart';
import '../../theme/components/overlays.dart';
import '../../theme/icons.dart';
import '../../theme/tokens.dart';
import '../../theme/typography.dart';
import '../team.dart';
import 'isletme_atomlari.dart';
import 'kurye_yetki_bolumu.dart';

/// Kişiye özel ezmesi olan kurye satırında gösterilen rozet — kuryeler listesi de bunu kullanır,
/// böylece iki ekran aynı sözcüğü kullanır.
const String kuryeOzelYetkiRozeti = 'özel yetki';

/// "Hepsini varsayılana döndür" sonrası bildirimi.
const String kuryeYetkiSifirlandiMesaji = 'Yetkiler varsayılana döndürüldü';

class KisiselYetkiGovdesi extends StatelessWidget {
  const KisiselYetkiGovdesi({
    super.key,
    required this.db,
    required this.userId,
    required this.kuryeAdi,
    this.writable = true,
  });

  final AppDatabase db;
  final String userId;
  final String kuryeAdi;
  final bool writable;

  @override
  Widget build(BuildContext context) {
    // İKİ AKIŞ birlikte: bayi varsayılanı (devralınan değerin ne olduğunu göstermek için) ve
    // bu kuryenin ezmeleri. İkisi de AKIŞTIR — patron başka bir cihazdan varsayılanı
    // değiştirdiğinde bu ekrandaki "Varsayılan · kapalı" rozeti aynı turda tazelenmelidir.
    return StreamBuilder<KuryeIzinleri>(
      stream: watchKuryeIzinleri(db),
      initialData: KuryeIzinleri.varsayilan,
      builder: (context, varsayilanSnap) {
        final varsayilan = varsayilanSnap.data ?? KuryeIzinleri.varsayilan;
        return StreamBuilder<KuryeIzinEzmeleri>(
          stream: watchKuryeEzmeleri(db, userId),
          initialData: KuryeIzinEzmeleri.bos,
          builder: (context, ezmeSnap) {
            final ezme = ezmeSnap.data ?? KuryeIzinEzmeleri.bos;
            return _Govde(
              db: db,
              userId: userId,
              kuryeAdi: kuryeAdi,
              writable: writable,
              varsayilan: varsayilan,
              ezme: ezme,
            );
          },
        );
      },
    );
  }
}

class _Govde extends StatelessWidget {
  const _Govde({
    required this.db,
    required this.userId,
    required this.kuryeAdi,
    required this.writable,
    required this.varsayilan,
    required this.ezme,
  });

  final AppDatabase db;
  final String userId;
  final String kuryeAdi;
  final bool writable;
  final KuryeIzinleri varsayilan;
  final KuryeIzinEzmeleri ezme;

  Future<void> _yaz(BuildContext context, KuryeIzinEzmeleri yeni, String? mesaj) async {
    if (!writable) {
      SipToast.goster(context, yetkiSaltOkunurUyarisi);
      return;
    }
    await CourierRepository(db).kuryeIzinEzmeleriKaydet(userId, yeni);
    if (mesaj != null && context.mounted) SipToast.goster(context, mesaj);
  }

  @override
  Widget build(BuildContext context) {
    final t = context.sip;

    // Etkin (çözülmüş) izinler — kategori rozetindeki "N/M Açık" sayısı bunlardan gelir.
    // Ezmeden değil: patronun görmek istediği "bu kurye bugün ne yapabiliyor" sorusunun cevabı.
    final etkin = kuryeIzinleriCoz(varsayilan, ezme);

    final kategoriler = <String, List<KuryeYetkiSatiri>>{};
    for (final s in kuryeYetkiSatirlari) {
      kategoriler.putIfAbsent(s.kategori, () => []).add(s);
    }

    return SingleChildScrollView(
      padding: const EdgeInsets.fromLTRB(
        SipSpace.govde,
        SipSpace.sm,
        SipSpace.govde,
        SipSpace.x6,
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          SipNotKutusu(
            ikon: SipIcons.user,
            tur: SipNotTuru.bilgi,
            onEtiket: 'Kişiye özel:',
            metin: 'Yalnız $kuryeAdi için. "Varsayılan" bırakılanlar genel ayardan gelir.',
          ),
          const SizedBox(height: SipSpace.md),

          for (final kat in kategoriler.entries) ...[
            YetkiKategoriKarti(
              kategoriAdi: kat.key,
              rozetMetni: '${kat.value.where((s) => s.oku(etkin)).length}/${kat.value.length} Açık',
              rozetVurgulu: kat.value.any((s) => s.oku(etkin)),
              satirlar: [
                for (final satir in kat.value)
                  _EzmeSatiri(
                    satir: satir,
                    ezme: satir.ezmeOku(ezme),
                    devralinan: satir.oku(varsayilan),
                    onSec: (durum) => _yaz(
                      context,
                      satir.ezmeYaz(ezme, yetkiEzmeDegeri(durum)),
                      null,
                    ),
                  ),
              ],
            ),
            const SizedBox(height: SipSpace.md),
          ],

          const SizedBox(height: SipSpace.xs),
          SipButon(
            etiket: 'Hepsini varsayılana döndür',
            ikon: SipIcons.sync,
            tur: SipButonTuru.ikincil,
            onTap: () => _yaz(context, KuryeIzinEzmeleri.bos, kuryeYetkiSifirlandiMesaji),
          ),
          const SizedBox(height: SipSpace.sm),
          Text(
            'Kişiye özel ayarlar silinir, tüm yetkiler genel ayardan gelir',
            style: SipText.metin(11.5, w: 500).copyWith(color: t.muted),
            textAlign: TextAlign.center,
          ),
        ],
      ),
    );
  }
}

/// Üç durumlu tekil yetki satırı — etiket + rozet + açıklama + seçim rayı.
class _EzmeSatiri extends StatelessWidget {
  const _EzmeSatiri({
    required this.satir,
    required this.ezme,
    required this.devralinan,
    required this.onSec,
  });

  final KuryeYetkiSatiri satir;

  /// Bu kuryenin kararı — `null` ise devralınıyor.
  final bool? ezme;

  /// Bayi varsayılanındaki değer (rozette okunur biçimde gösterilir).
  final bool devralinan;

  final ValueChanged<YetkiEzmeDurumu> onSec;

  @override
  Widget build(BuildContext context) {
    final t = context.sip;
    final durum = yetkiEzmeDurumu(ezme);
    final devraliyor = durum == YetkiEzmeDurumu.varsayilan;

    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: SipSpace.sm, vertical: SipSpace.md),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Expanded(
                child: Text(
                  satir.etiket,
                  style: SipText.metin(13, w: 600).copyWith(color: t.ink),
                ),
              ),
              const SizedBox(width: SipSpace.sm),
              YetkiRozeti(
                metin: devraliyor
                    ? 'Varsayılanı: ${devralinan ? 'açık' : 'kapalı'}'
                    : kuryeOzelYetkiRozeti,
                renk: devraliyor ? t.muted : t.accent,
                zemin: devraliyor ? t.surface2 : t.accentSoft,
              ),
            ],
          ),
          const SizedBox(height: 3),
          Text(
            satir.aciklama,
            style: SipText.metin(11, w: 500).copyWith(color: t.muted),
          ),
          const SizedBox(height: SipSpace.sm),
          UcDurumSecim(anahtar: satir.anahtar, durum: durum, onSec: onSec),
        ],
      ),
    );
  }
}
