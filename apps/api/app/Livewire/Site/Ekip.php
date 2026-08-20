<?php

namespace App\Livewire\Site;

use App\Abonelik\KotaDoluException;
use App\Abonelik\KuryeKotasi;
use App\Enums\UserRole;
use App\Eposta\BayiPostacisi;
use App\Livewire\Site\Forms\IsletmeFormu;
use App\Livewire\Site\Forms\KuryeFormu;
use App\Mail\KuryeHesabiAcildi;
use App\Models\Tenant;
use App\Models\User;
use App\Support\Sync\SyncService;
use Illuminate\Contracts\View\View;
use Illuminate\Support\Collection;
use Illuminate\Support\Facades\Auth;
use Illuminate\Support\Facades\DB;
use Illuminate\Support\Facades\Log;
use Illuminate\Support\Str;
use Livewire\Attributes\Computed;
use Livewire\Attributes\Locked;
use Livewire\Component;
use RuntimeException;
use Throwable;

/**
 * EKİP YÖNETİMİ — bayinin web hesap panelindeki bölüm (kullanıcı şikâyeti: "kurye hesaplarını
 * web panelinden ekleyebilmeli, silebilmeli"). Hesap bileşeninin İÇİNDE gömülü çalışır.
 *
 * MOBİLDE BU EKRANIN YARISI ZATEN VAR (`kuryeler_ekrani.dart`) ve orada bilerek "yeni kurye
 * hesabı buradan AÇILAMAZ" yazıyor: kullanıcı yaratmak e-posta+parola üretmeyi gerektirir ve
 * kimlik yüzeyini offline senkron kuyruğuna açmak yetki yükseltme vektörüdür. Eksik olan yüzey
 * mobil değil WEB'di; bu bileşen o boşluğu kapatır, mobildeki davranışı taklit eder.
 *
 * ÜÇ YAZMA YOLU VAR ve üçü de FARKLI bağlantı kullanır — ayrım bilinçlidir:
 *
 *  1. HESAP AÇMA → `Provisioning::createCourier` (owner). Kiracı-üstü bir provizyon eylemidir;
 *     kota kapısı (`KuryeKotasi`) o yolun İÇİNDEDİR. Kayıt telefona `sync_changes` ile değil,
 *     her senkron yanıtındaki `team` bloğuyla iner (users delta günlüğünde hiç yoktur).
 *
 *  2. AKTİFLİK DEĞİŞİMİ → mobilin kullandığı AYNI yoldan: RLS bağlamı + `SyncService::push` +
 *     `ProfileChangeApplier`. Doğrudan UPDATE atmak KAYITLI TUZAĞA düşerdi ("cihazsız yazım
 *     LWW'de sessizce bayat kalır"): `users.updated_occurred_at`/`updated_device_id` ilerlemezse
 *     telefonun kuyruğunda bekleyen ESKİ bir profil yazımı sunucuya ulaştığında kazanır ve devre
 *     dışı bıraktığımız kurye kendiliğinden geri açılır. Bu arıza hiçbir ekranda görünmez.
 *     Push yolu ayrıca abonelik kilidini de bedava getirir: süresi dolmuş bayide 'locked' döner.
 *
 *  3. OTURUM DÜŞÜRME → owner. Pasifleştirme yalnız YENİ girişi kapatır (`AuthController`
 *     `status !== 'active'` bakar); elde duran Sanctum token'ını hiçbir middleware denetlemez,
 *     yani token silinmezse kurye pasifken senkrona devam eder ve "devre dışı bıraktım" cümlesi
 *     yalan olur. `TeamController`ın parola değişiminde yaptığının aynısı.
 *
 * OKUMA RLS'li `pgsql` ile, kiracı bağlamı kurularak yapılır (`Hesap::isVerisinde` ile aynı
 * gerekçe): `users` üzerinde `sipario_app`in izni vardır, yani veritabanının kendi zorlaması
 * bedava gelir — `where tenant_id` yazılmaya devam eder ama artık tek savunma değildir.
 *
 * SİLME = PASİFLEŞTİRME, ve bu bir ödün değil KISITTIR. Kuryeye referans veren kolonların
 * hiçbirinde FK YOKTUR (`orders.assigned_user_id`, `ledger_entries.collected_by_user_id`,
 * `cash_handovers.from_user_id`/`to_user_id`, `day_closings.user_id`) — gerçek bir DELETE
 * veritabanı tarafından ENGELLENMEZ, sessizce sahipsiz para kayıtları bırakır ve kırmızı çizgi
 * #2'yi (para kayıtları silinmez/ezilmez) delerdi. Ekranda ne olduğu dürüstçe yazılır.
 *
 * KİM: yalnız PATRON. Kontrol her eylemin İÇİNDEDİR (route middleware'ine güvenilmez — 5c-3
 * dersi: Livewire eylemi `/livewire/update`e gider, sayfanın route middleware'i orada koşmaz).
 */
class Ekip extends Component
{
    /** Oturumdaki bayi — istemci DEĞİŞTİREMEZ (kırmızı çizgi #1'in runtime yarısı). */
    #[Locked]
    public string $bayiId = '';

    /** Yetkiyi taşıyan patron. Boşsa ekran salt-bilgidir ve HİÇBİR eylem çalışmaz. */
    #[Locked]
    public string $patronId = '';

    public KuryeFormu $form;

    public bool $formAcik = false;

    /** Onay bekleyen aktiflik değişimi (kullanıcı kimliği). */
    public string $onay = '';

    /**
     * Bayi ve yetki OTURUMDAN çözülür, dışarıdan PARAMETRE ALINMAZ. `Hesap` bileşeni panele
     * `session('subscription_tenant_id')` ile de girilebilmesine izin verir (ödeme akışının
     * ortasındaki, henüz giriş yapmamış bayi) — ekip yönetimi o kapıdan AÇILMAZ: kimlik
     * yaratan bir yüzey, kimliği doğrulanmamış bir oturuma verilemez.
     */
    public function mount(): void
    {
        $kullanici = Auth::guard('web')->check() ? Auth::guard('web')->user() : null;

        if ($kullanici instanceof User && $kullanici->role === UserRole::Patron) {
            $this->bayiId = (string) $kullanici->tenant_id;
            $this->patronId = (string) $kullanici->id;
        }
    }

    public function render(): View
    {
        return view('livewire.site.ekip');
    }

    public function yetkili(): bool
    {
        return $this->bayiId !== '' && $this->patronId !== '';
    }

    // ── Okuma ────────────────────────────────────────────────────────────────

    /**
     * Bayinin tüm ekibi (patron dahil) — tasarımın "kim var" sorusu kişilerden önce gelir.
     * Pasif hesaplar da DÖNER: işten ayrılan kuryenin adı geçmiş atamalarda okunur kalmalı ve
     * patron onu geri açabilmeli.
     *
     * @return Collection<int, User>
     */
    #[Computed]
    public function ekip(): Collection
    {
        if (! $this->yetkili()) {
            return collect();
        }

        return $this->isVerisinde(fn (): Collection => User::query()
            ->where('tenant_id', $this->bayiId)
            ->orderByRaw("case role when 'patron' then 0 when 'operator' then 1 else 2 end")
            ->orderBy('name')
            ->get(['id', 'name', 'username', 'phone', 'role', 'status']));
    }

    /**
     * @return array{limit: int, kullanilan: int, kalan: int}
     */
    public function kota(): array
    {
        if (! $this->yetkili()) {
            return ['limit' => 0, 'kullanilan' => 0, 'kalan' => 0];
        }

        return (new KuryeKotasi('pgsql_owner'))->kullanim($this->bayi());
    }

    /** Kuryenin uygulamaya gireceği firma kodu — ekranda ipucu olarak gösterilir. */
    public function firmaKodu(): string
    {
        return $this->yetkili() ? (string) $this->bayi()->slug : '';
    }

    public function rolAdi(User $uye): string
    {
        return match ($uye->role) {
            UserRole::Patron => 'Hesap sahibi',
            UserRole::Operator => 'Tezgâh',
            UserRole::Kurye => 'Kurye',
        };
    }

    /** Bu satır bu ekrandan yönetilebilir mi? (TeamController::HEDEF_ROLLER ile aynı kural.) */
    public function yonetilebilir(User $uye): bool
    {
        return $this->yetkili() && $uye->role !== UserRole::Patron;
    }

    // ── Eylemler ─────────────────────────────────────────────────────────────

    public function formAc(): void
    {
        if (! $this->yetkili()) {
            return;
        }

        $this->form->temizle();
        $this->resetValidation();
        $this->formAcik = true;
    }

    public function formKapat(): void
    {
        $this->formAcik = false;
        $this->form->temizle();
        $this->resetValidation();
    }

    /**
     * Kurye hesabı açar.
     *
     * KOTA İKİ KEZ SORULUR ve bu bilinçli: burada, kullanıcıya form doldurtmadan söyleyebilmek
     * için; bir kez daha `Provisioning::createCourier`ın içinde, çünkü kotayı hesabı YARATAN
     * yolun kendisi zorlamazsa yarın açılacak ikinci bir yol kapıyı atlar. İkisi de AYNI
     * `KuryeKotasi` sınıfına sorar — iki ayrı kural değil, tek kuralın iki çağrısıdır.
     */
    public function kuryeEkle(): void
    {
        if (! $this->yetkili()) {
            return;
        }

        // ABONELİK KİLİDİ: süresi dolmuş bayi bu siteye GİREBİLİR (ödeme yapmak için — Login'in
        // API'den bilinçli farkı), ama yazamaz. Aktiflik değişimi bu kapıyı `SyncService::push`ten
        // bedava alır ('locked'); hesap AÇMA ise provizyon yolundan gider ve orada kilit kontrolü
        // YOKTUR (panel/destek bilerek muaftır). Bu yüzden kapı burada, açıkça duruyor.
        if ($this->yazmaKilitli()) {
            $this->addError('form.kota', 'Aboneliğiniz sona erdiği için yeni hesap açılamıyor. '
                .'Aboneliğinizi yenilediğinizde ekip yönetimi aynen geri gelir.');

            return;
        }

        // Kota kapısı `Provisioning::createCourier`ın İÇİNDE de var (asıl zorlayan orasıdır);
        // buradaki kopya değil ÖNCELİK meselesi: kota doluyken kullanıcıya önce alan hatalarını
        // düzelttirip sonra "zaten hakkın yok" demek, boşuna doldurulmuş bir form demektir.
        if ($this->kota()['kalan'] <= 0) {
            $this->kotaHatasi();

            return;
        }

        try {
            $kurye = $this->form->olustur($this->bayi());
        } catch (KotaDoluException) {
            // Kota yarışı: form doldurulurken başka bir yüzeyden (panel/mobil) kurye açılmış
            // olabilir. Kapı INSERT'ten ÖNCE koşar, yani kullanıcı yaratılmadı.
            $this->kotaHatasi();

            return;
        }

        $this->formAcik = false;
        $this->form->temizle();
        unset($this->ekip);

        // KVKK / kırmızı çizgi #4: parola ve kullanıcı adı loga YAZILMAZ (TeamController ile
        // aynı sözleşme) — yalnız "kim, kime, ne" izlenebilsin diye kimlikler. ROL de yazılır:
        // iki tür hesap açılabildiği andan itibaren "ne açıldı" sorusu logdan cevaplanabilmeli.
        Log::info('Web panelinden personel hesabi acildi', [
            'tenant_id' => $this->bayiId,
            'actor_id' => $this->patronId,
            'target_id' => $kurye->id,
            'role' => $kurye->role->value,
        ]);

        /*
         * GİRİŞ BİLGİLERİ PATRONA POSTALANIR (2026-08-12).
         *
         * ALICI KURYE DEĞİL: kurye hesabının e-postası SAHTEDİR — `Provisioning::createCourier`
         * onu `<kullanıcı>@<firma-kodu>.sipario.local` diye türetir ve o adrese gönderilen posta
         * hiçbir yere ulaşmaz. Bilgiyi kuryeye ulaştıracak olan patrondur.
         *
         * NEDEN GEREKLİ: firma kodu + kullanıcı adı ikilisi bu ekranda bir kez görünüp kaybolur,
         * ama mobil giriş TAM OLARAK o ikiliyi ister (e-posta kabul etmez). Patron formu
         * kapattıktan sonra kuryesine ne söyleyeceğini hatırlamak zorunda kalıyordu.
         *
         * PAROLA POSTAYA YAZILMAZ — patron onu zaten kendisi belirledi; kopyalamak bilgi
         * eklemez, yalnız posta kutusunu ele geçirene hazır bir hesap verir.
         */
        BayiPostacisi::postala(
            (string) Auth::guard('web')->user()?->email,
            (string) Auth::guard('web')->user()?->name,
            new KuryeHesabiAcildi(
                isletme: (string) $this->bayi()->name,
                kuryeAdi: (string) $kurye->name,
                kullaniciAdi: (string) $kurye->username,
                firmaKodu: (string) $this->bayi()->slug,
                kalanHak: max(0, $this->kota()['kalan']),
                hesapUrl: route('site.hesap'),
                // Görev postada da yazar: iki tür hesap açılabildiği andan itibaren "kime ne
                // açtım" sorusunun cevabı, formu kapattıktan sonra yalnız bu iletide kalıyor.
                rolAdi: $this->rolAdi($kurye),
            ),
        );

        $this->dispatch('bildir', detail: $kurye->name.' için '.$this->rolAdi($kurye).' hesabı açıldı');
    }

    /** Onay kutusunu açar/kapatır (aktiflik değişimi geri alınması güç bir eylemdir). */
    public function onayIste(string $userId): void
    {
        $this->onay = $this->onay === $userId ? '' : $userId;
    }

    /**
     * Kuryeyi/operatörü devre dışı bırakır ya da geri açar. SİLMEZ (bkz. sınıf başlığı).
     *
     * Hedef RLS bağlamında aranır: başka bayinin kullanıcısı BULUNAMAZ — buradaki sessiz çıkış
     * yalnız kod filtresinin ikinci kilididir, birincisi veritabanı politikasıdır.
     */
    public function durumDegistir(string $userId): void
    {
        if (! $this->yetkili()) {
            return;
        }

        $hedef = $this->isVerisinde(fn (): ?User => User::query()
            ->where('tenant_id', $this->bayiId)->find($userId));

        if ($hedef === null || $hedef->role === UserRole::Patron) {
            // Patron kendini kilitlerse kurtarma yolu yalnız BİZ oluruz (panel) — mobil kimlik
            // ucundaki (TeamController) kuralın aynısı.
            $this->onay = '';

            return;
        }

        $acilacak = $hedef->status !== 'active';

        // GERİ AÇMA DA KOTAYA ÇARPAR: pasifleştirme kotayı serbest bırakır (KuryeKotasi yalnız
        // `active` sayar), dolayısıyla açma serbest olsaydı "birini kapat, ötekini aç" ile limit
        // sonsuza kadar aşılırdı.
        //
        // TEZGÂH DA KAPIYA TABİ (2026-08-20): kota artık patron dışındaki her aktif hesabı sayar.
        // Burada yalnız kuryeyi süzmek, kapatılan bir tezgâhın kotasız geri açılmasına — yani
        // limitin aynı yoldan aşılmasına — izin verirdi. `$hedef` zaten patron olamaz (yukarıda
        // erken dönüyor), o yüzden ek bir rol kontrolü gerekmiyor.
        if ($acilacak) {
            try {
                (new KuryeKotasi('pgsql_owner'))->bayiKontrolEt($this->bayiId);
            } catch (KotaDoluException) {
                $this->onay = '';
                $kota = $this->kota();
                $this->dispatch('bildir', detail: 'Personel hakkınız dolu ('.$kota['kullanilan'].'/'
                    .$kota['limit'].'); geri açmak için önce başka bir hesabı devre dışı bırakın');

                return;
            }
        }

        $durum = $this->aktifligiYaz($hedef, $acilacak ? 'active' : 'disabled');
        $this->onay = '';
        unset($this->ekip);

        if ($durum !== 'applied') {
            $this->dispatch('bildir', detail: match ($durum) {
                'locked' => 'Aboneliğiniz sona erdiği için ekip değişikliği kaydedilemedi',
                'stale' => 'Bu hesap daha yeni bir değişiklikle güncellenmiş; sayfayı tazeleyip tekrar deneyin',
                default => 'Değişiklik kaydedilemedi, tekrar deneyin',
            });

            return;
        }

        if (! $acilacak) {
            $this->oturumlariDusur($hedef->id);
        }

        Log::info('Web panelinden ekip aktifligi degisti', [
            'tenant_id' => $this->bayiId,
            'actor_id' => $this->patronId,
            'target_id' => $hedef->id,
            'aktif' => $acilacak,
        ]);

        $this->dispatch('bildir', detail: $hedef->name.($acilacak
            ? ' yeniden aktif edildi'
            : ' devre dışı bırakıldı; artık uygulamaya giremez'));
    }

    // ── Yazma yolu ───────────────────────────────────────────────────────────

    /**
     * Aktifliği MOBİLİN KULLANDIĞI YOLDAN yazar: RLS bağlamı → `SyncService::push` →
     * `ProfileChangeApplier`. Dönüş push'un tek olay sonucudur (applied|stale|locked|rejected).
     *
     * TAM PROFİL GÖNDERİLİR (ad + telefon + durum): `applyUserProfile` payload'da bulunmayan
     * anahtarı artık korur (sürüm çarpıklığı kapısı, 2026-08-05), yani eksik göndermek bugün
     * güvenlidir — ama o koruma İSTEMCİ SÜRÜMLERİ için konuldu, sunucu içi bir çağrının ona
     * yaslanması gereksiz bir bağımlılık olurdu. Değerler DB'den okunur, formdan değil.
     */
    private function aktifligiYaz(User $hedef, string $durum): string
    {
        $olay = [
            'client_event_id' => (string) Str::uuid7(),
            'entity_type' => 'user_profile',
            'op' => 'upsert',
            'occurred_at' => $this->damga($hedef),
            'device_id' => IsletmeFormu::SITE_DEVICE_ID,
            'payload' => [
                'id' => $hedef->id,
                'name' => $hedef->name,
                'phone' => $hedef->phone,
                'status' => $durum,
            ],
        ];

        return $this->isVerisinde(function () use ($olay): string {
            $aktor = User::query()->find($this->patronId);
            if ($aktor === null) {
                throw new RuntimeException('Hesap sahibi RLS bağlamında bulunamadı.');
            }

            $sonuc = (new SyncService)->push($aktor, [$olay]);

            return (string) ($sonuc['results'][0]['status'] ?? 'rejected');
        });
    }

    /**
     * LWW damgası — `IsletmeFormu::damga` ile aynı gerekçe, `users` satırı için.
     *
     * `updated_occurred_at` `timestamp(0)`dır (saniye çözünürlüğü) ve LWW eşitlikte `device_id`
     * karşılaştırmasına düşer; aynı saniyedeki İKİNCİ site yazması berabere kalıp 'stale' olur
     * ve sessizce kaybolurdu (patron kuryeyi kapatıp hemen açarsa: ikinci tıklama hiçbir şey
     * yapmaz). Damga yalnız SİTENİN KENDİ önceki damgasının üstüne çıkar — satırı en son bir
     * CİHAZ (ya da panel) yazdıysa dokunulmaz ve LWW doğal işini yapar; o zaman gerçekten daha
     * yeni olan yazım korunur ve kullanıcıya 'stale' söylenir. Koşulsuz ileri alma, sitenin
     * telefonun DAHA YENİ verisini sessizce ezmesi demekti.
     */
    private function damga(User $hedef): string
    {
        $damga = now()->startOfSecond();

        if ((string) $hedef->updated_device_id === IsletmeFormu::SITE_DEVICE_ID
            && $hedef->updated_occurred_at !== null
            && $hedef->updated_occurred_at->greaterThanOrEqualTo($damga)) {
            $damga = $hedef->updated_occurred_at->copy()->addSecond();
        }

        return $damga->toIso8601String();
    }

    /**
     * Pasifleştirilen kullanıcının AÇIK OTURUMLARINI düşürür.
     *
     * Bu, özelliğin varlık sebebinin yarısıdır: `AuthController` yalnız YENİ girişte
     * `status !== 'active'` bakar, elde duran Sanctum token'ını hiçbir middleware denetlemez.
     * Token silinmezse "devre dışı bıraktım" diyen patron, hâlâ sipariş kapatan bir kurye ile
     * karşılaşır. VERİ KAYBI YOK (kırmızı çizgi #3): cihazdaki bekleyen outbox kayıtları yerinde
     * durur; hesap geri açılıp yeniden girildiğinde sunucuya akar.
     *
     * Hata YUTULMAZ AMA EYLEMİ DÜŞÜRMEZ: aktiflik zaten yazıldı, geri alınamaz; token silme
     * başarısızsa bunu raporlamak, kullanıcıya "kaydedilmedi" demekten daha dürüsttür.
     */
    private function oturumlariDusur(string $userId): void
    {
        try {
            DB::connection('pgsql_owner')->table('personal_access_tokens')
                ->where('tokenable_type', User::class)
                ->where('tokenable_id', $userId)
                ->delete();
        } catch (Throwable $e) {
            report($e);
        }
    }

    // ── Yardımcılar ──────────────────────────────────────────────────────────

    private ?Tenant $bayiNesnesi = null;

    private function bayi(): Tenant
    {
        return $this->bayiNesnesi ??= Tenant::on('pgsql_owner')->findOrFail($this->bayiId);
    }

    /**
     * Bayinin YAZMA hakkı kapalı mı? Koşul `SyncService::resolveLock` ile birebir aynıdır:
     * durum locked/suspended/cancelled VEYA süre dolmuş. İki kaynak tek karar vermeli — kilidin
     * tanımı yüzeye göre değişirse "kilitli" kavramı anlamını kaybeder.
     */
    private function yazmaKilitli(): bool
    {
        $bayi = $this->bayi();

        return $bayi->status->writesLocked()
            || ($bayi->valid_until !== null && $bayi->valid_until->isPast());
    }

    private function kotaHatasi(): void
    {
        $kota = $this->kota();
        $this->addError('form.kota', 'Personel hakkınız dolu ('.$kota['kullanilan'].'/'.$kota['limit']
            .'). Yeni hesap açmak için ek kurye paketi alın ya da kullanılmayan bir hesabı devre dışı bırakın.');
    }

    /**
     * Bayinin İŞ VERİSİNDE koşar — RLS'li `pgsql`, kiracı bağlamı kurulmuş hâlde.
     * `Hesap::isVerisinde` ile birebir aynı gerekçe: bağlam BURADA kurulur, middleware'e bel
     * bağlanmaz (bileşen HTTP dışı bağlamlardan da çağrılabilir ve orada bağlamsız bir sorgu
     * politika gereği SIFIR satır döndürür — bu arıza SESSİZDİR).
     *
     * @template T
     *
     * @param  callable():T  $is
     * @return T
     */
    private function isVerisinde(callable $is): mixed
    {
        $onceki = DB::getDefaultConnection();
        DB::setDefaultConnection('pgsql');

        try {
            return DB::connection('pgsql')->transaction(function () use ($is) {
                DB::connection('pgsql')->statement(
                    "SELECT set_config('app.tenant_id', ?, true)", [$this->bayiId]
                );

                return $is();
            });
        } finally {
            DB::setDefaultConnection($onceki);
        }
    }
}
