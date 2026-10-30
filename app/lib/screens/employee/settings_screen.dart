import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../../core/theme.dart';
import '../../providers/face_login_provider.dart';
import '../../providers/settings_provider.dart';
import '../auth/face_login_screens.dart';
import '../../widgets/common_widgets.dart';
import '../../widgets/state_views.dart';
import '../../widgets/ui_kit.dart';

/// Cài đặt cá nhân: cỡ chữ, chế độ sáng/tối, màu chủ đạo, tông nền. Áp dụng ngay, lưu trên máy theo tài khoản.
class PersonalSettingsScreen extends StatelessWidget {
  const PersonalSettingsScreen({super.key});

  @override
  Widget build(BuildContext context) {
    final s = context.watch<SettingsProvider>();
    final prefs = s.prefs;
    final scheme = Theme.of(context).colorScheme;
    final text = Theme.of(context).textTheme;

    return Scaffold(
      appBar: AppBar(title: const Text('Cài đặt')),
      body: SafeArea(
        child: ListView(
          padding: const EdgeInsets.all(16),
          children: [
            // Xem trước: phản ánh ngay cỡ chữ, màu chủ đạo, nền đã chọn
            Card(
              child: Padding(
                padding: const EdgeInsets.all(16),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text('Xem trước', style: AppTypography.subtitle(context, size: 12)),
                    const SizedBox(height: 6),
                    Text('Ca sáng · 06:00 - 12:00', key: const Key('settings_preview'), style: text.titleMedium),
                    const SizedBox(height: 4),
                    Text('Đây là cỡ chữ và màu bạn đang chọn.', style: AppTypography.subtitle(context, size: 14)),
                    const SizedBox(height: 10),
                    Wrap(spacing: 8, children: [
                      Pill(label: 'Đúng giờ', color: StatusColors.of(context, 'on-time')),
                      Pill(label: 'Màu chủ đạo', color: scheme.primary),
                    ]),
                  ],
                ),
              ),
            ),
            const SectionHeader(title: 'Cỡ chữ', padding: EdgeInsets.fromLTRB(4, 20, 4, 8)),
            Wrap(
              spacing: 8,
              runSpacing: 8,
              children: [
                for (var i = 0; i < fontScaleOptions.length; i++)
                  ChoiceChip(
                    key: Key('settings_font_$i'),
                    label: Text(fontScaleOptions[i].$1),
                    selected: prefs.fontScale == fontScaleOptions[i].$2,
                    onSelected: (_) => s.setFontScale(fontScaleOptions[i].$2),
                  ),
              ],
            ),
            const SectionHeader(title: 'Chế độ hiển thị', padding: EdgeInsets.fromLTRB(4, 20, 4, 8)),
            Wrap(
              spacing: 8,
              runSpacing: 8,
              children: [
                for (final m in const [(ThemeMode.system, 'Theo hệ thống'), (ThemeMode.light, 'Sáng'), (ThemeMode.dark, 'Tối')])
                  ChoiceChip(
                    key: Key('settings_mode_${m.$1.name}'),
                    label: Text(m.$2),
                    selected: prefs.themeMode == m.$1,
                    onSelected: (_) => s.setThemeMode(m.$1),
                  ),
              ],
            ),
            const SectionHeader(title: 'Màu chủ đạo', padding: EdgeInsets.fromLTRB(4, 20, 4, 8)),
            Wrap(
              spacing: 12,
              runSpacing: 12,
              children: [
                for (var i = 0; i < AppPalettes.accents.length; i++)
                  _Swatch(
                    key: Key('settings_accent_$i'),
                    label: AppPalettes.accents[i].name,
                    color: Theme.of(context).brightness == Brightness.dark ? AppPalettes.accents[i].dark : AppPalettes.accents[i].light,
                    selected: prefs.accent == i,
                    onTap: () => s.setAccent(i),
                  ),
              ],
            ),
            const SectionHeader(title: 'Màu nền', padding: EdgeInsets.fromLTRB(4, 20, 4, 8)),
            Wrap(
              spacing: 12,
              runSpacing: 12,
              children: [
                for (var i = 0; i < AppPalettes.backgrounds.length; i++)
                  _Swatch(
                    key: Key('settings_bg_$i'),
                    label: AppPalettes.backgrounds[i].name,
                    color: Theme.of(context).brightness == Brightness.dark ? AppPalettes.backgrounds[i].dark : AppPalettes.backgrounds[i].light,
                    selected: prefs.background == i,
                    outlined: true,
                    onTap: () => s.setBackground(i),
                  ),
              ],
            ),
            const SectionHeader(title: 'Bảo mật', padding: EdgeInsets.fromLTRB(4, 20, 4, 8)),
            _FaceSwitch(),
            const SizedBox(height: 24),
            SizedBox(
              width: double.infinity,
              child: OutlinedButton.icon(
                key: const Key('settings_reset'),
                onPressed: prefs.isDefault
                    ? null
                    : () async {
                        await s.reset();
                        if (context.mounted) showAppSnack(context, 'Đã khôi phục mặc định');
                      },
                icon: const Icon(Icons.restart_alt_rounded),
                label: const Text('Khôi phục mặc định'),
              ),
            ),
            const SizedBox(height: 8),
            Text('Cài đặt chỉ lưu trên máy này, theo tài khoản của bạn.', textAlign: TextAlign.center, style: AppTypography.subtitle(context, size: 12)),
          ],
        ),
      ),
    );
  }
}

/// Ô chọn màu tròn kèm tên; đang chọn thì có viền và dấu tick.
class _Swatch extends StatelessWidget {
  final String label;
  final Color color;
  final bool selected;
  final bool outlined;
  final VoidCallback onTap;

  const _Swatch({super.key, required this.label, required this.color, required this.selected, required this.onTap, this.outlined = false});

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    return Semantics(
      button: true,
      selected: selected,
      label: label,
      child: InkWell(
        borderRadius: BorderRadius.circular(16),
        onTap: onTap,
        child: SizedBox(
          width: 76,
          child: Padding(
            padding: const EdgeInsets.symmetric(vertical: 4),
            child: Column(
              children: [
                Container(
                  width: 48,
                  height: 48,
                  decoration: BoxDecoration(
                    color: color,
                    shape: BoxShape.circle,
                    border: Border.all(
                      color: selected ? scheme.onSurface : (outlined ? scheme.outlineVariant : Colors.transparent),
                      width: selected ? 3 : 1.5,
                    ),
                  ),
                  child: selected ? Icon(Icons.check_rounded, color: AppTheme.onColor(color)) : null,
                ),
                const SizedBox(height: 4),
                Text(label, textAlign: TextAlign.center, maxLines: 2, overflow: TextOverflow.ellipsis, style: const TextStyle(fontSize: 12)),
              ],
            ),
          ),
        ),
      ),
    );
  }
}

/// Công tắc bật/tắt đăng nhập bằng khuôn mặt trên máy này. Ghi rõ giới hạn: chỉ xác nhận người sống.
class _FaceSwitch extends StatelessWidget {
  @override
  Widget build(BuildContext context) {
    final face = context.watch<FaceLoginProvider>();
    final on = face.enabledForCurrentUser;
    return Card(
      child: SwitchListTile(
        key: const Key('settings_face_switch'),
        value: on,
        title: const Text('Đăng nhập bằng khuôn mặt', style: TextStyle(fontWeight: FontWeight.w600)),
        subtitle: const Text('Chỉ xác nhận người sống trên máy này đã đăng nhập bằng OTP, không nhận diện danh tính.'),
        onChanged: (v) async {
          if (v) {
            await Navigator.of(context).push<bool>(MaterialPageRoute(builder: (_) => const FaceEnableScreen()));
          } else {
            final ok = await confirmDialog(
              context,
              title: 'Tắt đăng nhập bằng khuôn mặt?',
              message: 'Lần sau bạn cần đăng nhập bằng mật khẩu và OTP.',
              confirmLabel: 'Tắt',
              destructive: true,
            );
            if (ok) await face.disable();
          }
        },
      ),
    );
  }
}
