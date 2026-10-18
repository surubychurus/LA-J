import 'dart:convert';
import 'dart:io';

import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:http/http.dart' as http;
import 'package:open_filex/open_filex.dart';
import 'package:package_info_plus/package_info_plus.dart';
import 'package:path_provider/path_provider.dart';

/// Actualización sin tiendas (solo Android).
///
/// La app lee `version.json` de la rama main del repo. Si el número de build
/// publicado es mayor al instalado, ofrece descargar el APK (GitHub Releases)
/// y abre el instalador de Android, que pide la confirmación del usuario.
///
/// Formato de version.json:
/// {"version": "1.0.1", "build": 2, "apk": "https://.../2214.apk",
///  "notas": "Qué cambió", "obligatoria": false}
const updateManifestUrl = 'https://raw.githubusercontent.com/surubychurus/LA-J/main/version.json';

class UpdateInfo {
  final String version;
  final int build;
  final String apk;
  final String notas;
  final bool obligatoria;
  UpdateInfo(this.version, this.build, this.apk, this.notas, this.obligatoria);
}

class Updater {
  static Future<UpdateInfo?> check() async {
    if (kIsWeb || !Platform.isAndroid) return null;
    try {
      final res = await http
          .get(Uri.parse('$updateManifestUrl?t=${DateTime.now().millisecondsSinceEpoch}'))
          .timeout(const Duration(seconds: 8));
      if (res.statusCode != 200) return null;
      final j = jsonDecode(res.body) as Map<String, dynamic>;
      final info = await PackageInfo.fromPlatform();
      final actual = int.tryParse(info.buildNumber) ?? 0;
      final build = (j['build'] as num).toInt();
      if (build <= actual) return null;
      return UpdateInfo(
        j['version'] as String,
        build,
        j['apk'] as String,
        (j['notas'] as String?) ?? '',
        (j['obligatoria'] as bool?) ?? false,
      );
    } catch (_) {
      return null; // sin internet o manifiesto inválido: no molestar
    }
  }

  /// Chequea y, si hay versión nueva, muestra el diálogo de actualización.
  static Future<void> checkAndPrompt(BuildContext context) async {
    final u = await check();
    if (u == null || !context.mounted) return;
    await showDialog(
      context: context,
      barrierDismissible: !u.obligatoria,
      builder: (_) => _UpdateDialog(u),
    );
  }

  static Future<void> _download(UpdateInfo u, void Function(double) onProgress) async {
    final dir = await getTemporaryDirectory();
    final file = File('${dir.path}/2214-${u.version}.apk');
    final client = http.Client();
    try {
      final res = await client.send(http.Request('GET', Uri.parse(u.apk)));
      if (res.statusCode != 200) throw Exception('Descarga fallida (${res.statusCode})');
      final total = res.contentLength ?? 0;
      var got = 0;
      final sink = file.openWrite();
      await for (final chunk in res.stream) {
        sink.add(chunk);
        got += chunk.length;
        if (total > 0) onProgress(got / total);
      }
      await sink.close();
    } finally {
      client.close();
    }
    final r = await OpenFilex.open(file.path, type: 'application/vnd.android.package-archive');
    if (r.type != ResultType.done) throw Exception(r.message);
  }
}

class _UpdateDialog extends StatefulWidget {
  final UpdateInfo u;
  const _UpdateDialog(this.u);
  @override
  State<_UpdateDialog> createState() => _UpdateDialogState();
}

class _UpdateDialogState extends State<_UpdateDialog> {
  double? _progress;
  String? _error;

  Future<void> _go() async {
    setState(() {
      _progress = 0;
      _error = null;
    });
    try {
      await Updater._download(widget.u, (p) {
        if (mounted) setState(() => _progress = p);
      });
      if (mounted && !widget.u.obligatoria) Navigator.pop(context);
    } catch (e) {
      if (mounted) {
        setState(() {
          _progress = null;
          _error = 'No se pudo actualizar. Probá de nuevo.';
        });
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    final u = widget.u;
    return PopScope(
      canPop: !u.obligatoria && _progress == null,
      child: AlertDialog(
        title: Text('Nueva versión ${u.version}'),
        content: Column(mainAxisSize: MainAxisSize.min, crossAxisAlignment: CrossAxisAlignment.start, children: [
          if (u.notas.isNotEmpty) Text(u.notas),
          if (_progress != null) ...[
            const SizedBox(height: 16),
            LinearProgressIndicator(value: _progress == 0 ? null : _progress),
          ],
          if (_error != null) ...[
            const SizedBox(height: 12),
            Text(_error!, style: TextStyle(color: Theme.of(context).colorScheme.error)),
          ],
        ]),
        actions: [
          if (!u.obligatoria && _progress == null)
            TextButton(onPressed: () => Navigator.pop(context), child: const Text('Más tarde')),
          FilledButton(
            style: FilledButton.styleFrom(minimumSize: const Size(120, 40)),
            onPressed: _progress == null ? _go : null,
            child: const Text('Actualizar'),
          ),
        ],
      ),
    );
  }
}
