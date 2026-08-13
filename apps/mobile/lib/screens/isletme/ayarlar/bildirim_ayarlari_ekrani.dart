// AYARLAR → BİLDİRİMLER — izin durumu, kategori anahtarları, borç eşiği, sessiz saatler.
//
// Gövde `lib/bildirim/bildirim_ayar_bolumu.dart`ta yaşamaya devam eder: izin durumu ve kategori
// anahtarları kendi durumunu yönetiyor ve bildirim katmanının parçası. Bu dosya yalnız ona bir
// SAYFA verir — eskiden Ayarlar'ın uzun listesinin ortasında bir bölümdü.
//
// MAĞAZA KURALI: abonelik / ödeme / satın alma / fiyat / üyelik bağlantısı OLAMAZ.

import 'package:flutter/material.dart';

import '../../../bildirim/bildirim_ayar_bolumu.dart';
import '../../../theme/components/states.dart';
import '../../../theme/tokens.dart';

class BildirimAyarlariEkrani extends StatelessWidget {
  const BildirimAyarlariEkrani({super.key});

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
            SipUst(baslik: 'Bildirimler', onGeri: () => Navigator.of(context).maybePop()),
            const Expanded(
              child: SipGovde(children: [BildirimAyarBolumu()]),
            ),
          ],
        ),
      ),
    );
  }
}
