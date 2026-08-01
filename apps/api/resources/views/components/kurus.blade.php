{{-- Kuruş → okunur TL. Para HER ZAMAN tamsayı kuruştur (DECISIONS); burada yalnız gösterilir. --}}
@props(['value' => 0])
<span {{ $attributes }}>{{ number_format(((int) $value) / 100, 2, ',', '.') }} ₺</span>
