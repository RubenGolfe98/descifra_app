import 'package:flutter/material.dart';
import '../theme/app_colors.dart';

class DlgAppBar extends StatelessWidget implements PreferredSizeWidget {
  final String title;
  final bool isDark;
  final List<Widget>? actions;
  final PreferredSizeWidget? bottom;

  const DlgAppBar({
    super.key,
    required this.title,
    required this.isDark,
    this.actions,
    this.bottom,
  });

  @override
  Widget build(BuildContext context) {
    final pri = AppColors.textPri(isDark);
    final bord = AppColors.bord(isDark);

    return AppBar(
      backgroundColor: AppColors.surf(isDark),
      elevation: 0,
      leading: IconButton(
        icon: Icon(Icons.arrow_back_ios_new, color: pri, size: 18),
        onPressed: () => Navigator.of(context).pop(),
      ),
      title: Text(
        title,
        style: TextStyle(
          color: pri,
          fontSize: 16,
          fontWeight: FontWeight.w600,
        ),
      ),
      actions: actions,
      bottom: bottom ??
          PreferredSize(
            preferredSize: const Size.fromHeight(0.5),
            child: Divider(height: 0.5, color: bord),
          ),
    );
  }

  @override
  Size get preferredSize => Size.fromHeight(
        (bottom?.preferredSize.height ?? 0.5) + kToolbarHeight,
      );
}
