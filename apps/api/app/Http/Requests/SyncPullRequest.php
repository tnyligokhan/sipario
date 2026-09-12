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
            /**
             * SNAPSHOT SAYFALAMA YETENEK BİLDİRİMİ (2026-09-12).
             *
             * AYRI BİR BAYRAK, "imlecin varlığı" DEĞİL — ve bu bir tercih değil zorunluluktu:
             * ilk sayfada imleç BOŞTUR, Laravel'in `ConvertEmptyStringsToNull` middleware'i boş
             * metni `null`a çevirir ve yetenek bildirimi sessizce kaybolur. Ölçüldü: bayrak
             * eklenmeden önce sayfalı istek tek parça snapshot alıyordu.
             *
             * Bayrağı GÖNDERMEYEN eski istemci eski davranışı (tek parça) görür. Sayfalamayı
             * koşulsuz açmak sahadaki 1.2.0/1.3.0 telefonlarını KIRARDI — onlar snapshot modunda
             * `has_more`u izlemiyor, ilk sayfada imleci sona damgalar ve geri kalanı bir daha
             * hiç istemezlerdi.
             */
            'sayfali' => ['nullable', 'boolean'],

            /** Devam imleci: "<tip>:<son-id>" — bir önceki sayfanın `snapshot_cursor` alanı. */
            'snapshot_cursor' => ['nullable', 'string', 'max:80'],
        ];
    }
}
