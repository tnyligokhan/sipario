{{--
    Telefon — Sipario mobil uygulamasının gerçek ölçekli statik maketi (412×892, CSS ile ölçeklenir).
    Kaynak: design_handoff_web_and_yonetim_paneli/_kaynak/web/07-sw-telefon.jsx — SAF SUNUM, gerçek
    veriye bağlanmaz; içerik tasarımdaki örnek verinin birebir kopyasıdır.

    ekran: ana | cagri | musteri | siparis | kurye | gunsonu
    cagri (bool): true ise seçili ekranın ÜSTÜNE gelen çağrı kartı biner (kaynaktaki gibi bağımsız).
--}}
@props(['ekran' => 'ana', 'oran' => 0.72, 'cagri' => false, 'bildirim' => null,
    'ciro' => '12.480', 'acik' => 7, 'isletme' => 'Merkez Şube'])
@php
    $nav = [['k' => 'ana', 'ik' => 'ev', 'ad' => 'Ana'], ['k' => 'mus', 'ik' => 'musteriler', 'ad' => 'Müşteri'],
        ['k' => 'sip', 'ik' => 'liste', 'ad' => 'Sipariş'], ['k' => 'urn', 'ik' => 'kutu', 'ad' => 'Ürün']];
    $navAktif = ['ana' => 'ana', 'musteri' => 'mus', 'siparis' => 'sip', 'kurye' => 'sip', 'gunsonu' => 'ana'][$ekran] ?? 'ana';
@endphp
<div class="t-cerceve" style="--s:{{ $oran }}">
    <div class="t-ekranlik">
        <div class="t-ic">
            @switch($ekran)
                @case('musteri')
                    <div class="t-ekran">
                        <div class="t-sys"><span>09:41</span><span class="t-sys-sag"><x-site.ikon ad="global" boy="13" kalin="2.2" /><x-site.ikon ad="simsek" boy="13" kalin="2.2" /><span class="t-pil"><i></i></span></span></div>
                        <div class="t-ust">
                            <span class="t-ust-ik"><x-site.ikon ad="sol" boy="19" kalin="2.2" /></span>
                            <span class="t-ust-m"><b>Ahmet Yılmaz</b><small>05xx xxx xx 08</small></span>
                            <span class="t-ust-ik"><x-site.ikon ad="duzenle" boy="17" kalin="2" /></span>
                        </div>
                        <div class="t-govde">
                            <div class="t-md-bal">
                                <span class="t-md-bal-l">AÇIK BORÇ</span>
                                <span class="t-md-bal-v tab">8.550,00 ₺</span>
                                <span class="t-md-bal-t">BORÇLU</span>
                                <span class="t-md-kupon"><x-site.ikon ad="saat" boy="13" kalin="2" renk="rgba(255,255,255,.7)" />Son ödeme 14 gün önce</span>
                            </div>
                            <div class="t-md-akt">
                                @foreach ([['elpara','Tahsilat'],['arti','Sipariş'],['telefon','Ara'],['konum','Adres']] as [$ik, $ad])
                                    <button type="button" class="t-mda"><x-site.ikon :ad="$ik" boy="19" kalin="2" renk="#5A45F0" /><span>{{ $ad }}</span></button>
                                @endforeach
                            </div>
                            <div class="t-bas">Defter</div>
                            <div class="t-defter">
                                @foreach ([['borc','Karışık pide ×2 · ayran ×2','Bugün 12:24','+430,00 ₺','veresiye'],['odeme','Tahsilat · nakit','Dün 18:02','−250,00 ₺',null],['borc','Kahvaltı tabağı ×3','12 Tem 09:15','+780,00 ₺','veresiye'],['borc','Öğle menüsü ×2','8 Tem 13:40','+320,00 ₺','veresiye']] as [$tur, $ad, $tar, $tut, $etk])
                                    <div class="t-dh">
                                        <span class="t-dh-ic" style="background:{{ $tur === 'odeme' ? '#E3F4EC' : '#FCE9EA' }}"><x-site.ikon :ad="$tur === 'odeme' ? 'okYukari' : 'ok'" boy="14" kalin="2.4" :renk="$tur === 'odeme' ? '#1E9E6A' : '#DF3F45'" /></span>
                                        <span class="t-dh-m"><b>{{ $ad }}@if($etk)<em>{{ $etk }}</em>@endif</b><small>{{ $tar }}</small></span>
                                        <span class="t-dh-t tab" style="color:{{ $tur === 'odeme' ? '#1E9E6A' : '#17141F' }}">{{ $tut }}</span>
                                    </div>
                                @endforeach
                            </div>
                        </div>
                        <div class="t-nav"><div class="t-nav-g">@foreach($nav as $b)<button type="button" class="t-nav-b @if($b['k'] === $navAktif) on @endif"><x-site.ikon :ad="$b['ik']" boy="20" :kalin="$b['k'] === $navAktif ? 2.3 : 1.9" renk="#fff" /><span>{{ $b['ad'] }}</span></button>@endforeach</div><button type="button" class="t-fab"><x-site.ikon ad="arti" boy="23" kalin="2.4" renk="#fff" /></button></div>
                    </div>
                    @break

                @case('siparis')
                    <div class="t-ekran">
                        <div class="t-sys"><span>09:41</span><span class="t-sys-sag"><x-site.ikon ad="global" boy="13" kalin="2.2" /><x-site.ikon ad="simsek" boy="13" kalin="2.2" /><span class="t-pil"><i></i></span></span></div>
                        <div class="t-ust">
                            <span class="t-ust-m tek"><b>Siparişler</b><small>7 açık · 12 teslim</small></span>
                            <span class="t-ust-ik"><x-site.ikon ad="filtre" boy="17" kalin="2" /></span>
                        </div>
                        <div class="t-seg">@foreach (['Açık','Teslim','İptal'] as $i => $x)<button type="button" class="t-seg-b @if($i === 0) on @endif">{{ $x }}</button>@endforeach</div>
                        <div class="t-govde">
                            <div class="t-sliste">
                                @foreach ([['k'=>'#1043','ad'=>'Ahmet Yılmaz','s'=>'10:24','u'=>['Karışık pide ×2 · ayran ×2'],'adr'=>'Şirinyalı Mah. 42. Sk. No:9','kur'=>'Kurye 1','tut'=>'90,00 ₺','not'=>'Zil çalışmıyor'],['k'=>'#1042','ad'=>'Hatice Demir','s'=>'10:02','u'=>['Öğle menüsü ×3','Çatal-bıçak koysun'],'adr'=>'Meltem Mah. 3. Cd. No:14/B','kur'=>'Ben','tut'=>'110,00 ₺','not'=>null]] as $s)
                                    <div class="t-srow">
                                        <div class="t-srow-h"><span class="t-srow-k">{{ $s['k'] }}</span><span class="t-srow-n">{{ $s['ad'] }}</span><span class="t-srow-s"><x-site.ikon ad="saat" boy="12" kalin="2.1" renk="#8B8794" />{{ $s['s'] }}</span></div>
                                        <div class="t-srow-u">@foreach($s['u'] as $u)<span><i></i>{{ $u }}</span>@endforeach</div>
                                        <div class="t-srow-a"><x-site.ikon ad="konum" boy="14" kalin="2" />{{ $s['adr'] }}</div>
                                        @if($s['not'])<div class="t-srow-not"><x-site.ikon ad="uyari" boy="13" kalin="2.2" renk="#C08415" /><b>Not:</b> {{ $s['not'] }}</div>@endif
                                        <div class="t-srow-alt"><span class="t-srow-kur"><x-site.ikon ad="kurye" boy="13" kalin="2" />{{ $s['kur'] }}</span><span class="t-srow-t tab">{{ $s['tut'] }}</span></div>
                                    </div>
                                @endforeach
                            </div>
                        </div>
                        <div class="t-nav"><div class="t-nav-g">@foreach($nav as $b)<button type="button" class="t-nav-b @if($b['k'] === $navAktif) on @endif"><x-site.ikon :ad="$b['ik']" boy="20" :kalin="$b['k'] === $navAktif ? 2.3 : 1.9" renk="#fff" /><span>{{ $b['ad'] }}</span></button>@endforeach</div><button type="button" class="t-fab"><x-site.ikon ad="arti" boy="23" kalin="2.4" renk="#fff" /></button></div>
                    </div>
                    @break

                @case('kurye')
                    @php
                        $duraklar = [['n'=>1,'x'=>62,'y'=>58,'ad'=>'Ahmet Yılmaz','adr'=>'Şirinyalı 42. Sk.','d'=>'ok'],['n'=>2,'x'=>128,'y'=>112,'ad'=>'Hatice Demir','adr'=>'Meltem 3. Cd.','d'=>'ok'],['n'=>3,'x'=>196,'y'=>96,'ad'=>'Selin Kaya','adr'=>'Fener Mah. 18. Sk.','d'=>'yolda'],['n'=>4,'x'=>246,'y'=>162,'ad'=>'Murat Öz','adr'=>'Çağlayan 27. Sk.','d'=>'bekle'],['n'=>5,'x'=>172,'y'=>196,'ad'=>'İbrahim Şahin','adr'=>'Bahçelievler 9. Sk.','d'=>'bekle']];
                        $renkler = ['ok' => '#1E9E6A', 'yolda' => '#5A45F0', 'bekle' => '#17141F'];
                    @endphp
                    <div class="t-ekran">
                        <div class="t-sys"><span>09:41</span><span class="t-sys-sag"><x-site.ikon ad="global" boy="13" kalin="2.2" /><x-site.ikon ad="simsek" boy="13" kalin="2.2" /><span class="t-pil"><i></i></span></span></div>
                        <div class="t-ust">
                            <span class="t-ust-ik"><x-site.ikon ad="sol" boy="19" kalin="2.2" /></span>
                            <span class="t-ust-m"><b>Kurye 1 · Rota</b><small>5 durak · 2 teslim edildi</small></span>
                        </div>
                        <div class="t-harita">
                            <svg viewBox="0 0 320 240" class="t-harita-svg">
                                <rect width="320" height="240" fill="#E8E5EF"></rect>
                                <path d="M0 200 Q80 186 150 200 T320 192 L320 240 L0 240Z" fill="#CFE0E8"></path>
                                <rect x="28" y="24" width="74" height="52" rx="4" fill="#DFDCE8"></rect>
                                <rect x="120" y="18" width="96" height="44" rx="4" fill="#DFDCE8"></rect>
                                <rect x="236" y="34" width="62" height="66" rx="4" fill="#DFDCE8"></rect>
                                <rect x="36" y="104" width="66" height="70" rx="4" fill="#DFDCE8"></rect>
                                <rect x="150" y="118" width="60" height="52" rx="4" fill="#D6E7D2"></rect>
                                <rect x="228" y="126" width="70" height="48" rx="4" fill="#DFDCE8"></rect>
                                <g stroke="#F6F5F9" stroke-width="11" stroke-linecap="round"><path d="M0 88 H320"></path><path d="M0 182 H320"></path><path d="M112 0 V240"></path><path d="M222 0 V240"></path></g>
                                <path d="M62 58 L128 112 L196 96 L246 162 L172 196" fill="none" stroke="#5A45F0" stroke-width="4.5" stroke-linecap="round" stroke-linejoin="round" stroke-dasharray="1000" class="t-rota"></path>
                                @foreach($duraklar as $d)
                                    <g><circle cx="{{ $d['x'] }}" cy="{{ $d['y'] }}" r="13" fill="{{ $renkler[$d['d']] }}"></circle><text x="{{ $d['x'] }}" y="{{ $d['y'] + 4.5 }}" text-anchor="middle" fill="#fff" font-size="12" font-weight="800" font-family="Sora">{{ $d['n'] }}</text></g>
                                @endforeach
                            </svg>
                            <div class="t-harita-rzt"><i></i>Kurye 1 · 3. durakta</div>
                        </div>
                        <div class="t-govde t-govde-k">
                            <div class="t-durak">
                                @foreach($duraklar as $d)
                                    <div class="t-dur {{ $d['d'] }}">
                                        <span class="t-dur-n">@if($d['d'] === 'ok')<x-site.ikon ad="onay" boy="13" kalin="3" renk="#fff" />@else{{ $d['n'] }}@endif</span>
                                        <span class="t-dur-m"><b>{{ $d['ad'] }}</b><small>{{ $d['adr'] }}</small></span>
                                        <span class="t-dur-d">{{ ['ok' => 'Teslim', 'yolda' => 'Yolda'][$d['d']] ?? 'Sırada' }}</span>
                                    </div>
                                @endforeach
                            </div>
                        </div>
                        <div class="t-nav"><div class="t-nav-g">@foreach($nav as $b)<button type="button" class="t-nav-b @if($b['k'] === $navAktif) on @endif"><x-site.ikon :ad="$b['ik']" boy="20" :kalin="$b['k'] === $navAktif ? 2.3 : 1.9" renk="#fff" /><span>{{ $b['ad'] }}</span></button>@endforeach</div><button type="button" class="t-fab"><x-site.ikon ad="arti" boy="23" kalin="2.4" renk="#fff" /></button></div>
                    </div>
                    @break

                @case('gunsonu')
                    <div class="t-ekran">
                        <div class="t-sys"><span>09:41</span><span class="t-sys-sag"><x-site.ikon ad="global" boy="13" kalin="2.2" /><x-site.ikon ad="simsek" boy="13" kalin="2.2" /><span class="t-pil"><i></i></span></span></div>
                        <div class="t-ust">
                            <span class="t-ust-ik"><x-site.ikon ad="sol" boy="19" kalin="2.2" /></span>
                            <span class="t-ust-m"><b>Gün sonu</b><small>2 Ağustos · 19 sipariş</small></span>
                        </div>
                        <div class="t-govde">
                            <div class="t-bas">Kasa</div>
                            <div class="t-kasa">
                                @foreach ([['Nakit','6.240,00 ₺'],['Kart','4.120,00 ₺'],['Veresiye','2.120,00 ₺']] as [$e, $v])<div class="t-kr"><span>{{ $e }}</span><b class="tab">{{ $v }}</b></div>@endforeach
                                <div class="t-kr top"><span>Toplam ciro</span><b class="tab">12.480,00 ₺</b></div>
                            </div>
                            <div class="t-bas">Sayım</div>
                            <div class="t-sayim">
                                <div class="t-kr"><span>Kasada sayılan nakit</span><b class="tab">6.240,00 ₺</b></div>
                                <div class="t-fark tam"><span>FARK YOK</span><b class="tab">0,00 ₺</b></div>
                            </div>
                            <div class="t-bas">Veresiye</div>
                            <div class="t-kasa">
                                <div class="t-kr"><span>Yeni açılan</span><b class="tab">2.120,00 ₺</b></div>
                                <div class="t-kr"><span>Tahsil edilen</span><b class="tab" style="color:#1E9E6A">−1.850,00 ₺</b></div>
                            </div>
                            <button type="button" class="t-btn mor genis"><x-site.ikon ad="kilit" boy="17" kalin="2.2" renk="#fff" />Günü kapat</button>
                        </div>
                        <div class="t-nav"><div class="t-nav-g">@foreach($nav as $b)<button type="button" class="t-nav-b @if($b['k'] === $navAktif) on @endif"><x-site.ikon :ad="$b['ik']" boy="20" :kalin="$b['k'] === $navAktif ? 2.3 : 1.9" renk="#fff" /><span>{{ $b['ad'] }}</span></button>@endforeach</div><button type="button" class="t-fab"><x-site.ikon ad="arti" boy="23" kalin="2.4" renk="#fff" /></button></div>
                    </div>
                    @break

                @default {{-- ana --}}
                    <div class="t-ekran">
                        <div class="t-sys byz"><span>09:41</span><span class="t-sys-sag"><x-site.ikon ad="global" boy="13" kalin="2.2" /><x-site.ikon ad="simsek" boy="13" kalin="2.2" /><span class="t-pil"><i></i></span></span></div>
                        <div class="t-hero">
                            <div class="t-hero-ust">
                                <div><div class="t-selam">Günaydın</div><div class="t-isletme">{{ $isletme }}</div></div>
                                <span class="t-menu"><x-site.ikon ad="menu" boy="19" kalin="2.1" renk="#fff" /></span>
                            </div>
                            <div class="t-sync"><i></i>senkron <b>09:38</b></div>
                        </div>
                        <div class="t-govde">
                            <div class="t-bento">
                                <div class="t-bk mor"><span class="t-bk-l">Bugünkü ciro</span><span class="t-bk-v tab">{{ $ciro }}<small> ₺</small></span></div>
                                <div class="t-bk"><span class="t-bk-l">Açık sipariş</span><span class="t-bk-v tab">{{ $acik }}</span></div>
                                <div class="t-bk"><span class="t-bk-l">Veresiye</span><span class="t-bk-v kucuk tab">48.250 ₺</span><span class="t-bk-a">23 müşteri</span></div>
                                <div class="t-bk"><span class="t-bk-l">Yolda</span><span class="t-bk-v kucuk tab">2 kurye</span><span class="t-bk-a">5 teslimat</span></div>
                            </div>
                            <button type="button" class="t-cta">
                                <span class="t-cta-ic"><x-site.ikon ad="arti" boy="19" kalin="2.5" renk="#fff" /></span>
                                <span class="t-cta-t">Yeni sipariş</span>
                                <x-site.ikon ad="sag" boy="18" kalin="2.2" renk="rgba(255,255,255,.55)" />
                            </button>
                            <div class="t-bas">Son hareketler</div>
                            <div class="t-akt">
                                @foreach ([['Selin Kaya','Öğle menüsü ×2 · kart','360,00 ₺'],['Tezgâh Satışı','Paket sipariş · nakit','320,00 ₺'],['Murat Öz','Tatlı tabağı ×1 · nakit','145,00 ₺']] as [$ad, $ay, $tut])
                                    <div class="t-akt-r"><span class="t-akt-ic"><x-site.ikon ad="onay" boy="14" kalin="2.8" renk="#1E9E6A" /></span><span class="t-akt-m"><b>{{ $ad }}</b><small>{{ $ay }}</small></span><span class="t-akt-t tab">{{ $tut }}</span></div>
                                @endforeach
                            </div>
                        </div>
                        <div class="t-nav"><div class="t-nav-g">@foreach($nav as $b)<button type="button" class="t-nav-b @if($b['k'] === $navAktif) on @endif"><x-site.ikon :ad="$b['ik']" boy="20" :kalin="$b['k'] === $navAktif ? 2.3 : 1.9" renk="#fff" /><span>{{ $b['ad'] }}</span></button>@endforeach</div><button type="button" class="t-fab"><x-site.ikon ad="arti" boy="23" kalin="2.4" renk="#fff" /></button></div>
                        @if($bildirim)<div class="t-toast">{{ $bildirim }}</div>@endif
                    </div>
            @endswitch

            @if($cagri)
                <div class="t-cagri-fon">
                    <div class="t-cagri">
                        <div class="t-cagri-ust">
                            <span class="t-cagri-live"><i></i>GELEN ÇAĞRI</span>
                            <span class="t-cagri-sn"><x-site.ikon ad="saat" boy="12" kalin="2.2" renk="#8B8794" />00:03</span>
                        </div>
                        <div class="t-cagri-kim">
                            <span class="t-cagri-av">AY</span>
                            <span class="t-cagri-mid"><b>Ahmet Yılmaz</b><small>05xx xxx xx 08</small></span>
                        </div>
                        <div class="t-cagri-bal"><span>AÇIK BORÇ</span><b class="tab">8.550,00 ₺</b></div>
                        <div class="t-cagri-bilgi">
                            <div class="t-cagri-b"><x-site.ikon ad="konum" boy="15" kalin="2" renk="#47434F" /><span>Şirinyalı Mah. 42. Sk. No:9 · Muratpaşa</span></div>
                            <div class="t-cagri-b"><x-site.ikon ad="geri" boy="15" kalin="2" renk="#47434F" /><span>Son sipariş: Karışık pide ×2 · dün 12:24</span></div>
                            <div class="t-cagri-b uy"><x-site.ikon ad="uyari" boy="15" kalin="2.2" renk="#C08415" /><span>Zil çalışmıyor — arayın</span></div>
                        </div>
                        <div class="t-cagri-akt">
                            <button type="button" class="t-btn mor"><x-site.ikon ad="arti" boy="17" kalin="2.5" renk="#fff" />Sipariş oluştur</button>
                            <button type="button" class="t-btn gri">Kartı kapat</button>
                        </div>
                    </div>
                </div>
            @endif
        </div>
    </div>
    <span class="t-cizgi"></span>
</div>
