part of '../../../main.dart';

class MarketplaceShell extends StatefulWidget {
  const MarketplaceShell({
    super.key,
    this.themeMode = ThemeMode.dark,
    this.onToggleThemeMode,
  });

  final ThemeMode themeMode;
  final VoidCallback? onToggleThemeMode;

  @override
  State<MarketplaceShell> createState() => _MarketplaceShellState();
}

class _MarketplaceShellState extends State<MarketplaceShell>
    with WidgetsBindingObserver {
  int selectedIndex = 0;

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addObserver(this);
    appStore.addListener(_onStoreChanged);
    appStore.loadRemoteCatalog(force: true);
    appStore.loadSellerWorkspace();
  }

  @override
  void dispose() {
    WidgetsBinding.instance.removeObserver(this);
    appStore.removeListener(_onStoreChanged);
    super.dispose();
  }

  void _onStoreChanged() {
    if (mounted) setState(() {});
  }

  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    if (state == AppLifecycleState.resumed) {
      appStore.loadRemoteCatalog(force: true);
      if (appStore.isSignedIn) {
        appStore.loadSellerWorkspace();
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    final notificationCount = appStore.notificationCount;
    final pages = [
      const HomeScreen(),
      const VoucherCenterScreen(),
      const ShopDirectoryScreen(),
      VideoFeedScreen(isVisible: selectedIndex == 3),
      const NotificationsScreen(),
      const MeScreen(),
    ];
    return PremiumScaffold(
      safeArea: false,
      extendBody: true,
      bottomNavigationBar: SafeArea(
        top: false,
        child: Padding(
          padding: const EdgeInsets.fromLTRB(10, 0, 10, 8),
          child: ClipRRect(
            borderRadius: BorderRadius.circular(18),
            child: NavigationBar(
              selectedIndex: selectedIndex,
              labelBehavior: NavigationDestinationLabelBehavior.alwaysShow,
              onDestinationSelected: (index) async {
                if (index == 4 && !await requireCustomerLogin(context)) {
                  return;
                }
                setState(() => selectedIndex = index);
              },
              destinations: [
                const NavigationDestination(
                  icon: Icon(Icons.home_outlined),
                  selectedIcon: Icon(Icons.home),
                  label: 'หน้าแรก',
                ),
                const NavigationDestination(
                  icon: Icon(Icons.confirmation_number_outlined),
                  selectedIcon: Icon(Icons.confirmation_number),
                  label: 'สิทธิพิเศษ',
                ),
                const NavigationDestination(
                  icon: Icon(Icons.store_mall_directory_outlined),
                  selectedIcon: Icon(Icons.store_mall_directory),
                  label: 'แบรนด์',
                ),
                const NavigationDestination(
                  icon: Icon(Icons.play_circle_outline),
                  selectedIcon: Icon(Icons.play_circle),
                  label: 'Video',
                ),
                NavigationDestination(
                  icon: NotificationNavIcon(count: notificationCount),
                  selectedIcon: NotificationNavIcon(
                    count: notificationCount,
                    selected: true,
                  ),
                  label: 'แจ้งเตือน',
                ),
                const NavigationDestination(
                  icon: Icon(Icons.person_outline),
                  selectedIcon: Icon(Icons.person),
                  label: 'ฉัน',
                ),
              ],
            ),
          ),
        ),
      ),
      child: Stack(
        children: [
          AnimatedSwitcher(
            duration: const Duration(milliseconds: 280),
            switchInCurve: Curves.easeOutCubic,
            switchOutCurve: Curves.easeInCubic,
            transitionBuilder: (child, animation) {
              return FadeTransition(
                opacity: animation,
                child: SlideTransition(
                  position: Tween<Offset>(
                    begin: const Offset(0.025, 0.015),
                    end: Offset.zero,
                  ).animate(animation),
                  child: child,
                ),
              );
            },
            child: KeyedSubtree(
              key: ValueKey(selectedIndex),
              child: pages[selectedIndex],
            ),
          ),
          Positioned(
            top: 42,
            right: 12,
            child: _ThemeModeToggleButton(
              themeMode: widget.themeMode,
              onTap: widget.onToggleThemeMode,
            ),
          ),
        ],
      ),
    );
  }
}

class _ThemeModeToggleButton extends StatelessWidget {
  const _ThemeModeToggleButton({
    required this.themeMode,
    required this.onTap,
  });

  final ThemeMode themeMode;
  final VoidCallback? onTap;

  @override
  Widget build(BuildContext context) {
    final isDark = themeMode == ThemeMode.dark;
    return Material(
      color: Colors.transparent,
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(999),
        child: Container(
          width: 38,
          height: 38,
          decoration: BoxDecoration(
            color: isDark
                ? const Color(0xFF211D16).withValues(alpha: .94)
                : Colors.white.withValues(alpha: .94),
            borderRadius: BorderRadius.circular(999),
            border: Border.all(
              color: isDark
                  ? accentDark.withValues(alpha: .55)
                  : accentDark.withValues(alpha: .28),
            ),
            boxShadow: [
              BoxShadow(
                color: Colors.black.withValues(alpha: isDark ? .30 : .10),
                blurRadius: 14,
                offset: const Offset(0, 6),
              ),
            ],
          ),
          child: Icon(
            isDark ? Icons.light_mode_outlined : Icons.dark_mode_outlined,
            color: isDark ? accent : accentDark,
            size: 20,
          ),
        ),
      ),
    );
  }
}

class NotificationNavIcon extends StatelessWidget {
  const NotificationNavIcon({
    super.key,
    required this.count,
    this.selected = false,
  });

  final int count;
  final bool selected;

  @override
  Widget build(BuildContext context) {
    return Badge.count(
      isLabelVisible: count > 0,
      count: count > 99 ? 99 : count,
      backgroundColor: accent,
      child: Icon(selected ? Icons.notifications : Icons.notifications_none),
    );
  }
}
