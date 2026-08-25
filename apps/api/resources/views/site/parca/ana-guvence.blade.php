{{-- Ana sayfa · Güvenceler (09-sw-ana.jsx · GuvenceBlm). Koyu bölüm. --}}
<section class="blm gece guvence-blm">
    <div class="kap">
        {{--
            İki kez sadeleşti. Önce "İşin durursa defter de durur. O yüzden durmuyor." vardı;
            sonra "Sipario durursa işiniz durur. O yüzden durmayacak şekilde kurduk." oldu —
            ikisi de aynı reklam kalıbını (A. O yüzden B.) sürdürüyordu ve sayfada bu kalıp
            üç ayrı başlıkta tekrarlanıyordu.

            Alt açıklama ("Aşağıdaki dördü bir özellik listesi değil, verdiğimiz sözler.")
            tamamen silindi: metnin kendi türünü açıklaması, okura hiçbir bilgi vermeyen bir
            iç sestir. Dört kart zaten söz gibi yazılmış; onlara "bunlar sözdür" demek gerekmiyor.
        --}}
        {{-- "Merak ettikleriniz." denemişti; hemen altındaki bölüm "Sık sorulanlar" olduğu için
             ikisi aynı işi vaat ediyordu. Bu bölüm soru cevaplamıyor, SÖZ VERİYOR. --}}
        <x-site.blm-bas baslik="Verdiğimiz sözler" />
        <div class="guvence-grid">
            @foreach ($sw['guvence'] as $g)
                <div class="guvence">
                    <span class="guvence-ik"><x-site.ikon :ad="$g['ik']" boy="22" kalin="1.9" renk="#B3A6FF" /></span>
                    <h3 class="h3">{{ $g['t'] }}</h3>
                    <p class="gvd">{{ $g['a'] }}</p>
                </div>
            @endforeach
        </div>
    </div>
</section>
