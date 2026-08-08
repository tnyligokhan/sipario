<?php

namespace App\Livewire\Site\Forms;

use App\Enums\UserRole;
use App\Models\Tenant;
use App\Models\TenantSetting;
use App\Models\User;
use App\Support\Sync\SyncService;
use Illuminate\Support\Facades\DB;
use Illuminate\Support\Str;
use Illuminate\Validation\Rule;
use Livewire\Form;
use RuntimeException;

/**
 * "İşletme bilgileri" bölümünün formu (tasarım: 14-sw-hesap.jsx · HIsletme).
 *
 * ALANLAR İKİ AYRI DEPODA DURUR ve iki AYRI yoldan yazılır:
 *
 *  1. `tenants` (ad, firma kodu, yetkili, il/ilçe) + `users` (patronun adı/e-postası) — bunlar
 *     SUNUCU SAHİPLİ satış/kimlik alanlarıdır, senkron varlığı değildir. Owner bağlantısıyla
 *     doğrudan yazılır (SubscriptionService'in Faz 5b'den beri yaptığının aynısı). Telefona
 *     `SyncService::subscriptionPayload` ile TAM DURUM olarak zaten iner.
 *
 *  2. `tenant_settings` (fatura ünvanı, VKN, vergi dairesi, adres) — bu bir SENKRON VARLIĞIDIR ve
 *     LWW ile birleşir. Doğrudan UPDATE atmak iki hatayı birden doğururdu: (a) değişiklik
 *     `sync_changes`e düşmez, yani bayinin telefonuna HİÇ inmez (migration 802'nin dersi);
 *     (b) LWW damgası ilerlemez, yani bir sonraki cihaz yazımı sessizce üstüne yazar. Bu yüzden
 *     yazma mobilin kullandığı AYNI yoldan geçer: RLS bağlamı kurulur → `SyncService::push` →
 *     `ProfileChangeApplier`.
 *
 * TAM SATIR GÖNDERİLİR: `ProfileChangeApplier::applySettings` bir LWW UPSERT'tir ve payload'da
 * BULUNMAYAN alanı NULL'a çeker. Yalnız dört fatura alanını göndermek, bayinin telefondan girdiği
 * çalışma saatlerini, fiş notunu, IBAN'ını ve kurye yetkilerini SİLERDİ. Mevcut satır okunur,
 * üstüne yalnız bu formun alanları yazılır.
 */
class IsletmeFormu extends Form
{
    /**
     * Site yazmalarının sentetik cihaz kimliği. `PanelSyncYazici::PANEL_DEVICE_ID` ile aynı
     * gerekçe: LWW eşitliği `device_id` metin karşılaştırmasına düşer ve rastgele bir kimlik
     * seçmek sonucu yazı-turaya çevirirdi. Panelinkinden BİR HANE KÜÇÜK: aynı saniyede hem panel
     * hem site yazarsa insanın panelde bilerek yaptığı düzeltme kazanmalıdır.
     */
    public const SITE_DEVICE_ID = 'fffffffe-ffff-ffff-ffff-ffffffffffff';

    public string $isletmeAdi = '';

    public string $firmaKodu = '';

    public string $yetkili = '';

    public string $telefon = '';

    public string $eposta = '';

    public string $unvan = '';

    public string $vkn = '';

    public string $daire = '';

    public string $adres = '';

    public string $ilce = '';

    public string $il = '';

    /**
     * Tahsilat hatırlatması alanları (kullanıcı isteği 2026-08-06). IBAN'ın KENDİSİ burada YOK:
     * mod-97 denetimi mobilde yaşıyor ve yanlış IBAN sessiz bir hatadır — denetimsiz bir web
     * alanı, bayinin hesap numarasını kontrolsüz değiştirebileceği ikinci bir kapı açardı.
     * Buradan düzenlenen ikisi serbest metindir; yanlış yazılırsa mesaj çirkin olur, para
     * kaybolmaz.
     */
    public string $ibanAliciAdi = '';

    public string $hatirlatmaSablonu = '';

    /** Kaydetme sırasında sabitlenen bayi (doğrulama kuralları bunun kimliğini dışlar). */
    private string $bayiId = '';

    public function doldur(Tenant $bayi): void
    {
        $this->bayiId = $bayi->id;
        $ayar = TenantSetting::on('pgsql_owner')->find($bayi->id);
        $patron = $this->patron($bayi->id);

        $this->isletmeAdi = (string) $bayi->name;
        $this->firmaKodu = (string) $bayi->slug;
        $this->yetkili = (string) ($bayi->contact_name ?? ($patron === null ? '' : $patron->name));
        $this->telefon = (string) ($bayi->phone ?? '');
        $this->eposta = $patron === null ? '' : (string) $patron->email;
        $this->unvan = $ayar === null ? '' : (string) ($ayar->business_name ?? '');
        $this->vkn = $ayar === null ? '' : (string) ($ayar->tax_number ?? '');
        $this->daire = $ayar === null ? '' : (string) ($ayar->tax_office ?? '');
        $this->adres = $ayar === null ? '' : (string) ($ayar->address_text ?? '');
        $this->ilce = (string) ($bayi->district ?? '');
        $this->il = (string) ($bayi->city ?? '');
        $this->ibanAliciAdi = $ayar === null ? '' : (string) ($ayar->iban_owner_name ?? '');
        $this->hatirlatmaSablonu = $ayar === null ? '' : (string) ($ayar->reminder_template ?? '');
    }

    /**
     * Kaydeder ve bildirim metnini döndürür.
     *
     * YETKİ KAPISI BURADA (eylemin İÇİNDE, route'ta değil): yazılan bayi çağıranın verdiği
     * nesnedir ve `Hesap::$bayiId` `#[Locked]`tır — istemci başka bir bayi gösteremez.
     */
    public function kaydet(Tenant $bayi): string
    {
        $this->bayiId = $bayi->id;
        $this->firmaKodu = mb_strtolower(trim($this->firmaKodu));
        $this->eposta = Str::lower(trim($this->eposta));

        $this->validate($this->kurallar(), $this->mesajlar());

        $this->bayiYaz($bayi);
        $sonuc = $this->ayarYaz($bayi);

        return $sonuc ?? 'İşletme bilgileri kaydedildi';
    }

    /** `tenants` + patron kullanıcısı — owner bağlantısı, tek transaction. */
    private function bayiYaz(Tenant $bayi): void
    {
        DB::connection('pgsql_owner')->transaction(function () use ($bayi) {
            Tenant::on('pgsql_owner')->whereKey($bayi->id)->update([
                'name' => trim($this->isletmeAdi),
                'slug' => $this->firmaKodu,
                'contact_name' => $this->bosNull($this->yetkili),
                'phone' => $this->bosNull($this->telefon),
                'district' => $this->bosNull($this->ilce),
                'city' => $this->bosNull($this->il),
            ]);

            $patron = $this->patron($bayi->id);
            if ($patron !== null) {
                $patron->forceFill([
                    'name' => trim($this->yetkili) !== '' ? Str::limit(trim($this->yetkili), 120, '') : $patron->name,
                    'email' => $this->eposta,
                ])->save();
            }
        });
    }

    /**
     * `tenant_settings` — senkron yolundan. Dönüş: kullanıcıya söylenecek özel bir durum varsa
     * o metin, yoksa null.
     *
     * 'stale' BAŞARISIZ sayılır (PanelSyncYazici::durumOzeti ile aynı gerekçe): ChangeApplier bayat
     * olayı sessizce yutar; "kaydedildi" deyip hiçbir şey yazmamak ekranın söyleyebileceği en kötü
     * yalandır. 'locked' de gerçektir — süresi dolmuş bayide yazma kapalıdır ve bu kararın tek
     * sahibi sunucudur.
     */
    private function ayarYaz(Tenant $bayi): ?string
    {
        $patron = $this->patron($bayi->id);
        if ($patron === null) {
            return 'İşletme bilgileri kaydedildi (fatura bilgileri için hesap sahibi bulunamadı)';
        }

        $mevcut = TenantSetting::on('pgsql_owner')->find($bayi->id);

        // TAM SATIR: mevcut değerler taşınır, üstüne yalnız bu formun alanları yazılır.
        $payload = $mevcut === null ? [] : $mevcut->only([
            'business_name', 'owner_name', 'phone', 'whatsapp', 'address_text', 'tax_office',
            'tax_number', 'opens_at', 'closes_at', 'receipt_note', 'iban', 'iban_owner_name',
            'reminder_template', 'courier_can_customers', 'courier_can_orders', 'courier_can_collect',
            'courier_can_discount', 'courier_can_day_end', 'courier_can_see_all_orders',
            'courier_can_view_history', 'courier_can_expense', 'courier_phone_mask',
            'courier_can_customer_ledger', 'courier_can_debt_reminder', 'courier_can_toggle_stock',
            'courier_can_call_log', 'order_code_display',
        ]);
        $payload['business_name'] = $this->bosNull($this->unvan) ?? $payload['business_name'] ?? null;
        $payload['tax_number'] = $this->bosNull($this->vkn);
        $payload['tax_office'] = $this->bosNull($this->daire);
        $payload['address_text'] = $this->bosNull($this->adres);
        $payload['owner_name'] = $this->bosNull($this->yetkili) ?? $payload['owner_name'] ?? null;
        // Boş bırakmak GERÇEK bir niyettir ve korunmalı: alıcı adı boşsa mobil işletme adına
        // düşer, şablon boşsa varsayılan metin kurulur. Bu yüzden `?? mevcut` düşülmez —
        // bayi web'den temizleyebilmeli.
        $payload['iban_owner_name'] = $this->bosNull($this->ibanAliciAdi);
        $payload['reminder_template'] = $this->bosNull($this->hatirlatmaSablonu);

        $sonuc = $this->push($bayi->id, $patron->id, [
            'client_event_id' => (string) Str::uuid7(),
            'entity_type' => 'tenant_settings',
            'op' => 'upsert',
            'occurred_at' => $this->damga($mevcut),
            'device_id' => self::SITE_DEVICE_ID,
            'payload' => $payload,
        ]);

        return match ($sonuc) {
            'stale' => 'Fatura bilgileri daha yeni bir değişiklikle güncellenmiş; sayfayı tazeleyip tekrar deneyin',
            'locked' => 'İşletme bilgileri kaydedildi; fatura bilgileri abonelik açılınca güncellenecek',
            'applied' => null,
            default => 'İşletme bilgileri kaydedildi, fatura bilgileri kaydedilemedi',
        };
    }

    /**
     * Olayı bayinin RLS bağlamında senkron çekirdeğine verir (PanelSyncYazici::rlsIcinde deseni).
     *
     * Varsayılan bağlantı geçici olarak `pgsql`e alınır: Eloquent modelleri bağlantıyı
     * varsayılandan çözer; `set_config`i bir bağlantıda yapıp modeli başkasında koşturmak sessizce
     * RLS-bağlamsız (sıfır satır gören) bir sorgu üretirdi. Bağlam LOCAL'dir, transaction bitince
     * kendiliğinden sıfırlanır.
     *
     * @param  array<string, mixed>  $olay
     */
    private function push(string $tenantId, string $patronId, array $olay): string
    {
        $onceki = DB::getDefaultConnection();
        DB::setDefaultConnection('pgsql');

        try {
            return DB::connection('pgsql')->transaction(function () use ($tenantId, $patronId, $olay) {
                DB::connection('pgsql')->statement("SELECT set_config('app.tenant_id', ?, true)", [$tenantId]);

                $aktor = User::query()->find($patronId);
                if ($aktor === null) {
                    throw new RuntimeException('Hesap sahibi RLS bağlamında bulunamadı.');
                }

                $sonuc = (new SyncService)->push($aktor, [$olay]);

                return (string) ($sonuc['results'][0]['status'] ?? 'rejected');
            });
        } finally {
            DB::setDefaultConnection($onceki);
        }
    }

    /**
     * LWW damgası. `updated_occurred_at` `timestamp(0)`dır ve eşitlikte karar `device_id`
     * karşılaştırmasına düşer; aynı saniyedeki İKİNCİ site yazması 'stale' olup sessizce
     * kaybolurdu. Damga yalnız SİTENİN KENDİ önceki damgasının üstüne çıkar — satırı en son bir
     * cihaz (ya da panel) yazdıysa dokunulmaz ve LWW doğal işini yapar.
     */
    private function damga(?TenantSetting $mevcut): string
    {
        $damga = now()->startOfSecond();

        if ($mevcut !== null
            && (string) $mevcut->updated_device_id === self::SITE_DEVICE_ID
            && $mevcut->updated_occurred_at->greaterThanOrEqualTo($damga)) {
            $damga = $mevcut->updated_occurred_at->copy()->addSecond();
        }

        return $damga->toIso8601String();
    }

    private function patron(string $tenantId): ?User
    {
        return User::on('pgsql_owner')
            ->where('tenant_id', $tenantId)
            ->where('role', UserRole::Patron->value)
            ->orderBy('created_at')
            ->first();
    }

    private function bosNull(?string $deger): ?string
    {
        $deger = trim((string) $deger);

        return $deger === '' ? null : $deger;
    }

    /**
     * @return array<string, mixed>
     */
    private function kurallar(): array
    {
        return [
            'isletmeAdi' => ['required', 'string', 'min:3', 'max:255'],
            // Firma kodu DB kısıtıyla aynı: ^[a-z0-9-]{3,80}$. Kayıt ekranındaki daha dar kural
            // (tiresiz, 18 hane) BURADA UYGULANAMAZ — mevcut bayilerin kodu `Provisioning`
            // tarafından adlarından TİRELİ üretildi ("merkez-su-bayii"); tireyi süzmek, formu
            // açan bayinin kodunu sessizce değiştirmek olurdu.
            'firmaKodu' => ['required', 'string', 'regex:/^[a-z0-9-]{3,80}$/',
                Rule::unique('pgsql_owner.tenants', 'slug')->ignore($this->bayiId)],
            'yetkili' => ['nullable', 'string', 'max:120'],
            'telefon' => ['nullable', 'string', 'max:20'],
            'eposta' => ['required', 'email', 'max:190',
                Rule::unique('pgsql_owner.users', 'email')->ignore($this->patron($this->bayiId)?->id)],
            'unvan' => ['nullable', 'string', 'max:190'],
            'vkn' => ['nullable', 'string', 'regex:/^[0-9]{10,11}$/'],
            'daire' => ['nullable', 'string', 'max:120'],
            'adres' => ['nullable', 'string', 'max:500'],
            'ilce' => ['nullable', 'string', 'max:60'],
            'il' => ['nullable', 'string', 'max:60'],
            // Sınırlar kolonlarla (ve ProfileChangeApplier'ın kapısıyla) BİREBİR aynı: burada
            // gevşek bir kural, hatayı formdan alıp senkron partisinin içine taşırdı.
            'ibanAliciAdi' => ['nullable', 'string', 'max:120'],
            'hatirlatmaSablonu' => ['nullable', 'string', 'max:1000'],
        ];
    }

    /**
     * @return array<string, string>
     */
    private function mesajlar(): array
    {
        return [
            'isletmeAdi.required' => 'İşletme adını girin',
            'isletmeAdi.min' => 'En az 3 karakter',
            'firmaKodu.required' => 'Firma kodu boş olamaz',
            'firmaKodu.regex' => 'Sadece küçük harf, rakam ve tire; en az 3 karakter',
            'firmaKodu.unique' => 'Bu firma kodu alınmış, başka bir kod deneyin',
            'eposta.required' => 'E-posta adresinizi girin',
            'eposta.email' => 'Geçerli bir e-posta girin',
            'eposta.unique' => 'Bu e-posta ile devam edilemiyor.',
            'vkn.regex' => 'VKN 10, TCKN 11 hane olmalı',
            'ibanAliciAdi.max' => 'Alıcı adı en fazla 120 karakter olabilir',
            'hatirlatmaSablonu.max' => 'Mesaj en fazla 1000 karakter olabilir',
        ];
    }
}
