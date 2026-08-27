<?php

namespace App\Livewire\Panel;

use App\Abonelik\PlanDeposu;
use App\Eposta\BayiPostacisi;
use App\Livewire\Panel\Forms\UyeForm;
use App\Mail\Hosgeldiniz;
use App\Models\Tenant;
use App\Models\User;
use App\Panel\TenantAdminService;
use App\Payment\DuplicateEmailException;
use App\Support\DuplicateSlugException;
use App\Support\TurkceArama;
use Illuminate\Contracts\Pagination\LengthAwarePaginator;
use Illuminate\Database\Query\Builder;
use Illuminate\Support\Facades\Auth;
use Illuminate\Support\Facades\DB;
use InvalidArgumentException;
use Livewire\Attributes\Layout;
use Livewire\Attributes\Title;
use Livewire\Attributes\Url;
use Livewire\Component;
use Livewire\WithPagination;

/**
 * ÜYELER (tasarım `07-Uyeler.jsx` · Uyeler) — arama + durum çipleri + sayfalı tablo; sağ üstte
 * **Yeni Üye** (elle bayi açma). Her satır bayi detayına götürür.
 *
 * LİSTE OKUR, TEK BİR YAZMA YÜZEYİ VARDIR: yeni bayi açmak. Bu ekran 2026-08-27'ye kadar tamamen
 * salt-okunurdu ve BRIEF md. 3'ün ilk maddesi ("gerektiğinde elle açma — siteden kaydolmayan,
 * birebir satışla kazanılan bayiler için") panelde HİÇ karşılığı olmayan tek yetenekti: servis
 * (`TenantAdminService::createTenant`) ve konsol komutu (`sipario:tenant`) baştan beri vardı, ama
 * satışta olan kişi sunucuya SSH ile giremez. Bayi açmak listeye ait bir eylemdir — detay ekranı
 * henüz OLMAYAN bir bayi için açılamaz.
 *
 * YAZMA YOLU LİSTENİNKİNDEN AYRIDIR: liste `pgsql_panel` (BYPASSRLS, SELECT-only) ile okur; bayi
 * açmak `tenants`a INSERT ister ve panel rolünün böyle bir izni YOKTUR (bilinçli) — servis owner
 * bağlantısına geçer. Yani bu düğme panel rolünün iznini genişletmez.
 *
 * Sorgu `TenantAdminService::tenants()` yerine burada: o metot SAYFALAMASIZ bütün bayileri döndürür
 * ve ekranın üç süzgeci (arama · durum · sayfa) yok. Bütün listeyi çekip PHP'de süzmek, bayi sayısı
 * büyüdükçe her tuşa basışta tüm tabloyu ağdan geçirirdi.
 */
#[Layout('components.layouts.panel')]
#[Title('Üyeler')]
class TenantList extends Component
{
    use WithPagination;

    /**
     * Durum çipleri. İlk beşi tasarımın listesidir ve SIRASI KORUNUR; `locked` sunucunun beşinci
     * durumudur (tasarımda yoktu) ve sona eklendi — araya sokmak tasarımın çip sırasını bozardı.
     */
    public const DURUMLAR = [
        'tumu' => 'Tümü',
        'trial' => 'Deneme',
        'active' => 'Aktif',
        'suspended' => 'Askıda',
        'cancelled' => 'İptal',
        'locked' => 'Süresi doldu',
    ];

    private const BAGLANTI = 'pgsql_panel';

    private const SAYFA_BOYU = 20;

    /**
     * ARAMA UZUNLUK TAVANI. Alan bir metin süzgecidir ve hiçbir zaman sayısal kolonla
     * KARŞILAŞTIRILMAZ (yalnız LIKE) — yapıştırılan 15 haneli bir telefon bu yüzden int taşırmaz.
     * Tavan ayrı bir dert içindir: sınırsız uzunlukta bir desen boşuna tam tablo taraması üretir.
     */
    private const ARAMA_TAVANI = 120;

    #[Url(as: 'ara', except: '')]
    public string $arama = '';

    #[Url(as: 'durum', except: 'tumu')]
    public string $durum = 'tumu';

    // --- Yeni üye (elle bayi açma) -------------------------------------------------------

    public UyeForm $uyeForm;

    public bool $uyeAcik = false;

    /**
     * Açılan bayinin KURULUM BİLGİSİ — modal kapandıktan sonra listenin üstünde durur.
     *
     * Neden ekranda kalıyor: operatör bu üç şeyi (firma kodu · kullanıcı adı · parola) telefondaki
     * bayiye okuyacak. Modal kapanınca kaybolsaydı, kodu görmek için yeni açılan bayinin detayına
     * gidip parolayı sıfırlamak gerekirdi — yani hemen az önce kurulan hesap bozulurdu.
     *
     * @var array{isletme: string, kod: string, kullanici: string, parola: string, bitis: string, posta: ?string}|null
     */
    public ?array $acilan = null;

    /** null = henüz bakılmadı. Bkz. trSiralama(). */
    private ?bool $icuVar = null;

    public function updatedArama(): void
    {
        $this->resetPage('sayfa');
    }

    public function updatedDurum(): void
    {
        $this->resetPage('sayfa');
    }

    /**
     * İşletme adı yazıldığında firma kodu ÖNERİLİR (yalnız kod boşsa — operatörün yazdığı kod
     * asla ezilmez), kod alanına yazıldığında biçime indirilir.
     *
     * Genel `updated()` kancası kullanılıyor: form nesnesinin alanları bileşene `uyeForm.isletme`
     * adıyla ulaşır ve alan-başına kanca adları (`updatedUyeFormIsletme`) formun alan adı
     * değiştiğinde SESSİZCE ölürdü — bu dosyadaki eşleşme en azından bir yerde tek satırda görünür.
     */
    public function updated(string $ad): void
    {
        if ($ad === 'uyeForm.isletme') {
            $this->uyeForm->kodOner();

            return;
        }

        if ($ad === 'uyeForm.kod') {
            // Operatör "Aslan Su" yapıştırdığında alan sessizce geçersiz kalmasın: DB CHECK'inin
            // kabul ettiği alfabeye indirilir (küçük harf + rakam + tire). Kalan biçim hatasını
            // (örn. 2 karakter) doğrulama söyler.
            $this->uyeForm->kod = mb_substr(
                (string) preg_replace('/[^a-z0-9-]/', '', mb_strtolower(trim($this->uyeForm->kod))),
                0, 80,
            );
        }
    }

    public function uyeAc(): void
    {
        $this->superadminZorunlu();
        $this->uyeForm->reset();
        $this->resetErrorBag();
        $this->acilan = null;
        $this->uyeAcik = true;
    }

    public function uyeKapat(): void
    {
        $this->uyeAcik = false;
    }

    /**
     * Bayiyi aç. Kayıt tek transaction'dadır (`Provisioning`) — buradan yarım bir bayi çıkmaz.
     *
     * Hoş geldiniz postası kaydı DÜŞÜRMEZ: `BayiPostacisi::postala` istisnayı yutup raporlar.
     * Bir SMTP arızası yüzünden yeni açılmış bayiyi geri almak, çözdüğünden çok sorun yaratırdı —
     * hesap zaten yazıldı ve kurulum bilgisi ekranda duruyor. (Siteden kayıt akışının aynısı.)
     */
    public function uyeKaydet(): void
    {
        $this->superadminZorunlu();

        $this->uyeForm->normalize();
        $this->uyeForm->validate();

        try {
            $sonuc = app(TenantAdminService::class)->createTenant(
                name: $this->uyeForm->isletme,
                email: $this->uyeForm->eposta,
                password: $this->uyeForm->parola,
                adminId: $this->adminId(),
                slug: $this->uyeForm->kod,
                yetkili: $this->uyeForm->yetkili,
                telefon: $this->uyeForm->telefonVeya(),
            );
        } catch (DuplicateEmailException $e) {
            $this->addError('uyeForm.eposta', $e->getMessage());

            return;
        } catch (DuplicateSlugException|InvalidArgumentException $e) {
            $this->addError('uyeForm.kod', $e->getMessage());

            return;
        }

        /** @var Tenant $tenant */
        $tenant = $sonuc['tenant'];
        /** @var User $patron */
        $patron = $sonuc['patron'];

        $posta = $this->uyeForm->posta ? $patron->email : null;
        if ($posta !== null) {
            BayiPostacisi::postala($patron->email, $patron->name, new Hosgeldiniz(
                isletme: $tenant->name,
                yetkili: $patron->name,
                firmaKodu: $tenant->slug,
                kullaniciAdi: $patron->username,
                denemeBitisi: $tenant->trial_ends_at?->translatedFormat('j F Y') ?? '',
                denemeGun: (new PlanDeposu('pgsql_owner'))->denemeGun(),
                hesapUrl: route('site.hesap'),
            ));
        }

        $this->acilan = [
            'isletme' => $tenant->name,
            'kod' => $tenant->slug,
            'kullanici' => $patron->username,
            // Parola operatörün kendi yazdığıdır; hesap kurulurken okunacağı için ekranda tutulur
            // ve BURADA BİTER — hiçbir yere kaydedilmez, denetim günlüğüne yazılmaz (KVKK-nötr).
            'parola' => $this->uyeForm->parola,
            'bitis' => $tenant->trial_ends_at?->translatedFormat('j F Y') ?? '—',
            'posta' => $posta,
        ];

        $this->uyeAcik = false;
        $this->uyeForm->reset();
        $this->resetPage('sayfa');
        $this->dispatch('tost', mesaj: $tenant->name.' açıldı');
    }

    /** Kurulum bilgisi bandını kapat (operatör bilgileri iletti). */
    public function acilanKapat(): void
    {
        $this->acilan = null;
    }

    public function superadminMi(): bool
    {
        return Auth::guard('admin')->user()?->isSuperadmin() === true;
    }

    public function render(): mixed
    {
        // URL'den elle uydurulmuş bir durum sessizce boş liste üretmesin: bilinmeyen değer 'tumu'ya düşer.
        if (! array_key_exists($this->durum, self::DURUMLAR)) {
            $this->durum = 'tumu';
        }

        return view('livewire.panel.tenant-list', [
            'uyeler' => $this->sorgu(),
            'toplam' => DB::connection(self::BAGLANTI)->table('tenants')->count(),
            'durumlar' => self::DURUMLAR,
            'superadmin' => $this->superadminMi(),
        ]);
    }

    /**
     * Bayi açmak HESAP YÖNETİMİDİR → superadmin. Destek rolü panelde görüntüler ve bayinin iş
     * verisini girer; hesap/abonelik hattına dokunmaz (`TenantDetail`in çizgisiyle aynı).
     *
     * Yetki reddi İZ BIRAKIR: 403 sessizse "kim neyi denedi" görünmez olur. Düğmeyi gizlemek
     * yetki denetimi değildir — eylem isteği doğrudan da gönderilebilir, kapı burada.
     */
    private function superadminZorunlu(): void
    {
        if ($this->superadminMi()) {
            return;
        }

        app(TenantAdminService::class)->auditRed('create_tenant', null, 'yetkisiz', $this->adminId());
        abort(403);
    }

    private function adminId(): ?string
    {
        $id = Auth::guard('admin')->id();

        return $id !== null ? (string) $id : null;
    }

    /** @return LengthAwarePaginator<int, \stdClass> */
    private function sorgu(): LengthAwarePaginator
    {
        $q = DB::connection(self::BAGLANTI)->table('tenants as t')
            ->select(
                't.id', 't.name', 't.slug', 't.status', 't.phone',
                't.contact_name', 't.city', 't.district',
                't.trial_ends_at', 't.valid_until',
            )
            // SON ÖDEME alt sorguyla: bayi başına ayrı sorgu (N+1) yerine tek turda gelir. Yalnız
            // BAŞARILI ödemeler — 'initiated' satırı bir girişimdir, tarihi "son ödeme" değildir.
            ->selectSub(
                DB::connection(self::BAGLANTI)->table('subscription_payments')
                    ->selectRaw('max(occurred_at)')
                    ->whereColumn('subscription_payments.tenant_id', 't.id')
                    ->where('subscription_payments.status', 'success'),
                'son_odeme',
            );

        if ($this->durum !== 'tumu') {
            $q->where('t.status', $this->durum);
        }

        $this->aramayiUygula($q);

        return $q->orderByRaw($this->trSiralama())
            ->paginate(self::SAYFA_BOYU, ['*'], 'sayfa');
    }

    /**
     * Tasarımın araması firma adı + yetkili + il üzerinde çalışır; sunucuda karşılıkları
     * `name` / `contact_name` / `city`. Firma kodu (`slug`) da eklendi: destek telefonda çoğu zaman
     * bayiyi kodla söyler ve kod aranamıyorsa liste ekranı işe yaramaz.
     *
     * @param  Builder  $q
     */
    private function aramayiUygula($q): void
    {
        $arama = trim(mb_substr($this->arama, 0, self::ARAMA_TAVANI));
        if ($arama === '') {
            return;
        }

        // Katlama, joker kaçışı ve kaçış karakterinin seçimi TEK KAYNAKTAN: `App\Support\TurkceArama`.
        // Kural hem SQL (`translate`) hem PHP (`strtr`) tarafında yaşamak zorunda ve ikisi ayrışırsa
        // arama SESSİZCE boş döner — o yüzden burada kopyası tutulmaz.
        $desen = TurkceArama::desen($arama);

        $q->where(function ($alt) use ($desen) {
            // Kolon adları SABİT dizidir, kullanıcı girdisi değil — `sutun()` onu sorguya ham gömer.
            foreach (['t.name', 't.contact_name', 't.city', 't.slug'] as $kolon) {
                $alt->orWhereRaw(
                    TurkceArama::sutun($kolon)." LIKE ? ESCAPE '".TurkceArama::KACIS."'",
                    [$desen],
                );
            }
        });
    }

    /**
     * TÜRKÇE HARF SIRASI (tasarımdaki `localeCompare(ad, 'tr')`ın SQL karşılığı). Postgres'in
     * varsayılan sıralaması Türkçe'yi bilmez: "Çınar" C'lerin arasına değil Z'den sonraya düşer ve
     * "Işık" ile "İpek" yer değiştirir.
     *
     * ICU harmanlaması postgres:16 imajında vardır ama bir gün ICU'suz derlenmiş bir sunucuda
     * `42704` (undefined_object) verir ve LİSTE EKRANI TAMAMEN AÇILMAZ. Yanlış sıralama, açılmayan
     * ekrandan iyidir — varlığı bir kez sorulur, yoksa düz sıralamaya düşülür.
     */
    private function trSiralama(): string
    {
        if ($this->icuVar === null) {
            $this->icuVar = DB::connection(self::BAGLANTI)
                ->selectOne('select 1 from pg_collation where collname = ? limit 1', ['tr-TR-x-icu']) !== null;
        }

        return $this->icuVar ? 't.name COLLATE "tr-TR-x-icu" asc' : 't.name asc';
    }
}
