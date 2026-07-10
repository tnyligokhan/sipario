# BRIEF.md — Sipario

## Rolün
Sen bu projenin mimarı ve geliştiricisisin. Teknoloji seçimini, veritabanı şemasını, API tasarımını, mimariyi ve yol haritasını sen kurarsın. Aşağıdaki kırmızı çizgiler dışında her teknik karar senindir.

## Çalışma düzeni — tek onay kapısı
**Kapı:** Bu brief'i okuduktan sonra ilk çıktın bir **plan** olsun: teknoloji seçimi + gerekçesi, veri modelinin ana hatları, mimari yaklaşım (özellikle offline çalışma ve senkron stratejisi), kiracı izolasyonu yaklaşımı, ve risk sırasına göre iş planı. Planı bana sun, onayımı bekle.

**Kapıdan sonra:** Onay verdikten sonra bana karar sorma. Kararını ver, uygula, ilerle. Her önemli kararı `DECISIONS.md` dosyasına tek satır gerekçesiyle yaz — denetimim orada olacak. Takıldığın yerde tahmin et, gerekçeni yaz, devam et; yanlışsa sonra düzeltiriz. İlerlemeni durdurup beni beklemek, yanlış karar vermekten daha maliyetlidir.

## Proje nedir
Türkiye'de eve servis yapan mikro esnaf (ilk hedef: su/damacana bayileri) için sipariş + veresiye defteri + kurye takibi uygulaması. Telefon çaldığında bayi müşteriyi anında tanısın, birkaç dokunuşla sipariş girsin, kurye teslim etsin, akşam kasa ve borçlar net görünsün. İnternet çekmese bile her şey çalışsın, çekince senkronlansın. İş modeli: siteden üyelik → 30 gün ücretsiz deneme → yıllık peşin abonelik (değer hissi ayda 300–500 TL). Hedef: ilk 6 ayda 20–50 ödeyen bayi. Satış çoğunlukla birebir yürür; site hem kendi gelen bayiyi karşılar hem de birebir satışın ödeme ve hesap açma kanalıdır.

## Sistemin parçaları (ne olacağı — nasıl yapılacağı sana ait)
1. **Saha uygulaması** — bayinin ve kuryenin kullandığı mobil uygulama (Android birincil, iOS de olacak). Offline çalışan asıl ürün burası.
2. **Ortak API katmanı** — bütün istemciler tek bir backend API'si üzerinden konuşur. Platforma özel backend yazılmaz. Bugün mobil var; **sonrasında bayilerin masaüstünden kullanacağı bir web uygulaması gelecek** (Paraşüt'ün web arayüzü gibi), ilerleyen dönemde Windows istemcisi de gündeme gelebilir. API bu genişlemeye bugünden açık tasarlanmalı: yeni bir istemci eklemek backend'i yeniden yazmayı gerektirmemeli. v1'de web uygulaması YAZILMAZ — yalnız yol kapatılmaz.
3. **Yönetim paneli (bize ait, müşteriye değil)** — bayileri biz açtığımız için satış ve destek buradan yürür. Yapabilmesi gerekenler:
   - Bayi (tenant) hesaplarını görme; gerektiğinde elle açma — siteden kaydolmayan, birebir satışla kazanılan bayiler için
   - Deneme süresi uzatma, yıllık abonelik kaydetme, süresi dolanı kilitleme/açma
   - Bayi bazında opsiyonel modülleri açıp kapama (ör. boş/emanet takibi)
   - Patron şifresi sıfırlama, cihaz listesi görme
   - Bayinin verisini dışa aktarma (export)
   - Kullanım istatistikleri: bayi başına günlük sipariş sayısı, sipariş girme saatleri, kurulumdan ilk arayan-tanımaya geçen süre, aktif cihazlar. Bunlar erken terk (churn) sinyalleridir; bir bayi akşamları toplu sipariş giriyorsa gün içinde uygulamayı kullanmıyor demektir ve o bayiyi kaybediyoruz.
   - **Sınır:** Panel bayinin iş verisini (sipariş, müşteri, para kaydı) değiştiremez. Yalnız hesap/abonelik yönetimi ve salt-okunur istatistik. İş verisi yalnız uygulamadan girilir.

4. **Abonelik ve ödeme sitesi** — abonelik mağaza içi satın alma ile DEĞİL, kendi sitemiz üzerinden yürür. Akış: bayi siteden üyelik açar → tenant otomatik oluşur → deneme süresi başlar (30 gün) → süre dolmadan siteden ödeme yapar → yapmazsa uygulama yazma işlemlerine kapanır. Ödeme, Türkiye'de yerleşik bir ödeme altyapısı üzerinden alınır (iyzico, PayTR, Param, Craftgate gibi adaylardan birini sen seç ve gerekçesini yaz; seçim kriterleri: yinelenen/otomatik tahsilat desteği, KVKK/veri yerleşimi, komisyon, entegrasyon kalitesi). Yıllık peşin tahsilat esastır.
   - **Abonelik durumunun tek doğru kaynağı bizim sunucumuzdur.** İstemci "abonem var mı" kararını kendi başına vermez; son bilinen durumu önbellekte tutar ve sunucuyla makul bir süre hiç konuşamazsa salt-okunura düşer (uçak modunda süresiz kullanım açığı kalmamalı).
   - **Süre dolunca (deneme veya abonelik):** kullanım durur — hangi istemciden girilirse girilsin. Mobilde nötr bir "aboneliğiniz sona erdi, destek alın" ekranı, web'de abonelik/ödeme sayfası görünür; sisteme erişim yoktur. **Ancak:** veri silinmez, sunucuda durur; cihazda sunucuya gitmemiş bekleyen kayıtlar varsa senkron çalışmaya devam eder ve bunlar sunucuya akar — kilit yazmayı durdurur, veri kaybettirmez. Abonelik alındığı an bütün eski veri olduğu gibi geri gelir.
   - **Veri rehin alınmaz:** bayi destek kanalı üzerinden her zaman verisinin dışa aktarımını talep edebilir (uygulamada buton yok, yönetim panelinde bizde var). Bayi kendi müşterilerinin verisinden KVKK önünde sorumludur; bu kapı kapalı kalamaz.
   - **Platform farkı — pazarlıksız:** Sunucuda tek bir "süresi doldu" durumu vardır ama ekranı istemciye göre değişir. Web'de fiyat, paket ve "Abone Ol" butonu gösterilir. Mobil uygulamada bunların hiçbiri gösterilemez: fiyat yok, buton yok, ödeme sitesine link yok — yalnız nötr bilgi metni.
   - **Mağaza kuralları — pazarlıksız:** Mobil uygulamada **kayıt ekranı yoktur, yalnız giriş vardır.** İçinde satın alma ekranı, fiyat listesi, "abone ol" butonu veya ödeme/kayıt sitesine yönlendiren link ya da çağrı **bulunamaz**. Apple 3.1.3(f) ve Google Play ödeme politikası bunu gerektirir; ihlali uygulamayı mağazadan attırır. Süre dolduğunda gösterilecek mesaj nötr olmalıdır (satın almaya yönlendirme değil, bilgilendirme). Üyelik, ödeme ve hesap yönetimi yalnız web sitesinde yaşar.
   - **Mağaza incelemesi:** Giriş ekranlı uygulamayı incelemeci açamazsa reddedilir. Her iki mağazanın inceleme notlarına içi dolu bir demo hesabı ve arayan-tanıma özelliğini gösteren bir video konur.
   - Yasal gereklilikler (Türkiye): mesafeli satış sözleşmesi, ön bilgilendirme formu, iptal/iade koşulları, e-arşiv fatura, KVKK aydınlatma metni ve açık rıza akışı. Bunları ürünün parçası say, sonradan eklenecek evrak sanma.

## Kullanıcının dünyası (sahadan gerçekler)
- Bayi 1–3 kişidir: patron (+belki operatör) + kurye. Teknoloji toleransı düşük, şifreler basittir. Kurulumdan sonra ~10 dakika içinde "telefon çaldı, ekranda müşteri çıktı" anını yaşamazsa uygulamayı bırakır.
- Siparişin ezici çoğunluğu telefonla gelir. Bayiler sabit hatlarını cebe yönlendirir (arayan numara korunur). Arayan tanıma bu ürünün varlık sebebidir.
- Android hâkimdir. Xiaomi/Redmi/Poco başta olmak üzere agresif pil yönetimi arka plan uygulamalarını öldürür — arayan tanımanın bir numaralı düşmanı budur. iOS'ta işletim sistemi çağrı yakalamaya izin vermez; iOS sürümü çağrı özellikleri hariç tam çalışmalıdır.
- Veresiye kültürü derindir: mal bugün teslim edilir, para çoğu zaman ay sonu toplanır. Ödeme tipleri: nakit, kart, havale/IBAN, veresiye. Kısmi ödeme ("50 ver kalanı yaz") v1'de yok — bilinçli sadelik.
- Kupon yaygındır: müşteri peşin ödeyip N damacanalık paket alır, her teslimde düşülür. İki cihaz offline'ken aynı son kuponu harcayabilir — teslim edilmiş mal gerçektir, sistem reddedemez; bakiye eksiye düşer, arayüz kırmızı gösterir, düzeltme kaydıyla kapatılır.
- Boş damacana/emanet takibi bayiden bayiye değişir — kimi ister, kimi hiç uğraşmaz. İstemeyen bayide o alanlar hiç görünmemelidir.
- Kurye sahada telefonla çalışır; kısa sinyal kesintileri (bodrum, asansör, çukur bölge) gerçektir ama kalıcı değildir. Teslim kapatma internetsiz, saniyeler içinde bitmelidir; konum alınamıyorsa teslim ASLA bloklanmaz.
- Gün sonunda kurye kasayı patrona devreder. Rakamlar bayinin elle tuttuğu defterle kuruşu kuruşuna tutmazsa ürüne güven ölür. Para kayıtları düzeltilmez, telafi kaydıyla düzeltilir — eksik para kanıt olarak görünür kalmalıdır.
- Tek kişilik bayi çoktur: "kuryeye ata" gibi adımlar tek kişilik işletmede hiç görünmemelidir.

## Kırmızı çizgiler (pazarlıksız)
1. Çok kiracılı sistemde bir bayi başka bayinin verisini ASLA göremez/değiştiremez. İzolasyonu sen tasarla ve otomatik testlerle sürekli kanıtla.
2. Para ve hareket kayıtları silinmez/ezilmez (append-only mantık); bakiyeler kayıtlardan türetilir.
3. Uygulama internetsiz TAM çalışır (okuma+yazma); bağlantı gelince otomatik senkronlanır. Beklenen kopukluk süresi kısadır — tipik olarak 10 dakika, azami birkaç saat (asansör, bodrum, sinyal çukuru); istisnaen bir gün. Kullanıcı normalde çevrimiçidir. Yine de kesinti anında hiçbir işlem engellenmez ve hiçbir kayıt kaybolmaz; senkron çakışmaları veri kaybetmeden çözülür.
4. KVKK: müşteri verisi (ad, telefon, adres, konum) Türkiye'deki sunucuda tutulur; loglara ve crash raporlarına kişisel veri yazılmaz.
5. Veri rehin alınmaz: abonelik bitse ve sistem kilitlense bile bayinin verisi silinmez, sunucuda saklanır, abonelik yenilendiğinde eksiksiz geri gelir; bayi destek kanalıyla her zaman dışa aktarım talep edebilir.
6. Google Play uyumu: Arayan tanıma **yalnız Android 10+ `CallScreeningService` ile** yapılacak. Manifest'te SMS/Call Log izin grubundan (`READ_CALL_LOG`, `PROCESS_OUTGOING_CALLS`, `READ_PHONE_STATE` vb.) hiçbir izin bulunmayacak — üçüncü parti paketlerin manifest'e eklediklerini de temizle. Sebep: bu izinler Play'in kısıtlı izin beyan formunu tetikler ve red riskini doğurur; Android 10 API'si bu izinler olmadan arayan tanımaya izin verir. Ayrıca Google'ın geliştirici doğrulama zorunluluğu APK ile doğrudan dağıtımı da kapsayacak (2027 küresel) — dağıtım stratejisi buna göre planlanmalı.

## Verilmiş kararlar (değiştirme)
- İsim: **Sipario**. Domain sipario.com.tr alındı; marka başvurusu (9/35/42 sınıfları) süreçte.
- İlk dikey su bayileri; çekirdek sektör-bağımsız kurgulanır (manav/tüpçü ileriki aday).
- Platform: Android birincil (+iOS, çağrı özellikleri hariç).
- Pilot: Antalya'da 2–3 gerçek bayi ile saha testi.

## En büyük korkularım (planını buna göre kur)
1. **Arayan tanıma güvenilirliği.** Xiaomi/Samsung/stok Android'de gelen aramada pop-up güvenilir çıkmıyorsa ürün yok demektir. Başka hiçbir şeye derinlemesine girmeden ÖNCE bunu gerçek cihazlarda kanıtla ve go/no-go kararını bana getir. (Eski hedefimiz: 20/20 aramada ≤1 sn.)
2. **Defter tutarlılığı.** İki cihaz offline çalışıp senkron olduğunda borç/kasa rakamları bozulursa esnafın güveni bir daha gelmez.
3. **Kurulum sürtünmesi.** Esnaf kuramazsa satış ölür: kurulum→ilk tanıma 10 dakikanın altında kalmalı.

## Notlar
- Ekipte Flutter/Dart ve Laravel/PHP deneyimi var; bakım bizde kalacak. Stack seçimi senin, ama bu gerçeği maliyet hesabına kat.
- Benimle Türkçe konuş; kararlarını ve gerekçelerini kısa yaz.
