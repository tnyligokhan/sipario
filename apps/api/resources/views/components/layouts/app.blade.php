<!DOCTYPE html>
<html lang="tr">
<head>
    <meta charset="utf-8">
    <meta name="viewport" content="width=device-width, initial-scale=1">
    <title>Sipario Yönetim Paneli</title>
    <style>
        body { font-family: system-ui, sans-serif; margin: 0; background: #f6f7f9; color: #1a1a1a; }
        main { max-width: 900px; margin: 2rem auto; padding: 0 1rem; }
        table { width: 100%; border-collapse: collapse; background: #fff; }
        th, td { text-align: left; padding: .6rem .8rem; border-bottom: 1px solid #e5e7eb; }
        .card { background: #fff; border: 1px solid #e5e7eb; border-radius: 8px; padding: 1rem 1.2rem; }
        button { padding: .4rem .8rem; margin: .2rem .2rem 0 0; cursor: pointer; }
        .status { font-size: .8rem; padding: .1rem .5rem; border-radius: 4px; background: #eef; }
        a { color: #2563eb; text-decoration: none; }
        .err { color: #b91c1c; font-size: .85rem; }
    </style>
    @livewireStyles
</head>
<body>
    <main>{{ $slot }}</main>
    @livewireScripts
</body>
</html>
