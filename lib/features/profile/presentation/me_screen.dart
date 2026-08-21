part of '../../../main.dart';

class MeScreen extends StatefulWidget {
  const MeScreen({super.key});

  @override
  State<MeScreen> createState() => _MeScreenState();
}

class _MeScreenState extends State<MeScreen> {
  bool _showLoginPrompt = true;

  @override
  void initState() {
    super.initState();
    appStore.addListener(_refresh);
  }

  @override
  void dispose() {
    appStore.removeListener(_refresh);
    super.dispose();
  }

  void _refresh() => setState(() {});

  @override
  Widget build(BuildContext context) {
    final orderCount = appStore.orders.length;
    final suggested = marketplaceProducts.take(4).toList();
    final isSignedIn = appStore.isAuthenticated;

    return PremiumScaffold(
      child: ListView(
        padding: const EdgeInsets.fromLTRB(0, 0, 0, 104),
        children: [
          const MeProfileHeader(),
          if (!isSignedIn && _showLoginPrompt) ...[
            const SizedBox(height: 10),
            LoginSecurityCard(
              onClose: () => setState(() => _showLoginPrompt = false),
            ),
          ],
          const SizedBox(height: 10),
          MeOrderPanel(orderCount: orderCount),
          const SizedBox(height: 10),
          const MeShortcutPanel(
            title: 'กระเป๋าเงินของฉัน',
            items: [
              MeMenuItem(
                  icon: Icons.payments_outlined,
                  label: 'เก็บเงินปลายทาง',
                  route: '/payment-methods'),
              MeMenuItem(
                  icon: Icons.qr_code_2_outlined,
                  label: 'QR พร้อมเพย์',
                  route: '/payment-methods'),
              MeMenuItem(
                  icon: Icons.payments_outlined,
                  label: 'วิธีชำระเงิน',
                  route: '/payment-methods'),
            ],
          ),
          const SizedBox(height: 10),
          const MeMenuPanel(
            title: 'สิทธิประโยชน์ & การใช้งาน',
            items: [
              MeMenuItem(
                  icon: Icons.confirmation_number_outlined,
                  label: 'คูปองของฉัน',
                  route: '/me/vouchers'),
              MeMenuItem(
                  icon: Icons.favorite_border,
                  label: 'สิ่งที่ฉันถูกใจ',
                  route: '/me/favorites'),
              MeMenuItem(
                  icon: Icons.history_outlined,
                  label: 'ดูล่าสุด',
                  route: '/me/recent'),
              MeMenuItem(
                  icon: Icons.directions_car_outlined,
                  label: 'รถของฉัน',
                  route: '/me/e-service'),
            ],
          ),
          const SizedBox(height: 10),
          const MeMenuPanel(
            title: 'การตั้งค่า & ความช่วยเหลือ',
            items: [
              MeMenuItem(
                  icon: Icons.person_outline,
                  label: 'ข้อมูลบัญชี',
                  route: '/me/profile'),
              MeMenuItem(
                  icon: Icons.language_outlined,
                  label: 'ภาษา',
                  route: '/me/settings',
                  trailing: 'TH | EN'),
              MeMenuItem(
                  icon: Icons.settings_outlined,
                  label: 'การตั้งค่าแอป',
                  route: '/me/settings'),
              MeMenuItem(
                  icon: Icons.support_agent_outlined,
                  label: 'ติดต่อ NP',
                  route: '/me/chat'),
            ],
          ),
          const SizedBox(height: 14),
          const MeRecommendHeader(),
          const SizedBox(height: 8),
          MeRecommendationGrid(products: suggested),
        ],
      ),
    );
  }
}

class MeProfileHeader extends StatelessWidget {
  const MeProfileHeader({super.key});

  @override
  Widget build(BuildContext context) {
    final account = appStore.customerAccount;
    final isSignedIn = appStore.isAuthenticated;
    final displayName = isSignedIn
        ? (account?.nameOrEmail ?? account?.email ?? '')
        : 'สมัครสมาชิกเพื่อเข้าสู่ระบบ';
    return Container(
      margin: const EdgeInsets.fromLTRB(14, 10, 14, 0),
      padding: const EdgeInsets.fromLTRB(18, 18, 14, 18),
      decoration: BoxDecoration(
        gradient: LinearGradient(
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
          colors: const [
            Color(0xFF27231B),
            Color(0xFF15130F),
            Color(0xFF3D2D17),
          ],
        ),
        border: Border.all(color: accentDark.withValues(alpha: 0.48)),
        borderRadius: BorderRadius.circular(18),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(alpha: 0.36),
            blurRadius: 24,
            offset: const Offset(0, 12),
          ),
        ],
      ),
      child: Row(
        children: [
          Expanded(
            child: InkWell(
              onTap: isSignedIn
                  ? () => Navigator.of(context).pushNamed('/me/profile')
                  : () => requireCustomerLogin(context),
              borderRadius: BorderRadius.circular(12),
              child: Row(
                children: [
                  Container(
                    width: 52,
                    height: 52,
                    clipBehavior: Clip.antiAlias,
                    decoration: BoxDecoration(
                      color: Colors.white,
                      borderRadius: BorderRadius.circular(999),
                      border: Border.all(color: accent, width: 1.2),
                    ),
                    child: account?.avatarUrl.isNotEmpty == true
                        ? Image.network(
                            account!.avatarUrl,
                            fit: BoxFit.cover,
                            errorBuilder: (_, __, ___) => const Icon(
                              Icons.person,
                              color: accent,
                              size: 32,
                            ),
                          )
                        : const Icon(Icons.person, color: accent, size: 32),
                  ),
                  const SizedBox(width: 12),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          displayName,
                          maxLines: 2,
                          overflow: TextOverflow.ellipsis,
                          style: const TextStyle(
                            color: Colors.white,
                            fontSize: 17,
                            fontWeight: FontWeight.w900,
                          ),
                        ),
                      ],
                    ),
                  ),
                ],
              ),
            ),
          ),
          IconButton(
            onPressed: () => Navigator.of(context).pushNamed('/me/settings'),
            icon: const Icon(Icons.settings_outlined, color: Colors.white),
            tooltip: 'ตั้งค่า',
          ),
          IconButton(
            onPressed: () => Navigator.of(context).pushNamed('/cart'),
            icon: const Icon(Icons.shopping_cart_outlined, color: Colors.white),
            tooltip: 'ตะกร้า',
          ),
          IconButton(
            onPressed: () => Navigator.of(context).pushNamed('/me/chat'),
            icon: const Icon(Icons.chat_bubble_outline, color: Colors.white),
            tooltip: 'แชท',
          ),
        ],
      ),
    );
  }
}

class LoginSecurityCard extends StatelessWidget {
  const LoginSecurityCard({super.key, required this.onClose});

  final VoidCallback onClose;

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final primaryText = isDark ? darkInk : ink;
    final secondaryText = isDark ? darkMuted : muted;
    return MeCard(
      padding: const EdgeInsets.fromLTRB(12, 9, 4, 9),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.center,
        children: [
          const Icon(Icons.login_outlined, color: accent, size: 22),
          const SizedBox(width: 10),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              mainAxisSize: MainAxisSize.min,
              children: [
                Text(
                  'สมัครสมาชิกเพื่อเข้าสู่ระบบ',
                  style: TextStyle(
                    color: primaryText,
                    fontWeight: FontWeight.w900,
                    fontSize: 14,
                  ),
                ),
                const SizedBox(height: 2),
                Text(
                  'เข้าสู่ระบบเพื่อซื้อสินค้า เก็บคูปอง และติดตามคำสั่งซื้อ',
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: TextStyle(color: secondaryText, fontSize: 11.5),
                ),
              ],
            ),
          ),
          IconButton(
            onPressed: () => Navigator.of(context).pushNamed('/auth'),
            icon: Icon(Icons.chevron_right, color: secondaryText),
            tooltip: 'เข้าสู่ระบบ',
            constraints: const BoxConstraints.tightFor(width: 34, height: 34),
          ),
          IconButton(
            onPressed: onClose,
            icon: Icon(Icons.close, color: secondaryText),
            tooltip: 'ปิด',
            constraints: const BoxConstraints.tightFor(width: 36, height: 36),
          ),
        ],
      ),
    );
  }
}

class MeCard extends StatelessWidget {
  const MeCard({
    super.key,
    required this.child,
    this.padding = EdgeInsets.zero,
  });

  final Widget child;
  final EdgeInsetsGeometry padding;

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    return Container(
      margin: const EdgeInsets.symmetric(horizontal: 8),
      padding: padding,
      decoration: BoxDecoration(
        color: isDark ? const Color(0xFF262522) : Colors.white,
        border: Border.all(
          color: isDark ? accentDark.withValues(alpha: 0.48) : line,
        ),
        borderRadius: BorderRadius.circular(16),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(alpha: isDark ? 0.38 : 0.04),
            blurRadius: 18,
            offset: const Offset(0, 8),
          ),
        ],
      ),
      child: child,
    );
  }
}

class MeOrderPanel extends StatelessWidget {
  const MeOrderPanel({super.key, required this.orderCount});

  final int orderCount;

  @override
  Widget build(BuildContext context) {
    return MeCard(
      padding: EdgeInsets.zero,
      child: Column(
        children: [
          MeSectionRow(
            title: 'คำสั่งซื้อของฉัน',
            action: 'ดูทั้งหมด',
            onTap: () => Navigator.of(context).pushNamed('/orders'),
          ),
          const Divider(height: 1),
          Padding(
            padding: const EdgeInsets.fromLTRB(8, 13, 8, 13),
            child: Row(
              children: [
                Expanded(
                    child: MeOrderStatus(
                        icon: Icons.account_balance_wallet_outlined,
                        label: 'รอชำระเงิน',
                        count: 0)),
                Expanded(
                    child: MeOrderStatus(
                        icon: Icons.inventory_2_outlined,
                        label: 'เตรียมจัดส่ง',
                        count: orderCount)),
                const Expanded(
                    child: MeOrderStatus(
                        icon: Icons.local_shipping_outlined,
                        label: 'กำลังจัดส่ง',
                        count: 0)),
                const Expanded(
                    child: MeOrderStatus(
                        icon: Icons.star_border, label: 'ให้คะแนน', count: 0)),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

class MeOrderStatus extends StatelessWidget {
  const MeOrderStatus({
    super.key,
    required this.icon,
    required this.label,
    required this.count,
  });

  final IconData icon;
  final String label;
  final int count;

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final labelColor = isDark ? darkInk : ink;
    return Column(
      children: [
        Stack(
          clipBehavior: Clip.none,
          children: [
            Icon(icon, color: isDark ? darkInk : ink, size: 25),
            if (count > 0)
              Positioned(
                right: -8,
                top: -7,
                child: Container(
                  padding:
                      const EdgeInsets.symmetric(horizontal: 5, vertical: 1),
                  decoration: BoxDecoration(
                    color: accent,
                    borderRadius: BorderRadius.circular(999),
                    border: Border.all(color: Colors.white),
                  ),
                  child: Text('$count',
                      style: const TextStyle(color: Colors.white, fontSize: 9)),
                ),
              ),
          ],
        ),
        const SizedBox(height: 5),
        Text(
          label,
          textAlign: TextAlign.center,
          style: TextStyle(
            color: labelColor,
            fontSize: 11,
            fontWeight: FontWeight.w700,
          ),
        ),
      ],
    );
  }
}

class MeMenuPanel extends StatelessWidget {
  const MeMenuPanel({super.key, required this.title, required this.items});

  final String title;
  final List<MeMenuItem> items;

  @override
  Widget build(BuildContext context) {
    return MeCard(
      padding: EdgeInsets.zero,
      child: Column(
        children: [
          MeSectionRow(title: title),
          const Divider(height: 1),
          for (var i = 0; i < items.length; i++) ...[
            MeMenuTile(item: items[i]),
            if (i != items.length - 1) const Divider(height: 1),
          ],
        ],
      ),
    );
  }
}

class MeShortcutPanel extends StatelessWidget {
  const MeShortcutPanel({super.key, required this.title, required this.items});

  final String title;
  final List<MeMenuItem> items;

  @override
  Widget build(BuildContext context) {
    return MeCard(
      padding: EdgeInsets.zero,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          MeSectionRow(title: title),
          const Divider(height: 1),
          Padding(
            padding: const EdgeInsets.fromLTRB(8, 12, 8, 13),
            child: Row(
              children: [
                for (final item in items)
                  Expanded(child: MeShortcutTile(item: item)),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

class MeTwoColumnPanel extends StatelessWidget {
  const MeTwoColumnPanel({
    super.key,
    required this.title,
    required this.items,
    this.action,
  });

  final String title;
  final String? action;
  final List<MeMenuItem> items;

  @override
  Widget build(BuildContext context) {
    return MeCard(
      padding: EdgeInsets.zero,
      child: Column(
        children: [
          MeSectionRow(title: title, action: action),
          const Divider(height: 1),
          Padding(
            padding: const EdgeInsets.all(10),
            child: GridView.builder(
              shrinkWrap: true,
              physics: const NeverScrollableScrollPhysics(),
              itemCount: items.length,
              gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
                crossAxisCount: 2,
                crossAxisSpacing: 8,
                mainAxisSpacing: 8,
                childAspectRatio: 2.35,
              ),
              itemBuilder: (context, index) =>
                  MeServiceTile(item: items[index]),
            ),
          ),
        ],
      ),
    );
  }
}

class MeServiceTile extends StatelessWidget {
  const MeServiceTile({super.key, required this.item});

  final MeMenuItem item;

  @override
  Widget build(BuildContext context) {
    return InkWell(
      onTap: item.route == null
          ? null
          : () => Navigator.of(context).pushNamed(item.route!),
      borderRadius: BorderRadius.circular(6),
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 8),
        decoration: BoxDecoration(
          color: Colors.white,
          borderRadius: BorderRadius.circular(6),
          border: Border.all(color: const Color(0xFFE5E5E5)),
        ),
        child: Row(
          children: [
            Icon(item.icon, color: accent, size: 24),
            const SizedBox(width: 8),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  Text(
                    item.label,
                    maxLines: 2,
                    style: const TextStyle(
                      color: ink,
                      fontSize: 13,
                      fontWeight: FontWeight.w800,
                    ),
                  ),
                  if (item.trailing != null) ...[
                    const SizedBox(height: 2),
                    Text(
                      item.trailing!,
                      maxLines: 2,
                      style: const TextStyle(color: accent, fontSize: 10.5),
                    ),
                  ],
                ],
              ),
            ),
            const Icon(Icons.chevron_right, color: muted, size: 16),
          ],
        ),
      ),
    );
  }
}

class MeShortcutTile extends StatelessWidget {
  const MeShortcutTile({super.key, required this.item});

  final MeMenuItem item;

  void _open(BuildContext context) {
    if (item.route == null) return;
    Navigator.of(context).pushNamed(item.route!);
  }

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    return InkWell(
      onTap: () => _open(context),
      borderRadius: BorderRadius.circular(8),
      child: Padding(
        padding: const EdgeInsets.symmetric(vertical: 4),
        child: Column(
          children: [
            Icon(item.icon, color: isDark ? accent : ink, size: 27),
            const SizedBox(height: 6),
            Text(
              item.label,
              textAlign: TextAlign.center,
              style: TextStyle(
                color: isDark ? darkInk : ink,
                fontSize: 11.5,
                fontWeight: FontWeight.w700,
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class MeMenuItem {
  const MeMenuItem({
    required this.icon,
    required this.label,
    this.route,
    this.trailing,
  });

  final IconData icon;
  final String label;
  final String? route;
  final String? trailing;
}

class MeMenuTile extends StatelessWidget {
  const MeMenuTile({super.key, required this.item});

  final MeMenuItem item;

  void _open(BuildContext context) {
    if (item.route == null) return;
    Navigator.of(context).pushNamed(item.route!);
  }

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final secondaryText = isDark ? darkMuted : muted;
    return InkWell(
      onTap: () => _open(context),
      child: Row(
        children: [
          Expanded(
            child: Padding(
              padding: const EdgeInsets.fromLTRB(14, 13, 12, 13),
              child: Row(
                children: [
                  Icon(item.icon, color: accent, size: 21),
                  const SizedBox(width: 12),
                  Expanded(
                    child: Text(
                      item.label,
                      style: TextStyle(
                        color: isDark ? darkInk : ink,
                        fontSize: 14,
                        fontWeight: FontWeight.w800,
                      ),
                    ),
                  ),
                  if (item.trailing != null)
                    Padding(
                      padding: const EdgeInsets.only(right: 6),
                      child: Text(
                        item.trailing!,
                        style: TextStyle(color: secondaryText, fontSize: 12.5),
                      ),
                    ),
                  Icon(Icons.chevron_right, color: secondaryText, size: 18),
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }
}

class MeHelpPanel extends StatelessWidget {
  const MeHelpPanel({super.key});

  @override
  Widget build(BuildContext context) {
    return const MeMenuPanel(
      title: 'ช่วยเหลือ',
      items: [
        MeMenuItem(
            icon: Icons.help_outline,
            label: 'ศูนย์ช่วยเหลือ',
            route: '/me/help'),
        MeMenuItem(
            icon: Icons.support_agent, label: 'Chat กับเรา', route: '/me/chat'),
      ],
    );
  }
}

class MeRecommendHeader extends StatelessWidget {
  const MeRecommendHeader({super.key});

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final textColor = isDark ? darkInk : ink;
    final dividerColor = isDark ? darkLine : line;
    return Row(
      children: [
        Expanded(child: Divider(color: dividerColor)),
        const Padding(
          padding: EdgeInsets.symmetric(horizontal: 12),
          child: SizedBox.shrink(),
        ),
        Text(
          'คุณอาจจะชอบสิ่งนี้',
          style: TextStyle(color: textColor, fontWeight: FontWeight.w800),
        ),
        const Padding(
          padding: EdgeInsets.symmetric(horizontal: 12),
          child: SizedBox.shrink(),
        ),
        Expanded(child: Divider(color: dividerColor)),
      ],
    );
  }
}

class MeRecommendationGrid extends StatelessWidget {
  const MeRecommendationGrid({super.key, required this.products});

  final List<Product> products;

  @override
  Widget build(BuildContext context) {
    return GridView.builder(
      itemCount: products.length,
      shrinkWrap: true,
      physics: const NeverScrollableScrollPhysics(),
      gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
        crossAxisCount: 2,
        crossAxisSpacing: 8,
        mainAxisSpacing: 8,
        childAspectRatio: 0.53,
      ),
      itemBuilder: (context, index) => ProductCard(product: products[index]),
    );
  }
}
