<?php

namespace App\Support\Konum;

use App\Models\User;

/**
 * Canlı konumun SAKLAMA sözleşmesi — controller'ın gördüğü tek yüzey.
 *
 * NEDEN SOYUT (Geocoder/RotaMotoru deseni): bugün tek satırlık bir Postgres tablosu yeterli,
 * ama bu verinin doğası ilişkisel değil — uçucu, yüksek yazma hızlı, geçmişsiz. Yarın Redis'e
 * ya da bir pub/sub katmanına taşınırsa değişmesi gereken tek şey bağlamadır; controller,
 * FormRequest ve istemci sözleşmesi olduğu gibi kalır.
 *
 * TAZELİK BURADA DEĞİL, İMPLEMENTASYONDA: arayüz "listeyi ver" der, "60 dakikadan eskiyi ele"
 * demez. Eşikler config/konum.php'dedir ve çağıranın bilmesi gereken bir şey değildir —
 * controller bir filtre parametresi geçemez, yani gizlilik sınırı çağrı yerinden gevşetilemez.
 */
interface KonumDeposu
{
    /**
     * Kullanıcının SON konumunu yazar (varsa ezer — kullanıcı başına tek satır, geçmiş tutulmaz).
     * Damga sunucu saatidir; istemci zaman gönderemez.
     */
    public function kalpAtisiKaydet(User $kullanici, float $lat, float $lng, ?float $dogrulukM): void;

    /**
     * Oturumdaki kiracının canlı listesi. Kiracı filtresi PARAMETRE DEĞİLDİR: RLS bağlamı
     * (app.tenant_id) zaten isteğe sarılıdır, filtreyi çağırana bırakmak onu unutulabilir
     * kılardı — kırmızı çizgi #1 uygulama katmanının dikkatine emanet edilmez.
     *
     * @return list<CanliKonum>
     */
    public function canliListe(): array;
}
