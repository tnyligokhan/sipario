<?php

namespace App\Console\Commands;

use App\Models\AdminUser;
use App\Panel\PanelAdminService;
use Illuminate\Console\Command;
use Illuminate\Support\Facades\Validator;
use Illuminate\Support\Str;
use Throwable;

/**
 * İLK panel yöneticisini kurar (5c-3 · D5). Panel hesapları paneldeki ekrandan açılır ama YUMURTA-TAVUK
 * vardır: hiç hesap yokken o ekrana girilemez. Bu komut o kapıyı açar ve kurtarma yoludur (son
 * superadmin kilitlendiğinde de kullanılır).
 *
 * Parola BİR KEZ ekrana basılır ve SAKLANMAZ — verilmezse güçlü bir parola üretilir. Denetim
 * kaydına parola DEĞERİ asla yazılmaz (patron şifre sıfırlamayla aynı kural).
 *
 * Örnek:
 *   php artisan panel:admin "Gökhan" gokhan@sipario.com
 *   php artisan panel:admin "Destek" destek@sipario.com --rol=support
 */
class PanelAdmin extends Command
{
    protected $signature = 'panel:admin
                            {name : Yöneticinin adı (--sifirla ile yok sayılır)}
                            {email : E-posta (giriş kimliği)}
                            {--rol=superadmin : superadmin | support}
                            {--parola= : Verilmezse güçlü bir parola üretilir}
                            {--sifirla : Var olan hesabın parolasını sıfırlar (yeni hesap açmaz)}';

    protected $description = 'Panel yönetici hesabı oluşturur (ilk kurulum / kurtarma). Parolayı bir kez basar.';

    public function handle(PanelAdminService $service): int
    {
        $rol = (string) $this->option('rol');
        $email = mb_strtolower(trim((string) $this->argument('email')));

        // KURTARMA: parolasını kaybeden var olan hesap. Bu dalın olması komutun kendi sözleşmesiydi
        // ("son superadmin kilitlendiğinde de kullanılır") ama kod yalnız YENİ hesap açabiliyordu:
        // e-posta kayıtlıysa hata verip çıkıyordu, yani kilitlenen kişinin gidecek yeri yoktu.
        // Panelde sıfırlama ekranı bilinçli olarak yok (bkz. PanelAdminService::parolaSifirla).
        if ($this->option('sifirla')) {
            return $this->sifirla($service, $email);
        }

        $validator = Validator::make([
            'name' => $this->argument('name'),
            'email' => $email,
            'rol' => $rol,
            'parola' => $this->option('parola'),
        ], [
            'name' => ['required', 'string', 'max:160'],
            'email' => ['required', 'email', 'max:190'],
            'rol' => ['required', 'in:superadmin,support'],
            'parola' => ['nullable', 'string', 'min:12'],
        ]);

        if ($validator->fails()) {
            foreach ($validator->errors()->all() as $error) {
                $this->error($error);
            }

            return self::FAILURE;
        }

        try {
            $parola = (string) ($this->option('parola') ?: Str::password(20));

            // Pasifler DAHİL kontrol: aynı e-posta kapatılmış bir hesapta duruyorsa yeni hesap
            // açmak `email` tekilliğine çarpar; kullanıcıya ham SQL hatası göstermek yerine söyle.
            if (AdminUser::on('pgsql_panel')->withoutGlobalScope('aktif')->where('email', $email)->exists()) {
                $this->error('Bu e-posta zaten kayıtlı (pasif bir hesap da olabilir).');

                return self::FAILURE;
            }

            $admin = AdminUser::on('pgsql_panel')->create([
                'name' => (string) $this->argument('name'),
                'email' => $email,
                'password' => $parola,
                'role' => $rol,
            ]);
        } catch (Throwable $e) {
            $this->error('Hesap oluşturulamadı: '.$e->getMessage());

            return self::FAILURE;
        }

        $this->info('Panel yöneticisi oluşturuldu.');
        $this->line('  e-posta : '.$admin->email);
        $this->line('  rol     : '.(PanelAdminService::ROLLER[$rol] ?? $rol));
        $this->line('  parola  : '.$parola);
        $this->newLine();
        $this->warn('Parola BİR KEZ gösterildi ve hiçbir yere kaydedilmedi. Şimdi güvenli bir yere alın.');

        return self::SUCCESS;
    }

    /** `--sifirla` dalı: var olan hesaba yeni parola üretir, hesabın kimliğini/rolünü değiştirmez. */
    private function sifirla(PanelAdminService $service, string $email): int
    {
        if (! filter_var($email, FILTER_VALIDATE_EMAIL)) {
            $this->error('Geçerli bir e-posta verin.');

            return self::FAILURE;
        }

        try {
            ['admin' => $admin, 'parola' => $parola] = $service->parolaSifirla($email, null);
        } catch (Throwable $e) {
            $this->error('Parola sıfırlanamadı: '.$e->getMessage());

            return self::FAILURE;
        }

        $this->info('Panel parolası sıfırlandı.');
        $this->line('  e-posta : '.$admin->email);
        $this->line('  rol     : '.(PanelAdminService::ROLLER[$admin->role] ?? $admin->role));
        $this->line('  parola  : '.$parola);

        // Pasif hesabın parolasını sıfırlamak onu AÇMAZ; kullanıcı boşuna denemesin diye söyle.
        if ($admin->pasifMi()) {
            $this->newLine();
            $this->warn('DİKKAT: Bu hesap PASİF. Parola tazelendi ama hesap açılmadan giriş yapılamaz.');
        }

        $this->newLine();
        $this->warn('Parola BİR KEZ gösterildi ve hiçbir yere kaydedilmedi. Şimdi güvenli bir yere alın.');

        return self::SUCCESS;
    }
}
