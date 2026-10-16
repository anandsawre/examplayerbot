import 'dart:convert';
import 'package:http/http.dart' as http;

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
    }
    return data;
  }

  Future<bool> verifySession() async {
    try {
      final res = await http.get(Uri.parse('$baseUrl/stats'), headers: _headers);
      if (res.statusCode == 200) {
        final data = jsonDecode(res.body);
        return data['success'] == true;
      }
      return false;
    } catch (_) {
      return false;
    }
  }

  void logout() {
    authToken = null;
    masterKey = null;
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

  Future<Map<String, dynamic>> updateFolder(String folderId, String newName) async {
    final res = await http.put(
      Uri.parse('$baseUrl/folders/$folderId'),
      headers: _headers,
      body: jsonEncode({'name': newName}),
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

  // 11. BROADCAST TOOL (MULTI-TARGET BLAST)
  Future<Map<String, dynamic>> broadcastMessage(String message, {String target = 'all'}) async {
    final res = await http.post(
      Uri.parse('$baseUrl/broadcast'),
      headers: _headers,
      body: jsonEncode({
        'message': message,
        'target': target, // 'users' | 'groups' | 'all'
      }),
    );
    return jsonDecode(res.body);
  }
}
