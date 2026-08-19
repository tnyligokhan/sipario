{{--
    legal.deger — hukuk metinlerinde ŞİRKET KÜNYESİ değerini basar.

    NEDEN AYRI BİR BİLEŞEN: künye (`config('subscription.company')`) bugün hâlâ köşeli parantezli
    yer tutucu taşıyor — şirket kurulmadı, banka hesabı açılmadı. Bu değerlerin hukuk metninde iki
    yanlış davranışı vardır ve bileşen ikisini de kapatır:

      1. UYDURMAK. Bir MERSİS numarası ya da IBAN "gerçekçi" görünsün diye yazılamaz; mesafeli
         satış sözleşmesindeki satıcı künyesi yanlışsa sözleşme bir belge olmaktan çıkar.
      2. SESSİZCE GİZLEMEK. Sitenin pazarlama sayfalarında yer tutucuyu GİZLEMEK doğru karardı
         (SiteIcerikTest bunu kilitliyor) — orada eksik künye "yarım kalmış site" görüntüsü
         veriyordu. Hukuk metninde ise TERSİ doğrudur: eksik künye GÖRÜNMELİDİR. Mevzuatın
         zorunlu kıldığı bir alanın boş olduğu, belgeyi yayına alacak insanın gözüne batmalı.

    Bu yüzden bileşen: değer gerçekse düz basar; yer tutucuysa göze çarpan bir "DOLDURULACAK"
    işareti basar ve belge sayfası bu işaretleri sayıp en üstte bir özet uyarı gösterir
    (bkz. legal/show.blade.php).

    ── KULLANIM ────────────────────────────────────────────────────────────────────────────
        anahtar="title"                      → config'ten okur, gerçekse düz basar
        anahtar="mersis" ad="MERSİS numarası" → eksikse bu adla uyarır
        ad="Yetkili mahkeme"                  → config karşılığı yok, her zaman eksik sayılır

    ⚠️ BELGE BAŞLIĞINDA İKİ ŞEY YASAK — ikisi de bu dosyada bizzat yaşandı (2026-08-19):

      1. İÇ İÇE BLADE YORUMU. Blade yorumları iç içe GEÇMEZ: ayrıştırıcı ilk kapanış dizisini
         gördüğü yerde DIŞ yorumu da kapatır. O andan sonraki satırlar yorum değil, GERÇEK
         İŞARETLEMEDİR.
      2. BİLEŞENİN KENDİ ETİKETİNİ ÖRNEK OLARAK YAZMAK. Yukarıdaki kusurla birleşince örnek
         satırlar gerçek çağrıya dönüşür ve bileşen kendi gövdesinden kendini çağırır: sonsuz
         özyineleme, "Allowed memory size exhausted", 500.

    Bu yüzden yukarıdaki kullanım örnekleri açı parantezsiz, yalnız öznitelik olarak yazılıdır.
--}}
@props([
    // config('subscription.company') içindeki anahtar. Yoksa alan config'te hiç yaşamıyordur
    // (ör. yetkili mahkeme) ve her hâlükârda doldurulacak olarak basılır.
    'anahtar' => null,
    // İnsan okunur alan adı — eksik uyarısında görünür. Verilmezse anahtarın kendisi kullanılır.
    'ad' => null,
])
@php
    $sirket = config('subscription.company');
    $deger = $anahtar !== null ? ($sirket[$anahtar] ?? null) : null;

    // Yer tutucu ölçütü SİTE İLE AYNI: köşeli parantezle başlayan değer gerçek değildir
    // (config'in kendi belge başlığı bu kuralı yazıyor). İkinci bir ölçüt tanımlamak, iki yerin
    // farklı zamanlarda "gerçek"e geçmesi demek olurdu.
    $eksik = $deger === null || $deger === '' || str_starts_with((string) $deger, '[');
    $etiket = $ad ?? ($anahtar ?? 'bilgi');
@endphp
@if ($eksik)<mark class="doldur" data-doldur title="Yayına almadan önce doldurulmalı">DOLDURULACAK: {{ $etiket }}</mark>@else{{ $deger }}@endif
