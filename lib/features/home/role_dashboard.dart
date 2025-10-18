import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';

class RoleDashboard extends StatelessWidget {
  const RoleDashboard({super.key});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color(0xFFF5F7F2),
      appBar: AppBar(
        title: const Text('Dashboard'),
        backgroundColor: const Color(0xFF2E7D32),
        foregroundColor: Colors.white,
        elevation: 0,
        actions: [
          IconButton(
            icon: const Icon(Icons.logout),
            onPressed: () => context.go('/login'),
          ),
        ],
      ),
      body: SafeArea(
        child: SingleChildScrollView(
          padding: const EdgeInsets.fromLTRB(16, 16, 16, 24),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              _QuickChips(),
              const SizedBox(height: 16),
              GridView.count(
                physics: const NeverScrollableScrollPhysics(),
                shrinkWrap: true,
                crossAxisCount: 2,
                childAspectRatio: 1.05,
                mainAxisSpacing: 16,
                crossAxisSpacing: 16,
                children: [
                  _Tile(
                    color: const Color(0xFFDDEBD8), // green pastel
                    icon: Icons.hub_outlined,
                    label: 'Farmer Network',
                    onTap: () => context.push('/farmers/network'),
                  ),
                  _Tile(
                    color: const Color(0xFFE6EEFF), // blue pastel
                    icon: Icons.person_add_alt_1_outlined,
                    label: 'Farmer Registration',
                    onTap: () => context.push('/farmers/registration'),
                  ),
                  _Tile(
                    color: const Color(0xFFF7EFC8), // yellow pastel
                    icon: Icons.event_note_outlined,
                    label: 'Field Observations',
                    onTap: () => context.push('/field/observations'),
                  ),
                  _Tile(
                    color: const Color(0xFFEDE6FF), // lilac pastel
                    icon: Icons.inventory_2_outlined,
                    label: 'Inputs Details',
                    onTap: () => context.push('/inputs/supply'),
                  ),
                  _Tile(
                    color: const Color(0xFFF8E0CC), // peach pastel
                    icon: Icons.science_outlined,
                    label: 'Activity Schedule',
                    onTap: () => context.push('/activity/schedule'),
                  ),
                  _Tile(
                    color: const Color(0xFFEEEDEA), // grey pastel
                    icon: Icons.access_time_rounded,
                    label: 'Daily logs & Schedule',
                    onTap: () => context.push('/daily-logs'),
                  ),
                  _Tile(
                    color: const Color(0xFFFCE2E2), // pink pastel
                    icon: Icons.medical_services_outlined,
                    label: 'Diagnostics',
                    onTap: () => context.push('/diagnostics'),
                  ),
                  _Tile(
                    color: const Color(0xFFE6F7F9), // teal pastel
                    icon: Icons.biotech_outlined,
                    label: 'Field Diagnostics',
                    onTap: () => context.push('/field/diagnostics'),
                  ),
                ],
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class _Tile extends StatelessWidget {
  const _Tile({
    required this.color,
    required this.icon,
    required this.label,
    required this.onTap,
  });

  final Color color;
  final IconData icon;
  final String label;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return InkWell(
      borderRadius: BorderRadius.circular(24),
      onTap: onTap,
      child: Container(
        decoration: BoxDecoration(
          color: color,
          borderRadius: BorderRadius.circular(24),
        ),
        padding: const EdgeInsets.all(20),
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(icon, size: 42, color: Colors.black87),
            const SizedBox(height: 18),
            Text(
              label,
              textAlign: TextAlign.center,
              style: Theme.of(context).textTheme.titleMedium?.copyWith(
                fontWeight: FontWeight.w600,
                color: Colors.black87,
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _QuickChips extends StatelessWidget {
  @override
  Widget build(BuildContext context) {
    return Wrap(
      spacing: 12,
      runSpacing: 12,
      children: const [
        _Chip(icon: Icons.home_rounded, label: 'Home'),
        _Chip(icon: Icons.forum_outlined, label: 'Communication'),
        _Chip(icon: Icons.settings_outlined, label: 'Settings'),
      ],
    );
  }
}

class _Chip extends StatelessWidget {
  const _Chip({required this.icon, required this.label});
  final IconData icon;
  final String label;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
      decoration: BoxDecoration(
        color: const Color(0xFFE4EFDF),
        borderRadius: BorderRadius.circular(14),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(icon, size: 18, color: const Color(0xFF2E7D32)),
          const SizedBox(width: 8),
          Text(
            label,
            style: const TextStyle(
              color: Color(0xFF2E7D32),
              fontWeight: FontWeight.w600,
            ),
          ),
        ],
      ),
    );
  }
}
