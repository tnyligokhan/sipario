<?php

namespace App\Livewire\Panel;

use App\Support\TurkceArama;
use Illuminate\Contracts\Pagination\LengthAwarePaginator;
use Illuminate\Database\Query\Builder;
use Illuminate\Support\Facades\DB;
use Livewire\Attributes\Layout;
use Livewire\Attributes\Title;
use Livewire\Attributes\Url;
use Livewire\Component;
use Livewire\WithPagination;

/**
 * ÜYELER (tasarım `07-Uyeler.jsx` · Uyeler) — arama + durum çipleri + sayfalı tablo. SALT-OKUNUR:
 * her satır bayi detayına götürür, listeden hiçbir şey yazılmaz.
 *
 * Sorgu `TenantAdminService::tenants()` yerine burada: o metot SAYFALAMASIZ bütün bayileri döndürür
 * ve ekranın üç süzgeci (arama · durum · sayfa) yok. Bütün listeyi çekip PHP'de süzmek, bayi sayısı
 * büyüdükçe her tuşa basışta tüm tabloyu ağdan geçirirdi. Bağlantı yine `pgsql_panel` (BYPASSRLS,
 * SELECT-only) — servisin kullandığının aynısı.
 */
#[Layout('components.layouts.panel')]
#[Title('Üyeler')]
class TenantList extends Component
{
    use WithPagination;

    /**
     * Durum çipleri. İlk beşi tasarımın listesidir ve SIRASI KORUNUR; `locked` sunucunun beşinci
     * durumudur (tasarımda yoktu) ve sona eklendi — araya sokmak tasarımın çip sırasını bozardı.
     */
    public const DURUMLAR = [
        'tumu' => 'Tümü',
        'trial' => 'Deneme',
        'active' => 'Aktif',
        'suspended' => 'Askıda',
        'cancelled' => 'İptal',
        'locked' => 'Süresi doldu',
    ];

    private const BAGLANTI = 'pgsql_panel';

    private const SAYFA_BOYU = 20;

    /**
     * ARAMA UZUNLUK TAVANI. Alan bir metin süzgecidir ve hiçbir zaman sayısal kolonla
     * KARŞILAŞTIRILMAZ (yalnız LIKE) — yapıştırılan 15 haneli bir telefon bu yüzden int taşırmaz.
     * Tavan ayrı bir dert içindir: sınırsız uzunlukta bir desen boşuna tam tablo taraması üretir.
     */
    private const ARAMA_TAVANI = 120;

    #[Url(as: 'ara', except: '')]
    public string $arama = '';

    #[Url(as: 'durum', except: 'tumu')]
    public string $durum = 'tumu';

    /** null = henüz bakılmadı. Bkz. trSiralama(). */
    private ?bool $icuVar = null;

    public function updatedArama(): void
    {
        $this->resetPage('sayfa');
    }

    public function updatedDurum(): void
    {
        $this->resetPage('sayfa');
    }

    public function render(): mixed
    {
        // URL'den elle uydurulmuş bir durum sessizce boş liste üretmesin: bilinmeyen değer 'tumu'ya düşer.
        if (! array_key_exists($this->durum, self::DURUMLAR)) {
            $this->durum = 'tumu';
        }

        return view('livewire.panel.tenant-list', [
            'uyeler' => $this->sorgu(),
            'toplam' => DB::connection(self::BAGLANTI)->table('tenants')->count(),
            'durumlar' => self::DURUMLAR,
        ]);
    }

    /** @return LengthAwarePaginator<int, \stdClass> */
    private function sorgu(): LengthAwarePaginator
    {
        $q = DB::connection(self::BAGLANTI)->table('tenants as t')
            ->select(
                't.id', 't.name', 't.slug', 't.status', 't.phone',
                't.contact_name', 't.city', 't.district',
                't.trial_ends_at', 't.valid_until',
            )
            // SON ÖDEME alt sorguyla: bayi başına ayrı sorgu (N+1) yerine tek turda gelir. Yalnız
            // BAŞARILI ödemeler — 'initiated' satırı bir girişimdir, tarihi "son ödeme" değildir.
            ->selectSub(
                DB::connection(self::BAGLANTI)->table('subscription_payments')
                    ->selectRaw('max(occurred_at)')
                    ->whereColumn('subscription_payments.tenant_id', 't.id')
                    ->where('subscription_payments.status', 'success'),
                'son_odeme',
            );

        if ($this->durum !== 'tumu') {
            $q->where('t.status', $this->durum);
        }

        $this->aramayiUygula($q);

        return $q->orderByRaw($this->trSiralama())
            ->paginate(self::SAYFA_BOYU, ['*'], 'sayfa');
    }

    /**
     * Tasarımın araması firma adı + yetkili + il üzerinde çalışır; sunucuda karşılıkları
     * `name` / `contact_name` / `city`. Firma kodu (`slug`) da eklendi: destek telefonda çoğu zaman
     * bayiyi kodla söyler ve kod aranamıyorsa liste ekranı işe yaramaz.
     *
     * @param  Builder  $q
     */
    private function aramayiUygula($q): void
    {
        $arama = trim(mb_substr($this->arama, 0, self::ARAMA_TAVANI));
        if ($arama === '') {
            return;
        }

        // Katlama, joker kaçışı ve kaçış karakterinin seçimi TEK KAYNAKTAN: `App\Support\TurkceArama`.
        // Kural hem SQL (`translate`) hem PHP (`strtr`) tarafında yaşamak zorunda ve ikisi ayrışırsa
        // arama SESSİZCE boş döner — o yüzden burada kopyası tutulmaz.
        $desen = TurkceArama::desen($arama);

        $q->where(function ($alt) use ($desen) {
            // Kolon adları SABİT dizidir, kullanıcı girdisi değil — `sutun()` onu sorguya ham gömer.
            foreach (['t.name', 't.contact_name', 't.city', 't.slug'] as $kolon) {
                $alt->orWhereRaw(
                    TurkceArama::sutun($kolon)." LIKE ? ESCAPE '".TurkceArama::KACIS."'",
                    [$desen],
                );
            }
        });
    }

    /**
     * TÜRKÇE HARF SIRASI (tasarımdaki `localeCompare(ad, 'tr')`ın SQL karşılığı). Postgres'in
     * varsayılan sıralaması Türkçe'yi bilmez: "Çınar" C'lerin arasına değil Z'den sonraya düşer ve
     * "Işık" ile "İpek" yer değiştirir.
     *
     * ICU harmanlaması postgres:16 imajında vardır ama bir gün ICU'suz derlenmiş bir sunucuda
     * `42704` (undefined_object) verir ve LİSTE EKRANI TAMAMEN AÇILMAZ. Yanlış sıralama, açılmayan
     * ekrandan iyidir — varlığı bir kez sorulur, yoksa düz sıralamaya düşülür.
     */
    private function trSiralama(): string
    {
        if ($this->icuVar === null) {
            $this->icuVar = DB::connection(self::BAGLANTI)
                ->selectOne('select 1 from pg_collation where collname = ? limit 1', ['tr-TR-x-icu']) !== null;
        }

        return $this->icuVar ? 't.name COLLATE "tr-TR-x-icu" asc' : 't.name asc';
    }
}
