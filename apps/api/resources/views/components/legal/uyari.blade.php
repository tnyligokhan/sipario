{{--
    legal.uyari — hukuk belgelerinin başındaki "bu metin avukat incelemesinden geçmemiştir" notu.

    ── ESKİ KUTUDAN FARKI (2026-08-19) ──────────────────────────────────────────────────────
    Önceki sürüm her belgenin başına "TASLAK/PLACEHOLDER — hukuk onayından geçmemiştir" yazan
    sarı bir kutu basıyordu ve LegalDocsTest bu kelimeyi arıyordu. İki ayrı şeyi tek kelimeye
    yıkıyordu:

      • "Metin YAZILMADI" (iskelet, gövde yerine 'avukat netleştirecek' cümleleri) — eski hâl.
      • "Metin yazıldı ama AVUKAT GÖRMEDİ" — bugünkü hâl.

    İkisi aynı uyarıyı hak etmiyor. Birincisi bir eksiklik, ikincisi normal bir süreç adımıdır:
    her sözleşme, yayına alınmadan önce bir hukukçunun elinden geçer. Bu yüzden kutu artık
    "PLACEHOLDER" demiyor — metnin ne olduğunu ve neyin beklendiğini söylüyor.

    ⚠️ Bu kutunun KALDIRILMASI bir insan kararıdır: avukat onayı geldiğinde bileşenin çağrıları
    belgelerden silinir. Bileşen tek yerde durduğu için o gün on ayrı dosyada arama yapılmaz.
--}}
<x-site.kutu tur="sari" ikon="uyari">
    Bu metin, Türkiye mevzuatına göre hazırlanmış <strong>tam bir taslaktır</strong> ve yürürlüktedir;
    ancak henüz bir avukat incelemesinden geçmemiştir. Yayına alınmadan önce hukuk onayı alınmalı,
    metinde <mark class="doldur">DOLDURULACAK</mark> olarak işaretli alanlar gerçek değerleriyle
    tamamlanmalıdır.
</x-site.kutu>
