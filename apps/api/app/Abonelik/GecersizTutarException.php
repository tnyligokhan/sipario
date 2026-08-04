<?php

namespace App\Abonelik;

use RuntimeException;

/** Tutar/adet doğrulaması (negatif, sıfır ya da anlamsız değer). Mesaj kullanıcıya gösterilebilir. */
class GecersizTutarException extends RuntimeException {}
