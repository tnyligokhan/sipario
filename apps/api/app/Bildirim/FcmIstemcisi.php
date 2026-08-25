<?php

namespace App\Bildirim;

use Illuminate\Support\Facades\Cache;
use Illuminate\Support\Facades\Http;
use RuntimeException;

/**
 * FCM HTTP v1'in DÜŞÜK SEVİYE kapısı: erişim jetonu üretir, TEK cihaza veri mesajı gönderir.
 * "Kime gidecek, hangi olayda" sorusu burada değil `PushGondericisi`'ndedir.
 *
 * NEDEN HAZIR PAKET YOK (`kreait/firebase-php`, `google/auth`): ihtiyacımız iki HTTP çağrısı
 * ve bir RS256 imzasıdır. Paketler bunun için on kadar geçişli bağımlılık getirir ve her biri
 * ayrı bir güncelleme/CVE yüzeyidir. Buradaki ~40 satırın tamamı testle kilitlidir; taşınan
 * risk, bakılmayan bir bağımlılık ağacından düşüktür.
 *
 * ERİŞİM JETONU ÖNBELLEKLENİR: her bildirimde Google'dan yeni jeton almak, gönderim başına
 * FAZLADAN bir tur demektir. Anahtar hizmet hesabının parmak iziyle damgalıdır — anahtar
 * döndürüldüğünde eski jeton kendiliğinden düşer, elle temizlik gerekmez.
 */
class FcmIstemcisi
{
    /**
     * Kimlik bilgisi yapılandırılmış mı? Değilse push sistemi KAPALIDIR ve bu bir hata
     * değildir (bkz. `config/push.php`). Çağıran taraf sessizce atlar.
     */
    public function kurulu(): bool
    {
        return $this->kimlik() !== null;
    }

    /**
     * Tek bir cihaza VERİ mesajı gönderir.
     *
     * ⚠️ `notification` ALANI BİLEREK GÖNDERİLMİYOR, yalnız `data`. Sebep mimari: `notification`
     * varsa uygulama arka plandayken bildirimi ANDROID SİSTEMİ çizer — bizim sessiz saatler
     * (22:00–08:00), günlük bütçe ve kategori kısma kurallarımızın hiçbiri devreye girmez ve
     * metin sunucudan gelmek zorunda kalırdı (kişisel veri FCM'e sızardı). Veri mesajında
     * bildirimi uygulama çizer; kurallar korunur, yük anonim kalır.
     *
     * `priority: HIGH` ZORUNLU: veri mesajları varsayılan öncelikte Doze modunda saatlerce
     * beklet(ile)bilir. Bu üründe dürtünün değeri ANINDA olmasındadır — "kuryeye sipariş
     * düştü" bildirimi yarım saat sonra gelirse hiç gelmemiş sayılır.
     *
     * @param  array<string,string>  $veri  Yalnız string değerler — FCM `data` alanı başka tip kabul etmez.
     */
    public function gonder(string $cihazJetonu, array $veri): PushSonucu
    {
        $kimlik = $this->kimlik();
        if ($kimlik === null) {
            return PushSonucu::Kapali;
        }

        $jeton = $this->erisimJetonu($kimlik);
        if ($jeton === null) {
            // Jeton alınamadı (ağ ya da anahtar sorunu). Kalıcı olup olmadığını buradan
            // ayırt edemeyiz; kuyruğun yeniden denemesine bırakılır.
            return PushSonucu::Gecici;
        }

        $url = str_replace(
            '{proje}',
            (string) ($kimlik['project_id'] ?? ''),
            (string) config('push.fcm.gonderim_url')
        );

        $yanit = Http::withToken($jeton)
            ->timeout(10)
            ->post($url, [
                'message' => [
                    'token' => $cihazJetonu,
                    'data' => $veri,
                    'android' => ['priority' => 'HIGH'],
                ],
            ]);

        if ($yanit->successful()) {
            return PushSonucu::Basarili;
        }

        /*
         * ÖLÜ JETON AYIRT EDİLMEK ZORUNDA: kullanıcı uygulamayı sildiğinde ya da verilerini
         * temizlediğinde jeton geçersizleşir ve FCM 404/UNREGISTERED döner. Bunu geçici hata
         * sayarsak kuyruk her olayda üç kez yeniden dener ve ölü jeton veritabanında sonsuza
         * dek durur — bayi başına biriken çöp, her siparişte boşa giden üç HTTP çağrısı olur.
         */
        $hataKodu = (string) ($yanit->json('error.details.0.errorCode')
            ?? $yanit->json('error.status')
            ?? '');

        if ($yanit->status() === 404 || $hataKodu === 'UNREGISTERED' || $hataKodu === 'NOT_FOUND') {
            return PushSonucu::JetonOlu;
        }

        // 400 = yükümüz bozuk; yeniden denemek aynı sonucu verir, kuyruğu meşgul etmez.
        if ($yanit->status() === 400 || $yanit->status() === 403) {
            return PushSonucu::Kalici;
        }

        return PushSonucu::Gecici;
    }

    // ── Kimlik ve jeton ──────────────────────────────────────────────────────────────────────

    /**
     * Hizmet hesabı JSON'u. Base64 ya da ham JSON kabul edilir (bkz. `config/push.php`).
     * Bozuk yapılandırma SESSİZ GEÇMEZ — istisna atar; "push neden çalışmıyor" sorusunun
     * cevabı loglarda görünür olmalıdır.
     *
     * @return array<string,mixed>|null
     */
    private function kimlik(): ?array
    {
        $ham = config('push.fcm.hizmet_hesabi');
        if (! is_string($ham) || trim($ham) === '') {
            return null;
        }

        $ham = trim($ham);
        $json = str_starts_with($ham, '{') ? $ham : base64_decode($ham, true);

        if ($json === false) {
            throw new RuntimeException('FCM_HIZMET_HESABI base64 olarak çözülemedi.');
        }

        $veri = json_decode($json, true);
        if (! is_array($veri) || ! isset($veri['client_email'], $veri['private_key'], $veri['project_id'])) {
            throw new RuntimeException(
                'FCM_HIZMET_HESABI geçerli bir hizmet hesabı JSON\'u değil '.
                '(client_email · private_key · project_id gerekli).'
            );
        }

        return $veri;
    }

    /** @param  array<string,mixed>  $kimlik */
    private function erisimJetonu(array $kimlik): ?string
    {
        $anahtar = 'push:fcm:jeton:'.substr(sha1((string) $kimlik['client_email']), 0, 12);

        $jeton = Cache::get($anahtar);
        if (is_string($jeton) && $jeton !== '') {
            return $jeton;
        }

        $yanit = Http::asForm()
            ->timeout(10)
            ->post((string) config('push.fcm.token_url'), [
                'grant_type' => 'urn:ietf:params:oauth:grant-type:jwt-bearer',
                'assertion' => $this->imzaliJwt($kimlik),
            ]);

        $yeni = $yanit->successful() ? $yanit->json('access_token') : null;
        if (! is_string($yeni) || $yeni === '') {
            return null;
        }

        Cache::put($anahtar, $yeni, (int) config('push.fcm.jeton_onbellek_sn', 3300));

        return $yeni;
    }

    /**
     * Google'ın istediği imzalı iddia (assertion): RS256 JWT.
     *
     * `protected` — testler bunu ezer. Gerekçe ölçülmüş bir ortam kısıtı: Windows'ta
     * (geliştirme makinesi) `openssl_pkey_new` bir `openssl.cnf` bulamadığı için test
     * anahtarı ÜRETİLEMİYOR. İmzayı ezmek, asıl sınanmak isteneni (yük içeriği, ölü jeton
     * dalı, kiracı izolasyonu) test edilebilir kılar; imzanın kendisi ayrıca ve openssl
     * varsa `imza_gercekten_uretilir` testinde doğrulanır.
     *
     * @param  array<string,mixed>  $kimlik
     */
    protected function imzaliJwt(array $kimlik): string
    {
        $simdi = time();

        $govde = [
            'iss' => $kimlik['client_email'],
            'scope' => 'https://www.googleapis.com/auth/firebase.messaging',
            'aud' => (string) config('push.fcm.token_url'),
            'iat' => $simdi,
            'exp' => $simdi + 3600,
        ];

        $imzalanacak = $this->b64u((string) json_encode(['alg' => 'RS256', 'typ' => 'JWT']))
            .'.'.$this->b64u((string) json_encode($govde));

        $imza = '';
        if (! openssl_sign($imzalanacak, $imza, (string) $kimlik['private_key'], OPENSSL_ALGO_SHA256)) {
            throw new RuntimeException('FCM hizmet hesabı anahtarıyla imzalanamadı.');
        }

        return $imzalanacak.'.'.$this->b64u($imza);
    }

    /** JWT'nin istediği base64url: `+/` yerine `-_`, sondaki `=` dolgusu atılır. */
    private function b64u(string $ham): string
    {
        return rtrim(strtr(base64_encode($ham), '+/', '-_'), '=');
    }
}
