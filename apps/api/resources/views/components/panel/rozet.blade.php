{{--
    Kullanım: <x-panel.rozet durum="trial" /> veya <x-panel.rozet :durum="$tenant->status" />
    durum: App\Enums\TenantStatus (backed enum) VEYA onun ->value'su olan string, ikisi de kabul edilir.
    Tasarımda 4 durum vardı, sunucuda 5:
    trial→Deneme, active→Aktif, suspended→Askıda, cancelled→İptal, locked→Süresi doldu (yeni).
--}}
@props(['durum'])

@php
    $anahtar = $durum instanceof \BackedEnum ? $durum->value : (string) $durum;
    $eslesme = [
        'trial' => ['ad' => 'Deneme', 'sinif' => 'deneme'],
        'active' => ['ad' => 'Aktif', 'sinif' => 'aktif'],
        'suspended' => ['ad' => 'Askıda', 'sinif' => 'askida'],
        'cancelled' => ['ad' => 'İptal', 'sinif' => 'iptal'],
        'locked' => ['ad' => 'Süresi doldu', 'sinif' => 'kilitli'],
    ];
    $d = $eslesme[$anahtar] ?? ['ad' => $anahtar, 'sinif' => 'iptal'];
@endphp
<span {{ $attributes->merge(['class' => 'rozet ' . $d['sinif']]) }}>{{ $d['ad'] }}</span>
