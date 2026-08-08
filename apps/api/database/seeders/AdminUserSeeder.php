<?php

namespace Database\Seeders;

use App\Models\AdminUser;
use Illuminate\Database\Seeder;
use Illuminate\Support\Str;

/**
 * Panel yönetici hesaplarının VARLIĞINI garanti eder — parolalarını DEĞİL.
 *
 * ⚠️ GÜVENLİK GEÇMİŞİ (2026-08-09'da kapatıldı): bu seeder daha önce sabit bir parolayı
 * (`SiparioAdmin2026!`) kaynak koda gömüyor ve `updateOrCreate` ile HER koşumda hesaplara
 * yeniden yazıyordu. Depo public olduğu için bu, yönetim paneline — yani bütün bayilerin
 * iş verisine ve dışa aktarım yetkisine — açık bir kapıydı. Üstelik parolayı elle
 * değiştirmek işe yaramıyordu: bir sonraki deploy `updateOrCreate` ile eski değeri geri
 * yazıyordu.
 *
 * YENİ SÖZLEŞME — iki kural:
 *   1. Parola ASLA repoda durmaz. Yeni hesap rastgele, kimsenin bilmediği bir parolayla
 *      doğar; sahibi onu `panel:admin ... --sifirla` ile alır (parola bir kez basılır,
 *      hiçbir yere kaydedilmez — komutun kendi sözleşmesi).
 *   2. `firstOrCreate` — VAR OLAN hesaba DOKUNULMAZ. Parolayı değiştirdiysen kalıcıdır;
 *      hesabı kapattıysan deploy onu geri açmaz (`updateOrCreate` bunların ikisini de
 *      sessizce geri alıyordu).
 *
 * Bu seeder ARTIK deploy sırasında otomatik koşmaz (docker/php/Dockerfile'daki
 * `db:seed` satırı kaldırıldı); yalnız elle çağrılır.
 */
class AdminUserSeeder extends Seeder
{
    /** Hesabı OLMAYAN yöneticiler için kimlik iskeleti. Parola burada YOKTUR ve olmayacaktır. */
    private const YONETICILER = [
        ['email' => 'gokhan@sipario.com.tr', 'name' => 'Gökhan'],
        ['email' => 'bugra@sipario.com.tr', 'name' => 'Buğra'],
    ];

    public function run(): void
    {
        foreach (self::YONETICILER as $yonetici) {
            $admin = AdminUser::withoutGlobalScope('aktif')->firstOrCreate(
                ['email' => $yonetici['email']],
                [
                    'name' => $yonetici['name'],
                    // Kimsenin bilmediği bir parola: hesap AÇIK ama giriş yolu yalnız
                    // `panel:admin --sifirla`. Sabit parolanın aksine sızdırılacak bir sır yok.
                    'password' => Str::password(24),
                    'role' => 'superadmin',
                    'disabled_at' => null,
                ]
            );

            // Doğrudan `->` (koruma yok): `DemoSeeder`ın da kullandığı desen. Laravel'in PHPDoc'unda
            // `Seeder::$command` non-nullable; hem `?->` hem `isset()` PHPStan tarafından reddediliyor.
            if ($admin->wasRecentlyCreated) {
                $this->command->warn(
                    "Panel yöneticisi oluşturuldu: {$yonetici['email']} — parola RASTGELE. ".
                    "Almak için: php artisan panel:admin \"{$yonetici['name']}\" {$yonetici['email']} --sifirla"
                );
            }
        }
    }
}
