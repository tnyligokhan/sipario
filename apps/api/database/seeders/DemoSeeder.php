<?php

namespace Database\Seeders;

use App\Enums\TenantStatus;
use App\Enums\UserRole;
use App\Models\Customer;
use App\Models\CustomerAddress;
use App\Models\CustomerPhone;
use App\Models\LedgerEntry;
use App\Models\Order;
use App\Models\OrderEvent;
use App\Models\OrderLine;
use App\Models\Product;
use App\Models\Tenant;
use App\Models\User;
use App\Support\Provisioning;
use Illuminate\Database\Seeder;
use Illuminate\Support\Facades\DB;
use Illuminate\Support\Str;

/**
 * MAĞAZA İNCELEMESİ DEMO HESABI (Faz 6 gereksinimi — BRIEF: "içi dolu bir demo hesabı" + arayan-tanıma).
 * İncelemeci mobil uygulamaya bu hesapla girer; telefonlu müşteriler arayan-tanıma demosunu besler.
 *
 * AKTİF + uzun valid_until (inceleme sırasında kilitlenmez). İDEMPOTENT: demo e-postası varsa yeniden
 * kurmaz. Provizyon owner ile (Provisioning deseni; superuser RLS'i atlar, tenant_id açıkça yazılır).
 * Bu SAHTE demo verisidir (gerçek müşteri değil) — KVKK açısından temsili; gerçek bir bayiye verilmez.
 */
class DemoSeeder extends Seeder
{
    public const DEMO_EMAIL = 'demo@sipario.com.tr';

    public const DEMO_PASSWORD = 'demo1234';

    public function run(): void
    {
        Provisioning::asOwner(function () {
            if (User::query()->where('email', self::DEMO_EMAIL)->exists()) {
                $this->command->info('Demo hesabı zaten var — atlandı.');

                return;
            }

            $validUntil = now()->addYears(10); // inceleme boyunca kilitlenmesin
            $tenant = Tenant::create([
                'name' => 'Demo Su Bayii',
                'status' => TenantStatus::Active->value,
                'trial_ends_at' => now()->addDays(30),
                'valid_until' => $validUntil,
                'phone' => '02420000000',
            ]);
            $patron = User::create([
                'tenant_id' => $tenant->id,
                'name' => 'Demo Patron',
                'email' => self::DEMO_EMAIL,
                'password' => self::DEMO_PASSWORD, // 'hashed' cast bcrypt'ler
                'role' => UserRole::Patron->value,
                'status' => 'active',
            ]);
            DB::table('tenant_sync_state')->insertOrIgnore(['tenant_id' => $tenant->id, 'last_seq' => 0]);

            $products = $this->seedProducts($tenant->id);
            $damacana = $products['19L'];

            // Telefonlu müşteriler (arayan-tanıma demosu) — kimi veresiye borçlu, kimi peşin.
            $ahmet = $this->seedCustomer($tenant->id, 'Ahmet Yılmaz', '+905321112233', 'Konyaaltı, Antalya');
            $ayse = $this->seedCustomer($tenant->id, 'Ayşe Demir', '+905335556677', 'Muratpaşa, Antalya');
            $mehmet = $this->seedCustomer($tenant->id, 'Mehmet Kaya', '+905429998877', 'Kepez, Antalya');
            $this->seedCustomer($tenant->id, 'Fatma Şahin', '+905061234567', 'Lara, Antalya');

            // Teslim edilmiş siparişler + defter: 2 veresiye (borç kalır), 1 nakit peşin (borç 0, kasa dolu).
            $this->seedDeliveredOrder($tenant->id, $patron->id, $ahmet, $damacana, 2, 'veresiye');
            $this->seedDeliveredOrder($tenant->id, $patron->id, $mehmet, $damacana, 3, 'veresiye');
            $this->seedDeliveredOrder($tenant->id, $patron->id, $ayse, $damacana, 1, 'nakit');

            $this->command->info('Demo hesabı kuruldu: '.self::DEMO_EMAIL.' / '.self::DEMO_PASSWORD);
        });
    }

    /** @return array<string, Product> */
    private function seedProducts(string $tenantId): array
    {
        return [
            '19L' => $this->product($tenantId, '19L Damacana', 4500),
            '10L' => $this->product($tenantId, '10L Damacana', 3000),
        ];
    }

    private function product(string $tenantId, string $name, int $priceKurus): Product
    {
        $p = new Product;
        $p->forceFill([
            'id' => (string) Str::uuid7(), 'tenant_id' => $tenantId, 'name' => $name,
            'unit_price_kurus' => $priceKurus, 'unit' => 'adet', 'is_active' => true,
            'updated_occurred_at' => now(), 'updated_device_id' => null, 'deleted_at' => null,
        ])->save();

        return $p;
    }

    private function seedCustomer(string $tenantId, string $name, string $phoneE164, string $address): Customer
    {
        $now = now();
        $customer = new Customer;
        $customer->forceFill([
            'id' => (string) Str::uuid7(), 'tenant_id' => $tenantId, 'name' => $name,
            'note' => null, 'balance_kurus' => 0, // defter yazımında güncellenecek
            'updated_occurred_at' => $now, 'updated_device_id' => null, 'deleted_at' => null,
        ])->save();

        $phone = new CustomerPhone;
        $phone->forceFill([
            'id' => (string) Str::uuid7(), 'tenant_id' => $tenantId, 'customer_id' => $customer->id,
            'phone_e164' => $phoneE164, 'phone_last10' => substr(preg_replace('/\D/', '', $phoneE164) ?? '', -10),
            'label' => 'cep', 'is_primary' => true,
            'updated_occurred_at' => $now, 'updated_device_id' => null, 'deleted_at' => null,
        ])->save();

        $addr = new CustomerAddress;
        $addr->forceFill([
            'id' => (string) Str::uuid7(), 'tenant_id' => $tenantId, 'customer_id' => $customer->id,
            'label' => 'ev', 'address_text' => $address, 'lat' => null, 'lng' => null, 'is_primary' => true,
            'updated_occurred_at' => $now, 'updated_device_id' => null, 'deleted_at' => null,
        ])->save();

        return $customer;
    }

    /**
     * Teslim edilmiş sipariş + olayları + defter kaydı. veresiye → debit(+borç); nakit → debit+payment (borç 0).
     */
    private function seedDeliveredOrder(
        string $tenantId, string $patronId, Customer $customer, Product $product, int $qty, string $paymentType,
    ): void {
        $now = now();
        $total = $product->unit_price_kurus * $qty;
        $orderId = (string) Str::uuid7();

        $order = new Order;
        $order->forceFill([
            'id' => $orderId, 'tenant_id' => $tenantId, 'customer_id' => $customer->id,
            'status' => 'delivered', 'total_kurus' => $total, 'payment_type' => $paymentType,
            'note' => null, 'occurred_at' => $now, 'created_device_id' => null,
            'assigned_user_id' => null, 'deleted_at' => null,
        ])->save();

        $line = new OrderLine;
        $line->forceFill([
            'id' => (string) Str::uuid7(), 'tenant_id' => $tenantId, 'order_id' => $orderId,
            'product_id' => $product->id, 'product_name' => $product->name,
            'unit_price_kurus' => $product->unit_price_kurus, 'qty' => $qty, 'line_total_kurus' => $total,
            'deleted_at' => null,
        ])->save();

        foreach (['created', 'delivered'] as $type) {
            $ev = new OrderEvent;
            $ev->forceFill([
                'id' => (string) Str::uuid7(), 'tenant_id' => $tenantId, 'order_id' => $orderId,
                'event_type' => $type, 'payload' => ['order_id' => $orderId],
                'client_event_id' => (string) Str::uuid7(), 'occurred_at' => $now, 'device_id' => null,
            ])->save();
        }

        // Defter: her satış debit (+borç); nakit ayrıca payment (−borç, kasaya girer).
        $this->ledger($tenantId, $customer->id, 'debit', $total, null, $orderId, null);
        if ($paymentType === 'nakit') {
            $this->ledger($tenantId, $customer->id, 'payment', -$total, 'nakit', $orderId, $patronId);
        }

        // balance_kurus önbelleği defterden türetilir (net borç = SUM amount_kurus).
        $customer->balance_kurus = (int) LedgerEntry::query()->where('customer_id', $customer->id)->sum('amount_kurus');
        $customer->save();
    }

    private function ledger(
        string $tenantId, string $customerId, string $type, int $amount, ?string $paymentType,
        string $relatedOrderId, ?string $collectedBy,
    ): void {
        $entry = new LedgerEntry;
        $entry->forceFill([
            'id' => (string) Str::uuid7(), 'tenant_id' => $tenantId, 'customer_id' => $customerId,
            'entry_type' => $type, 'amount_kurus' => $amount, 'payment_type' => $paymentType,
            'related_order_id' => $relatedOrderId, 'reverses_entry_id' => null, 'note' => null,
            'occurred_at' => now(), 'device_id' => null, 'client_event_id' => (string) Str::uuid7(),
            'collected_by_user_id' => $collectedBy,
        ])->save();
    }
}
