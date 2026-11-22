import 'dart:convert';
import 'dart:io';
import 'package:flutter_test/flutter_test.dart';
import 'package:quantis_stock/core/constants/app_constants.dart';
import 'package:quantis_stock/core/network/server_discovery_service.dart';

void main() {
  group('ApiConstants.normalizeApiUrl', () {
    test('Normalise une IP nue en URL API complète avec port 8080', () {
      expect(
        ApiConstants.normalizeApiUrl('10.84.192.225'),
        'http://10.84.192.225:8080/api/v1',
      );
      expect(
        ApiConstants.normalizeApiUrl(' 192.168.137.42/ '),
        'http://192.168.137.42:8080/api/v1',
      );
    });

    test('Conserve un port personnalisé ou HTTPS et ajoute /api/v1 si absent', () {
      expect(
        ApiConstants.normalizeApiUrl('10.84.192.225:9090'),
        'http://10.84.192.225:9090/api/v1',
      );
      expect(
        ApiConstants.normalizeApiUrl('http://192.168.43.10:8080/api/v1/'),
        'http://192.168.43.10:8080/api/v1',
      );
      expect(
        ApiConstants.normalizeApiUrl('https://api.quantis.tech'),
        'https://api.quantis.tech/api/v1',
      );
    });
  });

  group('ServerDiscoveryService', () {
    test('verifyServer valide un backend Quantis réel et rejette un autre serveur', () async {
      final quantisServer = await HttpServer.bind(InternetAddress.loopbackIPv4, 0);
      quantisServer.listen((HttpRequest req) {
        if (req.uri.path == '/api/v1/health') {
          req.response
            ..statusCode = HttpStatus.ok
            ..headers.contentType = ContentType.json
            ..write(jsonEncode({
              'success': true,
              'data': {
                'status': 'UP',
                'application': 'Quantis Stock API',
              },
            }));
        } else {
          req.response.statusCode = HttpStatus.notFound;
        }
        req.response.close();
      });

      final otherServer = await HttpServer.bind(InternetAddress.loopbackIPv4, 0);
      otherServer.listen((HttpRequest req) {
        req.response
          ..statusCode = HttpStatus.ok
          ..write('<html>Not Quantis</html>')
          ..close();
      });

      try {
        final ok = await ServerDiscoveryService.verifyServer(
          'http://127.0.0.1:${quantisServer.port}/api/v1',
          timeout: const Duration(seconds: 2),
        );
        expect(ok, isNotNull);
        expect(ok!.ip, '127.0.0.1');
        expect(ok.port, quantisServer.port);

        final bad = await ServerDiscoveryService.verifyServer(
          'http://127.0.0.1:${otherServer.port}/api/v1',
          timeout: const Duration(seconds: 2),
        );
        expect(bad, isNull);
      } finally {
        await quantisServer.close(force: true);
        await otherServer.close(force: true);
      }
    });

    test('discoverServer retrouve le backend via priorityUrls', () async {
      final quantisServer = await HttpServer.bind(InternetAddress.loopbackIPv4, 0);
      quantisServer.listen((HttpRequest req) {
        req.response
          ..statusCode = HttpStatus.ok
          ..headers.contentType = ContentType.json
          ..write(jsonEncode({
            'success': true,
            'data': {
              'status': 'UP',
              'application': 'Quantis Stock API',
            },
          }))
          ..close();
      });

      try {
        final result = await ServerDiscoveryService.discoverServer(
          priorityUrls: ['http://127.0.0.1:${quantisServer.port}/api/v1'],
          scanSubnets: false,
          udpWindow: const Duration(milliseconds: 200),
        );
        expect(result.server, isNotNull);
        expect(result.server!.port, quantisServer.port);
      } finally {
        await quantisServer.close(force: true);
      }
    });
  });
}

