import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import 'package:lucide_icons_flutter/lucide_icons.dart';

import '../models.dart';
import '../services/db.dart';
import 'widgets.dart';

/// Pantalla de gestión de novedades (madrij: las de su kuvthzá; Hanagá: todas).
class NewsManageScreen extends StatelessWidget {
  final AppUser user;
  const NewsManageScreen({super.key, required this.user});

  Future<void> _delete(BuildContext context, Anuncio a) async {
    final ok = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('Borrar novedad'),
        content: Text('¿Borrar "${a.titulo}"? No se puede deshacer.'),
        actions: [
          TextButton(onPressed: () => Navigator.pop(ctx, false), child: const Text('Cancelar')),
          FilledButton(
            style: FilledButton.styleFrom(minimumSize: const Size(100, 40)),
            onPressed: () => Navigator.pop(ctx, true),
            child: const Text('Borrar'),
          ),
        ],
      ),
    );
    if (ok == true) await Db.borrarAnuncio(a.id);
  }

  void _open(BuildContext context, [Anuncio? a]) => Navigator.push(
      context, MaterialPageRoute(builder: (_) => NewsEditorScreen(user: user, anuncio: a)));

  @override
  Widget build(BuildContext context) {
    final t = Theme.of(context);
    final muted = t.colorScheme.onSurface.withValues(alpha: 0.6);
    return Scaffold(
      appBar: AppBar(title: const Text('Gestionar novedades')),
      floatingActionButton: FloatingActionButton.extended(
        onPressed: () => _open(context),
        backgroundColor: t.colorScheme.primary,
        foregroundColor: Colors.white,
        icon: const Icon(LucideIcons.plus),
        label: const Text('Nueva'),
      ),
      body: StreamBuilder<List<Kuvthza>>(
        stream: Db.kuvthzot(),
        builder: (_, ks) => StreamBuilder<List<Anuncio>>(
          stream: Db.anuncios(user),
          builder: (_, s) {
            // La Hanagá gestiona todas; el madrij solo las de su kuvthzá.
            final list = (s.data ?? [])
                .where((a) => user.esHanaga || a.kuvthzaId == user.kuvthzaId)
                .toList();
            if (list.isEmpty) {
              return const EmptyState(LucideIcons.megaphone, 'Todavía no hay novedades para gestionar');
            }
            return ListView.separated(
              padding: const EdgeInsets.fromLTRB(20, 8, 20, 100),
              itemCount: list.length,
              separatorBuilder: (_, __) => const SizedBox(height: 10),
              itemBuilder: (_, i) {
                final a = list[i];
                return Card(
                  child: ListTile(
                    contentPadding: const EdgeInsets.fromLTRB(16, 6, 8, 6),
                    title: Text(a.titulo, style: t.textTheme.titleMedium),
                    subtitle: Text(
                      '${kuvthzaName(ks.data ?? [], a.kuvthzaId) ?? 'General'} · '
                      '${DateFormat('d MMM', 'es').format(a.fecha)}'
                      '${a.acciones.isEmpty ? '' : ' · ${a.acciones.length} botón(es)'}',
                      style: TextStyle(color: muted),
                    ),
                    onTap: () => _open(context, a),
                    trailing: IconButton(
                      icon: const Icon(LucideIcons.trash2, size: 20),
                      onPressed: () => _delete(context, a),
                    ),
                  ),
                );
              },
            );
          },
        ),
      ),
    );
  }
}

class _AccionDraft {
  TipoAccion tipo;
  final etiqueta = TextEditingController();
  final valor = TextEditingController();
  DateTime? inicio;
  DateTime? fin;
  _AccionDraft(this.tipo);

  factory _AccionDraft.from(Accion a) => _AccionDraft(a.tipo)
    ..etiqueta.text = a.etiqueta
    ..valor.text = a.valor
    ..inicio = a.inicio
    ..fin = a.fin;
}

/// Pantalla completa para crear o editar una novedad con sus botones.
class NewsEditorScreen extends StatefulWidget {
  final AppUser user;
  final Anuncio? anuncio;
  const NewsEditorScreen({super.key, required this.user, this.anuncio});
  @override
  State<NewsEditorScreen> createState() => _NewsEditorScreenState();
}

class _NewsEditorScreenState extends State<NewsEditorScreen> {
  final _titulo = TextEditingController();
  final _cuerpo = TextEditingController();
  String? _target;
  final _acciones = <_AccionDraft>[];
  bool _saving = false;
  String? _error;

  @override
  void initState() {
    super.initState();
    final a = widget.anuncio;
    // Madrij: siempre su kuvthzá. Hanagá: general o cualquiera.
    _target = a != null ? a.kuvthzaId : (widget.user.esHanaga ? null : widget.user.kuvthzaId);
    if (a != null) {
      _titulo.text = a.titulo;
      _cuerpo.text = a.cuerpo;
      _acciones.addAll(a.acciones.map(_AccionDraft.from));
    }
  }

  Future<DateTime?> _pickDateTime(DateTime? initial) async {
    final now = DateTime.now();
    final d = await showDatePicker(
      context: context,
      initialDate: initial ?? now,
      firstDate: DateTime(now.year - 1),
      lastDate: DateTime(now.year + 3),
    );
    if (d == null || !mounted) return null;
    final t = await showTimePicker(
      context: context,
      initialTime: TimeOfDay.fromDateTime(initial ?? DateTime(now.year, now.month, now.day, 14, 30)),
    );
    if (t == null) return null;
    return DateTime(d.year, d.month, d.day, t.hour, t.minute);
  }

  Future<void> _save() async {
    if (_titulo.text.trim().isEmpty) {
      setState(() => _error = 'Poné un título');
      return;
    }
    if (!widget.user.esHanaga && _target == null) {
      setState(() => _error = 'No tenés kuvthzá asignada');
      return;
    }
    final acciones = <Accion>[];
    for (final d in _acciones) {
      final etiqueta = d.etiqueta.text.trim();
      final valor = d.valor.text.trim();
      if (d.tipo == TipoAccion.calendario) {
        if (d.inicio == null) {
          setState(() => _error = 'Elegí la fecha del evento en el botón de calendario');
          return;
        }
      } else if (valor.isEmpty) {
        setState(() => _error = 'Completá el dato de cada botón (${d.tipo.label})');
        return;
      }
      acciones.add(Accion(d.tipo, etiqueta, valor, inicio: d.inicio, fin: d.fin));
    }
    setState(() {
      _saving = true;
      _error = null;
    });
    try {
      await Db.guardarAnuncio(
        widget.user,
        id: widget.anuncio?.id,
        titulo: _titulo.text,
        cuerpo: _cuerpo.text,
        kuvthzaId: _target,
        acciones: acciones,
      );
      if (mounted) Navigator.pop(context);
    } catch (_) {
      if (mounted) {
        setState(() {
          _saving = false;
          _error = 'No se pudo guardar. Probá de nuevo.';
        });
      }
    }
  }

  String _valorLabel(TipoAccion t) => switch (t) {
        TipoAccion.enlace => 'Enlace (https://…)',
        TipoAccion.llamar => 'Teléfono',
        TipoAccion.whatsapp => 'Número con código de país (ej. 5491122334455)',
        TipoAccion.mapa => 'Dirección o lugar',
        TipoAccion.calendario => 'Lugar (opcional)',
      };

  Widget _accionCard(int i) {
    final d = _acciones[i];
    final fmt = DateFormat("EEE d MMM, HH:mm", 'es');
    return Card(
      child: Padding(
        padding: const EdgeInsets.all(14),
        child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
          Row(children: [
            Expanded(
              child: DropdownButtonFormField<TipoAccion>(
                value: d.tipo,
                decoration: const InputDecoration(labelText: 'Acción'),
                items: [
                  for (final t in TipoAccion.values)
                    DropdownMenuItem(
                      value: t,
                      child: Row(children: [
                        Icon(iconoAccion(t), size: 16),
                        const SizedBox(width: 8),
                        Text(t.label),
                      ]),
                    ),
                ],
                onChanged: (v) => setState(() => d.tipo = v!),
              ),
            ),
            IconButton(
              icon: const Icon(LucideIcons.trash2, size: 20),
              onPressed: () => setState(() => _acciones.removeAt(i)),
            ),
          ]),
          const SizedBox(height: 12),
          TextField(
              controller: d.etiqueta,
              decoration: InputDecoration(labelText: 'Texto del botón', hintText: d.tipo.label)),
          const SizedBox(height: 12),
          if (d.tipo == TipoAccion.calendario) ...[
            OutlinedButton.icon(
              icon: const Icon(LucideIcons.calendar, size: 16),
              label: Text(d.inicio == null ? 'Elegir inicio' : 'Inicio: ${fmt.format(d.inicio!)}'),
              onPressed: () async {
                final v = await _pickDateTime(d.inicio);
                if (v != null) setState(() => d.inicio = v);
              },
            ),
            const SizedBox(height: 8),
            OutlinedButton.icon(
              icon: const Icon(LucideIcons.calendarClock, size: 16),
              label: Text(d.fin == null ? 'Elegir fin (opcional, por defecto 1 h)' : 'Fin: ${fmt.format(d.fin!)}'),
              onPressed: () async {
                final v = await _pickDateTime(d.fin ?? d.inicio);
                if (v != null) setState(() => d.fin = v);
              },
            ),
            const SizedBox(height: 12),
          ],
          TextField(
            controller: d.valor,
            keyboardType: switch (d.tipo) {
              TipoAccion.llamar || TipoAccion.whatsapp => TextInputType.phone,
              TipoAccion.enlace => TextInputType.url,
              _ => TextInputType.text,
            },
            decoration: InputDecoration(labelText: _valorLabel(d.tipo)),
          ),
        ]),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final t = Theme.of(context);
    final u = widget.user;
    return Scaffold(
      appBar: AppBar(title: Text(widget.anuncio == null ? 'Nueva novedad' : 'Editar novedad')),
      body: Center(
        child: ConstrainedBox(
          constraints: const BoxConstraints(maxWidth: 640),
          child: StreamBuilder<List<Kuvthza>>(
            stream: Db.kuvthzot(),
            builder: (_, ks) {
              final kl = ks.data ?? [];
              return ListView(
                padding: const EdgeInsets.fromLTRB(20, 8, 20, 32),
                children: [
                  TextField(
                      controller: _titulo,
                      textCapitalization: TextCapitalization.sentences,
                      decoration: const InputDecoration(labelText: 'Título')),
                  const SizedBox(height: 12),
                  TextField(
                    controller: _cuerpo,
                    minLines: 3,
                    maxLines: 8,
                    textCapitalization: TextCapitalization.sentences,
                    decoration: const InputDecoration(labelText: 'Mensaje', alignLabelWithHint: true),
                  ),
                  const SizedBox(height: 12),
                  if (u.esHanaga)
                    DropdownButtonFormField<String?>(
                      value: kl.any((k) => k.id == _target) ? _target : null,
                      decoration: const InputDecoration(labelText: 'Para'),
                      items: [
                        const DropdownMenuItem(value: null, child: Text('General (todos)')),
                        for (final k in kl) DropdownMenuItem(value: k.id, child: Text(k.nombre)),
                      ],
                      onChanged: (v) => setState(() => _target = v),
                    )
                  else
                    Text('Para: ${kuvthzaName(kl, _target) ?? 'sin kuvthzá'}', style: t.textTheme.bodyMedium),
                  const SizedBox(height: 28),
                  Text('Botones', style: t.textTheme.titleMedium),
                  const SizedBox(height: 4),
                  Text('Acciones que aparecen debajo de la novedad.',
                      style: t.textTheme.bodySmall
                          ?.copyWith(color: t.colorScheme.onSurface.withValues(alpha: 0.6))),
                  const SizedBox(height: 12),
                  for (var i = 0; i < _acciones.length; i++)
                    Padding(padding: const EdgeInsets.only(bottom: 10), child: _accionCard(i)),
                  OutlinedButton.icon(
                    icon: const Icon(LucideIcons.plus, size: 16),
                    label: const Text('Añadir botón'),
                    style: OutlinedButton.styleFrom(minimumSize: const Size.fromHeight(48)),
                    onPressed: () => setState(() => _acciones.add(_AccionDraft(TipoAccion.enlace))),
                  ),
                  if (_error != null) ...[
                    const SizedBox(height: 16),
                    Text(_error!, style: TextStyle(color: t.colorScheme.error)),
                  ],
                  const SizedBox(height: 20),
                  FilledButton(
                    onPressed: _saving ? null : _save,
                    child: _saving
                        ? const SizedBox(
                            height: 20,
                            width: 20,
                            child: CircularProgressIndicator(strokeWidth: 2, color: Colors.white))
                        : Text(widget.anuncio == null ? 'Publicar' : 'Guardar cambios'),
                  ),
                ],
              );
            },
          ),
        ),
      ),
    );
  }
}
