<!DOCTYPE html>
<html lang="tr">
<head>
    <meta charset="utf-8">
    <meta name="viewport" content="width=device-width, initial-scale=1">
    <title>Sipario Yönetim Paneli</title>
    <x-favicon />
    <style>
        body { font-family: system-ui, sans-serif; margin: 0; background: #f6f7f9; color: #1a1a1a; }
        main { max-width: 1100px; margin: 1.5rem auto; padding: 0 1rem; }
        table { width: 100%; border-collapse: collapse; background: #fff; }
        th, td { text-align: left; padding: .6rem .8rem; border-bottom: 1px solid #e5e7eb; }
        .card { background: #fff; border: 1px solid #e5e7eb; border-radius: 8px; padding: 1rem 1.2rem; }
        button { padding: .4rem .8rem; margin: .2rem .2rem 0 0; cursor: pointer; }
        .status { font-size: .8rem; padding: .1rem .5rem; border-radius: 4px; background: #eef; }
        a { color: #2563eb; text-decoration: none; }
        .err { color: #b91c1c; font-size: .85rem; }
        .hint { color: #6b7280; font-size: .85rem; margin: .2rem 0 .8rem; }

        /* Üst gezinme — yalnız oturum açıkken çizilir (giriş ekranında bağlantı gösterilmez). */
        .topbar { background: #fff; border-bottom: 1px solid #e5e7eb; }
        .topbar .inner { max-width: 1100px; margin: 0 auto; padding: .7rem 1rem; display: flex;
            align-items: center; gap: 1.2rem; }
        .topbar .brand { font-weight: 600; }
        .topbar .spacer { flex: 1; }
        .topbar a.on { font-weight: 600; text-decoration: underline; }

        /* Genel Bakış panosu */
        .metrics { display: flex; flex-wrap: wrap; gap: .8rem; margin-top: 1rem; }
        .metric { flex: 1 1 140px; display: flex; flex-direction: column; gap: .15rem; }
        .metric-label { font-size: .8rem; color: #6b7280; }
        .metric-value { font-size: 1.8rem; font-weight: 600; line-height: 1.1; }
        .metric-note { font-size: .75rem; color: #9ca3af; }
        .chart { width: 100%; height: 120px; display: block; }
        .chart-axis { display: flex; font-size: .7rem; color: #6b7280; text-align: center; }

        /* Bayi detayı sekmeleri */
        .tabs { display: flex; flex-wrap: wrap; gap: .3rem; margin: 1rem 0 .8rem; }
        .tabs .tab { background: #fff; border: 1px solid #e5e7eb; border-radius: 6px; }
        .tabs .tab.on { background: #2563eb; border-color: #2563eb; color: #fff; }
        .tab-adet { font-size: .75rem; opacity: .7; }
        .pager { display: flex; align-items: center; gap: .8rem; margin-top: .8rem; }
        .pager .hint { margin: 0; }
        .detay { font-size: .9rem; }
        label { margin-right: .8rem; }

        /* Formlar ve bildirimler */
        .form { background: #f9fafb; border: 1px solid #e5e7eb; border-radius: 6px;
            padding: .8rem 1rem; margin: .8rem 0; }
        .form h3 { margin: 0 0 .5rem; font-size: 1rem; }
        .form p { margin: .5rem 0; }
        input[type=text], input[type=search], input[type=date], input[type=number], select {
            padding: .35rem .5rem; border: 1px solid #d1d5db; border-radius: 4px; font: inherit; }
        .bildirim { padding: .6rem .9rem; border-radius: 6px; margin: .8rem 0; }
        .bildirim-ok { background: #ecfdf5; border: 1px solid #a7f3d0; color: #065f46; }
        .bildirim-hata { background: #fef2f2; border: 1px solid #fecaca; color: #991b1b; }
    </style>
    @livewireStyles
</head>
<body>
    @auth('admin')
        <nav class="topbar">
            <div class="inner">
                <span class="brand">Sipario Panel</span>
                <a href="{{ route('panel.dashboard') }}" @class(['on' => request()->routeIs('panel.dashboard')])>Genel Bakış</a>
                <a href="{{ route('panel.tenants') }}" @class(['on' => request()->routeIs('panel.tenants')])>Bayiler</a>
                <a href="{{ route('panel.audit') }}" @class(['on' => request()->routeIs('panel.audit')])>Denetim</a>
                @if (auth('admin')->user()->isSuperadmin())
                    <a href="{{ route('panel.admins') }}" @class(['on' => request()->routeIs('panel.admins')])>Hesaplar</a>
                @endif
                <span class="spacer"></span>
                <span class="status">
                    {{ auth('admin')->user()->name }}
                    &middot; {{ auth('admin')->user()->isSuperadmin() ? 'süper yönetici' : 'destek' }}
                </span>
                <form method="POST" action="{{ route('panel.logout') }}">@csrf<button type="submit">Çıkış</button></form>
            </div>
        </nav>
    @endauth
    <main>{{ $slot }}</main>
    @livewireScripts
</body>
</html>
