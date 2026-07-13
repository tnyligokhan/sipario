<?php

namespace App\Http\Requests;

use App\Support\Sync\SyncService;
use Illuminate\Foundation\Http\FormRequest;

/**
 * Senkron push isteği (tek yazma yüzeyi). Girdi doğrulaması API sınırında (kural). tenant_id
 * gövdeden ALINMAZ — oturumdaki kullanıcının tenant'ıdır (RLS WITH CHECK zorlar).
 *
 * entity_type/op birleşiminin geçerliliği (ör. order.created payload'ı) ChangeApplier'da olay
 * bazında denetlenir; geçersiz birleşim tüm partiyi düşürmez, o olay 'rejected' döner.
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
            'events.*.client_event_id' => ['required', 'uuid'],
            'events.*.entity_type' => ['required', 'string', 'in:customer,customer_phone,customer_address,product,order,ledger'],
            'events.*.op' => ['required', 'string', 'in:upsert,delete,created,line_added,line_removed,delivered,cancelled,payment_set,note_set,entry'],
            'events.*.occurred_at' => ['required', 'date'],
            'events.*.payload' => ['required', 'array'],
            'events.*.device_id' => ['nullable', 'uuid'],
        ];
    }
}
