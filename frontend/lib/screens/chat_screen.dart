import 'package:flutter/material.dart';
import 'package:geolocator/geolocator.dart';
import '../api/api_client.dart';
import '../theme/app_colors.dart';
import 'bakery_detail_screen.dart';

class _Recommendation {
  final int id;
  final String name;
  final String reason;
  _Recommendation({required this.id, required this.name, required this.reason});
}

class _Message {
  final bool isUser;
  final String text;
  final List<_Recommendation> recommendations;
  final bool isError;
  _Message({required this.isUser, required this.text, this.recommendations = const [], this.isError = false});
}

class ChatScreen extends StatefulWidget {
  const ChatScreen({super.key});

  @override
  State<ChatScreen> createState() => _ChatScreenState();
}

class _ChatScreenState extends State<ChatScreen> {
  final ApiClient _apiClient = ApiClient();
  final TextEditingController _inputController = TextEditingController();
  final ScrollController _scrollController = ScrollController();
  bool _isLoading = false;
  String? _lastUserMessage;
  double? _userLat;
  double? _userLon;

  final List<_Message> _messages = [
    _Message(
      isUser: false,
      text: '안녕하세요! 저는 대전 빵집 추천 AI예요 🍞\n좋아하는 빵이나 취향을 알려주시면 딱 맞는 빵집을 찾아드릴게요!\n\n예) "달달한 케이크류", "크루아상이나 담백한 빵", "앙금빵"',
    ),
  ];

  @override
  void initState() {
    super.initState();
    _fetchLocation();
  }

  Future<void> _fetchLocation() async {
    try {
      final permission = await Geolocator.checkPermission();
      if (permission == LocationPermission.always || permission == LocationPermission.whileInUse) {
        final pos = await Geolocator.getCurrentPosition(
          locationSettings: const LocationSettings(accuracy: LocationAccuracy.low),
        );
        if (mounted) setState(() { _userLat = pos.latitude; _userLon = pos.longitude; });
      }
    } catch (_) {}
  }

  @override
  void dispose() {
    _apiClient.dispose();
    _inputController.dispose();
    _scrollController.dispose();
    super.dispose();
  }

  Future<void> _retry() async {
    if (_lastUserMessage == null || _isLoading) return;
    if (_messages.last.isError) {
      setState(() => _messages.removeLast());
    }
    await _sendMessageWithText(_lastUserMessage!);
  }

  Future<void> _sendMessage() async {
    final text = _inputController.text.trim();
    if (text.isEmpty || _isLoading) return;
    _inputController.clear();
    await _sendMessageWithText(text);
  }

  Future<void> _sendMessageWithText(String text) async {
    _lastUserMessage = text;
    setState(() {
      if (_messages.isEmpty || _messages.last.text != text || !_messages.last.isUser) {
        _messages.add(_Message(isUser: true, text: text));
      }
      _isLoading = true;
    });
    _scrollToBottom();

    final response = await _apiClient.post<Map<String, dynamic>>(
      '/api/v1/chat',
      body: {
        'message': text,
        'history': _messages
            .where((m) => !m.recommendations.isNotEmpty || m.isUser)
            .skip(1)
            .map((m) => {'isUser': m.isUser, 'text': m.text})
            .toList(),
        if (_userLat != null) 'userLat': _userLat,
        if (_userLon != null) 'userLon': _userLon,
      },
      fromJson: (json) => json as Map<String, dynamic>,
    );

    if (!mounted) return;

    if (response.isSuccess && response.data != null) {
      final data = response.data!;
      final recommendations = (data['recommendations'] as List<dynamic>? ?? []).map((r) {
        final m = r as Map<String, dynamic>;
        return _Recommendation(
          id: m['id'] as int,
          name: m['name'] as String,
          reason: m['reason'] as String,
        );
      }).toList();
      setState(() {
        _messages.add(_Message(
          isUser: false,
          text: data['message'] as String? ?? '',
          recommendations: recommendations,
        ));
        _isLoading = false;
      });
    } else {
      setState(() {
        _messages.add(_Message(isUser: false, text: '죄송해요, 잠시 후 다시 시도해주세요.', isError: true));
        _isLoading = false;
      });
    }
    _scrollToBottom();
  }

  void _scrollToBottom() {
    Future.delayed(const Duration(milliseconds: 100), () {
      if (_scrollController.hasClients) {
        _scrollController.animateTo(
          _scrollController.position.maxScrollExtent,
          duration: const Duration(milliseconds: 300),
          curve: Curves.easeOut,
        );
      }
    });
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppColors.background,
      appBar: AppBar(
        backgroundColor: AppColors.surface,
        surfaceTintColor: Colors.transparent,
        elevation: 0,
        title: const Row(
          children: [
            Icon(Icons.auto_awesome_rounded, color: AppColors.caramel, size: 20),
            SizedBox(width: 8),
            Text('AI 빵집 추천', style: TextStyle(fontSize: 17, fontWeight: FontWeight.w700, color: AppColors.textPrimary)),
          ],
        ),
        bottom: const PreferredSize(
          preferredSize: Size.fromHeight(1),
          child: Divider(height: 1, color: AppColors.divider),
        ),
      ),
      body: Column(
        children: [
          Expanded(
            child: ListView.builder(
              controller: _scrollController,
              padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 16),
              itemCount: _messages.length + (_isLoading ? 1 : 0),
              itemBuilder: (context, index) {
                if (index == _messages.length) return _buildTypingIndicator();
                return _buildMessageBubble(_messages[index]);
              },
            ),
          ),
          _buildInputBar(),
        ],
      ),
    );
  }

  Widget _buildMessageBubble(_Message message) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 16),
      child: Column(
        crossAxisAlignment: message.isUser ? CrossAxisAlignment.end : CrossAxisAlignment.start,
        children: [
          if (!message.isUser) ...[
            const Row(
              children: [
                CircleAvatar(
                  radius: 14,
                  backgroundColor: AppColors.creamFill,
                  child: Icon(Icons.auto_awesome_rounded, size: 16, color: AppColors.caramel),
                ),
                SizedBox(width: 8),
                Text('AI 추천봇', style: TextStyle(fontSize: 12, fontWeight: FontWeight.w600, color: AppColors.textSec)),
              ],
            ),
            const SizedBox(height: 6),
          ],
          Row(
            mainAxisAlignment: message.isUser ? MainAxisAlignment.end : MainAxisAlignment.start,
            crossAxisAlignment: CrossAxisAlignment.end,
            children: [
              if (!message.isUser) const SizedBox(width: 36),
              Flexible(
                child: Container(
                  padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
                  decoration: BoxDecoration(
                    color: message.isUser ? AppColors.crustBrown : AppColors.surface,
                    borderRadius: BorderRadius.only(
                      topLeft: const Radius.circular(16),
                      topRight: const Radius.circular(16),
                      bottomLeft: Radius.circular(message.isUser ? 16 : 4),
                      bottomRight: Radius.circular(message.isUser ? 4 : 16),
                    ),
                    boxShadow: [
                      BoxShadow(color: Colors.black.withValues(alpha: 0.06), blurRadius: 8, offset: const Offset(0, 2)),
                    ],
                  ),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Text(
                        message.text,
                        style: TextStyle(
                          fontSize: 14,
                          height: 1.6,
                          color: message.isUser ? Colors.white : AppColors.textPrimary,
                        ),
                      ),
                      if (message.isError) ...[
                        const SizedBox(height: 8),
                        GestureDetector(
                          onTap: _retry,
                          child: Container(
                            padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
                            decoration: BoxDecoration(
                              color: AppColors.crustBrown,
                              borderRadius: BorderRadius.circular(12),
                            ),
                            child: const Row(
                              mainAxisSize: MainAxisSize.min,
                              children: [
                                Icon(Icons.refresh_rounded, size: 14, color: Colors.white),
                                SizedBox(width: 4),
                                Text('다시 시도', style: TextStyle(fontSize: 12, color: Colors.white, fontWeight: FontWeight.w600)),
                              ],
                            ),
                          ),
                        ),
                      ],
                    ],
                  ),
                ),
              ),
            ],
          ),
          if (message.recommendations.isNotEmpty) ...[
            const SizedBox(height: 10),
            Padding(
              padding: const EdgeInsets.only(left: 36),
              child: Column(
                children: message.recommendations.map((r) => _buildRecommendationCard(r)).toList(),
              ),
            ),
          ],
        ],
      ),
    );
  }

  Widget _buildRecommendationCard(_Recommendation r) {
    return GestureDetector(
      onTap: () => Navigator.push(
        context,
        MaterialPageRoute(builder: (_) => BakeryDetailScreen(bakeryId: r.id)),
      ),
      child: Container(
        margin: const EdgeInsets.only(bottom: 8),
        padding: const EdgeInsets.all(14),
        decoration: BoxDecoration(
          color: AppColors.surface,
          borderRadius: BorderRadius.circular(14),
          border: Border.all(color: AppColors.crustBrown.withValues(alpha: 0.3), width: 1.5),
          boxShadow: [
            BoxShadow(color: Colors.black.withValues(alpha: 0.05), blurRadius: 8, offset: const Offset(0, 2)),
          ],
        ),
        child: Row(
          children: [
            Container(
              width: 40, height: 40,
              decoration: BoxDecoration(color: AppColors.creamFill, borderRadius: BorderRadius.circular(10)),
              child: const Icon(Icons.storefront_rounded, size: 22, color: AppColors.crustBrown),
            ),
            const SizedBox(width: 12),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(r.name, style: const TextStyle(fontSize: 14, fontWeight: FontWeight.w700, color: AppColors.textPrimary)),
                  const SizedBox(height: 3),
                  Text(r.reason, style: const TextStyle(fontSize: 12, color: AppColors.textSec, height: 1.4)),
                ],
              ),
            ),
            const SizedBox(width: 8),
            const Icon(Icons.chevron_right_rounded, size: 20, color: AppColors.textHint),
          ],
        ),
      ),
    );
  }

  Widget _buildTypingIndicator() {
    return Padding(
      padding: const EdgeInsets.only(bottom: 16),
      child: Row(
        children: [
          const CircleAvatar(
            radius: 14,
            backgroundColor: AppColors.creamFill,
            child: Icon(Icons.auto_awesome_rounded, size: 16, color: AppColors.caramel),
          ),
          const SizedBox(width: 8),
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
            decoration: BoxDecoration(
              color: AppColors.surface,
              borderRadius: const BorderRadius.only(
                topLeft: Radius.circular(16), topRight: Radius.circular(16),
                bottomLeft: Radius.circular(4), bottomRight: Radius.circular(16),
              ),
              boxShadow: [BoxShadow(color: Colors.black.withValues(alpha: 0.06), blurRadius: 8, offset: const Offset(0, 2))],
            ),
            child: Row(
              mainAxisSize: MainAxisSize.min,
              children: List.generate(3, (i) => _Dot(delay: i * 200)),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildInputBar() {
    return Container(
      padding: EdgeInsets.fromLTRB(16, 10, 16, MediaQuery.of(context).padding.bottom + 10),
      decoration: BoxDecoration(
        color: AppColors.surface,
        border: const Border(top: BorderSide(color: AppColors.divider, width: 1)),
      ),
      child: Row(
        children: [
          Expanded(
            child: Container(
              decoration: BoxDecoration(
                color: AppColors.surfaceAlt,
                borderRadius: BorderRadius.circular(24),
                border: Border.all(color: AppColors.border),
              ),
              child: TextField(
                controller: _inputController,
                maxLines: null,
                keyboardType: TextInputType.multiline,
                textInputAction: TextInputAction.send,
                onSubmitted: (_) => _sendMessage(),
                decoration: const InputDecoration(
                  hintText: '좋아하는 빵 취향을 알려주세요',
                  hintStyle: TextStyle(color: AppColors.textHint, fontSize: 14),
                  border: InputBorder.none,
                  contentPadding: EdgeInsets.symmetric(horizontal: 16, vertical: 10),
                ),
                style: const TextStyle(fontSize: 14, color: AppColors.textPrimary),
              ),
            ),
          ),
          const SizedBox(width: 8),
          GestureDetector(
            onTap: _sendMessage,
            child: Container(
              width: 42, height: 42,
              decoration: const BoxDecoration(color: AppColors.crustBrown, shape: BoxShape.circle),
              child: const Icon(Icons.send_rounded, color: Colors.white, size: 18),
            ),
          ),
        ],
      ),
    );
  }
}

class _Dot extends StatefulWidget {
  final int delay;
  const _Dot({required this.delay});

  @override
  State<_Dot> createState() => _DotState();
}

class _DotState extends State<_Dot> with SingleTickerProviderStateMixin {
  late AnimationController _controller;
  late Animation<double> _anim;

  @override
  void initState() {
    super.initState();
    _controller = AnimationController(vsync: this, duration: const Duration(milliseconds: 600))
      ..repeat(reverse: true);
    _anim = Tween(begin: 0.4, end: 1.0).animate(
      CurvedAnimation(parent: _controller, curve: Curves.easeInOut),
    );
    Future.delayed(Duration(milliseconds: widget.delay), () {
      if (mounted) _controller.forward();
    });
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 3),
      child: AnimatedBuilder(
        animation: _anim,
        builder: (_, __) => Opacity(
          opacity: _anim.value,
          child: Container(
            width: 7, height: 7,
            decoration: const BoxDecoration(color: AppColors.textHint, shape: BoxShape.circle),
          ),
        ),
      ),
    );
  }
}
