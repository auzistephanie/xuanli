import 'package:flutter/material.dart';

import '../../engine/profile_builder.dart';
import '../../models/profile.dart';
import '../../theme/xuanli_theme.dart';
import '../onboarding/birth_data_step.dart';
import '../onboarding/mbti_step.dart';
import 'synastry_screen.dart';

/// 同朋友合盤：輸入朋友出生資料 → MBTI → 合盤結果。朋友嘅資料**只喺呢個
/// widget 嘅記憶體**，計完即棄，唔寫入任何儲存（`StorageService` 完全唔 call）。
class PartnerFlow extends StatefulWidget {
  final Profile me;

  const PartnerFlow({super.key, required this.me});

  @override
  State<PartnerFlow> createState() => _PartnerFlowState();
}

class _PartnerFlowState extends State<PartnerFlow> {
  int _step = 0; // 0 出生資料、1 MBTI、2 結果

  BirthDataState _birthData = BirthDataState(
    isLunar: false,
    lunarDate: const LunarDateParts(year: 2000, month: 1, day: 1),
    birthDate: DateTime(2000, 1, 1),
    birthHour: 9,
    birthMinute: 0,
    birthTimeUnknown: false,
    birthPlace: '香港',
  );

  DateTime? _solarBirthDate;
  Profile? _friend;

  void _continueFromBirthData() {
    DateTime solarDate;
    try {
      solarDate = _birthData.toSolarDate();
    } on ArgumentError {
      ScaffoldMessenger.of(
        context,
      ).showSnackBar(const SnackBar(content: Text('呢個農曆日期唔存在，請重新選擇')));
      return;
    }
    setState(() {
      _solarBirthDate = solarDate;
      _step = 1;
    });
  }

  void _onMbti(String mbti) {
    setState(() {
      _friend = buildProfile(
        id: 'friend', // 只喺記憶體，唔會儲存
        name: '朋友',
        birthDate: _solarBirthDate!,
        birthHour: _birthData.birthHour,
        birthMinute: _birthData.birthMinute,
        birthPlace: _birthData.birthPlace,
        mbti: mbti,
      );
      _step = 2;
    });
  }

  void _back() {
    if (_step == 0) {
      Navigator.of(context).pop();
    } else {
      setState(() => _step -= 1);
    }
  }

  @override
  Widget build(BuildContext context) {
    final colors = context.xuanliColors;
    final title = switch (_step) {
      0 || 1 => '同朋友合盤',
      _ => '我哋嘅合盤',
    };
    return Scaffold(
      appBar: AppBar(
        title: Text(
          title,
          style: TextStyle(
            fontFamily: XuanLiFonts.serif,
            fontWeight: FontWeight.w700,
            fontSize: 16,
            color: colors.ink,
          ),
        ),
        centerTitle: true,
        backgroundColor: Colors.transparent,
        elevation: 0,
        iconTheme: IconThemeData(color: colors.ink60),
        leading: IconButton(
          icon: const Icon(Icons.arrow_back_ios_new, size: 18),
          tooltip: '返回',
          onPressed: _back,
        ),
      ),
      body: SafeArea(
        child: switch (_step) {
          0 => BirthDataStep(
            isLunar: _birthData.isLunar,
            isLeapMonth: _birthData.isLeapMonth,
            lunarDate: _birthData.lunarDate,
            birthDate: _birthData.birthDate,
            birthHour: _birthData.birthHour,
            birthMinute: _birthData.birthMinute,
            birthTimeUnknown: _birthData.birthTimeUnknown,
            birthPlace: _birthData.birthPlace,
            onChanged: (state) => setState(() => _birthData = state),
            onNext: _continueFromBirthData,
            title: '佢嘅出生一刻',
            subtitle: '輸入朋友嘅出生年月日時，即場計你哋嘅合盤。佢嘅資料唔會儲存，計完就冇。',
            showProgress: false,
          ),
          1 => MbtiStep(
            onDone: _onMbti,
            title: '佢嘅性格底色',
            subtitle: '揀朋友嘅 MBTI 類型（唔肯定可以問下佢）。',
            showProgress: false,
            allowQuiz: false,
          ),
          _ => SynastryScreen(
            me: widget.me,
            friend: _friend!,
            onTryAnother: () => setState(() {
              _step = 0;
              _friend = null;
              _solarBirthDate = null;
            }),
          ),
        },
      ),
    );
  }
}
