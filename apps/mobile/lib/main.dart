import 'package:flutter/material.dart';

import 'phase0/phase0_screen.dart';

void main() => runApp(const SiparioApp());

class SiparioApp extends StatelessWidget {
  const SiparioApp({super.key});

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      title: 'Sipario',
      debugShowCheckedModeBanner: false,
      theme: ThemeData(
        colorScheme: ColorScheme.fromSeed(
          seedColor: const Color(0xFF2F6BFF),
          brightness: Brightness.dark,
        ),
        useMaterial3: true,
      ),
      // Faz 0: ürünün varlık sebebi olan arayan tanımayı gerçek cihazda kanıtlama ekranı.
      // Kapı geçilene kadar uygulamanın başka ekranı yok.
      home: const Phase0Screen(),
    );
  }
}
