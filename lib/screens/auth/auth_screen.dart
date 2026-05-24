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
      _AuthMode.login => 'Đăng nhập Roamy',
      _AuthMode.register => 'Tạo tài khoản',
      _AuthMode.verify => 'Xác thực email',
      _AuthMode.forgot => 'Quên mật khẩu',
      _AuthMode.reset => 'Đặt lại mật khẩu',
    };
    final subtitle = switch (_mode) {
      _AuthMode.login => 'Đăng nhập để đồng bộ địa điểm của riêng bạn.',
      _AuthMode.register =>
        'Tạo tài khoản mới để dùng Roamy trên nhiều thiết bị.',
      _AuthMode.verify => 'Nhập mã 6 số đã gửi về email của bạn.',
      _AuthMode.forgot => 'Nhập email để nhận mã đặt lại mật khẩu.',
      _AuthMode.reset => 'Nhập mã 6 số và mật khẩu mới.',
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
                    const _AuthBrandMark(),
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
                        label: const Text('Đăng nhập bằng Google'),
                      ),
                    ],
                    const SizedBox(height: 16),
                    _ModeLinks(mode: _mode, onModeChanged: _changeMode),
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
          label: 'Tên hiển thị',
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
          label: 'Mã 6 số',
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
          label: _mode == _AuthMode.reset ? 'Mật khẩu mới' : 'Mật khẩu',
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
          label: 'Nhập lại mật khẩu',
          icon: Icons.lock_reset_rounded,
          obscureText: true,
          validator: _confirmPasswordValidator,
        ),
      );
    }
    return fields;
  }

  String get _primaryLabel => switch (_mode) {
    _AuthMode.login => 'Đăng nhập',
    _AuthMode.register => 'Đăng ký',
    _AuthMode.verify => 'Xác thực',
    _AuthMode.forgot => 'Gửi mã',
    _AuthMode.reset => 'Đặt lại mật khẩu',
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
          setState(() {
            _notice = 'Nếu email tồn tại, mã đặt lại mật khẩu đã được gửi.';
          });
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
    if (text.isEmpty) return 'Vui lòng nhập email';
    if (!text.contains('@') || !text.contains('.')) return 'Email không hợp lệ';
    return null;
  }

  String? _requiredMin2(String? value) {
    if ((value ?? '').trim().length < 2) return 'Tối thiểu 2 ký tự';
    return null;
  }

  String? _passwordValidator(String? value) {
    final text = value ?? '';
    if (text.length < 8) return 'Mật khẩu tối thiểu 8 ký tự';
    if (!RegExp(r'[A-Za-z]').hasMatch(text) || !RegExp(r'\d').hasMatch(text)) {
      return 'Cần có chữ và số';
    }
    return null;
  }

  String? _confirmPasswordValidator(String? value) {
    if (value != _passwordController.text) return 'Mật khẩu không khớp';
    return null;
  }

  String? _codeValidator(String? value) {
    final text = value?.trim() ?? '';
    if (!RegExp(r'^\d{6}$').hasMatch(text)) return 'Nhập đúng mã 6 số';
    return null;
  }
}

class _AuthBrandMark extends StatelessWidget {
  const _AuthBrandMark();

  @override
  Widget build(BuildContext context) {
    return Center(
      child: Container(
        width: 74,
        height: 74,
        decoration: BoxDecoration(
          color: AppColors.primarySoft,
          borderRadius: BorderRadius.circular(24),
          border: Border.all(color: AppColors.primary.withValues(alpha: 0.18)),
          boxShadow: [
            BoxShadow(
              color: AppColors.primary.withValues(alpha: 0.12),
              blurRadius: 22,
              offset: const Offset(0, 10),
            ),
          ],
        ),
        child: const Icon(
          Icons.travel_explore_rounded,
          color: AppColors.primary,
          size: 38,
        ),
      ),
    );
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
            child: const Text('Đăng nhập'),
          ),
        if (mode != _AuthMode.register)
          TextButton(
            onPressed: () => onModeChanged(_AuthMode.register),
            child: const Text('Đăng ký'),
          ),
        if (mode == _AuthMode.login)
          TextButton(
            onPressed: () => onModeChanged(_AuthMode.forgot),
            child: const Text('Quên mật khẩu'),
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
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: isError
            ? Colors.red.withValues(alpha: 0.07)
            : AppColors.primary.withValues(alpha: 0.08),
        borderRadius: BorderRadius.circular(18),
        border: Border.all(
          color: isError
              ? Colors.red.withValues(alpha: 0.22)
              : AppColors.primary.withValues(alpha: 0.2),
        ),
      ),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Container(
            width: 34,
            height: 34,
            decoration: BoxDecoration(
              color: isError
                  ? Colors.red.withValues(alpha: 0.12)
                  : AppColors.primary.withValues(alpha: 0.12),
              borderRadius: BorderRadius.circular(12),
            ),
            child: Icon(
              isError
                  ? Icons.error_outline_rounded
                  : Icons.check_circle_outline_rounded,
              color: isError ? Colors.red.shade700 : AppColors.primaryDark,
              size: 20,
            ),
          ),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  isError ? 'Không thành công' : 'Thông báo',
                  style: AppTextStyles.title.copyWith(
                    fontSize: 14,
                    color: isError
                        ? Colors.red.shade700
                        : AppColors.primaryDark,
                  ),
                ),
                const SizedBox(height: 3),
                Text(
                  message,
                  style: AppTextStyles.caption.copyWith(
                    color: isError
                        ? Colors.red.shade700
                        : AppColors.primaryDark,
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}
