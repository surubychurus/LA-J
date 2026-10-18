import 'package:flutter/material.dart';
import 'package:lucide_icons_flutter/lucide_icons.dart';

import '../models.dart';
import '../services/db.dart';
import 'news_manage_screen.dart';
import 'widgets.dart';

class NewsScreen extends StatefulWidget {
  final AppUser user;
  const NewsScreen({super.key, required this.user});
  @override
  State<NewsScreen> createState() => _NewsScreenState();
}

class _NewsScreenState extends State<NewsScreen> {
  bool _all = false;

  @override
  Widget build(BuildContext context) {
    final u = widget.user;
    final t = Theme.of(context);
    return StreamBuilder<List<Kuvthza>>(
      stream: Db.kuvthzot(),
      builder: (_, ks) {
        final kl = ks.data ?? [];
        return StreamBuilder<List<Anuncio>>(
          stream: Db.anuncios(u),
          builder: (_, s) {
            final all = s.data ?? [];
            final list = _all ? all : all.take(3).toList();
            return ListView(
              padding: const EdgeInsets.all(20),
              children: [
                PageHeader(
                  'Novedades',
                  subtitle: 'Generales y de tu kuvthzá',
                  trailing: u.puedePublicar
                      ? FilledButton.tonalIcon(
                          style: FilledButton.styleFrom(minimumSize: const Size(0, 40)),
                          icon: const Icon(LucideIcons.settings2, size: 16),
                          label: const Text('Gestionar'),
                          onPressed: () => Navigator.push(
                              context, MaterialPageRoute(builder: (_) => NewsManageScreen(user: u))),
                        )
                      : null,
                ),
                if (list.isEmpty) const EmptyState(LucideIcons.megaphone, 'No hay novedades'),
                for (final a in list)
                  Padding(
                    padding: const EdgeInsets.only(bottom: 10),
                    child: AnuncioCard(a: a, kuvthzaNombre: kuvthzaName(kl, a.kuvthzaId)),
                  ),
                if (all.length > 3)
                  TextButton(
                    onPressed: () => setState(() => _all = !_all),
                    child: Text(_all ? 'Ver menos' : 'Ver todos (${all.length})',
                        style: TextStyle(color: t.colorScheme.primary)),
                  ),
              ],
            );
          },
        );
      },
    );
  }
}
