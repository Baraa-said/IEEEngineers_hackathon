import 'dart:io';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:image_picker/image_picker.dart';
import 'package:speech_to_text/speech_to_text.dart' as stt;
import '../core/theme.dart';
import '../providers/chat_provider.dart';
import '../providers/language_provider.dart';

class AiChatScreen extends ConsumerStatefulWidget {
  const AiChatScreen({super.key});

  @override
  ConsumerState<AiChatScreen> createState() => _AiChatScreenState();
}

class _AiChatScreenState extends ConsumerState<AiChatScreen> {
  final _textCtl = TextEditingController();
  final _scrollCtl = ScrollController();
  final _picker = ImagePicker();
  final _speech = stt.SpeechToText();

  bool _listening = false;
  File? _attachedImage;

  @override
  void dispose() {
    _textCtl.dispose();
    _scrollCtl.dispose();
    super.dispose();
  }

  void _scrollToBottom() {
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (_scrollCtl.hasClients) {
        _scrollCtl.animateTo(
          _scrollCtl.position.maxScrollExtent + 120,
          duration: const Duration(milliseconds: 300),
          curve: Curves.easeOut,
        );
      }
    });
  }

  Future<void> _send() async {
    final text = _textCtl.text.trim();
    if (text.isEmpty && _attachedImage == null) return;

    final lang = ref.read(languageProvider);
    String? imageDesc;

    if (_attachedImage != null) {
      imageDesc =
          'User attached a photo from ${_attachedImage!.path.split('/').last}';
    }

    _textCtl.clear();
    final img = _attachedImage;
    setState(() => _attachedImage = null);

    await ref.read(chatProvider.notifier).send(
          text.isNotEmpty ? text : 'What can you tell me about this image?',
          imagePath: img?.path,
          imageDescription: imageDesc,
          language: lang,
        );
    _scrollToBottom();
  }

  Future<void> _pickImage(ImageSource source) async {
    final xf = await _picker.pickImage(source: source, imageQuality: 70, maxWidth: 1024);
    if (xf != null) setState(() => _attachedImage = File(xf.path));
  }

  void _showImageOptions() {
    final lang = ref.read(languageProvider);
    final tr = (String k) => S.t(k, lang);
    showModalBottomSheet(
      context: context,
      builder: (_) => SafeArea(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            ListTile(
              leading: const Icon(Icons.camera_alt),
              title: Text(tr('chat_camera')),
              onTap: () {
                Navigator.pop(context);
                _pickImage(ImageSource.camera);
              },
            ),
            ListTile(
              leading: const Icon(Icons.photo_library),
              title: Text(tr('chat_gallery')),
              onTap: () {
                Navigator.pop(context);
                _pickImage(ImageSource.gallery);
              },
            ),
          ],
        ),
      ),
    );
  }

  Future<void> _toggleVoice() async {
    if (_listening) {
      await _speech.stop();
      setState(() => _listening = false);
      return;
    }

    final available = await _speech.initialize(
      onStatus: (s) {
        if (s == 'done' || s == 'notListening') {
          setState(() => _listening = false);
        }
      },
      onError: (_) => setState(() => _listening = false),
    );
    if (!available) return;

    final lang = ref.read(languageProvider);
    setState(() => _listening = true);
    await _speech.listen(
      onResult: (r) {
        _textCtl.text = r.recognizedWords;
        _textCtl.selection =
            TextSelection.collapsed(offset: _textCtl.text.length);
      },
      localeId: lang == 'ar' ? 'ar_SA' : 'en_US',
      listenMode: stt.ListenMode.dictation,
    );
  }

  @override
  Widget build(BuildContext context) {
    final chat = ref.watch(chatProvider);
    final lang = ref.watch(languageProvider);
    final tr = (String k) => S.t(k, lang);
    final isDark = Theme.of(context).brightness == Brightness.dark;

    // Scroll when new messages arrive
    ref.listen<ChatState>(chatProvider, (_, __) => _scrollToBottom());

    return Directionality(
      textDirection: lang == 'ar' ? TextDirection.rtl : TextDirection.ltr,
      child: Scaffold(
        appBar: AppBar(
          title: Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              Container(
                padding: const EdgeInsets.all(6),
                decoration: BoxDecoration(
                  color: AppTheme.accentColor.withOpacity(0.15),
                  borderRadius: BorderRadius.circular(8),
                ),
                child: Icon(Icons.smart_toy, color: AppTheme.accentColor, size: 20),
              ),
              const SizedBox(width: 8),
              Text(tr('ai_agent')),
            ],
          ),
          actions: [
            if (chat.messages.isNotEmpty)
              IconButton(
                icon: const Icon(Icons.delete_outline),
                tooltip: tr('chat_clear'),
                onPressed: () => ref.read(chatProvider.notifier).clearChat(),
              ),
          ],
        ),
        body: Column(
          children: [
            // Messages
            Expanded(
              child: chat.messages.isEmpty
                  ? _buildWelcome(tr, isDark)
                  : ListView.builder(
                      controller: _scrollCtl,
                      padding: const EdgeInsets.fromLTRB(12, 12, 12, 8),
                      itemCount: chat.messages.length + (chat.isLoading ? 1 : 0),
                      itemBuilder: (_, i) {
                        if (i == chat.messages.length) return _buildTyping();
                        return _MessageBubble(
                          msg: chat.messages[i],
                          isDark: isDark,
                          lang: lang,
                          tr: tr,
                        );
                      },
                    ),
            ),

            // Error
            if (chat.error != null)
              Container(
                width: double.infinity,
                padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 6),
                color: Colors.red.withOpacity(0.1),
                child: Text(chat.error!,
                    style: TextStyle(color: Colors.red[400], fontSize: 12)),
              ),

            // Attached image preview
            if (_attachedImage != null)
              Container(
                height: 80,
                margin: const EdgeInsets.fromLTRB(12, 4, 12, 0),
                child: Stack(
                  children: [
                    ClipRRect(
                      borderRadius: BorderRadius.circular(10),
                      child: Image.file(_attachedImage!,
                          height: 80, width: 80, fit: BoxFit.cover),
                    ),
                    Positioned(
                      top: 2,
                      right: 2,
                      child: GestureDetector(
                        onTap: () => setState(() => _attachedImage = null),
                        child: Container(
                          decoration: const BoxDecoration(
                            color: Colors.black54,
                            shape: BoxShape.circle,
                          ),
                          padding: const EdgeInsets.all(3),
                          child: const Icon(Icons.close,
                              color: Colors.white, size: 14),
                        ),
                      ),
                    ),
                  ],
                ),
              ),

            // Input bar
            Container(
              padding: EdgeInsets.fromLTRB(
                  8, 8, 8, MediaQuery.of(context).padding.bottom + 8),
              decoration: BoxDecoration(
                color: Theme.of(context).cardColor,
                boxShadow: [
                  BoxShadow(
                      color: Colors.black12,
                      blurRadius: 6,
                      offset: const Offset(0, -2))
                ],
              ),
              child: Row(
                children: [
                  // Photo button
                  IconButton(
                    icon: const Icon(Icons.add_photo_alternate_outlined),
                    color: Colors.grey[600],
                    iconSize: 22,
                    onPressed: _showImageOptions,
                  ),
                  // Text field
                  Expanded(
                    child: Container(
                      constraints: const BoxConstraints(maxHeight: 120),
                      decoration: BoxDecoration(
                        color: isDark ? Colors.grey[800] : Colors.grey[100],
                        borderRadius: BorderRadius.circular(22),
                      ),
                      child: TextField(
                        controller: _textCtl,
                        maxLines: null,
                        textInputAction: TextInputAction.newline,
                        decoration: InputDecoration(
                          hintText: tr('chat_hint'),
                          border: InputBorder.none,
                          contentPadding: const EdgeInsets.symmetric(
                              horizontal: 16, vertical: 10),
                        ),
                      ),
                    ),
                  ),
                  const SizedBox(width: 4),
                  // Voice button
                  GestureDetector(
                    onTap: _toggleVoice,
                    child: Container(
                      width: 40,
                      height: 40,
                      decoration: BoxDecoration(
                        color: _listening
                            ? Colors.red.withOpacity(0.15)
                            : Colors.transparent,
                        shape: BoxShape.circle,
                      ),
                      child: Icon(
                        _listening ? Icons.mic : Icons.mic_none,
                        color: _listening ? Colors.red : Colors.grey[600],
                        size: 22,
                      ),
                    ),
                  ),
                  // Send button
                  GestureDetector(
                    onTap: chat.isLoading ? null : _send,
                    child: Container(
                      width: 40,
                      height: 40,
                      decoration: BoxDecoration(
                        color: AppTheme.accentColor,
                        shape: BoxShape.circle,
                      ),
                      child: Icon(
                        Icons.send,
                        color: Colors.white,
                        size: 18,
                      ),
                    ),
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildWelcome(String Function(String) tr, bool isDark) {
    final suggestions = [
      tr('q1'),
      tr('q2'),
      tr('q3'),
      tr('q4'),
    ];
    return Center(
      child: SingleChildScrollView(
        padding: const EdgeInsets.all(32),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Container(
              padding: const EdgeInsets.all(20),
              decoration: BoxDecoration(
                color: AppTheme.accentColor.withOpacity(0.1),
                shape: BoxShape.circle,
              ),
              child: Icon(Icons.smart_toy,
                  color: AppTheme.accentColor, size: 48),
            ),
            const SizedBox(height: 16),
            Text(tr('ai_agent'),
                style:
                    const TextStyle(fontSize: 20, fontWeight: FontWeight.bold)),
            const SizedBox(height: 6),
            Text(tr('chat_welcome'),
                textAlign: TextAlign.center,
                style: TextStyle(color: Colors.grey[500], fontSize: 13)),
            const SizedBox(height: 8),
            Row(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                _InputChip(icon: Icons.keyboard, label: tr('chat_text')),
                const SizedBox(width: 8),
                _InputChip(icon: Icons.mic, label: tr('chat_voice')),
                const SizedBox(width: 8),
                _InputChip(icon: Icons.photo_camera, label: tr('chat_photo')),
              ],
            ),
            const SizedBox(height: 24),
            Align(
              alignment: AlignmentDirectional.centerStart,
              child: Text(tr('chat_try'),
                  style: TextStyle(
                      fontWeight: FontWeight.w600,
                      color: Colors.grey[600],
                      fontSize: 12)),
            ),
            const SizedBox(height: 8),
            ...suggestions.map((s) => Padding(
                  padding: const EdgeInsets.only(bottom: 6),
                  child: InkWell(
                    borderRadius: BorderRadius.circular(10),
                    onTap: () {
                      _textCtl.text = s;
                      _send();
                    },
                    child: Container(
                      width: double.infinity,
                      padding: const EdgeInsets.symmetric(
                          horizontal: 14, vertical: 10),
                      decoration: BoxDecoration(
                        border: Border.all(
                            color: isDark
                                ? Colors.grey[700]!
                                : Colors.grey[300]!),
                        borderRadius: BorderRadius.circular(10),
                      ),
                      child: Row(
                        children: [
                          Icon(Icons.lightbulb_outline,
                              size: 16, color: Colors.grey[500]),
                          const SizedBox(width: 8),
                          Expanded(
                              child: Text(s,
                                  style: const TextStyle(fontSize: 13))),
                          Icon(Icons.arrow_forward_ios,
                              size: 12, color: Colors.grey[400]),
                        ],
                      ),
                    ),
                  ),
                )),
          ],
        ),
      ),
    );
  }

  Widget _buildTyping() {
    return Align(
      alignment: AlignmentDirectional.centerStart,
      child: Container(
        margin: const EdgeInsets.only(bottom: 8),
        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
        decoration: BoxDecoration(
          color: Colors.grey.withOpacity(0.12),
          borderRadius: BorderRadius.circular(16),
        ),
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            SizedBox(
                width: 18,
                height: 18,
                child:
                    CircularProgressIndicator(strokeWidth: 2, color: AppTheme.accentColor)),
            const SizedBox(width: 10),
            Text('Aid NAV AI ...',
                style: TextStyle(color: Colors.grey[600], fontSize: 13)),
          ],
        ),
      ),
    );
  }
}

// ---- Message Bubble ----

class _MessageBubble extends StatelessWidget {
  final ChatMsg msg;
  final bool isDark;
  final String lang;
  final String Function(String) tr;

  const _MessageBubble({
    required this.msg,
    required this.isDark,
    required this.lang,
    required this.tr,
  });

  @override
  Widget build(BuildContext context) {
    final isUser = msg.role == 'user';
    return Align(
      alignment:
          isUser ? AlignmentDirectional.centerEnd : AlignmentDirectional.centerStart,
      child: Container(
        constraints:
            BoxConstraints(maxWidth: MediaQuery.of(context).size.width * 0.8),
        margin: const EdgeInsets.only(bottom: 8),
        child: Column(
          crossAxisAlignment:
              isUser ? CrossAxisAlignment.end : CrossAxisAlignment.start,
          children: [
            // Image preview if user sent one
            if (msg.imagePath != null)
              Padding(
                padding: const EdgeInsets.only(bottom: 4),
                child: ClipRRect(
                  borderRadius: BorderRadius.circular(12),
                  child: Image.file(
                    File(msg.imagePath!),
                    width: 180,
                    height: 180,
                    fit: BoxFit.cover,
                    errorBuilder: (_, __, ___) => const SizedBox.shrink(),
                  ),
                ),
              ),
            // Text bubble
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
              decoration: BoxDecoration(
                color: isUser
                    ? AppTheme.accentColor
                    : (isDark ? Colors.grey[800] : Colors.grey[100]),
                borderRadius: BorderRadius.only(
                  topLeft: const Radius.circular(16),
                  topRight: const Radius.circular(16),
                  bottomLeft: Radius.circular(isUser ? 16 : 4),
                  bottomRight: Radius.circular(isUser ? 4 : 16),
                ),
              ),
              child: isUser
                  ? Text(msg.text,
                      style: const TextStyle(color: Colors.white, fontSize: 14))
                  : Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Row(
                          mainAxisSize: MainAxisSize.min,
                          children: [
                            Icon(Icons.smart_toy,
                                size: 14, color: AppTheme.accentColor),
                            const SizedBox(width: 4),
                            Text('Aid NAV AI',
                                style: TextStyle(
                                    fontSize: 11,
                                    fontWeight: FontWeight.w600,
                                    color: AppTheme.accentColor)),
                          ],
                        ),
                        const SizedBox(height: 4),
                        SelectableText(msg.text,
                            style: const TextStyle(fontSize: 14, height: 1.45)),
                      ],
                    ),
            ),
            // Map markers
            if (msg.markers.isNotEmpty)
              Padding(
                padding: const EdgeInsets.only(top: 4),
                child: InkWell(
                  borderRadius: BorderRadius.circular(8),
                  onTap: () => Navigator.pushNamed(context, '/map'),
                  child: Container(
                    padding:
                        const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
                    decoration: BoxDecoration(
                      color: AppTheme.primaryColor.withOpacity(0.1),
                      borderRadius: BorderRadius.circular(8),
                    ),
                    child: Row(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        Icon(Icons.map, size: 14, color: AppTheme.primaryColor),
                        const SizedBox(width: 4),
                        Text(
                          '${msg.markers.length} ${tr('chat_locations')}',
                          style: TextStyle(
                              fontSize: 12,
                              color: AppTheme.primaryColor,
                              fontWeight: FontWeight.w500),
                        ),
                        const SizedBox(width: 2),
                        Icon(Icons.chevron_right,
                            size: 14, color: AppTheme.primaryColor),
                      ],
                    ),
                  ),
                ),
              ),
          ],
        ),
      ),
    );
  }
}

// ---- Small chip showing input type ----

class _InputChip extends StatelessWidget {
  final IconData icon;
  final String label;
  const _InputChip({required this.icon, required this.label});

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 5),
      decoration: BoxDecoration(
        color: AppTheme.accentColor.withOpacity(0.08),
        borderRadius: BorderRadius.circular(20),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(icon, size: 14, color: AppTheme.accentColor),
          const SizedBox(width: 4),
          Text(label,
              style: TextStyle(
                  fontSize: 11,
                  color: AppTheme.accentColor,
                  fontWeight: FontWeight.w500)),
        ],
      ),
    );
  }
}
