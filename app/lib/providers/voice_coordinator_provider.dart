import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../core/di/service_locator.dart';
import '../core/contracts/i_database_service.dart';
import '../services/voice_service_coordinator.dart';
import '../services/voice_recognition_engine.dart';
import '../services/tts_service.dart';
import '../services/voice/entity_disambiguation_service.dart';
import '../services/voice/voice_delete_service.dart';
import '../services/voice/voice_modify_service.dart';
import '../services/voice_navigation_service.dart';
import '../services/voice/voice_intent_router.dart';
import '../services/voice_feedback_system.dart';

/// Riverpod provider for VoiceServiceCoordinator
///
/// Wraps the feature-rich VoiceServiceCoordinator with Riverpod's
/// ChangeNotifierProvider for reactive state management.
final voiceServiceCoordinatorProvider = ChangeNotifierProvider<VoiceServiceCoordinator>((ref) {
  final ttsService = TTSService.instance;
  // 通过服务定位器获取数据库服务
  final databaseService = sl<IDatabaseService>();

  final coordinator = VoiceServiceCoordinator(
    recognitionEngine: VoiceRecognitionEngine(),
    ttsService: ttsService,
    disambiguationService: EntityDisambiguationService(),
    deleteService: VoiceDeleteService(),
    modifyService: VoiceModifyService(),
    navigationService: VoiceNavigationService(),
    intentRouter: VoiceIntentRouter(),
    feedbackSystem: VoiceFeedbackSystem(ttsService: ttsService),
    databaseService: databaseService,
  );

  // Ensure proper cleanup when provider is disposed
  ref.onDispose(() {
    coordinator.dispose();
  });

  return coordinator;
});

/// Derived provider for voice session state
///
/// Provides reactive access to the current session state
final voiceSessionStateProvider = Provider<VoiceSessionState>((ref) {
  return ref.watch(voiceServiceCoordinatorProvider).sessionState;
});

/// Derived provider for current intent type
///
/// Provides reactive access to the current intent being processed
final voiceIntentTypeProvider = Provider<VoiceIntentType?>((ref) {
  return ref.watch(voiceServiceCoordinatorProvider).currentIntentType;
});

/// Derived provider for active session status
///
/// Returns true if there's an active voice session
final hasActiveSessionProvider = Provider<bool>((ref) {
  return ref.watch(voiceServiceCoordinatorProvider).hasActiveSession;
});

/// Derived provider for command history
///
/// Provides reactive access to the list of recent voice commands
final commandHistoryProvider = Provider<List<VoiceCommand>>((ref) {
  return ref.watch(voiceServiceCoordinatorProvider).commandHistory;
});
