import 'dart:async';

import 'package:cached_network_image/cached_network_image.dart';
import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import 'package:lucide_icons_flutter/lucide_icons.dart';

import '../models.dart';
import '../services/db.dart';
import 'widgets.dart';

class HomeScreen extends StatelessWidget {
  final AppUser user;
  const HomeScreen({super.key, required this.user});

  @override
  Widget build(BuildContext context) {
    final t = Theme.of(context);
    final muted = t.colorScheme.onSurface.withValues(alpha: 0.6);
    return ListView(
      padding: const EdgeInsets.fromLTRB(20, 16, 20, 24),
      children: [
        Row(children: [
          Initial(user.display,
              radius: 22,
              image: user.fotoUrl != null ? CachedNetworkImageProvider(user.fotoUrl!) : null),
          const SizedBox(width: 12),
          Expanded(
            child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
              Text('Shalom,', style: t.textTheme.bodySmall?.copyWith(color: muted)),
              Text(user.display, style: t.textTheme.titleLarge),
            ]),
          ),
        ]),
        const SizedBox(height: 24),
        const _Countdown(),
        const SizedBox(height: 12),
        StreamBuilder<String>(
          stream: Db.temaSabado(),
          builder: (_, s) {
            final tema = (s.data ?? '').trim();
            return Card(
              child: Padding(
                padding: const EdgeInsets.all(16),
                child: Row(children: [
                  Container(
                    padding: const EdgeInsets.all(10),
                    decoration: BoxDecoration(
                      color: t.colorScheme.primary.withValues(alpha: 0.12),
                      borderRadius: BorderRadius.circular(14),
                    ),
                    child: Icon(LucideIcons.sparkles, size: 20, color: t.colorScheme.primary),
                  ),
                  const SizedBox(width: 14),
                  Expanded(
                    child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                      Text('Tema del sábado',
                          style: t.textTheme.bodySmall?.copyWith(color: muted)),
                      const SizedBox(height: 2),
                      Text(tema.isEmpty ? 'Todavía sin definir' : tema,
                          style: t.textTheme.titleMedium),
                    ]),
                  ),
                ]),
              ),
            );
          },
        ),
        const SizedBox(height: 28),
        Text('Cartelera', style: t.textTheme.titleLarge),
        const SizedBox(height: 12),
        StreamBuilder<List<Kuvthza>>(
          stream: Db.kuvthzot(),
          builder: (_, ks) => StreamBuilder<List<Anuncio>>(
            stream: Db.anuncios(user),
            builder: (_, s) {
              final list = s.data ?? [];
              if (list.isEmpty) {
                return const EmptyState(LucideIcons.megaphone, 'No hay anuncios por ahora');
              }
              return Column(children: [
                for (final a in list.take(10))
                  Padding(
                    padding: const EdgeInsets.only(bottom: 10),
                    child: AnuncioCard(a: a, kuvthzaNombre: kuvthzaName(ks.data ?? [], a.kuvthzaId)),
                  ),
              ]);
            },
          ),
        ),
      ],
    );
  }
}

class _Countdown extends StatefulWidget {
  const _Countdown();
  @override
  State<_Countdown> createState() => _CountdownState();
}

class _CountdownState extends State<_Countdown> {
  late Timer _timer;
  Duration _left = Duration.zero;

  void _tick() => setState(() => _left = proximoSabado().difference(DateTime.now()));

  @override
  void initState() {
    super.initState();
    _tick();
    _timer = Timer.periodic(const Duration(seconds: 1), (_) => _tick());
  }

  @override
  void dispose() {
    _timer.cancel();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final t = Theme.of(context);
    Widget cell(int v, String l) => Expanded(
          child: Column(children: [
            Text(v.toString().padLeft(2, '0'),
                style: t.textTheme.displaySmall?.copyWith(color: Colors.white, height: 1.1)),
            const SizedBox(height: 2),
            Text(l, style: t.textTheme.labelSmall?.copyWith(color: Colors.white70)),
          ]),
        );
    final fecha = DateFormat("EEEE d 'de' MMMM", 'es').format(proximoSabado());
    return Container(
      padding: const EdgeInsets.fromLTRB(16, 20, 16, 20),
      decoration: BoxDecoration(
        borderRadius: BorderRadius.circular(28),
        gradient: const LinearGradient(
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
          colors: [Color(0xFF195EFC), Color(0xFF0B3BB8)],
        ),
      ),
      child: Column(children: [
        Row(mainAxisAlignment: MainAxisAlignment.center, children: [
          const Icon(LucideIcons.clock, size: 14, color: Colors.white70),
          const SizedBox(width: 6),
          Text('$fecha · 14:30', style: t.textTheme.labelMedium?.copyWith(color: Colors.white70)),
        ]),
        const SizedBox(height: 16),
        Row(children: [
          cell(_left.inDays, 'días'),
          cell(_left.inHours % 24, 'horas'),
          cell(_left.inMinutes % 60, 'min'),
          cell(_left.inSeconds % 60, 'seg'),
        ]),
      ]),
    );
  }
}
