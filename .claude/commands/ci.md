---
name: ci
description: CI durumu — son koşumlar, saha APK'sının yayınlanmış sürümü ve bekleyen iş var mı
---

# CI durumu

Aşağıdaki üç soruyu tek seferde cevapla ve KISA bir özet yaz. Uzun log dökme.

## 1) Yerelde bekleyen iş var mı

```bash
git status --short
git log --oneline -1
git rev-list --left-right --count origin/dev...dev
```

- Ağaç kirliyse: değişiklikler **henüz commit edilmedi** → CI hiç başlamamıştır.
  Sebebi genelde kalite kapısının kırmızı olmasıdır (`dart analyze` + `flutter test`).
- `origin/dev...dev` sayısı `0 1` gibiyse: commit var ama **push gitmemiş**.

## 2) Son koşumlar

```bash
gh run list --limit 5
```

- `saha-apk` → telefona giden APK'yı derleyen hat (yalnız `apps/mobile/**` dokunulunca koşar).
- `API CI` → sunucu testleri.
- Koşum sürüyorsa (`in_progress`) kalan süreyi söyle: saha-apk tipik olarak **8-9 dakika**.

## 3) Telefonun göreceği sürüm

```bash
git rev-list --count HEAD
curl -s -L "https://github.com/tnyligokhan/sipario/releases/download/saha/surum.json?t=$(date +%s)"
```

**Sorgu parametresi ŞART** — düz adres GitHub CDN'inden saatlerce bayat cevap dönebiliyor
(2026-07-29'da ölçüldü: `X-Cache: HIT`, yayından 9 saat eski içerik). Parametresiz bakıp
"yayınlanmamış" demek yanlış teşhistir.

Karşılaştır:
- `surum.json`daki `yapim` == `git rev-list --count HEAD` → **telefon güncel olabilir**.
- `yapim` küçükse → CI ya koşuyor ya da hiç tetiklenmemiştir (mobil dosya değişmediyse normaldir).

## Bir koşumu izlemek

Kullanıcı "bitince haber ver" derse:

```bash
gh run watch <run-id> --exit-status
```

Bunu arka planda çalıştır, bitince sonucu ve yeni `yapim` numarasını bildir.
