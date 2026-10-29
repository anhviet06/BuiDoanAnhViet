import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

import '../core/config.dart';
import '../core/theme.dart';
import 'brand.dart';

/// Khung chung cho các màn đăng nhập / đăng ký / OTP: logo, tiêu đề, nội dung cuộn được.
class AuthScaffold extends StatelessWidget {
  final String title;
  final String subtitle;
  final Widget child;
  final bool showBack;

  const AuthScaffold({super.key, required this.title, required this.subtitle, required this.child, this.showBack = false});

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    final text = Theme.of(context).textTheme;
    final dark = Theme.of(context).brightness == Brightness.dark;
    return Scaffold(
      extendBodyBehindAppBar: showBack,
      appBar: showBack ? AppBar(backgroundColor: Colors.transparent, scrolledUnderElevation: 0) : null,
      body: Container(
        decoration: BoxDecoration(
          gradient: LinearGradient(
            begin: Alignment.topCenter,
            end: Alignment.bottomCenter,
            colors: [dark ? const Color(0xFF0F1B3D) : const Color(0xFFDCE8FF), scheme.surface],
            stops: const [0, 0.55],
          ),
        ),
        child: SafeArea(
          child: Center(
            child: SingleChildScrollView(
              padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 24),
              child: ConstrainedBox(
                constraints: const BoxConstraints(maxWidth: 440),
                // Xuất hiện: mờ dần + trượt lên nhẹ (một lần)
                child: TweenAnimationBuilder<double>(
                  tween: Tween(begin: 0, end: 1),
                  duration: const Duration(milliseconds: 450),
                  curve: Curves.easeOutCubic,
                  builder: (context, v, inner) => Opacity(
                    opacity: v,
                    child: Transform.translate(offset: Offset(0, 16 * (1 - v)), child: inner),
                  ),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.stretch,
                    children: [
                      const Center(child: BrandLogo(size: 84)),
                      const SizedBox(height: 16),
                      Text(
                        AppConfig.appName,
                        textAlign: TextAlign.center,
                        style: text.labelLarge?.copyWith(color: scheme.primary, letterSpacing: 1.4, fontWeight: FontWeight.w700),
                      ),
                      const SizedBox(height: 8),
                      Text(
                        title,
                        textAlign: TextAlign.center,
                        style: text.headlineSmall?.copyWith(fontWeight: FontWeight.w700),
                      ),
                      const SizedBox(height: 8),
                      Text(
                        subtitle,
                        textAlign: TextAlign.center,
                        style: text.bodyMedium?.copyWith(color: scheme.onSurfaceVariant),
                      ),
                      const SizedBox(height: 24),
                      Card(
                        shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(AppRadius.xl),
                          side: BorderSide(color: scheme.outlineVariant),
                        ),
                        elevation: 0,
                        child: Padding(padding: const EdgeInsets.all(20), child: child),
                      ),
                    ],
                  ),
                ),
              ),
            ),
          ),
        ),
      ),
    );
  }
}

/// Ô nhập mật khẩu có nút hiện/ẩn.
class PasswordField extends StatefulWidget {
  final TextEditingController controller;
  final String label;
  final String? Function(String?)? validator;
  final TextInputAction textInputAction;
  final ValueChanged<String>? onSubmitted;
  final bool enabled;
  final FocusNode? focusNode;

  const PasswordField({
    super.key,
    required this.controller,
    this.label = 'Mật khẩu',
    this.validator,
    this.textInputAction = TextInputAction.done,
    this.onSubmitted,
    this.enabled = true,
    this.focusNode,
  });

  @override
  State<PasswordField> createState() => _PasswordFieldState();
}

class _PasswordFieldState extends State<PasswordField> {
  bool _obscure = true;

  @override
  Widget build(BuildContext context) {
    return TextFormField(
      controller: widget.controller,
      focusNode: widget.focusNode,
      enabled: widget.enabled,
      obscureText: _obscure,
      validator: widget.validator,
      textInputAction: widget.textInputAction,
      onFieldSubmitted: widget.onSubmitted,
      autofillHints: const [AutofillHints.password],
      decoration: InputDecoration(
        labelText: widget.label,
        prefixIcon: const Icon(Icons.lock_outline_rounded),
        suffixIcon: IconButton(
          tooltip: _obscure ? 'Hiện mật khẩu' : 'Ẩn mật khẩu',
          icon: Icon(_obscure ? Icons.visibility_outlined : Icons.visibility_off_outlined),
          onPressed: () => setState(() => _obscure = !_obscure),
        ),
      ),
    );
  }
}

/// Khung thông báo trong form (lỗi hoặc thông tin).
class MessageBanner extends StatelessWidget {
  final String message;
  final bool isError;
  final IconData? icon;
  final Widget? trailing;

  const MessageBanner({super.key, required this.message, this.isError = true, this.icon, this.trailing});

  @override
  Widget build(BuildContext context) {
    final base = isError ? StatusColors.of(context, 'suspicious') : Theme.of(context).colorScheme.primary;
    final fg = StatusColors.textColor(context, base);
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
      decoration: BoxDecoration(
        color: base.withValues(alpha: 0.1),
        borderRadius: BorderRadius.circular(AppRadius.md),
        border: Border.all(color: base.withValues(alpha: 0.3)),
      ),
      child: Row(
        children: [
          Icon(icon ?? (isError ? Icons.error_outline_rounded : Icons.info_outline_rounded), color: base, size: 22),
          const SizedBox(width: 10),
          Expanded(
            child: Text(
              message,
              style: TextStyle(color: fg, fontWeight: FontWeight.w500),
            ),
          ),
          ?trailing,
        ],
      ),
    );
  }
}

/// Nút chính có trạng thái đang xử lý.
class BusyButton extends StatelessWidget {
  final String label;
  final bool busy;
  final VoidCallback? onPressed;

  const BusyButton({super.key, required this.label, required this.busy, required this.onPressed});

  @override
  Widget build(BuildContext context) {
    return SizedBox(
      width: double.infinity,
      child: FilledButton(
        onPressed: busy ? null : onPressed,
        child: busy
            ? SizedBox(
                height: 22,
                width: 22,
                child: CircularProgressIndicator(strokeWidth: 2.5, color: Theme.of(context).colorScheme.onPrimary),
              )
            : Text(label),
      ),
    );
  }
}

/// Hiển thị mã OTP dạng 6 ô riêng, nhưng dữ liệu vẫn nằm ở MỘT ô nhập thật (trong suốt) phủ lên trên:
/// giữ nguyên bàn phím số, tự điền, validator và onFieldSubmitted.
class OtpBoxes extends StatelessWidget {
  final TextEditingController controller;
  final FocusNode focusNode;
  final bool enabled;
  final String? Function(String?)? validator;
  final ValueChanged<String>? onSubmitted;
  final int length;

  const OtpBoxes({
    super.key,
    required this.controller,
    required this.focusNode,
    this.enabled = true,
    this.validator,
    this.onSubmitted,
    this.length = 6,
  });

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    return Stack(
      children: [
        Positioned(
          left: 0,
          right: 0,
          top: 0,
          child: IgnorePointer(
            child: AnimatedBuilder(
              animation: Listenable.merge([controller, focusNode]),
              builder: (context, _) {
                final value = controller.text;
                return Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    for (var i = 0; i < length; i++)
                      Container(
                        width: 44,
                        height: 56,
                        alignment: Alignment.center,
                        decoration: BoxDecoration(
                          color: scheme.surfaceContainerHighest,
                          borderRadius: BorderRadius.circular(AppRadius.md),
                          border: Border.all(
                            color: focusNode.hasFocus && i == value.length.clamp(0, length - 1) ? scheme.primary : Colors.transparent,
                            width: 2,
                          ),
                        ),
                        child: Text(i < value.length ? value[i] : '', style: AppTypography.metric(context, size: 24)),
                      ),
                  ],
                );
              },
            ),
          ),
        ),
        TextFormField(
          key: const Key('otp_field'),
          controller: controller,
          focusNode: focusNode,
          enabled: enabled,
          autofocus: true,
          keyboardType: TextInputType.number,
          maxLength: length,
          showCursor: false,
          enableInteractiveSelection: false,
          inputFormatters: [FilteringTextInputFormatter.digitsOnly],
          autofillHints: const [AutofillHints.oneTimeCode],
          style: const TextStyle(color: Colors.transparent, fontSize: 24),
          decoration: const InputDecoration(
            counterText: '',
            filled: false,
            border: InputBorder.none,
            enabledBorder: InputBorder.none,
            focusedBorder: InputBorder.none,
            disabledBorder: InputBorder.none,
            contentPadding: EdgeInsets.symmetric(vertical: 16),
          ),
          validator: validator,
          onFieldSubmitted: onSubmitted,
        ),
      ],
    );
  }
}
