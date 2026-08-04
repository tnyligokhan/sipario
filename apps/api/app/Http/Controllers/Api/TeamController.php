<?php

namespace App\Http\Controllers\Api;

use App\Http\Controllers\Controller;
use App\Http\Requests\UpdateCredentialsRequest;
use App\Http\Resources\UserResource;
use App\Models\User;
use Illuminate\Http\JsonResponse;
use Illuminate\Support\Facades\Hash;
use Illuminate\Support\Facades\Log;

/**
 * EKİP KİMLİK BİLGİLERİ — kuryenin giriş yapacağı kullanıcı adı ve parolası
 * (kullanıcı isteği 2026-08-04: "kuryenin giriş yapacağı hesabın bilgilerini düzenlenebilir
 * hale getirelim").
 *
 * NEDEN SENKRON YOLUNDAN DEĞİL, AYRI BİR UÇ NOKTADAN: `ProfileChangeApplier` kimlik alanlarını
 * bilerek dışarıda tutar (ad/telefon/aktiflik yazar; rol/e-posta/parola YAZMAZ) — kimlik yüzeyini
 * offline kuyruğa açmak yetki yükseltme vektörüdür. Üstelik parola değişimi ÇEVRİMDIŞI ANLAMSIZDIR:
 * doğrulama sunucudadır, hash'i istemci üretemez ve iki cihazın çevrimdışı yazdığı iki parolayı
 * LWW ile "birleştirmek" güvenlik açısından saçmadır. Bu yüzden işlem ONLINE ve senkron dışıdır.
 *
 * KİM: yalnız patron (route `role:patron`). KİME: yalnız kurye/operatör — patron hesapları
 * (kendisi dahil) bu uçtan DEĞİŞTİRİLEMEZ. Gerekçesi iki taraflı: (1) başka bir patronun
 * kimliğini ele geçirme yüzeyi doğmasın; (2) patron kendi kullanıcı adını/parolasını buradan
 * değiştirip yanlış yazarsa kendini uygulamadan kilitler ve kurtarma yolu ancak biziz (panel).
 * Patron parolası panelden sıfırlanır — o kapı zaten var.
 */
class TeamController extends Controller
{
    /** Bu uçtan kimliği değiştirilebilen roller. */
    private const HEDEF_ROLLER = ['kurye', 'operator'];

    /**
     * PATCH /api/v1/team/{user}/credentials
     */
    public function credentials(UpdateCredentialsRequest $request, string $user): JsonResponse
    {
        // RLS altında sorgulanır: başka bayinin kullanıcısı BULUNAMAZ (kırmızı çizgi #1 veritabanı
        // seviyesinde; buradaki 404 yalnız kullanıcıya anlamlı bir cevap vermek içindir).
        $hedef = User::query()->find($user);
        if ($hedef === null) {
            return response()->json(['message' => 'Kullanıcı bulunamadı.'], 404);
        }

        if (! in_array($hedef->role->value, self::HEDEF_ROLLER, true)) {
            return response()->json([
                'message' => 'Bu hesabın giriş bilgileri uygulamadan değiştirilemez; destek alın.',
            ], 403);
        }

        $data = $request->validated();
        $parolaDegisti = array_key_exists('password', $data);

        if (array_key_exists('username', $data)) {
            $hedef->username = $data['username'];
        }
        if ($parolaDegisti) {
            $hedef->password = Hash::make($data['password']);
        }
        $hedef->save();

        // PAROLA DEĞİŞTİYSE O KULLANICININ TÜM OTURUMLARI DÜŞER. Bu, özelliğin varlık
        // sebebinin yarısıdır: patron parolayı çoğu zaman işten ayrılan ya da telefonunu
        // kaybeden kurye için değiştirir; eski token yaşamaya devam ederse değişiklik hiçbir
        // şey yapmamış olur. VERİ KAYBI YOK (kırmızı çizgi #3): cihazdaki bekleyen outbox
        // kayıtları yerinde durur ve kurye yeni parolayla girdiğinde sunucuya akar.
        //
        // Kullanıcı adı değişimi oturumu DÜŞÜRMEZ: token kullanıcı kimliğine bağlıdır, adına
        // değil — ve sahadaki kuryeyi sırf patron yazım hatası düzeltti diye işinden etmek
        // gereksiz bir bedeldir.
        if ($parolaDegisti) {
            $hedef->tokens()->delete();
        }

        // KVKK / kırmızı çizgi #4: log'a kimlik bilgisi YAZILMAZ — ne kullanıcı adı, ne parola.
        // Yalnız "kim, kime, neyi" izlenebilsin diye kimlikler ve değişen alanlar yazılır.
        Log::info('Ekip kimlik bilgisi guncellendi', [
            'tenant_id' => $request->user()->tenant_id,
            'actor_id' => $request->user()->id,
            'target_id' => $hedef->id,
            'username_changed' => array_key_exists('username', $data),
            'password_changed' => $parolaDegisti,
        ]);

        return response()->json([
            'user' => new UserResource($hedef),
            'sessions_revoked' => $parolaDegisti,
        ]);
    }
}
