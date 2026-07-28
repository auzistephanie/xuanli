import 'package:flutter/material.dart';

import '../../models/settings.dart';
import '../../services/storage_service.dart';
import '../../services/theme_mode_controller.dart';
import '../../theme/xuanli_theme.dart';
import '../onboarding/onboarding_flow.dart';

/// 設定頁（spec §9.8）：深色模式、每朝通知偏好（UI/storage only，唔真
/// 係排通知——Phase 3 先起 `flutter_local_notifications` 排程）、JSON
/// 匯出/匯入（stub，同 Tab B 日曆整合一樣要等有 device 先做真整合）、
/// 重新做 onboarding、免責聲明、關於。冇 required constructor 參數——
/// 由 `TabShell` 嘅 ⚙ icon 撳入嚟，自己內部靠 [StorageService] 讀寫。
class SettingsScreen extends StatefulWidget {
  const SettingsScreen({super.key});

  @override
  State<SettingsScreen> createState() => _SettingsScreenState();
}

class _SettingsScreenState extends State<SettingsScreen> {
  AppSettings? _settings;

  @override
  void initState() {
    super.initState();
    _load();
  }

  Future<void> _load() async {
    final settings = await StorageService().loadSettings();
    if (!mounted) return;
    setState(() => _settings = settings);
  }

  Future<void> _save(AppSettings next) async {
    await StorageService().saveSettings(next);
    if (!mounted) return;
    setState(() => _settings = next);
  }

  Future<void> _setThemeMode(ThemeMode mode) async {
    themeModeController.value = mode;
    await _save(_settings!.copyWith(themeMode: mode));
  }

  Future<void> _setNotificationsEnabled(bool enabled) async {
    await _save(_settings!.copyWith(notificationsEnabled: enabled));
  }

  Future<void> _pickNotificationTime() async {
    final current = _settings!;
    final picked = await showTimePicker(
      context: context,
      initialTime: TimeOfDay(hour: current.notificationHour, minute: current.notificationMinute),
    );
    if (picked == null) return;
    await _save(current.copyWith(notificationHour: picked.hour, notificationMinute: picked.minute));
  }

  void _stub(String feature) {
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(content: Text('$feature — 之後有 device 先驗證')),
    );
  }

  Future<void> _confirmRedoOnboarding() async {
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (dialogContext) => AlertDialog(
        title: const Text('重新做 Onboarding'),
        content: const Text('呢個動作會清除你而家嘅命理檔案，需要重新輸入出生資料。確定要繼續？'),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(dialogContext).pop(false),
            child: const Text('取消'),
          ),
          TextButton(
            onPressed: () => Navigator.of(dialogContext).pop(true),
            child: const Text('確定'),
          ),
        ],
      ),
    );
    if (confirmed != true) return;
    await StorageService().clearProfiles();
    if (!mounted) return;
    Navigator.of(context).pushAndRemoveUntil(
      MaterialPageRoute(builder: (_) => const OnboardingFlow()),
      (route) => false,
    );
  }

  void _infoDialog(String title, Widget content) {
    showDialog<void>(
      context: context,
      builder: (dialogContext) => AlertDialog(
        title: Text(title),
        content: content,
        actions: [
          TextButton(
            onPressed: () => Navigator.of(dialogContext).pop(),
            child: const Text('知道喇'),
          ),
        ],
      ),
    );
  }

  void _showDisclaimer() {
    _infoDialog(
      '免責聲明',
      const SingleChildScrollView(
        child: Text(
          '玄曆所有推薦內容（包括命理分、宜忌、活動建議、行事曆提示等）都係基於傳統曆法同你嘅個人命理'
          '資料自動生成，僅供參考、帶少少玄學生活趣味，並唔代表任何形式嘅專業意見。\n\n'
          '健康、法律、財務等重要決定，請以專業人士（醫生、律師、持牌顧問等）意見為準——玄曆嘅健康'
          '相關內容只會話你邊一日狀態較順，唔會亦唔應該被理解為「唔好睇醫生」嘅建議；財務／投資相關'
          '內容亦只提供宜忌方向，唔構成具體買賣建議。\n\n'
          '你嘅出生資料同命理檔案全部只存喺你部機度，玄曆唔會上傳、分享或者用嚟做任何其他用途。',
        ),
      ),
    );
  }

  void _showAbout() {
    _infoDialog(
      '關於玄曆',
      const Text(
        '玄曆 XuanLi\n版本 1.0.0\n\n'
        '中國傳統擇日 × 個人八字五行 × 紫微 × MBTI，全離線運作，你嘅出生資料唔會離開部機。',
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final colors = context.xuanliColors;
    final settings = _settings;
    return Scaffold(
      body: SafeArea(
        child: Column(
          children: [
            _buildHeader(colors),
            Expanded(
              child: settings == null
                  ? const Center(child: CircularProgressIndicator())
                  : SingleChildScrollView(
                      padding: const EdgeInsets.fromLTRB(18, 4, 18, 24),
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.stretch,
                        children: [
                          _sectionLabel(colors, '外觀'),
                          _themeModeRow(colors, settings),
                          const SizedBox(height: 12),
                          _sectionLabel(colors, '每朝通知'),
                          _notificationCard(colors, settings),
                          const SizedBox(height: 12),
                          _sectionLabel(colors, '資料'),
                          _actionTile(colors, '匯出 JSON', () => _stub('匯出（分享）')),
                          _actionTile(colors, '匯入 JSON', () => _stub('匯入（揀檔）')),
                          _actionTile(colors, '重新做 Onboarding', _confirmRedoOnboarding),
                          const SizedBox(height: 12),
                          _sectionLabel(colors, '關於'),
                          _actionTile(colors, '免責聲明全文', _showDisclaimer),
                          _actionTile(colors, '關於玄曆', _showAbout),
                        ],
                      ),
                    ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildHeader(XuanLiColors colors) {
    return Padding(
      padding: const EdgeInsets.fromLTRB(10, 6, 10, 6),
      child: Row(
        children: [
          GestureDetector(
            onTap: () => Navigator.of(context).pop(),
            child: Padding(
              padding: const EdgeInsets.all(8),
              child: Text('‹', style: TextStyle(fontSize: 22, color: colors.ink60)),
            ),
          ),
          const SizedBox(width: 4),
          Text(
            '設定',
            style: TextStyle(
              fontFamily: XuanLiFonts.serif,
              fontWeight: FontWeight.w700,
              fontSize: 16,
              color: colors.ink,
            ),
          ),
        ],
      ),
    );
  }

  Widget _sectionLabel(XuanLiColors colors, String label) {
    return Padding(
      padding: const EdgeInsets.fromLTRB(4, 0, 0, 8),
      child: Text(
        label,
        style: TextStyle(fontSize: 11, letterSpacing: 2, fontWeight: FontWeight.w700, color: colors.gold),
      ),
    );
  }

  Widget _themeModeRow(XuanLiColors colors, AppSettings settings) {
    Widget chip(String label, ThemeMode mode) {
      final selected = settings.themeMode == mode;
      return Expanded(
        child: GestureDetector(
          onTap: () => _setThemeMode(mode),
          child: Container(
            margin: const EdgeInsets.symmetric(horizontal: 3),
            padding: const EdgeInsets.symmetric(vertical: 10),
            decoration: BoxDecoration(
              color: selected ? colors.gold : colors.cardSurface,
              borderRadius: BorderRadius.circular(20),
              border: Border.all(color: selected ? colors.gold : colors.ink12),
            ),
            alignment: Alignment.center,
            child: Text(
              label,
              style: TextStyle(
                fontSize: 12.5,
                fontWeight: selected ? FontWeight.w700 : FontWeight.w400,
                color: selected ? colors.ink : colors.ink60,
              ),
            ),
          ),
        ),
      );
    }

    return Row(
      children: [
        chip('跟系統', ThemeMode.system),
        chip('常開', ThemeMode.dark),
        chip('常關', ThemeMode.light),
      ],
    );
  }

  Widget _notificationCard(XuanLiColors colors, AppSettings settings) {
    return Material(
      color: colors.cardSurface,
      borderRadius: BorderRadius.circular(XuanLiRadii.card),
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 14),
        child: Column(
          children: [
            SwitchListTile(
              dense: true,
              visualDensity: VisualDensity.compact,
              contentPadding: EdgeInsets.zero,
              title: Text('每朝推送', style: TextStyle(fontSize: 13, color: colors.ink)),
              value: settings.notificationsEnabled,
              activeThumbColor: colors.gold,
              onChanged: _setNotificationsEnabled,
            ),
            if (settings.notificationsEnabled)
              ListTile(
                dense: true,
                visualDensity: VisualDensity.compact,
                contentPadding: EdgeInsets.zero,
                title: Text('推送時間', style: TextStyle(fontSize: 13, color: colors.ink)),
                trailing: Text(
                  '${settings.notificationHour.toString().padLeft(2, '0')}:'
                  '${settings.notificationMinute.toString().padLeft(2, '0')}',
                  style: TextStyle(fontSize: 13, fontWeight: FontWeight.w700, color: colors.gold),
                ),
                onTap: _pickNotificationTime,
              ),
          ],
        ),
      ),
    );
  }

  Widget _actionTile(XuanLiColors colors, String label, VoidCallback onTap) {
    return Container(
      margin: const EdgeInsets.only(bottom: 6),
      child: Material(
        color: colors.cardSurface,
        borderRadius: BorderRadius.circular(XuanLiRadii.card),
        child: ListTile(
          dense: true,
          visualDensity: VisualDensity.compact,
          title: Text(label, style: TextStyle(fontSize: 13, color: colors.ink)),
          trailing: Text('›', style: TextStyle(fontSize: 16, color: colors.ink30)),
          onTap: onTap,
        ),
      ),
    );
  }
}
