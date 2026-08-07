<?php

namespace App\Http\Requests;

use App\Support\Sync\SyncService;
use Illuminate\Foundation\Http\FormRequest;

/**
 * Senkron push isteği (tek yazma yüzeyi). tenant_id gövdeden ALINMAZ — oturumdaki kullanıcının
 * tenant'ıdır (RLS WITH CHECK zorlar).
 *
 * BURADA YALNIZ ZARF DOĞRULANIR (2026-08-05). Olay İÇERİĞİNİN kuralları (client_event_id /
 * entity_type / op / occurred_at / payload / device_id) buradan ALINDI ve `EventValidator`a taşındı;
 * geçersiz olay artık tüm partiyi düşürmez, olay bazında 'rejected' döner (sınıfın açıklaması bunu
 * zaten VAAT EDİYORDU, kuralları tutmuyordu — arıza tam bu çelişkiden doğdu, bkz. EventValidator).
 *
 * Zarf hatası 422 KALIR ve bu kasıtlıdır: `events` yok / dizi değil / boş / MAX_EVENTS aşımı bir
 * PROTOKOL hatasıdır — tekrar denemek çözmez, ama reddedilecek bir "olay listesi" de yoktur, yani
 * kısmi başarı diye bir şey tanımlanamaz. Olay içeriği ise istemci-kaynaklı VERİ hatasıdır ve tek
 * bir bozuk satırın kuyruğun tamamını kilitlemesi kabul edilemez.
 */
class SyncPushRequest extends FormRequest
{
    public function authorize(): bool
    {
        return true; // auth:sanctum + tenant middleware korur
    }

    /** @return array<string, mixed> */
    public function rules(): array
    {
        return [
            'events' => ['required', 'array', 'min:1', 'max:'.SyncService::MAX_EVENTS],
        ];
    }
}
