const BUGUN = new Date(2026, 7, 4);
const PLAN_UCRET = 399;
const AYLAR = ['Ocak','Şubat','Mart','Nisan','Mayıs','Haziran','Temmuz','Ağustos','Eylül','Ekim','Kasım','Aralık'];
const para = (n) => '₺' + Math.abs(n).toLocaleString('tr-TR');
const paraNet = (n) => (n < 0 ? '−₺' : '+₺') + Math.abs(n).toLocaleString('tr-TR');
const tarihK = (iso) => { const d = new Date(iso + 'T00:00'); return `${d.getDate()} ${AYLAR[d.getMonth()].slice(0,3)} ${d.getFullYear()}`; };
const gunFarki = (iso) => Math.round((new Date(iso + 'T00:00') - BUGUN) / 864e5);
const isoBugun = '2026-08-04';
const ayEkle = (iso, n) => { const d = new Date(iso + 'T00:00'); d.setMonth(d.getMonth() + n); return d.toISOString().slice(0,10); };
const gunEkle = (iso, n) => { const d = new Date(iso + 'T00:00'); d.setDate(d.getDate() + n); return d.toISOString().slice(0,10); };
const DURUMLAR = { deneme:{ad:'Deneme',cls:'deneme'}, aktif:{ad:'Aktif',cls:'aktif'}, askida:{ad:'Askıda',cls:'askida'}, iptal:{ad:'İptal',cls:'iptal'} };
const MASRAF_KATEGORI = ['Sunucu/Altyapı','Domain/Lisans','Reklam','Komisyon','Diğer'];

const ILK_FIRMALAR = [
{id:'f1', ad:'Berrak Su', yetkili:'Hasan Yıldırım', tel:'0532 214 76 30', il:'Ankara', ilce:'Çankaya', kayit:'2026-02-11', durum:'aktif', bitis:'2026-08-27', notlar:[]},
{id:'f2', ad:'Pınar Su Bayii', yetkili:'Mehmet Karaca', tel:'0542 863 11 08', il:'İzmir', ilce:'Bornova', kayit:'2026-03-02', durum:'aktif', bitis:'2026-09-02', notlar:[]},
{id:'f3', ad:'Damla Su', yetkili:'Ayşe Demirtaş', tel:'0535 447 92 61', il:'İstanbul', ilce:'Ümraniye', kayit:'2026-07-21', durum:'deneme', bitis:'2026-08-07', notlar:[]},
{id:'f4', ad:'Kaynak Su Market', yetkili:'İbrahim Sözer', tel:'0546 210 38 55', il:'Bursa', ilce:'Nilüfer', kayit:'2026-04-15', durum:'aktif', bitis:'2026-08-15', notlar:[]},
{id:'f5', ad:'Saf Su Dağıtım', yetkili:'Ramazan Ekinci', tel:'0533 682 47 19', il:'Antalya', ilce:'Kepez', kayit:'2026-03-20', durum:'askida', bitis:'2026-07-20', notlar:[{t:'2026-07-28', m:'Telefonla arandı, haftaya ödeyecek.'}]},
{id:'f6', ad:'Buz Su', yetkili:'Kadir Aslan', tel:'0544 391 25 84', il:'Konya', ilce:'Selçuklu', kayit:'2026-07-26', durum:'deneme', bitis:'2026-08-16', notlar:[]},
{id:'f7', ad:'Elmas Su', yetkili:'Selim Bozkurt', tel:'0537 158 60 42', il:'Adana', ilce:'Seyhan', kayit:'2026-02-28', durum:'aktif', bitis:'2026-07-28', notlar:[{t:'2026-08-01', m:'WhatsApp\'tan hatırlatma gönderildi.'}]},
{id:'f8', ad:'Doruk Su Bayii', yetkili:'Emre Şahin', tel:'0538 745 90 13', il:'İstanbul', ilce:'Pendik', kayit:'2026-05-06', durum:'aktif', bitis:'2026-09-06', notlar:[]},
{id:'f9', ad:'Yudum Su', yetkili:'Fatma Güler', tel:'0543 528 74 96', il:'Gaziantep', ilce:'Şahinbey', kayit:'2026-07-19', durum:'deneme', bitis:'2026-08-09', notlar:[]},
{id:'f10', ad:'Mavi Damacana', yetkili:'Osman Çetin', tel:'0536 903 41 27', il:'Mersin', ilce:'Yenişehir', kayit:'2026-04-01', durum:'aktif', bitis:'2026-09-01', notlar:[]},
{id:'f11', ad:'Kristal Su', yetkili:'Hüseyin Aydın', tel:'0541 276 58 33', il:'Kayseri', ilce:'Melikgazi', kayit:'2026-03-11', durum:'iptal', bitis:'2026-06-11', notlar:[{t:'2026-06-09', m:'Kuryesini işten çıkarmış, uygulamayı bıraktı.'}]},
{id:'f12', ad:'Umut Su Dağıtım', yetkili:'Zeynep Kaplan', tel:'0545 619 82 70', il:'Samsun', ilce:'İlkadım', kayit:'2026-05-23', durum:'aktif', bitis:'2026-09-03', notlar:[]},
{id:'f13', ad:'Nehir Su', yetkili:'Murat Öztürk', tel:'0534 852 36 91', il:'Eskişehir', ilce:'Odunpazarı', kayit:'2026-07-15', durum:'deneme', bitis:'2026-08-05', notlar:[]},
{id:'f14', ad:'Yağmur Su Bayii', yetkili:'Ali Kurt', tel:'0539 407 63 58', il:'Trabzon', ilce:'Ortahisar', kayit:'2026-04-09', durum:'askida', bitis:'2026-07-09', notlar:[]},
{id:'f15', ad:'Derin Su', yetkili:'Nurten Acar', tel:'0547 731 20 45', il:'Denizli', ilce:'Pamukkale', kayit:'2026-06-12', durum:'aktif', bitis:'2026-09-01', notlar:[]},
{id:'f16', ad:'Zirve Su', yetkili:'Burak Tekin', tel:'0531 964 15 72', il:'Ankara', ilce:'Keçiören', kayit:'2026-02-05', durum:'iptal', bitis:'2026-05-05', notlar:[]}
];

const ILK_ODEMELER = [
{id:'o1', firmaId:'f8', tarih:'2026-08-03', tutar:399, yontem:'Elden', donem:'Ağustos 2026', not:'Ofiste elden alındı'},
{id:'op1', firmaId:'f8', tarih:'2026-08-02', tutar:299, yontem:'IBAN', donem:'Ek paket · 250 oto-sıralama hakkı', not:''},
{id:'op2', firmaId:'f2', tarih:'2026-07-24', tutar:79, yontem:'IBAN', donem:'Ek paket · +1 kurye hesabı', not:'Üçüncü kuryesini işe aldı'},
{id:'op3', firmaId:'f1', tarih:'2026-07-18', tutar:149, yontem:'Elden', donem:'Ek paket · 100 oto-sıralama hakkı', not:''},
{id:'op4', firmaId:'f10', tarih:'2026-06-22', tutar:499, yontem:'IBAN', donem:'Ek paket · 500 oto-sıralama hakkı', not:''},
{id:'o2', firmaId:'f12', tarih:'2026-08-03', tutar:399, yontem:'IBAN', donem:'Ağustos 2026', not:''},
{id:'o3', firmaId:'f2', tarih:'2026-08-02', tutar:399, yontem:'IBAN', donem:'Ağustos 2026', not:''},
{id:'o4', firmaId:'f10', tarih:'2026-08-01', tutar:399, yontem:'IBAN', donem:'Ağustos 2026', not:''},
{id:'o5', firmaId:'f15', tarih:'2026-08-01', tutar:399, yontem:'IBAN', donem:'Ağustos 2026', not:''},
{id:'o6', firmaId:'f1', tarih:'2026-07-27', tutar:399, yontem:'IBAN', donem:'Ağustos 2026', not:''},
{id:'o7', firmaId:'f4', tarih:'2026-07-15', tutar:399, yontem:'IBAN', donem:'Temmuz 2026', not:''},
{id:'o8', firmaId:'f8', tarih:'2026-07-06', tutar:399, yontem:'IBAN', donem:'Temmuz 2026', not:''},
{id:'o9', firmaId:'f12', tarih:'2026-07-03', tutar:399, yontem:'IBAN', donem:'Temmuz 2026', not:''},
{id:'o10', firmaId:'f15', tarih:'2026-07-03', tutar:399, yontem:'IBAN', donem:'Temmuz 2026', not:'Deneme sonrası ilk ödeme'},
{id:'o11', firmaId:'f2', tarih:'2026-07-02', tutar:399, yontem:'IBAN', donem:'Temmuz 2026', not:''},
{id:'o12', firmaId:'f10', tarih:'2026-07-01', tutar:399, yontem:'Elden', donem:'Temmuz 2026', not:''},
{id:'o13', firmaId:'f7', tarih:'2026-06-28', tutar:399, yontem:'IBAN', donem:'Temmuz 2026', not:''},
{id:'o14', firmaId:'f1', tarih:'2026-06-27', tutar:399, yontem:'IBAN', donem:'Temmuz 2026', not:''},
{id:'o15', firmaId:'f5', tarih:'2026-06-20', tutar:399, yontem:'Elden', donem:'Haziran 2026', not:'Dağıtımda uğrayıp alındı'},
{id:'o16', firmaId:'f4', tarih:'2026-06-15', tutar:399, yontem:'Elden', donem:'Haziran 2026', not:''},
{id:'o17', firmaId:'f8', tarih:'2026-06-06', tutar:399, yontem:'IBAN', donem:'Haziran 2026', not:''},
{id:'o18', firmaId:'f12', tarih:'2026-06-03', tutar:399, yontem:'IBAN', donem:'Haziran 2026', not:'Deneme sonrası ilk ödeme'},
{id:'o19', firmaId:'f2', tarih:'2026-06-02', tutar:399, yontem:'IBAN', donem:'Haziran 2026', not:''},
{id:'o20', firmaId:'f10', tarih:'2026-06-01', tutar:399, yontem:'IBAN', donem:'Haziran 2026', not:''},
{id:'o21', firmaId:'f7', tarih:'2026-05-28', tutar:399, yontem:'IBAN', donem:'Haziran 2026', not:''},
{id:'o22', firmaId:'f1', tarih:'2026-05-27', tutar:399, yontem:'IBAN', donem:'Haziran 2026', not:''},
{id:'o23', firmaId:'f11', tarih:'2026-05-11', tutar:399, yontem:'IBAN', donem:'Mayıs 2026', not:'Son ödemesi, ay sonunda iptal etti'},
{id:'o24', firmaId:'f14', tarih:'2026-05-09', tutar:399, yontem:'Elden', donem:'Mayıs 2026', not:''},
{id:'o25', firmaId:'f2', tarih:'2026-05-02', tutar:399, yontem:'IBAN', donem:'Mayıs 2026', not:''},
{id:'o26', firmaId:'f10', tarih:'2026-05-01', tutar:399, yontem:'IBAN', donem:'Mayıs 2026', not:''},
{id:'o27', firmaId:'f1', tarih:'2026-04-27', tutar:399, yontem:'IBAN', donem:'Mayıs 2026', not:''},
{id:'o28', firmaId:'f11', tarih:'2026-04-11', tutar:399, yontem:'IBAN', donem:'Nisan 2026', not:''},
{id:'o29', firmaId:'f2', tarih:'2026-04-02', tutar:399, yontem:'IBAN', donem:'Nisan 2026', not:'Deneme sonrası ilk ödeme'},
{id:'o30', firmaId:'f16', tarih:'2026-03-05', tutar:399, yontem:'IBAN', donem:'Mart 2026', not:''},
{id:'o31', firmaId:'f1', tarih:'2026-03-04', tutar:399, yontem:'IBAN', donem:'Mart 2026', not:'İlk ödeme'}
];

const ILK_MASRAFLAR = [
{id:'m14', tarih:'2026-08-03', kategori:'Domain/Lisans', tutar:240, not:'SMS paketi (NetGSM)'},
{id:'m13', tarih:'2026-08-01', kategori:'Sunucu/Altyapı', tutar:1150, not:'Hetzner aylık'},
{id:'m12', tarih:'2026-07-15', kategori:'Reklam', tutar:900, not:'Google Ads'},
{id:'m11', tarih:'2026-07-08', kategori:'Komisyon', tutar:460, not:'Banka havale komisyonları'},
{id:'m10', tarih:'2026-07-01', kategori:'Sunucu/Altyapı', tutar:1150, not:'Hetzner aylık'},
{id:'m9', tarih:'2026-06-10', kategori:'Reklam', tutar:1200, not:'Google Ads'},
{id:'m8', tarih:'2026-06-01', kategori:'Sunucu/Altyapı', tutar:1150, not:'Hetzner aylık — sunucu yükseltildi'},
{id:'m7', tarih:'2026-05-22', kategori:'Diğer', tutar:320, not:'Kartvizit ve broşür baskısı'},
{id:'m6', tarih:'2026-05-05', kategori:'Reklam', tutar:1800, not:'Google Ads'},
{id:'m5', tarih:'2026-05-01', kategori:'Sunucu/Altyapı', tutar:850, not:'Hetzner aylık'},
{id:'m4', tarih:'2026-04-18', kategori:'Reklam', tutar:1500, not:'Google Ads deneme kampanyası'},
{id:'m3', tarih:'2026-04-01', kategori:'Sunucu/Altyapı', tutar:850, not:'Hetzner aylık'},
{id:'m2', tarih:'2026-03-14', kategori:'Domain/Lisans', tutar:590, not:'sipario.app yıllık domain'},
{id:'m1', tarih:'2026-03-01', kategori:'Sunucu/Altyapı', tutar:850, not:'Hetzner aylık'}
];

const ILK_PLAN = { ad: 'Aylık Abonelik', ucret: 399, denemeGun: 14, hakAy: 50, kurye: 3 };

const ILK_PAKETLER = [
{id:'e1', tur:'hak', ad:'100 oto-sıralama hakkı', adet:100, ucret:149, aktif:true},
{id:'e2', tur:'hak', ad:'250 oto-sıralama hakkı', adet:250, ucret:299, aktif:true},
{id:'e3', tur:'hak', ad:'500 oto-sıralama hakkı', adet:500, ucret:499, aktif:true},
{id:'e4', tur:'kurye', ad:'+1 kurye hesabı', adet:1, ucret:79, aktif:true},
{id:'e5', tur:'kurye', ad:'+3 kurye hesabı', adet:3, ucret:199, aktif:true},
{id:'e6', tur:'hak', ad:'1000 oto-sıralama hakkı', adet:1000, ucret:849, aktif:false}
];

const ILK_TANIMLAMALAR = [
{id:'t1', firmaId:'f8', paketId:'e2', tarih:'2026-08-02', adet:250, tutar:299, tahsil:'IBAN', not:''},
{id:'t2', firmaId:'f2', paketId:'e4', tarih:'2026-07-24', adet:1, tutar:79, tahsil:'IBAN', not:'Üçüncü kuryesini işe aldı'},
{id:'t3', firmaId:'f1', paketId:'e1', tarih:'2026-07-18', adet:100, tutar:149, tahsil:'Elden', not:''},
{id:'t4', firmaId:'f15', paketId:'e1', tarih:'2026-07-06', adet:100, tutar:0, tahsil:'Bedelsiz', not:'Deneme sonrası jest'},
{id:'t5', firmaId:'f10', paketId:'e3', tarih:'2026-06-22', adet:500, tutar:499, tahsil:'IBAN', not:''}
];

const TAHSIL_YOLLARI = ['IBAN', 'Elden', 'Bedelsiz'];

const sonOdemeBul = (odemeler, firmaId) => { const o = odemeler.filter(x => x.firmaId === firmaId); return o.length ? o.reduce((a,b) => a.tarih > b.tarih ? a : b).tarih : null; };
const ayAnahtar = (iso) => iso.slice(0,7);
const ayAdi = (anahtar) => { const [y,m] = anahtar.split('-'); return `${AYLAR[+m-1]} ${y}`; };

Object.assign(window, { BUGUN, PLAN_UCRET, AYLAR, para, paraNet, tarihK, gunFarki, isoBugun, ayEkle, gunEkle, DURUMLAR, MASRAF_KATEGORI, ILK_FIRMALAR, ILK_ODEMELER, ILK_MASRAFLAR, ILK_PLAN, ILK_PAKETLER, ILK_TANIMLAMALAR, TAHSIL_YOLLARI, sonOdemeBul, ayAnahtar, ayAdi });
