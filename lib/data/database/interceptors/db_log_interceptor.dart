import 'dart:async';

import 'package:adguard_logger/adguard_logger.dart';
import 'package:drift/drift.dart';
import 'package:flutter/foundation.dart';
import 'package:trusttunnel/common/logging/extensions/db_logger_extension.dart';

class DBLogInterceptor extends QueryInterceptor {
  static final RegExp _insertIntoPattern = RegExp(
    r'^\s*INSERT(?:\s+OR\s+\w+)?\s+INTO\s+([^\s(]+)',
    caseSensitive: false,
  );
  static final RegExp _updatePattern = RegExp(
    r'^\s*UPDATE\s+([^\s(]+)',
    caseSensitive: false,
  );
  static final RegExp _deleteFromPattern = RegExp(
    r'^\s*DELETE\s+FROM\s+([^\s(]+)',
    caseSensitive: false,
  );
  static final RegExp _selectFromPattern = RegExp(
    r'^\s*SELECT\b[\s\S]*?\bFROM\s+([^\s(]+)',
    caseSensitive: false,
  );

  final DBLoggerExtension? _dbLogger;

  DBLogInterceptor() : _dbLogger = logger.extension<DBLoggerExtension>();

  @visibleForTesting
  static String describeBatch(BatchedStatements statements) => _DBOperationDescription.fromBatch(statements).summary;

  @visibleForTesting
  static String describeStatement(String statement) => _DBOperationDescription.fromStatement(statement).summary;

  @override
  Future<void> commitTransaction(TransactionExecutor inner) => _runOperation(
    'COMMIT transaction',
    () => inner.send(),
    mutating: true,
  );

  @override
  Future<void> rollbackTransaction(TransactionExecutor inner) => _runOperation(
    'ROLLBACK transaction',
    () => inner.rollback(),
    mutating: true,
  );

  @override
  Future<void> runBatched(
    QueryExecutor executor,
    BatchedStatements statements,
  ) => _runOperation(
    describeBatch(statements),
    () => executor.runBatched(statements),
    mutating: true,
  );

  @override
  Future<int> runInsert(
    QueryExecutor executor,
    String statement,
    List<Object?> args,
  ) => _runOperation(
    _DBOperationDescription.fromStatement(statement).summary,
    () => executor.runInsert(statement, args),
    mutating: true,
  );

  @override
  Future<int> runUpdate(
    QueryExecutor executor,
    String statement,
    List<Object?> args,
  ) => _runOperation(
    _DBOperationDescription.fromStatement(statement).summary,
    () => executor.runUpdate(statement, args),
    mutating: true,
  );

  @override
  Future<int> runDelete(
    QueryExecutor executor,
    String statement,
    List<Object?> args,
  ) => _runOperation(
    _DBOperationDescription.fromStatement(statement).summary,
    () => executor.runDelete(statement, args),
    mutating: true,
  );

  @override
  Future<void> runCustom(
    QueryExecutor executor,
    String statement,
    List<Object?> args,
  ) => _runOperation(
    _DBOperationDescription.fromStatement(statement).summary,
    () => executor.runCustom(statement, args),
    mutating: true,
  );

  @override
  Future<List<Map<String, Object?>>> runSelect(
    QueryExecutor executor,
    String statement,
    List<Object?> args,
  ) => _runOperation(
    _DBOperationDescription.fromStatement(statement).summary,
    () => executor.runSelect(statement, args),
  );

  Future<T> _runOperation<T>(String description, Future<T> Function() operation, {bool mutating = false}) {
    if (_dbLogger == null) {
      return operation();
    }

    return _dbLogger.runOperation(
      description,
      operation,
      mutating: mutating,
    );
  }
}

final class _DBOperationDescription {
  final String action;
  final String? table;
  final String? suffix;

  const _DBOperationDescription({
    required this.action,
    this.table,
    this.suffix,
  });

  factory _DBOperationDescription.fromBatch(BatchedStatements statements) {
    final descriptions = statements.statements.map(_DBOperationDescription.fromStatement).toList();
    final tables = descriptions.map((item) => item.table).whereType<String>().toSet().toList()..sort();

    return _DBOperationDescription(
      action: 'BATCH',
      table: tables.isEmpty ? null : tables.join(', '),
      suffix: '(${statements.statements.length} statements, ${statements.arguments.length} executions)',
    );
  }

  factory _DBOperationDescription.fromStatement(String statement) {
    final normalizedStatement = statement.trim();
    if (normalizedStatement.isEmpty) {
      return const _DBOperationDescription(action: 'CUSTOM');
    }
    if (normalizedStatement.toLowerCase() == 'commit transaction') {
      return const _DBOperationDescription(
        action: 'COMMIT',
        table: 'transaction',
      );
    }
    if (normalizedStatement.toLowerCase() == 'rollback transaction') {
      return const _DBOperationDescription(
        action: 'ROLLBACK',
        table: 'transaction',
      );
    }

    return _matchPattern(
          statement: normalizedStatement,
          pattern: DBLogInterceptor._insertIntoPattern,
          action: 'INSERT',
        ) ??
        _matchPattern(
          statement: normalizedStatement,
          pattern: DBLogInterceptor._updatePattern,
          action: 'UPDATE',
        ) ??
        _matchPattern(
          statement: normalizedStatement,
          pattern: DBLogInterceptor._deleteFromPattern,
          action: 'DELETE',
        ) ??
        _matchPattern(
          statement: normalizedStatement,
          pattern: DBLogInterceptor._selectFromPattern,
          action: 'SELECT',
        ) ??
        const _DBOperationDescription(action: 'CUSTOM');
  }

  static _DBOperationDescription? _matchPattern({
    required String statement,
    required RegExp pattern,
    required String action,
  }) {
    final match = pattern.firstMatch(statement);
    if (match == null) {
      return null;
    }

    return _DBOperationDescription(
      action: action,
      table: _normalizeTableName(match.group(1)),
    );
  }

  static String? _normalizeTableName(String? rawTableName) {
    if (rawTableName == null || rawTableName.isEmpty) {
      return null;
    }

    final tableName = rawTableName.replaceAll(RegExp(r'["`;\[\]]'), '');
    final dotIndex = tableName.lastIndexOf('.');
    if (dotIndex == -1 || dotIndex == tableName.length - 1) {
      return tableName;
    }

    return tableName.substring(dotIndex + 1);
  }

  String get summary {
    final buffer = StringBuffer(action);
    if (table != null) {
      buffer.write(' ');
      buffer.write(table);
    }
    if (suffix != null) {
      buffer.write(' ');
      buffer.write(suffix);
    }

    return buffer.toString();
  }
}
