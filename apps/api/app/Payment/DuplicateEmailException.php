<?php

namespace App\Payment;

use RuntimeException;

/** Üyelikte e-posta global tekil çakışması (nötr mesajla yüzeye çıkar — numaralandırma sızdırmaz). */
class DuplicateEmailException extends RuntimeException {}
