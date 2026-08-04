{{--
    PANELİN TEK NAVİGASYON KAYNAĞI. Yedi ekran aynı kenar çubuğunu çizer; liste tek yerde durmazsa
    yeni bir ekran eklendiğinde bazı sayfalarda görünür bazılarında görünmez olur.

    İki bölümü var çünkü <x-panel.layout>'un iki slotu var (nav + altNav) ve Blade bileşen SLOTLARI
    DERLEME ZAMANINDA çözülür — bir @include'un içinden <x-slot:...> yazılamaz. Bu yüzden tek dosya,
    $bolum ile ikiye ayrılır:
        <x-slot:nav>@include('livewire.panel._nav', ['bolum' => 'nav'])</x-slot:nav>
        <x-slot:altNav>@include('livewire.panel._nav', ['bolum' => 'alt'])</x-slot:altNav>
--}}
@php($bolum = $bolum ?? 'nav')

@if ($bolum === 'nav')
    <x-panel.nav-oge route="panel.dashboard" ikon="panel">Dashboard</x-panel.nav-oge>

    {{-- ÜYELER elle yazıldı, <x-panel.nav-oge> ile DEĞİL. Sebep: bileşen seçili durumu
         request()->routeIs($route) ile bulur, ama bayi detayının route adı `panel.tenant`
         (tekil) ve listeninki `panel.tenants` — biri diğerinin ön eki değil. Detaydayken
         "Üyeler" sönük kalırdı. `panel.tenant*` jokeri dördünü de (liste, detay, içe/dışa
         aktarım) kapsar; bileşene bu jokeri geçiremeyiz çünkü href'i route($route) ile
         üretiyor ve `panel.tenant` {tenant} parametresi ister. --}}
    <a
        href="{{ route('panel.tenants') }}"
        class="yk-item @if (request()->routeIs('panel.tenant*')) secili @endif"
        @if (request()->routeIs('panel.tenant*')) aria-current="page" @endif
    >
        <x-panel.ikon ad="uyeler" boy="17" /> Üyeler
    </a>

    <x-panel.nav-oge route="panel.payments" ikon="odemeler">Ödemeler</x-panel.nav-oge>
    <x-panel.nav-oge route="panel.packages" ikon="kutu">Paketler</x-panel.nav-oge>
    <x-panel.nav-oge route="panel.finance" ikon="gelirgider">Gelir-Gider</x-panel.nav-oge>

    {{-- Tasarımın NAV listesinde YOKtu; eklendi. Bildirimler bayinin siteden yaptığı havale
         beyanlarının kuyruğudur — navigasyonda görünmezse o kuyruğa girecek tek kapı
         Dashboard'daki kart olurdu ve panoyu atlayan kullanıcı beyanları hiç görmezdi. --}}
    <x-panel.nav-oge route="panel.notifications" ikon="uyari">Bildirimler</x-panel.nav-oge>
    <x-panel.nav-oge route="panel.audit" ikon="belge">Denetim</x-panel.nav-oge>

    {{-- Hesaplar YALNIZ superadmin'e gösterilir: ekranın kendisi zaten mount'ta 403 veriyor,
         herkese görünen bir bağlantı destek ekibini kapalı bir kapıya yollardı. Gizlemek yetki
         denetimi DEĞİLDİR — denetim bileşenin içindedir, bu yalnız gürültü azaltmasıdır. --}}
    @if (auth('admin')->user()?->isSuperadmin())
        <x-panel.nav-oge route="panel.admins" ikon="kilit">Hesaplar</x-panel.nav-oge>
    @endif
@else
    <form method="POST" action="{{ route('panel.logout') }}">
        @csrf
        <button type="submit" class="yk-item yk-cikis">
            <x-panel.ikon ad="cikis" boy="17" /> Çıkış
        </button>
    </form>
@endif
