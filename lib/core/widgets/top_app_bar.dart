import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../services/auth_service.dart';
import 'package:go_router/go_router.dart';


class TopAppBar extends StatelessWidget implements PreferredSizeWidget {
  final String title;
  final List<String> logoAssetPaths;
  final bool showMenu;

  const TopAppBar({
    super.key,
    required this.title,
    this.logoAssetPaths = const [],
    this.showMenu = true,
  });

  @override
  Size get preferredSize => const Size.fromHeight(56);

  @override
  Widget build(BuildContext context) {
    return AppBar(
      leading: showMenu ? Builder(
        builder: (context) => IconButton(
          icon: const Icon(Icons.menu, color: Colors.white),
          onPressed: () => Scaffold.of(context).openDrawer(),
        ),
      ) : null,
      title: Row(
        children: [
          if (logoAssetPaths.isNotEmpty)
            Row(
              children: logoAssetPaths.map((p) =>
                  Padding(
                    padding: const EdgeInsets.only(right: 8),
                    child: Image.asset(p, height: 28),
                  ),
              ).toList(),
            ),
          Flexible(
            child: Text(
              title,
              style: const TextStyle(
                color: Colors.white,
                fontWeight: FontWeight.w700,
                fontSize: 22,
              ),
              overflow: TextOverflow.ellipsis,
            ),
          ),
        ],
      ),
      actions: [
        IconButton(
          icon: const Icon(Icons.logout, color: Colors.white),
          onPressed: () {
            context.read<AuthService>().logout();
            context.go('/farmers');
          },
        ),
      ],
    );
  }
}
