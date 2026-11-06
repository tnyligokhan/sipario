<?php

namespace App\Support\Sync;

use InvalidArgumentException;

/**
 * `tenant_settings.message_templates` sınır doğrulaması — bayinin müşteriye giden bilgilendirme
 * mesajları (kullanıcı isteği 2026-11-06). Biçim:
 *
 *   { "sistem": { "<tür>": "metin" }, "ozel": [ { "id", "baslik", "metin" } ] }
 *
 * `sistem` yalnız bayinin DEĞİŞTİRDİĞİ hazır metinleri tutar. Tür anahtarları sunucuda bilinmez ve
 * bilinçli olarak beyaz listeye alınmaz: yeni tür istemciyle gelir, eski sunucu onu silmemeli.
 * Sayısı yine sınırlıdır.
 *
 * Kırpma YOK (`reminder_template` çizgisi): yarım kalmış metin müşteriye yarım gider, istisna yalnız
 * bu olayı 'rejected' yapar.
 */
final class MesajSablonlari
{
    public const AZAMI_OZEL = 20;

    public const AZAMI_SISTEM = 40;

    public const AZAMI_AD = 40;

    public const AZAMI_ANAHTAR = 64;

    public const AZAMI_METIN = 1000;

    /**
     * @return array{sistem?: array<string, string>, ozel?: list<array{id: string, baslik: string, metin: string}>}|null
     */
    public static function dogrula(mixed $ham): ?array
    {
        if ($ham === null || $ham === []) {
            return null;
        }
        if (! is_array($ham) || array_is_list($ham)) {
            throw new InvalidArgumentException('message_templates nesne olmalı');
        }

        $sistem = self::sistem($ham['sistem'] ?? []);
        $ozel = self::ozel($ham['ozel'] ?? []);

        $temiz = [];
        if ($sistem !== []) {
            $temiz['sistem'] = $sistem;
        }
        if ($ozel !== []) {
            $temiz['ozel'] = $ozel;
        }

        return $temiz === [] ? null : $temiz;
    }

    /**
     * @return array<string, string>
     */
    private static function sistem(mixed $ham): array
    {
        if (! is_array($ham)) {
            throw new InvalidArgumentException('message_templates.sistem nesne olmalı');
        }
        if (count($ham) > self::AZAMI_SISTEM) {
            throw new InvalidArgumentException('message_templates.sistem çok fazla kayıt taşıyor');
        }

        $temiz = [];
        foreach ($ham as $anahtar => $metin) {
            if (! is_string($anahtar) || mb_strlen($anahtar) > self::AZAMI_ANAHTAR) {
                throw new InvalidArgumentException('message_templates.sistem anahtarı geçersiz');
            }
            $temiz[$anahtar] = self::metin($metin);
        }

        return $temiz;
    }

    /**
     * @return list<array{id: string, baslik: string, metin: string}>
     */
    private static function ozel(mixed $ham): array
    {
        if (! is_array($ham) || ! array_is_list($ham)) {
            throw new InvalidArgumentException('message_templates.ozel düz bir dizi olmalı');
        }
        if (count($ham) > self::AZAMI_OZEL) {
            throw new InvalidArgumentException('message_templates.ozel en çok '.self::AZAMI_OZEL.' mesaj taşıyabilir');
        }

        $temiz = [];
        foreach ($ham as $mesaj) {
            if (! is_array($mesaj)) {
                throw new InvalidArgumentException('message_templates.ozel elemanı nesne olmalı');
            }
            $id = $mesaj['id'] ?? null;
            $baslik = $mesaj['baslik'] ?? null;
            if (! is_string($id) || $id === '' || mb_strlen($id) > self::AZAMI_ANAHTAR) {
                throw new InvalidArgumentException('message_templates.ozel kimliği geçersiz');
            }
            if (! is_string($baslik) || trim($baslik) === '' || mb_strlen($baslik) > self::AZAMI_AD) {
                throw new InvalidArgumentException('message_templates.ozel adı en çok '.self::AZAMI_AD.' karakter olabilir');
            }
            $temiz[] = ['id' => $id, 'baslik' => trim($baslik), 'metin' => self::metin($mesaj['metin'] ?? null)];
        }

        return $temiz;
    }

    private static function metin(mixed $ham): string
    {
        if (! is_string($ham) || trim($ham) === '' || mb_strlen($ham) > self::AZAMI_METIN) {
            throw new InvalidArgumentException('message_templates metni en çok '.self::AZAMI_METIN.' karakter olabilir');
        }

        return $ham;
    }
}
