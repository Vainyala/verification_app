
import 'dart:convert';
import 'package:sqflite_sqlcipher/sqflite.dart';
import 'package:flutter_secure_storage/flutter_secure_storage.dart';
import 'package:path/path.dart' as p;

class VehicleDb {
  static Database? _db;
  static const _dbName = "vehicles.db";
  static const _table = "vehicles";
  static const _auditTable = "audit_logs";
  static const _storage = FlutterSecureStorage();

  /// Initialize DB safely
  static Future<void> init() async {
    final dbPath = await getDatabasesPath();
    final path = p.join(dbPath, _dbName);

    try {
      String? key = await _storage.read(key: "vehicle_db_key");
      if (key == null) {
        key = DateTime.now().microsecondsSinceEpoch.toString();
        await _storage.write(key: "vehicle_db_key", value: key);
      }

      _db = await openDatabase(
        path,
        password: key,
        version: 3, // 🔹 incremented version for vehicle_type
        onCreate: (db, version) async {
          await _createTables(db);
        },
        onUpgrade: (db, oldVersion, newVersion) async {
          if (oldVersion < 2) {
            await db.execute(
                'ALTER TABLE $_table ADD COLUMN vehicle_number TEXT');
          }
          if (oldVersion < 3) {
            await db.execute(
                'ALTER TABLE $_table ADD COLUMN vehicle_type TEXT'); // 🔹 add new column
          }
        },
      );
      print("✅ VehicleDb initialized at $path");
    } catch (e) {
      print("❌ Error opening DB or decrypting storage: $e");
      await _storage.deleteAll();
      await deleteDatabase(path);
      String newKey = DateTime.now().microsecondsSinceEpoch.toString();
      await _storage.write(key: "vehicle_db_key", value: newKey);
      _db = await openDatabase(
        path,
        password: newKey,
        version: 3,
        onCreate: (db, version) async {
          await _createTables(db);
        },
      );
    }
  }

  /// Create tables
  static Future<void> _createTables(Database db) async {
    await db.execute('''
      CREATE TABLE $_table (
        id TEXT PRIMARY KEY,
        name TEXT,
        vector TEXT,
        imagePath TEXT,
        vehicle_number TEXT,
        vehicle_type TEXT
      )
    ''');

    await db.execute('''
      CREATE TABLE $_auditTable (
        id INTEGER PRIMARY KEY AUTOINCREMENT,
        action TEXT,
        suspectId TEXT,
        officerId TEXT,
        dateTime TEXT,
        extraInfo TEXT
      )
    ''');
  }

  /// Insert dummy once
  static Future<void> insertDummyOnce(
      String id,
      String name,
      List<double> vector,
      String imagePath, {
        String? officerId,
        String? vehicleNumber,
        String? vehicleType,
      }) async {
    try {
      if (_db == null) throw Exception("Database not initialized!");
      final exists = await _db!.query(_table, where: 'id = ?', whereArgs: [id]);
      if (exists.isEmpty) {
        final jsonVector = jsonEncode(vector);
        await _db!.insert(_table, {
          "id": id,
          "name": name,
          "vector": jsonVector,
          "imagePath": imagePath,
          "vehicle_number": vehicleNumber ?? "",
          "vehicle_type": vehicleType ?? "",
        });
        print("✅ Dummy data inserted (vehicle_type included)");
        if (officerId != null) {
          await _logAction("Added", id, officerId);
        }
      } else {
        print("ℹ️ Dummy data already exists, skipping insert");
      }
    } catch (e, stackTrace) {
      print("❌ Error inserting dummy data: $e\n$stackTrace");
    }
  }

  /// Get all vehicles
  static Future<List<Map<String, dynamic>>> getAll() async {
    if (_db == null) throw Exception("Database not initialized!");
    final rows = await _db!.query(_table);
    return rows.map((r) {
      final vectorStr = r["vector"] as String?;
      final vector = vectorStr != null ? List<double>.from(jsonDecode(vectorStr)) : <double>[];
      return {
        "id": r["id"],
        "name": r["name"],
        "vector": vector,
        "imagePath": r["imagePath"],
        "vehicle_number": r["vehicle_number"] ?? "",
        "vehicle_type": r["vehicle_type"] ?? "", // 🔹 include vehicle_type
      };
    }).toList();
  }

  /// Delete vehicle
  static Future<void> deleteVehicle(String id, {String? officerId}) async {
    if (_db == null) throw Exception("Database not initialized!");
    await _db!.delete(_table, where: 'id = ?', whereArgs: [id]);
    if (officerId != null) await _logAction("Deleted", id, officerId);
  }

  /// Delete vehicle by vehicle_number
  static Future<void> deletecrimnalVehicle(String vehicleNumber, {String? officerId}) async {
    if (_db == null) throw Exception("Database not initialized!");

    await _db!.delete(
      _table,
      where: 'vehicle_number = ?',
      whereArgs: [vehicleNumber],
    );

    if (officerId != null) {
      await _logAction("Deleted", vehicleNumber, officerId);
    }

    print("🚗 Vehicle with number $vehicleNumber deleted");
  }



  /// Log actions
  static Future<void> _logAction(
      String action, String suspectId, String officerId,
      {String? extraInfo}) async {
    if (_db == null) throw Exception("Database not initialized!");
    await _db!.insert(_auditTable, {
      "action": action,
      "suspectId": suspectId,
      "officerId": officerId,
      "dateTime": DateTime.now().toIso8601String(),
      "extraInfo": extraInfo ?? ""
    });
  }

  /// Clear DB
  static Future<void> clearDb() async {
    if (_db != null) {
      await _db!.delete(_table);
      await _db!.delete(_auditTable);
      print("🗑️ VehicleDb cleared");
    }
  }

  /// Audit logs
  static Future<List<Map<String, dynamic>>> getAuditLogs() async {
    if (_db == null) throw Exception("Database not initialized!");
    return await _db!.query(_auditTable, orderBy: "dateTime DESC");
  }
}
