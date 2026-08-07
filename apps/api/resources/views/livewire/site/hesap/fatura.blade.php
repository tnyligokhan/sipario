{{--
    Faturalar — tasarım HFatura, GERÇEK `subscription_payments` kayıtlarından.

    "İndir" DÜĞMESİ VE "Tümünü indir" YOK: fatura PDF'i HENÜZ ÜRETİLMİYOR (e-arşiv sağlayıcı
    entegrasyonu bekleyen dışsal iş). Tasarımdaki düğmeler bir toast basıp hiçbir dosya indirmiyordu;
    aynısını yapmak bayiye indirilecek bir belge olduğu hissini verirdi. Bölümün adı "Faturalar"
    kalıyor (gezinme sözleşmesi) ama içerik dürüstçe ÖDEME KAYITLARIdır.

    "Bekleyen bildirimler" panosu tasarımda YOK, eklendi: "Havale yaptım" diyen bayi beyanının bize
    ulaştığını görebilmeli — yoksa ekran bastığı düğmenin hiçbir izini göstermez.
--}}
<div class="hb">
    @php $bekleyenler = $this->bildirimler->where('status', \App\Models\PaymentNotification::STATUS_PENDING); @endphp

    @if ($bekleyenler->isNotEmpty())
        <x-site.pano etiket="Bekleyen ödeme bildirimleri">
            <x-slot:sag><x-site.rozet tur="sari" :nokta="true">{{ $bekleyenler->count() }} bekliyor</x-site.rozet></x-slot:sag>
            <div class="ab-satirlar">
                @foreach ($bekleyenler as $bildirim)
                    <div class="ozet-r">
                        <span>{{ $this->tarih($bildirim->declared_on) }} · {{ $this->yontemAdi($bildirim->method) }} · {{ $bildirim->reference_code }}</span>
                        <b class="tab">{{ $this->tl($bildirim->amount_kurus) }}</b>
                    </div>
                @endforeach
            </div>
            <hr class="ayrac">
            <p class="kucuk">Bildirim bir beyandır ve aboneliği kendiliğinden uzatmaz. Ödemeyi banka ekstresinde gördüğümüz gün eşleştirilir ve dönem o zaman uzar.</p>
        </x-site.pano>
    @endif

    <x-site.pano etiket="Ödeme geçmişi" :ic="false">
        @if ($this->odemeler->isEmpty())
            <div class="hb-bos">
                <span class="hb-bos-ik"><x-site.ikon ad="belge" boy="22" kalin="1.9" renk="var(--sonuk)" /></span>
                <b class="h4">Henüz fatura yok</b>
                <p class="kucuk">Deneme sürümü ücretsiz olduğu için fatura kesilmez. İlk faturanız aboneliği başlattığınızda, ilk tahsilat gününde oluşur.</p>
            </div>
        @else
            <div class="tbl-sar">
                <table class="tbl">
                    <thead>
                        <tr><th>Kalem</th><th>Tarih</th><th>Yöntem</th><th class="sag">Tutar</th><th class="sag">Durum</th></tr>
                    </thead>
                    <tbody>
                        @foreach ($this->odemeler as $odeme)
                            <tr>
                                <td><b>{{ $this->kalemAdi($odeme) }}</b></td>
                                <td class="tab">{{ $this->tarih($odeme->occurred_at) }}</td>
                                <td class="kucuk">{{ $this->yontemAdi($odeme->provider) }}</td>
                                <td class="sag tab"><b>{{ $this->tl($odeme->amount_kurus) }}</b></td>
                                <td class="sag"><x-site.rozet tur="yesil">Ödendi</x-site.rozet></td>
                            </tr>
                        @endforeach
                    </tbody>
                </table>
            </div>
        @endif
    </x-site.pano>

    <x-site.kutu tur="mor" ikon="bilgi">
        Fatura belgeleri şu an panelden düzenlenip e-posta ile gönderiliyor; buradan indirilebilir bir
        PDF henüz yok. Unvan, VKN ve adres bilgilerinizi <b>İşletme bilgileri</b> bölümünden girin —
        düzeltme sonraki faturaya yansır.
    </x-site.kutu>
</div>
