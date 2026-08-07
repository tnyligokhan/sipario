<?php

namespace App\Livewire\Panel\Concerns;

use App\Panel\TenantAdminService;
use Illuminate\Support\Facades\Auth;
use Illuminate\Support\Str;

/**
 * PARA EKRANLARININ ORTAK KAPISI (Ödemeler · Paketler · Gelir-Gider · Bildirimler).
 *
 * KAPI BİLEŞENİN İÇİNDEDİR, ROUTE'TA DEĞİL (5c-3 güvenlik incelemesinin dersi): `auth:admin`
 * middleware'i sayfayı korur ama bir Livewire EYLEMİ doğrudan da çağrılabilir; Blade'de düğmeyi
 * gizlemek yetki denetimi değildir. Bu yüzden `mount` VE her yazma eylemi ayrı ayrı kapıdan geçer.
 *
 * YAZMA = SUPERADMIN. TenantDetail'in koyduğu ayrımın aynısı: destek ekibi bayinin işini yapmasına
 * yardım edebilir (müşteri/ürün girişi — geri alınabilir), ama ABONELİĞE ve PARAYA dokunamaz. Bu
 * dört ekranın her yazması ya bir aboneliği uzatır, ya bir kotayı büyütür, ya şirket defterine
 * kalem yazar; üçü de parasal karardır.
 *
 * REDDEDİLEN DENEME DE DENETİME DÜŞER — `TenantAdminService::auditRed()` ile (`<eylem>_denied`).
 * Başarılı yazmaların kaydını `App\Abonelik` servisleri atar (`payment_manual`, `addon_grant`,
 * `expense_create`, `plan_update`, ...); geriye kalan boşluk REDDEDİLEN denemedir ve o boşluk tam
 * olarak "kim neye uzandı" sorusunun cevabıdır. `abort()` denetimden ÖNCE atılmaz — önce yazılır.
 *
 * KVKK: günlüğe yalnız EYLEM TÜRÜ + HEDEF BAYİ + KATEGORİK SEBEP yazılır. Tutar, IBAN, referans
 * kodu, not metni ASLA (panel_audit'in nötr sözleşmesi, kırmızı çizgi #4).
 */
trait ParaEkrani
{
    /** Sebep kodları — KISA ve KATEGORİK. Serbest metin/kullanıcı girdisi buraya GİRMEZ. */
    protected const RED_YETKISIZ = 'yetkisiz';

    protected const RED_GECERSIZ_TUTAR = 'gecersiz_tutar';

    protected const RED_GECERSIZ_KIMLIK = 'gecersiz_kimlik';

    protected const RED_FIRMA_YOK = 'firma_yok';

    protected const RED_PAKET_YOK = 'paket_yok';

    protected const RED_KAPALI_BILDIRIM = 'kapali_bildirim';

    protected const RED_SERVIS = 'servis_reddi';

    protected function adminId(): ?string
    {
        $id = Auth::guard('admin')->id();

        return $id !== null ? (string) $id : null;
    }

    protected function superadminMi(): bool
    {
        return Auth::guard('admin')->user()?->isSuperadmin() === true;
    }

    /** Okuma kapısı — oturum yoksa 403. mount()'ta ve render()'da çağrılır. */
    protected function panelOturumu(): void
    {
        abort_unless(Auth::guard('admin')->check(), 403);
    }

    /** YAZMA kapısı. Reddedilen deneme `<eylem>_denied` + `yetkisiz` olarak günlüğe düşer, sonra 403. */
    protected function paraYetkisi(string $eylem, ?string $tenantId = null): void
    {
        $this->panelOturumu();

        if ($this->superadminMi()) {
            return;
        }

        $this->redKaydet($eylem, self::RED_YETKISIZ, $tenantId);

        abort(403);
    }

    /**
     * Reddedilen yazma denemesini günlüğe yaz (yetkisizlik DIŞINDAKİ retler: geçersiz tutar,
     * kapanmış bildirim, olmayan paket/firma). `$sebep` yalnız yukarıdaki sabitlerden seçilir.
     */
    protected function redKaydet(string $eylem, string $sebep, ?string $tenantId = null): void
    {
        app(TenantAdminService::class)->auditRed($eylem, $this->guvenliTenantId($tenantId), $sebep, $this->adminId());
    }

    /**
     * Eylem argümanı olarak gelen kimlik. Bozuk/uydurma UUID → 404 (500 DEĞİL): `wire:click`
     * argümanları sunucudan basılmış olsa da istemci istediğini gönderebilir ve ham metin
     * Postgres'e uuid olarak gidince 22P02 → 500 olurdu. `$eylem` verilirse deneme günlüğe düşer.
     */
    protected function uuidZorunlu(string $id, ?string $eylem = null): string
    {
        if (! Str::isUuid($id)) {
            if ($eylem !== null) {
                $this->redKaydet($eylem, self::RED_GECERSIZ_KIMLIK);
            }

            abort(404);
        }

        return $id;
    }

    /**
     * Hedef bayi kimliği İSTEMCİDEN gelmiş olabilir: bozuk bir metin `panel_audit.tenant_id`
     * (uuid) kolonuna 22P02 ile düşer ve denetim yazımını — dolayısıyla kapının kendisini —
     * çökertirdi. Geçersizse kayıt HEDEFSİZ yazılır; günlük kaybolmaktansa eksik olsun.
     */
    private function guvenliTenantId(?string $tenantId): ?string
    {
        return ($tenantId !== null && Str::isUuid($tenantId)) ? $tenantId : null;
    }
}
