<?php

namespace App\Panel;

use App\Models\AdminUser;
use Illuminate\Contracts\Pagination\LengthAwarePaginator;
use Illuminate\Support\Collection;
use Illuminate\Support\Facades\DB;
use Illuminate\Support\Str;
use RuntimeException;

/**
 * Panel HESAP YÖNETİMİ ve GENEL DENETİM GÜNLÜĞÜ (5c-3 · D5).
 *
 * İKİ ROL (mevcut `admin_users.role` sütunu; yeni kavram eklenmedi):
 *  - `superadmin` — abonelik/kilit eylemleri, modül aç-kapa, patron şifre sıfırlama VE panel hesabı
 *    yönetimi. Yani bir bayinin ticari durumunu ya da bizim erişimimizi değiştirebilen her şey.
 *  - `support`   — görüntüleme + VERİ GİRİŞİ (müşteri/ürün ekleme-düzenleme, CSV aktarımı).
 *
 * Ayrımın mantığı: destek ekibi bayinin işini yapmasına yardım edebilmeli (onboarding, düzeltme)
 * ama bayinin ABONELİĞİNE ya da panelin kendi erişim listesine dokunamamalı. Veri girişi geri
 * alınabilir ve denetlenir; abonelik/kilit ise parasal ve bizim erişimimiz güvenliktir.
 *
 * `admin_users` `sipario_panel` rolüyle yönetilir (SELECT/INSERT/UPDATE grant'i var; DELETE YOK —
 * hesap silinmez, pasifleştirilir; denetim günlüğünün "kim" sütunu boşalmamalı).
 */
class PanelAdminService
{
    public const ROLLER = ['superadmin' => 'Süper yönetici', 'support' => 'Destek'];

    public function __construct(private readonly string $connection = 'pgsql_panel') {}

    /**
     * Tüm panel hesapları — PASİFLER DAHİL (model üzerindeki 'aktif' kapsamı burada kaldırılır;
     * yönetim ekranı kapattığı hesabı görebilmelidir).
     *
     * @return Collection<int, AdminUser>
     */
    public function adminler(): Collection
    {
        return AdminUser::on($this->connection)
            ->withoutGlobalScope('aktif')
            ->orderBy('name')
            ->get();
    }

    /**
     * Yeni panel hesabı. Parola ÜRETİLİR ve BİR KEZ döner (saklanmaz) — patron şifre sıfırlama
     * deseninin aynısı; denetim kaydına parola DEĞERİ asla yazılmaz (KVKK).
     *
     * @return array{admin: AdminUser, parola: string}
     */
    public function ekle(string $ad, string $email, string $rol, ?string $adminId): array
    {
        $email = mb_strtolower(trim($email));
        $ad = trim($ad);

        if ($ad === '' || $email === '') {
            throw new RuntimeException('Ad ve e-posta zorunludur.');
        }
        if (! isset(self::ROLLER[$rol])) {
            throw new RuntimeException('Geçersiz rol.');
        }
        if ($this->emailKullanimda($email)) {
            throw new RuntimeException('Bu e-posta zaten kayıtlı.');
        }

        $parola = Str::password(16);

        /** @var AdminUser $admin */
        $admin = AdminUser::on($this->connection)->create([
            'name' => $ad,
            'email' => $email,
            'password' => $parola, // 'hashed' cast bcrypt'ler
            'role' => $rol,
        ]);

        $this->audit($adminId, 'admin_create', 'admin:'.$admin->id.' rol='.$rol);

        return ['admin' => $admin, 'parola' => $parola];
    }

    /**
     * Var olan hesaba YENİ parola üretir ve bir kez döndürür (kurtarma yolu — konsoldan çağrılır).
     *
     * Panelde parola sıfırlama EKRANI bilinçli olarak yoktur: e-posta gönderimi panelin bağımlılığı
     * değildir ve "sıfırlama bağlantısı" akışı, BYPASSRLS bir hesap için yeni bir saldırı yüzeyi
     * açardı. Kurtarma bu yüzden konsola, yani sunucuya fiziksel/SSH erişimi olana bırakılmıştır.
     *
     * PASİF HESAPLAR DA SIFIRLANABİLİR (`withoutGlobalScope`): parola sıfırlamak hesabı açmaz,
     * yalnız kimliği tazeler — pasif hesap sıfırlandıktan sonra da giremez. Kapsamı burada
     * uygulasaydık pasifleştirilmiş bir hesabın parolası "bulunamadı" hatasına düşerdi.
     *
     * @return array{admin: AdminUser, parola: string}
     */
    public function parolaSifirla(string $email, ?string $adminId): array
    {
        $email = mb_strtolower(trim($email));

        $admin = AdminUser::on($this->connection)->withoutGlobalScope('aktif')
            ->where('email', $email)->first();

        if (! $admin instanceof AdminUser) {
            throw new RuntimeException('Bu e-postayla kayıtlı panel hesabı yok.');
        }

        $parola = Str::password(20);

        $admin->forceFill(['password' => $parola])->save(); // 'hashed' cast bcrypt'ler

        // Denetime yalnız OLAY yazılır, parola DEĞERİ asla (panel_audit'in KVKK-nötr sözleşmesi).
        $this->audit($adminId, 'admin_password_reset', 'admin:'.$admin->id);

        return ['admin' => $admin, 'parola' => $parola];
    }

    /**
     * Hesabı pasifleştir / yeniden aç. Kendi hesabını pasifleştirmek ENGELLENİR: son superadmin
     * kendini kapatırsa panele girilebilecek hesap kalmaz ve kurtarma yolu konsol komutudur —
     * kullanıcıyı kendi ayağına sıkmaktan korumak burada ucuz.
     */
    public function aktiflik(string $hedefId, bool $aktif, ?string $adminId): AdminUser
    {
        if ($adminId !== null && $hedefId === $adminId && ! $aktif) {
            throw new RuntimeException('Kendi hesabınızı pasifleştiremezsiniz.');
        }

        /** @var AdminUser $hedef */
        $hedef = AdminUser::on($this->connection)->withoutGlobalScope('aktif')->findOrFail($hedefId);

        if (! $aktif && $this->sonAktifSuperadminMi($hedef)) {
            throw new RuntimeException('Son aktif süper yönetici pasifleştirilemez.');
        }

        $hedef->forceFill(['disabled_at' => $aktif ? null : now()])->save();
        $this->audit($adminId, $aktif ? 'admin_enable' : 'admin_disable', 'admin:'.$hedefId);

        return $hedef;
    }

    /** Rol değiştir (yalnız superadmin çağırır — yetki kapısı bileşendedir). */
    public function rolDegistir(string $hedefId, string $rol, ?string $adminId): AdminUser
    {
        if (! isset(self::ROLLER[$rol])) {
            throw new RuntimeException('Geçersiz rol.');
        }

        /** @var AdminUser $hedef */
        $hedef = AdminUser::on($this->connection)->withoutGlobalScope('aktif')->findOrFail($hedefId);

        if ($rol !== 'superadmin' && $this->sonAktifSuperadminMi($hedef)) {
            throw new RuntimeException('Son aktif süper yöneticinin rolü düşürülemez.');
        }

        $hedef->forceFill(['role' => $rol])->save();
        $this->audit($adminId, 'admin_role', 'admin:'.$hedefId.' rol='.$rol);

        return $hedef;
    }

    /**
     * GENEL denetim günlüğü — TÜM bayiler. Bayi adı ve admin adı birleştirilir; ham uuid'lerden
     * oluşan bir günlük okunmaz ve okunmayan günlük denetlenmez.
     *
     * @param  array{admin?: string, eylem?: string, tenant?: string}  $filtre
     * @return LengthAwarePaginator<int, \stdClass>
     */
    public function denetimGunlugu(array $filtre = [], int $perPage = 50): LengthAwarePaginator
    {
        $q = DB::connection($this->connection)->table('panel_audit as a')
            ->leftJoin('admin_users as au', 'au.id', '=', 'a.admin_user_id')
            ->leftJoin('tenants as t', 't.id', '=', 'a.tenant_id')
            ->select('a.id', 'a.action', 'a.detail', 'a.created_at', 'a.tenant_id',
                'au.name as admin', 'au.email as admin_email', 't.name as bayi', 't.slug as bayi_kodu');

        if (($filtre['admin'] ?? '') !== '') {
            $q->where('a.admin_user_id', $filtre['admin']);
        }
        if (($filtre['eylem'] ?? '') !== '') {
            $q->where('a.action', $filtre['eylem']);
        }
        if (($filtre['tenant'] ?? '') !== '') {
            $q->where('a.tenant_id', $filtre['tenant']);
        }

        return $q->orderByDesc('a.created_at')->paginate($perPage, ['*'], 'gsayfa');
    }

    /**
     * Günlükte GEÇEN eylem türleri (süzgeç açılır listesi). Sabit bir liste yazmak yerine veriden
     * türetilir: yeni bir eylem eklendiğinde süzgeç kendiliğinden öğrenir, bayatlamaz.
     *
     * @return list<string>
     */
    public function eylemTurleri(): array
    {
        return DB::connection($this->connection)->table('panel_audit')
            ->select('action')->distinct()->orderBy('action')->pluck('action')->all();
    }

    // ------------------------------------------------------------------------------------

    private function emailKullanimda(string $email): bool
    {
        return AdminUser::on($this->connection)->withoutGlobalScope('aktif')
            ->where('email', $email)->exists();
    }

    /** Hedef, geriye kalan TEK aktif superadmin mi? (Kendini kilitleme koruması.) */
    private function sonAktifSuperadminMi(AdminUser $hedef): bool
    {
        if ($hedef->role !== 'superadmin' || $hedef->pasifMi()) {
            return false;
        }

        $digerAktifSuperadmin = AdminUser::on($this->connection)
            ->where('role', 'superadmin')
            ->whereKeyNot($hedef->id)
            ->exists(); // 'aktif' kapsamı burada İSTENİR: yalnız aktifler sayılmalı

        return ! $digerAktifSuperadmin;
    }

    private function audit(?string $adminId, string $action, ?string $detail = null): void
    {
        DB::connection($this->connection)->table('panel_audit')->insert([
            'id' => (string) Str::uuid7(),
            'admin_user_id' => $adminId,
            'tenant_id' => null, // hesap yönetimi bayi-üstüdür
            'action' => $action,
            'detail' => $detail,
            'created_at' => now(),
        ]);
    }
}
