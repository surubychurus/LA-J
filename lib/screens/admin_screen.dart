import 'package:flutter/material.dart';
import 'package:lucide_icons_flutter/lucide_icons.dart';

import '../models.dart';
import '../services/db.dart';
import 'widgets.dart';

/// Panel exclusivo de la Hanagá: usuarios, kuvthzot y tema del sábado.
class AdminScreen extends StatelessWidget {
  const AdminScreen({super.key});

  @override
  Widget build(BuildContext context) {
    return DefaultTabController(
      length: 3,
      child: Scaffold(
        appBar: AppBar(
          title: const Text('Hanagá'),
          bottom: const TabBar(tabs: [
            Tab(text: 'Usuarios'),
            Tab(text: 'Kuvthzot'),
            Tab(text: 'Sábado'),
          ]),
        ),
        body: const TabBarView(children: [_Users(), _Kuvthzot(), _Tema()]),
      ),
    );
  }
}

class _Users extends StatelessWidget {
  const _Users();

  Future<void> _edit(BuildContext context, AppUser u, List<Kuvthza> ks) async {
    // La Hanagá no se asigna desde la app (solo desde la base de datos).
    var rol = u.rol == Rol.hanaga ? Rol.janij : u.rol;
    String? kid = u.kuvthzaId;
    var ok = u.aprobado;
    await showDialog(
      context: context,
      builder: (ctx) => StatefulBuilder(
        builder: (ctx, set) => AlertDialog(
          title: Text(u.display),
          content: Column(mainAxisSize: MainAxisSize.min, children: [
            SwitchListTile(
                title: const Text('Aprobado'), value: ok, onChanged: (v) => set(() => ok = v)),
            DropdownButtonFormField<Rol>(
              value: rol,
              decoration: const InputDecoration(labelText: 'Rol'),
              items: [
                for (final r in Rol.values.where((r) => r != Rol.hanaga))
                  DropdownMenuItem(value: r, child: Text(r.label))
              ],
              onChanged: (v) => set(() => rol = v!),
            ),
            const SizedBox(height: 12),
            DropdownButtonFormField<String?>(
              value: ks.any((k) => k.id == kid) ? kid : null,
              decoration: const InputDecoration(labelText: 'Kuvthzá'),
              items: [
                const DropdownMenuItem(value: null, child: Text('Sin kuvthzá')),
                for (final k in ks) DropdownMenuItem(value: k.id, child: Text(k.nombre)),
              ],
              onChanged: (v) => set(() => kid = v),
            ),
            if (rol == Rol.boguer)
              const Padding(
                padding: EdgeInsets.only(top: 8),
                child: Text('Un boguer con kuvthzá pasa a ser madrij.',
                    style: TextStyle(fontSize: 12)),
              ),
          ]),
          actions: [
            TextButton(onPressed: () => Navigator.pop(ctx), child: const Text('Cancelar')),
            FilledButton(
              style: FilledButton.styleFrom(minimumSize: const Size(100, 40)),
              onPressed: () async {
                await Db.actualizarUsuario(u, rol: rol, kuvthzaId: kid, aprobado: ok);
                if (ctx.mounted) Navigator.pop(ctx);
              },
              child: const Text('Guardar'),
            ),
          ],
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return StreamBuilder<List<Kuvthza>>(
      stream: Db.kuvthzot(),
      builder: (_, ks) => StreamBuilder<List<AppUser>>(
        stream: Db.usuarios(),
        builder: (_, s) {
          final users = s.data ?? [];
          final pend = users.where((u) => !u.aprobado).toList();
          final rest = users.where((u) => u.aprobado).toList();
          Widget tile(AppUser u) => ListTile(
                title: Text(u.display),
                subtitle: Text(
                    '${u.rol.label} · ${kuvthzaName(ks.data ?? [], u.kuvthzaId) ?? 'sin kuvthzá'}'),
                // La Hanagá no puede gestionar a otros miembros de la Hanagá.
                trailing: u.esHanaga ? const Icon(LucideIcons.lock) : const Icon(LucideIcons.pencil),
                onTap: u.esHanaga ? null : () => _edit(context, u, ks.data ?? []),
              );
          return ListView(children: [
            if (pend.isNotEmpty) ...[
              const Padding(
                  padding: EdgeInsets.fromLTRB(16, 16, 16, 4), child: Text('Pendientes')),
              for (final u in pend) tile(u),
            ],
            const Padding(padding: EdgeInsets.fromLTRB(16, 16, 16, 4), child: Text('Miembros')),
            for (final u in rest) tile(u),
          ]);
        },
      ),
    );
  }
}

class _Kuvthzot extends StatelessWidget {
  const _Kuvthzot();

  @override
  Widget build(BuildContext context) {
    return StreamBuilder<List<Kuvthza>>(
      stream: Db.kuvthzot(),
      builder: (_, s) {
        final ks = s.data ?? [];
        return Scaffold(
          backgroundColor: Colors.transparent,
          floatingActionButton: FloatingActionButton(
            child: const Icon(LucideIcons.plus),
            onPressed: () async {
              final c = TextEditingController();
              await showDialog(
                context: context,
                builder: (ctx) => AlertDialog(
                  title: const Text('Nueva kuvthzá'),
                  content: TextField(controller: c, decoration: const InputDecoration(labelText: 'Nombre')),
                  actions: [
                    TextButton(onPressed: () => Navigator.pop(ctx), child: const Text('Cancelar')),
                    FilledButton(
                      style: FilledButton.styleFrom(minimumSize: const Size(100, 40)),
                      onPressed: () async {
                        if (c.text.trim().isNotEmpty) await Db.addKuvthza(c.text);
                        if (ctx.mounted) Navigator.pop(ctx);
                      },
                      child: const Text('Crear'),
                    ),
                  ],
                ),
              );
            },
          ),
          body: ListView(children: [
            for (final k in ks)
              ListTile(
                title: Text(k.nombre),
                trailing: IconButton(
                    icon: const Icon(LucideIcons.trash2),
                    onPressed: () => Db.deleteKuvthza(k.id)),
              ),
          ]),
        );
      },
    );
  }
}

class _Tema extends StatefulWidget {
  const _Tema();
  @override
  State<_Tema> createState() => _TemaState();
}

class _TemaState extends State<_Tema> {
  final _c = TextEditingController();

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.all(20),
      child: Column(children: [
        StreamBuilder<String>(
          stream: Db.temaSabado(),
          builder: (_, s) => Align(
              alignment: Alignment.centerLeft,
              child: Text('Actual: ${(s.data ?? '').isEmpty ? 'sin definir' : s.data}')),
        ),
        const SizedBox(height: 12),
        TextField(controller: _c, decoration: const InputDecoration(labelText: 'Tema del próximo sábado')),
        const SizedBox(height: 16),
        FilledButton(
          onPressed: () async {
            await Db.setTema(_c.text);
            if (context.mounted) snack(context, 'Tema actualizado');
          },
          child: const Text('Guardar'),
        ),
      ]),
    );
  }
}
