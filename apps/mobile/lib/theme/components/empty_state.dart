// Boş durum — ORTAK bileşen (handoff): daire ikon + yönlendirici başlık + altyazı. Müşteriler,
// Siparişler ve sonraki listeler aynı dili konuşur.

import 'package:flutter/material.dart';

import '../tokens.dart';
import '../typography.dart';

class SipEmptyState extends StatelessWidget {
  const SipEmptyState({
    super.key,
    required this.icon,
    required this.title,
    required this.subtitle,
  });

  final IconData icon;
  final String title;
  final String subtitle;

  @override
  Widget build(BuildContext context) {
    return Center(
      child: Padding(
        padding: const EdgeInsets.fromLTRB(40, 0, 40, 120),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Container(
              width: 84,
              height: 84,
              alignment: Alignment.center,
              decoration: BoxDecoration(
                color: SipColors.s2,
                shape: BoxShape.circle,
                border: Border.all(color: SipColors.line),
              ),
              child: Icon(icon, size: 40, color: SipColors.t3),
            ),
            const SizedBox(height: 22),
            Text(title, textAlign: TextAlign.center, style: SipText.emptyTitle),
            const SizedBox(height: 8),
            Text(subtitle, textAlign: TextAlign.center, style: SipText.emptyBody),
          ],
        ),
      ),
    );
  }
}
