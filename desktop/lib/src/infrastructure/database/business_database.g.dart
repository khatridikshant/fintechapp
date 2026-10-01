// GENERATED CODE - DO NOT MODIFY BY HAND

part of 'business_database.dart';

// ignore_for_file: type=lint
class $BusinessProfilesTable extends BusinessProfiles
    with TableInfo<$BusinessProfilesTable, BusinessProfileRow> {
  @override
  final GeneratedDatabase attachedDatabase;
  final String? _alias;
  $BusinessProfilesTable(this.attachedDatabase, [this._alias]);
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
  static const VerificationMeta _panMeta = const VerificationMeta('pan');
  @override
  late final GeneratedColumn<String> pan = GeneratedColumn<String>(
      'pan', aliasedName, true,
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
  static const VerificationMeta _addressMeta =
      const VerificationMeta('address');
  @override
  late final GeneratedColumn<String> address = GeneratedColumn<String>(
      'address', aliasedName, true,
      type: DriftSqlType.string, requiredDuringInsert: false);
  static const VerificationMeta _phoneMeta = const VerificationMeta('phone');
  @override
  late final GeneratedColumn<String> phone = GeneratedColumn<String>(
      'phone', aliasedName, true,
      type: DriftSqlType.string, requiredDuringInsert: false);
  static const VerificationMeta _emailMeta = const VerificationMeta('email');
  @override
  late final GeneratedColumn<String> email = GeneratedColumn<String>(
      'email', aliasedName, true,
      type: DriftSqlType.string, requiredDuringInsert: false);
  static const VerificationMeta _bankDetailsMeta =
      const VerificationMeta('bankDetails');
  @override
  late final GeneratedColumn<String> bankDetails = GeneratedColumn<String>(
      'bank_details', aliasedName, true,
      type: DriftSqlType.string, requiredDuringInsert: false);
  @override
  List<GeneratedColumn> get $columns =>
      [id, name, pan, isVatRegistered, address, phone, email, bankDetails];
  @override
  String get aliasedName => _alias ?? actualTableName;
  @override
  String get actualTableName => $name;
  static const String $name = 'business_profiles';
  @override
  VerificationContext validateIntegrity(Insertable<BusinessProfileRow> instance,
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
    if (data.containsKey('pan')) {
      context.handle(
          _panMeta, pan.isAcceptableOrUnknown(data['pan']!, _panMeta));
    }
    if (data.containsKey('is_vat_registered')) {
      context.handle(
          _isVatRegisteredMeta,
          isVatRegistered.isAcceptableOrUnknown(
              data['is_vat_registered']!, _isVatRegisteredMeta));
    }
    if (data.containsKey('address')) {
      context.handle(_addressMeta,
          address.isAcceptableOrUnknown(data['address']!, _addressMeta));
    }
    if (data.containsKey('phone')) {
      context.handle(
          _phoneMeta, phone.isAcceptableOrUnknown(data['phone']!, _phoneMeta));
    }
    if (data.containsKey('email')) {
      context.handle(
          _emailMeta, email.isAcceptableOrUnknown(data['email']!, _emailMeta));
    }
    if (data.containsKey('bank_details')) {
      context.handle(
          _bankDetailsMeta,
          bankDetails.isAcceptableOrUnknown(
              data['bank_details']!, _bankDetailsMeta));
    }
    return context;
  }

  @override
  Set<GeneratedColumn> get $primaryKey => {id};
  @override
  BusinessProfileRow map(Map<String, dynamic> data, {String? tablePrefix}) {
    final effectivePrefix = tablePrefix != null ? '$tablePrefix.' : '';
    return BusinessProfileRow(
      id: attachedDatabase.typeMapping
          .read(DriftSqlType.string, data['${effectivePrefix}id'])!,
      name: attachedDatabase.typeMapping
          .read(DriftSqlType.string, data['${effectivePrefix}name'])!,
      pan: attachedDatabase.typeMapping
          .read(DriftSqlType.string, data['${effectivePrefix}pan']),
      isVatRegistered: attachedDatabase.typeMapping.read(
          DriftSqlType.bool, data['${effectivePrefix}is_vat_registered'])!,
      address: attachedDatabase.typeMapping
          .read(DriftSqlType.string, data['${effectivePrefix}address']),
      phone: attachedDatabase.typeMapping
          .read(DriftSqlType.string, data['${effectivePrefix}phone']),
      email: attachedDatabase.typeMapping
          .read(DriftSqlType.string, data['${effectivePrefix}email']),
      bankDetails: attachedDatabase.typeMapping
          .read(DriftSqlType.string, data['${effectivePrefix}bank_details']),
    );
  }

  @override
  $BusinessProfilesTable createAlias(String alias) {
    return $BusinessProfilesTable(attachedDatabase, alias);
  }
}

class BusinessProfileRow extends DataClass
    implements Insertable<BusinessProfileRow> {
  /// Always `primary` for V1: one row, by design.
  final String id;

  /// The registered name, printed as the supplier on every invoice.
  final String name;

  /// The tax identity, as nine digits, or null.
  final String? pan;

  /// Whether VAT registration is active. Stated by the owner, never inferred:
  /// whether registration is *compulsory* depends on a turnover threshold the
  /// Finance Act resets every year. See `PROGRESS.md` section 5.1.
  final bool isVatRegistered;
  final String? address;
  final String? phone;
  final String? email;
  final String? bankDetails;
  const BusinessProfileRow(
      {required this.id,
      required this.name,
      this.pan,
      required this.isVatRegistered,
      this.address,
      this.phone,
      this.email,
      this.bankDetails});
  @override
  Map<String, Expression> toColumns(bool nullToAbsent) {
    final map = <String, Expression>{};
    map['id'] = Variable<String>(id);
    map['name'] = Variable<String>(name);
    if (!nullToAbsent || pan != null) {
      map['pan'] = Variable<String>(pan);
    }
    map['is_vat_registered'] = Variable<bool>(isVatRegistered);
    if (!nullToAbsent || address != null) {
      map['address'] = Variable<String>(address);
    }
    if (!nullToAbsent || phone != null) {
      map['phone'] = Variable<String>(phone);
    }
    if (!nullToAbsent || email != null) {
      map['email'] = Variable<String>(email);
    }
    if (!nullToAbsent || bankDetails != null) {
      map['bank_details'] = Variable<String>(bankDetails);
    }
    return map;
  }

  BusinessProfilesCompanion toCompanion(bool nullToAbsent) {
    return BusinessProfilesCompanion(
      id: Value(id),
      name: Value(name),
      pan: pan == null && nullToAbsent ? const Value.absent() : Value(pan),
      isVatRegistered: Value(isVatRegistered),
      address: address == null && nullToAbsent
          ? const Value.absent()
          : Value(address),
      phone:
          phone == null && nullToAbsent ? const Value.absent() : Value(phone),
      email:
          email == null && nullToAbsent ? const Value.absent() : Value(email),
      bankDetails: bankDetails == null && nullToAbsent
          ? const Value.absent()
          : Value(bankDetails),
    );
  }

  factory BusinessProfileRow.fromJson(Map<String, dynamic> json,
      {ValueSerializer? serializer}) {
    serializer ??= driftRuntimeOptions.defaultSerializer;
    return BusinessProfileRow(
      id: serializer.fromJson<String>(json['id']),
      name: serializer.fromJson<String>(json['name']),
      pan: serializer.fromJson<String?>(json['pan']),
      isVatRegistered: serializer.fromJson<bool>(json['isVatRegistered']),
      address: serializer.fromJson<String?>(json['address']),
      phone: serializer.fromJson<String?>(json['phone']),
      email: serializer.fromJson<String?>(json['email']),
      bankDetails: serializer.fromJson<String?>(json['bankDetails']),
    );
  }
  @override
  Map<String, dynamic> toJson({ValueSerializer? serializer}) {
    serializer ??= driftRuntimeOptions.defaultSerializer;
    return <String, dynamic>{
      'id': serializer.toJson<String>(id),
      'name': serializer.toJson<String>(name),
      'pan': serializer.toJson<String?>(pan),
      'isVatRegistered': serializer.toJson<bool>(isVatRegistered),
      'address': serializer.toJson<String?>(address),
      'phone': serializer.toJson<String?>(phone),
      'email': serializer.toJson<String?>(email),
      'bankDetails': serializer.toJson<String?>(bankDetails),
    };
  }

  BusinessProfileRow copyWith(
          {String? id,
          String? name,
          Value<String?> pan = const Value.absent(),
          bool? isVatRegistered,
          Value<String?> address = const Value.absent(),
          Value<String?> phone = const Value.absent(),
          Value<String?> email = const Value.absent(),
          Value<String?> bankDetails = const Value.absent()}) =>
      BusinessProfileRow(
        id: id ?? this.id,
        name: name ?? this.name,
        pan: pan.present ? pan.value : this.pan,
        isVatRegistered: isVatRegistered ?? this.isVatRegistered,
        address: address.present ? address.value : this.address,
        phone: phone.present ? phone.value : this.phone,
        email: email.present ? email.value : this.email,
        bankDetails: bankDetails.present ? bankDetails.value : this.bankDetails,
      );
  BusinessProfileRow copyWithCompanion(BusinessProfilesCompanion data) {
    return BusinessProfileRow(
      id: data.id.present ? data.id.value : this.id,
      name: data.name.present ? data.name.value : this.name,
      pan: data.pan.present ? data.pan.value : this.pan,
      isVatRegistered: data.isVatRegistered.present
          ? data.isVatRegistered.value
          : this.isVatRegistered,
      address: data.address.present ? data.address.value : this.address,
      phone: data.phone.present ? data.phone.value : this.phone,
      email: data.email.present ? data.email.value : this.email,
      bankDetails:
          data.bankDetails.present ? data.bankDetails.value : this.bankDetails,
    );
  }

  @override
  String toString() {
    return (StringBuffer('BusinessProfileRow(')
          ..write('id: $id, ')
          ..write('name: $name, ')
          ..write('pan: $pan, ')
          ..write('isVatRegistered: $isVatRegistered, ')
          ..write('address: $address, ')
          ..write('phone: $phone, ')
          ..write('email: $email, ')
          ..write('bankDetails: $bankDetails')
          ..write(')'))
        .toString();
  }

  @override
  int get hashCode => Object.hash(
      id, name, pan, isVatRegistered, address, phone, email, bankDetails);
  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      (other is BusinessProfileRow &&
          other.id == this.id &&
          other.name == this.name &&
          other.pan == this.pan &&
          other.isVatRegistered == this.isVatRegistered &&
          other.address == this.address &&
          other.phone == this.phone &&
          other.email == this.email &&
          other.bankDetails == this.bankDetails);
}

class BusinessProfilesCompanion extends UpdateCompanion<BusinessProfileRow> {
  final Value<String> id;
  final Value<String> name;
  final Value<String?> pan;
  final Value<bool> isVatRegistered;
  final Value<String?> address;
  final Value<String?> phone;
  final Value<String?> email;
  final Value<String?> bankDetails;
  final Value<int> rowid;
  const BusinessProfilesCompanion({
    this.id = const Value.absent(),
    this.name = const Value.absent(),
    this.pan = const Value.absent(),
    this.isVatRegistered = const Value.absent(),
    this.address = const Value.absent(),
    this.phone = const Value.absent(),
    this.email = const Value.absent(),
    this.bankDetails = const Value.absent(),
    this.rowid = const Value.absent(),
  });
  BusinessProfilesCompanion.insert({
    required String id,
    required String name,
    this.pan = const Value.absent(),
    this.isVatRegistered = const Value.absent(),
    this.address = const Value.absent(),
    this.phone = const Value.absent(),
    this.email = const Value.absent(),
    this.bankDetails = const Value.absent(),
    this.rowid = const Value.absent(),
  })  : id = Value(id),
        name = Value(name);
  static Insertable<BusinessProfileRow> custom({
    Expression<String>? id,
    Expression<String>? name,
    Expression<String>? pan,
    Expression<bool>? isVatRegistered,
    Expression<String>? address,
    Expression<String>? phone,
    Expression<String>? email,
    Expression<String>? bankDetails,
    Expression<int>? rowid,
  }) {
    return RawValuesInsertable({
      if (id != null) 'id': id,
      if (name != null) 'name': name,
      if (pan != null) 'pan': pan,
      if (isVatRegistered != null) 'is_vat_registered': isVatRegistered,
      if (address != null) 'address': address,
      if (phone != null) 'phone': phone,
      if (email != null) 'email': email,
      if (bankDetails != null) 'bank_details': bankDetails,
      if (rowid != null) 'rowid': rowid,
    });
  }

  BusinessProfilesCompanion copyWith(
      {Value<String>? id,
      Value<String>? name,
      Value<String?>? pan,
      Value<bool>? isVatRegistered,
      Value<String?>? address,
      Value<String?>? phone,
      Value<String?>? email,
      Value<String?>? bankDetails,
      Value<int>? rowid}) {
    return BusinessProfilesCompanion(
      id: id ?? this.id,
      name: name ?? this.name,
      pan: pan ?? this.pan,
      isVatRegistered: isVatRegistered ?? this.isVatRegistered,
      address: address ?? this.address,
      phone: phone ?? this.phone,
      email: email ?? this.email,
      bankDetails: bankDetails ?? this.bankDetails,
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
    if (pan.present) {
      map['pan'] = Variable<String>(pan.value);
    }
    if (isVatRegistered.present) {
      map['is_vat_registered'] = Variable<bool>(isVatRegistered.value);
    }
    if (address.present) {
      map['address'] = Variable<String>(address.value);
    }
    if (phone.present) {
      map['phone'] = Variable<String>(phone.value);
    }
    if (email.present) {
      map['email'] = Variable<String>(email.value);
    }
    if (bankDetails.present) {
      map['bank_details'] = Variable<String>(bankDetails.value);
    }
    if (rowid.present) {
      map['rowid'] = Variable<int>(rowid.value);
    }
    return map;
  }

  @override
  String toString() {
    return (StringBuffer('BusinessProfilesCompanion(')
          ..write('id: $id, ')
          ..write('name: $name, ')
          ..write('pan: $pan, ')
          ..write('isVatRegistered: $isVatRegistered, ')
          ..write('address: $address, ')
          ..write('phone: $phone, ')
          ..write('email: $email, ')
          ..write('bankDetails: $bankDetails, ')
          ..write('rowid: $rowid')
          ..write(')'))
        .toString();
  }
}

abstract class _$BusinessDatabase extends GeneratedDatabase {
  _$BusinessDatabase(QueryExecutor e) : super(e);
  $BusinessDatabaseManager get managers => $BusinessDatabaseManager(this);
  late final $BusinessProfilesTable businessProfiles =
      $BusinessProfilesTable(this);
  @override
  Iterable<TableInfo<Table, Object?>> get allTables =>
      allSchemaEntities.whereType<TableInfo<Table, Object?>>();
  @override
  List<DatabaseSchemaEntity> get allSchemaEntities => [businessProfiles];
}

typedef $$BusinessProfilesTableCreateCompanionBuilder
    = BusinessProfilesCompanion Function({
  required String id,
  required String name,
  Value<String?> pan,
  Value<bool> isVatRegistered,
  Value<String?> address,
  Value<String?> phone,
  Value<String?> email,
  Value<String?> bankDetails,
  Value<int> rowid,
});
typedef $$BusinessProfilesTableUpdateCompanionBuilder
    = BusinessProfilesCompanion Function({
  Value<String> id,
  Value<String> name,
  Value<String?> pan,
  Value<bool> isVatRegistered,
  Value<String?> address,
  Value<String?> phone,
  Value<String?> email,
  Value<String?> bankDetails,
  Value<int> rowid,
});

class $$BusinessProfilesTableFilterComposer
    extends Composer<_$BusinessDatabase, $BusinessProfilesTable> {
  $$BusinessProfilesTableFilterComposer({
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

  ColumnFilters<String> get pan => $composableBuilder(
      column: $table.pan, builder: (column) => ColumnFilters(column));

  ColumnFilters<bool> get isVatRegistered => $composableBuilder(
      column: $table.isVatRegistered,
      builder: (column) => ColumnFilters(column));

  ColumnFilters<String> get address => $composableBuilder(
      column: $table.address, builder: (column) => ColumnFilters(column));

  ColumnFilters<String> get phone => $composableBuilder(
      column: $table.phone, builder: (column) => ColumnFilters(column));

  ColumnFilters<String> get email => $composableBuilder(
      column: $table.email, builder: (column) => ColumnFilters(column));

  ColumnFilters<String> get bankDetails => $composableBuilder(
      column: $table.bankDetails, builder: (column) => ColumnFilters(column));
}

class $$BusinessProfilesTableOrderingComposer
    extends Composer<_$BusinessDatabase, $BusinessProfilesTable> {
  $$BusinessProfilesTableOrderingComposer({
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

  ColumnOrderings<String> get pan => $composableBuilder(
      column: $table.pan, builder: (column) => ColumnOrderings(column));

  ColumnOrderings<bool> get isVatRegistered => $composableBuilder(
      column: $table.isVatRegistered,
      builder: (column) => ColumnOrderings(column));

  ColumnOrderings<String> get address => $composableBuilder(
      column: $table.address, builder: (column) => ColumnOrderings(column));

  ColumnOrderings<String> get phone => $composableBuilder(
      column: $table.phone, builder: (column) => ColumnOrderings(column));

  ColumnOrderings<String> get email => $composableBuilder(
      column: $table.email, builder: (column) => ColumnOrderings(column));

  ColumnOrderings<String> get bankDetails => $composableBuilder(
      column: $table.bankDetails, builder: (column) => ColumnOrderings(column));
}

class $$BusinessProfilesTableAnnotationComposer
    extends Composer<_$BusinessDatabase, $BusinessProfilesTable> {
  $$BusinessProfilesTableAnnotationComposer({
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

  GeneratedColumn<String> get pan =>
      $composableBuilder(column: $table.pan, builder: (column) => column);

  GeneratedColumn<bool> get isVatRegistered => $composableBuilder(
      column: $table.isVatRegistered, builder: (column) => column);

  GeneratedColumn<String> get address =>
      $composableBuilder(column: $table.address, builder: (column) => column);

  GeneratedColumn<String> get phone =>
      $composableBuilder(column: $table.phone, builder: (column) => column);

  GeneratedColumn<String> get email =>
      $composableBuilder(column: $table.email, builder: (column) => column);

  GeneratedColumn<String> get bankDetails => $composableBuilder(
      column: $table.bankDetails, builder: (column) => column);
}

class $$BusinessProfilesTableTableManager extends RootTableManager<
    _$BusinessDatabase,
    $BusinessProfilesTable,
    BusinessProfileRow,
    $$BusinessProfilesTableFilterComposer,
    $$BusinessProfilesTableOrderingComposer,
    $$BusinessProfilesTableAnnotationComposer,
    $$BusinessProfilesTableCreateCompanionBuilder,
    $$BusinessProfilesTableUpdateCompanionBuilder,
    (
      BusinessProfileRow,
      BaseReferences<_$BusinessDatabase, $BusinessProfilesTable,
          BusinessProfileRow>
    ),
    BusinessProfileRow,
    PrefetchHooks Function()> {
  $$BusinessProfilesTableTableManager(
      _$BusinessDatabase db, $BusinessProfilesTable table)
      : super(TableManagerState(
          db: db,
          table: table,
          createFilteringComposer: () =>
              $$BusinessProfilesTableFilterComposer($db: db, $table: table),
          createOrderingComposer: () =>
              $$BusinessProfilesTableOrderingComposer($db: db, $table: table),
          createComputedFieldComposer: () =>
              $$BusinessProfilesTableAnnotationComposer($db: db, $table: table),
          updateCompanionCallback: ({
            Value<String> id = const Value.absent(),
            Value<String> name = const Value.absent(),
            Value<String?> pan = const Value.absent(),
            Value<bool> isVatRegistered = const Value.absent(),
            Value<String?> address = const Value.absent(),
            Value<String?> phone = const Value.absent(),
            Value<String?> email = const Value.absent(),
            Value<String?> bankDetails = const Value.absent(),
            Value<int> rowid = const Value.absent(),
          }) =>
              BusinessProfilesCompanion(
            id: id,
            name: name,
            pan: pan,
            isVatRegistered: isVatRegistered,
            address: address,
            phone: phone,
            email: email,
            bankDetails: bankDetails,
            rowid: rowid,
          ),
          createCompanionCallback: ({
            required String id,
            required String name,
            Value<String?> pan = const Value.absent(),
            Value<bool> isVatRegistered = const Value.absent(),
            Value<String?> address = const Value.absent(),
            Value<String?> phone = const Value.absent(),
            Value<String?> email = const Value.absent(),
            Value<String?> bankDetails = const Value.absent(),
            Value<int> rowid = const Value.absent(),
          }) =>
              BusinessProfilesCompanion.insert(
            id: id,
            name: name,
            pan: pan,
            isVatRegistered: isVatRegistered,
            address: address,
            phone: phone,
            email: email,
            bankDetails: bankDetails,
            rowid: rowid,
          ),
          withReferenceMapper: (p0) => p0
              .map((e) => (e.readTable(table), BaseReferences(db, table, e)))
              .toList(),
          prefetchHooksCallback: null,
        ));
}

typedef $$BusinessProfilesTableProcessedTableManager = ProcessedTableManager<
    _$BusinessDatabase,
    $BusinessProfilesTable,
    BusinessProfileRow,
    $$BusinessProfilesTableFilterComposer,
    $$BusinessProfilesTableOrderingComposer,
    $$BusinessProfilesTableAnnotationComposer,
    $$BusinessProfilesTableCreateCompanionBuilder,
    $$BusinessProfilesTableUpdateCompanionBuilder,
    (
      BusinessProfileRow,
      BaseReferences<_$BusinessDatabase, $BusinessProfilesTable,
          BusinessProfileRow>
    ),
    BusinessProfileRow,
    PrefetchHooks Function()>;

class $BusinessDatabaseManager {
  final _$BusinessDatabase _db;
  $BusinessDatabaseManager(this._db);
  $$BusinessProfilesTableTableManager get businessProfiles =>
      $$BusinessProfilesTableTableManager(_db, _db.businessProfiles);
}
