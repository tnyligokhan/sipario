<?php

namespace App\Panel;

use App\Enums\TenantStatus;
use App\Enums\UserRole;
use App\Models\Device;
use App\Models\Tenant;
use App\Models\User;
use App\Payment\DuplicateEmailException;
use App\Support\DuplicateSlugException;
use App\Support\Provisioning;
use Illuminate\Database\QueryException;
use Illuminate\Support\Carbon;
use Illuminate\Support\Collection;
use Illuminate\Support\Facades\DB;
use Illuminate\Support\Str;

/**
 * Yönetim paneli tenant/abonelik yönetimi (Faz 5c). TÜM okuma/yazma `pgsql_panel` bağlantısı
 * (sipario_panel rolü — BYPASSRLS cross-tenant görür, iş verisine YAZAMAZ) üzerinden yapılır; elle
 * tenant açma tek istisnadır (INSERT gerektirir → Provisioning owner ile, kiracı-üstü meşru eylem).
 *
 * Abonelik eylemleri 5a kilit mantığıyla TUTARLIdır (DECISIONS): writable olması için locked_at=null
 * + valid_until gelecekte + status ∈ {trial, active}. Her eylem panel_audit'e nötr kayıt bırakır
 * (KVKK: yalnız eylem türü + hedef id; iş verisi DEĞERİ yazılmaz).
 */
class TenantAdminService
{
    /** Elle bayi açarken e-posta çakışmasının TEK cümlesi (ön kontrol ve yarış aynı şeyi desin). */
    private const EPOSTA_ALINMIS = 'Bu e-posta adresi başka bir hesapta kayıtlı.';

    public function __construct(private readonly string $connection = 'pgsql_panel') {}

    /**
     * Tüm bayiler (özet). Panel cross-tenant okur (BYPASSRLS).
     *
     * @return Collection<int, Tenant>
     */
    public function tenants(): Collection
    {
        return Tenant::on($this->connection)->orderBy('created_at', 'desc')->get();
    }

    /**
     * Bayi detayı + salt-okunur özet (kullanıcı/cihaz sayısı). Yoksa null.
     *
     * @return array{tenant: Tenant, user_count: int, device_count: int}|null
     */
    public function tenantDetail(string $tenantId): ?array
    {
        $tenant = Tenant::on($this->connection)->find($tenantId);
        if ($tenant === null) {
            return null;
        }

        return [
            'tenant' => $tenant,
            'user_count' => User::on($this->connection)->where('tenant_id', $tenantId)->count(),
            'device_count' => Device::on($this->connection)->where('tenant_id', $tenantId)->count(),
        ];
    }

    /** Deneme uzat: trial_ends_at + valid_until'ı ileri al, status=trial, kilidi temizle. */
    public function extendTrial(string $tenantId, int $days, ?string $adminId = null): Tenant
    {
        $tenant = $this->find($tenantId);
        $base = $this->maxNow($tenant->trial_ends_at);
        $newEnd = $base->copy()->addDays($days);

        return $this->apply($tenant, [
            'status' => TenantStatus::Trial->value,
            'trial_ends_at' => $newEnd,
            'valid_until' => $newEnd,
            'locked_at' => null,
        ], $adminId, 'extend_trial', "+{$days}d");
    }

    /** Abonelik kaydet: valid_until = now+days (varsayılan 1 yıl), status=active, kilit temizle. */
    public function activateSubscription(string $tenantId, int $days = 365, ?string $adminId = null): Tenant
    {
        $tenant = $this->find($tenantId);

        return $this->apply($tenant, [
            'status' => TenantStatus::Active->value,
            'valid_until' => now()->addDays($days),
            'locked_at' => null,
        ], $adminId, 'activate', "+{$days}d");
    }

    /** Kilitle: status=locked, locked_at=now (5a: occurred_at>locked_at yeni yazım reddedilir). */
    public function lock(string $tenantId, ?string $adminId = null): Tenant
    {
        $tenant = $this->find($tenantId);

        return $this->apply($tenant, [
            'status' => TenantStatus::Locked->value,
            'locked_at' => now(),
        ], $adminId, 'lock');
    }

    /** Aç: status=active, locked_at=null, valid_until'ı ileri al (geçmişse now+30g — 5a re-lock önlenir). */
    public function unlock(string $tenantId, ?string $adminId = null): Tenant
    {
        $tenant = $this->find($tenantId);

        return $this->apply($tenant, [
            'status' => TenantStatus::Active->value,
            'locked_at' => null,
            'valid_until' => $this->forwardValidUntil($tenant),
        ], $adminId, 'unlock');
    }

    /** Askıya al: status=suspended, locked_at=now (kilit ile aynı 5a enforcement). */
    public function suspend(string $tenantId, ?string $adminId = null): Tenant
    {
        $tenant = $this->find($tenantId);

        return $this->apply($tenant, [
            'status' => TenantStatus::Suspended->value,
            'locked_at' => now(),
        ], $adminId, 'suspend');
    }

    /**
     * İptal: status=cancelled, locked_at=now. `suspend()` ile aynı 5a enforcement — FARKI NİYETTİR:
     * suspend BİZİM elimizle geçici askıya almadır (ödeme gecikti, haftaya ödeyecek), cancel ise
     * bayinin AYRILMASIDIR. İkisini ayırmak churn ölçümünün ön şartı: "askıya aldığımız" ile
     * "bizi bırakan" aynı sayaca düşerse terk oranı hiçbir zaman doğru okunmaz.
     *
     * Veri SİLİNMEZ (kırmızı çizgi #5): iptal yalnız yazmayı kapatır. `locked_at`ten ÖNCE cihazda
     * oluşmuş bekleyen kayıtlar senkronla akmaya devam eder; abonelik yenilenirse her şey geri gelir.
     */
    public function cancel(string $tenantId, ?string $adminId = null): Tenant
    {
        $tenant = $this->find($tenantId);

        return $this->apply($tenant, [
            'status' => TenantStatus::Cancelled->value,
            'locked_at' => now(),
        ], $adminId, 'cancel');
    }

    /**
     * Bayiye kurye hesabı aç. `Provisioning::createCourier` owner ile INSERT eder ve KOTA KAPISINDAN
     * geçer (`KuryeKotasi`); kota doluysa `KotaDoluException` BURADA YAKALANMAZ, çağırana çıkar —
     * kullanıcıya ne söyleneceği arayüzün kararıdır, servisin değil.
     *
     * Denetim kaydı yalnız BAŞARILI açılışta düşer; reddedilen deneme `auditRed()`in işidir.
     * Kullanıcı adı/parola denetime YAZILMAZ (panel_audit'in KVKK-nötr sözleşmesi) — yalnız
     * yaratılan kullanıcının kimliği.
     */
    public function createCourier(
        string $tenantId,
        string $ad,
        string $kullaniciAdi,
        string $parola,
        ?string $telefon = null,
        ?string $adminId = null,
    ): User {
        $user = Provisioning::createCourier($tenantId, $ad, $kullaniciAdi, $parola, $telefon);
        $this->audit($adminId, $tenantId, 'create_courier', 'user:'.$user->id);

        return $user;
    }

    /**
     * REDDEDİLEN bir yazma denemesini denetime yaz (5c-3 güvenlik incelemesinin kapatılmayan bulgusu).
     *
     * Gerekçe: bugün yalnız BAŞARILI eylemler iz bırakıyor. "Kota dolu olduğu hâlde on kez kurye
     * açmaya çalışıldı" ya da "yetkisiz hesap üç kez bayi silmeye çalıştı" günlükte hiç görünmüyor —
     * oysa denetim günlüğünün asıl değeri tam olarak budur. Eylem adı `<action>_denied` biçiminde
     * saklanır ki başarılı kardeşiyle aynı sorguda ayrışsın.
     *
     * `$sebep` KISA ve KATEGORİK olmalı ('kota_dolu', 'yetkisiz', 'stale') — kullanıcı girdisi,
     * tutar, IBAN ya da serbest metin GEÇİRME (panel_audit KVKK-nötr kalmalı, testle kilitli).
     * `$adminId` guard'dan geldiği için mixed kabul edilir ve burada normalleştirilir.
     */
    public function auditRed(string $action, ?string $tenantId, string $sebep, mixed $adminId = null): void
    {
        $this->audit(
            ($adminId === null || $adminId === '') ? null : (string) $adminId,
            $tenantId,
            $action.'_denied',
            $sebep,
        );
    }

    /**
     * Elle bayi aç (siteden gelmeyen, birebir satış bayisi). Provisioning owner ile INSERT eder
     * (panel rolü tenants'a INSERT edemez — bilinçli); denetim kaydı panel bağlantısıyla.
     *
     * FİRMA KODU, YETKİLİ ve TELEFON İMZADA (2026-08-27): eskiden yalnız ad/e-posta/parola
     * alınıyordu ve geri kalanı `Provisioning`in varsayılanlarına düşüyordu — elle açılan bayi
     * addan türetilmiş bir kodla, `contact_name`i NULL ve telefonu boş doğuyordu. Panelin
     * "Firma, yetkili veya il ara" araması `contact_name` okur; yani elle açılan bayi kendi
     * yetkilisinin adıyla ARANAMIYORDU. Kod da öyle: bayiye telefonda söylenen kod ile sistemin
     * ürettiği kod ayrışırsa mobil giriş ilk denemede tutmaz.
     *
     * E-POSTA ÇAKIŞMASI TİPLİ İSTİSNAYA ÇEVRİLİR. `users.email` global tekildir; ön kontrol
     * (form `unique` kuralı) yarışa karşı yetmez ve kaybeden taraf ham `23505` ile 500 alırdı.
     * Mesaj — `SubscriptionService::register`in aksine — AÇIK konuşur: burası kimliği doğrulanmış
     * bir iç araçtır, kullanıcı numaralandırma yüzeyi değil; operatör "neden açılmadı" sorusunun
     * cevabını görmezse aynı kaydı tekrar tekrar dener.
     *
     * @return array{tenant: Tenant, patron: User}
     *
     * @throws DuplicateEmailException e-posta başka bir hesapta
     * @throws DuplicateSlugException istenen firma kodu başka bir bayide
     */
    public function createTenant(
        string $name,
        string $email,
        string $password,
        ?string $adminId = null,
        ?string $slug = null,
        ?string $yetkili = null,
        ?string $telefon = null,
    ): array {
        $email = mb_strtolower(trim($email));

        if (User::on($this->connection)->where('email', $email)->exists()) {
            throw new DuplicateEmailException(self::EPOSTA_ALINMIS);
        }

        try {
            $result = Provisioning::createTenantWithPatron(
                tenantName: $name,
                patronEmail: $email,
                patronPassword: $password,
                patronName: $yetkili,
                slug: $slug,
                phone: $telefon,
            );
        } catch (QueryException $e) {
            // 23505 = unique_violation. Kod çakışması Provisioning'te zaten tiplenir; buraya
            // yalnız E-POSTA yarışı düşer. Kısıt adına bakılır: "bir yerde 23505 oldu" demek,
            // ileride eklenecek başka bir tekil indeksi de e-posta hatası göstermek olurdu.
            if ((string) $e->getCode() === '23505' && str_contains($e->getMessage(), 'users_email_unique')) {
                throw new DuplicateEmailException(self::EPOSTA_ALINMIS);
            }
            throw $e;
        }

        $this->audit($adminId, $result['tenant']->id, 'create_tenant');

        return $result;
    }

    /**
     * Opsiyonel modül aç/kapa (FAZ 5c-2; BRIEF: boş/emanet takibi). tenants.modules JSONB bayrağını
     * panel bağlantısıyla günceller (tenants UPDATE grant'i var). İstemci bunu subscription bloğuyla alır.
     */
    public function setModule(string $tenantId, string $module, bool $enabled, ?string $adminId = null): Tenant
    {
        $tenant = $this->find($tenantId);
        $modules = $tenant->modules;
        $modules[$module] = $enabled;

        return $this->apply($tenant, ['modules' => $modules], $adminId, 'set_module', "{$module}=".($enabled ? '1' : '0'));
    }

    /**
     * Patron şifre sıfırlama (FAZ 5c-2; BRIEF). Panelin `users`'ta UPDATE'i YOK (SELECT-only) →
     * AYRICALIKLI, owner bağlantısıyla (tenant yaratma deseni). Yeni parola üretilir, döner (admin bir
     * kez görür); audit'e parola DEĞERİ YAZILMAZ (KVKK) — yalnız "reset_password" + hedef user id.
     */
    public function resetPatronPassword(string $tenantId, ?string $adminId = null): string
    {
        return Provisioning::asOwner(function () use ($tenantId, $adminId) {
            /** @var User $patron */
            $patron = User::query()
                ->where('tenant_id', $tenantId)
                ->where('role', UserRole::Patron->value)
                ->firstOrFail();

            $newPassword = Str::password(16);
            $patron->forceFill(['password' => $newPassword])->save(); // 'hashed' cast bcrypt'ler

            $this->audit($adminId, $tenantId, 'reset_password', 'user:'.$patron->id);

            return $newPassword;
        });
    }

    /**
     * TOPLU DIŞA AKTARIM denetimi (güvenlik incelemesi 5c-3). Export route'ları bir bayinin TÜM
     * müşteri adı/telefonu/adresini tek istekte indirir — panelin en yüksek hacimli kişisel veri
     * çıkışıdır ve iz bırakmıyordu: müşteri ekleme gibi küçük bir eylem günlüğe düşerken tüm
     * listenin indirilmesi görünmezdi. KVKK hesap verebilirliği bunun tersini ister.
     *
     * Günlüğe yalnız NE indirildiği yazılır (tür + hedef bayi), indirilen DEĞERLER değil —
     * panel_audit'in KVKK-nötr sözleşmesi (kırmızı çizgi #4) korunur.
     *
     * `$adminId` guard'dan geldiği için mixed kabul edilir ve burada normalleştirilir; çağıran
     * route'ların her birinde aynı dönüşümü tekrarlamak gerekmesin.
     */
    public function auditExport(string $tenantId, string $tur, mixed $adminId = null): void
    {
        $this->audit(
            ($adminId === null || $adminId === '') ? null : (string) $adminId,
            $tenantId,
            'export',
            $tur,
        );
    }

    /**
     * Veritabanı yedeği indirildi — `tenant_id` YOK, çünkü yedek TÜM bayileri kapsar.
     *
     * Ayrı bir metot olmasının sebebi budur: `auditExport` bir bayiye işaret eder ve o
     * imzaya boş bir kimlik geçirmek, denetim kaydını "hangi bayi?" sorusuna yanlış
     * cevap verir hâle getirirdi. Burada doğru cevap "hepsi"dir ve onu tenant sütunu
     * değil, eylem adı taşır.
     *
     * Detaya yalnız DOSYA ADI yazılır — `panel_audit`in KVKK-nötr sözleşmesi gereği
     * dosyanın içeriğine dair hiçbir şey buraya girmez.
     */
    public function auditYedekIndirme(?string $adminId, string $dosya): void
    {
        $this->audit(
            ($adminId === null || $adminId === '') ? null : $adminId,
            null,
            'yedek_indirme',
            $dosya,
        );
    }

    // ------------------------------------------------------------------------------------

    private function find(string $tenantId): Tenant
    {
        return Tenant::on($this->connection)->findOrFail($tenantId);
    }

    /**
     * Değişiklikleri panel bağlantısıyla UPDATE eder (sipario_panel tenants UPDATE'e sahip) + audit.
     *
     * @param  array<string, mixed>  $attrs
     */
    private function apply(Tenant $tenant, array $attrs, ?string $adminId, string $action, ?string $detail = null): Tenant
    {
        $tenant->forceFill($attrs)->save();
        $this->audit($adminId, $tenant->id, $action, $detail);

        return $tenant;
    }

    private function audit(?string $adminId, ?string $tenantId, string $action, ?string $detail = null): void
    {
        DB::connection($this->connection)->table('panel_audit')->insert([
            'id' => (string) Str::uuid7(),
            'admin_user_id' => $adminId,
            'tenant_id' => $tenantId,
            'action' => $action,
            'detail' => $detail,
            'created_at' => now(),
        ]);
    }

    /** valid_until gelecekteyse korunur, geçmiş/null ise now+30g'ye çekilir (asla geriye alınmaz). */
    private function forwardValidUntil(Tenant $tenant): Carbon
    {
        $current = $tenant->valid_until;
        $floor = now()->addDays(30);

        return ($current !== null && $current->greaterThan($floor)) ? $current : $floor;
    }

    private function maxNow(?Carbon $date): Carbon
    {
        return ($date !== null && $date->greaterThan(now())) ? $date : now();
    }
}
