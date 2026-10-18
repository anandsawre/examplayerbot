import 'dart:convert';
import 'package:http/http.dart' as http;
import 'package:web/web.dart' as web;

class ApiService {
  static final ApiService _instance = ApiService._internal();
  factory ApiService() => _instance;
  ApiService._internal() {
    try {
      final origin = Uri.base.origin;
      if (origin.startsWith('https://') || origin.contains(':3000')) {
        baseUrl = '$origin/api/admin';
      }
    } catch (_) {}
  }

  String baseUrl = 'https://examplayerbot.onrender.com/api/admin';

  String? authToken;
  String? masterKey;

  static const String _tokenStorageKey = 'examplayer_admin_token';
  static const String _keyStorageKey = 'examplayer_master_key';

  void _persistCredentials(String? token, [String? key]) {
    try {
      if (token != null && token.isNotEmpty) {
        web.window.localStorage.setItem(_tokenStorageKey, token);
      }
      if (key != null && key.isNotEmpty) {
        web.window.localStorage.setItem(_keyStorageKey, key);
      }
    } catch (_) {}
  }

  void _clearPersistedCredentials() {
    try {
      web.window.localStorage.removeItem(_tokenStorageKey);
      web.window.localStorage.removeItem(_keyStorageKey);
    } catch (_) {}
  }

  Future<bool> restoreSession() async {
    try {
      final savedToken = web.window.localStorage.getItem(_tokenStorageKey);
      final savedKey = web.window.localStorage.getItem(_keyStorageKey);

      final hasToken = savedToken != null && savedToken.isNotEmpty;
      final hasKey = savedKey != null && savedKey.isNotEmpty;

      if (!hasToken && !hasKey) {
        return false;
      }

      authToken = hasToken ? savedToken : null;
      masterKey = hasKey ? savedKey : null;

      final isValid = await verifySession();
      if (!isValid) {
        logout();
        return false;
      }
      return true;
    } catch (_) {
      return false;
    }
  }

  Map<String, String> get _headers {
    final headers = <String, String>{
      'Content-Type': 'application/json',
    };
    if (authToken != null && authToken!.isNotEmpty) {
      headers['Authorization'] = 'Bearer $authToken';
    } else if (masterKey != null && masterKey!.isNotEmpty) {
      headers['x-admin-key'] = masterKey!;
    }
    return headers;
  }

  // 1. AUTHENTICATION
  Future<Map<String, dynamic>> requestOtp(String telegramUserId) async {
    final res = await http.post(
      Uri.parse('$baseUrl/auth/request-otp'),
      headers: {'Content-Type': 'application/json'},
      body: jsonEncode({
        'userId': telegramUserId,
        'telegram_user_id': telegramUserId,
      }),
    );
    return jsonDecode(res.body);
  }

  Future<Map<String, dynamic>> verifyOtp(String telegramUserId, String code) async {
    final res = await http.post(
      Uri.parse('$baseUrl/auth/login'),
      headers: {'Content-Type': 'application/json'},
      body: jsonEncode({
        'type': 'otp',
        'userId': telegramUserId,
        'otp': code,
      }),
    );
    final data = jsonDecode(res.body);
    if (data['success'] == true && data['token'] != null) {
      authToken = data['token'];
      _persistCredentials(authToken);
    }
    return data;
  }

  Future<Map<String, dynamic>> loginWithPassword(String password) async {
    final res = await http.post(
      Uri.parse('$baseUrl/auth/login'),
      headers: {'Content-Type': 'application/json'},
      body: jsonEncode({
        'type': 'password',
        'password': password,
        'key': password,
      }),
    );
    final data = jsonDecode(res.body);
    if (data['success'] == true && data['token'] != null) {
      authToken = data['token'];
      masterKey = password;
      _persistCredentials(authToken, masterKey);
    }
    return data;
  }

  Future<bool> verifySession() async {
    try {
      final res = await http.get(Uri.parse('$baseUrl/auth/verify'), headers: _headers);
      if (res.statusCode == 200) {
        final data = jsonDecode(res.body);
        return data['success'] == true;
      }
      if (res.statusCode == 404) {
        // Fallback to /stats if /auth/verify is not yet active on running server
        final statsRes = await http.get(Uri.parse('$baseUrl/stats'), headers: _headers);
        if (statsRes.statusCode == 200) {
          final statsData = jsonDecode(statsRes.body);
          return statsData['success'] == true;
        }
      }
      return false;
    } catch (_) {
      return false;
    }
  }

  void logout() {
    try {
      if (authToken != null) {
        http.post(
          Uri.parse('$baseUrl/auth/logout'),
          headers: _headers,
        ).catchError((_) => http.Response('', 200));
      }
    } catch (_) {}
    authToken = null;
    masterKey = null;
    _clearPersistedCredentials();
  }

  // 2. DASHBOARD KPI STATS
  Future<Map<String, dynamic>> getStats() async {
    final res = await http.get(Uri.parse('$baseUrl/stats'), headers: _headers);
    return jsonDecode(res.body);
  }

  // 3. FOLDERS / CATEGORIES MANAGEMENT
  Future<List<dynamic>> getFolders() async {
    final res = await http.get(Uri.parse('$baseUrl/folders'), headers: _headers);
    final data = jsonDecode(res.body);
    return data['folders'] ?? [];
  }

  Future<Map<String, dynamic>> createFolder(String name, {String? parentId}) async {
    final res = await http.post(
      Uri.parse('$baseUrl/folders'),
      headers: _headers,
      body: jsonEncode({'name': name, 'parentId': parentId}),
    );
    return jsonDecode(res.body);
  }

  Future<Map<String, dynamic>> updateFolder(String folderId, String newName, {String? parentId}) async {
    final body = <String, dynamic>{'name': newName};
    if (parentId != null) body['parentId'] = parentId;
    final res = await http.put(
      Uri.parse('$baseUrl/folders/$folderId'),
      headers: _headers,
      body: jsonEncode(body),
    );
    return jsonDecode(res.body);
  }

  Future<Map<String, dynamic>> deleteFolder(String folderId) async {
    final res = await http.delete(Uri.parse('$baseUrl/folders/$folderId'), headers: _headers);
    return jsonDecode(res.body);
  }

  // 4. QUIZZES & TESTS MANAGEMENT
  Future<List<dynamic>> getQuizzes() async {
    final res = await http.get(Uri.parse('$baseUrl/quizzes'), headers: _headers);
    final data = jsonDecode(res.body);
    return data['quizzes'] ?? [];
  }

  Future<Map<String, dynamic>> createQuiz({
    required String title,
    String category = 'General',
    String description = '',
    double marksPerQuestion = 2.0,
    double negativeMarks = 0.5,
    int timeLimitSeconds = 30,
    bool isPremium = false,
    String? folderId,
  }) async {
    final res = await http.post(
      Uri.parse('$baseUrl/quizzes'),
      headers: _headers,
      body: jsonEncode({
        'title': title,
        'category': category,
        'description': description,
        'marks_per_question': marksPerQuestion,
        'negative_marks': negativeMarks,
        'time_limit_seconds': timeLimitSeconds,
        'is_premium': isPremium,
        'folder_id': folderId,
      }),
    );
    return jsonDecode(res.body);
  }

  Future<Map<String, dynamic>> updateQuiz(String quizId, Map<String, dynamic> updateData) async {
    final res = await http.put(
      Uri.parse('$baseUrl/quizzes/$quizId'),
      headers: _headers,
      body: jsonEncode(updateData),
    );
    return jsonDecode(res.body);
  }

  Future<Map<String, dynamic>> deleteQuiz(String quizId) async {
    final res = await http.delete(Uri.parse('$baseUrl/quizzes/$quizId'), headers: _headers);
    return jsonDecode(res.body);
  }

  Future<Map<String, dynamic>> importQuizJson(String jsonText, {String? folderId}) async {
    Map<String, dynamic> payload;
    try {
      payload = jsonDecode(jsonText);
    } catch (_) {
      payload = {'title': 'Imported Quiz', 'questions': []};
    }
    if (folderId != null && folderId.isNotEmpty) {
      payload['folder_id'] = folderId;
    }

    final res = await http.post(
      Uri.parse('$baseUrl/quizzes/import'),
      headers: _headers,
      body: jsonEncode(payload),
    );
    return jsonDecode(res.body);
  }

  // 5. QUESTIONS MANAGEMENT
  Future<List<dynamic>> getQuizQuestions(String quizId) async {
    final res = await http.get(Uri.parse('$baseUrl/quizzes/$quizId/questions'), headers: _headers);
    final data = jsonDecode(res.body);
    return data['questions'] ?? [];
  }

  Future<Map<String, dynamic>> addQuestion(String quizId, {
    required String questionText,
    required List<String> options,
    required int correctOptionIndex,
    String? explanation,
  }) async {
    final res = await http.post(
      Uri.parse('$baseUrl/quizzes/$quizId/questions'),
      headers: _headers,
      body: jsonEncode({
        'question_text': questionText,
        'options': options,
        'correct_option_index': correctOptionIndex,
        'explanation': explanation,
      }),
    );
    return jsonDecode(res.body);
  }

  Future<Map<String, dynamic>> updateQuestion(String questionId, {
    String? questionText,
    List<String>? options,
    int? correctOptionIndex,
    String? explanation,
  }) async {
    final payload = <String, dynamic>{};
    if (questionText != null) payload['question_text'] = questionText;
    if (options != null) payload['options'] = options;
    if (correctOptionIndex != null) payload['correct_option_index'] = correctOptionIndex;
    if (explanation != null) payload['explanation'] = explanation;

    final res = await http.put(
      Uri.parse('$baseUrl/questions/$questionId'),
      headers: _headers,
      body: jsonEncode(payload),
    );
    return jsonDecode(res.body);
  }

  Future<Map<String, dynamic>> deleteQuestion(String questionId) async {
    final res = await http.delete(Uri.parse('$baseUrl/questions/$questionId'), headers: _headers);
    return jsonDecode(res.body);
  }

  Future<Map<String, dynamic>> duplicateQuiz(String quizId) async {
    final res = await http.post(
      Uri.parse('$baseUrl/quizzes/$quizId/duplicate'),
      headers: _headers,
    );
    return jsonDecode(res.body);
  }

  Future<Map<String, dynamic>> importQuestionsBulk(String quizId, List<Map<String, dynamic>> questions) async {
    final res = await http.post(
      Uri.parse('$baseUrl/quizzes/$quizId/bulk-questions'),
      headers: _headers,
      body: jsonEncode(questions),
    );
    return jsonDecode(res.body);
  }

  // 6. STUDENTS & USERS DIRECTORY
  Future<List<dynamic>> getUsers({String query = '', String tier = 'all'}) async {
    final uri = Uri.parse('$baseUrl/users').replace(queryParameters: {
      if (query.isNotEmpty) 'q': query,
      if (tier != 'all') 'tier': tier,
    });
    final res = await http.get(uri, headers: _headers);
    final data = jsonDecode(res.body);
    return data['users'] ?? [];
  }

  Future<Map<String, dynamic>> toggleUserPremium(dynamic userId, bool isPremium) async {
    final res = await http.post(
      Uri.parse('$baseUrl/users/$userId/toggle-premium'),
      headers: _headers,
      body: jsonEncode({'is_premium': isPremium}),
    );
    return jsonDecode(res.body);
  }

  Future<Map<String, dynamic>> sendUserMessage(dynamic userId, String message) async {
    final res = await http.post(
      Uri.parse('$baseUrl/users/$userId/message'),
      headers: _headers,
      body: jsonEncode({'message': message}),
    );
    return jsonDecode(res.body);
  }

  Future<Map<String, dynamic>> resetUserProgress(dynamic userId) async {
    final res = await http.post(
      Uri.parse('$baseUrl/users/$userId/reset-progress'),
      headers: _headers,
    );
    return jsonDecode(res.body);
  }

  Future<Map<String, dynamic>> toggleUserBlock(dynamic userId, {bool? isBlocked}) async {
    final body = <String, dynamic>{};
    if (isBlocked != null) {
      body['is_blocked'] = isBlocked;
    }
    final res = await http.post(
      Uri.parse('$baseUrl/users/$userId/toggle-block'),
      headers: _headers,
      body: jsonEncode(body),
    );
    return jsonDecode(res.body);
  }

  Future<Map<String, dynamic>> deleteUser(dynamic userId) async {
    final res = await http.delete(
      Uri.parse('$baseUrl/users/$userId'),
      headers: _headers,
    );
    return jsonDecode(res.body);
  }

  Future<Map<String, dynamic>> createUser({
    required String id,
    required String firstName,
    String? username,
    String plan = 'Free',
  }) async {
    final res = await http.post(
      Uri.parse('$baseUrl/users/create'),
      headers: _headers,
      body: jsonEncode({
        'id': id,
        'first_name': firstName,
        'username': username,
        'plan': plan,
      }),
    );
    return jsonDecode(res.body);
  }

  Future<Map<String, dynamic>> importUsers(List<Map<String, dynamic>> users) async {
    final res = await http.post(
      Uri.parse('$baseUrl/users/import'),
      headers: _headers,
      body: jsonEncode({'users': users}),
    );
    return jsonDecode(res.body);
  }

  Future<List<dynamic>> getUserAttempts(dynamic userId) async {
    try {
      final res = await http.get(
        Uri.parse('$baseUrl/users/$userId/attempts'),
        headers: _headers,
      );
      if (res.statusCode == 200) {
        final data = jsonDecode(res.body);
        return (data['attempts'] as List?) ?? [];
      }
      return [];
    } catch (_) {
      return [];
    }
  }

  // 7. ADMINISTRATORS MANAGEMENT
  Future<List<dynamic>> getAdmins() async {
    final res = await http.get(Uri.parse('$baseUrl/admins'), headers: _headers);
    final data = jsonDecode(res.body);
    return data['admins'] ?? [];
  }

  Future<Map<String, dynamic>> addAdmin(String userId) async {
    final res = await http.post(
      Uri.parse('$baseUrl/admins/add'),
      headers: _headers,
      body: jsonEncode({'userId': userId}),
    );
    return jsonDecode(res.body);
  }

  Future<Map<String, dynamic>> removeAdmin(String userId) async {
    final res = await http.post(
      Uri.parse('$baseUrl/admins/remove'),
      headers: _headers,
      body: jsonEncode({'userId': userId}),
    );
    return jsonDecode(res.body);
  }

  // 8. COMMUNITY GROUPS & LIVE BATTLES
  Future<List<dynamic>> getAuthorizedGroups() async {
    final res = await http.get(Uri.parse('$baseUrl/groups'), headers: _headers);
    final data = jsonDecode(res.body);
    return data['groups'] ?? [];
  }

  Future<Map<String, dynamic>> authorizeGroup(String groupId, String groupTitle) async {
    final res = await http.post(
      Uri.parse('$baseUrl/groups'),
      headers: _headers,
      body: jsonEncode({'groupId': groupId, 'groupTitle': groupTitle}),
    );
    return jsonDecode(res.body);
  }

  Future<Map<String, dynamic>> toggleGroupStatus(dynamic groupId, bool isActive, {String groupTitle = ''}) async {
    final res = await http.post(
      Uri.parse('$baseUrl/groups/$groupId/toggle'),
      headers: _headers,
      body: jsonEncode({'isActive': isActive, 'groupTitle': groupTitle}),
    );
    return jsonDecode(res.body);
  }

  Future<Map<String, dynamic>> deleteGroup(dynamic groupId) async {
    final res = await http.delete(Uri.parse('$baseUrl/groups/$groupId'), headers: _headers);
    return jsonDecode(res.body);
  }

  Future<Map<String, dynamic>> launchGroupBattle(dynamic groupId, String quizId) async {
    final res = await http.post(
      Uri.parse('$baseUrl/groups/$groupId/launch'),
      headers: _headers,
      body: jsonEncode({'quizId': quizId}),
    );
    return jsonDecode(res.body);
  }

  Future<Map<String, dynamic>> scheduleGroupBattle(dynamic groupId, String quizId, {int? delayMinutes, String? timeStr}) async {
    final payload = <String, dynamic>{'quizId': quizId};
    if (delayMinutes != null) payload['delayMinutes'] = delayMinutes;
    if (timeStr != null) payload['timeStr'] = timeStr;

    final res = await http.post(
      Uri.parse('$baseUrl/groups/$groupId/schedule'),
      headers: _headers,
      body: jsonEncode(payload),
    );
    return jsonDecode(res.body);
  }

  Future<Map<String, dynamic>> cancelGroupSchedule(dynamic groupId) async {
    final res = await http.post(
      Uri.parse('$baseUrl/groups/$groupId/cancel-schedule'),
      headers: _headers,
      body: jsonEncode({}),
    );
    return jsonDecode(res.body);
  }

  // 9. LEADERBOARDS & MERIT DIRECTORY
  Future<List<dynamic>> getGlobalLeaderboard() async {
    try {
      final res = await http.get(Uri.parse('$baseUrl/leaderboard/global'), headers: _headers);
      if (res.statusCode == 200) {
        final data = jsonDecode(res.body);
        return (data['leaderboard'] as List?) ?? [];
      }
      return [];
    } catch (_) {
      return [];
    }
  }

  Future<Map<String, dynamic>> getQuizLeaderboard(String quizId) async {
    try {
      final res = await http.get(Uri.parse('$baseUrl/leaderboard/quiz/$quizId'), headers: _headers);
      if (res.statusCode == 200) {
        return jsonDecode(res.body) as Map<String, dynamic>;
      }
      return {};
    } catch (_) {
      return {};
    }
  }

  // 10. SETTINGS & MONETIZATION
  Future<Map<String, dynamic>> getSettings() async {
    final res = await http.get(Uri.parse('$baseUrl/settings'), headers: _headers);
    final data = jsonDecode(res.body);
    return data['settings'] ?? {};
  }

  Future<Map<String, dynamic>> updateSettings({String? upiId, String? price, String? channel}) async {
    final payload = <String, dynamic>{};
    if (upiId != null) payload['upiId'] = upiId;
    if (price != null) payload['price'] = price;
    if (channel != null) payload['channel'] = channel;

    final res = await http.post(
      Uri.parse('$baseUrl/settings'),
      headers: _headers,
      body: jsonEncode(payload),
    );
    return jsonDecode(res.body);
  }

  // 11. BROADCAST TOOL & STUDIO SUITE
  Future<Map<String, dynamic>> broadcastMessage(String message, {String target = 'all'}) async {
    return sendBroadcast(message: message, target: target);
  }

  Future<Map<String, dynamic>> sendBroadcast({
    required String message,
    String? title,
    String type = 'text',
    String? mediaUrl,
    List<Map<String, dynamic>>? buttons,
    String target = 'all',
    String? planType,
    List<int>? specificUserIds,
    bool isTest = false,
    String? testChatId,
  }) async {
    try {
      final payload = <String, dynamic>{
        'message': message,
        'title': title ?? (message.length > 30 ? '${message.substring(0, 30)}...' : message),
        'type': type,
        'target': target,
        'isTest': isTest,
      };
      if (mediaUrl != null && mediaUrl.isNotEmpty) payload['mediaUrl'] = mediaUrl;
      if (buttons != null && buttons.isNotEmpty) payload['buttons'] = buttons;
      if (planType != null) payload['planType'] = planType;
      if (specificUserIds != null && specificUserIds.isNotEmpty) payload['specificUserIds'] = specificUserIds;
      if (testChatId != null && testChatId.isNotEmpty) payload['testChatId'] = testChatId;

      final res = await http.post(
        Uri.parse('$baseUrl/broadcast'),
        headers: _headers,
        body: jsonEncode(payload),
      );
      return jsonDecode(res.body);
    } catch (e) {
      return {'success': false, 'error': e.toString()};
    }
  }

  Future<Map<String, dynamic>> sendTestBroadcast({
    required String message,
    String type = 'text',
    String? mediaUrl,
    List<Map<String, dynamic>>? buttons,
    String? testChatId,
  }) async {
    try {
      final payload = <String, dynamic>{
        'message': message,
        'type': type,
        'testChatId': testChatId,
      };
      if (mediaUrl != null && mediaUrl.isNotEmpty) payload['mediaUrl'] = mediaUrl;
      if (buttons != null && buttons.isNotEmpty) payload['buttons'] = buttons;

      final res = await http.post(
        Uri.parse('$baseUrl/broadcast/test'),
        headers: _headers,
        body: jsonEncode(payload),
      );
      return jsonDecode(res.body);
    } catch (e) {
      return {'success': false, 'error': e.toString()};
    }
  }

  Future<List<dynamic>> getBroadcastHistory() async {
    try {
      final res = await http.get(Uri.parse('$baseUrl/broadcast/history'), headers: _headers);
      final data = jsonDecode(res.body);
      return data['history'] ?? [];
    } catch (_) {
      return [];
    }
  }

  Future<Map<String, dynamic>> getBroadcastStats() async {
    try {
      final res = await http.get(Uri.parse('$baseUrl/broadcast/stats'), headers: _headers);
      final data = jsonDecode(res.body);
      return data['stats'] ?? {};
    } catch (_) {
      return {};
    }
  }

  Future<Map<String, dynamic>> deleteBroadcast(String id) async {
    try {
      final res = await http.delete(Uri.parse('$baseUrl/broadcast/$id'), headers: _headers);
      return jsonDecode(res.body);
    } catch (e) {
      return {'success': false, 'error': e.toString()};
    }
  }

  // 12. LEADERBOARDS & MERIT ANALYTICS
  Future<Map<String, dynamic>> getLeaderboardAnalytics() async {
    try {
      final res = await http.get(Uri.parse('$baseUrl/leaderboard/analytics'), headers: _headers);
      if (res.statusCode == 200) {
        return jsonDecode(res.body) as Map<String, dynamic>;
      }
      return {};
    } catch (_) {
      return {};
    }
  }

  // 13. PAYMENTS & PLANS MANAGEMENT
  Future<List<dynamic>> getSubscriptionPlans() async {
    try {
      final res = await http.get(Uri.parse('$baseUrl/plans'), headers: _headers);
      if (res.statusCode == 200) {
        final data = jsonDecode(res.body);
        return (data['plans'] as List?) ?? [];
      }
      return [];
    } catch (_) {
      return [];
    }
  }

  Future<Map<String, dynamic>> saveSubscriptionPlan(Map<String, dynamic> plan) async {
    try {
      final res = await http.post(
        Uri.parse('$baseUrl/plans'),
        headers: _headers,
        body: jsonEncode(plan),
      );
      return jsonDecode(res.body);
    } catch (e) {
      return {'success': false, 'error': e.toString()};
    }
  }

  Future<List<dynamic>> getPaymentTransactions() async {
    try {
      final res = await http.get(Uri.parse('$baseUrl/transactions'), headers: _headers);
      if (res.statusCode == 200) {
        final data = jsonDecode(res.body);
        return (data['transactions'] as List?) ?? [];
      }
      return [];
    } catch (_) {
      return [];
    }
  }

  Future<Map<String, dynamic>> refundTransaction(String transactionId) async {
    try {
      final res = await http.post(
        Uri.parse('$baseUrl/transactions/refund'),
        headers: _headers,
        body: jsonEncode({'transactionId': transactionId}),
      );
      return jsonDecode(res.body);
    } catch (e) {
      return {'success': false, 'error': e.toString()};
    }
  }

  Future<Map<String, dynamic>> getPaymentStats() async {
    try {
      final res = await http.get(Uri.parse('$baseUrl/payments/stats'), headers: _headers);
      if (res.statusCode == 200) {
        return jsonDecode(res.body) as Map<String, dynamic>;
      }
      return {};
    } catch (_) {
      return {};
    }
  }

  Future<List<dynamic>> getPaymentGateways() async {
    try {
      final res = await http.get(Uri.parse('$baseUrl/payment-methods'), headers: _headers);
      if (res.statusCode == 200) {
        final data = jsonDecode(res.body);
        return (data['gateways'] as List?) ?? [];
      }
      return [];
    } catch (_) {
      return [];
    }
  }

  Future<Map<String, dynamic>> savePaymentGateways(List<dynamic> gateways) async {
    try {
      final res = await http.post(
        Uri.parse('$baseUrl/payment-methods'),
        headers: _headers,
        body: jsonEncode({'gateways': gateways}),
      );
      return jsonDecode(res.body);
    } catch (e) {
      return {'success': false, 'error': e.toString()};
    }
  }

  // 14. ADMINS HUB
  Future<Map<String, dynamic>> getAdminsHubData() async {
    try {
      final res = await http.get(Uri.parse('$baseUrl/admins/hub'), headers: _headers);
      if (res.statusCode == 200) {
        return jsonDecode(res.body) as Map<String, dynamic>;
      }
      return {};
    } catch (_) {
      return {};
    }
  }

  Future<Map<String, dynamic>> updateAdminRole(Map<String, dynamic> admin) async {
    try {
      final res = await http.post(
        Uri.parse('$baseUrl/admins/update-role'),
        headers: _headers,
        body: jsonEncode(admin),
      );
      return jsonDecode(res.body);
    } catch (e) {
      return {'success': false, 'error': e.toString()};
    }
  }

  // 15. GROUPS & COMMUNITY
  Future<Map<String, dynamic>> getGroupsHubData() async {
    try {
      final res = await http.get(Uri.parse('$baseUrl/groups/hub'), headers: _headers);
      if (res.statusCode == 200) {
        return jsonDecode(res.body) as Map<String, dynamic>;
      }
      return {};
    } catch (_) {
      return {};
    }
  }

  Future<Map<String, dynamic>> createGroupInviteLink(String groupId) async {
    try {
      final res = await http.post(
        Uri.parse('$baseUrl/groups/invite-link'),
        headers: _headers,
        body: jsonEncode({'groupId': groupId}),
      );
      return jsonDecode(res.body);
    } catch (e) {
      return {'success': false, 'error': e.toString()};
    }
  }

  // 16. BOT MANAGEMENT & SETTINGS
  Future<Map<String, dynamic>> getBotStatus() async {
    try {
      final res = await http.get(Uri.parse('$baseUrl/bot/status'), headers: _headers);
      if (res.statusCode == 200) {
        return jsonDecode(res.body) as Map<String, dynamic>;
      }
      return {};
    } catch (_) {
      return {};
    }
  }

  Future<Map<String, dynamic>> triggerBotControl(String action) async {
    try {
      final res = await http.post(
        Uri.parse('$baseUrl/bot/controls'),
        headers: _headers,
        body: jsonEncode({'action': action}),
      );
      return jsonDecode(res.body);
    } catch (e) {
      return {'success': false, 'error': e.toString()};
    }
  }

  Future<Map<String, dynamic>> configureBotWebhook({String? url, bool testOnly = false}) async {
    try {
      final res = await http.post(
        Uri.parse('$baseUrl/bot/webhook'),
        headers: _headers,
        body: jsonEncode({'url': url, 'testOnly': testOnly}),
      );
      return jsonDecode(res.body);
    } catch (e) {
      return {'success': false, 'error': e.toString()};
    }
  }

  Future<Map<String, dynamic>> saveBotOperationalSettings(Map<String, dynamic> settings) async {
    try {
      final res = await http.post(
        Uri.parse('$baseUrl/bot/operational-settings'),
        headers: _headers,
        body: jsonEncode({'settings': settings}),
      );
      return jsonDecode(res.body);
    } catch (e) {
      return {'success': false, 'error': e.toString()};
    }
  }

  Future<Map<String, dynamic>> updateBotProfile({String? name, String? description}) async {
    try {
      final res = await http.post(
        Uri.parse('$baseUrl/bot/profile'),
        headers: _headers,
        body: jsonEncode({'name': name, 'description': description}),
      );
      return jsonDecode(res.body);
    } catch (e) {
      return {'success': false, 'error': e.toString()};
    }
  }
}


