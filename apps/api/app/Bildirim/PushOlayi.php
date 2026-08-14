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
            self::YeniCihaz => 'yeni_cihaz',
        };
    }
}
