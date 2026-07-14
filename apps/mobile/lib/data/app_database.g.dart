// GENERATED CODE - DO NOT MODIFY BY HAND

part of 'app_database.dart';

// ignore_for_file: type=lint
class $CustomersTable extends Customers
    with TableInfo<$CustomersTable, Customer> {
  @override
  final GeneratedDatabase attachedDatabase;
  final String? _alias;
  $CustomersTable(this.attachedDatabase, [this._alias]);
  static const VerificationMeta _idMeta = const VerificationMeta('id');
  @override
  late final GeneratedColumn<String> id = GeneratedColumn<String>(
    'id',
    aliasedName,
    false,
    type: DriftSqlType.string,
    requiredDuringInsert: true,
  );
  static const VerificationMeta _nameMeta = const VerificationMeta('name');
  @override
  late final GeneratedColumn<String> name = GeneratedColumn<String>(
    'name',
    aliasedName,
    false,
    type: DriftSqlType.string,
    requiredDuringInsert: true,
  );
  static const VerificationMeta _noteMeta = const VerificationMeta('note');
  @override
  late final GeneratedColumn<String> note = GeneratedColumn<String>(
    'note',
    aliasedName,
    true,
    type: DriftSqlType.string,
    requiredDuringInsert: false,
  );
  static const VerificationMeta _balanceKurusMeta = const VerificationMeta(
    'balanceKurus',
  );
  @override
  late final GeneratedColumn<int> balanceKurus = GeneratedColumn<int>(
    'balance_kurus',
    aliasedName,
    false,
    type: DriftSqlType.int,
    requiredDuringInsert: false,
    defaultValue: const Constant(0),
  );
  static const VerificationMeta _updatedOccurredAtMeta = const VerificationMeta(
    'updatedOccurredAt',
  );
  @override
  late final GeneratedColumn<String> updatedOccurredAt =
      GeneratedColumn<String>(
        'updated_occurred_at',
        aliasedName,
        false,
        type: DriftSqlType.string,
        requiredDuringInsert: true,
      );
  static const VerificationMeta _updatedDeviceIdMeta = const VerificationMeta(
    'updatedDeviceId',
  );
  @override
  late final GeneratedColumn<String> updatedDeviceId = GeneratedColumn<String>(
    'updated_device_id',
    aliasedName,
    true,
    type: DriftSqlType.string,
    requiredDuringInsert: false,
  );
  static const VerificationMeta _deletedAtMeta = const VerificationMeta(
    'deletedAt',
  );
  @override
  late final GeneratedColumn<String> deletedAt = GeneratedColumn<String>(
    'deleted_at',
    aliasedName,
    true,
    type: DriftSqlType.string,
    requiredDuringInsert: false,
  );
  @override
  List<GeneratedColumn> get $columns => [
    id,
    name,
    note,
    balanceKurus,
    updatedOccurredAt,
    updatedDeviceId,
    deletedAt,
  ];
  @override
  String get aliasedName => _alias ?? actualTableName;
  @override
  String get actualTableName => $name;
  static const String $name = 'customers';
  @override
  VerificationContext validateIntegrity(
    Insertable<Customer> instance, {
    bool isInserting = false,
  }) {
    final context = VerificationContext();
    final data = instance.toColumns(true);
    if (data.containsKey('id')) {
      context.handle(_idMeta, id.isAcceptableOrUnknown(data['id']!, _idMeta));
    } else if (isInserting) {
      context.missing(_idMeta);
    }
    if (data.containsKey('name')) {
      context.handle(
        _nameMeta,
        name.isAcceptableOrUnknown(data['name']!, _nameMeta),
      );
    } else if (isInserting) {
      context.missing(_nameMeta);
    }
    if (data.containsKey('note')) {
      context.handle(
        _noteMeta,
        note.isAcceptableOrUnknown(data['note']!, _noteMeta),
      );
    }
    if (data.containsKey('balance_kurus')) {
      context.handle(
        _balanceKurusMeta,
        balanceKurus.isAcceptableOrUnknown(
          data['balance_kurus']!,
          _balanceKurusMeta,
        ),
      );
    }
    if (data.containsKey('updated_occurred_at')) {
      context.handle(
        _updatedOccurredAtMeta,
        updatedOccurredAt.isAcceptableOrUnknown(
          data['updated_occurred_at']!,
          _updatedOccurredAtMeta,
        ),
      );
    } else if (isInserting) {
      context.missing(_updatedOccurredAtMeta);
    }
    if (data.containsKey('updated_device_id')) {
      context.handle(
        _updatedDeviceIdMeta,
        updatedDeviceId.isAcceptableOrUnknown(
          data['updated_device_id']!,
          _updatedDeviceIdMeta,
        ),
      );
    }
    if (data.containsKey('deleted_at')) {
      context.handle(
        _deletedAtMeta,
        deletedAt.isAcceptableOrUnknown(data['deleted_at']!, _deletedAtMeta),
      );
    }
    return context;
  }

  @override
  Set<GeneratedColumn> get $primaryKey => {id};
  @override
  Customer map(Map<String, dynamic> data, {String? tablePrefix}) {
    final effectivePrefix = tablePrefix != null ? '$tablePrefix.' : '';
    return Customer(
      id: attachedDatabase.typeMapping.read(
        DriftSqlType.string,
        data['${effectivePrefix}id'],
      )!,
      name: attachedDatabase.typeMapping.read(
        DriftSqlType.string,
        data['${effectivePrefix}name'],
      )!,
      note: attachedDatabase.typeMapping.read(
        DriftSqlType.string,
        data['${effectivePrefix}note'],
      ),
      balanceKurus: attachedDatabase.typeMapping.read(
        DriftSqlType.int,
        data['${effectivePrefix}balance_kurus'],
      )!,
      updatedOccurredAt: attachedDatabase.typeMapping.read(
        DriftSqlType.string,
        data['${effectivePrefix}updated_occurred_at'],
      )!,
      updatedDeviceId: attachedDatabase.typeMapping.read(
        DriftSqlType.string,
        data['${effectivePrefix}updated_device_id'],
      ),
      deletedAt: attachedDatabase.typeMapping.read(
        DriftSqlType.string,
        data['${effectivePrefix}deleted_at'],
      ),
    );
  }

  @override
  $CustomersTable createAlias(String alias) {
    return $CustomersTable(attachedDatabase, alias);
  }
}

class Customer extends DataClass implements Insertable<Customer> {
  final String id;
  final String name;
  final String? note;

  /// OKUMA-MODELİ ÖNBELLEĞİ (DECISIONS: kaynak defterdir). Native arayan-tanıma bunu tek satır okur.
  final int balanceKurus;
  final String updatedOccurredAt;
  final String? updatedDeviceId;
  final String? deletedAt;
  const Customer({
    required this.id,
    required this.name,
    this.note,
    required this.balanceKurus,
    required this.updatedOccurredAt,
    this.updatedDeviceId,
    this.deletedAt,
  });
  @override
  Map<String, Expression> toColumns(bool nullToAbsent) {
    final map = <String, Expression>{};
    map['id'] = Variable<String>(id);
    map['name'] = Variable<String>(name);
    if (!nullToAbsent || note != null) {
      map['note'] = Variable<String>(note);
    }
    map['balance_kurus'] = Variable<int>(balanceKurus);
    map['updated_occurred_at'] = Variable<String>(updatedOccurredAt);
    if (!nullToAbsent || updatedDeviceId != null) {
      map['updated_device_id'] = Variable<String>(updatedDeviceId);
    }
    if (!nullToAbsent || deletedAt != null) {
      map['deleted_at'] = Variable<String>(deletedAt);
    }
    return map;
  }

  CustomersCompanion toCompanion(bool nullToAbsent) {
    return CustomersCompanion(
      id: Value(id),
      name: Value(name),
      note: note == null && nullToAbsent ? const Value.absent() : Value(note),
      balanceKurus: Value(balanceKurus),
      updatedOccurredAt: Value(updatedOccurredAt),
      updatedDeviceId: updatedDeviceId == null && nullToAbsent
          ? const Value.absent()
          : Value(updatedDeviceId),
      deletedAt: deletedAt == null && nullToAbsent
          ? const Value.absent()
          : Value(deletedAt),
    );
  }

  factory Customer.fromJson(
    Map<String, dynamic> json, {
    ValueSerializer? serializer,
  }) {
    serializer ??= driftRuntimeOptions.defaultSerializer;
    return Customer(
      id: serializer.fromJson<String>(json['id']),
      name: serializer.fromJson<String>(json['name']),
      note: serializer.fromJson<String?>(json['note']),
      balanceKurus: serializer.fromJson<int>(json['balanceKurus']),
      updatedOccurredAt: serializer.fromJson<String>(json['updatedOccurredAt']),
      updatedDeviceId: serializer.fromJson<String?>(json['updatedDeviceId']),
      deletedAt: serializer.fromJson<String?>(json['deletedAt']),
    );
  }
  @override
  Map<String, dynamic> toJson({ValueSerializer? serializer}) {
    serializer ??= driftRuntimeOptions.defaultSerializer;
    return <String, dynamic>{
      'id': serializer.toJson<String>(id),
      'name': serializer.toJson<String>(name),
      'note': serializer.toJson<String?>(note),
      'balanceKurus': serializer.toJson<int>(balanceKurus),
      'updatedOccurredAt': serializer.toJson<String>(updatedOccurredAt),
      'updatedDeviceId': serializer.toJson<String?>(updatedDeviceId),
      'deletedAt': serializer.toJson<String?>(deletedAt),
    };
  }

  Customer copyWith({
    String? id,
    String? name,
    Value<String?> note = const Value.absent(),
    int? balanceKurus,
    String? updatedOccurredAt,
    Value<String?> updatedDeviceId = const Value.absent(),
    Value<String?> deletedAt = const Value.absent(),
  }) => Customer(
    id: id ?? this.id,
    name: name ?? this.name,
    note: note.present ? note.value : this.note,
    balanceKurus: balanceKurus ?? this.balanceKurus,
    updatedOccurredAt: updatedOccurredAt ?? this.updatedOccurredAt,
    updatedDeviceId: updatedDeviceId.present
        ? updatedDeviceId.value
        : this.updatedDeviceId,
    deletedAt: deletedAt.present ? deletedAt.value : this.deletedAt,
  );
  Customer copyWithCompanion(CustomersCompanion data) {
    return Customer(
      id: data.id.present ? data.id.value : this.id,
      name: data.name.present ? data.name.value : this.name,
      note: data.note.present ? data.note.value : this.note,
      balanceKurus: data.balanceKurus.present
          ? data.balanceKurus.value
          : this.balanceKurus,
      updatedOccurredAt: data.updatedOccurredAt.present
          ? data.updatedOccurredAt.value
          : this.updatedOccurredAt,
      updatedDeviceId: data.updatedDeviceId.present
          ? data.updatedDeviceId.value
          : this.updatedDeviceId,
      deletedAt: data.deletedAt.present ? data.deletedAt.value : this.deletedAt,
    );
  }

  @override
  String toString() {
    return (StringBuffer('Customer(')
          ..write('id: $id, ')
          ..write('name: $name, ')
          ..write('note: $note, ')
          ..write('balanceKurus: $balanceKurus, ')
          ..write('updatedOccurredAt: $updatedOccurredAt, ')
          ..write('updatedDeviceId: $updatedDeviceId, ')
          ..write('deletedAt: $deletedAt')
          ..write(')'))
        .toString();
  }

  @override
  int get hashCode => Object.hash(
    id,
    name,
    note,
    balanceKurus,
    updatedOccurredAt,
    updatedDeviceId,
    deletedAt,
  );
  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      (other is Customer &&
          other.id == this.id &&
          other.name == this.name &&
          other.note == this.note &&
          other.balanceKurus == this.balanceKurus &&
          other.updatedOccurredAt == this.updatedOccurredAt &&
          other.updatedDeviceId == this.updatedDeviceId &&
          other.deletedAt == this.deletedAt);
}

class CustomersCompanion extends UpdateCompanion<Customer> {
  final Value<String> id;
  final Value<String> name;
  final Value<String?> note;
  final Value<int> balanceKurus;
  final Value<String> updatedOccurredAt;
  final Value<String?> updatedDeviceId;
  final Value<String?> deletedAt;
  final Value<int> rowid;
  const CustomersCompanion({
    this.id = const Value.absent(),
    this.name = const Value.absent(),
    this.note = const Value.absent(),
    this.balanceKurus = const Value.absent(),
    this.updatedOccurredAt = const Value.absent(),
    this.updatedDeviceId = const Value.absent(),
    this.deletedAt = const Value.absent(),
    this.rowid = const Value.absent(),
  });
  CustomersCompanion.insert({
    required String id,
    required String name,
    this.note = const Value.absent(),
    this.balanceKurus = const Value.absent(),
    required String updatedOccurredAt,
    this.updatedDeviceId = const Value.absent(),
    this.deletedAt = const Value.absent(),
    this.rowid = const Value.absent(),
  }) : id = Value(id),
       name = Value(name),
       updatedOccurredAt = Value(updatedOccurredAt);
  static Insertable<Customer> custom({
    Expression<String>? id,
    Expression<String>? name,
    Expression<String>? note,
    Expression<int>? balanceKurus,
    Expression<String>? updatedOccurredAt,
    Expression<String>? updatedDeviceId,
    Expression<String>? deletedAt,
    Expression<int>? rowid,
  }) {
    return RawValuesInsertable({
      if (id != null) 'id': id,
      if (name != null) 'name': name,
      if (note != null) 'note': note,
      if (balanceKurus != null) 'balance_kurus': balanceKurus,
      if (updatedOccurredAt != null) 'updated_occurred_at': updatedOccurredAt,
      if (updatedDeviceId != null) 'updated_device_id': updatedDeviceId,
      if (deletedAt != null) 'deleted_at': deletedAt,
      if (rowid != null) 'rowid': rowid,
    });
  }

  CustomersCompanion copyWith({
    Value<String>? id,
    Value<String>? name,
    Value<String?>? note,
    Value<int>? balanceKurus,
    Value<String>? updatedOccurredAt,
    Value<String?>? updatedDeviceId,
    Value<String?>? deletedAt,
    Value<int>? rowid,
  }) {
    return CustomersCompanion(
      id: id ?? this.id,
      name: name ?? this.name,
      note: note ?? this.note,
      balanceKurus: balanceKurus ?? this.balanceKurus,
      updatedOccurredAt: updatedOccurredAt ?? this.updatedOccurredAt,
      updatedDeviceId: updatedDeviceId ?? this.updatedDeviceId,
      deletedAt: deletedAt ?? this.deletedAt,
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
    if (note.present) {
      map['note'] = Variable<String>(note.value);
    }
    if (balanceKurus.present) {
      map['balance_kurus'] = Variable<int>(balanceKurus.value);
    }
    if (updatedOccurredAt.present) {
      map['updated_occurred_at'] = Variable<String>(updatedOccurredAt.value);
    }
    if (updatedDeviceId.present) {
      map['updated_device_id'] = Variable<String>(updatedDeviceId.value);
    }
    if (deletedAt.present) {
      map['deleted_at'] = Variable<String>(deletedAt.value);
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
          ..write('note: $note, ')
          ..write('balanceKurus: $balanceKurus, ')
          ..write('updatedOccurredAt: $updatedOccurredAt, ')
          ..write('updatedDeviceId: $updatedDeviceId, ')
          ..write('deletedAt: $deletedAt, ')
          ..write('rowid: $rowid')
          ..write(')'))
        .toString();
  }
}

class $CustomerPhonesTable extends CustomerPhones
    with TableInfo<$CustomerPhonesTable, CustomerPhone> {
  @override
  final GeneratedDatabase attachedDatabase;
  final String? _alias;
  $CustomerPhonesTable(this.attachedDatabase, [this._alias]);
  static const VerificationMeta _idMeta = const VerificationMeta('id');
  @override
  late final GeneratedColumn<String> id = GeneratedColumn<String>(
    'id',
    aliasedName,
    false,
    type: DriftSqlType.string,
    requiredDuringInsert: true,
  );
  static const VerificationMeta _customerIdMeta = const VerificationMeta(
    'customerId',
  );
  @override
  late final GeneratedColumn<String> customerId = GeneratedColumn<String>(
    'customer_id',
    aliasedName,
    false,
    type: DriftSqlType.string,
    requiredDuringInsert: true,
  );
  static const VerificationMeta _phoneE164Meta = const VerificationMeta(
    'phoneE164',
  );
  @override
  late final GeneratedColumn<String> phoneE164 = GeneratedColumn<String>(
    'phone_e164',
    aliasedName,
    false,
    type: DriftSqlType.string,
    requiredDuringInsert: true,
  );
  static const VerificationMeta _phoneLast10Meta = const VerificationMeta(
    'phoneLast10',
  );
  @override
  late final GeneratedColumn<String> phoneLast10 = GeneratedColumn<String>(
    'phone_last10',
    aliasedName,
    false,
    type: DriftSqlType.string,
    requiredDuringInsert: true,
  );
  static const VerificationMeta _labelMeta = const VerificationMeta('label');
  @override
  late final GeneratedColumn<String> label = GeneratedColumn<String>(
    'label',
    aliasedName,
    true,
    type: DriftSqlType.string,
    requiredDuringInsert: false,
  );
  static const VerificationMeta _isPrimaryMeta = const VerificationMeta(
    'isPrimary',
  );
  @override
  late final GeneratedColumn<bool> isPrimary = GeneratedColumn<bool>(
    'is_primary',
    aliasedName,
    false,
    type: DriftSqlType.bool,
    requiredDuringInsert: false,
    defaultConstraints: GeneratedColumn.constraintIsAlways(
      'CHECK ("is_primary" IN (0, 1))',
    ),
    defaultValue: const Constant(false),
  );
  static const VerificationMeta _updatedOccurredAtMeta = const VerificationMeta(
    'updatedOccurredAt',
  );
  @override
  late final GeneratedColumn<String> updatedOccurredAt =
      GeneratedColumn<String>(
        'updated_occurred_at',
        aliasedName,
        false,
        type: DriftSqlType.string,
        requiredDuringInsert: true,
      );
  static const VerificationMeta _updatedDeviceIdMeta = const VerificationMeta(
    'updatedDeviceId',
  );
  @override
  late final GeneratedColumn<String> updatedDeviceId = GeneratedColumn<String>(
    'updated_device_id',
    aliasedName,
    true,
    type: DriftSqlType.string,
    requiredDuringInsert: false,
  );
  static const VerificationMeta _deletedAtMeta = const VerificationMeta(
    'deletedAt',
  );
  @override
  late final GeneratedColumn<String> deletedAt = GeneratedColumn<String>(
    'deleted_at',
    aliasedName,
    true,
    type: DriftSqlType.string,
    requiredDuringInsert: false,
  );
  @override
  List<GeneratedColumn> get $columns => [
    id,
    customerId,
    phoneE164,
    phoneLast10,
    label,
    isPrimary,
    updatedOccurredAt,
    updatedDeviceId,
    deletedAt,
  ];
  @override
  String get aliasedName => _alias ?? actualTableName;
  @override
  String get actualTableName => $name;
  static const String $name = 'customer_phones';
  @override
  VerificationContext validateIntegrity(
    Insertable<CustomerPhone> instance, {
    bool isInserting = false,
  }) {
    final context = VerificationContext();
    final data = instance.toColumns(true);
    if (data.containsKey('id')) {
      context.handle(_idMeta, id.isAcceptableOrUnknown(data['id']!, _idMeta));
    } else if (isInserting) {
      context.missing(_idMeta);
    }
    if (data.containsKey('customer_id')) {
      context.handle(
        _customerIdMeta,
        customerId.isAcceptableOrUnknown(data['customer_id']!, _customerIdMeta),
      );
    } else if (isInserting) {
      context.missing(_customerIdMeta);
    }
    if (data.containsKey('phone_e164')) {
      context.handle(
        _phoneE164Meta,
        phoneE164.isAcceptableOrUnknown(data['phone_e164']!, _phoneE164Meta),
      );
    } else if (isInserting) {
      context.missing(_phoneE164Meta);
    }
    if (data.containsKey('phone_last10')) {
      context.handle(
        _phoneLast10Meta,
        phoneLast10.isAcceptableOrUnknown(
          data['phone_last10']!,
          _phoneLast10Meta,
        ),
      );
    } else if (isInserting) {
      context.missing(_phoneLast10Meta);
    }
    if (data.containsKey('label')) {
      context.handle(
        _labelMeta,
        label.isAcceptableOrUnknown(data['label']!, _labelMeta),
      );
    }
    if (data.containsKey('is_primary')) {
      context.handle(
        _isPrimaryMeta,
        isPrimary.isAcceptableOrUnknown(data['is_primary']!, _isPrimaryMeta),
      );
    }
    if (data.containsKey('updated_occurred_at')) {
      context.handle(
        _updatedOccurredAtMeta,
        updatedOccurredAt.isAcceptableOrUnknown(
          data['updated_occurred_at']!,
          _updatedOccurredAtMeta,
        ),
      );
    } else if (isInserting) {
      context.missing(_updatedOccurredAtMeta);
    }
    if (data.containsKey('updated_device_id')) {
      context.handle(
        _updatedDeviceIdMeta,
        updatedDeviceId.isAcceptableOrUnknown(
          data['updated_device_id']!,
          _updatedDeviceIdMeta,
        ),
      );
    }
    if (data.containsKey('deleted_at')) {
      context.handle(
        _deletedAtMeta,
        deletedAt.isAcceptableOrUnknown(data['deleted_at']!, _deletedAtMeta),
      );
    }
    return context;
  }

  @override
  Set<GeneratedColumn> get $primaryKey => {id};
  @override
  CustomerPhone map(Map<String, dynamic> data, {String? tablePrefix}) {
    final effectivePrefix = tablePrefix != null ? '$tablePrefix.' : '';
    return CustomerPhone(
      id: attachedDatabase.typeMapping.read(
        DriftSqlType.string,
        data['${effectivePrefix}id'],
      )!,
      customerId: attachedDatabase.typeMapping.read(
        DriftSqlType.string,
        data['${effectivePrefix}customer_id'],
      )!,
      phoneE164: attachedDatabase.typeMapping.read(
        DriftSqlType.string,
        data['${effectivePrefix}phone_e164'],
      )!,
      phoneLast10: attachedDatabase.typeMapping.read(
        DriftSqlType.string,
        data['${effectivePrefix}phone_last10'],
      )!,
      label: attachedDatabase.typeMapping.read(
        DriftSqlType.string,
        data['${effectivePrefix}label'],
      ),
      isPrimary: attachedDatabase.typeMapping.read(
        DriftSqlType.bool,
        data['${effectivePrefix}is_primary'],
      )!,
      updatedOccurredAt: attachedDatabase.typeMapping.read(
        DriftSqlType.string,
        data['${effectivePrefix}updated_occurred_at'],
      )!,
      updatedDeviceId: attachedDatabase.typeMapping.read(
        DriftSqlType.string,
        data['${effectivePrefix}updated_device_id'],
      ),
      deletedAt: attachedDatabase.typeMapping.read(
        DriftSqlType.string,
        data['${effectivePrefix}deleted_at'],
      ),
    );
  }

  @override
  $CustomerPhonesTable createAlias(String alias) {
    return $CustomerPhonesTable(attachedDatabase, alias);
  }
}

class CustomerPhone extends DataClass implements Insertable<CustomerPhone> {
  final String id;
  final String customerId;
  final String phoneE164;
  final String phoneLast10;
  final String? label;
  final bool isPrimary;
  final String updatedOccurredAt;
  final String? updatedDeviceId;
  final String? deletedAt;
  const CustomerPhone({
    required this.id,
    required this.customerId,
    required this.phoneE164,
    required this.phoneLast10,
    this.label,
    required this.isPrimary,
    required this.updatedOccurredAt,
    this.updatedDeviceId,
    this.deletedAt,
  });
  @override
  Map<String, Expression> toColumns(bool nullToAbsent) {
    final map = <String, Expression>{};
    map['id'] = Variable<String>(id);
    map['customer_id'] = Variable<String>(customerId);
    map['phone_e164'] = Variable<String>(phoneE164);
    map['phone_last10'] = Variable<String>(phoneLast10);
    if (!nullToAbsent || label != null) {
      map['label'] = Variable<String>(label);
    }
    map['is_primary'] = Variable<bool>(isPrimary);
    map['updated_occurred_at'] = Variable<String>(updatedOccurredAt);
    if (!nullToAbsent || updatedDeviceId != null) {
      map['updated_device_id'] = Variable<String>(updatedDeviceId);
    }
    if (!nullToAbsent || deletedAt != null) {
      map['deleted_at'] = Variable<String>(deletedAt);
    }
    return map;
  }

  CustomerPhonesCompanion toCompanion(bool nullToAbsent) {
    return CustomerPhonesCompanion(
      id: Value(id),
      customerId: Value(customerId),
      phoneE164: Value(phoneE164),
      phoneLast10: Value(phoneLast10),
      label: label == null && nullToAbsent
          ? const Value.absent()
          : Value(label),
      isPrimary: Value(isPrimary),
      updatedOccurredAt: Value(updatedOccurredAt),
      updatedDeviceId: updatedDeviceId == null && nullToAbsent
          ? const Value.absent()
          : Value(updatedDeviceId),
      deletedAt: deletedAt == null && nullToAbsent
          ? const Value.absent()
          : Value(deletedAt),
    );
  }

  factory CustomerPhone.fromJson(
    Map<String, dynamic> json, {
    ValueSerializer? serializer,
  }) {
    serializer ??= driftRuntimeOptions.defaultSerializer;
    return CustomerPhone(
      id: serializer.fromJson<String>(json['id']),
      customerId: serializer.fromJson<String>(json['customerId']),
      phoneE164: serializer.fromJson<String>(json['phoneE164']),
      phoneLast10: serializer.fromJson<String>(json['phoneLast10']),
      label: serializer.fromJson<String?>(json['label']),
      isPrimary: serializer.fromJson<bool>(json['isPrimary']),
      updatedOccurredAt: serializer.fromJson<String>(json['updatedOccurredAt']),
      updatedDeviceId: serializer.fromJson<String?>(json['updatedDeviceId']),
      deletedAt: serializer.fromJson<String?>(json['deletedAt']),
    );
  }
  @override
  Map<String, dynamic> toJson({ValueSerializer? serializer}) {
    serializer ??= driftRuntimeOptions.defaultSerializer;
    return <String, dynamic>{
      'id': serializer.toJson<String>(id),
      'customerId': serializer.toJson<String>(customerId),
      'phoneE164': serializer.toJson<String>(phoneE164),
      'phoneLast10': serializer.toJson<String>(phoneLast10),
      'label': serializer.toJson<String?>(label),
      'isPrimary': serializer.toJson<bool>(isPrimary),
      'updatedOccurredAt': serializer.toJson<String>(updatedOccurredAt),
      'updatedDeviceId': serializer.toJson<String?>(updatedDeviceId),
      'deletedAt': serializer.toJson<String?>(deletedAt),
    };
  }

  CustomerPhone copyWith({
    String? id,
    String? customerId,
    String? phoneE164,
    String? phoneLast10,
    Value<String?> label = const Value.absent(),
    bool? isPrimary,
    String? updatedOccurredAt,
    Value<String?> updatedDeviceId = const Value.absent(),
    Value<String?> deletedAt = const Value.absent(),
  }) => CustomerPhone(
    id: id ?? this.id,
    customerId: customerId ?? this.customerId,
    phoneE164: phoneE164 ?? this.phoneE164,
    phoneLast10: phoneLast10 ?? this.phoneLast10,
    label: label.present ? label.value : this.label,
    isPrimary: isPrimary ?? this.isPrimary,
    updatedOccurredAt: updatedOccurredAt ?? this.updatedOccurredAt,
    updatedDeviceId: updatedDeviceId.present
        ? updatedDeviceId.value
        : this.updatedDeviceId,
    deletedAt: deletedAt.present ? deletedAt.value : this.deletedAt,
  );
  CustomerPhone copyWithCompanion(CustomerPhonesCompanion data) {
    return CustomerPhone(
      id: data.id.present ? data.id.value : this.id,
      customerId: data.customerId.present
          ? data.customerId.value
          : this.customerId,
      phoneE164: data.phoneE164.present ? data.phoneE164.value : this.phoneE164,
      phoneLast10: data.phoneLast10.present
          ? data.phoneLast10.value
          : this.phoneLast10,
      label: data.label.present ? data.label.value : this.label,
      isPrimary: data.isPrimary.present ? data.isPrimary.value : this.isPrimary,
      updatedOccurredAt: data.updatedOccurredAt.present
          ? data.updatedOccurredAt.value
          : this.updatedOccurredAt,
      updatedDeviceId: data.updatedDeviceId.present
          ? data.updatedDeviceId.value
          : this.updatedDeviceId,
      deletedAt: data.deletedAt.present ? data.deletedAt.value : this.deletedAt,
    );
  }

  @override
  String toString() {
    return (StringBuffer('CustomerPhone(')
          ..write('id: $id, ')
          ..write('customerId: $customerId, ')
          ..write('phoneE164: $phoneE164, ')
          ..write('phoneLast10: $phoneLast10, ')
          ..write('label: $label, ')
          ..write('isPrimary: $isPrimary, ')
          ..write('updatedOccurredAt: $updatedOccurredAt, ')
          ..write('updatedDeviceId: $updatedDeviceId, ')
          ..write('deletedAt: $deletedAt')
          ..write(')'))
        .toString();
  }

  @override
  int get hashCode => Object.hash(
    id,
    customerId,
    phoneE164,
    phoneLast10,
    label,
    isPrimary,
    updatedOccurredAt,
    updatedDeviceId,
    deletedAt,
  );
  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      (other is CustomerPhone &&
          other.id == this.id &&
          other.customerId == this.customerId &&
          other.phoneE164 == this.phoneE164 &&
          other.phoneLast10 == this.phoneLast10 &&
          other.label == this.label &&
          other.isPrimary == this.isPrimary &&
          other.updatedOccurredAt == this.updatedOccurredAt &&
          other.updatedDeviceId == this.updatedDeviceId &&
          other.deletedAt == this.deletedAt);
}

class CustomerPhonesCompanion extends UpdateCompanion<CustomerPhone> {
  final Value<String> id;
  final Value<String> customerId;
  final Value<String> phoneE164;
  final Value<String> phoneLast10;
  final Value<String?> label;
  final Value<bool> isPrimary;
  final Value<String> updatedOccurredAt;
  final Value<String?> updatedDeviceId;
  final Value<String?> deletedAt;
  final Value<int> rowid;
  const CustomerPhonesCompanion({
    this.id = const Value.absent(),
    this.customerId = const Value.absent(),
    this.phoneE164 = const Value.absent(),
    this.phoneLast10 = const Value.absent(),
    this.label = const Value.absent(),
    this.isPrimary = const Value.absent(),
    this.updatedOccurredAt = const Value.absent(),
    this.updatedDeviceId = const Value.absent(),
    this.deletedAt = const Value.absent(),
    this.rowid = const Value.absent(),
  });
  CustomerPhonesCompanion.insert({
    required String id,
    required String customerId,
    required String phoneE164,
    required String phoneLast10,
    this.label = const Value.absent(),
    this.isPrimary = const Value.absent(),
    required String updatedOccurredAt,
    this.updatedDeviceId = const Value.absent(),
    this.deletedAt = const Value.absent(),
    this.rowid = const Value.absent(),
  }) : id = Value(id),
       customerId = Value(customerId),
       phoneE164 = Value(phoneE164),
       phoneLast10 = Value(phoneLast10),
       updatedOccurredAt = Value(updatedOccurredAt);
  static Insertable<CustomerPhone> custom({
    Expression<String>? id,
    Expression<String>? customerId,
    Expression<String>? phoneE164,
    Expression<String>? phoneLast10,
    Expression<String>? label,
    Expression<bool>? isPrimary,
    Expression<String>? updatedOccurredAt,
    Expression<String>? updatedDeviceId,
    Expression<String>? deletedAt,
    Expression<int>? rowid,
  }) {
    return RawValuesInsertable({
      if (id != null) 'id': id,
      if (customerId != null) 'customer_id': customerId,
      if (phoneE164 != null) 'phone_e164': phoneE164,
      if (phoneLast10 != null) 'phone_last10': phoneLast10,
      if (label != null) 'label': label,
      if (isPrimary != null) 'is_primary': isPrimary,
      if (updatedOccurredAt != null) 'updated_occurred_at': updatedOccurredAt,
      if (updatedDeviceId != null) 'updated_device_id': updatedDeviceId,
      if (deletedAt != null) 'deleted_at': deletedAt,
      if (rowid != null) 'rowid': rowid,
    });
  }

  CustomerPhonesCompanion copyWith({
    Value<String>? id,
    Value<String>? customerId,
    Value<String>? phoneE164,
    Value<String>? phoneLast10,
    Value<String?>? label,
    Value<bool>? isPrimary,
    Value<String>? updatedOccurredAt,
    Value<String?>? updatedDeviceId,
    Value<String?>? deletedAt,
    Value<int>? rowid,
  }) {
    return CustomerPhonesCompanion(
      id: id ?? this.id,
      customerId: customerId ?? this.customerId,
      phoneE164: phoneE164 ?? this.phoneE164,
      phoneLast10: phoneLast10 ?? this.phoneLast10,
      label: label ?? this.label,
      isPrimary: isPrimary ?? this.isPrimary,
      updatedOccurredAt: updatedOccurredAt ?? this.updatedOccurredAt,
      updatedDeviceId: updatedDeviceId ?? this.updatedDeviceId,
      deletedAt: deletedAt ?? this.deletedAt,
      rowid: rowid ?? this.rowid,
    );
  }

  @override
  Map<String, Expression> toColumns(bool nullToAbsent) {
    final map = <String, Expression>{};
    if (id.present) {
      map['id'] = Variable<String>(id.value);
    }
    if (customerId.present) {
      map['customer_id'] = Variable<String>(customerId.value);
    }
    if (phoneE164.present) {
      map['phone_e164'] = Variable<String>(phoneE164.value);
    }
    if (phoneLast10.present) {
      map['phone_last10'] = Variable<String>(phoneLast10.value);
    }
    if (label.present) {
      map['label'] = Variable<String>(label.value);
    }
    if (isPrimary.present) {
      map['is_primary'] = Variable<bool>(isPrimary.value);
    }
    if (updatedOccurredAt.present) {
      map['updated_occurred_at'] = Variable<String>(updatedOccurredAt.value);
    }
    if (updatedDeviceId.present) {
      map['updated_device_id'] = Variable<String>(updatedDeviceId.value);
    }
    if (deletedAt.present) {
      map['deleted_at'] = Variable<String>(deletedAt.value);
    }
    if (rowid.present) {
      map['rowid'] = Variable<int>(rowid.value);
    }
    return map;
  }

  @override
  String toString() {
    return (StringBuffer('CustomerPhonesCompanion(')
          ..write('id: $id, ')
          ..write('customerId: $customerId, ')
          ..write('phoneE164: $phoneE164, ')
          ..write('phoneLast10: $phoneLast10, ')
          ..write('label: $label, ')
          ..write('isPrimary: $isPrimary, ')
          ..write('updatedOccurredAt: $updatedOccurredAt, ')
          ..write('updatedDeviceId: $updatedDeviceId, ')
          ..write('deletedAt: $deletedAt, ')
          ..write('rowid: $rowid')
          ..write(')'))
        .toString();
  }
}

class $CustomerAddressesTable extends CustomerAddresses
    with TableInfo<$CustomerAddressesTable, CustomerAddressesData> {
  @override
  final GeneratedDatabase attachedDatabase;
  final String? _alias;
  $CustomerAddressesTable(this.attachedDatabase, [this._alias]);
  static const VerificationMeta _idMeta = const VerificationMeta('id');
  @override
  late final GeneratedColumn<String> id = GeneratedColumn<String>(
    'id',
    aliasedName,
    false,
    type: DriftSqlType.string,
    requiredDuringInsert: true,
  );
  static const VerificationMeta _customerIdMeta = const VerificationMeta(
    'customerId',
  );
  @override
  late final GeneratedColumn<String> customerId = GeneratedColumn<String>(
    'customer_id',
    aliasedName,
    false,
    type: DriftSqlType.string,
    requiredDuringInsert: true,
  );
  static const VerificationMeta _labelMeta = const VerificationMeta('label');
  @override
  late final GeneratedColumn<String> label = GeneratedColumn<String>(
    'label',
    aliasedName,
    true,
    type: DriftSqlType.string,
    requiredDuringInsert: false,
  );
  static const VerificationMeta _addressTextMeta = const VerificationMeta(
    'addressText',
  );
  @override
  late final GeneratedColumn<String> addressText = GeneratedColumn<String>(
    'address_text',
    aliasedName,
    false,
    type: DriftSqlType.string,
    requiredDuringInsert: true,
  );
  static const VerificationMeta _latMeta = const VerificationMeta('lat');
  @override
  late final GeneratedColumn<double> lat = GeneratedColumn<double>(
    'lat',
    aliasedName,
    true,
    type: DriftSqlType.double,
    requiredDuringInsert: false,
  );
  static const VerificationMeta _lngMeta = const VerificationMeta('lng');
  @override
  late final GeneratedColumn<double> lng = GeneratedColumn<double>(
    'lng',
    aliasedName,
    true,
    type: DriftSqlType.double,
    requiredDuringInsert: false,
  );
  static const VerificationMeta _isPrimaryMeta = const VerificationMeta(
    'isPrimary',
  );
  @override
  late final GeneratedColumn<bool> isPrimary = GeneratedColumn<bool>(
    'is_primary',
    aliasedName,
    false,
    type: DriftSqlType.bool,
    requiredDuringInsert: false,
    defaultConstraints: GeneratedColumn.constraintIsAlways(
      'CHECK ("is_primary" IN (0, 1))',
    ),
    defaultValue: const Constant(false),
  );
  static const VerificationMeta _updatedOccurredAtMeta = const VerificationMeta(
    'updatedOccurredAt',
  );
  @override
  late final GeneratedColumn<String> updatedOccurredAt =
      GeneratedColumn<String>(
        'updated_occurred_at',
        aliasedName,
        false,
        type: DriftSqlType.string,
        requiredDuringInsert: true,
      );
  static const VerificationMeta _updatedDeviceIdMeta = const VerificationMeta(
    'updatedDeviceId',
  );
  @override
  late final GeneratedColumn<String> updatedDeviceId = GeneratedColumn<String>(
    'updated_device_id',
    aliasedName,
    true,
    type: DriftSqlType.string,
    requiredDuringInsert: false,
  );
  static const VerificationMeta _deletedAtMeta = const VerificationMeta(
    'deletedAt',
  );
  @override
  late final GeneratedColumn<String> deletedAt = GeneratedColumn<String>(
    'deleted_at',
    aliasedName,
    true,
    type: DriftSqlType.string,
    requiredDuringInsert: false,
  );
  @override
  List<GeneratedColumn> get $columns => [
    id,
    customerId,
    label,
    addressText,
    lat,
    lng,
    isPrimary,
    updatedOccurredAt,
    updatedDeviceId,
    deletedAt,
  ];
  @override
  String get aliasedName => _alias ?? actualTableName;
  @override
  String get actualTableName => $name;
  static const String $name = 'customer_addresses';
  @override
  VerificationContext validateIntegrity(
    Insertable<CustomerAddressesData> instance, {
    bool isInserting = false,
  }) {
    final context = VerificationContext();
    final data = instance.toColumns(true);
    if (data.containsKey('id')) {
      context.handle(_idMeta, id.isAcceptableOrUnknown(data['id']!, _idMeta));
    } else if (isInserting) {
      context.missing(_idMeta);
    }
    if (data.containsKey('customer_id')) {
      context.handle(
        _customerIdMeta,
        customerId.isAcceptableOrUnknown(data['customer_id']!, _customerIdMeta),
      );
    } else if (isInserting) {
      context.missing(_customerIdMeta);
    }
    if (data.containsKey('label')) {
      context.handle(
        _labelMeta,
        label.isAcceptableOrUnknown(data['label']!, _labelMeta),
      );
    }
    if (data.containsKey('address_text')) {
      context.handle(
        _addressTextMeta,
        addressText.isAcceptableOrUnknown(
          data['address_text']!,
          _addressTextMeta,
        ),
      );
    } else if (isInserting) {
      context.missing(_addressTextMeta);
    }
    if (data.containsKey('lat')) {
      context.handle(
        _latMeta,
        lat.isAcceptableOrUnknown(data['lat']!, _latMeta),
      );
    }
    if (data.containsKey('lng')) {
      context.handle(
        _lngMeta,
        lng.isAcceptableOrUnknown(data['lng']!, _lngMeta),
      );
    }
    if (data.containsKey('is_primary')) {
      context.handle(
        _isPrimaryMeta,
        isPrimary.isAcceptableOrUnknown(data['is_primary']!, _isPrimaryMeta),
      );
    }
    if (data.containsKey('updated_occurred_at')) {
      context.handle(
        _updatedOccurredAtMeta,
        updatedOccurredAt.isAcceptableOrUnknown(
          data['updated_occurred_at']!,
          _updatedOccurredAtMeta,
        ),
      );
    } else if (isInserting) {
      context.missing(_updatedOccurredAtMeta);
    }
    if (data.containsKey('updated_device_id')) {
      context.handle(
        _updatedDeviceIdMeta,
        updatedDeviceId.isAcceptableOrUnknown(
          data['updated_device_id']!,
          _updatedDeviceIdMeta,
        ),
      );
    }
    if (data.containsKey('deleted_at')) {
      context.handle(
        _deletedAtMeta,
        deletedAt.isAcceptableOrUnknown(data['deleted_at']!, _deletedAtMeta),
      );
    }
    return context;
  }

  @override
  Set<GeneratedColumn> get $primaryKey => {id};
  @override
  CustomerAddressesData map(Map<String, dynamic> data, {String? tablePrefix}) {
    final effectivePrefix = tablePrefix != null ? '$tablePrefix.' : '';
    return CustomerAddressesData(
      id: attachedDatabase.typeMapping.read(
        DriftSqlType.string,
        data['${effectivePrefix}id'],
      )!,
      customerId: attachedDatabase.typeMapping.read(
        DriftSqlType.string,
        data['${effectivePrefix}customer_id'],
      )!,
      label: attachedDatabase.typeMapping.read(
        DriftSqlType.string,
        data['${effectivePrefix}label'],
      ),
      addressText: attachedDatabase.typeMapping.read(
        DriftSqlType.string,
        data['${effectivePrefix}address_text'],
      )!,
      lat: attachedDatabase.typeMapping.read(
        DriftSqlType.double,
        data['${effectivePrefix}lat'],
      ),
      lng: attachedDatabase.typeMapping.read(
        DriftSqlType.double,
        data['${effectivePrefix}lng'],
      ),
      isPrimary: attachedDatabase.typeMapping.read(
        DriftSqlType.bool,
        data['${effectivePrefix}is_primary'],
      )!,
      updatedOccurredAt: attachedDatabase.typeMapping.read(
        DriftSqlType.string,
        data['${effectivePrefix}updated_occurred_at'],
      )!,
      updatedDeviceId: attachedDatabase.typeMapping.read(
        DriftSqlType.string,
        data['${effectivePrefix}updated_device_id'],
      ),
      deletedAt: attachedDatabase.typeMapping.read(
        DriftSqlType.string,
        data['${effectivePrefix}deleted_at'],
      ),
    );
  }

  @override
  $CustomerAddressesTable createAlias(String alias) {
    return $CustomerAddressesTable(attachedDatabase, alias);
  }
}

class CustomerAddressesData extends DataClass
    implements Insertable<CustomerAddressesData> {
  final String id;
  final String customerId;
  final String? label;
  final String addressText;
  final double? lat;
  final double? lng;
  final bool isPrimary;
  final String updatedOccurredAt;
  final String? updatedDeviceId;
  final String? deletedAt;
  const CustomerAddressesData({
    required this.id,
    required this.customerId,
    this.label,
    required this.addressText,
    this.lat,
    this.lng,
    required this.isPrimary,
    required this.updatedOccurredAt,
    this.updatedDeviceId,
    this.deletedAt,
  });
  @override
  Map<String, Expression> toColumns(bool nullToAbsent) {
    final map = <String, Expression>{};
    map['id'] = Variable<String>(id);
    map['customer_id'] = Variable<String>(customerId);
    if (!nullToAbsent || label != null) {
      map['label'] = Variable<String>(label);
    }
    map['address_text'] = Variable<String>(addressText);
    if (!nullToAbsent || lat != null) {
      map['lat'] = Variable<double>(lat);
    }
    if (!nullToAbsent || lng != null) {
      map['lng'] = Variable<double>(lng);
    }
    map['is_primary'] = Variable<bool>(isPrimary);
    map['updated_occurred_at'] = Variable<String>(updatedOccurredAt);
    if (!nullToAbsent || updatedDeviceId != null) {
      map['updated_device_id'] = Variable<String>(updatedDeviceId);
    }
    if (!nullToAbsent || deletedAt != null) {
      map['deleted_at'] = Variable<String>(deletedAt);
    }
    return map;
  }

  CustomerAddressesCompanion toCompanion(bool nullToAbsent) {
    return CustomerAddressesCompanion(
      id: Value(id),
      customerId: Value(customerId),
      label: label == null && nullToAbsent
          ? const Value.absent()
          : Value(label),
      addressText: Value(addressText),
      lat: lat == null && nullToAbsent ? const Value.absent() : Value(lat),
      lng: lng == null && nullToAbsent ? const Value.absent() : Value(lng),
      isPrimary: Value(isPrimary),
      updatedOccurredAt: Value(updatedOccurredAt),
      updatedDeviceId: updatedDeviceId == null && nullToAbsent
          ? const Value.absent()
          : Value(updatedDeviceId),
      deletedAt: deletedAt == null && nullToAbsent
          ? const Value.absent()
          : Value(deletedAt),
    );
  }

  factory CustomerAddressesData.fromJson(
    Map<String, dynamic> json, {
    ValueSerializer? serializer,
  }) {
    serializer ??= driftRuntimeOptions.defaultSerializer;
    return CustomerAddressesData(
      id: serializer.fromJson<String>(json['id']),
      customerId: serializer.fromJson<String>(json['customerId']),
      label: serializer.fromJson<String?>(json['label']),
      addressText: serializer.fromJson<String>(json['addressText']),
      lat: serializer.fromJson<double?>(json['lat']),
      lng: serializer.fromJson<double?>(json['lng']),
      isPrimary: serializer.fromJson<bool>(json['isPrimary']),
      updatedOccurredAt: serializer.fromJson<String>(json['updatedOccurredAt']),
      updatedDeviceId: serializer.fromJson<String?>(json['updatedDeviceId']),
      deletedAt: serializer.fromJson<String?>(json['deletedAt']),
    );
  }
  @override
  Map<String, dynamic> toJson({ValueSerializer? serializer}) {
    serializer ??= driftRuntimeOptions.defaultSerializer;
    return <String, dynamic>{
      'id': serializer.toJson<String>(id),
      'customerId': serializer.toJson<String>(customerId),
      'label': serializer.toJson<String?>(label),
      'addressText': serializer.toJson<String>(addressText),
      'lat': serializer.toJson<double?>(lat),
      'lng': serializer.toJson<double?>(lng),
      'isPrimary': serializer.toJson<bool>(isPrimary),
      'updatedOccurredAt': serializer.toJson<String>(updatedOccurredAt),
      'updatedDeviceId': serializer.toJson<String?>(updatedDeviceId),
      'deletedAt': serializer.toJson<String?>(deletedAt),
    };
  }

  CustomerAddressesData copyWith({
    String? id,
    String? customerId,
    Value<String?> label = const Value.absent(),
    String? addressText,
    Value<double?> lat = const Value.absent(),
    Value<double?> lng = const Value.absent(),
    bool? isPrimary,
    String? updatedOccurredAt,
    Value<String?> updatedDeviceId = const Value.absent(),
    Value<String?> deletedAt = const Value.absent(),
  }) => CustomerAddressesData(
    id: id ?? this.id,
    customerId: customerId ?? this.customerId,
    label: label.present ? label.value : this.label,
    addressText: addressText ?? this.addressText,
    lat: lat.present ? lat.value : this.lat,
    lng: lng.present ? lng.value : this.lng,
    isPrimary: isPrimary ?? this.isPrimary,
    updatedOccurredAt: updatedOccurredAt ?? this.updatedOccurredAt,
    updatedDeviceId: updatedDeviceId.present
        ? updatedDeviceId.value
        : this.updatedDeviceId,
    deletedAt: deletedAt.present ? deletedAt.value : this.deletedAt,
  );
  CustomerAddressesData copyWithCompanion(CustomerAddressesCompanion data) {
    return CustomerAddressesData(
      id: data.id.present ? data.id.value : this.id,
      customerId: data.customerId.present
          ? data.customerId.value
          : this.customerId,
      label: data.label.present ? data.label.value : this.label,
      addressText: data.addressText.present
          ? data.addressText.value
          : this.addressText,
      lat: data.lat.present ? data.lat.value : this.lat,
      lng: data.lng.present ? data.lng.value : this.lng,
      isPrimary: data.isPrimary.present ? data.isPrimary.value : this.isPrimary,
      updatedOccurredAt: data.updatedOccurredAt.present
          ? data.updatedOccurredAt.value
          : this.updatedOccurredAt,
      updatedDeviceId: data.updatedDeviceId.present
          ? data.updatedDeviceId.value
          : this.updatedDeviceId,
      deletedAt: data.deletedAt.present ? data.deletedAt.value : this.deletedAt,
    );
  }

  @override
  String toString() {
    return (StringBuffer('CustomerAddressesData(')
          ..write('id: $id, ')
          ..write('customerId: $customerId, ')
          ..write('label: $label, ')
          ..write('addressText: $addressText, ')
          ..write('lat: $lat, ')
          ..write('lng: $lng, ')
          ..write('isPrimary: $isPrimary, ')
          ..write('updatedOccurredAt: $updatedOccurredAt, ')
          ..write('updatedDeviceId: $updatedDeviceId, ')
          ..write('deletedAt: $deletedAt')
          ..write(')'))
        .toString();
  }

  @override
  int get hashCode => Object.hash(
    id,
    customerId,
    label,
    addressText,
    lat,
    lng,
    isPrimary,
    updatedOccurredAt,
    updatedDeviceId,
    deletedAt,
  );
  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      (other is CustomerAddressesData &&
          other.id == this.id &&
          other.customerId == this.customerId &&
          other.label == this.label &&
          other.addressText == this.addressText &&
          other.lat == this.lat &&
          other.lng == this.lng &&
          other.isPrimary == this.isPrimary &&
          other.updatedOccurredAt == this.updatedOccurredAt &&
          other.updatedDeviceId == this.updatedDeviceId &&
          other.deletedAt == this.deletedAt);
}

class CustomerAddressesCompanion
    extends UpdateCompanion<CustomerAddressesData> {
  final Value<String> id;
  final Value<String> customerId;
  final Value<String?> label;
  final Value<String> addressText;
  final Value<double?> lat;
  final Value<double?> lng;
  final Value<bool> isPrimary;
  final Value<String> updatedOccurredAt;
  final Value<String?> updatedDeviceId;
  final Value<String?> deletedAt;
  final Value<int> rowid;
  const CustomerAddressesCompanion({
    this.id = const Value.absent(),
    this.customerId = const Value.absent(),
    this.label = const Value.absent(),
    this.addressText = const Value.absent(),
    this.lat = const Value.absent(),
    this.lng = const Value.absent(),
    this.isPrimary = const Value.absent(),
    this.updatedOccurredAt = const Value.absent(),
    this.updatedDeviceId = const Value.absent(),
    this.deletedAt = const Value.absent(),
    this.rowid = const Value.absent(),
  });
  CustomerAddressesCompanion.insert({
    required String id,
    required String customerId,
    this.label = const Value.absent(),
    required String addressText,
    this.lat = const Value.absent(),
    this.lng = const Value.absent(),
    this.isPrimary = const Value.absent(),
    required String updatedOccurredAt,
    this.updatedDeviceId = const Value.absent(),
    this.deletedAt = const Value.absent(),
    this.rowid = const Value.absent(),
  }) : id = Value(id),
       customerId = Value(customerId),
       addressText = Value(addressText),
       updatedOccurredAt = Value(updatedOccurredAt);
  static Insertable<CustomerAddressesData> custom({
    Expression<String>? id,
    Expression<String>? customerId,
    Expression<String>? label,
    Expression<String>? addressText,
    Expression<double>? lat,
    Expression<double>? lng,
    Expression<bool>? isPrimary,
    Expression<String>? updatedOccurredAt,
    Expression<String>? updatedDeviceId,
    Expression<String>? deletedAt,
    Expression<int>? rowid,
  }) {
    return RawValuesInsertable({
      if (id != null) 'id': id,
      if (customerId != null) 'customer_id': customerId,
      if (label != null) 'label': label,
      if (addressText != null) 'address_text': addressText,
      if (lat != null) 'lat': lat,
      if (lng != null) 'lng': lng,
      if (isPrimary != null) 'is_primary': isPrimary,
      if (updatedOccurredAt != null) 'updated_occurred_at': updatedOccurredAt,
      if (updatedDeviceId != null) 'updated_device_id': updatedDeviceId,
      if (deletedAt != null) 'deleted_at': deletedAt,
      if (rowid != null) 'rowid': rowid,
    });
  }

  CustomerAddressesCompanion copyWith({
    Value<String>? id,
    Value<String>? customerId,
    Value<String?>? label,
    Value<String>? addressText,
    Value<double?>? lat,
    Value<double?>? lng,
    Value<bool>? isPrimary,
    Value<String>? updatedOccurredAt,
    Value<String?>? updatedDeviceId,
    Value<String?>? deletedAt,
    Value<int>? rowid,
  }) {
    return CustomerAddressesCompanion(
      id: id ?? this.id,
      customerId: customerId ?? this.customerId,
      label: label ?? this.label,
      addressText: addressText ?? this.addressText,
      lat: lat ?? this.lat,
      lng: lng ?? this.lng,
      isPrimary: isPrimary ?? this.isPrimary,
      updatedOccurredAt: updatedOccurredAt ?? this.updatedOccurredAt,
      updatedDeviceId: updatedDeviceId ?? this.updatedDeviceId,
      deletedAt: deletedAt ?? this.deletedAt,
      rowid: rowid ?? this.rowid,
    );
  }

  @override
  Map<String, Expression> toColumns(bool nullToAbsent) {
    final map = <String, Expression>{};
    if (id.present) {
      map['id'] = Variable<String>(id.value);
    }
    if (customerId.present) {
      map['customer_id'] = Variable<String>(customerId.value);
    }
    if (label.present) {
      map['label'] = Variable<String>(label.value);
    }
    if (addressText.present) {
      map['address_text'] = Variable<String>(addressText.value);
    }
    if (lat.present) {
      map['lat'] = Variable<double>(lat.value);
    }
    if (lng.present) {
      map['lng'] = Variable<double>(lng.value);
    }
    if (isPrimary.present) {
      map['is_primary'] = Variable<bool>(isPrimary.value);
    }
    if (updatedOccurredAt.present) {
      map['updated_occurred_at'] = Variable<String>(updatedOccurredAt.value);
    }
    if (updatedDeviceId.present) {
      map['updated_device_id'] = Variable<String>(updatedDeviceId.value);
    }
    if (deletedAt.present) {
      map['deleted_at'] = Variable<String>(deletedAt.value);
    }
    if (rowid.present) {
      map['rowid'] = Variable<int>(rowid.value);
    }
    return map;
  }

  @override
  String toString() {
    return (StringBuffer('CustomerAddressesCompanion(')
          ..write('id: $id, ')
          ..write('customerId: $customerId, ')
          ..write('label: $label, ')
          ..write('addressText: $addressText, ')
          ..write('lat: $lat, ')
          ..write('lng: $lng, ')
          ..write('isPrimary: $isPrimary, ')
          ..write('updatedOccurredAt: $updatedOccurredAt, ')
          ..write('updatedDeviceId: $updatedDeviceId, ')
          ..write('deletedAt: $deletedAt, ')
          ..write('rowid: $rowid')
          ..write(')'))
        .toString();
  }
}

class $ProductsTable extends Products with TableInfo<$ProductsTable, Product> {
  @override
  final GeneratedDatabase attachedDatabase;
  final String? _alias;
  $ProductsTable(this.attachedDatabase, [this._alias]);
  static const VerificationMeta _idMeta = const VerificationMeta('id');
  @override
  late final GeneratedColumn<String> id = GeneratedColumn<String>(
    'id',
    aliasedName,
    false,
    type: DriftSqlType.string,
    requiredDuringInsert: true,
  );
  static const VerificationMeta _nameMeta = const VerificationMeta('name');
  @override
  late final GeneratedColumn<String> name = GeneratedColumn<String>(
    'name',
    aliasedName,
    false,
    type: DriftSqlType.string,
    requiredDuringInsert: true,
  );
  static const VerificationMeta _unitPriceKurusMeta = const VerificationMeta(
    'unitPriceKurus',
  );
  @override
  late final GeneratedColumn<int> unitPriceKurus = GeneratedColumn<int>(
    'unit_price_kurus',
    aliasedName,
    false,
    type: DriftSqlType.int,
    requiredDuringInsert: true,
  );
  static const VerificationMeta _unitMeta = const VerificationMeta('unit');
  @override
  late final GeneratedColumn<String> unit = GeneratedColumn<String>(
    'unit',
    aliasedName,
    false,
    type: DriftSqlType.string,
    requiredDuringInsert: false,
    defaultValue: const Constant('adet'),
  );
  static const VerificationMeta _isActiveMeta = const VerificationMeta(
    'isActive',
  );
  @override
  late final GeneratedColumn<bool> isActive = GeneratedColumn<bool>(
    'is_active',
    aliasedName,
    false,
    type: DriftSqlType.bool,
    requiredDuringInsert: false,
    defaultConstraints: GeneratedColumn.constraintIsAlways(
      'CHECK ("is_active" IN (0, 1))',
    ),
    defaultValue: const Constant(true),
  );
  static const VerificationMeta _updatedOccurredAtMeta = const VerificationMeta(
    'updatedOccurredAt',
  );
  @override
  late final GeneratedColumn<String> updatedOccurredAt =
      GeneratedColumn<String>(
        'updated_occurred_at',
        aliasedName,
        false,
        type: DriftSqlType.string,
        requiredDuringInsert: true,
      );
  static const VerificationMeta _updatedDeviceIdMeta = const VerificationMeta(
    'updatedDeviceId',
  );
  @override
  late final GeneratedColumn<String> updatedDeviceId = GeneratedColumn<String>(
    'updated_device_id',
    aliasedName,
    true,
    type: DriftSqlType.string,
    requiredDuringInsert: false,
  );
  static const VerificationMeta _deletedAtMeta = const VerificationMeta(
    'deletedAt',
  );
  @override
  late final GeneratedColumn<String> deletedAt = GeneratedColumn<String>(
    'deleted_at',
    aliasedName,
    true,
    type: DriftSqlType.string,
    requiredDuringInsert: false,
  );
  @override
  List<GeneratedColumn> get $columns => [
    id,
    name,
    unitPriceKurus,
    unit,
    isActive,
    updatedOccurredAt,
    updatedDeviceId,
    deletedAt,
  ];
  @override
  String get aliasedName => _alias ?? actualTableName;
  @override
  String get actualTableName => $name;
  static const String $name = 'products';
  @override
  VerificationContext validateIntegrity(
    Insertable<Product> instance, {
    bool isInserting = false,
  }) {
    final context = VerificationContext();
    final data = instance.toColumns(true);
    if (data.containsKey('id')) {
      context.handle(_idMeta, id.isAcceptableOrUnknown(data['id']!, _idMeta));
    } else if (isInserting) {
      context.missing(_idMeta);
    }
    if (data.containsKey('name')) {
      context.handle(
        _nameMeta,
        name.isAcceptableOrUnknown(data['name']!, _nameMeta),
      );
    } else if (isInserting) {
      context.missing(_nameMeta);
    }
    if (data.containsKey('unit_price_kurus')) {
      context.handle(
        _unitPriceKurusMeta,
        unitPriceKurus.isAcceptableOrUnknown(
          data['unit_price_kurus']!,
          _unitPriceKurusMeta,
        ),
      );
    } else if (isInserting) {
      context.missing(_unitPriceKurusMeta);
    }
    if (data.containsKey('unit')) {
      context.handle(
        _unitMeta,
        unit.isAcceptableOrUnknown(data['unit']!, _unitMeta),
      );
    }
    if (data.containsKey('is_active')) {
      context.handle(
        _isActiveMeta,
        isActive.isAcceptableOrUnknown(data['is_active']!, _isActiveMeta),
      );
    }
    if (data.containsKey('updated_occurred_at')) {
      context.handle(
        _updatedOccurredAtMeta,
        updatedOccurredAt.isAcceptableOrUnknown(
          data['updated_occurred_at']!,
          _updatedOccurredAtMeta,
        ),
      );
    } else if (isInserting) {
      context.missing(_updatedOccurredAtMeta);
    }
    if (data.containsKey('updated_device_id')) {
      context.handle(
        _updatedDeviceIdMeta,
        updatedDeviceId.isAcceptableOrUnknown(
          data['updated_device_id']!,
          _updatedDeviceIdMeta,
        ),
      );
    }
    if (data.containsKey('deleted_at')) {
      context.handle(
        _deletedAtMeta,
        deletedAt.isAcceptableOrUnknown(data['deleted_at']!, _deletedAtMeta),
      );
    }
    return context;
  }

  @override
  Set<GeneratedColumn> get $primaryKey => {id};
  @override
  Product map(Map<String, dynamic> data, {String? tablePrefix}) {
    final effectivePrefix = tablePrefix != null ? '$tablePrefix.' : '';
    return Product(
      id: attachedDatabase.typeMapping.read(
        DriftSqlType.string,
        data['${effectivePrefix}id'],
      )!,
      name: attachedDatabase.typeMapping.read(
        DriftSqlType.string,
        data['${effectivePrefix}name'],
      )!,
      unitPriceKurus: attachedDatabase.typeMapping.read(
        DriftSqlType.int,
        data['${effectivePrefix}unit_price_kurus'],
      )!,
      unit: attachedDatabase.typeMapping.read(
        DriftSqlType.string,
        data['${effectivePrefix}unit'],
      )!,
      isActive: attachedDatabase.typeMapping.read(
        DriftSqlType.bool,
        data['${effectivePrefix}is_active'],
      )!,
      updatedOccurredAt: attachedDatabase.typeMapping.read(
        DriftSqlType.string,
        data['${effectivePrefix}updated_occurred_at'],
      )!,
      updatedDeviceId: attachedDatabase.typeMapping.read(
        DriftSqlType.string,
        data['${effectivePrefix}updated_device_id'],
      ),
      deletedAt: attachedDatabase.typeMapping.read(
        DriftSqlType.string,
        data['${effectivePrefix}deleted_at'],
      ),
    );
  }

  @override
  $ProductsTable createAlias(String alias) {
    return $ProductsTable(attachedDatabase, alias);
  }
}

class Product extends DataClass implements Insertable<Product> {
  final String id;
  final String name;
  final int unitPriceKurus;
  final String unit;
  final bool isActive;
  final String updatedOccurredAt;
  final String? updatedDeviceId;
  final String? deletedAt;
  const Product({
    required this.id,
    required this.name,
    required this.unitPriceKurus,
    required this.unit,
    required this.isActive,
    required this.updatedOccurredAt,
    this.updatedDeviceId,
    this.deletedAt,
  });
  @override
  Map<String, Expression> toColumns(bool nullToAbsent) {
    final map = <String, Expression>{};
    map['id'] = Variable<String>(id);
    map['name'] = Variable<String>(name);
    map['unit_price_kurus'] = Variable<int>(unitPriceKurus);
    map['unit'] = Variable<String>(unit);
    map['is_active'] = Variable<bool>(isActive);
    map['updated_occurred_at'] = Variable<String>(updatedOccurredAt);
    if (!nullToAbsent || updatedDeviceId != null) {
      map['updated_device_id'] = Variable<String>(updatedDeviceId);
    }
    if (!nullToAbsent || deletedAt != null) {
      map['deleted_at'] = Variable<String>(deletedAt);
    }
    return map;
  }

  ProductsCompanion toCompanion(bool nullToAbsent) {
    return ProductsCompanion(
      id: Value(id),
      name: Value(name),
      unitPriceKurus: Value(unitPriceKurus),
      unit: Value(unit),
      isActive: Value(isActive),
      updatedOccurredAt: Value(updatedOccurredAt),
      updatedDeviceId: updatedDeviceId == null && nullToAbsent
          ? const Value.absent()
          : Value(updatedDeviceId),
      deletedAt: deletedAt == null && nullToAbsent
          ? const Value.absent()
          : Value(deletedAt),
    );
  }

  factory Product.fromJson(
    Map<String, dynamic> json, {
    ValueSerializer? serializer,
  }) {
    serializer ??= driftRuntimeOptions.defaultSerializer;
    return Product(
      id: serializer.fromJson<String>(json['id']),
      name: serializer.fromJson<String>(json['name']),
      unitPriceKurus: serializer.fromJson<int>(json['unitPriceKurus']),
      unit: serializer.fromJson<String>(json['unit']),
      isActive: serializer.fromJson<bool>(json['isActive']),
      updatedOccurredAt: serializer.fromJson<String>(json['updatedOccurredAt']),
      updatedDeviceId: serializer.fromJson<String?>(json['updatedDeviceId']),
      deletedAt: serializer.fromJson<String?>(json['deletedAt']),
    );
  }
  @override
  Map<String, dynamic> toJson({ValueSerializer? serializer}) {
    serializer ??= driftRuntimeOptions.defaultSerializer;
    return <String, dynamic>{
      'id': serializer.toJson<String>(id),
      'name': serializer.toJson<String>(name),
      'unitPriceKurus': serializer.toJson<int>(unitPriceKurus),
      'unit': serializer.toJson<String>(unit),
      'isActive': serializer.toJson<bool>(isActive),
      'updatedOccurredAt': serializer.toJson<String>(updatedOccurredAt),
      'updatedDeviceId': serializer.toJson<String?>(updatedDeviceId),
      'deletedAt': serializer.toJson<String?>(deletedAt),
    };
  }

  Product copyWith({
    String? id,
    String? name,
    int? unitPriceKurus,
    String? unit,
    bool? isActive,
    String? updatedOccurredAt,
    Value<String?> updatedDeviceId = const Value.absent(),
    Value<String?> deletedAt = const Value.absent(),
  }) => Product(
    id: id ?? this.id,
    name: name ?? this.name,
    unitPriceKurus: unitPriceKurus ?? this.unitPriceKurus,
    unit: unit ?? this.unit,
    isActive: isActive ?? this.isActive,
    updatedOccurredAt: updatedOccurredAt ?? this.updatedOccurredAt,
    updatedDeviceId: updatedDeviceId.present
        ? updatedDeviceId.value
        : this.updatedDeviceId,
    deletedAt: deletedAt.present ? deletedAt.value : this.deletedAt,
  );
  Product copyWithCompanion(ProductsCompanion data) {
    return Product(
      id: data.id.present ? data.id.value : this.id,
      name: data.name.present ? data.name.value : this.name,
      unitPriceKurus: data.unitPriceKurus.present
          ? data.unitPriceKurus.value
          : this.unitPriceKurus,
      unit: data.unit.present ? data.unit.value : this.unit,
      isActive: data.isActive.present ? data.isActive.value : this.isActive,
      updatedOccurredAt: data.updatedOccurredAt.present
          ? data.updatedOccurredAt.value
          : this.updatedOccurredAt,
      updatedDeviceId: data.updatedDeviceId.present
          ? data.updatedDeviceId.value
          : this.updatedDeviceId,
      deletedAt: data.deletedAt.present ? data.deletedAt.value : this.deletedAt,
    );
  }

  @override
  String toString() {
    return (StringBuffer('Product(')
          ..write('id: $id, ')
          ..write('name: $name, ')
          ..write('unitPriceKurus: $unitPriceKurus, ')
          ..write('unit: $unit, ')
          ..write('isActive: $isActive, ')
          ..write('updatedOccurredAt: $updatedOccurredAt, ')
          ..write('updatedDeviceId: $updatedDeviceId, ')
          ..write('deletedAt: $deletedAt')
          ..write(')'))
        .toString();
  }

  @override
  int get hashCode => Object.hash(
    id,
    name,
    unitPriceKurus,
    unit,
    isActive,
    updatedOccurredAt,
    updatedDeviceId,
    deletedAt,
  );
  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      (other is Product &&
          other.id == this.id &&
          other.name == this.name &&
          other.unitPriceKurus == this.unitPriceKurus &&
          other.unit == this.unit &&
          other.isActive == this.isActive &&
          other.updatedOccurredAt == this.updatedOccurredAt &&
          other.updatedDeviceId == this.updatedDeviceId &&
          other.deletedAt == this.deletedAt);
}

class ProductsCompanion extends UpdateCompanion<Product> {
  final Value<String> id;
  final Value<String> name;
  final Value<int> unitPriceKurus;
  final Value<String> unit;
  final Value<bool> isActive;
  final Value<String> updatedOccurredAt;
  final Value<String?> updatedDeviceId;
  final Value<String?> deletedAt;
  final Value<int> rowid;
  const ProductsCompanion({
    this.id = const Value.absent(),
    this.name = const Value.absent(),
    this.unitPriceKurus = const Value.absent(),
    this.unit = const Value.absent(),
    this.isActive = const Value.absent(),
    this.updatedOccurredAt = const Value.absent(),
    this.updatedDeviceId = const Value.absent(),
    this.deletedAt = const Value.absent(),
    this.rowid = const Value.absent(),
  });
  ProductsCompanion.insert({
    required String id,
    required String name,
    required int unitPriceKurus,
    this.unit = const Value.absent(),
    this.isActive = const Value.absent(),
    required String updatedOccurredAt,
    this.updatedDeviceId = const Value.absent(),
    this.deletedAt = const Value.absent(),
    this.rowid = const Value.absent(),
  }) : id = Value(id),
       name = Value(name),
       unitPriceKurus = Value(unitPriceKurus),
       updatedOccurredAt = Value(updatedOccurredAt);
  static Insertable<Product> custom({
    Expression<String>? id,
    Expression<String>? name,
    Expression<int>? unitPriceKurus,
    Expression<String>? unit,
    Expression<bool>? isActive,
    Expression<String>? updatedOccurredAt,
    Expression<String>? updatedDeviceId,
    Expression<String>? deletedAt,
    Expression<int>? rowid,
  }) {
    return RawValuesInsertable({
      if (id != null) 'id': id,
      if (name != null) 'name': name,
      if (unitPriceKurus != null) 'unit_price_kurus': unitPriceKurus,
      if (unit != null) 'unit': unit,
      if (isActive != null) 'is_active': isActive,
      if (updatedOccurredAt != null) 'updated_occurred_at': updatedOccurredAt,
      if (updatedDeviceId != null) 'updated_device_id': updatedDeviceId,
      if (deletedAt != null) 'deleted_at': deletedAt,
      if (rowid != null) 'rowid': rowid,
    });
  }

  ProductsCompanion copyWith({
    Value<String>? id,
    Value<String>? name,
    Value<int>? unitPriceKurus,
    Value<String>? unit,
    Value<bool>? isActive,
    Value<String>? updatedOccurredAt,
    Value<String?>? updatedDeviceId,
    Value<String?>? deletedAt,
    Value<int>? rowid,
  }) {
    return ProductsCompanion(
      id: id ?? this.id,
      name: name ?? this.name,
      unitPriceKurus: unitPriceKurus ?? this.unitPriceKurus,
      unit: unit ?? this.unit,
      isActive: isActive ?? this.isActive,
      updatedOccurredAt: updatedOccurredAt ?? this.updatedOccurredAt,
      updatedDeviceId: updatedDeviceId ?? this.updatedDeviceId,
      deletedAt: deletedAt ?? this.deletedAt,
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
    if (unitPriceKurus.present) {
      map['unit_price_kurus'] = Variable<int>(unitPriceKurus.value);
    }
    if (unit.present) {
      map['unit'] = Variable<String>(unit.value);
    }
    if (isActive.present) {
      map['is_active'] = Variable<bool>(isActive.value);
    }
    if (updatedOccurredAt.present) {
      map['updated_occurred_at'] = Variable<String>(updatedOccurredAt.value);
    }
    if (updatedDeviceId.present) {
      map['updated_device_id'] = Variable<String>(updatedDeviceId.value);
    }
    if (deletedAt.present) {
      map['deleted_at'] = Variable<String>(deletedAt.value);
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
          ..write('unitPriceKurus: $unitPriceKurus, ')
          ..write('unit: $unit, ')
          ..write('isActive: $isActive, ')
          ..write('updatedOccurredAt: $updatedOccurredAt, ')
          ..write('updatedDeviceId: $updatedDeviceId, ')
          ..write('deletedAt: $deletedAt, ')
          ..write('rowid: $rowid')
          ..write(')'))
        .toString();
  }
}

class $OrdersTable extends Orders with TableInfo<$OrdersTable, Order> {
  @override
  final GeneratedDatabase attachedDatabase;
  final String? _alias;
  $OrdersTable(this.attachedDatabase, [this._alias]);
  static const VerificationMeta _idMeta = const VerificationMeta('id');
  @override
  late final GeneratedColumn<String> id = GeneratedColumn<String>(
    'id',
    aliasedName,
    false,
    type: DriftSqlType.string,
    requiredDuringInsert: true,
  );
  static const VerificationMeta _customerIdMeta = const VerificationMeta(
    'customerId',
  );
  @override
  late final GeneratedColumn<String> customerId = GeneratedColumn<String>(
    'customer_id',
    aliasedName,
    true,
    type: DriftSqlType.string,
    requiredDuringInsert: false,
  );
  static const VerificationMeta _statusMeta = const VerificationMeta('status');
  @override
  late final GeneratedColumn<String> status = GeneratedColumn<String>(
    'status',
    aliasedName,
    false,
    type: DriftSqlType.string,
    requiredDuringInsert: false,
    defaultValue: const Constant('open'),
  );
  static const VerificationMeta _totalKurusMeta = const VerificationMeta(
    'totalKurus',
  );
  @override
  late final GeneratedColumn<int> totalKurus = GeneratedColumn<int>(
    'total_kurus',
    aliasedName,
    false,
    type: DriftSqlType.int,
    requiredDuringInsert: false,
    defaultValue: const Constant(0),
  );
  static const VerificationMeta _paymentTypeMeta = const VerificationMeta(
    'paymentType',
  );
  @override
  late final GeneratedColumn<String> paymentType = GeneratedColumn<String>(
    'payment_type',
    aliasedName,
    true,
    type: DriftSqlType.string,
    requiredDuringInsert: false,
  );
  static const VerificationMeta _noteMeta = const VerificationMeta('note');
  @override
  late final GeneratedColumn<String> note = GeneratedColumn<String>(
    'note',
    aliasedName,
    true,
    type: DriftSqlType.string,
    requiredDuringInsert: false,
  );
  static const VerificationMeta _occurredAtMeta = const VerificationMeta(
    'occurredAt',
  );
  @override
  late final GeneratedColumn<String> occurredAt = GeneratedColumn<String>(
    'occurred_at',
    aliasedName,
    false,
    type: DriftSqlType.string,
    requiredDuringInsert: true,
  );
  static const VerificationMeta _createdDeviceIdMeta = const VerificationMeta(
    'createdDeviceId',
  );
  @override
  late final GeneratedColumn<String> createdDeviceId = GeneratedColumn<String>(
    'created_device_id',
    aliasedName,
    true,
    type: DriftSqlType.string,
    requiredDuringInsert: false,
  );
  static const VerificationMeta _deletedAtMeta = const VerificationMeta(
    'deletedAt',
  );
  @override
  late final GeneratedColumn<String> deletedAt = GeneratedColumn<String>(
    'deleted_at',
    aliasedName,
    true,
    type: DriftSqlType.string,
    requiredDuringInsert: false,
  );
  @override
  List<GeneratedColumn> get $columns => [
    id,
    customerId,
    status,
    totalKurus,
    paymentType,
    note,
    occurredAt,
    createdDeviceId,
    deletedAt,
  ];
  @override
  String get aliasedName => _alias ?? actualTableName;
  @override
  String get actualTableName => $name;
  static const String $name = 'orders';
  @override
  VerificationContext validateIntegrity(
    Insertable<Order> instance, {
    bool isInserting = false,
  }) {
    final context = VerificationContext();
    final data = instance.toColumns(true);
    if (data.containsKey('id')) {
      context.handle(_idMeta, id.isAcceptableOrUnknown(data['id']!, _idMeta));
    } else if (isInserting) {
      context.missing(_idMeta);
    }
    if (data.containsKey('customer_id')) {
      context.handle(
        _customerIdMeta,
        customerId.isAcceptableOrUnknown(data['customer_id']!, _customerIdMeta),
      );
    }
    if (data.containsKey('status')) {
      context.handle(
        _statusMeta,
        status.isAcceptableOrUnknown(data['status']!, _statusMeta),
      );
    }
    if (data.containsKey('total_kurus')) {
      context.handle(
        _totalKurusMeta,
        totalKurus.isAcceptableOrUnknown(data['total_kurus']!, _totalKurusMeta),
      );
    }
    if (data.containsKey('payment_type')) {
      context.handle(
        _paymentTypeMeta,
        paymentType.isAcceptableOrUnknown(
          data['payment_type']!,
          _paymentTypeMeta,
        ),
      );
    }
    if (data.containsKey('note')) {
      context.handle(
        _noteMeta,
        note.isAcceptableOrUnknown(data['note']!, _noteMeta),
      );
    }
    if (data.containsKey('occurred_at')) {
      context.handle(
        _occurredAtMeta,
        occurredAt.isAcceptableOrUnknown(data['occurred_at']!, _occurredAtMeta),
      );
    } else if (isInserting) {
      context.missing(_occurredAtMeta);
    }
    if (data.containsKey('created_device_id')) {
      context.handle(
        _createdDeviceIdMeta,
        createdDeviceId.isAcceptableOrUnknown(
          data['created_device_id']!,
          _createdDeviceIdMeta,
        ),
      );
    }
    if (data.containsKey('deleted_at')) {
      context.handle(
        _deletedAtMeta,
        deletedAt.isAcceptableOrUnknown(data['deleted_at']!, _deletedAtMeta),
      );
    }
    return context;
  }

  @override
  Set<GeneratedColumn> get $primaryKey => {id};
  @override
  Order map(Map<String, dynamic> data, {String? tablePrefix}) {
    final effectivePrefix = tablePrefix != null ? '$tablePrefix.' : '';
    return Order(
      id: attachedDatabase.typeMapping.read(
        DriftSqlType.string,
        data['${effectivePrefix}id'],
      )!,
      customerId: attachedDatabase.typeMapping.read(
        DriftSqlType.string,
        data['${effectivePrefix}customer_id'],
      ),
      status: attachedDatabase.typeMapping.read(
        DriftSqlType.string,
        data['${effectivePrefix}status'],
      )!,
      totalKurus: attachedDatabase.typeMapping.read(
        DriftSqlType.int,
        data['${effectivePrefix}total_kurus'],
      )!,
      paymentType: attachedDatabase.typeMapping.read(
        DriftSqlType.string,
        data['${effectivePrefix}payment_type'],
      ),
      note: attachedDatabase.typeMapping.read(
        DriftSqlType.string,
        data['${effectivePrefix}note'],
      ),
      occurredAt: attachedDatabase.typeMapping.read(
        DriftSqlType.string,
        data['${effectivePrefix}occurred_at'],
      )!,
      createdDeviceId: attachedDatabase.typeMapping.read(
        DriftSqlType.string,
        data['${effectivePrefix}created_device_id'],
      ),
      deletedAt: attachedDatabase.typeMapping.read(
        DriftSqlType.string,
        data['${effectivePrefix}deleted_at'],
      ),
    );
  }

  @override
  $OrdersTable createAlias(String alias) {
    return $OrdersTable(attachedDatabase, alias);
  }
}

class Order extends DataClass implements Insertable<Order> {
  final String id;
  final String? customerId;

  /// ÖNBELLEK — kaynak order_events (DECISIONS). status: open|delivered|cancelled.
  final String status;
  final int totalKurus;
  final String? paymentType;
  final String? note;
  final String occurredAt;
  final String? createdDeviceId;
  final String? deletedAt;
  const Order({
    required this.id,
    this.customerId,
    required this.status,
    required this.totalKurus,
    this.paymentType,
    this.note,
    required this.occurredAt,
    this.createdDeviceId,
    this.deletedAt,
  });
  @override
  Map<String, Expression> toColumns(bool nullToAbsent) {
    final map = <String, Expression>{};
    map['id'] = Variable<String>(id);
    if (!nullToAbsent || customerId != null) {
      map['customer_id'] = Variable<String>(customerId);
    }
    map['status'] = Variable<String>(status);
    map['total_kurus'] = Variable<int>(totalKurus);
    if (!nullToAbsent || paymentType != null) {
      map['payment_type'] = Variable<String>(paymentType);
    }
    if (!nullToAbsent || note != null) {
      map['note'] = Variable<String>(note);
    }
    map['occurred_at'] = Variable<String>(occurredAt);
    if (!nullToAbsent || createdDeviceId != null) {
      map['created_device_id'] = Variable<String>(createdDeviceId);
    }
    if (!nullToAbsent || deletedAt != null) {
      map['deleted_at'] = Variable<String>(deletedAt);
    }
    return map;
  }

  OrdersCompanion toCompanion(bool nullToAbsent) {
    return OrdersCompanion(
      id: Value(id),
      customerId: customerId == null && nullToAbsent
          ? const Value.absent()
          : Value(customerId),
      status: Value(status),
      totalKurus: Value(totalKurus),
      paymentType: paymentType == null && nullToAbsent
          ? const Value.absent()
          : Value(paymentType),
      note: note == null && nullToAbsent ? const Value.absent() : Value(note),
      occurredAt: Value(occurredAt),
      createdDeviceId: createdDeviceId == null && nullToAbsent
          ? const Value.absent()
          : Value(createdDeviceId),
      deletedAt: deletedAt == null && nullToAbsent
          ? const Value.absent()
          : Value(deletedAt),
    );
  }

  factory Order.fromJson(
    Map<String, dynamic> json, {
    ValueSerializer? serializer,
  }) {
    serializer ??= driftRuntimeOptions.defaultSerializer;
    return Order(
      id: serializer.fromJson<String>(json['id']),
      customerId: serializer.fromJson<String?>(json['customerId']),
      status: serializer.fromJson<String>(json['status']),
      totalKurus: serializer.fromJson<int>(json['totalKurus']),
      paymentType: serializer.fromJson<String?>(json['paymentType']),
      note: serializer.fromJson<String?>(json['note']),
      occurredAt: serializer.fromJson<String>(json['occurredAt']),
      createdDeviceId: serializer.fromJson<String?>(json['createdDeviceId']),
      deletedAt: serializer.fromJson<String?>(json['deletedAt']),
    );
  }
  @override
  Map<String, dynamic> toJson({ValueSerializer? serializer}) {
    serializer ??= driftRuntimeOptions.defaultSerializer;
    return <String, dynamic>{
      'id': serializer.toJson<String>(id),
      'customerId': serializer.toJson<String?>(customerId),
      'status': serializer.toJson<String>(status),
      'totalKurus': serializer.toJson<int>(totalKurus),
      'paymentType': serializer.toJson<String?>(paymentType),
      'note': serializer.toJson<String?>(note),
      'occurredAt': serializer.toJson<String>(occurredAt),
      'createdDeviceId': serializer.toJson<String?>(createdDeviceId),
      'deletedAt': serializer.toJson<String?>(deletedAt),
    };
  }

  Order copyWith({
    String? id,
    Value<String?> customerId = const Value.absent(),
    String? status,
    int? totalKurus,
    Value<String?> paymentType = const Value.absent(),
    Value<String?> note = const Value.absent(),
    String? occurredAt,
    Value<String?> createdDeviceId = const Value.absent(),
    Value<String?> deletedAt = const Value.absent(),
  }) => Order(
    id: id ?? this.id,
    customerId: customerId.present ? customerId.value : this.customerId,
    status: status ?? this.status,
    totalKurus: totalKurus ?? this.totalKurus,
    paymentType: paymentType.present ? paymentType.value : this.paymentType,
    note: note.present ? note.value : this.note,
    occurredAt: occurredAt ?? this.occurredAt,
    createdDeviceId: createdDeviceId.present
        ? createdDeviceId.value
        : this.createdDeviceId,
    deletedAt: deletedAt.present ? deletedAt.value : this.deletedAt,
  );
  Order copyWithCompanion(OrdersCompanion data) {
    return Order(
      id: data.id.present ? data.id.value : this.id,
      customerId: data.customerId.present
          ? data.customerId.value
          : this.customerId,
      status: data.status.present ? data.status.value : this.status,
      totalKurus: data.totalKurus.present
          ? data.totalKurus.value
          : this.totalKurus,
      paymentType: data.paymentType.present
          ? data.paymentType.value
          : this.paymentType,
      note: data.note.present ? data.note.value : this.note,
      occurredAt: data.occurredAt.present
          ? data.occurredAt.value
          : this.occurredAt,
      createdDeviceId: data.createdDeviceId.present
          ? data.createdDeviceId.value
          : this.createdDeviceId,
      deletedAt: data.deletedAt.present ? data.deletedAt.value : this.deletedAt,
    );
  }

  @override
  String toString() {
    return (StringBuffer('Order(')
          ..write('id: $id, ')
          ..write('customerId: $customerId, ')
          ..write('status: $status, ')
          ..write('totalKurus: $totalKurus, ')
          ..write('paymentType: $paymentType, ')
          ..write('note: $note, ')
          ..write('occurredAt: $occurredAt, ')
          ..write('createdDeviceId: $createdDeviceId, ')
          ..write('deletedAt: $deletedAt')
          ..write(')'))
        .toString();
  }

  @override
  int get hashCode => Object.hash(
    id,
    customerId,
    status,
    totalKurus,
    paymentType,
    note,
    occurredAt,
    createdDeviceId,
    deletedAt,
  );
  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      (other is Order &&
          other.id == this.id &&
          other.customerId == this.customerId &&
          other.status == this.status &&
          other.totalKurus == this.totalKurus &&
          other.paymentType == this.paymentType &&
          other.note == this.note &&
          other.occurredAt == this.occurredAt &&
          other.createdDeviceId == this.createdDeviceId &&
          other.deletedAt == this.deletedAt);
}

class OrdersCompanion extends UpdateCompanion<Order> {
  final Value<String> id;
  final Value<String?> customerId;
  final Value<String> status;
  final Value<int> totalKurus;
  final Value<String?> paymentType;
  final Value<String?> note;
  final Value<String> occurredAt;
  final Value<String?> createdDeviceId;
  final Value<String?> deletedAt;
  final Value<int> rowid;
  const OrdersCompanion({
    this.id = const Value.absent(),
    this.customerId = const Value.absent(),
    this.status = const Value.absent(),
    this.totalKurus = const Value.absent(),
    this.paymentType = const Value.absent(),
    this.note = const Value.absent(),
    this.occurredAt = const Value.absent(),
    this.createdDeviceId = const Value.absent(),
    this.deletedAt = const Value.absent(),
    this.rowid = const Value.absent(),
  });
  OrdersCompanion.insert({
    required String id,
    this.customerId = const Value.absent(),
    this.status = const Value.absent(),
    this.totalKurus = const Value.absent(),
    this.paymentType = const Value.absent(),
    this.note = const Value.absent(),
    required String occurredAt,
    this.createdDeviceId = const Value.absent(),
    this.deletedAt = const Value.absent(),
    this.rowid = const Value.absent(),
  }) : id = Value(id),
       occurredAt = Value(occurredAt);
  static Insertable<Order> custom({
    Expression<String>? id,
    Expression<String>? customerId,
    Expression<String>? status,
    Expression<int>? totalKurus,
    Expression<String>? paymentType,
    Expression<String>? note,
    Expression<String>? occurredAt,
    Expression<String>? createdDeviceId,
    Expression<String>? deletedAt,
    Expression<int>? rowid,
  }) {
    return RawValuesInsertable({
      if (id != null) 'id': id,
      if (customerId != null) 'customer_id': customerId,
      if (status != null) 'status': status,
      if (totalKurus != null) 'total_kurus': totalKurus,
      if (paymentType != null) 'payment_type': paymentType,
      if (note != null) 'note': note,
      if (occurredAt != null) 'occurred_at': occurredAt,
      if (createdDeviceId != null) 'created_device_id': createdDeviceId,
      if (deletedAt != null) 'deleted_at': deletedAt,
      if (rowid != null) 'rowid': rowid,
    });
  }

  OrdersCompanion copyWith({
    Value<String>? id,
    Value<String?>? customerId,
    Value<String>? status,
    Value<int>? totalKurus,
    Value<String?>? paymentType,
    Value<String?>? note,
    Value<String>? occurredAt,
    Value<String?>? createdDeviceId,
    Value<String?>? deletedAt,
    Value<int>? rowid,
  }) {
    return OrdersCompanion(
      id: id ?? this.id,
      customerId: customerId ?? this.customerId,
      status: status ?? this.status,
      totalKurus: totalKurus ?? this.totalKurus,
      paymentType: paymentType ?? this.paymentType,
      note: note ?? this.note,
      occurredAt: occurredAt ?? this.occurredAt,
      createdDeviceId: createdDeviceId ?? this.createdDeviceId,
      deletedAt: deletedAt ?? this.deletedAt,
      rowid: rowid ?? this.rowid,
    );
  }

  @override
  Map<String, Expression> toColumns(bool nullToAbsent) {
    final map = <String, Expression>{};
    if (id.present) {
      map['id'] = Variable<String>(id.value);
    }
    if (customerId.present) {
      map['customer_id'] = Variable<String>(customerId.value);
    }
    if (status.present) {
      map['status'] = Variable<String>(status.value);
    }
    if (totalKurus.present) {
      map['total_kurus'] = Variable<int>(totalKurus.value);
    }
    if (paymentType.present) {
      map['payment_type'] = Variable<String>(paymentType.value);
    }
    if (note.present) {
      map['note'] = Variable<String>(note.value);
    }
    if (occurredAt.present) {
      map['occurred_at'] = Variable<String>(occurredAt.value);
    }
    if (createdDeviceId.present) {
      map['created_device_id'] = Variable<String>(createdDeviceId.value);
    }
    if (deletedAt.present) {
      map['deleted_at'] = Variable<String>(deletedAt.value);
    }
    if (rowid.present) {
      map['rowid'] = Variable<int>(rowid.value);
    }
    return map;
  }

  @override
  String toString() {
    return (StringBuffer('OrdersCompanion(')
          ..write('id: $id, ')
          ..write('customerId: $customerId, ')
          ..write('status: $status, ')
          ..write('totalKurus: $totalKurus, ')
          ..write('paymentType: $paymentType, ')
          ..write('note: $note, ')
          ..write('occurredAt: $occurredAt, ')
          ..write('createdDeviceId: $createdDeviceId, ')
          ..write('deletedAt: $deletedAt, ')
          ..write('rowid: $rowid')
          ..write(')'))
        .toString();
  }
}

class $OrderLinesTable extends OrderLines
    with TableInfo<$OrderLinesTable, OrderLine> {
  @override
  final GeneratedDatabase attachedDatabase;
  final String? _alias;
  $OrderLinesTable(this.attachedDatabase, [this._alias]);
  static const VerificationMeta _idMeta = const VerificationMeta('id');
  @override
  late final GeneratedColumn<String> id = GeneratedColumn<String>(
    'id',
    aliasedName,
    false,
    type: DriftSqlType.string,
    requiredDuringInsert: true,
  );
  static const VerificationMeta _orderIdMeta = const VerificationMeta(
    'orderId',
  );
  @override
  late final GeneratedColumn<String> orderId = GeneratedColumn<String>(
    'order_id',
    aliasedName,
    false,
    type: DriftSqlType.string,
    requiredDuringInsert: true,
  );
  static const VerificationMeta _productIdMeta = const VerificationMeta(
    'productId',
  );
  @override
  late final GeneratedColumn<String> productId = GeneratedColumn<String>(
    'product_id',
    aliasedName,
    true,
    type: DriftSqlType.string,
    requiredDuringInsert: false,
  );
  static const VerificationMeta _productNameMeta = const VerificationMeta(
    'productName',
  );
  @override
  late final GeneratedColumn<String> productName = GeneratedColumn<String>(
    'product_name',
    aliasedName,
    false,
    type: DriftSqlType.string,
    requiredDuringInsert: true,
  );
  static const VerificationMeta _unitPriceKurusMeta = const VerificationMeta(
    'unitPriceKurus',
  );
  @override
  late final GeneratedColumn<int> unitPriceKurus = GeneratedColumn<int>(
    'unit_price_kurus',
    aliasedName,
    false,
    type: DriftSqlType.int,
    requiredDuringInsert: true,
  );
  static const VerificationMeta _qtyMeta = const VerificationMeta('qty');
  @override
  late final GeneratedColumn<int> qty = GeneratedColumn<int>(
    'qty',
    aliasedName,
    false,
    type: DriftSqlType.int,
    requiredDuringInsert: true,
  );
  static const VerificationMeta _lineTotalKurusMeta = const VerificationMeta(
    'lineTotalKurus',
  );
  @override
  late final GeneratedColumn<int> lineTotalKurus = GeneratedColumn<int>(
    'line_total_kurus',
    aliasedName,
    false,
    type: DriftSqlType.int,
    requiredDuringInsert: true,
  );
  static const VerificationMeta _deletedAtMeta = const VerificationMeta(
    'deletedAt',
  );
  @override
  late final GeneratedColumn<String> deletedAt = GeneratedColumn<String>(
    'deleted_at',
    aliasedName,
    true,
    type: DriftSqlType.string,
    requiredDuringInsert: false,
  );
  @override
  List<GeneratedColumn> get $columns => [
    id,
    orderId,
    productId,
    productName,
    unitPriceKurus,
    qty,
    lineTotalKurus,
    deletedAt,
  ];
  @override
  String get aliasedName => _alias ?? actualTableName;
  @override
  String get actualTableName => $name;
  static const String $name = 'order_lines';
  @override
  VerificationContext validateIntegrity(
    Insertable<OrderLine> instance, {
    bool isInserting = false,
  }) {
    final context = VerificationContext();
    final data = instance.toColumns(true);
    if (data.containsKey('id')) {
      context.handle(_idMeta, id.isAcceptableOrUnknown(data['id']!, _idMeta));
    } else if (isInserting) {
      context.missing(_idMeta);
    }
    if (data.containsKey('order_id')) {
      context.handle(
        _orderIdMeta,
        orderId.isAcceptableOrUnknown(data['order_id']!, _orderIdMeta),
      );
    } else if (isInserting) {
      context.missing(_orderIdMeta);
    }
    if (data.containsKey('product_id')) {
      context.handle(
        _productIdMeta,
        productId.isAcceptableOrUnknown(data['product_id']!, _productIdMeta),
      );
    }
    if (data.containsKey('product_name')) {
      context.handle(
        _productNameMeta,
        productName.isAcceptableOrUnknown(
          data['product_name']!,
          _productNameMeta,
        ),
      );
    } else if (isInserting) {
      context.missing(_productNameMeta);
    }
    if (data.containsKey('unit_price_kurus')) {
      context.handle(
        _unitPriceKurusMeta,
        unitPriceKurus.isAcceptableOrUnknown(
          data['unit_price_kurus']!,
          _unitPriceKurusMeta,
        ),
      );
    } else if (isInserting) {
      context.missing(_unitPriceKurusMeta);
    }
    if (data.containsKey('qty')) {
      context.handle(
        _qtyMeta,
        qty.isAcceptableOrUnknown(data['qty']!, _qtyMeta),
      );
    } else if (isInserting) {
      context.missing(_qtyMeta);
    }
    if (data.containsKey('line_total_kurus')) {
      context.handle(
        _lineTotalKurusMeta,
        lineTotalKurus.isAcceptableOrUnknown(
          data['line_total_kurus']!,
          _lineTotalKurusMeta,
        ),
      );
    } else if (isInserting) {
      context.missing(_lineTotalKurusMeta);
    }
    if (data.containsKey('deleted_at')) {
      context.handle(
        _deletedAtMeta,
        deletedAt.isAcceptableOrUnknown(data['deleted_at']!, _deletedAtMeta),
      );
    }
    return context;
  }

  @override
  Set<GeneratedColumn> get $primaryKey => {id};
  @override
  OrderLine map(Map<String, dynamic> data, {String? tablePrefix}) {
    final effectivePrefix = tablePrefix != null ? '$tablePrefix.' : '';
    return OrderLine(
      id: attachedDatabase.typeMapping.read(
        DriftSqlType.string,
        data['${effectivePrefix}id'],
      )!,
      orderId: attachedDatabase.typeMapping.read(
        DriftSqlType.string,
        data['${effectivePrefix}order_id'],
      )!,
      productId: attachedDatabase.typeMapping.read(
        DriftSqlType.string,
        data['${effectivePrefix}product_id'],
      ),
      productName: attachedDatabase.typeMapping.read(
        DriftSqlType.string,
        data['${effectivePrefix}product_name'],
      )!,
      unitPriceKurus: attachedDatabase.typeMapping.read(
        DriftSqlType.int,
        data['${effectivePrefix}unit_price_kurus'],
      )!,
      qty: attachedDatabase.typeMapping.read(
        DriftSqlType.int,
        data['${effectivePrefix}qty'],
      )!,
      lineTotalKurus: attachedDatabase.typeMapping.read(
        DriftSqlType.int,
        data['${effectivePrefix}line_total_kurus'],
      )!,
      deletedAt: attachedDatabase.typeMapping.read(
        DriftSqlType.string,
        data['${effectivePrefix}deleted_at'],
      ),
    );
  }

  @override
  $OrderLinesTable createAlias(String alias) {
    return $OrderLinesTable(attachedDatabase, alias);
  }
}

class OrderLine extends DataClass implements Insertable<OrderLine> {
  final String id;
  final String orderId;
  final String? productId;

  /// SATIRDA saklanır (DECISIONS: siparişin çekildiği andaki gerçek).
  final String productName;
  final int unitPriceKurus;
  final int qty;
  final int lineTotalKurus;
  final String? deletedAt;
  const OrderLine({
    required this.id,
    required this.orderId,
    this.productId,
    required this.productName,
    required this.unitPriceKurus,
    required this.qty,
    required this.lineTotalKurus,
    this.deletedAt,
  });
  @override
  Map<String, Expression> toColumns(bool nullToAbsent) {
    final map = <String, Expression>{};
    map['id'] = Variable<String>(id);
    map['order_id'] = Variable<String>(orderId);
    if (!nullToAbsent || productId != null) {
      map['product_id'] = Variable<String>(productId);
    }
    map['product_name'] = Variable<String>(productName);
    map['unit_price_kurus'] = Variable<int>(unitPriceKurus);
    map['qty'] = Variable<int>(qty);
    map['line_total_kurus'] = Variable<int>(lineTotalKurus);
    if (!nullToAbsent || deletedAt != null) {
      map['deleted_at'] = Variable<String>(deletedAt);
    }
    return map;
  }

  OrderLinesCompanion toCompanion(bool nullToAbsent) {
    return OrderLinesCompanion(
      id: Value(id),
      orderId: Value(orderId),
      productId: productId == null && nullToAbsent
          ? const Value.absent()
          : Value(productId),
      productName: Value(productName),
      unitPriceKurus: Value(unitPriceKurus),
      qty: Value(qty),
      lineTotalKurus: Value(lineTotalKurus),
      deletedAt: deletedAt == null && nullToAbsent
          ? const Value.absent()
          : Value(deletedAt),
    );
  }

  factory OrderLine.fromJson(
    Map<String, dynamic> json, {
    ValueSerializer? serializer,
  }) {
    serializer ??= driftRuntimeOptions.defaultSerializer;
    return OrderLine(
      id: serializer.fromJson<String>(json['id']),
      orderId: serializer.fromJson<String>(json['orderId']),
      productId: serializer.fromJson<String?>(json['productId']),
      productName: serializer.fromJson<String>(json['productName']),
      unitPriceKurus: serializer.fromJson<int>(json['unitPriceKurus']),
      qty: serializer.fromJson<int>(json['qty']),
      lineTotalKurus: serializer.fromJson<int>(json['lineTotalKurus']),
      deletedAt: serializer.fromJson<String?>(json['deletedAt']),
    );
  }
  @override
  Map<String, dynamic> toJson({ValueSerializer? serializer}) {
    serializer ??= driftRuntimeOptions.defaultSerializer;
    return <String, dynamic>{
      'id': serializer.toJson<String>(id),
      'orderId': serializer.toJson<String>(orderId),
      'productId': serializer.toJson<String?>(productId),
      'productName': serializer.toJson<String>(productName),
      'unitPriceKurus': serializer.toJson<int>(unitPriceKurus),
      'qty': serializer.toJson<int>(qty),
      'lineTotalKurus': serializer.toJson<int>(lineTotalKurus),
      'deletedAt': serializer.toJson<String?>(deletedAt),
    };
  }

  OrderLine copyWith({
    String? id,
    String? orderId,
    Value<String?> productId = const Value.absent(),
    String? productName,
    int? unitPriceKurus,
    int? qty,
    int? lineTotalKurus,
    Value<String?> deletedAt = const Value.absent(),
  }) => OrderLine(
    id: id ?? this.id,
    orderId: orderId ?? this.orderId,
    productId: productId.present ? productId.value : this.productId,
    productName: productName ?? this.productName,
    unitPriceKurus: unitPriceKurus ?? this.unitPriceKurus,
    qty: qty ?? this.qty,
    lineTotalKurus: lineTotalKurus ?? this.lineTotalKurus,
    deletedAt: deletedAt.present ? deletedAt.value : this.deletedAt,
  );
  OrderLine copyWithCompanion(OrderLinesCompanion data) {
    return OrderLine(
      id: data.id.present ? data.id.value : this.id,
      orderId: data.orderId.present ? data.orderId.value : this.orderId,
      productId: data.productId.present ? data.productId.value : this.productId,
      productName: data.productName.present
          ? data.productName.value
          : this.productName,
      unitPriceKurus: data.unitPriceKurus.present
          ? data.unitPriceKurus.value
          : this.unitPriceKurus,
      qty: data.qty.present ? data.qty.value : this.qty,
      lineTotalKurus: data.lineTotalKurus.present
          ? data.lineTotalKurus.value
          : this.lineTotalKurus,
      deletedAt: data.deletedAt.present ? data.deletedAt.value : this.deletedAt,
    );
  }

  @override
  String toString() {
    return (StringBuffer('OrderLine(')
          ..write('id: $id, ')
          ..write('orderId: $orderId, ')
          ..write('productId: $productId, ')
          ..write('productName: $productName, ')
          ..write('unitPriceKurus: $unitPriceKurus, ')
          ..write('qty: $qty, ')
          ..write('lineTotalKurus: $lineTotalKurus, ')
          ..write('deletedAt: $deletedAt')
          ..write(')'))
        .toString();
  }

  @override
  int get hashCode => Object.hash(
    id,
    orderId,
    productId,
    productName,
    unitPriceKurus,
    qty,
    lineTotalKurus,
    deletedAt,
  );
  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      (other is OrderLine &&
          other.id == this.id &&
          other.orderId == this.orderId &&
          other.productId == this.productId &&
          other.productName == this.productName &&
          other.unitPriceKurus == this.unitPriceKurus &&
          other.qty == this.qty &&
          other.lineTotalKurus == this.lineTotalKurus &&
          other.deletedAt == this.deletedAt);
}

class OrderLinesCompanion extends UpdateCompanion<OrderLine> {
  final Value<String> id;
  final Value<String> orderId;
  final Value<String?> productId;
  final Value<String> productName;
  final Value<int> unitPriceKurus;
  final Value<int> qty;
  final Value<int> lineTotalKurus;
  final Value<String?> deletedAt;
  final Value<int> rowid;
  const OrderLinesCompanion({
    this.id = const Value.absent(),
    this.orderId = const Value.absent(),
    this.productId = const Value.absent(),
    this.productName = const Value.absent(),
    this.unitPriceKurus = const Value.absent(),
    this.qty = const Value.absent(),
    this.lineTotalKurus = const Value.absent(),
    this.deletedAt = const Value.absent(),
    this.rowid = const Value.absent(),
  });
  OrderLinesCompanion.insert({
    required String id,
    required String orderId,
    this.productId = const Value.absent(),
    required String productName,
    required int unitPriceKurus,
    required int qty,
    required int lineTotalKurus,
    this.deletedAt = const Value.absent(),
    this.rowid = const Value.absent(),
  }) : id = Value(id),
       orderId = Value(orderId),
       productName = Value(productName),
       unitPriceKurus = Value(unitPriceKurus),
       qty = Value(qty),
       lineTotalKurus = Value(lineTotalKurus);
  static Insertable<OrderLine> custom({
    Expression<String>? id,
    Expression<String>? orderId,
    Expression<String>? productId,
    Expression<String>? productName,
    Expression<int>? unitPriceKurus,
    Expression<int>? qty,
    Expression<int>? lineTotalKurus,
    Expression<String>? deletedAt,
    Expression<int>? rowid,
  }) {
    return RawValuesInsertable({
      if (id != null) 'id': id,
      if (orderId != null) 'order_id': orderId,
      if (productId != null) 'product_id': productId,
      if (productName != null) 'product_name': productName,
      if (unitPriceKurus != null) 'unit_price_kurus': unitPriceKurus,
      if (qty != null) 'qty': qty,
      if (lineTotalKurus != null) 'line_total_kurus': lineTotalKurus,
      if (deletedAt != null) 'deleted_at': deletedAt,
      if (rowid != null) 'rowid': rowid,
    });
  }

  OrderLinesCompanion copyWith({
    Value<String>? id,
    Value<String>? orderId,
    Value<String?>? productId,
    Value<String>? productName,
    Value<int>? unitPriceKurus,
    Value<int>? qty,
    Value<int>? lineTotalKurus,
    Value<String?>? deletedAt,
    Value<int>? rowid,
  }) {
    return OrderLinesCompanion(
      id: id ?? this.id,
      orderId: orderId ?? this.orderId,
      productId: productId ?? this.productId,
      productName: productName ?? this.productName,
      unitPriceKurus: unitPriceKurus ?? this.unitPriceKurus,
      qty: qty ?? this.qty,
      lineTotalKurus: lineTotalKurus ?? this.lineTotalKurus,
      deletedAt: deletedAt ?? this.deletedAt,
      rowid: rowid ?? this.rowid,
    );
  }

  @override
  Map<String, Expression> toColumns(bool nullToAbsent) {
    final map = <String, Expression>{};
    if (id.present) {
      map['id'] = Variable<String>(id.value);
    }
    if (orderId.present) {
      map['order_id'] = Variable<String>(orderId.value);
    }
    if (productId.present) {
      map['product_id'] = Variable<String>(productId.value);
    }
    if (productName.present) {
      map['product_name'] = Variable<String>(productName.value);
    }
    if (unitPriceKurus.present) {
      map['unit_price_kurus'] = Variable<int>(unitPriceKurus.value);
    }
    if (qty.present) {
      map['qty'] = Variable<int>(qty.value);
    }
    if (lineTotalKurus.present) {
      map['line_total_kurus'] = Variable<int>(lineTotalKurus.value);
    }
    if (deletedAt.present) {
      map['deleted_at'] = Variable<String>(deletedAt.value);
    }
    if (rowid.present) {
      map['rowid'] = Variable<int>(rowid.value);
    }
    return map;
  }

  @override
  String toString() {
    return (StringBuffer('OrderLinesCompanion(')
          ..write('id: $id, ')
          ..write('orderId: $orderId, ')
          ..write('productId: $productId, ')
          ..write('productName: $productName, ')
          ..write('unitPriceKurus: $unitPriceKurus, ')
          ..write('qty: $qty, ')
          ..write('lineTotalKurus: $lineTotalKurus, ')
          ..write('deletedAt: $deletedAt, ')
          ..write('rowid: $rowid')
          ..write(')'))
        .toString();
  }
}

class $OrderEventsTable extends OrderEvents
    with TableInfo<$OrderEventsTable, OrderEvent> {
  @override
  final GeneratedDatabase attachedDatabase;
  final String? _alias;
  $OrderEventsTable(this.attachedDatabase, [this._alias]);
  static const VerificationMeta _idMeta = const VerificationMeta('id');
  @override
  late final GeneratedColumn<String> id = GeneratedColumn<String>(
    'id',
    aliasedName,
    false,
    type: DriftSqlType.string,
    requiredDuringInsert: true,
  );
  static const VerificationMeta _orderIdMeta = const VerificationMeta(
    'orderId',
  );
  @override
  late final GeneratedColumn<String> orderId = GeneratedColumn<String>(
    'order_id',
    aliasedName,
    false,
    type: DriftSqlType.string,
    requiredDuringInsert: true,
  );
  static const VerificationMeta _eventTypeMeta = const VerificationMeta(
    'eventType',
  );
  @override
  late final GeneratedColumn<String> eventType = GeneratedColumn<String>(
    'event_type',
    aliasedName,
    false,
    type: DriftSqlType.string,
    requiredDuringInsert: true,
  );
  static const VerificationMeta _payloadMeta = const VerificationMeta(
    'payload',
  );
  @override
  late final GeneratedColumn<String> payload = GeneratedColumn<String>(
    'payload',
    aliasedName,
    true,
    type: DriftSqlType.string,
    requiredDuringInsert: false,
  );
  static const VerificationMeta _clientEventIdMeta = const VerificationMeta(
    'clientEventId',
  );
  @override
  late final GeneratedColumn<String> clientEventId = GeneratedColumn<String>(
    'client_event_id',
    aliasedName,
    false,
    type: DriftSqlType.string,
    requiredDuringInsert: true,
  );
  static const VerificationMeta _occurredAtMeta = const VerificationMeta(
    'occurredAt',
  );
  @override
  late final GeneratedColumn<String> occurredAt = GeneratedColumn<String>(
    'occurred_at',
    aliasedName,
    false,
    type: DriftSqlType.string,
    requiredDuringInsert: true,
  );
  static const VerificationMeta _deviceIdMeta = const VerificationMeta(
    'deviceId',
  );
  @override
  late final GeneratedColumn<String> deviceId = GeneratedColumn<String>(
    'device_id',
    aliasedName,
    true,
    type: DriftSqlType.string,
    requiredDuringInsert: false,
  );
  @override
  List<GeneratedColumn> get $columns => [
    id,
    orderId,
    eventType,
    payload,
    clientEventId,
    occurredAt,
    deviceId,
  ];
  @override
  String get aliasedName => _alias ?? actualTableName;
  @override
  String get actualTableName => $name;
  static const String $name = 'order_events';
  @override
  VerificationContext validateIntegrity(
    Insertable<OrderEvent> instance, {
    bool isInserting = false,
  }) {
    final context = VerificationContext();
    final data = instance.toColumns(true);
    if (data.containsKey('id')) {
      context.handle(_idMeta, id.isAcceptableOrUnknown(data['id']!, _idMeta));
    } else if (isInserting) {
      context.missing(_idMeta);
    }
    if (data.containsKey('order_id')) {
      context.handle(
        _orderIdMeta,
        orderId.isAcceptableOrUnknown(data['order_id']!, _orderIdMeta),
      );
    } else if (isInserting) {
      context.missing(_orderIdMeta);
    }
    if (data.containsKey('event_type')) {
      context.handle(
        _eventTypeMeta,
        eventType.isAcceptableOrUnknown(data['event_type']!, _eventTypeMeta),
      );
    } else if (isInserting) {
      context.missing(_eventTypeMeta);
    }
    if (data.containsKey('payload')) {
      context.handle(
        _payloadMeta,
        payload.isAcceptableOrUnknown(data['payload']!, _payloadMeta),
      );
    }
    if (data.containsKey('client_event_id')) {
      context.handle(
        _clientEventIdMeta,
        clientEventId.isAcceptableOrUnknown(
          data['client_event_id']!,
          _clientEventIdMeta,
        ),
      );
    } else if (isInserting) {
      context.missing(_clientEventIdMeta);
    }
    if (data.containsKey('occurred_at')) {
      context.handle(
        _occurredAtMeta,
        occurredAt.isAcceptableOrUnknown(data['occurred_at']!, _occurredAtMeta),
      );
    } else if (isInserting) {
      context.missing(_occurredAtMeta);
    }
    if (data.containsKey('device_id')) {
      context.handle(
        _deviceIdMeta,
        deviceId.isAcceptableOrUnknown(data['device_id']!, _deviceIdMeta),
      );
    }
    return context;
  }

  @override
  Set<GeneratedColumn> get $primaryKey => {id};
  @override
  List<Set<GeneratedColumn>> get uniqueKeys => [
    {clientEventId},
  ];
  @override
  OrderEvent map(Map<String, dynamic> data, {String? tablePrefix}) {
    final effectivePrefix = tablePrefix != null ? '$tablePrefix.' : '';
    return OrderEvent(
      id: attachedDatabase.typeMapping.read(
        DriftSqlType.string,
        data['${effectivePrefix}id'],
      )!,
      orderId: attachedDatabase.typeMapping.read(
        DriftSqlType.string,
        data['${effectivePrefix}order_id'],
      )!,
      eventType: attachedDatabase.typeMapping.read(
        DriftSqlType.string,
        data['${effectivePrefix}event_type'],
      )!,
      payload: attachedDatabase.typeMapping.read(
        DriftSqlType.string,
        data['${effectivePrefix}payload'],
      ),
      clientEventId: attachedDatabase.typeMapping.read(
        DriftSqlType.string,
        data['${effectivePrefix}client_event_id'],
      )!,
      occurredAt: attachedDatabase.typeMapping.read(
        DriftSqlType.string,
        data['${effectivePrefix}occurred_at'],
      )!,
      deviceId: attachedDatabase.typeMapping.read(
        DriftSqlType.string,
        data['${effectivePrefix}device_id'],
      ),
    );
  }

  @override
  $OrderEventsTable createAlias(String alias) {
    return $OrderEventsTable(attachedDatabase, alias);
  }
}

class OrderEvent extends DataClass implements Insertable<OrderEvent> {
  final String id;
  final String orderId;
  final String eventType;
  final String? payload;
  final String clientEventId;
  final String occurredAt;
  final String? deviceId;
  const OrderEvent({
    required this.id,
    required this.orderId,
    required this.eventType,
    this.payload,
    required this.clientEventId,
    required this.occurredAt,
    this.deviceId,
  });
  @override
  Map<String, Expression> toColumns(bool nullToAbsent) {
    final map = <String, Expression>{};
    map['id'] = Variable<String>(id);
    map['order_id'] = Variable<String>(orderId);
    map['event_type'] = Variable<String>(eventType);
    if (!nullToAbsent || payload != null) {
      map['payload'] = Variable<String>(payload);
    }
    map['client_event_id'] = Variable<String>(clientEventId);
    map['occurred_at'] = Variable<String>(occurredAt);
    if (!nullToAbsent || deviceId != null) {
      map['device_id'] = Variable<String>(deviceId);
    }
    return map;
  }

  OrderEventsCompanion toCompanion(bool nullToAbsent) {
    return OrderEventsCompanion(
      id: Value(id),
      orderId: Value(orderId),
      eventType: Value(eventType),
      payload: payload == null && nullToAbsent
          ? const Value.absent()
          : Value(payload),
      clientEventId: Value(clientEventId),
      occurredAt: Value(occurredAt),
      deviceId: deviceId == null && nullToAbsent
          ? const Value.absent()
          : Value(deviceId),
    );
  }

  factory OrderEvent.fromJson(
    Map<String, dynamic> json, {
    ValueSerializer? serializer,
  }) {
    serializer ??= driftRuntimeOptions.defaultSerializer;
    return OrderEvent(
      id: serializer.fromJson<String>(json['id']),
      orderId: serializer.fromJson<String>(json['orderId']),
      eventType: serializer.fromJson<String>(json['eventType']),
      payload: serializer.fromJson<String?>(json['payload']),
      clientEventId: serializer.fromJson<String>(json['clientEventId']),
      occurredAt: serializer.fromJson<String>(json['occurredAt']),
      deviceId: serializer.fromJson<String?>(json['deviceId']),
    );
  }
  @override
  Map<String, dynamic> toJson({ValueSerializer? serializer}) {
    serializer ??= driftRuntimeOptions.defaultSerializer;
    return <String, dynamic>{
      'id': serializer.toJson<String>(id),
      'orderId': serializer.toJson<String>(orderId),
      'eventType': serializer.toJson<String>(eventType),
      'payload': serializer.toJson<String?>(payload),
      'clientEventId': serializer.toJson<String>(clientEventId),
      'occurredAt': serializer.toJson<String>(occurredAt),
      'deviceId': serializer.toJson<String?>(deviceId),
    };
  }

  OrderEvent copyWith({
    String? id,
    String? orderId,
    String? eventType,
    Value<String?> payload = const Value.absent(),
    String? clientEventId,
    String? occurredAt,
    Value<String?> deviceId = const Value.absent(),
  }) => OrderEvent(
    id: id ?? this.id,
    orderId: orderId ?? this.orderId,
    eventType: eventType ?? this.eventType,
    payload: payload.present ? payload.value : this.payload,
    clientEventId: clientEventId ?? this.clientEventId,
    occurredAt: occurredAt ?? this.occurredAt,
    deviceId: deviceId.present ? deviceId.value : this.deviceId,
  );
  OrderEvent copyWithCompanion(OrderEventsCompanion data) {
    return OrderEvent(
      id: data.id.present ? data.id.value : this.id,
      orderId: data.orderId.present ? data.orderId.value : this.orderId,
      eventType: data.eventType.present ? data.eventType.value : this.eventType,
      payload: data.payload.present ? data.payload.value : this.payload,
      clientEventId: data.clientEventId.present
          ? data.clientEventId.value
          : this.clientEventId,
      occurredAt: data.occurredAt.present
          ? data.occurredAt.value
          : this.occurredAt,
      deviceId: data.deviceId.present ? data.deviceId.value : this.deviceId,
    );
  }

  @override
  String toString() {
    return (StringBuffer('OrderEvent(')
          ..write('id: $id, ')
          ..write('orderId: $orderId, ')
          ..write('eventType: $eventType, ')
          ..write('payload: $payload, ')
          ..write('clientEventId: $clientEventId, ')
          ..write('occurredAt: $occurredAt, ')
          ..write('deviceId: $deviceId')
          ..write(')'))
        .toString();
  }

  @override
  int get hashCode => Object.hash(
    id,
    orderId,
    eventType,
    payload,
    clientEventId,
    occurredAt,
    deviceId,
  );
  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      (other is OrderEvent &&
          other.id == this.id &&
          other.orderId == this.orderId &&
          other.eventType == this.eventType &&
          other.payload == this.payload &&
          other.clientEventId == this.clientEventId &&
          other.occurredAt == this.occurredAt &&
          other.deviceId == this.deviceId);
}

class OrderEventsCompanion extends UpdateCompanion<OrderEvent> {
  final Value<String> id;
  final Value<String> orderId;
  final Value<String> eventType;
  final Value<String?> payload;
  final Value<String> clientEventId;
  final Value<String> occurredAt;
  final Value<String?> deviceId;
  final Value<int> rowid;
  const OrderEventsCompanion({
    this.id = const Value.absent(),
    this.orderId = const Value.absent(),
    this.eventType = const Value.absent(),
    this.payload = const Value.absent(),
    this.clientEventId = const Value.absent(),
    this.occurredAt = const Value.absent(),
    this.deviceId = const Value.absent(),
    this.rowid = const Value.absent(),
  });
  OrderEventsCompanion.insert({
    required String id,
    required String orderId,
    required String eventType,
    this.payload = const Value.absent(),
    required String clientEventId,
    required String occurredAt,
    this.deviceId = const Value.absent(),
    this.rowid = const Value.absent(),
  }) : id = Value(id),
       orderId = Value(orderId),
       eventType = Value(eventType),
       clientEventId = Value(clientEventId),
       occurredAt = Value(occurredAt);
  static Insertable<OrderEvent> custom({
    Expression<String>? id,
    Expression<String>? orderId,
    Expression<String>? eventType,
    Expression<String>? payload,
    Expression<String>? clientEventId,
    Expression<String>? occurredAt,
    Expression<String>? deviceId,
    Expression<int>? rowid,
  }) {
    return RawValuesInsertable({
      if (id != null) 'id': id,
      if (orderId != null) 'order_id': orderId,
      if (eventType != null) 'event_type': eventType,
      if (payload != null) 'payload': payload,
      if (clientEventId != null) 'client_event_id': clientEventId,
      if (occurredAt != null) 'occurred_at': occurredAt,
      if (deviceId != null) 'device_id': deviceId,
      if (rowid != null) 'rowid': rowid,
    });
  }

  OrderEventsCompanion copyWith({
    Value<String>? id,
    Value<String>? orderId,
    Value<String>? eventType,
    Value<String?>? payload,
    Value<String>? clientEventId,
    Value<String>? occurredAt,
    Value<String?>? deviceId,
    Value<int>? rowid,
  }) {
    return OrderEventsCompanion(
      id: id ?? this.id,
      orderId: orderId ?? this.orderId,
      eventType: eventType ?? this.eventType,
      payload: payload ?? this.payload,
      clientEventId: clientEventId ?? this.clientEventId,
      occurredAt: occurredAt ?? this.occurredAt,
      deviceId: deviceId ?? this.deviceId,
      rowid: rowid ?? this.rowid,
    );
  }

  @override
  Map<String, Expression> toColumns(bool nullToAbsent) {
    final map = <String, Expression>{};
    if (id.present) {
      map['id'] = Variable<String>(id.value);
    }
    if (orderId.present) {
      map['order_id'] = Variable<String>(orderId.value);
    }
    if (eventType.present) {
      map['event_type'] = Variable<String>(eventType.value);
    }
    if (payload.present) {
      map['payload'] = Variable<String>(payload.value);
    }
    if (clientEventId.present) {
      map['client_event_id'] = Variable<String>(clientEventId.value);
    }
    if (occurredAt.present) {
      map['occurred_at'] = Variable<String>(occurredAt.value);
    }
    if (deviceId.present) {
      map['device_id'] = Variable<String>(deviceId.value);
    }
    if (rowid.present) {
      map['rowid'] = Variable<int>(rowid.value);
    }
    return map;
  }

  @override
  String toString() {
    return (StringBuffer('OrderEventsCompanion(')
          ..write('id: $id, ')
          ..write('orderId: $orderId, ')
          ..write('eventType: $eventType, ')
          ..write('payload: $payload, ')
          ..write('clientEventId: $clientEventId, ')
          ..write('occurredAt: $occurredAt, ')
          ..write('deviceId: $deviceId, ')
          ..write('rowid: $rowid')
          ..write(')'))
        .toString();
  }
}

class $LedgerEntriesTable extends LedgerEntries
    with TableInfo<$LedgerEntriesTable, LedgerEntry> {
  @override
  final GeneratedDatabase attachedDatabase;
  final String? _alias;
  $LedgerEntriesTable(this.attachedDatabase, [this._alias]);
  static const VerificationMeta _idMeta = const VerificationMeta('id');
  @override
  late final GeneratedColumn<String> id = GeneratedColumn<String>(
    'id',
    aliasedName,
    false,
    type: DriftSqlType.string,
    requiredDuringInsert: true,
  );
  static const VerificationMeta _customerIdMeta = const VerificationMeta(
    'customerId',
  );
  @override
  late final GeneratedColumn<String> customerId = GeneratedColumn<String>(
    'customer_id',
    aliasedName,
    true,
    type: DriftSqlType.string,
    requiredDuringInsert: false,
  );
  static const VerificationMeta _entryTypeMeta = const VerificationMeta(
    'entryType',
  );
  @override
  late final GeneratedColumn<String> entryType = GeneratedColumn<String>(
    'entry_type',
    aliasedName,
    false,
    type: DriftSqlType.string,
    requiredDuringInsert: true,
  );
  static const VerificationMeta _amountKurusMeta = const VerificationMeta(
    'amountKurus',
  );
  @override
  late final GeneratedColumn<int> amountKurus = GeneratedColumn<int>(
    'amount_kurus',
    aliasedName,
    false,
    type: DriftSqlType.int,
    requiredDuringInsert: true,
  );
  static const VerificationMeta _relatedOrderIdMeta = const VerificationMeta(
    'relatedOrderId',
  );
  @override
  late final GeneratedColumn<String> relatedOrderId = GeneratedColumn<String>(
    'related_order_id',
    aliasedName,
    true,
    type: DriftSqlType.string,
    requiredDuringInsert: false,
  );
  static const VerificationMeta _noteMeta = const VerificationMeta('note');
  @override
  late final GeneratedColumn<String> note = GeneratedColumn<String>(
    'note',
    aliasedName,
    true,
    type: DriftSqlType.string,
    requiredDuringInsert: false,
  );
  static const VerificationMeta _occurredAtMeta = const VerificationMeta(
    'occurredAt',
  );
  @override
  late final GeneratedColumn<String> occurredAt = GeneratedColumn<String>(
    'occurred_at',
    aliasedName,
    false,
    type: DriftSqlType.string,
    requiredDuringInsert: true,
  );
  static const VerificationMeta _deviceIdMeta = const VerificationMeta(
    'deviceId',
  );
  @override
  late final GeneratedColumn<String> deviceId = GeneratedColumn<String>(
    'device_id',
    aliasedName,
    true,
    type: DriftSqlType.string,
    requiredDuringInsert: false,
  );
  static const VerificationMeta _clientEventIdMeta = const VerificationMeta(
    'clientEventId',
  );
  @override
  late final GeneratedColumn<String> clientEventId = GeneratedColumn<String>(
    'client_event_id',
    aliasedName,
    false,
    type: DriftSqlType.string,
    requiredDuringInsert: true,
  );
  @override
  List<GeneratedColumn> get $columns => [
    id,
    customerId,
    entryType,
    amountKurus,
    relatedOrderId,
    note,
    occurredAt,
    deviceId,
    clientEventId,
  ];
  @override
  String get aliasedName => _alias ?? actualTableName;
  @override
  String get actualTableName => $name;
  static const String $name = 'ledger_entries';
  @override
  VerificationContext validateIntegrity(
    Insertable<LedgerEntry> instance, {
    bool isInserting = false,
  }) {
    final context = VerificationContext();
    final data = instance.toColumns(true);
    if (data.containsKey('id')) {
      context.handle(_idMeta, id.isAcceptableOrUnknown(data['id']!, _idMeta));
    } else if (isInserting) {
      context.missing(_idMeta);
    }
    if (data.containsKey('customer_id')) {
      context.handle(
        _customerIdMeta,
        customerId.isAcceptableOrUnknown(data['customer_id']!, _customerIdMeta),
      );
    }
    if (data.containsKey('entry_type')) {
      context.handle(
        _entryTypeMeta,
        entryType.isAcceptableOrUnknown(data['entry_type']!, _entryTypeMeta),
      );
    } else if (isInserting) {
      context.missing(_entryTypeMeta);
    }
    if (data.containsKey('amount_kurus')) {
      context.handle(
        _amountKurusMeta,
        amountKurus.isAcceptableOrUnknown(
          data['amount_kurus']!,
          _amountKurusMeta,
        ),
      );
    } else if (isInserting) {
      context.missing(_amountKurusMeta);
    }
    if (data.containsKey('related_order_id')) {
      context.handle(
        _relatedOrderIdMeta,
        relatedOrderId.isAcceptableOrUnknown(
          data['related_order_id']!,
          _relatedOrderIdMeta,
        ),
      );
    }
    if (data.containsKey('note')) {
      context.handle(
        _noteMeta,
        note.isAcceptableOrUnknown(data['note']!, _noteMeta),
      );
    }
    if (data.containsKey('occurred_at')) {
      context.handle(
        _occurredAtMeta,
        occurredAt.isAcceptableOrUnknown(data['occurred_at']!, _occurredAtMeta),
      );
    } else if (isInserting) {
      context.missing(_occurredAtMeta);
    }
    if (data.containsKey('device_id')) {
      context.handle(
        _deviceIdMeta,
        deviceId.isAcceptableOrUnknown(data['device_id']!, _deviceIdMeta),
      );
    }
    if (data.containsKey('client_event_id')) {
      context.handle(
        _clientEventIdMeta,
        clientEventId.isAcceptableOrUnknown(
          data['client_event_id']!,
          _clientEventIdMeta,
        ),
      );
    } else if (isInserting) {
      context.missing(_clientEventIdMeta);
    }
    return context;
  }

  @override
  Set<GeneratedColumn> get $primaryKey => {id};
  @override
  LedgerEntry map(Map<String, dynamic> data, {String? tablePrefix}) {
    final effectivePrefix = tablePrefix != null ? '$tablePrefix.' : '';
    return LedgerEntry(
      id: attachedDatabase.typeMapping.read(
        DriftSqlType.string,
        data['${effectivePrefix}id'],
      )!,
      customerId: attachedDatabase.typeMapping.read(
        DriftSqlType.string,
        data['${effectivePrefix}customer_id'],
      ),
      entryType: attachedDatabase.typeMapping.read(
        DriftSqlType.string,
        data['${effectivePrefix}entry_type'],
      )!,
      amountKurus: attachedDatabase.typeMapping.read(
        DriftSqlType.int,
        data['${effectivePrefix}amount_kurus'],
      )!,
      relatedOrderId: attachedDatabase.typeMapping.read(
        DriftSqlType.string,
        data['${effectivePrefix}related_order_id'],
      ),
      note: attachedDatabase.typeMapping.read(
        DriftSqlType.string,
        data['${effectivePrefix}note'],
      ),
      occurredAt: attachedDatabase.typeMapping.read(
        DriftSqlType.string,
        data['${effectivePrefix}occurred_at'],
      )!,
      deviceId: attachedDatabase.typeMapping.read(
        DriftSqlType.string,
        data['${effectivePrefix}device_id'],
      ),
      clientEventId: attachedDatabase.typeMapping.read(
        DriftSqlType.string,
        data['${effectivePrefix}client_event_id'],
      )!,
    );
  }

  @override
  $LedgerEntriesTable createAlias(String alias) {
    return $LedgerEntriesTable(attachedDatabase, alias);
  }
}

class LedgerEntry extends DataClass implements Insertable<LedgerEntry> {
  final String id;
  final String? customerId;
  final String entryType;
  final int amountKurus;
  final String? relatedOrderId;
  final String? note;
  final String occurredAt;
  final String? deviceId;
  final String clientEventId;
  const LedgerEntry({
    required this.id,
    this.customerId,
    required this.entryType,
    required this.amountKurus,
    this.relatedOrderId,
    this.note,
    required this.occurredAt,
    this.deviceId,
    required this.clientEventId,
  });
  @override
  Map<String, Expression> toColumns(bool nullToAbsent) {
    final map = <String, Expression>{};
    map['id'] = Variable<String>(id);
    if (!nullToAbsent || customerId != null) {
      map['customer_id'] = Variable<String>(customerId);
    }
    map['entry_type'] = Variable<String>(entryType);
    map['amount_kurus'] = Variable<int>(amountKurus);
    if (!nullToAbsent || relatedOrderId != null) {
      map['related_order_id'] = Variable<String>(relatedOrderId);
    }
    if (!nullToAbsent || note != null) {
      map['note'] = Variable<String>(note);
    }
    map['occurred_at'] = Variable<String>(occurredAt);
    if (!nullToAbsent || deviceId != null) {
      map['device_id'] = Variable<String>(deviceId);
    }
    map['client_event_id'] = Variable<String>(clientEventId);
    return map;
  }

  LedgerEntriesCompanion toCompanion(bool nullToAbsent) {
    return LedgerEntriesCompanion(
      id: Value(id),
      customerId: customerId == null && nullToAbsent
          ? const Value.absent()
          : Value(customerId),
      entryType: Value(entryType),
      amountKurus: Value(amountKurus),
      relatedOrderId: relatedOrderId == null && nullToAbsent
          ? const Value.absent()
          : Value(relatedOrderId),
      note: note == null && nullToAbsent ? const Value.absent() : Value(note),
      occurredAt: Value(occurredAt),
      deviceId: deviceId == null && nullToAbsent
          ? const Value.absent()
          : Value(deviceId),
      clientEventId: Value(clientEventId),
    );
  }

  factory LedgerEntry.fromJson(
    Map<String, dynamic> json, {
    ValueSerializer? serializer,
  }) {
    serializer ??= driftRuntimeOptions.defaultSerializer;
    return LedgerEntry(
      id: serializer.fromJson<String>(json['id']),
      customerId: serializer.fromJson<String?>(json['customerId']),
      entryType: serializer.fromJson<String>(json['entryType']),
      amountKurus: serializer.fromJson<int>(json['amountKurus']),
      relatedOrderId: serializer.fromJson<String?>(json['relatedOrderId']),
      note: serializer.fromJson<String?>(json['note']),
      occurredAt: serializer.fromJson<String>(json['occurredAt']),
      deviceId: serializer.fromJson<String?>(json['deviceId']),
      clientEventId: serializer.fromJson<String>(json['clientEventId']),
    );
  }
  @override
  Map<String, dynamic> toJson({ValueSerializer? serializer}) {
    serializer ??= driftRuntimeOptions.defaultSerializer;
    return <String, dynamic>{
      'id': serializer.toJson<String>(id),
      'customerId': serializer.toJson<String?>(customerId),
      'entryType': serializer.toJson<String>(entryType),
      'amountKurus': serializer.toJson<int>(amountKurus),
      'relatedOrderId': serializer.toJson<String?>(relatedOrderId),
      'note': serializer.toJson<String?>(note),
      'occurredAt': serializer.toJson<String>(occurredAt),
      'deviceId': serializer.toJson<String?>(deviceId),
      'clientEventId': serializer.toJson<String>(clientEventId),
    };
  }

  LedgerEntry copyWith({
    String? id,
    Value<String?> customerId = const Value.absent(),
    String? entryType,
    int? amountKurus,
    Value<String?> relatedOrderId = const Value.absent(),
    Value<String?> note = const Value.absent(),
    String? occurredAt,
    Value<String?> deviceId = const Value.absent(),
    String? clientEventId,
  }) => LedgerEntry(
    id: id ?? this.id,
    customerId: customerId.present ? customerId.value : this.customerId,
    entryType: entryType ?? this.entryType,
    amountKurus: amountKurus ?? this.amountKurus,
    relatedOrderId: relatedOrderId.present
        ? relatedOrderId.value
        : this.relatedOrderId,
    note: note.present ? note.value : this.note,
    occurredAt: occurredAt ?? this.occurredAt,
    deviceId: deviceId.present ? deviceId.value : this.deviceId,
    clientEventId: clientEventId ?? this.clientEventId,
  );
  LedgerEntry copyWithCompanion(LedgerEntriesCompanion data) {
    return LedgerEntry(
      id: data.id.present ? data.id.value : this.id,
      customerId: data.customerId.present
          ? data.customerId.value
          : this.customerId,
      entryType: data.entryType.present ? data.entryType.value : this.entryType,
      amountKurus: data.amountKurus.present
          ? data.amountKurus.value
          : this.amountKurus,
      relatedOrderId: data.relatedOrderId.present
          ? data.relatedOrderId.value
          : this.relatedOrderId,
      note: data.note.present ? data.note.value : this.note,
      occurredAt: data.occurredAt.present
          ? data.occurredAt.value
          : this.occurredAt,
      deviceId: data.deviceId.present ? data.deviceId.value : this.deviceId,
      clientEventId: data.clientEventId.present
          ? data.clientEventId.value
          : this.clientEventId,
    );
  }

  @override
  String toString() {
    return (StringBuffer('LedgerEntry(')
          ..write('id: $id, ')
          ..write('customerId: $customerId, ')
          ..write('entryType: $entryType, ')
          ..write('amountKurus: $amountKurus, ')
          ..write('relatedOrderId: $relatedOrderId, ')
          ..write('note: $note, ')
          ..write('occurredAt: $occurredAt, ')
          ..write('deviceId: $deviceId, ')
          ..write('clientEventId: $clientEventId')
          ..write(')'))
        .toString();
  }

  @override
  int get hashCode => Object.hash(
    id,
    customerId,
    entryType,
    amountKurus,
    relatedOrderId,
    note,
    occurredAt,
    deviceId,
    clientEventId,
  );
  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      (other is LedgerEntry &&
          other.id == this.id &&
          other.customerId == this.customerId &&
          other.entryType == this.entryType &&
          other.amountKurus == this.amountKurus &&
          other.relatedOrderId == this.relatedOrderId &&
          other.note == this.note &&
          other.occurredAt == this.occurredAt &&
          other.deviceId == this.deviceId &&
          other.clientEventId == this.clientEventId);
}

class LedgerEntriesCompanion extends UpdateCompanion<LedgerEntry> {
  final Value<String> id;
  final Value<String?> customerId;
  final Value<String> entryType;
  final Value<int> amountKurus;
  final Value<String?> relatedOrderId;
  final Value<String?> note;
  final Value<String> occurredAt;
  final Value<String?> deviceId;
  final Value<String> clientEventId;
  final Value<int> rowid;
  const LedgerEntriesCompanion({
    this.id = const Value.absent(),
    this.customerId = const Value.absent(),
    this.entryType = const Value.absent(),
    this.amountKurus = const Value.absent(),
    this.relatedOrderId = const Value.absent(),
    this.note = const Value.absent(),
    this.occurredAt = const Value.absent(),
    this.deviceId = const Value.absent(),
    this.clientEventId = const Value.absent(),
    this.rowid = const Value.absent(),
  });
  LedgerEntriesCompanion.insert({
    required String id,
    this.customerId = const Value.absent(),
    required String entryType,
    required int amountKurus,
    this.relatedOrderId = const Value.absent(),
    this.note = const Value.absent(),
    required String occurredAt,
    this.deviceId = const Value.absent(),
    required String clientEventId,
    this.rowid = const Value.absent(),
  }) : id = Value(id),
       entryType = Value(entryType),
       amountKurus = Value(amountKurus),
       occurredAt = Value(occurredAt),
       clientEventId = Value(clientEventId);
  static Insertable<LedgerEntry> custom({
    Expression<String>? id,
    Expression<String>? customerId,
    Expression<String>? entryType,
    Expression<int>? amountKurus,
    Expression<String>? relatedOrderId,
    Expression<String>? note,
    Expression<String>? occurredAt,
    Expression<String>? deviceId,
    Expression<String>? clientEventId,
    Expression<int>? rowid,
  }) {
    return RawValuesInsertable({
      if (id != null) 'id': id,
      if (customerId != null) 'customer_id': customerId,
      if (entryType != null) 'entry_type': entryType,
      if (amountKurus != null) 'amount_kurus': amountKurus,
      if (relatedOrderId != null) 'related_order_id': relatedOrderId,
      if (note != null) 'note': note,
      if (occurredAt != null) 'occurred_at': occurredAt,
      if (deviceId != null) 'device_id': deviceId,
      if (clientEventId != null) 'client_event_id': clientEventId,
      if (rowid != null) 'rowid': rowid,
    });
  }

  LedgerEntriesCompanion copyWith({
    Value<String>? id,
    Value<String?>? customerId,
    Value<String>? entryType,
    Value<int>? amountKurus,
    Value<String?>? relatedOrderId,
    Value<String?>? note,
    Value<String>? occurredAt,
    Value<String?>? deviceId,
    Value<String>? clientEventId,
    Value<int>? rowid,
  }) {
    return LedgerEntriesCompanion(
      id: id ?? this.id,
      customerId: customerId ?? this.customerId,
      entryType: entryType ?? this.entryType,
      amountKurus: amountKurus ?? this.amountKurus,
      relatedOrderId: relatedOrderId ?? this.relatedOrderId,
      note: note ?? this.note,
      occurredAt: occurredAt ?? this.occurredAt,
      deviceId: deviceId ?? this.deviceId,
      clientEventId: clientEventId ?? this.clientEventId,
      rowid: rowid ?? this.rowid,
    );
  }

  @override
  Map<String, Expression> toColumns(bool nullToAbsent) {
    final map = <String, Expression>{};
    if (id.present) {
      map['id'] = Variable<String>(id.value);
    }
    if (customerId.present) {
      map['customer_id'] = Variable<String>(customerId.value);
    }
    if (entryType.present) {
      map['entry_type'] = Variable<String>(entryType.value);
    }
    if (amountKurus.present) {
      map['amount_kurus'] = Variable<int>(amountKurus.value);
    }
    if (relatedOrderId.present) {
      map['related_order_id'] = Variable<String>(relatedOrderId.value);
    }
    if (note.present) {
      map['note'] = Variable<String>(note.value);
    }
    if (occurredAt.present) {
      map['occurred_at'] = Variable<String>(occurredAt.value);
    }
    if (deviceId.present) {
      map['device_id'] = Variable<String>(deviceId.value);
    }
    if (clientEventId.present) {
      map['client_event_id'] = Variable<String>(clientEventId.value);
    }
    if (rowid.present) {
      map['rowid'] = Variable<int>(rowid.value);
    }
    return map;
  }

  @override
  String toString() {
    return (StringBuffer('LedgerEntriesCompanion(')
          ..write('id: $id, ')
          ..write('customerId: $customerId, ')
          ..write('entryType: $entryType, ')
          ..write('amountKurus: $amountKurus, ')
          ..write('relatedOrderId: $relatedOrderId, ')
          ..write('note: $note, ')
          ..write('occurredAt: $occurredAt, ')
          ..write('deviceId: $deviceId, ')
          ..write('clientEventId: $clientEventId, ')
          ..write('rowid: $rowid')
          ..write(')'))
        .toString();
  }
}

class $OutboxTable extends Outbox with TableInfo<$OutboxTable, OutboxData> {
  @override
  final GeneratedDatabase attachedDatabase;
  final String? _alias;
  $OutboxTable(this.attachedDatabase, [this._alias]);
  static const VerificationMeta _idMeta = const VerificationMeta('id');
  @override
  late final GeneratedColumn<int> id = GeneratedColumn<int>(
    'id',
    aliasedName,
    false,
    hasAutoIncrement: true,
    type: DriftSqlType.int,
    requiredDuringInsert: false,
    defaultConstraints: GeneratedColumn.constraintIsAlways(
      'PRIMARY KEY AUTOINCREMENT',
    ),
  );
  static const VerificationMeta _clientEventIdMeta = const VerificationMeta(
    'clientEventId',
  );
  @override
  late final GeneratedColumn<String> clientEventId = GeneratedColumn<String>(
    'client_event_id',
    aliasedName,
    false,
    type: DriftSqlType.string,
    requiredDuringInsert: true,
  );
  static const VerificationMeta _entityTypeMeta = const VerificationMeta(
    'entityType',
  );
  @override
  late final GeneratedColumn<String> entityType = GeneratedColumn<String>(
    'entity_type',
    aliasedName,
    false,
    type: DriftSqlType.string,
    requiredDuringInsert: true,
  );
  static const VerificationMeta _opMeta = const VerificationMeta('op');
  @override
  late final GeneratedColumn<String> op = GeneratedColumn<String>(
    'op',
    aliasedName,
    false,
    type: DriftSqlType.string,
    requiredDuringInsert: true,
  );
  static const VerificationMeta _entityIdMeta = const VerificationMeta(
    'entityId',
  );
  @override
  late final GeneratedColumn<String> entityId = GeneratedColumn<String>(
    'entity_id',
    aliasedName,
    true,
    type: DriftSqlType.string,
    requiredDuringInsert: false,
  );
  static const VerificationMeta _payloadMeta = const VerificationMeta(
    'payload',
  );
  @override
  late final GeneratedColumn<String> payload = GeneratedColumn<String>(
    'payload',
    aliasedName,
    false,
    type: DriftSqlType.string,
    requiredDuringInsert: true,
  );
  static const VerificationMeta _occurredAtMeta = const VerificationMeta(
    'occurredAt',
  );
  @override
  late final GeneratedColumn<String> occurredAt = GeneratedColumn<String>(
    'occurred_at',
    aliasedName,
    false,
    type: DriftSqlType.string,
    requiredDuringInsert: true,
  );
  static const VerificationMeta _deviceIdMeta = const VerificationMeta(
    'deviceId',
  );
  @override
  late final GeneratedColumn<String> deviceId = GeneratedColumn<String>(
    'device_id',
    aliasedName,
    true,
    type: DriftSqlType.string,
    requiredDuringInsert: false,
  );
  static const VerificationMeta _createdAtMeta = const VerificationMeta(
    'createdAt',
  );
  @override
  late final GeneratedColumn<String> createdAt = GeneratedColumn<String>(
    'created_at',
    aliasedName,
    false,
    type: DriftSqlType.string,
    requiredDuringInsert: true,
  );
  static const VerificationMeta _statusMeta = const VerificationMeta('status');
  @override
  late final GeneratedColumn<String> status = GeneratedColumn<String>(
    'status',
    aliasedName,
    false,
    type: DriftSqlType.string,
    requiredDuringInsert: false,
    defaultValue: const Constant('pending'),
  );
  static const VerificationMeta _attemptsMeta = const VerificationMeta(
    'attempts',
  );
  @override
  late final GeneratedColumn<int> attempts = GeneratedColumn<int>(
    'attempts',
    aliasedName,
    false,
    type: DriftSqlType.int,
    requiredDuringInsert: false,
    defaultValue: const Constant(0),
  );
  static const VerificationMeta _lastErrorMeta = const VerificationMeta(
    'lastError',
  );
  @override
  late final GeneratedColumn<String> lastError = GeneratedColumn<String>(
    'last_error',
    aliasedName,
    true,
    type: DriftSqlType.string,
    requiredDuringInsert: false,
  );
  @override
  List<GeneratedColumn> get $columns => [
    id,
    clientEventId,
    entityType,
    op,
    entityId,
    payload,
    occurredAt,
    deviceId,
    createdAt,
    status,
    attempts,
    lastError,
  ];
  @override
  String get aliasedName => _alias ?? actualTableName;
  @override
  String get actualTableName => $name;
  static const String $name = 'outbox';
  @override
  VerificationContext validateIntegrity(
    Insertable<OutboxData> instance, {
    bool isInserting = false,
  }) {
    final context = VerificationContext();
    final data = instance.toColumns(true);
    if (data.containsKey('id')) {
      context.handle(_idMeta, id.isAcceptableOrUnknown(data['id']!, _idMeta));
    }
    if (data.containsKey('client_event_id')) {
      context.handle(
        _clientEventIdMeta,
        clientEventId.isAcceptableOrUnknown(
          data['client_event_id']!,
          _clientEventIdMeta,
        ),
      );
    } else if (isInserting) {
      context.missing(_clientEventIdMeta);
    }
    if (data.containsKey('entity_type')) {
      context.handle(
        _entityTypeMeta,
        entityType.isAcceptableOrUnknown(data['entity_type']!, _entityTypeMeta),
      );
    } else if (isInserting) {
      context.missing(_entityTypeMeta);
    }
    if (data.containsKey('op')) {
      context.handle(_opMeta, op.isAcceptableOrUnknown(data['op']!, _opMeta));
    } else if (isInserting) {
      context.missing(_opMeta);
    }
    if (data.containsKey('entity_id')) {
      context.handle(
        _entityIdMeta,
        entityId.isAcceptableOrUnknown(data['entity_id']!, _entityIdMeta),
      );
    }
    if (data.containsKey('payload')) {
      context.handle(
        _payloadMeta,
        payload.isAcceptableOrUnknown(data['payload']!, _payloadMeta),
      );
    } else if (isInserting) {
      context.missing(_payloadMeta);
    }
    if (data.containsKey('occurred_at')) {
      context.handle(
        _occurredAtMeta,
        occurredAt.isAcceptableOrUnknown(data['occurred_at']!, _occurredAtMeta),
      );
    } else if (isInserting) {
      context.missing(_occurredAtMeta);
    }
    if (data.containsKey('device_id')) {
      context.handle(
        _deviceIdMeta,
        deviceId.isAcceptableOrUnknown(data['device_id']!, _deviceIdMeta),
      );
    }
    if (data.containsKey('created_at')) {
      context.handle(
        _createdAtMeta,
        createdAt.isAcceptableOrUnknown(data['created_at']!, _createdAtMeta),
      );
    } else if (isInserting) {
      context.missing(_createdAtMeta);
    }
    if (data.containsKey('status')) {
      context.handle(
        _statusMeta,
        status.isAcceptableOrUnknown(data['status']!, _statusMeta),
      );
    }
    if (data.containsKey('attempts')) {
      context.handle(
        _attemptsMeta,
        attempts.isAcceptableOrUnknown(data['attempts']!, _attemptsMeta),
      );
    }
    if (data.containsKey('last_error')) {
      context.handle(
        _lastErrorMeta,
        lastError.isAcceptableOrUnknown(data['last_error']!, _lastErrorMeta),
      );
    }
    return context;
  }

  @override
  Set<GeneratedColumn> get $primaryKey => {id};
  @override
  List<Set<GeneratedColumn>> get uniqueKeys => [
    {clientEventId},
  ];
  @override
  OutboxData map(Map<String, dynamic> data, {String? tablePrefix}) {
    final effectivePrefix = tablePrefix != null ? '$tablePrefix.' : '';
    return OutboxData(
      id: attachedDatabase.typeMapping.read(
        DriftSqlType.int,
        data['${effectivePrefix}id'],
      )!,
      clientEventId: attachedDatabase.typeMapping.read(
        DriftSqlType.string,
        data['${effectivePrefix}client_event_id'],
      )!,
      entityType: attachedDatabase.typeMapping.read(
        DriftSqlType.string,
        data['${effectivePrefix}entity_type'],
      )!,
      op: attachedDatabase.typeMapping.read(
        DriftSqlType.string,
        data['${effectivePrefix}op'],
      )!,
      entityId: attachedDatabase.typeMapping.read(
        DriftSqlType.string,
        data['${effectivePrefix}entity_id'],
      ),
      payload: attachedDatabase.typeMapping.read(
        DriftSqlType.string,
        data['${effectivePrefix}payload'],
      )!,
      occurredAt: attachedDatabase.typeMapping.read(
        DriftSqlType.string,
        data['${effectivePrefix}occurred_at'],
      )!,
      deviceId: attachedDatabase.typeMapping.read(
        DriftSqlType.string,
        data['${effectivePrefix}device_id'],
      ),
      createdAt: attachedDatabase.typeMapping.read(
        DriftSqlType.string,
        data['${effectivePrefix}created_at'],
      )!,
      status: attachedDatabase.typeMapping.read(
        DriftSqlType.string,
        data['${effectivePrefix}status'],
      )!,
      attempts: attachedDatabase.typeMapping.read(
        DriftSqlType.int,
        data['${effectivePrefix}attempts'],
      )!,
      lastError: attachedDatabase.typeMapping.read(
        DriftSqlType.string,
        data['${effectivePrefix}last_error'],
      ),
    );
  }

  @override
  $OutboxTable createAlias(String alias) {
    return $OutboxTable(attachedDatabase, alias);
  }
}

class OutboxData extends DataClass implements Insertable<OutboxData> {
  final int id;
  final String clientEventId;
  final String entityType;
  final String op;
  final String? entityId;
  final String payload;
  final String occurredAt;
  final String? deviceId;
  final String createdAt;
  final String status;
  final int attempts;
  final String? lastError;
  const OutboxData({
    required this.id,
    required this.clientEventId,
    required this.entityType,
    required this.op,
    this.entityId,
    required this.payload,
    required this.occurredAt,
    this.deviceId,
    required this.createdAt,
    required this.status,
    required this.attempts,
    this.lastError,
  });
  @override
  Map<String, Expression> toColumns(bool nullToAbsent) {
    final map = <String, Expression>{};
    map['id'] = Variable<int>(id);
    map['client_event_id'] = Variable<String>(clientEventId);
    map['entity_type'] = Variable<String>(entityType);
    map['op'] = Variable<String>(op);
    if (!nullToAbsent || entityId != null) {
      map['entity_id'] = Variable<String>(entityId);
    }
    map['payload'] = Variable<String>(payload);
    map['occurred_at'] = Variable<String>(occurredAt);
    if (!nullToAbsent || deviceId != null) {
      map['device_id'] = Variable<String>(deviceId);
    }
    map['created_at'] = Variable<String>(createdAt);
    map['status'] = Variable<String>(status);
    map['attempts'] = Variable<int>(attempts);
    if (!nullToAbsent || lastError != null) {
      map['last_error'] = Variable<String>(lastError);
    }
    return map;
  }

  OutboxCompanion toCompanion(bool nullToAbsent) {
    return OutboxCompanion(
      id: Value(id),
      clientEventId: Value(clientEventId),
      entityType: Value(entityType),
      op: Value(op),
      entityId: entityId == null && nullToAbsent
          ? const Value.absent()
          : Value(entityId),
      payload: Value(payload),
      occurredAt: Value(occurredAt),
      deviceId: deviceId == null && nullToAbsent
          ? const Value.absent()
          : Value(deviceId),
      createdAt: Value(createdAt),
      status: Value(status),
      attempts: Value(attempts),
      lastError: lastError == null && nullToAbsent
          ? const Value.absent()
          : Value(lastError),
    );
  }

  factory OutboxData.fromJson(
    Map<String, dynamic> json, {
    ValueSerializer? serializer,
  }) {
    serializer ??= driftRuntimeOptions.defaultSerializer;
    return OutboxData(
      id: serializer.fromJson<int>(json['id']),
      clientEventId: serializer.fromJson<String>(json['clientEventId']),
      entityType: serializer.fromJson<String>(json['entityType']),
      op: serializer.fromJson<String>(json['op']),
      entityId: serializer.fromJson<String?>(json['entityId']),
      payload: serializer.fromJson<String>(json['payload']),
      occurredAt: serializer.fromJson<String>(json['occurredAt']),
      deviceId: serializer.fromJson<String?>(json['deviceId']),
      createdAt: serializer.fromJson<String>(json['createdAt']),
      status: serializer.fromJson<String>(json['status']),
      attempts: serializer.fromJson<int>(json['attempts']),
      lastError: serializer.fromJson<String?>(json['lastError']),
    );
  }
  @override
  Map<String, dynamic> toJson({ValueSerializer? serializer}) {
    serializer ??= driftRuntimeOptions.defaultSerializer;
    return <String, dynamic>{
      'id': serializer.toJson<int>(id),
      'clientEventId': serializer.toJson<String>(clientEventId),
      'entityType': serializer.toJson<String>(entityType),
      'op': serializer.toJson<String>(op),
      'entityId': serializer.toJson<String?>(entityId),
      'payload': serializer.toJson<String>(payload),
      'occurredAt': serializer.toJson<String>(occurredAt),
      'deviceId': serializer.toJson<String?>(deviceId),
      'createdAt': serializer.toJson<String>(createdAt),
      'status': serializer.toJson<String>(status),
      'attempts': serializer.toJson<int>(attempts),
      'lastError': serializer.toJson<String?>(lastError),
    };
  }

  OutboxData copyWith({
    int? id,
    String? clientEventId,
    String? entityType,
    String? op,
    Value<String?> entityId = const Value.absent(),
    String? payload,
    String? occurredAt,
    Value<String?> deviceId = const Value.absent(),
    String? createdAt,
    String? status,
    int? attempts,
    Value<String?> lastError = const Value.absent(),
  }) => OutboxData(
    id: id ?? this.id,
    clientEventId: clientEventId ?? this.clientEventId,
    entityType: entityType ?? this.entityType,
    op: op ?? this.op,
    entityId: entityId.present ? entityId.value : this.entityId,
    payload: payload ?? this.payload,
    occurredAt: occurredAt ?? this.occurredAt,
    deviceId: deviceId.present ? deviceId.value : this.deviceId,
    createdAt: createdAt ?? this.createdAt,
    status: status ?? this.status,
    attempts: attempts ?? this.attempts,
    lastError: lastError.present ? lastError.value : this.lastError,
  );
  OutboxData copyWithCompanion(OutboxCompanion data) {
    return OutboxData(
      id: data.id.present ? data.id.value : this.id,
      clientEventId: data.clientEventId.present
          ? data.clientEventId.value
          : this.clientEventId,
      entityType: data.entityType.present
          ? data.entityType.value
          : this.entityType,
      op: data.op.present ? data.op.value : this.op,
      entityId: data.entityId.present ? data.entityId.value : this.entityId,
      payload: data.payload.present ? data.payload.value : this.payload,
      occurredAt: data.occurredAt.present
          ? data.occurredAt.value
          : this.occurredAt,
      deviceId: data.deviceId.present ? data.deviceId.value : this.deviceId,
      createdAt: data.createdAt.present ? data.createdAt.value : this.createdAt,
      status: data.status.present ? data.status.value : this.status,
      attempts: data.attempts.present ? data.attempts.value : this.attempts,
      lastError: data.lastError.present ? data.lastError.value : this.lastError,
    );
  }

  @override
  String toString() {
    return (StringBuffer('OutboxData(')
          ..write('id: $id, ')
          ..write('clientEventId: $clientEventId, ')
          ..write('entityType: $entityType, ')
          ..write('op: $op, ')
          ..write('entityId: $entityId, ')
          ..write('payload: $payload, ')
          ..write('occurredAt: $occurredAt, ')
          ..write('deviceId: $deviceId, ')
          ..write('createdAt: $createdAt, ')
          ..write('status: $status, ')
          ..write('attempts: $attempts, ')
          ..write('lastError: $lastError')
          ..write(')'))
        .toString();
  }

  @override
  int get hashCode => Object.hash(
    id,
    clientEventId,
    entityType,
    op,
    entityId,
    payload,
    occurredAt,
    deviceId,
    createdAt,
    status,
    attempts,
    lastError,
  );
  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      (other is OutboxData &&
          other.id == this.id &&
          other.clientEventId == this.clientEventId &&
          other.entityType == this.entityType &&
          other.op == this.op &&
          other.entityId == this.entityId &&
          other.payload == this.payload &&
          other.occurredAt == this.occurredAt &&
          other.deviceId == this.deviceId &&
          other.createdAt == this.createdAt &&
          other.status == this.status &&
          other.attempts == this.attempts &&
          other.lastError == this.lastError);
}

class OutboxCompanion extends UpdateCompanion<OutboxData> {
  final Value<int> id;
  final Value<String> clientEventId;
  final Value<String> entityType;
  final Value<String> op;
  final Value<String?> entityId;
  final Value<String> payload;
  final Value<String> occurredAt;
  final Value<String?> deviceId;
  final Value<String> createdAt;
  final Value<String> status;
  final Value<int> attempts;
  final Value<String?> lastError;
  const OutboxCompanion({
    this.id = const Value.absent(),
    this.clientEventId = const Value.absent(),
    this.entityType = const Value.absent(),
    this.op = const Value.absent(),
    this.entityId = const Value.absent(),
    this.payload = const Value.absent(),
    this.occurredAt = const Value.absent(),
    this.deviceId = const Value.absent(),
    this.createdAt = const Value.absent(),
    this.status = const Value.absent(),
    this.attempts = const Value.absent(),
    this.lastError = const Value.absent(),
  });
  OutboxCompanion.insert({
    this.id = const Value.absent(),
    required String clientEventId,
    required String entityType,
    required String op,
    this.entityId = const Value.absent(),
    required String payload,
    required String occurredAt,
    this.deviceId = const Value.absent(),
    required String createdAt,
    this.status = const Value.absent(),
    this.attempts = const Value.absent(),
    this.lastError = const Value.absent(),
  }) : clientEventId = Value(clientEventId),
       entityType = Value(entityType),
       op = Value(op),
       payload = Value(payload),
       occurredAt = Value(occurredAt),
       createdAt = Value(createdAt);
  static Insertable<OutboxData> custom({
    Expression<int>? id,
    Expression<String>? clientEventId,
    Expression<String>? entityType,
    Expression<String>? op,
    Expression<String>? entityId,
    Expression<String>? payload,
    Expression<String>? occurredAt,
    Expression<String>? deviceId,
    Expression<String>? createdAt,
    Expression<String>? status,
    Expression<int>? attempts,
    Expression<String>? lastError,
  }) {
    return RawValuesInsertable({
      if (id != null) 'id': id,
      if (clientEventId != null) 'client_event_id': clientEventId,
      if (entityType != null) 'entity_type': entityType,
      if (op != null) 'op': op,
      if (entityId != null) 'entity_id': entityId,
      if (payload != null) 'payload': payload,
      if (occurredAt != null) 'occurred_at': occurredAt,
      if (deviceId != null) 'device_id': deviceId,
      if (createdAt != null) 'created_at': createdAt,
      if (status != null) 'status': status,
      if (attempts != null) 'attempts': attempts,
      if (lastError != null) 'last_error': lastError,
    });
  }

  OutboxCompanion copyWith({
    Value<int>? id,
    Value<String>? clientEventId,
    Value<String>? entityType,
    Value<String>? op,
    Value<String?>? entityId,
    Value<String>? payload,
    Value<String>? occurredAt,
    Value<String?>? deviceId,
    Value<String>? createdAt,
    Value<String>? status,
    Value<int>? attempts,
    Value<String?>? lastError,
  }) {
    return OutboxCompanion(
      id: id ?? this.id,
      clientEventId: clientEventId ?? this.clientEventId,
      entityType: entityType ?? this.entityType,
      op: op ?? this.op,
      entityId: entityId ?? this.entityId,
      payload: payload ?? this.payload,
      occurredAt: occurredAt ?? this.occurredAt,
      deviceId: deviceId ?? this.deviceId,
      createdAt: createdAt ?? this.createdAt,
      status: status ?? this.status,
      attempts: attempts ?? this.attempts,
      lastError: lastError ?? this.lastError,
    );
  }

  @override
  Map<String, Expression> toColumns(bool nullToAbsent) {
    final map = <String, Expression>{};
    if (id.present) {
      map['id'] = Variable<int>(id.value);
    }
    if (clientEventId.present) {
      map['client_event_id'] = Variable<String>(clientEventId.value);
    }
    if (entityType.present) {
      map['entity_type'] = Variable<String>(entityType.value);
    }
    if (op.present) {
      map['op'] = Variable<String>(op.value);
    }
    if (entityId.present) {
      map['entity_id'] = Variable<String>(entityId.value);
    }
    if (payload.present) {
      map['payload'] = Variable<String>(payload.value);
    }
    if (occurredAt.present) {
      map['occurred_at'] = Variable<String>(occurredAt.value);
    }
    if (deviceId.present) {
      map['device_id'] = Variable<String>(deviceId.value);
    }
    if (createdAt.present) {
      map['created_at'] = Variable<String>(createdAt.value);
    }
    if (status.present) {
      map['status'] = Variable<String>(status.value);
    }
    if (attempts.present) {
      map['attempts'] = Variable<int>(attempts.value);
    }
    if (lastError.present) {
      map['last_error'] = Variable<String>(lastError.value);
    }
    return map;
  }

  @override
  String toString() {
    return (StringBuffer('OutboxCompanion(')
          ..write('id: $id, ')
          ..write('clientEventId: $clientEventId, ')
          ..write('entityType: $entityType, ')
          ..write('op: $op, ')
          ..write('entityId: $entityId, ')
          ..write('payload: $payload, ')
          ..write('occurredAt: $occurredAt, ')
          ..write('deviceId: $deviceId, ')
          ..write('createdAt: $createdAt, ')
          ..write('status: $status, ')
          ..write('attempts: $attempts, ')
          ..write('lastError: $lastError')
          ..write(')'))
        .toString();
  }
}

class $SyncMetaTable extends SyncMeta
    with TableInfo<$SyncMetaTable, SyncMetaData> {
  @override
  final GeneratedDatabase attachedDatabase;
  final String? _alias;
  $SyncMetaTable(this.attachedDatabase, [this._alias]);
  static const VerificationMeta _idMeta = const VerificationMeta('id');
  @override
  late final GeneratedColumn<int> id = GeneratedColumn<int>(
    'id',
    aliasedName,
    false,
    type: DriftSqlType.int,
    requiredDuringInsert: false,
    defaultValue: const Constant(1),
  );
  static const VerificationMeta _lastPulledSeqMeta = const VerificationMeta(
    'lastPulledSeq',
  );
  @override
  late final GeneratedColumn<int> lastPulledSeq = GeneratedColumn<int>(
    'last_pulled_seq',
    aliasedName,
    false,
    type: DriftSqlType.int,
    requiredDuringInsert: false,
    defaultValue: const Constant(0),
  );
  static const VerificationMeta _lastServerTimeIsoMeta = const VerificationMeta(
    'lastServerTimeIso',
  );
  @override
  late final GeneratedColumn<String> lastServerTimeIso =
      GeneratedColumn<String>(
        'last_server_time_iso',
        aliasedName,
        true,
        type: DriftSqlType.string,
        requiredDuringInsert: false,
      );
  static const VerificationMeta _serverTimeOffsetMsMeta =
      const VerificationMeta('serverTimeOffsetMs');
  @override
  late final GeneratedColumn<int> serverTimeOffsetMs = GeneratedColumn<int>(
    'server_time_offset_ms',
    aliasedName,
    false,
    type: DriftSqlType.int,
    requiredDuringInsert: false,
    defaultValue: const Constant(0),
  );
  static const VerificationMeta _elapsedAnchorMsMeta = const VerificationMeta(
    'elapsedAnchorMs',
  );
  @override
  late final GeneratedColumn<int> elapsedAnchorMs = GeneratedColumn<int>(
    'elapsed_anchor_ms',
    aliasedName,
    true,
    type: DriftSqlType.int,
    requiredDuringInsert: false,
  );
  static const VerificationMeta _snapshotDoneMeta = const VerificationMeta(
    'snapshotDone',
  );
  @override
  late final GeneratedColumn<bool> snapshotDone = GeneratedColumn<bool>(
    'snapshot_done',
    aliasedName,
    false,
    type: DriftSqlType.bool,
    requiredDuringInsert: false,
    defaultConstraints: GeneratedColumn.constraintIsAlways(
      'CHECK ("snapshot_done" IN (0, 1))',
    ),
    defaultValue: const Constant(false),
  );
  static const VerificationMeta _deviceIdMeta = const VerificationMeta(
    'deviceId',
  );
  @override
  late final GeneratedColumn<String> deviceId = GeneratedColumn<String>(
    'device_id',
    aliasedName,
    true,
    type: DriftSqlType.string,
    requiredDuringInsert: false,
  );
  static const VerificationMeta _validUntilIsoMeta = const VerificationMeta(
    'validUntilIso',
  );
  @override
  late final GeneratedColumn<String> validUntilIso = GeneratedColumn<String>(
    'valid_until_iso',
    aliasedName,
    true,
    type: DriftSqlType.string,
    requiredDuringInsert: false,
  );
  @override
  List<GeneratedColumn> get $columns => [
    id,
    lastPulledSeq,
    lastServerTimeIso,
    serverTimeOffsetMs,
    elapsedAnchorMs,
    snapshotDone,
    deviceId,
    validUntilIso,
  ];
  @override
  String get aliasedName => _alias ?? actualTableName;
  @override
  String get actualTableName => $name;
  static const String $name = 'sync_meta';
  @override
  VerificationContext validateIntegrity(
    Insertable<SyncMetaData> instance, {
    bool isInserting = false,
  }) {
    final context = VerificationContext();
    final data = instance.toColumns(true);
    if (data.containsKey('id')) {
      context.handle(_idMeta, id.isAcceptableOrUnknown(data['id']!, _idMeta));
    }
    if (data.containsKey('last_pulled_seq')) {
      context.handle(
        _lastPulledSeqMeta,
        lastPulledSeq.isAcceptableOrUnknown(
          data['last_pulled_seq']!,
          _lastPulledSeqMeta,
        ),
      );
    }
    if (data.containsKey('last_server_time_iso')) {
      context.handle(
        _lastServerTimeIsoMeta,
        lastServerTimeIso.isAcceptableOrUnknown(
          data['last_server_time_iso']!,
          _lastServerTimeIsoMeta,
        ),
      );
    }
    if (data.containsKey('server_time_offset_ms')) {
      context.handle(
        _serverTimeOffsetMsMeta,
        serverTimeOffsetMs.isAcceptableOrUnknown(
          data['server_time_offset_ms']!,
          _serverTimeOffsetMsMeta,
        ),
      );
    }
    if (data.containsKey('elapsed_anchor_ms')) {
      context.handle(
        _elapsedAnchorMsMeta,
        elapsedAnchorMs.isAcceptableOrUnknown(
          data['elapsed_anchor_ms']!,
          _elapsedAnchorMsMeta,
        ),
      );
    }
    if (data.containsKey('snapshot_done')) {
      context.handle(
        _snapshotDoneMeta,
        snapshotDone.isAcceptableOrUnknown(
          data['snapshot_done']!,
          _snapshotDoneMeta,
        ),
      );
    }
    if (data.containsKey('device_id')) {
      context.handle(
        _deviceIdMeta,
        deviceId.isAcceptableOrUnknown(data['device_id']!, _deviceIdMeta),
      );
    }
    if (data.containsKey('valid_until_iso')) {
      context.handle(
        _validUntilIsoMeta,
        validUntilIso.isAcceptableOrUnknown(
          data['valid_until_iso']!,
          _validUntilIsoMeta,
        ),
      );
    }
    return context;
  }

  @override
  Set<GeneratedColumn> get $primaryKey => {id};
  @override
  SyncMetaData map(Map<String, dynamic> data, {String? tablePrefix}) {
    final effectivePrefix = tablePrefix != null ? '$tablePrefix.' : '';
    return SyncMetaData(
      id: attachedDatabase.typeMapping.read(
        DriftSqlType.int,
        data['${effectivePrefix}id'],
      )!,
      lastPulledSeq: attachedDatabase.typeMapping.read(
        DriftSqlType.int,
        data['${effectivePrefix}last_pulled_seq'],
      )!,
      lastServerTimeIso: attachedDatabase.typeMapping.read(
        DriftSqlType.string,
        data['${effectivePrefix}last_server_time_iso'],
      ),
      serverTimeOffsetMs: attachedDatabase.typeMapping.read(
        DriftSqlType.int,
        data['${effectivePrefix}server_time_offset_ms'],
      )!,
      elapsedAnchorMs: attachedDatabase.typeMapping.read(
        DriftSqlType.int,
        data['${effectivePrefix}elapsed_anchor_ms'],
      ),
      snapshotDone: attachedDatabase.typeMapping.read(
        DriftSqlType.bool,
        data['${effectivePrefix}snapshot_done'],
      )!,
      deviceId: attachedDatabase.typeMapping.read(
        DriftSqlType.string,
        data['${effectivePrefix}device_id'],
      ),
      validUntilIso: attachedDatabase.typeMapping.read(
        DriftSqlType.string,
        data['${effectivePrefix}valid_until_iso'],
      ),
    );
  }

  @override
  $SyncMetaTable createAlias(String alias) {
    return $SyncMetaTable(attachedDatabase, alias);
  }
}

class SyncMetaData extends DataClass implements Insertable<SyncMetaData> {
  final int id;
  final int lastPulledSeq;
  final String? lastServerTimeIso;
  final int serverTimeOffsetMs;
  final int? elapsedAnchorMs;
  final bool snapshotDone;
  final String? deviceId;
  final String? validUntilIso;
  const SyncMetaData({
    required this.id,
    required this.lastPulledSeq,
    this.lastServerTimeIso,
    required this.serverTimeOffsetMs,
    this.elapsedAnchorMs,
    required this.snapshotDone,
    this.deviceId,
    this.validUntilIso,
  });
  @override
  Map<String, Expression> toColumns(bool nullToAbsent) {
    final map = <String, Expression>{};
    map['id'] = Variable<int>(id);
    map['last_pulled_seq'] = Variable<int>(lastPulledSeq);
    if (!nullToAbsent || lastServerTimeIso != null) {
      map['last_server_time_iso'] = Variable<String>(lastServerTimeIso);
    }
    map['server_time_offset_ms'] = Variable<int>(serverTimeOffsetMs);
    if (!nullToAbsent || elapsedAnchorMs != null) {
      map['elapsed_anchor_ms'] = Variable<int>(elapsedAnchorMs);
    }
    map['snapshot_done'] = Variable<bool>(snapshotDone);
    if (!nullToAbsent || deviceId != null) {
      map['device_id'] = Variable<String>(deviceId);
    }
    if (!nullToAbsent || validUntilIso != null) {
      map['valid_until_iso'] = Variable<String>(validUntilIso);
    }
    return map;
  }

  SyncMetaCompanion toCompanion(bool nullToAbsent) {
    return SyncMetaCompanion(
      id: Value(id),
      lastPulledSeq: Value(lastPulledSeq),
      lastServerTimeIso: lastServerTimeIso == null && nullToAbsent
          ? const Value.absent()
          : Value(lastServerTimeIso),
      serverTimeOffsetMs: Value(serverTimeOffsetMs),
      elapsedAnchorMs: elapsedAnchorMs == null && nullToAbsent
          ? const Value.absent()
          : Value(elapsedAnchorMs),
      snapshotDone: Value(snapshotDone),
      deviceId: deviceId == null && nullToAbsent
          ? const Value.absent()
          : Value(deviceId),
      validUntilIso: validUntilIso == null && nullToAbsent
          ? const Value.absent()
          : Value(validUntilIso),
    );
  }

  factory SyncMetaData.fromJson(
    Map<String, dynamic> json, {
    ValueSerializer? serializer,
  }) {
    serializer ??= driftRuntimeOptions.defaultSerializer;
    return SyncMetaData(
      id: serializer.fromJson<int>(json['id']),
      lastPulledSeq: serializer.fromJson<int>(json['lastPulledSeq']),
      lastServerTimeIso: serializer.fromJson<String?>(
        json['lastServerTimeIso'],
      ),
      serverTimeOffsetMs: serializer.fromJson<int>(json['serverTimeOffsetMs']),
      elapsedAnchorMs: serializer.fromJson<int?>(json['elapsedAnchorMs']),
      snapshotDone: serializer.fromJson<bool>(json['snapshotDone']),
      deviceId: serializer.fromJson<String?>(json['deviceId']),
      validUntilIso: serializer.fromJson<String?>(json['validUntilIso']),
    );
  }
  @override
  Map<String, dynamic> toJson({ValueSerializer? serializer}) {
    serializer ??= driftRuntimeOptions.defaultSerializer;
    return <String, dynamic>{
      'id': serializer.toJson<int>(id),
      'lastPulledSeq': serializer.toJson<int>(lastPulledSeq),
      'lastServerTimeIso': serializer.toJson<String?>(lastServerTimeIso),
      'serverTimeOffsetMs': serializer.toJson<int>(serverTimeOffsetMs),
      'elapsedAnchorMs': serializer.toJson<int?>(elapsedAnchorMs),
      'snapshotDone': serializer.toJson<bool>(snapshotDone),
      'deviceId': serializer.toJson<String?>(deviceId),
      'validUntilIso': serializer.toJson<String?>(validUntilIso),
    };
  }

  SyncMetaData copyWith({
    int? id,
    int? lastPulledSeq,
    Value<String?> lastServerTimeIso = const Value.absent(),
    int? serverTimeOffsetMs,
    Value<int?> elapsedAnchorMs = const Value.absent(),
    bool? snapshotDone,
    Value<String?> deviceId = const Value.absent(),
    Value<String?> validUntilIso = const Value.absent(),
  }) => SyncMetaData(
    id: id ?? this.id,
    lastPulledSeq: lastPulledSeq ?? this.lastPulledSeq,
    lastServerTimeIso: lastServerTimeIso.present
        ? lastServerTimeIso.value
        : this.lastServerTimeIso,
    serverTimeOffsetMs: serverTimeOffsetMs ?? this.serverTimeOffsetMs,
    elapsedAnchorMs: elapsedAnchorMs.present
        ? elapsedAnchorMs.value
        : this.elapsedAnchorMs,
    snapshotDone: snapshotDone ?? this.snapshotDone,
    deviceId: deviceId.present ? deviceId.value : this.deviceId,
    validUntilIso: validUntilIso.present
        ? validUntilIso.value
        : this.validUntilIso,
  );
  SyncMetaData copyWithCompanion(SyncMetaCompanion data) {
    return SyncMetaData(
      id: data.id.present ? data.id.value : this.id,
      lastPulledSeq: data.lastPulledSeq.present
          ? data.lastPulledSeq.value
          : this.lastPulledSeq,
      lastServerTimeIso: data.lastServerTimeIso.present
          ? data.lastServerTimeIso.value
          : this.lastServerTimeIso,
      serverTimeOffsetMs: data.serverTimeOffsetMs.present
          ? data.serverTimeOffsetMs.value
          : this.serverTimeOffsetMs,
      elapsedAnchorMs: data.elapsedAnchorMs.present
          ? data.elapsedAnchorMs.value
          : this.elapsedAnchorMs,
      snapshotDone: data.snapshotDone.present
          ? data.snapshotDone.value
          : this.snapshotDone,
      deviceId: data.deviceId.present ? data.deviceId.value : this.deviceId,
      validUntilIso: data.validUntilIso.present
          ? data.validUntilIso.value
          : this.validUntilIso,
    );
  }

  @override
  String toString() {
    return (StringBuffer('SyncMetaData(')
          ..write('id: $id, ')
          ..write('lastPulledSeq: $lastPulledSeq, ')
          ..write('lastServerTimeIso: $lastServerTimeIso, ')
          ..write('serverTimeOffsetMs: $serverTimeOffsetMs, ')
          ..write('elapsedAnchorMs: $elapsedAnchorMs, ')
          ..write('snapshotDone: $snapshotDone, ')
          ..write('deviceId: $deviceId, ')
          ..write('validUntilIso: $validUntilIso')
          ..write(')'))
        .toString();
  }

  @override
  int get hashCode => Object.hash(
    id,
    lastPulledSeq,
    lastServerTimeIso,
    serverTimeOffsetMs,
    elapsedAnchorMs,
    snapshotDone,
    deviceId,
    validUntilIso,
  );
  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      (other is SyncMetaData &&
          other.id == this.id &&
          other.lastPulledSeq == this.lastPulledSeq &&
          other.lastServerTimeIso == this.lastServerTimeIso &&
          other.serverTimeOffsetMs == this.serverTimeOffsetMs &&
          other.elapsedAnchorMs == this.elapsedAnchorMs &&
          other.snapshotDone == this.snapshotDone &&
          other.deviceId == this.deviceId &&
          other.validUntilIso == this.validUntilIso);
}

class SyncMetaCompanion extends UpdateCompanion<SyncMetaData> {
  final Value<int> id;
  final Value<int> lastPulledSeq;
  final Value<String?> lastServerTimeIso;
  final Value<int> serverTimeOffsetMs;
  final Value<int?> elapsedAnchorMs;
  final Value<bool> snapshotDone;
  final Value<String?> deviceId;
  final Value<String?> validUntilIso;
  const SyncMetaCompanion({
    this.id = const Value.absent(),
    this.lastPulledSeq = const Value.absent(),
    this.lastServerTimeIso = const Value.absent(),
    this.serverTimeOffsetMs = const Value.absent(),
    this.elapsedAnchorMs = const Value.absent(),
    this.snapshotDone = const Value.absent(),
    this.deviceId = const Value.absent(),
    this.validUntilIso = const Value.absent(),
  });
  SyncMetaCompanion.insert({
    this.id = const Value.absent(),
    this.lastPulledSeq = const Value.absent(),
    this.lastServerTimeIso = const Value.absent(),
    this.serverTimeOffsetMs = const Value.absent(),
    this.elapsedAnchorMs = const Value.absent(),
    this.snapshotDone = const Value.absent(),
    this.deviceId = const Value.absent(),
    this.validUntilIso = const Value.absent(),
  });
  static Insertable<SyncMetaData> custom({
    Expression<int>? id,
    Expression<int>? lastPulledSeq,
    Expression<String>? lastServerTimeIso,
    Expression<int>? serverTimeOffsetMs,
    Expression<int>? elapsedAnchorMs,
    Expression<bool>? snapshotDone,
    Expression<String>? deviceId,
    Expression<String>? validUntilIso,
  }) {
    return RawValuesInsertable({
      if (id != null) 'id': id,
      if (lastPulledSeq != null) 'last_pulled_seq': lastPulledSeq,
      if (lastServerTimeIso != null) 'last_server_time_iso': lastServerTimeIso,
      if (serverTimeOffsetMs != null)
        'server_time_offset_ms': serverTimeOffsetMs,
      if (elapsedAnchorMs != null) 'elapsed_anchor_ms': elapsedAnchorMs,
      if (snapshotDone != null) 'snapshot_done': snapshotDone,
      if (deviceId != null) 'device_id': deviceId,
      if (validUntilIso != null) 'valid_until_iso': validUntilIso,
    });
  }

  SyncMetaCompanion copyWith({
    Value<int>? id,
    Value<int>? lastPulledSeq,
    Value<String?>? lastServerTimeIso,
    Value<int>? serverTimeOffsetMs,
    Value<int?>? elapsedAnchorMs,
    Value<bool>? snapshotDone,
    Value<String?>? deviceId,
    Value<String?>? validUntilIso,
  }) {
    return SyncMetaCompanion(
      id: id ?? this.id,
      lastPulledSeq: lastPulledSeq ?? this.lastPulledSeq,
      lastServerTimeIso: lastServerTimeIso ?? this.lastServerTimeIso,
      serverTimeOffsetMs: serverTimeOffsetMs ?? this.serverTimeOffsetMs,
      elapsedAnchorMs: elapsedAnchorMs ?? this.elapsedAnchorMs,
      snapshotDone: snapshotDone ?? this.snapshotDone,
      deviceId: deviceId ?? this.deviceId,
      validUntilIso: validUntilIso ?? this.validUntilIso,
    );
  }

  @override
  Map<String, Expression> toColumns(bool nullToAbsent) {
    final map = <String, Expression>{};
    if (id.present) {
      map['id'] = Variable<int>(id.value);
    }
    if (lastPulledSeq.present) {
      map['last_pulled_seq'] = Variable<int>(lastPulledSeq.value);
    }
    if (lastServerTimeIso.present) {
      map['last_server_time_iso'] = Variable<String>(lastServerTimeIso.value);
    }
    if (serverTimeOffsetMs.present) {
      map['server_time_offset_ms'] = Variable<int>(serverTimeOffsetMs.value);
    }
    if (elapsedAnchorMs.present) {
      map['elapsed_anchor_ms'] = Variable<int>(elapsedAnchorMs.value);
    }
    if (snapshotDone.present) {
      map['snapshot_done'] = Variable<bool>(snapshotDone.value);
    }
    if (deviceId.present) {
      map['device_id'] = Variable<String>(deviceId.value);
    }
    if (validUntilIso.present) {
      map['valid_until_iso'] = Variable<String>(validUntilIso.value);
    }
    return map;
  }

  @override
  String toString() {
    return (StringBuffer('SyncMetaCompanion(')
          ..write('id: $id, ')
          ..write('lastPulledSeq: $lastPulledSeq, ')
          ..write('lastServerTimeIso: $lastServerTimeIso, ')
          ..write('serverTimeOffsetMs: $serverTimeOffsetMs, ')
          ..write('elapsedAnchorMs: $elapsedAnchorMs, ')
          ..write('snapshotDone: $snapshotDone, ')
          ..write('deviceId: $deviceId, ')
          ..write('validUntilIso: $validUntilIso')
          ..write(')'))
        .toString();
  }
}

abstract class _$AppDatabase extends GeneratedDatabase {
  _$AppDatabase(QueryExecutor e) : super(e);
  $AppDatabaseManager get managers => $AppDatabaseManager(this);
  late final $CustomersTable customers = $CustomersTable(this);
  late final $CustomerPhonesTable customerPhones = $CustomerPhonesTable(this);
  late final $CustomerAddressesTable customerAddresses =
      $CustomerAddressesTable(this);
  late final $ProductsTable products = $ProductsTable(this);
  late final $OrdersTable orders = $OrdersTable(this);
  late final $OrderLinesTable orderLines = $OrderLinesTable(this);
  late final $OrderEventsTable orderEvents = $OrderEventsTable(this);
  late final $LedgerEntriesTable ledgerEntries = $LedgerEntriesTable(this);
  late final $OutboxTable outbox = $OutboxTable(this);
  late final $SyncMetaTable syncMeta = $SyncMetaTable(this);
  late final Index idxPhonesLast10 = Index(
    'idx_phones_last10',
    'CREATE INDEX idx_phones_last10 ON customer_phones (phone_last10)',
  );
  @override
  Iterable<TableInfo<Table, Object?>> get allTables =>
      allSchemaEntities.whereType<TableInfo<Table, Object?>>();
  @override
  List<DatabaseSchemaEntity> get allSchemaEntities => [
    customers,
    customerPhones,
    customerAddresses,
    products,
    orders,
    orderLines,
    orderEvents,
    ledgerEntries,
    outbox,
    syncMeta,
    idxPhonesLast10,
  ];
}

typedef $$CustomersTableCreateCompanionBuilder =
    CustomersCompanion Function({
      required String id,
      required String name,
      Value<String?> note,
      Value<int> balanceKurus,
      required String updatedOccurredAt,
      Value<String?> updatedDeviceId,
      Value<String?> deletedAt,
      Value<int> rowid,
    });
typedef $$CustomersTableUpdateCompanionBuilder =
    CustomersCompanion Function({
      Value<String> id,
      Value<String> name,
      Value<String?> note,
      Value<int> balanceKurus,
      Value<String> updatedOccurredAt,
      Value<String?> updatedDeviceId,
      Value<String?> deletedAt,
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
    column: $table.id,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<String> get name => $composableBuilder(
    column: $table.name,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<String> get note => $composableBuilder(
    column: $table.note,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<int> get balanceKurus => $composableBuilder(
    column: $table.balanceKurus,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<String> get updatedOccurredAt => $composableBuilder(
    column: $table.updatedOccurredAt,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<String> get updatedDeviceId => $composableBuilder(
    column: $table.updatedDeviceId,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<String> get deletedAt => $composableBuilder(
    column: $table.deletedAt,
    builder: (column) => ColumnFilters(column),
  );
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
    column: $table.id,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<String> get name => $composableBuilder(
    column: $table.name,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<String> get note => $composableBuilder(
    column: $table.note,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<int> get balanceKurus => $composableBuilder(
    column: $table.balanceKurus,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<String> get updatedOccurredAt => $composableBuilder(
    column: $table.updatedOccurredAt,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<String> get updatedDeviceId => $composableBuilder(
    column: $table.updatedDeviceId,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<String> get deletedAt => $composableBuilder(
    column: $table.deletedAt,
    builder: (column) => ColumnOrderings(column),
  );
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

  GeneratedColumn<String> get note =>
      $composableBuilder(column: $table.note, builder: (column) => column);

  GeneratedColumn<int> get balanceKurus => $composableBuilder(
    column: $table.balanceKurus,
    builder: (column) => column,
  );

  GeneratedColumn<String> get updatedOccurredAt => $composableBuilder(
    column: $table.updatedOccurredAt,
    builder: (column) => column,
  );

  GeneratedColumn<String> get updatedDeviceId => $composableBuilder(
    column: $table.updatedDeviceId,
    builder: (column) => column,
  );

  GeneratedColumn<String> get deletedAt =>
      $composableBuilder(column: $table.deletedAt, builder: (column) => column);
}

class $$CustomersTableTableManager
    extends
        RootTableManager<
          _$AppDatabase,
          $CustomersTable,
          Customer,
          $$CustomersTableFilterComposer,
          $$CustomersTableOrderingComposer,
          $$CustomersTableAnnotationComposer,
          $$CustomersTableCreateCompanionBuilder,
          $$CustomersTableUpdateCompanionBuilder,
          (Customer, BaseReferences<_$AppDatabase, $CustomersTable, Customer>),
          Customer,
          PrefetchHooks Function()
        > {
  $$CustomersTableTableManager(_$AppDatabase db, $CustomersTable table)
    : super(
        TableManagerState(
          db: db,
          table: table,
          createFilteringComposer: () =>
              $$CustomersTableFilterComposer($db: db, $table: table),
          createOrderingComposer: () =>
              $$CustomersTableOrderingComposer($db: db, $table: table),
          createComputedFieldComposer: () =>
              $$CustomersTableAnnotationComposer($db: db, $table: table),
          updateCompanionCallback:
              ({
                Value<String> id = const Value.absent(),
                Value<String> name = const Value.absent(),
                Value<String?> note = const Value.absent(),
                Value<int> balanceKurus = const Value.absent(),
                Value<String> updatedOccurredAt = const Value.absent(),
                Value<String?> updatedDeviceId = const Value.absent(),
                Value<String?> deletedAt = const Value.absent(),
                Value<int> rowid = const Value.absent(),
              }) => CustomersCompanion(
                id: id,
                name: name,
                note: note,
                balanceKurus: balanceKurus,
                updatedOccurredAt: updatedOccurredAt,
                updatedDeviceId: updatedDeviceId,
                deletedAt: deletedAt,
                rowid: rowid,
              ),
          createCompanionCallback:
              ({
                required String id,
                required String name,
                Value<String?> note = const Value.absent(),
                Value<int> balanceKurus = const Value.absent(),
                required String updatedOccurredAt,
                Value<String?> updatedDeviceId = const Value.absent(),
                Value<String?> deletedAt = const Value.absent(),
                Value<int> rowid = const Value.absent(),
              }) => CustomersCompanion.insert(
                id: id,
                name: name,
                note: note,
                balanceKurus: balanceKurus,
                updatedOccurredAt: updatedOccurredAt,
                updatedDeviceId: updatedDeviceId,
                deletedAt: deletedAt,
                rowid: rowid,
              ),
          withReferenceMapper: (p0) => p0
              .map((e) => (e.readTable(table), BaseReferences(db, table, e)))
              .toList(),
          prefetchHooksCallback: null,
        ),
      );
}

typedef $$CustomersTableProcessedTableManager =
    ProcessedTableManager<
      _$AppDatabase,
      $CustomersTable,
      Customer,
      $$CustomersTableFilterComposer,
      $$CustomersTableOrderingComposer,
      $$CustomersTableAnnotationComposer,
      $$CustomersTableCreateCompanionBuilder,
      $$CustomersTableUpdateCompanionBuilder,
      (Customer, BaseReferences<_$AppDatabase, $CustomersTable, Customer>),
      Customer,
      PrefetchHooks Function()
    >;
typedef $$CustomerPhonesTableCreateCompanionBuilder =
    CustomerPhonesCompanion Function({
      required String id,
      required String customerId,
      required String phoneE164,
      required String phoneLast10,
      Value<String?> label,
      Value<bool> isPrimary,
      required String updatedOccurredAt,
      Value<String?> updatedDeviceId,
      Value<String?> deletedAt,
      Value<int> rowid,
    });
typedef $$CustomerPhonesTableUpdateCompanionBuilder =
    CustomerPhonesCompanion Function({
      Value<String> id,
      Value<String> customerId,
      Value<String> phoneE164,
      Value<String> phoneLast10,
      Value<String?> label,
      Value<bool> isPrimary,
      Value<String> updatedOccurredAt,
      Value<String?> updatedDeviceId,
      Value<String?> deletedAt,
      Value<int> rowid,
    });

class $$CustomerPhonesTableFilterComposer
    extends Composer<_$AppDatabase, $CustomerPhonesTable> {
  $$CustomerPhonesTableFilterComposer({
    required super.$db,
    required super.$table,
    super.joinBuilder,
    super.$addJoinBuilderToRootComposer,
    super.$removeJoinBuilderFromRootComposer,
  });
  ColumnFilters<String> get id => $composableBuilder(
    column: $table.id,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<String> get customerId => $composableBuilder(
    column: $table.customerId,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<String> get phoneE164 => $composableBuilder(
    column: $table.phoneE164,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<String> get phoneLast10 => $composableBuilder(
    column: $table.phoneLast10,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<String> get label => $composableBuilder(
    column: $table.label,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<bool> get isPrimary => $composableBuilder(
    column: $table.isPrimary,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<String> get updatedOccurredAt => $composableBuilder(
    column: $table.updatedOccurredAt,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<String> get updatedDeviceId => $composableBuilder(
    column: $table.updatedDeviceId,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<String> get deletedAt => $composableBuilder(
    column: $table.deletedAt,
    builder: (column) => ColumnFilters(column),
  );
}

class $$CustomerPhonesTableOrderingComposer
    extends Composer<_$AppDatabase, $CustomerPhonesTable> {
  $$CustomerPhonesTableOrderingComposer({
    required super.$db,
    required super.$table,
    super.joinBuilder,
    super.$addJoinBuilderToRootComposer,
    super.$removeJoinBuilderFromRootComposer,
  });
  ColumnOrderings<String> get id => $composableBuilder(
    column: $table.id,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<String> get customerId => $composableBuilder(
    column: $table.customerId,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<String> get phoneE164 => $composableBuilder(
    column: $table.phoneE164,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<String> get phoneLast10 => $composableBuilder(
    column: $table.phoneLast10,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<String> get label => $composableBuilder(
    column: $table.label,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<bool> get isPrimary => $composableBuilder(
    column: $table.isPrimary,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<String> get updatedOccurredAt => $composableBuilder(
    column: $table.updatedOccurredAt,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<String> get updatedDeviceId => $composableBuilder(
    column: $table.updatedDeviceId,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<String> get deletedAt => $composableBuilder(
    column: $table.deletedAt,
    builder: (column) => ColumnOrderings(column),
  );
}

class $$CustomerPhonesTableAnnotationComposer
    extends Composer<_$AppDatabase, $CustomerPhonesTable> {
  $$CustomerPhonesTableAnnotationComposer({
    required super.$db,
    required super.$table,
    super.joinBuilder,
    super.$addJoinBuilderToRootComposer,
    super.$removeJoinBuilderFromRootComposer,
  });
  GeneratedColumn<String> get id =>
      $composableBuilder(column: $table.id, builder: (column) => column);

  GeneratedColumn<String> get customerId => $composableBuilder(
    column: $table.customerId,
    builder: (column) => column,
  );

  GeneratedColumn<String> get phoneE164 =>
      $composableBuilder(column: $table.phoneE164, builder: (column) => column);

  GeneratedColumn<String> get phoneLast10 => $composableBuilder(
    column: $table.phoneLast10,
    builder: (column) => column,
  );

  GeneratedColumn<String> get label =>
      $composableBuilder(column: $table.label, builder: (column) => column);

  GeneratedColumn<bool> get isPrimary =>
      $composableBuilder(column: $table.isPrimary, builder: (column) => column);

  GeneratedColumn<String> get updatedOccurredAt => $composableBuilder(
    column: $table.updatedOccurredAt,
    builder: (column) => column,
  );

  GeneratedColumn<String> get updatedDeviceId => $composableBuilder(
    column: $table.updatedDeviceId,
    builder: (column) => column,
  );

  GeneratedColumn<String> get deletedAt =>
      $composableBuilder(column: $table.deletedAt, builder: (column) => column);
}

class $$CustomerPhonesTableTableManager
    extends
        RootTableManager<
          _$AppDatabase,
          $CustomerPhonesTable,
          CustomerPhone,
          $$CustomerPhonesTableFilterComposer,
          $$CustomerPhonesTableOrderingComposer,
          $$CustomerPhonesTableAnnotationComposer,
          $$CustomerPhonesTableCreateCompanionBuilder,
          $$CustomerPhonesTableUpdateCompanionBuilder,
          (
            CustomerPhone,
            BaseReferences<_$AppDatabase, $CustomerPhonesTable, CustomerPhone>,
          ),
          CustomerPhone,
          PrefetchHooks Function()
        > {
  $$CustomerPhonesTableTableManager(
    _$AppDatabase db,
    $CustomerPhonesTable table,
  ) : super(
        TableManagerState(
          db: db,
          table: table,
          createFilteringComposer: () =>
              $$CustomerPhonesTableFilterComposer($db: db, $table: table),
          createOrderingComposer: () =>
              $$CustomerPhonesTableOrderingComposer($db: db, $table: table),
          createComputedFieldComposer: () =>
              $$CustomerPhonesTableAnnotationComposer($db: db, $table: table),
          updateCompanionCallback:
              ({
                Value<String> id = const Value.absent(),
                Value<String> customerId = const Value.absent(),
                Value<String> phoneE164 = const Value.absent(),
                Value<String> phoneLast10 = const Value.absent(),
                Value<String?> label = const Value.absent(),
                Value<bool> isPrimary = const Value.absent(),
                Value<String> updatedOccurredAt = const Value.absent(),
                Value<String?> updatedDeviceId = const Value.absent(),
                Value<String?> deletedAt = const Value.absent(),
                Value<int> rowid = const Value.absent(),
              }) => CustomerPhonesCompanion(
                id: id,
                customerId: customerId,
                phoneE164: phoneE164,
                phoneLast10: phoneLast10,
                label: label,
                isPrimary: isPrimary,
                updatedOccurredAt: updatedOccurredAt,
                updatedDeviceId: updatedDeviceId,
                deletedAt: deletedAt,
                rowid: rowid,
              ),
          createCompanionCallback:
              ({
                required String id,
                required String customerId,
                required String phoneE164,
                required String phoneLast10,
                Value<String?> label = const Value.absent(),
                Value<bool> isPrimary = const Value.absent(),
                required String updatedOccurredAt,
                Value<String?> updatedDeviceId = const Value.absent(),
                Value<String?> deletedAt = const Value.absent(),
                Value<int> rowid = const Value.absent(),
              }) => CustomerPhonesCompanion.insert(
                id: id,
                customerId: customerId,
                phoneE164: phoneE164,
                phoneLast10: phoneLast10,
                label: label,
                isPrimary: isPrimary,
                updatedOccurredAt: updatedOccurredAt,
                updatedDeviceId: updatedDeviceId,
                deletedAt: deletedAt,
                rowid: rowid,
              ),
          withReferenceMapper: (p0) => p0
              .map((e) => (e.readTable(table), BaseReferences(db, table, e)))
              .toList(),
          prefetchHooksCallback: null,
        ),
      );
}

typedef $$CustomerPhonesTableProcessedTableManager =
    ProcessedTableManager<
      _$AppDatabase,
      $CustomerPhonesTable,
      CustomerPhone,
      $$CustomerPhonesTableFilterComposer,
      $$CustomerPhonesTableOrderingComposer,
      $$CustomerPhonesTableAnnotationComposer,
      $$CustomerPhonesTableCreateCompanionBuilder,
      $$CustomerPhonesTableUpdateCompanionBuilder,
      (
        CustomerPhone,
        BaseReferences<_$AppDatabase, $CustomerPhonesTable, CustomerPhone>,
      ),
      CustomerPhone,
      PrefetchHooks Function()
    >;
typedef $$CustomerAddressesTableCreateCompanionBuilder =
    CustomerAddressesCompanion Function({
      required String id,
      required String customerId,
      Value<String?> label,
      required String addressText,
      Value<double?> lat,
      Value<double?> lng,
      Value<bool> isPrimary,
      required String updatedOccurredAt,
      Value<String?> updatedDeviceId,
      Value<String?> deletedAt,
      Value<int> rowid,
    });
typedef $$CustomerAddressesTableUpdateCompanionBuilder =
    CustomerAddressesCompanion Function({
      Value<String> id,
      Value<String> customerId,
      Value<String?> label,
      Value<String> addressText,
      Value<double?> lat,
      Value<double?> lng,
      Value<bool> isPrimary,
      Value<String> updatedOccurredAt,
      Value<String?> updatedDeviceId,
      Value<String?> deletedAt,
      Value<int> rowid,
    });

class $$CustomerAddressesTableFilterComposer
    extends Composer<_$AppDatabase, $CustomerAddressesTable> {
  $$CustomerAddressesTableFilterComposer({
    required super.$db,
    required super.$table,
    super.joinBuilder,
    super.$addJoinBuilderToRootComposer,
    super.$removeJoinBuilderFromRootComposer,
  });
  ColumnFilters<String> get id => $composableBuilder(
    column: $table.id,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<String> get customerId => $composableBuilder(
    column: $table.customerId,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<String> get label => $composableBuilder(
    column: $table.label,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<String> get addressText => $composableBuilder(
    column: $table.addressText,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<double> get lat => $composableBuilder(
    column: $table.lat,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<double> get lng => $composableBuilder(
    column: $table.lng,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<bool> get isPrimary => $composableBuilder(
    column: $table.isPrimary,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<String> get updatedOccurredAt => $composableBuilder(
    column: $table.updatedOccurredAt,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<String> get updatedDeviceId => $composableBuilder(
    column: $table.updatedDeviceId,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<String> get deletedAt => $composableBuilder(
    column: $table.deletedAt,
    builder: (column) => ColumnFilters(column),
  );
}

class $$CustomerAddressesTableOrderingComposer
    extends Composer<_$AppDatabase, $CustomerAddressesTable> {
  $$CustomerAddressesTableOrderingComposer({
    required super.$db,
    required super.$table,
    super.joinBuilder,
    super.$addJoinBuilderToRootComposer,
    super.$removeJoinBuilderFromRootComposer,
  });
  ColumnOrderings<String> get id => $composableBuilder(
    column: $table.id,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<String> get customerId => $composableBuilder(
    column: $table.customerId,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<String> get label => $composableBuilder(
    column: $table.label,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<String> get addressText => $composableBuilder(
    column: $table.addressText,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<double> get lat => $composableBuilder(
    column: $table.lat,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<double> get lng => $composableBuilder(
    column: $table.lng,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<bool> get isPrimary => $composableBuilder(
    column: $table.isPrimary,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<String> get updatedOccurredAt => $composableBuilder(
    column: $table.updatedOccurredAt,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<String> get updatedDeviceId => $composableBuilder(
    column: $table.updatedDeviceId,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<String> get deletedAt => $composableBuilder(
    column: $table.deletedAt,
    builder: (column) => ColumnOrderings(column),
  );
}

class $$CustomerAddressesTableAnnotationComposer
    extends Composer<_$AppDatabase, $CustomerAddressesTable> {
  $$CustomerAddressesTableAnnotationComposer({
    required super.$db,
    required super.$table,
    super.joinBuilder,
    super.$addJoinBuilderToRootComposer,
    super.$removeJoinBuilderFromRootComposer,
  });
  GeneratedColumn<String> get id =>
      $composableBuilder(column: $table.id, builder: (column) => column);

  GeneratedColumn<String> get customerId => $composableBuilder(
    column: $table.customerId,
    builder: (column) => column,
  );

  GeneratedColumn<String> get label =>
      $composableBuilder(column: $table.label, builder: (column) => column);

  GeneratedColumn<String> get addressText => $composableBuilder(
    column: $table.addressText,
    builder: (column) => column,
  );

  GeneratedColumn<double> get lat =>
      $composableBuilder(column: $table.lat, builder: (column) => column);

  GeneratedColumn<double> get lng =>
      $composableBuilder(column: $table.lng, builder: (column) => column);

  GeneratedColumn<bool> get isPrimary =>
      $composableBuilder(column: $table.isPrimary, builder: (column) => column);

  GeneratedColumn<String> get updatedOccurredAt => $composableBuilder(
    column: $table.updatedOccurredAt,
    builder: (column) => column,
  );

  GeneratedColumn<String> get updatedDeviceId => $composableBuilder(
    column: $table.updatedDeviceId,
    builder: (column) => column,
  );

  GeneratedColumn<String> get deletedAt =>
      $composableBuilder(column: $table.deletedAt, builder: (column) => column);
}

class $$CustomerAddressesTableTableManager
    extends
        RootTableManager<
          _$AppDatabase,
          $CustomerAddressesTable,
          CustomerAddressesData,
          $$CustomerAddressesTableFilterComposer,
          $$CustomerAddressesTableOrderingComposer,
          $$CustomerAddressesTableAnnotationComposer,
          $$CustomerAddressesTableCreateCompanionBuilder,
          $$CustomerAddressesTableUpdateCompanionBuilder,
          (
            CustomerAddressesData,
            BaseReferences<
              _$AppDatabase,
              $CustomerAddressesTable,
              CustomerAddressesData
            >,
          ),
          CustomerAddressesData,
          PrefetchHooks Function()
        > {
  $$CustomerAddressesTableTableManager(
    _$AppDatabase db,
    $CustomerAddressesTable table,
  ) : super(
        TableManagerState(
          db: db,
          table: table,
          createFilteringComposer: () =>
              $$CustomerAddressesTableFilterComposer($db: db, $table: table),
          createOrderingComposer: () =>
              $$CustomerAddressesTableOrderingComposer($db: db, $table: table),
          createComputedFieldComposer: () =>
              $$CustomerAddressesTableAnnotationComposer(
                $db: db,
                $table: table,
              ),
          updateCompanionCallback:
              ({
                Value<String> id = const Value.absent(),
                Value<String> customerId = const Value.absent(),
                Value<String?> label = const Value.absent(),
                Value<String> addressText = const Value.absent(),
                Value<double?> lat = const Value.absent(),
                Value<double?> lng = const Value.absent(),
                Value<bool> isPrimary = const Value.absent(),
                Value<String> updatedOccurredAt = const Value.absent(),
                Value<String?> updatedDeviceId = const Value.absent(),
                Value<String?> deletedAt = const Value.absent(),
                Value<int> rowid = const Value.absent(),
              }) => CustomerAddressesCompanion(
                id: id,
                customerId: customerId,
                label: label,
                addressText: addressText,
                lat: lat,
                lng: lng,
                isPrimary: isPrimary,
                updatedOccurredAt: updatedOccurredAt,
                updatedDeviceId: updatedDeviceId,
                deletedAt: deletedAt,
                rowid: rowid,
              ),
          createCompanionCallback:
              ({
                required String id,
                required String customerId,
                Value<String?> label = const Value.absent(),
                required String addressText,
                Value<double?> lat = const Value.absent(),
                Value<double?> lng = const Value.absent(),
                Value<bool> isPrimary = const Value.absent(),
                required String updatedOccurredAt,
                Value<String?> updatedDeviceId = const Value.absent(),
                Value<String?> deletedAt = const Value.absent(),
                Value<int> rowid = const Value.absent(),
              }) => CustomerAddressesCompanion.insert(
                id: id,
                customerId: customerId,
                label: label,
                addressText: addressText,
                lat: lat,
                lng: lng,
                isPrimary: isPrimary,
                updatedOccurredAt: updatedOccurredAt,
                updatedDeviceId: updatedDeviceId,
                deletedAt: deletedAt,
                rowid: rowid,
              ),
          withReferenceMapper: (p0) => p0
              .map((e) => (e.readTable(table), BaseReferences(db, table, e)))
              .toList(),
          prefetchHooksCallback: null,
        ),
      );
}

typedef $$CustomerAddressesTableProcessedTableManager =
    ProcessedTableManager<
      _$AppDatabase,
      $CustomerAddressesTable,
      CustomerAddressesData,
      $$CustomerAddressesTableFilterComposer,
      $$CustomerAddressesTableOrderingComposer,
      $$CustomerAddressesTableAnnotationComposer,
      $$CustomerAddressesTableCreateCompanionBuilder,
      $$CustomerAddressesTableUpdateCompanionBuilder,
      (
        CustomerAddressesData,
        BaseReferences<
          _$AppDatabase,
          $CustomerAddressesTable,
          CustomerAddressesData
        >,
      ),
      CustomerAddressesData,
      PrefetchHooks Function()
    >;
typedef $$ProductsTableCreateCompanionBuilder =
    ProductsCompanion Function({
      required String id,
      required String name,
      required int unitPriceKurus,
      Value<String> unit,
      Value<bool> isActive,
      required String updatedOccurredAt,
      Value<String?> updatedDeviceId,
      Value<String?> deletedAt,
      Value<int> rowid,
    });
typedef $$ProductsTableUpdateCompanionBuilder =
    ProductsCompanion Function({
      Value<String> id,
      Value<String> name,
      Value<int> unitPriceKurus,
      Value<String> unit,
      Value<bool> isActive,
      Value<String> updatedOccurredAt,
      Value<String?> updatedDeviceId,
      Value<String?> deletedAt,
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
    column: $table.id,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<String> get name => $composableBuilder(
    column: $table.name,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<int> get unitPriceKurus => $composableBuilder(
    column: $table.unitPriceKurus,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<String> get unit => $composableBuilder(
    column: $table.unit,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<bool> get isActive => $composableBuilder(
    column: $table.isActive,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<String> get updatedOccurredAt => $composableBuilder(
    column: $table.updatedOccurredAt,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<String> get updatedDeviceId => $composableBuilder(
    column: $table.updatedDeviceId,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<String> get deletedAt => $composableBuilder(
    column: $table.deletedAt,
    builder: (column) => ColumnFilters(column),
  );
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
    column: $table.id,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<String> get name => $composableBuilder(
    column: $table.name,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<int> get unitPriceKurus => $composableBuilder(
    column: $table.unitPriceKurus,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<String> get unit => $composableBuilder(
    column: $table.unit,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<bool> get isActive => $composableBuilder(
    column: $table.isActive,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<String> get updatedOccurredAt => $composableBuilder(
    column: $table.updatedOccurredAt,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<String> get updatedDeviceId => $composableBuilder(
    column: $table.updatedDeviceId,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<String> get deletedAt => $composableBuilder(
    column: $table.deletedAt,
    builder: (column) => ColumnOrderings(column),
  );
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

  GeneratedColumn<int> get unitPriceKurus => $composableBuilder(
    column: $table.unitPriceKurus,
    builder: (column) => column,
  );

  GeneratedColumn<String> get unit =>
      $composableBuilder(column: $table.unit, builder: (column) => column);

  GeneratedColumn<bool> get isActive =>
      $composableBuilder(column: $table.isActive, builder: (column) => column);

  GeneratedColumn<String> get updatedOccurredAt => $composableBuilder(
    column: $table.updatedOccurredAt,
    builder: (column) => column,
  );

  GeneratedColumn<String> get updatedDeviceId => $composableBuilder(
    column: $table.updatedDeviceId,
    builder: (column) => column,
  );

  GeneratedColumn<String> get deletedAt =>
      $composableBuilder(column: $table.deletedAt, builder: (column) => column);
}

class $$ProductsTableTableManager
    extends
        RootTableManager<
          _$AppDatabase,
          $ProductsTable,
          Product,
          $$ProductsTableFilterComposer,
          $$ProductsTableOrderingComposer,
          $$ProductsTableAnnotationComposer,
          $$ProductsTableCreateCompanionBuilder,
          $$ProductsTableUpdateCompanionBuilder,
          (Product, BaseReferences<_$AppDatabase, $ProductsTable, Product>),
          Product,
          PrefetchHooks Function()
        > {
  $$ProductsTableTableManager(_$AppDatabase db, $ProductsTable table)
    : super(
        TableManagerState(
          db: db,
          table: table,
          createFilteringComposer: () =>
              $$ProductsTableFilterComposer($db: db, $table: table),
          createOrderingComposer: () =>
              $$ProductsTableOrderingComposer($db: db, $table: table),
          createComputedFieldComposer: () =>
              $$ProductsTableAnnotationComposer($db: db, $table: table),
          updateCompanionCallback:
              ({
                Value<String> id = const Value.absent(),
                Value<String> name = const Value.absent(),
                Value<int> unitPriceKurus = const Value.absent(),
                Value<String> unit = const Value.absent(),
                Value<bool> isActive = const Value.absent(),
                Value<String> updatedOccurredAt = const Value.absent(),
                Value<String?> updatedDeviceId = const Value.absent(),
                Value<String?> deletedAt = const Value.absent(),
                Value<int> rowid = const Value.absent(),
              }) => ProductsCompanion(
                id: id,
                name: name,
                unitPriceKurus: unitPriceKurus,
                unit: unit,
                isActive: isActive,
                updatedOccurredAt: updatedOccurredAt,
                updatedDeviceId: updatedDeviceId,
                deletedAt: deletedAt,
                rowid: rowid,
              ),
          createCompanionCallback:
              ({
                required String id,
                required String name,
                required int unitPriceKurus,
                Value<String> unit = const Value.absent(),
                Value<bool> isActive = const Value.absent(),
                required String updatedOccurredAt,
                Value<String?> updatedDeviceId = const Value.absent(),
                Value<String?> deletedAt = const Value.absent(),
                Value<int> rowid = const Value.absent(),
              }) => ProductsCompanion.insert(
                id: id,
                name: name,
                unitPriceKurus: unitPriceKurus,
                unit: unit,
                isActive: isActive,
                updatedOccurredAt: updatedOccurredAt,
                updatedDeviceId: updatedDeviceId,
                deletedAt: deletedAt,
                rowid: rowid,
              ),
          withReferenceMapper: (p0) => p0
              .map((e) => (e.readTable(table), BaseReferences(db, table, e)))
              .toList(),
          prefetchHooksCallback: null,
        ),
      );
}

typedef $$ProductsTableProcessedTableManager =
    ProcessedTableManager<
      _$AppDatabase,
      $ProductsTable,
      Product,
      $$ProductsTableFilterComposer,
      $$ProductsTableOrderingComposer,
      $$ProductsTableAnnotationComposer,
      $$ProductsTableCreateCompanionBuilder,
      $$ProductsTableUpdateCompanionBuilder,
      (Product, BaseReferences<_$AppDatabase, $ProductsTable, Product>),
      Product,
      PrefetchHooks Function()
    >;
typedef $$OrdersTableCreateCompanionBuilder =
    OrdersCompanion Function({
      required String id,
      Value<String?> customerId,
      Value<String> status,
      Value<int> totalKurus,
      Value<String?> paymentType,
      Value<String?> note,
      required String occurredAt,
      Value<String?> createdDeviceId,
      Value<String?> deletedAt,
      Value<int> rowid,
    });
typedef $$OrdersTableUpdateCompanionBuilder =
    OrdersCompanion Function({
      Value<String> id,
      Value<String?> customerId,
      Value<String> status,
      Value<int> totalKurus,
      Value<String?> paymentType,
      Value<String?> note,
      Value<String> occurredAt,
      Value<String?> createdDeviceId,
      Value<String?> deletedAt,
      Value<int> rowid,
    });

class $$OrdersTableFilterComposer
    extends Composer<_$AppDatabase, $OrdersTable> {
  $$OrdersTableFilterComposer({
    required super.$db,
    required super.$table,
    super.joinBuilder,
    super.$addJoinBuilderToRootComposer,
    super.$removeJoinBuilderFromRootComposer,
  });
  ColumnFilters<String> get id => $composableBuilder(
    column: $table.id,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<String> get customerId => $composableBuilder(
    column: $table.customerId,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<String> get status => $composableBuilder(
    column: $table.status,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<int> get totalKurus => $composableBuilder(
    column: $table.totalKurus,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<String> get paymentType => $composableBuilder(
    column: $table.paymentType,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<String> get note => $composableBuilder(
    column: $table.note,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<String> get occurredAt => $composableBuilder(
    column: $table.occurredAt,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<String> get createdDeviceId => $composableBuilder(
    column: $table.createdDeviceId,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<String> get deletedAt => $composableBuilder(
    column: $table.deletedAt,
    builder: (column) => ColumnFilters(column),
  );
}

class $$OrdersTableOrderingComposer
    extends Composer<_$AppDatabase, $OrdersTable> {
  $$OrdersTableOrderingComposer({
    required super.$db,
    required super.$table,
    super.joinBuilder,
    super.$addJoinBuilderToRootComposer,
    super.$removeJoinBuilderFromRootComposer,
  });
  ColumnOrderings<String> get id => $composableBuilder(
    column: $table.id,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<String> get customerId => $composableBuilder(
    column: $table.customerId,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<String> get status => $composableBuilder(
    column: $table.status,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<int> get totalKurus => $composableBuilder(
    column: $table.totalKurus,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<String> get paymentType => $composableBuilder(
    column: $table.paymentType,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<String> get note => $composableBuilder(
    column: $table.note,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<String> get occurredAt => $composableBuilder(
    column: $table.occurredAt,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<String> get createdDeviceId => $composableBuilder(
    column: $table.createdDeviceId,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<String> get deletedAt => $composableBuilder(
    column: $table.deletedAt,
    builder: (column) => ColumnOrderings(column),
  );
}

class $$OrdersTableAnnotationComposer
    extends Composer<_$AppDatabase, $OrdersTable> {
  $$OrdersTableAnnotationComposer({
    required super.$db,
    required super.$table,
    super.joinBuilder,
    super.$addJoinBuilderToRootComposer,
    super.$removeJoinBuilderFromRootComposer,
  });
  GeneratedColumn<String> get id =>
      $composableBuilder(column: $table.id, builder: (column) => column);

  GeneratedColumn<String> get customerId => $composableBuilder(
    column: $table.customerId,
    builder: (column) => column,
  );

  GeneratedColumn<String> get status =>
      $composableBuilder(column: $table.status, builder: (column) => column);

  GeneratedColumn<int> get totalKurus => $composableBuilder(
    column: $table.totalKurus,
    builder: (column) => column,
  );

  GeneratedColumn<String> get paymentType => $composableBuilder(
    column: $table.paymentType,
    builder: (column) => column,
  );

  GeneratedColumn<String> get note =>
      $composableBuilder(column: $table.note, builder: (column) => column);

  GeneratedColumn<String> get occurredAt => $composableBuilder(
    column: $table.occurredAt,
    builder: (column) => column,
  );

  GeneratedColumn<String> get createdDeviceId => $composableBuilder(
    column: $table.createdDeviceId,
    builder: (column) => column,
  );

  GeneratedColumn<String> get deletedAt =>
      $composableBuilder(column: $table.deletedAt, builder: (column) => column);
}

class $$OrdersTableTableManager
    extends
        RootTableManager<
          _$AppDatabase,
          $OrdersTable,
          Order,
          $$OrdersTableFilterComposer,
          $$OrdersTableOrderingComposer,
          $$OrdersTableAnnotationComposer,
          $$OrdersTableCreateCompanionBuilder,
          $$OrdersTableUpdateCompanionBuilder,
          (Order, BaseReferences<_$AppDatabase, $OrdersTable, Order>),
          Order,
          PrefetchHooks Function()
        > {
  $$OrdersTableTableManager(_$AppDatabase db, $OrdersTable table)
    : super(
        TableManagerState(
          db: db,
          table: table,
          createFilteringComposer: () =>
              $$OrdersTableFilterComposer($db: db, $table: table),
          createOrderingComposer: () =>
              $$OrdersTableOrderingComposer($db: db, $table: table),
          createComputedFieldComposer: () =>
              $$OrdersTableAnnotationComposer($db: db, $table: table),
          updateCompanionCallback:
              ({
                Value<String> id = const Value.absent(),
                Value<String?> customerId = const Value.absent(),
                Value<String> status = const Value.absent(),
                Value<int> totalKurus = const Value.absent(),
                Value<String?> paymentType = const Value.absent(),
                Value<String?> note = const Value.absent(),
                Value<String> occurredAt = const Value.absent(),
                Value<String?> createdDeviceId = const Value.absent(),
                Value<String?> deletedAt = const Value.absent(),
                Value<int> rowid = const Value.absent(),
              }) => OrdersCompanion(
                id: id,
                customerId: customerId,
                status: status,
                totalKurus: totalKurus,
                paymentType: paymentType,
                note: note,
                occurredAt: occurredAt,
                createdDeviceId: createdDeviceId,
                deletedAt: deletedAt,
                rowid: rowid,
              ),
          createCompanionCallback:
              ({
                required String id,
                Value<String?> customerId = const Value.absent(),
                Value<String> status = const Value.absent(),
                Value<int> totalKurus = const Value.absent(),
                Value<String?> paymentType = const Value.absent(),
                Value<String?> note = const Value.absent(),
                required String occurredAt,
                Value<String?> createdDeviceId = const Value.absent(),
                Value<String?> deletedAt = const Value.absent(),
                Value<int> rowid = const Value.absent(),
              }) => OrdersCompanion.insert(
                id: id,
                customerId: customerId,
                status: status,
                totalKurus: totalKurus,
                paymentType: paymentType,
                note: note,
                occurredAt: occurredAt,
                createdDeviceId: createdDeviceId,
                deletedAt: deletedAt,
                rowid: rowid,
              ),
          withReferenceMapper: (p0) => p0
              .map((e) => (e.readTable(table), BaseReferences(db, table, e)))
              .toList(),
          prefetchHooksCallback: null,
        ),
      );
}

typedef $$OrdersTableProcessedTableManager =
    ProcessedTableManager<
      _$AppDatabase,
      $OrdersTable,
      Order,
      $$OrdersTableFilterComposer,
      $$OrdersTableOrderingComposer,
      $$OrdersTableAnnotationComposer,
      $$OrdersTableCreateCompanionBuilder,
      $$OrdersTableUpdateCompanionBuilder,
      (Order, BaseReferences<_$AppDatabase, $OrdersTable, Order>),
      Order,
      PrefetchHooks Function()
    >;
typedef $$OrderLinesTableCreateCompanionBuilder =
    OrderLinesCompanion Function({
      required String id,
      required String orderId,
      Value<String?> productId,
      required String productName,
      required int unitPriceKurus,
      required int qty,
      required int lineTotalKurus,
      Value<String?> deletedAt,
      Value<int> rowid,
    });
typedef $$OrderLinesTableUpdateCompanionBuilder =
    OrderLinesCompanion Function({
      Value<String> id,
      Value<String> orderId,
      Value<String?> productId,
      Value<String> productName,
      Value<int> unitPriceKurus,
      Value<int> qty,
      Value<int> lineTotalKurus,
      Value<String?> deletedAt,
      Value<int> rowid,
    });

class $$OrderLinesTableFilterComposer
    extends Composer<_$AppDatabase, $OrderLinesTable> {
  $$OrderLinesTableFilterComposer({
    required super.$db,
    required super.$table,
    super.joinBuilder,
    super.$addJoinBuilderToRootComposer,
    super.$removeJoinBuilderFromRootComposer,
  });
  ColumnFilters<String> get id => $composableBuilder(
    column: $table.id,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<String> get orderId => $composableBuilder(
    column: $table.orderId,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<String> get productId => $composableBuilder(
    column: $table.productId,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<String> get productName => $composableBuilder(
    column: $table.productName,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<int> get unitPriceKurus => $composableBuilder(
    column: $table.unitPriceKurus,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<int> get qty => $composableBuilder(
    column: $table.qty,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<int> get lineTotalKurus => $composableBuilder(
    column: $table.lineTotalKurus,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<String> get deletedAt => $composableBuilder(
    column: $table.deletedAt,
    builder: (column) => ColumnFilters(column),
  );
}

class $$OrderLinesTableOrderingComposer
    extends Composer<_$AppDatabase, $OrderLinesTable> {
  $$OrderLinesTableOrderingComposer({
    required super.$db,
    required super.$table,
    super.joinBuilder,
    super.$addJoinBuilderToRootComposer,
    super.$removeJoinBuilderFromRootComposer,
  });
  ColumnOrderings<String> get id => $composableBuilder(
    column: $table.id,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<String> get orderId => $composableBuilder(
    column: $table.orderId,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<String> get productId => $composableBuilder(
    column: $table.productId,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<String> get productName => $composableBuilder(
    column: $table.productName,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<int> get unitPriceKurus => $composableBuilder(
    column: $table.unitPriceKurus,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<int> get qty => $composableBuilder(
    column: $table.qty,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<int> get lineTotalKurus => $composableBuilder(
    column: $table.lineTotalKurus,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<String> get deletedAt => $composableBuilder(
    column: $table.deletedAt,
    builder: (column) => ColumnOrderings(column),
  );
}

class $$OrderLinesTableAnnotationComposer
    extends Composer<_$AppDatabase, $OrderLinesTable> {
  $$OrderLinesTableAnnotationComposer({
    required super.$db,
    required super.$table,
    super.joinBuilder,
    super.$addJoinBuilderToRootComposer,
    super.$removeJoinBuilderFromRootComposer,
  });
  GeneratedColumn<String> get id =>
      $composableBuilder(column: $table.id, builder: (column) => column);

  GeneratedColumn<String> get orderId =>
      $composableBuilder(column: $table.orderId, builder: (column) => column);

  GeneratedColumn<String> get productId =>
      $composableBuilder(column: $table.productId, builder: (column) => column);

  GeneratedColumn<String> get productName => $composableBuilder(
    column: $table.productName,
    builder: (column) => column,
  );

  GeneratedColumn<int> get unitPriceKurus => $composableBuilder(
    column: $table.unitPriceKurus,
    builder: (column) => column,
  );

  GeneratedColumn<int> get qty =>
      $composableBuilder(column: $table.qty, builder: (column) => column);

  GeneratedColumn<int> get lineTotalKurus => $composableBuilder(
    column: $table.lineTotalKurus,
    builder: (column) => column,
  );

  GeneratedColumn<String> get deletedAt =>
      $composableBuilder(column: $table.deletedAt, builder: (column) => column);
}

class $$OrderLinesTableTableManager
    extends
        RootTableManager<
          _$AppDatabase,
          $OrderLinesTable,
          OrderLine,
          $$OrderLinesTableFilterComposer,
          $$OrderLinesTableOrderingComposer,
          $$OrderLinesTableAnnotationComposer,
          $$OrderLinesTableCreateCompanionBuilder,
          $$OrderLinesTableUpdateCompanionBuilder,
          (
            OrderLine,
            BaseReferences<_$AppDatabase, $OrderLinesTable, OrderLine>,
          ),
          OrderLine,
          PrefetchHooks Function()
        > {
  $$OrderLinesTableTableManager(_$AppDatabase db, $OrderLinesTable table)
    : super(
        TableManagerState(
          db: db,
          table: table,
          createFilteringComposer: () =>
              $$OrderLinesTableFilterComposer($db: db, $table: table),
          createOrderingComposer: () =>
              $$OrderLinesTableOrderingComposer($db: db, $table: table),
          createComputedFieldComposer: () =>
              $$OrderLinesTableAnnotationComposer($db: db, $table: table),
          updateCompanionCallback:
              ({
                Value<String> id = const Value.absent(),
                Value<String> orderId = const Value.absent(),
                Value<String?> productId = const Value.absent(),
                Value<String> productName = const Value.absent(),
                Value<int> unitPriceKurus = const Value.absent(),
                Value<int> qty = const Value.absent(),
                Value<int> lineTotalKurus = const Value.absent(),
                Value<String?> deletedAt = const Value.absent(),
                Value<int> rowid = const Value.absent(),
              }) => OrderLinesCompanion(
                id: id,
                orderId: orderId,
                productId: productId,
                productName: productName,
                unitPriceKurus: unitPriceKurus,
                qty: qty,
                lineTotalKurus: lineTotalKurus,
                deletedAt: deletedAt,
                rowid: rowid,
              ),
          createCompanionCallback:
              ({
                required String id,
                required String orderId,
                Value<String?> productId = const Value.absent(),
                required String productName,
                required int unitPriceKurus,
                required int qty,
                required int lineTotalKurus,
                Value<String?> deletedAt = const Value.absent(),
                Value<int> rowid = const Value.absent(),
              }) => OrderLinesCompanion.insert(
                id: id,
                orderId: orderId,
                productId: productId,
                productName: productName,
                unitPriceKurus: unitPriceKurus,
                qty: qty,
                lineTotalKurus: lineTotalKurus,
                deletedAt: deletedAt,
                rowid: rowid,
              ),
          withReferenceMapper: (p0) => p0
              .map((e) => (e.readTable(table), BaseReferences(db, table, e)))
              .toList(),
          prefetchHooksCallback: null,
        ),
      );
}

typedef $$OrderLinesTableProcessedTableManager =
    ProcessedTableManager<
      _$AppDatabase,
      $OrderLinesTable,
      OrderLine,
      $$OrderLinesTableFilterComposer,
      $$OrderLinesTableOrderingComposer,
      $$OrderLinesTableAnnotationComposer,
      $$OrderLinesTableCreateCompanionBuilder,
      $$OrderLinesTableUpdateCompanionBuilder,
      (OrderLine, BaseReferences<_$AppDatabase, $OrderLinesTable, OrderLine>),
      OrderLine,
      PrefetchHooks Function()
    >;
typedef $$OrderEventsTableCreateCompanionBuilder =
    OrderEventsCompanion Function({
      required String id,
      required String orderId,
      required String eventType,
      Value<String?> payload,
      required String clientEventId,
      required String occurredAt,
      Value<String?> deviceId,
      Value<int> rowid,
    });
typedef $$OrderEventsTableUpdateCompanionBuilder =
    OrderEventsCompanion Function({
      Value<String> id,
      Value<String> orderId,
      Value<String> eventType,
      Value<String?> payload,
      Value<String> clientEventId,
      Value<String> occurredAt,
      Value<String?> deviceId,
      Value<int> rowid,
    });

class $$OrderEventsTableFilterComposer
    extends Composer<_$AppDatabase, $OrderEventsTable> {
  $$OrderEventsTableFilterComposer({
    required super.$db,
    required super.$table,
    super.joinBuilder,
    super.$addJoinBuilderToRootComposer,
    super.$removeJoinBuilderFromRootComposer,
  });
  ColumnFilters<String> get id => $composableBuilder(
    column: $table.id,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<String> get orderId => $composableBuilder(
    column: $table.orderId,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<String> get eventType => $composableBuilder(
    column: $table.eventType,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<String> get payload => $composableBuilder(
    column: $table.payload,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<String> get clientEventId => $composableBuilder(
    column: $table.clientEventId,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<String> get occurredAt => $composableBuilder(
    column: $table.occurredAt,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<String> get deviceId => $composableBuilder(
    column: $table.deviceId,
    builder: (column) => ColumnFilters(column),
  );
}

class $$OrderEventsTableOrderingComposer
    extends Composer<_$AppDatabase, $OrderEventsTable> {
  $$OrderEventsTableOrderingComposer({
    required super.$db,
    required super.$table,
    super.joinBuilder,
    super.$addJoinBuilderToRootComposer,
    super.$removeJoinBuilderFromRootComposer,
  });
  ColumnOrderings<String> get id => $composableBuilder(
    column: $table.id,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<String> get orderId => $composableBuilder(
    column: $table.orderId,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<String> get eventType => $composableBuilder(
    column: $table.eventType,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<String> get payload => $composableBuilder(
    column: $table.payload,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<String> get clientEventId => $composableBuilder(
    column: $table.clientEventId,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<String> get occurredAt => $composableBuilder(
    column: $table.occurredAt,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<String> get deviceId => $composableBuilder(
    column: $table.deviceId,
    builder: (column) => ColumnOrderings(column),
  );
}

class $$OrderEventsTableAnnotationComposer
    extends Composer<_$AppDatabase, $OrderEventsTable> {
  $$OrderEventsTableAnnotationComposer({
    required super.$db,
    required super.$table,
    super.joinBuilder,
    super.$addJoinBuilderToRootComposer,
    super.$removeJoinBuilderFromRootComposer,
  });
  GeneratedColumn<String> get id =>
      $composableBuilder(column: $table.id, builder: (column) => column);

  GeneratedColumn<String> get orderId =>
      $composableBuilder(column: $table.orderId, builder: (column) => column);

  GeneratedColumn<String> get eventType =>
      $composableBuilder(column: $table.eventType, builder: (column) => column);

  GeneratedColumn<String> get payload =>
      $composableBuilder(column: $table.payload, builder: (column) => column);

  GeneratedColumn<String> get clientEventId => $composableBuilder(
    column: $table.clientEventId,
    builder: (column) => column,
  );

  GeneratedColumn<String> get occurredAt => $composableBuilder(
    column: $table.occurredAt,
    builder: (column) => column,
  );

  GeneratedColumn<String> get deviceId =>
      $composableBuilder(column: $table.deviceId, builder: (column) => column);
}

class $$OrderEventsTableTableManager
    extends
        RootTableManager<
          _$AppDatabase,
          $OrderEventsTable,
          OrderEvent,
          $$OrderEventsTableFilterComposer,
          $$OrderEventsTableOrderingComposer,
          $$OrderEventsTableAnnotationComposer,
          $$OrderEventsTableCreateCompanionBuilder,
          $$OrderEventsTableUpdateCompanionBuilder,
          (
            OrderEvent,
            BaseReferences<_$AppDatabase, $OrderEventsTable, OrderEvent>,
          ),
          OrderEvent,
          PrefetchHooks Function()
        > {
  $$OrderEventsTableTableManager(_$AppDatabase db, $OrderEventsTable table)
    : super(
        TableManagerState(
          db: db,
          table: table,
          createFilteringComposer: () =>
              $$OrderEventsTableFilterComposer($db: db, $table: table),
          createOrderingComposer: () =>
              $$OrderEventsTableOrderingComposer($db: db, $table: table),
          createComputedFieldComposer: () =>
              $$OrderEventsTableAnnotationComposer($db: db, $table: table),
          updateCompanionCallback:
              ({
                Value<String> id = const Value.absent(),
                Value<String> orderId = const Value.absent(),
                Value<String> eventType = const Value.absent(),
                Value<String?> payload = const Value.absent(),
                Value<String> clientEventId = const Value.absent(),
                Value<String> occurredAt = const Value.absent(),
                Value<String?> deviceId = const Value.absent(),
                Value<int> rowid = const Value.absent(),
              }) => OrderEventsCompanion(
                id: id,
                orderId: orderId,
                eventType: eventType,
                payload: payload,
                clientEventId: clientEventId,
                occurredAt: occurredAt,
                deviceId: deviceId,
                rowid: rowid,
              ),
          createCompanionCallback:
              ({
                required String id,
                required String orderId,
                required String eventType,
                Value<String?> payload = const Value.absent(),
                required String clientEventId,
                required String occurredAt,
                Value<String?> deviceId = const Value.absent(),
                Value<int> rowid = const Value.absent(),
              }) => OrderEventsCompanion.insert(
                id: id,
                orderId: orderId,
                eventType: eventType,
                payload: payload,
                clientEventId: clientEventId,
                occurredAt: occurredAt,
                deviceId: deviceId,
                rowid: rowid,
              ),
          withReferenceMapper: (p0) => p0
              .map((e) => (e.readTable(table), BaseReferences(db, table, e)))
              .toList(),
          prefetchHooksCallback: null,
        ),
      );
}

typedef $$OrderEventsTableProcessedTableManager =
    ProcessedTableManager<
      _$AppDatabase,
      $OrderEventsTable,
      OrderEvent,
      $$OrderEventsTableFilterComposer,
      $$OrderEventsTableOrderingComposer,
      $$OrderEventsTableAnnotationComposer,
      $$OrderEventsTableCreateCompanionBuilder,
      $$OrderEventsTableUpdateCompanionBuilder,
      (
        OrderEvent,
        BaseReferences<_$AppDatabase, $OrderEventsTable, OrderEvent>,
      ),
      OrderEvent,
      PrefetchHooks Function()
    >;
typedef $$LedgerEntriesTableCreateCompanionBuilder =
    LedgerEntriesCompanion Function({
      required String id,
      Value<String?> customerId,
      required String entryType,
      required int amountKurus,
      Value<String?> relatedOrderId,
      Value<String?> note,
      required String occurredAt,
      Value<String?> deviceId,
      required String clientEventId,
      Value<int> rowid,
    });
typedef $$LedgerEntriesTableUpdateCompanionBuilder =
    LedgerEntriesCompanion Function({
      Value<String> id,
      Value<String?> customerId,
      Value<String> entryType,
      Value<int> amountKurus,
      Value<String?> relatedOrderId,
      Value<String?> note,
      Value<String> occurredAt,
      Value<String?> deviceId,
      Value<String> clientEventId,
      Value<int> rowid,
    });

class $$LedgerEntriesTableFilterComposer
    extends Composer<_$AppDatabase, $LedgerEntriesTable> {
  $$LedgerEntriesTableFilterComposer({
    required super.$db,
    required super.$table,
    super.joinBuilder,
    super.$addJoinBuilderToRootComposer,
    super.$removeJoinBuilderFromRootComposer,
  });
  ColumnFilters<String> get id => $composableBuilder(
    column: $table.id,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<String> get customerId => $composableBuilder(
    column: $table.customerId,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<String> get entryType => $composableBuilder(
    column: $table.entryType,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<int> get amountKurus => $composableBuilder(
    column: $table.amountKurus,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<String> get relatedOrderId => $composableBuilder(
    column: $table.relatedOrderId,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<String> get note => $composableBuilder(
    column: $table.note,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<String> get occurredAt => $composableBuilder(
    column: $table.occurredAt,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<String> get deviceId => $composableBuilder(
    column: $table.deviceId,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<String> get clientEventId => $composableBuilder(
    column: $table.clientEventId,
    builder: (column) => ColumnFilters(column),
  );
}

class $$LedgerEntriesTableOrderingComposer
    extends Composer<_$AppDatabase, $LedgerEntriesTable> {
  $$LedgerEntriesTableOrderingComposer({
    required super.$db,
    required super.$table,
    super.joinBuilder,
    super.$addJoinBuilderToRootComposer,
    super.$removeJoinBuilderFromRootComposer,
  });
  ColumnOrderings<String> get id => $composableBuilder(
    column: $table.id,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<String> get customerId => $composableBuilder(
    column: $table.customerId,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<String> get entryType => $composableBuilder(
    column: $table.entryType,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<int> get amountKurus => $composableBuilder(
    column: $table.amountKurus,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<String> get relatedOrderId => $composableBuilder(
    column: $table.relatedOrderId,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<String> get note => $composableBuilder(
    column: $table.note,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<String> get occurredAt => $composableBuilder(
    column: $table.occurredAt,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<String> get deviceId => $composableBuilder(
    column: $table.deviceId,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<String> get clientEventId => $composableBuilder(
    column: $table.clientEventId,
    builder: (column) => ColumnOrderings(column),
  );
}

class $$LedgerEntriesTableAnnotationComposer
    extends Composer<_$AppDatabase, $LedgerEntriesTable> {
  $$LedgerEntriesTableAnnotationComposer({
    required super.$db,
    required super.$table,
    super.joinBuilder,
    super.$addJoinBuilderToRootComposer,
    super.$removeJoinBuilderFromRootComposer,
  });
  GeneratedColumn<String> get id =>
      $composableBuilder(column: $table.id, builder: (column) => column);

  GeneratedColumn<String> get customerId => $composableBuilder(
    column: $table.customerId,
    builder: (column) => column,
  );

  GeneratedColumn<String> get entryType =>
      $composableBuilder(column: $table.entryType, builder: (column) => column);

  GeneratedColumn<int> get amountKurus => $composableBuilder(
    column: $table.amountKurus,
    builder: (column) => column,
  );

  GeneratedColumn<String> get relatedOrderId => $composableBuilder(
    column: $table.relatedOrderId,
    builder: (column) => column,
  );

  GeneratedColumn<String> get note =>
      $composableBuilder(column: $table.note, builder: (column) => column);

  GeneratedColumn<String> get occurredAt => $composableBuilder(
    column: $table.occurredAt,
    builder: (column) => column,
  );

  GeneratedColumn<String> get deviceId =>
      $composableBuilder(column: $table.deviceId, builder: (column) => column);

  GeneratedColumn<String> get clientEventId => $composableBuilder(
    column: $table.clientEventId,
    builder: (column) => column,
  );
}

class $$LedgerEntriesTableTableManager
    extends
        RootTableManager<
          _$AppDatabase,
          $LedgerEntriesTable,
          LedgerEntry,
          $$LedgerEntriesTableFilterComposer,
          $$LedgerEntriesTableOrderingComposer,
          $$LedgerEntriesTableAnnotationComposer,
          $$LedgerEntriesTableCreateCompanionBuilder,
          $$LedgerEntriesTableUpdateCompanionBuilder,
          (
            LedgerEntry,
            BaseReferences<_$AppDatabase, $LedgerEntriesTable, LedgerEntry>,
          ),
          LedgerEntry,
          PrefetchHooks Function()
        > {
  $$LedgerEntriesTableTableManager(_$AppDatabase db, $LedgerEntriesTable table)
    : super(
        TableManagerState(
          db: db,
          table: table,
          createFilteringComposer: () =>
              $$LedgerEntriesTableFilterComposer($db: db, $table: table),
          createOrderingComposer: () =>
              $$LedgerEntriesTableOrderingComposer($db: db, $table: table),
          createComputedFieldComposer: () =>
              $$LedgerEntriesTableAnnotationComposer($db: db, $table: table),
          updateCompanionCallback:
              ({
                Value<String> id = const Value.absent(),
                Value<String?> customerId = const Value.absent(),
                Value<String> entryType = const Value.absent(),
                Value<int> amountKurus = const Value.absent(),
                Value<String?> relatedOrderId = const Value.absent(),
                Value<String?> note = const Value.absent(),
                Value<String> occurredAt = const Value.absent(),
                Value<String?> deviceId = const Value.absent(),
                Value<String> clientEventId = const Value.absent(),
                Value<int> rowid = const Value.absent(),
              }) => LedgerEntriesCompanion(
                id: id,
                customerId: customerId,
                entryType: entryType,
                amountKurus: amountKurus,
                relatedOrderId: relatedOrderId,
                note: note,
                occurredAt: occurredAt,
                deviceId: deviceId,
                clientEventId: clientEventId,
                rowid: rowid,
              ),
          createCompanionCallback:
              ({
                required String id,
                Value<String?> customerId = const Value.absent(),
                required String entryType,
                required int amountKurus,
                Value<String?> relatedOrderId = const Value.absent(),
                Value<String?> note = const Value.absent(),
                required String occurredAt,
                Value<String?> deviceId = const Value.absent(),
                required String clientEventId,
                Value<int> rowid = const Value.absent(),
              }) => LedgerEntriesCompanion.insert(
                id: id,
                customerId: customerId,
                entryType: entryType,
                amountKurus: amountKurus,
                relatedOrderId: relatedOrderId,
                note: note,
                occurredAt: occurredAt,
                deviceId: deviceId,
                clientEventId: clientEventId,
                rowid: rowid,
              ),
          withReferenceMapper: (p0) => p0
              .map((e) => (e.readTable(table), BaseReferences(db, table, e)))
              .toList(),
          prefetchHooksCallback: null,
        ),
      );
}

typedef $$LedgerEntriesTableProcessedTableManager =
    ProcessedTableManager<
      _$AppDatabase,
      $LedgerEntriesTable,
      LedgerEntry,
      $$LedgerEntriesTableFilterComposer,
      $$LedgerEntriesTableOrderingComposer,
      $$LedgerEntriesTableAnnotationComposer,
      $$LedgerEntriesTableCreateCompanionBuilder,
      $$LedgerEntriesTableUpdateCompanionBuilder,
      (
        LedgerEntry,
        BaseReferences<_$AppDatabase, $LedgerEntriesTable, LedgerEntry>,
      ),
      LedgerEntry,
      PrefetchHooks Function()
    >;
typedef $$OutboxTableCreateCompanionBuilder =
    OutboxCompanion Function({
      Value<int> id,
      required String clientEventId,
      required String entityType,
      required String op,
      Value<String?> entityId,
      required String payload,
      required String occurredAt,
      Value<String?> deviceId,
      required String createdAt,
      Value<String> status,
      Value<int> attempts,
      Value<String?> lastError,
    });
typedef $$OutboxTableUpdateCompanionBuilder =
    OutboxCompanion Function({
      Value<int> id,
      Value<String> clientEventId,
      Value<String> entityType,
      Value<String> op,
      Value<String?> entityId,
      Value<String> payload,
      Value<String> occurredAt,
      Value<String?> deviceId,
      Value<String> createdAt,
      Value<String> status,
      Value<int> attempts,
      Value<String?> lastError,
    });

class $$OutboxTableFilterComposer
    extends Composer<_$AppDatabase, $OutboxTable> {
  $$OutboxTableFilterComposer({
    required super.$db,
    required super.$table,
    super.joinBuilder,
    super.$addJoinBuilderToRootComposer,
    super.$removeJoinBuilderFromRootComposer,
  });
  ColumnFilters<int> get id => $composableBuilder(
    column: $table.id,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<String> get clientEventId => $composableBuilder(
    column: $table.clientEventId,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<String> get entityType => $composableBuilder(
    column: $table.entityType,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<String> get op => $composableBuilder(
    column: $table.op,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<String> get entityId => $composableBuilder(
    column: $table.entityId,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<String> get payload => $composableBuilder(
    column: $table.payload,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<String> get occurredAt => $composableBuilder(
    column: $table.occurredAt,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<String> get deviceId => $composableBuilder(
    column: $table.deviceId,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<String> get createdAt => $composableBuilder(
    column: $table.createdAt,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<String> get status => $composableBuilder(
    column: $table.status,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<int> get attempts => $composableBuilder(
    column: $table.attempts,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<String> get lastError => $composableBuilder(
    column: $table.lastError,
    builder: (column) => ColumnFilters(column),
  );
}

class $$OutboxTableOrderingComposer
    extends Composer<_$AppDatabase, $OutboxTable> {
  $$OutboxTableOrderingComposer({
    required super.$db,
    required super.$table,
    super.joinBuilder,
    super.$addJoinBuilderToRootComposer,
    super.$removeJoinBuilderFromRootComposer,
  });
  ColumnOrderings<int> get id => $composableBuilder(
    column: $table.id,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<String> get clientEventId => $composableBuilder(
    column: $table.clientEventId,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<String> get entityType => $composableBuilder(
    column: $table.entityType,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<String> get op => $composableBuilder(
    column: $table.op,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<String> get entityId => $composableBuilder(
    column: $table.entityId,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<String> get payload => $composableBuilder(
    column: $table.payload,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<String> get occurredAt => $composableBuilder(
    column: $table.occurredAt,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<String> get deviceId => $composableBuilder(
    column: $table.deviceId,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<String> get createdAt => $composableBuilder(
    column: $table.createdAt,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<String> get status => $composableBuilder(
    column: $table.status,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<int> get attempts => $composableBuilder(
    column: $table.attempts,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<String> get lastError => $composableBuilder(
    column: $table.lastError,
    builder: (column) => ColumnOrderings(column),
  );
}

class $$OutboxTableAnnotationComposer
    extends Composer<_$AppDatabase, $OutboxTable> {
  $$OutboxTableAnnotationComposer({
    required super.$db,
    required super.$table,
    super.joinBuilder,
    super.$addJoinBuilderToRootComposer,
    super.$removeJoinBuilderFromRootComposer,
  });
  GeneratedColumn<int> get id =>
      $composableBuilder(column: $table.id, builder: (column) => column);

  GeneratedColumn<String> get clientEventId => $composableBuilder(
    column: $table.clientEventId,
    builder: (column) => column,
  );

  GeneratedColumn<String> get entityType => $composableBuilder(
    column: $table.entityType,
    builder: (column) => column,
  );

  GeneratedColumn<String> get op =>
      $composableBuilder(column: $table.op, builder: (column) => column);

  GeneratedColumn<String> get entityId =>
      $composableBuilder(column: $table.entityId, builder: (column) => column);

  GeneratedColumn<String> get payload =>
      $composableBuilder(column: $table.payload, builder: (column) => column);

  GeneratedColumn<String> get occurredAt => $composableBuilder(
    column: $table.occurredAt,
    builder: (column) => column,
  );

  GeneratedColumn<String> get deviceId =>
      $composableBuilder(column: $table.deviceId, builder: (column) => column);

  GeneratedColumn<String> get createdAt =>
      $composableBuilder(column: $table.createdAt, builder: (column) => column);

  GeneratedColumn<String> get status =>
      $composableBuilder(column: $table.status, builder: (column) => column);

  GeneratedColumn<int> get attempts =>
      $composableBuilder(column: $table.attempts, builder: (column) => column);

  GeneratedColumn<String> get lastError =>
      $composableBuilder(column: $table.lastError, builder: (column) => column);
}

class $$OutboxTableTableManager
    extends
        RootTableManager<
          _$AppDatabase,
          $OutboxTable,
          OutboxData,
          $$OutboxTableFilterComposer,
          $$OutboxTableOrderingComposer,
          $$OutboxTableAnnotationComposer,
          $$OutboxTableCreateCompanionBuilder,
          $$OutboxTableUpdateCompanionBuilder,
          (OutboxData, BaseReferences<_$AppDatabase, $OutboxTable, OutboxData>),
          OutboxData,
          PrefetchHooks Function()
        > {
  $$OutboxTableTableManager(_$AppDatabase db, $OutboxTable table)
    : super(
        TableManagerState(
          db: db,
          table: table,
          createFilteringComposer: () =>
              $$OutboxTableFilterComposer($db: db, $table: table),
          createOrderingComposer: () =>
              $$OutboxTableOrderingComposer($db: db, $table: table),
          createComputedFieldComposer: () =>
              $$OutboxTableAnnotationComposer($db: db, $table: table),
          updateCompanionCallback:
              ({
                Value<int> id = const Value.absent(),
                Value<String> clientEventId = const Value.absent(),
                Value<String> entityType = const Value.absent(),
                Value<String> op = const Value.absent(),
                Value<String?> entityId = const Value.absent(),
                Value<String> payload = const Value.absent(),
                Value<String> occurredAt = const Value.absent(),
                Value<String?> deviceId = const Value.absent(),
                Value<String> createdAt = const Value.absent(),
                Value<String> status = const Value.absent(),
                Value<int> attempts = const Value.absent(),
                Value<String?> lastError = const Value.absent(),
              }) => OutboxCompanion(
                id: id,
                clientEventId: clientEventId,
                entityType: entityType,
                op: op,
                entityId: entityId,
                payload: payload,
                occurredAt: occurredAt,
                deviceId: deviceId,
                createdAt: createdAt,
                status: status,
                attempts: attempts,
                lastError: lastError,
              ),
          createCompanionCallback:
              ({
                Value<int> id = const Value.absent(),
                required String clientEventId,
                required String entityType,
                required String op,
                Value<String?> entityId = const Value.absent(),
                required String payload,
                required String occurredAt,
                Value<String?> deviceId = const Value.absent(),
                required String createdAt,
                Value<String> status = const Value.absent(),
                Value<int> attempts = const Value.absent(),
                Value<String?> lastError = const Value.absent(),
              }) => OutboxCompanion.insert(
                id: id,
                clientEventId: clientEventId,
                entityType: entityType,
                op: op,
                entityId: entityId,
                payload: payload,
                occurredAt: occurredAt,
                deviceId: deviceId,
                createdAt: createdAt,
                status: status,
                attempts: attempts,
                lastError: lastError,
              ),
          withReferenceMapper: (p0) => p0
              .map((e) => (e.readTable(table), BaseReferences(db, table, e)))
              .toList(),
          prefetchHooksCallback: null,
        ),
      );
}

typedef $$OutboxTableProcessedTableManager =
    ProcessedTableManager<
      _$AppDatabase,
      $OutboxTable,
      OutboxData,
      $$OutboxTableFilterComposer,
      $$OutboxTableOrderingComposer,
      $$OutboxTableAnnotationComposer,
      $$OutboxTableCreateCompanionBuilder,
      $$OutboxTableUpdateCompanionBuilder,
      (OutboxData, BaseReferences<_$AppDatabase, $OutboxTable, OutboxData>),
      OutboxData,
      PrefetchHooks Function()
    >;
typedef $$SyncMetaTableCreateCompanionBuilder =
    SyncMetaCompanion Function({
      Value<int> id,
      Value<int> lastPulledSeq,
      Value<String?> lastServerTimeIso,
      Value<int> serverTimeOffsetMs,
      Value<int?> elapsedAnchorMs,
      Value<bool> snapshotDone,
      Value<String?> deviceId,
      Value<String?> validUntilIso,
    });
typedef $$SyncMetaTableUpdateCompanionBuilder =
    SyncMetaCompanion Function({
      Value<int> id,
      Value<int> lastPulledSeq,
      Value<String?> lastServerTimeIso,
      Value<int> serverTimeOffsetMs,
      Value<int?> elapsedAnchorMs,
      Value<bool> snapshotDone,
      Value<String?> deviceId,
      Value<String?> validUntilIso,
    });

class $$SyncMetaTableFilterComposer
    extends Composer<_$AppDatabase, $SyncMetaTable> {
  $$SyncMetaTableFilterComposer({
    required super.$db,
    required super.$table,
    super.joinBuilder,
    super.$addJoinBuilderToRootComposer,
    super.$removeJoinBuilderFromRootComposer,
  });
  ColumnFilters<int> get id => $composableBuilder(
    column: $table.id,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<int> get lastPulledSeq => $composableBuilder(
    column: $table.lastPulledSeq,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<String> get lastServerTimeIso => $composableBuilder(
    column: $table.lastServerTimeIso,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<int> get serverTimeOffsetMs => $composableBuilder(
    column: $table.serverTimeOffsetMs,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<int> get elapsedAnchorMs => $composableBuilder(
    column: $table.elapsedAnchorMs,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<bool> get snapshotDone => $composableBuilder(
    column: $table.snapshotDone,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<String> get deviceId => $composableBuilder(
    column: $table.deviceId,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<String> get validUntilIso => $composableBuilder(
    column: $table.validUntilIso,
    builder: (column) => ColumnFilters(column),
  );
}

class $$SyncMetaTableOrderingComposer
    extends Composer<_$AppDatabase, $SyncMetaTable> {
  $$SyncMetaTableOrderingComposer({
    required super.$db,
    required super.$table,
    super.joinBuilder,
    super.$addJoinBuilderToRootComposer,
    super.$removeJoinBuilderFromRootComposer,
  });
  ColumnOrderings<int> get id => $composableBuilder(
    column: $table.id,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<int> get lastPulledSeq => $composableBuilder(
    column: $table.lastPulledSeq,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<String> get lastServerTimeIso => $composableBuilder(
    column: $table.lastServerTimeIso,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<int> get serverTimeOffsetMs => $composableBuilder(
    column: $table.serverTimeOffsetMs,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<int> get elapsedAnchorMs => $composableBuilder(
    column: $table.elapsedAnchorMs,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<bool> get snapshotDone => $composableBuilder(
    column: $table.snapshotDone,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<String> get deviceId => $composableBuilder(
    column: $table.deviceId,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<String> get validUntilIso => $composableBuilder(
    column: $table.validUntilIso,
    builder: (column) => ColumnOrderings(column),
  );
}

class $$SyncMetaTableAnnotationComposer
    extends Composer<_$AppDatabase, $SyncMetaTable> {
  $$SyncMetaTableAnnotationComposer({
    required super.$db,
    required super.$table,
    super.joinBuilder,
    super.$addJoinBuilderToRootComposer,
    super.$removeJoinBuilderFromRootComposer,
  });
  GeneratedColumn<int> get id =>
      $composableBuilder(column: $table.id, builder: (column) => column);

  GeneratedColumn<int> get lastPulledSeq => $composableBuilder(
    column: $table.lastPulledSeq,
    builder: (column) => column,
  );

  GeneratedColumn<String> get lastServerTimeIso => $composableBuilder(
    column: $table.lastServerTimeIso,
    builder: (column) => column,
  );

  GeneratedColumn<int> get serverTimeOffsetMs => $composableBuilder(
    column: $table.serverTimeOffsetMs,
    builder: (column) => column,
  );

  GeneratedColumn<int> get elapsedAnchorMs => $composableBuilder(
    column: $table.elapsedAnchorMs,
    builder: (column) => column,
  );

  GeneratedColumn<bool> get snapshotDone => $composableBuilder(
    column: $table.snapshotDone,
    builder: (column) => column,
  );

  GeneratedColumn<String> get deviceId =>
      $composableBuilder(column: $table.deviceId, builder: (column) => column);

  GeneratedColumn<String> get validUntilIso => $composableBuilder(
    column: $table.validUntilIso,
    builder: (column) => column,
  );
}

class $$SyncMetaTableTableManager
    extends
        RootTableManager<
          _$AppDatabase,
          $SyncMetaTable,
          SyncMetaData,
          $$SyncMetaTableFilterComposer,
          $$SyncMetaTableOrderingComposer,
          $$SyncMetaTableAnnotationComposer,
          $$SyncMetaTableCreateCompanionBuilder,
          $$SyncMetaTableUpdateCompanionBuilder,
          (
            SyncMetaData,
            BaseReferences<_$AppDatabase, $SyncMetaTable, SyncMetaData>,
          ),
          SyncMetaData,
          PrefetchHooks Function()
        > {
  $$SyncMetaTableTableManager(_$AppDatabase db, $SyncMetaTable table)
    : super(
        TableManagerState(
          db: db,
          table: table,
          createFilteringComposer: () =>
              $$SyncMetaTableFilterComposer($db: db, $table: table),
          createOrderingComposer: () =>
              $$SyncMetaTableOrderingComposer($db: db, $table: table),
          createComputedFieldComposer: () =>
              $$SyncMetaTableAnnotationComposer($db: db, $table: table),
          updateCompanionCallback:
              ({
                Value<int> id = const Value.absent(),
                Value<int> lastPulledSeq = const Value.absent(),
                Value<String?> lastServerTimeIso = const Value.absent(),
                Value<int> serverTimeOffsetMs = const Value.absent(),
                Value<int?> elapsedAnchorMs = const Value.absent(),
                Value<bool> snapshotDone = const Value.absent(),
                Value<String?> deviceId = const Value.absent(),
                Value<String?> validUntilIso = const Value.absent(),
              }) => SyncMetaCompanion(
                id: id,
                lastPulledSeq: lastPulledSeq,
                lastServerTimeIso: lastServerTimeIso,
                serverTimeOffsetMs: serverTimeOffsetMs,
                elapsedAnchorMs: elapsedAnchorMs,
                snapshotDone: snapshotDone,
                deviceId: deviceId,
                validUntilIso: validUntilIso,
              ),
          createCompanionCallback:
              ({
                Value<int> id = const Value.absent(),
                Value<int> lastPulledSeq = const Value.absent(),
                Value<String?> lastServerTimeIso = const Value.absent(),
                Value<int> serverTimeOffsetMs = const Value.absent(),
                Value<int?> elapsedAnchorMs = const Value.absent(),
                Value<bool> snapshotDone = const Value.absent(),
                Value<String?> deviceId = const Value.absent(),
                Value<String?> validUntilIso = const Value.absent(),
              }) => SyncMetaCompanion.insert(
                id: id,
                lastPulledSeq: lastPulledSeq,
                lastServerTimeIso: lastServerTimeIso,
                serverTimeOffsetMs: serverTimeOffsetMs,
                elapsedAnchorMs: elapsedAnchorMs,
                snapshotDone: snapshotDone,
                deviceId: deviceId,
                validUntilIso: validUntilIso,
              ),
          withReferenceMapper: (p0) => p0
              .map((e) => (e.readTable(table), BaseReferences(db, table, e)))
              .toList(),
          prefetchHooksCallback: null,
        ),
      );
}

typedef $$SyncMetaTableProcessedTableManager =
    ProcessedTableManager<
      _$AppDatabase,
      $SyncMetaTable,
      SyncMetaData,
      $$SyncMetaTableFilterComposer,
      $$SyncMetaTableOrderingComposer,
      $$SyncMetaTableAnnotationComposer,
      $$SyncMetaTableCreateCompanionBuilder,
      $$SyncMetaTableUpdateCompanionBuilder,
      (
        SyncMetaData,
        BaseReferences<_$AppDatabase, $SyncMetaTable, SyncMetaData>,
      ),
      SyncMetaData,
      PrefetchHooks Function()
    >;

class $AppDatabaseManager {
  final _$AppDatabase _db;
  $AppDatabaseManager(this._db);
  $$CustomersTableTableManager get customers =>
      $$CustomersTableTableManager(_db, _db.customers);
  $$CustomerPhonesTableTableManager get customerPhones =>
      $$CustomerPhonesTableTableManager(_db, _db.customerPhones);
  $$CustomerAddressesTableTableManager get customerAddresses =>
      $$CustomerAddressesTableTableManager(_db, _db.customerAddresses);
  $$ProductsTableTableManager get products =>
      $$ProductsTableTableManager(_db, _db.products);
  $$OrdersTableTableManager get orders =>
      $$OrdersTableTableManager(_db, _db.orders);
  $$OrderLinesTableTableManager get orderLines =>
      $$OrderLinesTableTableManager(_db, _db.orderLines);
  $$OrderEventsTableTableManager get orderEvents =>
      $$OrderEventsTableTableManager(_db, _db.orderEvents);
  $$LedgerEntriesTableTableManager get ledgerEntries =>
      $$LedgerEntriesTableTableManager(_db, _db.ledgerEntries);
  $$OutboxTableTableManager get outbox =>
      $$OutboxTableTableManager(_db, _db.outbox);
  $$SyncMetaTableTableManager get syncMeta =>
      $$SyncMetaTableTableManager(_db, _db.syncMeta);
}
