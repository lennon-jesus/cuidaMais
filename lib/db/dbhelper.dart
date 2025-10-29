import 'package:sqflite/sqflite.dart';
import 'package:path/path.dart';
import '../models/medic.dart';
import '../models/profile.dart';

class DatabaseHelper {
  static final DatabaseHelper _instance = DatabaseHelper._internal();
  factory DatabaseHelper() => _instance;
  DatabaseHelper._internal();

  static Database? _db;

  Future<Database> get database async {
    if (_db != null) return _db!;
    _db = await _initDb();
    return _db!;
  }

  Future<Database> _initDb() async {
    final dbPath = await getDatabasesPath();
    final path = join(dbPath, 'medic.db');

    return await openDatabase(
      path,
      version: 1,
      onCreate: (db, version) async {
        await db.execute('''
          CREATE TABLE IF NOT EXISTS profiles(
            id INTEGER PRIMARY KEY AUTOINCREMENT,
            name TEXT NOT NULL
          )
        ''');
        await db.execute('''
            CREATE TABLE medicine(
            id INTEGER PRIMARY KEY AUTOINCREMENT,
            medName TEXT,
            medDose TEXT,
            medTimes TEXT,
            imagePath TEXT,
            observations TEXT,
            daysOfWeek TEXT,
            maxDoses INTEGER DEFAULT 0,
            takenDoses TEXT,
            profileId INTEGER DEFAULT 0,
            notificationType TEXT DEFAULT 'onTime'
          )
        ''');
      },
    );
  }

  Future<int> insertMed(Medicine medicine) async {
    final db = await database;
    return await db.insert('medicine', medicine.toMap());
  }

  Future<List<Medicine>> getMedsByProfile(int profileId) async {
  final db = await database;
  final List<Map<String, dynamic>> maps = await db.query(
    'medicine',
    where: 'profileId = ?',
    whereArgs: [profileId],
  );
  return List.generate(maps.length, (i) => Medicine.fromMap(maps[i]));
}
  Future<int> updateMed(Medicine medicine) async {
    final db = await database;
    return await db.update(
      'medicine',
      medicine.toMap(),
      where: 'id = ?',
      whereArgs: [medicine.id],
    );
  }

  Future<int> deleteMed(int id) async {
    final db = await database;
    return await db.delete('medicine', where: 'id = ?', whereArgs: [id]);
  }

  Future<int> insertProfile(Profile profile) async {
    final db = await database;
    return await db.insert('profiles', profile.toMap());
  }

  // Buscar todos os perfis
  Future<List<Profile>> getProfiles() async {
    final db = await database;
    final List<Map<String, dynamic>> maps = await db.query('profiles');
    return List.generate(maps.length, (i) => Profile.fromMap(maps[i]));
  }

  // Remover perfil com autenticação
  Future<int> deleteProfile(int id) async {
    final db = await database;
    return await db.delete('profiles', where: 'id = ?', whereArgs: [id]);
  }
}
