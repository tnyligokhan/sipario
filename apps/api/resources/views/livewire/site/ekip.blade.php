{{--
    EKİP bölümü — bayinin web hesap panelinde kurye hesabı açma / devre dışı bırakma.

    "SİL" DÜĞMESİ YOK VE BU BİR EKSİK DEĞİL. Kuryeye referans veren para kolonlarının hiçbirinde
    yabancı anahtar yoktur (orders.assigned_user_id, ledger_entries.collected_by_user_id,
    cash_handovers.*, day_closings.user_id): gerçek bir DELETE veritabanı tarafından engellenmez,
    sessizce sahipsiz para kayıtları bırakırdı (kırmızı çizgi #2). Düğme yaptığı işi söyler —
    "Devre dışı bırak" — ve kutu neden silinemediğini açıkça yazar. İşini yapamayacak bir düğme
    koymak yerine nedenini söylemek, mobildeki Kuryeler ekranının da izlediği yoldur.

    YENİ CSS SINIFI YOK: pano/tablo/rozet/kutu/alan bileşenleri ve mevcut `dg` düğme sınıfları
    kullanılıyor. Alpine ifadesi de YOK — onay kutusu Livewire durumuyla çizilir (csp_safe
    altında öznitelik içi ifade en ince tuzaktır; burada hiç ihtiyaç duyulmadı).
--}}
@php
    $kota = $this->kota();
    $kotaDolu = $kota['kalan'] <= 0;
@endphp

<div class="hb">
    @if (! $this->yetkili())
        <x-site.kutu tur="sari" ikon="kilit">
            Ekip yönetimi yalnız hesap sahibine açıktır. Kurye hesabı açmak için hesap sahibinin
            e-postasıyla giriş yapın.
        </x-site.kutu>
    @else
        <x-site.pano etiket="Ekibiniz" :ic="false">
            <x-slot:sag>
                <x-site.rozet :tur="$kotaDolu ? 'sari' : 'notr'">
                    {{ $kota['kullanilan'] }} / {{ $kota['limit'] }} kurye
                </x-site.rozet>
            </x-slot:sag>

            <div class="tbl-sar">
                <table class="tbl">
                    <thead>
                        <tr><th>Ad</th><th>Giriş adı</th><th>Rol</th><th>Durum</th><th class="sag">İşlem</th></tr>
                    </thead>
                    <tbody>
                        @foreach ($this->ekip as $uye)
                            <tr wire:key="uye-{{ $uye->id }}">
                                <td>
                                    <b>{{ $uye->name }}</b>
                                    @if ($uye->phone)<span class="kucuk"><br>{{ $uye->phone }}</span>@endif
                                </td>
                                <td class="tab">{{ $uye->username ?: '—' }}</td>
                                <td class="kucuk">{{ $this->rolAdi($uye) }}</td>
                                <td>
                                    @if ($uye->status === 'active')
                                        <x-site.rozet tur="yesil">Aktif</x-site.rozet>
                                    @else
                                        <x-site.rozet tur="notr">Devre dışı</x-site.rozet>
                                    @endif
                                </td>
                                <td class="sag">
                                    @if ($this->yonetilebilir($uye))
                                        <button type="button" class="dg dg-c gk"
                                            wire:click="onayIste('{{ $uye->id }}')">
                                            {{ $uye->status === 'active' ? 'Devre dışı bırak' : 'Yeniden aç' }}
                                        </button>
                                    @else
                                        <span class="kucuk">—</span>
                                    @endif
                                </td>
                            </tr>
                        @endforeach
                    </tbody>
                </table>
            </div>
        </x-site.pano>

        {{-- Onay — aynı anda yalnız bir satır için açıktır, bu yüzden tablonun ALTINDA durur. --}}
        @php $onaylanan = $this->ekip->firstWhere('id', $onay); @endphp
        @if ($onaylanan)
            <x-site.pano :etiket="$onaylanan->status === 'active' ? 'Devre dışı bırak' : 'Yeniden aç'">
                @if ($onaylanan->status === 'active')
                    <x-site.kutu tur="sari" ikon="uyari">
                        <b>{{ $onaylanan->name }}</b> uygulamaya bir daha giremez ve açık oturumu
                        hemen kapanır. Hesap <b>silinmez</b>: geçmiş siparişleri ve tahsilatları bu
                        kişiye bağlı olduğu için adı defterde okunur kalır. Dilediğiniz zaman
                        yeniden açabilirsiniz.
                    </x-site.kutu>
                @else
                    <x-site.kutu tur="mor" ikon="bilgi">
                        <b>{{ $onaylanan->name }}</b> mevcut kullanıcı adı ve parolasıyla yeniden
                        giriş yapabilir. Kurye hesabı açılınca kurye hakkınızdan bir adet kullanılır.
                    </x-site.kutu>
                @endif

                <hr class="ayrac">
                <div class="dg-grup">
                    <button type="button" class="dg dg-c k" wire:click="onayIste('{{ $onaylanan->id }}')">Vazgeç</button>
                    {{-- Devre dışı bırakma yıkıcı bir eylemdir: kırmızı varyant (dg-t). Geri açma
                         olağan bir eylemdir: mor birincil (dg-a). --}}
                    <button type="button" class="dg k {{ $onaylanan->status === 'active' ? 'dg-t' : 'dg-a' }}"
                        wire:click="durumDegistir('{{ $onaylanan->id }}')">
                        {{ $onaylanan->status === 'active' ? 'Devre dışı bırak' : 'Yeniden aç' }}
                    </button>
                </div>
            </x-site.pano>
        @endif

        {{-- Kurye ekleme --}}
        @error('form.kota')<x-site.kutu tur="sari" ikon="uyari">{{ $message }}</x-site.kutu>@enderror

        @if ($formAcik)
            <form wire:submit="kuryeEkle">
                <x-site.pano etiket="Yeni kurye hesabı">
                    <x-site.alan etiket="Kuryenin adı" :hata="$errors->first('form.ad')" id="k-ad">
                        <input id="k-ad" class="gir @error('form.ad') yanlis @enderror" wire:model="form.ad">
                    </x-site.alan>

                    <div class="alan-ikili">
                        <x-site.alan etiket="Giriş için kullanıcı adı" :hata="$errors->first('form.kullaniciAdi')" id="k-ku"
                            ipucu="Kurye uygulamaya firma kodu ({{ $this->firmaKodu() }}) ve bu adla girer.">
                            <input id="k-ku" class="gir @error('form.kullaniciAdi') yanlis @enderror"
                                autocapitalize="none" wire:model="form.kullaniciAdi">
                        </x-site.alan>
                        <x-site.alan etiket="Parola" :hata="$errors->first('form.parola')" id="k-pa">
                            <input id="k-pa" class="gir @error('form.parola') yanlis @enderror"
                                type="text" autocomplete="off" wire:model="form.parola">
                        </x-site.alan>
                    </div>

                    <x-site.alan etiket="Telefon" not="isteğe bağlı" :hata="$errors->first('form.telefon')" id="k-te">
                        <input id="k-te" class="gir" type="tel" inputmode="tel" wire:model="form.telefon">
                    </x-site.alan>

                    {{-- Parola ekranda AÇIK yazılır ve bu bilinçli: patron onu kuryesine söyleyecek.
                         Kaydedildikten sonra bir daha HİÇBİR yerde okunamaz (bcrypt) — bu yüzden
                         uyarı burada duruyor. --}}
                    <x-site.kutu tur="mor" ikon="bilgi">
                        Parolayı kuryenize siz ileteceksiniz; kaydettikten sonra bir daha
                        gösterilmez. Unutulursa buradan değil, uygulamadaki Kuryeler ekranından
                        yenisini belirleyebilirsiniz.
                    </x-site.kutu>

                    <hr class="ayrac">
                    <div class="dg-grup">
                        <button type="button" class="dg dg-c k" wire:click="formKapat">Vazgeç</button>
                        <button type="submit" class="dg dg-a k">Hesabı aç</button>
                    </div>
                </x-site.pano>
            </form>
        @elseif ($kotaDolu)
            {{-- FİYAT IZGARASI BİLEREK BURADA DEĞİL: ek kurye paketi satışı "Kullanım ve ek
                 paketler" bölümünde tek yerde duruyor (hesap ajanıyla kararlaştırıldı) — katalogu
                 iki ekranda çizmek, fiyat/kampanya değiştiğinde ikisinin ayrışacağı demekti.
                 Burada kalan KOTA bilgisi fazlalık değil: düğmenin neden kapalı olduğunu
                 açıklayan tek şey odur. --}}
            <x-site.pano etiket="Kurye hakkı">
                <x-site.kutu tur="sari" ikon="uyari">
                    {{ $kota['limit'] }} kurye hakkınızın tamamı kullanımda. Yeni bir hesap açmak
                    için kullanılmayan bir kuryeyi devre dışı bırakın ya da ek kurye paketi alın.
                </x-site.kutu>
                <hr class="ayrac">
                <a class="dg dg-c k" href="{{ route('site.hesap', ['bolum' => 'hak']) }}">Ek kurye paketi al</a>
            </x-site.pano>
        @else
            <x-site.pano etiket="Kurye hesabı">
                <p class="gvd">
                    Kuryeniz uygulamaya kendi hesabıyla girer; kendisine atanan siparişleri görür ve
                    teslim ettikçe kapatır. {{ $kota['kalan'] }} kurye hakkınız kaldı.
                </p>
                <hr class="ayrac">
                <button type="button" class="dg dg-a k" wire:click="formAc">Kurye hesabı aç</button>
            </x-site.pano>
        @endif
    @endif
</div>
