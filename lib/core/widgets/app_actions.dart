import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../../core/services/auth_service.dart';

List<Widget> appActions(
    BuildContext context, {
      VoidCallback? onView,         // what to open when the user taps “view”
      String viewTooltip = 'View saved',
    }) {
  return <Widget>[
    if (onView != null)
      IconButton(
        icon: const Icon(Icons.receipt_long_outlined),
        tooltip: viewTooltip,
        onPressed: onView,
      ),
    IconButton(
      icon: const Icon(Icons.logout_outlined),
      tooltip: 'Logout',
      onPressed: () => context.read<AuthService>().logout(),
    ),
  ];
}
