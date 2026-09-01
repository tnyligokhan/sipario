<?php

namespace App\Support;

use App\Models\User;

/**
 * PATRON HESABININ MOBİL GİRİŞ ADINI, KAYITTA GİRİLEN BİLGİLERDEN TÜRETİR.
 *
 * NEDEN ARTIK SABİT 'patron' DEĞİL (2026-08-31, kullanıcı kararı): kullanıcı adı bayi İÇİNDE
 * tekildir, dolayısıyla her bayide 'patron' teknik olarak meşrudu ve bu yüzden yıllarca sabit
 * kaldı. Ama sabit ad iki gerçek bedel doğurdu:
 *  - EKRANDA HİÇ GÖRÜNMÜYORDU. Bayi kendi kullanıcı adını yalnız hoş geldiniz postasında bir kez
 *    görüyordu; postayı silen ya da hiç almayan (SMTP arızası posta akışını DÜŞÜRMEZ) bayi için
 *    giriş adı öğrenilebilir bir bilgi değildi. "Kullanıcı adım neydi" sorusunun cevabı destekti.
 *  - AYIRT EDİCİ DEĞİLDİ. İki bayiye aynı anda bakan bir operatör için 'patron' hiçbir şey
 *    söylemiyor; kendi hesabına bakan bayi için de "benim adım" hissi vermiyordu.
 *
 * TÜRETİM KAYNAĞI SIRAYLA: yetkilinin adı → e-postanın yerel kısmı → 'patron'. Yetkili adı ilk
 * sırada çünkü telefonda söylenmesi ve akılda tutulması en kolay olan odur ("hasan.aslan").
 * E-posta yedeği, adın girilmediği yollar (konsol komutu, ad'sız provizyon) için vardır; son
 * yedek eski davranışın ta kendisidir, yani hiçbir girdi işe yaramazsa hesap yine de açılır.
 *
 * ALFABE DB KISITININ AYNISIDIR (`users_username_check`: ^[a-z0-9._-]{3,60}$). Türetilen ad bu
 * kısıtı geçemezse üretim kendi kendini yalanlar: INSERT 23514 ile düşer ve kayıt akışı, hiçbir
 * kullanıcı hatası olmadan 500 verirdi. Bu yüzden normalleştirme kısıtı KOPYALAMAZ, kısıtın
 * kabul ettiği alfabeye İNDİRİR ve indiremezse boş döner (bir sonraki kaynağa geçilir).
 *
 * TEKİLLİK BURADA DA SORULUR, tenant yeni açılıyor olsa bile: bu sınıf yarın var olan bir bayiye
 * ikinci bir hesap açan bir yolda da çağrılabilir ve o gün sessiz bir 23505 üretmesi, çağıranın
 * hiç beklemediği bir arıza olurdu. Sorgu OWNER bağlantısıyla koşar — RLS'li bağlantıda kiracı
 * bağlamı kurulu değilse tekillik sorgusu SIFIR satır görür ve kapı sessizce açılırdı
 * (`KuryeFormu`nun belge başlığındaki aynı ders).
 */
final class KullaniciAdiUretici
{
    /** DB CHECK'iyle aynı sınırlar. */
    private const ALT_SINIR = 3;

    private const UST_SINIR = 60;

    /**
     * Türetilen adın hedef uzunluğu. Kısıt 60'a izin verir ama bu ad TELEFONDA SÖYLENİR ve küçük
     * bir ekrana elle yazılır; "mehmet.ali.karaosmanoglu.ticaret" teknik olarak geçerli, pratikte
     * kullanılamaz bir giriş adıdır.
     */
    private const HEDEF_UZUNLUK = 24;

    public function __construct(private readonly string $connection = 'pgsql_owner') {}

    /**
     * Bayi içinde tekil, DB kısıtına uyan bir patron kullanıcı adı döndürür.
     *
     * @param  string  $tenantId  tekillik bu bayinin içinde sorulur
     * @param  string|null  $ad  yetkilinin adı (kayıt formundaki "ad soyad")
     * @param  string|null  $eposta  yetkilinin e-postası — ad işe yaramazsa yerel kısmı kullanılır
     */
    public function patronIcin(string $tenantId, ?string $ad, ?string $eposta = null): string
    {
        foreach ([$ad, $this->epostaYereli($eposta)] as $kaynak) {
            $taban = $this->normalize((string) $kaynak);
            if ($taban !== '') {
                return $this->tekillestir($tenantId, $taban);
            }
        }

        return $this->tekillestir($tenantId, 'patron');
    }

    /**
     * Serbest metni kısıtın alfabesine indirir; indiremezse (3 karakterin altına düşerse) BOŞ
     * döner — çağıran bir sonraki kaynağa geçsin diye. Boş yerine 'x' gibi bir dolgu üretmek,
     * kimsenin tanımadığı bir giriş adı yaratmak olurdu.
     */
    private function normalize(string $ham): string
    {
        // Türkçe harfler ASCII karşılığına İNDİRİLİR. `mb_strtolower`dan ÖNCE yapılır: 'İ' bazı
        // yapılandırmalarda 'i' + birleşen nokta olarak küçülür ve kısıt onu reddederdi.
        $tr = ['ç' => 'c', 'ğ' => 'g', 'ı' => 'i', 'İ' => 'i', 'ö' => 'o', 'ş' => 's', 'ü' => 'u',
            'Ç' => 'c', 'Ğ' => 'g', 'I' => 'i', 'Ö' => 'o', 'Ş' => 's', 'Ü' => 'u',
            'â' => 'a', 'î' => 'i', 'û' => 'u', 'Â' => 'a', 'Î' => 'i', 'Û' => 'u'];

        $ad = mb_strtolower(strtr(trim($ham), $tr), 'UTF-8');

        // Alfabe dışındaki her şey (boşluk dahil) NOKTAya iner: "Hasan Aslan" → "hasan.aslan".
        // Ardışık noktalar tekleşir, baştaki/sondaki ayraçlar atılır — ".hasan." bir ad değildir.
        $ad = (string) preg_replace('/[^a-z0-9._-]+/u', '.', $ad);
        $ad = (string) preg_replace('/[._-]{2,}/', '.', $ad);
        $ad = trim($ad, '._-');

        // Kırpma bir ayracın üstüne düşebilir ("ahmet.mehmet.ali" → "ahmet.mehmet."); ikinci
        // trim onu temizler. Sıra önemli: önce kırp, sonra temizle.
        $ad = trim(mb_substr($ad, 0, self::HEDEF_UZUNLUK), '._-');

        return mb_strlen($ad) >= self::ALT_SINIR ? $ad : '';
    }

    /** E-postanın '@' öncesi kısmı. '@' yoksa metnin kendisi denenir (bozuk adres de bir ipucudur). */
    private function epostaYereli(?string $eposta): string
    {
        if ($eposta === null) {
            return '';
        }

        $yerel = strstr($eposta, '@', true);

        return $yerel === false ? $eposta : $yerel;
    }

    /**
     * Bayide alınmışsa sonuna sayaç ekler. Sayaç 99'da durur ve rastgele eke düşer: sonsuz
     * döngü yerine kesin sonuç veren bir kapı, çünkü burada takılmak bir kayıt akışını asardı.
     */
    private function tekillestir(string $tenantId, string $taban): string
    {
        if (! $this->alinmis($tenantId, $taban)) {
            return $taban;
        }

        for ($n = 2; $n <= 99; $n++) {
            $aday = $taban.$n;
            if (! $this->alinmis($tenantId, $aday)) {
                return $aday;
            }
        }

        return mb_substr($taban, 0, self::UST_SINIR - 9).'.'.bin2hex(random_bytes(4));
    }

    private function alinmis(string $tenantId, string $aday): bool
    {
        return User::on($this->connection)
            ->where('tenant_id', $tenantId)
            ->where('username', $aday)
            ->exists();
    }
}
