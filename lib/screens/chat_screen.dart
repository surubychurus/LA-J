import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import 'package:lucide_icons_flutter/lucide_icons.dart';

import '../models.dart';
import '../services/db.dart';
import '../services/notifs.dart';
import '../theme.dart';
import 'widgets.dart';

class ChatScreen extends StatelessWidget {
  final AppUser user;
  const ChatScreen({super.key, required this.user});

  @override
  Widget build(BuildContext context) {
    final t = Theme.of(context);
    return StreamBuilder<List<Kuvthza>>(
      stream: Db.kuvthzot(),
      builder: (_, s) {
        final rooms = chatsFor(user, s.data ?? []);
        return ListView(
          padding: const EdgeInsets.all(20),
          children: [
            const PageHeader('Chats', subtitle: 'Tus grupos'),
            if (rooms.isEmpty)
              const EmptyState(LucideIcons.messageCircle,
                  'No tenés chats todavía.\nLa Hanagá tiene que asignarte una kuvthzá.'),
            for (final r in rooms)
              Padding(
                padding: const EdgeInsets.only(bottom: 10),
                child: Card(
                  child: ListTile(
                    contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 6),
                    leading: CircleAvatar(
                      backgroundColor: t.colorScheme.primary.withValues(alpha: 0.12),
                      child: Icon(LucideIcons.users, size: 20, color: t.colorScheme.primary),
                    ),
                    title: Text(r.titulo, style: t.textTheme.titleMedium),
                    subtitle: Text(r.subtitulo),
                    trailing: const Icon(LucideIcons.chevronRight, size: 18),
                    onTap: () => Navigator.push(context,
                        MaterialPageRoute(builder: (_) => ChatRoomScreen(room: r, user: user))),
                  ),
                ),
              ),
          ],
        );
      },
    );
  }
}

class ChatRoomScreen extends StatefulWidget {
  final ChatRoom room;
  final AppUser user;
  const ChatRoomScreen({super.key, required this.room, required this.user});
  @override
  State<ChatRoomScreen> createState() => _ChatRoomScreenState();
}

class _ChatRoomScreenState extends State<ChatRoomScreen> {
  final _c = TextEditingController();

  @override
  void initState() {
    super.initState();
    Notifs.salaActiva = widget.room.id;
  }

  @override
  void dispose() {
    if (Notifs.salaActiva == widget.room.id) Notifs.salaActiva = null;
    _c.dispose();
    super.dispose();
  }

  void _send() {
    final text = _c.text.trim();
    if (text.isEmpty) return;
    _c.clear();
    Db.enviar(widget.room.id, widget.user, text);
  }

  bool _sameDay(DateTime a, DateTime b) => a.year == b.year && a.month == b.month && a.day == b.day;

  String _dayLabel(DateTime d) {
    final now = DateTime.now();
    if (_sameDay(d, now)) return 'Hoy';
    if (_sameDay(d, now.subtract(const Duration(days: 1)))) return 'Ayer';
    return DateFormat("d 'de' MMMM", 'es').format(d);
  }

  OutlineInputBorder get _pill =>
      OutlineInputBorder(borderRadius: BorderRadius.circular(26), borderSide: BorderSide.none);

  @override
  Widget build(BuildContext context) {
    final t = Theme.of(context);
    final dark = t.brightness == Brightness.dark;
    final muted = t.colorScheme.onSurface.withValues(alpha: 0.55);
    return Scaffold(
      appBar: AppBar(
        titleSpacing: 0,
        title: Row(children: [
          CircleAvatar(
            radius: 18,
            backgroundColor: t.colorScheme.primary.withValues(alpha: 0.12),
            child: Icon(LucideIcons.users, size: 18, color: t.colorScheme.primary),
          ),
          const SizedBox(width: 12),
          Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
            Text(widget.room.titulo, style: t.textTheme.titleMedium),
            Text(widget.room.subtitulo, style: t.textTheme.labelSmall?.copyWith(color: muted)),
          ]),
        ]),
      ),
      body: Center(
        // En pantallas anchas el chat no se estira de lado a lado.
        child: ConstrainedBox(
          constraints: const BoxConstraints(maxWidth: 720),
          child: Column(children: [
            Expanded(
              child: StreamBuilder<List<Mensaje>>(
                stream: Db.mensajes(widget.room.id),
                builder: (_, s) {
                  final msgs = s.data ?? [];
                  if (msgs.isEmpty) {
                    return const EmptyState(
                        LucideIcons.messageCircle, 'Todavía no hay mensajes.\nEscribí el primero.');
                  }
                  final maxBubble = (MediaQuery.of(context).size.width * 0.78).clamp(0.0, 460.0);
                  return ListView.builder(
                    reverse: true,
                    padding: const EdgeInsets.fromLTRB(12, 12, 12, 8),
                    itemCount: msgs.length,
                    itemBuilder: (_, i) {
                      final m = msgs[i];
                      final mine = m.uid == widget.user.uid;
                      final older = i + 1 < msgs.length ? msgs[i + 1] : null;
                      final newDay = older == null || !_sameDay(older.fecha, m.fecha);
                      final firstOfGroup = newDay || older.uid != m.uid;
                      final bubbleColor =
                          mine ? AppColors.normal : (dark ? const Color(0xFF0B1445) : Colors.white);
                      final fg = mine ? Colors.white : t.colorScheme.onSurface;
                      return Column(children: [
                        if (newDay)
                          Padding(
                            padding: const EdgeInsets.symmetric(vertical: 12),
                            child: Container(
                              padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 4),
                              decoration: BoxDecoration(
                                color: t.colorScheme.onSurface.withValues(alpha: 0.07),
                                borderRadius: BorderRadius.circular(20),
                              ),
                              child: Text(_dayLabel(m.fecha),
                                  style: t.textTheme.labelSmall?.copyWith(color: muted)),
                            ),
                          ),
                        Align(
                          alignment: mine ? Alignment.centerRight : Alignment.centerLeft,
                          child: Container(
                            margin: EdgeInsets.only(top: firstOfGroup ? 8 : 2),
                            padding: const EdgeInsets.fromLTRB(12, 8, 12, 6),
                            constraints: BoxConstraints(maxWidth: maxBubble),
                            decoration: BoxDecoration(
                              color: bubbleColor,
                              borderRadius: BorderRadius.only(
                                topLeft: Radius.circular(!mine && firstOfGroup ? 4 : 18),
                                topRight: Radius.circular(mine && firstOfGroup ? 4 : 18),
                                bottomLeft: const Radius.circular(18),
                                bottomRight: const Radius.circular(18),
                              ),
                              border: mine
                                  ? null
                                  : Border.all(color: t.colorScheme.onSurface.withValues(alpha: 0.08)),
                            ),
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              mainAxisSize: MainAxisSize.min,
                              children: [
                                if (!mine && firstOfGroup)
                                  Padding(
                                    padding: const EdgeInsets.only(bottom: 2),
                                    child: Text(m.autor,
                                        style: t.textTheme.labelMedium?.copyWith(
                                            color: t.colorScheme.primary, fontWeight: FontWeight.w600)),
                                  ),
                                Wrap(
                                  alignment: WrapAlignment.end,
                                  crossAxisAlignment: WrapCrossAlignment.end,
                                  spacing: 10,
                                  children: [
                                    Text(m.texto, style: t.textTheme.bodyMedium?.copyWith(color: fg)),
                                    Text(DateFormat.Hm().format(m.fecha),
                                        style: t.textTheme.labelSmall?.copyWith(
                                            fontSize: 10, color: mine ? Colors.white70 : muted)),
                                  ],
                                ),
                              ],
                            ),
                          ),
                        ),
                      ]);
                    },
                  );
                },
              ),
            ),
            SafeArea(
              top: false,
              child: Padding(
                padding: const EdgeInsets.fromLTRB(12, 4, 12, 10),
                child: Row(crossAxisAlignment: CrossAxisAlignment.end, children: [
                  Expanded(
                    child: TextField(
                      controller: _c,
                      minLines: 1,
                      maxLines: 5,
                      textCapitalization: TextCapitalization.sentences,
                      decoration: InputDecoration(
                        hintText: 'Escribí un mensaje',
                        contentPadding: const EdgeInsets.symmetric(horizontal: 18, vertical: 12),
                        border: _pill,
                        enabledBorder: _pill,
                        focusedBorder: _pill,
                      ),
                      onSubmitted: (_) => _send(),
                    ),
                  ),
                  const SizedBox(width: 8),
                  IconButton.filled(
                    onPressed: _send,
                    style: IconButton.styleFrom(
                        backgroundColor: AppColors.normal,
                        foregroundColor: Colors.white,
                        fixedSize: const Size(48, 48)),
                    icon: const Icon(LucideIcons.send, size: 20),
                  ),
                ]),
              ),
            ),
          ]),
        ),
      ),
    );
  }
}
