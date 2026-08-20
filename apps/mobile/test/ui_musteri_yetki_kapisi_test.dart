// MÜŞTERİ KARTI — ROL KAPISI (K2). Kapatılan gerçek bir açığın regresyon kilidi.
//
// AÇIK NEYDİ (2026-08-13'te bulundu ve kapatıldı): `CustomerDetailScreen.yetki` alanı
// `RolYetkileri?` idi, her okuma `widget.yetki?.alan ?? true` deseniyle yazılmıştı ve doc'ta
// "null → tam yetki" diye KURAL olarak duruyordu. Ekranın altı giriş noktasından beşi yetkiyi
// geçiyordu; biri — Ayarlar → Çağrı Geçmişi → arama satırı — geçmiyordu. Sonuç: bayinin
// `cagriGunlugu` yetkisini AÇTIĞI bir kurye, o tek yoldan bir müşteriye girdiğinde müşteri
// silme · kara listeye alma · defter düzeltme · MASKESİZ telefon eylemlerinin hepsine
// erişiyordu. Aynı ekrana müşteri listesinden girdiğinde hiçbirine erişemezken.
//
// ASIL KİLİT BU DOSYA DEĞİL, TİP SİSTEMİDİR: alan artık zorunlu, yani parametreyi geçmeyi
// unutmak DERLEME HATASIDIR ve bir daha sessizce olamaz. Bu dosya kilidin ikinci yarısıdır —
// tipin söyleyemediğini söyler: "bir yetkinin açılması, YANINDAKİLERİ AÇMAZ."
//
// TEST NEDEN "AYARLAR → ÇAĞRI GEÇMİŞİ" YOLUNU KURMUYOR: o yol taşınıyor (çağrı geçmişi bir iş
// ekranıdır, ayar değil). Yola bağlı bir test, yol değişince kırılır ve korunan ŞEY kaybolur.
// Korunan şey davranıştır: kurye yetki kümesiyle çizilen kartta yönetici eylemleri YOKTUR.

import 'package:drift/native.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:sipario/data/app_database.dart';
import 'package:sipario/repo/customer_repository.dart';
import 'package:sipario/screens/customers/customer_detail_screen.dart';
import 'package:sipario/screens/customers/kara_liste.dart';
import 'package:sipario/screens/team.dart';

import 'support/ekran_yardimcilari.dart';
import 'support/yetki_yardimcilari.dart';

void main() {
  /// Kartı [yetki] ile kurar ve müşterinin telefonunu döndürür.
  Future<String> kartiAc(WidgetTester tester, RolYetkileri yetki) async {
    const telefon = '05324152290';
    final db = AppDatabase(NativeDatabase.memory());
    final id = await tester.runAsync(() => CustomerRepository(db).create(
          name: 'Ayşe Yılmaz',
          phones: [PhoneInput(phoneE164: telefon, isPrimary: true)],
        ));

    // `ekranaKoy` UZUN viewport kurar (800x2400) ve akış turlarını bekler. Düz `pumpWidget`
    // yetmiyor: tehlikeli eylemler gövdenin EN ALTINDA ve normal telefon yüksekliğinde görünür
    // alanın dışında kalıyor — liste tembel olduğu için `find.text` onları HİÇ bulamıyor ve
    // test "eylem yok" diye YÖNETİCİDE de yanlış geçerdi.
    await ekranaKoy(
      tester,
      CustomerDetailScreen(
        db: db,
        customerId: id!,
        writable: true,
        yetki: yetki,
      ),
    );
    return telefon;
  }

  /// Bayinin `cagriGunlugu`nu AÇTIĞI kurye — açığın tam senaryosu. Diğer izinler varsayılan.
  final cagriGunluguAcikKurye = yetkiler(
    rol: 'kurye',
    atamaHedefiVar: true,
    izin: const KuryeIzinleri(cagriGunlugu: true),
  );

  testWidgets('YÖNETİCİ: tehlikeli eylemler çizilir, telefon maskesiz', (tester) async {
    // Karşı kutup. Bu olmadan aşağıdaki "yok" iddiaları hiçbir şey kanıtlamaz: eylemler
    // ekranda HİÇ olmasaydı da testler yeşil geçerdi.
    final telefon = await kartiAc(tester, tamYetki);

    expect(find.text(musteriyiSilEtiketi), findsOneWidget);
    expect(find.text(karaListeyeEkleEtiketi), findsOneWidget);
    expect(find.textContaining('***'), findsNothing,
        reason: 'yöneticide maskeleme kapalıdır');
    expect(telefon, isNotEmpty);

    await kapat(tester);
  });

  testWidgets('KURYE: çağrı günlüğü açık olsa da yönetici eylemleri YOK', (tester) async {
    // AÇIĞIN KENDİSİ. `cagriGunlugu` yalnız çağrı geçmişini görmeye yarar; müşteri yönetimine
    // dokunmaz. Bir yetkinin açılması yanındakileri açıyorsa, matris bir yetki listesi değil
    // süslü bir "her şey açık" düğmesidir.
    await kartiAc(tester, cagriGunluguAcikKurye);

    expect(find.text(musteriyiSilEtiketi), findsNothing);
    expect(find.text(karaListeyeEkleEtiketi), findsNothing);

    await kapat(tester);
  });

  testWidgets('KURYE: telefon MASKELİ gösterilir', (tester) async {
    // Maskeleme ayrı bir testte: yukarıdaki iki iddia "eylem çizilmesin" der, bu ise VERİNİN
    // kendisini korur. Eylemleri gizleyip numarayı açıkta bırakmak, KVKK açısından kapıyı
    // kapatıp pencereyi açık bırakmaktır (BRIEF kırmızı çizgi #4).
    final telefon = await kartiAc(tester, cagriGunluguAcikKurye);

    expect(find.textContaining('***'), findsWidgets);
    expect(find.text(telefon), findsNothing, reason: 'ham numara ekranda geçmez');

    await kapat(tester);
  });
}
