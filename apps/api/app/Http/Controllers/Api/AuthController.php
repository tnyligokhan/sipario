<?php

namespace App\Http\Controllers\Api;

use App\Enums\TenantStatus;
use App\Http\Controllers\Controller;
use App\Http\Requests\LoginRequest;
use App\Http\Resources\TenantResource;
use App\Http\Resources\UserResource;
use App\Models\Device;
use App\Models\User;
use Illuminate\Http\JsonResponse;
use Illuminate\Http\Request;
use Illuminate\Support\Carbon;
use Illuminate\Support\Facades\DB;
use Illuminate\Support\Facades\Hash;

class AuthController extends Controller
{
    /**
     * Zamanlama yan-kanalı önlemi: e-posta bulunamadığında da bu SABİT, gerçek bcrypt hash'ine
     * karşı Hash::check koşarız ki yanıt süresi "kullanıcı var mı" bilgisini sızdırmasın.
     * cost=12 üretimdeki BCRYPT_ROUNDS ile eşleşir (gerçek kullanıcı doğrulamasıyla aynı süre).
     * Her istekte Hash::make ÇAĞRILMAZ — sabit hardcoded değer.
     */
    private const DUMMY_PASSWORD_HASH = '$2y$12$SIPdK92BiNANCVLYxTNjPOWYDzM9szOpCdGt9bIA3l82vGXOBI0rS';

    /**
     * POST /api/v1/auth/login  (public)
     *
     * Email global tekil olduğundan lookup deterministik tek satır döner. Tenant henüz set
     * olmadığından kullanıcı, RLS'i atlayan SECURITY DEFINER fonksiyonuyla bulunur; token üretimi
     * ise doğru tenant bağlamı kurulmuş bir transaction içinde yapılır (RLS'i pozitif de sınar).
     */
    public function login(LoginRequest $request): JsonResponse
    {
        $data = $request->validated();

        $row = DB::selectOne('SELECT * FROM sipario_login_lookup(?)', [$data['email']]);

        // Hash::check HER ZAMAN koşar (satır yoksa dummy hash'e karşı) → yanıt süresi e-postanın
        // varlığını sızdırmaz (zamanlama yan-kanalı kapatılır). Kısa-devre YOK: önce doğrula, sonra karar ver.
        $passwordValid = Hash::check($data['password'], $row->password ?? self::DUMMY_PASSWORD_HASH);

        // Nötr hata: email var/yok ayrımını sızdırma (kullanıcı numaralandırma önlenir).
        if ($row === null || ! $passwordValid) {
            return response()->json(['message' => 'E-posta veya parola hatalı.'], 401);
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
     * @param  array<string, mixed>  $device
     */
    private function upsertDevice(User $user, array $device): void
    {
        Device::updateOrCreate(
            ['id' => $device['device_id']],
            [
                'tenant_id' => $user->tenant_id,
                'user_id' => $user->id,
                'platform' => $device['platform'],
                'model' => $device['model'] ?? null,
                'os_version' => $device['os_version'] ?? null,
                'app_version' => $device['app_version'] ?? null,
                'push_token' => $device['push_token'] ?? null,
                'last_seen_at' => now(),
            ]
        );
    }
}
