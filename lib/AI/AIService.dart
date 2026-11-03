import 'dart:async';
import 'dart:convert';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/foundation.dart';
import 'package:http/http.dart' as http;

import 'AIChatMessage.dart';
import 'AIPrompt.dart';

/// Service responsible for CreatorConnect AI logic, Gemini API communication,
/// Firestore chat persistence, and role-based grounded creator matching.
class AIService {
  static final AIService _instance = AIService._internal();
  factory AIService() => _instance;
  AIService._internal();

  final FirebaseFirestore _firestore = FirebaseFirestore.instance;
  final FirebaseAuth _auth = FirebaseAuth.instance;

  // Gemini configuration
  // Securely passed via compile-time environment variable:
  // flutter run --dart-define=GEMINI_API_KEY=YOUR_GEMINI_KEY
  // or via Firebase Cloud Functions backend URL:
  // flutter run --dart-define=AI_BACKEND_URL=https://...

  static const String _geminiApiKey = String.fromEnvironment('GEMINI_API_KEY');
  static const String _backendUrl = String.fromEnvironment('AI_BACKEND_URL');

  // Supported model versions (ordered by preference and real-time reliability)
  static const List<String> _candidateModels = [
    'gemini-flash-lite-latest',
    'gemini-3.8-flash',
    'gemini-flash-latest',
  ];

  // Request lock to prevent duplicate concurrent submissions
  bool _isProcessing = false;
  bool get isProcessing => _isProcessing;

  // Cache user role and profile to avoid repeated Firestore lookups
  String? _cachedRole;
  String? _cachedName;
  String? _cachedUid;

  /// Fetches and caches the logged-in user's role from Firestore `users/{uid}`
  Future<String> getCurrentUserRole() async {
    final user = _auth.currentUser;
    if (user == null) return 'Influencer';

    if (_cachedUid == user.uid && _cachedRole != null) {
      return _cachedRole!;
    }

    try {
      var doc = await _firestore.collection('Profile_Data').doc(user.uid).get();
      if (!doc.exists) {
        doc = await _firestore.collection('users').doc(user.uid).get();
      }
      if (doc.exists) {
        final data = doc.data();
        final role = data?['role']?.toString().trim();
        final name = data?['fullName'] ?? data?['name'] ?? user.displayName;
        if (role != null && role.isNotEmpty) {
          _cachedUid = user.uid;
          _cachedRole = role;
          _cachedName = name?.toString();
          return role;
        }
      }
    } catch (e) {
      debugPrint('Error fetching user role for AI: $e');
    }

    return 'Influencer';
  }

  /// Returns the cached user name
  Future<String?> getCurrentUserName() async {
    if (_cachedName != null) return _cachedName;
    await getCurrentUserRole();
    return _cachedName;
  }

  /// Clears cache on logout/re-auth
  void clearUserCache() {
    _cachedRole = null;
    _cachedName = null;
    _cachedUid = null;
  }

  // ---------------------------------------------------------------------------
  // FIRESTORE CHAT PERSISTENCE
  // Structure: users/{userId}/ai_chats/{chatId}/messages/{messageId}
  // ---------------------------------------------------------------------------

  /// Creates a new chat session document and returns its unique ID
  Future<String> createNewChat({
    required String initialMessage,
    required String role,
  }) async {
    final user = _auth.currentUser;
    if (user == null) throw Exception('User is not authenticated.');

    final chatRef = _firestore
        .collection('Profile_Data')
        .doc(user.uid)
        .collection('ai_chats')
        .doc();

    final title = initialMessage.trim().length > 42
        ? '${initialMessage.trim().substring(0, 39)}...'
        : initialMessage.trim();

    await chatRef.set({
      'chatId': chatRef.id,
      'title': title.isEmpty ? 'New Conversation' : title,
      'userId': user.uid,
      'userRole': role,
      'createdAt': FieldValue.serverTimestamp(),
      'updatedAt': FieldValue.serverTimestamp(),
      'lastMessage': initialMessage.trim(),
    });

    return chatRef.id;
  }

  /// Updates existing chat metadata
  Future<void> updateChatMetadata({
    required String chatId,
    required String lastMessage,
  }) async {
    final user = _auth.currentUser;
    if (user == null) return;

    final chatRef = _firestore
        .collection('Profile_Data')
        .doc(user.uid)
        .collection('ai_chats')
        .doc(chatId);

    await chatRef.set({
      'updatedAt': FieldValue.serverTimestamp(),
      'lastMessage': lastMessage.length > 80
          ? '${lastMessage.substring(0, 77)}...'
          : lastMessage,
    }, SetOptions(merge: true));
  }

  /// Saves a message in Firestore
  Future<void> saveMessage(AIChatMessage message) async {
    final user = _auth.currentUser;
    if (user == null) return;

    final messageRef = _firestore
        .collection('Profile_Data')
        .doc(user.uid)
        .collection('ai_chats')
        .doc(message.chatId)
        .collection('messages')
        .doc(message.id);

    await messageRef.set(message.toFirestore());
  }

  /// Real-time stream of messages for a given chat session
  Stream<List<AIChatMessage>> getChatMessagesStream(String chatId) {
    final user = _auth.currentUser;
    if (user == null) return const Stream.empty();

    return _firestore
        .collection('Profile_Data')
        .doc(user.uid)
        .collection('ai_chats')
        .doc(chatId)
        .collection('messages')
        .orderBy('clientTimestamp', descending: false)
        .snapshots()
        .map((snapshot) {
          return snapshot.docs
              .map((doc) => AIChatMessage.fromFirestore(doc))
              .toList();
        });
  }

  /// Stream of user chat sessions for History screen
  Stream<List<Map<String, dynamic>>> getUserChatsStream() {
    final user = _auth.currentUser;
    if (user == null) return const Stream.empty();

    return _firestore
        .collection('Profile_Data')
        .doc(user.uid)
        .collection('ai_chats')
        .orderBy('updatedAt', descending: true)
        .snapshots()
        .map((snapshot) {
          return snapshot.docs.map((doc) {
            final data = doc.data();
            return {
              'chatId': doc.id,
              'title': data['title'] ?? 'Chat',
              'userRole': data['userRole'] ?? '',
              'lastMessage': data['lastMessage'] ?? '',
              'updatedAt':
                  _extractDateTime(data['updatedAt']) ??
                  _extractDateTime(data['createdAt']) ??
                  DateTime.now(),
            };
          }).toList();
        });
  }

  DateTime? _extractDateTime(dynamic field) {
    if (field is Timestamp) return field.toDate();
    if (field is int) return DateTime.fromMillisecondsSinceEpoch(field);
    if (field is String) return DateTime.tryParse(field);
    return null;
  }

  /// Deletes a chat session and its subcollection messages
  Future<void> deleteChat(String chatId) async {
    final user = _auth.currentUser;
    if (user == null) return;

    final chatDoc = _firestore
        .collection('Profile_Data')
        .doc(user.uid)
        .collection('ai_chats')
        .doc(chatId);

    // Delete subcollection messages
    final messagesSnapshot = await chatDoc.collection('messages').get();
    final batch = _firestore.batch();
    for (final doc in messagesSnapshot.docs) {
      batch.delete(doc.reference);
    }
    batch.delete(chatDoc);
    await batch.commit();
  }

  // ---------------------------------------------------------------------------
  // ADVANCED CREATOR MATCHING
  // Searches actual Firestore records to prevent hallucinations
  // ---------------------------------------------------------------------------

  /// Checks if the user's message is asking for creator recommendations
  bool isCreatorRecommendationQuery(String query) {
    final lower = query.toLowerCase();
    final creatorKeywords = [
      'find',
      'recommend',
      'search',
      'look for',
      'hire',
      'editor',
      'video editor',
      'writer',
      'influencer',
      'creator',
      'freelancer',
      'who can edit',
      'who can write',
      'suggest someone',
      'talent',
    ];

    int matches = 0;
    for (final kw in creatorKeywords) {
      if (lower.contains(kw)) matches++;
    }

    return matches >= 2 ||
        lower.contains('find a') ||
        lower.contains('find an') ||
        lower.contains('recommend a') ||
        lower.contains('looking for');
  }

  /// Queries Firestore for actual creators matching role, skills, location, category
  Future<List<Map<String, dynamic>>> findMatchingCreators(
    String userQuery,
  ) async {
    final lower = userQuery.toLowerCase();
    final currentUid = _auth.currentUser?.uid;

    // 1. Determine target role
    String? targetRole;
    if (lower.contains('editor') || lower.contains('video editor')) {
      targetRole = 'Editor';
    } else if (lower.contains('writer') ||
        lower.contains('script') ||
        lower.contains('copywriter')) {
      targetRole = 'Writer';
    } else if (lower.contains('influencer') ||
        lower.contains('vlogger') ||
        lower.contains('model')) {
      targetRole = 'Influencer';
    }

    // 2. Extract potential location keywords (e.g., Pune, Mumbai, Delhi, Bangalore)
    final commonCities = [
      'pune',
      'mumbai',
      'delhi',
      'bangalore',
      'bengaluru',
      'hyderabad',
      'chennai',
      'kolkata',
      'ahmedabad',
      'jaipur',
      'surat',
      'noida',
      'gurugram',
      'remote',
    ];
    String? matchedLocation;
    for (final city in commonCities) {
      if (lower.contains(city)) {
        matchedLocation = city;
        break;
      }
    }

    try {
      Query<Map<String, dynamic>> query = _firestore.collection('Profile_Data');

      // Filter by role if identified
      if (targetRole != null) {
        if (targetRole == 'Editor') {
          query = query.where('role', whereIn: ['Editor', 'Video Editor']);
        } else {
          query = query.where('role', isEqualTo: targetRole);
        }
      } else {
        query = query.where(
          'role',
          whereIn: ['Influencer', 'Writer', 'Editor', 'Video Editor'],
        );
      }

      final snapshot = await query.limit(25).get();
      final candidates = <Map<String, dynamic>>[];

      for (final doc in snapshot.docs) {
        final data = doc.data();
        final docUid = data['uid'] ?? doc.id;
        if (docUid == currentUid) continue; // Exclude current user

        final name =
            (data['fullName'] ?? data['name'] ?? data['username'] ?? '')
                .toString();
        final role = (data['role'] ?? '').toString();
        final location = (data['location'] ?? '').toString();
        final skills = (data['skills'] ?? '').toString();
        final category = (data['category'] ?? '').toString();
        final experience = (data['experience'] ?? '').toString();
        final photo = (data['profilePhotoUrl'] ?? data['profileImage'] ?? '')
            .toString();
        final portfolio = (data['portfolioUrl'] ?? '').toString();
        final bio = (data['bio'] ?? '').toString();
        final educationVideo = (data['educationVideoUrl'] ?? '').toString();

        // Calculate matching score
        int score = 0;

        // Role match
        if (targetRole != null &&
            role.toLowerCase().contains(targetRole.toLowerCase())) {
          score += 40;
        }

        // Location match
        if (matchedLocation != null &&
            location.toLowerCase().contains(matchedLocation)) {
          score += 50;
        }

        // Skills match
        final skillsList = skills.toLowerCase().split(RegExp(r'[,|/]'));
        for (final skill in skillsList) {
          final trimmed = skill.trim();
          if (trimmed.isNotEmpty && lower.contains(trimmed)) {
            score += 20;
          }
        }

        // Category match
        if (category.isNotEmpty && lower.contains(category.toLowerCase())) {
          score += 15;
        }

        // Experience bonus
        if (experience.toLowerCase().contains('experienced') ||
            experience.toLowerCase().contains('expert')) {
          score += 10;
        }

        // Has portfolio bonus
        if (portfolio.isNotEmpty) score += 5;

        candidates.add({
          'uid': doc.id,
          'name': name.isEmpty ? 'Creator' : name,
          'role': role,
          'location': location,
          'skills': skills,
          'category': category,
          'experience': experience,
          'photo': photo,
          'portfolioUrl': portfolio,
          'educationVideoUrl': educationVideo,
          'bio': bio,
          'score': score,
        });
      }

      // Sort by matching score descending
      candidates.sort(
        (a, b) => (b['score'] as int).compareTo(a['score'] as int),
      );

      // Return top 5 matches
      return candidates.take(5).toList();
    } catch (e) {
      debugPrint('Error searching creators in Firestore: $e');
      return [];
    }
  }

  // ---------------------------------------------------------------------------
  // GEMINI AI COMMUNICATION & RESPONSE GENERATION
  // ---------------------------------------------------------------------------

  /// Sends a message, maintains conversation context, queries matching creators,
  /// and returns the assistant's reply.
  Future<AIChatMessage> sendMessage({
    required String chatId,
    required String userText,
    required List<AIChatMessage> history,
  }) async {
    final user = _auth.currentUser;
    if (user == null) {
      throw Exception('You must be signed in to send messages.');
    }

    if (_isProcessing) {
      throw Exception('Please wait for the current response to complete.');
    }

    _isProcessing = true;

    try {
      // 1. Identify user role & name
      final role = await getCurrentUserRole();
      final userName = await getCurrentUserName();

      // 2. Check for creator recommendation request
      List<Map<String, dynamic>> matchedCreators = [];
      if (isCreatorRecommendationQuery(userText)) {
        matchedCreators = await findMatchingCreators(userText);
      }

      // 3. Prepare Grounded Creator Context
      String creatorContextPrompt = '';
      if (matchedCreators.isNotEmpty) {
        final creatorListStr = matchedCreators
            .map((c) {
              return '''
- Name: ${c['name']}
  Role: ${c['role']}
  Location: ${c['location'].isEmpty ? 'Not specified' : c['location']}
  Skills: ${c['skills'].isEmpty ? 'General' : c['skills']}
  Category: ${c['category']}
  Experience: ${c['experience']}
  Portfolio: ${c['portfolioUrl'].isNotEmpty ? 'Available' : 'None'}
  Bio: ${c['bio']}
''';
            })
            .join('\n');

        creatorContextPrompt =
            '''

VERIFIED CREATOR PROFILES FROM CREATORCONNECT DATABASE:
$creatorListStr

INSTRUCTION: Recommends these specific verified creators from the database above to the user.
Explain why each matches their criteria. DO NOT fabricate creators or details outside this list.
''';
      } else if (isCreatorRecommendationQuery(userText)) {
        creatorContextPrompt = '''

NOTICE: No registered creators currently match all requested filters in CreatorConnect's database.
Kindly explain this to the user, suggest broadening the search criteria (e.g. considering remote creators or related categories), and advise how they can post a project requirement.
''';
      }

      // 4. Construct System Instruction
      final systemInstruction =
          '${AIPrompt.getSystemInstruction(role: role, userName: userName)}$creatorContextPrompt';

      // 5. Select last 8 messages for context window management
      final recentHistory = history.length > 8
          ? history.sublist(history.length - 8)
          : history;

      // 6. Execute Gemini call (Cloud Function backend or direct Gemini API)
      final replyContent = await _callGemini(
        systemInstruction: systemInstruction,
        userMessage: userText,
        history: recentHistory,
      );

      // 7. Build Assistant Message
      final assistantMessageId = _firestore
          .collection('Profile_Data')
          .doc(user.uid)
          .collection('ai_chats')
          .doc(chatId)
          .collection('messages')
          .doc()
          .id;

      final assistantMessage = AIChatMessage(
        id: assistantMessageId,
        chatId: chatId,
        userId: user.uid,
        role: MessageRole.assistant,
        content: replyContent,
        timestamp: DateTime.now(),
        suggestedCreators: matchedCreators,
      );

      // 8. Persist assistant message and update chat metadata
      await saveMessage(assistantMessage);
      await updateChatMetadata(chatId: chatId, lastMessage: replyContent);

      return assistantMessage;
    } finally {
      _isProcessing = false;
    }
  }

  /// Performs the actual HTTP request to either the Cloud Function or Gemini endpoint
  Future<String> _callGemini({
    required String systemInstruction,
    required String userMessage,
    required List<AIChatMessage> history,
  }) async {
    // Mode A: Firebase Cloud Functions Backend (if configured)
    if (_backendUrl.isNotEmpty) {
      try {
        final idToken = await _auth.currentUser?.getIdToken();
        final response = await http
            .post(
              Uri.parse(_backendUrl),
              headers: {
                'Content-Type': 'application/json',
                if (idToken != null) 'Authorization': 'Bearer $idToken',
              },
              body: jsonEncode({
                'systemInstruction': systemInstruction,
                'message': userMessage,
                'history': history
                    .map(
                      (m) => {
                        'role': m.isUser ? 'user' : 'model',
                        'content': m.content,
                      },
                    )
                    .toList(),
              }),
            )
            .timeout(const Duration(seconds: 35));

        if (response.statusCode == 200) {
          final data = jsonDecode(response.body);
          return data['reply'] ?? data['text'] ?? 'No response received.';
        }
      } catch (e) {
        debugPrint(
          'Cloud Function call failed, falling back to direct API: $e',
        );
      }
    }

    // Mode B: Direct Gemini REST API via compile-time key or safe fallback
    if (_geminiApiKey.isEmpty) {
      return '''
CreatorConnect AI is running in offline preview mode.

To activate live Gemini responses, run your app with your Gemini API key:
`flutter run --dart-define=GEMINI_API_KEY=YOUR_GEMINI_API_KEY`

Or deploy our Firebase Cloud Function backend for zero client-side key exposure!
''';
    }

    // Build Gemini contents array
    final contents = <Map<String, dynamic>>[];

    // Add conversation history
    for (final msg in history) {
      contents.add({
        'role': msg.isUser ? 'user' : 'model',
        'parts': [
          {'text': msg.content},
        ],
      });
    }

    // Add current user prompt
    contents.add({
      'role': 'user',
      'parts': [
        {'text': userMessage},
      ],
    });

    final requestBodyJson = jsonEncode({
      'systemInstruction': {
        'parts': [
          {'text': systemInstruction},
        ],
      },
      'contents': contents,
      'generationConfig': {
        'temperature': 0.7,
        'topK': 40,
        'topP': 0.95,
        'maxOutputTokens': 2048,
      },
      'safetySettings': [
        {
          'category': 'HARM_CATEGORY_HARASSMENT',
          'threshold': 'BLOCK_MEDIUM_AND_ABOVE',
        },
        {
          'category': 'HARM_CATEGORY_HATE_SPEECH',
          'threshold': 'BLOCK_MEDIUM_AND_ABOVE',
        },
        {
          'category': 'HARM_CATEGORY_SEXUALLY_EXPLICIT',
          'threshold': 'BLOCK_MEDIUM_AND_ABOVE',
        },
        {
          'category': 'HARM_CATEGORY_DANGEROUS_CONTENT',
          'threshold': 'BLOCK_MEDIUM_AND_ABOVE',
        },
      ],
    });

    String lastErrorMessage = '';

    // Cascade through candidate models until one succeeds
    for (final model in _candidateModels) {
      final url = Uri.parse(
        'https://generativelanguage.googleapis.com/v1beta/models/$model:generateContent?key=$_geminiApiKey',
      );

      try {
        final response = await http
            .post(
              url,
              headers: {'Content-Type': 'application/json'},
              body: requestBodyJson,
            )
            .timeout(const Duration(seconds: 35));

        if (response.statusCode == 200) {
          final json = jsonDecode(response.body) as Map<String, dynamic>;
          final candidates = json['candidates'] as List?;
          if (candidates != null && candidates.isNotEmpty) {
            final content = candidates[0]['content'] as Map<String, dynamic>?;
            final parts = content?['parts'] as List?;
            if (parts != null && parts.isNotEmpty) {
              final text = parts[0]['text'] as String?;
              if (text != null && text.trim().isNotEmpty) {
                return text.trim();
              }
            }
          }
          return 'I received your message, but the model generated an empty response. Please rephrase your question.';
        }

        final errorBody = response.body;
        debugPrint(
          'Gemini API ($model) Error: ${response.statusCode} - $errorBody',
        );

        String extracted = '';
        try {
          final errJson = jsonDecode(errorBody);
          extracted = errJson['error']?['message']?.toString() ?? '';
        } catch (_) {}

        lastErrorMessage = extracted.isNotEmpty
            ? extracted
            : 'HTTP ${response.statusCode} from Gemini ($model)';

        // Cascade to next model if model is deprecated (404) or busy (503)
        if (response.statusCode == 404 || response.statusCode == 503) {
          continue;
        }

        throw Exception(lastErrorMessage);
      } catch (e) {
        if (e is TimeoutException) {
          lastErrorMessage = 'Request timed out for model $model';
          continue;
        }
        if (e.toString().contains('404') || e.toString().contains('503')) {
          continue;
        }
        rethrow;
      }
    }

    throw Exception(
      lastErrorMessage.isNotEmpty
          ? lastErrorMessage
          : 'Failed to reach CreatorConnect AI. Check your network and API key.',
    );
  }
}
