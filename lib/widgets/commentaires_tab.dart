import 'package:flutter/material.dart';
import 'package:lucide_icons/lucide_icons.dart';
import '../constants/colors.dart';

class CommentairesTab extends StatefulWidget {
  const CommentairesTab({super.key});

  @override
  State<CommentairesTab> createState() => _CommentairesTabState();
}

class _CommentairesTabState extends State<CommentairesTab> {
  final _controller = TextEditingController();
  final _scrollCtrl = ScrollController();

  final List<_Message> _messages = [
    _Message(
      auteur: 'Ahmed Bennani',
      role: 'ARCHITECTE',
      date: '15/01 01:00',
      texte: 'Projet initialisé, en attente de la validation finale du client.',
      isMine: true,
    ),
  ];

  void _send() {
    final text = _controller.text.trim();
    if (text.isEmpty) return;
    setState(() {
      _messages.add(
        _Message(
          auteur: 'Ahmed Bennani',
          role: 'ARCHITECTE',
          date: 'maintenant',
          texte: text,
          isMine: true,
        ),
      );
      _controller.clear();
    });
    Future.delayed(const Duration(milliseconds: 100), () {
      _scrollCtrl.animateTo(
        _scrollCtrl.position.maxScrollExtent,
        duration: const Duration(milliseconds: 200),
        curve: Curves.easeOut,
      );
    });
  }

  @override
  void dispose() {
    _controller.dispose();
    _scrollCtrl.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final isMobile = MediaQuery.of(context).size.width < 800;
    final pad = isMobile ? 16.0 : 28.0;

    return Padding(
      padding: EdgeInsets.all(pad),
      child: isMobile
          ? Column(
              children: [
                Expanded(
                  child: _ChatSection(
                    messages: _messages,
                    scrollCtrl: _scrollCtrl,
                  ),
                ),
                const SizedBox(height: 12),
                _InputBar(controller: _controller, onSend: _send),
              ],
            )
          : Row(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                // Chat
                Expanded(
                  flex: 3,
                  child: Column(
                    children: [
                      Expanded(
                        child: _ChatSection(
                          messages: _messages,
                          scrollCtrl: _scrollCtrl,
                        ),
                      ),
                      const SizedBox(height: 12),
                      _InputBar(controller: _controller, onSend: _send),
                    ],
                  ),
                ),
                const SizedBox(width: 20),
                // Info panel
                const SizedBox(width: 260, child: _InfoPanel()),
              ],
            ),
    );
  }
}

// ── Chat section ──────────────────────────────────────────────────────────────
class _ChatSection extends StatelessWidget {
  final List<_Message> messages;
  final ScrollController scrollCtrl;
  const _ChatSection({required this.messages, required this.scrollCtrl});

  @override
  Widget build(BuildContext context) {
    return Container(
      decoration: BoxDecoration(
        color: kCardBg,
        borderRadius: BorderRadius.circular(12),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withOpacity(0.04),
            blurRadius: 6,
            offset: const Offset(0, 2),
          ),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // Header
          Padding(
            padding: const EdgeInsets.fromLTRB(16, 16, 16, 12),
            child: Row(
              children: const [
                Icon(LucideIcons.messageSquare, size: 16, color: kTextSub),
                SizedBox(width: 8),
                Text(
                  'Fil de discussion',
                  style: TextStyle(
                    fontWeight: FontWeight.w700,
                    fontSize: 15,
                    color: kTextMain,
                  ),
                ),
              ],
            ),
          ),
          const Divider(height: 1, color: Color(0xFFF3F4F6)),

          // Messages
          Expanded(
            child: ListView.builder(
              controller: scrollCtrl,
              padding: const EdgeInsets.all(16),
              itemCount: messages.length,
              itemBuilder: (ctx, i) => _MessageBubble(msg: messages[i]),
            ),
          ),
        ],
      ),
    );
  }
}

// ── Input bar ─────────────────────────────────────────────────────────────────
class _InputBar extends StatelessWidget {
  final TextEditingController controller;
  final VoidCallback onSend;
  const _InputBar({required this.controller, required this.onSend});

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
      decoration: BoxDecoration(
        color: kCardBg,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: const Color(0xFFE5E7EB)),
      ),
      child: Row(
        children: [
          Expanded(
            child: TextField(
              controller: controller,
              onSubmitted: (_) => onSend(),
              style: const TextStyle(fontSize: 13, color: kTextMain),
              decoration: const InputDecoration(
                hintText: 'Écrivez votre commentaire...',
                hintStyle: TextStyle(color: kTextSub, fontSize: 13),
                border: InputBorder.none,
                isDense: true,
                contentPadding: EdgeInsets.zero,
              ),
            ),
          ),
          const SizedBox(width: 8),
          GestureDetector(
            onTap: onSend,
            child: Container(
              width: 36,
              height: 36,
              decoration: BoxDecoration(
                color: kAccent,
                borderRadius: BorderRadius.circular(8),
              ),
              child: const Icon(
                Icons.send_rounded,
                color: Colors.white,
                size: 16,
              ),
            ),
          ),
        ],
      ),
    );
  }
}

// ── Message bubble ────────────────────────────────────────────────────────────
class _Message {
  final String auteur;
  final String role;
  final String date;
  final String texte;
  final bool isMine;
  const _Message({
    required this.auteur,
    required this.role,
    required this.date,
    required this.texte,
    required this.isMine,
  });
}

class _MessageBubble extends StatelessWidget {
  final _Message msg;
  const _MessageBubble({required this.msg});

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 16),
      child: Column(
        crossAxisAlignment: msg.isMine
            ? CrossAxisAlignment.end
            : CrossAxisAlignment.start,
        children: [
          // Auteur + role + date
          Row(
            mainAxisAlignment: msg.isMine
                ? MainAxisAlignment.end
                : MainAxisAlignment.start,
            children: [
              Text(
                msg.auteur,
                style: const TextStyle(
                  fontWeight: FontWeight.w600,
                  fontSize: 12,
                  color: kTextMain,
                ),
              ),
              const SizedBox(width: 6),
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                decoration: BoxDecoration(
                  color: const Color(0xFFF3F4F6),
                  borderRadius: BorderRadius.circular(4),
                ),
                child: Text(
                  msg.role,
                  style: const TextStyle(
                    color: kTextSub,
                    fontSize: 9,
                    fontWeight: FontWeight.w700,
                    letterSpacing: 0.5,
                  ),
                ),
              ),
              const SizedBox(width: 6),
              Text(
                msg.date,
                style: const TextStyle(color: kTextSub, fontSize: 11),
              ),
            ],
          ),
          const SizedBox(height: 6),
          // Bulle
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
            decoration: BoxDecoration(
              color: msg.isMine ? kAccent : const Color(0xFFF3F4F6),
              borderRadius: BorderRadius.only(
                topLeft: const Radius.circular(12),
                topRight: const Radius.circular(12),
                bottomLeft: Radius.circular(msg.isMine ? 12 : 0),
                bottomRight: Radius.circular(msg.isMine ? 0 : 12),
              ),
            ),
            child: Text(
              msg.texte,
              style: TextStyle(
                color: msg.isMine ? Colors.white : kTextMain,
                fontSize: 13,
              ),
            ),
          ),
        ],
      ),
    );
  }
}

// ── Info panel ────────────────────────────────────────────────────────────────
class _InfoPanel extends StatelessWidget {
  const _InfoPanel();

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(18),
      decoration: BoxDecoration(
        color: kCardBg,
        borderRadius: BorderRadius.circular(12),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withOpacity(0.04),
            blurRadius: 6,
            offset: const Offset(0, 2),
          ),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Text(
            'À propos de l\'espace client',
            style: TextStyle(
              fontWeight: FontWeight.w700,
              fontSize: 14,
              color: kTextMain,
            ),
          ),
          const SizedBox(height: 10),
          const Text(
            "Cet espace permet aux architectes et au client d'échanger sur l'avancement du projet.",
            style: TextStyle(color: kTextSub, fontSize: 12, height: 1.5),
          ),
          const SizedBox(height: 14),
          ...[
            'Les clients peuvent suivre l\'avancement.',
            'Les finances sont masquées pour les clients.',
            'L\'accès client est révoqué une fois le projet terminé ou annulé.',
          ].map(
            (t) => Padding(
              padding: const EdgeInsets.only(bottom: 8),
              child: Row(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  const Text(
                    '• ',
                    style: TextStyle(color: kTextSub, fontSize: 12),
                  ),
                  Expanded(
                    child: Text(
                      t,
                      style: const TextStyle(
                        color: kTextSub,
                        fontSize: 12,
                        height: 1.4,
                      ),
                    ),
                  ),
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }
}
