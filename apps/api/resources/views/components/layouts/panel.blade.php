{{--
    Yönetim paneli için Livewire tam-sayfa yerleşimi. mevcut layouts/app.blade.php'ye
    dokunulmadı — bu yepyeni bir dosya (site tarafı app.blade.php'yi kullanmaya devam eder).

    Kullanım — Livewire bileşeninde:
        #[Layout('components.layouts.panel')]
        #[Title('Üyeler')]
        class Uyeler extends Component { ... }
    veya render() içinde: return view('livewire.panel.uyeler')->layout('components.layouts.panel');

    Yalnız kabuk (head/css/script) sağlar; kenar çubuğu YOK — onu isteyen ekran kendi
    view'inde <x-panel.layout> ile açar (bkz. o dosyanın belge başlığı). Böylece giriş
    ekranı gibi kenar çubuksuz sayfalar da bu kabuğu kullanabilir.
--}}
<!DOCTYPE html>
<html lang="tr">
<head>
    <meta charset="utf-8">
    <meta name="viewport" content="width=device-width, initial-scale=1">
    <title>{{ $title ?? 'Sipario Yönetim Paneli' }}</title>
    <link rel="stylesheet" href="{{ asset('css/panel.css') }}">
    @livewireStyles
</head>
<body>
    {{ $slot }}
    <x-panel.tost />
    @livewireScripts
</body>
</html>
