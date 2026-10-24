import 'dart:convert';
import 'package:flutter_test/flutter_test.dart';
import 'package:http/http.dart' as http;
import 'package:http/testing.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import 'package:arknights_story_app/account/account_service.dart';
import 'package:arknights_story_app/account/reading_library.dart';
import 'package:arknights_story_app/settings/reader_settings.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();
  const uid = '11111111-1111-1111-1111-111111111111';
  String jwt() {
    String encode(Map value) =>
        base64Url.encode(utf8.encode(jsonEncode(value))).replaceAll('=', '');
    return '${encode({'alg': 'HS256', 'typ': 'JWT'})}.${encode({'sub': uid, 'exp': 4102444800, 'role': 'authenticated'})}.test';
  }

  test(
    'sign-in pulls settings and dirty progress uploads with canonical identity',
    () async {
      final uploaded = <Map>[];
      final mock = MockClient((request) async {
        if (request.url.path.endsWith('/token')) {
          return http.Response(
            jsonEncode({
              'access_token': jwt(),
              'refresh_token': 'test-refresh',
              'token_type': 'bearer',
              'expires_in': 3600,
              'user': {'id': uid, 'email': 'test@example.com'},
            }),
            200,
            request: request,
            headers: {'content-type': 'application/json'},
          );
        }
        if (request.url.path.endsWith('/user_settings')) {
          return http.Response(
            jsonEncode([
              {
                'user_id': uid,
                'setting_key': 'doctorName',
                'value': {'value': 'cloud-doctor'},
                'revision': 3,
              },
            ]),
            200,
            request: request,
            headers: {'content-type': 'application/json'},
          );
        }
        if (request.url.path.endsWith('/sync_reading_records')) {
          final mutations =
              (jsonDecode(request.body) as Map)['mutations'] as List;
          uploaded.addAll(mutations.cast<Map>());
          return http.Response(
            jsonEncode([
              for (final m in mutations)
                {
                  'kind': m['kind'],
                  'key': m['key'],
                  'value': m['value'],
                  'revision': (m['base_revision'] as int) + 1,
                  'conflict': false,
                },
            ]),
            200,
            request: request,
            headers: {'content-type': 'application/json'},
          );
        }
        return http.Response(
          '[]',
          200,
          request: request,
          headers: {'content-type': 'application/json'},
        );
      });
      final settings = ReaderSettings();
      final library = ReadingLibrary(
        settings: settings,
        read: () async => null,
        write: (_) async {},
      );
      await library.init();
      final client = SupabaseClient(
        'https://example.supabase.co',
        'test-publishable',
        httpClient: mock,
      );
      await client.auth.signInWithPassword(
        email: 'test@example.com',
        password: 'test-password',
      );
      final service = AccountService(library, client: client);
      addTearDown(() async {
        service.dispose();
        await client.dispose();
        library.dispose();
        settings.dispose();
      });
      await service.init();
      expect(library.scope, uid);
      expect(settings.doctorName, 'cloud-doctor', reason: service.error);
      library.recordProgress({
        'storyId': 'main_0',
        'chapterId': 'obt/main/a',
        'title': 'A',
        'line': 10,
        'total': 100,
        'scriptHash': 'v1',
        'choices': [],
      });
      await service.sync(pull: false);
      expect(
        uploaded.any((m) => m['kind'] == 'chapter' && m['key'] == 'obt/main/a'),
        true,
      );
      expect(library.hasPending, false);
      expect(service.lastSynced, isNotNull);
    },
  );
}
