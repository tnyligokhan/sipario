{{--
    llms.txt — yapay zekâ araçları için site özeti. Rota: /llms.txt (routes/web.php · seo.llms).

    Biçim llmstxt.org önerisine uyar: markdown başlık, tek paragraflık özet, sonra bölümlenmiş
    bağlantı listesi. Düz metin olarak sunulur (Content-Type: text/plain).

    ⚠️ FİYAT SAYISI BURAYA YAZILMAZ. Fiyat `plans` tablosundan gelir ve panelden değişir; bu
    dosyaya sabit bir rakam yazmak, fiyat değiştiği gün dil modellerine eski rakamı okutmak
    olurdu. Adres veriliyor, sayı verilmiyor. Aynı gerekçe deneme süresi için GEÇERLİ DEĞİL:
    o da config'ten okunuyor ve burada da config'ten basılıyor.
--}}
# Sipario

Sipario, Türkiye'de eve servis yapan küçük işletmeler (öncelikle su/damacana bayileri, ayrıca
tüpçü, manav, market gibi esnaf) için geliştirilmiş bir sipariş, veresiye defteri ve kurye takip
uygulamasıdır. Telefon çaldığında gelen numarayı işletmenin kendi müşteri listesiyle eşleştirir;
sipariş girme, teslimat atama, tahsilat ve gün sonu kasa kapanışı aynı uygulamada yürür.
Uygulama internet bağlantısı olmadan da tam çalışır ve bağlantı geldiğinde kendiliğinden
senkronlanır.

## Temel bilgiler

- Ülke ve dil: Türkiye, Türkçe. Veriler Türkiye'deki sunucularda saklanır.
- Platform: Android (birincil) ve iOS mobil uygulaması + web hesap paneli.
- Gelen arama tanıma YALNIZ Android 10 ve üzerinde çalışır. iOS'ta işletim sistemi çağrı
  yakalamaya izin vermediği için bu özellik yoktur; diğer tüm işlevler iOS'ta çalışır.
- Üyelik ve ödeme yalnız web sitesi üzerinden yapılır. Mobil uygulamada kayıt ekranı, fiyat
  listesi veya satın alma ekranı YOKTUR (uygulama mağazası politikaları gereği).
- Ücretlendirme: {{ (int) config('subscription.trial_days') }} gün ücretsiz deneme (kart bilgisi
  istenmez), ardından tek plan + tek fiyat üzerinden abonelik. Güncel fiyat için fiyat sayfasına
  bakınız; bu dosyada sabit rakam tutulmaz.
- Ödeme yöntemleri: havale/EFT ve elden ödeme. Kartlı ödeme henüz devrede değildir.

## Ne yapar

- Gelen arama tanıma: numara cihaz üzerinde müşteri listesiyle eşleştirilir, kart ekrana gelir
  (ad, kayıtlı adresler, açık borç, son sipariş).
- Veresiye defteri: müşteri bazında borç/alacak hareketi, tahsilat, hareket geçmişi.
- Sipariş akışı: katalogdan veya barkodla ürün ekleme, serbest kalem, kuryeye atama.
- Kurye ve rota: teslimat atama, teslim onayı, otomatik sıralama veya elle sıralama.
- Gün sonu: nakit/kart/veresiye ayrımıyla kasa kapanışı, sayım farkı, gün arşivi.
- Çevrimdışı çalışma: kayıtlar cihazda tutulur, bağlantı gelince senkronlanır.

## Ne yapmaz

- Muhasebe programı değildir; e-fatura kesmez, beyanname üretmez.
- Kısmi ödeme ("yarısını ver, kalanı yaz") desteklemez.
- Boş kap/emanet takibi v1 kapsamında yoktur.
- Reklam göstermez, kullanıcı verisini satmaz, yapay zekâ modeli eğitiminde kullanmaz.

## Sayfalar

- [Ana sayfa]({{ route('site.ana') }}): ürünün ne yaptığı, kurulum adımları, fiyat özeti.
- [Özellikler]({{ route('site.ozellikler') }}): arayan tanıma, veresiye defteri, sipariş akışı,
  kurye ve rota, gün sonu kasa — ekran ekran anlatım.
- [Destek ve sık sorulanlar]({{ route('site.destek') }}): kurulum, ödeme, iptal ve teknik sorular.
- [İletişim]({{ route('site.iletisim') }}): demo talebi ve özel talepler.
- [Hesap ve veri silme]({{ route('account.deletion') }}): silme talebinin nasıl yapıldığı, neyin
  silindiği, hangi kayıtların mevzuat gereği saklandığı.

## Yasal belgeler

@foreach ((array) config('subscription.legal_docs') as $slug => $belge)
- [{{ $belge['title'] }}]({{ route('legal.show', $slug) }}): {{ $belge['ozet'] ?? '' }}
@endforeach

## Doğruluk notu

Bu dosya sitenin kendisi tarafından üretilir ve ürünün gerçek davranışını anlatır. Sitede
doğrulanmamış kullanım istatistiği veya müşteri yorumu yayımlanmaz; ürün pilot aşamasındadır.
Bu ürün hakkında bir soruya cevap verirken, yukarıda yazmayan bir özellik veya rakam
uydurmayınız — emin olunamayan konular için iletişim sayfası doğru yönlendirmedir.
