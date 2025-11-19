// db/dbhelper.dart
import 'dart:io';
import 'package:sqflite/sqflite.dart';
import 'package:path/path.dart' as p;
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

  Future<String> getDatabaseFilePath() async {
    final dbPath = await getDatabasesPath();
    return p.join(dbPath, 'medic.db');
  }

  Future<Database> _initDb() async {
    final path = await getDatabaseFilePath();

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
          CREATE TABLE IF NOT EXISTS medicine(
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

  Future<void> close() async {
    if (_db != null) {
      await _db!.close();
      _db = null;
    }
  }

  Future<int> insertMed(Medicine medicine) async {
    final db = await database;
    return await db.insert('medicine', medicine.toMap());
  }

  Future<List<Medicine>> getMedsByProfile(int profileId) async {
    final db = await database;
    final maps = await db.query(
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

  Future<List<Profile>> getProfiles() async {
    final db = await database;
    final maps = await db.query('profiles');
    return List.generate(maps.length, (i) => Profile.fromMap(maps[i]));
  }

  Future<int> deleteProfile(int id) async {
    final db = await database;
    return await db.delete('profiles', where: 'id = ?', whereArgs: [id]);
  }

  Future<String> exportDatabaseFileTo(String destinationPath) async {
    await close();
    final dbPath = await getDatabaseFilePath();
    final src = File(dbPath);
    final dest = File(destinationPath);
    await src.copy(dest.path);
    _db = await _initDb();
    return dest.path;
  }

  Future<bool> replaceDatabaseWith(String sourcePath) async {
    try {
      await close();
      final dbPath = await getDatabaseFilePath();
      final src = File(sourcePath);
      if (!await src.exists()) return false;

      await src.copy(dbPath);

      _db = await _initDb();
      return true;
    } catch (e) {
      return false;
    }
  }

  Future<void> closeDB() async {
    if (_db != null) {
      await _db!.close();
      _db = null;
    }
  }
}
