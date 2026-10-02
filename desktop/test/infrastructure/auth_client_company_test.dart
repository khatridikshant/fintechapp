import 'dart:convert';

import 'package:financeapp/src/domain/shared/book_upload.dart';
import 'package:financeapp/src/domain/shared/sign_in.dart';
import 'package:financeapp/src/infrastructure/auth/http_auth_client.dart';
import 'package:financeapp/src/infrastructure/http/http_transport.dart';
import 'package:flutter_test/flutter_test.dart';

/// The sign-in response now carries the registered business.
///
/// ## Why these tests exist
///
/// A field the desktop does not read is a field nobody can rely on, and one the
/// server spends effort producing. The riskiest part is `vat_registered`: the
/// server sends a real JSON boolean, but anything that accepts a string would turn
/// `"0"` into **true**, and a VAT-registered business is not the same as an
/// unregistered one.
void main() {
  final serverBaseUrl = Uri.parse('https://books.example.com');

  Future<SignInResult> interpret(Map<String, Object?> body) async {
    final transport = _Transport(
      TransportResponse(
        statusCode: 200,
        body: jsonEncode(body),
        headers: const <String, String>{},
      ),
    );
    return HttpAuthClient(transport).signIn(
      serverBaseUrl: serverBaseUrl,
      email: 'owner@example.com',
      password: 'a-long-enough-password',
    );
  }

  /// A minimal well-formed sign-in body, which each test extends.
  Map<String, Object?> bodyWith({
    Map<String, Object?>? company,
  }) =>
      <String, Object?>{
        'token': 'a-token',
        'user': <String, Object?>{'email': 'owner@example.com'},
        'book': <String, Object?>{'id': 7},
        if (company != null) 'company': company,
      };

  Future<BackendSession> sessionFrom(Map<String, Object?> body) async {
    final result = await interpret(body);
    expect(result.status, SignInStatus.signedIn);
    return result.session!;
  }

  group('a server that sends the company', () {
    test('the business name becomes the account label', () async {
      // The label distinguishes one account from another, so the business beats
      // the sign-in address.
      final session = await sessionFrom(bodyWith(
        company: <String, Object?>{
          'id': 3,
          'name': 'Himalayan Traders',
          'pan': '123456789',
          'vat_registered': true,
        },
      ));

      expect(session.companyName, 'Himalayan Traders');
      expect(session.accountLabel, 'Himalayan Traders');
      expect(session.companyPan, '123456789');
      expect(session.vatRegistered, isTrue);
    });

    test('an unregistered business reads as false, not as absent', () async {
      // The two are different claims: false means "not registered", null means
      // "the server did not say". Collapsing them would let a missing answer be
      // read as a definite one.
      final session = await sessionFrom(bodyWith(
        company: <String, Object?>{
          'name': 'Sita Sharma Supplies',
          'pan': '987654321',
          'vat_registered': false,
        },
      ));

      expect(session.vatRegistered, isFalse);
    });

    test('the string "0" is not read as a VAT registration', () async {
      // The bug this guards against: in Dart a non-empty string is truthy, so a
      // loose cast turns "0" into true and reports an unregistered business as
      // registered.
      final session = await sessionFrom(bodyWith(
        company: <String, Object?>{
          'name': 'Himalayan Traders',
          'pan': '123456789',
          'vat_registered': '0',
        },
      ));

      expect(session.vatRegistered, isNull,
          reason: 'a string must not be coerced');
    });

    test('the book id is still what identifies the upload target', () async {
      // The company is display information. It must not displace the book id the
      // upload endpoint is keyed by.
      final session = await sessionFrom(bodyWith(
        company: <String, Object?>{
          'name': 'Himalayan Traders',
          'pan': '123456789'
        },
      ));

      expect(session.bookId, '7');
    });
  });

  group('an older server that sends no company', () {
    test('sign-in still succeeds', () async {
      // Refusing to sign in over a missing display field would break every
      // desktop already deployed against a server without it.
      final result = await interpret(bodyWith());

      expect(result.status, SignInStatus.signedIn);
    });

    test('the label falls back to the sign-in address', () async {
      final session = await sessionFrom(bodyWith());

      expect(session.accountLabel, 'owner@example.com');
      expect(session.companyName, isNull);
      expect(session.vatRegistered, isNull);
    });

    test('an empty company name is treated as no company name', () async {
      // Blank is not a name, and must not become an empty account label.
      final session = await sessionFrom(bodyWith(
        company: <String, Object?>{
          'name': '',
          'pan': '',
          'vat_registered': true
        },
      ));

      expect(session.companyName, isNull);
      expect(session.accountLabel, 'owner@example.com');
      expect(session.vatRegistered, isTrue);
    });
  });
}

/// A transport that answers once, with a fixed response.
class _Transport implements HttpTransport {
  _Transport(this.response);

  final TransportResponse response;

  @override
  Future<TransportResponse> send({
    required String method,
    required Uri url,
    required Map<String, String> headers,
    List<List<int>> body = const <List<int>>[],
  }) async =>
      response;
}
