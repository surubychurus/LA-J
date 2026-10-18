import 'package:flutter/material.dart';
import 'package:lucide_icons_flutter/lucide_icons.dart';

import '../models.dart';
import '../services/db.dart';
import 'widgets.dart';

class NewsScreen extends StatefulWidget {
  final AppUser user;
  const NewsScreen({super.key, required this.user});
  @override
  State<NewsScreen> createState() => _NewsScreenState();
}

class _NewsScreenState extends State<NewsScreen> {
  bool _all = false;

  Future<void> _compose(List<Kuvthza> ks) async {
    final u = widget.user;
    final titulo = TextEditingController();
    final cuerpo = TextEditingController();
    // Madrij: solo su kuvthzá. Hanagá: general o cualquiera.
    String? target = u.esHanaga ? null : u.kuvthzaId;
    await showDialog(
      context: context,
      builder: (ctx) => StatefulBuilder(
        builder: (ctx, set) => AlertDialog(
          title: const Text('Nuevo anuncio'),
          content: SingleChildScrollView(
            child: Column(mainAxisSize: MainAxisSize.min, children: [
              TextField(controller: titulo, decoration: const InputDecoration(labelText: 'Título')),
              const SizedBox(height: 12),
              TextField(
                  controller: cuerpo,
                  maxLines: 4,
                  decoration: const InputDecoration(labelText: 'Mensaje')),
              const SizedBox(height: 12),
              if (u.esHanaga)
                DropdownButtonFormField<String?>(
                  value: target,
                  decoration: const InputDecoration(labelText: 'Para'),
                  items: [
                    const DropdownMenuItem(value: null, child: Text('General')),
                    for (final k in ks) DropdownMenuItem(value: k.id, child: Text(k.nombre)),
                  ],
                  onChanged: (v) => set(() => target = v),
                )
              else
                Align(
                    alignment: Alignment.centerLeft,
                    child: Text('Para: ${kuvthzaName(ks, target) ?? 'sin kuvthzá'}')),
            ]),
          ),
          actions: [
            TextButton(onPressed: () => Navigator.pop(ctx), child: const Text('Cancelar')),
            FilledButton(
              style: FilledButton.styleFrom(minimumSize: const Size(100, 40)),
              onPressed: () async {
                if (titulo.text.trim().isEmpty) return;
                if (!u.esHanaga && target == null) return;
                await Db.publicar(u, titulo.text, cuerpo.text, target);
                if (ctx.mounted) Navigator.pop(ctx);
              },
              child: const Text('Publicar'),
            ),
          ],
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final u = widget.user;
    final t = Theme.of(context);
    return StreamBuilder<List<Kuvthza>>(
      stream: Db.kuvthzot(),
      builder: (_, ks) {
        final kl = ks.data ?? [];
        return Scaffold(
          backgroundColor: Colors.transparent,
          floatingActionButton: u.puedePublicar
              ? FloatingActionButton(
                  onPressed: () => _compose(kl),
                  backgroundColor: t.colorScheme.primary,
                  foregroundColor: Colors.white,
                  child: const Icon(LucideIcons.plus),
                )
              : null,
          body: StreamBuilder<List<Anuncio>>(
            stream: Db.anuncios(u),
            builder: (_, s) {
              final all = s.data ?? [];
              final list = _all ? all : all.take(3).toList();
              return ListView(
                padding: const EdgeInsets.all(20),
                children: [
                  const PageHeader('Novedades', subtitle: 'Generales y de tu kuvthzá'),
                  if (list.isEmpty) const EmptyState(LucideIcons.megaphone, 'No hay novedades'),
                  for (final a in list)
                    Padding(
                      padding: const EdgeInsets.only(bottom: 10),
                      child: AnuncioCard(
                        a: a,
                        kuvthzaNombre: kuvthzaName(kl, a.kuvthzaId),
                        onDelete: u.esHanaga ? () => Db.borrarAnuncio(a.id) : null,
                      ),
                    ),
                  if (all.length > 3)
                    TextButton(
                      onPressed: () => setState(() => _all = !_all),
                      child: Text(_all ? 'Ver menos' : 'Ver todos (${all.length})'),
                    ),
                ],
              );
            },
          ),
        );
      },
    );
  }
}
