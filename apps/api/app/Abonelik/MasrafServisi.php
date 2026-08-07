<?php

namespace App\Abonelik;

use App\Models\Expense;
use Illuminate\Database\Eloquent\Collection;
use Illuminate\Database\QueryException;
use Illuminate\Support\Carbon;
use Illuminate\Support\Str;

/**
 * ŞİRKET MASRAFLARI (bizim giderimiz — bayi verisi DEĞİL, bkz. migration 005004).
 *
 * Yalnız EKLE + LİSTELE. Düzenleme/silme yolu bilerek yoktur: tasarımda böyle bir akış yok ve
 * `expenses` üzerinde panel rolüne UPDATE/DELETE izni verilmedi. "Yanlış girdim" durumunun bugünkü
 * karşılığı yeni bir kayıttır; gerçek bir düzeltme ihtiyacı doğarsa ayrı bir karar + izin + denetim
 * izi ister.
 */
class MasrafServisi extends AbonelikServisi
{
    /** Tasarımın (`03-BUGUN.jsx` MASRAF_KATEGORI) kategori listesi — sırası ekrandaki sırayla aynıdır. */
    public const KATEGORILER = ['Sunucu/Altyapı', 'Domain/Lisans', 'Reklam', 'Komisyon', 'Diğer'];

    /**
     * İDEMPOTENS — `$expenseId` (2026-08-04, `panel-para` bulgusu). Anahtarsız hâlde çift tıklama
     * ya da paralel iki istek İKİ kalem yazardı ve `expenses` üzerinde UPDATE/DELETE izni YOK
     * (005004) — yanlış kalem silinemez, ay sonu gideri sessizce şişerdi. Etkisi ek paket
     * tanımlamasından hafiftir (şirket defteri; bayiye dokunmaz) ama düzeltilemez olması aynıdır.
     *
     * Koruma `EkPaketServisi::tanimla()` ile aynı iki katmandır: ön kontrol + `expenses.id`
     * BİRİNCİL ANAHTARInın 23505'i (ayrı tekil indekse gerek yok). Burada `lockForUpdate` YOK,
     * çünkü kilitlenecek bir üst satır (tenant) yok; yarışı doğrudan PK çözer.
     *
     * Yakalama transaction'ın DIŞINDA: Postgres'te hatalı statement transaction'ı zehirler,
     * içeride yapılacak SELECT "current transaction is aborted" ile düşerdi.
     *
     * @param  string|null  $expenseId  idempotens anahtarı (UUID). null → her çağrı yeni kalemdir.
     */
    public function ekle(
        string $category,
        int $amountKurus,
        ?Carbon $spentOn = null,
        ?string $note = null,
        ?string $adminId = null,
        ?string $expenseId = null,
    ): Expense {
        if ($amountKurus <= 0) {
            throw new GecersizTutarException('Masraf tutarı sıfırdan büyük olmalıdır.');
        }
        // Kategori serbest metne AÇILMAZ: aylık özet kategori bazlı okunacaksa "Reklam" ile
        // "reklam" iki ayrı kalem sayılır ve rapor sessizce bölünür.
        if (! in_array($category, self::KATEGORILER, true)) {
            throw new GecersizTutarException('Masraf kategorisi geçersiz.');
        }

        try {
            return $this->masrafYaz($category, $amountKurus, $spentOn ?? now(), $note, $adminId, $expenseId);
        } catch (QueryException $e) {
            if ((string) $e->getCode() === '23505' && $expenseId !== null) {
                $mevcut = Expense::on($this->connection)->find($expenseId);
                if ($mevcut !== null) {
                    return $mevcut;
                }
            }
            throw $e;
        }
    }

    private function masrafYaz(
        string $category,
        int $amountKurus,
        Carbon $spentOn,
        ?string $note,
        ?string $adminId,
        ?string $expenseId,
    ): Expense {
        // Kalem + denetim kaydı TEK transaction: kalem yazılıp denetim düşmezse, şirket defterinde
        // kimin girdiği belirsiz bir gider kalırdı.
        return $this->db()->transaction(function () use ($category, $amountKurus, $spentOn, $note, $adminId, $expenseId) {
            if ($expenseId !== null) {
                $mevcut = Expense::on($this->connection)->find($expenseId);
                if ($mevcut !== null) {
                    // İkinci denetim satırı YAZILMAZ: tekrar eden çağrı yeni bir eylem değildir.
                    return $mevcut;
                }
            }

            /** @var Expense $masraf */
            $masraf = Expense::on($this->connection)->create([
                'id' => $expenseId ?? (string) Str::uuid7(),
                'spent_on' => $spentOn->toDateString(),
                'category' => $category,
                'amount_kurus' => $amountKurus,
                'note' => $note,
                'admin_user_id' => $adminId,
            ]);

            // Nötr denetim: tutar YAZILMAZ, kategori yazılır. tenant_id null — masrafın bayisi yoktur.
            $this->denetle($adminId, null, 'expense_create', $category);

            return $masraf;
        });
    }

    /**
     * Bir ayın masraf kalemleri ('YYYY-MM'). Tarih alanı DATE olduğu için saat dilimi dönüşümü
     * GEREKMEZ — `spent_on` zaten operatörün seçtiği iş günüdür.
     *
     * @return Collection<int, Expense>
     */
    public function ay(string $ay): Collection
    {
        return Expense::on($this->connection)
            ->whereRaw("to_char(spent_on, 'YYYY-MM') = ?", [$ay])
            ->orderByDesc('spent_on')
            ->get();
    }

    /**
     * @return Collection<int, Expense>
     */
    public function sonKayitlar(int $limit = 200): Collection
    {
        return Expense::on($this->connection)->orderByDesc('spent_on')->limit($limit)->get();
    }
}
