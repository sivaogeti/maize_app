// lib/data/models/registration.dart
import 'package:isar_community/isar.dart' hide Query; // keep hide Query where you use Firestore Query
part 'registration.g.dart';

@collection
class RegistrationLocal {
  Id id = Isar.autoIncrement;
  late String regId;
  late String orgId;
  late String farmerId;
  String? notes;
  @Index()
  late DateTime updatedAt;
  bool deleted = false;
  bool pending = false;
}
