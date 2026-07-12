# prompt.md — Claude Code İstem Rehberi (insan içindir, AI'a okutma)

Bu dosya sana yol göstermek için var. Claude'a okutmana gerek yok — o zaten
`CLAUDE.md`, `BRIEF.md`, `DECISIONS.md` ve `PLAN.md`'yi biliyor/okuyor.
Buradaki metinleri kopyala-yapıştır yap, kendine göre uyarla.

---

## 1. Altın kural — her yeni sohbetin İLK istemi

Sohbet geçmişi paylaşılmıyor; Claude her yeni oturumda "sıfırdan" başlar.
Ortak hafıza depodaki üç dosyadır. Bu yüzden her vardiyanın ilk istemi hep aynı:

```
Vardiyaya başlıyorum. BRIEF.md, DECISIONS.md ve PLAN.md'yi oku,
güncel durumu bana 5-6 cümleyle özetle ve PLAN.md'de "sıradaki iş"
olarak ne görünüyorsa ona başla.
```

Özet gelince kontrol et: söyledikleri PLAN.md'deki durumla uyuşuyor mu?
Uyuşuyorsa "devam" de, gerisini o götürür.

> Şu an sıradaki iş (2026-07-11 devri itibarıyla): **API güvenlik denetimi +
> düzeltmeleri** — yarım kalmıştı, kod değişikliği yapılmadı. İlk istemin şu da
> olabilir:
> ```
> Vardiyaya başlıyorum. Üç ortak hafıza dosyasını oku. PLAN.md'de yarım kaldığı
> yazan API güvenlik denetimini baştan koştur: denetçi → düzeltici → doğrulayıcı
> zinciriyle. Bulguları düzelt, 34 testin yeşil kaldığını ve yeni testler
> eklendiğini kanıtla.
> ```

---

## 2. Vardiya biterken — SON istem (asla atlama)

```
Vardiyayı kapatıyorum. PLAN.md'nin "Güncel durum" bölümünü güncelle:
ne bitti, ne yarım kaldı, sonraki kişi nereden devam etmeli, bilinen
tuzaklar neler. Önemli bir karar verdiysen DECISIONS.md'nin sonuna
tek satır ekle. Sonra commit'le ve dev'e push'la.
```

Bunu atlarsan bir sonraki vardiya (yani Gökhan ya da sen) kör başlar.

---

## 3. Senaryoya göre hazır istemler

### Hata / bug bildirirken
Ne yaptın + ne bekliyordun + ne oldu üçlüsünü ver, hata mesajını AYNEN yapıştır:

```
apps/api'de composer test koştum, DeviceRegistrationTest kırmızı.
Beklediğim: 34 test yeşil. Hata çıktısı şu: [ÇIKTIYI YAPIŞTIR]
Sebebini bul ve düzelt; düzeltince tüm testlerin yeşil olduğunu kanıtla.
```

### Yeni özellik / sıradaki faz işi
```
PLAN.md Faz 2'deki [iş adı] işine başla. Önce nasıl yapacağını 3-5 maddeyle
söyle, sonra uygula. Test yazmadan bitti sayma.
```

### Sadece soru — kod DEĞİŞMESİN
Analiz istiyorsan bunu açıkça söyle, yoksa düzeltmeye girişebilir:

```
Bir şey değiştirme, sadece açıkla: [sorun]. Örn: login akışında token
süresi dolunca ne oluyor? İlgili dosyaları göstererek anlat.
```

### Kurulum / ortam sorunu
```
[Komut] çalıştırınca şu hatayı alıyorum: [hata]. README'deki kurulum
adımlarını uyguladım. Sebebini araştır ve çöz; README'de eksik/yanlış
bir adım varsa onu da düzelt.
```

### İş bitti mi kontrolü / doğrulama
```
Az önce yaptığın değişikliği kanıtla: testleri koş, API'yi ayağa kaldırıp
gerçek bir istekle dene, sonucu göster.
```

### Kod incelemesi
```
/code-review
```
(veya: "Son commit'lerdeki değişiklikleri gözden geçir, hata ve
basitleştirme fırsatlarını raporla.")

### Güvenlik taraması
```
/audit
```
(ruflo-security-audit eklentisinin komutu; derinlik sorarsa "standard" de.)

---

## 4. İyi istem yazmanın 6 kuralı

1. **Tek istemde tek iş.** "Şunu da yap, bunu da bak" karıştırma; bitince
   sıradakini iste.
2. **Bağlam ver:** hangi dosya, hangi komut, hangi hata. "Çalışmıyor" yetmez.
3. **Bitiş tanımla:** "testler yeşil olunca bitti say", "201 dönünce tamam" gibi.
   Ölçülebilir hedef verirsen kendi kendini kontrol eder.
4. **Analiz ile değişikliği ayır:** fikir istiyorsan "değiştirme, sadece anlat" de;
   demezsen elini koda sürebilir.
5. **Hata çıktısını AYNEN yapıştır.** Özetleme, kırpma — tam çıktı en değerli ipucu.
6. **Türkçe yaz, rahat yaz.** Kibar kalıplara, "lütfen"lere gerek yok; net olmak
   yeterli. Kısaltma ve yarım cümle yerine düz cümle kur.

---

## 5. YAPTIRMA listesi (proje kuralları — pazarlıksız)

- **Yan dal / worktree açtırma.** İş doğrudan `dev` dalında yapılır
  (DECISIONS.md'de karar var). "Branch aç" deme; derse durdur.
- **main'e doğrudan push yok.** main'e yalnız dev→main PR ile gidilir.
- **Verilmiş kararları yeniden tarttırma.** DECISIONS.md'deki kararlar kapalıdır;
  Claude tartışmaya açarsa "DECISIONS.md'de karar verilmiş, uygula" de.
- **Onay kapısı geçildi.** BRIEF'teki plan onayı verildi; Claude sana karar sorarsa
  "kararı sen ver, DECISIONS.md'ye yaz, ilerle" de.
- **.env / şifre / anahtar commit'letme.** İsterse reddet.

---

## 6. İşine yarayacak Claude Code kısayolları

| Ne | Nasıl |
|---|---|
| Yarıda kalan sohbete dön | Terminalde `claude -c` (son sohbet) veya `claude --resume` (listeden seç) |
| Claude'u durdur | `ESC` (işlemi keser, sohbet kalır) |
| Kendi elinle komut çalıştır | İstem satırına `! komut` yaz (çıktı sohbete düşer) |
| Eklenti kur/yönet | `/plugin` |
| MCP durumu | Terminalde `claude mcp list` → `claude-flow ... Connected` görmelisin |
| İzin modu değiştir | `Shift+Tab` (auto-accept / plan modu arasında geçiş) |

---

## 7. Sorun çıkarsa

- Claude tuhaf davranıyor / bağlam şişti → sohbeti kapat, yeni sohbet aç,
  Bölüm 1'deki ilk istemi ver. Kaybolan bir şey olmaz — hafıza depoda.
- `claude-flow` MCP "Failed to connect" → README Bölüm 4'teki notu uygula
  (Windows'ta `cmd /c` sarmalayıcısı gerekir).
- Kurulumla ilgili her şey → README.md "Sıfırdan kurulum" bölümü.
