{{--
    E-POSTA DÜZENİ — Sipario "Levha" tasarım sisteminin posta kutusundaki karşılığı.
    Kaynak paleti/tipografisi: public/css/site.css (:root değişkenleri BİREBİR taşındı).

    ÜÇ KISIT TASARIMIN İÇİNE KATILDI — bunlar üslup tercihi değil, posta istemcisi davranışıdır
    ve her biri sitedeki bir çözümü BURADA kullanılamaz kılar:

    1. WEB FONT YÜKLENMEZ. Gmail, Outlook ve Yahoo `@font-face`i düşürür. Sitedeki Sora/Hanken
       Grotesk/JetBrains Mono üçlüsü burada yalnız yığının BAŞI olarak yazılır; gerçekte
       okuyucunun sistem yazı tipi çizer. Bu yüzden hiçbir yerleşim font metriğine bağlanmadı
       (sabit yükseklikli düğme yok, harf sayısına göre hizalama yok).

    2. SVG SİLİNİR. Gmail `<svg>`i ve `data:image/svg+xml`i tamamen kaldırır — yani
       `x-site.ikon` bileşeninin tamamı ve `marka.blade.php`nin çağrı ikonu burada ÇALIŞMAZ.
       Marka bu yüzden GÖRSELSİZ kuruldu: mor yuvarlak kare + "S" monogramı + "Sipario"
       wordmark'ı. Harici bir logo dosyası da BİLEREK kullanılmadı — uzak görseller "resimleri
       göster" denene kadar boş kutu olarak durur ve markanın ilk izlenimi kırık bir ikon olur.
       Tanınan şey ikon değil, mor kare + wordmark bileşimidir; o korundu.

    3. FLEX/GRID YOK. Outlook'un Word çizicisi ikisini de tanımaz. Yerleşimin tamamı
       `role="presentation"` tablolarıdır ve stiller SATIR İÇİDİR (`<style>` bloğu yalnız
       koyu mod ve dar ekran için; Gmail `<head>`deki medya sorgularını korur, geri kalanını
       atar — bu yüzden hiçbir GÖRÜNÜM kuralı oraya konmadı, yalnız uyarlamalar).

    KOYU MOD: sistemin kendi "gece" paleti kullanılır (site.css `.gece` bloğu) — yani koyu mod
    uydurma değil, markanın zaten tanımlı ikinci yüzüdür. Yalnız `prefers-color-scheme` destekleyen
    istemcilerde döner; desteklemeyende açık tasarım kendi başına eksiksizdir.

    Kullanım:
      <x-eposta.duzen onizleme="Aboneliğiniz 3 gün sonra bitiyor" kulak="Abonelik">
          ...bloklar...
      </x-eposta.duzen>
--}}
@props(['onizleme' => '', 'kulak' => ''])
@php
    /*
     * KÜNYE YER TUTUCU SÜZGECİ — config/subscription.php'deki şirket alanları BUGÜN köşeli
     * parantezli yer tutucudur ("[Şirket adresi]") ve o dosya bunu bilerek böyle bırakır:
     * uydurma bir bilgi göstermektense yer tutucu göstermek yeğdir. Ama o gerekçe EKRAN için
     * geçerlidir — müşteriye giden bir postanın altına "[Şirket adresi]" basmak markayı yarım
     * kurulmuş gösterir. Burada kural şu: yer tutucu = YOK say, satırı hiç çizme. Şirket
     * kurulup env dolduğunda satırlar kendiliğinden görünür, şablon değişmez.
     */
    $gercek = static fn ($d): string => is_string($d) && $d !== '' && ! str_starts_with(trim($d), '[')
        ? trim($d)
        : '';

    $kunye = (array) config('subscription.company', []);
    $destek = $gercek($kunye['support_email'] ?? null) ?: 'destek@sipario.com.tr';
    $unvan = $gercek($kunye['title'] ?? null) ?: 'Sipario';
    $adres = $gercek($kunye['address'] ?? null);
    $calismaSaati = $gercek($kunye['hours'] ?? null);
@endphp
<meta charset="utf-8">
<meta name="viewport" content="width=device-width,initial-scale=1">
<meta name="x-apple-disable-message-reformatting">
<meta name="color-scheme" content="light dark">
<meta name="supported-color-schemes" content="light dark">
<style>
    /* Dar ekran: 600px'lik gövde telefonda kenara yapışmasın. */
    @media only screen and (max-width: 620px) {
        .e-kap { width: 100% !important; }
        .e-yan { padding-left: 16px !important; padding-right: 16px !important; }
        .e-ic { padding: 22px 18px !important; }
        .e-genis { display: block !important; width: 100% !important; }
    }

    /* Koyu mod = markanın "gece" paleti (site.css .gece). Satır içi stilleri ezmek için
       !important ZORUNLU — satır içi stil her zaman daha yüksek özgüllüktedir. */
    @media (prefers-color-scheme: dark) {
        .e-govde, .e-zemin { background: #16131C !important; }
        .e-pano { background: #221D2C !important; border-color: #443C55 !important; }
        .e-pano-bas { border-bottom-color: #443C55 !important; }
        .e-murekkep, .e-murekkep * { color: #F3F0EC !important; }
        .e-metin, .e-metin * { color: #B9B2C4 !important; }
        .e-sonuk, .e-sonuk * { color: #8A8397 !important; }
        .e-cizgi { border-color: #332C41 !important; }
        .e-duz { background: #231E2E !important; border-color: #443C55 !important; }
        .e-kod { background: #231E2E !important; border-color: #443C55 !important; }
        .e-kod, .e-kod * { color: #F3F0EC !important; }
        .e-mor-metin, .e-mor-metin * { color: #B3A6FF !important; }
        .e-kutu-mor { background: #2A2350 !important; }
        .e-kutu-mor, .e-kutu-mor * { color: #C3B8FF !important; }
        .e-kutu-yesil { background: #16342A !important; }
        .e-kutu-yesil, .e-kutu-yesil * { color: #4FD69C !important; }
        .e-kutu-sari { background: #33280F !important; }
        .e-kutu-sari, .e-kutu-sari * { color: #E8B65A !important; }
        .e-kutu-kirmizi { background: #3A1D1F !important; }
        .e-kutu-kirmizi, .e-kutu-kirmizi * { color: #FF9296 !important; }
    }
</style>

<div class="e-govde" style="margin:0;padding:0;width:100%;background:#F5F2EE;">
    {{-- Önizleme satırı: gelen kutusunda konunun yanında görünür. Ardındaki görünmez karakter
         dizisi, istemcinin devamını GÖVDE metniyle doldurmasını engeller (yoksa gövdenin ilk
         cümlesi önizlemeye sızar ve iki kez okunmuş olur). --}}
    <div style="display:none;font-size:1px;color:#F5F2EE;line-height:1px;max-height:0;max-width:0;opacity:0;overflow:hidden;">
        {{ $onizleme }}
        {!! str_repeat('&#8199;&#65279;&#847; ', 40) !!}
    </div>

    <table role="presentation" cellpadding="0" cellspacing="0" border="0" width="100%" class="e-zemin" style="background:#F5F2EE;border-collapse:collapse;">
        <tr>
            <td align="center" class="e-yan" style="padding:32px 24px 44px 24px;">

                <table role="presentation" cellpadding="0" cellspacing="0" border="0" width="600" class="e-kap" style="width:600px;max-width:600px;border-collapse:collapse;">

                    {{-- ── Marka ─────────────────────────────────────────────────────────── --}}
                    <tr>
                        <td style="padding:0 2px 20px 2px;">
                            <table role="presentation" cellpadding="0" cellspacing="0" border="0">
                                <tr>
                                    {{-- Mor yuvarlak kare. Outlook radius'u yok sayar ve kare çizer —
                                         kabul: "Levha" zaten kenarı keskin, mürekkep konturlu bir dildir. --}}
                                    <td width="34" style="width:34px;height:34px;background:#5A45F0;border-radius:10px;text-align:center;vertical-align:middle;font-family:'Sora','Segoe UI',Roboto,Helvetica,Arial,sans-serif;font-size:18px;font-weight:800;color:#ffffff;line-height:34px;">S</td>
                                    <td style="padding-left:11px;font-family:'Sora','Segoe UI',Roboto,Helvetica,Arial,sans-serif;font-size:20px;font-weight:800;letter-spacing:-0.03em;color:#16131C;" class="e-murekkep">Sipario</td>
                                </tr>
                            </table>
                        </td>
                    </tr>

                    {{-- ── Pano ──────────────────────────────────────────────────────────── --}}
                    <tr>
                        <td class="e-pano" style="background:#FFFFFF;border:1.5px solid #16131C;border-radius:9px;">
                            <table role="presentation" cellpadding="0" cellspacing="0" border="0" width="100%" style="border-collapse:collapse;">
                                @if ($kulak !== '')
                                    {{-- Pano başlığı: mono, büyük harf, geniş harf aralığı + mor kare nokta.
                                         Sitedeki `.pano-bas` + `.blm-kulak` bileşiminin karşılığı. --}}
                                    <tr>
                                        <td class="e-pano-bas" style="padding:13px 20px;border-bottom:1.5px solid #16131C;">
                                            <table role="presentation" cellpadding="0" cellspacing="0" border="0">
                                                <tr>
                                                    <td width="7" style="width:7px;"><div style="width:7px;height:7px;background:#5A45F0;border-radius:2px;font-size:0;line-height:0;">&nbsp;</div></td>
                                                    <td style="padding-left:9px;font-family:'JetBrains Mono',ui-monospace,SFMono-Regular,Consolas,'Liberation Mono',monospace;font-size:11px;font-weight:500;letter-spacing:0.16em;text-transform:uppercase;color:#7B7486;" class="e-sonuk">{{ $kulak }}</td>
                                                </tr>
                                            </table>
                                        </td>
                                    </tr>
                                @endif
                                <tr>
                                    <td class="e-ic" style="padding:28px 26px;font-family:'Hanken Grotesk','Segoe UI',Roboto,Helvetica,Arial,sans-serif;font-size:16px;line-height:1.62;color:#413B4C;">
                                        {{ $slot }}
                                    </td>
                                </tr>
                            </table>
                        </td>
                    </tr>

                    {{-- ── Alt bilgi ─────────────────────────────────────────────────────── --}}
                    <tr>
                        <td style="padding:22px 6px 0 6px;font-family:'Hanken Grotesk','Segoe UI',Roboto,Helvetica,Arial,sans-serif;font-size:12.5px;line-height:1.55;color:#7B7486;" class="e-sonuk">
                            {{--
                                TİCARİ ELEKTRONİK İLETİ AYRIMI (6563 sayılı kanun / İYS): bu düzenden
                                çıkan postaların HEPSİ hizmet/işlem bildirimidir — bayinin kendi talebi
                                ya da sözleşmesi gereği gönderilir, onay gerektirmez ve İYS'ye işlenmez.
                                Aşağıdaki cümle o ayrımı POSTANIN İÇİNDE beyan eder. Bir gün pazarlama
                                postası eklenirse bu düzen KULLANILAMAZ: ayrı düzen + İYS onayı +
                                çıkma (ret) bağlantısı gerekir. Bu satırı silip pazarlama göndermek,
                                kanunun aradığı ayrımı görünmez kılar.
                            --}}
                            <p style="margin:0 0 10px 0;">
                                Bu ileti Sipario hesabınıza ait bir <strong style="color:#413B4C;" class="e-metin">hizmet bildirimidir</strong>; pazarlama iletisi değildir.
                            </p>
                            <p style="margin:0 0 10px 0;">
                                Sorunuz olursa bu iletiyi yanıtlayabilir ya da
                                <a href="mailto:{{ $destek }}" style="color:#5A45F0;text-decoration:underline;" class="e-mor-metin">{{ $destek }}</a>
                                adresine yazabilirsiniz.@if ($calismaSaati !== '') {{ $calismaSaati }}@endif
                            </p>
                            <p style="margin:0;">
                                {{ $unvan }}@if ($adres !== '') · {{ $adres }}@endif
                            </p>
                        </td>
                    </tr>

                </table>
            </td>
        </tr>
    </table>
</div>
