import 'package:flutter/material.dart';
import 'package:lucide_icons/lucide_icons.dart';
import '../constants/colors.dart';
import '../models/nav_item.dart';

// ─── Sidebar Web (collapsible) ────────────────────────────────────────────────
class SidebarWidget extends StatefulWidget {
  final int selectedIndex;
  final ValueChanged<int> onSelect;
  final int notifCount;
  final String architecteNom;
  final VoidCallback onLogout;

  const SidebarWidget({
    super.key,
    required this.selectedIndex,
    required this.onSelect,
    this.notifCount = 0,
    required this.architecteNom,
    required this.onLogout,
  });

  @override
  State<SidebarWidget> createState() => _SidebarWidgetState();
}

class _SidebarWidgetState extends State<SidebarWidget>
    with SingleTickerProviderStateMixin {
  bool _collapsed = false;
  late final AnimationController _animController;
  late final Animation<double> _widthAnim;

  @override
  void initState() {
    super.initState();
    _animController = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 250),
    );
    _widthAnim = Tween<double>(begin: 248, end: 68).animate(
      CurvedAnimation(parent: _animController, curve: Curves.easeInOut),
    );
  }

  @override
  void dispose() {
    _animController.dispose();
    super.dispose();
  }

  void _toggle() {
    setState(() => _collapsed = !_collapsed);
    _collapsed ? _animController.forward() : _animController.reverse();
  }

  @override
  Widget build(BuildContext context) {
    return AnimatedBuilder(
      animation: _widthAnim,
      builder: (context, _) => Container(
        width: _widthAnim.value,
        decoration: BoxDecoration(
          color: kSidebar,
          boxShadow: [
            BoxShadow(
              color: Colors.black.withOpacity(0.25),
              blurRadius: 12,
              offset: const Offset(2, 0),
            ),
          ],
        ),
        child: _collapsed
            ? _CollapsedRail(
                selectedIndex: widget.selectedIndex,
                onSelect: widget.onSelect,
                onExpand: _toggle,
                notifCount: widget.notifCount,
              )
            : SidebarContent(
                selectedIndex: widget.selectedIndex,
                onSelect: widget.onSelect,
                onCollapse: _toggle,
                notifCount: widget.notifCount,
                architecteNom: widget.architecteNom,
                onLogout: widget.onLogout,
              ),
      ),
    );
  }
}

// ─── Collapsed Rail ───────────────────────────────────────────────────────────
class _CollapsedRail extends StatelessWidget {
  final int selectedIndex;
  final ValueChanged<int> onSelect;
  final VoidCallback onExpand;
  final int notifCount;

  const _CollapsedRail({
    required this.selectedIndex,
    required this.onSelect,
    required this.onExpand,
    required this.notifCount,
  });

  @override
  Widget build(BuildContext context) {
    return SafeArea(
      child: Column(
        children: [
          const SizedBox(height: 12),
          // Logo visible en mode réduit — clic pour développer
          Tooltip(
            message: 'Développer le menu',
            preferBelow: false,
            child: GestureDetector(
              onTap: onExpand,
              child: Container(
                width: 44,
                height: 44,
                decoration: BoxDecoration(
                  gradient: const LinearGradient(
                    colors: [Color(0xFFFFC94D), Color(0xFFF5A623)],
                    begin: Alignment.topLeft,
                    end: Alignment.bottomRight,
                  ),
                  borderRadius: BorderRadius.circular(13),
                  boxShadow: [
                    BoxShadow(
                      color: kAccent.withOpacity(0.40),
                      blurRadius: 12,
                      offset: const Offset(0, 3),
                    ),
                  ],
                ),
                child: const Icon(
                  LucideIcons.building2,
                  color: Colors.black87,
                  size: 22,
                ),
              ),
            ),
          ),
          const SizedBox(height: 12),
          Container(
            height: 1,
            margin: const EdgeInsets.symmetric(horizontal: 12),
            color: Colors.white10,
          ),
          const SizedBox(height: 8),
          Expanded(
            child: ListView.builder(
              padding: EdgeInsets.zero,
              itemCount: navItems.length,
              itemBuilder: (context, i) {
                final item = navItems[i];
                final isActive = i == selectedIndex;
                final badge = i == kNotifNavIndex && notifCount > 0 ? notifCount : null;
                return _CollapsedItem(
                  item: item,
                  isActive: isActive,
                  badge: badge,
                  onTap: () => onSelect(i),
                );
              },
            ),
          ),
        ],
      ),
    );
  }
}

class _CollapsedItem extends StatefulWidget {
  final NavItem item;
  final bool isActive;
  final int? badge;
  final VoidCallback onTap;

  const _CollapsedItem({
    required this.item,
    required this.isActive,
    required this.badge,
    required this.onTap,
  });

  @override
  State<_CollapsedItem> createState() => _CollapsedItemState();
}

class _CollapsedItemState extends State<_CollapsedItem> {
  bool _hovered = false;

  @override
  Widget build(BuildContext context) {
    return Tooltip(
      message: widget.item.label,
      preferBelow: false,
      waitDuration: const Duration(milliseconds: 300),
      child: MouseRegion(
        onEnter: (_) => setState(() => _hovered = true),
        onExit: (_) => setState(() => _hovered = false),
        child: GestureDetector(
          onTap: widget.onTap,
          child: Container(
            width: 44,
            height: 44,
            margin: const EdgeInsets.only(bottom: 4, left: 12, right: 12),
            decoration: BoxDecoration(
              color: widget.isActive
                  ? kAccent
                  : _hovered
                      ? Colors.white.withOpacity(0.08)
                      : Colors.transparent,
              borderRadius: BorderRadius.circular(10),
            ),
            child: Stack(
              children: [
                Center(
                  child: Icon(
                    widget.item.lucideIcon,
                    color: widget.isActive ? Colors.black87 : Colors.white60,
                    size: 20,
                  ),
                ),
                if (widget.badge != null)
                  Positioned(
                    top: 7,
                    right: 7,
                    child: Container(
                      width: 14,
                      height: 14,
                      decoration: const BoxDecoration(
                        color: kRed,
                        shape: BoxShape.circle,
                      ),
                      child: Center(
                        child: Text(
                          '${widget.badge}',
                          style: const TextStyle(
                            color: Colors.white,
                            fontSize: 8,
                            fontWeight: FontWeight.bold,
                          ),
                        ),
                      ),
                    ),
                  ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}

// ─── Expanded Sidebar ─────────────────────────────────────────────────────────
class SidebarContent extends StatelessWidget {
  final int selectedIndex;
  final ValueChanged<int> onSelect;
  final VoidCallback? onCollapse;
  final int notifCount;
  final String architecteNom;
  final VoidCallback onLogout;

  const SidebarContent({
    super.key,
    required this.selectedIndex,
    required this.onSelect,
    this.onCollapse,
    this.notifCount = 0,
    required this.architecteNom,
    required this.onLogout,
  });

  @override
  Widget build(BuildContext context) {
    return SafeArea(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // ── HEADER ──────────────────────────────────────────────────
          Padding(
            padding: const EdgeInsets.fromLTRB(16, 20, 12, 0),
            child: Row(
              children: [
                // Logo badge avec gradient + glow
                Container(
                  width: 44,
                  height: 44,
                  decoration: BoxDecoration(
                    gradient: const LinearGradient(
                      colors: [Color(0xFFFFC94D), Color(0xFFF5A623)],
                      begin: Alignment.topLeft,
                      end: Alignment.bottomRight,
                    ),
                    borderRadius: BorderRadius.circular(13),
                    boxShadow: [
                      BoxShadow(
                        color: kAccent.withOpacity(0.45),
                        blurRadius: 14,
                        offset: const Offset(0, 4),
                      ),
                    ],
                  ),
                  child: const Icon(
                    LucideIcons.building2,
                    color: Colors.black87,
                    size: 24,
                  ),
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: const [
                      Text(
                        'ArchiManager',
                        style: TextStyle(
                          color: Colors.white,
                          fontSize: 15,
                          fontWeight: FontWeight.w700,
                          letterSpacing: 0.2,
                          height: 1.1,
                        ),
                      ),
                      Text(
                        'Gestion de projets',
                        style: TextStyle(
                          color: Colors.white30,
                          fontSize: 10.5,
                          letterSpacing: 0.1,
                        ),
                      ),
                    ],
                  ),
                ),
                if (onCollapse != null)
                  Tooltip(
                    message: 'Réduire',
                    child: Material(
                      color: Colors.transparent,
                      borderRadius: BorderRadius.circular(8),
                      child: InkWell(
                        onTap: onCollapse,
                        borderRadius: BorderRadius.circular(8),
                        hoverColor: Colors.white10,
                        child: const Padding(
                          padding: EdgeInsets.all(8),
                          child: Icon(
                            LucideIcons.chevronsLeft,
                            color: Colors.white30,
                            size: 18,
                          ),
                        ),
                      ),
                    ),
                  ),
              ],
            ),
          ),
          const SizedBox(height: 8),
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 16),
            child: Container(
              height: 1,
              color: Colors.white10,
            ),
          ),
          const SizedBox(height: 8),

          // ── MENU ────────────────────────────────────────────────────
          Expanded(
            child: ListView.builder(
              padding: const EdgeInsets.symmetric(horizontal: 10),
              itemCount: navItems.length,
              itemBuilder: (context, i) {
                final item = navItems[i];
                final badge = i == kNotifNavIndex && notifCount > 0 ? notifCount : null;
                return _MenuItem(
                  icon: item.lucideIcon,
                  title: item.label,
                  isActive: i == selectedIndex,
                  badge: badge,
                  onTap: () => onSelect(i),
                );
              },
            ),
          ),

          // ── PIED : nom architecte + logout ───────────────────────────
          Padding(
            padding: const EdgeInsets.fromLTRB(10, 0, 10, 12),
            child: Column(
              children: [
                Container(
                  height: 1,
                  color: Colors.white10,
                ),
                const SizedBox(height: 12),
                _UserFooter(
                  architecteNom: architecteNom,
                  onLogout: onLogout,
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

// ─── User Footer ──────────────────────────────────────────────────────────────
class _UserFooter extends StatefulWidget {
  final String architecteNom;
  final VoidCallback onLogout;

  const _UserFooter({required this.architecteNom, required this.onLogout});

  @override
  State<_UserFooter> createState() => _UserFooterState();
}

class _UserFooterState extends State<_UserFooter> {
  bool _hovered = false;

  @override
  Widget build(BuildContext context) {
    final initials = widget.architecteNom.trim().split(' ').take(2).map((w) {
      return w.isNotEmpty ? w[0].toUpperCase() : '';
    }).join();

    return MouseRegion(
      onEnter: (_) => setState(() => _hovered = true),
      onExit: (_) => setState(() => _hovered = false),
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 150),
        padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 8),
        decoration: BoxDecoration(
          color: _hovered ? Colors.white.withOpacity(0.06) : Colors.transparent,
          borderRadius: BorderRadius.circular(10),
        ),
        child: Row(
          children: [
            Container(
              width: 34,
              height: 34,
              decoration: BoxDecoration(
                gradient: LinearGradient(
                  colors: [kAccent, kAccent.withOpacity(0.6)],
                  begin: Alignment.topLeft,
                  end: Alignment.bottomRight,
                ),
                borderRadius: BorderRadius.circular(9),
              ),
              child: Center(
                child: Text(
                  initials.isNotEmpty ? initials : 'A',
                  style: const TextStyle(
                    color: Colors.black87,
                    fontWeight: FontWeight.w700,
                    fontSize: 13,
                  ),
                ),
              ),
            ),
            const SizedBox(width: 10),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    widget.architecteNom,
                    style: const TextStyle(
                      color: Colors.white,
                      fontSize: 13,
                      fontWeight: FontWeight.w500,
                    ),
                    overflow: TextOverflow.ellipsis,
                  ),
                  const Text(
                    'Architecte',
                    style: TextStyle(color: Colors.white38, fontSize: 11),
                  ),
                ],
              ),
            ),
            Tooltip(
              message: 'Se déconnecter',
              child: Material(
                color: Colors.transparent,
                borderRadius: BorderRadius.circular(8),
                child: InkWell(
                  onTap: widget.onLogout,
                  borderRadius: BorderRadius.circular(8),
                  hoverColor: Colors.red.withOpacity(0.15),
                  child: const Padding(
                    padding: EdgeInsets.all(6),
                    child: Icon(
                      LucideIcons.logOut,
                      color: Colors.white38,
                      size: 17,
                    ),
                  ),
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}

// ─── Menu Item ────────────────────────────────────────────────────────────────
class _MenuItem extends StatefulWidget {
  final IconData icon;
  final String title;
  final bool isActive;
  final int? badge;
  final VoidCallback onTap;

  const _MenuItem({
    required this.icon,
    required this.title,
    required this.isActive,
    required this.onTap,
    this.badge,
  });

  @override
  State<_MenuItem> createState() => _MenuItemState();
}

class _MenuItemState extends State<_MenuItem> {
  bool _hovered = false;

  @override
  Widget build(BuildContext context) {
    return MouseRegion(
      onEnter: (_) => setState(() => _hovered = true),
      onExit: (_) => setState(() => _hovered = false),
      child: GestureDetector(
        onTap: widget.onTap,
        child: AnimatedContainer(
          duration: const Duration(milliseconds: 150),
          margin: const EdgeInsets.only(bottom: 2),
          padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 9),
          decoration: BoxDecoration(
            color: widget.isActive
                ? kAccent.withOpacity(0.15)
                : _hovered
                    ? Colors.white.withOpacity(0.06)
                    : Colors.transparent,
            borderRadius: BorderRadius.circular(10),
            border: widget.isActive
                ? Border(
                    left: BorderSide(color: kAccent, width: 3),
                  )
                : const Border(
                    left: BorderSide(color: Colors.transparent, width: 3),
                  ),
          ),
          child: Row(
            children: [
              Icon(
                widget.icon,
                color: widget.isActive ? kAccent : Colors.white54,
                size: 25,
              ),
              const SizedBox(width: 10),
              Expanded(
                child: Text(
                  widget.title,
                  style: TextStyle(
                    color: widget.isActive ? Colors.white : Colors.white70,
                    fontSize: 13.5,
                    fontWeight: widget.isActive ? FontWeight.w600 : FontWeight.normal,
                  ),
                ),
              ),
              if (widget.badge != null)
                Container(
                  padding: const EdgeInsets.symmetric(horizontal: 7, vertical: 2),
                  decoration: BoxDecoration(
                    color: kRed,
                    borderRadius: BorderRadius.circular(10),
                  ),
                  child: Text(
                    '${widget.badge}',
                    style: const TextStyle(
                      color: Colors.white,
                      fontSize: 10,
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                ),
            ],
          ),
        ),
      ),
    );
  }
}
