{{--
    FAVICON KÜMESİ — <head> taşıyan HER düzen bunu basar.

    ⚠️ NEDEN TEK BİR BİLEŞEN (2026-09-01'de ölçüldü): dört ayrı düzen vardı ve favicon yalnız
    ikisinde tanımlıydı; yönetim paneli ile Livewire paneli sekmede boş simgeyle açılıyordu.
    Daha kötüsü, işaret edilen `public/favicon.ico` SIFIR BAYTTI — yani tanımlı olan iki
    düzende de tarayıcı hiçbir şey çizemiyordu. Dosya adlarını dört yere kopyalamak bu ayrışmayı
    tekrar üretirdi; tek kaynak burasıdır.

    Adresler `Varlik::url()` ile damgalanır: favicon tarayıcının en agresif önbelleklediği
    varlıktır ve damgasız bir adres, marka değiştiğinde eski simgeyi aylarca ekranda tutar
    (aynı ders `css/site.css`te ödendi).

    `android-chrome-*.png` BURADA YOK — onları `site.webmanifest` bildirir, iki yerde saymak
    ayrışma üretir.
--}}
<link rel="icon" href="{{ \App\Support\Varlik::url('favicon.ico') }}" sizes="any">
<link rel="icon" type="image/png" sizes="32x32" href="{{ \App\Support\Varlik::url('favicon-32x32.png') }}">
<link rel="icon" type="image/png" sizes="16x16" href="{{ \App\Support\Varlik::url('favicon-16x16.png') }}">
<link rel="apple-touch-icon" href="{{ \App\Support\Varlik::url('apple-touch-icon.png') }}">
<link rel="manifest" href="{{ \App\Support\Varlik::url('site.webmanifest') }}">
