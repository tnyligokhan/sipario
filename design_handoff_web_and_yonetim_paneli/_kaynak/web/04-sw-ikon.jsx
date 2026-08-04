// sw-ikon.jsx — Lucide (lucide.dev, ISC) CDN paketine bağlı ikon bileşeni. → window
// Türkçe takma ad → Lucide bileşen adı. Paket yüklenmezse nötr bir işaret çizilir.

const SW_AD = {
  cagri:'PhoneCall', telefon:'Phone', telefonKapali:'PhoneOff', musteri:'User', musteriler:'Users',
  musteriEkle:'UserPlus', defter:'BookOpen', cuzdan:'Wallet', kutu:'Package', kurye:'Truck',
  konum:'MapPin', fis:'Receipt', ayar:'Settings', senkron:'RefreshCw', onay:'Check', kapat:'X',
  sag:'ChevronRight', sol:'ChevronLeft', asagi:'ChevronDown', yukari:'ChevronUp', ara:'Search',
  uyari:'TriangleAlert', bilgi:'Info', simsek:'Zap', saat:'Clock', kilit:'Lock', kalkan:'ShieldCheck',
  kulaklik:'Headphones', kart:'CreditCard', bina:'Building2', belge:'FileText', indir:'Download',
  arti:'Plus', eksi:'Minus', ok:'ArrowRight', okYukari:'ArrowUpRight', okSol:'ArrowLeft',
  yildiz:'Star', tirnak:'Quote', oynat:'Play', para:'Banknote', takvim:'Calendar', grafik:'ChartColumn',
  cikis:'LogOut', menu:'Menu', cevrimdisi:'WifiOff', mobil:'Smartphone', parilti:'Sparkles',
  tamam:'CircleCheck', cansimidi:'LifeBuoy', posta:'Mail', sohbet:'MessageCircle', soru:'CircleQuestionMark',
  artis:'TrendingUp', katman:'Layers', elpara:'HandCoins', rozet:'BadgeCheck', geri:'RotateCcw',
  disLink:'ExternalLink', goz:'Eye', gozKapali:'EyeOff', duzenle:'Pencil', sil:'Trash2', kopyala:'Copy',
  qr:'QrCode', siren:'Siren', kumsaati:'Hourglass', liste:'List', filtre:'ListFilter', ev:'House',
  global:'Globe', anahtar:'KeyRound', kullanicilar:'UsersRound', barkod:'ScanBarcode', pin:'MapPinned',
};

function swDugum(ad){
  const L = window.lucide; if(!L) return null;
  const n = SW_AD[ad] || ad;
  return L[n] || (L.icons && L.icons[n]) || null;
}

function Ikon({ ad, boy = 20, kalin = 1.9, renk = 'currentColor', stil }){
  const d = swDugum(ad);
  const ortak = { width: boy, height: boy, viewBox:'0 0 24 24', fill:'none', stroke: renk,
    strokeWidth: kalin, strokeLinecap:'round', strokeLinejoin:'round', style: stil, 'aria-hidden':'true' };
  if(!d) return <svg {...ortak}><circle cx="12" cy="12" r="8" /></svg>;
  return <svg {...ortak}>{d.map((p, i) => React.createElement(p[0], { key: i, ...p[1] }))}</svg>;
}

Object.assign(window, { Ikon });
