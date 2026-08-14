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

    /** Kurye siparişi teslim etti. Alıcı: bayinin yöneticileri. */
    case SiparisTeslim = 'siparis_teslim';

    /** Kurye kasayı devretti. Alıcı: bayinin yöneticileri. */
    case KasaDevri = 'kasa_devri';

    /**
     * Telefonun bildirimi çizerken kullanacağı kategori (`bildirim_sozlesmesi.dart` →
     * `BildirimKategori.wire`). Bayi o kategoriyi kısmışsa bildirim ÇİZİLMEZ — ama
     * senkron yine koşar; "bildirim istemiyorum" ile "veri gelmesin" aynı şey değildir.
     */
    public function kategori(): string
    {
        return match ($this) {
            self::SiparisAtandi => 'siparis_atandi',
            self::SiparisTeslim => 'siparis_teslim',
            self::KasaDevri => 'kasa_devri',
        };
    }
}
