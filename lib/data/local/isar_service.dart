import 'package:isar_community/isar.dart' hide Query; // keep hide Query where you use Firestore Query
import 'package:path_provider/path_provider.dart';
import '../models/farmer.dart';
import '../models/registration.dart';

class IsarService {
  IsarService._();
  static final instance = IsarService._();

  late Isar _isar;
  Isar get db => _isar;

  Future<void> open() async {
    final dir = await getApplicationDocumentsDirectory();
    _isar = await Isar.open(
      [FarmerLocalSchema, RegistrationLocalSchema], // <-- positional list
      directory: dir.path,
      inspector: false,
    );
  }
}
