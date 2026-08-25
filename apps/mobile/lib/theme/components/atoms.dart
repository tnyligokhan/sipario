// Sipario paylaşılan ATOMLAR — toplayıcı (barrel) dosya.
//
// tasarımın Sipario.html CSS'inin birebir Flutter karşılıkları. Bileşenler konuya göre ayrı
// dosyalarda yaşar (500 satır sınırı); ekranlar tek bir `atoms.dart` import'uyla hepsine erişir.
// Bir bileşenin kaynak CSS sınıfı kendi dosyasındaki başlıkta yazar.
//
// KURAL: ekranlar ham renk/punto YAZMAZ. Bir şey burada yoksa ya buraya eklenir ya da
// jetonlardan (context.sip) kurulur.

export 'bicim.dart'; // sipTutar · sipSayi · sipTelefon · trBuyuk · trKucuk
export 'dokunma.dart'; // SipDokun · SipButon · SipMetinButon · SipIkonButon
export 'form.dart'; // SipInputOlcu · SipFormEtiket · SipInput · SipArama · SipSegment · SipToggle · SipKnob · SipOnayKutusu
export 'rozetler.dart'; // SipPil · SipDurumPili · SipBakiyeCipi · SipAvatar · SipIkonKutu
export 'yerlesim.dart'; // SipKart · SipBolumBaslik · SipNotKutusu
