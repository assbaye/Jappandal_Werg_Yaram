import 'package:flutter_test/flutter_test.dart';
import 'package:graphql_flutter/graphql_flutter.dart';
import 'package:jwy_mobile/core/graphql/client.dart';

/// Faux transport : échoue [echecs] fois (échec réseau ou erreur serveur), puis répond.
class _FauxTransport extends Link {
  _FauxTransport(this.echecs, {this.reponseServeur = false});
  int echecs;
  final bool reponseServeur;
  int appels = 0;

  @override
  Stream<Response> request(Request request, [NextLink? forward]) async* {
    appels++;
    if (echecs > 0) {
      echecs--;
      throw ServerException(
        parsedResponse: reponseServeur ? const Response(response: {}, data: null) : null,
        originalException: Exception('réseau coupé'),
      );
    }
    yield const Response(response: {}, data: {'ok': true});
  }
}

Request _requete(String document) => Request(operation: Operation(document: gql(document)));

void main() {
  test('une lecture est relancée après des échecs réseau puis aboutit', () async {
    final transport = _FauxTransport(2);
    final reponse = await Link.from([RelanceLink(), transport]).request(_requete('query { me { id } }')).first;
    expect(reponse.data, {'ok': true});
    expect(transport.appels, 3);
  });

  test('une lecture abandonne après trois échecs réseau', () async {
    final transport = _FauxTransport(5);
    await expectLater(
      Link.from([RelanceLink(), transport]).request(_requete('query { me { id } }')).first,
      throwsA(isA<ServerException>()),
    );
    expect(transport.appels, 3);
  });

  test('une mutation n\'est jamais relancée (pas de doublon d\'action)', () async {
    final transport = _FauxTransport(1);
    await expectLater(
      Link.from([RelanceLink(), transport]).request(_requete('mutation { logout }')).first,
      throwsA(isA<ServerException>()),
    );
    expect(transport.appels, 1);
  });

  test('une erreur renvoyée par le serveur n\'est pas relancée', () async {
    final transport = _FauxTransport(1, reponseServeur: true);
    await expectLater(
      Link.from([RelanceLink(), transport]).request(_requete('query { me { id } }')).first,
      throwsA(isA<ServerException>()),
    );
    expect(transport.appels, 1);
  });
}
