import 'package:flutter/material.dart';
import 'theme.dart';

class Shell extends StatefulWidget {
  const Shell({super.key});

  @override
  State<Shell> createState() => _ShellState();
}

class _ShellState extends State<Shell> {
  final GlobalKey<ScaffoldState> _key = GlobalKey<ScaffoldState>();
  int _tab = 0;

  static const _titles = ['Akış', 'Liderler', 'Tahmin Yap', 'Sonuçlar', 'Profilim'];

  void _toast(String t) {
    ScaffoldMessenger.of(context)
      ..hideCurrentSnackBar()
      ..showSnackBar(SnackBar(content: Text(t)));
  }

  @override
  Widget build(BuildContext context) {
    final c = AppColors.of(context);
    final bottom = MediaQuery.of(context).padding.bottom;
    return Scaffold(
      key: _key,
      drawer: const AppDrawer(),
      body: Stack(
        children: [
          SafeArea(
            bottom: false,
            child: Column(
              children: [
                TopBar(onMenu: () => _key.currentState?.openDrawer()),
                Expanded(
                  child: Padding(
                    padding: EdgeInsets.only(bottom: 70 + bottom),
                    child: PlaceholderPage(title: _titles[_tab]),
                  ),
                ),
              ],
            ),
          ),
          Positioned(
            left: 0,
            right: 0,
            bottom: 0,
            child: Center(
              child: ConstrainedBox(
                constraints: const BoxConstraints(maxWidth: 500),
                child: Container(
                  padding: EdgeInsets.fromLTRB(10, 8, 10, 8 + bottom),
                  decoration: BoxDecoration(
                    color: c.sf,
                    border: Border(top: BorderSide(color: c.ln)),
                    boxShadow: const [
                      BoxShadow(color: Color(0x14000000), blurRadius: 10, offset: Offset(0, -2)),
                    ],
                  ),
                  child: Row(
                    children: [
                      _NavItem(icon: Icons.home_outlined, label: 'Akış', on: _tab == 0, onTap: () => setState(() => _tab = 0)),
                      _NavItem(icon: Icons.emoji_events_outlined, label: 'Liderler', on: _tab == 1, onTap: () => setState(() => _tab = 1)),
                      _NavItem(icon: Icons.format_list_bulleted, label: 'Tahmin Yap', on: _tab == 2, onTap: () => setState(() => _tab = 2)),
                      const SizedBox(width: 56),
                      _NavItem(icon: Icons.flag_outlined, label: 'Sonuçlar', on: _tab == 3, onTap: () => setState(() => _tab = 3)),
                      _NavItem(icon: Icons.person_outline, label: 'Profilim', on: _tab == 4, onTap: () => setState(() => _tab = 4)),
                      _NavItem(icon: Icons.power_settings_new, label: 'Çıkış', on: false, danger: true, onTap: () => _toast('Çıkış sonraki aşamada')),
                    ],
                  ),
                ),
              ),
            ),
          ),
          Positioned(
            left: 0,
            right: 0,
            bottom: bottom + 18,
            child: Center(
              child: GestureDetector(
                onTap: () => _toast('Sohbet sonraki aşamada'),
                child: Container(
                  width: 76,
                  height: 76,
                  padding: const EdgeInsets.all(6),
                  decoration: BoxDecoration(
                    shape: BoxShape.circle,
                    color: c.sf,
                    boxShadow: const [
                      BoxShadow(color: Color(0x26000000), blurRadius: 16, offset: Offset(0, 4)),
                    ],
                  ),
                  child: Container(
                    decoration: const BoxDecoration(
                      shape: BoxShape.circle,
                      gradient: LinearGradient(
                        begin: Alignment.topLeft,
                        end: Alignment.bottomRight,
                        colors: [Color(0xFF34D399), Color(0xFF0E9F73)],
                      ),
                    ),
                    child: const Icon(Icons.chat_bubble_rounded, color: Colors.white, size: 30),
                  ),
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }
}

class TopBar extends StatelessWidget {
  final VoidCallback onMenu;
  const TopBar({super.key, required this.onMenu});

  @override
  Widget build(BuildContext context) {
    final c = AppColors.of(context);
    final isDark = Theme.of(context).brightness == Brightness.dark;
    return Container(
      padding: const EdgeInsets.fromLTRB(16, 10, 16, 10),
      decoration: BoxDecoration(
        color: c.bg,
        border: Border(bottom: BorderSide(color: c.ln.withAlpha(140))),
      ),
      child: Row(
        children: [
          IconBox(icon: Icons.menu, onTap: onMenu),
          const SizedBox(width: 10),
          const Brand(size: 19),
          const SizedBox(width: 10),
          Expanded(
            child: Container(
              height: 40,
              padding: const EdgeInsets.symmetric(horizontal: 10),
              decoration: BoxDecoration(
                color: c.sf,
                borderRadius: BorderRadius.circular(14),
                border: Border.all(color: c.ln),
              ),
              child: Row(
                children: [
                  Icon(Icons.search, size: 18, color: c.ac),
                  const SizedBox(width: 6),
                  Expanded(
                    child: Text('Kullanıcı ara',
                        maxLines: 1,
                        overflow: TextOverflow.clip,
                        style: jakarta(13, FontWeight.w600, c.mu)),
                  ),
                ],
              ),
            ),
          ),
          const SizedBox(width: 8),
          IconBox(
            icon: isDark ? Icons.wb_sunny_outlined : Icons.dark_mode_outlined,
            onTap: () => themeMode.value = isDark ? ThemeMode.light : ThemeMode.dark,
          ),
          const SizedBox(width: 8),
          IconBox(icon: Icons.notifications_none, onTap: () {}),
        ],
      ),
    );
  }
}

class IconBox extends StatelessWidget {
  final IconData icon;
  final VoidCallback onTap;
  final double size;
  const IconBox({super.key, required this.icon, required this.onTap, this.size = 40});

  @override
  Widget build(BuildContext context) {
    final c = AppColors.of(context);
    return GestureDetector(
      onTap: onTap,
      child: Container(
        width: size,
        height: size,
        decoration: BoxDecoration(
          color: c.sf,
          borderRadius: BorderRadius.circular(14),
          border: Border.all(color: c.ln),
          boxShadow: const [BoxShadow(color: Color(0x14000000), blurRadius: 6, offset: Offset(0, 2))],
        ),
        child: Icon(icon, size: 20, color: c.tx),
      ),
    );
  }
}

class _NavItem extends StatelessWidget {
  final IconData icon;
  final String label;
  final bool on;
  final bool danger;
  final VoidCallback onTap;
  const _NavItem({
    required this.icon,
    required this.label,
    required this.on,
    required this.onTap,
    this.danger = false,
  });

  @override
  Widget build(BuildContext context) {
    final c = AppColors.of(context);
    final fg = danger ? c.red : (on ? c.ac : c.mu);
    return Expanded(
      child: GestureDetector(
        behavior: HitTestBehavior.opaque,
        onTap: onTap,
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            AnimatedContainer(
              duration: const Duration(milliseconds: 200),
              width: 46,
              height: 30,
              decoration: BoxDecoration(
                borderRadius: BorderRadius.circular(12),
                gradient: on
                    ? const LinearGradient(colors: [Color(0xFF34D399), Color(0xFF0E9F73)])
                    : null,
                boxShadow: on
                    ? const [BoxShadow(color: Color(0x6B0E9F73), blurRadius: 12, offset: Offset(0, 4))]
                    : null,
              ),
              child: Icon(icon, size: 22, color: on ? Colors.white : fg),
            ),
            const SizedBox(height: 3),
            Text(label,
                maxLines: 1,
                softWrap: false,
                overflow: TextOverflow.visible,
                style: jakarta(10.5, FontWeight.w700, fg)),
          ],
        ),
      ),
    );
  }
}

class PlaceholderPage extends StatelessWidget {
  final String title;
  const PlaceholderPage({super.key, required this.title});

  @override
  Widget build(BuildContext context) {
    final c = AppColors.of(context);
    return Center(
      child: Container(
        margin: const EdgeInsets.all(24),
        padding: const EdgeInsets.all(20),
        decoration: BoxDecoration(
          color: c.sf,
          borderRadius: BorderRadius.circular(22),
          border: Border.all(color: c.ln),
        ),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Text(title, style: jakarta(22, FontWeight.w800, c.tx)),
            const SizedBox(height: 6),
            Text('Bu ekran sıradaki aşamada yapılacak.',
                textAlign: TextAlign.center,
                style: jakarta(14, FontWeight.w500, c.mu)),
          ],
        ),
      ),
    );
  }
}

class AppDrawer extends StatelessWidget {
  const AppDrawer({super.key});

  @override
  Widget build(BuildContext context) {
    final c = AppColors.of(context);
    final isDark = Theme.of(context).brightness == Brightness.dark;
    return Drawer(
      width: 300,
      backgroundColor: c.bg,
      child: SafeArea(
        child: Padding(
          padding: const EdgeInsets.all(16),
          child: Column(
            children: [
              Row(
                children: [
                  const Brand(size: 24),
                  const Spacer(),
                  IconBox(icon: Icons.close, onTap: () => Navigator.of(context).pop()),
                ],
              ),
              const SizedBox(height: 18),
              Container(
                padding: const EdgeInsets.all(14),
                decoration: BoxDecoration(
                  borderRadius: BorderRadius.circular(22),
                  gradient: const LinearGradient(colors: [Color(0xFF14B27D), Color(0xFF0E9F73)]),
                ),
                child: Row(
                  children: [
                    Container(
                      width: 48,
                      height: 48,
                      alignment: Alignment.center,
                      decoration: const BoxDecoration(shape: BoxShape.circle, color: Color(0xFFFFD66B)),
                      child: Text('C', style: jakarta(20, FontWeight.w800, const Color(0xFF7A4B00))),
                    ),
                    const SizedBox(width: 12),
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text('Cengiz', style: jakarta(18, FontWeight.w800, Colors.white)),
                          Text('@admin', style: jakarta(14, FontWeight.w600, const Color(0xE0FFFFFF))),
                        ],
                      ),
                    ),
                    const Icon(Icons.chevron_right, color: Colors.white),
                  ],
                ),
              ),
              const SizedBox(height: 14),
              Container(
                decoration: BoxDecoration(
                  color: c.sf,
                  borderRadius: BorderRadius.circular(22),
                  border: Border.all(color: c.ln),
                ),
                child: Column(
                  children: [
                    _DrawerRow(icon: Icons.diamond_outlined, label: 'Mağaza', onTap: () {}),
                    Divider(height: 1, color: c.ln),
                    _DrawerRow(icon: Icons.menu_book_outlined, label: 'Kurallar', onTap: () {}),
                    Divider(height: 1, color: c.ln),
                    _DrawerRow(
                      icon: Icons.wb_sunny_outlined,
                      label: 'Koyu tema',
                      onTap: () => themeMode.value = isDark ? ThemeMode.light : ThemeMode.dark,
                      trailing: Switch(
                        value: isDark,
                        activeColor: c.ac,
                        onChanged: (v) => themeMode.value = v ? ThemeMode.dark : ThemeMode.light,
                      ),
                    ),
                    Divider(height: 1, color: c.ln),
                    _DrawerRow(icon: Icons.lock_outline, label: 'Yönetim paneli', onTap: () {}),
                  ],
                ),
              ),
              const Spacer(),
              Text('Hesabın ve paylaşımların bulutta saklanır.',
                  textAlign: TextAlign.center,
                  style: jakarta(13, FontWeight.w500, c.mu)),
              const SizedBox(height: 10),
              Divider(height: 1, color: c.ln),
              const SizedBox(height: 10),
              Row(
                children: [
                  Container(
                    width: 42,
                    height: 42,
                    decoration: BoxDecoration(
                      color: c.red.withAlpha(30),
                      borderRadius: BorderRadius.circular(12),
                    ),
                    child: Icon(Icons.logout, color: c.red, size: 20),
                  ),
                  const SizedBox(width: 12),
                  Text('Oturumu kapat', style: jakarta(16, FontWeight.w700, c.red)),
                ],
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class _DrawerRow extends StatelessWidget {
  final IconData icon;
  final String label;
  final VoidCallback onTap;
  final Widget? trailing;
  const _DrawerRow({required this.icon, required this.label, required this.onTap, this.trailing});

  @override
  Widget build(BuildContext context) {
    final c = AppColors.of(context);
    return InkWell(
      onTap: onTap,
      borderRadius: BorderRadius.circular(22),
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
        child: Row(
          children: [
            Container(
              width: 42,
              height: 42,
              decoration: BoxDecoration(color: c.sf2, borderRadius: BorderRadius.circular(12)),
              child: Icon(icon, size: 20, color: c.mu),
            ),
            const SizedBox(width: 14),
            Expanded(child: Text(label, style: jakarta(16, FontWeight.w700, c.tx))),
            if (trailing != null) trailing!,
          ],
        ),
      ),
    );
  }
}
