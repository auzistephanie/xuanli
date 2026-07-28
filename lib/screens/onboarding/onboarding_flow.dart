import 'package:flutter/material.dart';

import '../../services/storage_service.dart';
import '../tab_shell.dart';
import 'birth_data_step.dart';
import 'mbti_step.dart';
import 'profile_card_step.dart';

/// 3 步 onboarding 嘅殼：擁有跨步驟嘅共用 state（出生資料 + MBTI），
/// 逐步遞畀 [BirthDataStep]/[MbtiStep]/[ProfileCardStep]，行完就
/// navigate 去 [TabShell]（`Navigator.pushReplacement`，唔靠
/// `_AppBootstrap` 嘅 FutureBuilder 自動重新路由）。
class OnboardingFlow extends StatefulWidget {
  const OnboardingFlow({super.key});

  @override
  State<OnboardingFlow> createState() => _OnboardingFlowState();
}

class _OnboardingFlowState extends State<OnboardingFlow> {
  int _step = 0;

  BirthDataState _birthData = BirthDataState(
    isLunar: false,
    birthDate: DateTime(2000, 1, 1),
    birthHour: 9,
    birthMinute: 0,
    birthTimeUnknown: false,
    birthPlace: '香港',
  );

  String? _mbti;

  Future<void> _finish() async {
    // [ProfileCardStep] 剛 save 咗個 profile 落 StorageService（先至 call
    // 呢個 callback）——同 [_AppBootstrap] 用返一樣嘅
    // StorageService().loadPrimaryProfile() 攞返嚟遞畀 [TabShell]，
    // 唔想改 [ProfileCardStep] 個 onSaved 簽名（會連累佢自己嘅 widget test）。
    final profile = await StorageService().loadPrimaryProfile();
    if (!mounted || profile == null) return;
    Navigator.of(context).pushReplacement(
      MaterialPageRoute(builder: (_) => TabShell(profile: profile)),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: SafeArea(
        child: switch (_step) {
          0 => BirthDataStep(
              isLunar: _birthData.isLunar,
              birthDate: _birthData.birthDate,
              birthHour: _birthData.birthHour,
              birthMinute: _birthData.birthMinute,
              birthTimeUnknown: _birthData.birthTimeUnknown,
              birthPlace: _birthData.birthPlace,
              onChanged: (s) => setState(() => _birthData = s),
              onNext: () => setState(() => _step = 1),
            ),
          1 => MbtiStep(
              onDone: (mbti) => setState(() {
                _mbti = mbti;
                _step = 2;
              }),
            ),
          _ => ProfileCardStep(
              name: '我',
              birthDate: _birthData.birthDate,
              birthHour: _birthData.birthHour,
              birthMinute: _birthData.birthMinute,
              birthPlace: _birthData.birthPlace,
              mbti: _mbti!,
              onSaved: _finish,
            ),
        },
      ),
    );
  }
}
