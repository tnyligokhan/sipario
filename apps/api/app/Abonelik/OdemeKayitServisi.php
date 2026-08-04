<?php

namespace App\Abonelik;

use App\Enums\BillingPeriod;
use App\Enums\TenantStatus;
use App\Models\SubscriptionPayment;
use App\Models\Tenant;
use App\Support\TurkceArama;
use Illuminate\Contracts\Pagination\LengthAwarePaginator;
use Illuminate\Database\Eloquent\Builder;
use Illuminate\Database\Eloquent\Collection;
use Illuminate\Support\Carbon;
use Illuminate\Support\Str;

/**
 * ELLE ÖDEME KAYDI (panelin "Ödeme Ekle" akışı; IBAN/havale ve elden tahsilat).
 *
 * Panelin EN HASSAS yetkisi budur: bir satır, bir bayinin aboneliğini uzatır. Bu yüzden dört kural
 * pazarlıksızdır:
 *
 *  1. TEK TRANSACTION. Ödeme satırı yazılıp tenant uzatılmazsa para alınmış ama hesap kapalı kalır;
 *     tersi olursa bedava abonelik. İkisi birlikte olur ya da hiçbiri olmaz.
 *  2. İDEMPOTENS. Aynı `provider_ref` ile ikinci çağrı YENİ AKTİVASYON ÜRETMEZ. Havale bildirimi
 *     eşleştirmesi ve panelde çift tıklama gerçek senaryolardır; DB'deki kısmi tekil indeks
 *     (`subscription_payments_success_ref`) son emniyettir ama kullanıcıya 23505 göstermeyiz.
 *  3. SÜRE GERİ ALINMAZ. Taban `valid_until > now ? valid_until : now`. Erken ödeyen bayinin kalan
 *     günleri yanmaz; süresi geçmiş bayide de bitiş bugünden başlar (geçmişe uzatma anlamsızdır).
 *  4. APPEND-ONLY. Mevcut ödeme satırı GÜNCELLENMEZ; her kayıt yeni satırdır (tablo zaten DB
 *     seviyesinde UPDATE/DELETE'e kapalı — 000506).
 *
 * BAĞLANTI: `pgsql_owner` (bkz. AbonelikServisi). `sipario_panel`in subscription_payments'ta yalnız
 * SELECT'i vardır — panel para kaydını doğrudan yazamaz, bu servisten geçer.
 */
class OdemeKayitServisi extends AbonelikServisi
{
    /**
     * Ödemeyi kaydeder ve aboneliği uzatır.
     *
     * @param  string  $method  'iban' | 'elden' → subscription_payments.provider
     * @param  string  $coversPeriod  insan okunur dönem etiketi ("Ağustos 2026")
     * @param  BillingPeriod|null  $period  null → tenant.billing_period → yoksa AYLIK
     *                                      (tasarımın modal notu: "abonelik bitişi 1 ay uzatılır")
     * @param  string|null  $providerRef  idempotens anahtarı. null → her çağrıda benzersiz üretilir,
     *                                    yani çift tıklamayı ÇAĞIRAN engellemek zorundadır. Tekrarı
     *                                    olabilecek yollar (havale bildirimi eşleştirme) kendi
     *                                    kararlı anahtarını verir.
     * @return array{payment: SubscriptionPayment, tenant: Tenant}
     */
    public function kaydet(
        string $tenantId,
        int $amountKurus,
        string $method,
        string $coversPeriod,
        ?BillingPeriod $period = null,
        ?string $note = null,
        ?string $adminId = null,
        ?Carbon $occurredAt = null,
        ?string $providerRef = null,
    ): array {
        if ($amountKurus <= 0) {
            throw new GecersizTutarException('Ödeme tutarı sıfırdan büyük olmalıdır.');
        }
        if (! in_array($method, ['iban', 'elden'], true)) {
            throw new GecersizTutarException('Tahsilat yöntemi IBAN veya elden olmalıdır.');
        }

        $ref = $providerRef ?? 'manual:'.Str::uuid7();
        $occurredAt ??= now();

        return $this->db()->transaction(function () use ($tenantId, $amountKurus, $method, $coversPeriod, $period, $note, $adminId, $occurredAt, $ref) {
            /** @var Tenant $tenant */
            $tenant = Tenant::on($this->connection)->lockForUpdate()->findOrFail($tenantId);

            // İDEMPOTENS: bu referansla zaten başarılı bir ödeme varsa ikinci kez aktive ETME.
            /** @var SubscriptionPayment|null $mevcut */
            $mevcut = SubscriptionPayment::on($this->connection)
                ->where('provider_ref', $ref)->where('status', 'success')->first();
            if ($mevcut !== null) {
                return ['payment' => $mevcut, 'tenant' => $tenant];
            }

            $donem = $period ?? $tenant->billing_period ?? BillingPeriod::Monthly;

            $payment = SubscriptionPayment::on($this->connection)->create([
                'tenant_id' => $tenantId,
                'amount_kurus' => $amountKurus,
                'currency' => (string) config('subscription.currency'),
                'provider' => $method,
                'provider_ref' => $ref,
                'status' => 'success',
                'covers_period' => $coversPeriod,
                'period' => $donem->value,
                'note' => $note,
                'recorded_by_admin_id' => $adminId,
                // Hukuk onayları ELLE ödemede alınmaz: sözleşme/ön bilgilendirme onayı siteden
                // üyelik/checkout anında verilir. Buraya sahte bir onay sürümü yazmak, KVKK
                // izinin kendisini yalanlardı.
                'consent_version' => null,
                'consented_at' => null,
                'occurred_at' => $occurredAt,
            ]);

            $taban = ($tenant->valid_until !== null && $tenant->valid_until->greaterThan(now()))
                ? $tenant->valid_until
                : now();

            $tenant->forceFill([
                'status' => TenantStatus::Active->value,
                'billing_period' => $donem->value,
                'valid_until' => $donem->uzat($taban),
                'locked_at' => null,
            ])->save();

            // Nötr denetim: tutar/not YAZILMAZ, yöntem ve dönem yazılır (eylemin türü).
            $this->denetle($adminId, $tenantId, 'payment_manual', $method.':'.$donem->value);

            return ['payment' => $payment, 'tenant' => $tenant];
        });
    }

    /**
     * Bir bayinin ödeme geçmişi (panelin firma detayı). Yalnız BAŞARILI kayıtlar — 'initiated'
     * satırları ödeme değil GİRİŞİMdir ve listede gösterilirse ödenmemiş para ödenmiş görünür.
     *
     * @return Collection<int, SubscriptionPayment>
     */
    public function bayiOdemeleri(string $tenantId): Collection
    {
        return SubscriptionPayment::on($this->connection)
            ->where('tenant_id', $tenantId)
            ->where('status', 'success')
            ->orderByDesc('occurred_at')
            ->get();
    }

    /**
     * Tüm ödemeler (küçük listeler / dışa aktarım). $ay verilirse 'YYYY-MM' süzgeci uygulanır
     * (TR günü: PanelStatsService ile aynı sabit +03:00, DST yok).
     *
     * EKRANLAR İÇİN `odemelerSayfali()` KULLANIN: buradaki `$limit` bir TAVANdır ve aşıldığında
     * SESSİZCE kırpar — "Tüm aylar" seçili bir panelde 501. ödeme hiç görünmez ve kimse fark etmez.
     *
     * @return Collection<int, SubscriptionPayment>
     */
    public function odemeler(?string $ay = null, int $limit = 500): Collection
    {
        return $this->odemeSorgusu($ay, null)->limit($limit)->get();
    }

    /**
     * ÖDEME LİSTESİ — sayfalı (panelin "Ödemeler" ekranı).
     *
     * NEDEN VAR (2026-08-04, `panel-para` bulgusu): ekran `odemeler()`in 500 satırını çekip
     * BELLEKTE süzüyor ve sayfalıyordu. İki arızası vardı: (a) 500'ü aşan kayıt sessizce kayboluyor,
     * (b) firma araması yalnız o 500 satırın içinde çalışıyor — yani eski bir bayiyi aratınca
     * "kayıt yok" diyor. Sayfalama ve süzme SORGUYA indi.
     *
     * Bayi kaydı EAGER YÜKLENİR (`with('tenant')`): ekran firma adını gösteriyor; ilişkisiz hâlde ya
     * N+1 sorgu ya da tüm bayi tablosunun belleğe çekilmesi gerekirdi.
     *
     * FİRMA ARAMASI Türkçe harf katlamasından ve joker kaçışından geçer; kural ve gerekçeleri
     * {@see TurkceArama}'dadır ve BURAYA TEKRARLANMAZ — kuralın kendisi tek kaynağa çekilirken
     * anlatısının iki dosyada kalması, aynı ayrışmayı yorum düzeyinde yeniden üretirdi.
     *
     * @param  string|null  $ay  'YYYY-MM' (TR ayı) — null ise tüm aylar
     * @param  string|null  $firmaArama  bayi adında geçen metin
     * @param  string  $pageName  sayfa parametresinin adı (Livewire ekranı kendi adını verir)
     * @return LengthAwarePaginator<int, SubscriptionPayment>
     */
    public function odemelerSayfali(
        ?string $ay = null,
        ?string $firmaArama = null,
        int $perPage = 25,
        string $pageName = 'page',
    ): LengthAwarePaginator {
        return $this->odemeSorgusu($ay, $firmaArama)
            ->with('tenant')
            ->paginate(perPage: $perPage, pageName: $pageName);
    }

    /**
     * Süzgeçle eşleşen TÜM kayıtların sayısı ve toplamı — sayfa başlığındaki "N kayıt · toplam X".
     *
     * Ayrı bir metot, çünkü sayfalı sonuçtan toplam ÇIKARILAMAZ: paginator yalnız o sayfanın
     * satırlarını taşır ve `sum()` almak "bu sayfadaki toplam"ı gösterip kullanıcıyı yanıltırdı.
     * `total()` adedi verir ama tutarı vermez.
     *
     * @return array{adet: int, toplam_kurus: int}
     */
    public function odemeOzeti(?string $ay = null, ?string $firmaArama = null): array
    {
        $satir = $this->odemeSorgusu($ay, $firmaArama)
            ->reorder()
            ->selectRaw('count(*) as adet, coalesce(sum(amount_kurus), 0) as toplam')
            ->first();

        return [
            'adet' => (int) ($satir->adet ?? 0),
            'toplam_kurus' => (int) ($satir->toplam ?? 0),
        ];
    }

    /**
     * Ödeme GÖRMÜŞ aylar, yeniden eskiye ('YYYY-MM'). Ay süzgecinin seçenekleri budur.
     *
     * NEDEN GelirGiderRaporu'ndan DEĞİL: orası gelir VE gideri birleştirir; masraf girilmiş ama
     * ödeme alınmamış bir ay da listelenir. Ekran bu yüzden `aylikOzet()` çıktısını `gelir_kurus>0`
     * ile süzmek zorunda kalmıştı — çalışan ama niyeti okunmayan bir kullanım. Süzgeç ödemelerin
     * üzerinde olduğuna göre listesi de burada durmalı. Ay sınırı yine sabit +03:00 — ekranda
     * ikinci bir zaman-dilimi hesabı YOK.
     *
     * @return list<string>
     */
    public function aylar(): array
    {
        /** @var list<string> $aylar */
        $aylar = SubscriptionPayment::on($this->connection)
            ->where('status', 'success')
            ->selectRaw("distinct to_char(occurred_at AT TIME ZONE 'Etc/GMT-3', 'YYYY-MM') as ay")
            ->orderByDesc('ay')
            ->pluck('ay')
            ->all();

        return $aylar;
    }

    /**
     * Liste sorgusunun TEK kaynağı: süzgeç kuralları (başarılı kayıtlar, TR ay sınırı, Türkçe firma
     * araması) sayfalı/sayfasız/özet üç yolda da AYNI olmak zorunda — kopyalansaydı biri güncellenip
     * diğeri unutulur ve başlıktaki toplam listeyle tutmazdı.
     *
     * @return Builder<SubscriptionPayment>
     */
    private function odemeSorgusu(?string $ay, ?string $firmaArama): Builder
    {
        $q = SubscriptionPayment::on($this->connection)
            ->where('status', 'success')
            ->orderByDesc('occurred_at');

        if ($ay !== null && $ay !== '') {
            $q->whereRaw("to_char(occurred_at AT TIME ZONE 'Etc/GMT-3', 'YYYY-MM') = ?", [$ay]);
        }

        $arama = trim((string) $firmaArama);
        if ($arama !== '') {
            $q->whereHas('tenant', fn (Builder $t) => $t->whereRaw(
                TurkceArama::sutun('name')." LIKE ? ESCAPE '".TurkceArama::KACIS."'",
                [TurkceArama::desen($arama)],
            ));
        }

        return $q;
    }
}
