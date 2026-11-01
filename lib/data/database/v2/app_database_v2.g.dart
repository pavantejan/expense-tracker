// GENERATED CODE - DO NOT MODIFY BY HAND

part of 'app_database_v2.dart';

// ignore_for_file: type=lint
class $AccountsTable extends Accounts with TableInfo<$AccountsTable, Account> {
  @override
  final GeneratedDatabase attachedDatabase;
  final String? _alias;
  $AccountsTable(this.attachedDatabase, [this._alias]);
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
  static const VerificationMeta _uuidMeta = const VerificationMeta('uuid');
  @override
  late final GeneratedColumn<String> uuid = GeneratedColumn<String>(
    'uuid',
    aliasedName,
    false,
    type: DriftSqlType.string,
    requiredDuringInsert: true,
    defaultConstraints: GeneratedColumn.constraintIsAlways('UNIQUE'),
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
  static const VerificationMeta _kindMeta = const VerificationMeta('kind');
  @override
  late final GeneratedColumn<String> kind = GeneratedColumn<String>(
    'kind',
    aliasedName,
    false,
    type: DriftSqlType.string,
    requiredDuringInsert: true,
  );
  static const VerificationMeta _currencyCodeMeta = const VerificationMeta(
    'currencyCode',
  );
  @override
  late final GeneratedColumn<String> currencyCode = GeneratedColumn<String>(
    'currency_code',
    aliasedName,
    false,
    type: DriftSqlType.string,
    requiredDuringInsert: false,
    defaultValue: const Constant('INR'),
  );
  static const VerificationMeta _iconCodePointMeta = const VerificationMeta(
    'iconCodePoint',
  );
  @override
  late final GeneratedColumn<int> iconCodePoint = GeneratedColumn<int>(
    'icon_code_point',
    aliasedName,
    true,
    type: DriftSqlType.int,
    requiredDuringInsert: false,
  );
  static const VerificationMeta _colorValueMeta = const VerificationMeta(
    'colorValue',
  );
  @override
  late final GeneratedColumn<int> colorValue = GeneratedColumn<int>(
    'color_value',
    aliasedName,
    true,
    type: DriftSqlType.int,
    requiredDuringInsert: false,
  );
  static const VerificationMeta _isArchivedMeta = const VerificationMeta(
    'isArchived',
  );
  @override
  late final GeneratedColumn<bool> isArchived = GeneratedColumn<bool>(
    'is_archived',
    aliasedName,
    false,
    type: DriftSqlType.bool,
    requiredDuringInsert: false,
    defaultConstraints: GeneratedColumn.constraintIsAlways(
      'CHECK ("is_archived" IN (0, 1))',
    ),
    defaultValue: const Constant(false),
  );
  static const VerificationMeta _archivedAtMeta = const VerificationMeta(
    'archivedAt',
  );
  @override
  late final GeneratedColumn<DateTime> archivedAt = GeneratedColumn<DateTime>(
    'archived_at',
    aliasedName,
    true,
    type: DriftSqlType.dateTime,
    requiredDuringInsert: false,
  );
  static const VerificationMeta _displayOrderMeta = const VerificationMeta(
    'displayOrder',
  );
  @override
  late final GeneratedColumn<int> displayOrder = GeneratedColumn<int>(
    'display_order',
    aliasedName,
    false,
    type: DriftSqlType.int,
    requiredDuringInsert: false,
    defaultValue: const Constant(0),
  );
  @override
  List<GeneratedColumn> get $columns => [
    id,
    uuid,
    name,
    kind,
    currencyCode,
    iconCodePoint,
    colorValue,
    isArchived,
    archivedAt,
    displayOrder,
  ];
  @override
  String get aliasedName => _alias ?? actualTableName;
  @override
  String get actualTableName => $name;
  static const String $name = 'accounts';
  @override
  VerificationContext validateIntegrity(
    Insertable<Account> instance, {
    bool isInserting = false,
  }) {
    final context = VerificationContext();
    final data = instance.toColumns(true);
    if (data.containsKey('id')) {
      context.handle(_idMeta, id.isAcceptableOrUnknown(data['id']!, _idMeta));
    }
    if (data.containsKey('uuid')) {
      context.handle(
        _uuidMeta,
        uuid.isAcceptableOrUnknown(data['uuid']!, _uuidMeta),
      );
    } else if (isInserting) {
      context.missing(_uuidMeta);
    }
    if (data.containsKey('name')) {
      context.handle(
        _nameMeta,
        name.isAcceptableOrUnknown(data['name']!, _nameMeta),
      );
    } else if (isInserting) {
      context.missing(_nameMeta);
    }
    if (data.containsKey('kind')) {
      context.handle(
        _kindMeta,
        kind.isAcceptableOrUnknown(data['kind']!, _kindMeta),
      );
    } else if (isInserting) {
      context.missing(_kindMeta);
    }
    if (data.containsKey('currency_code')) {
      context.handle(
        _currencyCodeMeta,
        currencyCode.isAcceptableOrUnknown(
          data['currency_code']!,
          _currencyCodeMeta,
        ),
      );
    }
    if (data.containsKey('icon_code_point')) {
      context.handle(
        _iconCodePointMeta,
        iconCodePoint.isAcceptableOrUnknown(
          data['icon_code_point']!,
          _iconCodePointMeta,
        ),
      );
    }
    if (data.containsKey('color_value')) {
      context.handle(
        _colorValueMeta,
        colorValue.isAcceptableOrUnknown(data['color_value']!, _colorValueMeta),
      );
    }
    if (data.containsKey('is_archived')) {
      context.handle(
        _isArchivedMeta,
        isArchived.isAcceptableOrUnknown(data['is_archived']!, _isArchivedMeta),
      );
    }
    if (data.containsKey('archived_at')) {
      context.handle(
        _archivedAtMeta,
        archivedAt.isAcceptableOrUnknown(data['archived_at']!, _archivedAtMeta),
      );
    }
    if (data.containsKey('display_order')) {
      context.handle(
        _displayOrderMeta,
        displayOrder.isAcceptableOrUnknown(
          data['display_order']!,
          _displayOrderMeta,
        ),
      );
    }
    return context;
  }

  @override
  Set<GeneratedColumn> get $primaryKey => {id};
  @override
  Account map(Map<String, dynamic> data, {String? tablePrefix}) {
    final effectivePrefix = tablePrefix != null ? '$tablePrefix.' : '';
    return Account(
      id: attachedDatabase.typeMapping.read(
        DriftSqlType.int,
        data['${effectivePrefix}id'],
      )!,
      uuid: attachedDatabase.typeMapping.read(
        DriftSqlType.string,
        data['${effectivePrefix}uuid'],
      )!,
      name: attachedDatabase.typeMapping.read(
        DriftSqlType.string,
        data['${effectivePrefix}name'],
      )!,
      kind: attachedDatabase.typeMapping.read(
        DriftSqlType.string,
        data['${effectivePrefix}kind'],
      )!,
      currencyCode: attachedDatabase.typeMapping.read(
        DriftSqlType.string,
        data['${effectivePrefix}currency_code'],
      )!,
      iconCodePoint: attachedDatabase.typeMapping.read(
        DriftSqlType.int,
        data['${effectivePrefix}icon_code_point'],
      ),
      colorValue: attachedDatabase.typeMapping.read(
        DriftSqlType.int,
        data['${effectivePrefix}color_value'],
      ),
      isArchived: attachedDatabase.typeMapping.read(
        DriftSqlType.bool,
        data['${effectivePrefix}is_archived'],
      )!,
      archivedAt: attachedDatabase.typeMapping.read(
        DriftSqlType.dateTime,
        data['${effectivePrefix}archived_at'],
      ),
      displayOrder: attachedDatabase.typeMapping.read(
        DriftSqlType.int,
        data['${effectivePrefix}display_order'],
      )!,
    );
  }

  @override
  $AccountsTable createAlias(String alias) {
    return $AccountsTable(attachedDatabase, alias);
  }
}

class Account extends DataClass implements Insertable<Account> {
  final int id;
  final String uuid;
  final String name;

  /// `bank`, `cash`, `wallet`, `other_asset`, or
  /// `credit_card_liability`. Asset kinds map to a `user_asset` ledger
  /// account; `credit_card_liability` maps to a `user_liability` ledger
  /// account. The classification rules live in a later stage.
  final String kind;
  final String currencyCode;

  /// Material icon code point, nullable when no icon was chosen.
  final int? iconCodePoint;

  /// ARGB colour value, nullable when no colour was chosen.
  final int? colorValue;
  final bool isArchived;
  final DateTime? archivedAt;
  final int displayOrder;
  const Account({
    required this.id,
    required this.uuid,
    required this.name,
    required this.kind,
    required this.currencyCode,
    this.iconCodePoint,
    this.colorValue,
    required this.isArchived,
    this.archivedAt,
    required this.displayOrder,
  });
  @override
  Map<String, Expression> toColumns(bool nullToAbsent) {
    final map = <String, Expression>{};
    map['id'] = Variable<int>(id);
    map['uuid'] = Variable<String>(uuid);
    map['name'] = Variable<String>(name);
    map['kind'] = Variable<String>(kind);
    map['currency_code'] = Variable<String>(currencyCode);
    if (!nullToAbsent || iconCodePoint != null) {
      map['icon_code_point'] = Variable<int>(iconCodePoint);
    }
    if (!nullToAbsent || colorValue != null) {
      map['color_value'] = Variable<int>(colorValue);
    }
    map['is_archived'] = Variable<bool>(isArchived);
    if (!nullToAbsent || archivedAt != null) {
      map['archived_at'] = Variable<DateTime>(archivedAt);
    }
    map['display_order'] = Variable<int>(displayOrder);
    return map;
  }

  AccountsCompanion toCompanion(bool nullToAbsent) {
    return AccountsCompanion(
      id: Value(id),
      uuid: Value(uuid),
      name: Value(name),
      kind: Value(kind),
      currencyCode: Value(currencyCode),
      iconCodePoint: iconCodePoint == null && nullToAbsent
          ? const Value.absent()
          : Value(iconCodePoint),
      colorValue: colorValue == null && nullToAbsent
          ? const Value.absent()
          : Value(colorValue),
      isArchived: Value(isArchived),
      archivedAt: archivedAt == null && nullToAbsent
          ? const Value.absent()
          : Value(archivedAt),
      displayOrder: Value(displayOrder),
    );
  }

  factory Account.fromJson(
    Map<String, dynamic> json, {
    ValueSerializer? serializer,
  }) {
    serializer ??= driftRuntimeOptions.defaultSerializer;
    return Account(
      id: serializer.fromJson<int>(json['id']),
      uuid: serializer.fromJson<String>(json['uuid']),
      name: serializer.fromJson<String>(json['name']),
      kind: serializer.fromJson<String>(json['kind']),
      currencyCode: serializer.fromJson<String>(json['currencyCode']),
      iconCodePoint: serializer.fromJson<int?>(json['iconCodePoint']),
      colorValue: serializer.fromJson<int?>(json['colorValue']),
      isArchived: serializer.fromJson<bool>(json['isArchived']),
      archivedAt: serializer.fromJson<DateTime?>(json['archivedAt']),
      displayOrder: serializer.fromJson<int>(json['displayOrder']),
    );
  }
  @override
  Map<String, dynamic> toJson({ValueSerializer? serializer}) {
    serializer ??= driftRuntimeOptions.defaultSerializer;
    return <String, dynamic>{
      'id': serializer.toJson<int>(id),
      'uuid': serializer.toJson<String>(uuid),
      'name': serializer.toJson<String>(name),
      'kind': serializer.toJson<String>(kind),
      'currencyCode': serializer.toJson<String>(currencyCode),
      'iconCodePoint': serializer.toJson<int?>(iconCodePoint),
      'colorValue': serializer.toJson<int?>(colorValue),
      'isArchived': serializer.toJson<bool>(isArchived),
      'archivedAt': serializer.toJson<DateTime?>(archivedAt),
      'displayOrder': serializer.toJson<int>(displayOrder),
    };
  }

  Account copyWith({
    int? id,
    String? uuid,
    String? name,
    String? kind,
    String? currencyCode,
    Value<int?> iconCodePoint = const Value.absent(),
    Value<int?> colorValue = const Value.absent(),
    bool? isArchived,
    Value<DateTime?> archivedAt = const Value.absent(),
    int? displayOrder,
  }) => Account(
    id: id ?? this.id,
    uuid: uuid ?? this.uuid,
    name: name ?? this.name,
    kind: kind ?? this.kind,
    currencyCode: currencyCode ?? this.currencyCode,
    iconCodePoint: iconCodePoint.present
        ? iconCodePoint.value
        : this.iconCodePoint,
    colorValue: colorValue.present ? colorValue.value : this.colorValue,
    isArchived: isArchived ?? this.isArchived,
    archivedAt: archivedAt.present ? archivedAt.value : this.archivedAt,
    displayOrder: displayOrder ?? this.displayOrder,
  );
  Account copyWithCompanion(AccountsCompanion data) {
    return Account(
      id: data.id.present ? data.id.value : this.id,
      uuid: data.uuid.present ? data.uuid.value : this.uuid,
      name: data.name.present ? data.name.value : this.name,
      kind: data.kind.present ? data.kind.value : this.kind,
      currencyCode: data.currencyCode.present
          ? data.currencyCode.value
          : this.currencyCode,
      iconCodePoint: data.iconCodePoint.present
          ? data.iconCodePoint.value
          : this.iconCodePoint,
      colorValue: data.colorValue.present
          ? data.colorValue.value
          : this.colorValue,
      isArchived: data.isArchived.present
          ? data.isArchived.value
          : this.isArchived,
      archivedAt: data.archivedAt.present
          ? data.archivedAt.value
          : this.archivedAt,
      displayOrder: data.displayOrder.present
          ? data.displayOrder.value
          : this.displayOrder,
    );
  }

  @override
  String toString() {
    return (StringBuffer('Account(')
          ..write('id: $id, ')
          ..write('uuid: $uuid, ')
          ..write('name: $name, ')
          ..write('kind: $kind, ')
          ..write('currencyCode: $currencyCode, ')
          ..write('iconCodePoint: $iconCodePoint, ')
          ..write('colorValue: $colorValue, ')
          ..write('isArchived: $isArchived, ')
          ..write('archivedAt: $archivedAt, ')
          ..write('displayOrder: $displayOrder')
          ..write(')'))
        .toString();
  }

  @override
  int get hashCode => Object.hash(
    id,
    uuid,
    name,
    kind,
    currencyCode,
    iconCodePoint,
    colorValue,
    isArchived,
    archivedAt,
    displayOrder,
  );
  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      (other is Account &&
          other.id == this.id &&
          other.uuid == this.uuid &&
          other.name == this.name &&
          other.kind == this.kind &&
          other.currencyCode == this.currencyCode &&
          other.iconCodePoint == this.iconCodePoint &&
          other.colorValue == this.colorValue &&
          other.isArchived == this.isArchived &&
          other.archivedAt == this.archivedAt &&
          other.displayOrder == this.displayOrder);
}

class AccountsCompanion extends UpdateCompanion<Account> {
  final Value<int> id;
  final Value<String> uuid;
  final Value<String> name;
  final Value<String> kind;
  final Value<String> currencyCode;
  final Value<int?> iconCodePoint;
  final Value<int?> colorValue;
  final Value<bool> isArchived;
  final Value<DateTime?> archivedAt;
  final Value<int> displayOrder;
  const AccountsCompanion({
    this.id = const Value.absent(),
    this.uuid = const Value.absent(),
    this.name = const Value.absent(),
    this.kind = const Value.absent(),
    this.currencyCode = const Value.absent(),
    this.iconCodePoint = const Value.absent(),
    this.colorValue = const Value.absent(),
    this.isArchived = const Value.absent(),
    this.archivedAt = const Value.absent(),
    this.displayOrder = const Value.absent(),
  });
  AccountsCompanion.insert({
    this.id = const Value.absent(),
    required String uuid,
    required String name,
    required String kind,
    this.currencyCode = const Value.absent(),
    this.iconCodePoint = const Value.absent(),
    this.colorValue = const Value.absent(),
    this.isArchived = const Value.absent(),
    this.archivedAt = const Value.absent(),
    this.displayOrder = const Value.absent(),
  }) : uuid = Value(uuid),
       name = Value(name),
       kind = Value(kind);
  static Insertable<Account> custom({
    Expression<int>? id,
    Expression<String>? uuid,
    Expression<String>? name,
    Expression<String>? kind,
    Expression<String>? currencyCode,
    Expression<int>? iconCodePoint,
    Expression<int>? colorValue,
    Expression<bool>? isArchived,
    Expression<DateTime>? archivedAt,
    Expression<int>? displayOrder,
  }) {
    return RawValuesInsertable({
      if (id != null) 'id': id,
      if (uuid != null) 'uuid': uuid,
      if (name != null) 'name': name,
      if (kind != null) 'kind': kind,
      if (currencyCode != null) 'currency_code': currencyCode,
      if (iconCodePoint != null) 'icon_code_point': iconCodePoint,
      if (colorValue != null) 'color_value': colorValue,
      if (isArchived != null) 'is_archived': isArchived,
      if (archivedAt != null) 'archived_at': archivedAt,
      if (displayOrder != null) 'display_order': displayOrder,
    });
  }

  AccountsCompanion copyWith({
    Value<int>? id,
    Value<String>? uuid,
    Value<String>? name,
    Value<String>? kind,
    Value<String>? currencyCode,
    Value<int?>? iconCodePoint,
    Value<int?>? colorValue,
    Value<bool>? isArchived,
    Value<DateTime?>? archivedAt,
    Value<int>? displayOrder,
  }) {
    return AccountsCompanion(
      id: id ?? this.id,
      uuid: uuid ?? this.uuid,
      name: name ?? this.name,
      kind: kind ?? this.kind,
      currencyCode: currencyCode ?? this.currencyCode,
      iconCodePoint: iconCodePoint ?? this.iconCodePoint,
      colorValue: colorValue ?? this.colorValue,
      isArchived: isArchived ?? this.isArchived,
      archivedAt: archivedAt ?? this.archivedAt,
      displayOrder: displayOrder ?? this.displayOrder,
    );
  }

  @override
  Map<String, Expression> toColumns(bool nullToAbsent) {
    final map = <String, Expression>{};
    if (id.present) {
      map['id'] = Variable<int>(id.value);
    }
    if (uuid.present) {
      map['uuid'] = Variable<String>(uuid.value);
    }
    if (name.present) {
      map['name'] = Variable<String>(name.value);
    }
    if (kind.present) {
      map['kind'] = Variable<String>(kind.value);
    }
    if (currencyCode.present) {
      map['currency_code'] = Variable<String>(currencyCode.value);
    }
    if (iconCodePoint.present) {
      map['icon_code_point'] = Variable<int>(iconCodePoint.value);
    }
    if (colorValue.present) {
      map['color_value'] = Variable<int>(colorValue.value);
    }
    if (isArchived.present) {
      map['is_archived'] = Variable<bool>(isArchived.value);
    }
    if (archivedAt.present) {
      map['archived_at'] = Variable<DateTime>(archivedAt.value);
    }
    if (displayOrder.present) {
      map['display_order'] = Variable<int>(displayOrder.value);
    }
    return map;
  }

  @override
  String toString() {
    return (StringBuffer('AccountsCompanion(')
          ..write('id: $id, ')
          ..write('uuid: $uuid, ')
          ..write('name: $name, ')
          ..write('kind: $kind, ')
          ..write('currencyCode: $currencyCode, ')
          ..write('iconCodePoint: $iconCodePoint, ')
          ..write('colorValue: $colorValue, ')
          ..write('isArchived: $isArchived, ')
          ..write('archivedAt: $archivedAt, ')
          ..write('displayOrder: $displayOrder')
          ..write(')'))
        .toString();
  }
}

class $CategoriesTable extends Categories
    with TableInfo<$CategoriesTable, Category> {
  @override
  final GeneratedDatabase attachedDatabase;
  final String? _alias;
  $CategoriesTable(this.attachedDatabase, [this._alias]);
  static const VerificationMeta _categoryIdMeta = const VerificationMeta(
    'categoryId',
  );
  @override
  late final GeneratedColumn<String> categoryId = GeneratedColumn<String>(
    'category_id',
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
  static const VerificationMeta _iconCodePointMeta = const VerificationMeta(
    'iconCodePoint',
  );
  @override
  late final GeneratedColumn<int> iconCodePoint = GeneratedColumn<int>(
    'icon_code_point',
    aliasedName,
    false,
    type: DriftSqlType.int,
    requiredDuringInsert: true,
  );
  static const VerificationMeta _colorValueMeta = const VerificationMeta(
    'colorValue',
  );
  @override
  late final GeneratedColumn<int> colorValue = GeneratedColumn<int>(
    'color_value',
    aliasedName,
    true,
    type: DriftSqlType.int,
    requiredDuringInsert: false,
  );
  static const VerificationMeta _kindMeta = const VerificationMeta('kind');
  @override
  late final GeneratedColumn<String> kind = GeneratedColumn<String>(
    'kind',
    aliasedName,
    false,
    type: DriftSqlType.string,
    requiredDuringInsert: true,
  );
  static const VerificationMeta _originMeta = const VerificationMeta('origin');
  @override
  late final GeneratedColumn<String> origin = GeneratedColumn<String>(
    'origin',
    aliasedName,
    false,
    type: DriftSqlType.string,
    requiredDuringInsert: true,
  );
  static const VerificationMeta _isArchivedMeta = const VerificationMeta(
    'isArchived',
  );
  @override
  late final GeneratedColumn<bool> isArchived = GeneratedColumn<bool>(
    'is_archived',
    aliasedName,
    false,
    type: DriftSqlType.bool,
    requiredDuringInsert: false,
    defaultConstraints: GeneratedColumn.constraintIsAlways(
      'CHECK ("is_archived" IN (0, 1))',
    ),
    defaultValue: const Constant(false),
  );
  static const VerificationMeta _parentCategoryIdMeta = const VerificationMeta(
    'parentCategoryId',
  );
  @override
  late final GeneratedColumn<String> parentCategoryId = GeneratedColumn<String>(
    'parent_category_id',
    aliasedName,
    true,
    type: DriftSqlType.string,
    requiredDuringInsert: false,
    defaultConstraints: GeneratedColumn.constraintIsAlways(
      'REFERENCES categories (category_id)',
    ),
  );
  static const VerificationMeta _displayOrderMeta = const VerificationMeta(
    'displayOrder',
  );
  @override
  late final GeneratedColumn<int> displayOrder = GeneratedColumn<int>(
    'display_order',
    aliasedName,
    false,
    type: DriftSqlType.int,
    requiredDuringInsert: false,
    defaultValue: const Constant(0),
  );
  @override
  List<GeneratedColumn> get $columns => [
    categoryId,
    name,
    iconCodePoint,
    colorValue,
    kind,
    origin,
    isArchived,
    parentCategoryId,
    displayOrder,
  ];
  @override
  String get aliasedName => _alias ?? actualTableName;
  @override
  String get actualTableName => $name;
  static const String $name = 'categories';
  @override
  VerificationContext validateIntegrity(
    Insertable<Category> instance, {
    bool isInserting = false,
  }) {
    final context = VerificationContext();
    final data = instance.toColumns(true);
    if (data.containsKey('category_id')) {
      context.handle(
        _categoryIdMeta,
        categoryId.isAcceptableOrUnknown(data['category_id']!, _categoryIdMeta),
      );
    } else if (isInserting) {
      context.missing(_categoryIdMeta);
    }
    if (data.containsKey('name')) {
      context.handle(
        _nameMeta,
        name.isAcceptableOrUnknown(data['name']!, _nameMeta),
      );
    } else if (isInserting) {
      context.missing(_nameMeta);
    }
    if (data.containsKey('icon_code_point')) {
      context.handle(
        _iconCodePointMeta,
        iconCodePoint.isAcceptableOrUnknown(
          data['icon_code_point']!,
          _iconCodePointMeta,
        ),
      );
    } else if (isInserting) {
      context.missing(_iconCodePointMeta);
    }
    if (data.containsKey('color_value')) {
      context.handle(
        _colorValueMeta,
        colorValue.isAcceptableOrUnknown(data['color_value']!, _colorValueMeta),
      );
    }
    if (data.containsKey('kind')) {
      context.handle(
        _kindMeta,
        kind.isAcceptableOrUnknown(data['kind']!, _kindMeta),
      );
    } else if (isInserting) {
      context.missing(_kindMeta);
    }
    if (data.containsKey('origin')) {
      context.handle(
        _originMeta,
        origin.isAcceptableOrUnknown(data['origin']!, _originMeta),
      );
    } else if (isInserting) {
      context.missing(_originMeta);
    }
    if (data.containsKey('is_archived')) {
      context.handle(
        _isArchivedMeta,
        isArchived.isAcceptableOrUnknown(data['is_archived']!, _isArchivedMeta),
      );
    }
    if (data.containsKey('parent_category_id')) {
      context.handle(
        _parentCategoryIdMeta,
        parentCategoryId.isAcceptableOrUnknown(
          data['parent_category_id']!,
          _parentCategoryIdMeta,
        ),
      );
    }
    if (data.containsKey('display_order')) {
      context.handle(
        _displayOrderMeta,
        displayOrder.isAcceptableOrUnknown(
          data['display_order']!,
          _displayOrderMeta,
        ),
      );
    }
    return context;
  }

  @override
  Set<GeneratedColumn> get $primaryKey => {categoryId};
  @override
  Category map(Map<String, dynamic> data, {String? tablePrefix}) {
    final effectivePrefix = tablePrefix != null ? '$tablePrefix.' : '';
    return Category(
      categoryId: attachedDatabase.typeMapping.read(
        DriftSqlType.string,
        data['${effectivePrefix}category_id'],
      )!,
      name: attachedDatabase.typeMapping.read(
        DriftSqlType.string,
        data['${effectivePrefix}name'],
      )!,
      iconCodePoint: attachedDatabase.typeMapping.read(
        DriftSqlType.int,
        data['${effectivePrefix}icon_code_point'],
      )!,
      colorValue: attachedDatabase.typeMapping.read(
        DriftSqlType.int,
        data['${effectivePrefix}color_value'],
      ),
      kind: attachedDatabase.typeMapping.read(
        DriftSqlType.string,
        data['${effectivePrefix}kind'],
      )!,
      origin: attachedDatabase.typeMapping.read(
        DriftSqlType.string,
        data['${effectivePrefix}origin'],
      )!,
      isArchived: attachedDatabase.typeMapping.read(
        DriftSqlType.bool,
        data['${effectivePrefix}is_archived'],
      )!,
      parentCategoryId: attachedDatabase.typeMapping.read(
        DriftSqlType.string,
        data['${effectivePrefix}parent_category_id'],
      ),
      displayOrder: attachedDatabase.typeMapping.read(
        DriftSqlType.int,
        data['${effectivePrefix}display_order'],
      )!,
    );
  }

  @override
  $CategoriesTable createAlias(String alias) {
    return $CategoriesTable(attachedDatabase, alias);
  }
}

class Category extends DataClass implements Insertable<Category> {
  /// Stable string id. Built-ins keep their existing ids (`food`,
  /// `travel`, `shopping`, `bills`, `entertainment`, `health`,
  /// `education`, `other`). Custom categories use `custom_<uuid>`.
  final String categoryId;
  final String name;

  /// Material icon code point.
  final int iconCodePoint;

  /// ARGB colour value, nullable when no colour was chosen.
  final int? colorValue;

  /// `expense`, `income`, or `both`. All eight built-in categories use
  /// `both`; custom categories support all three kinds.
  final String kind;

  /// `builtin` or `custom`.
  final String origin;
  final bool isArchived;

  /// Nullable self-reference for future subcategories. Unused in
  /// Module 1; no category in the baseline seed sets it.
  final String? parentCategoryId;
  final int displayOrder;
  const Category({
    required this.categoryId,
    required this.name,
    required this.iconCodePoint,
    this.colorValue,
    required this.kind,
    required this.origin,
    required this.isArchived,
    this.parentCategoryId,
    required this.displayOrder,
  });
  @override
  Map<String, Expression> toColumns(bool nullToAbsent) {
    final map = <String, Expression>{};
    map['category_id'] = Variable<String>(categoryId);
    map['name'] = Variable<String>(name);
    map['icon_code_point'] = Variable<int>(iconCodePoint);
    if (!nullToAbsent || colorValue != null) {
      map['color_value'] = Variable<int>(colorValue);
    }
    map['kind'] = Variable<String>(kind);
    map['origin'] = Variable<String>(origin);
    map['is_archived'] = Variable<bool>(isArchived);
    if (!nullToAbsent || parentCategoryId != null) {
      map['parent_category_id'] = Variable<String>(parentCategoryId);
    }
    map['display_order'] = Variable<int>(displayOrder);
    return map;
  }

  CategoriesCompanion toCompanion(bool nullToAbsent) {
    return CategoriesCompanion(
      categoryId: Value(categoryId),
      name: Value(name),
      iconCodePoint: Value(iconCodePoint),
      colorValue: colorValue == null && nullToAbsent
          ? const Value.absent()
          : Value(colorValue),
      kind: Value(kind),
      origin: Value(origin),
      isArchived: Value(isArchived),
      parentCategoryId: parentCategoryId == null && nullToAbsent
          ? const Value.absent()
          : Value(parentCategoryId),
      displayOrder: Value(displayOrder),
    );
  }

  factory Category.fromJson(
    Map<String, dynamic> json, {
    ValueSerializer? serializer,
  }) {
    serializer ??= driftRuntimeOptions.defaultSerializer;
    return Category(
      categoryId: serializer.fromJson<String>(json['categoryId']),
      name: serializer.fromJson<String>(json['name']),
      iconCodePoint: serializer.fromJson<int>(json['iconCodePoint']),
      colorValue: serializer.fromJson<int?>(json['colorValue']),
      kind: serializer.fromJson<String>(json['kind']),
      origin: serializer.fromJson<String>(json['origin']),
      isArchived: serializer.fromJson<bool>(json['isArchived']),
      parentCategoryId: serializer.fromJson<String?>(json['parentCategoryId']),
      displayOrder: serializer.fromJson<int>(json['displayOrder']),
    );
  }
  @override
  Map<String, dynamic> toJson({ValueSerializer? serializer}) {
    serializer ??= driftRuntimeOptions.defaultSerializer;
    return <String, dynamic>{
      'categoryId': serializer.toJson<String>(categoryId),
      'name': serializer.toJson<String>(name),
      'iconCodePoint': serializer.toJson<int>(iconCodePoint),
      'colorValue': serializer.toJson<int?>(colorValue),
      'kind': serializer.toJson<String>(kind),
      'origin': serializer.toJson<String>(origin),
      'isArchived': serializer.toJson<bool>(isArchived),
      'parentCategoryId': serializer.toJson<String?>(parentCategoryId),
      'displayOrder': serializer.toJson<int>(displayOrder),
    };
  }

  Category copyWith({
    String? categoryId,
    String? name,
    int? iconCodePoint,
    Value<int?> colorValue = const Value.absent(),
    String? kind,
    String? origin,
    bool? isArchived,
    Value<String?> parentCategoryId = const Value.absent(),
    int? displayOrder,
  }) => Category(
    categoryId: categoryId ?? this.categoryId,
    name: name ?? this.name,
    iconCodePoint: iconCodePoint ?? this.iconCodePoint,
    colorValue: colorValue.present ? colorValue.value : this.colorValue,
    kind: kind ?? this.kind,
    origin: origin ?? this.origin,
    isArchived: isArchived ?? this.isArchived,
    parentCategoryId: parentCategoryId.present
        ? parentCategoryId.value
        : this.parentCategoryId,
    displayOrder: displayOrder ?? this.displayOrder,
  );
  Category copyWithCompanion(CategoriesCompanion data) {
    return Category(
      categoryId: data.categoryId.present
          ? data.categoryId.value
          : this.categoryId,
      name: data.name.present ? data.name.value : this.name,
      iconCodePoint: data.iconCodePoint.present
          ? data.iconCodePoint.value
          : this.iconCodePoint,
      colorValue: data.colorValue.present
          ? data.colorValue.value
          : this.colorValue,
      kind: data.kind.present ? data.kind.value : this.kind,
      origin: data.origin.present ? data.origin.value : this.origin,
      isArchived: data.isArchived.present
          ? data.isArchived.value
          : this.isArchived,
      parentCategoryId: data.parentCategoryId.present
          ? data.parentCategoryId.value
          : this.parentCategoryId,
      displayOrder: data.displayOrder.present
          ? data.displayOrder.value
          : this.displayOrder,
    );
  }

  @override
  String toString() {
    return (StringBuffer('Category(')
          ..write('categoryId: $categoryId, ')
          ..write('name: $name, ')
          ..write('iconCodePoint: $iconCodePoint, ')
          ..write('colorValue: $colorValue, ')
          ..write('kind: $kind, ')
          ..write('origin: $origin, ')
          ..write('isArchived: $isArchived, ')
          ..write('parentCategoryId: $parentCategoryId, ')
          ..write('displayOrder: $displayOrder')
          ..write(')'))
        .toString();
  }

  @override
  int get hashCode => Object.hash(
    categoryId,
    name,
    iconCodePoint,
    colorValue,
    kind,
    origin,
    isArchived,
    parentCategoryId,
    displayOrder,
  );
  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      (other is Category &&
          other.categoryId == this.categoryId &&
          other.name == this.name &&
          other.iconCodePoint == this.iconCodePoint &&
          other.colorValue == this.colorValue &&
          other.kind == this.kind &&
          other.origin == this.origin &&
          other.isArchived == this.isArchived &&
          other.parentCategoryId == this.parentCategoryId &&
          other.displayOrder == this.displayOrder);
}

class CategoriesCompanion extends UpdateCompanion<Category> {
  final Value<String> categoryId;
  final Value<String> name;
  final Value<int> iconCodePoint;
  final Value<int?> colorValue;
  final Value<String> kind;
  final Value<String> origin;
  final Value<bool> isArchived;
  final Value<String?> parentCategoryId;
  final Value<int> displayOrder;
  final Value<int> rowid;
  const CategoriesCompanion({
    this.categoryId = const Value.absent(),
    this.name = const Value.absent(),
    this.iconCodePoint = const Value.absent(),
    this.colorValue = const Value.absent(),
    this.kind = const Value.absent(),
    this.origin = const Value.absent(),
    this.isArchived = const Value.absent(),
    this.parentCategoryId = const Value.absent(),
    this.displayOrder = const Value.absent(),
    this.rowid = const Value.absent(),
  });
  CategoriesCompanion.insert({
    required String categoryId,
    required String name,
    required int iconCodePoint,
    this.colorValue = const Value.absent(),
    required String kind,
    required String origin,
    this.isArchived = const Value.absent(),
    this.parentCategoryId = const Value.absent(),
    this.displayOrder = const Value.absent(),
    this.rowid = const Value.absent(),
  }) : categoryId = Value(categoryId),
       name = Value(name),
       iconCodePoint = Value(iconCodePoint),
       kind = Value(kind),
       origin = Value(origin);
  static Insertable<Category> custom({
    Expression<String>? categoryId,
    Expression<String>? name,
    Expression<int>? iconCodePoint,
    Expression<int>? colorValue,
    Expression<String>? kind,
    Expression<String>? origin,
    Expression<bool>? isArchived,
    Expression<String>? parentCategoryId,
    Expression<int>? displayOrder,
    Expression<int>? rowid,
  }) {
    return RawValuesInsertable({
      if (categoryId != null) 'category_id': categoryId,
      if (name != null) 'name': name,
      if (iconCodePoint != null) 'icon_code_point': iconCodePoint,
      if (colorValue != null) 'color_value': colorValue,
      if (kind != null) 'kind': kind,
      if (origin != null) 'origin': origin,
      if (isArchived != null) 'is_archived': isArchived,
      if (parentCategoryId != null) 'parent_category_id': parentCategoryId,
      if (displayOrder != null) 'display_order': displayOrder,
      if (rowid != null) 'rowid': rowid,
    });
  }

  CategoriesCompanion copyWith({
    Value<String>? categoryId,
    Value<String>? name,
    Value<int>? iconCodePoint,
    Value<int?>? colorValue,
    Value<String>? kind,
    Value<String>? origin,
    Value<bool>? isArchived,
    Value<String?>? parentCategoryId,
    Value<int>? displayOrder,
    Value<int>? rowid,
  }) {
    return CategoriesCompanion(
      categoryId: categoryId ?? this.categoryId,
      name: name ?? this.name,
      iconCodePoint: iconCodePoint ?? this.iconCodePoint,
      colorValue: colorValue ?? this.colorValue,
      kind: kind ?? this.kind,
      origin: origin ?? this.origin,
      isArchived: isArchived ?? this.isArchived,
      parentCategoryId: parentCategoryId ?? this.parentCategoryId,
      displayOrder: displayOrder ?? this.displayOrder,
      rowid: rowid ?? this.rowid,
    );
  }

  @override
  Map<String, Expression> toColumns(bool nullToAbsent) {
    final map = <String, Expression>{};
    if (categoryId.present) {
      map['category_id'] = Variable<String>(categoryId.value);
    }
    if (name.present) {
      map['name'] = Variable<String>(name.value);
    }
    if (iconCodePoint.present) {
      map['icon_code_point'] = Variable<int>(iconCodePoint.value);
    }
    if (colorValue.present) {
      map['color_value'] = Variable<int>(colorValue.value);
    }
    if (kind.present) {
      map['kind'] = Variable<String>(kind.value);
    }
    if (origin.present) {
      map['origin'] = Variable<String>(origin.value);
    }
    if (isArchived.present) {
      map['is_archived'] = Variable<bool>(isArchived.value);
    }
    if (parentCategoryId.present) {
      map['parent_category_id'] = Variable<String>(parentCategoryId.value);
    }
    if (displayOrder.present) {
      map['display_order'] = Variable<int>(displayOrder.value);
    }
    if (rowid.present) {
      map['rowid'] = Variable<int>(rowid.value);
    }
    return map;
  }

  @override
  String toString() {
    return (StringBuffer('CategoriesCompanion(')
          ..write('categoryId: $categoryId, ')
          ..write('name: $name, ')
          ..write('iconCodePoint: $iconCodePoint, ')
          ..write('colorValue: $colorValue, ')
          ..write('kind: $kind, ')
          ..write('origin: $origin, ')
          ..write('isArchived: $isArchived, ')
          ..write('parentCategoryId: $parentCategoryId, ')
          ..write('displayOrder: $displayOrder, ')
          ..write('rowid: $rowid')
          ..write(')'))
        .toString();
  }
}

class $LedgerAccountsTable extends LedgerAccounts
    with TableInfo<$LedgerAccountsTable, LedgerAccount> {
  @override
  final GeneratedDatabase attachedDatabase;
  final String? _alias;
  $LedgerAccountsTable(this.attachedDatabase, [this._alias]);
  static const VerificationMeta _ledgerAccountIdMeta = const VerificationMeta(
    'ledgerAccountId',
  );
  @override
  late final GeneratedColumn<String> ledgerAccountId = GeneratedColumn<String>(
    'ledger_account_id',
    aliasedName,
    false,
    type: DriftSqlType.string,
    requiredDuringInsert: true,
  );
  static const VerificationMeta _kindMeta = const VerificationMeta('kind');
  @override
  late final GeneratedColumn<String> kind = GeneratedColumn<String>(
    'kind',
    aliasedName,
    false,
    type: DriftSqlType.string,
    requiredDuringInsert: true,
  );
  static const VerificationMeta _userAccountIdMeta = const VerificationMeta(
    'userAccountId',
  );
  @override
  late final GeneratedColumn<String> userAccountId = GeneratedColumn<String>(
    'user_account_id',
    aliasedName,
    true,
    type: DriftSqlType.string,
    requiredDuringInsert: false,
    defaultConstraints: GeneratedColumn.constraintIsAlways(
      'UNIQUE REFERENCES accounts (uuid)',
    ),
  );
  static const VerificationMeta _categoryIdMeta = const VerificationMeta(
    'categoryId',
  );
  @override
  late final GeneratedColumn<String> categoryId = GeneratedColumn<String>(
    'category_id',
    aliasedName,
    true,
    type: DriftSqlType.string,
    requiredDuringInsert: false,
    defaultConstraints: GeneratedColumn.constraintIsAlways(
      'REFERENCES categories (category_id)',
    ),
  );
  static const VerificationMeta _isSystemMeta = const VerificationMeta(
    'isSystem',
  );
  @override
  late final GeneratedColumn<bool> isSystem = GeneratedColumn<bool>(
    'is_system',
    aliasedName,
    false,
    type: DriftSqlType.bool,
    requiredDuringInsert: false,
    defaultConstraints: GeneratedColumn.constraintIsAlways(
      'CHECK ("is_system" IN (0, 1))',
    ),
    defaultValue: const Constant(false),
  );
  static const VerificationMeta _normalBalanceMeta = const VerificationMeta(
    'normalBalance',
  );
  @override
  late final GeneratedColumn<String> normalBalance = GeneratedColumn<String>(
    'normal_balance',
    aliasedName,
    false,
    type: DriftSqlType.string,
    requiredDuringInsert: true,
  );
  static const VerificationMeta _isArchivedMeta = const VerificationMeta(
    'isArchived',
  );
  @override
  late final GeneratedColumn<bool> isArchived = GeneratedColumn<bool>(
    'is_archived',
    aliasedName,
    false,
    type: DriftSqlType.bool,
    requiredDuringInsert: false,
    defaultConstraints: GeneratedColumn.constraintIsAlways(
      'CHECK ("is_archived" IN (0, 1))',
    ),
    defaultValue: const Constant(false),
  );
  @override
  List<GeneratedColumn> get $columns => [
    ledgerAccountId,
    kind,
    userAccountId,
    categoryId,
    isSystem,
    normalBalance,
    isArchived,
  ];
  @override
  String get aliasedName => _alias ?? actualTableName;
  @override
  String get actualTableName => $name;
  static const String $name = 'ledger_accounts';
  @override
  VerificationContext validateIntegrity(
    Insertable<LedgerAccount> instance, {
    bool isInserting = false,
  }) {
    final context = VerificationContext();
    final data = instance.toColumns(true);
    if (data.containsKey('ledger_account_id')) {
      context.handle(
        _ledgerAccountIdMeta,
        ledgerAccountId.isAcceptableOrUnknown(
          data['ledger_account_id']!,
          _ledgerAccountIdMeta,
        ),
      );
    } else if (isInserting) {
      context.missing(_ledgerAccountIdMeta);
    }
    if (data.containsKey('kind')) {
      context.handle(
        _kindMeta,
        kind.isAcceptableOrUnknown(data['kind']!, _kindMeta),
      );
    } else if (isInserting) {
      context.missing(_kindMeta);
    }
    if (data.containsKey('user_account_id')) {
      context.handle(
        _userAccountIdMeta,
        userAccountId.isAcceptableOrUnknown(
          data['user_account_id']!,
          _userAccountIdMeta,
        ),
      );
    }
    if (data.containsKey('category_id')) {
      context.handle(
        _categoryIdMeta,
        categoryId.isAcceptableOrUnknown(data['category_id']!, _categoryIdMeta),
      );
    }
    if (data.containsKey('is_system')) {
      context.handle(
        _isSystemMeta,
        isSystem.isAcceptableOrUnknown(data['is_system']!, _isSystemMeta),
      );
    }
    if (data.containsKey('normal_balance')) {
      context.handle(
        _normalBalanceMeta,
        normalBalance.isAcceptableOrUnknown(
          data['normal_balance']!,
          _normalBalanceMeta,
        ),
      );
    } else if (isInserting) {
      context.missing(_normalBalanceMeta);
    }
    if (data.containsKey('is_archived')) {
      context.handle(
        _isArchivedMeta,
        isArchived.isAcceptableOrUnknown(data['is_archived']!, _isArchivedMeta),
      );
    }
    return context;
  }

  @override
  Set<GeneratedColumn> get $primaryKey => {ledgerAccountId};
  @override
  LedgerAccount map(Map<String, dynamic> data, {String? tablePrefix}) {
    final effectivePrefix = tablePrefix != null ? '$tablePrefix.' : '';
    return LedgerAccount(
      ledgerAccountId: attachedDatabase.typeMapping.read(
        DriftSqlType.string,
        data['${effectivePrefix}ledger_account_id'],
      )!,
      kind: attachedDatabase.typeMapping.read(
        DriftSqlType.string,
        data['${effectivePrefix}kind'],
      )!,
      userAccountId: attachedDatabase.typeMapping.read(
        DriftSqlType.string,
        data['${effectivePrefix}user_account_id'],
      ),
      categoryId: attachedDatabase.typeMapping.read(
        DriftSqlType.string,
        data['${effectivePrefix}category_id'],
      ),
      isSystem: attachedDatabase.typeMapping.read(
        DriftSqlType.bool,
        data['${effectivePrefix}is_system'],
      )!,
      normalBalance: attachedDatabase.typeMapping.read(
        DriftSqlType.string,
        data['${effectivePrefix}normal_balance'],
      )!,
      isArchived: attachedDatabase.typeMapping.read(
        DriftSqlType.bool,
        data['${effectivePrefix}is_archived'],
      )!,
    );
  }

  @override
  $LedgerAccountsTable createAlias(String alias) {
    return $LedgerAccountsTable(attachedDatabase, alias);
  }
}

class LedgerAccount extends DataClass implements Insertable<LedgerAccount> {
  /// Stable string id. User rows use the account uuid; system rows use
  /// fixed ids: `opening_equity`, `adjustments`,
  /// `expense:<categoryId>`, `income:<categoryId>`.
  final String ledgerAccountId;

  /// `user_asset`, `user_liability`, `system_expense`,
  /// `system_income`, `system_opening_equity`, or `system_adjustment`.
  final String kind;

  /// Set exactly when [kind] is `user_asset` or `user_liability`.
  final String? userAccountId;

  /// Set exactly when [kind] is `system_expense` or `system_income`.
  final String? categoryId;

  /// True for every `system_*` kind.
  final bool isSystem;

  /// Normal balance side: `debit` or `credit`. Asset and expense
  /// accounts are normal-debit; liability, income, opening-equity, and
  /// adjustment accounts are normal-credit (blueprint section 6.3).
  final String normalBalance;

  /// Mirrors the archival state of its account or category.
  final bool isArchived;
  const LedgerAccount({
    required this.ledgerAccountId,
    required this.kind,
    this.userAccountId,
    this.categoryId,
    required this.isSystem,
    required this.normalBalance,
    required this.isArchived,
  });
  @override
  Map<String, Expression> toColumns(bool nullToAbsent) {
    final map = <String, Expression>{};
    map['ledger_account_id'] = Variable<String>(ledgerAccountId);
    map['kind'] = Variable<String>(kind);
    if (!nullToAbsent || userAccountId != null) {
      map['user_account_id'] = Variable<String>(userAccountId);
    }
    if (!nullToAbsent || categoryId != null) {
      map['category_id'] = Variable<String>(categoryId);
    }
    map['is_system'] = Variable<bool>(isSystem);
    map['normal_balance'] = Variable<String>(normalBalance);
    map['is_archived'] = Variable<bool>(isArchived);
    return map;
  }

  LedgerAccountsCompanion toCompanion(bool nullToAbsent) {
    return LedgerAccountsCompanion(
      ledgerAccountId: Value(ledgerAccountId),
      kind: Value(kind),
      userAccountId: userAccountId == null && nullToAbsent
          ? const Value.absent()
          : Value(userAccountId),
      categoryId: categoryId == null && nullToAbsent
          ? const Value.absent()
          : Value(categoryId),
      isSystem: Value(isSystem),
      normalBalance: Value(normalBalance),
      isArchived: Value(isArchived),
    );
  }

  factory LedgerAccount.fromJson(
    Map<String, dynamic> json, {
    ValueSerializer? serializer,
  }) {
    serializer ??= driftRuntimeOptions.defaultSerializer;
    return LedgerAccount(
      ledgerAccountId: serializer.fromJson<String>(json['ledgerAccountId']),
      kind: serializer.fromJson<String>(json['kind']),
      userAccountId: serializer.fromJson<String?>(json['userAccountId']),
      categoryId: serializer.fromJson<String?>(json['categoryId']),
      isSystem: serializer.fromJson<bool>(json['isSystem']),
      normalBalance: serializer.fromJson<String>(json['normalBalance']),
      isArchived: serializer.fromJson<bool>(json['isArchived']),
    );
  }
  @override
  Map<String, dynamic> toJson({ValueSerializer? serializer}) {
    serializer ??= driftRuntimeOptions.defaultSerializer;
    return <String, dynamic>{
      'ledgerAccountId': serializer.toJson<String>(ledgerAccountId),
      'kind': serializer.toJson<String>(kind),
      'userAccountId': serializer.toJson<String?>(userAccountId),
      'categoryId': serializer.toJson<String?>(categoryId),
      'isSystem': serializer.toJson<bool>(isSystem),
      'normalBalance': serializer.toJson<String>(normalBalance),
      'isArchived': serializer.toJson<bool>(isArchived),
    };
  }

  LedgerAccount copyWith({
    String? ledgerAccountId,
    String? kind,
    Value<String?> userAccountId = const Value.absent(),
    Value<String?> categoryId = const Value.absent(),
    bool? isSystem,
    String? normalBalance,
    bool? isArchived,
  }) => LedgerAccount(
    ledgerAccountId: ledgerAccountId ?? this.ledgerAccountId,
    kind: kind ?? this.kind,
    userAccountId: userAccountId.present
        ? userAccountId.value
        : this.userAccountId,
    categoryId: categoryId.present ? categoryId.value : this.categoryId,
    isSystem: isSystem ?? this.isSystem,
    normalBalance: normalBalance ?? this.normalBalance,
    isArchived: isArchived ?? this.isArchived,
  );
  LedgerAccount copyWithCompanion(LedgerAccountsCompanion data) {
    return LedgerAccount(
      ledgerAccountId: data.ledgerAccountId.present
          ? data.ledgerAccountId.value
          : this.ledgerAccountId,
      kind: data.kind.present ? data.kind.value : this.kind,
      userAccountId: data.userAccountId.present
          ? data.userAccountId.value
          : this.userAccountId,
      categoryId: data.categoryId.present
          ? data.categoryId.value
          : this.categoryId,
      isSystem: data.isSystem.present ? data.isSystem.value : this.isSystem,
      normalBalance: data.normalBalance.present
          ? data.normalBalance.value
          : this.normalBalance,
      isArchived: data.isArchived.present
          ? data.isArchived.value
          : this.isArchived,
    );
  }

  @override
  String toString() {
    return (StringBuffer('LedgerAccount(')
          ..write('ledgerAccountId: $ledgerAccountId, ')
          ..write('kind: $kind, ')
          ..write('userAccountId: $userAccountId, ')
          ..write('categoryId: $categoryId, ')
          ..write('isSystem: $isSystem, ')
          ..write('normalBalance: $normalBalance, ')
          ..write('isArchived: $isArchived')
          ..write(')'))
        .toString();
  }

  @override
  int get hashCode => Object.hash(
    ledgerAccountId,
    kind,
    userAccountId,
    categoryId,
    isSystem,
    normalBalance,
    isArchived,
  );
  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      (other is LedgerAccount &&
          other.ledgerAccountId == this.ledgerAccountId &&
          other.kind == this.kind &&
          other.userAccountId == this.userAccountId &&
          other.categoryId == this.categoryId &&
          other.isSystem == this.isSystem &&
          other.normalBalance == this.normalBalance &&
          other.isArchived == this.isArchived);
}

class LedgerAccountsCompanion extends UpdateCompanion<LedgerAccount> {
  final Value<String> ledgerAccountId;
  final Value<String> kind;
  final Value<String?> userAccountId;
  final Value<String?> categoryId;
  final Value<bool> isSystem;
  final Value<String> normalBalance;
  final Value<bool> isArchived;
  final Value<int> rowid;
  const LedgerAccountsCompanion({
    this.ledgerAccountId = const Value.absent(),
    this.kind = const Value.absent(),
    this.userAccountId = const Value.absent(),
    this.categoryId = const Value.absent(),
    this.isSystem = const Value.absent(),
    this.normalBalance = const Value.absent(),
    this.isArchived = const Value.absent(),
    this.rowid = const Value.absent(),
  });
  LedgerAccountsCompanion.insert({
    required String ledgerAccountId,
    required String kind,
    this.userAccountId = const Value.absent(),
    this.categoryId = const Value.absent(),
    this.isSystem = const Value.absent(),
    required String normalBalance,
    this.isArchived = const Value.absent(),
    this.rowid = const Value.absent(),
  }) : ledgerAccountId = Value(ledgerAccountId),
       kind = Value(kind),
       normalBalance = Value(normalBalance);
  static Insertable<LedgerAccount> custom({
    Expression<String>? ledgerAccountId,
    Expression<String>? kind,
    Expression<String>? userAccountId,
    Expression<String>? categoryId,
    Expression<bool>? isSystem,
    Expression<String>? normalBalance,
    Expression<bool>? isArchived,
    Expression<int>? rowid,
  }) {
    return RawValuesInsertable({
      if (ledgerAccountId != null) 'ledger_account_id': ledgerAccountId,
      if (kind != null) 'kind': kind,
      if (userAccountId != null) 'user_account_id': userAccountId,
      if (categoryId != null) 'category_id': categoryId,
      if (isSystem != null) 'is_system': isSystem,
      if (normalBalance != null) 'normal_balance': normalBalance,
      if (isArchived != null) 'is_archived': isArchived,
      if (rowid != null) 'rowid': rowid,
    });
  }

  LedgerAccountsCompanion copyWith({
    Value<String>? ledgerAccountId,
    Value<String>? kind,
    Value<String?>? userAccountId,
    Value<String?>? categoryId,
    Value<bool>? isSystem,
    Value<String>? normalBalance,
    Value<bool>? isArchived,
    Value<int>? rowid,
  }) {
    return LedgerAccountsCompanion(
      ledgerAccountId: ledgerAccountId ?? this.ledgerAccountId,
      kind: kind ?? this.kind,
      userAccountId: userAccountId ?? this.userAccountId,
      categoryId: categoryId ?? this.categoryId,
      isSystem: isSystem ?? this.isSystem,
      normalBalance: normalBalance ?? this.normalBalance,
      isArchived: isArchived ?? this.isArchived,
      rowid: rowid ?? this.rowid,
    );
  }

  @override
  Map<String, Expression> toColumns(bool nullToAbsent) {
    final map = <String, Expression>{};
    if (ledgerAccountId.present) {
      map['ledger_account_id'] = Variable<String>(ledgerAccountId.value);
    }
    if (kind.present) {
      map['kind'] = Variable<String>(kind.value);
    }
    if (userAccountId.present) {
      map['user_account_id'] = Variable<String>(userAccountId.value);
    }
    if (categoryId.present) {
      map['category_id'] = Variable<String>(categoryId.value);
    }
    if (isSystem.present) {
      map['is_system'] = Variable<bool>(isSystem.value);
    }
    if (normalBalance.present) {
      map['normal_balance'] = Variable<String>(normalBalance.value);
    }
    if (isArchived.present) {
      map['is_archived'] = Variable<bool>(isArchived.value);
    }
    if (rowid.present) {
      map['rowid'] = Variable<int>(rowid.value);
    }
    return map;
  }

  @override
  String toString() {
    return (StringBuffer('LedgerAccountsCompanion(')
          ..write('ledgerAccountId: $ledgerAccountId, ')
          ..write('kind: $kind, ')
          ..write('userAccountId: $userAccountId, ')
          ..write('categoryId: $categoryId, ')
          ..write('isSystem: $isSystem, ')
          ..write('normalBalance: $normalBalance, ')
          ..write('isArchived: $isArchived, ')
          ..write('rowid: $rowid')
          ..write(')'))
        .toString();
  }
}

class $FinancialTransactionsTable extends FinancialTransactions
    with TableInfo<$FinancialTransactionsTable, FinancialTransaction> {
  @override
  final GeneratedDatabase attachedDatabase;
  final String? _alias;
  $FinancialTransactionsTable(this.attachedDatabase, [this._alias]);
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
  static const VerificationMeta _uuidMeta = const VerificationMeta('uuid');
  @override
  late final GeneratedColumn<String> uuid = GeneratedColumn<String>(
    'uuid',
    aliasedName,
    false,
    type: DriftSqlType.string,
    requiredDuringInsert: true,
    defaultConstraints: GeneratedColumn.constraintIsAlways('UNIQUE'),
  );
  static const VerificationMeta _kindMeta = const VerificationMeta('kind');
  @override
  late final GeneratedColumn<String> kind = GeneratedColumn<String>(
    'kind',
    aliasedName,
    false,
    type: DriftSqlType.string,
    requiredDuringInsert: true,
  );
  static const VerificationMeta _categoryIdMeta = const VerificationMeta(
    'categoryId',
  );
  @override
  late final GeneratedColumn<String> categoryId = GeneratedColumn<String>(
    'category_id',
    aliasedName,
    true,
    type: DriftSqlType.string,
    requiredDuringInsert: false,
    defaultConstraints: GeneratedColumn.constraintIsAlways(
      'REFERENCES categories (category_id)',
    ),
  );
  static const VerificationMeta _reversesTransactionIdMeta =
      const VerificationMeta('reversesTransactionId');
  @override
  late final GeneratedColumn<String> reversesTransactionId =
      GeneratedColumn<String>(
        'reverses_transaction_id',
        aliasedName,
        true,
        type: DriftSqlType.string,
        requiredDuringInsert: false,
        defaultConstraints: GeneratedColumn.constraintIsAlways(
          'REFERENCES financial_transactions (uuid)',
        ),
      );
  static const VerificationMeta _relatedTransactionIdMeta =
      const VerificationMeta('relatedTransactionId');
  @override
  late final GeneratedColumn<String> relatedTransactionId =
      GeneratedColumn<String>(
        'related_transaction_id',
        aliasedName,
        true,
        type: DriftSqlType.string,
        requiredDuringInsert: false,
        defaultConstraints: GeneratedColumn.constraintIsAlways(
          'REFERENCES financial_transactions (uuid)',
        ),
      );
  static const VerificationMeta _sourceAccountIdMeta = const VerificationMeta(
    'sourceAccountId',
  );
  @override
  late final GeneratedColumn<String> sourceAccountId = GeneratedColumn<String>(
    'source_account_id',
    aliasedName,
    true,
    type: DriftSqlType.string,
    requiredDuringInsert: false,
    defaultConstraints: GeneratedColumn.constraintIsAlways(
      'REFERENCES accounts (uuid)',
    ),
  );
  static const VerificationMeta _destinationAccountIdMeta =
      const VerificationMeta('destinationAccountId');
  @override
  late final GeneratedColumn<String> destinationAccountId =
      GeneratedColumn<String>(
        'destination_account_id',
        aliasedName,
        true,
        type: DriftSqlType.string,
        requiredDuringInsert: false,
        defaultConstraints: GeneratedColumn.constraintIsAlways(
          'REFERENCES accounts (uuid)',
        ),
      );
  static const VerificationMeta _refundAccountIdMeta = const VerificationMeta(
    'refundAccountId',
  );
  @override
  late final GeneratedColumn<String> refundAccountId = GeneratedColumn<String>(
    'refund_account_id',
    aliasedName,
    true,
    type: DriftSqlType.string,
    requiredDuringInsert: false,
    defaultConstraints: GeneratedColumn.constraintIsAlways(
      'REFERENCES accounts (uuid)',
    ),
  );
  static const VerificationMeta _amountMinorUnitsMeta = const VerificationMeta(
    'amountMinorUnits',
  );
  @override
  late final GeneratedColumn<int> amountMinorUnits = GeneratedColumn<int>(
    'amount_minor_units',
    aliasedName,
    false,
    type: DriftSqlType.int,
    requiredDuringInsert: true,
  );
  static const VerificationMeta _currencyCodeMeta = const VerificationMeta(
    'currencyCode',
  );
  @override
  late final GeneratedColumn<String> currencyCode = GeneratedColumn<String>(
    'currency_code',
    aliasedName,
    false,
    type: DriftSqlType.string,
    requiredDuringInsert: false,
    defaultValue: const Constant('INR'),
  );
  static const VerificationMeta _descriptionMeta = const VerificationMeta(
    'description',
  );
  @override
  late final GeneratedColumn<String> description = GeneratedColumn<String>(
    'description',
    aliasedName,
    true,
    type: DriftSqlType.string,
    requiredDuringInsert: false,
  );
  static const VerificationMeta _notesMeta = const VerificationMeta('notes');
  @override
  late final GeneratedColumn<String> notes = GeneratedColumn<String>(
    'notes',
    aliasedName,
    true,
    type: DriftSqlType.string,
    requiredDuringInsert: false,
  );
  static const VerificationMeta _paymentChannelMeta = const VerificationMeta(
    'paymentChannel',
  );
  @override
  late final GeneratedColumn<String> paymentChannel = GeneratedColumn<String>(
    'payment_channel',
    aliasedName,
    false,
    type: DriftSqlType.string,
    requiredDuringInsert: true,
  );
  static const VerificationMeta _occurredAtMeta = const VerificationMeta(
    'occurredAt',
  );
  @override
  late final GeneratedColumn<DateTime> occurredAt = GeneratedColumn<DateTime>(
    'occurred_at',
    aliasedName,
    false,
    type: DriftSqlType.dateTime,
    requiredDuringInsert: true,
  );
  static const VerificationMeta _statusMeta = const VerificationMeta('status');
  @override
  late final GeneratedColumn<String> status = GeneratedColumn<String>(
    'status',
    aliasedName,
    false,
    type: DriftSqlType.string,
    requiredDuringInsert: true,
  );
  static const VerificationMeta _sourceMeta = const VerificationMeta('source');
  @override
  late final GeneratedColumn<String> source = GeneratedColumn<String>(
    'source',
    aliasedName,
    false,
    type: DriftSqlType.string,
    requiredDuringInsert: true,
  );
  static const VerificationMeta _adjustmentReasonMeta = const VerificationMeta(
    'adjustmentReason',
  );
  @override
  late final GeneratedColumn<String> adjustmentReason = GeneratedColumn<String>(
    'adjustment_reason',
    aliasedName,
    true,
    type: DriftSqlType.string,
    requiredDuringInsert: false,
  );
  static const VerificationMeta _createdAtMeta = const VerificationMeta(
    'createdAt',
  );
  @override
  late final GeneratedColumn<DateTime> createdAt = GeneratedColumn<DateTime>(
    'created_at',
    aliasedName,
    false,
    type: DriftSqlType.dateTime,
    requiredDuringInsert: true,
  );
  static const VerificationMeta _updatedAtMeta = const VerificationMeta(
    'updatedAt',
  );
  @override
  late final GeneratedColumn<DateTime> updatedAt = GeneratedColumn<DateTime>(
    'updated_at',
    aliasedName,
    false,
    type: DriftSqlType.dateTime,
    requiredDuringInsert: true,
  );
  static const VerificationMeta _syncRevisionMeta = const VerificationMeta(
    'syncRevision',
  );
  @override
  late final GeneratedColumn<int> syncRevision = GeneratedColumn<int>(
    'sync_revision',
    aliasedName,
    false,
    type: DriftSqlType.int,
    requiredDuringInsert: false,
    defaultValue: const Constant(0),
  );
  static const VerificationMeta _syncStatusMeta = const VerificationMeta(
    'syncStatus',
  );
  @override
  late final GeneratedColumn<String> syncStatus = GeneratedColumn<String>(
    'sync_status',
    aliasedName,
    false,
    type: DriftSqlType.string,
    requiredDuringInsert: true,
  );
  @override
  List<GeneratedColumn> get $columns => [
    id,
    uuid,
    kind,
    categoryId,
    reversesTransactionId,
    relatedTransactionId,
    sourceAccountId,
    destinationAccountId,
    refundAccountId,
    amountMinorUnits,
    currencyCode,
    description,
    notes,
    paymentChannel,
    occurredAt,
    status,
    source,
    adjustmentReason,
    createdAt,
    updatedAt,
    syncRevision,
    syncStatus,
  ];
  @override
  String get aliasedName => _alias ?? actualTableName;
  @override
  String get actualTableName => $name;
  static const String $name = 'financial_transactions';
  @override
  VerificationContext validateIntegrity(
    Insertable<FinancialTransaction> instance, {
    bool isInserting = false,
  }) {
    final context = VerificationContext();
    final data = instance.toColumns(true);
    if (data.containsKey('id')) {
      context.handle(_idMeta, id.isAcceptableOrUnknown(data['id']!, _idMeta));
    }
    if (data.containsKey('uuid')) {
      context.handle(
        _uuidMeta,
        uuid.isAcceptableOrUnknown(data['uuid']!, _uuidMeta),
      );
    } else if (isInserting) {
      context.missing(_uuidMeta);
    }
    if (data.containsKey('kind')) {
      context.handle(
        _kindMeta,
        kind.isAcceptableOrUnknown(data['kind']!, _kindMeta),
      );
    } else if (isInserting) {
      context.missing(_kindMeta);
    }
    if (data.containsKey('category_id')) {
      context.handle(
        _categoryIdMeta,
        categoryId.isAcceptableOrUnknown(data['category_id']!, _categoryIdMeta),
      );
    }
    if (data.containsKey('reverses_transaction_id')) {
      context.handle(
        _reversesTransactionIdMeta,
        reversesTransactionId.isAcceptableOrUnknown(
          data['reverses_transaction_id']!,
          _reversesTransactionIdMeta,
        ),
      );
    }
    if (data.containsKey('related_transaction_id')) {
      context.handle(
        _relatedTransactionIdMeta,
        relatedTransactionId.isAcceptableOrUnknown(
          data['related_transaction_id']!,
          _relatedTransactionIdMeta,
        ),
      );
    }
    if (data.containsKey('source_account_id')) {
      context.handle(
        _sourceAccountIdMeta,
        sourceAccountId.isAcceptableOrUnknown(
          data['source_account_id']!,
          _sourceAccountIdMeta,
        ),
      );
    }
    if (data.containsKey('destination_account_id')) {
      context.handle(
        _destinationAccountIdMeta,
        destinationAccountId.isAcceptableOrUnknown(
          data['destination_account_id']!,
          _destinationAccountIdMeta,
        ),
      );
    }
    if (data.containsKey('refund_account_id')) {
      context.handle(
        _refundAccountIdMeta,
        refundAccountId.isAcceptableOrUnknown(
          data['refund_account_id']!,
          _refundAccountIdMeta,
        ),
      );
    }
    if (data.containsKey('amount_minor_units')) {
      context.handle(
        _amountMinorUnitsMeta,
        amountMinorUnits.isAcceptableOrUnknown(
          data['amount_minor_units']!,
          _amountMinorUnitsMeta,
        ),
      );
    } else if (isInserting) {
      context.missing(_amountMinorUnitsMeta);
    }
    if (data.containsKey('currency_code')) {
      context.handle(
        _currencyCodeMeta,
        currencyCode.isAcceptableOrUnknown(
          data['currency_code']!,
          _currencyCodeMeta,
        ),
      );
    }
    if (data.containsKey('description')) {
      context.handle(
        _descriptionMeta,
        description.isAcceptableOrUnknown(
          data['description']!,
          _descriptionMeta,
        ),
      );
    }
    if (data.containsKey('notes')) {
      context.handle(
        _notesMeta,
        notes.isAcceptableOrUnknown(data['notes']!, _notesMeta),
      );
    }
    if (data.containsKey('payment_channel')) {
      context.handle(
        _paymentChannelMeta,
        paymentChannel.isAcceptableOrUnknown(
          data['payment_channel']!,
          _paymentChannelMeta,
        ),
      );
    } else if (isInserting) {
      context.missing(_paymentChannelMeta);
    }
    if (data.containsKey('occurred_at')) {
      context.handle(
        _occurredAtMeta,
        occurredAt.isAcceptableOrUnknown(data['occurred_at']!, _occurredAtMeta),
      );
    } else if (isInserting) {
      context.missing(_occurredAtMeta);
    }
    if (data.containsKey('status')) {
      context.handle(
        _statusMeta,
        status.isAcceptableOrUnknown(data['status']!, _statusMeta),
      );
    } else if (isInserting) {
      context.missing(_statusMeta);
    }
    if (data.containsKey('source')) {
      context.handle(
        _sourceMeta,
        source.isAcceptableOrUnknown(data['source']!, _sourceMeta),
      );
    } else if (isInserting) {
      context.missing(_sourceMeta);
    }
    if (data.containsKey('adjustment_reason')) {
      context.handle(
        _adjustmentReasonMeta,
        adjustmentReason.isAcceptableOrUnknown(
          data['adjustment_reason']!,
          _adjustmentReasonMeta,
        ),
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
    if (data.containsKey('updated_at')) {
      context.handle(
        _updatedAtMeta,
        updatedAt.isAcceptableOrUnknown(data['updated_at']!, _updatedAtMeta),
      );
    } else if (isInserting) {
      context.missing(_updatedAtMeta);
    }
    if (data.containsKey('sync_revision')) {
      context.handle(
        _syncRevisionMeta,
        syncRevision.isAcceptableOrUnknown(
          data['sync_revision']!,
          _syncRevisionMeta,
        ),
      );
    }
    if (data.containsKey('sync_status')) {
      context.handle(
        _syncStatusMeta,
        syncStatus.isAcceptableOrUnknown(data['sync_status']!, _syncStatusMeta),
      );
    } else if (isInserting) {
      context.missing(_syncStatusMeta);
    }
    return context;
  }

  @override
  Set<GeneratedColumn> get $primaryKey => {id};
  @override
  FinancialTransaction map(Map<String, dynamic> data, {String? tablePrefix}) {
    final effectivePrefix = tablePrefix != null ? '$tablePrefix.' : '';
    return FinancialTransaction(
      id: attachedDatabase.typeMapping.read(
        DriftSqlType.int,
        data['${effectivePrefix}id'],
      )!,
      uuid: attachedDatabase.typeMapping.read(
        DriftSqlType.string,
        data['${effectivePrefix}uuid'],
      )!,
      kind: attachedDatabase.typeMapping.read(
        DriftSqlType.string,
        data['${effectivePrefix}kind'],
      )!,
      categoryId: attachedDatabase.typeMapping.read(
        DriftSqlType.string,
        data['${effectivePrefix}category_id'],
      ),
      reversesTransactionId: attachedDatabase.typeMapping.read(
        DriftSqlType.string,
        data['${effectivePrefix}reverses_transaction_id'],
      ),
      relatedTransactionId: attachedDatabase.typeMapping.read(
        DriftSqlType.string,
        data['${effectivePrefix}related_transaction_id'],
      ),
      sourceAccountId: attachedDatabase.typeMapping.read(
        DriftSqlType.string,
        data['${effectivePrefix}source_account_id'],
      ),
      destinationAccountId: attachedDatabase.typeMapping.read(
        DriftSqlType.string,
        data['${effectivePrefix}destination_account_id'],
      ),
      refundAccountId: attachedDatabase.typeMapping.read(
        DriftSqlType.string,
        data['${effectivePrefix}refund_account_id'],
      ),
      amountMinorUnits: attachedDatabase.typeMapping.read(
        DriftSqlType.int,
        data['${effectivePrefix}amount_minor_units'],
      )!,
      currencyCode: attachedDatabase.typeMapping.read(
        DriftSqlType.string,
        data['${effectivePrefix}currency_code'],
      )!,
      description: attachedDatabase.typeMapping.read(
        DriftSqlType.string,
        data['${effectivePrefix}description'],
      ),
      notes: attachedDatabase.typeMapping.read(
        DriftSqlType.string,
        data['${effectivePrefix}notes'],
      ),
      paymentChannel: attachedDatabase.typeMapping.read(
        DriftSqlType.string,
        data['${effectivePrefix}payment_channel'],
      )!,
      occurredAt: attachedDatabase.typeMapping.read(
        DriftSqlType.dateTime,
        data['${effectivePrefix}occurred_at'],
      )!,
      status: attachedDatabase.typeMapping.read(
        DriftSqlType.string,
        data['${effectivePrefix}status'],
      )!,
      source: attachedDatabase.typeMapping.read(
        DriftSqlType.string,
        data['${effectivePrefix}source'],
      )!,
      adjustmentReason: attachedDatabase.typeMapping.read(
        DriftSqlType.string,
        data['${effectivePrefix}adjustment_reason'],
      ),
      createdAt: attachedDatabase.typeMapping.read(
        DriftSqlType.dateTime,
        data['${effectivePrefix}created_at'],
      )!,
      updatedAt: attachedDatabase.typeMapping.read(
        DriftSqlType.dateTime,
        data['${effectivePrefix}updated_at'],
      )!,
      syncRevision: attachedDatabase.typeMapping.read(
        DriftSqlType.int,
        data['${effectivePrefix}sync_revision'],
      )!,
      syncStatus: attachedDatabase.typeMapping.read(
        DriftSqlType.string,
        data['${effectivePrefix}sync_status'],
      )!,
    );
  }

  @override
  $FinancialTransactionsTable createAlias(String alias) {
    return $FinancialTransactionsTable(attachedDatabase, alias);
  }
}

class FinancialTransaction extends DataClass
    implements Insertable<FinancialTransaction> {
  final int id;
  final String uuid;

  /// `expense`, `income`, `transfer`, `card_payment`, `refund`,
  /// `adjustment`, `opening_balance`, or `reversal`.
  final String kind;

  /// Stable category id. Nullable for transfers, card payments, and
  /// opening balances. For a refund, the immutable category snapshot
  /// taken from the original at refund creation (later stages).
  final String? categoryId;

  /// Set on refunds and reversals, pointing at the original
  /// transaction by uuid.
  final String? reversesTransactionId;

  /// Set on adjustments that correct another transaction, for
  /// example an opening-balance correction.
  final String? relatedTransactionId;

  /// Required exactly when [kind] is `transfer` or `card_payment`:
  /// the funding account for a card payment.
  final String? sourceAccountId;

  /// Required exactly when [kind] is `transfer` or `card_payment`.
  final String? destinationAccountId;

  /// Required exactly when [kind] is `refund`: the account money
  /// returns to or is paid out of.
  final String? refundAccountId;

  /// Event amount in integer minor units, always strictly positive.
  /// For a refund, the refunded amount; for a transfer, the moved
  /// amount; for an opening balance, the absolute opening amount.
  /// Positivity is enforced by the table-level CHECK constraint below
  /// (a column-level `.check(...)` expression would read as a
  /// self-referencing getter to the analyzer).
  final int amountMinorUnits;
  final String currencyCode;
  final String? description;
  final String? notes;

  /// UPI, cash, card, or bank. Replaces the old free-text payment
  /// method; canonical stored values are used internally while the
  /// existing display labels remain (approved decision 5).
  final String paymentChannel;
  final DateTime occurredAt;

  /// `active` or `deleted` only.
  final String status;

  /// `manual`, `recurring`, `import`, or `template`.
  final String source;

  /// Required exactly when [kind] is `adjustment`:
  /// `opening_balance_correction`, `balance_correction`,
  /// `fee_correction`, or `other`.
  final String? adjustmentReason;
  final DateTime createdAt;
  final DateTime updatedAt;

  /// Local-only conditional-acknowledgement token, as established in
  /// PR #2. Never written to Google Sheets.
  final int syncRevision;
  final String syncStatus;
  const FinancialTransaction({
    required this.id,
    required this.uuid,
    required this.kind,
    this.categoryId,
    this.reversesTransactionId,
    this.relatedTransactionId,
    this.sourceAccountId,
    this.destinationAccountId,
    this.refundAccountId,
    required this.amountMinorUnits,
    required this.currencyCode,
    this.description,
    this.notes,
    required this.paymentChannel,
    required this.occurredAt,
    required this.status,
    required this.source,
    this.adjustmentReason,
    required this.createdAt,
    required this.updatedAt,
    required this.syncRevision,
    required this.syncStatus,
  });
  @override
  Map<String, Expression> toColumns(bool nullToAbsent) {
    final map = <String, Expression>{};
    map['id'] = Variable<int>(id);
    map['uuid'] = Variable<String>(uuid);
    map['kind'] = Variable<String>(kind);
    if (!nullToAbsent || categoryId != null) {
      map['category_id'] = Variable<String>(categoryId);
    }
    if (!nullToAbsent || reversesTransactionId != null) {
      map['reverses_transaction_id'] = Variable<String>(reversesTransactionId);
    }
    if (!nullToAbsent || relatedTransactionId != null) {
      map['related_transaction_id'] = Variable<String>(relatedTransactionId);
    }
    if (!nullToAbsent || sourceAccountId != null) {
      map['source_account_id'] = Variable<String>(sourceAccountId);
    }
    if (!nullToAbsent || destinationAccountId != null) {
      map['destination_account_id'] = Variable<String>(destinationAccountId);
    }
    if (!nullToAbsent || refundAccountId != null) {
      map['refund_account_id'] = Variable<String>(refundAccountId);
    }
    map['amount_minor_units'] = Variable<int>(amountMinorUnits);
    map['currency_code'] = Variable<String>(currencyCode);
    if (!nullToAbsent || description != null) {
      map['description'] = Variable<String>(description);
    }
    if (!nullToAbsent || notes != null) {
      map['notes'] = Variable<String>(notes);
    }
    map['payment_channel'] = Variable<String>(paymentChannel);
    map['occurred_at'] = Variable<DateTime>(occurredAt);
    map['status'] = Variable<String>(status);
    map['source'] = Variable<String>(source);
    if (!nullToAbsent || adjustmentReason != null) {
      map['adjustment_reason'] = Variable<String>(adjustmentReason);
    }
    map['created_at'] = Variable<DateTime>(createdAt);
    map['updated_at'] = Variable<DateTime>(updatedAt);
    map['sync_revision'] = Variable<int>(syncRevision);
    map['sync_status'] = Variable<String>(syncStatus);
    return map;
  }

  FinancialTransactionsCompanion toCompanion(bool nullToAbsent) {
    return FinancialTransactionsCompanion(
      id: Value(id),
      uuid: Value(uuid),
      kind: Value(kind),
      categoryId: categoryId == null && nullToAbsent
          ? const Value.absent()
          : Value(categoryId),
      reversesTransactionId: reversesTransactionId == null && nullToAbsent
          ? const Value.absent()
          : Value(reversesTransactionId),
      relatedTransactionId: relatedTransactionId == null && nullToAbsent
          ? const Value.absent()
          : Value(relatedTransactionId),
      sourceAccountId: sourceAccountId == null && nullToAbsent
          ? const Value.absent()
          : Value(sourceAccountId),
      destinationAccountId: destinationAccountId == null && nullToAbsent
          ? const Value.absent()
          : Value(destinationAccountId),
      refundAccountId: refundAccountId == null && nullToAbsent
          ? const Value.absent()
          : Value(refundAccountId),
      amountMinorUnits: Value(amountMinorUnits),
      currencyCode: Value(currencyCode),
      description: description == null && nullToAbsent
          ? const Value.absent()
          : Value(description),
      notes: notes == null && nullToAbsent
          ? const Value.absent()
          : Value(notes),
      paymentChannel: Value(paymentChannel),
      occurredAt: Value(occurredAt),
      status: Value(status),
      source: Value(source),
      adjustmentReason: adjustmentReason == null && nullToAbsent
          ? const Value.absent()
          : Value(adjustmentReason),
      createdAt: Value(createdAt),
      updatedAt: Value(updatedAt),
      syncRevision: Value(syncRevision),
      syncStatus: Value(syncStatus),
    );
  }

  factory FinancialTransaction.fromJson(
    Map<String, dynamic> json, {
    ValueSerializer? serializer,
  }) {
    serializer ??= driftRuntimeOptions.defaultSerializer;
    return FinancialTransaction(
      id: serializer.fromJson<int>(json['id']),
      uuid: serializer.fromJson<String>(json['uuid']),
      kind: serializer.fromJson<String>(json['kind']),
      categoryId: serializer.fromJson<String?>(json['categoryId']),
      reversesTransactionId: serializer.fromJson<String?>(
        json['reversesTransactionId'],
      ),
      relatedTransactionId: serializer.fromJson<String?>(
        json['relatedTransactionId'],
      ),
      sourceAccountId: serializer.fromJson<String?>(json['sourceAccountId']),
      destinationAccountId: serializer.fromJson<String?>(
        json['destinationAccountId'],
      ),
      refundAccountId: serializer.fromJson<String?>(json['refundAccountId']),
      amountMinorUnits: serializer.fromJson<int>(json['amountMinorUnits']),
      currencyCode: serializer.fromJson<String>(json['currencyCode']),
      description: serializer.fromJson<String?>(json['description']),
      notes: serializer.fromJson<String?>(json['notes']),
      paymentChannel: serializer.fromJson<String>(json['paymentChannel']),
      occurredAt: serializer.fromJson<DateTime>(json['occurredAt']),
      status: serializer.fromJson<String>(json['status']),
      source: serializer.fromJson<String>(json['source']),
      adjustmentReason: serializer.fromJson<String?>(json['adjustmentReason']),
      createdAt: serializer.fromJson<DateTime>(json['createdAt']),
      updatedAt: serializer.fromJson<DateTime>(json['updatedAt']),
      syncRevision: serializer.fromJson<int>(json['syncRevision']),
      syncStatus: serializer.fromJson<String>(json['syncStatus']),
    );
  }
  @override
  Map<String, dynamic> toJson({ValueSerializer? serializer}) {
    serializer ??= driftRuntimeOptions.defaultSerializer;
    return <String, dynamic>{
      'id': serializer.toJson<int>(id),
      'uuid': serializer.toJson<String>(uuid),
      'kind': serializer.toJson<String>(kind),
      'categoryId': serializer.toJson<String?>(categoryId),
      'reversesTransactionId': serializer.toJson<String?>(
        reversesTransactionId,
      ),
      'relatedTransactionId': serializer.toJson<String?>(relatedTransactionId),
      'sourceAccountId': serializer.toJson<String?>(sourceAccountId),
      'destinationAccountId': serializer.toJson<String?>(destinationAccountId),
      'refundAccountId': serializer.toJson<String?>(refundAccountId),
      'amountMinorUnits': serializer.toJson<int>(amountMinorUnits),
      'currencyCode': serializer.toJson<String>(currencyCode),
      'description': serializer.toJson<String?>(description),
      'notes': serializer.toJson<String?>(notes),
      'paymentChannel': serializer.toJson<String>(paymentChannel),
      'occurredAt': serializer.toJson<DateTime>(occurredAt),
      'status': serializer.toJson<String>(status),
      'source': serializer.toJson<String>(source),
      'adjustmentReason': serializer.toJson<String?>(adjustmentReason),
      'createdAt': serializer.toJson<DateTime>(createdAt),
      'updatedAt': serializer.toJson<DateTime>(updatedAt),
      'syncRevision': serializer.toJson<int>(syncRevision),
      'syncStatus': serializer.toJson<String>(syncStatus),
    };
  }

  FinancialTransaction copyWith({
    int? id,
    String? uuid,
    String? kind,
    Value<String?> categoryId = const Value.absent(),
    Value<String?> reversesTransactionId = const Value.absent(),
    Value<String?> relatedTransactionId = const Value.absent(),
    Value<String?> sourceAccountId = const Value.absent(),
    Value<String?> destinationAccountId = const Value.absent(),
    Value<String?> refundAccountId = const Value.absent(),
    int? amountMinorUnits,
    String? currencyCode,
    Value<String?> description = const Value.absent(),
    Value<String?> notes = const Value.absent(),
    String? paymentChannel,
    DateTime? occurredAt,
    String? status,
    String? source,
    Value<String?> adjustmentReason = const Value.absent(),
    DateTime? createdAt,
    DateTime? updatedAt,
    int? syncRevision,
    String? syncStatus,
  }) => FinancialTransaction(
    id: id ?? this.id,
    uuid: uuid ?? this.uuid,
    kind: kind ?? this.kind,
    categoryId: categoryId.present ? categoryId.value : this.categoryId,
    reversesTransactionId: reversesTransactionId.present
        ? reversesTransactionId.value
        : this.reversesTransactionId,
    relatedTransactionId: relatedTransactionId.present
        ? relatedTransactionId.value
        : this.relatedTransactionId,
    sourceAccountId: sourceAccountId.present
        ? sourceAccountId.value
        : this.sourceAccountId,
    destinationAccountId: destinationAccountId.present
        ? destinationAccountId.value
        : this.destinationAccountId,
    refundAccountId: refundAccountId.present
        ? refundAccountId.value
        : this.refundAccountId,
    amountMinorUnits: amountMinorUnits ?? this.amountMinorUnits,
    currencyCode: currencyCode ?? this.currencyCode,
    description: description.present ? description.value : this.description,
    notes: notes.present ? notes.value : this.notes,
    paymentChannel: paymentChannel ?? this.paymentChannel,
    occurredAt: occurredAt ?? this.occurredAt,
    status: status ?? this.status,
    source: source ?? this.source,
    adjustmentReason: adjustmentReason.present
        ? adjustmentReason.value
        : this.adjustmentReason,
    createdAt: createdAt ?? this.createdAt,
    updatedAt: updatedAt ?? this.updatedAt,
    syncRevision: syncRevision ?? this.syncRevision,
    syncStatus: syncStatus ?? this.syncStatus,
  );
  FinancialTransaction copyWithCompanion(FinancialTransactionsCompanion data) {
    return FinancialTransaction(
      id: data.id.present ? data.id.value : this.id,
      uuid: data.uuid.present ? data.uuid.value : this.uuid,
      kind: data.kind.present ? data.kind.value : this.kind,
      categoryId: data.categoryId.present
          ? data.categoryId.value
          : this.categoryId,
      reversesTransactionId: data.reversesTransactionId.present
          ? data.reversesTransactionId.value
          : this.reversesTransactionId,
      relatedTransactionId: data.relatedTransactionId.present
          ? data.relatedTransactionId.value
          : this.relatedTransactionId,
      sourceAccountId: data.sourceAccountId.present
          ? data.sourceAccountId.value
          : this.sourceAccountId,
      destinationAccountId: data.destinationAccountId.present
          ? data.destinationAccountId.value
          : this.destinationAccountId,
      refundAccountId: data.refundAccountId.present
          ? data.refundAccountId.value
          : this.refundAccountId,
      amountMinorUnits: data.amountMinorUnits.present
          ? data.amountMinorUnits.value
          : this.amountMinorUnits,
      currencyCode: data.currencyCode.present
          ? data.currencyCode.value
          : this.currencyCode,
      description: data.description.present
          ? data.description.value
          : this.description,
      notes: data.notes.present ? data.notes.value : this.notes,
      paymentChannel: data.paymentChannel.present
          ? data.paymentChannel.value
          : this.paymentChannel,
      occurredAt: data.occurredAt.present
          ? data.occurredAt.value
          : this.occurredAt,
      status: data.status.present ? data.status.value : this.status,
      source: data.source.present ? data.source.value : this.source,
      adjustmentReason: data.adjustmentReason.present
          ? data.adjustmentReason.value
          : this.adjustmentReason,
      createdAt: data.createdAt.present ? data.createdAt.value : this.createdAt,
      updatedAt: data.updatedAt.present ? data.updatedAt.value : this.updatedAt,
      syncRevision: data.syncRevision.present
          ? data.syncRevision.value
          : this.syncRevision,
      syncStatus: data.syncStatus.present
          ? data.syncStatus.value
          : this.syncStatus,
    );
  }

  @override
  String toString() {
    return (StringBuffer('FinancialTransaction(')
          ..write('id: $id, ')
          ..write('uuid: $uuid, ')
          ..write('kind: $kind, ')
          ..write('categoryId: $categoryId, ')
          ..write('reversesTransactionId: $reversesTransactionId, ')
          ..write('relatedTransactionId: $relatedTransactionId, ')
          ..write('sourceAccountId: $sourceAccountId, ')
          ..write('destinationAccountId: $destinationAccountId, ')
          ..write('refundAccountId: $refundAccountId, ')
          ..write('amountMinorUnits: $amountMinorUnits, ')
          ..write('currencyCode: $currencyCode, ')
          ..write('description: $description, ')
          ..write('notes: $notes, ')
          ..write('paymentChannel: $paymentChannel, ')
          ..write('occurredAt: $occurredAt, ')
          ..write('status: $status, ')
          ..write('source: $source, ')
          ..write('adjustmentReason: $adjustmentReason, ')
          ..write('createdAt: $createdAt, ')
          ..write('updatedAt: $updatedAt, ')
          ..write('syncRevision: $syncRevision, ')
          ..write('syncStatus: $syncStatus')
          ..write(')'))
        .toString();
  }

  @override
  int get hashCode => Object.hashAll([
    id,
    uuid,
    kind,
    categoryId,
    reversesTransactionId,
    relatedTransactionId,
    sourceAccountId,
    destinationAccountId,
    refundAccountId,
    amountMinorUnits,
    currencyCode,
    description,
    notes,
    paymentChannel,
    occurredAt,
    status,
    source,
    adjustmentReason,
    createdAt,
    updatedAt,
    syncRevision,
    syncStatus,
  ]);
  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      (other is FinancialTransaction &&
          other.id == this.id &&
          other.uuid == this.uuid &&
          other.kind == this.kind &&
          other.categoryId == this.categoryId &&
          other.reversesTransactionId == this.reversesTransactionId &&
          other.relatedTransactionId == this.relatedTransactionId &&
          other.sourceAccountId == this.sourceAccountId &&
          other.destinationAccountId == this.destinationAccountId &&
          other.refundAccountId == this.refundAccountId &&
          other.amountMinorUnits == this.amountMinorUnits &&
          other.currencyCode == this.currencyCode &&
          other.description == this.description &&
          other.notes == this.notes &&
          other.paymentChannel == this.paymentChannel &&
          other.occurredAt == this.occurredAt &&
          other.status == this.status &&
          other.source == this.source &&
          other.adjustmentReason == this.adjustmentReason &&
          other.createdAt == this.createdAt &&
          other.updatedAt == this.updatedAt &&
          other.syncRevision == this.syncRevision &&
          other.syncStatus == this.syncStatus);
}

class FinancialTransactionsCompanion
    extends UpdateCompanion<FinancialTransaction> {
  final Value<int> id;
  final Value<String> uuid;
  final Value<String> kind;
  final Value<String?> categoryId;
  final Value<String?> reversesTransactionId;
  final Value<String?> relatedTransactionId;
  final Value<String?> sourceAccountId;
  final Value<String?> destinationAccountId;
  final Value<String?> refundAccountId;
  final Value<int> amountMinorUnits;
  final Value<String> currencyCode;
  final Value<String?> description;
  final Value<String?> notes;
  final Value<String> paymentChannel;
  final Value<DateTime> occurredAt;
  final Value<String> status;
  final Value<String> source;
  final Value<String?> adjustmentReason;
  final Value<DateTime> createdAt;
  final Value<DateTime> updatedAt;
  final Value<int> syncRevision;
  final Value<String> syncStatus;
  const FinancialTransactionsCompanion({
    this.id = const Value.absent(),
    this.uuid = const Value.absent(),
    this.kind = const Value.absent(),
    this.categoryId = const Value.absent(),
    this.reversesTransactionId = const Value.absent(),
    this.relatedTransactionId = const Value.absent(),
    this.sourceAccountId = const Value.absent(),
    this.destinationAccountId = const Value.absent(),
    this.refundAccountId = const Value.absent(),
    this.amountMinorUnits = const Value.absent(),
    this.currencyCode = const Value.absent(),
    this.description = const Value.absent(),
    this.notes = const Value.absent(),
    this.paymentChannel = const Value.absent(),
    this.occurredAt = const Value.absent(),
    this.status = const Value.absent(),
    this.source = const Value.absent(),
    this.adjustmentReason = const Value.absent(),
    this.createdAt = const Value.absent(),
    this.updatedAt = const Value.absent(),
    this.syncRevision = const Value.absent(),
    this.syncStatus = const Value.absent(),
  });
  FinancialTransactionsCompanion.insert({
    this.id = const Value.absent(),
    required String uuid,
    required String kind,
    this.categoryId = const Value.absent(),
    this.reversesTransactionId = const Value.absent(),
    this.relatedTransactionId = const Value.absent(),
    this.sourceAccountId = const Value.absent(),
    this.destinationAccountId = const Value.absent(),
    this.refundAccountId = const Value.absent(),
    required int amountMinorUnits,
    this.currencyCode = const Value.absent(),
    this.description = const Value.absent(),
    this.notes = const Value.absent(),
    required String paymentChannel,
    required DateTime occurredAt,
    required String status,
    required String source,
    this.adjustmentReason = const Value.absent(),
    required DateTime createdAt,
    required DateTime updatedAt,
    this.syncRevision = const Value.absent(),
    required String syncStatus,
  }) : uuid = Value(uuid),
       kind = Value(kind),
       amountMinorUnits = Value(amountMinorUnits),
       paymentChannel = Value(paymentChannel),
       occurredAt = Value(occurredAt),
       status = Value(status),
       source = Value(source),
       createdAt = Value(createdAt),
       updatedAt = Value(updatedAt),
       syncStatus = Value(syncStatus);
  static Insertable<FinancialTransaction> custom({
    Expression<int>? id,
    Expression<String>? uuid,
    Expression<String>? kind,
    Expression<String>? categoryId,
    Expression<String>? reversesTransactionId,
    Expression<String>? relatedTransactionId,
    Expression<String>? sourceAccountId,
    Expression<String>? destinationAccountId,
    Expression<String>? refundAccountId,
    Expression<int>? amountMinorUnits,
    Expression<String>? currencyCode,
    Expression<String>? description,
    Expression<String>? notes,
    Expression<String>? paymentChannel,
    Expression<DateTime>? occurredAt,
    Expression<String>? status,
    Expression<String>? source,
    Expression<String>? adjustmentReason,
    Expression<DateTime>? createdAt,
    Expression<DateTime>? updatedAt,
    Expression<int>? syncRevision,
    Expression<String>? syncStatus,
  }) {
    return RawValuesInsertable({
      if (id != null) 'id': id,
      if (uuid != null) 'uuid': uuid,
      if (kind != null) 'kind': kind,
      if (categoryId != null) 'category_id': categoryId,
      if (reversesTransactionId != null)
        'reverses_transaction_id': reversesTransactionId,
      if (relatedTransactionId != null)
        'related_transaction_id': relatedTransactionId,
      if (sourceAccountId != null) 'source_account_id': sourceAccountId,
      if (destinationAccountId != null)
        'destination_account_id': destinationAccountId,
      if (refundAccountId != null) 'refund_account_id': refundAccountId,
      if (amountMinorUnits != null) 'amount_minor_units': amountMinorUnits,
      if (currencyCode != null) 'currency_code': currencyCode,
      if (description != null) 'description': description,
      if (notes != null) 'notes': notes,
      if (paymentChannel != null) 'payment_channel': paymentChannel,
      if (occurredAt != null) 'occurred_at': occurredAt,
      if (status != null) 'status': status,
      if (source != null) 'source': source,
      if (adjustmentReason != null) 'adjustment_reason': adjustmentReason,
      if (createdAt != null) 'created_at': createdAt,
      if (updatedAt != null) 'updated_at': updatedAt,
      if (syncRevision != null) 'sync_revision': syncRevision,
      if (syncStatus != null) 'sync_status': syncStatus,
    });
  }

  FinancialTransactionsCompanion copyWith({
    Value<int>? id,
    Value<String>? uuid,
    Value<String>? kind,
    Value<String?>? categoryId,
    Value<String?>? reversesTransactionId,
    Value<String?>? relatedTransactionId,
    Value<String?>? sourceAccountId,
    Value<String?>? destinationAccountId,
    Value<String?>? refundAccountId,
    Value<int>? amountMinorUnits,
    Value<String>? currencyCode,
    Value<String?>? description,
    Value<String?>? notes,
    Value<String>? paymentChannel,
    Value<DateTime>? occurredAt,
    Value<String>? status,
    Value<String>? source,
    Value<String?>? adjustmentReason,
    Value<DateTime>? createdAt,
    Value<DateTime>? updatedAt,
    Value<int>? syncRevision,
    Value<String>? syncStatus,
  }) {
    return FinancialTransactionsCompanion(
      id: id ?? this.id,
      uuid: uuid ?? this.uuid,
      kind: kind ?? this.kind,
      categoryId: categoryId ?? this.categoryId,
      reversesTransactionId:
          reversesTransactionId ?? this.reversesTransactionId,
      relatedTransactionId: relatedTransactionId ?? this.relatedTransactionId,
      sourceAccountId: sourceAccountId ?? this.sourceAccountId,
      destinationAccountId: destinationAccountId ?? this.destinationAccountId,
      refundAccountId: refundAccountId ?? this.refundAccountId,
      amountMinorUnits: amountMinorUnits ?? this.amountMinorUnits,
      currencyCode: currencyCode ?? this.currencyCode,
      description: description ?? this.description,
      notes: notes ?? this.notes,
      paymentChannel: paymentChannel ?? this.paymentChannel,
      occurredAt: occurredAt ?? this.occurredAt,
      status: status ?? this.status,
      source: source ?? this.source,
      adjustmentReason: adjustmentReason ?? this.adjustmentReason,
      createdAt: createdAt ?? this.createdAt,
      updatedAt: updatedAt ?? this.updatedAt,
      syncRevision: syncRevision ?? this.syncRevision,
      syncStatus: syncStatus ?? this.syncStatus,
    );
  }

  @override
  Map<String, Expression> toColumns(bool nullToAbsent) {
    final map = <String, Expression>{};
    if (id.present) {
      map['id'] = Variable<int>(id.value);
    }
    if (uuid.present) {
      map['uuid'] = Variable<String>(uuid.value);
    }
    if (kind.present) {
      map['kind'] = Variable<String>(kind.value);
    }
    if (categoryId.present) {
      map['category_id'] = Variable<String>(categoryId.value);
    }
    if (reversesTransactionId.present) {
      map['reverses_transaction_id'] = Variable<String>(
        reversesTransactionId.value,
      );
    }
    if (relatedTransactionId.present) {
      map['related_transaction_id'] = Variable<String>(
        relatedTransactionId.value,
      );
    }
    if (sourceAccountId.present) {
      map['source_account_id'] = Variable<String>(sourceAccountId.value);
    }
    if (destinationAccountId.present) {
      map['destination_account_id'] = Variable<String>(
        destinationAccountId.value,
      );
    }
    if (refundAccountId.present) {
      map['refund_account_id'] = Variable<String>(refundAccountId.value);
    }
    if (amountMinorUnits.present) {
      map['amount_minor_units'] = Variable<int>(amountMinorUnits.value);
    }
    if (currencyCode.present) {
      map['currency_code'] = Variable<String>(currencyCode.value);
    }
    if (description.present) {
      map['description'] = Variable<String>(description.value);
    }
    if (notes.present) {
      map['notes'] = Variable<String>(notes.value);
    }
    if (paymentChannel.present) {
      map['payment_channel'] = Variable<String>(paymentChannel.value);
    }
    if (occurredAt.present) {
      map['occurred_at'] = Variable<DateTime>(occurredAt.value);
    }
    if (status.present) {
      map['status'] = Variable<String>(status.value);
    }
    if (source.present) {
      map['source'] = Variable<String>(source.value);
    }
    if (adjustmentReason.present) {
      map['adjustment_reason'] = Variable<String>(adjustmentReason.value);
    }
    if (createdAt.present) {
      map['created_at'] = Variable<DateTime>(createdAt.value);
    }
    if (updatedAt.present) {
      map['updated_at'] = Variable<DateTime>(updatedAt.value);
    }
    if (syncRevision.present) {
      map['sync_revision'] = Variable<int>(syncRevision.value);
    }
    if (syncStatus.present) {
      map['sync_status'] = Variable<String>(syncStatus.value);
    }
    return map;
  }

  @override
  String toString() {
    return (StringBuffer('FinancialTransactionsCompanion(')
          ..write('id: $id, ')
          ..write('uuid: $uuid, ')
          ..write('kind: $kind, ')
          ..write('categoryId: $categoryId, ')
          ..write('reversesTransactionId: $reversesTransactionId, ')
          ..write('relatedTransactionId: $relatedTransactionId, ')
          ..write('sourceAccountId: $sourceAccountId, ')
          ..write('destinationAccountId: $destinationAccountId, ')
          ..write('refundAccountId: $refundAccountId, ')
          ..write('amountMinorUnits: $amountMinorUnits, ')
          ..write('currencyCode: $currencyCode, ')
          ..write('description: $description, ')
          ..write('notes: $notes, ')
          ..write('paymentChannel: $paymentChannel, ')
          ..write('occurredAt: $occurredAt, ')
          ..write('status: $status, ')
          ..write('source: $source, ')
          ..write('adjustmentReason: $adjustmentReason, ')
          ..write('createdAt: $createdAt, ')
          ..write('updatedAt: $updatedAt, ')
          ..write('syncRevision: $syncRevision, ')
          ..write('syncStatus: $syncStatus')
          ..write(')'))
        .toString();
  }
}

class $PostingsTable extends Postings with TableInfo<$PostingsTable, Posting> {
  @override
  final GeneratedDatabase attachedDatabase;
  final String? _alias;
  $PostingsTable(this.attachedDatabase, [this._alias]);
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
  static const VerificationMeta _uuidMeta = const VerificationMeta('uuid');
  @override
  late final GeneratedColumn<String> uuid = GeneratedColumn<String>(
    'uuid',
    aliasedName,
    false,
    type: DriftSqlType.string,
    requiredDuringInsert: true,
    defaultConstraints: GeneratedColumn.constraintIsAlways('UNIQUE'),
  );
  static const VerificationMeta _transactionIdMeta = const VerificationMeta(
    'transactionId',
  );
  @override
  late final GeneratedColumn<int> transactionId = GeneratedColumn<int>(
    'transaction_id',
    aliasedName,
    false,
    type: DriftSqlType.int,
    requiredDuringInsert: true,
    defaultConstraints: GeneratedColumn.constraintIsAlways(
      'REFERENCES financial_transactions (id)',
    ),
  );
  static const VerificationMeta _ledgerAccountIdMeta = const VerificationMeta(
    'ledgerAccountId',
  );
  @override
  late final GeneratedColumn<String> ledgerAccountId = GeneratedColumn<String>(
    'ledger_account_id',
    aliasedName,
    false,
    type: DriftSqlType.string,
    requiredDuringInsert: true,
    defaultConstraints: GeneratedColumn.constraintIsAlways(
      'REFERENCES ledger_accounts (ledger_account_id)',
    ),
  );
  static const VerificationMeta _directionMeta = const VerificationMeta(
    'direction',
  );
  @override
  late final GeneratedColumn<String> direction = GeneratedColumn<String>(
    'direction',
    aliasedName,
    false,
    type: DriftSqlType.string,
    requiredDuringInsert: true,
  );
  static const VerificationMeta _amountMinorUnitsMeta = const VerificationMeta(
    'amountMinorUnits',
  );
  @override
  late final GeneratedColumn<int> amountMinorUnits = GeneratedColumn<int>(
    'amount_minor_units',
    aliasedName,
    false,
    type: DriftSqlType.int,
    requiredDuringInsert: true,
  );
  static const VerificationMeta _currencyCodeMeta = const VerificationMeta(
    'currencyCode',
  );
  @override
  late final GeneratedColumn<String> currencyCode = GeneratedColumn<String>(
    'currency_code',
    aliasedName,
    false,
    type: DriftSqlType.string,
    requiredDuringInsert: false,
    defaultValue: const Constant('INR'),
  );
  static const VerificationMeta _postingDateMeta = const VerificationMeta(
    'postingDate',
  );
  @override
  late final GeneratedColumn<DateTime> postingDate = GeneratedColumn<DateTime>(
    'posting_date',
    aliasedName,
    false,
    type: DriftSqlType.dateTime,
    requiredDuringInsert: true,
  );
  @override
  List<GeneratedColumn> get $columns => [
    id,
    uuid,
    transactionId,
    ledgerAccountId,
    direction,
    amountMinorUnits,
    currencyCode,
    postingDate,
  ];
  @override
  String get aliasedName => _alias ?? actualTableName;
  @override
  String get actualTableName => $name;
  static const String $name = 'postings';
  @override
  VerificationContext validateIntegrity(
    Insertable<Posting> instance, {
    bool isInserting = false,
  }) {
    final context = VerificationContext();
    final data = instance.toColumns(true);
    if (data.containsKey('id')) {
      context.handle(_idMeta, id.isAcceptableOrUnknown(data['id']!, _idMeta));
    }
    if (data.containsKey('uuid')) {
      context.handle(
        _uuidMeta,
        uuid.isAcceptableOrUnknown(data['uuid']!, _uuidMeta),
      );
    } else if (isInserting) {
      context.missing(_uuidMeta);
    }
    if (data.containsKey('transaction_id')) {
      context.handle(
        _transactionIdMeta,
        transactionId.isAcceptableOrUnknown(
          data['transaction_id']!,
          _transactionIdMeta,
        ),
      );
    } else if (isInserting) {
      context.missing(_transactionIdMeta);
    }
    if (data.containsKey('ledger_account_id')) {
      context.handle(
        _ledgerAccountIdMeta,
        ledgerAccountId.isAcceptableOrUnknown(
          data['ledger_account_id']!,
          _ledgerAccountIdMeta,
        ),
      );
    } else if (isInserting) {
      context.missing(_ledgerAccountIdMeta);
    }
    if (data.containsKey('direction')) {
      context.handle(
        _directionMeta,
        direction.isAcceptableOrUnknown(data['direction']!, _directionMeta),
      );
    } else if (isInserting) {
      context.missing(_directionMeta);
    }
    if (data.containsKey('amount_minor_units')) {
      context.handle(
        _amountMinorUnitsMeta,
        amountMinorUnits.isAcceptableOrUnknown(
          data['amount_minor_units']!,
          _amountMinorUnitsMeta,
        ),
      );
    } else if (isInserting) {
      context.missing(_amountMinorUnitsMeta);
    }
    if (data.containsKey('currency_code')) {
      context.handle(
        _currencyCodeMeta,
        currencyCode.isAcceptableOrUnknown(
          data['currency_code']!,
          _currencyCodeMeta,
        ),
      );
    }
    if (data.containsKey('posting_date')) {
      context.handle(
        _postingDateMeta,
        postingDate.isAcceptableOrUnknown(
          data['posting_date']!,
          _postingDateMeta,
        ),
      );
    } else if (isInserting) {
      context.missing(_postingDateMeta);
    }
    return context;
  }

  @override
  Set<GeneratedColumn> get $primaryKey => {id};
  @override
  Posting map(Map<String, dynamic> data, {String? tablePrefix}) {
    final effectivePrefix = tablePrefix != null ? '$tablePrefix.' : '';
    return Posting(
      id: attachedDatabase.typeMapping.read(
        DriftSqlType.int,
        data['${effectivePrefix}id'],
      )!,
      uuid: attachedDatabase.typeMapping.read(
        DriftSqlType.string,
        data['${effectivePrefix}uuid'],
      )!,
      transactionId: attachedDatabase.typeMapping.read(
        DriftSqlType.int,
        data['${effectivePrefix}transaction_id'],
      )!,
      ledgerAccountId: attachedDatabase.typeMapping.read(
        DriftSqlType.string,
        data['${effectivePrefix}ledger_account_id'],
      )!,
      direction: attachedDatabase.typeMapping.read(
        DriftSqlType.string,
        data['${effectivePrefix}direction'],
      )!,
      amountMinorUnits: attachedDatabase.typeMapping.read(
        DriftSqlType.int,
        data['${effectivePrefix}amount_minor_units'],
      )!,
      currencyCode: attachedDatabase.typeMapping.read(
        DriftSqlType.string,
        data['${effectivePrefix}currency_code'],
      )!,
      postingDate: attachedDatabase.typeMapping.read(
        DriftSqlType.dateTime,
        data['${effectivePrefix}posting_date'],
      )!,
    );
  }

  @override
  $PostingsTable createAlias(String alias) {
    return $PostingsTable(attachedDatabase, alias);
  }
}

class Posting extends DataClass implements Insertable<Posting> {
  final int id;
  final String uuid;
  final int transactionId;
  final String ledgerAccountId;

  /// `debit` or `credit`. Distinct values, never a signed amount.
  final String direction;

  /// Always strictly positive; direction carries the sign. Zero-amount
  /// postings are forbidden by the table-level CHECK constraint below
  /// (a column-level `.check(...)` expression would read as a
  /// self-referencing getter to the analyzer).
  final int amountMinorUnits;
  final String currencyCode;

  /// Equals the transaction date in V1.
  final DateTime postingDate;
  const Posting({
    required this.id,
    required this.uuid,
    required this.transactionId,
    required this.ledgerAccountId,
    required this.direction,
    required this.amountMinorUnits,
    required this.currencyCode,
    required this.postingDate,
  });
  @override
  Map<String, Expression> toColumns(bool nullToAbsent) {
    final map = <String, Expression>{};
    map['id'] = Variable<int>(id);
    map['uuid'] = Variable<String>(uuid);
    map['transaction_id'] = Variable<int>(transactionId);
    map['ledger_account_id'] = Variable<String>(ledgerAccountId);
    map['direction'] = Variable<String>(direction);
    map['amount_minor_units'] = Variable<int>(amountMinorUnits);
    map['currency_code'] = Variable<String>(currencyCode);
    map['posting_date'] = Variable<DateTime>(postingDate);
    return map;
  }

  PostingsCompanion toCompanion(bool nullToAbsent) {
    return PostingsCompanion(
      id: Value(id),
      uuid: Value(uuid),
      transactionId: Value(transactionId),
      ledgerAccountId: Value(ledgerAccountId),
      direction: Value(direction),
      amountMinorUnits: Value(amountMinorUnits),
      currencyCode: Value(currencyCode),
      postingDate: Value(postingDate),
    );
  }

  factory Posting.fromJson(
    Map<String, dynamic> json, {
    ValueSerializer? serializer,
  }) {
    serializer ??= driftRuntimeOptions.defaultSerializer;
    return Posting(
      id: serializer.fromJson<int>(json['id']),
      uuid: serializer.fromJson<String>(json['uuid']),
      transactionId: serializer.fromJson<int>(json['transactionId']),
      ledgerAccountId: serializer.fromJson<String>(json['ledgerAccountId']),
      direction: serializer.fromJson<String>(json['direction']),
      amountMinorUnits: serializer.fromJson<int>(json['amountMinorUnits']),
      currencyCode: serializer.fromJson<String>(json['currencyCode']),
      postingDate: serializer.fromJson<DateTime>(json['postingDate']),
    );
  }
  @override
  Map<String, dynamic> toJson({ValueSerializer? serializer}) {
    serializer ??= driftRuntimeOptions.defaultSerializer;
    return <String, dynamic>{
      'id': serializer.toJson<int>(id),
      'uuid': serializer.toJson<String>(uuid),
      'transactionId': serializer.toJson<int>(transactionId),
      'ledgerAccountId': serializer.toJson<String>(ledgerAccountId),
      'direction': serializer.toJson<String>(direction),
      'amountMinorUnits': serializer.toJson<int>(amountMinorUnits),
      'currencyCode': serializer.toJson<String>(currencyCode),
      'postingDate': serializer.toJson<DateTime>(postingDate),
    };
  }

  Posting copyWith({
    int? id,
    String? uuid,
    int? transactionId,
    String? ledgerAccountId,
    String? direction,
    int? amountMinorUnits,
    String? currencyCode,
    DateTime? postingDate,
  }) => Posting(
    id: id ?? this.id,
    uuid: uuid ?? this.uuid,
    transactionId: transactionId ?? this.transactionId,
    ledgerAccountId: ledgerAccountId ?? this.ledgerAccountId,
    direction: direction ?? this.direction,
    amountMinorUnits: amountMinorUnits ?? this.amountMinorUnits,
    currencyCode: currencyCode ?? this.currencyCode,
    postingDate: postingDate ?? this.postingDate,
  );
  Posting copyWithCompanion(PostingsCompanion data) {
    return Posting(
      id: data.id.present ? data.id.value : this.id,
      uuid: data.uuid.present ? data.uuid.value : this.uuid,
      transactionId: data.transactionId.present
          ? data.transactionId.value
          : this.transactionId,
      ledgerAccountId: data.ledgerAccountId.present
          ? data.ledgerAccountId.value
          : this.ledgerAccountId,
      direction: data.direction.present ? data.direction.value : this.direction,
      amountMinorUnits: data.amountMinorUnits.present
          ? data.amountMinorUnits.value
          : this.amountMinorUnits,
      currencyCode: data.currencyCode.present
          ? data.currencyCode.value
          : this.currencyCode,
      postingDate: data.postingDate.present
          ? data.postingDate.value
          : this.postingDate,
    );
  }

  @override
  String toString() {
    return (StringBuffer('Posting(')
          ..write('id: $id, ')
          ..write('uuid: $uuid, ')
          ..write('transactionId: $transactionId, ')
          ..write('ledgerAccountId: $ledgerAccountId, ')
          ..write('direction: $direction, ')
          ..write('amountMinorUnits: $amountMinorUnits, ')
          ..write('currencyCode: $currencyCode, ')
          ..write('postingDate: $postingDate')
          ..write(')'))
        .toString();
  }

  @override
  int get hashCode => Object.hash(
    id,
    uuid,
    transactionId,
    ledgerAccountId,
    direction,
    amountMinorUnits,
    currencyCode,
    postingDate,
  );
  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      (other is Posting &&
          other.id == this.id &&
          other.uuid == this.uuid &&
          other.transactionId == this.transactionId &&
          other.ledgerAccountId == this.ledgerAccountId &&
          other.direction == this.direction &&
          other.amountMinorUnits == this.amountMinorUnits &&
          other.currencyCode == this.currencyCode &&
          other.postingDate == this.postingDate);
}

class PostingsCompanion extends UpdateCompanion<Posting> {
  final Value<int> id;
  final Value<String> uuid;
  final Value<int> transactionId;
  final Value<String> ledgerAccountId;
  final Value<String> direction;
  final Value<int> amountMinorUnits;
  final Value<String> currencyCode;
  final Value<DateTime> postingDate;
  const PostingsCompanion({
    this.id = const Value.absent(),
    this.uuid = const Value.absent(),
    this.transactionId = const Value.absent(),
    this.ledgerAccountId = const Value.absent(),
    this.direction = const Value.absent(),
    this.amountMinorUnits = const Value.absent(),
    this.currencyCode = const Value.absent(),
    this.postingDate = const Value.absent(),
  });
  PostingsCompanion.insert({
    this.id = const Value.absent(),
    required String uuid,
    required int transactionId,
    required String ledgerAccountId,
    required String direction,
    required int amountMinorUnits,
    this.currencyCode = const Value.absent(),
    required DateTime postingDate,
  }) : uuid = Value(uuid),
       transactionId = Value(transactionId),
       ledgerAccountId = Value(ledgerAccountId),
       direction = Value(direction),
       amountMinorUnits = Value(amountMinorUnits),
       postingDate = Value(postingDate);
  static Insertable<Posting> custom({
    Expression<int>? id,
    Expression<String>? uuid,
    Expression<int>? transactionId,
    Expression<String>? ledgerAccountId,
    Expression<String>? direction,
    Expression<int>? amountMinorUnits,
    Expression<String>? currencyCode,
    Expression<DateTime>? postingDate,
  }) {
    return RawValuesInsertable({
      if (id != null) 'id': id,
      if (uuid != null) 'uuid': uuid,
      if (transactionId != null) 'transaction_id': transactionId,
      if (ledgerAccountId != null) 'ledger_account_id': ledgerAccountId,
      if (direction != null) 'direction': direction,
      if (amountMinorUnits != null) 'amount_minor_units': amountMinorUnits,
      if (currencyCode != null) 'currency_code': currencyCode,
      if (postingDate != null) 'posting_date': postingDate,
    });
  }

  PostingsCompanion copyWith({
    Value<int>? id,
    Value<String>? uuid,
    Value<int>? transactionId,
    Value<String>? ledgerAccountId,
    Value<String>? direction,
    Value<int>? amountMinorUnits,
    Value<String>? currencyCode,
    Value<DateTime>? postingDate,
  }) {
    return PostingsCompanion(
      id: id ?? this.id,
      uuid: uuid ?? this.uuid,
      transactionId: transactionId ?? this.transactionId,
      ledgerAccountId: ledgerAccountId ?? this.ledgerAccountId,
      direction: direction ?? this.direction,
      amountMinorUnits: amountMinorUnits ?? this.amountMinorUnits,
      currencyCode: currencyCode ?? this.currencyCode,
      postingDate: postingDate ?? this.postingDate,
    );
  }

  @override
  Map<String, Expression> toColumns(bool nullToAbsent) {
    final map = <String, Expression>{};
    if (id.present) {
      map['id'] = Variable<int>(id.value);
    }
    if (uuid.present) {
      map['uuid'] = Variable<String>(uuid.value);
    }
    if (transactionId.present) {
      map['transaction_id'] = Variable<int>(transactionId.value);
    }
    if (ledgerAccountId.present) {
      map['ledger_account_id'] = Variable<String>(ledgerAccountId.value);
    }
    if (direction.present) {
      map['direction'] = Variable<String>(direction.value);
    }
    if (amountMinorUnits.present) {
      map['amount_minor_units'] = Variable<int>(amountMinorUnits.value);
    }
    if (currencyCode.present) {
      map['currency_code'] = Variable<String>(currencyCode.value);
    }
    if (postingDate.present) {
      map['posting_date'] = Variable<DateTime>(postingDate.value);
    }
    return map;
  }

  @override
  String toString() {
    return (StringBuffer('PostingsCompanion(')
          ..write('id: $id, ')
          ..write('uuid: $uuid, ')
          ..write('transactionId: $transactionId, ')
          ..write('ledgerAccountId: $ledgerAccountId, ')
          ..write('direction: $direction, ')
          ..write('amountMinorUnits: $amountMinorUnits, ')
          ..write('currencyCode: $currencyCode, ')
          ..write('postingDate: $postingDate')
          ..write(')'))
        .toString();
  }
}

class $TransactionHistoryTable extends TransactionHistory
    with TableInfo<$TransactionHistoryTable, TransactionHistoryData> {
  @override
  final GeneratedDatabase attachedDatabase;
  final String? _alias;
  $TransactionHistoryTable(this.attachedDatabase, [this._alias]);
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
  static const VerificationMeta _uuidMeta = const VerificationMeta('uuid');
  @override
  late final GeneratedColumn<String> uuid = GeneratedColumn<String>(
    'uuid',
    aliasedName,
    false,
    type: DriftSqlType.string,
    requiredDuringInsert: true,
    defaultConstraints: GeneratedColumn.constraintIsAlways('UNIQUE'),
  );
  static const VerificationMeta _transactionIdMeta = const VerificationMeta(
    'transactionId',
  );
  @override
  late final GeneratedColumn<int> transactionId = GeneratedColumn<int>(
    'transaction_id',
    aliasedName,
    false,
    type: DriftSqlType.int,
    requiredDuringInsert: true,
    defaultConstraints: GeneratedColumn.constraintIsAlways(
      'REFERENCES financial_transactions (id)',
    ),
  );
  static const VerificationMeta _changedAtMeta = const VerificationMeta(
    'changedAt',
  );
  @override
  late final GeneratedColumn<DateTime> changedAt = GeneratedColumn<DateTime>(
    'changed_at',
    aliasedName,
    false,
    type: DriftSqlType.dateTime,
    requiredDuringInsert: true,
  );
  static const VerificationMeta _changeKindMeta = const VerificationMeta(
    'changeKind',
  );
  @override
  late final GeneratedColumn<String> changeKind = GeneratedColumn<String>(
    'change_kind',
    aliasedName,
    false,
    type: DriftSqlType.string,
    requiredDuringInsert: true,
  );
  static const VerificationMeta _beforeSnapshotMeta = const VerificationMeta(
    'beforeSnapshot',
  );
  @override
  late final GeneratedColumn<String> beforeSnapshot = GeneratedColumn<String>(
    'before_snapshot',
    aliasedName,
    true,
    type: DriftSqlType.string,
    requiredDuringInsert: false,
  );
  static const VerificationMeta _afterSnapshotMeta = const VerificationMeta(
    'afterSnapshot',
  );
  @override
  late final GeneratedColumn<String> afterSnapshot = GeneratedColumn<String>(
    'after_snapshot',
    aliasedName,
    true,
    type: DriftSqlType.string,
    requiredDuringInsert: false,
  );
  @override
  List<GeneratedColumn> get $columns => [
    id,
    uuid,
    transactionId,
    changedAt,
    changeKind,
    beforeSnapshot,
    afterSnapshot,
  ];
  @override
  String get aliasedName => _alias ?? actualTableName;
  @override
  String get actualTableName => $name;
  static const String $name = 'transaction_history';
  @override
  VerificationContext validateIntegrity(
    Insertable<TransactionHistoryData> instance, {
    bool isInserting = false,
  }) {
    final context = VerificationContext();
    final data = instance.toColumns(true);
    if (data.containsKey('id')) {
      context.handle(_idMeta, id.isAcceptableOrUnknown(data['id']!, _idMeta));
    }
    if (data.containsKey('uuid')) {
      context.handle(
        _uuidMeta,
        uuid.isAcceptableOrUnknown(data['uuid']!, _uuidMeta),
      );
    } else if (isInserting) {
      context.missing(_uuidMeta);
    }
    if (data.containsKey('transaction_id')) {
      context.handle(
        _transactionIdMeta,
        transactionId.isAcceptableOrUnknown(
          data['transaction_id']!,
          _transactionIdMeta,
        ),
      );
    } else if (isInserting) {
      context.missing(_transactionIdMeta);
    }
    if (data.containsKey('changed_at')) {
      context.handle(
        _changedAtMeta,
        changedAt.isAcceptableOrUnknown(data['changed_at']!, _changedAtMeta),
      );
    } else if (isInserting) {
      context.missing(_changedAtMeta);
    }
    if (data.containsKey('change_kind')) {
      context.handle(
        _changeKindMeta,
        changeKind.isAcceptableOrUnknown(data['change_kind']!, _changeKindMeta),
      );
    } else if (isInserting) {
      context.missing(_changeKindMeta);
    }
    if (data.containsKey('before_snapshot')) {
      context.handle(
        _beforeSnapshotMeta,
        beforeSnapshot.isAcceptableOrUnknown(
          data['before_snapshot']!,
          _beforeSnapshotMeta,
        ),
      );
    }
    if (data.containsKey('after_snapshot')) {
      context.handle(
        _afterSnapshotMeta,
        afterSnapshot.isAcceptableOrUnknown(
          data['after_snapshot']!,
          _afterSnapshotMeta,
        ),
      );
    }
    return context;
  }

  @override
  Set<GeneratedColumn> get $primaryKey => {id};
  @override
  TransactionHistoryData map(Map<String, dynamic> data, {String? tablePrefix}) {
    final effectivePrefix = tablePrefix != null ? '$tablePrefix.' : '';
    return TransactionHistoryData(
      id: attachedDatabase.typeMapping.read(
        DriftSqlType.int,
        data['${effectivePrefix}id'],
      )!,
      uuid: attachedDatabase.typeMapping.read(
        DriftSqlType.string,
        data['${effectivePrefix}uuid'],
      )!,
      transactionId: attachedDatabase.typeMapping.read(
        DriftSqlType.int,
        data['${effectivePrefix}transaction_id'],
      )!,
      changedAt: attachedDatabase.typeMapping.read(
        DriftSqlType.dateTime,
        data['${effectivePrefix}changed_at'],
      )!,
      changeKind: attachedDatabase.typeMapping.read(
        DriftSqlType.string,
        data['${effectivePrefix}change_kind'],
      )!,
      beforeSnapshot: attachedDatabase.typeMapping.read(
        DriftSqlType.string,
        data['${effectivePrefix}before_snapshot'],
      ),
      afterSnapshot: attachedDatabase.typeMapping.read(
        DriftSqlType.string,
        data['${effectivePrefix}after_snapshot'],
      ),
    );
  }

  @override
  $TransactionHistoryTable createAlias(String alias) {
    return $TransactionHistoryTable(attachedDatabase, alias);
  }
}

class TransactionHistoryData extends DataClass
    implements Insertable<TransactionHistoryData> {
  final int id;
  final String uuid;
  final int transactionId;
  final DateTime changedAt;

  /// `created`, `edited`, `deleted`, `restored`, or
  /// `renamed_category`. Stage 1 seeds no history rows; later stages
  /// write the first four kinds only.
  final String changeKind;
  final String? beforeSnapshot;
  final String? afterSnapshot;
  const TransactionHistoryData({
    required this.id,
    required this.uuid,
    required this.transactionId,
    required this.changedAt,
    required this.changeKind,
    this.beforeSnapshot,
    this.afterSnapshot,
  });
  @override
  Map<String, Expression> toColumns(bool nullToAbsent) {
    final map = <String, Expression>{};
    map['id'] = Variable<int>(id);
    map['uuid'] = Variable<String>(uuid);
    map['transaction_id'] = Variable<int>(transactionId);
    map['changed_at'] = Variable<DateTime>(changedAt);
    map['change_kind'] = Variable<String>(changeKind);
    if (!nullToAbsent || beforeSnapshot != null) {
      map['before_snapshot'] = Variable<String>(beforeSnapshot);
    }
    if (!nullToAbsent || afterSnapshot != null) {
      map['after_snapshot'] = Variable<String>(afterSnapshot);
    }
    return map;
  }

  TransactionHistoryCompanion toCompanion(bool nullToAbsent) {
    return TransactionHistoryCompanion(
      id: Value(id),
      uuid: Value(uuid),
      transactionId: Value(transactionId),
      changedAt: Value(changedAt),
      changeKind: Value(changeKind),
      beforeSnapshot: beforeSnapshot == null && nullToAbsent
          ? const Value.absent()
          : Value(beforeSnapshot),
      afterSnapshot: afterSnapshot == null && nullToAbsent
          ? const Value.absent()
          : Value(afterSnapshot),
    );
  }

  factory TransactionHistoryData.fromJson(
    Map<String, dynamic> json, {
    ValueSerializer? serializer,
  }) {
    serializer ??= driftRuntimeOptions.defaultSerializer;
    return TransactionHistoryData(
      id: serializer.fromJson<int>(json['id']),
      uuid: serializer.fromJson<String>(json['uuid']),
      transactionId: serializer.fromJson<int>(json['transactionId']),
      changedAt: serializer.fromJson<DateTime>(json['changedAt']),
      changeKind: serializer.fromJson<String>(json['changeKind']),
      beforeSnapshot: serializer.fromJson<String?>(json['beforeSnapshot']),
      afterSnapshot: serializer.fromJson<String?>(json['afterSnapshot']),
    );
  }
  @override
  Map<String, dynamic> toJson({ValueSerializer? serializer}) {
    serializer ??= driftRuntimeOptions.defaultSerializer;
    return <String, dynamic>{
      'id': serializer.toJson<int>(id),
      'uuid': serializer.toJson<String>(uuid),
      'transactionId': serializer.toJson<int>(transactionId),
      'changedAt': serializer.toJson<DateTime>(changedAt),
      'changeKind': serializer.toJson<String>(changeKind),
      'beforeSnapshot': serializer.toJson<String?>(beforeSnapshot),
      'afterSnapshot': serializer.toJson<String?>(afterSnapshot),
    };
  }

  TransactionHistoryData copyWith({
    int? id,
    String? uuid,
    int? transactionId,
    DateTime? changedAt,
    String? changeKind,
    Value<String?> beforeSnapshot = const Value.absent(),
    Value<String?> afterSnapshot = const Value.absent(),
  }) => TransactionHistoryData(
    id: id ?? this.id,
    uuid: uuid ?? this.uuid,
    transactionId: transactionId ?? this.transactionId,
    changedAt: changedAt ?? this.changedAt,
    changeKind: changeKind ?? this.changeKind,
    beforeSnapshot: beforeSnapshot.present
        ? beforeSnapshot.value
        : this.beforeSnapshot,
    afterSnapshot: afterSnapshot.present
        ? afterSnapshot.value
        : this.afterSnapshot,
  );
  TransactionHistoryData copyWithCompanion(TransactionHistoryCompanion data) {
    return TransactionHistoryData(
      id: data.id.present ? data.id.value : this.id,
      uuid: data.uuid.present ? data.uuid.value : this.uuid,
      transactionId: data.transactionId.present
          ? data.transactionId.value
          : this.transactionId,
      changedAt: data.changedAt.present ? data.changedAt.value : this.changedAt,
      changeKind: data.changeKind.present
          ? data.changeKind.value
          : this.changeKind,
      beforeSnapshot: data.beforeSnapshot.present
          ? data.beforeSnapshot.value
          : this.beforeSnapshot,
      afterSnapshot: data.afterSnapshot.present
          ? data.afterSnapshot.value
          : this.afterSnapshot,
    );
  }

  @override
  String toString() {
    return (StringBuffer('TransactionHistoryData(')
          ..write('id: $id, ')
          ..write('uuid: $uuid, ')
          ..write('transactionId: $transactionId, ')
          ..write('changedAt: $changedAt, ')
          ..write('changeKind: $changeKind, ')
          ..write('beforeSnapshot: $beforeSnapshot, ')
          ..write('afterSnapshot: $afterSnapshot')
          ..write(')'))
        .toString();
  }

  @override
  int get hashCode => Object.hash(
    id,
    uuid,
    transactionId,
    changedAt,
    changeKind,
    beforeSnapshot,
    afterSnapshot,
  );
  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      (other is TransactionHistoryData &&
          other.id == this.id &&
          other.uuid == this.uuid &&
          other.transactionId == this.transactionId &&
          other.changedAt == this.changedAt &&
          other.changeKind == this.changeKind &&
          other.beforeSnapshot == this.beforeSnapshot &&
          other.afterSnapshot == this.afterSnapshot);
}

class TransactionHistoryCompanion
    extends UpdateCompanion<TransactionHistoryData> {
  final Value<int> id;
  final Value<String> uuid;
  final Value<int> transactionId;
  final Value<DateTime> changedAt;
  final Value<String> changeKind;
  final Value<String?> beforeSnapshot;
  final Value<String?> afterSnapshot;
  const TransactionHistoryCompanion({
    this.id = const Value.absent(),
    this.uuid = const Value.absent(),
    this.transactionId = const Value.absent(),
    this.changedAt = const Value.absent(),
    this.changeKind = const Value.absent(),
    this.beforeSnapshot = const Value.absent(),
    this.afterSnapshot = const Value.absent(),
  });
  TransactionHistoryCompanion.insert({
    this.id = const Value.absent(),
    required String uuid,
    required int transactionId,
    required DateTime changedAt,
    required String changeKind,
    this.beforeSnapshot = const Value.absent(),
    this.afterSnapshot = const Value.absent(),
  }) : uuid = Value(uuid),
       transactionId = Value(transactionId),
       changedAt = Value(changedAt),
       changeKind = Value(changeKind);
  static Insertable<TransactionHistoryData> custom({
    Expression<int>? id,
    Expression<String>? uuid,
    Expression<int>? transactionId,
    Expression<DateTime>? changedAt,
    Expression<String>? changeKind,
    Expression<String>? beforeSnapshot,
    Expression<String>? afterSnapshot,
  }) {
    return RawValuesInsertable({
      if (id != null) 'id': id,
      if (uuid != null) 'uuid': uuid,
      if (transactionId != null) 'transaction_id': transactionId,
      if (changedAt != null) 'changed_at': changedAt,
      if (changeKind != null) 'change_kind': changeKind,
      if (beforeSnapshot != null) 'before_snapshot': beforeSnapshot,
      if (afterSnapshot != null) 'after_snapshot': afterSnapshot,
    });
  }

  TransactionHistoryCompanion copyWith({
    Value<int>? id,
    Value<String>? uuid,
    Value<int>? transactionId,
    Value<DateTime>? changedAt,
    Value<String>? changeKind,
    Value<String?>? beforeSnapshot,
    Value<String?>? afterSnapshot,
  }) {
    return TransactionHistoryCompanion(
      id: id ?? this.id,
      uuid: uuid ?? this.uuid,
      transactionId: transactionId ?? this.transactionId,
      changedAt: changedAt ?? this.changedAt,
      changeKind: changeKind ?? this.changeKind,
      beforeSnapshot: beforeSnapshot ?? this.beforeSnapshot,
      afterSnapshot: afterSnapshot ?? this.afterSnapshot,
    );
  }

  @override
  Map<String, Expression> toColumns(bool nullToAbsent) {
    final map = <String, Expression>{};
    if (id.present) {
      map['id'] = Variable<int>(id.value);
    }
    if (uuid.present) {
      map['uuid'] = Variable<String>(uuid.value);
    }
    if (transactionId.present) {
      map['transaction_id'] = Variable<int>(transactionId.value);
    }
    if (changedAt.present) {
      map['changed_at'] = Variable<DateTime>(changedAt.value);
    }
    if (changeKind.present) {
      map['change_kind'] = Variable<String>(changeKind.value);
    }
    if (beforeSnapshot.present) {
      map['before_snapshot'] = Variable<String>(beforeSnapshot.value);
    }
    if (afterSnapshot.present) {
      map['after_snapshot'] = Variable<String>(afterSnapshot.value);
    }
    return map;
  }

  @override
  String toString() {
    return (StringBuffer('TransactionHistoryCompanion(')
          ..write('id: $id, ')
          ..write('uuid: $uuid, ')
          ..write('transactionId: $transactionId, ')
          ..write('changedAt: $changedAt, ')
          ..write('changeKind: $changeKind, ')
          ..write('beforeSnapshot: $beforeSnapshot, ')
          ..write('afterSnapshot: $afterSnapshot')
          ..write(')'))
        .toString();
  }
}

class $AppSettingsTable extends AppSettings
    with TableInfo<$AppSettingsTable, AppSetting> {
  @override
  final GeneratedDatabase attachedDatabase;
  final String? _alias;
  $AppSettingsTable(this.attachedDatabase, [this._alias]);
  static const VerificationMeta _idMeta = const VerificationMeta('id');
  @override
  late final GeneratedColumn<int> id = GeneratedColumn<int>(
    'id',
    aliasedName,
    false,
    type: DriftSqlType.int,
    requiredDuringInsert: false,
  );
  static const VerificationMeta _currencyCodeMeta = const VerificationMeta(
    'currencyCode',
  );
  @override
  late final GeneratedColumn<String> currencyCode = GeneratedColumn<String>(
    'currency_code',
    aliasedName,
    false,
    type: DriftSqlType.string,
    requiredDuringInsert: false,
    defaultValue: const Constant('INR'),
  );
  static const VerificationMeta _defaultAccountIdMeta = const VerificationMeta(
    'defaultAccountId',
  );
  @override
  late final GeneratedColumn<String> defaultAccountId = GeneratedColumn<String>(
    'default_account_id',
    aliasedName,
    true,
    type: DriftSqlType.string,
    requiredDuringInsert: false,
    defaultConstraints: GeneratedColumn.constraintIsAlways(
      'REFERENCES accounts (uuid)',
    ),
  );
  static const VerificationMeta _themeModeMeta = const VerificationMeta(
    'themeMode',
  );
  @override
  late final GeneratedColumn<String> themeMode = GeneratedColumn<String>(
    'theme_mode',
    aliasedName,
    false,
    type: DriftSqlType.string,
    requiredDuringInsert: false,
    defaultValue: const Constant('system'),
  );
  static const VerificationMeta _appLockEnabledMeta = const VerificationMeta(
    'appLockEnabled',
  );
  @override
  late final GeneratedColumn<bool> appLockEnabled = GeneratedColumn<bool>(
    'app_lock_enabled',
    aliasedName,
    false,
    type: DriftSqlType.bool,
    requiredDuringInsert: false,
    defaultConstraints: GeneratedColumn.constraintIsAlways(
      'CHECK ("app_lock_enabled" IN (0, 1))',
    ),
    defaultValue: const Constant(false),
  );
  static const VerificationMeta _documentRetentionDaysMeta =
      const VerificationMeta('documentRetentionDays');
  @override
  late final GeneratedColumn<int> documentRetentionDays = GeneratedColumn<int>(
    'document_retention_days',
    aliasedName,
    true,
    type: DriftSqlType.int,
    requiredDuringInsert: false,
  );
  static const VerificationMeta _defaultReminderDaysMeta =
      const VerificationMeta('defaultReminderDays');
  @override
  late final GeneratedColumn<int> defaultReminderDays = GeneratedColumn<int>(
    'default_reminder_days',
    aliasedName,
    false,
    type: DriftSqlType.int,
    requiredDuringInsert: false,
    defaultValue: const Constant(1),
  );
  static const VerificationMeta _sheetsBackupEnabledMeta =
      const VerificationMeta('sheetsBackupEnabled');
  @override
  late final GeneratedColumn<bool> sheetsBackupEnabled = GeneratedColumn<bool>(
    'sheets_backup_enabled',
    aliasedName,
    false,
    type: DriftSqlType.bool,
    requiredDuringInsert: false,
    defaultConstraints: GeneratedColumn.constraintIsAlways(
      'CHECK ("sheets_backup_enabled" IN (0, 1))',
    ),
    defaultValue: const Constant(true),
  );
  static const VerificationMeta _setupCompletedMeta = const VerificationMeta(
    'setupCompleted',
  );
  @override
  late final GeneratedColumn<bool> setupCompleted = GeneratedColumn<bool>(
    'setup_completed',
    aliasedName,
    false,
    type: DriftSqlType.bool,
    requiredDuringInsert: false,
    defaultConstraints: GeneratedColumn.constraintIsAlways(
      'CHECK ("setup_completed" IN (0, 1))',
    ),
    defaultValue: const Constant(false),
  );
  @override
  List<GeneratedColumn> get $columns => [
    id,
    currencyCode,
    defaultAccountId,
    themeMode,
    appLockEnabled,
    documentRetentionDays,
    defaultReminderDays,
    sheetsBackupEnabled,
    setupCompleted,
  ];
  @override
  String get aliasedName => _alias ?? actualTableName;
  @override
  String get actualTableName => $name;
  static const String $name = 'app_settings';
  @override
  VerificationContext validateIntegrity(
    Insertable<AppSetting> instance, {
    bool isInserting = false,
  }) {
    final context = VerificationContext();
    final data = instance.toColumns(true);
    if (data.containsKey('id')) {
      context.handle(_idMeta, id.isAcceptableOrUnknown(data['id']!, _idMeta));
    }
    if (data.containsKey('currency_code')) {
      context.handle(
        _currencyCodeMeta,
        currencyCode.isAcceptableOrUnknown(
          data['currency_code']!,
          _currencyCodeMeta,
        ),
      );
    }
    if (data.containsKey('default_account_id')) {
      context.handle(
        _defaultAccountIdMeta,
        defaultAccountId.isAcceptableOrUnknown(
          data['default_account_id']!,
          _defaultAccountIdMeta,
        ),
      );
    }
    if (data.containsKey('theme_mode')) {
      context.handle(
        _themeModeMeta,
        themeMode.isAcceptableOrUnknown(data['theme_mode']!, _themeModeMeta),
      );
    }
    if (data.containsKey('app_lock_enabled')) {
      context.handle(
        _appLockEnabledMeta,
        appLockEnabled.isAcceptableOrUnknown(
          data['app_lock_enabled']!,
          _appLockEnabledMeta,
        ),
      );
    }
    if (data.containsKey('document_retention_days')) {
      context.handle(
        _documentRetentionDaysMeta,
        documentRetentionDays.isAcceptableOrUnknown(
          data['document_retention_days']!,
          _documentRetentionDaysMeta,
        ),
      );
    }
    if (data.containsKey('default_reminder_days')) {
      context.handle(
        _defaultReminderDaysMeta,
        defaultReminderDays.isAcceptableOrUnknown(
          data['default_reminder_days']!,
          _defaultReminderDaysMeta,
        ),
      );
    }
    if (data.containsKey('sheets_backup_enabled')) {
      context.handle(
        _sheetsBackupEnabledMeta,
        sheetsBackupEnabled.isAcceptableOrUnknown(
          data['sheets_backup_enabled']!,
          _sheetsBackupEnabledMeta,
        ),
      );
    }
    if (data.containsKey('setup_completed')) {
      context.handle(
        _setupCompletedMeta,
        setupCompleted.isAcceptableOrUnknown(
          data['setup_completed']!,
          _setupCompletedMeta,
        ),
      );
    }
    return context;
  }

  @override
  Set<GeneratedColumn> get $primaryKey => {id};
  @override
  AppSetting map(Map<String, dynamic> data, {String? tablePrefix}) {
    final effectivePrefix = tablePrefix != null ? '$tablePrefix.' : '';
    return AppSetting(
      id: attachedDatabase.typeMapping.read(
        DriftSqlType.int,
        data['${effectivePrefix}id'],
      )!,
      currencyCode: attachedDatabase.typeMapping.read(
        DriftSqlType.string,
        data['${effectivePrefix}currency_code'],
      )!,
      defaultAccountId: attachedDatabase.typeMapping.read(
        DriftSqlType.string,
        data['${effectivePrefix}default_account_id'],
      ),
      themeMode: attachedDatabase.typeMapping.read(
        DriftSqlType.string,
        data['${effectivePrefix}theme_mode'],
      )!,
      appLockEnabled: attachedDatabase.typeMapping.read(
        DriftSqlType.bool,
        data['${effectivePrefix}app_lock_enabled'],
      )!,
      documentRetentionDays: attachedDatabase.typeMapping.read(
        DriftSqlType.int,
        data['${effectivePrefix}document_retention_days'],
      ),
      defaultReminderDays: attachedDatabase.typeMapping.read(
        DriftSqlType.int,
        data['${effectivePrefix}default_reminder_days'],
      )!,
      sheetsBackupEnabled: attachedDatabase.typeMapping.read(
        DriftSqlType.bool,
        data['${effectivePrefix}sheets_backup_enabled'],
      )!,
      setupCompleted: attachedDatabase.typeMapping.read(
        DriftSqlType.bool,
        data['${effectivePrefix}setup_completed'],
      )!,
    );
  }

  @override
  $AppSettingsTable createAlias(String alias) {
    return $AppSettingsTable(attachedDatabase, alias);
  }
}

class AppSetting extends DataClass implements Insertable<AppSetting> {
  final int id;
  final String currencyCode;

  /// Optional default account. At most one default account, and none
  /// is valid. Must never be used as a fallback account for a
  /// transaction, posting, or Sheets row (later stages).
  final String? defaultAccountId;

  /// `system`, `light`, or `dark`. Mirrors the current system
  /// behaviour; a user choice is added in Module 12.
  final String themeMode;
  final bool appLockEnabled;

  /// Days originals are retained. Null until the Module 7 retention
  /// default is decided.
  final int? documentRetentionDays;
  final int defaultReminderDays;

  /// Preference default only (approved Stage 1 seed default: true).
  /// Sheets sync remains gated by explicit Google authentication and
  /// authorisation; this flag never bypasses consent and no sync runs
  /// from seeding. No reminder scheduling or app-lock functionality
  /// is implied by any field in this table.
  final bool sheetsBackupEnabled;
  final bool setupCompleted;
  const AppSetting({
    required this.id,
    required this.currencyCode,
    this.defaultAccountId,
    required this.themeMode,
    required this.appLockEnabled,
    this.documentRetentionDays,
    required this.defaultReminderDays,
    required this.sheetsBackupEnabled,
    required this.setupCompleted,
  });
  @override
  Map<String, Expression> toColumns(bool nullToAbsent) {
    final map = <String, Expression>{};
    map['id'] = Variable<int>(id);
    map['currency_code'] = Variable<String>(currencyCode);
    if (!nullToAbsent || defaultAccountId != null) {
      map['default_account_id'] = Variable<String>(defaultAccountId);
    }
    map['theme_mode'] = Variable<String>(themeMode);
    map['app_lock_enabled'] = Variable<bool>(appLockEnabled);
    if (!nullToAbsent || documentRetentionDays != null) {
      map['document_retention_days'] = Variable<int>(documentRetentionDays);
    }
    map['default_reminder_days'] = Variable<int>(defaultReminderDays);
    map['sheets_backup_enabled'] = Variable<bool>(sheetsBackupEnabled);
    map['setup_completed'] = Variable<bool>(setupCompleted);
    return map;
  }

  AppSettingsCompanion toCompanion(bool nullToAbsent) {
    return AppSettingsCompanion(
      id: Value(id),
      currencyCode: Value(currencyCode),
      defaultAccountId: defaultAccountId == null && nullToAbsent
          ? const Value.absent()
          : Value(defaultAccountId),
      themeMode: Value(themeMode),
      appLockEnabled: Value(appLockEnabled),
      documentRetentionDays: documentRetentionDays == null && nullToAbsent
          ? const Value.absent()
          : Value(documentRetentionDays),
      defaultReminderDays: Value(defaultReminderDays),
      sheetsBackupEnabled: Value(sheetsBackupEnabled),
      setupCompleted: Value(setupCompleted),
    );
  }

  factory AppSetting.fromJson(
    Map<String, dynamic> json, {
    ValueSerializer? serializer,
  }) {
    serializer ??= driftRuntimeOptions.defaultSerializer;
    return AppSetting(
      id: serializer.fromJson<int>(json['id']),
      currencyCode: serializer.fromJson<String>(json['currencyCode']),
      defaultAccountId: serializer.fromJson<String?>(json['defaultAccountId']),
      themeMode: serializer.fromJson<String>(json['themeMode']),
      appLockEnabled: serializer.fromJson<bool>(json['appLockEnabled']),
      documentRetentionDays: serializer.fromJson<int?>(
        json['documentRetentionDays'],
      ),
      defaultReminderDays: serializer.fromJson<int>(
        json['defaultReminderDays'],
      ),
      sheetsBackupEnabled: serializer.fromJson<bool>(
        json['sheetsBackupEnabled'],
      ),
      setupCompleted: serializer.fromJson<bool>(json['setupCompleted']),
    );
  }
  @override
  Map<String, dynamic> toJson({ValueSerializer? serializer}) {
    serializer ??= driftRuntimeOptions.defaultSerializer;
    return <String, dynamic>{
      'id': serializer.toJson<int>(id),
      'currencyCode': serializer.toJson<String>(currencyCode),
      'defaultAccountId': serializer.toJson<String?>(defaultAccountId),
      'themeMode': serializer.toJson<String>(themeMode),
      'appLockEnabled': serializer.toJson<bool>(appLockEnabled),
      'documentRetentionDays': serializer.toJson<int?>(documentRetentionDays),
      'defaultReminderDays': serializer.toJson<int>(defaultReminderDays),
      'sheetsBackupEnabled': serializer.toJson<bool>(sheetsBackupEnabled),
      'setupCompleted': serializer.toJson<bool>(setupCompleted),
    };
  }

  AppSetting copyWith({
    int? id,
    String? currencyCode,
    Value<String?> defaultAccountId = const Value.absent(),
    String? themeMode,
    bool? appLockEnabled,
    Value<int?> documentRetentionDays = const Value.absent(),
    int? defaultReminderDays,
    bool? sheetsBackupEnabled,
    bool? setupCompleted,
  }) => AppSetting(
    id: id ?? this.id,
    currencyCode: currencyCode ?? this.currencyCode,
    defaultAccountId: defaultAccountId.present
        ? defaultAccountId.value
        : this.defaultAccountId,
    themeMode: themeMode ?? this.themeMode,
    appLockEnabled: appLockEnabled ?? this.appLockEnabled,
    documentRetentionDays: documentRetentionDays.present
        ? documentRetentionDays.value
        : this.documentRetentionDays,
    defaultReminderDays: defaultReminderDays ?? this.defaultReminderDays,
    sheetsBackupEnabled: sheetsBackupEnabled ?? this.sheetsBackupEnabled,
    setupCompleted: setupCompleted ?? this.setupCompleted,
  );
  AppSetting copyWithCompanion(AppSettingsCompanion data) {
    return AppSetting(
      id: data.id.present ? data.id.value : this.id,
      currencyCode: data.currencyCode.present
          ? data.currencyCode.value
          : this.currencyCode,
      defaultAccountId: data.defaultAccountId.present
          ? data.defaultAccountId.value
          : this.defaultAccountId,
      themeMode: data.themeMode.present ? data.themeMode.value : this.themeMode,
      appLockEnabled: data.appLockEnabled.present
          ? data.appLockEnabled.value
          : this.appLockEnabled,
      documentRetentionDays: data.documentRetentionDays.present
          ? data.documentRetentionDays.value
          : this.documentRetentionDays,
      defaultReminderDays: data.defaultReminderDays.present
          ? data.defaultReminderDays.value
          : this.defaultReminderDays,
      sheetsBackupEnabled: data.sheetsBackupEnabled.present
          ? data.sheetsBackupEnabled.value
          : this.sheetsBackupEnabled,
      setupCompleted: data.setupCompleted.present
          ? data.setupCompleted.value
          : this.setupCompleted,
    );
  }

  @override
  String toString() {
    return (StringBuffer('AppSetting(')
          ..write('id: $id, ')
          ..write('currencyCode: $currencyCode, ')
          ..write('defaultAccountId: $defaultAccountId, ')
          ..write('themeMode: $themeMode, ')
          ..write('appLockEnabled: $appLockEnabled, ')
          ..write('documentRetentionDays: $documentRetentionDays, ')
          ..write('defaultReminderDays: $defaultReminderDays, ')
          ..write('sheetsBackupEnabled: $sheetsBackupEnabled, ')
          ..write('setupCompleted: $setupCompleted')
          ..write(')'))
        .toString();
  }

  @override
  int get hashCode => Object.hash(
    id,
    currencyCode,
    defaultAccountId,
    themeMode,
    appLockEnabled,
    documentRetentionDays,
    defaultReminderDays,
    sheetsBackupEnabled,
    setupCompleted,
  );
  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      (other is AppSetting &&
          other.id == this.id &&
          other.currencyCode == this.currencyCode &&
          other.defaultAccountId == this.defaultAccountId &&
          other.themeMode == this.themeMode &&
          other.appLockEnabled == this.appLockEnabled &&
          other.documentRetentionDays == this.documentRetentionDays &&
          other.defaultReminderDays == this.defaultReminderDays &&
          other.sheetsBackupEnabled == this.sheetsBackupEnabled &&
          other.setupCompleted == this.setupCompleted);
}

class AppSettingsCompanion extends UpdateCompanion<AppSetting> {
  final Value<int> id;
  final Value<String> currencyCode;
  final Value<String?> defaultAccountId;
  final Value<String> themeMode;
  final Value<bool> appLockEnabled;
  final Value<int?> documentRetentionDays;
  final Value<int> defaultReminderDays;
  final Value<bool> sheetsBackupEnabled;
  final Value<bool> setupCompleted;
  const AppSettingsCompanion({
    this.id = const Value.absent(),
    this.currencyCode = const Value.absent(),
    this.defaultAccountId = const Value.absent(),
    this.themeMode = const Value.absent(),
    this.appLockEnabled = const Value.absent(),
    this.documentRetentionDays = const Value.absent(),
    this.defaultReminderDays = const Value.absent(),
    this.sheetsBackupEnabled = const Value.absent(),
    this.setupCompleted = const Value.absent(),
  });
  AppSettingsCompanion.insert({
    this.id = const Value.absent(),
    this.currencyCode = const Value.absent(),
    this.defaultAccountId = const Value.absent(),
    this.themeMode = const Value.absent(),
    this.appLockEnabled = const Value.absent(),
    this.documentRetentionDays = const Value.absent(),
    this.defaultReminderDays = const Value.absent(),
    this.sheetsBackupEnabled = const Value.absent(),
    this.setupCompleted = const Value.absent(),
  });
  static Insertable<AppSetting> custom({
    Expression<int>? id,
    Expression<String>? currencyCode,
    Expression<String>? defaultAccountId,
    Expression<String>? themeMode,
    Expression<bool>? appLockEnabled,
    Expression<int>? documentRetentionDays,
    Expression<int>? defaultReminderDays,
    Expression<bool>? sheetsBackupEnabled,
    Expression<bool>? setupCompleted,
  }) {
    return RawValuesInsertable({
      if (id != null) 'id': id,
      if (currencyCode != null) 'currency_code': currencyCode,
      if (defaultAccountId != null) 'default_account_id': defaultAccountId,
      if (themeMode != null) 'theme_mode': themeMode,
      if (appLockEnabled != null) 'app_lock_enabled': appLockEnabled,
      if (documentRetentionDays != null)
        'document_retention_days': documentRetentionDays,
      if (defaultReminderDays != null)
        'default_reminder_days': defaultReminderDays,
      if (sheetsBackupEnabled != null)
        'sheets_backup_enabled': sheetsBackupEnabled,
      if (setupCompleted != null) 'setup_completed': setupCompleted,
    });
  }

  AppSettingsCompanion copyWith({
    Value<int>? id,
    Value<String>? currencyCode,
    Value<String?>? defaultAccountId,
    Value<String>? themeMode,
    Value<bool>? appLockEnabled,
    Value<int?>? documentRetentionDays,
    Value<int>? defaultReminderDays,
    Value<bool>? sheetsBackupEnabled,
    Value<bool>? setupCompleted,
  }) {
    return AppSettingsCompanion(
      id: id ?? this.id,
      currencyCode: currencyCode ?? this.currencyCode,
      defaultAccountId: defaultAccountId ?? this.defaultAccountId,
      themeMode: themeMode ?? this.themeMode,
      appLockEnabled: appLockEnabled ?? this.appLockEnabled,
      documentRetentionDays:
          documentRetentionDays ?? this.documentRetentionDays,
      defaultReminderDays: defaultReminderDays ?? this.defaultReminderDays,
      sheetsBackupEnabled: sheetsBackupEnabled ?? this.sheetsBackupEnabled,
      setupCompleted: setupCompleted ?? this.setupCompleted,
    );
  }

  @override
  Map<String, Expression> toColumns(bool nullToAbsent) {
    final map = <String, Expression>{};
    if (id.present) {
      map['id'] = Variable<int>(id.value);
    }
    if (currencyCode.present) {
      map['currency_code'] = Variable<String>(currencyCode.value);
    }
    if (defaultAccountId.present) {
      map['default_account_id'] = Variable<String>(defaultAccountId.value);
    }
    if (themeMode.present) {
      map['theme_mode'] = Variable<String>(themeMode.value);
    }
    if (appLockEnabled.present) {
      map['app_lock_enabled'] = Variable<bool>(appLockEnabled.value);
    }
    if (documentRetentionDays.present) {
      map['document_retention_days'] = Variable<int>(
        documentRetentionDays.value,
      );
    }
    if (defaultReminderDays.present) {
      map['default_reminder_days'] = Variable<int>(defaultReminderDays.value);
    }
    if (sheetsBackupEnabled.present) {
      map['sheets_backup_enabled'] = Variable<bool>(sheetsBackupEnabled.value);
    }
    if (setupCompleted.present) {
      map['setup_completed'] = Variable<bool>(setupCompleted.value);
    }
    return map;
  }

  @override
  String toString() {
    return (StringBuffer('AppSettingsCompanion(')
          ..write('id: $id, ')
          ..write('currencyCode: $currencyCode, ')
          ..write('defaultAccountId: $defaultAccountId, ')
          ..write('themeMode: $themeMode, ')
          ..write('appLockEnabled: $appLockEnabled, ')
          ..write('documentRetentionDays: $documentRetentionDays, ')
          ..write('defaultReminderDays: $defaultReminderDays, ')
          ..write('sheetsBackupEnabled: $sheetsBackupEnabled, ')
          ..write('setupCompleted: $setupCompleted')
          ..write(')'))
        .toString();
  }
}

class $NotificationsTable extends Notifications
    with TableInfo<$NotificationsTable, Notification> {
  @override
  final GeneratedDatabase attachedDatabase;
  final String? _alias;
  $NotificationsTable(this.attachedDatabase, [this._alias]);
  static const VerificationMeta _idMeta = const VerificationMeta('id');
  @override
  late final GeneratedColumn<String> id = GeneratedColumn<String>(
    'id',
    aliasedName,
    false,
    type: DriftSqlType.string,
    requiredDuringInsert: true,
  );
  static const VerificationMeta _typeMeta = const VerificationMeta('type');
  @override
  late final GeneratedColumn<String> type = GeneratedColumn<String>(
    'type',
    aliasedName,
    false,
    type: DriftSqlType.string,
    requiredDuringInsert: true,
  );
  static const VerificationMeta _titleMeta = const VerificationMeta('title');
  @override
  late final GeneratedColumn<String> title = GeneratedColumn<String>(
    'title',
    aliasedName,
    false,
    type: DriftSqlType.string,
    requiredDuringInsert: true,
  );
  static const VerificationMeta _messageMeta = const VerificationMeta(
    'message',
  );
  @override
  late final GeneratedColumn<String> message = GeneratedColumn<String>(
    'message',
    aliasedName,
    false,
    type: DriftSqlType.string,
    requiredDuringInsert: true,
  );
  static const VerificationMeta _createdAtMeta = const VerificationMeta(
    'createdAt',
  );
  @override
  late final GeneratedColumn<DateTime> createdAt = GeneratedColumn<DateTime>(
    'created_at',
    aliasedName,
    false,
    type: DriftSqlType.dateTime,
    requiredDuringInsert: true,
  );
  static const VerificationMeta _isReadMeta = const VerificationMeta('isRead');
  @override
  late final GeneratedColumn<bool> isRead = GeneratedColumn<bool>(
    'is_read',
    aliasedName,
    false,
    type: DriftSqlType.bool,
    requiredDuringInsert: false,
    defaultConstraints: GeneratedColumn.constraintIsAlways(
      'CHECK ("is_read" IN (0, 1))',
    ),
    defaultValue: const Constant(false),
  );
  @override
  List<GeneratedColumn> get $columns => [
    id,
    type,
    title,
    message,
    createdAt,
    isRead,
  ];
  @override
  String get aliasedName => _alias ?? actualTableName;
  @override
  String get actualTableName => $name;
  static const String $name = 'notifications';
  @override
  VerificationContext validateIntegrity(
    Insertable<Notification> instance, {
    bool isInserting = false,
  }) {
    final context = VerificationContext();
    final data = instance.toColumns(true);
    if (data.containsKey('id')) {
      context.handle(_idMeta, id.isAcceptableOrUnknown(data['id']!, _idMeta));
    } else if (isInserting) {
      context.missing(_idMeta);
    }
    if (data.containsKey('type')) {
      context.handle(
        _typeMeta,
        type.isAcceptableOrUnknown(data['type']!, _typeMeta),
      );
    } else if (isInserting) {
      context.missing(_typeMeta);
    }
    if (data.containsKey('title')) {
      context.handle(
        _titleMeta,
        title.isAcceptableOrUnknown(data['title']!, _titleMeta),
      );
    } else if (isInserting) {
      context.missing(_titleMeta);
    }
    if (data.containsKey('message')) {
      context.handle(
        _messageMeta,
        message.isAcceptableOrUnknown(data['message']!, _messageMeta),
      );
    } else if (isInserting) {
      context.missing(_messageMeta);
    }
    if (data.containsKey('created_at')) {
      context.handle(
        _createdAtMeta,
        createdAt.isAcceptableOrUnknown(data['created_at']!, _createdAtMeta),
      );
    } else if (isInserting) {
      context.missing(_createdAtMeta);
    }
    if (data.containsKey('is_read')) {
      context.handle(
        _isReadMeta,
        isRead.isAcceptableOrUnknown(data['is_read']!, _isReadMeta),
      );
    }
    return context;
  }

  @override
  Set<GeneratedColumn> get $primaryKey => {id};
  @override
  Notification map(Map<String, dynamic> data, {String? tablePrefix}) {
    final effectivePrefix = tablePrefix != null ? '$tablePrefix.' : '';
    return Notification(
      id: attachedDatabase.typeMapping.read(
        DriftSqlType.string,
        data['${effectivePrefix}id'],
      )!,
      type: attachedDatabase.typeMapping.read(
        DriftSqlType.string,
        data['${effectivePrefix}type'],
      )!,
      title: attachedDatabase.typeMapping.read(
        DriftSqlType.string,
        data['${effectivePrefix}title'],
      )!,
      message: attachedDatabase.typeMapping.read(
        DriftSqlType.string,
        data['${effectivePrefix}message'],
      )!,
      createdAt: attachedDatabase.typeMapping.read(
        DriftSqlType.dateTime,
        data['${effectivePrefix}created_at'],
      )!,
      isRead: attachedDatabase.typeMapping.read(
        DriftSqlType.bool,
        data['${effectivePrefix}is_read'],
      )!,
    );
  }

  @override
  $NotificationsTable createAlias(String alias) {
    return $NotificationsTable(attachedDatabase, alias);
  }
}

class Notification extends DataClass implements Insertable<Notification> {
  final String id;
  final String type;
  final String title;
  final String message;
  final DateTime createdAt;
  final bool isRead;
  const Notification({
    required this.id,
    required this.type,
    required this.title,
    required this.message,
    required this.createdAt,
    required this.isRead,
  });
  @override
  Map<String, Expression> toColumns(bool nullToAbsent) {
    final map = <String, Expression>{};
    map['id'] = Variable<String>(id);
    map['type'] = Variable<String>(type);
    map['title'] = Variable<String>(title);
    map['message'] = Variable<String>(message);
    map['created_at'] = Variable<DateTime>(createdAt);
    map['is_read'] = Variable<bool>(isRead);
    return map;
  }

  NotificationsCompanion toCompanion(bool nullToAbsent) {
    return NotificationsCompanion(
      id: Value(id),
      type: Value(type),
      title: Value(title),
      message: Value(message),
      createdAt: Value(createdAt),
      isRead: Value(isRead),
    );
  }

  factory Notification.fromJson(
    Map<String, dynamic> json, {
    ValueSerializer? serializer,
  }) {
    serializer ??= driftRuntimeOptions.defaultSerializer;
    return Notification(
      id: serializer.fromJson<String>(json['id']),
      type: serializer.fromJson<String>(json['type']),
      title: serializer.fromJson<String>(json['title']),
      message: serializer.fromJson<String>(json['message']),
      createdAt: serializer.fromJson<DateTime>(json['createdAt']),
      isRead: serializer.fromJson<bool>(json['isRead']),
    );
  }
  @override
  Map<String, dynamic> toJson({ValueSerializer? serializer}) {
    serializer ??= driftRuntimeOptions.defaultSerializer;
    return <String, dynamic>{
      'id': serializer.toJson<String>(id),
      'type': serializer.toJson<String>(type),
      'title': serializer.toJson<String>(title),
      'message': serializer.toJson<String>(message),
      'createdAt': serializer.toJson<DateTime>(createdAt),
      'isRead': serializer.toJson<bool>(isRead),
    };
  }

  Notification copyWith({
    String? id,
    String? type,
    String? title,
    String? message,
    DateTime? createdAt,
    bool? isRead,
  }) => Notification(
    id: id ?? this.id,
    type: type ?? this.type,
    title: title ?? this.title,
    message: message ?? this.message,
    createdAt: createdAt ?? this.createdAt,
    isRead: isRead ?? this.isRead,
  );
  Notification copyWithCompanion(NotificationsCompanion data) {
    return Notification(
      id: data.id.present ? data.id.value : this.id,
      type: data.type.present ? data.type.value : this.type,
      title: data.title.present ? data.title.value : this.title,
      message: data.message.present ? data.message.value : this.message,
      createdAt: data.createdAt.present ? data.createdAt.value : this.createdAt,
      isRead: data.isRead.present ? data.isRead.value : this.isRead,
    );
  }

  @override
  String toString() {
    return (StringBuffer('Notification(')
          ..write('id: $id, ')
          ..write('type: $type, ')
          ..write('title: $title, ')
          ..write('message: $message, ')
          ..write('createdAt: $createdAt, ')
          ..write('isRead: $isRead')
          ..write(')'))
        .toString();
  }

  @override
  int get hashCode => Object.hash(id, type, title, message, createdAt, isRead);
  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      (other is Notification &&
          other.id == this.id &&
          other.type == this.type &&
          other.title == this.title &&
          other.message == this.message &&
          other.createdAt == this.createdAt &&
          other.isRead == this.isRead);
}

class NotificationsCompanion extends UpdateCompanion<Notification> {
  final Value<String> id;
  final Value<String> type;
  final Value<String> title;
  final Value<String> message;
  final Value<DateTime> createdAt;
  final Value<bool> isRead;
  final Value<int> rowid;
  const NotificationsCompanion({
    this.id = const Value.absent(),
    this.type = const Value.absent(),
    this.title = const Value.absent(),
    this.message = const Value.absent(),
    this.createdAt = const Value.absent(),
    this.isRead = const Value.absent(),
    this.rowid = const Value.absent(),
  });
  NotificationsCompanion.insert({
    required String id,
    required String type,
    required String title,
    required String message,
    required DateTime createdAt,
    this.isRead = const Value.absent(),
    this.rowid = const Value.absent(),
  }) : id = Value(id),
       type = Value(type),
       title = Value(title),
       message = Value(message),
       createdAt = Value(createdAt);
  static Insertable<Notification> custom({
    Expression<String>? id,
    Expression<String>? type,
    Expression<String>? title,
    Expression<String>? message,
    Expression<DateTime>? createdAt,
    Expression<bool>? isRead,
    Expression<int>? rowid,
  }) {
    return RawValuesInsertable({
      if (id != null) 'id': id,
      if (type != null) 'type': type,
      if (title != null) 'title': title,
      if (message != null) 'message': message,
      if (createdAt != null) 'created_at': createdAt,
      if (isRead != null) 'is_read': isRead,
      if (rowid != null) 'rowid': rowid,
    });
  }

  NotificationsCompanion copyWith({
    Value<String>? id,
    Value<String>? type,
    Value<String>? title,
    Value<String>? message,
    Value<DateTime>? createdAt,
    Value<bool>? isRead,
    Value<int>? rowid,
  }) {
    return NotificationsCompanion(
      id: id ?? this.id,
      type: type ?? this.type,
      title: title ?? this.title,
      message: message ?? this.message,
      createdAt: createdAt ?? this.createdAt,
      isRead: isRead ?? this.isRead,
      rowid: rowid ?? this.rowid,
    );
  }

  @override
  Map<String, Expression> toColumns(bool nullToAbsent) {
    final map = <String, Expression>{};
    if (id.present) {
      map['id'] = Variable<String>(id.value);
    }
    if (type.present) {
      map['type'] = Variable<String>(type.value);
    }
    if (title.present) {
      map['title'] = Variable<String>(title.value);
    }
    if (message.present) {
      map['message'] = Variable<String>(message.value);
    }
    if (createdAt.present) {
      map['created_at'] = Variable<DateTime>(createdAt.value);
    }
    if (isRead.present) {
      map['is_read'] = Variable<bool>(isRead.value);
    }
    if (rowid.present) {
      map['rowid'] = Variable<int>(rowid.value);
    }
    return map;
  }

  @override
  String toString() {
    return (StringBuffer('NotificationsCompanion(')
          ..write('id: $id, ')
          ..write('type: $type, ')
          ..write('title: $title, ')
          ..write('message: $message, ')
          ..write('createdAt: $createdAt, ')
          ..write('isRead: $isRead, ')
          ..write('rowid: $rowid')
          ..write(')'))
        .toString();
  }
}

abstract class _$AppDatabaseV2 extends GeneratedDatabase {
  _$AppDatabaseV2(QueryExecutor e) : super(e);
  $AppDatabaseV2Manager get managers => $AppDatabaseV2Manager(this);
  late final $AccountsTable accounts = $AccountsTable(this);
  late final $CategoriesTable categories = $CategoriesTable(this);
  late final $LedgerAccountsTable ledgerAccounts = $LedgerAccountsTable(this);
  late final $FinancialTransactionsTable financialTransactions =
      $FinancialTransactionsTable(this);
  late final $PostingsTable postings = $PostingsTable(this);
  late final $TransactionHistoryTable transactionHistory =
      $TransactionHistoryTable(this);
  late final $AppSettingsTable appSettings = $AppSettingsTable(this);
  late final $NotificationsTable notifications = $NotificationsTable(this);
  late final Index ledgerAccountsCategoryKind = Index(
    'ledger_accounts_category_kind',
    'CREATE UNIQUE INDEX ledger_accounts_category_kind ON ledger_accounts (category_id, kind)',
  );
  late final Index categoriesKind = Index(
    'categories_kind',
    'CREATE INDEX categories_kind ON categories (kind)',
  );
  late final Index financialTransactionsOccurredAt = Index(
    'financial_transactions_occurred_at',
    'CREATE INDEX financial_transactions_occurred_at ON financial_transactions (occurred_at)',
  );
  late final Index financialTransactionsReverses = Index(
    'financial_transactions_reverses',
    'CREATE INDEX financial_transactions_reverses ON financial_transactions (reverses_transaction_id)',
  );
  late final Index financialTransactionsRelated = Index(
    'financial_transactions_related',
    'CREATE INDEX financial_transactions_related ON financial_transactions (related_transaction_id)',
  );
  late final Index financialTransactionsKind = Index(
    'financial_transactions_kind',
    'CREATE INDEX financial_transactions_kind ON financial_transactions (kind)',
  );
  @override
  Iterable<TableInfo<Table, Object?>> get allTables =>
      allSchemaEntities.whereType<TableInfo<Table, Object?>>();
  @override
  List<DatabaseSchemaEntity> get allSchemaEntities => [
    accounts,
    categories,
    ledgerAccounts,
    financialTransactions,
    postings,
    transactionHistory,
    appSettings,
    notifications,
    ledgerAccountsCategoryKind,
    categoriesKind,
    financialTransactionsOccurredAt,
    financialTransactionsReverses,
    financialTransactionsRelated,
    financialTransactionsKind,
  ];
}

typedef $$AccountsTableCreateCompanionBuilder = AccountsCompanion Function({
  Value<int> id,
  required String uuid,
  required String name,
  required String kind,
  Value<String> currencyCode,
  Value<int?> iconCodePoint,
  Value<int?> colorValue,
  Value<bool> isArchived,
  Value<DateTime?> archivedAt,
  Value<int> displayOrder,
});
typedef $$AccountsTableUpdateCompanionBuilder = AccountsCompanion Function({
  Value<int> id,
  Value<String> uuid,
  Value<String> name,
  Value<String> kind,
  Value<String> currencyCode,
  Value<int?> iconCodePoint,
  Value<int?> colorValue,
  Value<bool> isArchived,
  Value<DateTime?> archivedAt,
  Value<int> displayOrder,
});

final class $$AccountsTableReferences
    extends BaseReferences<_$AppDatabaseV2, $AccountsTable, Account> {
  $$AccountsTableReferences(super.$_db, super.$_table, super.$_typedResult);

  static MultiTypedResultKey<$LedgerAccountsTable, List<LedgerAccount>>
  _ledgerAccountsRefsTable(_$AppDatabaseV2 db) => MultiTypedResultKey.fromTable(
    db.ledgerAccounts,
    aliasName: 'accounts__uuid__ledger_accounts__user_account_id',
  );

  $$LedgerAccountsTableProcessedTableManager get ledgerAccountsRefs {
    final manager = $$LedgerAccountsTableTableManager($_db, $_db.ledgerAccounts)
        .filter(
          (f) => f.userAccountId.uuid.sqlEquals($_itemColumn<String>('uuid')!),
        );

    final cache = $_typedResult.readTableOrNull(_ledgerAccountsRefsTable($_db));
    return ProcessedTableManager(
      manager.$state.copyWith(prefetchedData: cache),
    );
  }

  static MultiTypedResultKey<
    $FinancialTransactionsTable,
    List<FinancialTransaction>
  >
  _sourceTransactionsTable(_$AppDatabaseV2 db) => MultiTypedResultKey.fromTable(
    db.financialTransactions,
    aliasName: 'accounts__uuid__financial_transactions__source_account_id',
  );

  $$FinancialTransactionsTableProcessedTableManager get sourceTransactions {
    final manager =
        $$FinancialTransactionsTableTableManager(
          $_db,
          $_db.financialTransactions,
        ).filter(
          (f) =>
              f.sourceAccountId.uuid.sqlEquals($_itemColumn<String>('uuid')!),
        );

    final cache = $_typedResult.readTableOrNull(_sourceTransactionsTable($_db));
    return ProcessedTableManager(
      manager.$state.copyWith(prefetchedData: cache),
    );
  }

  static MultiTypedResultKey<
    $FinancialTransactionsTable,
    List<FinancialTransaction>
  >
  _destinationTransactionsTable(_$AppDatabaseV2 db) =>
      MultiTypedResultKey.fromTable(
        db.financialTransactions,
        aliasName:
            'accounts__uuid__financial_transactions__destination_account_id',
      );

  $$FinancialTransactionsTableProcessedTableManager
  get destinationTransactions {
    final manager =
        $$FinancialTransactionsTableTableManager(
          $_db,
          $_db.financialTransactions,
        ).filter(
          (f) => f.destinationAccountId.uuid.sqlEquals(
            $_itemColumn<String>('uuid')!,
          ),
        );

    final cache = $_typedResult.readTableOrNull(
      _destinationTransactionsTable($_db),
    );
    return ProcessedTableManager(
      manager.$state.copyWith(prefetchedData: cache),
    );
  }

  static MultiTypedResultKey<
    $FinancialTransactionsTable,
    List<FinancialTransaction>
  >
  _refundTransactionsTable(_$AppDatabaseV2 db) => MultiTypedResultKey.fromTable(
    db.financialTransactions,
    aliasName: 'accounts__uuid__financial_transactions__refund_account_id',
  );

  $$FinancialTransactionsTableProcessedTableManager get refundTransactions {
    final manager =
        $$FinancialTransactionsTableTableManager(
          $_db,
          $_db.financialTransactions,
        ).filter(
          (f) =>
              f.refundAccountId.uuid.sqlEquals($_itemColumn<String>('uuid')!),
        );

    final cache = $_typedResult.readTableOrNull(_refundTransactionsTable($_db));
    return ProcessedTableManager(
      manager.$state.copyWith(prefetchedData: cache),
    );
  }

  static MultiTypedResultKey<$AppSettingsTable, List<AppSetting>>
  _appSettingsRefsTable(_$AppDatabaseV2 db) => MultiTypedResultKey.fromTable(
    db.appSettings,
    aliasName: 'accounts__uuid__app_settings__default_account_id',
  );

  $$AppSettingsTableProcessedTableManager get appSettingsRefs {
    final manager = $$AppSettingsTableTableManager($_db, $_db.appSettings)
        .filter(
          (f) =>
              f.defaultAccountId.uuid.sqlEquals($_itemColumn<String>('uuid')!),
        );

    final cache = $_typedResult.readTableOrNull(_appSettingsRefsTable($_db));
    return ProcessedTableManager(
      manager.$state.copyWith(prefetchedData: cache),
    );
  }
}

class $$AccountsTableFilterComposer
    extends Composer<_$AppDatabaseV2, $AccountsTable> {
  $$AccountsTableFilterComposer({
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

  ColumnFilters<String> get uuid => $composableBuilder(
    column: $table.uuid,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<String> get name => $composableBuilder(
    column: $table.name,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<String> get kind => $composableBuilder(
    column: $table.kind,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<String> get currencyCode => $composableBuilder(
    column: $table.currencyCode,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<int> get iconCodePoint => $composableBuilder(
    column: $table.iconCodePoint,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<int> get colorValue => $composableBuilder(
    column: $table.colorValue,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<bool> get isArchived => $composableBuilder(
    column: $table.isArchived,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<DateTime> get archivedAt => $composableBuilder(
    column: $table.archivedAt,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<int> get displayOrder => $composableBuilder(
    column: $table.displayOrder,
    builder: (column) => ColumnFilters(column),
  );

  Expression<bool> ledgerAccountsRefs(
    Expression<bool> Function($$LedgerAccountsTableFilterComposer f) f,
  ) {
    final $$LedgerAccountsTableFilterComposer composer = $composerBuilder(
      composer: this,
      getCurrentColumn: (t) => t.uuid,
      referencedTable: $db.ledgerAccounts,
      getReferencedColumn: (t) => t.userAccountId,
      builder:
          (
            joinBuilder, {
            $addJoinBuilderToRootComposer,
            $removeJoinBuilderFromRootComposer,
          }) => $$LedgerAccountsTableFilterComposer(
            $db: $db,
            $table: $db.ledgerAccounts,
            $addJoinBuilderToRootComposer: $addJoinBuilderToRootComposer,
            joinBuilder: joinBuilder,
            $removeJoinBuilderFromRootComposer:
                $removeJoinBuilderFromRootComposer,
          ),
    );
    return f(composer);
  }

  Expression<bool> sourceTransactions(
    Expression<bool> Function($$FinancialTransactionsTableFilterComposer f) f,
  ) {
    final $$FinancialTransactionsTableFilterComposer composer =
        $composerBuilder(
          composer: this,
          getCurrentColumn: (t) => t.uuid,
          referencedTable: $db.financialTransactions,
          getReferencedColumn: (t) => t.sourceAccountId,
          builder:
              (
                joinBuilder, {
                $addJoinBuilderToRootComposer,
                $removeJoinBuilderFromRootComposer,
              }) => $$FinancialTransactionsTableFilterComposer(
                $db: $db,
                $table: $db.financialTransactions,
                $addJoinBuilderToRootComposer: $addJoinBuilderToRootComposer,
                joinBuilder: joinBuilder,
                $removeJoinBuilderFromRootComposer:
                    $removeJoinBuilderFromRootComposer,
              ),
        );
    return f(composer);
  }

  Expression<bool> destinationTransactions(
    Expression<bool> Function($$FinancialTransactionsTableFilterComposer f) f,
  ) {
    final $$FinancialTransactionsTableFilterComposer composer =
        $composerBuilder(
          composer: this,
          getCurrentColumn: (t) => t.uuid,
          referencedTable: $db.financialTransactions,
          getReferencedColumn: (t) => t.destinationAccountId,
          builder:
              (
                joinBuilder, {
                $addJoinBuilderToRootComposer,
                $removeJoinBuilderFromRootComposer,
              }) => $$FinancialTransactionsTableFilterComposer(
                $db: $db,
                $table: $db.financialTransactions,
                $addJoinBuilderToRootComposer: $addJoinBuilderToRootComposer,
                joinBuilder: joinBuilder,
                $removeJoinBuilderFromRootComposer:
                    $removeJoinBuilderFromRootComposer,
              ),
        );
    return f(composer);
  }

  Expression<bool> refundTransactions(
    Expression<bool> Function($$FinancialTransactionsTableFilterComposer f) f,
  ) {
    final $$FinancialTransactionsTableFilterComposer composer =
        $composerBuilder(
          composer: this,
          getCurrentColumn: (t) => t.uuid,
          referencedTable: $db.financialTransactions,
          getReferencedColumn: (t) => t.refundAccountId,
          builder:
              (
                joinBuilder, {
                $addJoinBuilderToRootComposer,
                $removeJoinBuilderFromRootComposer,
              }) => $$FinancialTransactionsTableFilterComposer(
                $db: $db,
                $table: $db.financialTransactions,
                $addJoinBuilderToRootComposer: $addJoinBuilderToRootComposer,
                joinBuilder: joinBuilder,
                $removeJoinBuilderFromRootComposer:
                    $removeJoinBuilderFromRootComposer,
              ),
        );
    return f(composer);
  }

  Expression<bool> appSettingsRefs(
    Expression<bool> Function($$AppSettingsTableFilterComposer f) f,
  ) {
    final $$AppSettingsTableFilterComposer composer = $composerBuilder(
      composer: this,
      getCurrentColumn: (t) => t.uuid,
      referencedTable: $db.appSettings,
      getReferencedColumn: (t) => t.defaultAccountId,
      builder:
          (
            joinBuilder, {
            $addJoinBuilderToRootComposer,
            $removeJoinBuilderFromRootComposer,
          }) => $$AppSettingsTableFilterComposer(
            $db: $db,
            $table: $db.appSettings,
            $addJoinBuilderToRootComposer: $addJoinBuilderToRootComposer,
            joinBuilder: joinBuilder,
            $removeJoinBuilderFromRootComposer:
                $removeJoinBuilderFromRootComposer,
          ),
    );
    return f(composer);
  }
}

class $$AccountsTableOrderingComposer
    extends Composer<_$AppDatabaseV2, $AccountsTable> {
  $$AccountsTableOrderingComposer({
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

  ColumnOrderings<String> get uuid => $composableBuilder(
    column: $table.uuid,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<String> get name => $composableBuilder(
    column: $table.name,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<String> get kind => $composableBuilder(
    column: $table.kind,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<String> get currencyCode => $composableBuilder(
    column: $table.currencyCode,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<int> get iconCodePoint => $composableBuilder(
    column: $table.iconCodePoint,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<int> get colorValue => $composableBuilder(
    column: $table.colorValue,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<bool> get isArchived => $composableBuilder(
    column: $table.isArchived,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<DateTime> get archivedAt => $composableBuilder(
    column: $table.archivedAt,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<int> get displayOrder => $composableBuilder(
    column: $table.displayOrder,
    builder: (column) => ColumnOrderings(column),
  );
}

class $$AccountsTableAnnotationComposer
    extends Composer<_$AppDatabaseV2, $AccountsTable> {
  $$AccountsTableAnnotationComposer({
    required super.$db,
    required super.$table,
    super.joinBuilder,
    super.$addJoinBuilderToRootComposer,
    super.$removeJoinBuilderFromRootComposer,
  });
  GeneratedColumn<int> get id =>
      $composableBuilder(column: $table.id, builder: (column) => column);

  GeneratedColumn<String> get uuid =>
      $composableBuilder(column: $table.uuid, builder: (column) => column);

  GeneratedColumn<String> get name =>
      $composableBuilder(column: $table.name, builder: (column) => column);

  GeneratedColumn<String> get kind =>
      $composableBuilder(column: $table.kind, builder: (column) => column);

  GeneratedColumn<String> get currencyCode => $composableBuilder(
    column: $table.currencyCode,
    builder: (column) => column,
  );

  GeneratedColumn<int> get iconCodePoint => $composableBuilder(
    column: $table.iconCodePoint,
    builder: (column) => column,
  );

  GeneratedColumn<int> get colorValue => $composableBuilder(
    column: $table.colorValue,
    builder: (column) => column,
  );

  GeneratedColumn<bool> get isArchived => $composableBuilder(
    column: $table.isArchived,
    builder: (column) => column,
  );

  GeneratedColumn<DateTime> get archivedAt => $composableBuilder(
    column: $table.archivedAt,
    builder: (column) => column,
  );

  GeneratedColumn<int> get displayOrder => $composableBuilder(
    column: $table.displayOrder,
    builder: (column) => column,
  );

  Expression<T> ledgerAccountsRefs<T extends Object>(
    Expression<T> Function($$LedgerAccountsTableAnnotationComposer a) f,
  ) {
    final $$LedgerAccountsTableAnnotationComposer composer = $composerBuilder(
      composer: this,
      getCurrentColumn: (t) => t.uuid,
      referencedTable: $db.ledgerAccounts,
      getReferencedColumn: (t) => t.userAccountId,
      builder:
          (
            joinBuilder, {
            $addJoinBuilderToRootComposer,
            $removeJoinBuilderFromRootComposer,
          }) => $$LedgerAccountsTableAnnotationComposer(
            $db: $db,
            $table: $db.ledgerAccounts,
            $addJoinBuilderToRootComposer: $addJoinBuilderToRootComposer,
            joinBuilder: joinBuilder,
            $removeJoinBuilderFromRootComposer:
                $removeJoinBuilderFromRootComposer,
          ),
    );
    return f(composer);
  }

  Expression<T> sourceTransactions<T extends Object>(
    Expression<T> Function($$FinancialTransactionsTableAnnotationComposer a) f,
  ) {
    final $$FinancialTransactionsTableAnnotationComposer composer =
        $composerBuilder(
          composer: this,
          getCurrentColumn: (t) => t.uuid,
          referencedTable: $db.financialTransactions,
          getReferencedColumn: (t) => t.sourceAccountId,
          builder:
              (
                joinBuilder, {
                $addJoinBuilderToRootComposer,
                $removeJoinBuilderFromRootComposer,
              }) => $$FinancialTransactionsTableAnnotationComposer(
                $db: $db,
                $table: $db.financialTransactions,
                $addJoinBuilderToRootComposer: $addJoinBuilderToRootComposer,
                joinBuilder: joinBuilder,
                $removeJoinBuilderFromRootComposer:
                    $removeJoinBuilderFromRootComposer,
              ),
        );
    return f(composer);
  }

  Expression<T> destinationTransactions<T extends Object>(
    Expression<T> Function($$FinancialTransactionsTableAnnotationComposer a) f,
  ) {
    final $$FinancialTransactionsTableAnnotationComposer composer =
        $composerBuilder(
          composer: this,
          getCurrentColumn: (t) => t.uuid,
          referencedTable: $db.financialTransactions,
          getReferencedColumn: (t) => t.destinationAccountId,
          builder:
              (
                joinBuilder, {
                $addJoinBuilderToRootComposer,
                $removeJoinBuilderFromRootComposer,
              }) => $$FinancialTransactionsTableAnnotationComposer(
                $db: $db,
                $table: $db.financialTransactions,
                $addJoinBuilderToRootComposer: $addJoinBuilderToRootComposer,
                joinBuilder: joinBuilder,
                $removeJoinBuilderFromRootComposer:
                    $removeJoinBuilderFromRootComposer,
              ),
        );
    return f(composer);
  }

  Expression<T> refundTransactions<T extends Object>(
    Expression<T> Function($$FinancialTransactionsTableAnnotationComposer a) f,
  ) {
    final $$FinancialTransactionsTableAnnotationComposer composer =
        $composerBuilder(
          composer: this,
          getCurrentColumn: (t) => t.uuid,
          referencedTable: $db.financialTransactions,
          getReferencedColumn: (t) => t.refundAccountId,
          builder:
              (
                joinBuilder, {
                $addJoinBuilderToRootComposer,
                $removeJoinBuilderFromRootComposer,
              }) => $$FinancialTransactionsTableAnnotationComposer(
                $db: $db,
                $table: $db.financialTransactions,
                $addJoinBuilderToRootComposer: $addJoinBuilderToRootComposer,
                joinBuilder: joinBuilder,
                $removeJoinBuilderFromRootComposer:
                    $removeJoinBuilderFromRootComposer,
              ),
        );
    return f(composer);
  }

  Expression<T> appSettingsRefs<T extends Object>(
    Expression<T> Function($$AppSettingsTableAnnotationComposer a) f,
  ) {
    final $$AppSettingsTableAnnotationComposer composer = $composerBuilder(
      composer: this,
      getCurrentColumn: (t) => t.uuid,
      referencedTable: $db.appSettings,
      getReferencedColumn: (t) => t.defaultAccountId,
      builder:
          (
            joinBuilder, {
            $addJoinBuilderToRootComposer,
            $removeJoinBuilderFromRootComposer,
          }) => $$AppSettingsTableAnnotationComposer(
            $db: $db,
            $table: $db.appSettings,
            $addJoinBuilderToRootComposer: $addJoinBuilderToRootComposer,
            joinBuilder: joinBuilder,
            $removeJoinBuilderFromRootComposer:
                $removeJoinBuilderFromRootComposer,
          ),
    );
    return f(composer);
  }
}

class $$AccountsTableTableManager
    extends
        RootTableManager<
          _$AppDatabaseV2,
          $AccountsTable,
          Account,
          $$AccountsTableFilterComposer,
          $$AccountsTableOrderingComposer,
          $$AccountsTableAnnotationComposer,
          $$AccountsTableCreateCompanionBuilder,
          $$AccountsTableUpdateCompanionBuilder,
          (Account, $$AccountsTableReferences),
          Account,
          PrefetchHooks Function({
            bool ledgerAccountsRefs,
            bool sourceTransactions,
            bool destinationTransactions,
            bool refundTransactions,
            bool appSettingsRefs,
          })
        > {
  $$AccountsTableTableManager(_$AppDatabaseV2 db, $AccountsTable table)
    : super(
        TableManagerState(
          db: db,
          table: table,
          createFilteringComposer: () =>
              $$AccountsTableFilterComposer($db: db, $table: table),
          createOrderingComposer: () =>
              $$AccountsTableOrderingComposer($db: db, $table: table),
          createComputedFieldComposer: () =>
              $$AccountsTableAnnotationComposer($db: db, $table: table),
          updateCompanionCallback:
              ({
                Value<int> id = const Value.absent(),
                Value<String> uuid = const Value.absent(),
                Value<String> name = const Value.absent(),
                Value<String> kind = const Value.absent(),
                Value<String> currencyCode = const Value.absent(),
                Value<int?> iconCodePoint = const Value.absent(),
                Value<int?> colorValue = const Value.absent(),
                Value<bool> isArchived = const Value.absent(),
                Value<DateTime?> archivedAt = const Value.absent(),
                Value<int> displayOrder = const Value.absent(),
              }) => AccountsCompanion(
                id: id,
                uuid: uuid,
                name: name,
                kind: kind,
                currencyCode: currencyCode,
                iconCodePoint: iconCodePoint,
                colorValue: colorValue,
                isArchived: isArchived,
                archivedAt: archivedAt,
                displayOrder: displayOrder,
              ),
          createCompanionCallback:
              ({
                Value<int> id = const Value.absent(),
                required String uuid,
                required String name,
                required String kind,
                Value<String> currencyCode = const Value.absent(),
                Value<int?> iconCodePoint = const Value.absent(),
                Value<int?> colorValue = const Value.absent(),
                Value<bool> isArchived = const Value.absent(),
                Value<DateTime?> archivedAt = const Value.absent(),
                Value<int> displayOrder = const Value.absent(),
              }) => AccountsCompanion.insert(
                id: id,
                uuid: uuid,
                name: name,
                kind: kind,
                currencyCode: currencyCode,
                iconCodePoint: iconCodePoint,
                colorValue: colorValue,
                isArchived: isArchived,
                archivedAt: archivedAt,
                displayOrder: displayOrder,
              ),
          withReferenceMapper: (p0) => p0
              .map(
                (e) => (
                  e.readTable<$AccountsTable, Account>(table),
                  $$AccountsTableReferences(db, table, e),
                ),
              )
              .toList(),
          prefetchHooksCallback:
              ({
                ledgerAccountsRefs = false,
                sourceTransactions = false,
                destinationTransactions = false,
                refundTransactions = false,
                appSettingsRefs = false,
              }) {
                return PrefetchHooks(
                  db: db,
                  explicitlyWatchedTables: [
                    if (ledgerAccountsRefs) db.ledgerAccounts,
                    if (sourceTransactions) db.financialTransactions,
                    if (destinationTransactions) db.financialTransactions,
                    if (refundTransactions) db.financialTransactions,
                    if (appSettingsRefs) db.appSettings,
                  ],
                  addJoins: null,
                  getPrefetchedDataCallback: (items) async {
                    return [
                      if (ledgerAccountsRefs)
                        await $_getPrefetchedData<
                          Account,
                          $AccountsTable,
                          LedgerAccount
                        >(
                          currentTable: table,
                          referencedTable: $$AccountsTableReferences
                              ._ledgerAccountsRefsTable(db),
                          managerFromTypedResult: (p0) =>
                              $$AccountsTableReferences(
                                db,
                                table,
                                p0,
                              ).ledgerAccountsRefs,
                          referencedItemsForCurrentItem:
                              (item, referencedItems) => referencedItems.where(
                                (e) => e.userAccountId == item.uuid,
                              ),
                          typedResults: items,
                        ),
                      if (sourceTransactions)
                        await $_getPrefetchedData<
                          Account,
                          $AccountsTable,
                          FinancialTransaction
                        >(
                          currentTable: table,
                          referencedTable: $$AccountsTableReferences
                              ._sourceTransactionsTable(db),
                          managerFromTypedResult: (p0) =>
                              $$AccountsTableReferences(
                                db,
                                table,
                                p0,
                              ).sourceTransactions,
                          referencedItemsForCurrentItem:
                              (item, referencedItems) => referencedItems.where(
                                (e) => e.sourceAccountId == item.uuid,
                              ),
                          typedResults: items,
                        ),
                      if (destinationTransactions)
                        await $_getPrefetchedData<
                          Account,
                          $AccountsTable,
                          FinancialTransaction
                        >(
                          currentTable: table,
                          referencedTable: $$AccountsTableReferences
                              ._destinationTransactionsTable(db),
                          managerFromTypedResult: (p0) =>
                              $$AccountsTableReferences(
                                db,
                                table,
                                p0,
                              ).destinationTransactions,
                          referencedItemsForCurrentItem:
                              (item, referencedItems) => referencedItems.where(
                                (e) => e.destinationAccountId == item.uuid,
                              ),
                          typedResults: items,
                        ),
                      if (refundTransactions)
                        await $_getPrefetchedData<
                          Account,
                          $AccountsTable,
                          FinancialTransaction
                        >(
                          currentTable: table,
                          referencedTable: $$AccountsTableReferences
                              ._refundTransactionsTable(db),
                          managerFromTypedResult: (p0) =>
                              $$AccountsTableReferences(
                                db,
                                table,
                                p0,
                              ).refundTransactions,
                          referencedItemsForCurrentItem:
                              (item, referencedItems) => referencedItems.where(
                                (e) => e.refundAccountId == item.uuid,
                              ),
                          typedResults: items,
                        ),
                      if (appSettingsRefs)
                        await $_getPrefetchedData<
                          Account,
                          $AccountsTable,
                          AppSetting
                        >(
                          currentTable: table,
                          referencedTable: $$AccountsTableReferences
                              ._appSettingsRefsTable(db),
                          managerFromTypedResult: (p0) =>
                              $$AccountsTableReferences(
                                db,
                                table,
                                p0,
                              ).appSettingsRefs,
                          referencedItemsForCurrentItem:
                              (item, referencedItems) => referencedItems.where(
                                (e) => e.defaultAccountId == item.uuid,
                              ),
                          typedResults: items,
                        ),
                    ];
                  },
                );
              },
        ),
      );
}

typedef $$AccountsTableProcessedTableManager =
    ProcessedTableManager<
      _$AppDatabaseV2,
      $AccountsTable,
      Account,
      $$AccountsTableFilterComposer,
      $$AccountsTableOrderingComposer,
      $$AccountsTableAnnotationComposer,
      $$AccountsTableCreateCompanionBuilder,
      $$AccountsTableUpdateCompanionBuilder,
      (Account, $$AccountsTableReferences),
      Account,
      PrefetchHooks Function({
        bool ledgerAccountsRefs,
        bool sourceTransactions,
        bool destinationTransactions,
        bool refundTransactions,
        bool appSettingsRefs,
      })
    >;
typedef $$CategoriesTableCreateCompanionBuilder = CategoriesCompanion Function({
  required String categoryId,
  required String name,
  required int iconCodePoint,
  Value<int?> colorValue,
  required String kind,
  required String origin,
  Value<bool> isArchived,
  Value<String?> parentCategoryId,
  Value<int> displayOrder,
  Value<int> rowid,
});
typedef $$CategoriesTableUpdateCompanionBuilder = CategoriesCompanion Function({
  Value<String> categoryId,
  Value<String> name,
  Value<int> iconCodePoint,
  Value<int?> colorValue,
  Value<String> kind,
  Value<String> origin,
  Value<bool> isArchived,
  Value<String?> parentCategoryId,
  Value<int> displayOrder,
  Value<int> rowid,
});

final class $$CategoriesTableReferences
    extends BaseReferences<_$AppDatabaseV2, $CategoriesTable, Category> {
  $$CategoriesTableReferences(super.$_db, super.$_table, super.$_typedResult);

  static $CategoriesTable _parentCategoryIdTable(_$AppDatabaseV2 db) => db
      .categories
      .createAlias('categories__parent_category_id__categories__category_id');

  $$CategoriesTableProcessedTableManager? get parentCategoryId {
    final $_column = $_itemColumn<String>('parent_category_id');
    if ($_column == null) return null;
    final manager = $$CategoriesTableTableManager(
      $_db,
      $_db.categories,
    ).filter((f) => f.categoryId.sqlEquals($_column));
    final item = $_typedResult.readTableOrNull(_parentCategoryIdTable($_db));
    if (item == null) return manager;
    return ProcessedTableManager(
      manager.$state.copyWith(prefetchedData: [item]),
    );
  }

  static MultiTypedResultKey<$LedgerAccountsTable, List<LedgerAccount>>
  _ledgerAccountsRefsTable(_$AppDatabaseV2 db) => MultiTypedResultKey.fromTable(
    db.ledgerAccounts,
    aliasName: 'categories__category_id__ledger_accounts__category_id',
  );

  $$LedgerAccountsTableProcessedTableManager get ledgerAccountsRefs {
    final manager = $$LedgerAccountsTableTableManager($_db, $_db.ledgerAccounts)
        .filter(
          (f) => f.categoryId.categoryId.sqlEquals(
            $_itemColumn<String>('category_id')!,
          ),
        );

    final cache = $_typedResult.readTableOrNull(_ledgerAccountsRefsTable($_db));
    return ProcessedTableManager(
      manager.$state.copyWith(prefetchedData: cache),
    );
  }

  static MultiTypedResultKey<
    $FinancialTransactionsTable,
    List<FinancialTransaction>
  >
  _financialTransactionsRefsTable(_$AppDatabaseV2 db) =>
      MultiTypedResultKey.fromTable(
        db.financialTransactions,
        aliasName:
            'categories__category_id__financial_transactions__category_id',
      );

  $$FinancialTransactionsTableProcessedTableManager
  get financialTransactionsRefs {
    final manager =
        $$FinancialTransactionsTableTableManager(
          $_db,
          $_db.financialTransactions,
        ).filter(
          (f) => f.categoryId.categoryId.sqlEquals(
            $_itemColumn<String>('category_id')!,
          ),
        );

    final cache = $_typedResult.readTableOrNull(
      _financialTransactionsRefsTable($_db),
    );
    return ProcessedTableManager(
      manager.$state.copyWith(prefetchedData: cache),
    );
  }
}

class $$CategoriesTableFilterComposer
    extends Composer<_$AppDatabaseV2, $CategoriesTable> {
  $$CategoriesTableFilterComposer({
    required super.$db,
    required super.$table,
    super.joinBuilder,
    super.$addJoinBuilderToRootComposer,
    super.$removeJoinBuilderFromRootComposer,
  });
  ColumnFilters<String> get categoryId => $composableBuilder(
    column: $table.categoryId,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<String> get name => $composableBuilder(
    column: $table.name,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<int> get iconCodePoint => $composableBuilder(
    column: $table.iconCodePoint,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<int> get colorValue => $composableBuilder(
    column: $table.colorValue,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<String> get kind => $composableBuilder(
    column: $table.kind,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<String> get origin => $composableBuilder(
    column: $table.origin,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<bool> get isArchived => $composableBuilder(
    column: $table.isArchived,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<int> get displayOrder => $composableBuilder(
    column: $table.displayOrder,
    builder: (column) => ColumnFilters(column),
  );

  $$CategoriesTableFilterComposer get parentCategoryId {
    final $$CategoriesTableFilterComposer composer = $composerBuilder(
      composer: this,
      getCurrentColumn: (t) => t.parentCategoryId,
      referencedTable: $db.categories,
      getReferencedColumn: (t) => t.categoryId,
      builder:
          (
            joinBuilder, {
            $addJoinBuilderToRootComposer,
            $removeJoinBuilderFromRootComposer,
          }) => $$CategoriesTableFilterComposer(
            $db: $db,
            $table: $db.categories,
            $addJoinBuilderToRootComposer: $addJoinBuilderToRootComposer,
            joinBuilder: joinBuilder,
            $removeJoinBuilderFromRootComposer:
                $removeJoinBuilderFromRootComposer,
          ),
    );
    return composer;
  }

  Expression<bool> ledgerAccountsRefs(
    Expression<bool> Function($$LedgerAccountsTableFilterComposer f) f,
  ) {
    final $$LedgerAccountsTableFilterComposer composer = $composerBuilder(
      composer: this,
      getCurrentColumn: (t) => t.categoryId,
      referencedTable: $db.ledgerAccounts,
      getReferencedColumn: (t) => t.categoryId,
      builder:
          (
            joinBuilder, {
            $addJoinBuilderToRootComposer,
            $removeJoinBuilderFromRootComposer,
          }) => $$LedgerAccountsTableFilterComposer(
            $db: $db,
            $table: $db.ledgerAccounts,
            $addJoinBuilderToRootComposer: $addJoinBuilderToRootComposer,
            joinBuilder: joinBuilder,
            $removeJoinBuilderFromRootComposer:
                $removeJoinBuilderFromRootComposer,
          ),
    );
    return f(composer);
  }

  Expression<bool> financialTransactionsRefs(
    Expression<bool> Function($$FinancialTransactionsTableFilterComposer f) f,
  ) {
    final $$FinancialTransactionsTableFilterComposer composer =
        $composerBuilder(
          composer: this,
          getCurrentColumn: (t) => t.categoryId,
          referencedTable: $db.financialTransactions,
          getReferencedColumn: (t) => t.categoryId,
          builder:
              (
                joinBuilder, {
                $addJoinBuilderToRootComposer,
                $removeJoinBuilderFromRootComposer,
              }) => $$FinancialTransactionsTableFilterComposer(
                $db: $db,
                $table: $db.financialTransactions,
                $addJoinBuilderToRootComposer: $addJoinBuilderToRootComposer,
                joinBuilder: joinBuilder,
                $removeJoinBuilderFromRootComposer:
                    $removeJoinBuilderFromRootComposer,
              ),
        );
    return f(composer);
  }
}

class $$CategoriesTableOrderingComposer
    extends Composer<_$AppDatabaseV2, $CategoriesTable> {
  $$CategoriesTableOrderingComposer({
    required super.$db,
    required super.$table,
    super.joinBuilder,
    super.$addJoinBuilderToRootComposer,
    super.$removeJoinBuilderFromRootComposer,
  });
  ColumnOrderings<String> get categoryId => $composableBuilder(
    column: $table.categoryId,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<String> get name => $composableBuilder(
    column: $table.name,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<int> get iconCodePoint => $composableBuilder(
    column: $table.iconCodePoint,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<int> get colorValue => $composableBuilder(
    column: $table.colorValue,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<String> get kind => $composableBuilder(
    column: $table.kind,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<String> get origin => $composableBuilder(
    column: $table.origin,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<bool> get isArchived => $composableBuilder(
    column: $table.isArchived,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<int> get displayOrder => $composableBuilder(
    column: $table.displayOrder,
    builder: (column) => ColumnOrderings(column),
  );

  $$CategoriesTableOrderingComposer get parentCategoryId {
    final $$CategoriesTableOrderingComposer composer = $composerBuilder(
      composer: this,
      getCurrentColumn: (t) => t.parentCategoryId,
      referencedTable: $db.categories,
      getReferencedColumn: (t) => t.categoryId,
      builder:
          (
            joinBuilder, {
            $addJoinBuilderToRootComposer,
            $removeJoinBuilderFromRootComposer,
          }) => $$CategoriesTableOrderingComposer(
            $db: $db,
            $table: $db.categories,
            $addJoinBuilderToRootComposer: $addJoinBuilderToRootComposer,
            joinBuilder: joinBuilder,
            $removeJoinBuilderFromRootComposer:
                $removeJoinBuilderFromRootComposer,
          ),
    );
    return composer;
  }
}

class $$CategoriesTableAnnotationComposer
    extends Composer<_$AppDatabaseV2, $CategoriesTable> {
  $$CategoriesTableAnnotationComposer({
    required super.$db,
    required super.$table,
    super.joinBuilder,
    super.$addJoinBuilderToRootComposer,
    super.$removeJoinBuilderFromRootComposer,
  });
  GeneratedColumn<String> get categoryId => $composableBuilder(
    column: $table.categoryId,
    builder: (column) => column,
  );

  GeneratedColumn<String> get name =>
      $composableBuilder(column: $table.name, builder: (column) => column);

  GeneratedColumn<int> get iconCodePoint => $composableBuilder(
    column: $table.iconCodePoint,
    builder: (column) => column,
  );

  GeneratedColumn<int> get colorValue => $composableBuilder(
    column: $table.colorValue,
    builder: (column) => column,
  );

  GeneratedColumn<String> get kind =>
      $composableBuilder(column: $table.kind, builder: (column) => column);

  GeneratedColumn<String> get origin =>
      $composableBuilder(column: $table.origin, builder: (column) => column);

  GeneratedColumn<bool> get isArchived => $composableBuilder(
    column: $table.isArchived,
    builder: (column) => column,
  );

  GeneratedColumn<int> get displayOrder => $composableBuilder(
    column: $table.displayOrder,
    builder: (column) => column,
  );

  $$CategoriesTableAnnotationComposer get parentCategoryId {
    final $$CategoriesTableAnnotationComposer composer = $composerBuilder(
      composer: this,
      getCurrentColumn: (t) => t.parentCategoryId,
      referencedTable: $db.categories,
      getReferencedColumn: (t) => t.categoryId,
      builder:
          (
            joinBuilder, {
            $addJoinBuilderToRootComposer,
            $removeJoinBuilderFromRootComposer,
          }) => $$CategoriesTableAnnotationComposer(
            $db: $db,
            $table: $db.categories,
            $addJoinBuilderToRootComposer: $addJoinBuilderToRootComposer,
            joinBuilder: joinBuilder,
            $removeJoinBuilderFromRootComposer:
                $removeJoinBuilderFromRootComposer,
          ),
    );
    return composer;
  }

  Expression<T> ledgerAccountsRefs<T extends Object>(
    Expression<T> Function($$LedgerAccountsTableAnnotationComposer a) f,
  ) {
    final $$LedgerAccountsTableAnnotationComposer composer = $composerBuilder(
      composer: this,
      getCurrentColumn: (t) => t.categoryId,
      referencedTable: $db.ledgerAccounts,
      getReferencedColumn: (t) => t.categoryId,
      builder:
          (
            joinBuilder, {
            $addJoinBuilderToRootComposer,
            $removeJoinBuilderFromRootComposer,
          }) => $$LedgerAccountsTableAnnotationComposer(
            $db: $db,
            $table: $db.ledgerAccounts,
            $addJoinBuilderToRootComposer: $addJoinBuilderToRootComposer,
            joinBuilder: joinBuilder,
            $removeJoinBuilderFromRootComposer:
                $removeJoinBuilderFromRootComposer,
          ),
    );
    return f(composer);
  }

  Expression<T> financialTransactionsRefs<T extends Object>(
    Expression<T> Function($$FinancialTransactionsTableAnnotationComposer a) f,
  ) {
    final $$FinancialTransactionsTableAnnotationComposer composer =
        $composerBuilder(
          composer: this,
          getCurrentColumn: (t) => t.categoryId,
          referencedTable: $db.financialTransactions,
          getReferencedColumn: (t) => t.categoryId,
          builder:
              (
                joinBuilder, {
                $addJoinBuilderToRootComposer,
                $removeJoinBuilderFromRootComposer,
              }) => $$FinancialTransactionsTableAnnotationComposer(
                $db: $db,
                $table: $db.financialTransactions,
                $addJoinBuilderToRootComposer: $addJoinBuilderToRootComposer,
                joinBuilder: joinBuilder,
                $removeJoinBuilderFromRootComposer:
                    $removeJoinBuilderFromRootComposer,
              ),
        );
    return f(composer);
  }
}

class $$CategoriesTableTableManager
    extends
        RootTableManager<
          _$AppDatabaseV2,
          $CategoriesTable,
          Category,
          $$CategoriesTableFilterComposer,
          $$CategoriesTableOrderingComposer,
          $$CategoriesTableAnnotationComposer,
          $$CategoriesTableCreateCompanionBuilder,
          $$CategoriesTableUpdateCompanionBuilder,
          (Category, $$CategoriesTableReferences),
          Category,
          PrefetchHooks Function({
            bool parentCategoryId,
            bool ledgerAccountsRefs,
            bool financialTransactionsRefs,
          })
        > {
  $$CategoriesTableTableManager(_$AppDatabaseV2 db, $CategoriesTable table)
    : super(
        TableManagerState(
          db: db,
          table: table,
          createFilteringComposer: () =>
              $$CategoriesTableFilterComposer($db: db, $table: table),
          createOrderingComposer: () =>
              $$CategoriesTableOrderingComposer($db: db, $table: table),
          createComputedFieldComposer: () =>
              $$CategoriesTableAnnotationComposer($db: db, $table: table),
          updateCompanionCallback:
              ({
                Value<String> categoryId = const Value.absent(),
                Value<String> name = const Value.absent(),
                Value<int> iconCodePoint = const Value.absent(),
                Value<int?> colorValue = const Value.absent(),
                Value<String> kind = const Value.absent(),
                Value<String> origin = const Value.absent(),
                Value<bool> isArchived = const Value.absent(),
                Value<String?> parentCategoryId = const Value.absent(),
                Value<int> displayOrder = const Value.absent(),
                Value<int> rowid = const Value.absent(),
              }) => CategoriesCompanion(
                categoryId: categoryId,
                name: name,
                iconCodePoint: iconCodePoint,
                colorValue: colorValue,
                kind: kind,
                origin: origin,
                isArchived: isArchived,
                parentCategoryId: parentCategoryId,
                displayOrder: displayOrder,
                rowid: rowid,
              ),
          createCompanionCallback:
              ({
                required String categoryId,
                required String name,
                required int iconCodePoint,
                Value<int?> colorValue = const Value.absent(),
                required String kind,
                required String origin,
                Value<bool> isArchived = const Value.absent(),
                Value<String?> parentCategoryId = const Value.absent(),
                Value<int> displayOrder = const Value.absent(),
                Value<int> rowid = const Value.absent(),
              }) => CategoriesCompanion.insert(
                categoryId: categoryId,
                name: name,
                iconCodePoint: iconCodePoint,
                colorValue: colorValue,
                kind: kind,
                origin: origin,
                isArchived: isArchived,
                parentCategoryId: parentCategoryId,
                displayOrder: displayOrder,
                rowid: rowid,
              ),
          withReferenceMapper: (p0) => p0
              .map(
                (e) => (
                  e.readTable<$CategoriesTable, Category>(table),
                  $$CategoriesTableReferences(db, table, e),
                ),
              )
              .toList(),
          prefetchHooksCallback:
              ({
                parentCategoryId = false,
                ledgerAccountsRefs = false,
                financialTransactionsRefs = false,
              }) {
                return PrefetchHooks(
                  db: db,
                  explicitlyWatchedTables: [
                    if (ledgerAccountsRefs) db.ledgerAccounts,
                    if (financialTransactionsRefs) db.financialTransactions,
                  ],
                  addJoins:
                      <
                        T extends TableManagerState<
                          dynamic,
                          dynamic,
                          dynamic,
                          dynamic,
                          dynamic,
                          dynamic,
                          dynamic,
                          dynamic,
                          dynamic,
                          dynamic,
                          dynamic
                        >
                      >(state) {
                        if (parentCategoryId) {
                          state = state.withJoin(
                            currentTable: table,
                            currentColumn: table.parentCategoryId,
                            referencedTable: $$CategoriesTableReferences
                                ._parentCategoryIdTable(db),
                            referencedColumn: $$CategoriesTableReferences
                                ._parentCategoryIdTable(db)
                                .categoryId,
                          ) as T;
                        }

                        return state;
                      },
                  getPrefetchedDataCallback: (items) async {
                    return [
                      if (ledgerAccountsRefs)
                        await $_getPrefetchedData<
                          Category,
                          $CategoriesTable,
                          LedgerAccount
                        >(
                          currentTable: table,
                          referencedTable: $$CategoriesTableReferences
                              ._ledgerAccountsRefsTable(db),
                          managerFromTypedResult: (p0) =>
                              $$CategoriesTableReferences(
                                db,
                                table,
                                p0,
                              ).ledgerAccountsRefs,
                          referencedItemsForCurrentItem:
                              (item, referencedItems) => referencedItems.where(
                                (e) => e.categoryId == item.categoryId,
                              ),
                          typedResults: items,
                        ),
                      if (financialTransactionsRefs)
                        await $_getPrefetchedData<
                          Category,
                          $CategoriesTable,
                          FinancialTransaction
                        >(
                          currentTable: table,
                          referencedTable: $$CategoriesTableReferences
                              ._financialTransactionsRefsTable(db),
                          managerFromTypedResult: (p0) =>
                              $$CategoriesTableReferences(
                                db,
                                table,
                                p0,
                              ).financialTransactionsRefs,
                          referencedItemsForCurrentItem:
                              (item, referencedItems) => referencedItems.where(
                                (e) => e.categoryId == item.categoryId,
                              ),
                          typedResults: items,
                        ),
                    ];
                  },
                );
              },
        ),
      );
}

typedef $$CategoriesTableProcessedTableManager =
    ProcessedTableManager<
      _$AppDatabaseV2,
      $CategoriesTable,
      Category,
      $$CategoriesTableFilterComposer,
      $$CategoriesTableOrderingComposer,
      $$CategoriesTableAnnotationComposer,
      $$CategoriesTableCreateCompanionBuilder,
      $$CategoriesTableUpdateCompanionBuilder,
      (Category, $$CategoriesTableReferences),
      Category,
      PrefetchHooks Function({
        bool parentCategoryId,
        bool ledgerAccountsRefs,
        bool financialTransactionsRefs,
      })
    >;
typedef $$LedgerAccountsTableCreateCompanionBuilder =
    LedgerAccountsCompanion Function({
      required String ledgerAccountId,
      required String kind,
      Value<String?> userAccountId,
      Value<String?> categoryId,
      Value<bool> isSystem,
      required String normalBalance,
      Value<bool> isArchived,
      Value<int> rowid,
    });
typedef $$LedgerAccountsTableUpdateCompanionBuilder =
    LedgerAccountsCompanion Function({
      Value<String> ledgerAccountId,
      Value<String> kind,
      Value<String?> userAccountId,
      Value<String?> categoryId,
      Value<bool> isSystem,
      Value<String> normalBalance,
      Value<bool> isArchived,
      Value<int> rowid,
    });

final class $$LedgerAccountsTableReferences
    extends
        BaseReferences<_$AppDatabaseV2, $LedgerAccountsTable, LedgerAccount> {
  $$LedgerAccountsTableReferences(
    super.$_db,
    super.$_table,
    super.$_typedResult,
  );

  static $AccountsTable _userAccountIdTable(_$AppDatabaseV2 db) => db.accounts
      .createAlias('ledger_accounts__user_account_id__accounts__uuid');

  $$AccountsTableProcessedTableManager? get userAccountId {
    final $_column = $_itemColumn<String>('user_account_id');
    if ($_column == null) return null;
    final manager = $$AccountsTableTableManager(
      $_db,
      $_db.accounts,
    ).filter((f) => f.uuid.sqlEquals($_column));
    final item = $_typedResult.readTableOrNull(_userAccountIdTable($_db));
    if (item == null) return manager;
    return ProcessedTableManager(
      manager.$state.copyWith(prefetchedData: [item]),
    );
  }

  static $CategoriesTable _categoryIdTable(_$AppDatabaseV2 db) => db.categories
      .createAlias('ledger_accounts__category_id__categories__category_id');

  $$CategoriesTableProcessedTableManager? get categoryId {
    final $_column = $_itemColumn<String>('category_id');
    if ($_column == null) return null;
    final manager = $$CategoriesTableTableManager(
      $_db,
      $_db.categories,
    ).filter((f) => f.categoryId.sqlEquals($_column));
    final item = $_typedResult.readTableOrNull(_categoryIdTable($_db));
    if (item == null) return manager;
    return ProcessedTableManager(
      manager.$state.copyWith(prefetchedData: [item]),
    );
  }

  static MultiTypedResultKey<$PostingsTable, List<Posting>> _postingsRefsTable(
    _$AppDatabaseV2 db,
  ) => MultiTypedResultKey.fromTable(
    db.postings,
    aliasName:
        'ledger_accounts__ledger_account_id__postings__ledger_account_id',
  );

  $$PostingsTableProcessedTableManager get postingsRefs {
    final manager = $$PostingsTableTableManager($_db, $_db.postings).filter(
      (f) => f.ledgerAccountId.ledgerAccountId.sqlEquals(
        $_itemColumn<String>('ledger_account_id')!,
      ),
    );

    final cache = $_typedResult.readTableOrNull(_postingsRefsTable($_db));
    return ProcessedTableManager(
      manager.$state.copyWith(prefetchedData: cache),
    );
  }
}

class $$LedgerAccountsTableFilterComposer
    extends Composer<_$AppDatabaseV2, $LedgerAccountsTable> {
  $$LedgerAccountsTableFilterComposer({
    required super.$db,
    required super.$table,
    super.joinBuilder,
    super.$addJoinBuilderToRootComposer,
    super.$removeJoinBuilderFromRootComposer,
  });
  ColumnFilters<String> get ledgerAccountId => $composableBuilder(
    column: $table.ledgerAccountId,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<String> get kind => $composableBuilder(
    column: $table.kind,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<bool> get isSystem => $composableBuilder(
    column: $table.isSystem,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<String> get normalBalance => $composableBuilder(
    column: $table.normalBalance,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<bool> get isArchived => $composableBuilder(
    column: $table.isArchived,
    builder: (column) => ColumnFilters(column),
  );

  $$AccountsTableFilterComposer get userAccountId {
    final $$AccountsTableFilterComposer composer = $composerBuilder(
      composer: this,
      getCurrentColumn: (t) => t.userAccountId,
      referencedTable: $db.accounts,
      getReferencedColumn: (t) => t.uuid,
      builder:
          (
            joinBuilder, {
            $addJoinBuilderToRootComposer,
            $removeJoinBuilderFromRootComposer,
          }) => $$AccountsTableFilterComposer(
            $db: $db,
            $table: $db.accounts,
            $addJoinBuilderToRootComposer: $addJoinBuilderToRootComposer,
            joinBuilder: joinBuilder,
            $removeJoinBuilderFromRootComposer:
                $removeJoinBuilderFromRootComposer,
          ),
    );
    return composer;
  }

  $$CategoriesTableFilterComposer get categoryId {
    final $$CategoriesTableFilterComposer composer = $composerBuilder(
      composer: this,
      getCurrentColumn: (t) => t.categoryId,
      referencedTable: $db.categories,
      getReferencedColumn: (t) => t.categoryId,
      builder:
          (
            joinBuilder, {
            $addJoinBuilderToRootComposer,
            $removeJoinBuilderFromRootComposer,
          }) => $$CategoriesTableFilterComposer(
            $db: $db,
            $table: $db.categories,
            $addJoinBuilderToRootComposer: $addJoinBuilderToRootComposer,
            joinBuilder: joinBuilder,
            $removeJoinBuilderFromRootComposer:
                $removeJoinBuilderFromRootComposer,
          ),
    );
    return composer;
  }

  Expression<bool> postingsRefs(
    Expression<bool> Function($$PostingsTableFilterComposer f) f,
  ) {
    final $$PostingsTableFilterComposer composer = $composerBuilder(
      composer: this,
      getCurrentColumn: (t) => t.ledgerAccountId,
      referencedTable: $db.postings,
      getReferencedColumn: (t) => t.ledgerAccountId,
      builder:
          (
            joinBuilder, {
            $addJoinBuilderToRootComposer,
            $removeJoinBuilderFromRootComposer,
          }) => $$PostingsTableFilterComposer(
            $db: $db,
            $table: $db.postings,
            $addJoinBuilderToRootComposer: $addJoinBuilderToRootComposer,
            joinBuilder: joinBuilder,
            $removeJoinBuilderFromRootComposer:
                $removeJoinBuilderFromRootComposer,
          ),
    );
    return f(composer);
  }
}

class $$LedgerAccountsTableOrderingComposer
    extends Composer<_$AppDatabaseV2, $LedgerAccountsTable> {
  $$LedgerAccountsTableOrderingComposer({
    required super.$db,
    required super.$table,
    super.joinBuilder,
    super.$addJoinBuilderToRootComposer,
    super.$removeJoinBuilderFromRootComposer,
  });
  ColumnOrderings<String> get ledgerAccountId => $composableBuilder(
    column: $table.ledgerAccountId,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<String> get kind => $composableBuilder(
    column: $table.kind,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<bool> get isSystem => $composableBuilder(
    column: $table.isSystem,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<String> get normalBalance => $composableBuilder(
    column: $table.normalBalance,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<bool> get isArchived => $composableBuilder(
    column: $table.isArchived,
    builder: (column) => ColumnOrderings(column),
  );

  $$AccountsTableOrderingComposer get userAccountId {
    final $$AccountsTableOrderingComposer composer = $composerBuilder(
      composer: this,
      getCurrentColumn: (t) => t.userAccountId,
      referencedTable: $db.accounts,
      getReferencedColumn: (t) => t.uuid,
      builder:
          (
            joinBuilder, {
            $addJoinBuilderToRootComposer,
            $removeJoinBuilderFromRootComposer,
          }) => $$AccountsTableOrderingComposer(
            $db: $db,
            $table: $db.accounts,
            $addJoinBuilderToRootComposer: $addJoinBuilderToRootComposer,
            joinBuilder: joinBuilder,
            $removeJoinBuilderFromRootComposer:
                $removeJoinBuilderFromRootComposer,
          ),
    );
    return composer;
  }

  $$CategoriesTableOrderingComposer get categoryId {
    final $$CategoriesTableOrderingComposer composer = $composerBuilder(
      composer: this,
      getCurrentColumn: (t) => t.categoryId,
      referencedTable: $db.categories,
      getReferencedColumn: (t) => t.categoryId,
      builder:
          (
            joinBuilder, {
            $addJoinBuilderToRootComposer,
            $removeJoinBuilderFromRootComposer,
          }) => $$CategoriesTableOrderingComposer(
            $db: $db,
            $table: $db.categories,
            $addJoinBuilderToRootComposer: $addJoinBuilderToRootComposer,
            joinBuilder: joinBuilder,
            $removeJoinBuilderFromRootComposer:
                $removeJoinBuilderFromRootComposer,
          ),
    );
    return composer;
  }
}

class $$LedgerAccountsTableAnnotationComposer
    extends Composer<_$AppDatabaseV2, $LedgerAccountsTable> {
  $$LedgerAccountsTableAnnotationComposer({
    required super.$db,
    required super.$table,
    super.joinBuilder,
    super.$addJoinBuilderToRootComposer,
    super.$removeJoinBuilderFromRootComposer,
  });
  GeneratedColumn<String> get ledgerAccountId => $composableBuilder(
    column: $table.ledgerAccountId,
    builder: (column) => column,
  );

  GeneratedColumn<String> get kind =>
      $composableBuilder(column: $table.kind, builder: (column) => column);

  GeneratedColumn<bool> get isSystem =>
      $composableBuilder(column: $table.isSystem, builder: (column) => column);

  GeneratedColumn<String> get normalBalance => $composableBuilder(
    column: $table.normalBalance,
    builder: (column) => column,
  );

  GeneratedColumn<bool> get isArchived => $composableBuilder(
    column: $table.isArchived,
    builder: (column) => column,
  );

  $$AccountsTableAnnotationComposer get userAccountId {
    final $$AccountsTableAnnotationComposer composer = $composerBuilder(
      composer: this,
      getCurrentColumn: (t) => t.userAccountId,
      referencedTable: $db.accounts,
      getReferencedColumn: (t) => t.uuid,
      builder:
          (
            joinBuilder, {
            $addJoinBuilderToRootComposer,
            $removeJoinBuilderFromRootComposer,
          }) => $$AccountsTableAnnotationComposer(
            $db: $db,
            $table: $db.accounts,
            $addJoinBuilderToRootComposer: $addJoinBuilderToRootComposer,
            joinBuilder: joinBuilder,
            $removeJoinBuilderFromRootComposer:
                $removeJoinBuilderFromRootComposer,
          ),
    );
    return composer;
  }

  $$CategoriesTableAnnotationComposer get categoryId {
    final $$CategoriesTableAnnotationComposer composer = $composerBuilder(
      composer: this,
      getCurrentColumn: (t) => t.categoryId,
      referencedTable: $db.categories,
      getReferencedColumn: (t) => t.categoryId,
      builder:
          (
            joinBuilder, {
            $addJoinBuilderToRootComposer,
            $removeJoinBuilderFromRootComposer,
          }) => $$CategoriesTableAnnotationComposer(
            $db: $db,
            $table: $db.categories,
            $addJoinBuilderToRootComposer: $addJoinBuilderToRootComposer,
            joinBuilder: joinBuilder,
            $removeJoinBuilderFromRootComposer:
                $removeJoinBuilderFromRootComposer,
          ),
    );
    return composer;
  }

  Expression<T> postingsRefs<T extends Object>(
    Expression<T> Function($$PostingsTableAnnotationComposer a) f,
  ) {
    final $$PostingsTableAnnotationComposer composer = $composerBuilder(
      composer: this,
      getCurrentColumn: (t) => t.ledgerAccountId,
      referencedTable: $db.postings,
      getReferencedColumn: (t) => t.ledgerAccountId,
      builder:
          (
            joinBuilder, {
            $addJoinBuilderToRootComposer,
            $removeJoinBuilderFromRootComposer,
          }) => $$PostingsTableAnnotationComposer(
            $db: $db,
            $table: $db.postings,
            $addJoinBuilderToRootComposer: $addJoinBuilderToRootComposer,
            joinBuilder: joinBuilder,
            $removeJoinBuilderFromRootComposer:
                $removeJoinBuilderFromRootComposer,
          ),
    );
    return f(composer);
  }
}

class $$LedgerAccountsTableTableManager
    extends
        RootTableManager<
          _$AppDatabaseV2,
          $LedgerAccountsTable,
          LedgerAccount,
          $$LedgerAccountsTableFilterComposer,
          $$LedgerAccountsTableOrderingComposer,
          $$LedgerAccountsTableAnnotationComposer,
          $$LedgerAccountsTableCreateCompanionBuilder,
          $$LedgerAccountsTableUpdateCompanionBuilder,
          (LedgerAccount, $$LedgerAccountsTableReferences),
          LedgerAccount,
          PrefetchHooks Function({
            bool userAccountId,
            bool categoryId,
            bool postingsRefs,
          })
        > {
  $$LedgerAccountsTableTableManager(
    _$AppDatabaseV2 db,
    $LedgerAccountsTable table,
  ) : super(
        TableManagerState(
          db: db,
          table: table,
          createFilteringComposer: () =>
              $$LedgerAccountsTableFilterComposer($db: db, $table: table),
          createOrderingComposer: () =>
              $$LedgerAccountsTableOrderingComposer($db: db, $table: table),
          createComputedFieldComposer: () =>
              $$LedgerAccountsTableAnnotationComposer($db: db, $table: table),
          updateCompanionCallback:
              ({
                Value<String> ledgerAccountId = const Value.absent(),
                Value<String> kind = const Value.absent(),
                Value<String?> userAccountId = const Value.absent(),
                Value<String?> categoryId = const Value.absent(),
                Value<bool> isSystem = const Value.absent(),
                Value<String> normalBalance = const Value.absent(),
                Value<bool> isArchived = const Value.absent(),
                Value<int> rowid = const Value.absent(),
              }) => LedgerAccountsCompanion(
                ledgerAccountId: ledgerAccountId,
                kind: kind,
                userAccountId: userAccountId,
                categoryId: categoryId,
                isSystem: isSystem,
                normalBalance: normalBalance,
                isArchived: isArchived,
                rowid: rowid,
              ),
          createCompanionCallback:
              ({
                required String ledgerAccountId,
                required String kind,
                Value<String?> userAccountId = const Value.absent(),
                Value<String?> categoryId = const Value.absent(),
                Value<bool> isSystem = const Value.absent(),
                required String normalBalance,
                Value<bool> isArchived = const Value.absent(),
                Value<int> rowid = const Value.absent(),
              }) => LedgerAccountsCompanion.insert(
                ledgerAccountId: ledgerAccountId,
                kind: kind,
                userAccountId: userAccountId,
                categoryId: categoryId,
                isSystem: isSystem,
                normalBalance: normalBalance,
                isArchived: isArchived,
                rowid: rowid,
              ),
          withReferenceMapper: (p0) => p0
              .map(
                (e) => (
                  e.readTable<$LedgerAccountsTable, LedgerAccount>(table),
                  $$LedgerAccountsTableReferences(db, table, e),
                ),
              )
              .toList(),
          prefetchHooksCallback:
              ({
                userAccountId = false,
                categoryId = false,
                postingsRefs = false,
              }) {
                return PrefetchHooks(
                  db: db,
                  explicitlyWatchedTables: [if (postingsRefs) db.postings],
                  addJoins:
                      <
                        T extends TableManagerState<
                          dynamic,
                          dynamic,
                          dynamic,
                          dynamic,
                          dynamic,
                          dynamic,
                          dynamic,
                          dynamic,
                          dynamic,
                          dynamic,
                          dynamic
                        >
                      >(state) {
                        if (userAccountId) {
                          state = state.withJoin(
                            currentTable: table,
                            currentColumn: table.userAccountId,
                            referencedTable: $$LedgerAccountsTableReferences
                                ._userAccountIdTable(db),
                            referencedColumn: $$LedgerAccountsTableReferences
                                ._userAccountIdTable(db)
                                .uuid,
                          ) as T;
                        }
                        if (categoryId) {
                          state = state.withJoin(
                            currentTable: table,
                            currentColumn: table.categoryId,
                            referencedTable: $$LedgerAccountsTableReferences
                                ._categoryIdTable(db),
                            referencedColumn: $$LedgerAccountsTableReferences
                                ._categoryIdTable(db)
                                .categoryId,
                          ) as T;
                        }

                        return state;
                      },
                  getPrefetchedDataCallback: (items) async {
                    return [
                      if (postingsRefs)
                        await $_getPrefetchedData<
                          LedgerAccount,
                          $LedgerAccountsTable,
                          Posting
                        >(
                          currentTable: table,
                          referencedTable: $$LedgerAccountsTableReferences
                              ._postingsRefsTable(db),
                          managerFromTypedResult: (p0) =>
                              $$LedgerAccountsTableReferences(
                                db,
                                table,
                                p0,
                              ).postingsRefs,
                          referencedItemsForCurrentItem:
                              (item, referencedItems) => referencedItems.where(
                                (e) =>
                                    e.ledgerAccountId == item.ledgerAccountId,
                              ),
                          typedResults: items,
                        ),
                    ];
                  },
                );
              },
        ),
      );
}

typedef $$LedgerAccountsTableProcessedTableManager =
    ProcessedTableManager<
      _$AppDatabaseV2,
      $LedgerAccountsTable,
      LedgerAccount,
      $$LedgerAccountsTableFilterComposer,
      $$LedgerAccountsTableOrderingComposer,
      $$LedgerAccountsTableAnnotationComposer,
      $$LedgerAccountsTableCreateCompanionBuilder,
      $$LedgerAccountsTableUpdateCompanionBuilder,
      (LedgerAccount, $$LedgerAccountsTableReferences),
      LedgerAccount,
      PrefetchHooks Function({
        bool userAccountId,
        bool categoryId,
        bool postingsRefs,
      })
    >;
typedef $$FinancialTransactionsTableCreateCompanionBuilder =
    FinancialTransactionsCompanion Function({
      Value<int> id,
      required String uuid,
      required String kind,
      Value<String?> categoryId,
      Value<String?> reversesTransactionId,
      Value<String?> relatedTransactionId,
      Value<String?> sourceAccountId,
      Value<String?> destinationAccountId,
      Value<String?> refundAccountId,
      required int amountMinorUnits,
      Value<String> currencyCode,
      Value<String?> description,
      Value<String?> notes,
      required String paymentChannel,
      required DateTime occurredAt,
      required String status,
      required String source,
      Value<String?> adjustmentReason,
      required DateTime createdAt,
      required DateTime updatedAt,
      Value<int> syncRevision,
      required String syncStatus,
    });
typedef $$FinancialTransactionsTableUpdateCompanionBuilder =
    FinancialTransactionsCompanion Function({
      Value<int> id,
      Value<String> uuid,
      Value<String> kind,
      Value<String?> categoryId,
      Value<String?> reversesTransactionId,
      Value<String?> relatedTransactionId,
      Value<String?> sourceAccountId,
      Value<String?> destinationAccountId,
      Value<String?> refundAccountId,
      Value<int> amountMinorUnits,
      Value<String> currencyCode,
      Value<String?> description,
      Value<String?> notes,
      Value<String> paymentChannel,
      Value<DateTime> occurredAt,
      Value<String> status,
      Value<String> source,
      Value<String?> adjustmentReason,
      Value<DateTime> createdAt,
      Value<DateTime> updatedAt,
      Value<int> syncRevision,
      Value<String> syncStatus,
    });

final class $$FinancialTransactionsTableReferences
    extends
        BaseReferences<
          _$AppDatabaseV2,
          $FinancialTransactionsTable,
          FinancialTransaction
        > {
  $$FinancialTransactionsTableReferences(
    super.$_db,
    super.$_table,
    super.$_typedResult,
  );

  static $CategoriesTable _categoryIdTable(_$AppDatabaseV2 db) =>
      db.categories.createAlias(
        'financial_transactions__category_id__categories__category_id',
      );

  $$CategoriesTableProcessedTableManager? get categoryId {
    final $_column = $_itemColumn<String>('category_id');
    if ($_column == null) return null;
    final manager = $$CategoriesTableTableManager(
      $_db,
      $_db.categories,
    ).filter((f) => f.categoryId.sqlEquals($_column));
    final item = $_typedResult.readTableOrNull(_categoryIdTable($_db));
    if (item == null) return manager;
    return ProcessedTableManager(
      manager.$state.copyWith(prefetchedData: [item]),
    );
  }

  static $FinancialTransactionsTable _reversesTransactionIdTable(
    _$AppDatabaseV2 db,
  ) => db.financialTransactions.createAlias(
    'financial_transactions__reverses_transaction_id__financial_transactions__uuid',
  );

  $$FinancialTransactionsTableProcessedTableManager? get reversesTransactionId {
    final $_column = $_itemColumn<String>('reverses_transaction_id');
    if ($_column == null) return null;
    final manager = $$FinancialTransactionsTableTableManager(
      $_db,
      $_db.financialTransactions,
    ).filter((f) => f.uuid.sqlEquals($_column));
    final item = $_typedResult.readTableOrNull(
      _reversesTransactionIdTable($_db),
    );
    if (item == null) return manager;
    return ProcessedTableManager(
      manager.$state.copyWith(prefetchedData: [item]),
    );
  }

  static $FinancialTransactionsTable _relatedTransactionIdTable(
    _$AppDatabaseV2 db,
  ) => db.financialTransactions.createAlias(
    'financial_transactions__related_transaction_id__financial_transactions__uuid',
  );

  $$FinancialTransactionsTableProcessedTableManager? get relatedTransactionId {
    final $_column = $_itemColumn<String>('related_transaction_id');
    if ($_column == null) return null;
    final manager = $$FinancialTransactionsTableTableManager(
      $_db,
      $_db.financialTransactions,
    ).filter((f) => f.uuid.sqlEquals($_column));
    final item = $_typedResult.readTableOrNull(
      _relatedTransactionIdTable($_db),
    );
    if (item == null) return manager;
    return ProcessedTableManager(
      manager.$state.copyWith(prefetchedData: [item]),
    );
  }

  static $AccountsTable _sourceAccountIdTable(_$AppDatabaseV2 db) => db.accounts
      .createAlias('financial_transactions__source_account_id__accounts__uuid');

  $$AccountsTableProcessedTableManager? get sourceAccountId {
    final $_column = $_itemColumn<String>('source_account_id');
    if ($_column == null) return null;
    final manager = $$AccountsTableTableManager(
      $_db,
      $_db.accounts,
    ).filter((f) => f.uuid.sqlEquals($_column));
    final item = $_typedResult.readTableOrNull(_sourceAccountIdTable($_db));
    if (item == null) return manager;
    return ProcessedTableManager(
      manager.$state.copyWith(prefetchedData: [item]),
    );
  }

  static $AccountsTable _destinationAccountIdTable(_$AppDatabaseV2 db) =>
      db.accounts.createAlias(
        'financial_transactions__destination_account_id__accounts__uuid',
      );

  $$AccountsTableProcessedTableManager? get destinationAccountId {
    final $_column = $_itemColumn<String>('destination_account_id');
    if ($_column == null) return null;
    final manager = $$AccountsTableTableManager(
      $_db,
      $_db.accounts,
    ).filter((f) => f.uuid.sqlEquals($_column));
    final item = $_typedResult.readTableOrNull(
      _destinationAccountIdTable($_db),
    );
    if (item == null) return manager;
    return ProcessedTableManager(
      manager.$state.copyWith(prefetchedData: [item]),
    );
  }

  static $AccountsTable _refundAccountIdTable(_$AppDatabaseV2 db) => db.accounts
      .createAlias('financial_transactions__refund_account_id__accounts__uuid');

  $$AccountsTableProcessedTableManager? get refundAccountId {
    final $_column = $_itemColumn<String>('refund_account_id');
    if ($_column == null) return null;
    final manager = $$AccountsTableTableManager(
      $_db,
      $_db.accounts,
    ).filter((f) => f.uuid.sqlEquals($_column));
    final item = $_typedResult.readTableOrNull(_refundAccountIdTable($_db));
    if (item == null) return manager;
    return ProcessedTableManager(
      manager.$state.copyWith(prefetchedData: [item]),
    );
  }

  static MultiTypedResultKey<$PostingsTable, List<Posting>> _postingsRefsTable(
    _$AppDatabaseV2 db,
  ) => MultiTypedResultKey.fromTable(
    db.postings,
    aliasName: 'financial_transactions__id__postings__transaction_id',
  );

  $$PostingsTableProcessedTableManager get postingsRefs {
    final manager = $$PostingsTableTableManager(
      $_db,
      $_db.postings,
    ).filter((f) => f.transactionId.id.sqlEquals($_itemColumn<int>('id')!));

    final cache = $_typedResult.readTableOrNull(_postingsRefsTable($_db));
    return ProcessedTableManager(
      manager.$state.copyWith(prefetchedData: cache),
    );
  }

  static MultiTypedResultKey<
    $TransactionHistoryTable,
    List<TransactionHistoryData>
  >
  _transactionHistoryRefsTable(_$AppDatabaseV2 db) =>
      MultiTypedResultKey.fromTable(
        db.transactionHistory,
        aliasName:
            'financial_transactions__id__transaction_history__transaction_id',
      );

  $$TransactionHistoryTableProcessedTableManager get transactionHistoryRefs {
    final manager = $$TransactionHistoryTableTableManager(
      $_db,
      $_db.transactionHistory,
    ).filter((f) => f.transactionId.id.sqlEquals($_itemColumn<int>('id')!));

    final cache = $_typedResult.readTableOrNull(
      _transactionHistoryRefsTable($_db),
    );
    return ProcessedTableManager(
      manager.$state.copyWith(prefetchedData: cache),
    );
  }
}

class $$FinancialTransactionsTableFilterComposer
    extends Composer<_$AppDatabaseV2, $FinancialTransactionsTable> {
  $$FinancialTransactionsTableFilterComposer({
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

  ColumnFilters<String> get uuid => $composableBuilder(
    column: $table.uuid,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<String> get kind => $composableBuilder(
    column: $table.kind,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<int> get amountMinorUnits => $composableBuilder(
    column: $table.amountMinorUnits,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<String> get currencyCode => $composableBuilder(
    column: $table.currencyCode,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<String> get description => $composableBuilder(
    column: $table.description,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<String> get notes => $composableBuilder(
    column: $table.notes,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<String> get paymentChannel => $composableBuilder(
    column: $table.paymentChannel,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<DateTime> get occurredAt => $composableBuilder(
    column: $table.occurredAt,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<String> get status => $composableBuilder(
    column: $table.status,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<String> get source => $composableBuilder(
    column: $table.source,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<String> get adjustmentReason => $composableBuilder(
    column: $table.adjustmentReason,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<DateTime> get createdAt => $composableBuilder(
    column: $table.createdAt,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<DateTime> get updatedAt => $composableBuilder(
    column: $table.updatedAt,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<int> get syncRevision => $composableBuilder(
    column: $table.syncRevision,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<String> get syncStatus => $composableBuilder(
    column: $table.syncStatus,
    builder: (column) => ColumnFilters(column),
  );

  $$CategoriesTableFilterComposer get categoryId {
    final $$CategoriesTableFilterComposer composer = $composerBuilder(
      composer: this,
      getCurrentColumn: (t) => t.categoryId,
      referencedTable: $db.categories,
      getReferencedColumn: (t) => t.categoryId,
      builder:
          (
            joinBuilder, {
            $addJoinBuilderToRootComposer,
            $removeJoinBuilderFromRootComposer,
          }) => $$CategoriesTableFilterComposer(
            $db: $db,
            $table: $db.categories,
            $addJoinBuilderToRootComposer: $addJoinBuilderToRootComposer,
            joinBuilder: joinBuilder,
            $removeJoinBuilderFromRootComposer:
                $removeJoinBuilderFromRootComposer,
          ),
    );
    return composer;
  }

  $$FinancialTransactionsTableFilterComposer get reversesTransactionId {
    final $$FinancialTransactionsTableFilterComposer composer =
        $composerBuilder(
          composer: this,
          getCurrentColumn: (t) => t.reversesTransactionId,
          referencedTable: $db.financialTransactions,
          getReferencedColumn: (t) => t.uuid,
          builder:
              (
                joinBuilder, {
                $addJoinBuilderToRootComposer,
                $removeJoinBuilderFromRootComposer,
              }) => $$FinancialTransactionsTableFilterComposer(
                $db: $db,
                $table: $db.financialTransactions,
                $addJoinBuilderToRootComposer: $addJoinBuilderToRootComposer,
                joinBuilder: joinBuilder,
                $removeJoinBuilderFromRootComposer:
                    $removeJoinBuilderFromRootComposer,
              ),
        );
    return composer;
  }

  $$FinancialTransactionsTableFilterComposer get relatedTransactionId {
    final $$FinancialTransactionsTableFilterComposer composer =
        $composerBuilder(
          composer: this,
          getCurrentColumn: (t) => t.relatedTransactionId,
          referencedTable: $db.financialTransactions,
          getReferencedColumn: (t) => t.uuid,
          builder:
              (
                joinBuilder, {
                $addJoinBuilderToRootComposer,
                $removeJoinBuilderFromRootComposer,
              }) => $$FinancialTransactionsTableFilterComposer(
                $db: $db,
                $table: $db.financialTransactions,
                $addJoinBuilderToRootComposer: $addJoinBuilderToRootComposer,
                joinBuilder: joinBuilder,
                $removeJoinBuilderFromRootComposer:
                    $removeJoinBuilderFromRootComposer,
              ),
        );
    return composer;
  }

  $$AccountsTableFilterComposer get sourceAccountId {
    final $$AccountsTableFilterComposer composer = $composerBuilder(
      composer: this,
      getCurrentColumn: (t) => t.sourceAccountId,
      referencedTable: $db.accounts,
      getReferencedColumn: (t) => t.uuid,
      builder:
          (
            joinBuilder, {
            $addJoinBuilderToRootComposer,
            $removeJoinBuilderFromRootComposer,
          }) => $$AccountsTableFilterComposer(
            $db: $db,
            $table: $db.accounts,
            $addJoinBuilderToRootComposer: $addJoinBuilderToRootComposer,
            joinBuilder: joinBuilder,
            $removeJoinBuilderFromRootComposer:
                $removeJoinBuilderFromRootComposer,
          ),
    );
    return composer;
  }

  $$AccountsTableFilterComposer get destinationAccountId {
    final $$AccountsTableFilterComposer composer = $composerBuilder(
      composer: this,
      getCurrentColumn: (t) => t.destinationAccountId,
      referencedTable: $db.accounts,
      getReferencedColumn: (t) => t.uuid,
      builder:
          (
            joinBuilder, {
            $addJoinBuilderToRootComposer,
            $removeJoinBuilderFromRootComposer,
          }) => $$AccountsTableFilterComposer(
            $db: $db,
            $table: $db.accounts,
            $addJoinBuilderToRootComposer: $addJoinBuilderToRootComposer,
            joinBuilder: joinBuilder,
            $removeJoinBuilderFromRootComposer:
                $removeJoinBuilderFromRootComposer,
          ),
    );
    return composer;
  }

  $$AccountsTableFilterComposer get refundAccountId {
    final $$AccountsTableFilterComposer composer = $composerBuilder(
      composer: this,
      getCurrentColumn: (t) => t.refundAccountId,
      referencedTable: $db.accounts,
      getReferencedColumn: (t) => t.uuid,
      builder:
          (
            joinBuilder, {
            $addJoinBuilderToRootComposer,
            $removeJoinBuilderFromRootComposer,
          }) => $$AccountsTableFilterComposer(
            $db: $db,
            $table: $db.accounts,
            $addJoinBuilderToRootComposer: $addJoinBuilderToRootComposer,
            joinBuilder: joinBuilder,
            $removeJoinBuilderFromRootComposer:
                $removeJoinBuilderFromRootComposer,
          ),
    );
    return composer;
  }

  Expression<bool> postingsRefs(
    Expression<bool> Function($$PostingsTableFilterComposer f) f,
  ) {
    final $$PostingsTableFilterComposer composer = $composerBuilder(
      composer: this,
      getCurrentColumn: (t) => t.id,
      referencedTable: $db.postings,
      getReferencedColumn: (t) => t.transactionId,
      builder:
          (
            joinBuilder, {
            $addJoinBuilderToRootComposer,
            $removeJoinBuilderFromRootComposer,
          }) => $$PostingsTableFilterComposer(
            $db: $db,
            $table: $db.postings,
            $addJoinBuilderToRootComposer: $addJoinBuilderToRootComposer,
            joinBuilder: joinBuilder,
            $removeJoinBuilderFromRootComposer:
                $removeJoinBuilderFromRootComposer,
          ),
    );
    return f(composer);
  }

  Expression<bool> transactionHistoryRefs(
    Expression<bool> Function($$TransactionHistoryTableFilterComposer f) f,
  ) {
    final $$TransactionHistoryTableFilterComposer composer = $composerBuilder(
      composer: this,
      getCurrentColumn: (t) => t.id,
      referencedTable: $db.transactionHistory,
      getReferencedColumn: (t) => t.transactionId,
      builder:
          (
            joinBuilder, {
            $addJoinBuilderToRootComposer,
            $removeJoinBuilderFromRootComposer,
          }) => $$TransactionHistoryTableFilterComposer(
            $db: $db,
            $table: $db.transactionHistory,
            $addJoinBuilderToRootComposer: $addJoinBuilderToRootComposer,
            joinBuilder: joinBuilder,
            $removeJoinBuilderFromRootComposer:
                $removeJoinBuilderFromRootComposer,
          ),
    );
    return f(composer);
  }
}

class $$FinancialTransactionsTableOrderingComposer
    extends Composer<_$AppDatabaseV2, $FinancialTransactionsTable> {
  $$FinancialTransactionsTableOrderingComposer({
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

  ColumnOrderings<String> get uuid => $composableBuilder(
    column: $table.uuid,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<String> get kind => $composableBuilder(
    column: $table.kind,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<int> get amountMinorUnits => $composableBuilder(
    column: $table.amountMinorUnits,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<String> get currencyCode => $composableBuilder(
    column: $table.currencyCode,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<String> get description => $composableBuilder(
    column: $table.description,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<String> get notes => $composableBuilder(
    column: $table.notes,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<String> get paymentChannel => $composableBuilder(
    column: $table.paymentChannel,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<DateTime> get occurredAt => $composableBuilder(
    column: $table.occurredAt,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<String> get status => $composableBuilder(
    column: $table.status,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<String> get source => $composableBuilder(
    column: $table.source,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<String> get adjustmentReason => $composableBuilder(
    column: $table.adjustmentReason,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<DateTime> get createdAt => $composableBuilder(
    column: $table.createdAt,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<DateTime> get updatedAt => $composableBuilder(
    column: $table.updatedAt,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<int> get syncRevision => $composableBuilder(
    column: $table.syncRevision,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<String> get syncStatus => $composableBuilder(
    column: $table.syncStatus,
    builder: (column) => ColumnOrderings(column),
  );

  $$CategoriesTableOrderingComposer get categoryId {
    final $$CategoriesTableOrderingComposer composer = $composerBuilder(
      composer: this,
      getCurrentColumn: (t) => t.categoryId,
      referencedTable: $db.categories,
      getReferencedColumn: (t) => t.categoryId,
      builder:
          (
            joinBuilder, {
            $addJoinBuilderToRootComposer,
            $removeJoinBuilderFromRootComposer,
          }) => $$CategoriesTableOrderingComposer(
            $db: $db,
            $table: $db.categories,
            $addJoinBuilderToRootComposer: $addJoinBuilderToRootComposer,
            joinBuilder: joinBuilder,
            $removeJoinBuilderFromRootComposer:
                $removeJoinBuilderFromRootComposer,
          ),
    );
    return composer;
  }

  $$FinancialTransactionsTableOrderingComposer get reversesTransactionId {
    final $$FinancialTransactionsTableOrderingComposer composer =
        $composerBuilder(
          composer: this,
          getCurrentColumn: (t) => t.reversesTransactionId,
          referencedTable: $db.financialTransactions,
          getReferencedColumn: (t) => t.uuid,
          builder:
              (
                joinBuilder, {
                $addJoinBuilderToRootComposer,
                $removeJoinBuilderFromRootComposer,
              }) => $$FinancialTransactionsTableOrderingComposer(
                $db: $db,
                $table: $db.financialTransactions,
                $addJoinBuilderToRootComposer: $addJoinBuilderToRootComposer,
                joinBuilder: joinBuilder,
                $removeJoinBuilderFromRootComposer:
                    $removeJoinBuilderFromRootComposer,
              ),
        );
    return composer;
  }

  $$FinancialTransactionsTableOrderingComposer get relatedTransactionId {
    final $$FinancialTransactionsTableOrderingComposer composer =
        $composerBuilder(
          composer: this,
          getCurrentColumn: (t) => t.relatedTransactionId,
          referencedTable: $db.financialTransactions,
          getReferencedColumn: (t) => t.uuid,
          builder:
              (
                joinBuilder, {
                $addJoinBuilderToRootComposer,
                $removeJoinBuilderFromRootComposer,
              }) => $$FinancialTransactionsTableOrderingComposer(
                $db: $db,
                $table: $db.financialTransactions,
                $addJoinBuilderToRootComposer: $addJoinBuilderToRootComposer,
                joinBuilder: joinBuilder,
                $removeJoinBuilderFromRootComposer:
                    $removeJoinBuilderFromRootComposer,
              ),
        );
    return composer;
  }

  $$AccountsTableOrderingComposer get sourceAccountId {
    final $$AccountsTableOrderingComposer composer = $composerBuilder(
      composer: this,
      getCurrentColumn: (t) => t.sourceAccountId,
      referencedTable: $db.accounts,
      getReferencedColumn: (t) => t.uuid,
      builder:
          (
            joinBuilder, {
            $addJoinBuilderToRootComposer,
            $removeJoinBuilderFromRootComposer,
          }) => $$AccountsTableOrderingComposer(
            $db: $db,
            $table: $db.accounts,
            $addJoinBuilderToRootComposer: $addJoinBuilderToRootComposer,
            joinBuilder: joinBuilder,
            $removeJoinBuilderFromRootComposer:
                $removeJoinBuilderFromRootComposer,
          ),
    );
    return composer;
  }

  $$AccountsTableOrderingComposer get destinationAccountId {
    final $$AccountsTableOrderingComposer composer = $composerBuilder(
      composer: this,
      getCurrentColumn: (t) => t.destinationAccountId,
      referencedTable: $db.accounts,
      getReferencedColumn: (t) => t.uuid,
      builder:
          (
            joinBuilder, {
            $addJoinBuilderToRootComposer,
            $removeJoinBuilderFromRootComposer,
          }) => $$AccountsTableOrderingComposer(
            $db: $db,
            $table: $db.accounts,
            $addJoinBuilderToRootComposer: $addJoinBuilderToRootComposer,
            joinBuilder: joinBuilder,
            $removeJoinBuilderFromRootComposer:
                $removeJoinBuilderFromRootComposer,
          ),
    );
    return composer;
  }

  $$AccountsTableOrderingComposer get refundAccountId {
    final $$AccountsTableOrderingComposer composer = $composerBuilder(
      composer: this,
      getCurrentColumn: (t) => t.refundAccountId,
      referencedTable: $db.accounts,
      getReferencedColumn: (t) => t.uuid,
      builder:
          (
            joinBuilder, {
            $addJoinBuilderToRootComposer,
            $removeJoinBuilderFromRootComposer,
          }) => $$AccountsTableOrderingComposer(
            $db: $db,
            $table: $db.accounts,
            $addJoinBuilderToRootComposer: $addJoinBuilderToRootComposer,
            joinBuilder: joinBuilder,
            $removeJoinBuilderFromRootComposer:
                $removeJoinBuilderFromRootComposer,
          ),
    );
    return composer;
  }
}

class $$FinancialTransactionsTableAnnotationComposer
    extends Composer<_$AppDatabaseV2, $FinancialTransactionsTable> {
  $$FinancialTransactionsTableAnnotationComposer({
    required super.$db,
    required super.$table,
    super.joinBuilder,
    super.$addJoinBuilderToRootComposer,
    super.$removeJoinBuilderFromRootComposer,
  });
  GeneratedColumn<int> get id =>
      $composableBuilder(column: $table.id, builder: (column) => column);

  GeneratedColumn<String> get uuid =>
      $composableBuilder(column: $table.uuid, builder: (column) => column);

  GeneratedColumn<String> get kind =>
      $composableBuilder(column: $table.kind, builder: (column) => column);

  GeneratedColumn<int> get amountMinorUnits => $composableBuilder(
    column: $table.amountMinorUnits,
    builder: (column) => column,
  );

  GeneratedColumn<String> get currencyCode => $composableBuilder(
    column: $table.currencyCode,
    builder: (column) => column,
  );

  GeneratedColumn<String> get description => $composableBuilder(
    column: $table.description,
    builder: (column) => column,
  );

  GeneratedColumn<String> get notes =>
      $composableBuilder(column: $table.notes, builder: (column) => column);

  GeneratedColumn<String> get paymentChannel => $composableBuilder(
    column: $table.paymentChannel,
    builder: (column) => column,
  );

  GeneratedColumn<DateTime> get occurredAt => $composableBuilder(
    column: $table.occurredAt,
    builder: (column) => column,
  );

  GeneratedColumn<String> get status =>
      $composableBuilder(column: $table.status, builder: (column) => column);

  GeneratedColumn<String> get source =>
      $composableBuilder(column: $table.source, builder: (column) => column);

  GeneratedColumn<String> get adjustmentReason => $composableBuilder(
    column: $table.adjustmentReason,
    builder: (column) => column,
  );

  GeneratedColumn<DateTime> get createdAt =>
      $composableBuilder(column: $table.createdAt, builder: (column) => column);

  GeneratedColumn<DateTime> get updatedAt =>
      $composableBuilder(column: $table.updatedAt, builder: (column) => column);

  GeneratedColumn<int> get syncRevision => $composableBuilder(
    column: $table.syncRevision,
    builder: (column) => column,
  );

  GeneratedColumn<String> get syncStatus => $composableBuilder(
    column: $table.syncStatus,
    builder: (column) => column,
  );

  $$CategoriesTableAnnotationComposer get categoryId {
    final $$CategoriesTableAnnotationComposer composer = $composerBuilder(
      composer: this,
      getCurrentColumn: (t) => t.categoryId,
      referencedTable: $db.categories,
      getReferencedColumn: (t) => t.categoryId,
      builder:
          (
            joinBuilder, {
            $addJoinBuilderToRootComposer,
            $removeJoinBuilderFromRootComposer,
          }) => $$CategoriesTableAnnotationComposer(
            $db: $db,
            $table: $db.categories,
            $addJoinBuilderToRootComposer: $addJoinBuilderToRootComposer,
            joinBuilder: joinBuilder,
            $removeJoinBuilderFromRootComposer:
                $removeJoinBuilderFromRootComposer,
          ),
    );
    return composer;
  }

  $$FinancialTransactionsTableAnnotationComposer get reversesTransactionId {
    final $$FinancialTransactionsTableAnnotationComposer composer =
        $composerBuilder(
          composer: this,
          getCurrentColumn: (t) => t.reversesTransactionId,
          referencedTable: $db.financialTransactions,
          getReferencedColumn: (t) => t.uuid,
          builder:
              (
                joinBuilder, {
                $addJoinBuilderToRootComposer,
                $removeJoinBuilderFromRootComposer,
              }) => $$FinancialTransactionsTableAnnotationComposer(
                $db: $db,
                $table: $db.financialTransactions,
                $addJoinBuilderToRootComposer: $addJoinBuilderToRootComposer,
                joinBuilder: joinBuilder,
                $removeJoinBuilderFromRootComposer:
                    $removeJoinBuilderFromRootComposer,
              ),
        );
    return composer;
  }

  $$FinancialTransactionsTableAnnotationComposer get relatedTransactionId {
    final $$FinancialTransactionsTableAnnotationComposer composer =
        $composerBuilder(
          composer: this,
          getCurrentColumn: (t) => t.relatedTransactionId,
          referencedTable: $db.financialTransactions,
          getReferencedColumn: (t) => t.uuid,
          builder:
              (
                joinBuilder, {
                $addJoinBuilderToRootComposer,
                $removeJoinBuilderFromRootComposer,
              }) => $$FinancialTransactionsTableAnnotationComposer(
                $db: $db,
                $table: $db.financialTransactions,
                $addJoinBuilderToRootComposer: $addJoinBuilderToRootComposer,
                joinBuilder: joinBuilder,
                $removeJoinBuilderFromRootComposer:
                    $removeJoinBuilderFromRootComposer,
              ),
        );
    return composer;
  }

  $$AccountsTableAnnotationComposer get sourceAccountId {
    final $$AccountsTableAnnotationComposer composer = $composerBuilder(
      composer: this,
      getCurrentColumn: (t) => t.sourceAccountId,
      referencedTable: $db.accounts,
      getReferencedColumn: (t) => t.uuid,
      builder:
          (
            joinBuilder, {
            $addJoinBuilderToRootComposer,
            $removeJoinBuilderFromRootComposer,
          }) => $$AccountsTableAnnotationComposer(
            $db: $db,
            $table: $db.accounts,
            $addJoinBuilderToRootComposer: $addJoinBuilderToRootComposer,
            joinBuilder: joinBuilder,
            $removeJoinBuilderFromRootComposer:
                $removeJoinBuilderFromRootComposer,
          ),
    );
    return composer;
  }

  $$AccountsTableAnnotationComposer get destinationAccountId {
    final $$AccountsTableAnnotationComposer composer = $composerBuilder(
      composer: this,
      getCurrentColumn: (t) => t.destinationAccountId,
      referencedTable: $db.accounts,
      getReferencedColumn: (t) => t.uuid,
      builder:
          (
            joinBuilder, {
            $addJoinBuilderToRootComposer,
            $removeJoinBuilderFromRootComposer,
          }) => $$AccountsTableAnnotationComposer(
            $db: $db,
            $table: $db.accounts,
            $addJoinBuilderToRootComposer: $addJoinBuilderToRootComposer,
            joinBuilder: joinBuilder,
            $removeJoinBuilderFromRootComposer:
                $removeJoinBuilderFromRootComposer,
          ),
    );
    return composer;
  }

  $$AccountsTableAnnotationComposer get refundAccountId {
    final $$AccountsTableAnnotationComposer composer = $composerBuilder(
      composer: this,
      getCurrentColumn: (t) => t.refundAccountId,
      referencedTable: $db.accounts,
      getReferencedColumn: (t) => t.uuid,
      builder:
          (
            joinBuilder, {
            $addJoinBuilderToRootComposer,
            $removeJoinBuilderFromRootComposer,
          }) => $$AccountsTableAnnotationComposer(
            $db: $db,
            $table: $db.accounts,
            $addJoinBuilderToRootComposer: $addJoinBuilderToRootComposer,
            joinBuilder: joinBuilder,
            $removeJoinBuilderFromRootComposer:
                $removeJoinBuilderFromRootComposer,
          ),
    );
    return composer;
  }

  Expression<T> postingsRefs<T extends Object>(
    Expression<T> Function($$PostingsTableAnnotationComposer a) f,
  ) {
    final $$PostingsTableAnnotationComposer composer = $composerBuilder(
      composer: this,
      getCurrentColumn: (t) => t.id,
      referencedTable: $db.postings,
      getReferencedColumn: (t) => t.transactionId,
      builder:
          (
            joinBuilder, {
            $addJoinBuilderToRootComposer,
            $removeJoinBuilderFromRootComposer,
          }) => $$PostingsTableAnnotationComposer(
            $db: $db,
            $table: $db.postings,
            $addJoinBuilderToRootComposer: $addJoinBuilderToRootComposer,
            joinBuilder: joinBuilder,
            $removeJoinBuilderFromRootComposer:
                $removeJoinBuilderFromRootComposer,
          ),
    );
    return f(composer);
  }

  Expression<T> transactionHistoryRefs<T extends Object>(
    Expression<T> Function($$TransactionHistoryTableAnnotationComposer a) f,
  ) {
    final $$TransactionHistoryTableAnnotationComposer composer =
        $composerBuilder(
          composer: this,
          getCurrentColumn: (t) => t.id,
          referencedTable: $db.transactionHistory,
          getReferencedColumn: (t) => t.transactionId,
          builder:
              (
                joinBuilder, {
                $addJoinBuilderToRootComposer,
                $removeJoinBuilderFromRootComposer,
              }) => $$TransactionHistoryTableAnnotationComposer(
                $db: $db,
                $table: $db.transactionHistory,
                $addJoinBuilderToRootComposer: $addJoinBuilderToRootComposer,
                joinBuilder: joinBuilder,
                $removeJoinBuilderFromRootComposer:
                    $removeJoinBuilderFromRootComposer,
              ),
        );
    return f(composer);
  }
}

class $$FinancialTransactionsTableTableManager
    extends
        RootTableManager<
          _$AppDatabaseV2,
          $FinancialTransactionsTable,
          FinancialTransaction,
          $$FinancialTransactionsTableFilterComposer,
          $$FinancialTransactionsTableOrderingComposer,
          $$FinancialTransactionsTableAnnotationComposer,
          $$FinancialTransactionsTableCreateCompanionBuilder,
          $$FinancialTransactionsTableUpdateCompanionBuilder,
          (FinancialTransaction, $$FinancialTransactionsTableReferences),
          FinancialTransaction,
          PrefetchHooks Function({
            bool categoryId,
            bool reversesTransactionId,
            bool relatedTransactionId,
            bool sourceAccountId,
            bool destinationAccountId,
            bool refundAccountId,
            bool postingsRefs,
            bool transactionHistoryRefs,
          })
        > {
  $$FinancialTransactionsTableTableManager(
    _$AppDatabaseV2 db,
    $FinancialTransactionsTable table,
  ) : super(
        TableManagerState(
          db: db,
          table: table,
          createFilteringComposer: () =>
              $$FinancialTransactionsTableFilterComposer(
                $db: db,
                $table: table,
              ),
          createOrderingComposer: () =>
              $$FinancialTransactionsTableOrderingComposer(
                $db: db,
                $table: table,
              ),
          createComputedFieldComposer: () =>
              $$FinancialTransactionsTableAnnotationComposer(
                $db: db,
                $table: table,
              ),
          updateCompanionCallback:
              ({
                Value<int> id = const Value.absent(),
                Value<String> uuid = const Value.absent(),
                Value<String> kind = const Value.absent(),
                Value<String?> categoryId = const Value.absent(),
                Value<String?> reversesTransactionId = const Value.absent(),
                Value<String?> relatedTransactionId = const Value.absent(),
                Value<String?> sourceAccountId = const Value.absent(),
                Value<String?> destinationAccountId = const Value.absent(),
                Value<String?> refundAccountId = const Value.absent(),
                Value<int> amountMinorUnits = const Value.absent(),
                Value<String> currencyCode = const Value.absent(),
                Value<String?> description = const Value.absent(),
                Value<String?> notes = const Value.absent(),
                Value<String> paymentChannel = const Value.absent(),
                Value<DateTime> occurredAt = const Value.absent(),
                Value<String> status = const Value.absent(),
                Value<String> source = const Value.absent(),
                Value<String?> adjustmentReason = const Value.absent(),
                Value<DateTime> createdAt = const Value.absent(),
                Value<DateTime> updatedAt = const Value.absent(),
                Value<int> syncRevision = const Value.absent(),
                Value<String> syncStatus = const Value.absent(),
              }) => FinancialTransactionsCompanion(
                id: id,
                uuid: uuid,
                kind: kind,
                categoryId: categoryId,
                reversesTransactionId: reversesTransactionId,
                relatedTransactionId: relatedTransactionId,
                sourceAccountId: sourceAccountId,
                destinationAccountId: destinationAccountId,
                refundAccountId: refundAccountId,
                amountMinorUnits: amountMinorUnits,
                currencyCode: currencyCode,
                description: description,
                notes: notes,
                paymentChannel: paymentChannel,
                occurredAt: occurredAt,
                status: status,
                source: source,
                adjustmentReason: adjustmentReason,
                createdAt: createdAt,
                updatedAt: updatedAt,
                syncRevision: syncRevision,
                syncStatus: syncStatus,
              ),
          createCompanionCallback:
              ({
                Value<int> id = const Value.absent(),
                required String uuid,
                required String kind,
                Value<String?> categoryId = const Value.absent(),
                Value<String?> reversesTransactionId = const Value.absent(),
                Value<String?> relatedTransactionId = const Value.absent(),
                Value<String?> sourceAccountId = const Value.absent(),
                Value<String?> destinationAccountId = const Value.absent(),
                Value<String?> refundAccountId = const Value.absent(),
                required int amountMinorUnits,
                Value<String> currencyCode = const Value.absent(),
                Value<String?> description = const Value.absent(),
                Value<String?> notes = const Value.absent(),
                required String paymentChannel,
                required DateTime occurredAt,
                required String status,
                required String source,
                Value<String?> adjustmentReason = const Value.absent(),
                required DateTime createdAt,
                required DateTime updatedAt,
                Value<int> syncRevision = const Value.absent(),
                required String syncStatus,
              }) => FinancialTransactionsCompanion.insert(
                id: id,
                uuid: uuid,
                kind: kind,
                categoryId: categoryId,
                reversesTransactionId: reversesTransactionId,
                relatedTransactionId: relatedTransactionId,
                sourceAccountId: sourceAccountId,
                destinationAccountId: destinationAccountId,
                refundAccountId: refundAccountId,
                amountMinorUnits: amountMinorUnits,
                currencyCode: currencyCode,
                description: description,
                notes: notes,
                paymentChannel: paymentChannel,
                occurredAt: occurredAt,
                status: status,
                source: source,
                adjustmentReason: adjustmentReason,
                createdAt: createdAt,
                updatedAt: updatedAt,
                syncRevision: syncRevision,
                syncStatus: syncStatus,
              ),
          withReferenceMapper: (p0) => p0
              .map(
                (e) => (
                  e.readTable<
                    $FinancialTransactionsTable,
                    FinancialTransaction
                  >(table),
                  $$FinancialTransactionsTableReferences(db, table, e),
                ),
              )
              .toList(),
          prefetchHooksCallback:
              ({
                categoryId = false,
                reversesTransactionId = false,
                relatedTransactionId = false,
                sourceAccountId = false,
                destinationAccountId = false,
                refundAccountId = false,
                postingsRefs = false,
                transactionHistoryRefs = false,
              }) {
                return PrefetchHooks(
                  db: db,
                  explicitlyWatchedTables: [
                    if (postingsRefs) db.postings,
                    if (transactionHistoryRefs) db.transactionHistory,
                  ],
                  addJoins:
                      <
                        T extends TableManagerState<
                          dynamic,
                          dynamic,
                          dynamic,
                          dynamic,
                          dynamic,
                          dynamic,
                          dynamic,
                          dynamic,
                          dynamic,
                          dynamic,
                          dynamic
                        >
                      >(state) {
                        if (categoryId) {
                          state = state.withJoin(
                            currentTable: table,
                            currentColumn: table.categoryId,
                            referencedTable:
                                $$FinancialTransactionsTableReferences
                                    ._categoryIdTable(db),
                            referencedColumn:
                                $$FinancialTransactionsTableReferences
                                    ._categoryIdTable(db)
                                    .categoryId,
                          ) as T;
                        }
                        if (reversesTransactionId) {
                          state = state.withJoin(
                            currentTable: table,
                            currentColumn: table.reversesTransactionId,
                            referencedTable:
                                $$FinancialTransactionsTableReferences
                                    ._reversesTransactionIdTable(db),
                            referencedColumn:
                                $$FinancialTransactionsTableReferences
                                    ._reversesTransactionIdTable(db)
                                    .uuid,
                          ) as T;
                        }
                        if (relatedTransactionId) {
                          state = state.withJoin(
                            currentTable: table,
                            currentColumn: table.relatedTransactionId,
                            referencedTable:
                                $$FinancialTransactionsTableReferences
                                    ._relatedTransactionIdTable(db),
                            referencedColumn:
                                $$FinancialTransactionsTableReferences
                                    ._relatedTransactionIdTable(db)
                                    .uuid,
                          ) as T;
                        }
                        if (sourceAccountId) {
                          state = state.withJoin(
                            currentTable: table,
                            currentColumn: table.sourceAccountId,
                            referencedTable:
                                $$FinancialTransactionsTableReferences
                                    ._sourceAccountIdTable(db),
                            referencedColumn:
                                $$FinancialTransactionsTableReferences
                                    ._sourceAccountIdTable(db)
                                    .uuid,
                          ) as T;
                        }
                        if (destinationAccountId) {
                          state = state.withJoin(
                            currentTable: table,
                            currentColumn: table.destinationAccountId,
                            referencedTable:
                                $$FinancialTransactionsTableReferences
                                    ._destinationAccountIdTable(db),
                            referencedColumn:
                                $$FinancialTransactionsTableReferences
                                    ._destinationAccountIdTable(db)
                                    .uuid,
                          ) as T;
                        }
                        if (refundAccountId) {
                          state = state.withJoin(
                            currentTable: table,
                            currentColumn: table.refundAccountId,
                            referencedTable:
                                $$FinancialTransactionsTableReferences
                                    ._refundAccountIdTable(db),
                            referencedColumn:
                                $$FinancialTransactionsTableReferences
                                    ._refundAccountIdTable(db)
                                    .uuid,
                          ) as T;
                        }

                        return state;
                      },
                  getPrefetchedDataCallback: (items) async {
                    return [
                      if (postingsRefs)
                        await $_getPrefetchedData<
                          FinancialTransaction,
                          $FinancialTransactionsTable,
                          Posting
                        >(
                          currentTable: table,
                          referencedTable:
                              $$FinancialTransactionsTableReferences
                                  ._postingsRefsTable(db),
                          managerFromTypedResult: (p0) =>
                              $$FinancialTransactionsTableReferences(
                                db,
                                table,
                                p0,
                              ).postingsRefs,
                          referencedItemsForCurrentItem:
                              (item, referencedItems) => referencedItems.where(
                                (e) => e.transactionId == item.id,
                              ),
                          typedResults: items,
                        ),
                      if (transactionHistoryRefs)
                        await $_getPrefetchedData<
                          FinancialTransaction,
                          $FinancialTransactionsTable,
                          TransactionHistoryData
                        >(
                          currentTable: table,
                          referencedTable:
                              $$FinancialTransactionsTableReferences
                                  ._transactionHistoryRefsTable(db),
                          managerFromTypedResult: (p0) =>
                              $$FinancialTransactionsTableReferences(
                                db,
                                table,
                                p0,
                              ).transactionHistoryRefs,
                          referencedItemsForCurrentItem:
                              (item, referencedItems) => referencedItems.where(
                                (e) => e.transactionId == item.id,
                              ),
                          typedResults: items,
                        ),
                    ];
                  },
                );
              },
        ),
      );
}

typedef $$FinancialTransactionsTableProcessedTableManager =
    ProcessedTableManager<
      _$AppDatabaseV2,
      $FinancialTransactionsTable,
      FinancialTransaction,
      $$FinancialTransactionsTableFilterComposer,
      $$FinancialTransactionsTableOrderingComposer,
      $$FinancialTransactionsTableAnnotationComposer,
      $$FinancialTransactionsTableCreateCompanionBuilder,
      $$FinancialTransactionsTableUpdateCompanionBuilder,
      (FinancialTransaction, $$FinancialTransactionsTableReferences),
      FinancialTransaction,
      PrefetchHooks Function({
        bool categoryId,
        bool reversesTransactionId,
        bool relatedTransactionId,
        bool sourceAccountId,
        bool destinationAccountId,
        bool refundAccountId,
        bool postingsRefs,
        bool transactionHistoryRefs,
      })
    >;
typedef $$PostingsTableCreateCompanionBuilder = PostingsCompanion Function({
  Value<int> id,
  required String uuid,
  required int transactionId,
  required String ledgerAccountId,
  required String direction,
  required int amountMinorUnits,
  Value<String> currencyCode,
  required DateTime postingDate,
});
typedef $$PostingsTableUpdateCompanionBuilder = PostingsCompanion Function({
  Value<int> id,
  Value<String> uuid,
  Value<int> transactionId,
  Value<String> ledgerAccountId,
  Value<String> direction,
  Value<int> amountMinorUnits,
  Value<String> currencyCode,
  Value<DateTime> postingDate,
});

final class $$PostingsTableReferences
    extends BaseReferences<_$AppDatabaseV2, $PostingsTable, Posting> {
  $$PostingsTableReferences(super.$_db, super.$_table, super.$_typedResult);

  static $FinancialTransactionsTable _transactionIdTable(_$AppDatabaseV2 db) =>
      db.financialTransactions.createAlias(
        'postings__transaction_id__financial_transactions__id',
      );

  $$FinancialTransactionsTableProcessedTableManager get transactionId {
    final $_column = $_itemColumn<int>('transaction_id')!;

    final manager = $$FinancialTransactionsTableTableManager(
      $_db,
      $_db.financialTransactions,
    ).filter((f) => f.id.sqlEquals($_column));
    final item = $_typedResult.readTableOrNull(_transactionIdTable($_db));
    if (item == null) return manager;
    return ProcessedTableManager(
      manager.$state.copyWith(prefetchedData: [item]),
    );
  }

  static $LedgerAccountsTable _ledgerAccountIdTable(_$AppDatabaseV2 db) =>
      db.ledgerAccounts.createAlias(
        'postings__ledger_account_id__ledger_accounts__ledger_account_id',
      );

  $$LedgerAccountsTableProcessedTableManager get ledgerAccountId {
    final $_column = $_itemColumn<String>('ledger_account_id')!;

    final manager = $$LedgerAccountsTableTableManager(
      $_db,
      $_db.ledgerAccounts,
    ).filter((f) => f.ledgerAccountId.sqlEquals($_column));
    final item = $_typedResult.readTableOrNull(_ledgerAccountIdTable($_db));
    if (item == null) return manager;
    return ProcessedTableManager(
      manager.$state.copyWith(prefetchedData: [item]),
    );
  }
}

class $$PostingsTableFilterComposer
    extends Composer<_$AppDatabaseV2, $PostingsTable> {
  $$PostingsTableFilterComposer({
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

  ColumnFilters<String> get uuid => $composableBuilder(
    column: $table.uuid,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<String> get direction => $composableBuilder(
    column: $table.direction,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<int> get amountMinorUnits => $composableBuilder(
    column: $table.amountMinorUnits,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<String> get currencyCode => $composableBuilder(
    column: $table.currencyCode,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<DateTime> get postingDate => $composableBuilder(
    column: $table.postingDate,
    builder: (column) => ColumnFilters(column),
  );

  $$FinancialTransactionsTableFilterComposer get transactionId {
    final $$FinancialTransactionsTableFilterComposer composer =
        $composerBuilder(
          composer: this,
          getCurrentColumn: (t) => t.transactionId,
          referencedTable: $db.financialTransactions,
          getReferencedColumn: (t) => t.id,
          builder:
              (
                joinBuilder, {
                $addJoinBuilderToRootComposer,
                $removeJoinBuilderFromRootComposer,
              }) => $$FinancialTransactionsTableFilterComposer(
                $db: $db,
                $table: $db.financialTransactions,
                $addJoinBuilderToRootComposer: $addJoinBuilderToRootComposer,
                joinBuilder: joinBuilder,
                $removeJoinBuilderFromRootComposer:
                    $removeJoinBuilderFromRootComposer,
              ),
        );
    return composer;
  }

  $$LedgerAccountsTableFilterComposer get ledgerAccountId {
    final $$LedgerAccountsTableFilterComposer composer = $composerBuilder(
      composer: this,
      getCurrentColumn: (t) => t.ledgerAccountId,
      referencedTable: $db.ledgerAccounts,
      getReferencedColumn: (t) => t.ledgerAccountId,
      builder:
          (
            joinBuilder, {
            $addJoinBuilderToRootComposer,
            $removeJoinBuilderFromRootComposer,
          }) => $$LedgerAccountsTableFilterComposer(
            $db: $db,
            $table: $db.ledgerAccounts,
            $addJoinBuilderToRootComposer: $addJoinBuilderToRootComposer,
            joinBuilder: joinBuilder,
            $removeJoinBuilderFromRootComposer:
                $removeJoinBuilderFromRootComposer,
          ),
    );
    return composer;
  }
}

class $$PostingsTableOrderingComposer
    extends Composer<_$AppDatabaseV2, $PostingsTable> {
  $$PostingsTableOrderingComposer({
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

  ColumnOrderings<String> get uuid => $composableBuilder(
    column: $table.uuid,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<String> get direction => $composableBuilder(
    column: $table.direction,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<int> get amountMinorUnits => $composableBuilder(
    column: $table.amountMinorUnits,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<String> get currencyCode => $composableBuilder(
    column: $table.currencyCode,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<DateTime> get postingDate => $composableBuilder(
    column: $table.postingDate,
    builder: (column) => ColumnOrderings(column),
  );

  $$FinancialTransactionsTableOrderingComposer get transactionId {
    final $$FinancialTransactionsTableOrderingComposer composer =
        $composerBuilder(
          composer: this,
          getCurrentColumn: (t) => t.transactionId,
          referencedTable: $db.financialTransactions,
          getReferencedColumn: (t) => t.id,
          builder:
              (
                joinBuilder, {
                $addJoinBuilderToRootComposer,
                $removeJoinBuilderFromRootComposer,
              }) => $$FinancialTransactionsTableOrderingComposer(
                $db: $db,
                $table: $db.financialTransactions,
                $addJoinBuilderToRootComposer: $addJoinBuilderToRootComposer,
                joinBuilder: joinBuilder,
                $removeJoinBuilderFromRootComposer:
                    $removeJoinBuilderFromRootComposer,
              ),
        );
    return composer;
  }

  $$LedgerAccountsTableOrderingComposer get ledgerAccountId {
    final $$LedgerAccountsTableOrderingComposer composer = $composerBuilder(
      composer: this,
      getCurrentColumn: (t) => t.ledgerAccountId,
      referencedTable: $db.ledgerAccounts,
      getReferencedColumn: (t) => t.ledgerAccountId,
      builder:
          (
            joinBuilder, {
            $addJoinBuilderToRootComposer,
            $removeJoinBuilderFromRootComposer,
          }) => $$LedgerAccountsTableOrderingComposer(
            $db: $db,
            $table: $db.ledgerAccounts,
            $addJoinBuilderToRootComposer: $addJoinBuilderToRootComposer,
            joinBuilder: joinBuilder,
            $removeJoinBuilderFromRootComposer:
                $removeJoinBuilderFromRootComposer,
          ),
    );
    return composer;
  }
}

class $$PostingsTableAnnotationComposer
    extends Composer<_$AppDatabaseV2, $PostingsTable> {
  $$PostingsTableAnnotationComposer({
    required super.$db,
    required super.$table,
    super.joinBuilder,
    super.$addJoinBuilderToRootComposer,
    super.$removeJoinBuilderFromRootComposer,
  });
  GeneratedColumn<int> get id =>
      $composableBuilder(column: $table.id, builder: (column) => column);

  GeneratedColumn<String> get uuid =>
      $composableBuilder(column: $table.uuid, builder: (column) => column);

  GeneratedColumn<String> get direction =>
      $composableBuilder(column: $table.direction, builder: (column) => column);

  GeneratedColumn<int> get amountMinorUnits => $composableBuilder(
    column: $table.amountMinorUnits,
    builder: (column) => column,
  );

  GeneratedColumn<String> get currencyCode => $composableBuilder(
    column: $table.currencyCode,
    builder: (column) => column,
  );

  GeneratedColumn<DateTime> get postingDate => $composableBuilder(
    column: $table.postingDate,
    builder: (column) => column,
  );

  $$FinancialTransactionsTableAnnotationComposer get transactionId {
    final $$FinancialTransactionsTableAnnotationComposer composer =
        $composerBuilder(
          composer: this,
          getCurrentColumn: (t) => t.transactionId,
          referencedTable: $db.financialTransactions,
          getReferencedColumn: (t) => t.id,
          builder:
              (
                joinBuilder, {
                $addJoinBuilderToRootComposer,
                $removeJoinBuilderFromRootComposer,
              }) => $$FinancialTransactionsTableAnnotationComposer(
                $db: $db,
                $table: $db.financialTransactions,
                $addJoinBuilderToRootComposer: $addJoinBuilderToRootComposer,
                joinBuilder: joinBuilder,
                $removeJoinBuilderFromRootComposer:
                    $removeJoinBuilderFromRootComposer,
              ),
        );
    return composer;
  }

  $$LedgerAccountsTableAnnotationComposer get ledgerAccountId {
    final $$LedgerAccountsTableAnnotationComposer composer = $composerBuilder(
      composer: this,
      getCurrentColumn: (t) => t.ledgerAccountId,
      referencedTable: $db.ledgerAccounts,
      getReferencedColumn: (t) => t.ledgerAccountId,
      builder:
          (
            joinBuilder, {
            $addJoinBuilderToRootComposer,
            $removeJoinBuilderFromRootComposer,
          }) => $$LedgerAccountsTableAnnotationComposer(
            $db: $db,
            $table: $db.ledgerAccounts,
            $addJoinBuilderToRootComposer: $addJoinBuilderToRootComposer,
            joinBuilder: joinBuilder,
            $removeJoinBuilderFromRootComposer:
                $removeJoinBuilderFromRootComposer,
          ),
    );
    return composer;
  }
}

class $$PostingsTableTableManager
    extends
        RootTableManager<
          _$AppDatabaseV2,
          $PostingsTable,
          Posting,
          $$PostingsTableFilterComposer,
          $$PostingsTableOrderingComposer,
          $$PostingsTableAnnotationComposer,
          $$PostingsTableCreateCompanionBuilder,
          $$PostingsTableUpdateCompanionBuilder,
          (Posting, $$PostingsTableReferences),
          Posting,
          PrefetchHooks Function({bool transactionId, bool ledgerAccountId})
        > {
  $$PostingsTableTableManager(_$AppDatabaseV2 db, $PostingsTable table)
    : super(
        TableManagerState(
          db: db,
          table: table,
          createFilteringComposer: () =>
              $$PostingsTableFilterComposer($db: db, $table: table),
          createOrderingComposer: () =>
              $$PostingsTableOrderingComposer($db: db, $table: table),
          createComputedFieldComposer: () =>
              $$PostingsTableAnnotationComposer($db: db, $table: table),
          updateCompanionCallback:
              ({
                Value<int> id = const Value.absent(),
                Value<String> uuid = const Value.absent(),
                Value<int> transactionId = const Value.absent(),
                Value<String> ledgerAccountId = const Value.absent(),
                Value<String> direction = const Value.absent(),
                Value<int> amountMinorUnits = const Value.absent(),
                Value<String> currencyCode = const Value.absent(),
                Value<DateTime> postingDate = const Value.absent(),
              }) => PostingsCompanion(
                id: id,
                uuid: uuid,
                transactionId: transactionId,
                ledgerAccountId: ledgerAccountId,
                direction: direction,
                amountMinorUnits: amountMinorUnits,
                currencyCode: currencyCode,
                postingDate: postingDate,
              ),
          createCompanionCallback:
              ({
                Value<int> id = const Value.absent(),
                required String uuid,
                required int transactionId,
                required String ledgerAccountId,
                required String direction,
                required int amountMinorUnits,
                Value<String> currencyCode = const Value.absent(),
                required DateTime postingDate,
              }) => PostingsCompanion.insert(
                id: id,
                uuid: uuid,
                transactionId: transactionId,
                ledgerAccountId: ledgerAccountId,
                direction: direction,
                amountMinorUnits: amountMinorUnits,
                currencyCode: currencyCode,
                postingDate: postingDate,
              ),
          withReferenceMapper: (p0) => p0
              .map(
                (e) => (
                  e.readTable<$PostingsTable, Posting>(table),
                  $$PostingsTableReferences(db, table, e),
                ),
              )
              .toList(),
          prefetchHooksCallback:
              ({transactionId = false, ledgerAccountId = false}) {
                return PrefetchHooks(
                  db: db,
                  explicitlyWatchedTables: [],
                  addJoins:
                      <
                        T extends TableManagerState<
                          dynamic,
                          dynamic,
                          dynamic,
                          dynamic,
                          dynamic,
                          dynamic,
                          dynamic,
                          dynamic,
                          dynamic,
                          dynamic,
                          dynamic
                        >
                      >(state) {
                        if (transactionId) {
                          state = state.withJoin(
                            currentTable: table,
                            currentColumn: table.transactionId,
                            referencedTable: $$PostingsTableReferences
                                ._transactionIdTable(db),
                            referencedColumn: $$PostingsTableReferences
                                ._transactionIdTable(db)
                                .id,
                          ) as T;
                        }
                        if (ledgerAccountId) {
                          state = state.withJoin(
                            currentTable: table,
                            currentColumn: table.ledgerAccountId,
                            referencedTable: $$PostingsTableReferences
                                ._ledgerAccountIdTable(db),
                            referencedColumn: $$PostingsTableReferences
                                ._ledgerAccountIdTable(db)
                                .ledgerAccountId,
                          ) as T;
                        }

                        return state;
                      },
                  getPrefetchedDataCallback: (items) async {
                    return [];
                  },
                );
              },
        ),
      );
}

typedef $$PostingsTableProcessedTableManager =
    ProcessedTableManager<
      _$AppDatabaseV2,
      $PostingsTable,
      Posting,
      $$PostingsTableFilterComposer,
      $$PostingsTableOrderingComposer,
      $$PostingsTableAnnotationComposer,
      $$PostingsTableCreateCompanionBuilder,
      $$PostingsTableUpdateCompanionBuilder,
      (Posting, $$PostingsTableReferences),
      Posting,
      PrefetchHooks Function({bool transactionId, bool ledgerAccountId})
    >;
typedef $$TransactionHistoryTableCreateCompanionBuilder =
    TransactionHistoryCompanion Function({
      Value<int> id,
      required String uuid,
      required int transactionId,
      required DateTime changedAt,
      required String changeKind,
      Value<String?> beforeSnapshot,
      Value<String?> afterSnapshot,
    });
typedef $$TransactionHistoryTableUpdateCompanionBuilder =
    TransactionHistoryCompanion Function({
      Value<int> id,
      Value<String> uuid,
      Value<int> transactionId,
      Value<DateTime> changedAt,
      Value<String> changeKind,
      Value<String?> beforeSnapshot,
      Value<String?> afterSnapshot,
    });

final class $$TransactionHistoryTableReferences
    extends
        BaseReferences<
          _$AppDatabaseV2,
          $TransactionHistoryTable,
          TransactionHistoryData
        > {
  $$TransactionHistoryTableReferences(
    super.$_db,
    super.$_table,
    super.$_typedResult,
  );

  static $FinancialTransactionsTable _transactionIdTable(_$AppDatabaseV2 db) =>
      db.financialTransactions.createAlias(
        'transaction_history__transaction_id__financial_transactions__id',
      );

  $$FinancialTransactionsTableProcessedTableManager get transactionId {
    final $_column = $_itemColumn<int>('transaction_id')!;

    final manager = $$FinancialTransactionsTableTableManager(
      $_db,
      $_db.financialTransactions,
    ).filter((f) => f.id.sqlEquals($_column));
    final item = $_typedResult.readTableOrNull(_transactionIdTable($_db));
    if (item == null) return manager;
    return ProcessedTableManager(
      manager.$state.copyWith(prefetchedData: [item]),
    );
  }
}

class $$TransactionHistoryTableFilterComposer
    extends Composer<_$AppDatabaseV2, $TransactionHistoryTable> {
  $$TransactionHistoryTableFilterComposer({
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

  ColumnFilters<String> get uuid => $composableBuilder(
    column: $table.uuid,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<DateTime> get changedAt => $composableBuilder(
    column: $table.changedAt,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<String> get changeKind => $composableBuilder(
    column: $table.changeKind,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<String> get beforeSnapshot => $composableBuilder(
    column: $table.beforeSnapshot,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<String> get afterSnapshot => $composableBuilder(
    column: $table.afterSnapshot,
    builder: (column) => ColumnFilters(column),
  );

  $$FinancialTransactionsTableFilterComposer get transactionId {
    final $$FinancialTransactionsTableFilterComposer composer =
        $composerBuilder(
          composer: this,
          getCurrentColumn: (t) => t.transactionId,
          referencedTable: $db.financialTransactions,
          getReferencedColumn: (t) => t.id,
          builder:
              (
                joinBuilder, {
                $addJoinBuilderToRootComposer,
                $removeJoinBuilderFromRootComposer,
              }) => $$FinancialTransactionsTableFilterComposer(
                $db: $db,
                $table: $db.financialTransactions,
                $addJoinBuilderToRootComposer: $addJoinBuilderToRootComposer,
                joinBuilder: joinBuilder,
                $removeJoinBuilderFromRootComposer:
                    $removeJoinBuilderFromRootComposer,
              ),
        );
    return composer;
  }
}

class $$TransactionHistoryTableOrderingComposer
    extends Composer<_$AppDatabaseV2, $TransactionHistoryTable> {
  $$TransactionHistoryTableOrderingComposer({
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

  ColumnOrderings<String> get uuid => $composableBuilder(
    column: $table.uuid,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<DateTime> get changedAt => $composableBuilder(
    column: $table.changedAt,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<String> get changeKind => $composableBuilder(
    column: $table.changeKind,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<String> get beforeSnapshot => $composableBuilder(
    column: $table.beforeSnapshot,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<String> get afterSnapshot => $composableBuilder(
    column: $table.afterSnapshot,
    builder: (column) => ColumnOrderings(column),
  );

  $$FinancialTransactionsTableOrderingComposer get transactionId {
    final $$FinancialTransactionsTableOrderingComposer composer =
        $composerBuilder(
          composer: this,
          getCurrentColumn: (t) => t.transactionId,
          referencedTable: $db.financialTransactions,
          getReferencedColumn: (t) => t.id,
          builder:
              (
                joinBuilder, {
                $addJoinBuilderToRootComposer,
                $removeJoinBuilderFromRootComposer,
              }) => $$FinancialTransactionsTableOrderingComposer(
                $db: $db,
                $table: $db.financialTransactions,
                $addJoinBuilderToRootComposer: $addJoinBuilderToRootComposer,
                joinBuilder: joinBuilder,
                $removeJoinBuilderFromRootComposer:
                    $removeJoinBuilderFromRootComposer,
              ),
        );
    return composer;
  }
}

class $$TransactionHistoryTableAnnotationComposer
    extends Composer<_$AppDatabaseV2, $TransactionHistoryTable> {
  $$TransactionHistoryTableAnnotationComposer({
    required super.$db,
    required super.$table,
    super.joinBuilder,
    super.$addJoinBuilderToRootComposer,
    super.$removeJoinBuilderFromRootComposer,
  });
  GeneratedColumn<int> get id =>
      $composableBuilder(column: $table.id, builder: (column) => column);

  GeneratedColumn<String> get uuid =>
      $composableBuilder(column: $table.uuid, builder: (column) => column);

  GeneratedColumn<DateTime> get changedAt =>
      $composableBuilder(column: $table.changedAt, builder: (column) => column);

  GeneratedColumn<String> get changeKind => $composableBuilder(
    column: $table.changeKind,
    builder: (column) => column,
  );

  GeneratedColumn<String> get beforeSnapshot => $composableBuilder(
    column: $table.beforeSnapshot,
    builder: (column) => column,
  );

  GeneratedColumn<String> get afterSnapshot => $composableBuilder(
    column: $table.afterSnapshot,
    builder: (column) => column,
  );

  $$FinancialTransactionsTableAnnotationComposer get transactionId {
    final $$FinancialTransactionsTableAnnotationComposer composer =
        $composerBuilder(
          composer: this,
          getCurrentColumn: (t) => t.transactionId,
          referencedTable: $db.financialTransactions,
          getReferencedColumn: (t) => t.id,
          builder:
              (
                joinBuilder, {
                $addJoinBuilderToRootComposer,
                $removeJoinBuilderFromRootComposer,
              }) => $$FinancialTransactionsTableAnnotationComposer(
                $db: $db,
                $table: $db.financialTransactions,
                $addJoinBuilderToRootComposer: $addJoinBuilderToRootComposer,
                joinBuilder: joinBuilder,
                $removeJoinBuilderFromRootComposer:
                    $removeJoinBuilderFromRootComposer,
              ),
        );
    return composer;
  }
}

class $$TransactionHistoryTableTableManager
    extends
        RootTableManager<
          _$AppDatabaseV2,
          $TransactionHistoryTable,
          TransactionHistoryData,
          $$TransactionHistoryTableFilterComposer,
          $$TransactionHistoryTableOrderingComposer,
          $$TransactionHistoryTableAnnotationComposer,
          $$TransactionHistoryTableCreateCompanionBuilder,
          $$TransactionHistoryTableUpdateCompanionBuilder,
          (TransactionHistoryData, $$TransactionHistoryTableReferences),
          TransactionHistoryData,
          PrefetchHooks Function({bool transactionId})
        > {
  $$TransactionHistoryTableTableManager(
    _$AppDatabaseV2 db,
    $TransactionHistoryTable table,
  ) : super(
        TableManagerState(
          db: db,
          table: table,
          createFilteringComposer: () =>
              $$TransactionHistoryTableFilterComposer($db: db, $table: table),
          createOrderingComposer: () =>
              $$TransactionHistoryTableOrderingComposer($db: db, $table: table),
          createComputedFieldComposer: () =>
              $$TransactionHistoryTableAnnotationComposer(
                $db: db,
                $table: table,
              ),
          updateCompanionCallback:
              ({
                Value<int> id = const Value.absent(),
                Value<String> uuid = const Value.absent(),
                Value<int> transactionId = const Value.absent(),
                Value<DateTime> changedAt = const Value.absent(),
                Value<String> changeKind = const Value.absent(),
                Value<String?> beforeSnapshot = const Value.absent(),
                Value<String?> afterSnapshot = const Value.absent(),
              }) => TransactionHistoryCompanion(
                id: id,
                uuid: uuid,
                transactionId: transactionId,
                changedAt: changedAt,
                changeKind: changeKind,
                beforeSnapshot: beforeSnapshot,
                afterSnapshot: afterSnapshot,
              ),
          createCompanionCallback:
              ({
                Value<int> id = const Value.absent(),
                required String uuid,
                required int transactionId,
                required DateTime changedAt,
                required String changeKind,
                Value<String?> beforeSnapshot = const Value.absent(),
                Value<String?> afterSnapshot = const Value.absent(),
              }) => TransactionHistoryCompanion.insert(
                id: id,
                uuid: uuid,
                transactionId: transactionId,
                changedAt: changedAt,
                changeKind: changeKind,
                beforeSnapshot: beforeSnapshot,
                afterSnapshot: afterSnapshot,
              ),
          withReferenceMapper: (p0) => p0
              .map(
                (e) => (
                  e.readTable<$TransactionHistoryTable, TransactionHistoryData>(
                    table,
                  ),
                  $$TransactionHistoryTableReferences(db, table, e),
                ),
              )
              .toList(),
          prefetchHooksCallback: ({transactionId = false}) {
            return PrefetchHooks(
              db: db,
              explicitlyWatchedTables: [],
              addJoins:
                  <
                    T extends TableManagerState<
                      dynamic,
                      dynamic,
                      dynamic,
                      dynamic,
                      dynamic,
                      dynamic,
                      dynamic,
                      dynamic,
                      dynamic,
                      dynamic,
                      dynamic
                    >
                  >(state) {
                    if (transactionId) {
                      state = state.withJoin(
                        currentTable: table,
                        currentColumn: table.transactionId,
                        referencedTable: $$TransactionHistoryTableReferences
                            ._transactionIdTable(db),
                        referencedColumn: $$TransactionHistoryTableReferences
                            ._transactionIdTable(db)
                            .id,
                      ) as T;
                    }

                    return state;
                  },
              getPrefetchedDataCallback: (items) async {
                return [];
              },
            );
          },
        ),
      );
}

typedef $$TransactionHistoryTableProcessedTableManager =
    ProcessedTableManager<
      _$AppDatabaseV2,
      $TransactionHistoryTable,
      TransactionHistoryData,
      $$TransactionHistoryTableFilterComposer,
      $$TransactionHistoryTableOrderingComposer,
      $$TransactionHistoryTableAnnotationComposer,
      $$TransactionHistoryTableCreateCompanionBuilder,
      $$TransactionHistoryTableUpdateCompanionBuilder,
      (TransactionHistoryData, $$TransactionHistoryTableReferences),
      TransactionHistoryData,
      PrefetchHooks Function({bool transactionId})
    >;
typedef $$AppSettingsTableCreateCompanionBuilder =
    AppSettingsCompanion Function({
      Value<int> id,
      Value<String> currencyCode,
      Value<String?> defaultAccountId,
      Value<String> themeMode,
      Value<bool> appLockEnabled,
      Value<int?> documentRetentionDays,
      Value<int> defaultReminderDays,
      Value<bool> sheetsBackupEnabled,
      Value<bool> setupCompleted,
    });
typedef $$AppSettingsTableUpdateCompanionBuilder =
    AppSettingsCompanion Function({
      Value<int> id,
      Value<String> currencyCode,
      Value<String?> defaultAccountId,
      Value<String> themeMode,
      Value<bool> appLockEnabled,
      Value<int?> documentRetentionDays,
      Value<int> defaultReminderDays,
      Value<bool> sheetsBackupEnabled,
      Value<bool> setupCompleted,
    });

final class $$AppSettingsTableReferences
    extends BaseReferences<_$AppDatabaseV2, $AppSettingsTable, AppSetting> {
  $$AppSettingsTableReferences(super.$_db, super.$_table, super.$_typedResult);

  static $AccountsTable _defaultAccountIdTable(_$AppDatabaseV2 db) => db
      .accounts
      .createAlias('app_settings__default_account_id__accounts__uuid');

  $$AccountsTableProcessedTableManager? get defaultAccountId {
    final $_column = $_itemColumn<String>('default_account_id');
    if ($_column == null) return null;
    final manager = $$AccountsTableTableManager(
      $_db,
      $_db.accounts,
    ).filter((f) => f.uuid.sqlEquals($_column));
    final item = $_typedResult.readTableOrNull(_defaultAccountIdTable($_db));
    if (item == null) return manager;
    return ProcessedTableManager(
      manager.$state.copyWith(prefetchedData: [item]),
    );
  }
}

class $$AppSettingsTableFilterComposer
    extends Composer<_$AppDatabaseV2, $AppSettingsTable> {
  $$AppSettingsTableFilterComposer({
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

  ColumnFilters<String> get currencyCode => $composableBuilder(
    column: $table.currencyCode,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<String> get themeMode => $composableBuilder(
    column: $table.themeMode,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<bool> get appLockEnabled => $composableBuilder(
    column: $table.appLockEnabled,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<int> get documentRetentionDays => $composableBuilder(
    column: $table.documentRetentionDays,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<int> get defaultReminderDays => $composableBuilder(
    column: $table.defaultReminderDays,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<bool> get sheetsBackupEnabled => $composableBuilder(
    column: $table.sheetsBackupEnabled,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<bool> get setupCompleted => $composableBuilder(
    column: $table.setupCompleted,
    builder: (column) => ColumnFilters(column),
  );

  $$AccountsTableFilterComposer get defaultAccountId {
    final $$AccountsTableFilterComposer composer = $composerBuilder(
      composer: this,
      getCurrentColumn: (t) => t.defaultAccountId,
      referencedTable: $db.accounts,
      getReferencedColumn: (t) => t.uuid,
      builder:
          (
            joinBuilder, {
            $addJoinBuilderToRootComposer,
            $removeJoinBuilderFromRootComposer,
          }) => $$AccountsTableFilterComposer(
            $db: $db,
            $table: $db.accounts,
            $addJoinBuilderToRootComposer: $addJoinBuilderToRootComposer,
            joinBuilder: joinBuilder,
            $removeJoinBuilderFromRootComposer:
                $removeJoinBuilderFromRootComposer,
          ),
    );
    return composer;
  }
}

class $$AppSettingsTableOrderingComposer
    extends Composer<_$AppDatabaseV2, $AppSettingsTable> {
  $$AppSettingsTableOrderingComposer({
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

  ColumnOrderings<String> get currencyCode => $composableBuilder(
    column: $table.currencyCode,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<String> get themeMode => $composableBuilder(
    column: $table.themeMode,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<bool> get appLockEnabled => $composableBuilder(
    column: $table.appLockEnabled,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<int> get documentRetentionDays => $composableBuilder(
    column: $table.documentRetentionDays,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<int> get defaultReminderDays => $composableBuilder(
    column: $table.defaultReminderDays,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<bool> get sheetsBackupEnabled => $composableBuilder(
    column: $table.sheetsBackupEnabled,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<bool> get setupCompleted => $composableBuilder(
    column: $table.setupCompleted,
    builder: (column) => ColumnOrderings(column),
  );

  $$AccountsTableOrderingComposer get defaultAccountId {
    final $$AccountsTableOrderingComposer composer = $composerBuilder(
      composer: this,
      getCurrentColumn: (t) => t.defaultAccountId,
      referencedTable: $db.accounts,
      getReferencedColumn: (t) => t.uuid,
      builder:
          (
            joinBuilder, {
            $addJoinBuilderToRootComposer,
            $removeJoinBuilderFromRootComposer,
          }) => $$AccountsTableOrderingComposer(
            $db: $db,
            $table: $db.accounts,
            $addJoinBuilderToRootComposer: $addJoinBuilderToRootComposer,
            joinBuilder: joinBuilder,
            $removeJoinBuilderFromRootComposer:
                $removeJoinBuilderFromRootComposer,
          ),
    );
    return composer;
  }
}

class $$AppSettingsTableAnnotationComposer
    extends Composer<_$AppDatabaseV2, $AppSettingsTable> {
  $$AppSettingsTableAnnotationComposer({
    required super.$db,
    required super.$table,
    super.joinBuilder,
    super.$addJoinBuilderToRootComposer,
    super.$removeJoinBuilderFromRootComposer,
  });
  GeneratedColumn<int> get id =>
      $composableBuilder(column: $table.id, builder: (column) => column);

  GeneratedColumn<String> get currencyCode => $composableBuilder(
    column: $table.currencyCode,
    builder: (column) => column,
  );

  GeneratedColumn<String> get themeMode =>
      $composableBuilder(column: $table.themeMode, builder: (column) => column);

  GeneratedColumn<bool> get appLockEnabled => $composableBuilder(
    column: $table.appLockEnabled,
    builder: (column) => column,
  );

  GeneratedColumn<int> get documentRetentionDays => $composableBuilder(
    column: $table.documentRetentionDays,
    builder: (column) => column,
  );

  GeneratedColumn<int> get defaultReminderDays => $composableBuilder(
    column: $table.defaultReminderDays,
    builder: (column) => column,
  );

  GeneratedColumn<bool> get sheetsBackupEnabled => $composableBuilder(
    column: $table.sheetsBackupEnabled,
    builder: (column) => column,
  );

  GeneratedColumn<bool> get setupCompleted => $composableBuilder(
    column: $table.setupCompleted,
    builder: (column) => column,
  );

  $$AccountsTableAnnotationComposer get defaultAccountId {
    final $$AccountsTableAnnotationComposer composer = $composerBuilder(
      composer: this,
      getCurrentColumn: (t) => t.defaultAccountId,
      referencedTable: $db.accounts,
      getReferencedColumn: (t) => t.uuid,
      builder:
          (
            joinBuilder, {
            $addJoinBuilderToRootComposer,
            $removeJoinBuilderFromRootComposer,
          }) => $$AccountsTableAnnotationComposer(
            $db: $db,
            $table: $db.accounts,
            $addJoinBuilderToRootComposer: $addJoinBuilderToRootComposer,
            joinBuilder: joinBuilder,
            $removeJoinBuilderFromRootComposer:
                $removeJoinBuilderFromRootComposer,
          ),
    );
    return composer;
  }
}

class $$AppSettingsTableTableManager
    extends
        RootTableManager<
          _$AppDatabaseV2,
          $AppSettingsTable,
          AppSetting,
          $$AppSettingsTableFilterComposer,
          $$AppSettingsTableOrderingComposer,
          $$AppSettingsTableAnnotationComposer,
          $$AppSettingsTableCreateCompanionBuilder,
          $$AppSettingsTableUpdateCompanionBuilder,
          (AppSetting, $$AppSettingsTableReferences),
          AppSetting,
          PrefetchHooks Function({bool defaultAccountId})
        > {
  $$AppSettingsTableTableManager(_$AppDatabaseV2 db, $AppSettingsTable table)
    : super(
        TableManagerState(
          db: db,
          table: table,
          createFilteringComposer: () =>
              $$AppSettingsTableFilterComposer($db: db, $table: table),
          createOrderingComposer: () =>
              $$AppSettingsTableOrderingComposer($db: db, $table: table),
          createComputedFieldComposer: () =>
              $$AppSettingsTableAnnotationComposer($db: db, $table: table),
          updateCompanionCallback:
              ({
                Value<int> id = const Value.absent(),
                Value<String> currencyCode = const Value.absent(),
                Value<String?> defaultAccountId = const Value.absent(),
                Value<String> themeMode = const Value.absent(),
                Value<bool> appLockEnabled = const Value.absent(),
                Value<int?> documentRetentionDays = const Value.absent(),
                Value<int> defaultReminderDays = const Value.absent(),
                Value<bool> sheetsBackupEnabled = const Value.absent(),
                Value<bool> setupCompleted = const Value.absent(),
              }) => AppSettingsCompanion(
                id: id,
                currencyCode: currencyCode,
                defaultAccountId: defaultAccountId,
                themeMode: themeMode,
                appLockEnabled: appLockEnabled,
                documentRetentionDays: documentRetentionDays,
                defaultReminderDays: defaultReminderDays,
                sheetsBackupEnabled: sheetsBackupEnabled,
                setupCompleted: setupCompleted,
              ),
          createCompanionCallback:
              ({
                Value<int> id = const Value.absent(),
                Value<String> currencyCode = const Value.absent(),
                Value<String?> defaultAccountId = const Value.absent(),
                Value<String> themeMode = const Value.absent(),
                Value<bool> appLockEnabled = const Value.absent(),
                Value<int?> documentRetentionDays = const Value.absent(),
                Value<int> defaultReminderDays = const Value.absent(),
                Value<bool> sheetsBackupEnabled = const Value.absent(),
                Value<bool> setupCompleted = const Value.absent(),
              }) => AppSettingsCompanion.insert(
                id: id,
                currencyCode: currencyCode,
                defaultAccountId: defaultAccountId,
                themeMode: themeMode,
                appLockEnabled: appLockEnabled,
                documentRetentionDays: documentRetentionDays,
                defaultReminderDays: defaultReminderDays,
                sheetsBackupEnabled: sheetsBackupEnabled,
                setupCompleted: setupCompleted,
              ),
          withReferenceMapper: (p0) => p0
              .map(
                (e) => (
                  e.readTable<$AppSettingsTable, AppSetting>(table),
                  $$AppSettingsTableReferences(db, table, e),
                ),
              )
              .toList(),
          prefetchHooksCallback: ({defaultAccountId = false}) {
            return PrefetchHooks(
              db: db,
              explicitlyWatchedTables: [],
              addJoins:
                  <
                    T extends TableManagerState<
                      dynamic,
                      dynamic,
                      dynamic,
                      dynamic,
                      dynamic,
                      dynamic,
                      dynamic,
                      dynamic,
                      dynamic,
                      dynamic,
                      dynamic
                    >
                  >(state) {
                    if (defaultAccountId) {
                      state = state.withJoin(
                        currentTable: table,
                        currentColumn: table.defaultAccountId,
                        referencedTable: $$AppSettingsTableReferences
                            ._defaultAccountIdTable(db),
                        referencedColumn: $$AppSettingsTableReferences
                            ._defaultAccountIdTable(db)
                            .uuid,
                      ) as T;
                    }

                    return state;
                  },
              getPrefetchedDataCallback: (items) async {
                return [];
              },
            );
          },
        ),
      );
}

typedef $$AppSettingsTableProcessedTableManager =
    ProcessedTableManager<
      _$AppDatabaseV2,
      $AppSettingsTable,
      AppSetting,
      $$AppSettingsTableFilterComposer,
      $$AppSettingsTableOrderingComposer,
      $$AppSettingsTableAnnotationComposer,
      $$AppSettingsTableCreateCompanionBuilder,
      $$AppSettingsTableUpdateCompanionBuilder,
      (AppSetting, $$AppSettingsTableReferences),
      AppSetting,
      PrefetchHooks Function({bool defaultAccountId})
    >;
typedef $$NotificationsTableCreateCompanionBuilder =
    NotificationsCompanion Function({
      required String id,
      required String type,
      required String title,
      required String message,
      required DateTime createdAt,
      Value<bool> isRead,
      Value<int> rowid,
    });
typedef $$NotificationsTableUpdateCompanionBuilder =
    NotificationsCompanion Function({
      Value<String> id,
      Value<String> type,
      Value<String> title,
      Value<String> message,
      Value<DateTime> createdAt,
      Value<bool> isRead,
      Value<int> rowid,
    });

class $$NotificationsTableFilterComposer
    extends Composer<_$AppDatabaseV2, $NotificationsTable> {
  $$NotificationsTableFilterComposer({
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

  ColumnFilters<String> get type => $composableBuilder(
    column: $table.type,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<String> get title => $composableBuilder(
    column: $table.title,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<String> get message => $composableBuilder(
    column: $table.message,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<DateTime> get createdAt => $composableBuilder(
    column: $table.createdAt,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<bool> get isRead => $composableBuilder(
    column: $table.isRead,
    builder: (column) => ColumnFilters(column),
  );
}

class $$NotificationsTableOrderingComposer
    extends Composer<_$AppDatabaseV2, $NotificationsTable> {
  $$NotificationsTableOrderingComposer({
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

  ColumnOrderings<String> get type => $composableBuilder(
    column: $table.type,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<String> get title => $composableBuilder(
    column: $table.title,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<String> get message => $composableBuilder(
    column: $table.message,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<DateTime> get createdAt => $composableBuilder(
    column: $table.createdAt,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<bool> get isRead => $composableBuilder(
    column: $table.isRead,
    builder: (column) => ColumnOrderings(column),
  );
}

class $$NotificationsTableAnnotationComposer
    extends Composer<_$AppDatabaseV2, $NotificationsTable> {
  $$NotificationsTableAnnotationComposer({
    required super.$db,
    required super.$table,
    super.joinBuilder,
    super.$addJoinBuilderToRootComposer,
    super.$removeJoinBuilderFromRootComposer,
  });
  GeneratedColumn<String> get id =>
      $composableBuilder(column: $table.id, builder: (column) => column);

  GeneratedColumn<String> get type =>
      $composableBuilder(column: $table.type, builder: (column) => column);

  GeneratedColumn<String> get title =>
      $composableBuilder(column: $table.title, builder: (column) => column);

  GeneratedColumn<String> get message =>
      $composableBuilder(column: $table.message, builder: (column) => column);

  GeneratedColumn<DateTime> get createdAt =>
      $composableBuilder(column: $table.createdAt, builder: (column) => column);

  GeneratedColumn<bool> get isRead =>
      $composableBuilder(column: $table.isRead, builder: (column) => column);
}

class $$NotificationsTableTableManager
    extends
        RootTableManager<
          _$AppDatabaseV2,
          $NotificationsTable,
          Notification,
          $$NotificationsTableFilterComposer,
          $$NotificationsTableOrderingComposer,
          $$NotificationsTableAnnotationComposer,
          $$NotificationsTableCreateCompanionBuilder,
          $$NotificationsTableUpdateCompanionBuilder,
          (
            Notification,
            BaseReferences<_$AppDatabaseV2, $NotificationsTable, Notification>,
          ),
          Notification,
          PrefetchHooks Function()
        > {
  $$NotificationsTableTableManager(
    _$AppDatabaseV2 db,
    $NotificationsTable table,
  ) : super(
        TableManagerState(
          db: db,
          table: table,
          createFilteringComposer: () =>
              $$NotificationsTableFilterComposer($db: db, $table: table),
          createOrderingComposer: () =>
              $$NotificationsTableOrderingComposer($db: db, $table: table),
          createComputedFieldComposer: () =>
              $$NotificationsTableAnnotationComposer($db: db, $table: table),
          updateCompanionCallback:
              ({
                Value<String> id = const Value.absent(),
                Value<String> type = const Value.absent(),
                Value<String> title = const Value.absent(),
                Value<String> message = const Value.absent(),
                Value<DateTime> createdAt = const Value.absent(),
                Value<bool> isRead = const Value.absent(),
                Value<int> rowid = const Value.absent(),
              }) => NotificationsCompanion(
                id: id,
                type: type,
                title: title,
                message: message,
                createdAt: createdAt,
                isRead: isRead,
                rowid: rowid,
              ),
          createCompanionCallback:
              ({
                required String id,
                required String type,
                required String title,
                required String message,
                required DateTime createdAt,
                Value<bool> isRead = const Value.absent(),
                Value<int> rowid = const Value.absent(),
              }) => NotificationsCompanion.insert(
                id: id,
                type: type,
                title: title,
                message: message,
                createdAt: createdAt,
                isRead: isRead,
                rowid: rowid,
              ),
          withReferenceMapper: (p0) => p0
              .map(
                (e) => (
                  e.readTable<$NotificationsTable, Notification>(table),
                  BaseReferences<
                    _$AppDatabaseV2,
                    $NotificationsTable,
                    Notification
                  >(db, table, e),
                ),
              )
              .toList(),
          prefetchHooksCallback: null,
        ),
      );
}

typedef $$NotificationsTableProcessedTableManager =
    ProcessedTableManager<
      _$AppDatabaseV2,
      $NotificationsTable,
      Notification,
      $$NotificationsTableFilterComposer,
      $$NotificationsTableOrderingComposer,
      $$NotificationsTableAnnotationComposer,
      $$NotificationsTableCreateCompanionBuilder,
      $$NotificationsTableUpdateCompanionBuilder,
      (
        Notification,
        BaseReferences<_$AppDatabaseV2, $NotificationsTable, Notification>,
      ),
      Notification,
      PrefetchHooks Function()
    >;

class $AppDatabaseV2Manager {
  final _$AppDatabaseV2 _db;
  $AppDatabaseV2Manager(this._db);
  $$AccountsTableTableManager get accounts =>
      $$AccountsTableTableManager(_db, _db.accounts);
  $$CategoriesTableTableManager get categories =>
      $$CategoriesTableTableManager(_db, _db.categories);
  $$LedgerAccountsTableTableManager get ledgerAccounts =>
      $$LedgerAccountsTableTableManager(_db, _db.ledgerAccounts);
  $$FinancialTransactionsTableTableManager get financialTransactions =>
      $$FinancialTransactionsTableTableManager(_db, _db.financialTransactions);
  $$PostingsTableTableManager get postings =>
      $$PostingsTableTableManager(_db, _db.postings);
  $$TransactionHistoryTableTableManager get transactionHistory =>
      $$TransactionHistoryTableTableManager(_db, _db.transactionHistory);
  $$AppSettingsTableTableManager get appSettings =>
      $$AppSettingsTableTableManager(_db, _db.appSettings);
  $$NotificationsTableTableManager get notifications =>
      $$NotificationsTableTableManager(_db, _db.notifications);
}
