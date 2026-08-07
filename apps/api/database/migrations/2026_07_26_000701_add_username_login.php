<?php

use Illuminate\Database\Migrations\Migration;
use Illuminate\Database\Schema\Blueprint;
use Illuminate\Support\Facades\DB;
use Illuminate\Support\Facades\Schema;

/**
 * GİRİŞ MODELİ DEĞİŞİKLİĞİ — tasarım `s-giris.jsx`: mobil giriş artık
 * **Firma Kodu + Kullanıcı Adı + Parola** ile yapılır, e-posta ile DEĞİL.
 *
 * Gerekçe (tasarımın kendi metni, `s-isletme.jsx` firma kodu kartı):
 * "Kullanıcılarınız bu kodla giriş yapar; değiştirilemez." Bayinin kuryesi/tezgâhtarı
 * çoğu zaman e-posta sahibi değildir; hesabı patron açar ve ona bir kullanıcı adı verir.
 *
 * NE DEĞİŞTİ:
 *  - users.username eklendi. TENANT İÇİNDE tekil (global değil): iki farklı bayide aynı
 *    "mehmet" kullanıcı adı meşrudur, ayrımı firma kodu yapar.
 *  - sipario_login_lookup artık (firma kodu, kullanıcı adı) alır. Tek argümanlı e-posta
 *    sürümü KALDIRILDI — iki giriş yüzeyi bırakmak, biri unutulduğunda sessiz bir
 *    kimlik doğrulama açığı demektir.
 *
 * NE DEĞİŞMEDİ:
 *  - users.email duruyor ve global tekil kalıyor: yönetim paneli, parola sıfırlama ve
 *    e-posta bildirimi onu kullanır. Yalnız MOBİL GİRİŞ yüzeyinden çıktı.
 *
 * GERİ DOLDURMA: mevcut kullanıcıların kullanıcı adı e-postanın yerel parçasından türetilir
 * (nokta/tire/alt çizgi dışındaki karakterler '.'ya iner, 3 haneden kısaysa 'u' ile doldurulur).
 * Aynı bayide çakışma olursa sonuna sayaç eklenir. Bu tek seferliktir; sonrası panel işidir.
 */
return new class extends Migration
{
    public function up(): void
    {
        // --- Firma kodu ZORUNLU olur --------------------------------------------------------
        // tenants.slug bugüne kadar nullable'dı çünkü hiçbir yerde kimlik değildi (yalnız
        // senkron yanıtında bilgi olarak yayınlanıyordu). Artık girişin ilk alanı: kodu
        // olmayan bir bayiye kimse giremez, dolayısıyla NULL meşru bir durum değil.
        $this->backfillSlug();
        DB::statement('ALTER TABLE tenants ALTER COLUMN slug SET NOT NULL');
        DB::statement(
            'ALTER TABLE tenants ADD CONSTRAINT tenants_slug_check '.
            "CHECK (slug ~ '^[a-z0-9-]{3,80}$')"
        );

        // --- Kullanıcı adı ------------------------------------------------------------------
        Schema::table('users', function (Blueprint $table) {
            $table->string('username', 60)->nullable()->after('email');
        });

        $this->backfill();

        DB::statement('ALTER TABLE users ALTER COLUMN username SET NOT NULL');
        DB::statement('ALTER TABLE users ADD CONSTRAINT users_tenant_username_unique UNIQUE (tenant_id, username)');
        // Tasarımdaki alan doğrulaması ({3,} harf/rakam/nokta/tire/alt çizgi) veritabanında da
        // sabitlenir: istemci doğrulaması atlanabilir, CHECK atlanamaz.
        DB::statement(
            'ALTER TABLE users ADD CONSTRAINT users_username_check '.
            "CHECK (username ~ '^[a-z0-9._-]{3,60}$')"
        );

        // İKİ AYRI GİRİŞ YÜZEYİ VAR, İKİSİ DE MEŞRU — karıştırılmasın:
        //  - sipario_login_lookup(text)        → e-posta. ABONELİK WEB SİTESİ (Faz 5): patron
        //    tarayıcıdan girip ödeme yapar. Mağaza kuralı gereği mobilde bu akış YOKtur.
        //  - sipario_login_lookup(text, text)  → firma kodu + kullanıcı adı. MOBİL UYGULAMA
        //    (tasarım `s-giris.jsx`). Kuryenin e-postası olmayabilir.
        // Tek argümanlı sürüm bu yüzden KALDIRILMAZ; yalnız mobil yüzeyinden çıkarılmıştır.
        DB::unprepared(<<<'SQL'
            CREATE OR REPLACE FUNCTION sipario_login_lookup(p_tenant_code text, p_username text)
            RETURNS TABLE (
                id uuid, tenant_id uuid, name text, username text, password text,
                role text, status text, tenant_status text, valid_until timestamptz
            )
            LANGUAGE sql
            SECURITY DEFINER
            SET search_path = public
            AS $$
                SELECT u.id, u.tenant_id, u.name, u.username, u.password, u.role, u.status,
                       t.status, t.valid_until
                FROM users u
                JOIN tenants t ON t.id = u.tenant_id
                WHERE t.slug = lower(p_tenant_code)
                  AND u.username = lower(p_username)
                LIMIT 1;
            $$;

            ALTER FUNCTION sipario_login_lookup(text, text) OWNER TO sipario_auth;
            REVOKE ALL ON FUNCTION sipario_login_lookup(text, text) FROM PUBLIC;
            GRANT EXECUTE ON FUNCTION sipario_login_lookup(text, text) TO sipario_app;
        SQL);
    }

    public function down(): void
    {
        // Yalnız iki argümanlı (mobil) sürüm geri alınır; e-posta sürümü web sitesinin
        // yüzeyidir ve bu migration onu hiç değiştirmedi.
        DB::unprepared('DROP FUNCTION IF EXISTS sipario_login_lookup(text, text);');

        DB::statement('ALTER TABLE users DROP CONSTRAINT IF EXISTS users_username_check');
        DB::statement('ALTER TABLE users DROP CONSTRAINT IF EXISTS users_tenant_username_unique');

        Schema::table('users', function (Blueprint $table) {
            $table->dropColumn('username');
        });

        DB::statement('ALTER TABLE tenants DROP CONSTRAINT IF EXISTS tenants_slug_check');
        DB::statement('ALTER TABLE tenants ALTER COLUMN slug DROP NOT NULL');
    }

    /**
     * Firma kodu boş olan bayilere addan bir kod türet; çakışırsa sayaç ekle.
     * Türkçe harfler ASCII karşılığına iner ("Şirinyalı Su" → "sirinyali-su").
     */
    private function backfillSlug(): void
    {
        $rows = DB::select('SELECT id, name FROM tenants ORDER BY created_at');
        $alinan = [];
        foreach (DB::select("SELECT slug FROM tenants WHERE slug IS NOT NULL AND slug <> ''") as $r) {
            $alinan[$r->slug] = true;
        }

        foreach ($rows as $row) {
            $mevcut = DB::selectOne('SELECT slug FROM tenants WHERE id = ?', [$row->id]);
            if ($mevcut !== null && $mevcut->slug !== null && $mevcut->slug !== '') {
                continue;
            }

            $taban = $this->kodla((string) $row->name);
            $aday = $taban;
            $n = 1;
            while (isset($alinan[$aday])) {
                $aday = substr($taban, 0, 76).'-'.++$n;
            }
            $alinan[$aday] = true;

            DB::update('UPDATE tenants SET slug = ? WHERE id = ?', [$aday, $row->id]);
        }
    }

    private function kodla(string $ad): string
    {
        $tr = ['ı' => 'i', 'İ' => 'i', 'ş' => 's', 'Ş' => 's', 'ğ' => 'g', 'Ğ' => 'g',
            'ü' => 'u', 'Ü' => 'u', 'ö' => 'o', 'Ö' => 'o', 'ç' => 'c', 'Ç' => 'c'];
        $s = mb_strtolower(strtr($ad, $tr), 'UTF-8');
        $s = preg_replace('/[^a-z0-9]+/', '-', $s) ?? '';
        $s = trim($s, '-');
        if (strlen($s) < 3) {
            $s = str_pad($s === '' ? 'bayi' : $s, 3, 'x');
        }

        return substr($s, 0, 80);
    }

    /**
     * E-postadan kullanıcı adı türet; bayi içinde çakışırsa sayaç ekle.
     * RLS'i atlamak için owner bağlantısı kullanılır (migration zaten owner ile koşar).
     */
    private function backfill(): void
    {
        $rows = DB::select('SELECT id, tenant_id, email FROM users ORDER BY created_at');
        $alinan = [];   // "tenant_id|username" => true

        foreach ($rows as $row) {
            $taban = $this->slugla((string) $row->email);
            $aday = $taban;
            $n = 1;
            while (isset($alinan[$row->tenant_id.'|'.$aday])) {
                $aday = substr($taban, 0, 57).++$n;
            }
            $alinan[$row->tenant_id.'|'.$aday] = true;

            DB::update('UPDATE users SET username = ? WHERE id = ?', [$aday, $row->id]);
        }
    }

    private function slugla(string $email): string
    {
        $yerel = strtolower(explode('@', $email)[0]);
        $temiz = preg_replace('/[^a-z0-9._-]/', '.', $yerel) ?? '';
        $temiz = trim($temiz, '.');
        if (strlen($temiz) < 3) {
            $temiz = str_pad($temiz, 3, 'u');
        }

        return substr($temiz, 0, 60);
    }
};
