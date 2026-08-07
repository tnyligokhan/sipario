<?php

use Illuminate\Database\Migrations\Migration;
use Illuminate\Support\Facades\DB;

/**
 * `day_closings` PANEL İZNİ (000504'ün eksiği; 005010'un aynı sınıfı, inceleme #3 yan bulgusu).
 *
 * 000504 iş verisi tablolarını sayarken `day_closings` HENÜZ YOKTU (tablo 000604'te, on gün sonra
 * doğdu) ve sonraki hiçbir migration ona izin vermedi. Postgres yeni tabloya kendiliğinden izin
 * vermediği için panel rolünün bu tabloda BUGÜNE KADAR HİÇBİR izni olmadı — 005010'daki
 * `subscription_payments` ile birebir aynı arıza sınıfı.
 *
 * NEDEN ÖNEMLİ (BRIEF taahhüdü): "Veri rehin alınmaz — bayi destek kanalıyla her zaman dışa aktarım
 * talep edebilir." Dışa aktarım `PanelExportService` ile `pgsql_panel` bağlantısından okunuyor;
 * izin olmadığı için bayinin GÜN SONU MUTABAKAT ARŞİVİ export'a hiç giremiyordu. `cash_handovers`
 * export'ta olduğu hâlde kapanış arşivinin olmaması, mutabakatın yarısını vermek demekti: devirler
 * görünüyor ama "o gün ne beklendi, ne sayıldı, fark neydi" görünmüyordu.
 *
 * YALNIZ SELECT: 000504'ün felsefesi aynen geçerli — panel bayinin iş verisini DEĞİŞTİREMEZ, ve bu
 * koda değil DB İZNİNE bağlıdır. Ayrıca `day_closings` append-only'dir (000607 `sipario_app`ten
 * UPDATE/DELETE'i geri alır); panele yazma vermek o değişmezliğin yanından dolaşan bir kapı açardı.
 */
return new class extends Migration
{
    public function up(): void
    {
        DB::unprepared('GRANT SELECT ON day_closings TO sipario_panel;');
    }

    public function down(): void
    {
        DB::unprepared('REVOKE SELECT ON day_closings FROM sipario_panel;');
    }
};
