// İŞLETME/YÖNETİM ekranlarının paylaşılan küçük parçaları — TOPLAYICI (barrel).
//
// Bileşenler 500 satır sınırı için `atomlar/` altına üçe bölündü; ekranlar bu tek dosyayı
// import etmeye devam eder, böylece parçalar yeniden düzenlenirken çağıran ekranlar sabit kalır.
// Buradakiler yalnız bu ekran ailesinde tekrar eder; tüm uygulamada tekrar edenler
// `lib/theme/components/atoms.dart` içindedir (oraya YAZILMAZ — başka ajanın alanı).

export 'atomlar/form_atomlari.dart';
export 'atomlar/kart_atomlari.dart';
export 'atomlar/rol_kapisi.dart';
export 'atomlar/yetki_atomlari.dart';
