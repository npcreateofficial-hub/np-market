import 'package:flutter/material.dart';

import '../../../app_theme.dart';

class MeSectionRow extends StatelessWidget {
  const MeSectionRow({super.key, required this.title, this.action, this.onTap});

  final String title;
  final String? action;
  final VoidCallback? onTap;

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final titleColor = isDark ? darkInk : ink;
    final actionColor = isDark ? darkMuted : muted;
    return InkWell(
      onTap: onTap,
      child: Padding(
        padding: const EdgeInsets.fromLTRB(14, 13, 12, 12),
        child: Row(
          children: [
            Expanded(
              child: Text(
                title,
                style: TextStyle(
                  color: titleColor,
                  fontWeight: FontWeight.w900,
                  fontSize: 15.5,
                ),
              ),
            ),
            if (action != null)
              Text(
                action!,
                style: TextStyle(color: actionColor, fontSize: 12.5),
              ),
            if (action != null)
              Icon(Icons.chevron_right, color: actionColor, size: 18),
          ],
        ),
      ),
    );
  }
}
