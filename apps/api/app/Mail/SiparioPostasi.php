<?php

namespace App\Mail;

use Illuminate\Bus\Queueable;
use Illuminate\Contracts\Queue\ShouldQueue;
use Illuminate\Mail\Mailable;
use Illuminate\Mail\Mailables\Address;
use Illuminate\Mail\Mailables\Content;
use Illuminate\Mail\Mailables\Envelope;
use Illuminate\Queue\SerializesModels;

/**
 * Sipario'dan çıkan HER postanın ortak tabanı.
 *
 * NEDEN ORTAK BİR TABAN VAR: bu depoda bir e-posta üç ayrı yerde bozulabilir ve üçü de sessizdir
 * — yanlış gönderen adresi, eksik düz metin karşılığı, kuyruğa girmeyip isteği bekleten gönderim.
 * Üçünü de tek yerde çözmek, on dört şablonun on dördünde ayrı ayrı hatırlamaktan güvenlidir.
 *
 * ÜÇ KARAR BURADA MERKEZÎDİR:
 *
 * 1. KUYRUĞA GİRER (`ShouldQueue`). Posta gönderimi bir SMTP el sıkışması demektir; kayıt
 *    formunun ya da panel onay düğmesinin yanıtını ona bağlamak, sunucu yavaşladığında
 *    kullanıcıyı bekletir. Üretimde `queue:work` zaten koşuyor (docker-compose.prod.yml:290).
 *
 * 2. HER POSTANIN DÜZ METİN KARŞILIĞI VARDIR. Yalnız HTML gönderen ileti spam puanında
 *    cezalandırılır; ayrıca ekran okuyucu ve metin istemcisi kullanan okuyucu için tek
 *    okunabilir sürüm odur. `sablon()` tek bir ad döndürür, iki görünüm o addan türetilir —
 *    yani düz metin karşılığını YAZMAYI UNUTMAK mümkün değil, dosya yoksa gönderim patlar.
 *
 * 3. YANITLANABİLİR. `replyTo` destek kutusudur. Bir bayi "ödemem neden eşleşmedi" diye
 *    postayı yanıtladığında cevabın hiçbir yere gitmemesi, desteği yok saymaktır.
 *
 * KONU SATIRI KURALI: konuya "Sipario ·" ÖN EKİ KONMAZ. Gönderen adı zaten "Sipario"dur ve
 * telefonda konu satırı ~35 karakterde kırpılır; ön ek, bilginin yerini alır. Tek istisna
 * BİZE gelen iç bildirimlerdir (`IcBildirim`) — orada ön ek süzgeç anahtarıdır.
 */
abstract class SiparioPostasi extends Mailable implements ShouldQueue
{
    use Queueable, SerializesModels;

    /** Görünüm adı — `eposta/<ad>.blade.php` ve `eposta/metin/<ad>.blade.php` ikilisini çözer. */
    abstract protected function sablon(): string;

    abstract protected function konu(): string;

    /** Gelen kutusunda konunun yanında görünen önizleme satırı. Boşsa istemci gövdeden çalar. */
    protected function onizleme(): string
    {
        return '';
    }

    public function envelope(): Envelope
    {
        $destek = (string) config('subscription.company.support_email', 'destek@sipario.com.tr');

        return new Envelope(
            subject: $this->konu(),
            replyTo: [new Address($destek, 'Sipario destek')],
        );
    }

    public function content(): Content
    {
        $ad = $this->sablon();

        return new Content(
            view: 'eposta.'.$ad,
            text: 'eposta.metin.'.$ad,
            with: ['onizleme' => $this->onizleme()],
        );
    }
}
