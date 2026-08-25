<?php

namespace App\Bildirim;

/**
 * SUNUCUDAN TELEFONA GİDEBİLECEK OLAYLARIN TAM LİSTESİ.
 *
 * Değerler (`wire`) MAĞAZADA DEĞİŞMEZ: telefonlar offline-first çalışır ve günlerce eski
 * sürümde kalır (ölçüldü: `main` bir ara `dev`'in 41 commit gerisindeydi). Bir değeri
 * yeniden adlandırmak, sahadaki eski istemcinin o olayı TANIMAMASI demektir; olay sessizce
 * yutulur ve kimse fark etmez.
 *
 * ⚠️ YÜKTE KİŞİSEL VERİ YOKTUR ve bu pazarlıksızdır (BRIEF kırmızı çizgi #4): müşterinin
 * adı, adresi, telefonu, tutar — hiçbiri FCM'e verilmez. Google'ın sunucularından yalnız
 * bu enum'un değeri ve bir UUID geçer. Bildirimin METNİ telefonda, telefonun kendi
 * veritabanından üretilir. Bu aynı zamanda mimariyi de sağlamlaştırır: dürtü kaybolsa bile
 * (telefon kapalıydı, Play Services takıldı) veri mevcut senkronla akmaya devam eder —
 * push HIZLANDIRICIDIR, taşıyıcı değil.
 *
 * ABONELİK/ÖDEME OLAYI BURAYA EKLENEMEZ — mağaza kuralı (BRIEF: mobilde fiyat, satın alma,
 * yönlendirme bulunamaz). Aynı sınır `bildirim_sozlesmesi.dart` içinde de yazılıdır.
 */
enum PushOlayi: string
{
    /** Patron siparişi bir kuryeye atadı. Alıcı: ATANAN kurye. */
    case SiparisAtandi = 'siparis_atandi';

    /**
     * Sipariş İPTAL edildi ya da kuryeden geri alındı. Alıcı: o ana kadar ATANMIŞ olan kurye.
     *
     * Kurye yola çıkmış olabilir; bugün iptali görmesinin tek yolu uygulamayı açmak.
     */
    case SiparisIptal = 'siparis_iptal';

    /** Kurye siparişi teslim etti. Alıcı: bayinin yöneticileri. */
    case SiparisTeslim = 'siparis_teslim';

    /** Kurye kasayı devretti. Alıcı: bayinin yöneticileri. */
    case KasaDevri = 'kasa_devri';

    /**
     * KURYE İPTAL İSTEDİ. Alıcı: bayinin yöneticileri.
     *
     * Kullanıcı isteği 2026-08-22: *"Kurye siparişi iptal ettiğinde, patrona Onayla veya
     * Reddet şeklinde bildirim gitmeli."* Bildirimin İÇİNDEKİ düğmeler istemci tarafındadır
     * (`bildirim_servisi.dart` → `actions`); sunucu yalnız dürtüyü yollar.
     */
    case SiparisIptalTalebi = 'siparis_iptal_talebi';

    /**
     * İPTAL TALEBİ REDDEDİLDİ. Alıcı: talebi AÇAN kurye.
     *
     * Onayın ayrı bir olayı YOKTUR ve olmamalı: onaylanan talep siparişi gerçekten iptal eder,
     * yani `cancelled` olayı doğar ve o zaten [SiparisIptal] dürtüsünü kuryeye gönderir. İkinci
     * bir olay aynı gerçeği iki kez anlatır ve günlük bildirim bütçesini iki kez yakardı.
     */
    case SiparisIptalReddedildi = 'siparis_iptal_reddedildi';

    /**
     * Hesap YENİ BİR CİHAZDA açıldı. Alıcı: bayinin yöneticileri (giriş yapan cihaz HARİÇ).
     *
     * Güvenlik bildirimi: bugün bir kurye parolasını başkasına verse patronun haberi olmaz.
     * Mobilde karşılığı hazır — Hesap → Cihazlar ekranı.
     */
    case YeniCihaz = 'yeni_cihaz';

    /**
     * Telefonun bildirimi çizerken kullanacağı kategori (`bildirim_sozlesmesi.dart` →
     * `BildirimKategori.wire`). Bayi o kategoriyi kısmışsa bildirim ÇİZİLMEZ — ama
     * senkron yine koşar; "bildirim istemiyorum" ile "veri gelmesin" aynı şey değildir.
     */
    public function kategori(): string
    {
        return match ($this) {
            self::SiparisAtandi => 'siparis_atandi',
            self::SiparisIptal => 'siparis_iptal',
            self::SiparisTeslim => 'siparis_teslim',
            self::KasaDevri => 'kasa_devri',
            // İKİ OLAY, TEK KATEGORİ (2026-08-22): talep ve ret aynı konuşmanın iki yönüdür ve
            // bayi için tek bir anahtardır ("İptal onayı"). Metni ayıran şey yükteki `olay`
            // alanıdır — istemci onu okur (`push_sozlesmesi.dart` → `PushMesaji.olay`).
            self::SiparisIptalTalebi, self::SiparisIptalReddedildi => 'siparis_iptal_onayi',
            self::YeniCihaz => 'yeni_cihaz',
        };
    }
}
