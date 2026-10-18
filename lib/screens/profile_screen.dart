import 'package:cached_network_image/cached_network_image.dart';
import 'package:flutter/material.dart';
import 'package:lucide_icons_flutter/lucide_icons.dart';
import 'package:image_picker/image_picker.dart';
import 'package:provider/provider.dart';

import '../models.dart';
import '../services/app_state.dart';
import '../services/db.dart';
import 'admin_screen.dart';
import 'widgets.dart';

class ProfileScreen extends StatelessWidget {
  final AppUser user;
  const ProfileScreen({super.key, required this.user});

  Future<void> _avatar(BuildContext context) async {
    final f = await ImagePicker()
        .pickImage(source: ImageSource.gallery, maxWidth: 512, imageQuality: 85);
    if (f == null) return;
    await Db.subirAvatar(user.uid, await f.readAsBytes());
  }

  Future<void> _editNames(BuildContext context) async {
    final n = TextEditingController(text: user.nombre);
    final a = TextEditingController(text: user.apodo);
    await showDialog(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('Nombre y apodo'),
        content: Column(mainAxisSize: MainAxisSize.min, children: [
          TextField(controller: n, decoration: const InputDecoration(labelText: 'Nombre')),
          const SizedBox(height: 12),
          TextField(controller: a, decoration: const InputDecoration(labelText: 'Apodo')),
        ]),
        actions: [
          TextButton(onPressed: () => Navigator.pop(ctx), child: const Text('Cancelar')),
          FilledButton(
            style: FilledButton.styleFrom(minimumSize: const Size(100, 40)),
            onPressed: () async {
              await Db.actualizarPerfil(user.uid, nombre: n.text, apodo: a.text);
              if (ctx.mounted) Navigator.pop(ctx);
            },
            child: const Text('Guardar'),
          ),
        ],
      ),
    );
  }

  Future<void> _password(BuildContext context) async {
    final cur = TextEditingController();
    final nw = TextEditingController();
    final state = context.read<AppState>();
    await showDialog(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('Cambiar contraseña'),
        content: Column(mainAxisSize: MainAxisSize.min, children: [
          TextField(
              controller: cur,
              obscureText: true,
              decoration: const InputDecoration(labelText: 'Contraseña actual')),
          const SizedBox(height: 12),
          TextField(
              controller: nw,
              obscureText: true,
              decoration: const InputDecoration(labelText: 'Nueva contraseña')),
        ]),
        actions: [
          TextButton(onPressed: () => Navigator.pop(ctx), child: const Text('Cancelar')),
          FilledButton(
            style: FilledButton.styleFrom(minimumSize: const Size(100, 40)),
            onPressed: () async {
              try {
                await state.changePassword(cur.text, nw.text);
                if (ctx.mounted) Navigator.pop(ctx);
                if (context.mounted) snack(context, 'Contraseña actualizada');
              } catch (_) {
                if (ctx.mounted) snack(ctx, 'No se pudo cambiar la contraseña');
              }
            },
            child: const Text('Cambiar'),
          ),
        ],
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final t = Theme.of(context);
    final state = context.watch<AppState>();
    return ListView(
      padding: const EdgeInsets.all(20),
      children: [
        const PageHeader('Yo', subtitle: 'Tu perfil y ajustes'),
        Center(
          child: GestureDetector(
            onTap: () => _avatar(context),
            child: Stack(children: [
              CircleAvatar(
                radius: 52,
                backgroundColor: t.colorScheme.primary.withValues(alpha: 0.12),
                backgroundImage:
                    user.fotoUrl != null ? CachedNetworkImageProvider(user.fotoUrl!) : null,
                child: user.fotoUrl == null
                    ? Text(user.display.isEmpty ? '?' : user.display[0].toUpperCase(),
                        style: t.textTheme.headlineMedium?.copyWith(color: t.colorScheme.primary))
                    : null,
              ),
              Positioned(
                right: 0,
                bottom: 0,
                child: CircleAvatar(
                    radius: 16,
                    backgroundColor: t.colorScheme.primary,
                    child: const Icon(LucideIcons.pencil, size: 16, color: Colors.white)),
              ),
            ]),
          ),
        ),
        const SizedBox(height: 12),
        Center(child: Text(user.nombre, style: t.textTheme.titleLarge)),
        Center(child: Text('${user.rol.label} · ${user.email}', style: t.textTheme.bodySmall)),
        const SizedBox(height: 24),
        Card(
          child: Column(children: [
            ListTile(
              leading: const Icon(LucideIcons.idCard),
              title: const Text('Nombre y apodo'),
              subtitle: Text(user.apodo.isEmpty ? user.nombre : '${user.nombre} · ${user.apodo}'),
              onTap: () => _editNames(context),
            ),
            const Divider(),
            ListTile(
              leading: const Icon(LucideIcons.lock),
              title: const Text('Contraseña'),
              onTap: () => _password(context),
            ),
            const Divider(),
            SwitchListTile(
              secondary: const Icon(LucideIcons.moon),
              title: const Text('Tema oscuro'),
              value: state.themeMode == ThemeMode.dark,
              onChanged: state.setDark,
            ),
          ]),
        ),
        if (user.esHanaga) ...[
          const SizedBox(height: 12),
          Card(
            child: ListTile(
              leading: const Icon(LucideIcons.shieldCheck),
              title: const Text('Panel de la Hanagá'),
              subtitle: const Text('Usuarios, kuvthzot y tema del sábado'),
              trailing: const Icon(LucideIcons.chevronRight),
              onTap: () => Navigator.push(
                  context, MaterialPageRoute(builder: (_) => const AdminScreen())),
            ),
          ),
        ],
        const SizedBox(height: 12),
        OutlinedButton(
          onPressed: state.logout,
          style: OutlinedButton.styleFrom(minimumSize: const Size.fromHeight(48)),
          child: const Text('Cerrar sesión'),
        ),
      ],
    );
  }
}
