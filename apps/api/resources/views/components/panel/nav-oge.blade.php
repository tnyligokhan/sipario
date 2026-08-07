{{--
    Kenar çubuğu nav öğesi. Kit listesinde ayrıca istenmedi ama layout.blade.php'nin
    "nav öğeleri slot ile gelsin, secili durumu request()->routeIs() ile" şartını
    dolduran yardımcı budur. Orijinal tasarımda <button onClick={setRota}> idi; burada
    çoklu sayfa yönlendirmesi olduğu için gerçek <a href> — CSS'e küçük bir hover
    düzeltmesi eklendi (panel.css'te "KİT EKLERİ" bloğuna bak).
    Kullanım:
    <x-panel.nav-oge route="panel.dashboard" ikon="panel">Dashboard</x-panel.nav-oge>
    route: routeIs() ile eşleştirilecek route adı (joker: "panel.tenants.*" gibi alt
    rotaları da kapsaması için otomatik ".*" de denenir).
--}}
@props(['route', 'ikon'])

@php
    $secili = request()->routeIs($route) || request()->routeIs($route . '.*');
@endphp
<a
    href="{{ route($route) }}"
    class="yk-item @if ($secili) secili @endif"
    @if ($secili) aria-current="page" @endif
>
    <x-panel.ikon :ad="$ikon" boy="17" />
    {{ $slot }}
</a>
