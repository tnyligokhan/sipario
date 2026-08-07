<?php

/*
 * CANLI KONUM — tazelik eşikleri SUNUCUDA.
 *
 * NEDEN SUNUCUDA: "taze mi" kararı istemcide verilseydi her cihaz kendi (yanlış olabilen) saatine
 * göre karar verir ve iki patron aynı listeye bakıp farklı sonuç görürdü. Kalp atışının damgası
 * zaten sunucu saatidir; kıyası da aynı saatin yapması gerekir. İstemci `is_fresh` bayrağını
 * OKUR, hesaplamaz.
 *
 * İKİ EŞİK, İKİ AYRI SORU:
 *  - taze_dakika  → "bu nokta ŞU AN güvenilir mi?" Değilse satır listede kalır ama soluk gösterilir
 *    (patron kuryenin uygulamayı arka plana attığını görmeli; satırın kaybolması "yok" demek olur).
 *  - liste_dakika → "bu nokta artık BİLGİ Mİ?" Değilse satır hiç dönmez. Bu bir gizlilik sınırıdır,
 *    kozmetik değil: eve gitmiş bir çalışanın saatler önceki son konumu haritada durmamalı.
 */
return [
    // Dakika. Kalp atışı aralığının birkaç katı olacak şekilde seçildi: tek bir atışın ağ
    // yüzünden düşmesi satırı hemen "bayat" göstermemeli.
    'taze_dakika' => (int) env('KONUM_TAZE_DAKIKA', 3),

    // Dakika. Bu yaştan eski satır canlı listeye HİÇ girmez (satır DB'de durur, bir sonraki
    // kalp atışında ezilir — silme işi ayrı bir temizlik değil, upsert'in doğal sonucudur).
    'liste_dakika' => (int) env('KONUM_LISTE_DAKIKA', 60),

    // Kalp atışı hız sınırı: kullanıcı başına dakikada kaç atış. Uygulama ~30 sn'de bir bildirir
    // (2/dk); 6 tekrar denemelere ve ekran açılışındaki ilk atışa pay bırakır, ama bozuk bir
    // istemci döngüsünün tabloya saniyede onlarca yazmasını engeller.
    'kalp_atisi_limit' => (int) env('KONUM_KALP_ATISI_LIMIT', 6),
];
