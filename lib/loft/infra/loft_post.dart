import 'dart:convert';

import 'package:cluckfall_heights/loft/config/loft_config.dart';
import 'package:cluckfall_heights/loft/core/loft_models.dart';
import 'package:cluckfall_heights/loft/core/loft_trace.dart';
import 'package:cluckfall_heights/loft/infra/loft_vault.dart';
import 'package:cluckfall_heights/loft/infra/span_agent.dart';

class LoftPost {
  LoftPost(this._agent, this._vault);

  final SpanAgent _agent;
  final LoftVault _vault;

  Future<LoftReply> request(Map<String, dynamic> payload) async {
    if (!LoftConfig.grayCredentialsReady) {
      return LoftReply.rejected('credentials_unavailable');
    }
    try {
      loftTrace(() => '[CFH.POST] request ${jsonEncode(payload)}');
      final response = await _agent
          .post(
            Uri.parse(LoftConfig.endpoint),
            headers: <String, String>{
              'Accept': 'application/json',
              'Content-Type': 'application/json',
              'X-Partner-App-Id': LoftConfig.bundleId,
              'X-Partner-App-Name': LoftConfig.appNameToken,
            },
            body: jsonEncode(payload),
          )
          .timeout(LoftConfig.configPostTimeout);
      loftTrace(
        () => '[CFH.POST] response ${response.statusCode} ${response.body}',
      );
      if (response.statusCode != 200) {
        return LoftReply.rejected('http_${response.statusCode}');
      }
      final decoded = _decodeMap(response.body);
      if (decoded == null) {
        return LoftReply.rejected('invalid_response');
      }
      final reply = LoftReply.fromJson(decoded);
      if (reply.hasDestination) {
        await _vault.cacheUrl(reply.url!, reply.expiresAt);
      }
      return reply;
    } catch (error) {
      loftTrace(() => '[CFH.POST] failed: $error');
      return LoftReply.rejected('network_failure');
    }
  }

  static Map<String, dynamic>? _decodeMap(String body) {
    try {
      final decoded = jsonDecode(body);
      if (decoded is Map) {
        return Map<String, dynamic>.from(decoded);
      }
    } catch (_) {}
    return null;
  }
}
