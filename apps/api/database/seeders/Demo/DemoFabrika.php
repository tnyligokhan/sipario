<?php

namespace Database\Seeders\Demo;

use App\Abonelik\KotaDoluException;
use App\Abonelik\KuryeKotasi;
use App\Enums\UserRole;
use App\Models\CallLog;
use App\Models\Customer;
use App\Models\CustomerAddress;
use App\Models\CustomerPhone;
use App\Models\DayClosing;
use App\Models\ExemptNumber;
use App\Models\LedgerEntry;
use App\Models\Order;
use App\Models\OrderEvent;
use App\Models\OrderLine;
use App\Models\Product;
use App\Models\TenantSetting;
use App\Models\User;
use Illuminate\Support\Carbon;
use Illuminate\Support\Str;

/**
 * Demo verisinin SATIR KURUCUSU — `DemoSeeder` neyi kuracağına karar verir, bu sınıf nasıl
 * yazılacağını bilir. Ayrılma sebebi 500 satır sınırı ve okunabilirlik: veri kümesinin kendisi
 * tek bir yerde, kolonların ayrıntısı burada.
 *
 * OWNER bağlamında çağrılır (`Provisioning::asOwner`) — tenant_id her satıra AÇIKÇA yazılır,
 * RLS meşru olarak atlanır.
 *
 * BU SAHTE VERİDİR. Adlar, telefonlar ve adresler uydurmadır (KVKK: gerçek kişi verisi değil).
 */
class DemoFabrika
{
    public function __construct(private readonly string $tenantId) {}

    // ── Kullanıcılar ────────────────────────────────────────────────────────────────────────

    /**
     * Demo kullanıcısı. AKTİF KURYE açarken kota kapısından geçer (App\Abonelik\KuryeKotasi):
     * demo verisinin ürünün kendi kurallarını çiğnemesi, kuralın gerçekten çalıştığı yanılsamasını
     * üretirdi. Demo bayisi 3 kurye hakkına sahiptir ve 2 aktif + 1 pasif kurye kurar — pasif olan
     * kotadan düşmez, o yüzden kapı açık kalır (ve bu, kotanın doğru saydığının kanıtıdır).
     *
     * @throws KotaDoluException
     */
    public function kullanici(
        string $ad,
        string $kullaniciAdi,
        string $rol,
        string $parola,
        ?string $telefon = null,
        string $durum = 'active',
    ): User {
        if ($rol === UserRole::Kurye->value && $durum === 'active') {
            (new KuryeKotasi('pgsql_owner'))->bayiKontrolEt($this->tenantId);
        }

        $u = new User;
        $u->forceFill([
            'id' => (string) Str::uuid7(),
            'tenant_id' => $this->tenantId,
            'name' => $ad,
            'email' => $kullaniciAdi.'@demo.sipario.test',
            'username' => $kullaniciAdi,
            'password' => $parola,   // 'hashed' cast bcrypt'ler
            'role' => $rol,
            'status' => $durum,
            'phone' => $telefon,
        ])->save();

        return $u;
    }

    // ── Katalog ─────────────────────────────────────────────────────────────────────────────

    public function urun(
        string $ad,
        int $fiyatKurus,
        string $birim = 'adet',
        ?string $barkod = null,
        bool $aktif = true,
    ): Product {
        $p = new Product;
        $p->forceFill([
            'id' => (string) Str::uuid7(),
            'tenant_id' => $this->tenantId,
            'name' => $ad,
            'unit_price_kurus' => $fiyatKurus,
            'unit' => $birim,
            'barcode' => $barkod,
            'image_url' => null,
            'is_active' => $aktif,
            'updated_occurred_at' => now(),
            'updated_device_id' => null,
            'deleted_at' => null,
        ])->save();

        return $p;
    }

    // ── Müşteri ─────────────────────────────────────────────────────────────────────────────

    /**
     * @param  list<string>  $telefonlar  ilki BİRİNCİLdir (arayan-tanıma bunu eşler)
     * @param  array{0: float, 1: float}|null  $konum  [lat, lng]; null = "Konum alınmamış"
     */
    public function musteri(
        string $ad,
        array $telefonlar,
        string $adres,
        string $bolge,
        ?array $konum = null,
        ?string $not = null,
        string $adresEtiketi = 'Ev',
    ): Customer {
        $now = now();

        $m = new Customer;
        $m->forceFill([
            'id' => (string) Str::uuid7(),
            'tenant_id' => $this->tenantId,
            'name' => $ad,
            'note' => $not,
            'balance_kurus' => 0,   // defter yazıldıkça `bakiyeTazele` ile türetilir
            'updated_occurred_at' => $now,
            'updated_device_id' => null,
            'deleted_at' => null,
        ])->save();

        foreach ($telefonlar as $i => $no) {
            $t = new CustomerPhone;
            $t->forceFill([
                'id' => (string) Str::uuid7(),
                'tenant_id' => $this->tenantId,
                'customer_id' => $m->id,
                'phone_e164' => $this->e164($no),
                'phone_last10' => $this->son10($no),
                'label' => $i === 0 ? 'Cep' : 'İş',
                'is_primary' => $i === 0,
                'updated_occurred_at' => $now,
                'updated_device_id' => null,
                'deleted_at' => null,
            ])->save();
        }

        $a = new CustomerAddress;
        $a->forceFill([
            'id' => (string) Str::uuid7(),
            'tenant_id' => $this->tenantId,
            'customer_id' => $m->id,
            'label' => $adresEtiketi,
            'address_text' => $adres,
            'region' => $bolge,
            'lat' => $konum[0] ?? null,
            'lng' => $konum[1] ?? null,
            'is_primary' => true,
            'updated_occurred_at' => $now,
            'updated_device_id' => null,
            'deleted_at' => null,
        ])->save();

        return $m;
    }

    // ── Sipariş ─────────────────────────────────────────────────────────────────────────────

    /**
     * Sipariş + satırları + olayları (+ teslimse defter kaydı).
     *
     * @param  list<array{urun: Product, adet: int}>  $satirlar  katalog kalemleri
     * @param  list<array{ad: string, tutar: int}>  $serbest  katalogda olmayan tek seferlik iş
     */
    public function siparis(
        ?Customer $musteri,
        array $satirlar,
        Carbon $zaman,
        string $durum = 'open',
        ?string $odeme = null,
        ?User $kurye = null,
        ?string $not = null,
        array $serbest = [],
        ?User $tahsilEden = null,
    ): Order {
        $orderId = (string) Str::uuid7();
        $toplam = 0;

        $o = new Order;
        $o->forceFill([
            'id' => $orderId,
            'tenant_id' => $this->tenantId,
            'customer_id' => $musteri?->id,
            'assigned_user_id' => $kurye?->id,
            'status' => $durum,
            'total_kurus' => 0,   // satırlar yazıldıktan sonra güncellenir
            'payment_type' => $odeme,
            'note' => $not,
            'sort_index' => null,
            'occurred_at' => $zaman,
            'created_device_id' => null,
            'deleted_at' => null,
        ])->save();

        foreach ($satirlar as $s) {
            $urun = $s['urun'];
            $adet = $s['adet'];
            $tutar = $urun->unit_price_kurus * $adet;
            $toplam += $tutar;

            $l = new OrderLine;
            $l->forceFill([
                'id' => (string) Str::uuid7(),
                'tenant_id' => $this->tenantId,
                'order_id' => $orderId,
                'product_id' => $urun->id,
                'product_name' => $urun->name,
                'unit_price_kurus' => $urun->unit_price_kurus,
                'unit' => $urun->unit,
                'is_custom' => false,
                'qty' => $adet,
                'line_total_kurus' => $tutar,
                'deleted_at' => null,
            ])->save();
        }

        foreach ($serbest as $s) {
            $toplam += $s['tutar'];

            $l = new OrderLine;
            $l->forceFill([
                'id' => (string) Str::uuid7(),
                'tenant_id' => $this->tenantId,
                'order_id' => $orderId,
                'product_id' => null,
                'product_name' => $s['ad'],
                'unit_price_kurus' => $s['tutar'],
                'unit' => null,
                'is_custom' => true,   // AÇIK bayrak: product_id null olması yeterli ayırt edici değil
                'qty' => 1,
                'line_total_kurus' => $s['tutar'],
                'deleted_at' => null,
            ])->save();
        }

        $o->total_kurus = $toplam;
        $o->save();

        $olaylar = ['created'];
        if ($kurye !== null) {
            $olaylar[] = 'assigned';
        }
        if ($durum === 'delivered') {
            $olaylar[] = 'delivered';
        }
        if ($durum === 'cancelled') {
            $olaylar[] = 'cancelled';
        }
        foreach ($olaylar as $tip) {
            $this->siparisOlayi($orderId, $tip, $zaman);
        }

        // Defter: teslim edilen her sipariş borç yazar; nakit/kart/havale ise aynı anda ödenir.
        // Veresiyede ödeme kaydı YOKtur — borç açık kalır (tasarımın "Açık Veresiye"si budur).
        if ($durum === 'delivered' && $musteri !== null) {
            $this->defter($musteri, 'debit', $toplam, zaman: $zaman, siparisId: $orderId);
            if ($odeme !== null && $odeme !== 'veresiye') {
                $this->defter($musteri, 'payment', -$toplam, odeme: $odeme, zaman: $zaman,
                    siparisId: $orderId, tahsilEden: $tahsilEden ?? $kurye);
            }
        }

        return $o;
    }

    private function siparisOlayi(string $orderId, string $tip, Carbon $zaman): void
    {
        $e = new OrderEvent;
        $e->forceFill([
            'id' => (string) Str::uuid7(),
            'tenant_id' => $this->tenantId,
            'order_id' => $orderId,
            'event_type' => $tip,
            'payload' => ['order_id' => $orderId],
            'client_event_id' => (string) Str::uuid7(),
            'occurred_at' => $zaman,
            'device_id' => null,
        ])->save();
    }

    // ── Defter (APPEND-ONLY) ────────────────────────────────────────────────────────────────

    /**
     * İmzalı tutar: `+` borç artırır, `−` azaltır. Bakiye SUM(amount_kurus)'tur; hiçbir yerde
     * ezilmez. Düzeltme için [tersKayit] verilir — orijinal satır DEĞİŞMEZ, yenisi eklenir.
     */
    public function defter(
        Customer $musteri,
        string $tip,
        int $tutar,
        ?string $odeme = null,
        ?Carbon $zaman = null,
        ?string $siparisId = null,
        ?User $tahsilEden = null,
        ?string $not = null,
        ?string $tersKayit = null,
    ): LedgerEntry {
        $e = new LedgerEntry;
        $e->forceFill([
            'id' => (string) Str::uuid7(),
            'tenant_id' => $this->tenantId,
            'customer_id' => $musteri->id,
            'entry_type' => $tip,
            'amount_kurus' => $tutar,
            'payment_type' => $odeme,
            'related_order_id' => $siparisId,
            'reverses_entry_id' => $tersKayit,
            'note' => $not,
            'occurred_at' => $zaman ?? now(),
            'device_id' => null,
            'client_event_id' => (string) Str::uuid7(),
            'collected_by_user_id' => $tahsilEden?->id,
        ])->save();

        return $e;
    }

    /** `customers.balance_kurus` yalnız bir ÖNBELLEKTİR — kaynak defterdir, buradan türetilir. */
    public function bakiyeTazele(Customer ...$musteriler): void
    {
        foreach ($musteriler as $m) {
            $m->balance_kurus = (int) LedgerEntry::query()
                ->where('customer_id', $m->id)
                ->sum('amount_kurus');
            $m->save();
        }
    }

    // ── Çağrı günlüğü · muaf numaralar · profil · gün kapanışı ──────────────────────────────

    public function cagri(
        ?Customer $musteri,
        string $numara,
        string $yon,
        Carbon $zaman,
        ?string $sonuc = null,
    ): void {
        $c = new CallLog;
        $c->forceFill([
            'id' => (string) Str::uuid7(),
            'tenant_id' => $this->tenantId,
            'customer_id' => $musteri?->id,
            'phone_e164' => $this->e164($numara),
            'phone_last10' => $this->son10($numara),
            'direction' => $yon,     // incoming | missed | outgoing
            'outcome' => $sonuc,
            'related_order_id' => null,
            'occurred_at' => $zaman,
            'device_id' => null,
            'updated_occurred_at' => $zaman,
            'updated_device_id' => null,
            'deleted_at' => null,
        ])->save();
    }

    public function muaf(string $etiket, string $numara): void
    {
        $m = new ExemptNumber;
        $m->forceFill([
            'id' => (string) Str::uuid7(),
            'tenant_id' => $this->tenantId,
            'phone_e164' => $this->e164($numara),
            'phone_last10' => $this->son10($numara),
            'label' => $etiket,
            'updated_occurred_at' => now(),
            'updated_device_id' => null,
            'deleted_at' => null,
        ])->save();
    }

    /** @param  array<string, string|null>  $alanlar */
    public function isletmeProfili(array $alanlar): void
    {
        TenantSetting::query()->updateOrCreate(
            ['tenant_id' => $this->tenantId],
            $alanlar + ['updated_occurred_at' => now(), 'updated_device_id' => null],
        );
    }

    /** Arşivde görünecek geçmiş bir kapanış (APPEND-ONLY; fark KANIT olarak durur). */
    public function gunKapanisi(
        Carbon $zaman,
        int $teslimat,
        int $nakit,
        int $kart,
        int $havale,
        int $sayilan,
        ?User $kurye = null,
        ?string $not = null,
    ): void {
        $toplam = $nakit + $kart + $havale;
        $k = new DayClosing;
        $k->forceFill([
            'id' => (string) Str::uuid7(),
            'tenant_id' => $this->tenantId,
            'scope' => $kurye === null ? 'day' : 'courier',
            'user_id' => $kurye?->id,
            'period_start' => null,
            'delivery_count' => $teslimat,
            'total_collected_kurus' => $toplam,
            'cash_nakit_kurus' => $nakit,
            'cash_kart_kurus' => $kart,
            'cash_havale_kurus' => $havale,
            'open_credit_kurus' => 0,
            'expected_cash_kurus' => $nakit,
            'counted_cash_kurus' => $sayilan,
            'diff_kurus' => $sayilan - $nakit,
            'cash_handover_id' => null,
            'note' => $not,
            'occurred_at' => $zaman,
            'device_id' => null,
        ])->save();
    }

    // ── Telefon normalizasyonu (native arayan-tanıma sözleşmesiyle AYNI kural) ──────────────

    private function son10(string $no): string
    {
        return substr((string) preg_replace('/\D/', '', $no), -10);
    }

    private function e164(string $no): string
    {
        return '+90'.$this->son10($no);
    }
}
