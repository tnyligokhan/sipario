<?php

namespace App\Http\Controllers\Api;

use App\Enums\TenantStatus;
use App\Enums\UserRole;
use App\Http\Controllers\Controller;
use App\Http\Requests\LoginRequest;
use App\Http\Resources\TenantResource;
use App\Http\Resources\UserResource;
use App\Models\Device;
use App\Models\User;
use App\Support\PostaAdresi;
use Illuminate\Database\QueryException;
use Illuminate\Http\JsonResponse;
use Illuminate\Http\Request;
use Illuminate\Support\Carbon;
use Illuminate\Support\Facades\DB;
use Illuminate\Support\Facades\Hash;
use Illuminate\Support\Facades\Log;
use Illuminate\Support\Facades\Password;
use Illuminate\Support\Str;
use Throwable;

class AuthController extends Controller
{
    /**
     * Zamanlama yan-kanalı önlemi: kullanıcı bulunamadığında da bu SABİT, gerçek bcrypt hash'ine
     * karşı Hash::check koşarız ki yanıt süresi "kullanıcı var mı" bilgisini sızdırmasın.
     * cost=12 üretimdeki BCRYPT_ROUNDS ile eşleşir (gerçek kullanıcı doğrulamasıyla aynı süre).
     * Her istekte Hash::make ÇAĞRILMAZ — sabit hardcoded değer.
     */
    private const DUMMY_PASSWORD_HASH = '$2y$12$SIPdK92BiNANCVLYxTNjPOWYDzM9szOpCdGt9bIA3l82vGXOBI0rS';

    /**
     * POST /api/v1/auth/login  (public)
     *
     * Tasarım `s-giris.jsx`: **firma kodu + kullanıcı adı + parola**. Kullanıcı adı tenant
     * içinde tekildir; (tenants.slug, users.username) çifti deterministik tek satır döner.
     * Tenant henüz set olmadığından kullanıcı, RLS'i atlayan SECURITY DEFINER fonksiyonuyla
     * bulunur; token üretimi ise doğru tenant bağlamı kurulmuş bir transaction içinde yapılır
     * (RLS'i pozitif de sınar).
     */
    public function login(LoginRequest $request): JsonResponse
    {
        $data = $request->validated();

        $row = DB::selectOne(
            'SELECT * FROM sipario_login_lookup(?, ?)',
            [$data['tenant_code'], $data['username']]
        );

        // Hash::check HER ZAMAN koşar (satır yoksa dummy hash'e karşı) → yanıt süresi kullanıcının
        // varlığını sızdırmaz (zamanlama yan-kanalı kapatılır). Kısa-devre YOK: önce doğrula, sonra karar ver.
        $passwordValid = Hash::check($data['password'], $row->password ?? self::DUMMY_PASSWORD_HASH);

        // Nötr hata: firma kodu / kullanıcı adı / parola hangisinin yanlış olduğunu SÖYLEME —
        // yoksa geçerli firma kodları ve kullanıcı adları tek tek numaralandırılabilir.
        if ($row === null || ! $passwordValid) {
            return response()->json(['message' => 'Firma kodu, kullanıcı adı veya parola hatalı.'], 401);
        }

        // Pasif kullanıcı, trial/active olmayan bayi, veya SÜRESİ DOLMUŞ abonelik (FAZ 5a): nötr 403.
        // valid_until geçmişse status hâlâ trial/active olsa bile giriş kapalı (süre tek çıpa; NULL geç).
        // Kontrol Hash::check'ten SONRA (sabit süre zaten harcandı → zamanlama yan-kanalı açılmaz).
        $tenantStatus = TenantStatus::tryFrom($row->tenant_status);
        $expired = $row->valid_until !== null && Carbon::parse($row->valid_until)->isPast();
        if ($row->status !== 'active' || $tenantStatus === null || ! $tenantStatus->allowsLogin() || $expired) {
            return response()->json(['message' => 'Hesabınız şu anda kullanıma kapalı. Destek alın.'], 403);
        }

        return DB::transaction(function () use ($row, $data) {
            // Bu transaction boyunca kiracı bağlamını kur → User ve Device RLS altında görünür.
            DB::statement("SELECT set_config('app.tenant_id', ?, true)", [$row->tenant_id]);

            $user = User::findOrFail($row->id);

            $token = $user->createToken('mobile');
            // Token satırına tenant_id yaz: sonraki isteklerde middleware bunu okuyup app.tenant_id set eder.
            $token->accessToken->forceFill(['tenant_id' => $user->tenant_id])->save();

            $user->forceFill(['last_login_at' => now()])->save();

            if (isset($data['device'])) {
                $this->upsertDevice($user, $data['device']);
            }

            return response()->json([
                'token' => $token->plainTextToken,
                'user' => new UserResource($user),
                'tenant' => new TenantResource($user->tenant),
            ], 200);
        });
    }

    /** GET /api/v1/auth/me  (korumalı) — tenant-scope okuma; RLS'in çalıştığını da kanıtlar. */
    public function me(Request $request): JsonResponse
    {
        $user = $request->user();
        $tenant = $user->tenant;

        // users.tenant_id NOT NULL + FK olduğundan bu üretimde oluşamaz; yine de tenant satırı
        // (ör. RLS bağlamı beklenmedik şekilde boşsa) yoksa 500 yerine nötr, kontrollü yanıt dön.
        abort_if($tenant === null, 409, 'Hesabınızın kiracı bağlamı bulunamadı, destek alın.');

        return response()->json([
            'user' => new UserResource($user),
            'tenant' => new TenantResource($tenant),
        ]);
    }

    /** POST /api/v1/auth/logout  (korumalı) — yalnız geçerli token'ı iptal eder. */
    public function logout(Request $request): JsonResponse
    {
        $request->user()->currentAccessToken()->delete();

        return response()->json(status: 204);
    }

    /**
     * Login çağrısındaki opsiyonel cihaz bloğunu idempotent kaydeder.
     * tenant_id gövdeden ALINMAZ — oturumdaki kullanıcının tenant'ıdır.
     *
     * CİHAZ KAYDI GİRİŞİ ASLA DÜŞÜRMEZ (2026-07-29 saha hatası). `device_id` istemcide üretilir
     * ve kurulum boyunca KALICIDIR; aynı telefon başka bir bayiye giriş yaptığında o kimlik
     * başka bir kiracının satırında durur. `updateOrCreate` önce SELECT atar, RLS o satırı
     * GİZLER, dolayısıyla "yok" sanıp INSERT'e geçer ve birincil anahtar çakışır —
     * `SQLSTATE[23505] devices_pkey`. Kullanıcı, doğru parolayı girdiği hâlde ham bir SQL
     * hatasıyla karşılaşıyordu; oysa kimlik doğrulama BAŞARILIYDI.
     *
     * Politika `DeviceController::store` ile AYNI: başka bayinin cihaz satırına DOKUNULMAZ
     * (sahibini değiştirmek, o bayinin bildirim kaydını sessizce çalmak olurdu). Fark şu ki
     * orası ayrı bir uç noktadır ve 409 döner; BURASI giriş yoludur ve cihaz bloğu OPSİYONELDİR
     * — giriş başarılıysa cevap 200 olmalıdır. Durum sessizce yutulmaz, log'a yazılır.
     *
     * @param  array<string, mixed>  $device
     */
    private function upsertDevice(User $user, array $device): void
    {
        try {
            Device::updateOrCreate(
                ['id' => $device['device_id']],
                Device::kayitNitelikleri($user, $device)
            );
        } catch (QueryException $e) {
            // 23505 = unique_violation. BAŞKA hiçbir veritabanı hatası yutulmaz.
            if ($e->getCode() !== '23505') {
                throw $e;
            }

            Log::warning('Cihaz kaydi atlandi: device_id baska bir kiracida', [
                'tenant_id' => $user->tenant_id,
                'user_id' => $user->id,
            ]);
        }
    }

    /**
     * POST /api/v1/auth/parola-sifirla  (public, throttle:parola-sifirla)
     *
     * ══ NEDEN VAR (kullanıcı isteği 2026-08-13) ═════════════════════════════════════════════
     * Mobilde parola kurtarma yolu HİÇ YOKTU: uygulamada "şifremi unuttum" geçen tek bir satır
     * bile aranmadı ve bulunamadı. Kullanıcı parolasını unuttuğunda yapabildiği tek şey birini
     * aramaktı — pilot bayilerde bu, birinci sıradaki destek çağrısıdır.
     *
     * ══ İKİ AYRI GERÇEK, TEK UÇ NOKTA ═══════════════════════════════════════════════════════
     * PATRON'un e-postası gerçektir; sıfırlama bağlantısı ona gider (site akışının aynısı).
     * KURYE/OPERATÖR'ün e-postası SENTETİKTİR (`<kullanıcı>@<kod>.sipario.local`) — o adrese
     * gönderilen posta hiçbir yere ulaşmaz. Onlar için bu uç nokta bilinçli olarak HİÇBİR ŞEY
     * YAPMAZ; parolalarını bayi yöneticisi belirler ve mobil ekran bunu AÇIKÇA yazar.
     *
     * ⚠️ YANIT HER KOŞULDA AYNI ve bu pazarlıksız: "gönderildi" / "böyle bir hesap yok" /
     * "bu hesap kurye" ayrımı yapmak, firma kodu + kullanıcı adı çiftlerini tek tek
     * numaralandırmaya açık kapı bırakırdı (`login`in nötr hata kuralının aynısı). Ekran da bu
     * yüzden iki gerçeği ÖNCEDEN yazar — cevaptan öğrenilemeyecek şeyi baştan söylemek, hem
     * dürüst hem güvenlidir.
     *
     * OWNER BAĞLANTISI: istek kimliksizdir, yani `app.tenant_id` kurulmamıştır ve RLS altında
     * hiçbir kullanıcı görünmez. Site tarafı (`Livewire\Site\Parola`) aynı sebeple owner
     * bağlantısı kullanıyor; buradaki okuma da onun deseni.
     */
    public function parolaSifirla(Request $request): JsonResponse
    {
        $data = $request->validate([
            'tenant_code' => ['required', 'string', 'max:80'],
            'username' => ['required', 'string', 'max:60'],
        ]);

        // Nötr yanıt ÖNCE kurulur ve her yoldan bu döner — aşağıdaki hiçbir dal onu değiştirmez.
        $notr = response()->json([
            'message' => 'Bu hesap için kayıtlı bir e-posta adresi varsa sıfırlama bağlantısı '
                .'gönderildi. Gelen kutunuzu kontrol edin.',
        ]);

        try {
            /** @var User|null $kullanici */
            $kullanici = User::on('pgsql_owner')
                ->join('tenants', 'tenants.id', '=', 'users.tenant_id')
                ->where('tenants.slug', Str::lower(trim($data['tenant_code'])))
                ->where('users.username', Str::lower(trim($data['username'])))
                ->where('users.status', 'active')
                ->where('users.role', UserRole::Patron->value)
                ->select('users.*')
                ->first();

            // Kullanıcı yok · pasif · patron değil → sessizce çık. Hangi koşulun tutmadığı
            // İSTEMCİYE SÖYLENMEZ (numaralandırma).
            if ($kullanici === null || ! PostaAdresi::gercekMi($kullanici->email)) {
                return $notr;
            }

            $depo = Password::getRepository();

            // Framework'ün 60 saniyelik kendi throttle'ı: aynı token ard arda üretilmez.
            // Hız sınırlayıcının (dakikada 3) ALTINDAKİ ikinci kapı.
            if ($depo->recentlyCreatedToken($kullanici)) {
                return $notr;
            }

            // Bağlantı adresi ve postanın gövdesi `AppServiceProvider`da bir kez kuruluyor
            // (`ResetPassword::createUrlUsing` + `toMailUsing`) — burada kurulmaz. Gerekçe
            // `Livewire\Site\Parola::baglantiGonder()` başlığında.
            $kullanici->sendPasswordResetNotification($depo->create($kullanici));
        } catch (Throwable $e) {
            // Posta/altyapı hatası İSTEMCİYE YANSIMAZ (yine numaralandırma) ama sessizce de
            // kaybolmaz: `report` ile günlüğe düşer.
            report($e);
        }

        return $notr;
    }
}
