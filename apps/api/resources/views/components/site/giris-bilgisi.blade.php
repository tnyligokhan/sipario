{{--
    GİRİŞ KİMLİĞİ — firma kodu + kullanıcı adı, ikisi de kopyalanabilir.

    NEDEN BİLEŞEN: aynı iki bilgi İKİ AYRI ekranda gösteriliyor (kayıt başarı ekranı ve hesap
    panelindeki genel bakış) ve ikisinin farklı görünmesi ya da birinin sonradan güncellenmemesi
    gerçek bir risk — bayi "kayıtta gördüğüm ad bu muydu" sorusunu iki farklı ekrana sorabilmeli
    ve aynı cevabı almalı.

    PAROLA BURADA YOK ve olamaz: parolayı saklamıyoruz (bcrypt), gösterebileceğimiz bir şey de
    yok. Bunu bilmeyen bir okuyucu "parola da eklensin" diye düşünebilir; eklenemez.
--}}
@props(['kod', 'kullanici'])

<div class="giris-kimlik">
    <div class="giris-k" x-data="kopyalaKutusu(@js((string) $kod))">
        <span class="mn giris-k-e">Firma kodu</span>
        <span class="kod-v">{{ $kod }}</span>
        <button type="button" class="dg dg-d gk" @click="kopyala('Firma kodu kopyalandı')">
            <x-site.ikon ad="kopyala" boy="15" kalin="2" />Kopyala
        </button>
    </div>

    <div class="giris-k" x-data="kopyalaKutusu(@js((string) $kullanici))">
        <span class="mn giris-k-e">Kullanıcı adı</span>
        <span class="kod-v">{{ $kullanici }}</span>
        <button type="button" class="dg dg-d gk" @click="kopyala('Kullanıcı adı kopyalandı')">
            <x-site.ikon ad="kopyala" boy="15" kalin="2" />Kopyala
        </button>
    </div>
</div>
