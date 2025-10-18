// lib/data/models/farmer.dart
import 'package:isar_community/isar.dart' hide Query; // keep hide Query where you use Firestore Query
part 'farmer.g.dart';

@collection
class FarmerLocal {
  Id id = Isar.autoIncrement;
  late String farmerId;
  late String orgId;
  late String name;
  String? phone;
  @Index()
  late DateTime updatedAt;
  bool deleted = false;
  bool pending = false;
}
