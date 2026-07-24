import 'package:flutter/material.dart';

import '../auth/auth_api.dart';
import '../auth/session.dart';
import '../theme/tokens.dart';
import '../theme/typography.dart';

/// Giriş ekranı — mobilde KAYIT YOK, yalnız giriş (BRIEF mağaza kuralı: kayıt/ödeme/fiyat mobilde
/// gösterilemez; üyelik yalnız web'de yaşar). Bu yüzden ekranda kayıt linki/metni BULUNMAZ.
///
/// Yeniden tasarım: marka bloğu (daire ikon + Sipario) + temanın dolgulu input/buton stilleri
/// (ekran-yerel kenarlık ezmeleri kaldırıldı) + hata şeridi. Davranış/doğrulama DEĞİŞMEDİ.
class LoginScreen extends StatefulWidget {
  const LoginScreen({super.key, required this.session, required this.onLoggedIn});

  final Session session;
  final VoidCallback onLoggedIn;

  @override
  State<LoginScreen> createState() => _LoginScreenState();
}

class _LoginScreenState extends State<LoginScreen> {
  final _formKey = GlobalKey<FormState>();
  final _email = TextEditingController();
  final _password = TextEditingController();
  final _baseUrl = TextEditingController();

  bool _busy = false;
  bool _showAdvanced = false;
  bool _obscure = true;
  String? _error;

  @override
  void initState() {
    super.initState();
    widget.session.state().then((meta) {
      if (mounted) _baseUrl.text = Session.baseUrlOf(meta);
    });
  }

  @override
  void dispose() {
    _email.dispose();
    _password.dispose();
    _baseUrl.dispose();
    super.dispose();
  }

  Future<void> _submit() async {
    if (!_formKey.currentState!.validate()) return;
    setState(() {
      _busy = true;
      _error = null;
    });
    try {
      await widget.session.login(
        email: _email.text,
        password: _password.text,
        baseUrlOverride: _baseUrl.text.trim().isEmpty ? null : _baseUrl.text,
      );
      if (mounted) widget.onLoggedIn();
    } on AuthException catch (e) {
      setState(() => _error = e.message);
    } finally {
      if (mounted) setState(() => _busy = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: SipColors.bg,
      body: SafeArea(
        child: Center(
          child: SingleChildScrollView(
            padding: const EdgeInsets.all(24),
            child: ConstrainedBox(
              constraints: const BoxConstraints(maxWidth: 420),
              child: Form(
                key: _formKey,
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  crossAxisAlignment: CrossAxisAlignment.stretch,
                  children: [
                    // Marka bloğu — profil kartındaki dairesel avatar diliyle aynı.
                    Center(
                      child: Container(
                        width: 84,
                        height: 84,
                        alignment: Alignment.center,
                        decoration: BoxDecoration(
                          color: SipColors.s2,
                          shape: BoxShape.circle,
                          border: Border.all(color: SipColors.line),
                        ),
                        child: const Icon(Icons.storefront, size: 40, color: SipColors.accFg),
                      ),
                    ),
                    const SizedBox(height: SipSpace.lg),
                    const Text('Sipario',
                        textAlign: TextAlign.center, style: SipText.screenTitle),
                    const SizedBox(height: 6),
                    Text('Bayi girişi',
                        textAlign: TextAlign.center,
                        style: SipText.secondary.copyWith(color: SipColors.t3)),
                    const SizedBox(height: SipSpace.section),
                    TextFormField(
                      controller: _email,
                      enabled: !_busy,
                      keyboardType: TextInputType.emailAddress,
                      autofillHints: const [AutofillHints.email],
                      textInputAction: TextInputAction.next,
                      decoration: const InputDecoration(
                        labelText: 'E-posta',
                        prefixIcon: Icon(Icons.mail_outline),
                      ),
                      validator: (v) =>
                          (v == null || !v.contains('@')) ? 'Geçerli bir e-posta girin' : null,
                    ),
                    const SizedBox(height: SipSpace.md),
                    TextFormField(
                      controller: _password,
                      enabled: !_busy,
                      obscureText: _obscure,
                      autofillHints: const [AutofillHints.password],
                      textInputAction: TextInputAction.done,
                      onFieldSubmitted: (_) => _submit(),
                      decoration: InputDecoration(
                        labelText: 'Parola',
                        prefixIcon: const Icon(Icons.lock_outline),
                        suffixIcon: IconButton(
                          onPressed: () => setState(() => _obscure = !_obscure),
                          icon: Icon(_obscure ? Icons.visibility_off : Icons.visibility),
                        ),
                      ),
                      validator: (v) => (v == null || v.isEmpty) ? 'Parola gerekli' : null,
                    ),
                    if (_error != null) ...[
                      const SizedBox(height: SipSpace.md),
                      // Hata şeridi — nötr metin yerine görünür kırmızı yumuşak zemin.
                      Container(
                        padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 11),
                        decoration: const BoxDecoration(
                          color: SipColors.debtSoft,
                          borderRadius: SipRadius.smBr,
                        ),
                        child: Text(_error!,
                            textAlign: TextAlign.center,
                            style: SipText.secondary.copyWith(color: SipColors.debt)),
                      ),
                    ],
                    const SizedBox(height: SipSpace.xl),
                    FilledButton(
                      onPressed: _busy ? null : _submit,
                      child: _busy
                          ? const SizedBox(
                              width: 20, height: 20, child: CircularProgressIndicator(strokeWidth: 2))
                          : const Text('Giriş yap'),
                    ),
                    const SizedBox(height: SipSpace.lg),
                    TextButton(
                      onPressed: () => setState(() => _showAdvanced = !_showAdvanced),
                      child: Text(_showAdvanced ? 'Gelişmişi gizle' : 'Gelişmiş'),
                    ),
                    if (_showAdvanced)
                      TextFormField(
                        controller: _baseUrl,
                        enabled: !_busy,
                        keyboardType: TextInputType.url,
                        decoration: const InputDecoration(
                          labelText: 'Sunucu adresi',
                          helperText: 'Geliştirme: http://10.0.2.2:8000/api/v1',
                        ),
                      ),
                  ],
                ),
              ),
            ),
          ),
        ),
      ),
    );
  }
}
