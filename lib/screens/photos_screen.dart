import 'package:cached_network_image/cached_network_image.dart';
import 'package:flutter/material.dart';
import 'package:lucide_icons_flutter/lucide_icons.dart';
import 'package:image_picker/image_picker.dart';
import 'package:intl/intl.dart';
import 'package:url_launcher/url_launcher.dart';

import '../models.dart';
import '../services/db.dart';
import 'widgets.dart';

class PhotosScreen extends StatelessWidget {
  final AppUser user;
  const PhotosScreen({super.key, required this.user});

  Future<void> _upload(BuildContext context, bool video) async {
    final picker = ImagePicker();
    final f = video
        ? await picker.pickVideo(source: ImageSource.gallery)
        : await picker.pickImage(source: ImageSource.gallery, imageQuality: 85);
    if (f == null) return;
    // Se asocia al último sábado.
    final now = DateTime.now();
    final sab = DateTime(now.year, now.month, now.day)
        .subtract(Duration(days: (now.weekday - DateTime.saturday) % 7));
    await Db.subirFoto(await f.readAsBytes(), f.name, video, sab);
    if (context.mounted) snack(context, 'Subido');
  }

  @override
  Widget build(BuildContext context) {
    final t = Theme.of(context);
    return Scaffold(
      backgroundColor: Colors.transparent,
      floatingActionButton: user.puedeSubirFotos
          ? PopupMenuButton<bool>(
              onSelected: (v) => _upload(context, v),
              itemBuilder: (_) => const [
                PopupMenuItem(value: false, child: Text('Foto')),
                PopupMenuItem(value: true, child: Text('Video')),
              ],
              child: CircleAvatar(
                radius: 28,
                backgroundColor: t.colorScheme.primary,
                child: const Icon(LucideIcons.camera, color: Colors.white),
              ),
            )
          : null,
      body: StreamBuilder<List<Foto>>(
        stream: Db.fotos(),
        builder: (_, s) {
          final list = s.data ?? [];
          if (list.isEmpty) return const EmptyState(LucideIcons.image, 'Todavía no hay fotos');
          // Agrupadas por sábado.
          final groups = <DateTime, List<Foto>>{};
          for (final f in list) {
            groups.putIfAbsent(DateTime(f.sabado.year, f.sabado.month, f.sabado.day), () => []).add(f);
          }
          return ListView(
            padding: const EdgeInsets.all(20),
            children: [
              const PageHeader('Fotos y videos', subtitle: 'Lo mejor de cada sábado'),
              for (final e in groups.entries) ...[
                const SizedBox(height: 12),
                Text(DateFormat("EEEE d 'de' MMMM", 'es').format(e.key),
                    style: t.textTheme.titleMedium),
                const SizedBox(height: 8),
                GridView.count(
                  crossAxisCount: 3,
                  mainAxisSpacing: 6,
                  crossAxisSpacing: 6,
                  shrinkWrap: true,
                  physics: const NeverScrollableScrollPhysics(),
                  children: [
                    for (final f in e.value)
                      GestureDetector(
                        onTap: () => f.esVideo
                            ? launchUrl(Uri.parse(f.url), mode: LaunchMode.externalApplication)
                            : showDialog(
                                context: context,
                                builder: (_) => Dialog(
                                    child: InteractiveViewer(
                                        child: CachedNetworkImage(imageUrl: f.url)))),
                        child: ClipRRect(
                          borderRadius: BorderRadius.circular(16),
                          child: f.esVideo
                              ? Container(
                                  color: t.colorScheme.secondary,
                                  child: const Center(
                                      child: Icon(LucideIcons.circlePlay, color: Colors.white, size: 36)))
                              : CachedNetworkImage(imageUrl: f.url, fit: BoxFit.cover),
                        ),
                      ),
                  ],
                ),
              ],
              const SizedBox(height: 80),
            ],
          );
        },
      ),
    );
  }
}
