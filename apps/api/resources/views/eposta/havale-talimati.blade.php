<x-eposta.duzen :onizleme="$onizleme" kulak="Havale / EFT bilgileri">

    <x-eposta.baslik>Ödeme bilgileriniz</x-eposta.baslik>

    <x-eposta.metin>
        Aşağıdaki hesaba havale ya da EFT yapabilirsiniz. Açıklama alanına referans kodunuzu
        yazarsanız ödemeniz otomatik eşleşir ve hesabınız aynı gün açılır.
    </x-eposta.metin>

    <x-eposta.tutar etiket="Ödenecek tutar">{{ $tutar }}</x-eposta.tutar>

    {{-- IBAN mono: karakter karakter okunacak. `word-break` bileşenin içinde — dar ekranda
         IBAN satırı taşmak yerine sarar, kesilmez. --}}
    <x-eposta.veri mono :satirlar="[
        'Alıcı ünvanı' => $unvan,
        'Banka' => $banka,
        'IBAN' => $iban,
        'Tutar' => $tutar,
    ]" />

    {{-- Referans kodu İKİNCİ KEZ, tek başına: yukarıdaki tabloda bir satır olarak kalsaydı
         açıklamaya yazılmadan havale yapılırdı ve ödeme elle eşleştirilene kadar hesap kapalı
         kalırdı. Bu postanın tek gerçek eylemi bu kodu doğru yere yazdırmaktır. --}}
    <x-eposta.kod etiket="Açıklamaya bunu yazın">{{ $referans }}</x-eposta.kod>

    <x-eposta.kutu tur="sari" etiket="Referans kodu olmadan:">
        ödemenizi elle eşleştirmemiz gerekir; bu da hesabınızın açılmasını geciktirir. Kodu
        açıklama alanına yazdığınızdan emin olun.
    </x-eposta.kutu>

    <x-eposta.metin>
        Havaleyi yaptıktan sonra hesap sayfanızdaki <strong>“Havale yaptım”</strong> düğmesine
        basmanız yeterli — dekont göndermenize gerek yok. Ödemeyi gördüğümüzde size ayrıca
        haber vereceğiz.
    </x-eposta.metin>

    <x-eposta.metin :son="true">
        Ödemeyle ilgili bir sorun olursa bu iletiyi yanıtlayın.
    </x-eposta.metin>

    <x-eposta.imza />

</x-eposta.duzen>
