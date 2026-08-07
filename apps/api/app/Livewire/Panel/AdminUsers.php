<?php

namespace App\Livewire\Panel;

use App\Panel\PanelAdminService;
use Illuminate\Support\Facades\Auth;
use Livewire\Attributes\Layout;
use Livewire\Attributes\Title;
use Livewire\Attributes\Validate;
use Livewire\Component;
use RuntimeException;

/**
 * Panel hesapları ekranı (5c-3 · D5) — YALNIZ superadmin. Yetki kapısı hem `mount`ta (sayfa hiç
 * açılmasın) hem her eylemde (istek doğrudan gönderilebilir) uygulanır; yalnız düğmeyi gizlemek
 * yetki denetimi değildir.
 */
#[Layout('components.layouts.panel')]
#[Title('Panel Hesapları')]
class AdminUsers extends Component
{
    #[Validate('required|string|min:2|max:160')]
    public string $ad = '';

    #[Validate('required|email|max:190')]
    public string $email = '';

    #[Validate('required|in:superadmin,support')]
    public string $rol = 'support';

    /** Yeni hesabın parolası — BİR KEZ gösterilir, saklanmaz. */
    public ?string $yeniParola = null;

    /** @var array{tur: string, mesaj: string}|null */
    public ?array $bildirim = null;

    public function mount(): void
    {
        $this->superadminZorunlu();
    }

    public function ekle(): void
    {
        $this->superadminZorunlu();
        $this->validate();

        $this->calistir(function () {
            $sonuc = app(PanelAdminService::class)->ekle($this->ad, $this->email, $this->rol, $this->adminId());
            $this->yeniParola = $sonuc['parola'];
            $this->reset(['ad', 'email', 'rol']);
            $this->rol = 'support';

            return $sonuc['admin']->name.' eklendi.';
        });
    }

    public function aktiflik(string $id, bool $aktif): void
    {
        $this->superadminZorunlu();

        $this->calistir(function () use ($id, $aktif) {
            app(PanelAdminService::class)->aktiflik($id, $aktif, $this->adminId());

            return $aktif ? 'Hesap yeniden açıldı.' : 'Hesap pasifleştirildi.';
        });
    }

    public function rolDegistir(string $id, string $rol): void
    {
        $this->superadminZorunlu();

        $this->calistir(function () use ($id, $rol) {
            app(PanelAdminService::class)->rolDegistir($id, $rol, $this->adminId());

            return 'Rol güncellendi.';
        });
    }

    public function render(): mixed
    {
        return view('livewire.panel.admin-users', [
            'adminler' => app(PanelAdminService::class)->adminler(),
            'roller' => PanelAdminService::ROLLER,
            'benimId' => $this->adminId(),
        ]);
    }

    /** @param callable():string $is */
    private function calistir(callable $is): void
    {
        try {
            $this->bildirim = ['tur' => 'ok', 'mesaj' => $is()];
        } catch (RuntimeException $e) {
            $this->bildirim = ['tur' => 'hata', 'mesaj' => $e->getMessage()];
        }
    }

    private function superadminZorunlu(): void
    {
        abort_unless(Auth::guard('admin')->user()?->isSuperadmin() === true, 403);
    }

    private function adminId(): ?string
    {
        $id = Auth::guard('admin')->id();

        return $id !== null ? (string) $id : null;
    }
}
