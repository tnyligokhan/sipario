<?php

namespace App\Livewire\Site\Forms;

/**
 * ŞİRKETİN TAHSİLAT KÜNYESİNİ OKUYAN TEK NOKTA (ödeme ekranı + hesap panelindeki "Ödeme yöntemi").
 *
 * Neden tek yer: bayi bu satırlara bakıp PARA GÖNDERİYOR. İkinci bir kopya çıkarsa biri bayatlar
 * ve bayi yanlış hesaba havale yapar; bunun telafisi yoktur. Değerlerin kendisi
 * `config('subscription.company')`dedir (env'den) — burada yalnız okunur, hiçbir şey sabitlenmez.
 *
 * DEĞERLER HENÜZ YOK: şirket kurulmadı, varsayılanlar köşeli parantez yer tutucudur
 * ("[Şirket IBAN]") ve sitenin künyesiyle aynı biçimdedir. SAHTE IBAN ÜRETİLMEZ — tasarımdaki
 * `TR12 0001…` örnek bir numaraydı. `tenant_settings.iban` de KULLANILAMAZ: o, bayinin KENDİ
 * müşterilerinden tahsilat yaptığı hesaptır; abonelik tahsilatında kullanmak bayinin parasını
 * bize yönlendirmek olurdu.
 *
 * Gerçek değerler geldiğinde dokunulacak tek yer `config/subscription.php`'deki `company` bloğudur.
 */
trait SirketKunyesi
{
    /**
     * @return array{unvan: string, banka: string, iban: string}
     */
    public function sirket(): array
    {
        return [
            'unvan' => (string) config('subscription.company.title', '[Şirket unvanı]'),
            'banka' => (string) config('subscription.company.bank', '[Şirket bankası]'),
            'iban' => (string) config('subscription.company.iban', '[Şirket IBAN]'),
        ];
    }
}
