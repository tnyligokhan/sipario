package com.sipario.app

import android.content.Context
import android.database.sqlite.SQLiteDatabase
import android.database.sqlite.SQLiteException
import android.util.Log

/**
 * Arayan tanımanın veri yolu. Drift'in yazdığı SQLite dosyasını doğrudan açar.
 *
 * Buradaki her satır 1 saniyelik bütçeye karşı yazıldı:
 *  - Flutter engine başlatılmaz (soğuk başlangıç 1-2 sn alır, bütçeyi tek başına yer).
 *  - Ağ çağrısı yoktur.
 *  - Sorgu `phone_last10` indeksinden tek okumadır; JOIN yalnız birincil anahtar üzerinden.
 *  - Bakiye toplanmaz, okuma-modeli önbellek sütunundan okunur (kaynak defterdir).
 */
object CustomerLookup {

    const val DB_NAME = "sipario.db"
    private const val TAG = "SiparioLookup"

    data class Customer(
        val name: String,
        val address: String?,
        val balanceKurus: Long,
        val note: String?,
    )

    /**
     * Türkiye'de aynı numara +905321234567 / 05321234567 / 5321234567 biçimlerinde gelir.
     * Son 10 hane bu üç biçimde de aynıdır ve ülke içinde tekildir; eşleştirmeyi buna dayandırıyoruz.
     * Gizli/bilinmeyen numaralarda handle boş gelir — çağıran tarafın bunu ayırt etmesi gerekir.
     */
    fun last10(raw: String): String {
        val digits = raw.filter(Char::isDigit)
        return if (digits.length >= 10) digits.takeLast(10) else digits
    }

    fun find(context: Context, rawPhone: String): Customer? {
        val key = last10(rawPhone)
        if (key.length < 10) return null

        val file = context.getDatabasePath(DB_NAME)
        if (!file.exists()) {
            Log.w(TAG, "veritabani yok, ilk kurulum tamamlanmamis olabilir")
            return null
        }

        val db = openForRead(file.absolutePath) ?: return null
        try {
            db.rawQuery(
                """
                SELECT c.name, c.address, c.balance_kurus, c.note
                FROM customer_phones p
                JOIN customers c ON c.id = p.customer_id
                WHERE p.phone_last10 = ?
                LIMIT 1
                """.trimIndent(),
                arrayOf(key)
            ).use { cursor ->
                if (!cursor.moveToFirst()) return null
                return Customer(
                    name = cursor.getString(0),
                    address = if (cursor.isNull(1)) null else cursor.getString(1),
                    balanceKurus = cursor.getLong(2),
                    note = if (cursor.isNull(3)) null else cursor.getString(3),
                )
            }
        } catch (e: SQLiteException) {
            Log.e(TAG, "sorgu basarisiz: ${e.javaClass.simpleName}")
            return null
        } finally {
            db.close()
        }
    }

    /**
     * Drift WAL modunda çalışır. Salt-okunur açış, -wal dosyası kurtarma gerektirdiğinde
     * "attempt to write a readonly database" ile patlayabilir; bu durumda okuma-yazma açıp
     * yalnız okuruz. Yazma yolu hiçbir zaman buradan geçmez.
     */
    private fun openForRead(path: String): SQLiteDatabase? {
        try {
            return SQLiteDatabase.openDatabase(path, null, SQLiteDatabase.OPEN_READONLY)
        } catch (e: SQLiteException) {
            Log.w(TAG, "salt-okunur acilis basarisiz, okuma-yazma deneniyor")
        }
        return try {
            SQLiteDatabase.openDatabase(path, null, SQLiteDatabase.OPEN_READWRITE)
        } catch (e: SQLiteException) {
            Log.e(TAG, "veritabani acilamadi: ${e.javaClass.simpleName}")
            null
        }
    }
}
