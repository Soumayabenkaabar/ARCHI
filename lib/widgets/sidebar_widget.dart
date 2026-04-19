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
      duration: const Duration(milliseconds: 220),
    );
    _widthAnim = Tween<double>(begin: 240, end: 64).animate(
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
        color: const Color(0xFF1F2937),
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
          const SizedBox(height: 20),
          IconButton(
            onPressed: onExpand,
            icon: const Icon(Icons.menu_rounded, color: Colors.white),
          ),
          const SizedBox(height: 10),
          Container(
            height: 1,
            margin: const EdgeInsets.symmetric(horizontal: 10),
            color: Colors.white10,
          ),
          const SizedBox(height: 10),
          ...List.generate(navItems.length, (i) {
            final item = navItems[i];
            final isActive = i == selectedIndex;
            final badge = i == kNotifNavIndex && notifCount > 0
                ? notifCount
                : null;
            return GestureDetector(
              onTap: () => onSelect(i),
              child: Container(
                width: 44,
                height: 44,
                margin: const EdgeInsets.only(bottom: 8),
                decoration: BoxDecoration(
                  color: isActive ? kAccent : Colors.transparent,
                  borderRadius: BorderRadius.circular(12),
                ),
                child: Stack(
                  children: [
                    Center(
                      child: Icon(
                        item.lucideIcon,
                        color: isActive ? Colors.black : Colors.white70,
                        size: 20,
                      ),
                    ),
                    if (badge != null)
                      Positioned(
                        top: 6,
                        right: 6,
                        child: Container(
                          width: 14,
                          height: 14,
                          decoration: const BoxDecoration(
                            color: Colors.red,
                            shape: BoxShape.circle,
                          ),
                          child: Center(
                            child: Text(
                              '$badge',
                              style: const TextStyle(
                                color: Colors.white,
                                fontSize: 8,
                              ),
                            ),
                          ),
                        ),
                      ),
                  ],
                ),
              ),
            );
          }),
          const Spacer(),
        ],
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
      child: Padding(
        padding: const EdgeInsets.fromLTRB(16, 30, 16, 16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // ── HEADER ────────────────────────────────────────────────
            Row(
              children: [
                const Icon(LucideIcons.building2, color: Colors.amber),
                const SizedBox(width: 8),
                const Expanded(
                  child: Text(
                    'ArchiManager',
                    style: TextStyle(color: Colors.white, fontSize: 16),
                  ),
                ),
                if (onCollapse != null)
                  GestureDetector(
                    onTap: onCollapse,
                    child: const Icon(
                      LucideIcons.menu,
                      color: Colors.white54,
                      size: 20,
                    ),
                  ),
              ],
            ),
            const SizedBox(height: 30),

            // ── MENU ──────────────────────────────────────────────────
            ...List.generate(navItems.length, (i) {
              final item = navItems[i];
              final badge = i == kNotifNavIndex && notifCount > 0
                  ? notifCount
                  : null;
              return _MenuItem(
                icon: item.lucideIcon,
                title: item.label,
                isActive: i == selectedIndex,
                badge: badge,
                onTap: () => onSelect(i),
              );
            }),

            const Spacer(),

            // ── PIED : nom architecte + logout (une seule fois) ───────
            const Divider(color: Colors.white12),
            const SizedBox(height: 8),
            Row(
              children: [
                Container(
                  width: 32,
                  height: 32,
                  decoration: BoxDecoration(
                    color: kAccent.withOpacity(0.2),
                    borderRadius: BorderRadius.circular(8),
                  ),
                  child: Center(
                    child: Text(
                      architecteNom.isNotEmpty
                          ? architecteNom[0].toUpperCase()
                          : 'A',
                      style: const TextStyle(
                        color: Colors.white,
                        fontWeight: FontWeight.w600,
                      ),
                    ),
                  ),
                ),
                const SizedBox(width: 10),
                Expanded(
                  child: Text(
                    architecteNom,
                    style: const TextStyle(color: Colors.white, fontSize: 13),
                    overflow: TextOverflow.ellipsis,
                  ),
                ),
                IconButton(
                  icon: const Icon(
                    LucideIcons.logOut,
                    color: Colors.white54,
                    size: 18,
                  ),
                  tooltip: 'Se déconnecter',
                  onPressed: onLogout,
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }
}

// ─── Menu Item ────────────────────────────────────────────────────────────────
class _MenuItem extends StatelessWidget {
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
  Widget build(BuildContext context) {
    return InkWell(
      onTap: onTap,
      borderRadius: BorderRadius.circular(10),
      child: Container(
        margin: const EdgeInsets.only(bottom: 10),
        padding: const EdgeInsets.all(10),
        decoration: BoxDecoration(
          color: isActive ? Colors.amber : Colors.transparent,
          borderRadius: BorderRadius.circular(10),
        ),
        child: Row(
          children: [
            Icon(icon, color: isActive ? Colors.black : Colors.white, size: 18),
            const SizedBox(width: 10),
            Expanded(
              child: Text(
                title,
                style: TextStyle(color: isActive ? Colors.black : Colors.white),
              ),
            ),
            if (badge != null)
              Container(
                padding: const EdgeInsets.all(5),
                decoration: const BoxDecoration(
                  color: Colors.red,
                  shape: BoxShape.circle,
                ),
                child: Text(
                  '$badge',
                  style: const TextStyle(color: Colors.white, fontSize: 10),
                ),
              ),
          ],
        ),
      ),
    );
  }
}
