<?php

namespace App\Panel;

use Illuminate\Support\Carbon;
use Illuminate\Support\Facades\DB;

/**
 * Müşteri ve sipariş listelerinin CSV DIŞA AKTARIMI (5c-3 · D4). Mevcut JSON export
 * (`PanelExportService`) DURUR — o teknik bir dump'tır (geri yükleme/taşıma için, tüm tablolar);
 * bu ise İNSANIN Excel'de açacağı iki liste. İkisi farklı işlere hizmet ettiği için biri diğerinin
 * yerine geçmiyor.
 *
 * SALT-OKUNUR — `pgsql_panel` (BYPASSRLS) ile okunur ve HER sorgu `tenant_id` ile açıkça
 * filtrelenir (kırmızı çizgi #1; RLS yedeği yok).
 *
 * Hücreler `Csv::hucre` üzerinden geçer: müşteri adı gibi KULLANICI GİRDİSİ alanlar, elektronik
 * tabloda formül olarak yorumlanabilecek bir karakterle başlıyorsa kaçırılır.
 */
class PanelCsvExportService
{
    public function __construct(private readonly string $connection = 'pgsql_panel') {}

    /** Müşteri listesi: kod, ad, telefon, adres, bölge, bakiye, kara liste, son sipariş. */
    public function musteriler(string $tenantId): string
    {
        $satirlar = DB::connection($this->connection)->table('customers as c')
            ->where('c.tenant_id', $tenantId)
            ->whereNull('c.deleted_at')
            ->select('c.id', 'c.code', 'c.name', 'c.note', 'c.balance_kurus', 'c.blacklisted_at')
            ->selectSub($this->altSorgu('customer_phones', 'phone_e164'), 'telefon')
            ->selectSub($this->altSorgu('customer_addresses', 'address_text'), 'adres')
            ->selectSub($this->altSorgu('customer_addresses', 'region'), 'bolge')
            ->selectSub(
                DB::connection($this->connection)->table('orders as o')
                    ->selectRaw('max(o.occurred_at)')
                    ->whereColumn('o.tenant_id', 'c.tenant_id')
                    ->whereColumn('o.customer_id', 'c.id')
                    ->whereNull('o.deleted_at'),
                'son_siparis'
            )
            ->orderBy('c.name')
            ->get();

        return Csv::olustur(
            ['kod', 'ad', 'telefon', 'adres', 'bolge', 'bakiye', 'kara_liste', 'son_siparis', 'not'],
            $satirlar->map(fn ($m) => [
                $m->code,
                $m->name,
                $m->telefon,
                $m->adres,
                $m->bolge,
                $this->lira($m->balance_kurus),
                $m->blacklisted_at ? 'evet' : 'hayır',
                $this->tarih($m->son_siparis),
                $m->note,
            ]),
        );
    }

    /**
     * Sipariş listesi. Süzgeçler bayi detayındaki sekmeyle AYNI anlamı taşır — ekranda süzüp
     * dışa aktarınca farklı bir liste inmesi en can sıkıcı kusurlardan biri olurdu.
     *
     * @param  array{durum?: string, baslangic?: string, bitis?: string}  $filtre
     */
    public function siparisler(string $tenantId, array $filtre = []): string
    {
        $q = DB::connection($this->connection)->table('orders as o')
            ->where('o.tenant_id', $tenantId)
            ->whereNull('o.deleted_at')
            ->leftJoin('customers as c', function ($j) {
                $j->on('c.id', '=', 'o.customer_id')->on('c.tenant_id', '=', 'o.tenant_id');
            })
            ->leftJoin('users as u', function ($j) {
                $j->on('u.id', '=', 'o.assigned_user_id')->on('u.tenant_id', '=', 'o.tenant_id');
            })
            ->select('o.code', 'o.status', 'o.total_kurus', 'o.payment_type', 'o.occurred_at', 'o.note',
                'c.name as musteri', 'c.code as musteri_kodu', 'u.name as kurye');

        if (($filtre['durum'] ?? '') !== '') {
            $q->where('o.status', $filtre['durum']);
        }
        if (($filtre['baslangic'] ?? '') !== '') {
            $q->whereRaw("(o.occurred_at AT TIME ZONE 'Etc/GMT-3')::date >= ?", [$filtre['baslangic']]);
        }
        if (($filtre['bitis'] ?? '') !== '') {
            $q->whereRaw("(o.occurred_at AT TIME ZONE 'Etc/GMT-3')::date <= ?", [$filtre['bitis']]);
        }

        $satirlar = $q->orderByDesc('o.occurred_at')->get();

        return Csv::olustur(
            ['siparis_kodu', 'tarih', 'musteri_kodu', 'musteri', 'durum', 'tutar', 'odeme', 'kurye', 'not'],
            $satirlar->map(fn ($s) => [
                $s->code,
                $this->tarih($s->occurred_at),
                $s->musteri_kodu,
                $s->musteri,
                $s->status,
                $this->lira($s->total_kurus),
                $s->payment_type,
                $s->kurye,
                $s->note,
            ]),
        );
    }

    // ------------------------------------------------------------------------------------

    /** Müşterinin BİRİNCİL telefon/adres alanı (liste satırı başına tek değer). */
    private function altSorgu(string $tablo, string $kolon): mixed
    {
        return DB::connection($this->connection)->table($tablo.' as x')
            ->select('x.'.$kolon)
            ->whereColumn('x.tenant_id', 'c.tenant_id')
            ->whereColumn('x.customer_id', 'c.id')
            ->whereNull('x.deleted_at')
            ->orderByDesc('x.is_primary')
            ->limit(1);
    }

    /** Kuruş → lira metni. Ondalık ayırıcı VİRGÜL: dosyayı TR Excel açacak. */
    private function lira(int|string|null $kurus): string
    {
        return number_format(((int) $kurus) / 100, 2, ',', '');
    }

    private function tarih(?string $ham): string
    {
        return $ham !== null ? Carbon::parse($ham)->format('d.m.Y H:i') : '';
    }
}
