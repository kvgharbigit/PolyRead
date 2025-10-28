// Database Adapter
// Bridges Drift AppDatabase with services that expect sqflite Database
// Currently not used as we have Drift-native services

import 'package:polyread/core/database/app_database.dart';

/// Adapter to bridge Drift AppDatabase with services expecting sqflite Database
class DatabaseAdapter {
  final AppDatabase _driftDatabase;
  
  DatabaseAdapter(this._driftDatabase);
  
  /// Access the underlying Drift database
  AppDatabase get driftDatabase => _driftDatabase;
  
  /// Create a mock sqflite Database that delegates operations to Drift
  /// TODO: Complete implementation when needed for legacy services
  // MockSqfliteDatabase get sqfliteDatabase => MockSqfliteDatabase(_driftDatabase);
}

/// Mock sqflite Database implementation that delegates to Drift
/// TODO: Complete implementation when needed
/*
class MockSqfliteDatabase implements sqflite.Database {
  final AppDatabase _driftDatabase;
  
  MockSqfliteDatabase(this._driftDatabase);
  
  @override
  Future<List<Map<String, Object?>>> query(
    String table, {
    bool? distinct,
    List<String>? columns,
    String? where,
    List<Object?>? whereArgs,
    String? groupBy,
    String? having,
    String? orderBy,
    int? limit,
    int? offset,
  }) async {
    // Convert query to Drift format
    final query = _driftDatabase.customSelect(
      _buildSelectQuery(
        table: table,
        distinct: distinct,
        columns: columns,
        where: where,
        groupBy: groupBy,
        having: having,
        orderBy: orderBy,
        limit: limit,
        offset: offset,
      ),
      variables: whereArgs?.map((arg) => Variable(arg)).toList() ?? [],
    );
    
    final results = await query.get();
    return results.map((row) => row.data).toList();
  }
  
  @override
  Future<int> insert(
    String table,
    Map<String, Object?> values, {
    String? nullColumnHack,
    sqflite.ConflictAlgorithm? conflictAlgorithm,
  }) async {
    // Convert to Drift insert
    final insertQuery = _buildInsertQuery(table, values, conflictAlgorithm);
    final variables = values.values.map((value) => Variable(value)).toList();
    
    final result = await _driftDatabase.customInsert(
      insertQuery,
      variables: variables,
    );
    
    return result;
  }
  
  @override
  Future<int> update(
    String table,
    Map<String, Object?> values, {
    String? where,
    List<Object?>? whereArgs,
    sqflite.ConflictAlgorithm? conflictAlgorithm,
  }) async {
    final updateQuery = _buildUpdateQuery(table, values, where);
    final allArgs = [...values.values, ...?whereArgs];
    final variables = allArgs.map((arg) => Variable(arg)).toList();
    
    return await _driftDatabase.customUpdate(
      updateQuery,
      variables: variables,
    );
  }
  
  @override
  Future<int> delete(String table, {String? where, List<Object?>? whereArgs}) async {
    final deleteQuery = _buildDeleteQuery(table, where);
    final variables = whereArgs?.map((arg) => Variable(arg)).toList() ?? [];
    
    return await _driftDatabase.customUpdate(
      deleteQuery,
      variables: variables,
    );
  }
  
  @override
  Future<List<Map<String, Object?>>> rawQuery(
    String sql, [
    List<Object?>? arguments,
  ]) async {
    final variables = arguments?.map((arg) => Variable(arg)).toList() ?? [];
    final results = await _driftDatabase.customSelect(sql, variables: variables).get();
    return results.map((row) => row.data).toList();
  }
  
  @override
  Future<int> rawInsert(String sql, [List<Object?>? arguments]) async {
    final variables = arguments?.map((arg) => Variable(arg)).toList() ?? [];
    return await _driftDatabase.customInsert(sql, variables: variables);
  }
  
  @override
  Future<int> rawUpdate(String sql, [List<Object?>? arguments]) async {
    final variables = arguments?.map((arg) => Variable(arg)).toList() ?? [];
    return await _driftDatabase.customUpdate(sql, variables: variables);
  }
  
  @override
  Future<int> rawDelete(String sql, [List<Object?>? arguments]) async {
    final variables = arguments?.map((arg) => Variable(arg)).toList() ?? [];
    return await _driftDatabase.customUpdate(sql, variables: variables);
  }
  
  @override
  Future<void> execute(String sql, [List<Object?>? arguments]) async {
    final variables = arguments?.map((arg) => Variable(arg)).toList() ?? [];
    await _driftDatabase.customStatement(sql, variables);
  }
  
  // Helper methods to build SQL queries
  
  String _buildSelectQuery({
    required String table,
    bool? distinct,
    List<String>? columns,
    String? where,
    String? groupBy,
    String? having,
    String? orderBy,
    int? limit,
    int? offset,
  }) {
    final buffer = StringBuffer();
    buffer.write('SELECT ');
    
    if (distinct == true) buffer.write('DISTINCT ');
    
    if (columns?.isNotEmpty == true) {
      buffer.write(columns!.join(', '));
    } else {
      buffer.write('*');
    }
    
    buffer.write(' FROM $table');
    
    if (where != null) {
      buffer.write(' WHERE $where');
    }
    
    if (groupBy != null) {
      buffer.write(' GROUP BY $groupBy');
    }
    
    if (having != null) {
      buffer.write(' HAVING $having');
    }
    
    if (orderBy != null) {
      buffer.write(' ORDER BY $orderBy');
    }
    
    if (limit != null) {
      buffer.write(' LIMIT $limit');
      if (offset != null) {
        buffer.write(' OFFSET $offset');
      }
    }
    
    return buffer.toString();
  }
  
  String _buildInsertQuery(
    String table,
    Map<String, Object?> values,
    sqflite.ConflictAlgorithm? conflictAlgorithm,
  ) {
    final buffer = StringBuffer();
    
    if (conflictAlgorithm == sqflite.ConflictAlgorithm.replace) {
      buffer.write('INSERT OR REPLACE INTO ');
    } else if (conflictAlgorithm == sqflite.ConflictAlgorithm.ignore) {
      buffer.write('INSERT OR IGNORE INTO ');
    } else {
      buffer.write('INSERT INTO ');
    }
    
    buffer.write(table);
    buffer.write(' (');
    buffer.write(values.keys.join(', '));
    buffer.write(') VALUES (');
    buffer.write(List.filled(values.length, '?').join(', '));
    buffer.write(')');
    
    return buffer.toString();
  }
  
  String _buildUpdateQuery(String table, Map<String, Object?> values, String? where) {
    final buffer = StringBuffer();
    buffer.write('UPDATE $table SET ');
    buffer.write(values.keys.map((key) => '$key = ?').join(', '));
    
    if (where != null) {
      buffer.write(' WHERE $where');
    }
    
    return buffer.toString();
  }
  
  String _buildDeleteQuery(String table, String? where) {
    final buffer = StringBuffer();
    buffer.write('DELETE FROM $table');
    
    if (where != null) {
      buffer.write(' WHERE $where');
    }
    
    return buffer.toString();
  }
  
  // These methods are not supported in this adapter
  // They will throw UnsupportedError
  
  @override
  String get path => throw UnsupportedError('Path not available in Drift adapter');
  
  @override
  bool get isOpen => true; // Assume Drift database is always open
  
  @override
  Future<void> close() async {
    await _driftDatabase.close();
  }
  
  @override
  Future<T> transaction<T>(Future<T> Function(sqflite.Transaction txn) action) {
    throw UnsupportedError('Use Drift transactions instead');
  }
  
  @override
  sqflite.Batch batch() {
    throw UnsupportedError('Use Drift batch operations instead');
  }
  
  @override
  int get version => throw UnsupportedError('Version not available in Drift adapter');
}
*/