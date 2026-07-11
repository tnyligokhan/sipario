<?php

namespace App\Console\Commands;

use App\Support\Provisioning;
use Illuminate\Console\Command;
use Illuminate\Support\Facades\Validator;

/**
 * Bayi hesabı açma (dev/test + birebir satışla kazanılan bayiler için elle provizyon).
 * Mobilde kayıt YOKtur (kırmızı çizgi); hesaplar buradan veya Faz 5 sitesinden açılır.
 *
 * Örnek: php artisan sipario:create-tenant "Aspendos Su" patron@aspendos.com sifre123
 */
class CreateTenant extends Command
{
    protected $signature = 'sipario:create-tenant
                            {name : Bayi adı}
                            {email : Patron e-postası}
                            {password : Patron parolası}
                            {--patron-name=Patron : Patron görünen adı}';

    protected $description = 'Yeni bayi (tenant) ve patron kullanıcısı oluşturur (30 gün deneme).';

    public function handle(): int
    {
        $validator = Validator::make([
            'name' => $this->argument('name'),
            'email' => $this->argument('email'),
            'password' => $this->argument('password'),
        ], [
            'name' => ['required', 'string', 'max:160'],
            'email' => ['required', 'email', 'max:190'],
            'password' => ['required', 'string', 'min:6'],
        ]);

        if ($validator->fails()) {
            foreach ($validator->errors()->all() as $error) {
                $this->error($error);
            }

            return self::FAILURE;
        }

        $result = Provisioning::createTenantWithPatron(
            $this->argument('name'),
            $this->argument('email'),
            $this->argument('password'),
            $this->option('patron-name'),
        );

        $this->info('Bayi oluşturuldu.');
        $this->line('  tenant_id : '.$result['tenant']->id);
        $this->line('  patron    : '.$result['patron']->email);
        $this->line('  deneme    : '.$result['tenant']->trial_ends_at->toDateString().' tarihine kadar');

        return self::SUCCESS;
    }
}
