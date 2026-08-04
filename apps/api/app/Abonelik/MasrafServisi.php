<?php

namespace App\Abonelik;

use App\Models\Expense;
use Illuminate\Database\Eloquent\Collection;
use Illuminate\Support\Carbon;

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

    public function ekle(
        string $category,
        int $amountKurus,
        ?Carbon $spentOn = null,
        ?string $note = null,
        ?string $adminId = null,
    ): Expense {
        if ($amountKurus <= 0) {
            throw new GecersizTutarException('Masraf tutarı sıfırdan büyük olmalıdır.');
        }
        // Kategori serbest metne AÇILMAZ: aylık özet kategori bazlı okunacaksa "Reklam" ile
        // "reklam" iki ayrı kalem sayılır ve rapor sessizce bölünür.
        if (! in_array($category, self::KATEGORILER, true)) {
            throw new GecersizTutarException('Masraf kategorisi geçersiz.');
        }

        /** @var Expense $masraf */
        $masraf = Expense::on($this->connection)->create([
            'spent_on' => ($spentOn ?? now())->toDateString(),
            'category' => $category,
            'amount_kurus' => $amountKurus,
            'note' => $note,
            'admin_user_id' => $adminId,
        ]);

        // Nötr denetim: tutar YAZILMAZ, kategori yazılır. tenant_id null — masrafın bayisi yoktur.
        $this->denetle($adminId, null, 'expense_create', $category);

        return $masraf;
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
