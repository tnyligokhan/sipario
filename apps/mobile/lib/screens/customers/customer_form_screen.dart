import 'package:flutter/material.dart';

import '../../repo/customer_repository.dart';

/// Yeni müşteri formu: ad zorunlu, telefon önerilir (arayan tanımanın anahtarı), adres/not opsiyonel.
/// Telefon +90 E.164'e normalize edilir (05xx / 5xx / +905xx üç yazım da kabul).
class CustomerFormScreen extends StatefulWidget {
  const CustomerFormScreen({super.key, required this.repo});

  final CustomerRepository repo;

  @override
  State<CustomerFormScreen> createState() => _CustomerFormScreenState();
}

class _CustomerFormScreenState extends State<CustomerFormScreen> {
  final _formKey = GlobalKey<FormState>();
  final _name = TextEditingController();
  final _phone = TextEditingController();
  final _address = TextEditingController();
  final _note = TextEditingController();
  bool _busy = false;

  @override
  void dispose() {
    _name.dispose();
    _phone.dispose();
    _address.dispose();
    _note.dispose();
    super.dispose();
  }

  Future<void> _save() async {
    if (!_formKey.currentState!.validate()) return;
    setState(() => _busy = true);
    try {
      final phone = normalizePhoneTR(_phone.text);
      await widget.repo.create(
        name: _name.text.trim(),
        note: _note.text.trim().isEmpty ? null : _note.text.trim(),
        phones: [
          if (phone != null) PhoneInput(phoneE164: phone, isPrimary: true),
        ],
        addresses: [
          if (_address.text.trim().isNotEmpty)
            AddressInput(addressText: _address.text.trim(), isPrimary: true),
        ],
      );
      if (mounted) Navigator.of(context).pop();
    } finally {
      if (mounted) setState(() => _busy = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('Yeni müşteri')),
      body: SingleChildScrollView(
        padding: const EdgeInsets.all(16),
        child: Form(
          key: _formKey,
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              TextFormField(
                controller: _name,
                enabled: !_busy,
                autofocus: true,
                textCapitalization: TextCapitalization.words,
                decoration: const InputDecoration(
                  labelText: 'Ad soyad / ünvan *',
                  border: OutlineInputBorder(),
                  prefixIcon: Icon(Icons.person_outline),
                ),
                validator: (v) => (v == null || v.trim().isEmpty) ? 'Ad gerekli' : null,
              ),
              const SizedBox(height: 12),
              TextFormField(
                controller: _phone,
                enabled: !_busy,
                keyboardType: TextInputType.phone,
                decoration: const InputDecoration(
                  labelText: 'Telefon',
                  helperText: 'Arayınca ekranda tanımak için — 05xx xxx xx xx',
                  border: OutlineInputBorder(),
                  prefixIcon: Icon(Icons.phone_outlined),
                ),
                validator: (v) {
                  if (v == null || v.trim().isEmpty) return null; // opsiyonel
                  return normalizePhoneTR(v) == null ? 'Geçersiz telefon numarası' : null;
                },
              ),
              const SizedBox(height: 12),
              TextFormField(
                controller: _address,
                enabled: !_busy,
                maxLines: 2,
                decoration: const InputDecoration(
                  labelText: 'Adres',
                  border: OutlineInputBorder(),
                  prefixIcon: Icon(Icons.home_outlined),
                ),
              ),
              const SizedBox(height: 12),
              TextFormField(
                controller: _note,
                enabled: !_busy,
                decoration: const InputDecoration(
                  labelText: 'Not',
                  helperText: 'Ör. kapı kodu, kat, "akşam 6\'dan sonra"',
                  border: OutlineInputBorder(),
                  prefixIcon: Icon(Icons.notes_outlined),
                ),
              ),
              const SizedBox(height: 24),
              FilledButton.icon(
                onPressed: _busy ? null : _save,
                icon: const Icon(Icons.check),
                label: const Text('Kaydet'),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

/// TR telefonunu E.164'e çevirir; geçersizse null. Kabul edilen yazımlar:
/// 05321112233 / 5321112233 / +905321112233 / 90 532 111 22 33 (boşluk-tire önemsiz).
String? normalizePhoneTR(String raw) {
  final digits = raw.replaceAll(RegExp(r'\D'), '');
  String ten;
  if (digits.length == 10) {
    ten = digits; // 5321112233
  } else if (digits.length == 11 && digits.startsWith('0')) {
    ten = digits.substring(1); // 05321112233
  } else if (digits.length == 12 && digits.startsWith('90')) {
    ten = digits.substring(2); // 905321112233
  } else {
    return null;
  }
  // Mobil ve sabit hatlar: TR'de ulusal numara 10 hane ve 0 ile başlamaz.
  if (ten.startsWith('0')) return null;
  return '+90$ten';
}
