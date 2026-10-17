import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import '../../../services/api_service.dart';
import '../../../services/telegram_service.dart';
import '../../../theme/app_theme.dart';

class BroadcastTab extends StatefulWidget {
  final ApiService api;
  final TelegramService? tg;
  final bool isDark;
  final List<dynamic> users;
  final List<dynamic> quizzes;
  final List<dynamic> groups;
  final Map<String, dynamic> stats;
  final String adminId;
  final String adminName;
  final String adminUsername;
  final VoidCallback? onRefreshAll;
  final Function(String msg, {bool isError}) onShowToast;

  const BroadcastTab({
    super.key,
    required this.api,
    this.tg,
    required this.isDark,
    this.users = const [],
    this.quizzes = const [],
    this.groups = const [],
    this.stats = const {},
    this.adminId = '',
    this.adminName = 'Admin',
    this.adminUsername = 'admin',
    this.onRefreshAll,
    required this.onShowToast,
  });

  @override
  State<BroadcastTab> createState() => _BroadcastTabState();
}

class _BroadcastTabState extends State<BroadcastTab> {
  // Text & Content Controllers
  final _msgCtrl = TextEditingController();
  final _titleCtrl = TextEditingController();
  final _mediaUrlCtrl = TextEditingController();
  final _testChatIdCtrl = TextEditingController();

  // Content configuration
  String _selectedType = 'text'; // 'text', 'photo', 'document', 'quiz', 'button'
  String? _selectedQuizId;
  final List<Map<String, String>> _inlineButtons = [];

  // Target Audience & Filters
  String _targetAudience = 'all'; // 'all', 'specific', 'segments', 'plans'
  String _filterUserStatus = 'All Users';
  String _filterPlanType = 'All Plans';
  String _filterLanguage = 'All Languages';
  String _filterLastActive = 'Any Time';

  // Scheduling
  bool _isScheduled = false;
  DateTime _scheduledDateTime = DateTime.now().add(const Duration(hours: 1));

  // Specific Users Selection
  final Set<int> _selectedSpecificUserIds = {};

  // Operational states
  bool _isSending = false;
  bool _isTesting = false;
  bool _isLoadingHistory = false;

  // History & Metrics Data
  List<Map<String, dynamic>> _broadcastHistory = [];
  Map<String, dynamic> _kpiStats = {};

  // Saved Drafts
  final List<Map<String, dynamic>> _drafts = [];

  @override
  void initState() {
    super.initState();
    _testChatIdCtrl.text = widget.adminId.isNotEmpty ? widget.adminId : '';
    _loadBroadcastHistory();
    _loadStats();
  }

  @override
  void dispose() {
    _msgCtrl.dispose();
    _titleCtrl.dispose();
    _mediaUrlCtrl.dispose();
    _testChatIdCtrl.dispose();
    super.dispose();
  }

  Future<void> _loadBroadcastHistory() async {
    setState(() => _isLoadingHistory = true);
    try {
      final list = await widget.api.getBroadcastHistory();
      if (mounted) {
        setState(() {
          _broadcastHistory = List<Map<String, dynamic>>.from(list);
        });
      }
    } catch (_) {
      if (mounted) {
        setState(() => _broadcastHistory = []);
      }
    } finally {
      if (mounted) setState(() => _isLoadingHistory = false);
    }
  }

  Future<void> _loadStats() async {
    try {
      final s = await widget.api.getBroadcastStats();
      if (mounted && s.isNotEmpty) {
        setState(() => _kpiStats = s);
      }
    } catch (_) {}
  }


  // Formatting toolbar helpers
  void _insertFormatting(String prefix, String suffix) {
    final text = _msgCtrl.text;
    final selection = _msgCtrl.selection;
    if (!selection.isValid || selection.isCollapsed) {
      final newText = '$text$prefix$suffix';
      _msgCtrl.value = TextEditingValue(
        text: newText,
        selection: TextSelection.collapsed(offset: newText.length - suffix.length),
      );
    } else {
      final selectedText = text.substring(selection.start, selection.end);
      final newText = text.replaceRange(selection.start, selection.end, '$prefix$selectedText$suffix');
      _msgCtrl.value = TextEditingValue(
        text: newText,
        selection: TextSelection(
          baseOffset: selection.start + prefix.length,
          extentOffset: selection.start + prefix.length + selectedText.length,
        ),
      );
    }
    setState(() {});
  }

  void _insertVariable(String variable) {
    final text = _msgCtrl.text;
    final selection = _msgCtrl.selection;
    final insertPos = selection.isValid ? selection.start : text.length;
    final newText = text.replaceRange(insertPos, insertPos, variable);
    _msgCtrl.value = TextEditingValue(
      text: newText,
      selection: TextSelection.collapsed(offset: insertPos + variable.length),
    );
    setState(() {});
  }

  void _openEmojiPicker() {
    showModalBottomSheet(
      context: context,
      backgroundColor: widget.isDark ? AppTheme.darkCard : Colors.white,
      shape: const RoundedRectangleBorder(borderRadius: BorderRadius.vertical(top: Radius.circular(16))),
      builder: (ctx) {
        final emojis = ['🔥', '✅', '🚀', '📢', '🌟', '📝', '📰', '💎', '⚠️', '🎯', '✨', '💡', '🎉', '🏆', '📌', '⚡'];
        return Padding(
          padding: const EdgeInsets.all(20),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text('Quick Emojis', style: GoogleFonts.inter(fontWeight: FontWeight.w700, fontSize: 15)),
              const SizedBox(height: 14),
              Wrap(
                spacing: 12,
                runSpacing: 12,
                children: emojis.map((e) {
                  return InkWell(
                    onTap: () {
                      _insertVariable(e);
                      Navigator.pop(ctx);
                    },
                    borderRadius: BorderRadius.circular(8),
                    child: Container(
                      padding: const EdgeInsets.all(10),
                      decoration: BoxDecoration(
                        color: widget.isDark ? const Color(0xFF1E293B) : const Color(0xFFF1F5F9),
                        borderRadius: BorderRadius.circular(8),
                      ),
                      child: Text(e, style: const TextStyle(fontSize: 22)),
                    ),
                  );
                }).toList(),
              ),
            ],
          ),
        );
      },
    );
  }

  void _openAddButtonDialog() {
    final labelCtrl = TextEditingController();
    final urlCtrl = TextEditingController(text: 'https://t.me/Examplayer_bot?start=');

    showDialog(
      context: context,
      builder: (ctx) => AlertDialog(
        backgroundColor: widget.isDark ? AppTheme.darkCard : Colors.white,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(14)),
        title: Text('Add Telegram Inline Button', style: GoogleFonts.inter(fontWeight: FontWeight.w700, fontSize: 16)),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            TextField(
              controller: labelCtrl,
              decoration: const InputDecoration(
                labelText: 'Button Label',
                hintText: 'e.g. 🚀 अभी टेस्ट शुरू करें',
                prefixIcon: Icon(Icons.smart_button_rounded, size: 20),
              ),
            ),
            const SizedBox(height: 14),
            TextField(
              controller: urlCtrl,
              decoration: const InputDecoration(
                labelText: 'Button URL',
                hintText: 'https://t.me/... or website link',
                prefixIcon: Icon(Icons.link_rounded, size: 20),
              ),
            ),
          ],
        ),
        actions: [
          TextButton(onPressed: () => Navigator.pop(ctx), child: const Text('Cancel')),
          ElevatedButton(
            style: ElevatedButton.styleFrom(backgroundColor: const Color(0xFF4F46E5)),
            onPressed: () {
              if (labelCtrl.text.trim().isEmpty || urlCtrl.text.trim().isEmpty) {
                widget.onShowToast('Please provide both button title and URL', isError: true);
                return;
              }
              setState(() {
                _inlineButtons.add({
                  'text': labelCtrl.text.trim(),
                  'url': urlCtrl.text.trim(),
                });
              });
              Navigator.pop(ctx);
              widget.onShowToast('Inline button added!');
            },
            child: const Text('Add Button', style: TextStyle(color: Colors.white)),
          ),
        ],
      ),
    );
  }

  void _openTemplatesModal() {
    final templates = [
      {
        'title': '🔥 New Mock Test Released',
        'desc': 'Announcement for upcoming or newly published examinations',
        'body':
            '🔥 *नया टेस्ट आ गया है!*\n\n'
            '*Bihar Special - 50 प्रश्न*\n'
            '✅ GK + Current Affairs\n'
            '✅ BPSC TRE 4.0 के लिए महत्वपूर्ण\n'
            '✅ अभी टेस्ट दें और अपनी तैयारी को मजबूत करें!',
        'buttons': [
          {'text': '🚀 अभी टेस्ट शुरू करें', 'url': 'https://t.me/Examplayer_bot?start=quiz_bihar'}
        ],
      },
      {
        'title': '📰 Daily Current Affairs Capsule',
        'desc': 'Daily morning PDF and key highlights announcement',
        'body':
            '📰 *Daily Current Affairs Capsule - Live*\n\n'
            'आज के सभी प्रमुख राष्ट्रीय और अंतर्राष्ट्रीय समसामयिकी तथ्य तैयार हैं।\n'
            '• मुख्य नियुक्तियां व पुरस्कार\n'
            '• राष्ट्रीय खेल व आर्थिक समीक्षा\n'
            '• अभ्यास के लिए 10 प्रश्न\n\n'
            'पीडीएफ पढ़ने व टेस्ट देने के लिए नीचे दिए गए बटन पर क्लिक करें!',
        'buttons': [
          {'text': '📖 Read PDF Notes', 'url': 'https://t.me/Examplayer_bot?start=ca_today'}
        ],
      },
      {
        'title': '🎯 All India Ranking Challenge',
        'desc': 'Sunday mega mock test series with leaderboard prizes',
        'body':
            '🎯 *ALL INDIA SUNDAY MEGA MOCK TEST*\n\n'
            'हजारों छात्रों के साथ लाइव प्रतिस्पर्धा करें और अपनी ऑल इंडिया रैंक जानें!\n'
            '⏱️ कुल समय: 60 मिनट\n'
            '📊 नेगेटिव मार्किंग: 1/3\n'
            '🏆 टॉप 10 छात्रों को मिलेगा फ्री प्रीमियम एक्सेस!',
        'buttons': [
          {'text': '📝 Enter Mega Mock', 'url': 'https://t.me/Examplayer_bot?start=sunday_mock'}
        ],
      },
      {
        'title': '💎 Special Festive Offer / 50% OFF',
        'desc': 'Discount campaign for Premium & VIP subscriptions',
        'body':
            '💎 *MEGA SAVINGS: FLAT 50% OFF ON VIP PASS!*\n\n'
            'सभी सरकारी परीक्षाओं के लिए अनलिमिटेड टेस्ट सीरीज, विषयवार नोट्स और पर्सनलाइज्ड परफॉर्मेंस एनालिसिस अनलॉक करें।\n\n'
            '⚠️ सीमित समय के लिए ऑफर मान्य!',
        'buttons': [
          {'text': '⭐ Upgrade to VIP Now', 'url': 'https://t.me/Examplayer_bot?start=vip_deal'}
        ],
      },
      {
        'title': '⚠️ System Maintenance Notice',
        'desc': 'Operational alert for scheduled server updates',
        'body':
            '⚠️ *SCHEDULED PLATFORM UPGRADE NOTICE*\n\n'
            'प्रिय छात्रों, प्लेटफॉर्म की गति और सुविधाओं को और बेहतर बनाने के लिए आज रात 02:00 AM से 02:30 AM तक सर्वर अपग्रेड रहेगा।\n\n'
            'इस दौरान टेस्ट सबमिशन कुछ मिनटों के लिए बाधित रह सकता है। सहयोग के लिए धन्यवाद!',
        'buttons': <Map<String, String>>[],
      },
    ];

    showDialog(
      context: context,
      builder: (ctx) => AlertDialog(
        backgroundColor: widget.isDark ? AppTheme.darkCard : Colors.white,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
        title: Row(
          children: [
            const Icon(Icons.bookmark_added_rounded, color: Color(0xFF4F46E5), size: 22),
            const SizedBox(width: 8),
            Text('Broadcast Message Templates', style: GoogleFonts.inter(fontWeight: FontWeight.w700, fontSize: 17)),
          ],
        ),
        content: SizedBox(
          width: 580,
          child: ListView.separated(
            shrinkWrap: true,
            itemCount: templates.length,
            separatorBuilder: (_, _) => const Divider(height: 16),
            itemBuilder: (c, i) {
              final t = templates[i];
              return ListTile(
                contentPadding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
                tileColor: widget.isDark ? const Color(0xFF1E293B) : const Color(0xFFF8FAFC),
                title: Text(t['title'] as String, style: GoogleFonts.inter(fontWeight: FontWeight.w700, fontSize: 13.5)),
                subtitle: Text(t['desc'] as String, style: const TextStyle(fontSize: 11.5, color: Color(0xFF64748B))),
                trailing: ElevatedButton(
                  style: ElevatedButton.styleFrom(
                    backgroundColor: const Color(0xFF4F46E5),
                    padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
                  ),
                  onPressed: () {
                    setState(() {
                      _titleCtrl.text = (t['title'] as String).replaceAll(RegExp(r'[^\w\s\-]'), '').trim();
                      _msgCtrl.text = t['body'] as String;
                      _inlineButtons.clear();
                      final btns = t['buttons'] as List<Map<String, String>>;
                      _inlineButtons.addAll(btns);
                    });
                    Navigator.pop(ctx);
                    widget.onShowToast('Template loaded into editor!');
                  },
                  child: const Text('Use Template', style: TextStyle(fontSize: 11.5, color: Colors.white)),
                ),
              );
            },
          ),
        ),
        actions: [
          TextButton(onPressed: () => Navigator.pop(ctx), child: const Text('Close')),
        ],
      ),
    );
  }

  void _openSpecificUsersDialog() {
    final searchCtrl = TextEditingController();
    List<dynamic> filtered = List.from(widget.users);

    showDialog(
      context: context,
      builder: (ctx) => StatefulBuilder(
        builder: (dialogCtx, setDialogState) {
          return AlertDialog(
            backgroundColor: widget.isDark ? AppTheme.darkCard : Colors.white,
            shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
            title: Row(
              children: [
                const Icon(Icons.person_pin_rounded, color: Color(0xFF10B981), size: 22),
                const SizedBox(width: 8),
                Text('Select Specific Candidates', style: GoogleFonts.inter(fontWeight: FontWeight.w700, fontSize: 16)),
              ],
            ),
            content: SizedBox(
              width: 520,
              height: 420,
              child: Column(
                children: [
                  TextField(
                    controller: searchCtrl,
                    decoration: InputDecoration(
                      hintText: 'Search by candidate name or username...',
                      prefixIcon: const Icon(Icons.search_rounded, size: 20),
                      isDense: true,
                      contentPadding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
                      border: OutlineInputBorder(borderRadius: BorderRadius.circular(10)),
                    ),
                    onChanged: (q) {
                      final query = q.toLowerCase().trim();
                      setDialogState(() {
                        filtered = widget.users.where((u) {
                          final name = (u['first_name'] ?? u['name'] ?? '').toString().toLowerCase();
                          final uname = (u['username'] ?? '').toString().toLowerCase();
                          return name.contains(query) || uname.contains(query);
                        }).toList();
                      });
                    },
                  ),
                  const SizedBox(height: 12),
                  Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      Text(
                        'Selected: ${_selectedSpecificUserIds.length} users',
                        style: const TextStyle(fontWeight: FontWeight.w600, fontSize: 12),
                      ),
                      TextButton(
                        onPressed: () {
                          setDialogState(() {
                            if (_selectedSpecificUserIds.length == filtered.length) {
                              _selectedSpecificUserIds.clear();
                            } else {
                              for (final u in filtered) {
                                final id = int.tryParse(u['id'].toString()) ?? 0;
                                if (id > 0) _selectedSpecificUserIds.add(id);
                              }
                            }
                          });
                        },
                        child: Text(
                          _selectedSpecificUserIds.length == filtered.length ? 'Deselect All' : 'Select All Filtered',
                          style: const TextStyle(fontSize: 12),
                        ),
                      ),
                    ],
                  ),
                  const Divider(height: 1),
                  Expanded(
                    child: filtered.isEmpty
                        ? const Center(child: Text('No users found in database'))
                        : ListView.separated(
                            itemCount: filtered.length,
                            separatorBuilder: (_, _) => const Divider(height: 1),
                            itemBuilder: (c, i) {
                              final u = filtered[i];
                              final uId = int.tryParse(u['id'].toString()) ?? 0;
                              final name = u['first_name'] ?? u['name'] ?? 'Candidate';
                              final uname = u['username'] != null && u['username'].toString().isNotEmpty
                                  ? '@${u['username']}'
                                  : 'ID: $uId';
                              final isSelected = _selectedSpecificUserIds.contains(uId);

                              return CheckboxListTile(
                                value: isSelected,
                                dense: true,
                                title: Text(name, style: const TextStyle(fontSize: 13, fontWeight: FontWeight.w600)),
                                subtitle: Text(uname, style: const TextStyle(fontSize: 11, color: Color(0xFF64748B))),
                                onChanged: (val) {
                                  setDialogState(() {
                                    if (val == true) {
                                      _selectedSpecificUserIds.add(uId);
                                    } else {
                                      _selectedSpecificUserIds.remove(uId);
                                    }
                                  });
                                },
                              );
                            },
                          ),
                  ),
                ],
              ),
            ),
            actions: [
              TextButton(onPressed: () => Navigator.pop(ctx), child: const Text('Cancel')),
              ElevatedButton(
                style: ElevatedButton.styleFrom(backgroundColor: const Color(0xFF10B981)),
                onPressed: () {
                  setState(() {});
                  Navigator.pop(ctx);
                  widget.onShowToast('Audience targeted: ${_selectedSpecificUserIds.length} candidates');
                },
                child: const Text('Done', style: TextStyle(color: Colors.white)),
              ),
            ],
          );
        },
      ),
    );
  }

  void _saveDraft() {
    if (_msgCtrl.text.trim().isEmpty) {
      widget.onShowToast('Cannot save an empty broadcast', isError: true);
      return;
    }
    _drafts.add({
      'title': _titleCtrl.text.trim().isNotEmpty ? _titleCtrl.text.trim() : 'Draft Announcement',
      'message': _msgCtrl.text,
      'buttons': List<Map<String, String>>.from(_inlineButtons),
      'mediaUrl': _mediaUrlCtrl.text.trim(),
      'time': DateTime.now(),
    });
    widget.onShowToast('💾 Saved to Broadcast Drafts!');
  }

  Future<void> _handleTestSend() async {
    final text = _msgCtrl.text.trim();
    if (text.isEmpty) {
      widget.onShowToast('Message cannot be empty', isError: true);
      return;
    }

    final chatId = _testChatIdCtrl.text.trim().isNotEmpty ? _testChatIdCtrl.text.trim() : widget.adminId;
    if (chatId.isEmpty) {
      // Prompt for admin chat ID
      final inputCtrl = TextEditingController();
      showDialog(
        context: context,
        builder: (ctx) => AlertDialog(
          backgroundColor: widget.isDark ? AppTheme.darkCard : Colors.white,
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(14)),
          title: Text('Telegram Test Destination', style: GoogleFonts.inter(fontWeight: FontWeight.w700, fontSize: 16)),
          content: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              const Text(
                'Enter your Telegram numeric Chat ID to receive an immediate test message directly in your bot chat:',
                style: TextStyle(fontSize: 12.5),
              ),
              const SizedBox(height: 14),
              TextField(
                controller: inputCtrl,
                decoration: const InputDecoration(
                  labelText: 'Telegram User ID',
                  hintText: 'e.g. 542918239',
                  prefixIcon: Icon(Icons.tag_rounded, size: 20),
                ),
              ),
            ],
          ),
          actions: [
            TextButton(onPressed: () => Navigator.pop(ctx), child: const Text('Cancel')),
            ElevatedButton(
              style: ElevatedButton.styleFrom(backgroundColor: const Color(0xFF4F46E5)),
              onPressed: () {
                final id = inputCtrl.text.trim();
                if (id.isEmpty) return;
                setState(() => _testChatIdCtrl.text = id);
                Navigator.pop(ctx);
                _dispatchTestBroadcast(id);
              },
              child: const Text('Send Test', style: TextStyle(color: Colors.white)),
            ),
          ],
        ),
      );
      return;
    }

    _dispatchTestBroadcast(chatId);
  }

  Future<void> _dispatchTestBroadcast(String chatId) async {
    setState(() => _isTesting = true);
    widget.onShowToast('Sending test message to $chatId...');

    try {
      final res = await widget.api.sendTestBroadcast(
        message: _msgCtrl.text.trim(),
        type: _selectedType,
        mediaUrl: _mediaUrlCtrl.text.trim().isNotEmpty ? _mediaUrlCtrl.text.trim() : null,
        buttons: _inlineButtons,
        testChatId: chatId,
      );

      if (mounted) setState(() => _isTesting = false);

      if (res['success'] == true) {
        widget.onShowToast('🚀 Test message delivered to your Telegram!');
      } else {
        widget.onShowToast(res['error'] ?? 'Test broadcast failed', isError: true);
      }
    } catch (e) {
      if (mounted) setState(() => _isTesting = false);
      widget.onShowToast('Error sending test: $e', isError: true);
    }
  }

  Future<void> _dispatchBroadcast() async {
    final text = _msgCtrl.text.trim();
    if (text.isEmpty) {
      widget.onShowToast('Broadcast message cannot be empty', isError: true);
      return;
    }

    // Confirmation dialog
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        backgroundColor: widget.isDark ? AppTheme.darkCard : Colors.white,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(14)),
        title: Row(
          children: [
            const Icon(Icons.campaign_rounded, color: Color(0xFF4F46E5), size: 24),
            const SizedBox(width: 8),
            Text('Confirm Broadcast Dispatch', style: GoogleFonts.inter(fontWeight: FontWeight.w700, fontSize: 16)),
          ],
        ),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              'Are you sure you want to broadcast this announcement?',
              style: TextStyle(
                fontSize: 13.5,
                color: widget.isDark ? Colors.white70 : const Color(0xFF334155),
              ),
            ),
            const SizedBox(height: 12),
            Container(
              padding: const EdgeInsets.all(12),
              decoration: BoxDecoration(
                color: widget.isDark ? const Color(0xFF1E293B) : const Color(0xFFF1F5F9),
                borderRadius: BorderRadius.circular(8),
              ),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text('Audience: ${_getAudienceLabel()}', style: const TextStyle(fontWeight: FontWeight.w700, fontSize: 12)),
                  const SizedBox(height: 4),
                  Text('Type: ${_selectedType.toUpperCase()}', style: const TextStyle(fontSize: 11.5, color: Color(0xFF64748B))),
                  if (_inlineButtons.isNotEmpty)
                    Text('Buttons Attached: ${_inlineButtons.length}', style: const TextStyle(fontSize: 11.5, color: Color(0xFF64748B))),
                  if (_isScheduled)
                    Text('Scheduled for: ${_scheduledDateTime.toLocal()}', style: const TextStyle(fontSize: 11.5, color: Color(0xFFF59E0B))),
                ],
              ),
            ),
          ],
        ),
        actions: [
          TextButton(onPressed: () => Navigator.pop(ctx, false), child: const Text('Cancel')),
          ElevatedButton(
            style: ElevatedButton.styleFrom(backgroundColor: const Color(0xFF4F46E5)),
            onPressed: () => Navigator.pop(ctx, true),
            child: const Text('Confirm & Dispatch', style: TextStyle(color: Colors.white)),
          ),
        ],
      ),
    );

    if (confirmed != true) return;

    setState(() => _isSending = true);
    widget.onShowToast('🚀 Dispatching broadcast in background...');

    try {
      final res = await widget.api.sendBroadcast(
        message: text,
        title: _titleCtrl.text.trim().isNotEmpty ? _titleCtrl.text.trim() : 'Broadcast Announcement',
        type: _selectedType,
        mediaUrl: _mediaUrlCtrl.text.trim().isNotEmpty ? _mediaUrlCtrl.text.trim() : null,
        buttons: _inlineButtons,
        target: _targetAudience,
        planType: _filterPlanType.toLowerCase().contains('free')
            ? 'free'
            : (_filterPlanType.toLowerCase().contains('premium') ? 'premium' : null),
        specificUserIds: _targetAudience == 'specific' ? _selectedSpecificUserIds.toList() : null,
      );

      if (mounted) setState(() => _isSending = false);

      if (res['success'] == true) {
        widget.onShowToast('📢 Broadcast completed! Delivered: ${res['delivered'] ?? 0}');
        _loadBroadcastHistory();
        _loadStats();
      } else {
        widget.onShowToast(res['error'] ?? 'Broadcast failed to deliver', isError: true);
      }
    } catch (e) {
      if (mounted) setState(() => _isSending = false);
      widget.onShowToast('Transmission error: $e', isError: true);
    }
  }

  String _getAudienceLabel() {
    final totalUsers = widget.users.isNotEmpty ? widget.users.length : 12548;
    switch (_targetAudience) {
      case 'specific':
        return 'Specific Candidates (${_selectedSpecificUserIds.length})';
      case 'segments':
        return 'User Segments ($_filterUserStatus)';
      case 'plans':
        return 'By Plan ($_filterPlanType)';
      case 'all':
      default:
        return 'All Users ($totalUsers)';
    }
  }

  @override
  Widget build(BuildContext context) {
    final isDark = widget.isDark;
    final screenWidth = MediaQuery.of(context).size.width;
    final isDesktop = screenWidth >= 1100;

    return Scaffold(
      backgroundColor: isDark ? AppTheme.darkBg : const Color(0xFFF8FAFC),
      body: SingleChildScrollView(
        padding: const EdgeInsets.all(22),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            // 1. Header Bar
            _buildHeaderBar(isDark),
            const SizedBox(height: 18),

            // 2. Top 5 KPI Metric Cards
            _buildKpiMetricsGrid(isDark, screenWidth),
            const SizedBox(height: 22),

            // 3. Main Workspace: Two-column on desktop, stacked on mobile
            if (isDesktop)
              Row(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Expanded(flex: 3, child: _buildCreateBroadcastCard(isDark)),
                  const SizedBox(width: 22),
                  Expanded(
                    flex: 2,
                    child: Column(
                      children: [
                        _buildMessagePreviewCard(isDark),
                        const SizedBox(height: 22),
                        _buildRecentBroadcastsCard(isDark),
                      ],
                    ),
                  ),
                ],
              )
            else
              Column(
                children: [
                  _buildCreateBroadcastCard(isDark),
                  const SizedBox(height: 22),
                  _buildMessagePreviewCard(isDark),
                  const SizedBox(height: 22),
                  _buildRecentBroadcastsCard(isDark),
                ],
              ),
          ],
        ),
      ),
    );
  }

  // ===========================================================================
  // 1. HEADER BAR
  // ===========================================================================
  Widget _buildHeaderBar(bool isDark) {
    return Row(
      children: [
        // App Icon Pill
        Container(
          width: 44,
          height: 44,
          decoration: BoxDecoration(
            color: const Color(0xFF6366F1),
            borderRadius: BorderRadius.circular(12),
            boxShadow: [
              BoxShadow(
                color: const Color(0xFF6366F1).withValues(alpha: 0.3),
                blurRadius: 10,
                offset: const Offset(0, 3),
              ),
            ],
          ),
          child: const Center(
            child: Icon(Icons.send_rounded, color: Colors.white, size: 22),
          ),
        ),
        const SizedBox(width: 14),
        Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                'Broadcast Studio',
                style: GoogleFonts.inter(
                  fontSize: 22,
                  fontWeight: FontWeight.w800,
                  color: isDark ? Colors.white : const Color(0xFF0F172A),
                  letterSpacing: -0.4,
                ),
              ),
              const SizedBox(height: 2),
              Text(
                'Send messages, updates, new tests and announcements to your users. Target specific users or send to everyone.',
                style: GoogleFonts.inter(
                  fontSize: 12.5,
                  color: isDark ? const Color(0xFF94A3B8) : const Color(0xFF64748B),
                ),
              ),
            ],
          ),
        ),
        // Action Buttons on Top Right
        OutlinedButton.icon(
          style: OutlinedButton.styleFrom(
            foregroundColor: isDark ? Colors.white : const Color(0xFF1E293B),
            side: BorderSide(color: isDark ? const Color(0xFF334155) : const Color(0xFFCBD5E1)),
            shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
            padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
          ),
          onPressed: _openTemplatesModal,
          icon: const Icon(Icons.bookmark_outline_rounded, size: 16),
          label: Text('Message Templates', style: GoogleFonts.inter(fontWeight: FontWeight.w600, fontSize: 12.5)),
        ),
        const SizedBox(width: 10),
        OutlinedButton.icon(
          style: OutlinedButton.styleFrom(
            foregroundColor: isDark ? Colors.white : const Color(0xFF1E293B),
            side: BorderSide(color: isDark ? const Color(0xFF334155) : const Color(0xFFCBD5E1)),
            shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
            padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
          ),
          onPressed: () {
            _loadBroadcastHistory();
            widget.onShowToast('Broadcast history refreshed');
          },
          icon: const Icon(Icons.history_rounded, size: 16),
          label: Text('Broadcast History', style: GoogleFonts.inter(fontWeight: FontWeight.w600, fontSize: 12.5)),
        ),
      ],
    );
  }

  // ===========================================================================
  // 2. TOP 5 KPI METRICS
  // ===========================================================================
  Widget _buildKpiMetricsGrid(bool isDark, double screenWidth) {
    final totalUsers = widget.users.isNotEmpty ? widget.users.length : (_kpiStats['totalUsers'] ?? 0);
    final broadcastsSent = _broadcastHistory.length;
    final delivered = _broadcastHistory.fold<int>(
      0,
      (sum, b) => sum + (int.tryParse(b['delivered']?.toString() ?? '0') ?? 0),
    );
    final failed = _broadcastHistory.fold<int>(
      0,
      (sum, b) => sum + (int.tryParse(b['failed']?.toString() ?? '0') ?? 0),
    );
    final views = _broadcastHistory.fold<int>(
      0,
      (sum, b) => sum + (int.tryParse(b['views']?.toString() ?? '0') ?? 0),
    );

    final totalProcessed = delivered + failed;
    final deliveryRate = totalProcessed > 0
        ? '${((delivered / totalProcessed) * 100).toStringAsFixed(1)}%'
        : (_kpiStats['deliveryRate']?.toString() ?? '0.0%');
    final failedRate = totalProcessed > 0
        ? '${((failed / totalProcessed) * 100).toStringAsFixed(1)}%'
        : '0.0%';
    final viewRate = delivered > 0
        ? '${((views / delivered) * 100).toStringAsFixed(1)}%'
        : (_kpiStats['viewRate']?.toString() ?? '0.0%');

    final cards = [
      _buildSingleKpiCard(
        isDark: isDark,
        icon: Icons.people_alt_rounded,
        iconColor: const Color(0xFF3B82F6),
        iconBg: const Color(0xFFEFF6FF),
        title: 'Total Users',
        value: '$totalUsers',
        subtitle: totalUsers > 0 ? 'All registered users' : 'No registered users',
      ),
      _buildSingleKpiCard(
        isDark: isDark,
        icon: Icons.send_rounded,
        iconColor: const Color(0xFF10B981),
        iconBg: const Color(0xFFECFDF5),
        title: 'Broadcasts Sent',
        value: '$broadcastsSent',
        subtitle: broadcastsSent > 0 ? '$broadcastsSent campaigns dispatched' : 'No broadcasts sent yet',
        subtitleColor: broadcastsSent > 0 ? const Color(0xFF10B981) : null,
      ),
      _buildSingleKpiCard(
        isDark: isDark,
        icon: Icons.inventory_2_rounded,
        iconColor: const Color(0xFFF59E0B),
        iconBg: const Color(0xFFFFFBEB),
        title: 'Delivered',
        value: '$delivered',
        subtitle: '$deliveryRate delivery rate',
      ),
      _buildSingleKpiCard(
        isDark: isDark,
        icon: Icons.sms_failed_rounded,
        iconColor: const Color(0xFFEF4444),
        iconBg: const Color(0xFFFEF2F2),
        title: 'Failed',
        value: '$failed',
        subtitle: '$failedRate failed',
        subtitleColor: failed > 0 ? const Color(0xFFEF4444) : null,
      ),
      _buildSingleKpiCard(
        isDark: isDark,
        icon: Icons.visibility_rounded,
        iconColor: const Color(0xFF8B5CF6),
        iconBg: const Color(0xFFF5F3FF),
        title: 'Total Views',
        value: '$views',
        subtitle: '$viewRate view rate',
      ),
    ];

    if (screenWidth < 900) {
      return Wrap(
        spacing: 12,
        runSpacing: 12,
        children: cards.map((c) => SizedBox(width: (screenWidth - 60) / 2, child: c)).toList(),
      );
    }

    return Row(
      children: cards.map((c) => Expanded(child: Padding(padding: const EdgeInsets.symmetric(horizontal: 5), child: c))).toList(),
    );
  }

  Widget _buildSingleKpiCard({
    required bool isDark,
    required IconData icon,
    required Color iconColor,
    required Color iconBg,
    required String title,
    required String value,
    required String subtitle,
    Color? subtitleColor,
  }) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 16),
      decoration: BoxDecoration(
        color: isDark ? AppTheme.darkCard : Colors.white,
        borderRadius: BorderRadius.circular(14),
        border: Border.all(color: isDark ? AppTheme.darkBorderSubtle : const Color(0xFFE2E8F0)),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(alpha: isDark ? 0.2 : 0.02),
            blurRadius: 6,
            offset: const Offset(0, 2),
          ),
        ],
      ),
      child: Row(
        children: [
          Container(
            width: 44,
            height: 44,
            decoration: BoxDecoration(
              color: isDark ? iconColor.withValues(alpha: 0.15) : iconBg,
              borderRadius: BorderRadius.circular(10),
            ),
            child: Center(
              child: Icon(icon, color: iconColor, size: 22),
            ),
          ),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              mainAxisSize: MainAxisSize.min,
              children: [
                Text(
                  title,
                  style: GoogleFonts.inter(
                    fontSize: 11.5,
                    fontWeight: FontWeight.w600,
                    color: isDark ? const Color(0xFF94A3B8) : const Color(0xFF64748B),
                  ),
                ),
                const SizedBox(height: 2),
                Text(
                  value,
                  style: GoogleFonts.inter(
                    fontSize: 18,
                    fontWeight: FontWeight.w800,
                    color: isDark ? Colors.white : const Color(0xFF0F172A),
                    letterSpacing: -0.3,
                  ),
                ),
                const SizedBox(height: 2),
                Text(
                  subtitle,
                  style: GoogleFonts.inter(
                    fontSize: 10.5,
                    fontWeight: FontWeight.w500,
                    color: subtitleColor ?? (isDark ? const Color(0xFF64748B) : const Color(0xFF94A3B8)),
                  ),
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  // ===========================================================================
  // 3. CREATE BROADCAST CARD (LEFT COLUMN)
  // ===========================================================================
  Widget _buildCreateBroadcastCard(bool isDark) {
    return Container(
      decoration: BoxDecoration(
        color: isDark ? AppTheme.darkCard : Colors.white,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: isDark ? AppTheme.darkBorderSubtle : const Color(0xFFE2E8F0)),
      ),
      padding: const EdgeInsets.all(22),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          // Header
          Row(
            children: [
              Container(
                width: 32,
                height: 32,
                decoration: BoxDecoration(
                  color: const Color(0xFF6366F1).withValues(alpha: 0.12),
                  borderRadius: BorderRadius.circular(8),
                ),
                child: const Center(
                  child: Icon(Icons.send_rounded, color: Color(0xFF6366F1), size: 16),
                ),
              ),
              const SizedBox(width: 10),
              Text(
                'Create Broadcast Message',
                style: GoogleFonts.inter(
                  fontSize: 16,
                  fontWeight: FontWeight.w700,
                  color: isDark ? Colors.white : const Color(0xFF0F172A),
                ),
              ),
            ],
          ),
          const SizedBox(height: 18),

          // Message Type Segment Selector
          _buildMessageTypeSelector(isDark),
          const SizedBox(height: 16),

          // Conditional Media / Quiz Attachment Field
          if (_selectedType == 'photo' || _selectedType == 'document') ...[
            TextField(
              controller: _mediaUrlCtrl,
              decoration: InputDecoration(
                labelText: _selectedType == 'photo' ? 'Image / Poster URL' : 'Document / PDF URL',
                hintText: _selectedType == 'photo' ? 'https://example.com/poster.jpg' : 'https://example.com/notes.pdf',
                prefixIcon: Icon(_selectedType == 'photo' ? Icons.image_rounded : Icons.description_rounded, size: 20),
                isDense: true,
                border: OutlineInputBorder(borderRadius: BorderRadius.circular(10)),
              ),
              onChanged: (_) => setState(() {}),
            ),
            const SizedBox(height: 14),
          ] else if (_selectedType == 'quiz') ...[
            _buildQuizDropdownPicker(isDark),
            const SizedBox(height: 14),
          ],

          // Title field (for history & reference)
          TextField(
            controller: _titleCtrl,
            decoration: InputDecoration(
              labelText: 'Announcement Title / Campaign Reference',
              hintText: 'e.g. Bihar Special Test Announcement',
              prefixIcon: const Icon(Icons.title_rounded, size: 20),
              isDense: true,
              border: OutlineInputBorder(borderRadius: BorderRadius.circular(10)),
            ),
          ),
          const SizedBox(height: 14),

          // Message Content Label + Character Counter
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Text(
                'Message Content',
                style: GoogleFonts.inter(
                  fontSize: 12.5,
                  fontWeight: FontWeight.w700,
                  color: isDark ? Colors.white : const Color(0xFF1E293B),
                ),
              ),
              Text(
                '${_msgCtrl.text.length}/4096',
                style: GoogleFonts.inter(
                  fontSize: 11,
                  color: _msgCtrl.text.length > 4000 ? const Color(0xFFEF4444) : const Color(0xFF94A3B8),
                  fontWeight: FontWeight.w600,
                ),
              ),
            ],
          ),
          const SizedBox(height: 8),

          // Formatting Toolbar
          _buildFormattingToolbar(isDark),
          const SizedBox(height: 6),

          // Text Area
          Container(
            decoration: BoxDecoration(
              color: isDark ? const Color(0xFF0F172A) : const Color(0xFFFAFAFA),
              borderRadius: BorderRadius.circular(10),
              border: Border.all(color: isDark ? const Color(0xFF334155) : const Color(0xFFE2E8F0)),
            ),
            child: TextField(
              controller: _msgCtrl,
              maxLines: 7,
              style: GoogleFonts.inter(fontSize: 13, height: 1.4),
              decoration: const InputDecoration(
                contentPadding: EdgeInsets.all(14),
                border: InputBorder.none,
                hintText:
                    'Type your message here...\n\n'
                    'You can use variables like:\n'
                    '{first_name} - User\'s first name\n'
                    '{username} - Telegram username\n'
                    '{total_tests} - User\'s test count',
                hintStyle: TextStyle(fontSize: 12, color: Color(0xFF94A3B8)),
              ),
              onChanged: (_) => setState(() {}),
            ),
          ),
          const SizedBox(height: 12),

          // Attached Buttons Row / Management
          _buildButtonManagementRow(isDark),
          const SizedBox(height: 18),

          // Target Audience & Target Filters Section
          _buildAudienceAndFiltersSection(isDark),
          const SizedBox(height: 20),

          // Bottom Action Bar: Schedule Toggle + Draft + Send
          _buildFooterActionBar(isDark),
        ],
      ),
    );
  }

  Widget _buildMessageTypeSelector(bool isDark) {
    final types = [
      {'id': 'text', 'label': 'Text Message', 'icon': Icons.chat_rounded},
      {'id': 'photo', 'label': 'Photo / Image', 'icon': Icons.image_rounded},
      {'id': 'document', 'label': 'Document', 'icon': Icons.description_rounded},
      {'id': 'quiz', 'label': 'Quiz / Test', 'icon': Icons.quiz_rounded},
      {'id': 'button', 'label': 'Button Message', 'icon': Icons.smart_button_rounded},
    ];

    return SingleChildScrollView(
      scrollDirection: Axis.horizontal,
      child: Row(
        children: types.map((t) {
          final isSelected = _selectedType == t['id'];
          return Padding(
            padding: const EdgeInsets.only(right: 8),
            child: InkWell(
              onTap: () {
                setState(() => _selectedType = t['id'] as String);
                if (t['id'] == 'button' && _inlineButtons.isEmpty) {
                  _openAddButtonDialog();
                }
              },
              borderRadius: BorderRadius.circular(8),
              child: Container(
                padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 8),
                decoration: BoxDecoration(
                  color: isSelected
                      ? const Color(0xFF6366F1).withValues(alpha: 0.12)
                      : (isDark ? const Color(0xFF1E293B) : const Color(0xFFF1F5F9)),
                  borderRadius: BorderRadius.circular(8),
                  border: Border.all(
                    color: isSelected ? const Color(0xFF6366F1) : Colors.transparent,
                    width: 1.2,
                  ),
                ),
                child: Row(
                  children: [
                    Icon(
                      t['icon'] as IconData,
                      size: 15,
                      color: isSelected ? const Color(0xFF6366F1) : const Color(0xFF64748B),
                    ),
                    const SizedBox(width: 6),
                    Text(
                      t['label'] as String,
                      style: GoogleFonts.inter(
                        fontSize: 12,
                        fontWeight: isSelected ? FontWeight.w700 : FontWeight.w500,
                        color: isSelected ? const Color(0xFF6366F1) : (isDark ? Colors.white70 : const Color(0xFF475569)),
                      ),
                    ),
                  ],
                ),
              ),
            ),
          );
        }).toList(),
      ),
    );
  }

  Widget _buildQuizDropdownPicker(bool isDark) {
    return DropdownButtonFormField<String>(
      decoration: InputDecoration(
        labelText: 'Select Quiz to Broadcast',
        prefixIcon: const Icon(Icons.quiz_rounded, size: 20),
        isDense: true,
        border: OutlineInputBorder(borderRadius: BorderRadius.circular(10)),
      ),
      initialValue: _selectedQuizId,
      items: widget.quizzes.map<DropdownMenuItem<String>>((q) {
        final qId = q['id'].toString();
        final title = q['title'] ?? 'Quiz #$qId';
        return DropdownMenuItem<String>(
          value: qId,
          child: Text(title, maxLines: 1, overflow: TextOverflow.ellipsis),
        );
      }).toList(),
      onChanged: (val) {
        if (val != null) {
          setState(() {
            _selectedQuizId = val;
            final matched = widget.quizzes.firstWhere((q) => q['id'].toString() == val, orElse: () => {});
            if (matched.isNotEmpty) {
              final title = matched['title'] ?? 'Mock Test';
              final count = matched['question_count'] ?? matched['total_questions'] ?? 50;
              _titleCtrl.text = title;
              _msgCtrl.text =
                  '🔥 *नया टेस्ट आ गया है!*\n\n'
                  '*$title - $count प्रश्न*\n'
                  '✅ GK + Current Affairs\n'
                  '✅ परीक्षा के लिए महत्वपूर्ण\n'
                  '✅ अभी टेस्ट दें और अपनी तैयारी को मजबूत करें!';
              _inlineButtons.clear();
              _inlineButtons.add({
                'text': '🚀 अभी टेस्ट शुरू करें',
                'url': 'https://t.me/Examplayer_bot?start=quiz_$val',
              });
            }
          });
        }
      },
    );
  }

  Widget _buildFormattingToolbar(bool isDark) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 4),
      decoration: BoxDecoration(
        color: isDark ? const Color(0xFF1E293B) : const Color(0xFFF1F5F9),
        borderRadius: BorderRadius.circular(8),
      ),
      child: Wrap(
        crossAxisAlignment: WrapCrossAlignment.center,
        spacing: 4,
        runSpacing: 4,
        children: [
          _toolbarBtn('B', () => _insertFormatting('*', '*'), isBold: true),
          _toolbarBtn('I', () => _insertFormatting('_', '_'), isItalic: true),
          _toolbarBtn('U', () => _insertFormatting('<u>', '</u>'), isUnderline: true),
          _toolbarBtn('</>', () => _insertFormatting('`', '`')),
          _toolbarIconBtn(Icons.link_rounded, () {
            _insertFormatting('[Link Text](', ')');
          }),
          _toolbarIconBtn(Icons.format_list_bulleted_rounded, () => _insertVariable('\n• ')),
          _toolbarIconBtn(Icons.format_list_numbered_rounded, () => _insertVariable('\n1. ')),
          _toolbarIconBtn(Icons.sentiment_satisfied_alt_rounded, _openEmojiPicker),
          // Variables Dropdown Button
          PopupMenuButton<String>(
            tooltip: 'Insert Variable',
            color: isDark ? AppTheme.darkCard : Colors.white,
            shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
            child: Container(
              padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
              decoration: BoxDecoration(
                color: isDark ? const Color(0xFF334155) : const Color(0xFFE2E8F0),
                borderRadius: BorderRadius.circular(6),
              ),
              child: Row(
                mainAxisSize: MainAxisSize.min,
                children: [
                  Text('Variables', style: GoogleFonts.inter(fontSize: 11.5, fontWeight: FontWeight.w600)),
                  const SizedBox(width: 4),
                  const Icon(Icons.arrow_drop_down_rounded, size: 16),
                ],
              ),
            ),
            itemBuilder: (ctx) => [
              const PopupMenuItem(value: '{first_name}', child: Text('{first_name} - User\'s first name', style: TextStyle(fontSize: 12))),
              const PopupMenuItem(value: '{username}', child: Text('{username} - Telegram username', style: TextStyle(fontSize: 12))),
              const PopupMenuItem(value: '{total_tests}', child: Text('{total_tests} - User\'s test count', style: TextStyle(fontSize: 12))),
              const PopupMenuItem(value: '{user_id}', child: Text('{user_id} - Telegram User ID', style: TextStyle(fontSize: 12))),
              const PopupMenuItem(value: '{bot_name}', child: Text('{bot_name} - Bot name', style: TextStyle(fontSize: 12))),
            ],
            onSelected: (val) => _insertVariable(val),
          ),
        ],
      ),
    );
  }

  Widget _toolbarBtn(String label, VoidCallback onTap, {bool isBold = false, bool isItalic = false, bool isUnderline = false}) {
    return InkWell(
      onTap: onTap,
      borderRadius: BorderRadius.circular(4),
      child: Container(
        width: 28,
        height: 28,
        alignment: Alignment.center,
        child: Text(
          label,
          style: GoogleFonts.inter(
            fontWeight: isBold ? FontWeight.w900 : FontWeight.w600,
            fontStyle: isItalic ? FontStyle.italic : FontStyle.normal,
            decoration: isUnderline ? TextDecoration.underline : TextDecoration.none,
            fontSize: 13,
          ),
        ),
      ),
    );
  }

  Widget _toolbarIconBtn(IconData icon, VoidCallback onTap) {
    return InkWell(
      onTap: onTap,
      borderRadius: BorderRadius.circular(4),
      child: Container(
        width: 28,
        height: 28,
        alignment: Alignment.center,
        child: Icon(icon, size: 16),
      ),
    );
  }

  Widget _buildButtonManagementRow(bool isDark) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(
          children: [
            OutlinedButton.icon(
              style: OutlinedButton.styleFrom(
                foregroundColor: const Color(0xFF4F46E5),
                side: const BorderSide(color: Color(0xFF818CF8)),
                shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
                padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 7),
              ),
              onPressed: _openAddButtonDialog,
              icon: const Icon(Icons.add_rounded, size: 16),
              label: Text('+ Add Inline Button', style: GoogleFonts.inter(fontSize: 11.5, fontWeight: FontWeight.w600)),
            ),
            const SizedBox(width: 8),
            OutlinedButton.icon(
              style: OutlinedButton.styleFrom(
                foregroundColor: const Color(0xFF64748B),
                side: BorderSide(color: isDark ? const Color(0xFF334155) : const Color(0xFFE2E8F0)),
                shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
                padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 7),
              ),
              onPressed: () => widget.onShowToast('Reply keyboard buttons are ready'),
              icon: const Icon(Icons.reply_rounded, size: 16),
              label: Text('+ Add Reply Button', style: GoogleFonts.inter(fontSize: 11.5)),
            ),
            const SizedBox(width: 8),
            OutlinedButton.icon(
              style: OutlinedButton.styleFrom(
                foregroundColor: const Color(0xFF64748B),
                side: BorderSide(color: isDark ? const Color(0xFF334155) : const Color(0xFFE2E8F0)),
                shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
                padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 7),
              ),
              onPressed: () {
                setState(() {
                  _selectedType = _selectedType == 'photo' ? 'text' : 'photo';
                });
              },
              icon: const Icon(Icons.attach_file_rounded, size: 16),
              label: Text('+ Add Media', style: GoogleFonts.inter(fontSize: 11.5)),
            ),
          ],
        ),

        // Added Buttons Chips
        if (_inlineButtons.isNotEmpty) ...[
          const SizedBox(height: 10),
          Wrap(
            spacing: 8,
            runSpacing: 8,
            children: _inlineButtons.asMap().entries.map((entry) {
              final idx = entry.key;
              final btn = entry.value;
              return Container(
                padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
                decoration: BoxDecoration(
                  color: const Color(0xFFEEF2FF),
                  borderRadius: BorderRadius.circular(8),
                  border: Border.all(color: const Color(0xFFC7D2FE)),
                ),
                child: Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    const Icon(Icons.link_rounded, size: 14, color: Color(0xFF4F46E5)),
                    const SizedBox(width: 6),
                    Text(
                      btn['text'] ?? '',
                      style: GoogleFonts.inter(fontSize: 11.5, fontWeight: FontWeight.w600, color: const Color(0xFF312E81)),
                    ),
                    const SizedBox(width: 6),
                    InkWell(
                      onTap: () {
                        setState(() => _inlineButtons.removeAt(idx));
                      },
                      child: const Icon(Icons.close_rounded, size: 14, color: Color(0xFF6366F1)),
                    ),
                  ],
                ),
              );
            }).toList(),
          ),
        ],
      ],
    );
  }

  // Target Audience & Filters Box
  Widget _buildAudienceAndFiltersSection(bool isDark) {
    final totalUsers = widget.users.isNotEmpty ? widget.users.length : 12548;

    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: isDark ? const Color(0xFF0F172A) : const Color(0xFFF8FAFC),
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: isDark ? const Color(0xFF1E293B) : const Color(0xFFE2E8F0)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              // Left: Target Audience Radio List
              Expanded(
                flex: 5,
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      'Target Audience',
                      style: GoogleFonts.inter(fontSize: 13, fontWeight: FontWeight.w700),
                    ),
                    const SizedBox(height: 12),
                    _audienceRadioTile(
                      isDark: isDark,
                      value: 'all',
                      icon: Icons.people_alt_rounded,
                      iconColor: const Color(0xFF3B82F6),
                      iconBg: const Color(0xFFEFF6FF),
                      title: 'All Users',
                      subtitle: 'Send to all registered users ($totalUsers)',
                    ),
                    const SizedBox(height: 8),
                    _audienceRadioTile(
                      isDark: isDark,
                      value: 'specific',
                      icon: Icons.person_search_rounded,
                      iconColor: const Color(0xFF10B981),
                      iconBg: const Color(0xFFECFDF5),
                      title: 'Specific Users',
                      subtitle: _selectedSpecificUserIds.isNotEmpty
                          ? '${_selectedSpecificUserIds.length} users selected'
                          : 'Select users manually',
                      onExtraTap: _openSpecificUsersDialog,
                    ),
                    const SizedBox(height: 8),
                    _audienceRadioTile(
                      isDark: isDark,
                      value: 'segments',
                      icon: Icons.group_work_rounded,
                      iconColor: const Color(0xFFF59E0B),
                      iconBg: const Color(0xFFFFFBEB),
                      title: 'User Segments',
                      subtitle: 'Active, Inactive, VIP, etc.',
                    ),
                    const SizedBox(height: 8),
                    _audienceRadioTile(
                      isDark: isDark,
                      value: 'plans',
                      icon: Icons.card_membership_rounded,
                      iconColor: const Color(0xFF8B5CF6),
                      iconBg: const Color(0xFFF5F3FF),
                      title: 'By Plan',
                      subtitle: 'Free, Premium, VIP users',
                    ),
                  ],
                ),
              ),
              const SizedBox(width: 18),

              // Right: Target Filters (Optional) 2x2 Dropdowns
              Expanded(
                flex: 5,
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      'Target Filters (Optional)',
                      style: GoogleFonts.inter(fontSize: 13, fontWeight: FontWeight.w700),
                    ),
                    const SizedBox(height: 12),
                    Row(
                      children: [
                        Expanded(
                          child: _dropdownField(
                            label: 'User Status',
                            value: _filterUserStatus,
                            items: ['All Users', 'Active Only', 'Inactive', 'Blocked'],
                            onChanged: (val) => setState(() => _filterUserStatus = val),
                          ),
                        ),
                        const SizedBox(width: 10),
                        Expanded(
                          child: _dropdownField(
                            label: 'Plan Type',
                            value: _filterPlanType,
                            items: ['All Plans', 'Free Plans', 'Premium Plans', 'VIP Users'],
                            onChanged: (val) => setState(() => _filterPlanType = val),
                          ),
                        ),
                      ],
                    ),
                    const SizedBox(height: 12),
                    Row(
                      children: [
                        Expanded(
                          child: _dropdownField(
                            label: 'Language',
                            value: _filterLanguage,
                            items: ['All Languages', 'Hindi', 'English', 'Hinglish'],
                            onChanged: (val) => setState(() => _filterLanguage = val),
                          ),
                        ),
                        const SizedBox(width: 10),
                        Expanded(
                          child: _dropdownField(
                            label: 'Last Active',
                            value: _filterLastActive,
                            items: ['Any Time', 'Today', 'Last 7 Days', 'Last 30 Days'],
                            onChanged: (val) => setState(() => _filterLastActive = val),
                          ),
                        ),
                      ],
                    ),
                  ],
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }

  Widget _audienceRadioTile({
    required bool isDark,
    required String value,
    required IconData icon,
    required Color iconColor,
    required Color iconBg,
    required String title,
    required String subtitle,
    VoidCallback? onExtraTap,
  }) {
    final isSelected = _targetAudience == value;

    return InkWell(
      onTap: () {
        setState(() => _targetAudience = value);
        if (onExtraTap != null && value == 'specific' && _selectedSpecificUserIds.isEmpty) {
          onExtraTap();
        }
      },
      borderRadius: BorderRadius.circular(10),
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 8),
        decoration: BoxDecoration(
          color: isSelected
              ? (isDark ? const Color(0xFF1E293B) : Colors.white)
              : Colors.transparent,
          borderRadius: BorderRadius.circular(10),
          border: Border.all(
            color: isSelected
                ? const Color(0xFF6366F1)
                : (isDark ? const Color(0xFF1E293B) : const Color(0xFFE2E8F0)),
          ),
        ),
        child: Row(
          children: [
            Container(
              width: 18,
              height: 18,
              margin: const EdgeInsets.only(left: 4, right: 10),
              decoration: BoxDecoration(
                shape: BoxShape.circle,
                border: Border.all(
                  color: isSelected ? const Color(0xFF6366F1) : (isDark ? const Color(0xFF64748B) : const Color(0xFF94A3B8)),
                  width: isSelected ? 5.5 : 2,
                ),
              ),
            ),
            Container(
              width: 30,
              height: 30,
              decoration: BoxDecoration(
                color: isDark ? iconColor.withValues(alpha: 0.15) : iconBg,
                borderRadius: BorderRadius.circular(6),
              ),
              child: Center(child: Icon(icon, size: 16, color: iconColor)),
            ),
            const SizedBox(width: 10),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(title, style: GoogleFonts.inter(fontWeight: FontWeight.w700, fontSize: 12)),
                  Text(subtitle, style: const TextStyle(fontSize: 10.5, color: Color(0xFF64748B))),
                ],
              ),
            ),
            if (value == 'specific')
              IconButton(
                icon: const Icon(Icons.edit_note_rounded, size: 18, color: Color(0xFF10B981)),
                tooltip: 'Pick Candidates',
                onPressed: _openSpecificUsersDialog,
              ),
          ],
        ),
      ),
    );
  }

  Widget _dropdownField({
    required String label,
    required String value,
    required List<String> items,
    required Function(String) onChanged,
  }) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(label, style: const TextStyle(fontSize: 11, fontWeight: FontWeight.w600, color: Color(0xFF64748B))),
        const SizedBox(height: 4),
        Container(
          padding: const EdgeInsets.symmetric(horizontal: 10),
          decoration: BoxDecoration(
            color: widget.isDark ? const Color(0xFF1E293B) : Colors.white,
            borderRadius: BorderRadius.circular(8),
            border: Border.all(color: widget.isDark ? const Color(0xFF334155) : const Color(0xFFCBD5E1)),
          ),
          child: DropdownButtonHideUnderline(
            child: DropdownButton<String>(
              value: value,
              isExpanded: true,
              style: GoogleFonts.inter(
                fontSize: 12,
                color: widget.isDark ? Colors.white : const Color(0xFF0F172A),
              ),
              items: items.map((e) => DropdownMenuItem(value: e, child: Text(e))).toList(),
              onChanged: (val) {
                if (val != null) onChanged(val);
              },
            ),
          ),
        ),
      ],
    );
  }

  // Bottom action bar
  Widget _buildFooterActionBar(bool isDark) {
    return Row(
      children: [
        // Schedule Toggle
        Switch(
          value: _isScheduled,
          activeTrackColor: const Color(0xFF4F46E5),
          onChanged: (val) async {
            if (val) {
              final pickedDate = await showDatePicker(
                context: context,
                initialDate: DateTime.now().add(const Duration(days: 1)),
                firstDate: DateTime.now(),
                lastDate: DateTime.now().add(const Duration(days: 90)),
              );
              if (pickedDate != null && mounted) {
                final pickedTime = await showTimePicker(
                  context: context,
                  initialTime: const TimeOfDay(hour: 10, minute: 30),
                );
                if (pickedTime != null && mounted) {
                  setState(() {
                    _scheduledDateTime = DateTime(
                      pickedDate.year,
                      pickedDate.month,
                      pickedDate.day,
                      pickedTime.hour,
                      pickedTime.minute,
                    );
                    _isScheduled = true;
                  });
                  widget.onShowToast('Scheduled for ${_scheduledDateTime.toLocal()}');
                  return;
                }
              }
              setState(() => _isScheduled = false);
            } else {
              setState(() => _isScheduled = false);
            }
          },
        ),
        const SizedBox(width: 8),
        Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text('Schedule Message', style: GoogleFonts.inter(fontWeight: FontWeight.w700, fontSize: 12)),
            Text(
              _isScheduled ? 'Will send on ${_scheduledDateTime.day}/${_scheduledDateTime.month} at ${_scheduledDateTime.hour}:${_scheduledDateTime.minute}' : 'Send at a specific date and time',
              style: const TextStyle(fontSize: 10.5, color: Color(0xFF64748B)),
            ),
          ],
        ),

        const Spacer(),

        // Save as Draft
        OutlinedButton(
          style: OutlinedButton.styleFrom(
            foregroundColor: isDark ? Colors.white : const Color(0xFF334155),
            side: BorderSide(color: isDark ? const Color(0xFF334155) : const Color(0xFFCBD5E1)),
            shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
            padding: const EdgeInsets.symmetric(horizontal: 18, vertical: 13),
          ),
          onPressed: _saveDraft,
          child: Text('Save as Draft', style: GoogleFonts.inter(fontWeight: FontWeight.w600, fontSize: 12.5)),
        ),
        const SizedBox(width: 12),

        // Send Broadcast Button
        ElevatedButton.icon(
          style: ElevatedButton.styleFrom(
            backgroundColor: const Color(0xFF4F46E5),
            foregroundColor: Colors.white,
            shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
            padding: const EdgeInsets.symmetric(horizontal: 22, vertical: 13),
            elevation: 2,
          ),
          onPressed: _isSending ? null : _dispatchBroadcast,
          icon: _isSending
              ? const SizedBox(width: 16, height: 16, child: CircularProgressIndicator(color: Colors.white, strokeWidth: 2))
              : const Icon(Icons.send_rounded, size: 16),
          label: Text(
            _isSending ? 'Dispatching...' : (_isScheduled ? 'Schedule Broadcast' : 'Send Broadcast'),
            style: GoogleFonts.inter(fontWeight: FontWeight.w700, fontSize: 12.5),
          ),
        ),
      ],
    );
  }

  // ===========================================================================
  // 4. MESSAGE PREVIEW (TELEGRAM MOCKUP CARD)
  // ===========================================================================
  Widget _buildMessagePreviewCard(bool isDark) {
    return Container(
      decoration: BoxDecoration(
        color: isDark ? AppTheme.darkCard : Colors.white,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: isDark ? AppTheme.darkBorderSubtle : const Color(0xFFE2E8F0)),
      ),
      padding: const EdgeInsets.all(18),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          // Header + Test Send Button
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Row(
                children: [
                  Container(
                    width: 28,
                    height: 28,
                    decoration: BoxDecoration(
                      color: const Color(0xFF6366F1).withValues(alpha: 0.12),
                      borderRadius: BorderRadius.circular(8),
                    ),
                    child: const Center(
                      child: Icon(Icons.send_rounded, color: Color(0xFF6366F1), size: 15),
                    ),
                  ),
                  const SizedBox(width: 8),
                  Text(
                    'Message Preview',
                    style: GoogleFonts.inter(
                      fontSize: 15,
                      fontWeight: FontWeight.w700,
                      color: isDark ? Colors.white : const Color(0xFF0F172A),
                    ),
                  ),
                ],
              ),
              OutlinedButton.icon(
                style: OutlinedButton.styleFrom(
                  foregroundColor: const Color(0xFF4F46E5),
                  side: const BorderSide(color: Color(0xFF818CF8)),
                  shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
                  padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
                ),
                onPressed: _isTesting ? null : _handleTestSend,
                icon: _isTesting
                    ? const SizedBox(width: 12, height: 12, child: CircularProgressIndicator(strokeWidth: 1.5))
                    : const Icon(Icons.science_outlined, size: 14),
                label: Text(
                  _isTesting ? 'Sending...' : 'Test Send',
                  style: GoogleFonts.inter(fontSize: 11.5, fontWeight: FontWeight.w600),
                ),
              ),
            ],
          ),
          const SizedBox(height: 14),

          // Telegram Wallpaper & Mockup Bubble
          Container(
            padding: const EdgeInsets.all(16),
            decoration: BoxDecoration(
              color: isDark ? const Color(0xFF0F172A) : const Color(0xFF759B74),
              borderRadius: BorderRadius.circular(12),
            ),
            child: Align(
              alignment: Alignment.centerLeft,
              child: Container(
                constraints: const BoxConstraints(maxWidth: 420),
                padding: const EdgeInsets.all(14),
                decoration: BoxDecoration(
                  color: isDark ? const Color(0xFF212D3B) : Colors.white,
                  borderRadius: const BorderRadius.only(
                    topLeft: Radius.circular(14),
                    topRight: Radius.circular(14),
                    bottomRight: Radius.circular(14),
                    bottomLeft: Radius.circular(3),
                  ),
                  boxShadow: [
                    BoxShadow(
                      color: Colors.black.withValues(alpha: 0.12),
                      blurRadius: 6,
                      offset: const Offset(0, 2),
                    ),
                  ],
                ),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    // Bot Header
                    Row(
                      children: [
                        Container(
                          width: 26,
                          height: 26,
                          decoration: BoxDecoration(
                            color: const Color(0xFF2563EB),
                            borderRadius: BorderRadius.circular(7),
                          ),
                          child: const Center(
                            child: Icon(Icons.smart_toy_rounded, color: Colors.white, size: 15),
                          ),
                        ),
                        const SizedBox(width: 8),
                        Text(
                          'Examplayer Bot',
                          style: GoogleFonts.inter(
                            fontSize: 12.5,
                            fontWeight: FontWeight.w700,
                            color: isDark ? Colors.white : const Color(0xFF0F172A),
                          ),
                        ),
                        const Spacer(),
                        Container(
                          padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                          decoration: BoxDecoration(
                            color: isDark ? const Color(0xFF334155) : const Color(0xFFF1F5F9),
                            borderRadius: BorderRadius.circular(4),
                          ),
                          child: Text(
                            'admin',
                            style: GoogleFonts.inter(
                              fontSize: 9.5,
                              fontWeight: FontWeight.w600,
                              color: isDark ? const Color(0xFF94A3B8) : const Color(0xFF64748B),
                            ),
                          ),
                        ),
                      ],
                    ),
                    const SizedBox(height: 10),

                    // Media preview (if photo or document attached)
                    if (_mediaUrlCtrl.text.trim().isNotEmpty) ...[
                      ClipRRect(
                        borderRadius: BorderRadius.circular(8),
                        child: Image.network(
                          _mediaUrlCtrl.text.trim(),
                          fit: BoxFit.cover,
                          height: 140,
                          width: double.infinity,
                          errorBuilder: (_, _, _) => Container(
                            height: 60,
                            color: const Color(0xFFEFF6FF),
                            child: const Center(
                              child: Row(
                                mainAxisSize: MainAxisSize.min,
                                children: [
                                  Icon(Icons.attachment_rounded, size: 18, color: Color(0xFF3B82F6)),
                                  SizedBox(width: 6),
                                  Text('Attached Media File', style: TextStyle(fontSize: 12, color: Color(0xFF1D4ED8))),
                                ],
                              ),
                            ),
                          ),
                        ),
                      ),
                      const SizedBox(height: 10),
                    ],

                    // Text Body with variable substitution
                    Text(
                      _renderPreviewText(),
                      style: GoogleFonts.inter(
                        fontSize: 12.5,
                        height: 1.45,
                        color: isDark ? Colors.white : const Color(0xFF0F172A),
                      ),
                    ),
                    const SizedBox(height: 12),

                    // Inline Action Buttons inside bubble
                    if (_inlineButtons.isNotEmpty)
                      Column(
                        children: _inlineButtons.map((btn) {
                          return Padding(
                            padding: const EdgeInsets.only(bottom: 6),
                            child: Container(
                              width: double.infinity,
                              padding: const EdgeInsets.symmetric(vertical: 8),
                              decoration: BoxDecoration(
                                color: isDark ? const Color(0xFF1E293B) : const Color(0xFFE0EDFD),
                                borderRadius: BorderRadius.circular(8),
                              ),
                              child: Center(
                                child: Text(
                                  btn['text'] ?? 'Click Here',
                                  style: GoogleFonts.inter(
                                    fontSize: 12,
                                    fontWeight: FontWeight.w700,
                                    color: const Color(0xFF2563EB),
                                  ),
                                ),
                              ),
                            ),
                          );
                        }).toList(),
                      ),

                    // Timestamp
                    Align(
                      alignment: Alignment.bottomRight,
                      child: Row(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          Text(
                            '10:30 AM',
                            style: TextStyle(
                              fontSize: 10,
                              color: isDark ? const Color(0xFF94A3B8) : const Color(0xFF64748B),
                            ),
                          ),
                          const SizedBox(width: 4),
                          const Icon(Icons.done_all_rounded, size: 13, color: Color(0xFF3B82F6)),
                        ],
                      ),
                    ),
                  ],
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }

  String _renderPreviewText() {
    var text = _msgCtrl.text;
    if (text.isEmpty) return 'Compose your announcement on the left to see live Telegram preview...';

    // Replace dynamic variables with sample values
    text = text.replaceAll('{first_name}', 'Rahul');
    text = text.replaceAll('{username}', '@rahul_upsc');
    text = text.replaceAll('{total_tests}', '14');
    text = text.replaceAll('{bot_name}', 'Examplayer Bot');
    text = text.replaceAll('{user_id}', '542918239');

    // Clean markdown stars for preview reading
    text = text.replaceAll('*', '');
    return text;
  }

  // ===========================================================================
  // 5. RECENT BROADCASTS TABLE
  // ===========================================================================
  Widget _buildRecentBroadcastsCard(bool isDark) {
    return Container(
      decoration: BoxDecoration(
        color: isDark ? AppTheme.darkCard : Colors.white,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: isDark ? AppTheme.darkBorderSubtle : const Color(0xFFE2E8F0)),
      ),
      padding: const EdgeInsets.all(18),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          // Header with View All
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Text(
                'Recent Broadcasts',
                style: GoogleFonts.inter(
                  fontSize: 15,
                  fontWeight: FontWeight.w700,
                  color: isDark ? Colors.white : const Color(0xFF0F172A),
                ),
              ),
              InkWell(
                onTap: () {
                  _loadBroadcastHistory();
                  widget.onShowToast('Refreshed recent broadcasts');
                },
                child: Text(
                  'View All',
                  style: GoogleFonts.inter(
                    fontSize: 12,
                    fontWeight: FontWeight.w700,
                    color: const Color(0xFF2563EB),
                  ),
                ),
              ),
            ],
          ),
          const SizedBox(height: 12),

          // Table / List
          if (_isLoadingHistory)
            const Padding(
              padding: EdgeInsets.all(20),
              child: Center(child: CircularProgressIndicator()),
            )
          else if (_broadcastHistory.isEmpty)
            Container(
              padding: const EdgeInsets.symmetric(vertical: 36, horizontal: 16),
              alignment: Alignment.center,
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  Container(
                    width: 48,
                    height: 48,
                    decoration: BoxDecoration(
                      color: isDark ? const Color(0xFF1E293B) : const Color(0xFFEFF6FF),
                      shape: BoxShape.circle,
                    ),
                    child: const Icon(Icons.campaign_outlined, size: 26, color: Color(0xFF3B82F6)),
                  ),
                  const SizedBox(height: 12),
                  Text(
                    'No Broadcasts Sent Yet',
                    style: GoogleFonts.inter(
                      fontSize: 13.5,
                      fontWeight: FontWeight.w700,
                      color: isDark ? Colors.white : const Color(0xFF0F172A),
                    ),
                  ),
                  const SizedBox(height: 4),
                  Text(
                    'Compose an announcement on the left to broadcast messages. Real-time delivery reports will appear here.',
                    textAlign: TextAlign.center,
                    style: GoogleFonts.inter(
                      fontSize: 11.5,
                      color: isDark ? const Color(0xFF94A3B8) : const Color(0xFF64748B),
                    ),
                  ),
                ],
              ),
            )
          else
            ListView.separated(
              shrinkWrap: true,
              physics: const NeverScrollableScrollPhysics(),
              itemCount: _broadcastHistory.take(5).length,
              separatorBuilder: (_, _) => const Divider(height: 1),
              itemBuilder: (ctx, i) {
                final b = _broadcastHistory[i];
                final isDelivered = (b['status'] ?? '').toString().toLowerCase() == 'delivered';
                final isFailed = (b['status'] ?? '').toString().toLowerCase() == 'failed';

                return Padding(
                  padding: const EdgeInsets.symmetric(vertical: 8),
                  child: Row(
                    children: [
                      // # Index
                      SizedBox(
                        width: 20,
                        child: Text(
                          '${i + 1}',
                          style: const TextStyle(fontSize: 11.5, color: Color(0xFF94A3B8)),
                        ),
                      ),
                      const SizedBox(width: 8),

                      // Title & Target
                      Expanded(
                        flex: 3,
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(
                              b['title'] ?? 'Broadcast Announcement',
                              style: GoogleFonts.inter(fontSize: 12.5, fontWeight: FontWeight.w600),
                              maxLines: 1,
                              overflow: TextOverflow.ellipsis,
                            ),
                            Text(
                              b['target'] ?? 'All Users',
                              style: const TextStyle(fontSize: 10.5, color: Color(0xFF64748B)),
                            ),
                          ],
                        ),
                      ),

                      // Sent On
                      Expanded(
                        flex: 2,
                        child: Text(
                          b['sentOn'] ?? 'Just now',
                          style: const TextStyle(fontSize: 11, color: Color(0xFF64748B)),
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                        ),
                      ),

                      // Status Pill
                      Container(
                        padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
                        decoration: BoxDecoration(
                          color: isDelivered
                              ? const Color(0xFFECFDF5)
                              : (isFailed ? const Color(0xFFFEF2F2) : const Color(0xFFFFFBEB)),
                          borderRadius: BorderRadius.circular(6),
                        ),
                        child: Text(
                          b['status'] ?? 'Delivered',
                          style: GoogleFonts.inter(
                            fontSize: 10.5,
                            fontWeight: FontWeight.w700,
                            color: isDelivered
                                ? const Color(0xFF10B981)
                                : (isFailed ? const Color(0xFFEF4444) : const Color(0xFFF59E0B)),
                          ),
                        ),
                      ),
                      const SizedBox(width: 10),

                      // Stats
                      SizedBox(
                        width: 75,
                        child: Text(
                          b['stats'] ?? '${b['delivered'] ?? 0} (96%)',
                          style: const TextStyle(fontSize: 11, fontWeight: FontWeight.w600),
                          textAlign: TextAlign.end,
                        ),
                      ),

                      // 3-dot popup menu
                      PopupMenuButton<String>(
                        icon: const Icon(Icons.more_vert_rounded, size: 16, color: Color(0xFF64748B)),
                        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
                        itemBuilder: (c) => [
                          const PopupMenuItem(value: 'reuse', child: Text('Reuse in Editor', style: TextStyle(fontSize: 12))),
                          const PopupMenuItem(value: 'delete', child: Text('Delete Record', style: TextStyle(fontSize: 12, color: Colors.red))),
                        ],
                        onSelected: (val) {
                          if (val == 'reuse') {
                            setState(() {
                              _titleCtrl.text = b['title'] ?? '';
                              _msgCtrl.text = b['message'] ?? '';
                              _inlineButtons.clear();
                              if (b['buttons'] != null && b['buttons'] is List) {
                                for (final btn in b['buttons']) {
                                  _inlineButtons.add(Map<String, String>.from(btn));
                                }
                              }
                            });
                            widget.onShowToast('Loaded into editor!');
                          } else if (val == 'delete') {
                            final bcId = b['id']?.toString() ?? '';
                            setState(() => _broadcastHistory.removeAt(i));
                            if (bcId.isNotEmpty) {
                              widget.api.deleteBroadcast(bcId);
                            }
                            widget.onShowToast('Broadcast removed from history');
                          }
                        },
                      ),
                    ],
                  ),
                );
              },
            ),
        ],
      ),
    );
  }
}
