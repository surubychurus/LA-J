import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import 'package:lucide_icons_flutter/lucide_icons.dart';

import '../models.dart';

class AnuncioCard extends StatelessWidget {
  final Anuncio a;
  final String? kuvthzaNombre;
  final VoidCallback? onDelete;
  const AnuncioCard({super.key, required this.a, this.kuvthzaNombre, this.onDelete});

  @override
  Widget build(BuildContext context) {
    final t = Theme.of(context);
    return Card(
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(children: [
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 2),
                decoration: BoxDecoration(
                  color: t.colorScheme.primary.withValues(alpha: 0.12),
                  borderRadius: BorderRadius.circular(20),
                ),
                child: Text(kuvthzaNombre ?? 'General',
                    style: t.textTheme.labelSmall?.copyWith(color: t.colorScheme.primary)),
              ),
              const Spacer(),
              Text(DateFormat('d MMM', 'es').format(a.fecha), style: t.textTheme.labelSmall),
              if (onDelete != null)
                IconButton(
                    visualDensity: VisualDensity.compact,
                    icon: const Icon(LucideIcons.trash2, size: 20),
                    onPressed: onDelete),
            ]),
            const SizedBox(height: 8),
            Text(a.titulo, style: t.textTheme.titleMedium),
            if (a.cuerpo.isNotEmpty) ...[
              const SizedBox(height: 4),
              Text(a.cuerpo),
            ],
          ],
        ),
      ),
    );
  }
}

String? kuvthzaName(List<Kuvthza> ks, String? id) =>
    id == null ? null : ks.where((k) => k.id == id).firstOrNull?.nombre;

void snack(BuildContext c, String m) =>
    ScaffoldMessenger.of(c).showSnackBar(SnackBar(content: Text(m)));

class PageHeader extends StatelessWidget {
  final String title;
  final String? subtitle;
  final Widget? trailing;
  const PageHeader(this.title, {super.key, this.subtitle, this.trailing});

  @override
  Widget build(BuildContext context) {
    final t = Theme.of(context);
    return Padding(
      padding: const EdgeInsets.only(bottom: 20),
      child: Row(children: [
        Expanded(
          child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
            Text(title, style: t.textTheme.headlineSmall),
            if (subtitle != null)
              Text(subtitle!,
                  style: t.textTheme.bodySmall
                      ?.copyWith(color: t.colorScheme.onSurface.withValues(alpha: 0.6))),
          ]),
        ),
        if (trailing != null) trailing!,
      ]),
    );
  }
}

class EmptyState extends StatelessWidget {
  final IconData icon;
  final String text;
  const EmptyState(this.icon, this.text, {super.key});

  @override
  Widget build(BuildContext context) {
    final t = Theme.of(context);
    final c = t.colorScheme.onSurface.withValues(alpha: 0.4);
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 40),
      child: Center(
        child: Column(mainAxisSize: MainAxisSize.min, children: [
          Icon(icon, size: 36, color: c),
          const SizedBox(height: 12),
          Text(text, style: t.textTheme.bodyMedium?.copyWith(color: c), textAlign: TextAlign.center),
        ]),
      ),
    );
  }
}

/// Avatar con foto o inicial, usado en saludo, perfil y chats.
class Initial extends StatelessWidget {
  final String text;
  final double radius;
  final ImageProvider? image;
  const Initial(this.text, {super.key, this.radius = 20, this.image});

  @override
  Widget build(BuildContext context) {
    final t = Theme.of(context);
    return CircleAvatar(
      radius: radius,
      backgroundColor: t.colorScheme.primary.withValues(alpha: 0.12),
      backgroundImage: image,
      child: image == null
          ? Text(text.isEmpty ? '?' : text[0].toUpperCase(),
              style: t.textTheme.titleMedium?.copyWith(color: t.colorScheme.primary))
          : null,
    );
  }
}
