import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../../core/constants/app_colors.dart';
import '../../core/constants/app_spacing.dart';
import '../../core/constants/app_text_styles.dart';
import '../../providers/auth_provider.dart';

enum _AuthMode { login, register, verify, forgot, reset }

class AuthScreen extends StatefulWidget {
  const AuthScreen({super.key});

  @override
  State<AuthScreen> createState() => _AuthScreenState();
}

class _AuthScreenState extends State<AuthScreen> {
  final _formKey = GlobalKey<FormState>();
  final _nameController = TextEditingController();
  final _emailController = TextEditingController();
  final _passwordController = TextEditingController();
  final _confirmPasswordController = TextEditingController();
  final _codeController = TextEditingController();

  _AuthMode _mode = _AuthMode.login;
  bool _obscurePassword = true;
  String? _notice;

  @override
  void dispose() {
    _nameController.dispose();
    _emailController.dispose();
    _passwordController.dispose();
    _confirmPasswordController.dispose();
    _codeController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final auth = context.watch<AuthProvider>();
    final title = switch (_mode) {
      _AuthMode.login => 'Dang nhap Roamy',
      _AuthMode.register => 'Tao tai khoan',
      _AuthMode.verify => 'Xac thuc email',
      _AuthMode.forgot => 'Quen mat khau',
      _AuthMode.reset => 'Dat lai mat khau',
    };
    final subtitle = switch (_mode) {
      _AuthMode.login => 'Dang nhap de dong bo dia diem cua rieng ban.',
      _AuthMode.register => 'Tao tai khoan moi de su dung Roamy tren nhieu thiet bi.',
      _AuthMode.verify => 'Nhap ma 6 so da gui ve email cua ban.',
      _AuthMode.forgot => 'Nhap email de nhan ma dat lai mat khau.',
      _AuthMode.reset => 'Nhap ma 6 so va mat khau moi.',
    };

    return Scaffold(
      body: SafeArea(
        child: Center(
          child: SingleChildScrollView(
            padding: const EdgeInsets.all(AppSpacing.xl),
            child: ConstrainedBox(
              constraints: const BoxConstraints(maxWidth: 430),
              child: Form(
                key: _formKey,
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.stretch,
                  children: [
                    Image.asset(
                      'assets/logo.png',
                      height: 86,
                      errorBuilder: (_, _, _) => const Icon(
                        Icons.place_rounded,
                        color: AppColors.primary,
                        size: 72,
                      ),
                    ),
                    const SizedBox(height: 18),
                    Text(
                      title,
                      style: AppTextStyles.headline.copyWith(fontSize: 28),
                      textAlign: TextAlign.center,
                    ),
                    const SizedBox(height: 8),
                    Text(
                      subtitle,
                      style: AppTextStyles.body.copyWith(
                        color: AppColors.textSecondary,
                      ),
                      textAlign: TextAlign.center,
                    ),
                    const SizedBox(height: 28),
                    if (_notice != null) _MessageBox(message: _notice!),
                    if (auth.errorMessage != null)
                      _MessageBox(message: auth.errorMessage!, isError: true),
                    ..._fieldsForMode(),
                    const SizedBox(height: 18),
                    FilledButton(
                      onPressed: auth.isBusy ? null : () => _submit(auth),
                      child: auth.isBusy
                          ? const SizedBox(
                              height: 20,
                              width: 20,
                              child: CircularProgressIndicator(strokeWidth: 2),
                            )
                          : Text(_primaryLabel),
                    ),
                    if (_mode == _AuthMode.login) ...[
                      const SizedBox(height: 10),
                      OutlinedButton.icon(
                        onPressed: auth.isBusy ? null : () => _google(auth),
                        icon: const Icon(Icons.g_mobiledata_rounded),
                        label: const Text('Dang nhap bang Google'),
                      ),
                    ],
                    const SizedBox(height: 16),
                    _ModeLinks(
                      mode: _mode,
                      onModeChanged: _changeMode,
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

  List<Widget> _fieldsForMode() {
    final fields = <Widget>[];
    if (_mode == _AuthMode.register) {
      fields.add(
        _TextInput(
          controller: _nameController,
          label: 'Ten hien thi',
          icon: Icons.person_rounded,
          validator: _requiredMin2,
        ),
      );
    }

    fields.add(
      _TextInput(
        controller: _emailController,
        label: 'Email',
        icon: Icons.email_rounded,
        keyboardType: TextInputType.emailAddress,
        validator: _emailValidator,
      ),
    );

    if (_mode == _AuthMode.verify || _mode == _AuthMode.reset) {
      fields.add(
        _TextInput(
          controller: _codeController,
          label: 'Ma 6 so',
          icon: Icons.pin_rounded,
          keyboardType: TextInputType.number,
          validator: _codeValidator,
        ),
      );
    }

    if (_mode == _AuthMode.login ||
        _mode == _AuthMode.register ||
        _mode == _AuthMode.reset) {
      fields.add(
        _TextInput(
          controller: _passwordController,
          label: _mode == _AuthMode.reset ? 'Mat khau moi' : 'Mat khau',
          icon: Icons.lock_rounded,
          obscureText: _obscurePassword,
          suffix: IconButton(
            onPressed: () {
              setState(() => _obscurePassword = !_obscurePassword);
            },
            icon: Icon(
              _obscurePassword
                  ? Icons.visibility_rounded
                  : Icons.visibility_off_rounded,
            ),
          ),
          validator: _passwordValidator,
        ),
      );
    }

    if (_mode == _AuthMode.register || _mode == _AuthMode.reset) {
      fields.add(
        _TextInput(
          controller: _confirmPasswordController,
          label: 'Nhap lai mat khau',
          icon: Icons.lock_reset_rounded,
          obscureText: true,
          validator: _confirmPasswordValidator,
        ),
      );
    }
    return fields;
  }

  String get _primaryLabel => switch (_mode) {
    _AuthMode.login => 'Dang nhap',
    _AuthMode.register => 'Dang ky',
    _AuthMode.verify => 'Xac thuc',
    _AuthMode.forgot => 'Gui ma',
    _AuthMode.reset => 'Dat lai mat khau',
  };

  Future<void> _submit(AuthProvider auth) async {
    FocusScope.of(context).unfocus();
    if (!(_formKey.currentState?.validate() ?? false)) return;
    setState(() => _notice = null);
    final email = _emailController.text.trim();
    try {
      switch (_mode) {
        case _AuthMode.login:
          await auth.login(email, _passwordController.text);
        case _AuthMode.register:
          await auth.register(
            name: _nameController.text.trim(),
            email: email,
            password: _passwordController.text,
          );
        case _AuthMode.verify:
          await auth.verifyEmail(email, _codeController.text.trim());
        case _AuthMode.forgot:
          await auth.forgotPassword(email);
          _changeMode(_AuthMode.reset);
          setState(() => _notice = 'Neu email ton tai, ma dat lai mat khau da duoc gui.');
        case _AuthMode.reset:
          await auth.resetPassword(
            email: email,
            code: _codeController.text.trim(),
            password: _passwordController.text,
          );
      }
    } catch (_) {
      // AuthProvider exposes the message in the UI.
    }
  }

  Future<void> _google(AuthProvider auth) async {
    try {
      await auth.loginWithGoogle();
    } catch (_) {}
  }

  void _changeMode(_AuthMode mode) {
    setState(() {
      _mode = mode;
      _notice = null;
      _codeController.clear();
      _passwordController.clear();
      _confirmPasswordController.clear();
    });
  }

  String? _emailValidator(String? value) {
    final text = value?.trim() ?? '';
    if (text.isEmpty) return 'Vui long nhap email';
    if (!text.contains('@') || !text.contains('.')) return 'Email khong hop le';
    return null;
  }

  String? _requiredMin2(String? value) {
    if ((value ?? '').trim().length < 2) return 'Toi thieu 2 ky tu';
    return null;
  }

  String? _passwordValidator(String? value) {
    final text = value ?? '';
    if (text.length < 8) return 'Mat khau toi thieu 8 ky tu';
    if (!RegExp(r'[A-Za-z]').hasMatch(text) || !RegExp(r'\d').hasMatch(text)) {
      return 'Can co chu va so';
    }
    return null;
  }

  String? _confirmPasswordValidator(String? value) {
    if (value != _passwordController.text) return 'Mat khau khong khop';
    return null;
  }

  String? _codeValidator(String? value) {
    final text = value?.trim() ?? '';
    if (!RegExp(r'^\d{6}$').hasMatch(text)) return 'Nhap dung ma 6 so';
    return null;
  }
}

class _TextInput extends StatelessWidget {
  const _TextInput({
    required this.controller,
    required this.label,
    required this.icon,
    this.keyboardType,
    this.obscureText = false,
    this.suffix,
    this.validator,
  });

  final TextEditingController controller;
  final String label;
  final IconData icon;
  final TextInputType? keyboardType;
  final bool obscureText;
  final Widget? suffix;
  final String? Function(String?)? validator;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 12),
      child: TextFormField(
        controller: controller,
        keyboardType: keyboardType,
        obscureText: obscureText,
        validator: validator,
        decoration: InputDecoration(
          labelText: label,
          prefixIcon: Icon(icon),
          suffixIcon: suffix,
        ),
      ),
    );
  }
}

class _ModeLinks extends StatelessWidget {
  const _ModeLinks({required this.mode, required this.onModeChanged});

  final _AuthMode mode;
  final ValueChanged<_AuthMode> onModeChanged;

  @override
  Widget build(BuildContext context) {
    return Wrap(
      alignment: WrapAlignment.center,
      spacing: 8,
      runSpacing: 8,
      children: [
        if (mode != _AuthMode.login)
          TextButton(
            onPressed: () => onModeChanged(_AuthMode.login),
            child: const Text('Dang nhap'),
          ),
        if (mode != _AuthMode.register)
          TextButton(
            onPressed: () => onModeChanged(_AuthMode.register),
            child: const Text('Dang ky'),
          ),
        if (mode == _AuthMode.login)
          TextButton(
            onPressed: () => onModeChanged(_AuthMode.forgot),
            child: const Text('Quen mat khau'),
          ),
        TextButton(
          onPressed: () => onModeChanged(_AuthMode.verify),
          child: const Text('Nhap ma xac thuc'),
        ),
      ],
    );
  }
}

class _MessageBox extends StatelessWidget {
  const _MessageBox({required this.message, this.isError = false});

  final String message;
  final bool isError;

  @override
  Widget build(BuildContext context) {
    return Container(
      margin: const EdgeInsets.only(bottom: 14),
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: isError
            ? Colors.red.withValues(alpha: 0.08)
            : AppColors.primary.withValues(alpha: 0.08),
        borderRadius: BorderRadius.circular(14),
        border: Border.all(
          color: isError
              ? Colors.red.withValues(alpha: 0.18)
              : AppColors.primary.withValues(alpha: 0.18),
        ),
      ),
      child: Text(
        message,
        style: AppTextStyles.caption.copyWith(
          color: isError ? Colors.red.shade700 : AppColors.primaryDark,
        ),
      ),
    );
  }
}
