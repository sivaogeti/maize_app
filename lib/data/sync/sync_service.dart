import 'package:flutter/foundation.dart';
import '../repositories/farmer_repository.dart';
import '../repositories/registration_repository.dart';

class SyncService {
  SyncService(this.farmers, this.regs);

  final FarmerRepository farmers;
  final RegistrationRepository regs;

  DateTime? _lastFarmersSync;
  DateTime? _lastRegsSync;

  Future<void> fullSync() async {
    await farmers.pushPending();
    await regs.pushPending();

    await farmers.pullSince(_lastFarmersSync);
    await regs.pullSince(_lastRegsSync);

    _lastFarmersSync = DateTime.now();
    _lastRegsSync = DateTime.now();
    debugPrint('Sync complete');
  }
}
