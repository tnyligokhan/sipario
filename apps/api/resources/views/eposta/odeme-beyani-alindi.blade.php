<x-eposta.duzen :onizleme="$onizleme" kulak="Ödeme bildirimi">

    <x-eposta.baslik>Bildiriminizi aldık</x-eposta.baslik>

    <x-eposta.metin>
        {{ $isletme }} için ödeme bildiriminiz bize ulaştı. Şu an muhasebe kontrolünde.
    </x-eposta.metin>

    <x-eposta.veri :satirlar="[
        'Bildirim tarihi' => $beyanTarihi,
        'Yöntem' => $yontemAdi,
        'Tutar' => $tutar,
        'Referans' => $referans,
    ]" />

    {{-- DÜRÜSTLÜK KAPISI: beyan aboneliği uzatmaz. Bunu yazmazsak bayi hesabının açıldığını
         sanır, uygulamada kilidi görür ve bize "para gönderdim ama çalışmıyor" diye döner. --}}
    <x-eposta.kutu tur="sari" etiket="Hesabınız henüz açılmadı.">
        Bildiriminiz bir beyandır; ödemeyi banka hesabımızda gördüğümüzde hesabınız açılır ve
        size ayrıca haber veririz. Bu sırada tekrar ödeme yapmanıza gerek yok.
    </x-eposta.kutu>

    <x-eposta.metin>
        Havaleler genelde aynı iş günü içinde görünür. Hafta sonu ya da resmi tatil araya
        girerse ilk iş gününü bulabilir.
    </x-eposta.metin>

    <x-eposta.metin :son="true">
        Bir yanlışlık olduğunu düşünüyorsanız bu iletiyi yanıtlayın — bildiriminizi birlikte
        kontrol edelim.
    </x-eposta.metin>

    <x-eposta.imza />

</x-eposta.duzen>
