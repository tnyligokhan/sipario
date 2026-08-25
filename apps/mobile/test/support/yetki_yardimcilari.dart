// Ekran testlerinin ROL YETKİSİ dili.
//
// NEDEN VAR (2026-08-13): `CustomerDetailScreen`, `CustomerListScreen`, `BorclularEkrani` ve
// `AyarlarEkrani` yetkiyi ZORUNLU alana çevirdi. Öncesinde alan nullable'dı ve "null → tam yetki"
// diye belgelenmişti; o geçirgen varsayılan üründe bir yetki genişlemesine dönüştü (Ayarlar →
// Çağrı Geçmişi yolundan giren kurye yönetici eylemlerine erişiyordu). Testler de aynı
// varsayılana yaslanıyordu — 25 çağrı yeri yetkiyi hiç geçmiyordu.
//
// Bu dosya o 25 yerin ortak cevabıdır: "bu test tam yetkili yöneticiyi kuruyor" cümlesini TEK
// yerde, gerekçesiyle söyler.

import 'package:sipario/screens/team.dart';

/// Tam yetkili YÖNETİCİ görünümü — rol kapısını konu etmeyen ekran testlerinin varsayılanı.
///
/// ⚠️ `RolYetkileri.tumu` KULLANILMAZ ve bu fark önemlidir: o sabit `telefonMaskeleme: true`
/// taşır, oysa maskeleme bir YETKİ DEĞİL KISITTIR. "Hepsi açık" niyetiyle `tumu` geçen bir test,
/// istemeden telefonu MASKELİ gösteren bir görünüm kurar — yani kastettiği yöneticiyi değil
/// kısıtlanmış bir kuryeyi. `yetkiler()` gerçek kuralı çalıştırır ve yöneticide maskelemeyi
/// kapalı üretir.
///
/// Bu değer, alan zorunlu olmadan ÖNCEKİ davranışı birebir korur: eski kodda tüm okumalar
/// `?? true` (izinli), maskeleme ise `?? false` (maskesiz) varsayıyordu — yöneticinin yetki
/// kümesi tam olarak budur. Yani testlerin niyeti değişmedi, yalnız açıkça yazıldı.
///
/// Rol kapısını SINAYAN testler bunu kullanmaz; kendi kümesini kurar
/// (ör. `yetkiler(rol: 'kurye', atamaHedefiVar: true, izin: ...)`).
final RolYetkileri tamYetki = yetkiler(rol: 'patron', atamaHedefiVar: true);
