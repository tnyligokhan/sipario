{{--
    Oturum açmış ekranların iskeleti: kenar çubuğu (.yk) + gövde (.yg > .yg-ic).
    $slot ZATEN .yg-ic içine sarılır — ekranlar kendi içinde tekrar .yg-ic AÇMASIN,
    doğrudan <x-panel.ust>, <x-panel.kart> vb. ile başlasın.

    Kullanım (bir Livewire bileşeninin view'i):
    <x-panel.layout>
        <x-slot:nav>
            <x-panel.nav-oge route="panel.dashboard" ikon="panel">Dashboard</x-panel.nav-oge>
            <x-panel.nav-oge route="panel.tenants" ikon="uyeler">Üyeler</x-panel.nav-oge>
        </x-slot:nav>
        <x-slot:altNav>
            <form method="POST" action="{{ route('panel.logout') }}">
                @csrf
                <button type="submit" class="yk-item yk-cikis"><x-panel.ikon ad="cikis" boy="17" /> Çıkış</button>
            </form>
        </x-slot:altNav>

        <x-panel.ust baslik="Dashboard" alt="4 Ağustos 2026 Salı" />
        ...
    </x-panel.layout>

    Giriş ekranı (oturum yok) bu bileşeni HİÇ kullanmaz — .giris-sahne'yi doğrudan basar.
    Login screen'de layout kullanmayarak kenar çubuğunu gizlemiş oluruz.
--}}
@props(['baslik' => 'Sipario', 'etiket' => 'Yönetim'])

<div class="yp">
    <aside class="yk">
        <div class="yk-logo">
            <img class="yk-mark" src="{{ \App\Support\Varlik::url('android-chrome-192x192.png') }}" alt="" width="30" height="30">
            <div>
                <div class="yk-ad">{{ $baslik }}</div>
                <div class="yk-tag">{{ $etiket }}</div>
            </div>
        </div>
        <nav class="yk-nav">
            {{ $nav }}
        </nav>
        @isset($altNav)
            <div class="yk-alt">{{ $altNav }}</div>
        @endisset
    </aside>
    <main class="yg">
        <div class="yg-ic">
            {{ $slot }}
        </div>
    </main>
</div>
