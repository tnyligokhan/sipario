<?php

namespace App\Support;

use RuntimeException;

/**
 * İstenen firma kodu (slug) BAŞKA bir bayide kullanılıyor.
 *
 * NEDEN AÇIK KONUŞUYOR (DuplicateEmailException'ın aksine): e-posta çakışmasında mesaj NÖTRdür,
 * çünkü "bu e-posta kayıtlı" demek kullanıcı numaralandırmasına kapı açar. Firma kodu ise
 * tasarım gereği ZATEN herkese açık bir kimliktir — kayıt ekranı kod müsaitliğini kullanıcıya
 * yazarken gösterir ve giriş ekranının ilk alanı odur. Burada gizlenecek bir şey yok; gizlemek
 * yalnız kullanıcıyı "kodum neden uygulanmadı" diye bırakırdı.
 */
class DuplicateSlugException extends RuntimeException {}
