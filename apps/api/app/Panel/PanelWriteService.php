<?php

namespace App\Panel;

use App\Models\Customer;
use App\Models\CustomerAddress;
use App\Models\CustomerPhone;
use App\Models\Product;
use Illuminate\Support\Str;
use RuntimeException;

/**
 * Panelden TEK TEK müşteri/ürün yazma (5c-3 · D3). Kullanıcı kararı 2026-08-01: panel müşteri ve
 * ürün girebilir/düzenleyebilir; sipariş, defter ve kasa SALT-OKUNUR kalır (kırmızı çizgi #2).
 *
 * Yazma yolunun kuralları (panel rolüyle yazılmaz · elle SQL yok · her yazma denetlenir · abonelik
 * kilidi paneli de bağlar) ortak temelde anlatılmıştır: {@see PanelSyncYazici}.
 *
 * BU SINIFIN KENDİ MESELESİ — DEĞER KORUMA TUZAĞI (ChangeApplier sözleşmesi): istemci upsert'te
 * SATIRIN TAMAMINI gönderir; gönderilmeyen alan null'lanır. Yani yalnız adı düzenleyen bir panel
 * formu, `blacklisted_at`i (kara liste) ve ürünün `image_url`ini SESSİZCE SİLERDİ. Bu yüzden
 * düzenlemede mevcut satır okunur ve dokunulmayan alanlar aynen geri gönderilir (testle kilitli).
 */
class PanelWriteService extends PanelSyncYazici
{
    /**
     * Müşteri ekle/düzenle. `id` verilirse düzenleme, verilmezse yeni kayıt.
     * Telefon ve adres opsiyoneldir; verilirse müşterinin BİRİNCİL kaydı olarak yazılır.
     *
     * @param  array{id?: string|null, ad: string, not?: string|null, telefon?: string|null, adres?: string|null, bolge?: string|null}  $veri
     * @return array{id: string, durum: string, mesaj: string|null}
     */
    public function musteriKaydet(string $tenantId, array $veri, ?string $adminId): array
    {
        $ad = trim((string) $veri['ad']);
        if ($ad === '') {
            throw new RuntimeException('Müşteri adı zorunludur.');
        }

        $sonuc = $this->rlsIcinde($tenantId, function () use ($tenantId, $veri, $ad) {
            $istenen = $veri['id'] ?? null;
            /** @var Customer|null $mevcut */
            $mevcut = $istenen !== null ? Customer::query()->find($istenen) : null;

            // DÜZENLEME AKIŞI UPSERT DEĞİLDİR (lead kararı): id verilmiş ama kayıt yoksa (silinmiş
            // ya da RLS altında görünmeyen bir kayıt) sessizce YENİ müşteri yaratmak iki yalan
            // söylerdi — kullanıcıya "düzenledim", denetim günlüğüne `customer_update`. Kopya kayıt
            // da sahada en pahalı kirliliktir. Bulunamayan id BAŞARISIZLIKTIR.
            if ($istenen !== null && $mevcut === null) {
                throw new RuntimeException('Düzenlenecek müşteri bulunamadı; sayfayı tazeleyip tekrar deneyin.');
            }

            $id = $mevcut->id ?? (string) Str::uuid7();

            $telefonKaydi = $mevcut !== null ? $this->birincilKayit(CustomerPhone::class, $id) : null;
            $adresKaydi = $mevcut !== null ? $this->birincilKayit(CustomerAddress::class, $id) : null;
            // Müşteri, telefonu ve adresi TEK karardır; damgaları ayrışmamalı (ChangeApplier'ın
            // cascade silmede izlediği kuralla aynı).
            $damga = $this->damga([$mevcut, $telefonKaydi, $adresKaydi]);

            $olaylar = [$this->olay('customer', 'upsert', [
                'id' => $id,
                'name' => $ad,
                'note' => $this->bosNull($veri['not'] ?? null),
                // Dokunulmayan alan KORUNUR: form kara listeyi göstermez, temizlemesi de gerekmez.
                'blacklisted_at' => $mevcut?->blacklisted_at?->toIso8601String(),
            ], $damga)];

            $telefon = Telefon::e164($veri['telefon'] ?? null);
            if ($telefon !== null) {
                $olaylar[] = $this->olay('customer_phone', 'upsert', [
                    'id' => $telefonKaydi !== null ? (string) $telefonKaydi->getKey() : (string) Str::uuid7(),
                    'customer_id' => $id,
                    'phone_e164' => $telefon,
                    'phone_last10' => Telefon::son10($telefon),
                    'is_primary' => true,
                ], $damga);
            }

            $adres = $this->bosNull($veri['adres'] ?? null);
            if ($adres !== null) {
                $olaylar[] = $this->olay('customer_address', 'upsert', [
                    'id' => $adresKaydi !== null ? (string) $adresKaydi->getKey() : (string) Str::uuid7(),
                    'customer_id' => $id,
                    'address_text' => $adres,
                    'region' => $this->bosNull($veri['bolge'] ?? null),
                    'is_primary' => true,
                ], $damga);
            }

            return [$id, $this->push($tenantId, $olaylar)];
        });

        [$id, $push] = $sonuc;
        $durum = $this->durumOzeti($push);

        if ($durum['durum'] === 'applied') {
            $this->audit($adminId, $tenantId, ($veri['id'] ?? null) !== null ? 'customer_update' : 'customer_create', 'customer:'.$id);
        }

        return ['id' => $id] + $durum;
    }

    /**
     * Müşteriyi KARA LİSTEYE al / listeden çıkar — panelin "pasifleştirme"si budur.
     *
     * Neden silme değil: müşteri SİLİNMEZ (kullanıcı kuralı) ve `customers`ta `is_active` kolonu
     * yoktur. Alan adayları arasında anlamı karşılayan tek şey `blacklisted_at`tir: kayıt listede
     * kalır, geçmişi durur, YENİ SİPARİŞ alamaz — "pasif müşteri"nin sahadaki karşılığı tam budur.
     * Geri alınabilir olması da bilinçli (silme tek yönlüdür, bu değil).
     *
     * @return array{id: string, durum: string, mesaj: string|null}
     */
    public function musteriKaraListe(string $tenantId, string $customerId, bool $karaListe, ?string $adminId): array
    {
        $push = $this->rlsIcinde($tenantId, function () use ($tenantId, $customerId, $karaListe) {
            /** @var Customer|null $mevcut */
            $mevcut = Customer::query()->find($customerId);
            if ($mevcut === null) {
                throw new RuntimeException('Müşteri bu bayide bulunamadı.');
            }

            return $this->push($tenantId, [$this->olay('customer', 'upsert', [
                'id' => $customerId,
                'name' => $mevcut->name,
                'note' => $mevcut->note,
                'blacklisted_at' => $karaListe ? now()->toIso8601String() : null,
            ], $this->damga([$mevcut]))]);
        });

        $durum = $this->durumOzeti($push);
        if ($durum['durum'] === 'applied') {
            $this->audit($adminId, $tenantId, $karaListe ? 'customer_blacklist' : 'customer_unblacklist', 'customer:'.$customerId);
        }

        return ['id' => $customerId] + $durum;
    }

    /**
     * Ürün ekle/düzenle.
     *
     * @param  array{id?: string|null, ad: string, fiyat_kurus: int, birim?: string|null, barkod?: string|null}  $veri
     * @return array{id: string, durum: string, mesaj: string|null}
     */
    public function urunKaydet(string $tenantId, array $veri, ?string $adminId): array
    {
        $ad = trim((string) $veri['ad']);
        if ($ad === '') {
            throw new RuntimeException('Ürün adı zorunludur.');
        }
        $fiyat = (int) $veri['fiyat_kurus'];
        if ($fiyat < 0) {
            throw new RuntimeException('Fiyat negatif olamaz.');
        }

        [$id, $push] = $this->rlsIcinde($tenantId, function () use ($tenantId, $veri, $ad, $fiyat) {
            $istenen = $veri['id'] ?? null;
            /** @var Product|null $mevcut */
            $mevcut = $istenen !== null ? Product::query()->find($istenen) : null;

            // Müşteri tarafıyla AYNI kural (lead kararı): düzenleme akışı upsert değildir.
            if ($istenen !== null && $mevcut === null) {
                throw new RuntimeException('Düzenlenecek ürün bulunamadı; sayfayı tazeleyip tekrar deneyin.');
            }

            $id = $mevcut->id ?? (string) Str::uuid7();

            return [$id, $this->push($tenantId, [$this->olay('product', 'upsert', [
                'id' => $id,
                'name' => $ad,
                'unit_price_kurus' => $fiyat,
                'unit' => $this->bosNull($veri['birim'] ?? null) ?? ($mevcut->unit ?? 'adet'),
                'barcode' => $this->bosNull($veri['barkod'] ?? null),
                // Panelde görsel alanı YOK; cihazdan gelen görsel düzenlemede silinmemeli.
                'image_url' => $mevcut->image_url ?? null,
                // Aktiflik ayrı düğmenin işi; kaydetmek pasif ürünü diriltmemeli.
                'is_active' => $mevcut->is_active ?? true,
            ], $this->damga([$mevcut]))])];
        });

        $durum = $this->durumOzeti($push);
        if ($durum['durum'] === 'applied') {
            $this->audit($adminId, $tenantId, ($veri['id'] ?? null) !== null ? 'product_update' : 'product_create', 'product:'.$id);
        }

        return ['id' => $id] + $durum;
    }

    /**
     * Ürünü pasifleştir / yeniden etkinleştir (`is_active`). Silme YOK — ürün siparişlerde
     * referanslıdır ve geçmiş bozulmamalıdır.
     *
     * @return array{id: string, durum: string, mesaj: string|null}
     */
    public function urunAktiflik(string $tenantId, string $productId, bool $aktif, ?string $adminId): array
    {
        $push = $this->rlsIcinde($tenantId, function () use ($tenantId, $productId, $aktif) {
            /** @var Product|null $mevcut */
            $mevcut = Product::query()->find($productId);
            if ($mevcut === null) {
                throw new RuntimeException('Ürün bu bayide bulunamadı.');
            }

            return $this->push($tenantId, [$this->olay('product', 'upsert', [
                'id' => $productId,
                'name' => $mevcut->name,
                'unit_price_kurus' => $mevcut->unit_price_kurus,
                'unit' => $mevcut->unit,
                'barcode' => $mevcut->barcode,
                'image_url' => $mevcut->image_url,
                'is_active' => $aktif,
            ], $this->damga([$mevcut]))]);
        });

        $durum = $this->durumOzeti($push);
        if ($durum['durum'] === 'applied') {
            $this->audit($adminId, $tenantId, $aktif ? 'product_activate' : 'product_deactivate', 'product:'.$productId);
        }

        return ['id' => $productId] + $durum;
    }
}
