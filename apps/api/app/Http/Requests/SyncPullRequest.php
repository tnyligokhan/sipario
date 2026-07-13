<?php

namespace App\Http\Requests;

use Illuminate\Foundation\Http\FormRequest;

/**
 * Senkron pull isteği (tek okuma yüzeyi). since=0 (veya yok) → tam snapshot; since>0 → delta.
 * limit sayfa büyüklüğü (delta); has_more true ise istemci cursor ile döngüye devam eder.
 */
class SyncPullRequest extends FormRequest
{
    public function authorize(): bool
    {
        return true; // auth:sanctum + tenant middleware korur
    }

    /** @return array<string, mixed> */
    public function rules(): array
    {
        return [
            'since' => ['nullable', 'integer', 'min:0'],
            'limit' => ['nullable', 'integer', 'min:1', 'max:1000'],
        ];
    }
}
