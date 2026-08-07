{{--
    Ana sayfa · Müşteri yorumları (09-sw-ana.jsx · YorumBlm).

    ⚠️ BU BÖLÜMÜN İÇERİĞİ TEMSİLİDİR — KİŞİLER, İŞLETMELER VE SÜRELER UYDURMADIR.
    Yorumlar site/parca/_temsili-veri.php'den gelir; gerekçe ve yayın öncesi zorunluluk o dosyanın
    başında yazılı. Dizi boşaltılırsa bölüm sayfadan tamamen düşer (aşağıdaki koruma).
--}}
@if (! empty($tmsl['yorum']))
    <section class="blm">
        <div class="kap">
            <x-site.blm-bas kulak="Kullananlar" baslik="Rakamı değişen işletmeler." />
            <div class="yorum-grid">
                @foreach ($tmsl['yorum'] as $y)
                    <figure class="yorum">
                        <span class="yorum-t"><x-site.ikon ad="tirnak" boy="22" kalin="1.8" renk="var(--mor)" /></span>
                        <blockquote class="h3 yorum-s">{{ $y['s'] }}</blockquote>
                        <figcaption>
                            <b>{{ $y['k'] }}</b>
                            <span class="kucuk">{{ $y['r'] }}</span>
                            <span class="mn k yorum-m">{{ $y['m'] }}</span>
                        </figcaption>
                    </figure>
                @endforeach
            </div>
        </div>
    </section>
@endif
