<?php

use Illuminate\Database\Migrations\Migration;
use Illuminate\Support\Facades\DB;

/**
 * OTO-SIRALAMA HAKKI HİÇ VERİLMEMİŞ BAYİLERİN ONARIMI (saha şikâyeti 2026-09-26: "Yeni açılan
 * üyeye Oto-Sıralama hakkı tanımlaması yapmıyor").
 *
 * KÖK: `Provisioning::createTenantWithPatron` yalnız AYLIK KOTAYI (`route_credits_monthly`)
 * yazıyordu; KALAN HAK (`route_credits`) kolon varsayılanı 0'da kalıyordu. Açılış kodu
 * düzeltildi; bu göç o güne dek açılmış bayileri onarır.
 *
 * KİMİN ONARILDIĞI KESİN: bugüne dek `route_credits`in TEK kaynağı kontör paketiydi
 * (`addon_grants.type = 'credits'`, append-only). Hiç kontör paketi almamış ve hakkı 0 olan bayi
 * hiç hak ALMAMIŞ demektir — hakkını harcamış bir bayi değildir. Paket almış bayiye DOKUNULMAZ:
 * onun sıfırı gerçek bir tüketim olabilir ve kullanım kaydı tutulmadığı için ayırt edilemez;
 * yanlış tarafa düşmek bedava hak dağıtmak olurdu.
 *
 * `down()` BOŞTUR: bu bir veri onarımıdır, geri alınması bayilerden verilmiş hakkı geri çekmek
 * olurdu ve hangi satırın bu göçle değiştiği ayrıca kaydedilmez.
 *
 * Migration owner (sipario_owner) ile koşar: `artisan migrate --database=pgsql_owner --force`.
 */
return new class extends Migration
{
    public function up(): void
    {
        DB::statement(
            'UPDATE tenants SET route_credits = route_credits_monthly '.
            'WHERE route_credits = 0 AND route_credits_monthly > 0 '.
            "AND NOT EXISTS (SELECT 1 FROM addon_grants g WHERE g.tenant_id = tenants.id AND g.type = 'credits')"
        );
    }

    public function down(): void
    {
        // Bilinçli olarak boş — bkz. sınıf açıklaması.
    }
};
