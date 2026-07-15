<?php

namespace App\Payment;

use RuntimeException;

/** Zorunlu hukuk onayı (mesafeli satış / ön bilgilendirme / KVKK) işaretlenmeden ödeme/kayıt denenirse. */
class ConsentRequiredException extends RuntimeException {}
