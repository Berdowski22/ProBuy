import 'package:flutter/material.dart';

import '../services/auth_service.dart';
import 'authScreen.dart';

class ProfileScreen extends StatefulWidget {
  const ProfileScreen({super.key});

  @override
  State<ProfileScreen> createState() => _ProfileScreenState();
}

class _ProfileScreenState extends State<ProfileScreen> {
  final _formKey = GlobalKey<FormState>();
  final _nameController = TextEditingController();
  final _phoneController = TextEditingController();
  final _addressController = TextEditingController();
  final _authService = AuthService();

  bool _loading = true;
  bool _saving = false;

  @override
  void initState() {
    super.initState();
    _loadProfile();
  }

  @override
  void dispose() {
    _nameController.dispose();
    _phoneController.dispose();
    _addressController.dispose();
    super.dispose();
  }

  Future<void> _loadProfile() async {
    try {
      final profile = await _authService.getProfile();
      _nameController.text = (profile['name'] ??
              _authService.currentUser?.displayName ??
              '')
          .toString();
      _phoneController.text = (profile['phone'] ?? '').toString();
      _addressController.text = (profile['address'] ?? '').toString();
    } catch (e) {
      _showMessage('Profil yüklenemedi: $e');
    } finally {
      if (mounted) setState(() => _loading = false);
    }
  }

  void _showMessage(String text) {
    if (!mounted) return;
    ScaffoldMessenger.of(context)
        .showSnackBar(SnackBar(content: Text(text)));
  }

  Future<void> _save() async {
    if (!_formKey.currentState!.validate()) return;
    setState(() => _saving = true);
    try {
      await _authService.updateProfile(
        name: _nameController.text,
        phone: _phoneController.text,
        address: _addressController.text,
      );
      _showMessage('Profil güncellendi.');
    } on AuthException catch (e) {
      _showMessage(e.message);
    } catch (e) {
      _showMessage('Beklenmeyen bir hata oluştu: $e');
    } finally {
      if (mounted) setState(() => _saving = false);
    }
  }

  Future<void> _resetPassword() async {
    try {
      await _authService.sendPasswordReset();
      _showMessage('Şifre sıfırlama e-postası gönderildi.');
    } on AuthException catch (e) {
      _showMessage(e.message);
    }
  }

  Future<void> _logout() async {
    final navigator = Navigator.of(context);
    await _authService.logout();
    navigator.pushAndRemoveUntil(
      MaterialPageRoute(builder: (_) => const AuthScreen()),
      (_) => false,
    );
  }

  @override
  Widget build(BuildContext context) {
    final email = _authService.currentUser?.email ?? '';
    return Scaffold(
      appBar: AppBar(title: const Text('Profil')),
      body: _loading
          ? const Center(child: CircularProgressIndicator())
          : SingleChildScrollView(
              padding: const EdgeInsets.all(24),
              child: Form(
                key: _formKey,
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.stretch,
                  children: [
                    const Center(
                      child: CircleAvatar(
                        radius: 40,
                        child: Icon(Icons.person, size: 40),
                      ),
                    ),
                    const SizedBox(height: 24),
                    TextFormField(
                      initialValue: email,
                      enabled: false,
                      decoration: const InputDecoration(
                        labelText: 'E-posta',
                        prefixIcon: Icon(Icons.email_outlined),
                        border: OutlineInputBorder(),
                      ),
                    ),
                    const SizedBox(height: 16),
                    TextFormField(
                      controller: _nameController,
                      textInputAction: TextInputAction.next,
                      decoration: const InputDecoration(
                        labelText: 'Ad Soyad',
                        prefixIcon: Icon(Icons.person_outline),
                        border: OutlineInputBorder(),
                      ),
                      validator: (v) => (v == null || v.trim().isEmpty)
                          ? 'Ad soyad gerekli'
                          : null,
                    ),
                    const SizedBox(height: 16),
                    TextFormField(
                      controller: _phoneController,
                      keyboardType: TextInputType.phone,
                      textInputAction: TextInputAction.next,
                      decoration: const InputDecoration(
                        labelText: 'Telefon',
                        prefixIcon: Icon(Icons.phone_outlined),
                        border: OutlineInputBorder(),
                      ),
                      validator: (v) {
                        final value = v?.trim() ?? '';
                        if (value.isEmpty) return null;
                        if (!RegExp(r'^[0-9+\s()-]{7,20}$').hasMatch(value)) {
                          return 'Geçerli bir telefon girin';
                        }
                        return null;
                      },
                    ),
                    const SizedBox(height: 16),
                    TextFormField(
                      controller: _addressController,
                      minLines: 2,
                      maxLines: 4,
                      decoration: const InputDecoration(
                        labelText: 'Adres',
                        prefixIcon: Icon(Icons.home_outlined),
                        border: OutlineInputBorder(),
                      ),
                    ),
                    const SizedBox(height: 24),
                    FilledButton.icon(
                      icon: _saving
                          ? const SizedBox(
                              height: 18,
                              width: 18,
                              child: CircularProgressIndicator(strokeWidth: 2),
                            )
                          : const Icon(Icons.save),
                      label: const Text('Kaydet'),
                      onPressed: _saving ? null : _save,
                    ),
                    const SizedBox(height: 12),
                    OutlinedButton.icon(
                      icon: const Icon(Icons.lock_reset),
                      label: const Text('Şifre sıfırlama e-postası gönder'),
                      onPressed: _resetPassword,
                    ),
                    const SizedBox(height: 12),
                    TextButton.icon(
                      icon: const Icon(Icons.logout),
                      label: const Text('Çıkış Yap'),
                      onPressed: _logout,
                    ),
                  ],
                ),
              ),
            ),
    );
  }
}
