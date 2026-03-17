import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../services/api_service.dart';
import '../models/query_result.dart';
import 'auth_provider.dart';

/// A single chat message (user or assistant).
class ChatMsg {
  final String role; // 'user' | 'assistant'
  final String text;
  final String? imagePath; // local path if user sent a photo
  final String? imageDesc; // description sent to backend
  final List<MapMarker> markers;

  const ChatMsg({
    required this.role,
    required this.text,
    this.imagePath,
    this.imageDesc,
    this.markers = const [],
  });

  Map<String, dynamic> toApi() => {
        'role': role,
        'content': text,
        if (imageDesc != null) 'image_description': imageDesc,
      };
}

class ChatState {
  final List<ChatMsg> messages;
  final bool isLoading;
  final String? error;

  const ChatState({
    this.messages = const [],
    this.isLoading = false,
    this.error,
  });

  ChatState copyWith({
    List<ChatMsg>? messages,
    bool? isLoading,
    String? error,
  }) =>
      ChatState(
        messages: messages ?? this.messages,
        isLoading: isLoading ?? this.isLoading,
        error: error,
      );
}

class ChatNotifier extends StateNotifier<ChatState> {
  final ApiService _api;

  ChatNotifier(this._api) : super(const ChatState());

  Future<void> send(
    String text, {
    String? imagePath,
    String? imageDescription,
    double? latitude,
    double? longitude,
    String language = 'en',
  }) async {
    // Add user message
    final userMsg = ChatMsg(
      role: 'user',
      text: text,
      imagePath: imagePath,
      imageDesc: imageDescription,
    );
    final updated = [...state.messages, userMsg];
    state = state.copyWith(messages: updated, isLoading: true, error: null);

    try {
      final history = updated
          .where((m) => m.role == 'user' || m.role == 'assistant')
          .map((m) => m.toApi())
          .toList();
      // Remove last (it's the current message)
      if (history.isNotEmpty) history.removeLast();

      final data = await _api.sendChatMessage(
        message: text,
        history: history,
        imageDescription: imageDescription,
        latitude: latitude,
        longitude: longitude,
        language: language,
      );

      final markers = (data['map_markers'] as List? ?? [])
          .map((e) => MapMarker.fromJson(Map<String, dynamic>.from(e)))
          .toList();

      final assistantMsg = ChatMsg(
        role: 'assistant',
        text: data['reply'] ?? '',
        markers: markers,
      );

      state = state.copyWith(
        messages: [...state.messages, assistantMsg],
        isLoading: false,
      );
    } catch (e) {
      state = state.copyWith(
        isLoading: false,
        error: 'Failed to get response. Please try again.',
      );
    }
  }

  void clearChat() {
    state = const ChatState();
  }
}

final chatProvider = StateNotifierProvider<ChatNotifier, ChatState>((ref) {
  final api = ref.watch(apiServiceProvider);
  return ChatNotifier(api);
});
