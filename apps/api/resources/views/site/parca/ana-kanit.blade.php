{{--
    Ana sayfa · sayısal kanıt şeridi (09-sw-ana.jsx · KanitBlm).

    ⚠️ BU BÖLÜMÜN İÇERİĞİ TEMSİLİDİR — GERÇEK ÖLÇÜM DEĞİLDİR.
    Rakamlar site/parca/_temsili-veri.php'den gelir; gerekçe ve yayın öncesi zorunluluk o dosyanın
    başında yazılı. Dizi boşaltılırsa bölüm sayfadan tamamen düşer (aşağıdaki koruma).
--}}
@if (! empty($tmsl['kanit']))
    <section class="blm kisa kanit-blm">
        <div class="kap kanit-grid">
            @foreach ($tmsl['kanit'] as $k)
                <div class="kanit">
                    <span class="rakam">{{ $k['v'] }}</span>
                    <span class="kanit-b mn">{{ $k['b'] }}</span>
                    <p class="kucuk">{{ $k['a'] }}</p>
                </div>
            @endforeach
        </div>
    </section>
@endif
