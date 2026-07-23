// Bakiye rozeti — ORTAK bileşen (handoff "Bileşenler & durumlar" + müşteri listesi + çağrı popup'ı
// aynı dili konuşur). İşaret kuralı defterle aynı: + = müşteri BORÇLU (dolgulu kırmızı, dikkat çeker),
// 0 = temiz (nötr, sessiz), − = alacak (sessiz yeşil). Tutar metni formatKurus'tan gelir (tek sınır).

import 'package:flutter/material.dart';

import '../../screens/money.dart';
import '../tokens.dart';
import '../typography.dart';

class BalanceBadge extends StatelessWidget {
  const BalanceBadge({super.key, required this.kurus});

  final int kurus;

  @override
  Widget build(BuildContext context) {
    final text = formatKurus(kurus);

    if (kurus > 0) {
      // Borç — dolgulu kırmızı hap, beyaz yazı. Listede/çağrıda "bak buraya" öğesi.
      return Container(
        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 7),
        decoration: const BoxDecoration(color: SipColors.debt, borderRadius: SipRadius.smBr),
        child: Text(text, style: SipText.badge.copyWith(color: Colors.white)),
      );
    }

    // Temiz (0) → soluk; alacak (−) → sessiz yeşil. İkisi de dolgusuz: sessiz kalır.
    final color = kurus < 0 ? SipColors.ok : SipColors.t3;
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 7),
      child: Text(
        text,
        style: SipText.badge.copyWith(color: color, fontWeight: FontWeight.w500),
      ),
    );
  }
}
