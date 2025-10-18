import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import 'package:provider/provider.dart';

import '../../core/services/auth_service.dart';

/// Opens the most-relevant Activity Schedule for the current CIC
/// and immediately navigates to the detail screen with tabs.
/// If none is found, shows a friendly message.
class ClusterActivityScheduleListScreen extends StatefulWidget {
  const ClusterActivityScheduleListScreen({super.key});

  @override
  State<ClusterActivityScheduleListScreen> createState() =>
      _ClusterActivityScheduleListScreenState();
}

class _ClusterActivityScheduleListScreenState
    extends State<ClusterActivityScheduleListScreen> {
  bool _loading = true;
  String? _error;

  @override
  void initState() {
    super.initState();
    _openLatest();
  }

  Future<void> _openLatest() async {
    try {
      final auth = context.read<AuthService>();
      final cicUid = auth.currentUser?.uid ?? auth.currentUserId ?? 'anon';

      final col = FirebaseFirestore.instance.collection('activity_schedule');

      Query<Map<String, dynamic>> q = col
          .where('orgPathUids', arrayContains: cicUid)
          .orderBy('dateYMD', descending: true)
          .orderBy('createdAt', descending: true)
          .limit(1);

      DocumentSnapshot<Map<String, dynamic>>? doc;

      try {
        final shot = await q.get();
        if (shot.docs.isNotEmpty) doc = shot.docs.first;
      } on FirebaseException catch (e) {
        // If a composite index is missing, fall back to a non-indexed path.
        if (e.code == 'failed-precondition') {
          final fallback = await col
              .where('orgPathUids', arrayContains: cicUid)
              .limit(50)
              .get();

          if (fallback.docs.isNotEmpty) {
            // Sort client-side by dateYMD then createdAt (both desc).
            final docs = [...fallback.docs];
            docs.sort((a, b) {
              final am = a.data(), bm = b.data();
              final ay = (am['dateYMD'] ?? '').toString();
              final by = (bm['dateYMD'] ?? '').toString();
              final yCmp = by.compareTo(ay);
              if (yCmp != 0) return yCmp;

              DateTime ad, bd;
              final ac = am['createdAt'], bc = bm['createdAt'];
              ad = (ac is Timestamp) ? ac.toDate() : DateTime.fromMillisecondsSinceEpoch(0);
              bd = (bc is Timestamp) ? bc.toDate() : DateTime.fromMillisecondsSinceEpoch(0);
              return bd.compareTo(ad);
            });
            doc = docs.first;
          }
        } else {
          rethrow;
        }
      }

      if (!mounted) return;

      if (doc != null) {
        context.goNamed(
          'ci.activity.schedule.detail',
          pathParameters: {'docId': doc!.id},
        );
        return;
      } else {
        setState(() {
          _loading = false;
          _error = 'No schedules found';
        });
      }
    } catch (e) {
      if (!mounted) return;
      setState(() {
        _loading = false;
        _error = 'Failed to load schedule: $e';
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('Activity Schedule (Cluster)')),
      body: Center(
        child: _loading
            ? const CircularProgressIndicator()
            : Text(_error ?? 'No schedules found'),
      ),
    );
  }
}
