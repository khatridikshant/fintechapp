// GENERATED CODE - DO NOT MODIFY BY HAND

part of 'app_database.dart';

// ignore_for_file: type=lint
class $AccountsTable extends Accounts
    with TableInfo<$AccountsTable, AccountRow> {
  @override
  final GeneratedDatabase attachedDatabase;
  final String? _alias;
  $AccountsTable(this.attachedDatabase, [this._alias]);
  static const VerificationMeta _idMeta = const VerificationMeta('id');
  @override
  late final GeneratedColumn<String> id = GeneratedColumn<String>(
      'id', aliasedName, false,
      type: DriftSqlType.string, requiredDuringInsert: true);
  static const VerificationMeta _codeMeta = const VerificationMeta('code');
  @override
  late final GeneratedColumn<String> code = GeneratedColumn<String>(
      'code', aliasedName, false,
      type: DriftSqlType.string,
      requiredDuringInsert: true,
      defaultConstraints: GeneratedColumn.constraintIsAlways('UNIQUE'));
  static const VerificationMeta _nameMeta = const VerificationMeta('name');
  @override
  late final GeneratedColumn<String> name = GeneratedColumn<String>(
      'name', aliasedName, false,
      type: DriftSqlType.string, requiredDuringInsert: true);
  @override
  late final GeneratedColumnWithTypeConverter<AccountType, String> type =
      GeneratedColumn<String>('type', aliasedName, false,
              type: DriftSqlType.string, requiredDuringInsert: true)
          .withConverter<AccountType>($AccountsTable.$convertertype);
  @override
  List<GeneratedColumn> get $columns => [id, code, name, type];
  @override
  String get aliasedName => _alias ?? actualTableName;
  @override
  String get actualTableName => $name;
  static const String $name = 'accounts';
  @override
  VerificationContext validateIntegrity(Insertable<AccountRow> instance,
      {bool isInserting = false}) {
    final context = VerificationContext();
    final data = instance.toColumns(true);
    if (data.containsKey('id')) {
      context.handle(_idMeta, id.isAcceptableOrUnknown(data['id']!, _idMeta));
    } else if (isInserting) {
      context.missing(_idMeta);
    }
    if (data.containsKey('code')) {
      context.handle(
          _codeMeta, code.isAcceptableOrUnknown(data['code']!, _codeMeta));
    } else if (isInserting) {
      context.missing(_codeMeta);
    }
    if (data.containsKey('name')) {
      context.handle(
          _nameMeta, name.isAcceptableOrUnknown(data['name']!, _nameMeta));
    } else if (isInserting) {
      context.missing(_nameMeta);
    }
    return context;
  }

  @override
  Set<GeneratedColumn> get $primaryKey => {id};
  @override
  AccountRow map(Map<String, dynamic> data, {String? tablePrefix}) {
    final effectivePrefix = tablePrefix != null ? '$tablePrefix.' : '';
    return AccountRow(
      id: attachedDatabase.typeMapping
          .read(DriftSqlType.string, data['${effectivePrefix}id'])!,
      code: attachedDatabase.typeMapping
          .read(DriftSqlType.string, data['${effectivePrefix}code'])!,
      name: attachedDatabase.typeMapping
          .read(DriftSqlType.string, data['${effectivePrefix}name'])!,
      type: $AccountsTable.$convertertype.fromSql(attachedDatabase.typeMapping
          .read(DriftSqlType.string, data['${effectivePrefix}type'])!),
    );
  }

  @override
  $AccountsTable createAlias(String alias) {
    return $AccountsTable(attachedDatabase, alias);
  }

  static JsonTypeConverter2<AccountType, String, String> $convertertype =
      const EnumNameConverter<AccountType>(AccountType.values);
}

class AccountRow extends DataClass implements Insertable<AccountRow> {
  final String id;
  final String code;
  final String name;
  final AccountType type;
  const AccountRow(
      {required this.id,
      required this.code,
      required this.name,
      required this.type});
  @override
  Map<String, Expression> toColumns(bool nullToAbsent) {
    final map = <String, Expression>{};
    map['id'] = Variable<String>(id);
    map['code'] = Variable<String>(code);
    map['name'] = Variable<String>(name);
    {
      map['type'] = Variable<String>($AccountsTable.$convertertype.toSql(type));
    }
    return map;
  }

  AccountsCompanion toCompanion(bool nullToAbsent) {
    return AccountsCompanion(
      id: Value(id),
      code: Value(code),
      name: Value(name),
      type: Value(type),
    );
  }

  factory AccountRow.fromJson(Map<String, dynamic> json,
      {ValueSerializer? serializer}) {
    serializer ??= driftRuntimeOptions.defaultSerializer;
    return AccountRow(
      id: serializer.fromJson<String>(json['id']),
      code: serializer.fromJson<String>(json['code']),
      name: serializer.fromJson<String>(json['name']),
      type: $AccountsTable.$convertertype
          .fromJson(serializer.fromJson<String>(json['type'])),
    );
  }
  @override
  Map<String, dynamic> toJson({ValueSerializer? serializer}) {
    serializer ??= driftRuntimeOptions.defaultSerializer;
    return <String, dynamic>{
      'id': serializer.toJson<String>(id),
      'code': serializer.toJson<String>(code),
      'name': serializer.toJson<String>(name),
      'type':
          serializer.toJson<String>($AccountsTable.$convertertype.toJson(type)),
    };
  }

  AccountRow copyWith(
          {String? id, String? code, String? name, AccountType? type}) =>
      AccountRow(
        id: id ?? this.id,
        code: code ?? this.code,
        name: name ?? this.name,
        type: type ?? this.type,
      );
  AccountRow copyWithCompanion(AccountsCompanion data) {
    return AccountRow(
      id: data.id.present ? data.id.value : this.id,
      code: data.code.present ? data.code.value : this.code,
      name: data.name.present ? data.name.value : this.name,
      type: data.type.present ? data.type.value : this.type,
    );
  }

  @override
  String toString() {
    return (StringBuffer('AccountRow(')
          ..write('id: $id, ')
          ..write('code: $code, ')
          ..write('name: $name, ')
          ..write('type: $type')
          ..write(')'))
        .toString();
  }

  @override
  int get hashCode => Object.hash(id, code, name, type);
  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      (other is AccountRow &&
          other.id == this.id &&
          other.code == this.code &&
          other.name == this.name &&
          other.type == this.type);
}

class AccountsCompanion extends UpdateCompanion<AccountRow> {
  final Value<String> id;
  final Value<String> code;
  final Value<String> name;
  final Value<AccountType> type;
  final Value<int> rowid;
  const AccountsCompanion({
    this.id = const Value.absent(),
    this.code = const Value.absent(),
    this.name = const Value.absent(),
    this.type = const Value.absent(),
    this.rowid = const Value.absent(),
  });
  AccountsCompanion.insert({
    required String id,
    required String code,
    required String name,
    required AccountType type,
    this.rowid = const Value.absent(),
  })  : id = Value(id),
        code = Value(code),
        name = Value(name),
        type = Value(type);
  static Insertable<AccountRow> custom({
    Expression<String>? id,
    Expression<String>? code,
    Expression<String>? name,
    Expression<String>? type,
    Expression<int>? rowid,
  }) {
    return RawValuesInsertable({
      if (id != null) 'id': id,
      if (code != null) 'code': code,
      if (name != null) 'name': name,
      if (type != null) 'type': type,
      if (rowid != null) 'rowid': rowid,
    });
  }

  AccountsCompanion copyWith(
      {Value<String>? id,
      Value<String>? code,
      Value<String>? name,
      Value<AccountType>? type,
      Value<int>? rowid}) {
    return AccountsCompanion(
      id: id ?? this.id,
      code: code ?? this.code,
      name: name ?? this.name,
      type: type ?? this.type,
      rowid: rowid ?? this.rowid,
    );
  }

  @override
  Map<String, Expression> toColumns(bool nullToAbsent) {
    final map = <String, Expression>{};
    if (id.present) {
      map['id'] = Variable<String>(id.value);
    }
    if (code.present) {
      map['code'] = Variable<String>(code.value);
    }
    if (name.present) {
      map['name'] = Variable<String>(name.value);
    }
    if (type.present) {
      map['type'] =
          Variable<String>($AccountsTable.$convertertype.toSql(type.value));
    }
    if (rowid.present) {
      map['rowid'] = Variable<int>(rowid.value);
    }
    return map;
  }

  @override
  String toString() {
    return (StringBuffer('AccountsCompanion(')
          ..write('id: $id, ')
          ..write('code: $code, ')
          ..write('name: $name, ')
          ..write('type: $type, ')
          ..write('rowid: $rowid')
          ..write(')'))
        .toString();
  }
}

class $JournalEntriesTable extends JournalEntries
    with TableInfo<$JournalEntriesTable, JournalEntryRow> {
  @override
  final GeneratedDatabase attachedDatabase;
  final String? _alias;
  $JournalEntriesTable(this.attachedDatabase, [this._alias]);
  static const VerificationMeta _idMeta = const VerificationMeta('id');
  @override
  late final GeneratedColumn<String> id = GeneratedColumn<String>(
      'id', aliasedName, false,
      type: DriftSqlType.string, requiredDuringInsert: true);
  static const VerificationMeta _dateMeta = const VerificationMeta('date');
  @override
  late final GeneratedColumn<DateTime> date = GeneratedColumn<DateTime>(
      'date', aliasedName, false,
      type: DriftSqlType.dateTime, requiredDuringInsert: true);
  static const VerificationMeta _descriptionMeta =
      const VerificationMeta('description');
  @override
  late final GeneratedColumn<String> description = GeneratedColumn<String>(
      'description', aliasedName, false,
      type: DriftSqlType.string, requiredDuringInsert: true);
  static const VerificationMeta _referenceMeta =
      const VerificationMeta('reference');
  @override
  late final GeneratedColumn<String> reference = GeneratedColumn<String>(
      'reference', aliasedName, true,
      type: DriftSqlType.string, requiredDuringInsert: false);
  static const VerificationMeta _currencyMeta =
      const VerificationMeta('currency');
  @override
  late final GeneratedColumn<String> currency = GeneratedColumn<String>(
      'currency', aliasedName, false,
      type: DriftSqlType.string, requiredDuringInsert: true);
  @override
  List<GeneratedColumn> get $columns =>
      [id, date, description, reference, currency];
  @override
  String get aliasedName => _alias ?? actualTableName;
  @override
  String get actualTableName => $name;
  static const String $name = 'journal_entries';
  @override
  VerificationContext validateIntegrity(Insertable<JournalEntryRow> instance,
      {bool isInserting = false}) {
    final context = VerificationContext();
    final data = instance.toColumns(true);
    if (data.containsKey('id')) {
      context.handle(_idMeta, id.isAcceptableOrUnknown(data['id']!, _idMeta));
    } else if (isInserting) {
      context.missing(_idMeta);
    }
    if (data.containsKey('date')) {
      context.handle(
          _dateMeta, date.isAcceptableOrUnknown(data['date']!, _dateMeta));
    } else if (isInserting) {
      context.missing(_dateMeta);
    }
    if (data.containsKey('description')) {
      context.handle(
          _descriptionMeta,
          description.isAcceptableOrUnknown(
              data['description']!, _descriptionMeta));
    } else if (isInserting) {
      context.missing(_descriptionMeta);
    }
    if (data.containsKey('reference')) {
      context.handle(_referenceMeta,
          reference.isAcceptableOrUnknown(data['reference']!, _referenceMeta));
    }
    if (data.containsKey('currency')) {
      context.handle(_currencyMeta,
          currency.isAcceptableOrUnknown(data['currency']!, _currencyMeta));
    } else if (isInserting) {
      context.missing(_currencyMeta);
    }
    return context;
  }

  @override
  Set<GeneratedColumn> get $primaryKey => {id};
  @override
  JournalEntryRow map(Map<String, dynamic> data, {String? tablePrefix}) {
    final effectivePrefix = tablePrefix != null ? '$tablePrefix.' : '';
    return JournalEntryRow(
      id: attachedDatabase.typeMapping
          .read(DriftSqlType.string, data['${effectivePrefix}id'])!,
      date: attachedDatabase.typeMapping
          .read(DriftSqlType.dateTime, data['${effectivePrefix}date'])!,
      description: attachedDatabase.typeMapping
          .read(DriftSqlType.string, data['${effectivePrefix}description'])!,
      reference: attachedDatabase.typeMapping
          .read(DriftSqlType.string, data['${effectivePrefix}reference']),
      currency: attachedDatabase.typeMapping
          .read(DriftSqlType.string, data['${effectivePrefix}currency'])!,
    );
  }

  @override
  $JournalEntriesTable createAlias(String alias) {
    return $JournalEntriesTable(attachedDatabase, alias);
  }
}

class JournalEntryRow extends DataClass implements Insertable<JournalEntryRow> {
  final String id;
  final DateTime date;
  final String description;
  final String? reference;

  /// Currency of the whole entry. V1 is single-currency per book, so this is
  /// recorded once on the header and repeated on lines for query convenience.
  final String currency;
  const JournalEntryRow(
      {required this.id,
      required this.date,
      required this.description,
      this.reference,
      required this.currency});
  @override
  Map<String, Expression> toColumns(bool nullToAbsent) {
    final map = <String, Expression>{};
    map['id'] = Variable<String>(id);
    map['date'] = Variable<DateTime>(date);
    map['description'] = Variable<String>(description);
    if (!nullToAbsent || reference != null) {
      map['reference'] = Variable<String>(reference);
    }
    map['currency'] = Variable<String>(currency);
    return map;
  }

  JournalEntriesCompanion toCompanion(bool nullToAbsent) {
    return JournalEntriesCompanion(
      id: Value(id),
      date: Value(date),
      description: Value(description),
      reference: reference == null && nullToAbsent
          ? const Value.absent()
          : Value(reference),
      currency: Value(currency),
    );
  }

  factory JournalEntryRow.fromJson(Map<String, dynamic> json,
      {ValueSerializer? serializer}) {
    serializer ??= driftRuntimeOptions.defaultSerializer;
    return JournalEntryRow(
      id: serializer.fromJson<String>(json['id']),
      date: serializer.fromJson<DateTime>(json['date']),
      description: serializer.fromJson<String>(json['description']),
      reference: serializer.fromJson<String?>(json['reference']),
      currency: serializer.fromJson<String>(json['currency']),
    );
  }
  @override
  Map<String, dynamic> toJson({ValueSerializer? serializer}) {
    serializer ??= driftRuntimeOptions.defaultSerializer;
    return <String, dynamic>{
      'id': serializer.toJson<String>(id),
      'date': serializer.toJson<DateTime>(date),
      'description': serializer.toJson<String>(description),
      'reference': serializer.toJson<String?>(reference),
      'currency': serializer.toJson<String>(currency),
    };
  }

  JournalEntryRow copyWith(
          {String? id,
          DateTime? date,
          String? description,
          Value<String?> reference = const Value.absent(),
          String? currency}) =>
      JournalEntryRow(
        id: id ?? this.id,
        date: date ?? this.date,
        description: description ?? this.description,
        reference: reference.present ? reference.value : this.reference,
        currency: currency ?? this.currency,
      );
  JournalEntryRow copyWithCompanion(JournalEntriesCompanion data) {
    return JournalEntryRow(
      id: data.id.present ? data.id.value : this.id,
      date: data.date.present ? data.date.value : this.date,
      description:
          data.description.present ? data.description.value : this.description,
      reference: data.reference.present ? data.reference.value : this.reference,
      currency: data.currency.present ? data.currency.value : this.currency,
    );
  }

  @override
  String toString() {
    return (StringBuffer('JournalEntryRow(')
          ..write('id: $id, ')
          ..write('date: $date, ')
          ..write('description: $description, ')
          ..write('reference: $reference, ')
          ..write('currency: $currency')
          ..write(')'))
        .toString();
  }

  @override
  int get hashCode => Object.hash(id, date, description, reference, currency);
  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      (other is JournalEntryRow &&
          other.id == this.id &&
          other.date == this.date &&
          other.description == this.description &&
          other.reference == this.reference &&
          other.currency == this.currency);
}

class JournalEntriesCompanion extends UpdateCompanion<JournalEntryRow> {
  final Value<String> id;
  final Value<DateTime> date;
  final Value<String> description;
  final Value<String?> reference;
  final Value<String> currency;
  final Value<int> rowid;
  const JournalEntriesCompanion({
    this.id = const Value.absent(),
    this.date = const Value.absent(),
    this.description = const Value.absent(),
    this.reference = const Value.absent(),
    this.currency = const Value.absent(),
    this.rowid = const Value.absent(),
  });
  JournalEntriesCompanion.insert({
    required String id,
    required DateTime date,
    required String description,
    this.reference = const Value.absent(),
    required String currency,
    this.rowid = const Value.absent(),
  })  : id = Value(id),
        date = Value(date),
        description = Value(description),
        currency = Value(currency);
  static Insertable<JournalEntryRow> custom({
    Expression<String>? id,
    Expression<DateTime>? date,
    Expression<String>? description,
    Expression<String>? reference,
    Expression<String>? currency,
    Expression<int>? rowid,
  }) {
    return RawValuesInsertable({
      if (id != null) 'id': id,
      if (date != null) 'date': date,
      if (description != null) 'description': description,
      if (reference != null) 'reference': reference,
      if (currency != null) 'currency': currency,
      if (rowid != null) 'rowid': rowid,
    });
  }

  JournalEntriesCompanion copyWith(
      {Value<String>? id,
      Value<DateTime>? date,
      Value<String>? description,
      Value<String?>? reference,
      Value<String>? currency,
      Value<int>? rowid}) {
    return JournalEntriesCompanion(
      id: id ?? this.id,
      date: date ?? this.date,
      description: description ?? this.description,
      reference: reference ?? this.reference,
      currency: currency ?? this.currency,
      rowid: rowid ?? this.rowid,
    );
  }

  @override
  Map<String, Expression> toColumns(bool nullToAbsent) {
    final map = <String, Expression>{};
    if (id.present) {
      map['id'] = Variable<String>(id.value);
    }
    if (date.present) {
      map['date'] = Variable<DateTime>(date.value);
    }
    if (description.present) {
      map['description'] = Variable<String>(description.value);
    }
    if (reference.present) {
      map['reference'] = Variable<String>(reference.value);
    }
    if (currency.present) {
      map['currency'] = Variable<String>(currency.value);
    }
    if (rowid.present) {
      map['rowid'] = Variable<int>(rowid.value);
    }
    return map;
  }

  @override
  String toString() {
    return (StringBuffer('JournalEntriesCompanion(')
          ..write('id: $id, ')
          ..write('date: $date, ')
          ..write('description: $description, ')
          ..write('reference: $reference, ')
          ..write('currency: $currency, ')
          ..write('rowid: $rowid')
          ..write(')'))
        .toString();
  }
}

class $JournalLinesTable extends JournalLines
    with TableInfo<$JournalLinesTable, JournalLineRow> {
  @override
  final GeneratedDatabase attachedDatabase;
  final String? _alias;
  $JournalLinesTable(this.attachedDatabase, [this._alias]);
  static const VerificationMeta _idMeta = const VerificationMeta('id');
  @override
  late final GeneratedColumn<int> id = GeneratedColumn<int>(
      'id', aliasedName, false,
      hasAutoIncrement: true,
      type: DriftSqlType.int,
      requiredDuringInsert: false,
      defaultConstraints:
          GeneratedColumn.constraintIsAlways('PRIMARY KEY AUTOINCREMENT'));
  static const VerificationMeta _journalEntryIdMeta =
      const VerificationMeta('journalEntryId');
  @override
  late final GeneratedColumn<String> journalEntryId = GeneratedColumn<String>(
      'journal_entry_id', aliasedName, false,
      type: DriftSqlType.string, requiredDuringInsert: true);
  static const VerificationMeta _accountIdMeta =
      const VerificationMeta('accountId');
  @override
  late final GeneratedColumn<String> accountId = GeneratedColumn<String>(
      'account_id', aliasedName, false,
      type: DriftSqlType.string, requiredDuringInsert: true);
  static const VerificationMeta _debitMinorUnitsMeta =
      const VerificationMeta('debitMinorUnits');
  @override
  late final GeneratedColumn<int> debitMinorUnits = GeneratedColumn<int>(
      'debit_minor_units', aliasedName, false,
      type: DriftSqlType.int,
      requiredDuringInsert: false,
      defaultValue: const Constant(0));
  static const VerificationMeta _creditMinorUnitsMeta =
      const VerificationMeta('creditMinorUnits');
  @override
  late final GeneratedColumn<int> creditMinorUnits = GeneratedColumn<int>(
      'credit_minor_units', aliasedName, false,
      type: DriftSqlType.int,
      requiredDuringInsert: false,
      defaultValue: const Constant(0));
  static const VerificationMeta _currencyMeta =
      const VerificationMeta('currency');
  @override
  late final GeneratedColumn<String> currency = GeneratedColumn<String>(
      'currency', aliasedName, false,
      type: DriftSqlType.string, requiredDuringInsert: true);
  @override
  List<GeneratedColumn> get $columns => [
        id,
        journalEntryId,
        accountId,
        debitMinorUnits,
        creditMinorUnits,
        currency
      ];
  @override
  String get aliasedName => _alias ?? actualTableName;
  @override
  String get actualTableName => $name;
  static const String $name = 'journal_lines';
  @override
  VerificationContext validateIntegrity(Insertable<JournalLineRow> instance,
      {bool isInserting = false}) {
    final context = VerificationContext();
    final data = instance.toColumns(true);
    if (data.containsKey('id')) {
      context.handle(_idMeta, id.isAcceptableOrUnknown(data['id']!, _idMeta));
    }
    if (data.containsKey('journal_entry_id')) {
      context.handle(
          _journalEntryIdMeta,
          journalEntryId.isAcceptableOrUnknown(
              data['journal_entry_id']!, _journalEntryIdMeta));
    } else if (isInserting) {
      context.missing(_journalEntryIdMeta);
    }
    if (data.containsKey('account_id')) {
      context.handle(_accountIdMeta,
          accountId.isAcceptableOrUnknown(data['account_id']!, _accountIdMeta));
    } else if (isInserting) {
      context.missing(_accountIdMeta);
    }
    if (data.containsKey('debit_minor_units')) {
      context.handle(
          _debitMinorUnitsMeta,
          debitMinorUnits.isAcceptableOrUnknown(
              data['debit_minor_units']!, _debitMinorUnitsMeta));
    }
    if (data.containsKey('credit_minor_units')) {
      context.handle(
          _creditMinorUnitsMeta,
          creditMinorUnits.isAcceptableOrUnknown(
              data['credit_minor_units']!, _creditMinorUnitsMeta));
    }
    if (data.containsKey('currency')) {
      context.handle(_currencyMeta,
          currency.isAcceptableOrUnknown(data['currency']!, _currencyMeta));
    } else if (isInserting) {
      context.missing(_currencyMeta);
    }
    return context;
  }

  @override
  Set<GeneratedColumn> get $primaryKey => {id};
  @override
  JournalLineRow map(Map<String, dynamic> data, {String? tablePrefix}) {
    final effectivePrefix = tablePrefix != null ? '$tablePrefix.' : '';
    return JournalLineRow(
      id: attachedDatabase.typeMapping
          .read(DriftSqlType.int, data['${effectivePrefix}id'])!,
      journalEntryId: attachedDatabase.typeMapping.read(
          DriftSqlType.string, data['${effectivePrefix}journal_entry_id'])!,
      accountId: attachedDatabase.typeMapping
          .read(DriftSqlType.string, data['${effectivePrefix}account_id'])!,
      debitMinorUnits: attachedDatabase.typeMapping
          .read(DriftSqlType.int, data['${effectivePrefix}debit_minor_units'])!,
      creditMinorUnits: attachedDatabase.typeMapping.read(
          DriftSqlType.int, data['${effectivePrefix}credit_minor_units'])!,
      currency: attachedDatabase.typeMapping
          .read(DriftSqlType.string, data['${effectivePrefix}currency'])!,
    );
  }

  @override
  $JournalLinesTable createAlias(String alias) {
    return $JournalLinesTable(attachedDatabase, alias);
  }
}

class JournalLineRow extends DataClass implements Insertable<JournalLineRow> {
  final int id;

  /// Insertion order, used to reconstruct the entry's line order.
  final String journalEntryId;
  final String accountId;

  /// Amount in minor units, for example paisa. **Integer, never REAL.**
  ///
  /// A REAL column would reintroduce binary floating point at the storage
  /// boundary and silently corrupt amounts. This is the single most important
  /// column type in the schema.
  final int debitMinorUnits;
  final int creditMinorUnits;
  final String currency;
  const JournalLineRow(
      {required this.id,
      required this.journalEntryId,
      required this.accountId,
      required this.debitMinorUnits,
      required this.creditMinorUnits,
      required this.currency});
  @override
  Map<String, Expression> toColumns(bool nullToAbsent) {
    final map = <String, Expression>{};
    map['id'] = Variable<int>(id);
    map['journal_entry_id'] = Variable<String>(journalEntryId);
    map['account_id'] = Variable<String>(accountId);
    map['debit_minor_units'] = Variable<int>(debitMinorUnits);
    map['credit_minor_units'] = Variable<int>(creditMinorUnits);
    map['currency'] = Variable<String>(currency);
    return map;
  }

  JournalLinesCompanion toCompanion(bool nullToAbsent) {
    return JournalLinesCompanion(
      id: Value(id),
      journalEntryId: Value(journalEntryId),
      accountId: Value(accountId),
      debitMinorUnits: Value(debitMinorUnits),
      creditMinorUnits: Value(creditMinorUnits),
      currency: Value(currency),
    );
  }

  factory JournalLineRow.fromJson(Map<String, dynamic> json,
      {ValueSerializer? serializer}) {
    serializer ??= driftRuntimeOptions.defaultSerializer;
    return JournalLineRow(
      id: serializer.fromJson<int>(json['id']),
      journalEntryId: serializer.fromJson<String>(json['journalEntryId']),
      accountId: serializer.fromJson<String>(json['accountId']),
      debitMinorUnits: serializer.fromJson<int>(json['debitMinorUnits']),
      creditMinorUnits: serializer.fromJson<int>(json['creditMinorUnits']),
      currency: serializer.fromJson<String>(json['currency']),
    );
  }
  @override
  Map<String, dynamic> toJson({ValueSerializer? serializer}) {
    serializer ??= driftRuntimeOptions.defaultSerializer;
    return <String, dynamic>{
      'id': serializer.toJson<int>(id),
      'journalEntryId': serializer.toJson<String>(journalEntryId),
      'accountId': serializer.toJson<String>(accountId),
      'debitMinorUnits': serializer.toJson<int>(debitMinorUnits),
      'creditMinorUnits': serializer.toJson<int>(creditMinorUnits),
      'currency': serializer.toJson<String>(currency),
    };
  }

  JournalLineRow copyWith(
          {int? id,
          String? journalEntryId,
          String? accountId,
          int? debitMinorUnits,
          int? creditMinorUnits,
          String? currency}) =>
      JournalLineRow(
        id: id ?? this.id,
        journalEntryId: journalEntryId ?? this.journalEntryId,
        accountId: accountId ?? this.accountId,
        debitMinorUnits: debitMinorUnits ?? this.debitMinorUnits,
        creditMinorUnits: creditMinorUnits ?? this.creditMinorUnits,
        currency: currency ?? this.currency,
      );
  JournalLineRow copyWithCompanion(JournalLinesCompanion data) {
    return JournalLineRow(
      id: data.id.present ? data.id.value : this.id,
      journalEntryId: data.journalEntryId.present
          ? data.journalEntryId.value
          : this.journalEntryId,
      accountId: data.accountId.present ? data.accountId.value : this.accountId,
      debitMinorUnits: data.debitMinorUnits.present
          ? data.debitMinorUnits.value
          : this.debitMinorUnits,
      creditMinorUnits: data.creditMinorUnits.present
          ? data.creditMinorUnits.value
          : this.creditMinorUnits,
      currency: data.currency.present ? data.currency.value : this.currency,
    );
  }

  @override
  String toString() {
    return (StringBuffer('JournalLineRow(')
          ..write('id: $id, ')
          ..write('journalEntryId: $journalEntryId, ')
          ..write('accountId: $accountId, ')
          ..write('debitMinorUnits: $debitMinorUnits, ')
          ..write('creditMinorUnits: $creditMinorUnits, ')
          ..write('currency: $currency')
          ..write(')'))
        .toString();
  }

  @override
  int get hashCode => Object.hash(id, journalEntryId, accountId,
      debitMinorUnits, creditMinorUnits, currency);
  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      (other is JournalLineRow &&
          other.id == this.id &&
          other.journalEntryId == this.journalEntryId &&
          other.accountId == this.accountId &&
          other.debitMinorUnits == this.debitMinorUnits &&
          other.creditMinorUnits == this.creditMinorUnits &&
          other.currency == this.currency);
}

class JournalLinesCompanion extends UpdateCompanion<JournalLineRow> {
  final Value<int> id;
  final Value<String> journalEntryId;
  final Value<String> accountId;
  final Value<int> debitMinorUnits;
  final Value<int> creditMinorUnits;
  final Value<String> currency;
  const JournalLinesCompanion({
    this.id = const Value.absent(),
    this.journalEntryId = const Value.absent(),
    this.accountId = const Value.absent(),
    this.debitMinorUnits = const Value.absent(),
    this.creditMinorUnits = const Value.absent(),
    this.currency = const Value.absent(),
  });
  JournalLinesCompanion.insert({
    this.id = const Value.absent(),
    required String journalEntryId,
    required String accountId,
    this.debitMinorUnits = const Value.absent(),
    this.creditMinorUnits = const Value.absent(),
    required String currency,
  })  : journalEntryId = Value(journalEntryId),
        accountId = Value(accountId),
        currency = Value(currency);
  static Insertable<JournalLineRow> custom({
    Expression<int>? id,
    Expression<String>? journalEntryId,
    Expression<String>? accountId,
    Expression<int>? debitMinorUnits,
    Expression<int>? creditMinorUnits,
    Expression<String>? currency,
  }) {
    return RawValuesInsertable({
      if (id != null) 'id': id,
      if (journalEntryId != null) 'journal_entry_id': journalEntryId,
      if (accountId != null) 'account_id': accountId,
      if (debitMinorUnits != null) 'debit_minor_units': debitMinorUnits,
      if (creditMinorUnits != null) 'credit_minor_units': creditMinorUnits,
      if (currency != null) 'currency': currency,
    });
  }

  JournalLinesCompanion copyWith(
      {Value<int>? id,
      Value<String>? journalEntryId,
      Value<String>? accountId,
      Value<int>? debitMinorUnits,
      Value<int>? creditMinorUnits,
      Value<String>? currency}) {
    return JournalLinesCompanion(
      id: id ?? this.id,
      journalEntryId: journalEntryId ?? this.journalEntryId,
      accountId: accountId ?? this.accountId,
      debitMinorUnits: debitMinorUnits ?? this.debitMinorUnits,
      creditMinorUnits: creditMinorUnits ?? this.creditMinorUnits,
      currency: currency ?? this.currency,
    );
  }

  @override
  Map<String, Expression> toColumns(bool nullToAbsent) {
    final map = <String, Expression>{};
    if (id.present) {
      map['id'] = Variable<int>(id.value);
    }
    if (journalEntryId.present) {
      map['journal_entry_id'] = Variable<String>(journalEntryId.value);
    }
    if (accountId.present) {
      map['account_id'] = Variable<String>(accountId.value);
    }
    if (debitMinorUnits.present) {
      map['debit_minor_units'] = Variable<int>(debitMinorUnits.value);
    }
    if (creditMinorUnits.present) {
      map['credit_minor_units'] = Variable<int>(creditMinorUnits.value);
    }
    if (currency.present) {
      map['currency'] = Variable<String>(currency.value);
    }
    return map;
  }

  @override
  String toString() {
    return (StringBuffer('JournalLinesCompanion(')
          ..write('id: $id, ')
          ..write('journalEntryId: $journalEntryId, ')
          ..write('accountId: $accountId, ')
          ..write('debitMinorUnits: $debitMinorUnits, ')
          ..write('creditMinorUnits: $creditMinorUnits, ')
          ..write('currency: $currency')
          ..write(')'))
        .toString();
  }
}

class $DocumentSequencesTable extends DocumentSequences
    with TableInfo<$DocumentSequencesTable, DocumentSequenceRow> {
  @override
  final GeneratedDatabase attachedDatabase;
  final String? _alias;
  $DocumentSequencesTable(this.attachedDatabase, [this._alias]);
  static const VerificationMeta _documentTypeMeta =
      const VerificationMeta('documentType');
  @override
  late final GeneratedColumn<String> documentType = GeneratedColumn<String>(
      'document_type', aliasedName, false,
      type: DriftSqlType.string, requiredDuringInsert: true);
  static const VerificationMeta _fiscalYearLabelMeta =
      const VerificationMeta('fiscalYearLabel');
  @override
  late final GeneratedColumn<String> fiscalYearLabel = GeneratedColumn<String>(
      'fiscal_year_label', aliasedName, false,
      type: DriftSqlType.string, requiredDuringInsert: true);
  static const VerificationMeta _lastSequenceMeta =
      const VerificationMeta('lastSequence');
  @override
  late final GeneratedColumn<int> lastSequence = GeneratedColumn<int>(
      'last_sequence', aliasedName, false,
      type: DriftSqlType.int,
      requiredDuringInsert: false,
      defaultValue: const Constant(0));
  @override
  List<GeneratedColumn> get $columns =>
      [documentType, fiscalYearLabel, lastSequence];
  @override
  String get aliasedName => _alias ?? actualTableName;
  @override
  String get actualTableName => $name;
  static const String $name = 'document_sequences';
  @override
  VerificationContext validateIntegrity(
      Insertable<DocumentSequenceRow> instance,
      {bool isInserting = false}) {
    final context = VerificationContext();
    final data = instance.toColumns(true);
    if (data.containsKey('document_type')) {
      context.handle(
          _documentTypeMeta,
          documentType.isAcceptableOrUnknown(
              data['document_type']!, _documentTypeMeta));
    } else if (isInserting) {
      context.missing(_documentTypeMeta);
    }
    if (data.containsKey('fiscal_year_label')) {
      context.handle(
          _fiscalYearLabelMeta,
          fiscalYearLabel.isAcceptableOrUnknown(
              data['fiscal_year_label']!, _fiscalYearLabelMeta));
    } else if (isInserting) {
      context.missing(_fiscalYearLabelMeta);
    }
    if (data.containsKey('last_sequence')) {
      context.handle(
          _lastSequenceMeta,
          lastSequence.isAcceptableOrUnknown(
              data['last_sequence']!, _lastSequenceMeta));
    }
    return context;
  }

  @override
  Set<GeneratedColumn> get $primaryKey => {documentType, fiscalYearLabel};
  @override
  DocumentSequenceRow map(Map<String, dynamic> data, {String? tablePrefix}) {
    final effectivePrefix = tablePrefix != null ? '$tablePrefix.' : '';
    return DocumentSequenceRow(
      documentType: attachedDatabase.typeMapping
          .read(DriftSqlType.string, data['${effectivePrefix}document_type'])!,
      fiscalYearLabel: attachedDatabase.typeMapping.read(
          DriftSqlType.string, data['${effectivePrefix}fiscal_year_label'])!,
      lastSequence: attachedDatabase.typeMapping
          .read(DriftSqlType.int, data['${effectivePrefix}last_sequence'])!,
    );
  }

  @override
  $DocumentSequencesTable createAlias(String alias) {
    return $DocumentSequencesTable(attachedDatabase, alias);
  }
}

class DocumentSequenceRow extends DataClass
    implements Insertable<DocumentSequenceRow> {
  /// The `DocumentType` name, for example `invoice`.
  final String documentType;

  /// The fiscal year label, for example `FY 2082/83`.
  final String fiscalYearLabel;

  /// Highest serial already allocated. Never negative.
  final int lastSequence;
  const DocumentSequenceRow(
      {required this.documentType,
      required this.fiscalYearLabel,
      required this.lastSequence});
  @override
  Map<String, Expression> toColumns(bool nullToAbsent) {
    final map = <String, Expression>{};
    map['document_type'] = Variable<String>(documentType);
    map['fiscal_year_label'] = Variable<String>(fiscalYearLabel);
    map['last_sequence'] = Variable<int>(lastSequence);
    return map;
  }

  DocumentSequencesCompanion toCompanion(bool nullToAbsent) {
    return DocumentSequencesCompanion(
      documentType: Value(documentType),
      fiscalYearLabel: Value(fiscalYearLabel),
      lastSequence: Value(lastSequence),
    );
  }

  factory DocumentSequenceRow.fromJson(Map<String, dynamic> json,
      {ValueSerializer? serializer}) {
    serializer ??= driftRuntimeOptions.defaultSerializer;
    return DocumentSequenceRow(
      documentType: serializer.fromJson<String>(json['documentType']),
      fiscalYearLabel: serializer.fromJson<String>(json['fiscalYearLabel']),
      lastSequence: serializer.fromJson<int>(json['lastSequence']),
    );
  }
  @override
  Map<String, dynamic> toJson({ValueSerializer? serializer}) {
    serializer ??= driftRuntimeOptions.defaultSerializer;
    return <String, dynamic>{
      'documentType': serializer.toJson<String>(documentType),
      'fiscalYearLabel': serializer.toJson<String>(fiscalYearLabel),
      'lastSequence': serializer.toJson<int>(lastSequence),
    };
  }

  DocumentSequenceRow copyWith(
          {String? documentType, String? fiscalYearLabel, int? lastSequence}) =>
      DocumentSequenceRow(
        documentType: documentType ?? this.documentType,
        fiscalYearLabel: fiscalYearLabel ?? this.fiscalYearLabel,
        lastSequence: lastSequence ?? this.lastSequence,
      );
  DocumentSequenceRow copyWithCompanion(DocumentSequencesCompanion data) {
    return DocumentSequenceRow(
      documentType: data.documentType.present
          ? data.documentType.value
          : this.documentType,
      fiscalYearLabel: data.fiscalYearLabel.present
          ? data.fiscalYearLabel.value
          : this.fiscalYearLabel,
      lastSequence: data.lastSequence.present
          ? data.lastSequence.value
          : this.lastSequence,
    );
  }

  @override
  String toString() {
    return (StringBuffer('DocumentSequenceRow(')
          ..write('documentType: $documentType, ')
          ..write('fiscalYearLabel: $fiscalYearLabel, ')
          ..write('lastSequence: $lastSequence')
          ..write(')'))
        .toString();
  }

  @override
  int get hashCode => Object.hash(documentType, fiscalYearLabel, lastSequence);
  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      (other is DocumentSequenceRow &&
          other.documentType == this.documentType &&
          other.fiscalYearLabel == this.fiscalYearLabel &&
          other.lastSequence == this.lastSequence);
}

class DocumentSequencesCompanion extends UpdateCompanion<DocumentSequenceRow> {
  final Value<String> documentType;
  final Value<String> fiscalYearLabel;
  final Value<int> lastSequence;
  final Value<int> rowid;
  const DocumentSequencesCompanion({
    this.documentType = const Value.absent(),
    this.fiscalYearLabel = const Value.absent(),
    this.lastSequence = const Value.absent(),
    this.rowid = const Value.absent(),
  });
  DocumentSequencesCompanion.insert({
    required String documentType,
    required String fiscalYearLabel,
    this.lastSequence = const Value.absent(),
    this.rowid = const Value.absent(),
  })  : documentType = Value(documentType),
        fiscalYearLabel = Value(fiscalYearLabel);
  static Insertable<DocumentSequenceRow> custom({
    Expression<String>? documentType,
    Expression<String>? fiscalYearLabel,
    Expression<int>? lastSequence,
    Expression<int>? rowid,
  }) {
    return RawValuesInsertable({
      if (documentType != null) 'document_type': documentType,
      if (fiscalYearLabel != null) 'fiscal_year_label': fiscalYearLabel,
      if (lastSequence != null) 'last_sequence': lastSequence,
      if (rowid != null) 'rowid': rowid,
    });
  }

  DocumentSequencesCompanion copyWith(
      {Value<String>? documentType,
      Value<String>? fiscalYearLabel,
      Value<int>? lastSequence,
      Value<int>? rowid}) {
    return DocumentSequencesCompanion(
      documentType: documentType ?? this.documentType,
      fiscalYearLabel: fiscalYearLabel ?? this.fiscalYearLabel,
      lastSequence: lastSequence ?? this.lastSequence,
      rowid: rowid ?? this.rowid,
    );
  }

  @override
  Map<String, Expression> toColumns(bool nullToAbsent) {
    final map = <String, Expression>{};
    if (documentType.present) {
      map['document_type'] = Variable<String>(documentType.value);
    }
    if (fiscalYearLabel.present) {
      map['fiscal_year_label'] = Variable<String>(fiscalYearLabel.value);
    }
    if (lastSequence.present) {
      map['last_sequence'] = Variable<int>(lastSequence.value);
    }
    if (rowid.present) {
      map['rowid'] = Variable<int>(rowid.value);
    }
    return map;
  }

  @override
  String toString() {
    return (StringBuffer('DocumentSequencesCompanion(')
          ..write('documentType: $documentType, ')
          ..write('fiscalYearLabel: $fiscalYearLabel, ')
          ..write('lastSequence: $lastSequence, ')
          ..write('rowid: $rowid')
          ..write(')'))
        .toString();
  }
}

class $CustomersTable extends Customers
    with TableInfo<$CustomersTable, CustomerRow> {
  @override
  final GeneratedDatabase attachedDatabase;
  final String? _alias;
  $CustomersTable(this.attachedDatabase, [this._alias]);
  static const VerificationMeta _idMeta = const VerificationMeta('id');
  @override
  late final GeneratedColumn<String> id = GeneratedColumn<String>(
      'id', aliasedName, false,
      type: DriftSqlType.string, requiredDuringInsert: true);
  static const VerificationMeta _nameMeta = const VerificationMeta('name');
  @override
  late final GeneratedColumn<String> name = GeneratedColumn<String>(
      'name', aliasedName, false,
      type: DriftSqlType.string, requiredDuringInsert: true);
  static const VerificationMeta _panNumberMeta =
      const VerificationMeta('panNumber');
  @override
  late final GeneratedColumn<String> panNumber = GeneratedColumn<String>(
      'pan_number', aliasedName, true,
      type: DriftSqlType.string, requiredDuringInsert: false);
  static const VerificationMeta _phoneMeta = const VerificationMeta('phone');
  @override
  late final GeneratedColumn<String> phone = GeneratedColumn<String>(
      'phone', aliasedName, true,
      type: DriftSqlType.string, requiredDuringInsert: false);
  static const VerificationMeta _addressMeta =
      const VerificationMeta('address');
  @override
  late final GeneratedColumn<String> address = GeneratedColumn<String>(
      'address', aliasedName, true,
      type: DriftSqlType.string, requiredDuringInsert: false);
  @override
  List<GeneratedColumn> get $columns => [id, name, panNumber, phone, address];
  @override
  String get aliasedName => _alias ?? actualTableName;
  @override
  String get actualTableName => $name;
  static const String $name = 'customers';
  @override
  VerificationContext validateIntegrity(Insertable<CustomerRow> instance,
      {bool isInserting = false}) {
    final context = VerificationContext();
    final data = instance.toColumns(true);
    if (data.containsKey('id')) {
      context.handle(_idMeta, id.isAcceptableOrUnknown(data['id']!, _idMeta));
    } else if (isInserting) {
      context.missing(_idMeta);
    }
    if (data.containsKey('name')) {
      context.handle(
          _nameMeta, name.isAcceptableOrUnknown(data['name']!, _nameMeta));
    } else if (isInserting) {
      context.missing(_nameMeta);
    }
    if (data.containsKey('pan_number')) {
      context.handle(_panNumberMeta,
          panNumber.isAcceptableOrUnknown(data['pan_number']!, _panNumberMeta));
    }
    if (data.containsKey('phone')) {
      context.handle(
          _phoneMeta, phone.isAcceptableOrUnknown(data['phone']!, _phoneMeta));
    }
    if (data.containsKey('address')) {
      context.handle(_addressMeta,
          address.isAcceptableOrUnknown(data['address']!, _addressMeta));
    }
    return context;
  }

  @override
  Set<GeneratedColumn> get $primaryKey => {id};
  @override
  CustomerRow map(Map<String, dynamic> data, {String? tablePrefix}) {
    final effectivePrefix = tablePrefix != null ? '$tablePrefix.' : '';
    return CustomerRow(
      id: attachedDatabase.typeMapping
          .read(DriftSqlType.string, data['${effectivePrefix}id'])!,
      name: attachedDatabase.typeMapping
          .read(DriftSqlType.string, data['${effectivePrefix}name'])!,
      panNumber: attachedDatabase.typeMapping
          .read(DriftSqlType.string, data['${effectivePrefix}pan_number']),
      phone: attachedDatabase.typeMapping
          .read(DriftSqlType.string, data['${effectivePrefix}phone']),
      address: attachedDatabase.typeMapping
          .read(DriftSqlType.string, data['${effectivePrefix}address']),
    );
  }

  @override
  $CustomersTable createAlias(String alias) {
    return $CustomersTable(attachedDatabase, alias);
  }
}

class CustomerRow extends DataClass implements Insertable<CustomerRow> {
  final String id;
  final String name;
  final String? panNumber;
  final String? phone;
  final String? address;
  const CustomerRow(
      {required this.id,
      required this.name,
      this.panNumber,
      this.phone,
      this.address});
  @override
  Map<String, Expression> toColumns(bool nullToAbsent) {
    final map = <String, Expression>{};
    map['id'] = Variable<String>(id);
    map['name'] = Variable<String>(name);
    if (!nullToAbsent || panNumber != null) {
      map['pan_number'] = Variable<String>(panNumber);
    }
    if (!nullToAbsent || phone != null) {
      map['phone'] = Variable<String>(phone);
    }
    if (!nullToAbsent || address != null) {
      map['address'] = Variable<String>(address);
    }
    return map;
  }

  CustomersCompanion toCompanion(bool nullToAbsent) {
    return CustomersCompanion(
      id: Value(id),
      name: Value(name),
      panNumber: panNumber == null && nullToAbsent
          ? const Value.absent()
          : Value(panNumber),
      phone:
          phone == null && nullToAbsent ? const Value.absent() : Value(phone),
      address: address == null && nullToAbsent
          ? const Value.absent()
          : Value(address),
    );
  }

  factory CustomerRow.fromJson(Map<String, dynamic> json,
      {ValueSerializer? serializer}) {
    serializer ??= driftRuntimeOptions.defaultSerializer;
    return CustomerRow(
      id: serializer.fromJson<String>(json['id']),
      name: serializer.fromJson<String>(json['name']),
      panNumber: serializer.fromJson<String?>(json['panNumber']),
      phone: serializer.fromJson<String?>(json['phone']),
      address: serializer.fromJson<String?>(json['address']),
    );
  }
  @override
  Map<String, dynamic> toJson({ValueSerializer? serializer}) {
    serializer ??= driftRuntimeOptions.defaultSerializer;
    return <String, dynamic>{
      'id': serializer.toJson<String>(id),
      'name': serializer.toJson<String>(name),
      'panNumber': serializer.toJson<String?>(panNumber),
      'phone': serializer.toJson<String?>(phone),
      'address': serializer.toJson<String?>(address),
    };
  }

  CustomerRow copyWith(
          {String? id,
          String? name,
          Value<String?> panNumber = const Value.absent(),
          Value<String?> phone = const Value.absent(),
          Value<String?> address = const Value.absent()}) =>
      CustomerRow(
        id: id ?? this.id,
        name: name ?? this.name,
        panNumber: panNumber.present ? panNumber.value : this.panNumber,
        phone: phone.present ? phone.value : this.phone,
        address: address.present ? address.value : this.address,
      );
  CustomerRow copyWithCompanion(CustomersCompanion data) {
    return CustomerRow(
      id: data.id.present ? data.id.value : this.id,
      name: data.name.present ? data.name.value : this.name,
      panNumber: data.panNumber.present ? data.panNumber.value : this.panNumber,
      phone: data.phone.present ? data.phone.value : this.phone,
      address: data.address.present ? data.address.value : this.address,
    );
  }

  @override
  String toString() {
    return (StringBuffer('CustomerRow(')
          ..write('id: $id, ')
          ..write('name: $name, ')
          ..write('panNumber: $panNumber, ')
          ..write('phone: $phone, ')
          ..write('address: $address')
          ..write(')'))
        .toString();
  }

  @override
  int get hashCode => Object.hash(id, name, panNumber, phone, address);
  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      (other is CustomerRow &&
          other.id == this.id &&
          other.name == this.name &&
          other.panNumber == this.panNumber &&
          other.phone == this.phone &&
          other.address == this.address);
}

class CustomersCompanion extends UpdateCompanion<CustomerRow> {
  final Value<String> id;
  final Value<String> name;
  final Value<String?> panNumber;
  final Value<String?> phone;
  final Value<String?> address;
  final Value<int> rowid;
  const CustomersCompanion({
    this.id = const Value.absent(),
    this.name = const Value.absent(),
    this.panNumber = const Value.absent(),
    this.phone = const Value.absent(),
    this.address = const Value.absent(),
    this.rowid = const Value.absent(),
  });
  CustomersCompanion.insert({
    required String id,
    required String name,
    this.panNumber = const Value.absent(),
    this.phone = const Value.absent(),
    this.address = const Value.absent(),
    this.rowid = const Value.absent(),
  })  : id = Value(id),
        name = Value(name);
  static Insertable<CustomerRow> custom({
    Expression<String>? id,
    Expression<String>? name,
    Expression<String>? panNumber,
    Expression<String>? phone,
    Expression<String>? address,
    Expression<int>? rowid,
  }) {
    return RawValuesInsertable({
      if (id != null) 'id': id,
      if (name != null) 'name': name,
      if (panNumber != null) 'pan_number': panNumber,
      if (phone != null) 'phone': phone,
      if (address != null) 'address': address,
      if (rowid != null) 'rowid': rowid,
    });
  }

  CustomersCompanion copyWith(
      {Value<String>? id,
      Value<String>? name,
      Value<String?>? panNumber,
      Value<String?>? phone,
      Value<String?>? address,
      Value<int>? rowid}) {
    return CustomersCompanion(
      id: id ?? this.id,
      name: name ?? this.name,
      panNumber: panNumber ?? this.panNumber,
      phone: phone ?? this.phone,
      address: address ?? this.address,
      rowid: rowid ?? this.rowid,
    );
  }

  @override
  Map<String, Expression> toColumns(bool nullToAbsent) {
    final map = <String, Expression>{};
    if (id.present) {
      map['id'] = Variable<String>(id.value);
    }
    if (name.present) {
      map['name'] = Variable<String>(name.value);
    }
    if (panNumber.present) {
      map['pan_number'] = Variable<String>(panNumber.value);
    }
    if (phone.present) {
      map['phone'] = Variable<String>(phone.value);
    }
    if (address.present) {
      map['address'] = Variable<String>(address.value);
    }
    if (rowid.present) {
      map['rowid'] = Variable<int>(rowid.value);
    }
    return map;
  }

  @override
  String toString() {
    return (StringBuffer('CustomersCompanion(')
          ..write('id: $id, ')
          ..write('name: $name, ')
          ..write('panNumber: $panNumber, ')
          ..write('phone: $phone, ')
          ..write('address: $address, ')
          ..write('rowid: $rowid')
          ..write(')'))
        .toString();
  }
}

class $InvoicesTable extends Invoices
    with TableInfo<$InvoicesTable, InvoiceRow> {
  @override
  final GeneratedDatabase attachedDatabase;
  final String? _alias;
  $InvoicesTable(this.attachedDatabase, [this._alias]);
  static const VerificationMeta _idMeta = const VerificationMeta('id');
  @override
  late final GeneratedColumn<String> id = GeneratedColumn<String>(
      'id', aliasedName, false,
      type: DriftSqlType.string, requiredDuringInsert: true);
  static const VerificationMeta _numberMeta = const VerificationMeta('number');
  @override
  late final GeneratedColumn<String> number = GeneratedColumn<String>(
      'number', aliasedName, false,
      type: DriftSqlType.string,
      requiredDuringInsert: true,
      defaultConstraints: GeneratedColumn.constraintIsAlways('UNIQUE'));
  static const VerificationMeta _sequenceMeta =
      const VerificationMeta('sequence');
  @override
  late final GeneratedColumn<int> sequence = GeneratedColumn<int>(
      'sequence', aliasedName, false,
      type: DriftSqlType.int, requiredDuringInsert: true);
  static const VerificationMeta _fiscalYearLabelMeta =
      const VerificationMeta('fiscalYearLabel');
  @override
  late final GeneratedColumn<String> fiscalYearLabel = GeneratedColumn<String>(
      'fiscal_year_label', aliasedName, false,
      type: DriftSqlType.string, requiredDuringInsert: true);
  static const VerificationMeta _customerIdMeta =
      const VerificationMeta('customerId');
  @override
  late final GeneratedColumn<String> customerId = GeneratedColumn<String>(
      'customer_id', aliasedName, false,
      type: DriftSqlType.string, requiredDuringInsert: true);
  static const VerificationMeta _issueDateMeta =
      const VerificationMeta('issueDate');
  @override
  late final GeneratedColumn<DateTime> issueDate = GeneratedColumn<DateTime>(
      'issue_date', aliasedName, false,
      type: DriftSqlType.dateTime, requiredDuringInsert: true);
  static const VerificationMeta _currencyMeta =
      const VerificationMeta('currency');
  @override
  late final GeneratedColumn<String> currency = GeneratedColumn<String>(
      'currency', aliasedName, false,
      type: DriftSqlType.string, requiredDuringInsert: true);
  static const VerificationMeta _vatRateBasisPointsMeta =
      const VerificationMeta('vatRateBasisPoints');
  @override
  late final GeneratedColumn<int> vatRateBasisPoints = GeneratedColumn<int>(
      'vat_rate_basis_points', aliasedName, false,
      type: DriftSqlType.int, requiredDuringInsert: true);
  static const VerificationMeta _subtotalMinorUnitsMeta =
      const VerificationMeta('subtotalMinorUnits');
  @override
  late final GeneratedColumn<int> subtotalMinorUnits = GeneratedColumn<int>(
      'subtotal_minor_units', aliasedName, false,
      type: DriftSqlType.int, requiredDuringInsert: true);
  static const VerificationMeta _vatMinorUnitsMeta =
      const VerificationMeta('vatMinorUnits');
  @override
  late final GeneratedColumn<int> vatMinorUnits = GeneratedColumn<int>(
      'vat_minor_units', aliasedName, false,
      type: DriftSqlType.int, requiredDuringInsert: true);
  static const VerificationMeta _totalMinorUnitsMeta =
      const VerificationMeta('totalMinorUnits');
  @override
  late final GeneratedColumn<int> totalMinorUnits = GeneratedColumn<int>(
      'total_minor_units', aliasedName, false,
      type: DriftSqlType.int, requiredDuringInsert: true);
  static const VerificationMeta _journalEntryIdMeta =
      const VerificationMeta('journalEntryId');
  @override
  late final GeneratedColumn<String> journalEntryId = GeneratedColumn<String>(
      'journal_entry_id', aliasedName, false,
      type: DriftSqlType.string, requiredDuringInsert: true);
  @override
  List<GeneratedColumn> get $columns => [
        id,
        number,
        sequence,
        fiscalYearLabel,
        customerId,
        issueDate,
        currency,
        vatRateBasisPoints,
        subtotalMinorUnits,
        vatMinorUnits,
        totalMinorUnits,
        journalEntryId
      ];
  @override
  String get aliasedName => _alias ?? actualTableName;
  @override
  String get actualTableName => $name;
  static const String $name = 'invoices';
  @override
  VerificationContext validateIntegrity(Insertable<InvoiceRow> instance,
      {bool isInserting = false}) {
    final context = VerificationContext();
    final data = instance.toColumns(true);
    if (data.containsKey('id')) {
      context.handle(_idMeta, id.isAcceptableOrUnknown(data['id']!, _idMeta));
    } else if (isInserting) {
      context.missing(_idMeta);
    }
    if (data.containsKey('number')) {
      context.handle(_numberMeta,
          number.isAcceptableOrUnknown(data['number']!, _numberMeta));
    } else if (isInserting) {
      context.missing(_numberMeta);
    }
    if (data.containsKey('sequence')) {
      context.handle(_sequenceMeta,
          sequence.isAcceptableOrUnknown(data['sequence']!, _sequenceMeta));
    } else if (isInserting) {
      context.missing(_sequenceMeta);
    }
    if (data.containsKey('fiscal_year_label')) {
      context.handle(
          _fiscalYearLabelMeta,
          fiscalYearLabel.isAcceptableOrUnknown(
              data['fiscal_year_label']!, _fiscalYearLabelMeta));
    } else if (isInserting) {
      context.missing(_fiscalYearLabelMeta);
    }
    if (data.containsKey('customer_id')) {
      context.handle(
          _customerIdMeta,
          customerId.isAcceptableOrUnknown(
              data['customer_id']!, _customerIdMeta));
    } else if (isInserting) {
      context.missing(_customerIdMeta);
    }
    if (data.containsKey('issue_date')) {
      context.handle(_issueDateMeta,
          issueDate.isAcceptableOrUnknown(data['issue_date']!, _issueDateMeta));
    } else if (isInserting) {
      context.missing(_issueDateMeta);
    }
    if (data.containsKey('currency')) {
      context.handle(_currencyMeta,
          currency.isAcceptableOrUnknown(data['currency']!, _currencyMeta));
    } else if (isInserting) {
      context.missing(_currencyMeta);
    }
    if (data.containsKey('vat_rate_basis_points')) {
      context.handle(
          _vatRateBasisPointsMeta,
          vatRateBasisPoints.isAcceptableOrUnknown(
              data['vat_rate_basis_points']!, _vatRateBasisPointsMeta));
    } else if (isInserting) {
      context.missing(_vatRateBasisPointsMeta);
    }
    if (data.containsKey('subtotal_minor_units')) {
      context.handle(
          _subtotalMinorUnitsMeta,
          subtotalMinorUnits.isAcceptableOrUnknown(
              data['subtotal_minor_units']!, _subtotalMinorUnitsMeta));
    } else if (isInserting) {
      context.missing(_subtotalMinorUnitsMeta);
    }
    if (data.containsKey('vat_minor_units')) {
      context.handle(
          _vatMinorUnitsMeta,
          vatMinorUnits.isAcceptableOrUnknown(
              data['vat_minor_units']!, _vatMinorUnitsMeta));
    } else if (isInserting) {
      context.missing(_vatMinorUnitsMeta);
    }
    if (data.containsKey('total_minor_units')) {
      context.handle(
          _totalMinorUnitsMeta,
          totalMinorUnits.isAcceptableOrUnknown(
              data['total_minor_units']!, _totalMinorUnitsMeta));
    } else if (isInserting) {
      context.missing(_totalMinorUnitsMeta);
    }
    if (data.containsKey('journal_entry_id')) {
      context.handle(
          _journalEntryIdMeta,
          journalEntryId.isAcceptableOrUnknown(
              data['journal_entry_id']!, _journalEntryIdMeta));
    } else if (isInserting) {
      context.missing(_journalEntryIdMeta);
    }
    return context;
  }

  @override
  Set<GeneratedColumn> get $primaryKey => {id};
  @override
  InvoiceRow map(Map<String, dynamic> data, {String? tablePrefix}) {
    final effectivePrefix = tablePrefix != null ? '$tablePrefix.' : '';
    return InvoiceRow(
      id: attachedDatabase.typeMapping
          .read(DriftSqlType.string, data['${effectivePrefix}id'])!,
      number: attachedDatabase.typeMapping
          .read(DriftSqlType.string, data['${effectivePrefix}number'])!,
      sequence: attachedDatabase.typeMapping
          .read(DriftSqlType.int, data['${effectivePrefix}sequence'])!,
      fiscalYearLabel: attachedDatabase.typeMapping.read(
          DriftSqlType.string, data['${effectivePrefix}fiscal_year_label'])!,
      customerId: attachedDatabase.typeMapping
          .read(DriftSqlType.string, data['${effectivePrefix}customer_id'])!,
      issueDate: attachedDatabase.typeMapping
          .read(DriftSqlType.dateTime, data['${effectivePrefix}issue_date'])!,
      currency: attachedDatabase.typeMapping
          .read(DriftSqlType.string, data['${effectivePrefix}currency'])!,
      vatRateBasisPoints: attachedDatabase.typeMapping.read(
          DriftSqlType.int, data['${effectivePrefix}vat_rate_basis_points'])!,
      subtotalMinorUnits: attachedDatabase.typeMapping.read(
          DriftSqlType.int, data['${effectivePrefix}subtotal_minor_units'])!,
      vatMinorUnits: attachedDatabase.typeMapping
          .read(DriftSqlType.int, data['${effectivePrefix}vat_minor_units'])!,
      totalMinorUnits: attachedDatabase.typeMapping
          .read(DriftSqlType.int, data['${effectivePrefix}total_minor_units'])!,
      journalEntryId: attachedDatabase.typeMapping.read(
          DriftSqlType.string, data['${effectivePrefix}journal_entry_id'])!,
    );
  }

  @override
  $InvoicesTable createAlias(String alias) {
    return $InvoicesTable(attachedDatabase, alias);
  }
}

class InvoiceRow extends DataClass implements Insertable<InvoiceRow> {
  final String id;

  /// The printed document number. Unique, because reissuing one is prohibited.
  final String number;

  /// The sequence part of [number], kept separately so it can be ordered and
  /// audited without parsing the formatted string.
  final int sequence;
  final String fiscalYearLabel;
  final String customerId;
  final DateTime issueDate;
  final String currency;

  /// The VAT rate applied, in basis points.
  ///
  /// Stored rather than inferred. Without it a reloaded invoice could not
  /// reproduce its own VAT, and deriving the rate back out of the stored
  /// subtotal and VAT amount would be lossy and would break for a zero-rated
  /// invoice.
  final int vatRateBasisPoints;

  /// All amounts are **INTEGER minor units**, never REAL.
  final int subtotalMinorUnits;
  final int vatMinorUnits;
  final int totalMinorUnits;

  /// The journal entry that records the sale. A foreign key, so an invoice
  /// cannot exist without the accounting behind it.
  final String journalEntryId;
  const InvoiceRow(
      {required this.id,
      required this.number,
      required this.sequence,
      required this.fiscalYearLabel,
      required this.customerId,
      required this.issueDate,
      required this.currency,
      required this.vatRateBasisPoints,
      required this.subtotalMinorUnits,
      required this.vatMinorUnits,
      required this.totalMinorUnits,
      required this.journalEntryId});
  @override
  Map<String, Expression> toColumns(bool nullToAbsent) {
    final map = <String, Expression>{};
    map['id'] = Variable<String>(id);
    map['number'] = Variable<String>(number);
    map['sequence'] = Variable<int>(sequence);
    map['fiscal_year_label'] = Variable<String>(fiscalYearLabel);
    map['customer_id'] = Variable<String>(customerId);
    map['issue_date'] = Variable<DateTime>(issueDate);
    map['currency'] = Variable<String>(currency);
    map['vat_rate_basis_points'] = Variable<int>(vatRateBasisPoints);
    map['subtotal_minor_units'] = Variable<int>(subtotalMinorUnits);
    map['vat_minor_units'] = Variable<int>(vatMinorUnits);
    map['total_minor_units'] = Variable<int>(totalMinorUnits);
    map['journal_entry_id'] = Variable<String>(journalEntryId);
    return map;
  }

  InvoicesCompanion toCompanion(bool nullToAbsent) {
    return InvoicesCompanion(
      id: Value(id),
      number: Value(number),
      sequence: Value(sequence),
      fiscalYearLabel: Value(fiscalYearLabel),
      customerId: Value(customerId),
      issueDate: Value(issueDate),
      currency: Value(currency),
      vatRateBasisPoints: Value(vatRateBasisPoints),
      subtotalMinorUnits: Value(subtotalMinorUnits),
      vatMinorUnits: Value(vatMinorUnits),
      totalMinorUnits: Value(totalMinorUnits),
      journalEntryId: Value(journalEntryId),
    );
  }

  factory InvoiceRow.fromJson(Map<String, dynamic> json,
      {ValueSerializer? serializer}) {
    serializer ??= driftRuntimeOptions.defaultSerializer;
    return InvoiceRow(
      id: serializer.fromJson<String>(json['id']),
      number: serializer.fromJson<String>(json['number']),
      sequence: serializer.fromJson<int>(json['sequence']),
      fiscalYearLabel: serializer.fromJson<String>(json['fiscalYearLabel']),
      customerId: serializer.fromJson<String>(json['customerId']),
      issueDate: serializer.fromJson<DateTime>(json['issueDate']),
      currency: serializer.fromJson<String>(json['currency']),
      vatRateBasisPoints: serializer.fromJson<int>(json['vatRateBasisPoints']),
      subtotalMinorUnits: serializer.fromJson<int>(json['subtotalMinorUnits']),
      vatMinorUnits: serializer.fromJson<int>(json['vatMinorUnits']),
      totalMinorUnits: serializer.fromJson<int>(json['totalMinorUnits']),
      journalEntryId: serializer.fromJson<String>(json['journalEntryId']),
    );
  }
  @override
  Map<String, dynamic> toJson({ValueSerializer? serializer}) {
    serializer ??= driftRuntimeOptions.defaultSerializer;
    return <String, dynamic>{
      'id': serializer.toJson<String>(id),
      'number': serializer.toJson<String>(number),
      'sequence': serializer.toJson<int>(sequence),
      'fiscalYearLabel': serializer.toJson<String>(fiscalYearLabel),
      'customerId': serializer.toJson<String>(customerId),
      'issueDate': serializer.toJson<DateTime>(issueDate),
      'currency': serializer.toJson<String>(currency),
      'vatRateBasisPoints': serializer.toJson<int>(vatRateBasisPoints),
      'subtotalMinorUnits': serializer.toJson<int>(subtotalMinorUnits),
      'vatMinorUnits': serializer.toJson<int>(vatMinorUnits),
      'totalMinorUnits': serializer.toJson<int>(totalMinorUnits),
      'journalEntryId': serializer.toJson<String>(journalEntryId),
    };
  }

  InvoiceRow copyWith(
          {String? id,
          String? number,
          int? sequence,
          String? fiscalYearLabel,
          String? customerId,
          DateTime? issueDate,
          String? currency,
          int? vatRateBasisPoints,
          int? subtotalMinorUnits,
          int? vatMinorUnits,
          int? totalMinorUnits,
          String? journalEntryId}) =>
      InvoiceRow(
        id: id ?? this.id,
        number: number ?? this.number,
        sequence: sequence ?? this.sequence,
        fiscalYearLabel: fiscalYearLabel ?? this.fiscalYearLabel,
        customerId: customerId ?? this.customerId,
        issueDate: issueDate ?? this.issueDate,
        currency: currency ?? this.currency,
        vatRateBasisPoints: vatRateBasisPoints ?? this.vatRateBasisPoints,
        subtotalMinorUnits: subtotalMinorUnits ?? this.subtotalMinorUnits,
        vatMinorUnits: vatMinorUnits ?? this.vatMinorUnits,
        totalMinorUnits: totalMinorUnits ?? this.totalMinorUnits,
        journalEntryId: journalEntryId ?? this.journalEntryId,
      );
  InvoiceRow copyWithCompanion(InvoicesCompanion data) {
    return InvoiceRow(
      id: data.id.present ? data.id.value : this.id,
      number: data.number.present ? data.number.value : this.number,
      sequence: data.sequence.present ? data.sequence.value : this.sequence,
      fiscalYearLabel: data.fiscalYearLabel.present
          ? data.fiscalYearLabel.value
          : this.fiscalYearLabel,
      customerId:
          data.customerId.present ? data.customerId.value : this.customerId,
      issueDate: data.issueDate.present ? data.issueDate.value : this.issueDate,
      currency: data.currency.present ? data.currency.value : this.currency,
      vatRateBasisPoints: data.vatRateBasisPoints.present
          ? data.vatRateBasisPoints.value
          : this.vatRateBasisPoints,
      subtotalMinorUnits: data.subtotalMinorUnits.present
          ? data.subtotalMinorUnits.value
          : this.subtotalMinorUnits,
      vatMinorUnits: data.vatMinorUnits.present
          ? data.vatMinorUnits.value
          : this.vatMinorUnits,
      totalMinorUnits: data.totalMinorUnits.present
          ? data.totalMinorUnits.value
          : this.totalMinorUnits,
      journalEntryId: data.journalEntryId.present
          ? data.journalEntryId.value
          : this.journalEntryId,
    );
  }

  @override
  String toString() {
    return (StringBuffer('InvoiceRow(')
          ..write('id: $id, ')
          ..write('number: $number, ')
          ..write('sequence: $sequence, ')
          ..write('fiscalYearLabel: $fiscalYearLabel, ')
          ..write('customerId: $customerId, ')
          ..write('issueDate: $issueDate, ')
          ..write('currency: $currency, ')
          ..write('vatRateBasisPoints: $vatRateBasisPoints, ')
          ..write('subtotalMinorUnits: $subtotalMinorUnits, ')
          ..write('vatMinorUnits: $vatMinorUnits, ')
          ..write('totalMinorUnits: $totalMinorUnits, ')
          ..write('journalEntryId: $journalEntryId')
          ..write(')'))
        .toString();
  }

  @override
  int get hashCode => Object.hash(
      id,
      number,
      sequence,
      fiscalYearLabel,
      customerId,
      issueDate,
      currency,
      vatRateBasisPoints,
      subtotalMinorUnits,
      vatMinorUnits,
      totalMinorUnits,
      journalEntryId);
  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      (other is InvoiceRow &&
          other.id == this.id &&
          other.number == this.number &&
          other.sequence == this.sequence &&
          other.fiscalYearLabel == this.fiscalYearLabel &&
          other.customerId == this.customerId &&
          other.issueDate == this.issueDate &&
          other.currency == this.currency &&
          other.vatRateBasisPoints == this.vatRateBasisPoints &&
          other.subtotalMinorUnits == this.subtotalMinorUnits &&
          other.vatMinorUnits == this.vatMinorUnits &&
          other.totalMinorUnits == this.totalMinorUnits &&
          other.journalEntryId == this.journalEntryId);
}

class InvoicesCompanion extends UpdateCompanion<InvoiceRow> {
  final Value<String> id;
  final Value<String> number;
  final Value<int> sequence;
  final Value<String> fiscalYearLabel;
  final Value<String> customerId;
  final Value<DateTime> issueDate;
  final Value<String> currency;
  final Value<int> vatRateBasisPoints;
  final Value<int> subtotalMinorUnits;
  final Value<int> vatMinorUnits;
  final Value<int> totalMinorUnits;
  final Value<String> journalEntryId;
  final Value<int> rowid;
  const InvoicesCompanion({
    this.id = const Value.absent(),
    this.number = const Value.absent(),
    this.sequence = const Value.absent(),
    this.fiscalYearLabel = const Value.absent(),
    this.customerId = const Value.absent(),
    this.issueDate = const Value.absent(),
    this.currency = const Value.absent(),
    this.vatRateBasisPoints = const Value.absent(),
    this.subtotalMinorUnits = const Value.absent(),
    this.vatMinorUnits = const Value.absent(),
    this.totalMinorUnits = const Value.absent(),
    this.journalEntryId = const Value.absent(),
    this.rowid = const Value.absent(),
  });
  InvoicesCompanion.insert({
    required String id,
    required String number,
    required int sequence,
    required String fiscalYearLabel,
    required String customerId,
    required DateTime issueDate,
    required String currency,
    required int vatRateBasisPoints,
    required int subtotalMinorUnits,
    required int vatMinorUnits,
    required int totalMinorUnits,
    required String journalEntryId,
    this.rowid = const Value.absent(),
  })  : id = Value(id),
        number = Value(number),
        sequence = Value(sequence),
        fiscalYearLabel = Value(fiscalYearLabel),
        customerId = Value(customerId),
        issueDate = Value(issueDate),
        currency = Value(currency),
        vatRateBasisPoints = Value(vatRateBasisPoints),
        subtotalMinorUnits = Value(subtotalMinorUnits),
        vatMinorUnits = Value(vatMinorUnits),
        totalMinorUnits = Value(totalMinorUnits),
        journalEntryId = Value(journalEntryId);
  static Insertable<InvoiceRow> custom({
    Expression<String>? id,
    Expression<String>? number,
    Expression<int>? sequence,
    Expression<String>? fiscalYearLabel,
    Expression<String>? customerId,
    Expression<DateTime>? issueDate,
    Expression<String>? currency,
    Expression<int>? vatRateBasisPoints,
    Expression<int>? subtotalMinorUnits,
    Expression<int>? vatMinorUnits,
    Expression<int>? totalMinorUnits,
    Expression<String>? journalEntryId,
    Expression<int>? rowid,
  }) {
    return RawValuesInsertable({
      if (id != null) 'id': id,
      if (number != null) 'number': number,
      if (sequence != null) 'sequence': sequence,
      if (fiscalYearLabel != null) 'fiscal_year_label': fiscalYearLabel,
      if (customerId != null) 'customer_id': customerId,
      if (issueDate != null) 'issue_date': issueDate,
      if (currency != null) 'currency': currency,
      if (vatRateBasisPoints != null)
        'vat_rate_basis_points': vatRateBasisPoints,
      if (subtotalMinorUnits != null)
        'subtotal_minor_units': subtotalMinorUnits,
      if (vatMinorUnits != null) 'vat_minor_units': vatMinorUnits,
      if (totalMinorUnits != null) 'total_minor_units': totalMinorUnits,
      if (journalEntryId != null) 'journal_entry_id': journalEntryId,
      if (rowid != null) 'rowid': rowid,
    });
  }

  InvoicesCompanion copyWith(
      {Value<String>? id,
      Value<String>? number,
      Value<int>? sequence,
      Value<String>? fiscalYearLabel,
      Value<String>? customerId,
      Value<DateTime>? issueDate,
      Value<String>? currency,
      Value<int>? vatRateBasisPoints,
      Value<int>? subtotalMinorUnits,
      Value<int>? vatMinorUnits,
      Value<int>? totalMinorUnits,
      Value<String>? journalEntryId,
      Value<int>? rowid}) {
    return InvoicesCompanion(
      id: id ?? this.id,
      number: number ?? this.number,
      sequence: sequence ?? this.sequence,
      fiscalYearLabel: fiscalYearLabel ?? this.fiscalYearLabel,
      customerId: customerId ?? this.customerId,
      issueDate: issueDate ?? this.issueDate,
      currency: currency ?? this.currency,
      vatRateBasisPoints: vatRateBasisPoints ?? this.vatRateBasisPoints,
      subtotalMinorUnits: subtotalMinorUnits ?? this.subtotalMinorUnits,
      vatMinorUnits: vatMinorUnits ?? this.vatMinorUnits,
      totalMinorUnits: totalMinorUnits ?? this.totalMinorUnits,
      journalEntryId: journalEntryId ?? this.journalEntryId,
      rowid: rowid ?? this.rowid,
    );
  }

  @override
  Map<String, Expression> toColumns(bool nullToAbsent) {
    final map = <String, Expression>{};
    if (id.present) {
      map['id'] = Variable<String>(id.value);
    }
    if (number.present) {
      map['number'] = Variable<String>(number.value);
    }
    if (sequence.present) {
      map['sequence'] = Variable<int>(sequence.value);
    }
    if (fiscalYearLabel.present) {
      map['fiscal_year_label'] = Variable<String>(fiscalYearLabel.value);
    }
    if (customerId.present) {
      map['customer_id'] = Variable<String>(customerId.value);
    }
    if (issueDate.present) {
      map['issue_date'] = Variable<DateTime>(issueDate.value);
    }
    if (currency.present) {
      map['currency'] = Variable<String>(currency.value);
    }
    if (vatRateBasisPoints.present) {
      map['vat_rate_basis_points'] = Variable<int>(vatRateBasisPoints.value);
    }
    if (subtotalMinorUnits.present) {
      map['subtotal_minor_units'] = Variable<int>(subtotalMinorUnits.value);
    }
    if (vatMinorUnits.present) {
      map['vat_minor_units'] = Variable<int>(vatMinorUnits.value);
    }
    if (totalMinorUnits.present) {
      map['total_minor_units'] = Variable<int>(totalMinorUnits.value);
    }
    if (journalEntryId.present) {
      map['journal_entry_id'] = Variable<String>(journalEntryId.value);
    }
    if (rowid.present) {
      map['rowid'] = Variable<int>(rowid.value);
    }
    return map;
  }

  @override
  String toString() {
    return (StringBuffer('InvoicesCompanion(')
          ..write('id: $id, ')
          ..write('number: $number, ')
          ..write('sequence: $sequence, ')
          ..write('fiscalYearLabel: $fiscalYearLabel, ')
          ..write('customerId: $customerId, ')
          ..write('issueDate: $issueDate, ')
          ..write('currency: $currency, ')
          ..write('vatRateBasisPoints: $vatRateBasisPoints, ')
          ..write('subtotalMinorUnits: $subtotalMinorUnits, ')
          ..write('vatMinorUnits: $vatMinorUnits, ')
          ..write('totalMinorUnits: $totalMinorUnits, ')
          ..write('journalEntryId: $journalEntryId, ')
          ..write('rowid: $rowid')
          ..write(')'))
        .toString();
  }
}

class $InvoiceLinesTable extends InvoiceLines
    with TableInfo<$InvoiceLinesTable, InvoiceLineRow> {
  @override
  final GeneratedDatabase attachedDatabase;
  final String? _alias;
  $InvoiceLinesTable(this.attachedDatabase, [this._alias]);
  static const VerificationMeta _idMeta = const VerificationMeta('id');
  @override
  late final GeneratedColumn<int> id = GeneratedColumn<int>(
      'id', aliasedName, false,
      hasAutoIncrement: true,
      type: DriftSqlType.int,
      requiredDuringInsert: false,
      defaultConstraints:
          GeneratedColumn.constraintIsAlways('PRIMARY KEY AUTOINCREMENT'));
  static const VerificationMeta _invoiceIdMeta =
      const VerificationMeta('invoiceId');
  @override
  late final GeneratedColumn<String> invoiceId = GeneratedColumn<String>(
      'invoice_id', aliasedName, false,
      type: DriftSqlType.string, requiredDuringInsert: true);
  static const VerificationMeta _lineNumberMeta =
      const VerificationMeta('lineNumber');
  @override
  late final GeneratedColumn<int> lineNumber = GeneratedColumn<int>(
      'line_number', aliasedName, false,
      type: DriftSqlType.int, requiredDuringInsert: true);
  static const VerificationMeta _descriptionMeta =
      const VerificationMeta('description');
  @override
  late final GeneratedColumn<String> description = GeneratedColumn<String>(
      'description', aliasedName, false,
      type: DriftSqlType.string, requiredDuringInsert: true);
  static const VerificationMeta _quantityMeta =
      const VerificationMeta('quantity');
  @override
  late final GeneratedColumn<int> quantity = GeneratedColumn<int>(
      'quantity', aliasedName, false,
      type: DriftSqlType.int, requiredDuringInsert: true);
  static const VerificationMeta _unitPriceMinorUnitsMeta =
      const VerificationMeta('unitPriceMinorUnits');
  @override
  late final GeneratedColumn<int> unitPriceMinorUnits = GeneratedColumn<int>(
      'unit_price_minor_units', aliasedName, false,
      type: DriftSqlType.int, requiredDuringInsert: true);
  static const VerificationMeta _currencyMeta =
      const VerificationMeta('currency');
  @override
  late final GeneratedColumn<String> currency = GeneratedColumn<String>(
      'currency', aliasedName, false,
      type: DriftSqlType.string, requiredDuringInsert: true);
  @override
  List<GeneratedColumn> get $columns => [
        id,
        invoiceId,
        lineNumber,
        description,
        quantity,
        unitPriceMinorUnits,
        currency
      ];
  @override
  String get aliasedName => _alias ?? actualTableName;
  @override
  String get actualTableName => $name;
  static const String $name = 'invoice_lines';
  @override
  VerificationContext validateIntegrity(Insertable<InvoiceLineRow> instance,
      {bool isInserting = false}) {
    final context = VerificationContext();
    final data = instance.toColumns(true);
    if (data.containsKey('id')) {
      context.handle(_idMeta, id.isAcceptableOrUnknown(data['id']!, _idMeta));
    }
    if (data.containsKey('invoice_id')) {
      context.handle(_invoiceIdMeta,
          invoiceId.isAcceptableOrUnknown(data['invoice_id']!, _invoiceIdMeta));
    } else if (isInserting) {
      context.missing(_invoiceIdMeta);
    }
    if (data.containsKey('line_number')) {
      context.handle(
          _lineNumberMeta,
          lineNumber.isAcceptableOrUnknown(
              data['line_number']!, _lineNumberMeta));
    } else if (isInserting) {
      context.missing(_lineNumberMeta);
    }
    if (data.containsKey('description')) {
      context.handle(
          _descriptionMeta,
          description.isAcceptableOrUnknown(
              data['description']!, _descriptionMeta));
    } else if (isInserting) {
      context.missing(_descriptionMeta);
    }
    if (data.containsKey('quantity')) {
      context.handle(_quantityMeta,
          quantity.isAcceptableOrUnknown(data['quantity']!, _quantityMeta));
    } else if (isInserting) {
      context.missing(_quantityMeta);
    }
    if (data.containsKey('unit_price_minor_units')) {
      context.handle(
          _unitPriceMinorUnitsMeta,
          unitPriceMinorUnits.isAcceptableOrUnknown(
              data['unit_price_minor_units']!, _unitPriceMinorUnitsMeta));
    } else if (isInserting) {
      context.missing(_unitPriceMinorUnitsMeta);
    }
    if (data.containsKey('currency')) {
      context.handle(_currencyMeta,
          currency.isAcceptableOrUnknown(data['currency']!, _currencyMeta));
    } else if (isInserting) {
      context.missing(_currencyMeta);
    }
    return context;
  }

  @override
  Set<GeneratedColumn> get $primaryKey => {id};
  @override
  InvoiceLineRow map(Map<String, dynamic> data, {String? tablePrefix}) {
    final effectivePrefix = tablePrefix != null ? '$tablePrefix.' : '';
    return InvoiceLineRow(
      id: attachedDatabase.typeMapping
          .read(DriftSqlType.int, data['${effectivePrefix}id'])!,
      invoiceId: attachedDatabase.typeMapping
          .read(DriftSqlType.string, data['${effectivePrefix}invoice_id'])!,
      lineNumber: attachedDatabase.typeMapping
          .read(DriftSqlType.int, data['${effectivePrefix}line_number'])!,
      description: attachedDatabase.typeMapping
          .read(DriftSqlType.string, data['${effectivePrefix}description'])!,
      quantity: attachedDatabase.typeMapping
          .read(DriftSqlType.int, data['${effectivePrefix}quantity'])!,
      unitPriceMinorUnits: attachedDatabase.typeMapping.read(
          DriftSqlType.int, data['${effectivePrefix}unit_price_minor_units'])!,
      currency: attachedDatabase.typeMapping
          .read(DriftSqlType.string, data['${effectivePrefix}currency'])!,
    );
  }

  @override
  $InvoiceLinesTable createAlias(String alias) {
    return $InvoiceLinesTable(attachedDatabase, alias);
  }
}

class InvoiceLineRow extends DataClass implements Insertable<InvoiceLineRow> {
  final int id;
  final String invoiceId;

  /// Position on the invoice, starting at 1. Preserves the order the lines were
  /// entered in, which is the order they print in.
  final int lineNumber;
  final String description;
  final int quantity;
  final int unitPriceMinorUnits;
  final String currency;
  const InvoiceLineRow(
      {required this.id,
      required this.invoiceId,
      required this.lineNumber,
      required this.description,
      required this.quantity,
      required this.unitPriceMinorUnits,
      required this.currency});
  @override
  Map<String, Expression> toColumns(bool nullToAbsent) {
    final map = <String, Expression>{};
    map['id'] = Variable<int>(id);
    map['invoice_id'] = Variable<String>(invoiceId);
    map['line_number'] = Variable<int>(lineNumber);
    map['description'] = Variable<String>(description);
    map['quantity'] = Variable<int>(quantity);
    map['unit_price_minor_units'] = Variable<int>(unitPriceMinorUnits);
    map['currency'] = Variable<String>(currency);
    return map;
  }

  InvoiceLinesCompanion toCompanion(bool nullToAbsent) {
    return InvoiceLinesCompanion(
      id: Value(id),
      invoiceId: Value(invoiceId),
      lineNumber: Value(lineNumber),
      description: Value(description),
      quantity: Value(quantity),
      unitPriceMinorUnits: Value(unitPriceMinorUnits),
      currency: Value(currency),
    );
  }

  factory InvoiceLineRow.fromJson(Map<String, dynamic> json,
      {ValueSerializer? serializer}) {
    serializer ??= driftRuntimeOptions.defaultSerializer;
    return InvoiceLineRow(
      id: serializer.fromJson<int>(json['id']),
      invoiceId: serializer.fromJson<String>(json['invoiceId']),
      lineNumber: serializer.fromJson<int>(json['lineNumber']),
      description: serializer.fromJson<String>(json['description']),
      quantity: serializer.fromJson<int>(json['quantity']),
      unitPriceMinorUnits:
          serializer.fromJson<int>(json['unitPriceMinorUnits']),
      currency: serializer.fromJson<String>(json['currency']),
    );
  }
  @override
  Map<String, dynamic> toJson({ValueSerializer? serializer}) {
    serializer ??= driftRuntimeOptions.defaultSerializer;
    return <String, dynamic>{
      'id': serializer.toJson<int>(id),
      'invoiceId': serializer.toJson<String>(invoiceId),
      'lineNumber': serializer.toJson<int>(lineNumber),
      'description': serializer.toJson<String>(description),
      'quantity': serializer.toJson<int>(quantity),
      'unitPriceMinorUnits': serializer.toJson<int>(unitPriceMinorUnits),
      'currency': serializer.toJson<String>(currency),
    };
  }

  InvoiceLineRow copyWith(
          {int? id,
          String? invoiceId,
          int? lineNumber,
          String? description,
          int? quantity,
          int? unitPriceMinorUnits,
          String? currency}) =>
      InvoiceLineRow(
        id: id ?? this.id,
        invoiceId: invoiceId ?? this.invoiceId,
        lineNumber: lineNumber ?? this.lineNumber,
        description: description ?? this.description,
        quantity: quantity ?? this.quantity,
        unitPriceMinorUnits: unitPriceMinorUnits ?? this.unitPriceMinorUnits,
        currency: currency ?? this.currency,
      );
  InvoiceLineRow copyWithCompanion(InvoiceLinesCompanion data) {
    return InvoiceLineRow(
      id: data.id.present ? data.id.value : this.id,
      invoiceId: data.invoiceId.present ? data.invoiceId.value : this.invoiceId,
      lineNumber:
          data.lineNumber.present ? data.lineNumber.value : this.lineNumber,
      description:
          data.description.present ? data.description.value : this.description,
      quantity: data.quantity.present ? data.quantity.value : this.quantity,
      unitPriceMinorUnits: data.unitPriceMinorUnits.present
          ? data.unitPriceMinorUnits.value
          : this.unitPriceMinorUnits,
      currency: data.currency.present ? data.currency.value : this.currency,
    );
  }

  @override
  String toString() {
    return (StringBuffer('InvoiceLineRow(')
          ..write('id: $id, ')
          ..write('invoiceId: $invoiceId, ')
          ..write('lineNumber: $lineNumber, ')
          ..write('description: $description, ')
          ..write('quantity: $quantity, ')
          ..write('unitPriceMinorUnits: $unitPriceMinorUnits, ')
          ..write('currency: $currency')
          ..write(')'))
        .toString();
  }

  @override
  int get hashCode => Object.hash(id, invoiceId, lineNumber, description,
      quantity, unitPriceMinorUnits, currency);
  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      (other is InvoiceLineRow &&
          other.id == this.id &&
          other.invoiceId == this.invoiceId &&
          other.lineNumber == this.lineNumber &&
          other.description == this.description &&
          other.quantity == this.quantity &&
          other.unitPriceMinorUnits == this.unitPriceMinorUnits &&
          other.currency == this.currency);
}

class InvoiceLinesCompanion extends UpdateCompanion<InvoiceLineRow> {
  final Value<int> id;
  final Value<String> invoiceId;
  final Value<int> lineNumber;
  final Value<String> description;
  final Value<int> quantity;
  final Value<int> unitPriceMinorUnits;
  final Value<String> currency;
  const InvoiceLinesCompanion({
    this.id = const Value.absent(),
    this.invoiceId = const Value.absent(),
    this.lineNumber = const Value.absent(),
    this.description = const Value.absent(),
    this.quantity = const Value.absent(),
    this.unitPriceMinorUnits = const Value.absent(),
    this.currency = const Value.absent(),
  });
  InvoiceLinesCompanion.insert({
    this.id = const Value.absent(),
    required String invoiceId,
    required int lineNumber,
    required String description,
    required int quantity,
    required int unitPriceMinorUnits,
    required String currency,
  })  : invoiceId = Value(invoiceId),
        lineNumber = Value(lineNumber),
        description = Value(description),
        quantity = Value(quantity),
        unitPriceMinorUnits = Value(unitPriceMinorUnits),
        currency = Value(currency);
  static Insertable<InvoiceLineRow> custom({
    Expression<int>? id,
    Expression<String>? invoiceId,
    Expression<int>? lineNumber,
    Expression<String>? description,
    Expression<int>? quantity,
    Expression<int>? unitPriceMinorUnits,
    Expression<String>? currency,
  }) {
    return RawValuesInsertable({
      if (id != null) 'id': id,
      if (invoiceId != null) 'invoice_id': invoiceId,
      if (lineNumber != null) 'line_number': lineNumber,
      if (description != null) 'description': description,
      if (quantity != null) 'quantity': quantity,
      if (unitPriceMinorUnits != null)
        'unit_price_minor_units': unitPriceMinorUnits,
      if (currency != null) 'currency': currency,
    });
  }

  InvoiceLinesCompanion copyWith(
      {Value<int>? id,
      Value<String>? invoiceId,
      Value<int>? lineNumber,
      Value<String>? description,
      Value<int>? quantity,
      Value<int>? unitPriceMinorUnits,
      Value<String>? currency}) {
    return InvoiceLinesCompanion(
      id: id ?? this.id,
      invoiceId: invoiceId ?? this.invoiceId,
      lineNumber: lineNumber ?? this.lineNumber,
      description: description ?? this.description,
      quantity: quantity ?? this.quantity,
      unitPriceMinorUnits: unitPriceMinorUnits ?? this.unitPriceMinorUnits,
      currency: currency ?? this.currency,
    );
  }

  @override
  Map<String, Expression> toColumns(bool nullToAbsent) {
    final map = <String, Expression>{};
    if (id.present) {
      map['id'] = Variable<int>(id.value);
    }
    if (invoiceId.present) {
      map['invoice_id'] = Variable<String>(invoiceId.value);
    }
    if (lineNumber.present) {
      map['line_number'] = Variable<int>(lineNumber.value);
    }
    if (description.present) {
      map['description'] = Variable<String>(description.value);
    }
    if (quantity.present) {
      map['quantity'] = Variable<int>(quantity.value);
    }
    if (unitPriceMinorUnits.present) {
      map['unit_price_minor_units'] = Variable<int>(unitPriceMinorUnits.value);
    }
    if (currency.present) {
      map['currency'] = Variable<String>(currency.value);
    }
    return map;
  }

  @override
  String toString() {
    return (StringBuffer('InvoiceLinesCompanion(')
          ..write('id: $id, ')
          ..write('invoiceId: $invoiceId, ')
          ..write('lineNumber: $lineNumber, ')
          ..write('description: $description, ')
          ..write('quantity: $quantity, ')
          ..write('unitPriceMinorUnits: $unitPriceMinorUnits, ')
          ..write('currency: $currency')
          ..write(')'))
        .toString();
  }
}

class $PaymentsTable extends Payments
    with TableInfo<$PaymentsTable, PaymentRow> {
  @override
  final GeneratedDatabase attachedDatabase;
  final String? _alias;
  $PaymentsTable(this.attachedDatabase, [this._alias]);
  static const VerificationMeta _idMeta = const VerificationMeta('id');
  @override
  late final GeneratedColumn<String> id = GeneratedColumn<String>(
      'id', aliasedName, false,
      type: DriftSqlType.string, requiredDuringInsert: true);
  static const VerificationMeta _invoiceIdMeta =
      const VerificationMeta('invoiceId');
  @override
  late final GeneratedColumn<String> invoiceId = GeneratedColumn<String>(
      'invoice_id', aliasedName, false,
      type: DriftSqlType.string, requiredDuringInsert: true);
  static const VerificationMeta _dateMeta = const VerificationMeta('date');
  @override
  late final GeneratedColumn<DateTime> date = GeneratedColumn<DateTime>(
      'date', aliasedName, false,
      type: DriftSqlType.dateTime, requiredDuringInsert: true);
  static const VerificationMeta _amountMinorUnitsMeta =
      const VerificationMeta('amountMinorUnits');
  @override
  late final GeneratedColumn<int> amountMinorUnits = GeneratedColumn<int>(
      'amount_minor_units', aliasedName, false,
      type: DriftSqlType.int, requiredDuringInsert: true);
  static const VerificationMeta _currencyMeta =
      const VerificationMeta('currency');
  @override
  late final GeneratedColumn<String> currency = GeneratedColumn<String>(
      'currency', aliasedName, false,
      type: DriftSqlType.string, requiredDuringInsert: true);
  static const VerificationMeta _accountIdMeta =
      const VerificationMeta('accountId');
  @override
  late final GeneratedColumn<String> accountId = GeneratedColumn<String>(
      'account_id', aliasedName, false,
      type: DriftSqlType.string, requiredDuringInsert: true);
  @override
  List<GeneratedColumn> get $columns =>
      [id, invoiceId, date, amountMinorUnits, currency, accountId];
  @override
  String get aliasedName => _alias ?? actualTableName;
  @override
  String get actualTableName => $name;
  static const String $name = 'payments';
  @override
  VerificationContext validateIntegrity(Insertable<PaymentRow> instance,
      {bool isInserting = false}) {
    final context = VerificationContext();
    final data = instance.toColumns(true);
    if (data.containsKey('id')) {
      context.handle(_idMeta, id.isAcceptableOrUnknown(data['id']!, _idMeta));
    } else if (isInserting) {
      context.missing(_idMeta);
    }
    if (data.containsKey('invoice_id')) {
      context.handle(_invoiceIdMeta,
          invoiceId.isAcceptableOrUnknown(data['invoice_id']!, _invoiceIdMeta));
    } else if (isInserting) {
      context.missing(_invoiceIdMeta);
    }
    if (data.containsKey('date')) {
      context.handle(
          _dateMeta, date.isAcceptableOrUnknown(data['date']!, _dateMeta));
    } else if (isInserting) {
      context.missing(_dateMeta);
    }
    if (data.containsKey('amount_minor_units')) {
      context.handle(
          _amountMinorUnitsMeta,
          amountMinorUnits.isAcceptableOrUnknown(
              data['amount_minor_units']!, _amountMinorUnitsMeta));
    } else if (isInserting) {
      context.missing(_amountMinorUnitsMeta);
    }
    if (data.containsKey('currency')) {
      context.handle(_currencyMeta,
          currency.isAcceptableOrUnknown(data['currency']!, _currencyMeta));
    } else if (isInserting) {
      context.missing(_currencyMeta);
    }
    if (data.containsKey('account_id')) {
      context.handle(_accountIdMeta,
          accountId.isAcceptableOrUnknown(data['account_id']!, _accountIdMeta));
    } else if (isInserting) {
      context.missing(_accountIdMeta);
    }
    return context;
  }

  @override
  Set<GeneratedColumn> get $primaryKey => {id};
  @override
  PaymentRow map(Map<String, dynamic> data, {String? tablePrefix}) {
    final effectivePrefix = tablePrefix != null ? '$tablePrefix.' : '';
    return PaymentRow(
      id: attachedDatabase.typeMapping
          .read(DriftSqlType.string, data['${effectivePrefix}id'])!,
      invoiceId: attachedDatabase.typeMapping
          .read(DriftSqlType.string, data['${effectivePrefix}invoice_id'])!,
      date: attachedDatabase.typeMapping
          .read(DriftSqlType.dateTime, data['${effectivePrefix}date'])!,
      amountMinorUnits: attachedDatabase.typeMapping.read(
          DriftSqlType.int, data['${effectivePrefix}amount_minor_units'])!,
      currency: attachedDatabase.typeMapping
          .read(DriftSqlType.string, data['${effectivePrefix}currency'])!,
      accountId: attachedDatabase.typeMapping
          .read(DriftSqlType.string, data['${effectivePrefix}account_id'])!,
    );
  }

  @override
  $PaymentsTable createAlias(String alias) {
    return $PaymentsTable(attachedDatabase, alias);
  }
}

class PaymentRow extends DataClass implements Insertable<PaymentRow> {
  final String id;
  final String invoiceId;
  final DateTime date;

  /// Amount in minor units, for example paisa. **Integer, never REAL.**
  final int amountMinorUnits;
  final String currency;

  /// The account the money arrived in, for example Bank or Cash.
  final String accountId;
  const PaymentRow(
      {required this.id,
      required this.invoiceId,
      required this.date,
      required this.amountMinorUnits,
      required this.currency,
      required this.accountId});
  @override
  Map<String, Expression> toColumns(bool nullToAbsent) {
    final map = <String, Expression>{};
    map['id'] = Variable<String>(id);
    map['invoice_id'] = Variable<String>(invoiceId);
    map['date'] = Variable<DateTime>(date);
    map['amount_minor_units'] = Variable<int>(amountMinorUnits);
    map['currency'] = Variable<String>(currency);
    map['account_id'] = Variable<String>(accountId);
    return map;
  }

  PaymentsCompanion toCompanion(bool nullToAbsent) {
    return PaymentsCompanion(
      id: Value(id),
      invoiceId: Value(invoiceId),
      date: Value(date),
      amountMinorUnits: Value(amountMinorUnits),
      currency: Value(currency),
      accountId: Value(accountId),
    );
  }

  factory PaymentRow.fromJson(Map<String, dynamic> json,
      {ValueSerializer? serializer}) {
    serializer ??= driftRuntimeOptions.defaultSerializer;
    return PaymentRow(
      id: serializer.fromJson<String>(json['id']),
      invoiceId: serializer.fromJson<String>(json['invoiceId']),
      date: serializer.fromJson<DateTime>(json['date']),
      amountMinorUnits: serializer.fromJson<int>(json['amountMinorUnits']),
      currency: serializer.fromJson<String>(json['currency']),
      accountId: serializer.fromJson<String>(json['accountId']),
    );
  }
  @override
  Map<String, dynamic> toJson({ValueSerializer? serializer}) {
    serializer ??= driftRuntimeOptions.defaultSerializer;
    return <String, dynamic>{
      'id': serializer.toJson<String>(id),
      'invoiceId': serializer.toJson<String>(invoiceId),
      'date': serializer.toJson<DateTime>(date),
      'amountMinorUnits': serializer.toJson<int>(amountMinorUnits),
      'currency': serializer.toJson<String>(currency),
      'accountId': serializer.toJson<String>(accountId),
    };
  }

  PaymentRow copyWith(
          {String? id,
          String? invoiceId,
          DateTime? date,
          int? amountMinorUnits,
          String? currency,
          String? accountId}) =>
      PaymentRow(
        id: id ?? this.id,
        invoiceId: invoiceId ?? this.invoiceId,
        date: date ?? this.date,
        amountMinorUnits: amountMinorUnits ?? this.amountMinorUnits,
        currency: currency ?? this.currency,
        accountId: accountId ?? this.accountId,
      );
  PaymentRow copyWithCompanion(PaymentsCompanion data) {
    return PaymentRow(
      id: data.id.present ? data.id.value : this.id,
      invoiceId: data.invoiceId.present ? data.invoiceId.value : this.invoiceId,
      date: data.date.present ? data.date.value : this.date,
      amountMinorUnits: data.amountMinorUnits.present
          ? data.amountMinorUnits.value
          : this.amountMinorUnits,
      currency: data.currency.present ? data.currency.value : this.currency,
      accountId: data.accountId.present ? data.accountId.value : this.accountId,
    );
  }

  @override
  String toString() {
    return (StringBuffer('PaymentRow(')
          ..write('id: $id, ')
          ..write('invoiceId: $invoiceId, ')
          ..write('date: $date, ')
          ..write('amountMinorUnits: $amountMinorUnits, ')
          ..write('currency: $currency, ')
          ..write('accountId: $accountId')
          ..write(')'))
        .toString();
  }

  @override
  int get hashCode =>
      Object.hash(id, invoiceId, date, amountMinorUnits, currency, accountId);
  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      (other is PaymentRow &&
          other.id == this.id &&
          other.invoiceId == this.invoiceId &&
          other.date == this.date &&
          other.amountMinorUnits == this.amountMinorUnits &&
          other.currency == this.currency &&
          other.accountId == this.accountId);
}

class PaymentsCompanion extends UpdateCompanion<PaymentRow> {
  final Value<String> id;
  final Value<String> invoiceId;
  final Value<DateTime> date;
  final Value<int> amountMinorUnits;
  final Value<String> currency;
  final Value<String> accountId;
  final Value<int> rowid;
  const PaymentsCompanion({
    this.id = const Value.absent(),
    this.invoiceId = const Value.absent(),
    this.date = const Value.absent(),
    this.amountMinorUnits = const Value.absent(),
    this.currency = const Value.absent(),
    this.accountId = const Value.absent(),
    this.rowid = const Value.absent(),
  });
  PaymentsCompanion.insert({
    required String id,
    required String invoiceId,
    required DateTime date,
    required int amountMinorUnits,
    required String currency,
    required String accountId,
    this.rowid = const Value.absent(),
  })  : id = Value(id),
        invoiceId = Value(invoiceId),
        date = Value(date),
        amountMinorUnits = Value(amountMinorUnits),
        currency = Value(currency),
        accountId = Value(accountId);
  static Insertable<PaymentRow> custom({
    Expression<String>? id,
    Expression<String>? invoiceId,
    Expression<DateTime>? date,
    Expression<int>? amountMinorUnits,
    Expression<String>? currency,
    Expression<String>? accountId,
    Expression<int>? rowid,
  }) {
    return RawValuesInsertable({
      if (id != null) 'id': id,
      if (invoiceId != null) 'invoice_id': invoiceId,
      if (date != null) 'date': date,
      if (amountMinorUnits != null) 'amount_minor_units': amountMinorUnits,
      if (currency != null) 'currency': currency,
      if (accountId != null) 'account_id': accountId,
      if (rowid != null) 'rowid': rowid,
    });
  }

  PaymentsCompanion copyWith(
      {Value<String>? id,
      Value<String>? invoiceId,
      Value<DateTime>? date,
      Value<int>? amountMinorUnits,
      Value<String>? currency,
      Value<String>? accountId,
      Value<int>? rowid}) {
    return PaymentsCompanion(
      id: id ?? this.id,
      invoiceId: invoiceId ?? this.invoiceId,
      date: date ?? this.date,
      amountMinorUnits: amountMinorUnits ?? this.amountMinorUnits,
      currency: currency ?? this.currency,
      accountId: accountId ?? this.accountId,
      rowid: rowid ?? this.rowid,
    );
  }

  @override
  Map<String, Expression> toColumns(bool nullToAbsent) {
    final map = <String, Expression>{};
    if (id.present) {
      map['id'] = Variable<String>(id.value);
    }
    if (invoiceId.present) {
      map['invoice_id'] = Variable<String>(invoiceId.value);
    }
    if (date.present) {
      map['date'] = Variable<DateTime>(date.value);
    }
    if (amountMinorUnits.present) {
      map['amount_minor_units'] = Variable<int>(amountMinorUnits.value);
    }
    if (currency.present) {
      map['currency'] = Variable<String>(currency.value);
    }
    if (accountId.present) {
      map['account_id'] = Variable<String>(accountId.value);
    }
    if (rowid.present) {
      map['rowid'] = Variable<int>(rowid.value);
    }
    return map;
  }

  @override
  String toString() {
    return (StringBuffer('PaymentsCompanion(')
          ..write('id: $id, ')
          ..write('invoiceId: $invoiceId, ')
          ..write('date: $date, ')
          ..write('amountMinorUnits: $amountMinorUnits, ')
          ..write('currency: $currency, ')
          ..write('accountId: $accountId, ')
          ..write('rowid: $rowid')
          ..write(')'))
        .toString();
  }
}

class $CreditNotesTable extends CreditNotes
    with TableInfo<$CreditNotesTable, CreditNoteRow> {
  @override
  final GeneratedDatabase attachedDatabase;
  final String? _alias;
  $CreditNotesTable(this.attachedDatabase, [this._alias]);
  static const VerificationMeta _idMeta = const VerificationMeta('id');
  @override
  late final GeneratedColumn<String> id = GeneratedColumn<String>(
      'id', aliasedName, false,
      type: DriftSqlType.string, requiredDuringInsert: true);
  static const VerificationMeta _numberMeta = const VerificationMeta('number');
  @override
  late final GeneratedColumn<String> number = GeneratedColumn<String>(
      'number', aliasedName, false,
      type: DriftSqlType.string,
      requiredDuringInsert: true,
      defaultConstraints: GeneratedColumn.constraintIsAlways('UNIQUE'));
  static const VerificationMeta _sequenceMeta =
      const VerificationMeta('sequence');
  @override
  late final GeneratedColumn<int> sequence = GeneratedColumn<int>(
      'sequence', aliasedName, false,
      type: DriftSqlType.int, requiredDuringInsert: true);
  static const VerificationMeta _fiscalYearLabelMeta =
      const VerificationMeta('fiscalYearLabel');
  @override
  late final GeneratedColumn<String> fiscalYearLabel = GeneratedColumn<String>(
      'fiscal_year_label', aliasedName, false,
      type: DriftSqlType.string, requiredDuringInsert: true);
  static const VerificationMeta _invoiceIdMeta =
      const VerificationMeta('invoiceId');
  @override
  late final GeneratedColumn<String> invoiceId = GeneratedColumn<String>(
      'invoice_id', aliasedName, false,
      type: DriftSqlType.string, requiredDuringInsert: true);
  static const VerificationMeta _dateMeta = const VerificationMeta('date');
  @override
  late final GeneratedColumn<DateTime> date = GeneratedColumn<DateTime>(
      'date', aliasedName, false,
      type: DriftSqlType.dateTime, requiredDuringInsert: true);
  static const VerificationMeta _currencyMeta =
      const VerificationMeta('currency');
  @override
  late final GeneratedColumn<String> currency = GeneratedColumn<String>(
      'currency', aliasedName, false,
      type: DriftSqlType.string, requiredDuringInsert: true);
  static const VerificationMeta _vatRateBasisPointsMeta =
      const VerificationMeta('vatRateBasisPoints');
  @override
  late final GeneratedColumn<int> vatRateBasisPoints = GeneratedColumn<int>(
      'vat_rate_basis_points', aliasedName, false,
      type: DriftSqlType.int, requiredDuringInsert: true);
  static const VerificationMeta _subtotalMinorUnitsMeta =
      const VerificationMeta('subtotalMinorUnits');
  @override
  late final GeneratedColumn<int> subtotalMinorUnits = GeneratedColumn<int>(
      'subtotal_minor_units', aliasedName, false,
      type: DriftSqlType.int, requiredDuringInsert: true);
  static const VerificationMeta _vatMinorUnitsMeta =
      const VerificationMeta('vatMinorUnits');
  @override
  late final GeneratedColumn<int> vatMinorUnits = GeneratedColumn<int>(
      'vat_minor_units', aliasedName, false,
      type: DriftSqlType.int, requiredDuringInsert: true);
  static const VerificationMeta _totalMinorUnitsMeta =
      const VerificationMeta('totalMinorUnits');
  @override
  late final GeneratedColumn<int> totalMinorUnits = GeneratedColumn<int>(
      'total_minor_units', aliasedName, false,
      type: DriftSqlType.int, requiredDuringInsert: true);
  static const VerificationMeta _journalEntryIdMeta =
      const VerificationMeta('journalEntryId');
  @override
  late final GeneratedColumn<String> journalEntryId = GeneratedColumn<String>(
      'journal_entry_id', aliasedName, false,
      type: DriftSqlType.string, requiredDuringInsert: true);
  @override
  List<GeneratedColumn> get $columns => [
        id,
        number,
        sequence,
        fiscalYearLabel,
        invoiceId,
        date,
        currency,
        vatRateBasisPoints,
        subtotalMinorUnits,
        vatMinorUnits,
        totalMinorUnits,
        journalEntryId
      ];
  @override
  String get aliasedName => _alias ?? actualTableName;
  @override
  String get actualTableName => $name;
  static const String $name = 'credit_notes';
  @override
  VerificationContext validateIntegrity(Insertable<CreditNoteRow> instance,
      {bool isInserting = false}) {
    final context = VerificationContext();
    final data = instance.toColumns(true);
    if (data.containsKey('id')) {
      context.handle(_idMeta, id.isAcceptableOrUnknown(data['id']!, _idMeta));
    } else if (isInserting) {
      context.missing(_idMeta);
    }
    if (data.containsKey('number')) {
      context.handle(_numberMeta,
          number.isAcceptableOrUnknown(data['number']!, _numberMeta));
    } else if (isInserting) {
      context.missing(_numberMeta);
    }
    if (data.containsKey('sequence')) {
      context.handle(_sequenceMeta,
          sequence.isAcceptableOrUnknown(data['sequence']!, _sequenceMeta));
    } else if (isInserting) {
      context.missing(_sequenceMeta);
    }
    if (data.containsKey('fiscal_year_label')) {
      context.handle(
          _fiscalYearLabelMeta,
          fiscalYearLabel.isAcceptableOrUnknown(
              data['fiscal_year_label']!, _fiscalYearLabelMeta));
    } else if (isInserting) {
      context.missing(_fiscalYearLabelMeta);
    }
    if (data.containsKey('invoice_id')) {
      context.handle(_invoiceIdMeta,
          invoiceId.isAcceptableOrUnknown(data['invoice_id']!, _invoiceIdMeta));
    } else if (isInserting) {
      context.missing(_invoiceIdMeta);
    }
    if (data.containsKey('date')) {
      context.handle(
          _dateMeta, date.isAcceptableOrUnknown(data['date']!, _dateMeta));
    } else if (isInserting) {
      context.missing(_dateMeta);
    }
    if (data.containsKey('currency')) {
      context.handle(_currencyMeta,
          currency.isAcceptableOrUnknown(data['currency']!, _currencyMeta));
    } else if (isInserting) {
      context.missing(_currencyMeta);
    }
    if (data.containsKey('vat_rate_basis_points')) {
      context.handle(
          _vatRateBasisPointsMeta,
          vatRateBasisPoints.isAcceptableOrUnknown(
              data['vat_rate_basis_points']!, _vatRateBasisPointsMeta));
    } else if (isInserting) {
      context.missing(_vatRateBasisPointsMeta);
    }
    if (data.containsKey('subtotal_minor_units')) {
      context.handle(
          _subtotalMinorUnitsMeta,
          subtotalMinorUnits.isAcceptableOrUnknown(
              data['subtotal_minor_units']!, _subtotalMinorUnitsMeta));
    } else if (isInserting) {
      context.missing(_subtotalMinorUnitsMeta);
    }
    if (data.containsKey('vat_minor_units')) {
      context.handle(
          _vatMinorUnitsMeta,
          vatMinorUnits.isAcceptableOrUnknown(
              data['vat_minor_units']!, _vatMinorUnitsMeta));
    } else if (isInserting) {
      context.missing(_vatMinorUnitsMeta);
    }
    if (data.containsKey('total_minor_units')) {
      context.handle(
          _totalMinorUnitsMeta,
          totalMinorUnits.isAcceptableOrUnknown(
              data['total_minor_units']!, _totalMinorUnitsMeta));
    } else if (isInserting) {
      context.missing(_totalMinorUnitsMeta);
    }
    if (data.containsKey('journal_entry_id')) {
      context.handle(
          _journalEntryIdMeta,
          journalEntryId.isAcceptableOrUnknown(
              data['journal_entry_id']!, _journalEntryIdMeta));
    } else if (isInserting) {
      context.missing(_journalEntryIdMeta);
    }
    return context;
  }

  @override
  Set<GeneratedColumn> get $primaryKey => {id};
  @override
  CreditNoteRow map(Map<String, dynamic> data, {String? tablePrefix}) {
    final effectivePrefix = tablePrefix != null ? '$tablePrefix.' : '';
    return CreditNoteRow(
      id: attachedDatabase.typeMapping
          .read(DriftSqlType.string, data['${effectivePrefix}id'])!,
      number: attachedDatabase.typeMapping
          .read(DriftSqlType.string, data['${effectivePrefix}number'])!,
      sequence: attachedDatabase.typeMapping
          .read(DriftSqlType.int, data['${effectivePrefix}sequence'])!,
      fiscalYearLabel: attachedDatabase.typeMapping.read(
          DriftSqlType.string, data['${effectivePrefix}fiscal_year_label'])!,
      invoiceId: attachedDatabase.typeMapping
          .read(DriftSqlType.string, data['${effectivePrefix}invoice_id'])!,
      date: attachedDatabase.typeMapping
          .read(DriftSqlType.dateTime, data['${effectivePrefix}date'])!,
      currency: attachedDatabase.typeMapping
          .read(DriftSqlType.string, data['${effectivePrefix}currency'])!,
      vatRateBasisPoints: attachedDatabase.typeMapping.read(
          DriftSqlType.int, data['${effectivePrefix}vat_rate_basis_points'])!,
      subtotalMinorUnits: attachedDatabase.typeMapping.read(
          DriftSqlType.int, data['${effectivePrefix}subtotal_minor_units'])!,
      vatMinorUnits: attachedDatabase.typeMapping
          .read(DriftSqlType.int, data['${effectivePrefix}vat_minor_units'])!,
      totalMinorUnits: attachedDatabase.typeMapping
          .read(DriftSqlType.int, data['${effectivePrefix}total_minor_units'])!,
      journalEntryId: attachedDatabase.typeMapping.read(
          DriftSqlType.string, data['${effectivePrefix}journal_entry_id'])!,
    );
  }

  @override
  $CreditNotesTable createAlias(String alias) {
    return $CreditNotesTable(attachedDatabase, alias);
  }
}

class CreditNoteRow extends DataClass implements Insertable<CreditNoteRow> {
  final String id;

  /// The printed document number, from its own `CRN` sequence.
  final String number;
  final int sequence;
  final String fiscalYearLabel;

  /// The invoice being credited. Required, so every correction is traceable.
  final String invoiceId;
  final DateTime date;
  final String currency;
  final int vatRateBasisPoints;

  /// All amounts are **INTEGER minor units**, never REAL.
  final int subtotalMinorUnits;
  final int vatMinorUnits;
  final int totalMinorUnits;
  final String journalEntryId;
  const CreditNoteRow(
      {required this.id,
      required this.number,
      required this.sequence,
      required this.fiscalYearLabel,
      required this.invoiceId,
      required this.date,
      required this.currency,
      required this.vatRateBasisPoints,
      required this.subtotalMinorUnits,
      required this.vatMinorUnits,
      required this.totalMinorUnits,
      required this.journalEntryId});
  @override
  Map<String, Expression> toColumns(bool nullToAbsent) {
    final map = <String, Expression>{};
    map['id'] = Variable<String>(id);
    map['number'] = Variable<String>(number);
    map['sequence'] = Variable<int>(sequence);
    map['fiscal_year_label'] = Variable<String>(fiscalYearLabel);
    map['invoice_id'] = Variable<String>(invoiceId);
    map['date'] = Variable<DateTime>(date);
    map['currency'] = Variable<String>(currency);
    map['vat_rate_basis_points'] = Variable<int>(vatRateBasisPoints);
    map['subtotal_minor_units'] = Variable<int>(subtotalMinorUnits);
    map['vat_minor_units'] = Variable<int>(vatMinorUnits);
    map['total_minor_units'] = Variable<int>(totalMinorUnits);
    map['journal_entry_id'] = Variable<String>(journalEntryId);
    return map;
  }

  CreditNotesCompanion toCompanion(bool nullToAbsent) {
    return CreditNotesCompanion(
      id: Value(id),
      number: Value(number),
      sequence: Value(sequence),
      fiscalYearLabel: Value(fiscalYearLabel),
      invoiceId: Value(invoiceId),
      date: Value(date),
      currency: Value(currency),
      vatRateBasisPoints: Value(vatRateBasisPoints),
      subtotalMinorUnits: Value(subtotalMinorUnits),
      vatMinorUnits: Value(vatMinorUnits),
      totalMinorUnits: Value(totalMinorUnits),
      journalEntryId: Value(journalEntryId),
    );
  }

  factory CreditNoteRow.fromJson(Map<String, dynamic> json,
      {ValueSerializer? serializer}) {
    serializer ??= driftRuntimeOptions.defaultSerializer;
    return CreditNoteRow(
      id: serializer.fromJson<String>(json['id']),
      number: serializer.fromJson<String>(json['number']),
      sequence: serializer.fromJson<int>(json['sequence']),
      fiscalYearLabel: serializer.fromJson<String>(json['fiscalYearLabel']),
      invoiceId: serializer.fromJson<String>(json['invoiceId']),
      date: serializer.fromJson<DateTime>(json['date']),
      currency: serializer.fromJson<String>(json['currency']),
      vatRateBasisPoints: serializer.fromJson<int>(json['vatRateBasisPoints']),
      subtotalMinorUnits: serializer.fromJson<int>(json['subtotalMinorUnits']),
      vatMinorUnits: serializer.fromJson<int>(json['vatMinorUnits']),
      totalMinorUnits: serializer.fromJson<int>(json['totalMinorUnits']),
      journalEntryId: serializer.fromJson<String>(json['journalEntryId']),
    );
  }
  @override
  Map<String, dynamic> toJson({ValueSerializer? serializer}) {
    serializer ??= driftRuntimeOptions.defaultSerializer;
    return <String, dynamic>{
      'id': serializer.toJson<String>(id),
      'number': serializer.toJson<String>(number),
      'sequence': serializer.toJson<int>(sequence),
      'fiscalYearLabel': serializer.toJson<String>(fiscalYearLabel),
      'invoiceId': serializer.toJson<String>(invoiceId),
      'date': serializer.toJson<DateTime>(date),
      'currency': serializer.toJson<String>(currency),
      'vatRateBasisPoints': serializer.toJson<int>(vatRateBasisPoints),
      'subtotalMinorUnits': serializer.toJson<int>(subtotalMinorUnits),
      'vatMinorUnits': serializer.toJson<int>(vatMinorUnits),
      'totalMinorUnits': serializer.toJson<int>(totalMinorUnits),
      'journalEntryId': serializer.toJson<String>(journalEntryId),
    };
  }

  CreditNoteRow copyWith(
          {String? id,
          String? number,
          int? sequence,
          String? fiscalYearLabel,
          String? invoiceId,
          DateTime? date,
          String? currency,
          int? vatRateBasisPoints,
          int? subtotalMinorUnits,
          int? vatMinorUnits,
          int? totalMinorUnits,
          String? journalEntryId}) =>
      CreditNoteRow(
        id: id ?? this.id,
        number: number ?? this.number,
        sequence: sequence ?? this.sequence,
        fiscalYearLabel: fiscalYearLabel ?? this.fiscalYearLabel,
        invoiceId: invoiceId ?? this.invoiceId,
        date: date ?? this.date,
        currency: currency ?? this.currency,
        vatRateBasisPoints: vatRateBasisPoints ?? this.vatRateBasisPoints,
        subtotalMinorUnits: subtotalMinorUnits ?? this.subtotalMinorUnits,
        vatMinorUnits: vatMinorUnits ?? this.vatMinorUnits,
        totalMinorUnits: totalMinorUnits ?? this.totalMinorUnits,
        journalEntryId: journalEntryId ?? this.journalEntryId,
      );
  CreditNoteRow copyWithCompanion(CreditNotesCompanion data) {
    return CreditNoteRow(
      id: data.id.present ? data.id.value : this.id,
      number: data.number.present ? data.number.value : this.number,
      sequence: data.sequence.present ? data.sequence.value : this.sequence,
      fiscalYearLabel: data.fiscalYearLabel.present
          ? data.fiscalYearLabel.value
          : this.fiscalYearLabel,
      invoiceId: data.invoiceId.present ? data.invoiceId.value : this.invoiceId,
      date: data.date.present ? data.date.value : this.date,
      currency: data.currency.present ? data.currency.value : this.currency,
      vatRateBasisPoints: data.vatRateBasisPoints.present
          ? data.vatRateBasisPoints.value
          : this.vatRateBasisPoints,
      subtotalMinorUnits: data.subtotalMinorUnits.present
          ? data.subtotalMinorUnits.value
          : this.subtotalMinorUnits,
      vatMinorUnits: data.vatMinorUnits.present
          ? data.vatMinorUnits.value
          : this.vatMinorUnits,
      totalMinorUnits: data.totalMinorUnits.present
          ? data.totalMinorUnits.value
          : this.totalMinorUnits,
      journalEntryId: data.journalEntryId.present
          ? data.journalEntryId.value
          : this.journalEntryId,
    );
  }

  @override
  String toString() {
    return (StringBuffer('CreditNoteRow(')
          ..write('id: $id, ')
          ..write('number: $number, ')
          ..write('sequence: $sequence, ')
          ..write('fiscalYearLabel: $fiscalYearLabel, ')
          ..write('invoiceId: $invoiceId, ')
          ..write('date: $date, ')
          ..write('currency: $currency, ')
          ..write('vatRateBasisPoints: $vatRateBasisPoints, ')
          ..write('subtotalMinorUnits: $subtotalMinorUnits, ')
          ..write('vatMinorUnits: $vatMinorUnits, ')
          ..write('totalMinorUnits: $totalMinorUnits, ')
          ..write('journalEntryId: $journalEntryId')
          ..write(')'))
        .toString();
  }

  @override
  int get hashCode => Object.hash(
      id,
      number,
      sequence,
      fiscalYearLabel,
      invoiceId,
      date,
      currency,
      vatRateBasisPoints,
      subtotalMinorUnits,
      vatMinorUnits,
      totalMinorUnits,
      journalEntryId);
  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      (other is CreditNoteRow &&
          other.id == this.id &&
          other.number == this.number &&
          other.sequence == this.sequence &&
          other.fiscalYearLabel == this.fiscalYearLabel &&
          other.invoiceId == this.invoiceId &&
          other.date == this.date &&
          other.currency == this.currency &&
          other.vatRateBasisPoints == this.vatRateBasisPoints &&
          other.subtotalMinorUnits == this.subtotalMinorUnits &&
          other.vatMinorUnits == this.vatMinorUnits &&
          other.totalMinorUnits == this.totalMinorUnits &&
          other.journalEntryId == this.journalEntryId);
}

class CreditNotesCompanion extends UpdateCompanion<CreditNoteRow> {
  final Value<String> id;
  final Value<String> number;
  final Value<int> sequence;
  final Value<String> fiscalYearLabel;
  final Value<String> invoiceId;
  final Value<DateTime> date;
  final Value<String> currency;
  final Value<int> vatRateBasisPoints;
  final Value<int> subtotalMinorUnits;
  final Value<int> vatMinorUnits;
  final Value<int> totalMinorUnits;
  final Value<String> journalEntryId;
  final Value<int> rowid;
  const CreditNotesCompanion({
    this.id = const Value.absent(),
    this.number = const Value.absent(),
    this.sequence = const Value.absent(),
    this.fiscalYearLabel = const Value.absent(),
    this.invoiceId = const Value.absent(),
    this.date = const Value.absent(),
    this.currency = const Value.absent(),
    this.vatRateBasisPoints = const Value.absent(),
    this.subtotalMinorUnits = const Value.absent(),
    this.vatMinorUnits = const Value.absent(),
    this.totalMinorUnits = const Value.absent(),
    this.journalEntryId = const Value.absent(),
    this.rowid = const Value.absent(),
  });
  CreditNotesCompanion.insert({
    required String id,
    required String number,
    required int sequence,
    required String fiscalYearLabel,
    required String invoiceId,
    required DateTime date,
    required String currency,
    required int vatRateBasisPoints,
    required int subtotalMinorUnits,
    required int vatMinorUnits,
    required int totalMinorUnits,
    required String journalEntryId,
    this.rowid = const Value.absent(),
  })  : id = Value(id),
        number = Value(number),
        sequence = Value(sequence),
        fiscalYearLabel = Value(fiscalYearLabel),
        invoiceId = Value(invoiceId),
        date = Value(date),
        currency = Value(currency),
        vatRateBasisPoints = Value(vatRateBasisPoints),
        subtotalMinorUnits = Value(subtotalMinorUnits),
        vatMinorUnits = Value(vatMinorUnits),
        totalMinorUnits = Value(totalMinorUnits),
        journalEntryId = Value(journalEntryId);
  static Insertable<CreditNoteRow> custom({
    Expression<String>? id,
    Expression<String>? number,
    Expression<int>? sequence,
    Expression<String>? fiscalYearLabel,
    Expression<String>? invoiceId,
    Expression<DateTime>? date,
    Expression<String>? currency,
    Expression<int>? vatRateBasisPoints,
    Expression<int>? subtotalMinorUnits,
    Expression<int>? vatMinorUnits,
    Expression<int>? totalMinorUnits,
    Expression<String>? journalEntryId,
    Expression<int>? rowid,
  }) {
    return RawValuesInsertable({
      if (id != null) 'id': id,
      if (number != null) 'number': number,
      if (sequence != null) 'sequence': sequence,
      if (fiscalYearLabel != null) 'fiscal_year_label': fiscalYearLabel,
      if (invoiceId != null) 'invoice_id': invoiceId,
      if (date != null) 'date': date,
      if (currency != null) 'currency': currency,
      if (vatRateBasisPoints != null)
        'vat_rate_basis_points': vatRateBasisPoints,
      if (subtotalMinorUnits != null)
        'subtotal_minor_units': subtotalMinorUnits,
      if (vatMinorUnits != null) 'vat_minor_units': vatMinorUnits,
      if (totalMinorUnits != null) 'total_minor_units': totalMinorUnits,
      if (journalEntryId != null) 'journal_entry_id': journalEntryId,
      if (rowid != null) 'rowid': rowid,
    });
  }

  CreditNotesCompanion copyWith(
      {Value<String>? id,
      Value<String>? number,
      Value<int>? sequence,
      Value<String>? fiscalYearLabel,
      Value<String>? invoiceId,
      Value<DateTime>? date,
      Value<String>? currency,
      Value<int>? vatRateBasisPoints,
      Value<int>? subtotalMinorUnits,
      Value<int>? vatMinorUnits,
      Value<int>? totalMinorUnits,
      Value<String>? journalEntryId,
      Value<int>? rowid}) {
    return CreditNotesCompanion(
      id: id ?? this.id,
      number: number ?? this.number,
      sequence: sequence ?? this.sequence,
      fiscalYearLabel: fiscalYearLabel ?? this.fiscalYearLabel,
      invoiceId: invoiceId ?? this.invoiceId,
      date: date ?? this.date,
      currency: currency ?? this.currency,
      vatRateBasisPoints: vatRateBasisPoints ?? this.vatRateBasisPoints,
      subtotalMinorUnits: subtotalMinorUnits ?? this.subtotalMinorUnits,
      vatMinorUnits: vatMinorUnits ?? this.vatMinorUnits,
      totalMinorUnits: totalMinorUnits ?? this.totalMinorUnits,
      journalEntryId: journalEntryId ?? this.journalEntryId,
      rowid: rowid ?? this.rowid,
    );
  }

  @override
  Map<String, Expression> toColumns(bool nullToAbsent) {
    final map = <String, Expression>{};
    if (id.present) {
      map['id'] = Variable<String>(id.value);
    }
    if (number.present) {
      map['number'] = Variable<String>(number.value);
    }
    if (sequence.present) {
      map['sequence'] = Variable<int>(sequence.value);
    }
    if (fiscalYearLabel.present) {
      map['fiscal_year_label'] = Variable<String>(fiscalYearLabel.value);
    }
    if (invoiceId.present) {
      map['invoice_id'] = Variable<String>(invoiceId.value);
    }
    if (date.present) {
      map['date'] = Variable<DateTime>(date.value);
    }
    if (currency.present) {
      map['currency'] = Variable<String>(currency.value);
    }
    if (vatRateBasisPoints.present) {
      map['vat_rate_basis_points'] = Variable<int>(vatRateBasisPoints.value);
    }
    if (subtotalMinorUnits.present) {
      map['subtotal_minor_units'] = Variable<int>(subtotalMinorUnits.value);
    }
    if (vatMinorUnits.present) {
      map['vat_minor_units'] = Variable<int>(vatMinorUnits.value);
    }
    if (totalMinorUnits.present) {
      map['total_minor_units'] = Variable<int>(totalMinorUnits.value);
    }
    if (journalEntryId.present) {
      map['journal_entry_id'] = Variable<String>(journalEntryId.value);
    }
    if (rowid.present) {
      map['rowid'] = Variable<int>(rowid.value);
    }
    return map;
  }

  @override
  String toString() {
    return (StringBuffer('CreditNotesCompanion(')
          ..write('id: $id, ')
          ..write('number: $number, ')
          ..write('sequence: $sequence, ')
          ..write('fiscalYearLabel: $fiscalYearLabel, ')
          ..write('invoiceId: $invoiceId, ')
          ..write('date: $date, ')
          ..write('currency: $currency, ')
          ..write('vatRateBasisPoints: $vatRateBasisPoints, ')
          ..write('subtotalMinorUnits: $subtotalMinorUnits, ')
          ..write('vatMinorUnits: $vatMinorUnits, ')
          ..write('totalMinorUnits: $totalMinorUnits, ')
          ..write('journalEntryId: $journalEntryId, ')
          ..write('rowid: $rowid')
          ..write(')'))
        .toString();
  }
}

class $CreditNoteLinesTable extends CreditNoteLines
    with TableInfo<$CreditNoteLinesTable, CreditNoteLineRow> {
  @override
  final GeneratedDatabase attachedDatabase;
  final String? _alias;
  $CreditNoteLinesTable(this.attachedDatabase, [this._alias]);
  static const VerificationMeta _idMeta = const VerificationMeta('id');
  @override
  late final GeneratedColumn<int> id = GeneratedColumn<int>(
      'id', aliasedName, false,
      hasAutoIncrement: true,
      type: DriftSqlType.int,
      requiredDuringInsert: false,
      defaultConstraints:
          GeneratedColumn.constraintIsAlways('PRIMARY KEY AUTOINCREMENT'));
  static const VerificationMeta _creditNoteIdMeta =
      const VerificationMeta('creditNoteId');
  @override
  late final GeneratedColumn<String> creditNoteId = GeneratedColumn<String>(
      'credit_note_id', aliasedName, false,
      type: DriftSqlType.string, requiredDuringInsert: true);
  static const VerificationMeta _lineNumberMeta =
      const VerificationMeta('lineNumber');
  @override
  late final GeneratedColumn<int> lineNumber = GeneratedColumn<int>(
      'line_number', aliasedName, false,
      type: DriftSqlType.int, requiredDuringInsert: true);
  static const VerificationMeta _descriptionMeta =
      const VerificationMeta('description');
  @override
  late final GeneratedColumn<String> description = GeneratedColumn<String>(
      'description', aliasedName, false,
      type: DriftSqlType.string, requiredDuringInsert: true);
  static const VerificationMeta _quantityMeta =
      const VerificationMeta('quantity');
  @override
  late final GeneratedColumn<int> quantity = GeneratedColumn<int>(
      'quantity', aliasedName, false,
      type: DriftSqlType.int, requiredDuringInsert: true);
  static const VerificationMeta _unitPriceMinorUnitsMeta =
      const VerificationMeta('unitPriceMinorUnits');
  @override
  late final GeneratedColumn<int> unitPriceMinorUnits = GeneratedColumn<int>(
      'unit_price_minor_units', aliasedName, false,
      type: DriftSqlType.int, requiredDuringInsert: true);
  static const VerificationMeta _currencyMeta =
      const VerificationMeta('currency');
  @override
  late final GeneratedColumn<String> currency = GeneratedColumn<String>(
      'currency', aliasedName, false,
      type: DriftSqlType.string, requiredDuringInsert: true);
  @override
  List<GeneratedColumn> get $columns => [
        id,
        creditNoteId,
        lineNumber,
        description,
        quantity,
        unitPriceMinorUnits,
        currency
      ];
  @override
  String get aliasedName => _alias ?? actualTableName;
  @override
  String get actualTableName => $name;
  static const String $name = 'credit_note_lines';
  @override
  VerificationContext validateIntegrity(Insertable<CreditNoteLineRow> instance,
      {bool isInserting = false}) {
    final context = VerificationContext();
    final data = instance.toColumns(true);
    if (data.containsKey('id')) {
      context.handle(_idMeta, id.isAcceptableOrUnknown(data['id']!, _idMeta));
    }
    if (data.containsKey('credit_note_id')) {
      context.handle(
          _creditNoteIdMeta,
          creditNoteId.isAcceptableOrUnknown(
              data['credit_note_id']!, _creditNoteIdMeta));
    } else if (isInserting) {
      context.missing(_creditNoteIdMeta);
    }
    if (data.containsKey('line_number')) {
      context.handle(
          _lineNumberMeta,
          lineNumber.isAcceptableOrUnknown(
              data['line_number']!, _lineNumberMeta));
    } else if (isInserting) {
      context.missing(_lineNumberMeta);
    }
    if (data.containsKey('description')) {
      context.handle(
          _descriptionMeta,
          description.isAcceptableOrUnknown(
              data['description']!, _descriptionMeta));
    } else if (isInserting) {
      context.missing(_descriptionMeta);
    }
    if (data.containsKey('quantity')) {
      context.handle(_quantityMeta,
          quantity.isAcceptableOrUnknown(data['quantity']!, _quantityMeta));
    } else if (isInserting) {
      context.missing(_quantityMeta);
    }
    if (data.containsKey('unit_price_minor_units')) {
      context.handle(
          _unitPriceMinorUnitsMeta,
          unitPriceMinorUnits.isAcceptableOrUnknown(
              data['unit_price_minor_units']!, _unitPriceMinorUnitsMeta));
    } else if (isInserting) {
      context.missing(_unitPriceMinorUnitsMeta);
    }
    if (data.containsKey('currency')) {
      context.handle(_currencyMeta,
          currency.isAcceptableOrUnknown(data['currency']!, _currencyMeta));
    } else if (isInserting) {
      context.missing(_currencyMeta);
    }
    return context;
  }

  @override
  Set<GeneratedColumn> get $primaryKey => {id};
  @override
  CreditNoteLineRow map(Map<String, dynamic> data, {String? tablePrefix}) {
    final effectivePrefix = tablePrefix != null ? '$tablePrefix.' : '';
    return CreditNoteLineRow(
      id: attachedDatabase.typeMapping
          .read(DriftSqlType.int, data['${effectivePrefix}id'])!,
      creditNoteId: attachedDatabase.typeMapping
          .read(DriftSqlType.string, data['${effectivePrefix}credit_note_id'])!,
      lineNumber: attachedDatabase.typeMapping
          .read(DriftSqlType.int, data['${effectivePrefix}line_number'])!,
      description: attachedDatabase.typeMapping
          .read(DriftSqlType.string, data['${effectivePrefix}description'])!,
      quantity: attachedDatabase.typeMapping
          .read(DriftSqlType.int, data['${effectivePrefix}quantity'])!,
      unitPriceMinorUnits: attachedDatabase.typeMapping.read(
          DriftSqlType.int, data['${effectivePrefix}unit_price_minor_units'])!,
      currency: attachedDatabase.typeMapping
          .read(DriftSqlType.string, data['${effectivePrefix}currency'])!,
    );
  }

  @override
  $CreditNoteLinesTable createAlias(String alias) {
    return $CreditNoteLinesTable(attachedDatabase, alias);
  }
}

class CreditNoteLineRow extends DataClass
    implements Insertable<CreditNoteLineRow> {
  final int id;
  final String creditNoteId;
  final int lineNumber;
  final String description;
  final int quantity;
  final int unitPriceMinorUnits;
  final String currency;
  const CreditNoteLineRow(
      {required this.id,
      required this.creditNoteId,
      required this.lineNumber,
      required this.description,
      required this.quantity,
      required this.unitPriceMinorUnits,
      required this.currency});
  @override
  Map<String, Expression> toColumns(bool nullToAbsent) {
    final map = <String, Expression>{};
    map['id'] = Variable<int>(id);
    map['credit_note_id'] = Variable<String>(creditNoteId);
    map['line_number'] = Variable<int>(lineNumber);
    map['description'] = Variable<String>(description);
    map['quantity'] = Variable<int>(quantity);
    map['unit_price_minor_units'] = Variable<int>(unitPriceMinorUnits);
    map['currency'] = Variable<String>(currency);
    return map;
  }

  CreditNoteLinesCompanion toCompanion(bool nullToAbsent) {
    return CreditNoteLinesCompanion(
      id: Value(id),
      creditNoteId: Value(creditNoteId),
      lineNumber: Value(lineNumber),
      description: Value(description),
      quantity: Value(quantity),
      unitPriceMinorUnits: Value(unitPriceMinorUnits),
      currency: Value(currency),
    );
  }

  factory CreditNoteLineRow.fromJson(Map<String, dynamic> json,
      {ValueSerializer? serializer}) {
    serializer ??= driftRuntimeOptions.defaultSerializer;
    return CreditNoteLineRow(
      id: serializer.fromJson<int>(json['id']),
      creditNoteId: serializer.fromJson<String>(json['creditNoteId']),
      lineNumber: serializer.fromJson<int>(json['lineNumber']),
      description: serializer.fromJson<String>(json['description']),
      quantity: serializer.fromJson<int>(json['quantity']),
      unitPriceMinorUnits:
          serializer.fromJson<int>(json['unitPriceMinorUnits']),
      currency: serializer.fromJson<String>(json['currency']),
    );
  }
  @override
  Map<String, dynamic> toJson({ValueSerializer? serializer}) {
    serializer ??= driftRuntimeOptions.defaultSerializer;
    return <String, dynamic>{
      'id': serializer.toJson<int>(id),
      'creditNoteId': serializer.toJson<String>(creditNoteId),
      'lineNumber': serializer.toJson<int>(lineNumber),
      'description': serializer.toJson<String>(description),
      'quantity': serializer.toJson<int>(quantity),
      'unitPriceMinorUnits': serializer.toJson<int>(unitPriceMinorUnits),
      'currency': serializer.toJson<String>(currency),
    };
  }

  CreditNoteLineRow copyWith(
          {int? id,
          String? creditNoteId,
          int? lineNumber,
          String? description,
          int? quantity,
          int? unitPriceMinorUnits,
          String? currency}) =>
      CreditNoteLineRow(
        id: id ?? this.id,
        creditNoteId: creditNoteId ?? this.creditNoteId,
        lineNumber: lineNumber ?? this.lineNumber,
        description: description ?? this.description,
        quantity: quantity ?? this.quantity,
        unitPriceMinorUnits: unitPriceMinorUnits ?? this.unitPriceMinorUnits,
        currency: currency ?? this.currency,
      );
  CreditNoteLineRow copyWithCompanion(CreditNoteLinesCompanion data) {
    return CreditNoteLineRow(
      id: data.id.present ? data.id.value : this.id,
      creditNoteId: data.creditNoteId.present
          ? data.creditNoteId.value
          : this.creditNoteId,
      lineNumber:
          data.lineNumber.present ? data.lineNumber.value : this.lineNumber,
      description:
          data.description.present ? data.description.value : this.description,
      quantity: data.quantity.present ? data.quantity.value : this.quantity,
      unitPriceMinorUnits: data.unitPriceMinorUnits.present
          ? data.unitPriceMinorUnits.value
          : this.unitPriceMinorUnits,
      currency: data.currency.present ? data.currency.value : this.currency,
    );
  }

  @override
  String toString() {
    return (StringBuffer('CreditNoteLineRow(')
          ..write('id: $id, ')
          ..write('creditNoteId: $creditNoteId, ')
          ..write('lineNumber: $lineNumber, ')
          ..write('description: $description, ')
          ..write('quantity: $quantity, ')
          ..write('unitPriceMinorUnits: $unitPriceMinorUnits, ')
          ..write('currency: $currency')
          ..write(')'))
        .toString();
  }

  @override
  int get hashCode => Object.hash(id, creditNoteId, lineNumber, description,
      quantity, unitPriceMinorUnits, currency);
  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      (other is CreditNoteLineRow &&
          other.id == this.id &&
          other.creditNoteId == this.creditNoteId &&
          other.lineNumber == this.lineNumber &&
          other.description == this.description &&
          other.quantity == this.quantity &&
          other.unitPriceMinorUnits == this.unitPriceMinorUnits &&
          other.currency == this.currency);
}

class CreditNoteLinesCompanion extends UpdateCompanion<CreditNoteLineRow> {
  final Value<int> id;
  final Value<String> creditNoteId;
  final Value<int> lineNumber;
  final Value<String> description;
  final Value<int> quantity;
  final Value<int> unitPriceMinorUnits;
  final Value<String> currency;
  const CreditNoteLinesCompanion({
    this.id = const Value.absent(),
    this.creditNoteId = const Value.absent(),
    this.lineNumber = const Value.absent(),
    this.description = const Value.absent(),
    this.quantity = const Value.absent(),
    this.unitPriceMinorUnits = const Value.absent(),
    this.currency = const Value.absent(),
  });
  CreditNoteLinesCompanion.insert({
    this.id = const Value.absent(),
    required String creditNoteId,
    required int lineNumber,
    required String description,
    required int quantity,
    required int unitPriceMinorUnits,
    required String currency,
  })  : creditNoteId = Value(creditNoteId),
        lineNumber = Value(lineNumber),
        description = Value(description),
        quantity = Value(quantity),
        unitPriceMinorUnits = Value(unitPriceMinorUnits),
        currency = Value(currency);
  static Insertable<CreditNoteLineRow> custom({
    Expression<int>? id,
    Expression<String>? creditNoteId,
    Expression<int>? lineNumber,
    Expression<String>? description,
    Expression<int>? quantity,
    Expression<int>? unitPriceMinorUnits,
    Expression<String>? currency,
  }) {
    return RawValuesInsertable({
      if (id != null) 'id': id,
      if (creditNoteId != null) 'credit_note_id': creditNoteId,
      if (lineNumber != null) 'line_number': lineNumber,
      if (description != null) 'description': description,
      if (quantity != null) 'quantity': quantity,
      if (unitPriceMinorUnits != null)
        'unit_price_minor_units': unitPriceMinorUnits,
      if (currency != null) 'currency': currency,
    });
  }

  CreditNoteLinesCompanion copyWith(
      {Value<int>? id,
      Value<String>? creditNoteId,
      Value<int>? lineNumber,
      Value<String>? description,
      Value<int>? quantity,
      Value<int>? unitPriceMinorUnits,
      Value<String>? currency}) {
    return CreditNoteLinesCompanion(
      id: id ?? this.id,
      creditNoteId: creditNoteId ?? this.creditNoteId,
      lineNumber: lineNumber ?? this.lineNumber,
      description: description ?? this.description,
      quantity: quantity ?? this.quantity,
      unitPriceMinorUnits: unitPriceMinorUnits ?? this.unitPriceMinorUnits,
      currency: currency ?? this.currency,
    );
  }

  @override
  Map<String, Expression> toColumns(bool nullToAbsent) {
    final map = <String, Expression>{};
    if (id.present) {
      map['id'] = Variable<int>(id.value);
    }
    if (creditNoteId.present) {
      map['credit_note_id'] = Variable<String>(creditNoteId.value);
    }
    if (lineNumber.present) {
      map['line_number'] = Variable<int>(lineNumber.value);
    }
    if (description.present) {
      map['description'] = Variable<String>(description.value);
    }
    if (quantity.present) {
      map['quantity'] = Variable<int>(quantity.value);
    }
    if (unitPriceMinorUnits.present) {
      map['unit_price_minor_units'] = Variable<int>(unitPriceMinorUnits.value);
    }
    if (currency.present) {
      map['currency'] = Variable<String>(currency.value);
    }
    return map;
  }

  @override
  String toString() {
    return (StringBuffer('CreditNoteLinesCompanion(')
          ..write('id: $id, ')
          ..write('creditNoteId: $creditNoteId, ')
          ..write('lineNumber: $lineNumber, ')
          ..write('description: $description, ')
          ..write('quantity: $quantity, ')
          ..write('unitPriceMinorUnits: $unitPriceMinorUnits, ')
          ..write('currency: $currency')
          ..write(')'))
        .toString();
  }
}

class $ProductsTable extends Products
    with TableInfo<$ProductsTable, ProductRow> {
  @override
  final GeneratedDatabase attachedDatabase;
  final String? _alias;
  $ProductsTable(this.attachedDatabase, [this._alias]);
  static const VerificationMeta _idMeta = const VerificationMeta('id');
  @override
  late final GeneratedColumn<String> id = GeneratedColumn<String>(
      'id', aliasedName, false,
      type: DriftSqlType.string, requiredDuringInsert: true);
  static const VerificationMeta _nameMeta = const VerificationMeta('name');
  @override
  late final GeneratedColumn<String> name = GeneratedColumn<String>(
      'name', aliasedName, false,
      type: DriftSqlType.string, requiredDuringInsert: true);
  static const VerificationMeta _salePriceMinorUnitsMeta =
      const VerificationMeta('salePriceMinorUnits');
  @override
  late final GeneratedColumn<int> salePriceMinorUnits = GeneratedColumn<int>(
      'sale_price_minor_units', aliasedName, false,
      type: DriftSqlType.int, requiredDuringInsert: true);
  static const VerificationMeta _currencyMeta =
      const VerificationMeta('currency');
  @override
  late final GeneratedColumn<String> currency = GeneratedColumn<String>(
      'currency', aliasedName, false,
      type: DriftSqlType.string, requiredDuringInsert: true);
  static const VerificationMeta _stockTrackingEnabledMeta =
      const VerificationMeta('stockTrackingEnabled');
  @override
  late final GeneratedColumn<bool> stockTrackingEnabled = GeneratedColumn<bool>(
      'stock_tracking_enabled', aliasedName, false,
      type: DriftSqlType.bool,
      requiredDuringInsert: true,
      defaultConstraints: GeneratedColumn.constraintIsAlways(
          'CHECK ("stock_tracking_enabled" IN (0, 1))'));
  @override
  List<GeneratedColumn> get $columns =>
      [id, name, salePriceMinorUnits, currency, stockTrackingEnabled];
  @override
  String get aliasedName => _alias ?? actualTableName;
  @override
  String get actualTableName => $name;
  static const String $name = 'products';
  @override
  VerificationContext validateIntegrity(Insertable<ProductRow> instance,
      {bool isInserting = false}) {
    final context = VerificationContext();
    final data = instance.toColumns(true);
    if (data.containsKey('id')) {
      context.handle(_idMeta, id.isAcceptableOrUnknown(data['id']!, _idMeta));
    } else if (isInserting) {
      context.missing(_idMeta);
    }
    if (data.containsKey('name')) {
      context.handle(
          _nameMeta, name.isAcceptableOrUnknown(data['name']!, _nameMeta));
    } else if (isInserting) {
      context.missing(_nameMeta);
    }
    if (data.containsKey('sale_price_minor_units')) {
      context.handle(
          _salePriceMinorUnitsMeta,
          salePriceMinorUnits.isAcceptableOrUnknown(
              data['sale_price_minor_units']!, _salePriceMinorUnitsMeta));
    } else if (isInserting) {
      context.missing(_salePriceMinorUnitsMeta);
    }
    if (data.containsKey('currency')) {
      context.handle(_currencyMeta,
          currency.isAcceptableOrUnknown(data['currency']!, _currencyMeta));
    } else if (isInserting) {
      context.missing(_currencyMeta);
    }
    if (data.containsKey('stock_tracking_enabled')) {
      context.handle(
          _stockTrackingEnabledMeta,
          stockTrackingEnabled.isAcceptableOrUnknown(
              data['stock_tracking_enabled']!, _stockTrackingEnabledMeta));
    } else if (isInserting) {
      context.missing(_stockTrackingEnabledMeta);
    }
    return context;
  }

  @override
  Set<GeneratedColumn> get $primaryKey => {id};
  @override
  ProductRow map(Map<String, dynamic> data, {String? tablePrefix}) {
    final effectivePrefix = tablePrefix != null ? '$tablePrefix.' : '';
    return ProductRow(
      id: attachedDatabase.typeMapping
          .read(DriftSqlType.string, data['${effectivePrefix}id'])!,
      name: attachedDatabase.typeMapping
          .read(DriftSqlType.string, data['${effectivePrefix}name'])!,
      salePriceMinorUnits: attachedDatabase.typeMapping.read(
          DriftSqlType.int, data['${effectivePrefix}sale_price_minor_units'])!,
      currency: attachedDatabase.typeMapping
          .read(DriftSqlType.string, data['${effectivePrefix}currency'])!,
      stockTrackingEnabled: attachedDatabase.typeMapping.read(
          DriftSqlType.bool, data['${effectivePrefix}stock_tracking_enabled'])!,
    );
  }

  @override
  $ProductsTable createAlias(String alias) {
    return $ProductsTable(attachedDatabase, alias);
  }
}

class ProductRow extends DataClass implements Insertable<ProductRow> {
  final String id;
  final String name;

  /// Sale price in **INTEGER minor units**, never REAL.
  final int salePriceMinorUnits;
  final String currency;
  final bool stockTrackingEnabled;
  const ProductRow(
      {required this.id,
      required this.name,
      required this.salePriceMinorUnits,
      required this.currency,
      required this.stockTrackingEnabled});
  @override
  Map<String, Expression> toColumns(bool nullToAbsent) {
    final map = <String, Expression>{};
    map['id'] = Variable<String>(id);
    map['name'] = Variable<String>(name);
    map['sale_price_minor_units'] = Variable<int>(salePriceMinorUnits);
    map['currency'] = Variable<String>(currency);
    map['stock_tracking_enabled'] = Variable<bool>(stockTrackingEnabled);
    return map;
  }

  ProductsCompanion toCompanion(bool nullToAbsent) {
    return ProductsCompanion(
      id: Value(id),
      name: Value(name),
      salePriceMinorUnits: Value(salePriceMinorUnits),
      currency: Value(currency),
      stockTrackingEnabled: Value(stockTrackingEnabled),
    );
  }

  factory ProductRow.fromJson(Map<String, dynamic> json,
      {ValueSerializer? serializer}) {
    serializer ??= driftRuntimeOptions.defaultSerializer;
    return ProductRow(
      id: serializer.fromJson<String>(json['id']),
      name: serializer.fromJson<String>(json['name']),
      salePriceMinorUnits:
          serializer.fromJson<int>(json['salePriceMinorUnits']),
      currency: serializer.fromJson<String>(json['currency']),
      stockTrackingEnabled:
          serializer.fromJson<bool>(json['stockTrackingEnabled']),
    );
  }
  @override
  Map<String, dynamic> toJson({ValueSerializer? serializer}) {
    serializer ??= driftRuntimeOptions.defaultSerializer;
    return <String, dynamic>{
      'id': serializer.toJson<String>(id),
      'name': serializer.toJson<String>(name),
      'salePriceMinorUnits': serializer.toJson<int>(salePriceMinorUnits),
      'currency': serializer.toJson<String>(currency),
      'stockTrackingEnabled': serializer.toJson<bool>(stockTrackingEnabled),
    };
  }

  ProductRow copyWith(
          {String? id,
          String? name,
          int? salePriceMinorUnits,
          String? currency,
          bool? stockTrackingEnabled}) =>
      ProductRow(
        id: id ?? this.id,
        name: name ?? this.name,
        salePriceMinorUnits: salePriceMinorUnits ?? this.salePriceMinorUnits,
        currency: currency ?? this.currency,
        stockTrackingEnabled: stockTrackingEnabled ?? this.stockTrackingEnabled,
      );
  ProductRow copyWithCompanion(ProductsCompanion data) {
    return ProductRow(
      id: data.id.present ? data.id.value : this.id,
      name: data.name.present ? data.name.value : this.name,
      salePriceMinorUnits: data.salePriceMinorUnits.present
          ? data.salePriceMinorUnits.value
          : this.salePriceMinorUnits,
      currency: data.currency.present ? data.currency.value : this.currency,
      stockTrackingEnabled: data.stockTrackingEnabled.present
          ? data.stockTrackingEnabled.value
          : this.stockTrackingEnabled,
    );
  }

  @override
  String toString() {
    return (StringBuffer('ProductRow(')
          ..write('id: $id, ')
          ..write('name: $name, ')
          ..write('salePriceMinorUnits: $salePriceMinorUnits, ')
          ..write('currency: $currency, ')
          ..write('stockTrackingEnabled: $stockTrackingEnabled')
          ..write(')'))
        .toString();
  }

  @override
  int get hashCode => Object.hash(
      id, name, salePriceMinorUnits, currency, stockTrackingEnabled);
  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      (other is ProductRow &&
          other.id == this.id &&
          other.name == this.name &&
          other.salePriceMinorUnits == this.salePriceMinorUnits &&
          other.currency == this.currency &&
          other.stockTrackingEnabled == this.stockTrackingEnabled);
}

class ProductsCompanion extends UpdateCompanion<ProductRow> {
  final Value<String> id;
  final Value<String> name;
  final Value<int> salePriceMinorUnits;
  final Value<String> currency;
  final Value<bool> stockTrackingEnabled;
  final Value<int> rowid;
  const ProductsCompanion({
    this.id = const Value.absent(),
    this.name = const Value.absent(),
    this.salePriceMinorUnits = const Value.absent(),
    this.currency = const Value.absent(),
    this.stockTrackingEnabled = const Value.absent(),
    this.rowid = const Value.absent(),
  });
  ProductsCompanion.insert({
    required String id,
    required String name,
    required int salePriceMinorUnits,
    required String currency,
    required bool stockTrackingEnabled,
    this.rowid = const Value.absent(),
  })  : id = Value(id),
        name = Value(name),
        salePriceMinorUnits = Value(salePriceMinorUnits),
        currency = Value(currency),
        stockTrackingEnabled = Value(stockTrackingEnabled);
  static Insertable<ProductRow> custom({
    Expression<String>? id,
    Expression<String>? name,
    Expression<int>? salePriceMinorUnits,
    Expression<String>? currency,
    Expression<bool>? stockTrackingEnabled,
    Expression<int>? rowid,
  }) {
    return RawValuesInsertable({
      if (id != null) 'id': id,
      if (name != null) 'name': name,
      if (salePriceMinorUnits != null)
        'sale_price_minor_units': salePriceMinorUnits,
      if (currency != null) 'currency': currency,
      if (stockTrackingEnabled != null)
        'stock_tracking_enabled': stockTrackingEnabled,
      if (rowid != null) 'rowid': rowid,
    });
  }

  ProductsCompanion copyWith(
      {Value<String>? id,
      Value<String>? name,
      Value<int>? salePriceMinorUnits,
      Value<String>? currency,
      Value<bool>? stockTrackingEnabled,
      Value<int>? rowid}) {
    return ProductsCompanion(
      id: id ?? this.id,
      name: name ?? this.name,
      salePriceMinorUnits: salePriceMinorUnits ?? this.salePriceMinorUnits,
      currency: currency ?? this.currency,
      stockTrackingEnabled: stockTrackingEnabled ?? this.stockTrackingEnabled,
      rowid: rowid ?? this.rowid,
    );
  }

  @override
  Map<String, Expression> toColumns(bool nullToAbsent) {
    final map = <String, Expression>{};
    if (id.present) {
      map['id'] = Variable<String>(id.value);
    }
    if (name.present) {
      map['name'] = Variable<String>(name.value);
    }
    if (salePriceMinorUnits.present) {
      map['sale_price_minor_units'] = Variable<int>(salePriceMinorUnits.value);
    }
    if (currency.present) {
      map['currency'] = Variable<String>(currency.value);
    }
    if (stockTrackingEnabled.present) {
      map['stock_tracking_enabled'] =
          Variable<bool>(stockTrackingEnabled.value);
    }
    if (rowid.present) {
      map['rowid'] = Variable<int>(rowid.value);
    }
    return map;
  }

  @override
  String toString() {
    return (StringBuffer('ProductsCompanion(')
          ..write('id: $id, ')
          ..write('name: $name, ')
          ..write('salePriceMinorUnits: $salePriceMinorUnits, ')
          ..write('currency: $currency, ')
          ..write('stockTrackingEnabled: $stockTrackingEnabled, ')
          ..write('rowid: $rowid')
          ..write(')'))
        .toString();
  }
}

class $InventoryMovementsTable extends InventoryMovements
    with TableInfo<$InventoryMovementsTable, InventoryMovementRow> {
  @override
  final GeneratedDatabase attachedDatabase;
  final String? _alias;
  $InventoryMovementsTable(this.attachedDatabase, [this._alias]);
  static const VerificationMeta _idMeta = const VerificationMeta('id');
  @override
  late final GeneratedColumn<String> id = GeneratedColumn<String>(
      'id', aliasedName, false,
      type: DriftSqlType.string, requiredDuringInsert: true);
  static const VerificationMeta _productIdMeta =
      const VerificationMeta('productId');
  @override
  late final GeneratedColumn<String> productId = GeneratedColumn<String>(
      'product_id', aliasedName, false,
      type: DriftSqlType.string, requiredDuringInsert: true);
  static const VerificationMeta _dateMeta = const VerificationMeta('date');
  @override
  late final GeneratedColumn<DateTime> date = GeneratedColumn<DateTime>(
      'date', aliasedName, false,
      type: DriftSqlType.dateTime, requiredDuringInsert: true);
  static const VerificationMeta _reasonMeta = const VerificationMeta('reason');
  @override
  late final GeneratedColumn<String> reason = GeneratedColumn<String>(
      'reason', aliasedName, false,
      type: DriftSqlType.string, requiredDuringInsert: true);
  static const VerificationMeta _quantityMeta =
      const VerificationMeta('quantity');
  @override
  late final GeneratedColumn<int> quantity = GeneratedColumn<int>(
      'quantity', aliasedName, false,
      type: DriftSqlType.int, requiredDuringInsert: true);
  static const VerificationMeta _valueMinorUnitsMeta =
      const VerificationMeta('valueMinorUnits');
  @override
  late final GeneratedColumn<int> valueMinorUnits = GeneratedColumn<int>(
      'value_minor_units', aliasedName, false,
      type: DriftSqlType.int, requiredDuringInsert: true);
  static const VerificationMeta _currencyMeta =
      const VerificationMeta('currency');
  @override
  late final GeneratedColumn<String> currency = GeneratedColumn<String>(
      'currency', aliasedName, false,
      type: DriftSqlType.string, requiredDuringInsert: true);
  static const VerificationMeta _journalEntryIdMeta =
      const VerificationMeta('journalEntryId');
  @override
  late final GeneratedColumn<String> journalEntryId = GeneratedColumn<String>(
      'journal_entry_id', aliasedName, true,
      type: DriftSqlType.string, requiredDuringInsert: false);
  @override
  List<GeneratedColumn> get $columns => [
        id,
        productId,
        date,
        reason,
        quantity,
        valueMinorUnits,
        currency,
        journalEntryId
      ];
  @override
  String get aliasedName => _alias ?? actualTableName;
  @override
  String get actualTableName => $name;
  static const String $name = 'inventory_movements';
  @override
  VerificationContext validateIntegrity(
      Insertable<InventoryMovementRow> instance,
      {bool isInserting = false}) {
    final context = VerificationContext();
    final data = instance.toColumns(true);
    if (data.containsKey('id')) {
      context.handle(_idMeta, id.isAcceptableOrUnknown(data['id']!, _idMeta));
    } else if (isInserting) {
      context.missing(_idMeta);
    }
    if (data.containsKey('product_id')) {
      context.handle(_productIdMeta,
          productId.isAcceptableOrUnknown(data['product_id']!, _productIdMeta));
    } else if (isInserting) {
      context.missing(_productIdMeta);
    }
    if (data.containsKey('date')) {
      context.handle(
          _dateMeta, date.isAcceptableOrUnknown(data['date']!, _dateMeta));
    } else if (isInserting) {
      context.missing(_dateMeta);
    }
    if (data.containsKey('reason')) {
      context.handle(_reasonMeta,
          reason.isAcceptableOrUnknown(data['reason']!, _reasonMeta));
    } else if (isInserting) {
      context.missing(_reasonMeta);
    }
    if (data.containsKey('quantity')) {
      context.handle(_quantityMeta,
          quantity.isAcceptableOrUnknown(data['quantity']!, _quantityMeta));
    } else if (isInserting) {
      context.missing(_quantityMeta);
    }
    if (data.containsKey('value_minor_units')) {
      context.handle(
          _valueMinorUnitsMeta,
          valueMinorUnits.isAcceptableOrUnknown(
              data['value_minor_units']!, _valueMinorUnitsMeta));
    } else if (isInserting) {
      context.missing(_valueMinorUnitsMeta);
    }
    if (data.containsKey('currency')) {
      context.handle(_currencyMeta,
          currency.isAcceptableOrUnknown(data['currency']!, _currencyMeta));
    } else if (isInserting) {
      context.missing(_currencyMeta);
    }
    if (data.containsKey('journal_entry_id')) {
      context.handle(
          _journalEntryIdMeta,
          journalEntryId.isAcceptableOrUnknown(
              data['journal_entry_id']!, _journalEntryIdMeta));
    }
    return context;
  }

  @override
  Set<GeneratedColumn> get $primaryKey => {id};
  @override
  InventoryMovementRow map(Map<String, dynamic> data, {String? tablePrefix}) {
    final effectivePrefix = tablePrefix != null ? '$tablePrefix.' : '';
    return InventoryMovementRow(
      id: attachedDatabase.typeMapping
          .read(DriftSqlType.string, data['${effectivePrefix}id'])!,
      productId: attachedDatabase.typeMapping
          .read(DriftSqlType.string, data['${effectivePrefix}product_id'])!,
      date: attachedDatabase.typeMapping
          .read(DriftSqlType.dateTime, data['${effectivePrefix}date'])!,
      reason: attachedDatabase.typeMapping
          .read(DriftSqlType.string, data['${effectivePrefix}reason'])!,
      quantity: attachedDatabase.typeMapping
          .read(DriftSqlType.int, data['${effectivePrefix}quantity'])!,
      valueMinorUnits: attachedDatabase.typeMapping
          .read(DriftSqlType.int, data['${effectivePrefix}value_minor_units'])!,
      currency: attachedDatabase.typeMapping
          .read(DriftSqlType.string, data['${effectivePrefix}currency'])!,
      journalEntryId: attachedDatabase.typeMapping.read(
          DriftSqlType.string, data['${effectivePrefix}journal_entry_id']),
    );
  }

  @override
  $InventoryMovementsTable createAlias(String alias) {
    return $InventoryMovementsTable(attachedDatabase, alias);
  }
}

class InventoryMovementRow extends DataClass
    implements Insertable<InventoryMovementRow> {
  final String id;
  final String productId;
  final DateTime date;

  /// The `MovementReason` name, for example `purchase`.
  final String reason;

  /// Signed units. Positive is stock coming in.
  final int quantity;

  /// Signed value in minor units. Same sign as `quantity`.
  final int valueMinorUnits;
  final String currency;

  /// The journal entry this movement posted, once it has been posted.
  ///
  /// **Nullable only for rows written before v8, and for a non-stock-tracked
  /// product where a movement may carry no accounting.** Every movement written
  /// by the posting use case sets it. It is not made non-nullable because
  /// backfilling a value that does not exist would be a lie, and because a
  /// movement is a physical fact that must be recordable even when its accounting
  /// is still pending.
  final String? journalEntryId;
  const InventoryMovementRow(
      {required this.id,
      required this.productId,
      required this.date,
      required this.reason,
      required this.quantity,
      required this.valueMinorUnits,
      required this.currency,
      this.journalEntryId});
  @override
  Map<String, Expression> toColumns(bool nullToAbsent) {
    final map = <String, Expression>{};
    map['id'] = Variable<String>(id);
    map['product_id'] = Variable<String>(productId);
    map['date'] = Variable<DateTime>(date);
    map['reason'] = Variable<String>(reason);
    map['quantity'] = Variable<int>(quantity);
    map['value_minor_units'] = Variable<int>(valueMinorUnits);
    map['currency'] = Variable<String>(currency);
    if (!nullToAbsent || journalEntryId != null) {
      map['journal_entry_id'] = Variable<String>(journalEntryId);
    }
    return map;
  }

  InventoryMovementsCompanion toCompanion(bool nullToAbsent) {
    return InventoryMovementsCompanion(
      id: Value(id),
      productId: Value(productId),
      date: Value(date),
      reason: Value(reason),
      quantity: Value(quantity),
      valueMinorUnits: Value(valueMinorUnits),
      currency: Value(currency),
      journalEntryId: journalEntryId == null && nullToAbsent
          ? const Value.absent()
          : Value(journalEntryId),
    );
  }

  factory InventoryMovementRow.fromJson(Map<String, dynamic> json,
      {ValueSerializer? serializer}) {
    serializer ??= driftRuntimeOptions.defaultSerializer;
    return InventoryMovementRow(
      id: serializer.fromJson<String>(json['id']),
      productId: serializer.fromJson<String>(json['productId']),
      date: serializer.fromJson<DateTime>(json['date']),
      reason: serializer.fromJson<String>(json['reason']),
      quantity: serializer.fromJson<int>(json['quantity']),
      valueMinorUnits: serializer.fromJson<int>(json['valueMinorUnits']),
      currency: serializer.fromJson<String>(json['currency']),
      journalEntryId: serializer.fromJson<String?>(json['journalEntryId']),
    );
  }
  @override
  Map<String, dynamic> toJson({ValueSerializer? serializer}) {
    serializer ??= driftRuntimeOptions.defaultSerializer;
    return <String, dynamic>{
      'id': serializer.toJson<String>(id),
      'productId': serializer.toJson<String>(productId),
      'date': serializer.toJson<DateTime>(date),
      'reason': serializer.toJson<String>(reason),
      'quantity': serializer.toJson<int>(quantity),
      'valueMinorUnits': serializer.toJson<int>(valueMinorUnits),
      'currency': serializer.toJson<String>(currency),
      'journalEntryId': serializer.toJson<String?>(journalEntryId),
    };
  }

  InventoryMovementRow copyWith(
          {String? id,
          String? productId,
          DateTime? date,
          String? reason,
          int? quantity,
          int? valueMinorUnits,
          String? currency,
          Value<String?> journalEntryId = const Value.absent()}) =>
      InventoryMovementRow(
        id: id ?? this.id,
        productId: productId ?? this.productId,
        date: date ?? this.date,
        reason: reason ?? this.reason,
        quantity: quantity ?? this.quantity,
        valueMinorUnits: valueMinorUnits ?? this.valueMinorUnits,
        currency: currency ?? this.currency,
        journalEntryId:
            journalEntryId.present ? journalEntryId.value : this.journalEntryId,
      );
  InventoryMovementRow copyWithCompanion(InventoryMovementsCompanion data) {
    return InventoryMovementRow(
      id: data.id.present ? data.id.value : this.id,
      productId: data.productId.present ? data.productId.value : this.productId,
      date: data.date.present ? data.date.value : this.date,
      reason: data.reason.present ? data.reason.value : this.reason,
      quantity: data.quantity.present ? data.quantity.value : this.quantity,
      valueMinorUnits: data.valueMinorUnits.present
          ? data.valueMinorUnits.value
          : this.valueMinorUnits,
      currency: data.currency.present ? data.currency.value : this.currency,
      journalEntryId: data.journalEntryId.present
          ? data.journalEntryId.value
          : this.journalEntryId,
    );
  }

  @override
  String toString() {
    return (StringBuffer('InventoryMovementRow(')
          ..write('id: $id, ')
          ..write('productId: $productId, ')
          ..write('date: $date, ')
          ..write('reason: $reason, ')
          ..write('quantity: $quantity, ')
          ..write('valueMinorUnits: $valueMinorUnits, ')
          ..write('currency: $currency, ')
          ..write('journalEntryId: $journalEntryId')
          ..write(')'))
        .toString();
  }

  @override
  int get hashCode => Object.hash(id, productId, date, reason, quantity,
      valueMinorUnits, currency, journalEntryId);
  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      (other is InventoryMovementRow &&
          other.id == this.id &&
          other.productId == this.productId &&
          other.date == this.date &&
          other.reason == this.reason &&
          other.quantity == this.quantity &&
          other.valueMinorUnits == this.valueMinorUnits &&
          other.currency == this.currency &&
          other.journalEntryId == this.journalEntryId);
}

class InventoryMovementsCompanion
    extends UpdateCompanion<InventoryMovementRow> {
  final Value<String> id;
  final Value<String> productId;
  final Value<DateTime> date;
  final Value<String> reason;
  final Value<int> quantity;
  final Value<int> valueMinorUnits;
  final Value<String> currency;
  final Value<String?> journalEntryId;
  final Value<int> rowid;
  const InventoryMovementsCompanion({
    this.id = const Value.absent(),
    this.productId = const Value.absent(),
    this.date = const Value.absent(),
    this.reason = const Value.absent(),
    this.quantity = const Value.absent(),
    this.valueMinorUnits = const Value.absent(),
    this.currency = const Value.absent(),
    this.journalEntryId = const Value.absent(),
    this.rowid = const Value.absent(),
  });
  InventoryMovementsCompanion.insert({
    required String id,
    required String productId,
    required DateTime date,
    required String reason,
    required int quantity,
    required int valueMinorUnits,
    required String currency,
    this.journalEntryId = const Value.absent(),
    this.rowid = const Value.absent(),
  })  : id = Value(id),
        productId = Value(productId),
        date = Value(date),
        reason = Value(reason),
        quantity = Value(quantity),
        valueMinorUnits = Value(valueMinorUnits),
        currency = Value(currency);
  static Insertable<InventoryMovementRow> custom({
    Expression<String>? id,
    Expression<String>? productId,
    Expression<DateTime>? date,
    Expression<String>? reason,
    Expression<int>? quantity,
    Expression<int>? valueMinorUnits,
    Expression<String>? currency,
    Expression<String>? journalEntryId,
    Expression<int>? rowid,
  }) {
    return RawValuesInsertable({
      if (id != null) 'id': id,
      if (productId != null) 'product_id': productId,
      if (date != null) 'date': date,
      if (reason != null) 'reason': reason,
      if (quantity != null) 'quantity': quantity,
      if (valueMinorUnits != null) 'value_minor_units': valueMinorUnits,
      if (currency != null) 'currency': currency,
      if (journalEntryId != null) 'journal_entry_id': journalEntryId,
      if (rowid != null) 'rowid': rowid,
    });
  }

  InventoryMovementsCompanion copyWith(
      {Value<String>? id,
      Value<String>? productId,
      Value<DateTime>? date,
      Value<String>? reason,
      Value<int>? quantity,
      Value<int>? valueMinorUnits,
      Value<String>? currency,
      Value<String?>? journalEntryId,
      Value<int>? rowid}) {
    return InventoryMovementsCompanion(
      id: id ?? this.id,
      productId: productId ?? this.productId,
      date: date ?? this.date,
      reason: reason ?? this.reason,
      quantity: quantity ?? this.quantity,
      valueMinorUnits: valueMinorUnits ?? this.valueMinorUnits,
      currency: currency ?? this.currency,
      journalEntryId: journalEntryId ?? this.journalEntryId,
      rowid: rowid ?? this.rowid,
    );
  }

  @override
  Map<String, Expression> toColumns(bool nullToAbsent) {
    final map = <String, Expression>{};
    if (id.present) {
      map['id'] = Variable<String>(id.value);
    }
    if (productId.present) {
      map['product_id'] = Variable<String>(productId.value);
    }
    if (date.present) {
      map['date'] = Variable<DateTime>(date.value);
    }
    if (reason.present) {
      map['reason'] = Variable<String>(reason.value);
    }
    if (quantity.present) {
      map['quantity'] = Variable<int>(quantity.value);
    }
    if (valueMinorUnits.present) {
      map['value_minor_units'] = Variable<int>(valueMinorUnits.value);
    }
    if (currency.present) {
      map['currency'] = Variable<String>(currency.value);
    }
    if (journalEntryId.present) {
      map['journal_entry_id'] = Variable<String>(journalEntryId.value);
    }
    if (rowid.present) {
      map['rowid'] = Variable<int>(rowid.value);
    }
    return map;
  }

  @override
  String toString() {
    return (StringBuffer('InventoryMovementsCompanion(')
          ..write('id: $id, ')
          ..write('productId: $productId, ')
          ..write('date: $date, ')
          ..write('reason: $reason, ')
          ..write('quantity: $quantity, ')
          ..write('valueMinorUnits: $valueMinorUnits, ')
          ..write('currency: $currency, ')
          ..write('journalEntryId: $journalEntryId, ')
          ..write('rowid: $rowid')
          ..write(')'))
        .toString();
  }
}

class $CustomerDetailsTable extends CustomerDetails
    with TableInfo<$CustomerDetailsTable, CustomerDetailRow> {
  @override
  final GeneratedDatabase attachedDatabase;
  final String? _alias;
  $CustomerDetailsTable(this.attachedDatabase, [this._alias]);
  static const VerificationMeta _customerIdMeta =
      const VerificationMeta('customerId');
  @override
  late final GeneratedColumn<String> customerId = GeneratedColumn<String>(
      'customer_id', aliasedName, false,
      type: DriftSqlType.string, requiredDuringInsert: true);
  static const VerificationMeta _codeMeta = const VerificationMeta('code');
  @override
  late final GeneratedColumn<String> code = GeneratedColumn<String>(
      'code', aliasedName, true,
      type: DriftSqlType.string, requiredDuringInsert: false);
  static const VerificationMeta _isVatRegisteredMeta =
      const VerificationMeta('isVatRegistered');
  @override
  late final GeneratedColumn<bool> isVatRegistered = GeneratedColumn<bool>(
      'is_vat_registered', aliasedName, false,
      type: DriftSqlType.bool,
      requiredDuringInsert: false,
      defaultConstraints: GeneratedColumn.constraintIsAlways(
          'CHECK ("is_vat_registered" IN (0, 1))'),
      defaultValue: const Constant(false));
  static const VerificationMeta _businessNameMeta =
      const VerificationMeta('businessName');
  @override
  late final GeneratedColumn<String> businessName = GeneratedColumn<String>(
      'business_name', aliasedName, true,
      type: DriftSqlType.string, requiredDuringInsert: false);
  @override
  List<GeneratedColumn> get $columns =>
      [customerId, code, isVatRegistered, businessName];
  @override
  String get aliasedName => _alias ?? actualTableName;
  @override
  String get actualTableName => $name;
  static const String $name = 'customer_details';
  @override
  VerificationContext validateIntegrity(Insertable<CustomerDetailRow> instance,
      {bool isInserting = false}) {
    final context = VerificationContext();
    final data = instance.toColumns(true);
    if (data.containsKey('customer_id')) {
      context.handle(
          _customerIdMeta,
          customerId.isAcceptableOrUnknown(
              data['customer_id']!, _customerIdMeta));
    } else if (isInserting) {
      context.missing(_customerIdMeta);
    }
    if (data.containsKey('code')) {
      context.handle(
          _codeMeta, code.isAcceptableOrUnknown(data['code']!, _codeMeta));
    }
    if (data.containsKey('is_vat_registered')) {
      context.handle(
          _isVatRegisteredMeta,
          isVatRegistered.isAcceptableOrUnknown(
              data['is_vat_registered']!, _isVatRegisteredMeta));
    }
    if (data.containsKey('business_name')) {
      context.handle(
          _businessNameMeta,
          businessName.isAcceptableOrUnknown(
              data['business_name']!, _businessNameMeta));
    }
    return context;
  }

  @override
  Set<GeneratedColumn> get $primaryKey => {customerId};
  @override
  List<Set<GeneratedColumn>> get uniqueKeys => [
        {code},
      ];
  @override
  CustomerDetailRow map(Map<String, dynamic> data, {String? tablePrefix}) {
    final effectivePrefix = tablePrefix != null ? '$tablePrefix.' : '';
    return CustomerDetailRow(
      customerId: attachedDatabase.typeMapping
          .read(DriftSqlType.string, data['${effectivePrefix}customer_id'])!,
      code: attachedDatabase.typeMapping
          .read(DriftSqlType.string, data['${effectivePrefix}code']),
      isVatRegistered: attachedDatabase.typeMapping.read(
          DriftSqlType.bool, data['${effectivePrefix}is_vat_registered'])!,
      businessName: attachedDatabase.typeMapping
          .read(DriftSqlType.string, data['${effectivePrefix}business_name']),
    );
  }

  @override
  $CustomerDetailsTable createAlias(String alias) {
    return $CustomerDetailsTable(attachedDatabase, alias);
  }
}

class CustomerDetailRow extends DataClass
    implements Insertable<CustomerDetailRow> {
  /// The customer this describes. One row per customer at most.
  final String customerId;

  /// The business reference, such as `C-0001`. Not the identity.
  final String? code;

  /// Whether VAT registration is active. Stated, never inferred -- see
  /// `Customer.isVatRegistered` for why.
  final bool isVatRegistered;

  /// The registered business name, where it differs from the contact name.
  final String? businessName;
  const CustomerDetailRow(
      {required this.customerId,
      this.code,
      required this.isVatRegistered,
      this.businessName});
  @override
  Map<String, Expression> toColumns(bool nullToAbsent) {
    final map = <String, Expression>{};
    map['customer_id'] = Variable<String>(customerId);
    if (!nullToAbsent || code != null) {
      map['code'] = Variable<String>(code);
    }
    map['is_vat_registered'] = Variable<bool>(isVatRegistered);
    if (!nullToAbsent || businessName != null) {
      map['business_name'] = Variable<String>(businessName);
    }
    return map;
  }

  CustomerDetailsCompanion toCompanion(bool nullToAbsent) {
    return CustomerDetailsCompanion(
      customerId: Value(customerId),
      code: code == null && nullToAbsent ? const Value.absent() : Value(code),
      isVatRegistered: Value(isVatRegistered),
      businessName: businessName == null && nullToAbsent
          ? const Value.absent()
          : Value(businessName),
    );
  }

  factory CustomerDetailRow.fromJson(Map<String, dynamic> json,
      {ValueSerializer? serializer}) {
    serializer ??= driftRuntimeOptions.defaultSerializer;
    return CustomerDetailRow(
      customerId: serializer.fromJson<String>(json['customerId']),
      code: serializer.fromJson<String?>(json['code']),
      isVatRegistered: serializer.fromJson<bool>(json['isVatRegistered']),
      businessName: serializer.fromJson<String?>(json['businessName']),
    );
  }
  @override
  Map<String, dynamic> toJson({ValueSerializer? serializer}) {
    serializer ??= driftRuntimeOptions.defaultSerializer;
    return <String, dynamic>{
      'customerId': serializer.toJson<String>(customerId),
      'code': serializer.toJson<String?>(code),
      'isVatRegistered': serializer.toJson<bool>(isVatRegistered),
      'businessName': serializer.toJson<String?>(businessName),
    };
  }

  CustomerDetailRow copyWith(
          {String? customerId,
          Value<String?> code = const Value.absent(),
          bool? isVatRegistered,
          Value<String?> businessName = const Value.absent()}) =>
      CustomerDetailRow(
        customerId: customerId ?? this.customerId,
        code: code.present ? code.value : this.code,
        isVatRegistered: isVatRegistered ?? this.isVatRegistered,
        businessName:
            businessName.present ? businessName.value : this.businessName,
      );
  CustomerDetailRow copyWithCompanion(CustomerDetailsCompanion data) {
    return CustomerDetailRow(
      customerId:
          data.customerId.present ? data.customerId.value : this.customerId,
      code: data.code.present ? data.code.value : this.code,
      isVatRegistered: data.isVatRegistered.present
          ? data.isVatRegistered.value
          : this.isVatRegistered,
      businessName: data.businessName.present
          ? data.businessName.value
          : this.businessName,
    );
  }

  @override
  String toString() {
    return (StringBuffer('CustomerDetailRow(')
          ..write('customerId: $customerId, ')
          ..write('code: $code, ')
          ..write('isVatRegistered: $isVatRegistered, ')
          ..write('businessName: $businessName')
          ..write(')'))
        .toString();
  }

  @override
  int get hashCode =>
      Object.hash(customerId, code, isVatRegistered, businessName);
  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      (other is CustomerDetailRow &&
          other.customerId == this.customerId &&
          other.code == this.code &&
          other.isVatRegistered == this.isVatRegistered &&
          other.businessName == this.businessName);
}

class CustomerDetailsCompanion extends UpdateCompanion<CustomerDetailRow> {
  final Value<String> customerId;
  final Value<String?> code;
  final Value<bool> isVatRegistered;
  final Value<String?> businessName;
  final Value<int> rowid;
  const CustomerDetailsCompanion({
    this.customerId = const Value.absent(),
    this.code = const Value.absent(),
    this.isVatRegistered = const Value.absent(),
    this.businessName = const Value.absent(),
    this.rowid = const Value.absent(),
  });
  CustomerDetailsCompanion.insert({
    required String customerId,
    this.code = const Value.absent(),
    this.isVatRegistered = const Value.absent(),
    this.businessName = const Value.absent(),
    this.rowid = const Value.absent(),
  }) : customerId = Value(customerId);
  static Insertable<CustomerDetailRow> custom({
    Expression<String>? customerId,
    Expression<String>? code,
    Expression<bool>? isVatRegistered,
    Expression<String>? businessName,
    Expression<int>? rowid,
  }) {
    return RawValuesInsertable({
      if (customerId != null) 'customer_id': customerId,
      if (code != null) 'code': code,
      if (isVatRegistered != null) 'is_vat_registered': isVatRegistered,
      if (businessName != null) 'business_name': businessName,
      if (rowid != null) 'rowid': rowid,
    });
  }

  CustomerDetailsCompanion copyWith(
      {Value<String>? customerId,
      Value<String?>? code,
      Value<bool>? isVatRegistered,
      Value<String?>? businessName,
      Value<int>? rowid}) {
    return CustomerDetailsCompanion(
      customerId: customerId ?? this.customerId,
      code: code ?? this.code,
      isVatRegistered: isVatRegistered ?? this.isVatRegistered,
      businessName: businessName ?? this.businessName,
      rowid: rowid ?? this.rowid,
    );
  }

  @override
  Map<String, Expression> toColumns(bool nullToAbsent) {
    final map = <String, Expression>{};
    if (customerId.present) {
      map['customer_id'] = Variable<String>(customerId.value);
    }
    if (code.present) {
      map['code'] = Variable<String>(code.value);
    }
    if (isVatRegistered.present) {
      map['is_vat_registered'] = Variable<bool>(isVatRegistered.value);
    }
    if (businessName.present) {
      map['business_name'] = Variable<String>(businessName.value);
    }
    if (rowid.present) {
      map['rowid'] = Variable<int>(rowid.value);
    }
    return map;
  }

  @override
  String toString() {
    return (StringBuffer('CustomerDetailsCompanion(')
          ..write('customerId: $customerId, ')
          ..write('code: $code, ')
          ..write('isVatRegistered: $isVatRegistered, ')
          ..write('businessName: $businessName, ')
          ..write('rowid: $rowid')
          ..write(')'))
        .toString();
  }
}

class $InvoiceSellersTable extends InvoiceSellers
    with TableInfo<$InvoiceSellersTable, InvoiceSellerRow> {
  @override
  final GeneratedDatabase attachedDatabase;
  final String? _alias;
  $InvoiceSellersTable(this.attachedDatabase, [this._alias]);
  static const VerificationMeta _invoiceIdMeta =
      const VerificationMeta('invoiceId');
  @override
  late final GeneratedColumn<String> invoiceId = GeneratedColumn<String>(
      'invoice_id', aliasedName, false,
      type: DriftSqlType.string, requiredDuringInsert: true);
  static const VerificationMeta _sellerNameMeta =
      const VerificationMeta('sellerName');
  @override
  late final GeneratedColumn<String> sellerName = GeneratedColumn<String>(
      'seller_name', aliasedName, false,
      type: DriftSqlType.string, requiredDuringInsert: true);
  static const VerificationMeta _sellerPanMeta =
      const VerificationMeta('sellerPan');
  @override
  late final GeneratedColumn<String> sellerPan = GeneratedColumn<String>(
      'seller_pan', aliasedName, false,
      type: DriftSqlType.string, requiredDuringInsert: true);
  @override
  List<GeneratedColumn> get $columns => [invoiceId, sellerName, sellerPan];
  @override
  String get aliasedName => _alias ?? actualTableName;
  @override
  String get actualTableName => $name;
  static const String $name = 'invoice_sellers';
  @override
  VerificationContext validateIntegrity(Insertable<InvoiceSellerRow> instance,
      {bool isInserting = false}) {
    final context = VerificationContext();
    final data = instance.toColumns(true);
    if (data.containsKey('invoice_id')) {
      context.handle(_invoiceIdMeta,
          invoiceId.isAcceptableOrUnknown(data['invoice_id']!, _invoiceIdMeta));
    } else if (isInserting) {
      context.missing(_invoiceIdMeta);
    }
    if (data.containsKey('seller_name')) {
      context.handle(
          _sellerNameMeta,
          sellerName.isAcceptableOrUnknown(
              data['seller_name']!, _sellerNameMeta));
    } else if (isInserting) {
      context.missing(_sellerNameMeta);
    }
    if (data.containsKey('seller_pan')) {
      context.handle(_sellerPanMeta,
          sellerPan.isAcceptableOrUnknown(data['seller_pan']!, _sellerPanMeta));
    } else if (isInserting) {
      context.missing(_sellerPanMeta);
    }
    return context;
  }

  @override
  Set<GeneratedColumn> get $primaryKey => {invoiceId};
  @override
  InvoiceSellerRow map(Map<String, dynamic> data, {String? tablePrefix}) {
    final effectivePrefix = tablePrefix != null ? '$tablePrefix.' : '';
    return InvoiceSellerRow(
      invoiceId: attachedDatabase.typeMapping
          .read(DriftSqlType.string, data['${effectivePrefix}invoice_id'])!,
      sellerName: attachedDatabase.typeMapping
          .read(DriftSqlType.string, data['${effectivePrefix}seller_name'])!,
      sellerPan: attachedDatabase.typeMapping
          .read(DriftSqlType.string, data['${effectivePrefix}seller_pan'])!,
    );
  }

  @override
  $InvoiceSellersTable createAlias(String alias) {
    return $InvoiceSellersTable(attachedDatabase, alias);
  }
}

class InvoiceSellerRow extends DataClass
    implements Insertable<InvoiceSellerRow> {
  /// The invoice this was printed on.
  final String invoiceId;

  /// The registered business name as printed.
  final String sellerName;

  /// The PAN as printed, as nine digits.
  final String sellerPan;
  const InvoiceSellerRow(
      {required this.invoiceId,
      required this.sellerName,
      required this.sellerPan});
  @override
  Map<String, Expression> toColumns(bool nullToAbsent) {
    final map = <String, Expression>{};
    map['invoice_id'] = Variable<String>(invoiceId);
    map['seller_name'] = Variable<String>(sellerName);
    map['seller_pan'] = Variable<String>(sellerPan);
    return map;
  }

  InvoiceSellersCompanion toCompanion(bool nullToAbsent) {
    return InvoiceSellersCompanion(
      invoiceId: Value(invoiceId),
      sellerName: Value(sellerName),
      sellerPan: Value(sellerPan),
    );
  }

  factory InvoiceSellerRow.fromJson(Map<String, dynamic> json,
      {ValueSerializer? serializer}) {
    serializer ??= driftRuntimeOptions.defaultSerializer;
    return InvoiceSellerRow(
      invoiceId: serializer.fromJson<String>(json['invoiceId']),
      sellerName: serializer.fromJson<String>(json['sellerName']),
      sellerPan: serializer.fromJson<String>(json['sellerPan']),
    );
  }
  @override
  Map<String, dynamic> toJson({ValueSerializer? serializer}) {
    serializer ??= driftRuntimeOptions.defaultSerializer;
    return <String, dynamic>{
      'invoiceId': serializer.toJson<String>(invoiceId),
      'sellerName': serializer.toJson<String>(sellerName),
      'sellerPan': serializer.toJson<String>(sellerPan),
    };
  }

  InvoiceSellerRow copyWith(
          {String? invoiceId, String? sellerName, String? sellerPan}) =>
      InvoiceSellerRow(
        invoiceId: invoiceId ?? this.invoiceId,
        sellerName: sellerName ?? this.sellerName,
        sellerPan: sellerPan ?? this.sellerPan,
      );
  InvoiceSellerRow copyWithCompanion(InvoiceSellersCompanion data) {
    return InvoiceSellerRow(
      invoiceId: data.invoiceId.present ? data.invoiceId.value : this.invoiceId,
      sellerName:
          data.sellerName.present ? data.sellerName.value : this.sellerName,
      sellerPan: data.sellerPan.present ? data.sellerPan.value : this.sellerPan,
    );
  }

  @override
  String toString() {
    return (StringBuffer('InvoiceSellerRow(')
          ..write('invoiceId: $invoiceId, ')
          ..write('sellerName: $sellerName, ')
          ..write('sellerPan: $sellerPan')
          ..write(')'))
        .toString();
  }

  @override
  int get hashCode => Object.hash(invoiceId, sellerName, sellerPan);
  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      (other is InvoiceSellerRow &&
          other.invoiceId == this.invoiceId &&
          other.sellerName == this.sellerName &&
          other.sellerPan == this.sellerPan);
}

class InvoiceSellersCompanion extends UpdateCompanion<InvoiceSellerRow> {
  final Value<String> invoiceId;
  final Value<String> sellerName;
  final Value<String> sellerPan;
  final Value<int> rowid;
  const InvoiceSellersCompanion({
    this.invoiceId = const Value.absent(),
    this.sellerName = const Value.absent(),
    this.sellerPan = const Value.absent(),
    this.rowid = const Value.absent(),
  });
  InvoiceSellersCompanion.insert({
    required String invoiceId,
    required String sellerName,
    required String sellerPan,
    this.rowid = const Value.absent(),
  })  : invoiceId = Value(invoiceId),
        sellerName = Value(sellerName),
        sellerPan = Value(sellerPan);
  static Insertable<InvoiceSellerRow> custom({
    Expression<String>? invoiceId,
    Expression<String>? sellerName,
    Expression<String>? sellerPan,
    Expression<int>? rowid,
  }) {
    return RawValuesInsertable({
      if (invoiceId != null) 'invoice_id': invoiceId,
      if (sellerName != null) 'seller_name': sellerName,
      if (sellerPan != null) 'seller_pan': sellerPan,
      if (rowid != null) 'rowid': rowid,
    });
  }

  InvoiceSellersCompanion copyWith(
      {Value<String>? invoiceId,
      Value<String>? sellerName,
      Value<String>? sellerPan,
      Value<int>? rowid}) {
    return InvoiceSellersCompanion(
      invoiceId: invoiceId ?? this.invoiceId,
      sellerName: sellerName ?? this.sellerName,
      sellerPan: sellerPan ?? this.sellerPan,
      rowid: rowid ?? this.rowid,
    );
  }

  @override
  Map<String, Expression> toColumns(bool nullToAbsent) {
    final map = <String, Expression>{};
    if (invoiceId.present) {
      map['invoice_id'] = Variable<String>(invoiceId.value);
    }
    if (sellerName.present) {
      map['seller_name'] = Variable<String>(sellerName.value);
    }
    if (sellerPan.present) {
      map['seller_pan'] = Variable<String>(sellerPan.value);
    }
    if (rowid.present) {
      map['rowid'] = Variable<int>(rowid.value);
    }
    return map;
  }

  @override
  String toString() {
    return (StringBuffer('InvoiceSellersCompanion(')
          ..write('invoiceId: $invoiceId, ')
          ..write('sellerName: $sellerName, ')
          ..write('sellerPan: $sellerPan, ')
          ..write('rowid: $rowid')
          ..write(')'))
        .toString();
  }
}

abstract class _$AppDatabase extends GeneratedDatabase {
  _$AppDatabase(QueryExecutor e) : super(e);
  $AppDatabaseManager get managers => $AppDatabaseManager(this);
  late final $AccountsTable accounts = $AccountsTable(this);
  late final $JournalEntriesTable journalEntries = $JournalEntriesTable(this);
  late final $JournalLinesTable journalLines = $JournalLinesTable(this);
  late final $DocumentSequencesTable documentSequences =
      $DocumentSequencesTable(this);
  late final $CustomersTable customers = $CustomersTable(this);
  late final $InvoicesTable invoices = $InvoicesTable(this);
  late final $InvoiceLinesTable invoiceLines = $InvoiceLinesTable(this);
  late final $PaymentsTable payments = $PaymentsTable(this);
  late final $CreditNotesTable creditNotes = $CreditNotesTable(this);
  late final $CreditNoteLinesTable creditNoteLines =
      $CreditNoteLinesTable(this);
  late final $ProductsTable products = $ProductsTable(this);
  late final $InventoryMovementsTable inventoryMovements =
      $InventoryMovementsTable(this);
  late final $CustomerDetailsTable customerDetails =
      $CustomerDetailsTable(this);
  late final $InvoiceSellersTable invoiceSellers = $InvoiceSellersTable(this);
  @override
  Iterable<TableInfo<Table, Object?>> get allTables =>
      allSchemaEntities.whereType<TableInfo<Table, Object?>>();
  @override
  List<DatabaseSchemaEntity> get allSchemaEntities => [
        accounts,
        journalEntries,
        journalLines,
        documentSequences,
        customers,
        invoices,
        invoiceLines,
        payments,
        creditNotes,
        creditNoteLines,
        products,
        inventoryMovements,
        customerDetails,
        invoiceSellers
      ];
}

typedef $$AccountsTableCreateCompanionBuilder = AccountsCompanion Function({
  required String id,
  required String code,
  required String name,
  required AccountType type,
  Value<int> rowid,
});
typedef $$AccountsTableUpdateCompanionBuilder = AccountsCompanion Function({
  Value<String> id,
  Value<String> code,
  Value<String> name,
  Value<AccountType> type,
  Value<int> rowid,
});

class $$AccountsTableFilterComposer
    extends Composer<_$AppDatabase, $AccountsTable> {
  $$AccountsTableFilterComposer({
    required super.$db,
    required super.$table,
    super.joinBuilder,
    super.$addJoinBuilderToRootComposer,
    super.$removeJoinBuilderFromRootComposer,
  });
  ColumnFilters<String> get id => $composableBuilder(
      column: $table.id, builder: (column) => ColumnFilters(column));

  ColumnFilters<String> get code => $composableBuilder(
      column: $table.code, builder: (column) => ColumnFilters(column));

  ColumnFilters<String> get name => $composableBuilder(
      column: $table.name, builder: (column) => ColumnFilters(column));

  ColumnWithTypeConverterFilters<AccountType, AccountType, String> get type =>
      $composableBuilder(
          column: $table.type,
          builder: (column) => ColumnWithTypeConverterFilters(column));
}

class $$AccountsTableOrderingComposer
    extends Composer<_$AppDatabase, $AccountsTable> {
  $$AccountsTableOrderingComposer({
    required super.$db,
    required super.$table,
    super.joinBuilder,
    super.$addJoinBuilderToRootComposer,
    super.$removeJoinBuilderFromRootComposer,
  });
  ColumnOrderings<String> get id => $composableBuilder(
      column: $table.id, builder: (column) => ColumnOrderings(column));

  ColumnOrderings<String> get code => $composableBuilder(
      column: $table.code, builder: (column) => ColumnOrderings(column));

  ColumnOrderings<String> get name => $composableBuilder(
      column: $table.name, builder: (column) => ColumnOrderings(column));

  ColumnOrderings<String> get type => $composableBuilder(
      column: $table.type, builder: (column) => ColumnOrderings(column));
}

class $$AccountsTableAnnotationComposer
    extends Composer<_$AppDatabase, $AccountsTable> {
  $$AccountsTableAnnotationComposer({
    required super.$db,
    required super.$table,
    super.joinBuilder,
    super.$addJoinBuilderToRootComposer,
    super.$removeJoinBuilderFromRootComposer,
  });
  GeneratedColumn<String> get id =>
      $composableBuilder(column: $table.id, builder: (column) => column);

  GeneratedColumn<String> get code =>
      $composableBuilder(column: $table.code, builder: (column) => column);

  GeneratedColumn<String> get name =>
      $composableBuilder(column: $table.name, builder: (column) => column);

  GeneratedColumnWithTypeConverter<AccountType, String> get type =>
      $composableBuilder(column: $table.type, builder: (column) => column);
}

class $$AccountsTableTableManager extends RootTableManager<
    _$AppDatabase,
    $AccountsTable,
    AccountRow,
    $$AccountsTableFilterComposer,
    $$AccountsTableOrderingComposer,
    $$AccountsTableAnnotationComposer,
    $$AccountsTableCreateCompanionBuilder,
    $$AccountsTableUpdateCompanionBuilder,
    (AccountRow, BaseReferences<_$AppDatabase, $AccountsTable, AccountRow>),
    AccountRow,
    PrefetchHooks Function()> {
  $$AccountsTableTableManager(_$AppDatabase db, $AccountsTable table)
      : super(TableManagerState(
          db: db,
          table: table,
          createFilteringComposer: () =>
              $$AccountsTableFilterComposer($db: db, $table: table),
          createOrderingComposer: () =>
              $$AccountsTableOrderingComposer($db: db, $table: table),
          createComputedFieldComposer: () =>
              $$AccountsTableAnnotationComposer($db: db, $table: table),
          updateCompanionCallback: ({
            Value<String> id = const Value.absent(),
            Value<String> code = const Value.absent(),
            Value<String> name = const Value.absent(),
            Value<AccountType> type = const Value.absent(),
            Value<int> rowid = const Value.absent(),
          }) =>
              AccountsCompanion(
            id: id,
            code: code,
            name: name,
            type: type,
            rowid: rowid,
          ),
          createCompanionCallback: ({
            required String id,
            required String code,
            required String name,
            required AccountType type,
            Value<int> rowid = const Value.absent(),
          }) =>
              AccountsCompanion.insert(
            id: id,
            code: code,
            name: name,
            type: type,
            rowid: rowid,
          ),
          withReferenceMapper: (p0) => p0
              .map((e) => (e.readTable(table), BaseReferences(db, table, e)))
              .toList(),
          prefetchHooksCallback: null,
        ));
}

typedef $$AccountsTableProcessedTableManager = ProcessedTableManager<
    _$AppDatabase,
    $AccountsTable,
    AccountRow,
    $$AccountsTableFilterComposer,
    $$AccountsTableOrderingComposer,
    $$AccountsTableAnnotationComposer,
    $$AccountsTableCreateCompanionBuilder,
    $$AccountsTableUpdateCompanionBuilder,
    (AccountRow, BaseReferences<_$AppDatabase, $AccountsTable, AccountRow>),
    AccountRow,
    PrefetchHooks Function()>;
typedef $$JournalEntriesTableCreateCompanionBuilder = JournalEntriesCompanion
    Function({
  required String id,
  required DateTime date,
  required String description,
  Value<String?> reference,
  required String currency,
  Value<int> rowid,
});
typedef $$JournalEntriesTableUpdateCompanionBuilder = JournalEntriesCompanion
    Function({
  Value<String> id,
  Value<DateTime> date,
  Value<String> description,
  Value<String?> reference,
  Value<String> currency,
  Value<int> rowid,
});

class $$JournalEntriesTableFilterComposer
    extends Composer<_$AppDatabase, $JournalEntriesTable> {
  $$JournalEntriesTableFilterComposer({
    required super.$db,
    required super.$table,
    super.joinBuilder,
    super.$addJoinBuilderToRootComposer,
    super.$removeJoinBuilderFromRootComposer,
  });
  ColumnFilters<String> get id => $composableBuilder(
      column: $table.id, builder: (column) => ColumnFilters(column));

  ColumnFilters<DateTime> get date => $composableBuilder(
      column: $table.date, builder: (column) => ColumnFilters(column));

  ColumnFilters<String> get description => $composableBuilder(
      column: $table.description, builder: (column) => ColumnFilters(column));

  ColumnFilters<String> get reference => $composableBuilder(
      column: $table.reference, builder: (column) => ColumnFilters(column));

  ColumnFilters<String> get currency => $composableBuilder(
      column: $table.currency, builder: (column) => ColumnFilters(column));
}

class $$JournalEntriesTableOrderingComposer
    extends Composer<_$AppDatabase, $JournalEntriesTable> {
  $$JournalEntriesTableOrderingComposer({
    required super.$db,
    required super.$table,
    super.joinBuilder,
    super.$addJoinBuilderToRootComposer,
    super.$removeJoinBuilderFromRootComposer,
  });
  ColumnOrderings<String> get id => $composableBuilder(
      column: $table.id, builder: (column) => ColumnOrderings(column));

  ColumnOrderings<DateTime> get date => $composableBuilder(
      column: $table.date, builder: (column) => ColumnOrderings(column));

  ColumnOrderings<String> get description => $composableBuilder(
      column: $table.description, builder: (column) => ColumnOrderings(column));

  ColumnOrderings<String> get reference => $composableBuilder(
      column: $table.reference, builder: (column) => ColumnOrderings(column));

  ColumnOrderings<String> get currency => $composableBuilder(
      column: $table.currency, builder: (column) => ColumnOrderings(column));
}

class $$JournalEntriesTableAnnotationComposer
    extends Composer<_$AppDatabase, $JournalEntriesTable> {
  $$JournalEntriesTableAnnotationComposer({
    required super.$db,
    required super.$table,
    super.joinBuilder,
    super.$addJoinBuilderToRootComposer,
    super.$removeJoinBuilderFromRootComposer,
  });
  GeneratedColumn<String> get id =>
      $composableBuilder(column: $table.id, builder: (column) => column);

  GeneratedColumn<DateTime> get date =>
      $composableBuilder(column: $table.date, builder: (column) => column);

  GeneratedColumn<String> get description => $composableBuilder(
      column: $table.description, builder: (column) => column);

  GeneratedColumn<String> get reference =>
      $composableBuilder(column: $table.reference, builder: (column) => column);

  GeneratedColumn<String> get currency =>
      $composableBuilder(column: $table.currency, builder: (column) => column);
}

class $$JournalEntriesTableTableManager extends RootTableManager<
    _$AppDatabase,
    $JournalEntriesTable,
    JournalEntryRow,
    $$JournalEntriesTableFilterComposer,
    $$JournalEntriesTableOrderingComposer,
    $$JournalEntriesTableAnnotationComposer,
    $$JournalEntriesTableCreateCompanionBuilder,
    $$JournalEntriesTableUpdateCompanionBuilder,
    (
      JournalEntryRow,
      BaseReferences<_$AppDatabase, $JournalEntriesTable, JournalEntryRow>
    ),
    JournalEntryRow,
    PrefetchHooks Function()> {
  $$JournalEntriesTableTableManager(
      _$AppDatabase db, $JournalEntriesTable table)
      : super(TableManagerState(
          db: db,
          table: table,
          createFilteringComposer: () =>
              $$JournalEntriesTableFilterComposer($db: db, $table: table),
          createOrderingComposer: () =>
              $$JournalEntriesTableOrderingComposer($db: db, $table: table),
          createComputedFieldComposer: () =>
              $$JournalEntriesTableAnnotationComposer($db: db, $table: table),
          updateCompanionCallback: ({
            Value<String> id = const Value.absent(),
            Value<DateTime> date = const Value.absent(),
            Value<String> description = const Value.absent(),
            Value<String?> reference = const Value.absent(),
            Value<String> currency = const Value.absent(),
            Value<int> rowid = const Value.absent(),
          }) =>
              JournalEntriesCompanion(
            id: id,
            date: date,
            description: description,
            reference: reference,
            currency: currency,
            rowid: rowid,
          ),
          createCompanionCallback: ({
            required String id,
            required DateTime date,
            required String description,
            Value<String?> reference = const Value.absent(),
            required String currency,
            Value<int> rowid = const Value.absent(),
          }) =>
              JournalEntriesCompanion.insert(
            id: id,
            date: date,
            description: description,
            reference: reference,
            currency: currency,
            rowid: rowid,
          ),
          withReferenceMapper: (p0) => p0
              .map((e) => (e.readTable(table), BaseReferences(db, table, e)))
              .toList(),
          prefetchHooksCallback: null,
        ));
}

typedef $$JournalEntriesTableProcessedTableManager = ProcessedTableManager<
    _$AppDatabase,
    $JournalEntriesTable,
    JournalEntryRow,
    $$JournalEntriesTableFilterComposer,
    $$JournalEntriesTableOrderingComposer,
    $$JournalEntriesTableAnnotationComposer,
    $$JournalEntriesTableCreateCompanionBuilder,
    $$JournalEntriesTableUpdateCompanionBuilder,
    (
      JournalEntryRow,
      BaseReferences<_$AppDatabase, $JournalEntriesTable, JournalEntryRow>
    ),
    JournalEntryRow,
    PrefetchHooks Function()>;
typedef $$JournalLinesTableCreateCompanionBuilder = JournalLinesCompanion
    Function({
  Value<int> id,
  required String journalEntryId,
  required String accountId,
  Value<int> debitMinorUnits,
  Value<int> creditMinorUnits,
  required String currency,
});
typedef $$JournalLinesTableUpdateCompanionBuilder = JournalLinesCompanion
    Function({
  Value<int> id,
  Value<String> journalEntryId,
  Value<String> accountId,
  Value<int> debitMinorUnits,
  Value<int> creditMinorUnits,
  Value<String> currency,
});

class $$JournalLinesTableFilterComposer
    extends Composer<_$AppDatabase, $JournalLinesTable> {
  $$JournalLinesTableFilterComposer({
    required super.$db,
    required super.$table,
    super.joinBuilder,
    super.$addJoinBuilderToRootComposer,
    super.$removeJoinBuilderFromRootComposer,
  });
  ColumnFilters<int> get id => $composableBuilder(
      column: $table.id, builder: (column) => ColumnFilters(column));

  ColumnFilters<String> get journalEntryId => $composableBuilder(
      column: $table.journalEntryId,
      builder: (column) => ColumnFilters(column));

  ColumnFilters<String> get accountId => $composableBuilder(
      column: $table.accountId, builder: (column) => ColumnFilters(column));

  ColumnFilters<int> get debitMinorUnits => $composableBuilder(
      column: $table.debitMinorUnits,
      builder: (column) => ColumnFilters(column));

  ColumnFilters<int> get creditMinorUnits => $composableBuilder(
      column: $table.creditMinorUnits,
      builder: (column) => ColumnFilters(column));

  ColumnFilters<String> get currency => $composableBuilder(
      column: $table.currency, builder: (column) => ColumnFilters(column));
}

class $$JournalLinesTableOrderingComposer
    extends Composer<_$AppDatabase, $JournalLinesTable> {
  $$JournalLinesTableOrderingComposer({
    required super.$db,
    required super.$table,
    super.joinBuilder,
    super.$addJoinBuilderToRootComposer,
    super.$removeJoinBuilderFromRootComposer,
  });
  ColumnOrderings<int> get id => $composableBuilder(
      column: $table.id, builder: (column) => ColumnOrderings(column));

  ColumnOrderings<String> get journalEntryId => $composableBuilder(
      column: $table.journalEntryId,
      builder: (column) => ColumnOrderings(column));

  ColumnOrderings<String> get accountId => $composableBuilder(
      column: $table.accountId, builder: (column) => ColumnOrderings(column));

  ColumnOrderings<int> get debitMinorUnits => $composableBuilder(
      column: $table.debitMinorUnits,
      builder: (column) => ColumnOrderings(column));

  ColumnOrderings<int> get creditMinorUnits => $composableBuilder(
      column: $table.creditMinorUnits,
      builder: (column) => ColumnOrderings(column));

  ColumnOrderings<String> get currency => $composableBuilder(
      column: $table.currency, builder: (column) => ColumnOrderings(column));
}

class $$JournalLinesTableAnnotationComposer
    extends Composer<_$AppDatabase, $JournalLinesTable> {
  $$JournalLinesTableAnnotationComposer({
    required super.$db,
    required super.$table,
    super.joinBuilder,
    super.$addJoinBuilderToRootComposer,
    super.$removeJoinBuilderFromRootComposer,
  });
  GeneratedColumn<int> get id =>
      $composableBuilder(column: $table.id, builder: (column) => column);

  GeneratedColumn<String> get journalEntryId => $composableBuilder(
      column: $table.journalEntryId, builder: (column) => column);

  GeneratedColumn<String> get accountId =>
      $composableBuilder(column: $table.accountId, builder: (column) => column);

  GeneratedColumn<int> get debitMinorUnits => $composableBuilder(
      column: $table.debitMinorUnits, builder: (column) => column);

  GeneratedColumn<int> get creditMinorUnits => $composableBuilder(
      column: $table.creditMinorUnits, builder: (column) => column);

  GeneratedColumn<String> get currency =>
      $composableBuilder(column: $table.currency, builder: (column) => column);
}

class $$JournalLinesTableTableManager extends RootTableManager<
    _$AppDatabase,
    $JournalLinesTable,
    JournalLineRow,
    $$JournalLinesTableFilterComposer,
    $$JournalLinesTableOrderingComposer,
    $$JournalLinesTableAnnotationComposer,
    $$JournalLinesTableCreateCompanionBuilder,
    $$JournalLinesTableUpdateCompanionBuilder,
    (
      JournalLineRow,
      BaseReferences<_$AppDatabase, $JournalLinesTable, JournalLineRow>
    ),
    JournalLineRow,
    PrefetchHooks Function()> {
  $$JournalLinesTableTableManager(_$AppDatabase db, $JournalLinesTable table)
      : super(TableManagerState(
          db: db,
          table: table,
          createFilteringComposer: () =>
              $$JournalLinesTableFilterComposer($db: db, $table: table),
          createOrderingComposer: () =>
              $$JournalLinesTableOrderingComposer($db: db, $table: table),
          createComputedFieldComposer: () =>
              $$JournalLinesTableAnnotationComposer($db: db, $table: table),
          updateCompanionCallback: ({
            Value<int> id = const Value.absent(),
            Value<String> journalEntryId = const Value.absent(),
            Value<String> accountId = const Value.absent(),
            Value<int> debitMinorUnits = const Value.absent(),
            Value<int> creditMinorUnits = const Value.absent(),
            Value<String> currency = const Value.absent(),
          }) =>
              JournalLinesCompanion(
            id: id,
            journalEntryId: journalEntryId,
            accountId: accountId,
            debitMinorUnits: debitMinorUnits,
            creditMinorUnits: creditMinorUnits,
            currency: currency,
          ),
          createCompanionCallback: ({
            Value<int> id = const Value.absent(),
            required String journalEntryId,
            required String accountId,
            Value<int> debitMinorUnits = const Value.absent(),
            Value<int> creditMinorUnits = const Value.absent(),
            required String currency,
          }) =>
              JournalLinesCompanion.insert(
            id: id,
            journalEntryId: journalEntryId,
            accountId: accountId,
            debitMinorUnits: debitMinorUnits,
            creditMinorUnits: creditMinorUnits,
            currency: currency,
          ),
          withReferenceMapper: (p0) => p0
              .map((e) => (e.readTable(table), BaseReferences(db, table, e)))
              .toList(),
          prefetchHooksCallback: null,
        ));
}

typedef $$JournalLinesTableProcessedTableManager = ProcessedTableManager<
    _$AppDatabase,
    $JournalLinesTable,
    JournalLineRow,
    $$JournalLinesTableFilterComposer,
    $$JournalLinesTableOrderingComposer,
    $$JournalLinesTableAnnotationComposer,
    $$JournalLinesTableCreateCompanionBuilder,
    $$JournalLinesTableUpdateCompanionBuilder,
    (
      JournalLineRow,
      BaseReferences<_$AppDatabase, $JournalLinesTable, JournalLineRow>
    ),
    JournalLineRow,
    PrefetchHooks Function()>;
typedef $$DocumentSequencesTableCreateCompanionBuilder
    = DocumentSequencesCompanion Function({
  required String documentType,
  required String fiscalYearLabel,
  Value<int> lastSequence,
  Value<int> rowid,
});
typedef $$DocumentSequencesTableUpdateCompanionBuilder
    = DocumentSequencesCompanion Function({
  Value<String> documentType,
  Value<String> fiscalYearLabel,
  Value<int> lastSequence,
  Value<int> rowid,
});

class $$DocumentSequencesTableFilterComposer
    extends Composer<_$AppDatabase, $DocumentSequencesTable> {
  $$DocumentSequencesTableFilterComposer({
    required super.$db,
    required super.$table,
    super.joinBuilder,
    super.$addJoinBuilderToRootComposer,
    super.$removeJoinBuilderFromRootComposer,
  });
  ColumnFilters<String> get documentType => $composableBuilder(
      column: $table.documentType, builder: (column) => ColumnFilters(column));

  ColumnFilters<String> get fiscalYearLabel => $composableBuilder(
      column: $table.fiscalYearLabel,
      builder: (column) => ColumnFilters(column));

  ColumnFilters<int> get lastSequence => $composableBuilder(
      column: $table.lastSequence, builder: (column) => ColumnFilters(column));
}

class $$DocumentSequencesTableOrderingComposer
    extends Composer<_$AppDatabase, $DocumentSequencesTable> {
  $$DocumentSequencesTableOrderingComposer({
    required super.$db,
    required super.$table,
    super.joinBuilder,
    super.$addJoinBuilderToRootComposer,
    super.$removeJoinBuilderFromRootComposer,
  });
  ColumnOrderings<String> get documentType => $composableBuilder(
      column: $table.documentType,
      builder: (column) => ColumnOrderings(column));

  ColumnOrderings<String> get fiscalYearLabel => $composableBuilder(
      column: $table.fiscalYearLabel,
      builder: (column) => ColumnOrderings(column));

  ColumnOrderings<int> get lastSequence => $composableBuilder(
      column: $table.lastSequence,
      builder: (column) => ColumnOrderings(column));
}

class $$DocumentSequencesTableAnnotationComposer
    extends Composer<_$AppDatabase, $DocumentSequencesTable> {
  $$DocumentSequencesTableAnnotationComposer({
    required super.$db,
    required super.$table,
    super.joinBuilder,
    super.$addJoinBuilderToRootComposer,
    super.$removeJoinBuilderFromRootComposer,
  });
  GeneratedColumn<String> get documentType => $composableBuilder(
      column: $table.documentType, builder: (column) => column);

  GeneratedColumn<String> get fiscalYearLabel => $composableBuilder(
      column: $table.fiscalYearLabel, builder: (column) => column);

  GeneratedColumn<int> get lastSequence => $composableBuilder(
      column: $table.lastSequence, builder: (column) => column);
}

class $$DocumentSequencesTableTableManager extends RootTableManager<
    _$AppDatabase,
    $DocumentSequencesTable,
    DocumentSequenceRow,
    $$DocumentSequencesTableFilterComposer,
    $$DocumentSequencesTableOrderingComposer,
    $$DocumentSequencesTableAnnotationComposer,
    $$DocumentSequencesTableCreateCompanionBuilder,
    $$DocumentSequencesTableUpdateCompanionBuilder,
    (
      DocumentSequenceRow,
      BaseReferences<_$AppDatabase, $DocumentSequencesTable,
          DocumentSequenceRow>
    ),
    DocumentSequenceRow,
    PrefetchHooks Function()> {
  $$DocumentSequencesTableTableManager(
      _$AppDatabase db, $DocumentSequencesTable table)
      : super(TableManagerState(
          db: db,
          table: table,
          createFilteringComposer: () =>
              $$DocumentSequencesTableFilterComposer($db: db, $table: table),
          createOrderingComposer: () =>
              $$DocumentSequencesTableOrderingComposer($db: db, $table: table),
          createComputedFieldComposer: () =>
              $$DocumentSequencesTableAnnotationComposer(
                  $db: db, $table: table),
          updateCompanionCallback: ({
            Value<String> documentType = const Value.absent(),
            Value<String> fiscalYearLabel = const Value.absent(),
            Value<int> lastSequence = const Value.absent(),
            Value<int> rowid = const Value.absent(),
          }) =>
              DocumentSequencesCompanion(
            documentType: documentType,
            fiscalYearLabel: fiscalYearLabel,
            lastSequence: lastSequence,
            rowid: rowid,
          ),
          createCompanionCallback: ({
            required String documentType,
            required String fiscalYearLabel,
            Value<int> lastSequence = const Value.absent(),
            Value<int> rowid = const Value.absent(),
          }) =>
              DocumentSequencesCompanion.insert(
            documentType: documentType,
            fiscalYearLabel: fiscalYearLabel,
            lastSequence: lastSequence,
            rowid: rowid,
          ),
          withReferenceMapper: (p0) => p0
              .map((e) => (e.readTable(table), BaseReferences(db, table, e)))
              .toList(),
          prefetchHooksCallback: null,
        ));
}

typedef $$DocumentSequencesTableProcessedTableManager = ProcessedTableManager<
    _$AppDatabase,
    $DocumentSequencesTable,
    DocumentSequenceRow,
    $$DocumentSequencesTableFilterComposer,
    $$DocumentSequencesTableOrderingComposer,
    $$DocumentSequencesTableAnnotationComposer,
    $$DocumentSequencesTableCreateCompanionBuilder,
    $$DocumentSequencesTableUpdateCompanionBuilder,
    (
      DocumentSequenceRow,
      BaseReferences<_$AppDatabase, $DocumentSequencesTable,
          DocumentSequenceRow>
    ),
    DocumentSequenceRow,
    PrefetchHooks Function()>;
typedef $$CustomersTableCreateCompanionBuilder = CustomersCompanion Function({
  required String id,
  required String name,
  Value<String?> panNumber,
  Value<String?> phone,
  Value<String?> address,
  Value<int> rowid,
});
typedef $$CustomersTableUpdateCompanionBuilder = CustomersCompanion Function({
  Value<String> id,
  Value<String> name,
  Value<String?> panNumber,
  Value<String?> phone,
  Value<String?> address,
  Value<int> rowid,
});

class $$CustomersTableFilterComposer
    extends Composer<_$AppDatabase, $CustomersTable> {
  $$CustomersTableFilterComposer({
    required super.$db,
    required super.$table,
    super.joinBuilder,
    super.$addJoinBuilderToRootComposer,
    super.$removeJoinBuilderFromRootComposer,
  });
  ColumnFilters<String> get id => $composableBuilder(
      column: $table.id, builder: (column) => ColumnFilters(column));

  ColumnFilters<String> get name => $composableBuilder(
      column: $table.name, builder: (column) => ColumnFilters(column));

  ColumnFilters<String> get panNumber => $composableBuilder(
      column: $table.panNumber, builder: (column) => ColumnFilters(column));

  ColumnFilters<String> get phone => $composableBuilder(
      column: $table.phone, builder: (column) => ColumnFilters(column));

  ColumnFilters<String> get address => $composableBuilder(
      column: $table.address, builder: (column) => ColumnFilters(column));
}

class $$CustomersTableOrderingComposer
    extends Composer<_$AppDatabase, $CustomersTable> {
  $$CustomersTableOrderingComposer({
    required super.$db,
    required super.$table,
    super.joinBuilder,
    super.$addJoinBuilderToRootComposer,
    super.$removeJoinBuilderFromRootComposer,
  });
  ColumnOrderings<String> get id => $composableBuilder(
      column: $table.id, builder: (column) => ColumnOrderings(column));

  ColumnOrderings<String> get name => $composableBuilder(
      column: $table.name, builder: (column) => ColumnOrderings(column));

  ColumnOrderings<String> get panNumber => $composableBuilder(
      column: $table.panNumber, builder: (column) => ColumnOrderings(column));

  ColumnOrderings<String> get phone => $composableBuilder(
      column: $table.phone, builder: (column) => ColumnOrderings(column));

  ColumnOrderings<String> get address => $composableBuilder(
      column: $table.address, builder: (column) => ColumnOrderings(column));
}

class $$CustomersTableAnnotationComposer
    extends Composer<_$AppDatabase, $CustomersTable> {
  $$CustomersTableAnnotationComposer({
    required super.$db,
    required super.$table,
    super.joinBuilder,
    super.$addJoinBuilderToRootComposer,
    super.$removeJoinBuilderFromRootComposer,
  });
  GeneratedColumn<String> get id =>
      $composableBuilder(column: $table.id, builder: (column) => column);

  GeneratedColumn<String> get name =>
      $composableBuilder(column: $table.name, builder: (column) => column);

  GeneratedColumn<String> get panNumber =>
      $composableBuilder(column: $table.panNumber, builder: (column) => column);

  GeneratedColumn<String> get phone =>
      $composableBuilder(column: $table.phone, builder: (column) => column);

  GeneratedColumn<String> get address =>
      $composableBuilder(column: $table.address, builder: (column) => column);
}

class $$CustomersTableTableManager extends RootTableManager<
    _$AppDatabase,
    $CustomersTable,
    CustomerRow,
    $$CustomersTableFilterComposer,
    $$CustomersTableOrderingComposer,
    $$CustomersTableAnnotationComposer,
    $$CustomersTableCreateCompanionBuilder,
    $$CustomersTableUpdateCompanionBuilder,
    (CustomerRow, BaseReferences<_$AppDatabase, $CustomersTable, CustomerRow>),
    CustomerRow,
    PrefetchHooks Function()> {
  $$CustomersTableTableManager(_$AppDatabase db, $CustomersTable table)
      : super(TableManagerState(
          db: db,
          table: table,
          createFilteringComposer: () =>
              $$CustomersTableFilterComposer($db: db, $table: table),
          createOrderingComposer: () =>
              $$CustomersTableOrderingComposer($db: db, $table: table),
          createComputedFieldComposer: () =>
              $$CustomersTableAnnotationComposer($db: db, $table: table),
          updateCompanionCallback: ({
            Value<String> id = const Value.absent(),
            Value<String> name = const Value.absent(),
            Value<String?> panNumber = const Value.absent(),
            Value<String?> phone = const Value.absent(),
            Value<String?> address = const Value.absent(),
            Value<int> rowid = const Value.absent(),
          }) =>
              CustomersCompanion(
            id: id,
            name: name,
            panNumber: panNumber,
            phone: phone,
            address: address,
            rowid: rowid,
          ),
          createCompanionCallback: ({
            required String id,
            required String name,
            Value<String?> panNumber = const Value.absent(),
            Value<String?> phone = const Value.absent(),
            Value<String?> address = const Value.absent(),
            Value<int> rowid = const Value.absent(),
          }) =>
              CustomersCompanion.insert(
            id: id,
            name: name,
            panNumber: panNumber,
            phone: phone,
            address: address,
            rowid: rowid,
          ),
          withReferenceMapper: (p0) => p0
              .map((e) => (e.readTable(table), BaseReferences(db, table, e)))
              .toList(),
          prefetchHooksCallback: null,
        ));
}

typedef $$CustomersTableProcessedTableManager = ProcessedTableManager<
    _$AppDatabase,
    $CustomersTable,
    CustomerRow,
    $$CustomersTableFilterComposer,
    $$CustomersTableOrderingComposer,
    $$CustomersTableAnnotationComposer,
    $$CustomersTableCreateCompanionBuilder,
    $$CustomersTableUpdateCompanionBuilder,
    (CustomerRow, BaseReferences<_$AppDatabase, $CustomersTable, CustomerRow>),
    CustomerRow,
    PrefetchHooks Function()>;
typedef $$InvoicesTableCreateCompanionBuilder = InvoicesCompanion Function({
  required String id,
  required String number,
  required int sequence,
  required String fiscalYearLabel,
  required String customerId,
  required DateTime issueDate,
  required String currency,
  required int vatRateBasisPoints,
  required int subtotalMinorUnits,
  required int vatMinorUnits,
  required int totalMinorUnits,
  required String journalEntryId,
  Value<int> rowid,
});
typedef $$InvoicesTableUpdateCompanionBuilder = InvoicesCompanion Function({
  Value<String> id,
  Value<String> number,
  Value<int> sequence,
  Value<String> fiscalYearLabel,
  Value<String> customerId,
  Value<DateTime> issueDate,
  Value<String> currency,
  Value<int> vatRateBasisPoints,
  Value<int> subtotalMinorUnits,
  Value<int> vatMinorUnits,
  Value<int> totalMinorUnits,
  Value<String> journalEntryId,
  Value<int> rowid,
});

class $$InvoicesTableFilterComposer
    extends Composer<_$AppDatabase, $InvoicesTable> {
  $$InvoicesTableFilterComposer({
    required super.$db,
    required super.$table,
    super.joinBuilder,
    super.$addJoinBuilderToRootComposer,
    super.$removeJoinBuilderFromRootComposer,
  });
  ColumnFilters<String> get id => $composableBuilder(
      column: $table.id, builder: (column) => ColumnFilters(column));

  ColumnFilters<String> get number => $composableBuilder(
      column: $table.number, builder: (column) => ColumnFilters(column));

  ColumnFilters<int> get sequence => $composableBuilder(
      column: $table.sequence, builder: (column) => ColumnFilters(column));

  ColumnFilters<String> get fiscalYearLabel => $composableBuilder(
      column: $table.fiscalYearLabel,
      builder: (column) => ColumnFilters(column));

  ColumnFilters<String> get customerId => $composableBuilder(
      column: $table.customerId, builder: (column) => ColumnFilters(column));

  ColumnFilters<DateTime> get issueDate => $composableBuilder(
      column: $table.issueDate, builder: (column) => ColumnFilters(column));

  ColumnFilters<String> get currency => $composableBuilder(
      column: $table.currency, builder: (column) => ColumnFilters(column));

  ColumnFilters<int> get vatRateBasisPoints => $composableBuilder(
      column: $table.vatRateBasisPoints,
      builder: (column) => ColumnFilters(column));

  ColumnFilters<int> get subtotalMinorUnits => $composableBuilder(
      column: $table.subtotalMinorUnits,
      builder: (column) => ColumnFilters(column));

  ColumnFilters<int> get vatMinorUnits => $composableBuilder(
      column: $table.vatMinorUnits, builder: (column) => ColumnFilters(column));

  ColumnFilters<int> get totalMinorUnits => $composableBuilder(
      column: $table.totalMinorUnits,
      builder: (column) => ColumnFilters(column));

  ColumnFilters<String> get journalEntryId => $composableBuilder(
      column: $table.journalEntryId,
      builder: (column) => ColumnFilters(column));
}

class $$InvoicesTableOrderingComposer
    extends Composer<_$AppDatabase, $InvoicesTable> {
  $$InvoicesTableOrderingComposer({
    required super.$db,
    required super.$table,
    super.joinBuilder,
    super.$addJoinBuilderToRootComposer,
    super.$removeJoinBuilderFromRootComposer,
  });
  ColumnOrderings<String> get id => $composableBuilder(
      column: $table.id, builder: (column) => ColumnOrderings(column));

  ColumnOrderings<String> get number => $composableBuilder(
      column: $table.number, builder: (column) => ColumnOrderings(column));

  ColumnOrderings<int> get sequence => $composableBuilder(
      column: $table.sequence, builder: (column) => ColumnOrderings(column));

  ColumnOrderings<String> get fiscalYearLabel => $composableBuilder(
      column: $table.fiscalYearLabel,
      builder: (column) => ColumnOrderings(column));

  ColumnOrderings<String> get customerId => $composableBuilder(
      column: $table.customerId, builder: (column) => ColumnOrderings(column));

  ColumnOrderings<DateTime> get issueDate => $composableBuilder(
      column: $table.issueDate, builder: (column) => ColumnOrderings(column));

  ColumnOrderings<String> get currency => $composableBuilder(
      column: $table.currency, builder: (column) => ColumnOrderings(column));

  ColumnOrderings<int> get vatRateBasisPoints => $composableBuilder(
      column: $table.vatRateBasisPoints,
      builder: (column) => ColumnOrderings(column));

  ColumnOrderings<int> get subtotalMinorUnits => $composableBuilder(
      column: $table.subtotalMinorUnits,
      builder: (column) => ColumnOrderings(column));

  ColumnOrderings<int> get vatMinorUnits => $composableBuilder(
      column: $table.vatMinorUnits,
      builder: (column) => ColumnOrderings(column));

  ColumnOrderings<int> get totalMinorUnits => $composableBuilder(
      column: $table.totalMinorUnits,
      builder: (column) => ColumnOrderings(column));

  ColumnOrderings<String> get journalEntryId => $composableBuilder(
      column: $table.journalEntryId,
      builder: (column) => ColumnOrderings(column));
}

class $$InvoicesTableAnnotationComposer
    extends Composer<_$AppDatabase, $InvoicesTable> {
  $$InvoicesTableAnnotationComposer({
    required super.$db,
    required super.$table,
    super.joinBuilder,
    super.$addJoinBuilderToRootComposer,
    super.$removeJoinBuilderFromRootComposer,
  });
  GeneratedColumn<String> get id =>
      $composableBuilder(column: $table.id, builder: (column) => column);

  GeneratedColumn<String> get number =>
      $composableBuilder(column: $table.number, builder: (column) => column);

  GeneratedColumn<int> get sequence =>
      $composableBuilder(column: $table.sequence, builder: (column) => column);

  GeneratedColumn<String> get fiscalYearLabel => $composableBuilder(
      column: $table.fiscalYearLabel, builder: (column) => column);

  GeneratedColumn<String> get customerId => $composableBuilder(
      column: $table.customerId, builder: (column) => column);

  GeneratedColumn<DateTime> get issueDate =>
      $composableBuilder(column: $table.issueDate, builder: (column) => column);

  GeneratedColumn<String> get currency =>
      $composableBuilder(column: $table.currency, builder: (column) => column);

  GeneratedColumn<int> get vatRateBasisPoints => $composableBuilder(
      column: $table.vatRateBasisPoints, builder: (column) => column);

  GeneratedColumn<int> get subtotalMinorUnits => $composableBuilder(
      column: $table.subtotalMinorUnits, builder: (column) => column);

  GeneratedColumn<int> get vatMinorUnits => $composableBuilder(
      column: $table.vatMinorUnits, builder: (column) => column);

  GeneratedColumn<int> get totalMinorUnits => $composableBuilder(
      column: $table.totalMinorUnits, builder: (column) => column);

  GeneratedColumn<String> get journalEntryId => $composableBuilder(
      column: $table.journalEntryId, builder: (column) => column);
}

class $$InvoicesTableTableManager extends RootTableManager<
    _$AppDatabase,
    $InvoicesTable,
    InvoiceRow,
    $$InvoicesTableFilterComposer,
    $$InvoicesTableOrderingComposer,
    $$InvoicesTableAnnotationComposer,
    $$InvoicesTableCreateCompanionBuilder,
    $$InvoicesTableUpdateCompanionBuilder,
    (InvoiceRow, BaseReferences<_$AppDatabase, $InvoicesTable, InvoiceRow>),
    InvoiceRow,
    PrefetchHooks Function()> {
  $$InvoicesTableTableManager(_$AppDatabase db, $InvoicesTable table)
      : super(TableManagerState(
          db: db,
          table: table,
          createFilteringComposer: () =>
              $$InvoicesTableFilterComposer($db: db, $table: table),
          createOrderingComposer: () =>
              $$InvoicesTableOrderingComposer($db: db, $table: table),
          createComputedFieldComposer: () =>
              $$InvoicesTableAnnotationComposer($db: db, $table: table),
          updateCompanionCallback: ({
            Value<String> id = const Value.absent(),
            Value<String> number = const Value.absent(),
            Value<int> sequence = const Value.absent(),
            Value<String> fiscalYearLabel = const Value.absent(),
            Value<String> customerId = const Value.absent(),
            Value<DateTime> issueDate = const Value.absent(),
            Value<String> currency = const Value.absent(),
            Value<int> vatRateBasisPoints = const Value.absent(),
            Value<int> subtotalMinorUnits = const Value.absent(),
            Value<int> vatMinorUnits = const Value.absent(),
            Value<int> totalMinorUnits = const Value.absent(),
            Value<String> journalEntryId = const Value.absent(),
            Value<int> rowid = const Value.absent(),
          }) =>
              InvoicesCompanion(
            id: id,
            number: number,
            sequence: sequence,
            fiscalYearLabel: fiscalYearLabel,
            customerId: customerId,
            issueDate: issueDate,
            currency: currency,
            vatRateBasisPoints: vatRateBasisPoints,
            subtotalMinorUnits: subtotalMinorUnits,
            vatMinorUnits: vatMinorUnits,
            totalMinorUnits: totalMinorUnits,
            journalEntryId: journalEntryId,
            rowid: rowid,
          ),
          createCompanionCallback: ({
            required String id,
            required String number,
            required int sequence,
            required String fiscalYearLabel,
            required String customerId,
            required DateTime issueDate,
            required String currency,
            required int vatRateBasisPoints,
            required int subtotalMinorUnits,
            required int vatMinorUnits,
            required int totalMinorUnits,
            required String journalEntryId,
            Value<int> rowid = const Value.absent(),
          }) =>
              InvoicesCompanion.insert(
            id: id,
            number: number,
            sequence: sequence,
            fiscalYearLabel: fiscalYearLabel,
            customerId: customerId,
            issueDate: issueDate,
            currency: currency,
            vatRateBasisPoints: vatRateBasisPoints,
            subtotalMinorUnits: subtotalMinorUnits,
            vatMinorUnits: vatMinorUnits,
            totalMinorUnits: totalMinorUnits,
            journalEntryId: journalEntryId,
            rowid: rowid,
          ),
          withReferenceMapper: (p0) => p0
              .map((e) => (e.readTable(table), BaseReferences(db, table, e)))
              .toList(),
          prefetchHooksCallback: null,
        ));
}

typedef $$InvoicesTableProcessedTableManager = ProcessedTableManager<
    _$AppDatabase,
    $InvoicesTable,
    InvoiceRow,
    $$InvoicesTableFilterComposer,
    $$InvoicesTableOrderingComposer,
    $$InvoicesTableAnnotationComposer,
    $$InvoicesTableCreateCompanionBuilder,
    $$InvoicesTableUpdateCompanionBuilder,
    (InvoiceRow, BaseReferences<_$AppDatabase, $InvoicesTable, InvoiceRow>),
    InvoiceRow,
    PrefetchHooks Function()>;
typedef $$InvoiceLinesTableCreateCompanionBuilder = InvoiceLinesCompanion
    Function({
  Value<int> id,
  required String invoiceId,
  required int lineNumber,
  required String description,
  required int quantity,
  required int unitPriceMinorUnits,
  required String currency,
});
typedef $$InvoiceLinesTableUpdateCompanionBuilder = InvoiceLinesCompanion
    Function({
  Value<int> id,
  Value<String> invoiceId,
  Value<int> lineNumber,
  Value<String> description,
  Value<int> quantity,
  Value<int> unitPriceMinorUnits,
  Value<String> currency,
});

class $$InvoiceLinesTableFilterComposer
    extends Composer<_$AppDatabase, $InvoiceLinesTable> {
  $$InvoiceLinesTableFilterComposer({
    required super.$db,
    required super.$table,
    super.joinBuilder,
    super.$addJoinBuilderToRootComposer,
    super.$removeJoinBuilderFromRootComposer,
  });
  ColumnFilters<int> get id => $composableBuilder(
      column: $table.id, builder: (column) => ColumnFilters(column));

  ColumnFilters<String> get invoiceId => $composableBuilder(
      column: $table.invoiceId, builder: (column) => ColumnFilters(column));

  ColumnFilters<int> get lineNumber => $composableBuilder(
      column: $table.lineNumber, builder: (column) => ColumnFilters(column));

  ColumnFilters<String> get description => $composableBuilder(
      column: $table.description, builder: (column) => ColumnFilters(column));

  ColumnFilters<int> get quantity => $composableBuilder(
      column: $table.quantity, builder: (column) => ColumnFilters(column));

  ColumnFilters<int> get unitPriceMinorUnits => $composableBuilder(
      column: $table.unitPriceMinorUnits,
      builder: (column) => ColumnFilters(column));

  ColumnFilters<String> get currency => $composableBuilder(
      column: $table.currency, builder: (column) => ColumnFilters(column));
}

class $$InvoiceLinesTableOrderingComposer
    extends Composer<_$AppDatabase, $InvoiceLinesTable> {
  $$InvoiceLinesTableOrderingComposer({
    required super.$db,
    required super.$table,
    super.joinBuilder,
    super.$addJoinBuilderToRootComposer,
    super.$removeJoinBuilderFromRootComposer,
  });
  ColumnOrderings<int> get id => $composableBuilder(
      column: $table.id, builder: (column) => ColumnOrderings(column));

  ColumnOrderings<String> get invoiceId => $composableBuilder(
      column: $table.invoiceId, builder: (column) => ColumnOrderings(column));

  ColumnOrderings<int> get lineNumber => $composableBuilder(
      column: $table.lineNumber, builder: (column) => ColumnOrderings(column));

  ColumnOrderings<String> get description => $composableBuilder(
      column: $table.description, builder: (column) => ColumnOrderings(column));

  ColumnOrderings<int> get quantity => $composableBuilder(
      column: $table.quantity, builder: (column) => ColumnOrderings(column));

  ColumnOrderings<int> get unitPriceMinorUnits => $composableBuilder(
      column: $table.unitPriceMinorUnits,
      builder: (column) => ColumnOrderings(column));

  ColumnOrderings<String> get currency => $composableBuilder(
      column: $table.currency, builder: (column) => ColumnOrderings(column));
}

class $$InvoiceLinesTableAnnotationComposer
    extends Composer<_$AppDatabase, $InvoiceLinesTable> {
  $$InvoiceLinesTableAnnotationComposer({
    required super.$db,
    required super.$table,
    super.joinBuilder,
    super.$addJoinBuilderToRootComposer,
    super.$removeJoinBuilderFromRootComposer,
  });
  GeneratedColumn<int> get id =>
      $composableBuilder(column: $table.id, builder: (column) => column);

  GeneratedColumn<String> get invoiceId =>
      $composableBuilder(column: $table.invoiceId, builder: (column) => column);

  GeneratedColumn<int> get lineNumber => $composableBuilder(
      column: $table.lineNumber, builder: (column) => column);

  GeneratedColumn<String> get description => $composableBuilder(
      column: $table.description, builder: (column) => column);

  GeneratedColumn<int> get quantity =>
      $composableBuilder(column: $table.quantity, builder: (column) => column);

  GeneratedColumn<int> get unitPriceMinorUnits => $composableBuilder(
      column: $table.unitPriceMinorUnits, builder: (column) => column);

  GeneratedColumn<String> get currency =>
      $composableBuilder(column: $table.currency, builder: (column) => column);
}

class $$InvoiceLinesTableTableManager extends RootTableManager<
    _$AppDatabase,
    $InvoiceLinesTable,
    InvoiceLineRow,
    $$InvoiceLinesTableFilterComposer,
    $$InvoiceLinesTableOrderingComposer,
    $$InvoiceLinesTableAnnotationComposer,
    $$InvoiceLinesTableCreateCompanionBuilder,
    $$InvoiceLinesTableUpdateCompanionBuilder,
    (
      InvoiceLineRow,
      BaseReferences<_$AppDatabase, $InvoiceLinesTable, InvoiceLineRow>
    ),
    InvoiceLineRow,
    PrefetchHooks Function()> {
  $$InvoiceLinesTableTableManager(_$AppDatabase db, $InvoiceLinesTable table)
      : super(TableManagerState(
          db: db,
          table: table,
          createFilteringComposer: () =>
              $$InvoiceLinesTableFilterComposer($db: db, $table: table),
          createOrderingComposer: () =>
              $$InvoiceLinesTableOrderingComposer($db: db, $table: table),
          createComputedFieldComposer: () =>
              $$InvoiceLinesTableAnnotationComposer($db: db, $table: table),
          updateCompanionCallback: ({
            Value<int> id = const Value.absent(),
            Value<String> invoiceId = const Value.absent(),
            Value<int> lineNumber = const Value.absent(),
            Value<String> description = const Value.absent(),
            Value<int> quantity = const Value.absent(),
            Value<int> unitPriceMinorUnits = const Value.absent(),
            Value<String> currency = const Value.absent(),
          }) =>
              InvoiceLinesCompanion(
            id: id,
            invoiceId: invoiceId,
            lineNumber: lineNumber,
            description: description,
            quantity: quantity,
            unitPriceMinorUnits: unitPriceMinorUnits,
            currency: currency,
          ),
          createCompanionCallback: ({
            Value<int> id = const Value.absent(),
            required String invoiceId,
            required int lineNumber,
            required String description,
            required int quantity,
            required int unitPriceMinorUnits,
            required String currency,
          }) =>
              InvoiceLinesCompanion.insert(
            id: id,
            invoiceId: invoiceId,
            lineNumber: lineNumber,
            description: description,
            quantity: quantity,
            unitPriceMinorUnits: unitPriceMinorUnits,
            currency: currency,
          ),
          withReferenceMapper: (p0) => p0
              .map((e) => (e.readTable(table), BaseReferences(db, table, e)))
              .toList(),
          prefetchHooksCallback: null,
        ));
}

typedef $$InvoiceLinesTableProcessedTableManager = ProcessedTableManager<
    _$AppDatabase,
    $InvoiceLinesTable,
    InvoiceLineRow,
    $$InvoiceLinesTableFilterComposer,
    $$InvoiceLinesTableOrderingComposer,
    $$InvoiceLinesTableAnnotationComposer,
    $$InvoiceLinesTableCreateCompanionBuilder,
    $$InvoiceLinesTableUpdateCompanionBuilder,
    (
      InvoiceLineRow,
      BaseReferences<_$AppDatabase, $InvoiceLinesTable, InvoiceLineRow>
    ),
    InvoiceLineRow,
    PrefetchHooks Function()>;
typedef $$PaymentsTableCreateCompanionBuilder = PaymentsCompanion Function({
  required String id,
  required String invoiceId,
  required DateTime date,
  required int amountMinorUnits,
  required String currency,
  required String accountId,
  Value<int> rowid,
});
typedef $$PaymentsTableUpdateCompanionBuilder = PaymentsCompanion Function({
  Value<String> id,
  Value<String> invoiceId,
  Value<DateTime> date,
  Value<int> amountMinorUnits,
  Value<String> currency,
  Value<String> accountId,
  Value<int> rowid,
});

class $$PaymentsTableFilterComposer
    extends Composer<_$AppDatabase, $PaymentsTable> {
  $$PaymentsTableFilterComposer({
    required super.$db,
    required super.$table,
    super.joinBuilder,
    super.$addJoinBuilderToRootComposer,
    super.$removeJoinBuilderFromRootComposer,
  });
  ColumnFilters<String> get id => $composableBuilder(
      column: $table.id, builder: (column) => ColumnFilters(column));

  ColumnFilters<String> get invoiceId => $composableBuilder(
      column: $table.invoiceId, builder: (column) => ColumnFilters(column));

  ColumnFilters<DateTime> get date => $composableBuilder(
      column: $table.date, builder: (column) => ColumnFilters(column));

  ColumnFilters<int> get amountMinorUnits => $composableBuilder(
      column: $table.amountMinorUnits,
      builder: (column) => ColumnFilters(column));

  ColumnFilters<String> get currency => $composableBuilder(
      column: $table.currency, builder: (column) => ColumnFilters(column));

  ColumnFilters<String> get accountId => $composableBuilder(
      column: $table.accountId, builder: (column) => ColumnFilters(column));
}

class $$PaymentsTableOrderingComposer
    extends Composer<_$AppDatabase, $PaymentsTable> {
  $$PaymentsTableOrderingComposer({
    required super.$db,
    required super.$table,
    super.joinBuilder,
    super.$addJoinBuilderToRootComposer,
    super.$removeJoinBuilderFromRootComposer,
  });
  ColumnOrderings<String> get id => $composableBuilder(
      column: $table.id, builder: (column) => ColumnOrderings(column));

  ColumnOrderings<String> get invoiceId => $composableBuilder(
      column: $table.invoiceId, builder: (column) => ColumnOrderings(column));

  ColumnOrderings<DateTime> get date => $composableBuilder(
      column: $table.date, builder: (column) => ColumnOrderings(column));

  ColumnOrderings<int> get amountMinorUnits => $composableBuilder(
      column: $table.amountMinorUnits,
      builder: (column) => ColumnOrderings(column));

  ColumnOrderings<String> get currency => $composableBuilder(
      column: $table.currency, builder: (column) => ColumnOrderings(column));

  ColumnOrderings<String> get accountId => $composableBuilder(
      column: $table.accountId, builder: (column) => ColumnOrderings(column));
}

class $$PaymentsTableAnnotationComposer
    extends Composer<_$AppDatabase, $PaymentsTable> {
  $$PaymentsTableAnnotationComposer({
    required super.$db,
    required super.$table,
    super.joinBuilder,
    super.$addJoinBuilderToRootComposer,
    super.$removeJoinBuilderFromRootComposer,
  });
  GeneratedColumn<String> get id =>
      $composableBuilder(column: $table.id, builder: (column) => column);

  GeneratedColumn<String> get invoiceId =>
      $composableBuilder(column: $table.invoiceId, builder: (column) => column);

  GeneratedColumn<DateTime> get date =>
      $composableBuilder(column: $table.date, builder: (column) => column);

  GeneratedColumn<int> get amountMinorUnits => $composableBuilder(
      column: $table.amountMinorUnits, builder: (column) => column);

  GeneratedColumn<String> get currency =>
      $composableBuilder(column: $table.currency, builder: (column) => column);

  GeneratedColumn<String> get accountId =>
      $composableBuilder(column: $table.accountId, builder: (column) => column);
}

class $$PaymentsTableTableManager extends RootTableManager<
    _$AppDatabase,
    $PaymentsTable,
    PaymentRow,
    $$PaymentsTableFilterComposer,
    $$PaymentsTableOrderingComposer,
    $$PaymentsTableAnnotationComposer,
    $$PaymentsTableCreateCompanionBuilder,
    $$PaymentsTableUpdateCompanionBuilder,
    (PaymentRow, BaseReferences<_$AppDatabase, $PaymentsTable, PaymentRow>),
    PaymentRow,
    PrefetchHooks Function()> {
  $$PaymentsTableTableManager(_$AppDatabase db, $PaymentsTable table)
      : super(TableManagerState(
          db: db,
          table: table,
          createFilteringComposer: () =>
              $$PaymentsTableFilterComposer($db: db, $table: table),
          createOrderingComposer: () =>
              $$PaymentsTableOrderingComposer($db: db, $table: table),
          createComputedFieldComposer: () =>
              $$PaymentsTableAnnotationComposer($db: db, $table: table),
          updateCompanionCallback: ({
            Value<String> id = const Value.absent(),
            Value<String> invoiceId = const Value.absent(),
            Value<DateTime> date = const Value.absent(),
            Value<int> amountMinorUnits = const Value.absent(),
            Value<String> currency = const Value.absent(),
            Value<String> accountId = const Value.absent(),
            Value<int> rowid = const Value.absent(),
          }) =>
              PaymentsCompanion(
            id: id,
            invoiceId: invoiceId,
            date: date,
            amountMinorUnits: amountMinorUnits,
            currency: currency,
            accountId: accountId,
            rowid: rowid,
          ),
          createCompanionCallback: ({
            required String id,
            required String invoiceId,
            required DateTime date,
            required int amountMinorUnits,
            required String currency,
            required String accountId,
            Value<int> rowid = const Value.absent(),
          }) =>
              PaymentsCompanion.insert(
            id: id,
            invoiceId: invoiceId,
            date: date,
            amountMinorUnits: amountMinorUnits,
            currency: currency,
            accountId: accountId,
            rowid: rowid,
          ),
          withReferenceMapper: (p0) => p0
              .map((e) => (e.readTable(table), BaseReferences(db, table, e)))
              .toList(),
          prefetchHooksCallback: null,
        ));
}

typedef $$PaymentsTableProcessedTableManager = ProcessedTableManager<
    _$AppDatabase,
    $PaymentsTable,
    PaymentRow,
    $$PaymentsTableFilterComposer,
    $$PaymentsTableOrderingComposer,
    $$PaymentsTableAnnotationComposer,
    $$PaymentsTableCreateCompanionBuilder,
    $$PaymentsTableUpdateCompanionBuilder,
    (PaymentRow, BaseReferences<_$AppDatabase, $PaymentsTable, PaymentRow>),
    PaymentRow,
    PrefetchHooks Function()>;
typedef $$CreditNotesTableCreateCompanionBuilder = CreditNotesCompanion
    Function({
  required String id,
  required String number,
  required int sequence,
  required String fiscalYearLabel,
  required String invoiceId,
  required DateTime date,
  required String currency,
  required int vatRateBasisPoints,
  required int subtotalMinorUnits,
  required int vatMinorUnits,
  required int totalMinorUnits,
  required String journalEntryId,
  Value<int> rowid,
});
typedef $$CreditNotesTableUpdateCompanionBuilder = CreditNotesCompanion
    Function({
  Value<String> id,
  Value<String> number,
  Value<int> sequence,
  Value<String> fiscalYearLabel,
  Value<String> invoiceId,
  Value<DateTime> date,
  Value<String> currency,
  Value<int> vatRateBasisPoints,
  Value<int> subtotalMinorUnits,
  Value<int> vatMinorUnits,
  Value<int> totalMinorUnits,
  Value<String> journalEntryId,
  Value<int> rowid,
});

class $$CreditNotesTableFilterComposer
    extends Composer<_$AppDatabase, $CreditNotesTable> {
  $$CreditNotesTableFilterComposer({
    required super.$db,
    required super.$table,
    super.joinBuilder,
    super.$addJoinBuilderToRootComposer,
    super.$removeJoinBuilderFromRootComposer,
  });
  ColumnFilters<String> get id => $composableBuilder(
      column: $table.id, builder: (column) => ColumnFilters(column));

  ColumnFilters<String> get number => $composableBuilder(
      column: $table.number, builder: (column) => ColumnFilters(column));

  ColumnFilters<int> get sequence => $composableBuilder(
      column: $table.sequence, builder: (column) => ColumnFilters(column));

  ColumnFilters<String> get fiscalYearLabel => $composableBuilder(
      column: $table.fiscalYearLabel,
      builder: (column) => ColumnFilters(column));

  ColumnFilters<String> get invoiceId => $composableBuilder(
      column: $table.invoiceId, builder: (column) => ColumnFilters(column));

  ColumnFilters<DateTime> get date => $composableBuilder(
      column: $table.date, builder: (column) => ColumnFilters(column));

  ColumnFilters<String> get currency => $composableBuilder(
      column: $table.currency, builder: (column) => ColumnFilters(column));

  ColumnFilters<int> get vatRateBasisPoints => $composableBuilder(
      column: $table.vatRateBasisPoints,
      builder: (column) => ColumnFilters(column));

  ColumnFilters<int> get subtotalMinorUnits => $composableBuilder(
      column: $table.subtotalMinorUnits,
      builder: (column) => ColumnFilters(column));

  ColumnFilters<int> get vatMinorUnits => $composableBuilder(
      column: $table.vatMinorUnits, builder: (column) => ColumnFilters(column));

  ColumnFilters<int> get totalMinorUnits => $composableBuilder(
      column: $table.totalMinorUnits,
      builder: (column) => ColumnFilters(column));

  ColumnFilters<String> get journalEntryId => $composableBuilder(
      column: $table.journalEntryId,
      builder: (column) => ColumnFilters(column));
}

class $$CreditNotesTableOrderingComposer
    extends Composer<_$AppDatabase, $CreditNotesTable> {
  $$CreditNotesTableOrderingComposer({
    required super.$db,
    required super.$table,
    super.joinBuilder,
    super.$addJoinBuilderToRootComposer,
    super.$removeJoinBuilderFromRootComposer,
  });
  ColumnOrderings<String> get id => $composableBuilder(
      column: $table.id, builder: (column) => ColumnOrderings(column));

  ColumnOrderings<String> get number => $composableBuilder(
      column: $table.number, builder: (column) => ColumnOrderings(column));

  ColumnOrderings<int> get sequence => $composableBuilder(
      column: $table.sequence, builder: (column) => ColumnOrderings(column));

  ColumnOrderings<String> get fiscalYearLabel => $composableBuilder(
      column: $table.fiscalYearLabel,
      builder: (column) => ColumnOrderings(column));

  ColumnOrderings<String> get invoiceId => $composableBuilder(
      column: $table.invoiceId, builder: (column) => ColumnOrderings(column));

  ColumnOrderings<DateTime> get date => $composableBuilder(
      column: $table.date, builder: (column) => ColumnOrderings(column));

  ColumnOrderings<String> get currency => $composableBuilder(
      column: $table.currency, builder: (column) => ColumnOrderings(column));

  ColumnOrderings<int> get vatRateBasisPoints => $composableBuilder(
      column: $table.vatRateBasisPoints,
      builder: (column) => ColumnOrderings(column));

  ColumnOrderings<int> get subtotalMinorUnits => $composableBuilder(
      column: $table.subtotalMinorUnits,
      builder: (column) => ColumnOrderings(column));

  ColumnOrderings<int> get vatMinorUnits => $composableBuilder(
      column: $table.vatMinorUnits,
      builder: (column) => ColumnOrderings(column));

  ColumnOrderings<int> get totalMinorUnits => $composableBuilder(
      column: $table.totalMinorUnits,
      builder: (column) => ColumnOrderings(column));

  ColumnOrderings<String> get journalEntryId => $composableBuilder(
      column: $table.journalEntryId,
      builder: (column) => ColumnOrderings(column));
}

class $$CreditNotesTableAnnotationComposer
    extends Composer<_$AppDatabase, $CreditNotesTable> {
  $$CreditNotesTableAnnotationComposer({
    required super.$db,
    required super.$table,
    super.joinBuilder,
    super.$addJoinBuilderToRootComposer,
    super.$removeJoinBuilderFromRootComposer,
  });
  GeneratedColumn<String> get id =>
      $composableBuilder(column: $table.id, builder: (column) => column);

  GeneratedColumn<String> get number =>
      $composableBuilder(column: $table.number, builder: (column) => column);

  GeneratedColumn<int> get sequence =>
      $composableBuilder(column: $table.sequence, builder: (column) => column);

  GeneratedColumn<String> get fiscalYearLabel => $composableBuilder(
      column: $table.fiscalYearLabel, builder: (column) => column);

  GeneratedColumn<String> get invoiceId =>
      $composableBuilder(column: $table.invoiceId, builder: (column) => column);

  GeneratedColumn<DateTime> get date =>
      $composableBuilder(column: $table.date, builder: (column) => column);

  GeneratedColumn<String> get currency =>
      $composableBuilder(column: $table.currency, builder: (column) => column);

  GeneratedColumn<int> get vatRateBasisPoints => $composableBuilder(
      column: $table.vatRateBasisPoints, builder: (column) => column);

  GeneratedColumn<int> get subtotalMinorUnits => $composableBuilder(
      column: $table.subtotalMinorUnits, builder: (column) => column);

  GeneratedColumn<int> get vatMinorUnits => $composableBuilder(
      column: $table.vatMinorUnits, builder: (column) => column);

  GeneratedColumn<int> get totalMinorUnits => $composableBuilder(
      column: $table.totalMinorUnits, builder: (column) => column);

  GeneratedColumn<String> get journalEntryId => $composableBuilder(
      column: $table.journalEntryId, builder: (column) => column);
}

class $$CreditNotesTableTableManager extends RootTableManager<
    _$AppDatabase,
    $CreditNotesTable,
    CreditNoteRow,
    $$CreditNotesTableFilterComposer,
    $$CreditNotesTableOrderingComposer,
    $$CreditNotesTableAnnotationComposer,
    $$CreditNotesTableCreateCompanionBuilder,
    $$CreditNotesTableUpdateCompanionBuilder,
    (
      CreditNoteRow,
      BaseReferences<_$AppDatabase, $CreditNotesTable, CreditNoteRow>
    ),
    CreditNoteRow,
    PrefetchHooks Function()> {
  $$CreditNotesTableTableManager(_$AppDatabase db, $CreditNotesTable table)
      : super(TableManagerState(
          db: db,
          table: table,
          createFilteringComposer: () =>
              $$CreditNotesTableFilterComposer($db: db, $table: table),
          createOrderingComposer: () =>
              $$CreditNotesTableOrderingComposer($db: db, $table: table),
          createComputedFieldComposer: () =>
              $$CreditNotesTableAnnotationComposer($db: db, $table: table),
          updateCompanionCallback: ({
            Value<String> id = const Value.absent(),
            Value<String> number = const Value.absent(),
            Value<int> sequence = const Value.absent(),
            Value<String> fiscalYearLabel = const Value.absent(),
            Value<String> invoiceId = const Value.absent(),
            Value<DateTime> date = const Value.absent(),
            Value<String> currency = const Value.absent(),
            Value<int> vatRateBasisPoints = const Value.absent(),
            Value<int> subtotalMinorUnits = const Value.absent(),
            Value<int> vatMinorUnits = const Value.absent(),
            Value<int> totalMinorUnits = const Value.absent(),
            Value<String> journalEntryId = const Value.absent(),
            Value<int> rowid = const Value.absent(),
          }) =>
              CreditNotesCompanion(
            id: id,
            number: number,
            sequence: sequence,
            fiscalYearLabel: fiscalYearLabel,
            invoiceId: invoiceId,
            date: date,
            currency: currency,
            vatRateBasisPoints: vatRateBasisPoints,
            subtotalMinorUnits: subtotalMinorUnits,
            vatMinorUnits: vatMinorUnits,
            totalMinorUnits: totalMinorUnits,
            journalEntryId: journalEntryId,
            rowid: rowid,
          ),
          createCompanionCallback: ({
            required String id,
            required String number,
            required int sequence,
            required String fiscalYearLabel,
            required String invoiceId,
            required DateTime date,
            required String currency,
            required int vatRateBasisPoints,
            required int subtotalMinorUnits,
            required int vatMinorUnits,
            required int totalMinorUnits,
            required String journalEntryId,
            Value<int> rowid = const Value.absent(),
          }) =>
              CreditNotesCompanion.insert(
            id: id,
            number: number,
            sequence: sequence,
            fiscalYearLabel: fiscalYearLabel,
            invoiceId: invoiceId,
            date: date,
            currency: currency,
            vatRateBasisPoints: vatRateBasisPoints,
            subtotalMinorUnits: subtotalMinorUnits,
            vatMinorUnits: vatMinorUnits,
            totalMinorUnits: totalMinorUnits,
            journalEntryId: journalEntryId,
            rowid: rowid,
          ),
          withReferenceMapper: (p0) => p0
              .map((e) => (e.readTable(table), BaseReferences(db, table, e)))
              .toList(),
          prefetchHooksCallback: null,
        ));
}

typedef $$CreditNotesTableProcessedTableManager = ProcessedTableManager<
    _$AppDatabase,
    $CreditNotesTable,
    CreditNoteRow,
    $$CreditNotesTableFilterComposer,
    $$CreditNotesTableOrderingComposer,
    $$CreditNotesTableAnnotationComposer,
    $$CreditNotesTableCreateCompanionBuilder,
    $$CreditNotesTableUpdateCompanionBuilder,
    (
      CreditNoteRow,
      BaseReferences<_$AppDatabase, $CreditNotesTable, CreditNoteRow>
    ),
    CreditNoteRow,
    PrefetchHooks Function()>;
typedef $$CreditNoteLinesTableCreateCompanionBuilder = CreditNoteLinesCompanion
    Function({
  Value<int> id,
  required String creditNoteId,
  required int lineNumber,
  required String description,
  required int quantity,
  required int unitPriceMinorUnits,
  required String currency,
});
typedef $$CreditNoteLinesTableUpdateCompanionBuilder = CreditNoteLinesCompanion
    Function({
  Value<int> id,
  Value<String> creditNoteId,
  Value<int> lineNumber,
  Value<String> description,
  Value<int> quantity,
  Value<int> unitPriceMinorUnits,
  Value<String> currency,
});

class $$CreditNoteLinesTableFilterComposer
    extends Composer<_$AppDatabase, $CreditNoteLinesTable> {
  $$CreditNoteLinesTableFilterComposer({
    required super.$db,
    required super.$table,
    super.joinBuilder,
    super.$addJoinBuilderToRootComposer,
    super.$removeJoinBuilderFromRootComposer,
  });
  ColumnFilters<int> get id => $composableBuilder(
      column: $table.id, builder: (column) => ColumnFilters(column));

  ColumnFilters<String> get creditNoteId => $composableBuilder(
      column: $table.creditNoteId, builder: (column) => ColumnFilters(column));

  ColumnFilters<int> get lineNumber => $composableBuilder(
      column: $table.lineNumber, builder: (column) => ColumnFilters(column));

  ColumnFilters<String> get description => $composableBuilder(
      column: $table.description, builder: (column) => ColumnFilters(column));

  ColumnFilters<int> get quantity => $composableBuilder(
      column: $table.quantity, builder: (column) => ColumnFilters(column));

  ColumnFilters<int> get unitPriceMinorUnits => $composableBuilder(
      column: $table.unitPriceMinorUnits,
      builder: (column) => ColumnFilters(column));

  ColumnFilters<String> get currency => $composableBuilder(
      column: $table.currency, builder: (column) => ColumnFilters(column));
}

class $$CreditNoteLinesTableOrderingComposer
    extends Composer<_$AppDatabase, $CreditNoteLinesTable> {
  $$CreditNoteLinesTableOrderingComposer({
    required super.$db,
    required super.$table,
    super.joinBuilder,
    super.$addJoinBuilderToRootComposer,
    super.$removeJoinBuilderFromRootComposer,
  });
  ColumnOrderings<int> get id => $composableBuilder(
      column: $table.id, builder: (column) => ColumnOrderings(column));

  ColumnOrderings<String> get creditNoteId => $composableBuilder(
      column: $table.creditNoteId,
      builder: (column) => ColumnOrderings(column));

  ColumnOrderings<int> get lineNumber => $composableBuilder(
      column: $table.lineNumber, builder: (column) => ColumnOrderings(column));

  ColumnOrderings<String> get description => $composableBuilder(
      column: $table.description, builder: (column) => ColumnOrderings(column));

  ColumnOrderings<int> get quantity => $composableBuilder(
      column: $table.quantity, builder: (column) => ColumnOrderings(column));

  ColumnOrderings<int> get unitPriceMinorUnits => $composableBuilder(
      column: $table.unitPriceMinorUnits,
      builder: (column) => ColumnOrderings(column));

  ColumnOrderings<String> get currency => $composableBuilder(
      column: $table.currency, builder: (column) => ColumnOrderings(column));
}

class $$CreditNoteLinesTableAnnotationComposer
    extends Composer<_$AppDatabase, $CreditNoteLinesTable> {
  $$CreditNoteLinesTableAnnotationComposer({
    required super.$db,
    required super.$table,
    super.joinBuilder,
    super.$addJoinBuilderToRootComposer,
    super.$removeJoinBuilderFromRootComposer,
  });
  GeneratedColumn<int> get id =>
      $composableBuilder(column: $table.id, builder: (column) => column);

  GeneratedColumn<String> get creditNoteId => $composableBuilder(
      column: $table.creditNoteId, builder: (column) => column);

  GeneratedColumn<int> get lineNumber => $composableBuilder(
      column: $table.lineNumber, builder: (column) => column);

  GeneratedColumn<String> get description => $composableBuilder(
      column: $table.description, builder: (column) => column);

  GeneratedColumn<int> get quantity =>
      $composableBuilder(column: $table.quantity, builder: (column) => column);

  GeneratedColumn<int> get unitPriceMinorUnits => $composableBuilder(
      column: $table.unitPriceMinorUnits, builder: (column) => column);

  GeneratedColumn<String> get currency =>
      $composableBuilder(column: $table.currency, builder: (column) => column);
}

class $$CreditNoteLinesTableTableManager extends RootTableManager<
    _$AppDatabase,
    $CreditNoteLinesTable,
    CreditNoteLineRow,
    $$CreditNoteLinesTableFilterComposer,
    $$CreditNoteLinesTableOrderingComposer,
    $$CreditNoteLinesTableAnnotationComposer,
    $$CreditNoteLinesTableCreateCompanionBuilder,
    $$CreditNoteLinesTableUpdateCompanionBuilder,
    (
      CreditNoteLineRow,
      BaseReferences<_$AppDatabase, $CreditNoteLinesTable, CreditNoteLineRow>
    ),
    CreditNoteLineRow,
    PrefetchHooks Function()> {
  $$CreditNoteLinesTableTableManager(
      _$AppDatabase db, $CreditNoteLinesTable table)
      : super(TableManagerState(
          db: db,
          table: table,
          createFilteringComposer: () =>
              $$CreditNoteLinesTableFilterComposer($db: db, $table: table),
          createOrderingComposer: () =>
              $$CreditNoteLinesTableOrderingComposer($db: db, $table: table),
          createComputedFieldComposer: () =>
              $$CreditNoteLinesTableAnnotationComposer($db: db, $table: table),
          updateCompanionCallback: ({
            Value<int> id = const Value.absent(),
            Value<String> creditNoteId = const Value.absent(),
            Value<int> lineNumber = const Value.absent(),
            Value<String> description = const Value.absent(),
            Value<int> quantity = const Value.absent(),
            Value<int> unitPriceMinorUnits = const Value.absent(),
            Value<String> currency = const Value.absent(),
          }) =>
              CreditNoteLinesCompanion(
            id: id,
            creditNoteId: creditNoteId,
            lineNumber: lineNumber,
            description: description,
            quantity: quantity,
            unitPriceMinorUnits: unitPriceMinorUnits,
            currency: currency,
          ),
          createCompanionCallback: ({
            Value<int> id = const Value.absent(),
            required String creditNoteId,
            required int lineNumber,
            required String description,
            required int quantity,
            required int unitPriceMinorUnits,
            required String currency,
          }) =>
              CreditNoteLinesCompanion.insert(
            id: id,
            creditNoteId: creditNoteId,
            lineNumber: lineNumber,
            description: description,
            quantity: quantity,
            unitPriceMinorUnits: unitPriceMinorUnits,
            currency: currency,
          ),
          withReferenceMapper: (p0) => p0
              .map((e) => (e.readTable(table), BaseReferences(db, table, e)))
              .toList(),
          prefetchHooksCallback: null,
        ));
}

typedef $$CreditNoteLinesTableProcessedTableManager = ProcessedTableManager<
    _$AppDatabase,
    $CreditNoteLinesTable,
    CreditNoteLineRow,
    $$CreditNoteLinesTableFilterComposer,
    $$CreditNoteLinesTableOrderingComposer,
    $$CreditNoteLinesTableAnnotationComposer,
    $$CreditNoteLinesTableCreateCompanionBuilder,
    $$CreditNoteLinesTableUpdateCompanionBuilder,
    (
      CreditNoteLineRow,
      BaseReferences<_$AppDatabase, $CreditNoteLinesTable, CreditNoteLineRow>
    ),
    CreditNoteLineRow,
    PrefetchHooks Function()>;
typedef $$ProductsTableCreateCompanionBuilder = ProductsCompanion Function({
  required String id,
  required String name,
  required int salePriceMinorUnits,
  required String currency,
  required bool stockTrackingEnabled,
  Value<int> rowid,
});
typedef $$ProductsTableUpdateCompanionBuilder = ProductsCompanion Function({
  Value<String> id,
  Value<String> name,
  Value<int> salePriceMinorUnits,
  Value<String> currency,
  Value<bool> stockTrackingEnabled,
  Value<int> rowid,
});

class $$ProductsTableFilterComposer
    extends Composer<_$AppDatabase, $ProductsTable> {
  $$ProductsTableFilterComposer({
    required super.$db,
    required super.$table,
    super.joinBuilder,
    super.$addJoinBuilderToRootComposer,
    super.$removeJoinBuilderFromRootComposer,
  });
  ColumnFilters<String> get id => $composableBuilder(
      column: $table.id, builder: (column) => ColumnFilters(column));

  ColumnFilters<String> get name => $composableBuilder(
      column: $table.name, builder: (column) => ColumnFilters(column));

  ColumnFilters<int> get salePriceMinorUnits => $composableBuilder(
      column: $table.salePriceMinorUnits,
      builder: (column) => ColumnFilters(column));

  ColumnFilters<String> get currency => $composableBuilder(
      column: $table.currency, builder: (column) => ColumnFilters(column));

  ColumnFilters<bool> get stockTrackingEnabled => $composableBuilder(
      column: $table.stockTrackingEnabled,
      builder: (column) => ColumnFilters(column));
}

class $$ProductsTableOrderingComposer
    extends Composer<_$AppDatabase, $ProductsTable> {
  $$ProductsTableOrderingComposer({
    required super.$db,
    required super.$table,
    super.joinBuilder,
    super.$addJoinBuilderToRootComposer,
    super.$removeJoinBuilderFromRootComposer,
  });
  ColumnOrderings<String> get id => $composableBuilder(
      column: $table.id, builder: (column) => ColumnOrderings(column));

  ColumnOrderings<String> get name => $composableBuilder(
      column: $table.name, builder: (column) => ColumnOrderings(column));

  ColumnOrderings<int> get salePriceMinorUnits => $composableBuilder(
      column: $table.salePriceMinorUnits,
      builder: (column) => ColumnOrderings(column));

  ColumnOrderings<String> get currency => $composableBuilder(
      column: $table.currency, builder: (column) => ColumnOrderings(column));

  ColumnOrderings<bool> get stockTrackingEnabled => $composableBuilder(
      column: $table.stockTrackingEnabled,
      builder: (column) => ColumnOrderings(column));
}

class $$ProductsTableAnnotationComposer
    extends Composer<_$AppDatabase, $ProductsTable> {
  $$ProductsTableAnnotationComposer({
    required super.$db,
    required super.$table,
    super.joinBuilder,
    super.$addJoinBuilderToRootComposer,
    super.$removeJoinBuilderFromRootComposer,
  });
  GeneratedColumn<String> get id =>
      $composableBuilder(column: $table.id, builder: (column) => column);

  GeneratedColumn<String> get name =>
      $composableBuilder(column: $table.name, builder: (column) => column);

  GeneratedColumn<int> get salePriceMinorUnits => $composableBuilder(
      column: $table.salePriceMinorUnits, builder: (column) => column);

  GeneratedColumn<String> get currency =>
      $composableBuilder(column: $table.currency, builder: (column) => column);

  GeneratedColumn<bool> get stockTrackingEnabled => $composableBuilder(
      column: $table.stockTrackingEnabled, builder: (column) => column);
}

class $$ProductsTableTableManager extends RootTableManager<
    _$AppDatabase,
    $ProductsTable,
    ProductRow,
    $$ProductsTableFilterComposer,
    $$ProductsTableOrderingComposer,
    $$ProductsTableAnnotationComposer,
    $$ProductsTableCreateCompanionBuilder,
    $$ProductsTableUpdateCompanionBuilder,
    (ProductRow, BaseReferences<_$AppDatabase, $ProductsTable, ProductRow>),
    ProductRow,
    PrefetchHooks Function()> {
  $$ProductsTableTableManager(_$AppDatabase db, $ProductsTable table)
      : super(TableManagerState(
          db: db,
          table: table,
          createFilteringComposer: () =>
              $$ProductsTableFilterComposer($db: db, $table: table),
          createOrderingComposer: () =>
              $$ProductsTableOrderingComposer($db: db, $table: table),
          createComputedFieldComposer: () =>
              $$ProductsTableAnnotationComposer($db: db, $table: table),
          updateCompanionCallback: ({
            Value<String> id = const Value.absent(),
            Value<String> name = const Value.absent(),
            Value<int> salePriceMinorUnits = const Value.absent(),
            Value<String> currency = const Value.absent(),
            Value<bool> stockTrackingEnabled = const Value.absent(),
            Value<int> rowid = const Value.absent(),
          }) =>
              ProductsCompanion(
            id: id,
            name: name,
            salePriceMinorUnits: salePriceMinorUnits,
            currency: currency,
            stockTrackingEnabled: stockTrackingEnabled,
            rowid: rowid,
          ),
          createCompanionCallback: ({
            required String id,
            required String name,
            required int salePriceMinorUnits,
            required String currency,
            required bool stockTrackingEnabled,
            Value<int> rowid = const Value.absent(),
          }) =>
              ProductsCompanion.insert(
            id: id,
            name: name,
            salePriceMinorUnits: salePriceMinorUnits,
            currency: currency,
            stockTrackingEnabled: stockTrackingEnabled,
            rowid: rowid,
          ),
          withReferenceMapper: (p0) => p0
              .map((e) => (e.readTable(table), BaseReferences(db, table, e)))
              .toList(),
          prefetchHooksCallback: null,
        ));
}

typedef $$ProductsTableProcessedTableManager = ProcessedTableManager<
    _$AppDatabase,
    $ProductsTable,
    ProductRow,
    $$ProductsTableFilterComposer,
    $$ProductsTableOrderingComposer,
    $$ProductsTableAnnotationComposer,
    $$ProductsTableCreateCompanionBuilder,
    $$ProductsTableUpdateCompanionBuilder,
    (ProductRow, BaseReferences<_$AppDatabase, $ProductsTable, ProductRow>),
    ProductRow,
    PrefetchHooks Function()>;
typedef $$InventoryMovementsTableCreateCompanionBuilder
    = InventoryMovementsCompanion Function({
  required String id,
  required String productId,
  required DateTime date,
  required String reason,
  required int quantity,
  required int valueMinorUnits,
  required String currency,
  Value<String?> journalEntryId,
  Value<int> rowid,
});
typedef $$InventoryMovementsTableUpdateCompanionBuilder
    = InventoryMovementsCompanion Function({
  Value<String> id,
  Value<String> productId,
  Value<DateTime> date,
  Value<String> reason,
  Value<int> quantity,
  Value<int> valueMinorUnits,
  Value<String> currency,
  Value<String?> journalEntryId,
  Value<int> rowid,
});

class $$InventoryMovementsTableFilterComposer
    extends Composer<_$AppDatabase, $InventoryMovementsTable> {
  $$InventoryMovementsTableFilterComposer({
    required super.$db,
    required super.$table,
    super.joinBuilder,
    super.$addJoinBuilderToRootComposer,
    super.$removeJoinBuilderFromRootComposer,
  });
  ColumnFilters<String> get id => $composableBuilder(
      column: $table.id, builder: (column) => ColumnFilters(column));

  ColumnFilters<String> get productId => $composableBuilder(
      column: $table.productId, builder: (column) => ColumnFilters(column));

  ColumnFilters<DateTime> get date => $composableBuilder(
      column: $table.date, builder: (column) => ColumnFilters(column));

  ColumnFilters<String> get reason => $composableBuilder(
      column: $table.reason, builder: (column) => ColumnFilters(column));

  ColumnFilters<int> get quantity => $composableBuilder(
      column: $table.quantity, builder: (column) => ColumnFilters(column));

  ColumnFilters<int> get valueMinorUnits => $composableBuilder(
      column: $table.valueMinorUnits,
      builder: (column) => ColumnFilters(column));

  ColumnFilters<String> get currency => $composableBuilder(
      column: $table.currency, builder: (column) => ColumnFilters(column));

  ColumnFilters<String> get journalEntryId => $composableBuilder(
      column: $table.journalEntryId,
      builder: (column) => ColumnFilters(column));
}

class $$InventoryMovementsTableOrderingComposer
    extends Composer<_$AppDatabase, $InventoryMovementsTable> {
  $$InventoryMovementsTableOrderingComposer({
    required super.$db,
    required super.$table,
    super.joinBuilder,
    super.$addJoinBuilderToRootComposer,
    super.$removeJoinBuilderFromRootComposer,
  });
  ColumnOrderings<String> get id => $composableBuilder(
      column: $table.id, builder: (column) => ColumnOrderings(column));

  ColumnOrderings<String> get productId => $composableBuilder(
      column: $table.productId, builder: (column) => ColumnOrderings(column));

  ColumnOrderings<DateTime> get date => $composableBuilder(
      column: $table.date, builder: (column) => ColumnOrderings(column));

  ColumnOrderings<String> get reason => $composableBuilder(
      column: $table.reason, builder: (column) => ColumnOrderings(column));

  ColumnOrderings<int> get quantity => $composableBuilder(
      column: $table.quantity, builder: (column) => ColumnOrderings(column));

  ColumnOrderings<int> get valueMinorUnits => $composableBuilder(
      column: $table.valueMinorUnits,
      builder: (column) => ColumnOrderings(column));

  ColumnOrderings<String> get currency => $composableBuilder(
      column: $table.currency, builder: (column) => ColumnOrderings(column));

  ColumnOrderings<String> get journalEntryId => $composableBuilder(
      column: $table.journalEntryId,
      builder: (column) => ColumnOrderings(column));
}

class $$InventoryMovementsTableAnnotationComposer
    extends Composer<_$AppDatabase, $InventoryMovementsTable> {
  $$InventoryMovementsTableAnnotationComposer({
    required super.$db,
    required super.$table,
    super.joinBuilder,
    super.$addJoinBuilderToRootComposer,
    super.$removeJoinBuilderFromRootComposer,
  });
  GeneratedColumn<String> get id =>
      $composableBuilder(column: $table.id, builder: (column) => column);

  GeneratedColumn<String> get productId =>
      $composableBuilder(column: $table.productId, builder: (column) => column);

  GeneratedColumn<DateTime> get date =>
      $composableBuilder(column: $table.date, builder: (column) => column);

  GeneratedColumn<String> get reason =>
      $composableBuilder(column: $table.reason, builder: (column) => column);

  GeneratedColumn<int> get quantity =>
      $composableBuilder(column: $table.quantity, builder: (column) => column);

  GeneratedColumn<int> get valueMinorUnits => $composableBuilder(
      column: $table.valueMinorUnits, builder: (column) => column);

  GeneratedColumn<String> get currency =>
      $composableBuilder(column: $table.currency, builder: (column) => column);

  GeneratedColumn<String> get journalEntryId => $composableBuilder(
      column: $table.journalEntryId, builder: (column) => column);
}

class $$InventoryMovementsTableTableManager extends RootTableManager<
    _$AppDatabase,
    $InventoryMovementsTable,
    InventoryMovementRow,
    $$InventoryMovementsTableFilterComposer,
    $$InventoryMovementsTableOrderingComposer,
    $$InventoryMovementsTableAnnotationComposer,
    $$InventoryMovementsTableCreateCompanionBuilder,
    $$InventoryMovementsTableUpdateCompanionBuilder,
    (
      InventoryMovementRow,
      BaseReferences<_$AppDatabase, $InventoryMovementsTable,
          InventoryMovementRow>
    ),
    InventoryMovementRow,
    PrefetchHooks Function()> {
  $$InventoryMovementsTableTableManager(
      _$AppDatabase db, $InventoryMovementsTable table)
      : super(TableManagerState(
          db: db,
          table: table,
          createFilteringComposer: () =>
              $$InventoryMovementsTableFilterComposer($db: db, $table: table),
          createOrderingComposer: () =>
              $$InventoryMovementsTableOrderingComposer($db: db, $table: table),
          createComputedFieldComposer: () =>
              $$InventoryMovementsTableAnnotationComposer(
                  $db: db, $table: table),
          updateCompanionCallback: ({
            Value<String> id = const Value.absent(),
            Value<String> productId = const Value.absent(),
            Value<DateTime> date = const Value.absent(),
            Value<String> reason = const Value.absent(),
            Value<int> quantity = const Value.absent(),
            Value<int> valueMinorUnits = const Value.absent(),
            Value<String> currency = const Value.absent(),
            Value<String?> journalEntryId = const Value.absent(),
            Value<int> rowid = const Value.absent(),
          }) =>
              InventoryMovementsCompanion(
            id: id,
            productId: productId,
            date: date,
            reason: reason,
            quantity: quantity,
            valueMinorUnits: valueMinorUnits,
            currency: currency,
            journalEntryId: journalEntryId,
            rowid: rowid,
          ),
          createCompanionCallback: ({
            required String id,
            required String productId,
            required DateTime date,
            required String reason,
            required int quantity,
            required int valueMinorUnits,
            required String currency,
            Value<String?> journalEntryId = const Value.absent(),
            Value<int> rowid = const Value.absent(),
          }) =>
              InventoryMovementsCompanion.insert(
            id: id,
            productId: productId,
            date: date,
            reason: reason,
            quantity: quantity,
            valueMinorUnits: valueMinorUnits,
            currency: currency,
            journalEntryId: journalEntryId,
            rowid: rowid,
          ),
          withReferenceMapper: (p0) => p0
              .map((e) => (e.readTable(table), BaseReferences(db, table, e)))
              .toList(),
          prefetchHooksCallback: null,
        ));
}

typedef $$InventoryMovementsTableProcessedTableManager = ProcessedTableManager<
    _$AppDatabase,
    $InventoryMovementsTable,
    InventoryMovementRow,
    $$InventoryMovementsTableFilterComposer,
    $$InventoryMovementsTableOrderingComposer,
    $$InventoryMovementsTableAnnotationComposer,
    $$InventoryMovementsTableCreateCompanionBuilder,
    $$InventoryMovementsTableUpdateCompanionBuilder,
    (
      InventoryMovementRow,
      BaseReferences<_$AppDatabase, $InventoryMovementsTable,
          InventoryMovementRow>
    ),
    InventoryMovementRow,
    PrefetchHooks Function()>;
typedef $$CustomerDetailsTableCreateCompanionBuilder = CustomerDetailsCompanion
    Function({
  required String customerId,
  Value<String?> code,
  Value<bool> isVatRegistered,
  Value<String?> businessName,
  Value<int> rowid,
});
typedef $$CustomerDetailsTableUpdateCompanionBuilder = CustomerDetailsCompanion
    Function({
  Value<String> customerId,
  Value<String?> code,
  Value<bool> isVatRegistered,
  Value<String?> businessName,
  Value<int> rowid,
});

class $$CustomerDetailsTableFilterComposer
    extends Composer<_$AppDatabase, $CustomerDetailsTable> {
  $$CustomerDetailsTableFilterComposer({
    required super.$db,
    required super.$table,
    super.joinBuilder,
    super.$addJoinBuilderToRootComposer,
    super.$removeJoinBuilderFromRootComposer,
  });
  ColumnFilters<String> get customerId => $composableBuilder(
      column: $table.customerId, builder: (column) => ColumnFilters(column));

  ColumnFilters<String> get code => $composableBuilder(
      column: $table.code, builder: (column) => ColumnFilters(column));

  ColumnFilters<bool> get isVatRegistered => $composableBuilder(
      column: $table.isVatRegistered,
      builder: (column) => ColumnFilters(column));

  ColumnFilters<String> get businessName => $composableBuilder(
      column: $table.businessName, builder: (column) => ColumnFilters(column));
}

class $$CustomerDetailsTableOrderingComposer
    extends Composer<_$AppDatabase, $CustomerDetailsTable> {
  $$CustomerDetailsTableOrderingComposer({
    required super.$db,
    required super.$table,
    super.joinBuilder,
    super.$addJoinBuilderToRootComposer,
    super.$removeJoinBuilderFromRootComposer,
  });
  ColumnOrderings<String> get customerId => $composableBuilder(
      column: $table.customerId, builder: (column) => ColumnOrderings(column));

  ColumnOrderings<String> get code => $composableBuilder(
      column: $table.code, builder: (column) => ColumnOrderings(column));

  ColumnOrderings<bool> get isVatRegistered => $composableBuilder(
      column: $table.isVatRegistered,
      builder: (column) => ColumnOrderings(column));

  ColumnOrderings<String> get businessName => $composableBuilder(
      column: $table.businessName,
      builder: (column) => ColumnOrderings(column));
}

class $$CustomerDetailsTableAnnotationComposer
    extends Composer<_$AppDatabase, $CustomerDetailsTable> {
  $$CustomerDetailsTableAnnotationComposer({
    required super.$db,
    required super.$table,
    super.joinBuilder,
    super.$addJoinBuilderToRootComposer,
    super.$removeJoinBuilderFromRootComposer,
  });
  GeneratedColumn<String> get customerId => $composableBuilder(
      column: $table.customerId, builder: (column) => column);

  GeneratedColumn<String> get code =>
      $composableBuilder(column: $table.code, builder: (column) => column);

  GeneratedColumn<bool> get isVatRegistered => $composableBuilder(
      column: $table.isVatRegistered, builder: (column) => column);

  GeneratedColumn<String> get businessName => $composableBuilder(
      column: $table.businessName, builder: (column) => column);
}

class $$CustomerDetailsTableTableManager extends RootTableManager<
    _$AppDatabase,
    $CustomerDetailsTable,
    CustomerDetailRow,
    $$CustomerDetailsTableFilterComposer,
    $$CustomerDetailsTableOrderingComposer,
    $$CustomerDetailsTableAnnotationComposer,
    $$CustomerDetailsTableCreateCompanionBuilder,
    $$CustomerDetailsTableUpdateCompanionBuilder,
    (
      CustomerDetailRow,
      BaseReferences<_$AppDatabase, $CustomerDetailsTable, CustomerDetailRow>
    ),
    CustomerDetailRow,
    PrefetchHooks Function()> {
  $$CustomerDetailsTableTableManager(
      _$AppDatabase db, $CustomerDetailsTable table)
      : super(TableManagerState(
          db: db,
          table: table,
          createFilteringComposer: () =>
              $$CustomerDetailsTableFilterComposer($db: db, $table: table),
          createOrderingComposer: () =>
              $$CustomerDetailsTableOrderingComposer($db: db, $table: table),
          createComputedFieldComposer: () =>
              $$CustomerDetailsTableAnnotationComposer($db: db, $table: table),
          updateCompanionCallback: ({
            Value<String> customerId = const Value.absent(),
            Value<String?> code = const Value.absent(),
            Value<bool> isVatRegistered = const Value.absent(),
            Value<String?> businessName = const Value.absent(),
            Value<int> rowid = const Value.absent(),
          }) =>
              CustomerDetailsCompanion(
            customerId: customerId,
            code: code,
            isVatRegistered: isVatRegistered,
            businessName: businessName,
            rowid: rowid,
          ),
          createCompanionCallback: ({
            required String customerId,
            Value<String?> code = const Value.absent(),
            Value<bool> isVatRegistered = const Value.absent(),
            Value<String?> businessName = const Value.absent(),
            Value<int> rowid = const Value.absent(),
          }) =>
              CustomerDetailsCompanion.insert(
            customerId: customerId,
            code: code,
            isVatRegistered: isVatRegistered,
            businessName: businessName,
            rowid: rowid,
          ),
          withReferenceMapper: (p0) => p0
              .map((e) => (e.readTable(table), BaseReferences(db, table, e)))
              .toList(),
          prefetchHooksCallback: null,
        ));
}

typedef $$CustomerDetailsTableProcessedTableManager = ProcessedTableManager<
    _$AppDatabase,
    $CustomerDetailsTable,
    CustomerDetailRow,
    $$CustomerDetailsTableFilterComposer,
    $$CustomerDetailsTableOrderingComposer,
    $$CustomerDetailsTableAnnotationComposer,
    $$CustomerDetailsTableCreateCompanionBuilder,
    $$CustomerDetailsTableUpdateCompanionBuilder,
    (
      CustomerDetailRow,
      BaseReferences<_$AppDatabase, $CustomerDetailsTable, CustomerDetailRow>
    ),
    CustomerDetailRow,
    PrefetchHooks Function()>;
typedef $$InvoiceSellersTableCreateCompanionBuilder = InvoiceSellersCompanion
    Function({
  required String invoiceId,
  required String sellerName,
  required String sellerPan,
  Value<int> rowid,
});
typedef $$InvoiceSellersTableUpdateCompanionBuilder = InvoiceSellersCompanion
    Function({
  Value<String> invoiceId,
  Value<String> sellerName,
  Value<String> sellerPan,
  Value<int> rowid,
});

class $$InvoiceSellersTableFilterComposer
    extends Composer<_$AppDatabase, $InvoiceSellersTable> {
  $$InvoiceSellersTableFilterComposer({
    required super.$db,
    required super.$table,
    super.joinBuilder,
    super.$addJoinBuilderToRootComposer,
    super.$removeJoinBuilderFromRootComposer,
  });
  ColumnFilters<String> get invoiceId => $composableBuilder(
      column: $table.invoiceId, builder: (column) => ColumnFilters(column));

  ColumnFilters<String> get sellerName => $composableBuilder(
      column: $table.sellerName, builder: (column) => ColumnFilters(column));

  ColumnFilters<String> get sellerPan => $composableBuilder(
      column: $table.sellerPan, builder: (column) => ColumnFilters(column));
}

class $$InvoiceSellersTableOrderingComposer
    extends Composer<_$AppDatabase, $InvoiceSellersTable> {
  $$InvoiceSellersTableOrderingComposer({
    required super.$db,
    required super.$table,
    super.joinBuilder,
    super.$addJoinBuilderToRootComposer,
    super.$removeJoinBuilderFromRootComposer,
  });
  ColumnOrderings<String> get invoiceId => $composableBuilder(
      column: $table.invoiceId, builder: (column) => ColumnOrderings(column));

  ColumnOrderings<String> get sellerName => $composableBuilder(
      column: $table.sellerName, builder: (column) => ColumnOrderings(column));

  ColumnOrderings<String> get sellerPan => $composableBuilder(
      column: $table.sellerPan, builder: (column) => ColumnOrderings(column));
}

class $$InvoiceSellersTableAnnotationComposer
    extends Composer<_$AppDatabase, $InvoiceSellersTable> {
  $$InvoiceSellersTableAnnotationComposer({
    required super.$db,
    required super.$table,
    super.joinBuilder,
    super.$addJoinBuilderToRootComposer,
    super.$removeJoinBuilderFromRootComposer,
  });
  GeneratedColumn<String> get invoiceId =>
      $composableBuilder(column: $table.invoiceId, builder: (column) => column);

  GeneratedColumn<String> get sellerName => $composableBuilder(
      column: $table.sellerName, builder: (column) => column);

  GeneratedColumn<String> get sellerPan =>
      $composableBuilder(column: $table.sellerPan, builder: (column) => column);
}

class $$InvoiceSellersTableTableManager extends RootTableManager<
    _$AppDatabase,
    $InvoiceSellersTable,
    InvoiceSellerRow,
    $$InvoiceSellersTableFilterComposer,
    $$InvoiceSellersTableOrderingComposer,
    $$InvoiceSellersTableAnnotationComposer,
    $$InvoiceSellersTableCreateCompanionBuilder,
    $$InvoiceSellersTableUpdateCompanionBuilder,
    (
      InvoiceSellerRow,
      BaseReferences<_$AppDatabase, $InvoiceSellersTable, InvoiceSellerRow>
    ),
    InvoiceSellerRow,
    PrefetchHooks Function()> {
  $$InvoiceSellersTableTableManager(
      _$AppDatabase db, $InvoiceSellersTable table)
      : super(TableManagerState(
          db: db,
          table: table,
          createFilteringComposer: () =>
              $$InvoiceSellersTableFilterComposer($db: db, $table: table),
          createOrderingComposer: () =>
              $$InvoiceSellersTableOrderingComposer($db: db, $table: table),
          createComputedFieldComposer: () =>
              $$InvoiceSellersTableAnnotationComposer($db: db, $table: table),
          updateCompanionCallback: ({
            Value<String> invoiceId = const Value.absent(),
            Value<String> sellerName = const Value.absent(),
            Value<String> sellerPan = const Value.absent(),
            Value<int> rowid = const Value.absent(),
          }) =>
              InvoiceSellersCompanion(
            invoiceId: invoiceId,
            sellerName: sellerName,
            sellerPan: sellerPan,
            rowid: rowid,
          ),
          createCompanionCallback: ({
            required String invoiceId,
            required String sellerName,
            required String sellerPan,
            Value<int> rowid = const Value.absent(),
          }) =>
              InvoiceSellersCompanion.insert(
            invoiceId: invoiceId,
            sellerName: sellerName,
            sellerPan: sellerPan,
            rowid: rowid,
          ),
          withReferenceMapper: (p0) => p0
              .map((e) => (e.readTable(table), BaseReferences(db, table, e)))
              .toList(),
          prefetchHooksCallback: null,
        ));
}

typedef $$InvoiceSellersTableProcessedTableManager = ProcessedTableManager<
    _$AppDatabase,
    $InvoiceSellersTable,
    InvoiceSellerRow,
    $$InvoiceSellersTableFilterComposer,
    $$InvoiceSellersTableOrderingComposer,
    $$InvoiceSellersTableAnnotationComposer,
    $$InvoiceSellersTableCreateCompanionBuilder,
    $$InvoiceSellersTableUpdateCompanionBuilder,
    (
      InvoiceSellerRow,
      BaseReferences<_$AppDatabase, $InvoiceSellersTable, InvoiceSellerRow>
    ),
    InvoiceSellerRow,
    PrefetchHooks Function()>;

class $AppDatabaseManager {
  final _$AppDatabase _db;
  $AppDatabaseManager(this._db);
  $$AccountsTableTableManager get accounts =>
      $$AccountsTableTableManager(_db, _db.accounts);
  $$JournalEntriesTableTableManager get journalEntries =>
      $$JournalEntriesTableTableManager(_db, _db.journalEntries);
  $$JournalLinesTableTableManager get journalLines =>
      $$JournalLinesTableTableManager(_db, _db.journalLines);
  $$DocumentSequencesTableTableManager get documentSequences =>
      $$DocumentSequencesTableTableManager(_db, _db.documentSequences);
  $$CustomersTableTableManager get customers =>
      $$CustomersTableTableManager(_db, _db.customers);
  $$InvoicesTableTableManager get invoices =>
      $$InvoicesTableTableManager(_db, _db.invoices);
  $$InvoiceLinesTableTableManager get invoiceLines =>
      $$InvoiceLinesTableTableManager(_db, _db.invoiceLines);
  $$PaymentsTableTableManager get payments =>
      $$PaymentsTableTableManager(_db, _db.payments);
  $$CreditNotesTableTableManager get creditNotes =>
      $$CreditNotesTableTableManager(_db, _db.creditNotes);
  $$CreditNoteLinesTableTableManager get creditNoteLines =>
      $$CreditNoteLinesTableTableManager(_db, _db.creditNoteLines);
  $$ProductsTableTableManager get products =>
      $$ProductsTableTableManager(_db, _db.products);
  $$InventoryMovementsTableTableManager get inventoryMovements =>
      $$InventoryMovementsTableTableManager(_db, _db.inventoryMovements);
  $$CustomerDetailsTableTableManager get customerDetails =>
      $$CustomerDetailsTableTableManager(_db, _db.customerDetails);
  $$InvoiceSellersTableTableManager get invoiceSellers =>
      $$InvoiceSellersTableTableManager(_db, _db.invoiceSellers);
}
