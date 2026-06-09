// GENERATED CODE - DO NOT MODIFY BY HAND

part of 'app_database.dart';

// ignore_for_file: type=lint
class $AppSettingsTable extends AppSettings
    with TableInfo<$AppSettingsTable, AppSetting> {
  @override
  final GeneratedDatabase attachedDatabase;
  final String? _alias;
  $AppSettingsTable(this.attachedDatabase, [this._alias]);
  static const VerificationMeta _keyMeta = const VerificationMeta('key');
  @override
  late final GeneratedColumn<String> key = GeneratedColumn<String>(
      'key', aliasedName, false,
      type: DriftSqlType.string, requiredDuringInsert: true);
  static const VerificationMeta _valueMeta = const VerificationMeta('value');
  @override
  late final GeneratedColumn<String> value = GeneratedColumn<String>(
      'value', aliasedName, false,
      type: DriftSqlType.string, requiredDuringInsert: true);
  @override
  List<GeneratedColumn> get $columns => [key, value];
  @override
  String get aliasedName => _alias ?? actualTableName;
  @override
  String get actualTableName => $name;
  static const String $name = 'app_settings';
  @override
  VerificationContext validateIntegrity(Insertable<AppSetting> instance,
      {bool isInserting = false}) {
    final context = VerificationContext();
    final data = instance.toColumns(true);
    if (data.containsKey('key')) {
      context.handle(
          _keyMeta, key.isAcceptableOrUnknown(data['key']!, _keyMeta));
    } else if (isInserting) {
      context.missing(_keyMeta);
    }
    if (data.containsKey('value')) {
      context.handle(
          _valueMeta, value.isAcceptableOrUnknown(data['value']!, _valueMeta));
    } else if (isInserting) {
      context.missing(_valueMeta);
    }
    return context;
  }

  @override
  Set<GeneratedColumn> get $primaryKey => {key};
  @override
  AppSetting map(Map<String, dynamic> data, {String? tablePrefix}) {
    final effectivePrefix = tablePrefix != null ? '$tablePrefix.' : '';
    return AppSetting(
      key: attachedDatabase.typeMapping
          .read(DriftSqlType.string, data['${effectivePrefix}key'])!,
      value: attachedDatabase.typeMapping
          .read(DriftSqlType.string, data['${effectivePrefix}value'])!,
    );
  }

  @override
  $AppSettingsTable createAlias(String alias) {
    return $AppSettingsTable(attachedDatabase, alias);
  }
}

class AppSetting extends DataClass implements Insertable<AppSetting> {
  final String key;
  final String value;
  const AppSetting({required this.key, required this.value});
  @override
  Map<String, Expression> toColumns(bool nullToAbsent) {
    final map = <String, Expression>{};
    map['key'] = Variable<String>(key);
    map['value'] = Variable<String>(value);
    return map;
  }

  AppSettingsCompanion toCompanion(bool nullToAbsent) {
    return AppSettingsCompanion(
      key: Value(key),
      value: Value(value),
    );
  }

  factory AppSetting.fromJson(Map<String, dynamic> json,
      {ValueSerializer? serializer}) {
    serializer ??= driftRuntimeOptions.defaultSerializer;
    return AppSetting(
      key: serializer.fromJson<String>(json['key']),
      value: serializer.fromJson<String>(json['value']),
    );
  }
  @override
  Map<String, dynamic> toJson({ValueSerializer? serializer}) {
    serializer ??= driftRuntimeOptions.defaultSerializer;
    return <String, dynamic>{
      'key': serializer.toJson<String>(key),
      'value': serializer.toJson<String>(value),
    };
  }

  AppSetting copyWith({String? key, String? value}) => AppSetting(
        key: key ?? this.key,
        value: value ?? this.value,
      );
  AppSetting copyWithCompanion(AppSettingsCompanion data) {
    return AppSetting(
      key: data.key.present ? data.key.value : this.key,
      value: data.value.present ? data.value.value : this.value,
    );
  }

  @override
  String toString() {
    return (StringBuffer('AppSetting(')
          ..write('key: $key, ')
          ..write('value: $value')
          ..write(')'))
        .toString();
  }

  @override
  int get hashCode => Object.hash(key, value);
  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      (other is AppSetting &&
          other.key == this.key &&
          other.value == this.value);
}

class AppSettingsCompanion extends UpdateCompanion<AppSetting> {
  final Value<String> key;
  final Value<String> value;
  final Value<int> rowid;
  const AppSettingsCompanion({
    this.key = const Value.absent(),
    this.value = const Value.absent(),
    this.rowid = const Value.absent(),
  });
  AppSettingsCompanion.insert({
    required String key,
    required String value,
    this.rowid = const Value.absent(),
  })  : key = Value(key),
        value = Value(value);
  static Insertable<AppSetting> custom({
    Expression<String>? key,
    Expression<String>? value,
    Expression<int>? rowid,
  }) {
    return RawValuesInsertable({
      if (key != null) 'key': key,
      if (value != null) 'value': value,
      if (rowid != null) 'rowid': rowid,
    });
  }

  AppSettingsCompanion copyWith(
      {Value<String>? key, Value<String>? value, Value<int>? rowid}) {
    return AppSettingsCompanion(
      key: key ?? this.key,
      value: value ?? this.value,
      rowid: rowid ?? this.rowid,
    );
  }

  @override
  Map<String, Expression> toColumns(bool nullToAbsent) {
    final map = <String, Expression>{};
    if (key.present) {
      map['key'] = Variable<String>(key.value);
    }
    if (value.present) {
      map['value'] = Variable<String>(value.value);
    }
    if (rowid.present) {
      map['rowid'] = Variable<int>(rowid.value);
    }
    return map;
  }

  @override
  String toString() {
    return (StringBuffer('AppSettingsCompanion(')
          ..write('key: $key, ')
          ..write('value: $value, ')
          ..write('rowid: $rowid')
          ..write(')'))
        .toString();
  }
}

class $UsersTable extends Users with TableInfo<$UsersTable, User> {
  @override
  final GeneratedDatabase attachedDatabase;
  final String? _alias;
  $UsersTable(this.attachedDatabase, [this._alias]);
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
  static const VerificationMeta _emailMeta = const VerificationMeta('email');
  @override
  late final GeneratedColumn<String> email = GeneratedColumn<String>(
      'email', aliasedName, true,
      type: DriftSqlType.string, requiredDuringInsert: false);
  static const VerificationMeta _phoneMeta = const VerificationMeta('phone');
  @override
  late final GeneratedColumn<String> phone = GeneratedColumn<String>(
      'phone', aliasedName, true,
      type: DriftSqlType.string, requiredDuringInsert: false);
  static const VerificationMeta _typeMeta = const VerificationMeta('type');
  @override
  late final GeneratedColumn<String> type = GeneratedColumn<String>(
      'type', aliasedName, false,
      type: DriftSqlType.string, requiredDuringInsert: true);
  static const VerificationMeta _kycStatusMeta =
      const VerificationMeta('kycStatus');
  @override
  late final GeneratedColumn<String> kycStatus = GeneratedColumn<String>(
      'kyc_status', aliasedName, false,
      type: DriftSqlType.string,
      requiredDuringInsert: false,
      defaultValue: const Constant('none'));
  static const VerificationMeta _createdAtMeta =
      const VerificationMeta('createdAt');
  @override
  late final GeneratedColumn<DateTime> createdAt = GeneratedColumn<DateTime>(
      'created_at', aliasedName, false,
      type: DriftSqlType.dateTime,
      requiredDuringInsert: false,
      defaultValue: currentDateAndTime);
  @override
  List<GeneratedColumn> get $columns =>
      [id, name, email, phone, type, kycStatus, createdAt];
  @override
  String get aliasedName => _alias ?? actualTableName;
  @override
  String get actualTableName => $name;
  static const String $name = 'users';
  @override
  VerificationContext validateIntegrity(Insertable<User> instance,
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
    if (data.containsKey('email')) {
      context.handle(
          _emailMeta, email.isAcceptableOrUnknown(data['email']!, _emailMeta));
    }
    if (data.containsKey('phone')) {
      context.handle(
          _phoneMeta, phone.isAcceptableOrUnknown(data['phone']!, _phoneMeta));
    }
    if (data.containsKey('type')) {
      context.handle(
          _typeMeta, type.isAcceptableOrUnknown(data['type']!, _typeMeta));
    } else if (isInserting) {
      context.missing(_typeMeta);
    }
    if (data.containsKey('kyc_status')) {
      context.handle(_kycStatusMeta,
          kycStatus.isAcceptableOrUnknown(data['kyc_status']!, _kycStatusMeta));
    }
    if (data.containsKey('created_at')) {
      context.handle(_createdAtMeta,
          createdAt.isAcceptableOrUnknown(data['created_at']!, _createdAtMeta));
    }
    return context;
  }

  @override
  Set<GeneratedColumn> get $primaryKey => {id};
  @override
  User map(Map<String, dynamic> data, {String? tablePrefix}) {
    final effectivePrefix = tablePrefix != null ? '$tablePrefix.' : '';
    return User(
      id: attachedDatabase.typeMapping
          .read(DriftSqlType.string, data['${effectivePrefix}id'])!,
      name: attachedDatabase.typeMapping
          .read(DriftSqlType.string, data['${effectivePrefix}name'])!,
      email: attachedDatabase.typeMapping
          .read(DriftSqlType.string, data['${effectivePrefix}email']),
      phone: attachedDatabase.typeMapping
          .read(DriftSqlType.string, data['${effectivePrefix}phone']),
      type: attachedDatabase.typeMapping
          .read(DriftSqlType.string, data['${effectivePrefix}type'])!,
      kycStatus: attachedDatabase.typeMapping
          .read(DriftSqlType.string, data['${effectivePrefix}kyc_status'])!,
      createdAt: attachedDatabase.typeMapping
          .read(DriftSqlType.dateTime, data['${effectivePrefix}created_at'])!,
    );
  }

  @override
  $UsersTable createAlias(String alias) {
    return $UsersTable(attachedDatabase, alias);
  }
}

class User extends DataClass implements Insertable<User> {
  final String id;
  final String name;
  final String? email;
  final String? phone;
  final String type;
  final String kycStatus;
  final DateTime createdAt;
  const User(
      {required this.id,
      required this.name,
      this.email,
      this.phone,
      required this.type,
      required this.kycStatus,
      required this.createdAt});
  @override
  Map<String, Expression> toColumns(bool nullToAbsent) {
    final map = <String, Expression>{};
    map['id'] = Variable<String>(id);
    map['name'] = Variable<String>(name);
    if (!nullToAbsent || email != null) {
      map['email'] = Variable<String>(email);
    }
    if (!nullToAbsent || phone != null) {
      map['phone'] = Variable<String>(phone);
    }
    map['type'] = Variable<String>(type);
    map['kyc_status'] = Variable<String>(kycStatus);
    map['created_at'] = Variable<DateTime>(createdAt);
    return map;
  }

  UsersCompanion toCompanion(bool nullToAbsent) {
    return UsersCompanion(
      id: Value(id),
      name: Value(name),
      email:
          email == null && nullToAbsent ? const Value.absent() : Value(email),
      phone:
          phone == null && nullToAbsent ? const Value.absent() : Value(phone),
      type: Value(type),
      kycStatus: Value(kycStatus),
      createdAt: Value(createdAt),
    );
  }

  factory User.fromJson(Map<String, dynamic> json,
      {ValueSerializer? serializer}) {
    serializer ??= driftRuntimeOptions.defaultSerializer;
    return User(
      id: serializer.fromJson<String>(json['id']),
      name: serializer.fromJson<String>(json['name']),
      email: serializer.fromJson<String?>(json['email']),
      phone: serializer.fromJson<String?>(json['phone']),
      type: serializer.fromJson<String>(json['type']),
      kycStatus: serializer.fromJson<String>(json['kycStatus']),
      createdAt: serializer.fromJson<DateTime>(json['createdAt']),
    );
  }
  @override
  Map<String, dynamic> toJson({ValueSerializer? serializer}) {
    serializer ??= driftRuntimeOptions.defaultSerializer;
    return <String, dynamic>{
      'id': serializer.toJson<String>(id),
      'name': serializer.toJson<String>(name),
      'email': serializer.toJson<String?>(email),
      'phone': serializer.toJson<String?>(phone),
      'type': serializer.toJson<String>(type),
      'kycStatus': serializer.toJson<String>(kycStatus),
      'createdAt': serializer.toJson<DateTime>(createdAt),
    };
  }

  User copyWith(
          {String? id,
          String? name,
          Value<String?> email = const Value.absent(),
          Value<String?> phone = const Value.absent(),
          String? type,
          String? kycStatus,
          DateTime? createdAt}) =>
      User(
        id: id ?? this.id,
        name: name ?? this.name,
        email: email.present ? email.value : this.email,
        phone: phone.present ? phone.value : this.phone,
        type: type ?? this.type,
        kycStatus: kycStatus ?? this.kycStatus,
        createdAt: createdAt ?? this.createdAt,
      );
  User copyWithCompanion(UsersCompanion data) {
    return User(
      id: data.id.present ? data.id.value : this.id,
      name: data.name.present ? data.name.value : this.name,
      email: data.email.present ? data.email.value : this.email,
      phone: data.phone.present ? data.phone.value : this.phone,
      type: data.type.present ? data.type.value : this.type,
      kycStatus: data.kycStatus.present ? data.kycStatus.value : this.kycStatus,
      createdAt: data.createdAt.present ? data.createdAt.value : this.createdAt,
    );
  }

  @override
  String toString() {
    return (StringBuffer('User(')
          ..write('id: $id, ')
          ..write('name: $name, ')
          ..write('email: $email, ')
          ..write('phone: $phone, ')
          ..write('type: $type, ')
          ..write('kycStatus: $kycStatus, ')
          ..write('createdAt: $createdAt')
          ..write(')'))
        .toString();
  }

  @override
  int get hashCode =>
      Object.hash(id, name, email, phone, type, kycStatus, createdAt);
  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      (other is User &&
          other.id == this.id &&
          other.name == this.name &&
          other.email == this.email &&
          other.phone == this.phone &&
          other.type == this.type &&
          other.kycStatus == this.kycStatus &&
          other.createdAt == this.createdAt);
}

class UsersCompanion extends UpdateCompanion<User> {
  final Value<String> id;
  final Value<String> name;
  final Value<String?> email;
  final Value<String?> phone;
  final Value<String> type;
  final Value<String> kycStatus;
  final Value<DateTime> createdAt;
  final Value<int> rowid;
  const UsersCompanion({
    this.id = const Value.absent(),
    this.name = const Value.absent(),
    this.email = const Value.absent(),
    this.phone = const Value.absent(),
    this.type = const Value.absent(),
    this.kycStatus = const Value.absent(),
    this.createdAt = const Value.absent(),
    this.rowid = const Value.absent(),
  });
  UsersCompanion.insert({
    required String id,
    required String name,
    this.email = const Value.absent(),
    this.phone = const Value.absent(),
    required String type,
    this.kycStatus = const Value.absent(),
    this.createdAt = const Value.absent(),
    this.rowid = const Value.absent(),
  })  : id = Value(id),
        name = Value(name),
        type = Value(type);
  static Insertable<User> custom({
    Expression<String>? id,
    Expression<String>? name,
    Expression<String>? email,
    Expression<String>? phone,
    Expression<String>? type,
    Expression<String>? kycStatus,
    Expression<DateTime>? createdAt,
    Expression<int>? rowid,
  }) {
    return RawValuesInsertable({
      if (id != null) 'id': id,
      if (name != null) 'name': name,
      if (email != null) 'email': email,
      if (phone != null) 'phone': phone,
      if (type != null) 'type': type,
      if (kycStatus != null) 'kyc_status': kycStatus,
      if (createdAt != null) 'created_at': createdAt,
      if (rowid != null) 'rowid': rowid,
    });
  }

  UsersCompanion copyWith(
      {Value<String>? id,
      Value<String>? name,
      Value<String?>? email,
      Value<String?>? phone,
      Value<String>? type,
      Value<String>? kycStatus,
      Value<DateTime>? createdAt,
      Value<int>? rowid}) {
    return UsersCompanion(
      id: id ?? this.id,
      name: name ?? this.name,
      email: email ?? this.email,
      phone: phone ?? this.phone,
      type: type ?? this.type,
      kycStatus: kycStatus ?? this.kycStatus,
      createdAt: createdAt ?? this.createdAt,
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
    if (email.present) {
      map['email'] = Variable<String>(email.value);
    }
    if (phone.present) {
      map['phone'] = Variable<String>(phone.value);
    }
    if (type.present) {
      map['type'] = Variable<String>(type.value);
    }
    if (kycStatus.present) {
      map['kyc_status'] = Variable<String>(kycStatus.value);
    }
    if (createdAt.present) {
      map['created_at'] = Variable<DateTime>(createdAt.value);
    }
    if (rowid.present) {
      map['rowid'] = Variable<int>(rowid.value);
    }
    return map;
  }

  @override
  String toString() {
    return (StringBuffer('UsersCompanion(')
          ..write('id: $id, ')
          ..write('name: $name, ')
          ..write('email: $email, ')
          ..write('phone: $phone, ')
          ..write('type: $type, ')
          ..write('kycStatus: $kycStatus, ')
          ..write('createdAt: $createdAt, ')
          ..write('rowid: $rowid')
          ..write(')'))
        .toString();
  }
}

class $ModuleRegistryTableTable extends ModuleRegistryTable
    with TableInfo<$ModuleRegistryTableTable, ModuleRegistryTableData> {
  @override
  final GeneratedDatabase attachedDatabase;
  final String? _alias;
  $ModuleRegistryTableTable(this.attachedDatabase, [this._alias]);
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
  static const VerificationMeta _versionMeta =
      const VerificationMeta('version');
  @override
  late final GeneratedColumn<String> version = GeneratedColumn<String>(
      'version', aliasedName, false,
      type: DriftSqlType.string, requiredDuringInsert: true);
  static const VerificationMeta _isInstalledMeta =
      const VerificationMeta('isInstalled');
  @override
  late final GeneratedColumn<bool> isInstalled = GeneratedColumn<bool>(
      'is_installed', aliasedName, false,
      type: DriftSqlType.bool,
      requiredDuringInsert: false,
      defaultConstraints: GeneratedColumn.constraintIsAlways(
          'CHECK ("is_installed" IN (0, 1))'),
      defaultValue: const Constant(false));
  @override
  List<GeneratedColumn> get $columns => [id, name, version, isInstalled];
  @override
  String get aliasedName => _alias ?? actualTableName;
  @override
  String get actualTableName => $name;
  static const String $name = 'module_registry_table';
  @override
  VerificationContext validateIntegrity(
      Insertable<ModuleRegistryTableData> instance,
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
    if (data.containsKey('version')) {
      context.handle(_versionMeta,
          version.isAcceptableOrUnknown(data['version']!, _versionMeta));
    } else if (isInserting) {
      context.missing(_versionMeta);
    }
    if (data.containsKey('is_installed')) {
      context.handle(
          _isInstalledMeta,
          isInstalled.isAcceptableOrUnknown(
              data['is_installed']!, _isInstalledMeta));
    }
    return context;
  }

  @override
  Set<GeneratedColumn> get $primaryKey => {id};
  @override
  ModuleRegistryTableData map(Map<String, dynamic> data,
      {String? tablePrefix}) {
    final effectivePrefix = tablePrefix != null ? '$tablePrefix.' : '';
    return ModuleRegistryTableData(
      id: attachedDatabase.typeMapping
          .read(DriftSqlType.string, data['${effectivePrefix}id'])!,
      name: attachedDatabase.typeMapping
          .read(DriftSqlType.string, data['${effectivePrefix}name'])!,
      version: attachedDatabase.typeMapping
          .read(DriftSqlType.string, data['${effectivePrefix}version'])!,
      isInstalled: attachedDatabase.typeMapping
          .read(DriftSqlType.bool, data['${effectivePrefix}is_installed'])!,
    );
  }

  @override
  $ModuleRegistryTableTable createAlias(String alias) {
    return $ModuleRegistryTableTable(attachedDatabase, alias);
  }
}

class ModuleRegistryTableData extends DataClass
    implements Insertable<ModuleRegistryTableData> {
  final String id;
  final String name;
  final String version;
  final bool isInstalled;
  const ModuleRegistryTableData(
      {required this.id,
      required this.name,
      required this.version,
      required this.isInstalled});
  @override
  Map<String, Expression> toColumns(bool nullToAbsent) {
    final map = <String, Expression>{};
    map['id'] = Variable<String>(id);
    map['name'] = Variable<String>(name);
    map['version'] = Variable<String>(version);
    map['is_installed'] = Variable<bool>(isInstalled);
    return map;
  }

  ModuleRegistryTableCompanion toCompanion(bool nullToAbsent) {
    return ModuleRegistryTableCompanion(
      id: Value(id),
      name: Value(name),
      version: Value(version),
      isInstalled: Value(isInstalled),
    );
  }

  factory ModuleRegistryTableData.fromJson(Map<String, dynamic> json,
      {ValueSerializer? serializer}) {
    serializer ??= driftRuntimeOptions.defaultSerializer;
    return ModuleRegistryTableData(
      id: serializer.fromJson<String>(json['id']),
      name: serializer.fromJson<String>(json['name']),
      version: serializer.fromJson<String>(json['version']),
      isInstalled: serializer.fromJson<bool>(json['isInstalled']),
    );
  }
  @override
  Map<String, dynamic> toJson({ValueSerializer? serializer}) {
    serializer ??= driftRuntimeOptions.defaultSerializer;
    return <String, dynamic>{
      'id': serializer.toJson<String>(id),
      'name': serializer.toJson<String>(name),
      'version': serializer.toJson<String>(version),
      'isInstalled': serializer.toJson<bool>(isInstalled),
    };
  }

  ModuleRegistryTableData copyWith(
          {String? id, String? name, String? version, bool? isInstalled}) =>
      ModuleRegistryTableData(
        id: id ?? this.id,
        name: name ?? this.name,
        version: version ?? this.version,
        isInstalled: isInstalled ?? this.isInstalled,
      );
  ModuleRegistryTableData copyWithCompanion(ModuleRegistryTableCompanion data) {
    return ModuleRegistryTableData(
      id: data.id.present ? data.id.value : this.id,
      name: data.name.present ? data.name.value : this.name,
      version: data.version.present ? data.version.value : this.version,
      isInstalled:
          data.isInstalled.present ? data.isInstalled.value : this.isInstalled,
    );
  }

  @override
  String toString() {
    return (StringBuffer('ModuleRegistryTableData(')
          ..write('id: $id, ')
          ..write('name: $name, ')
          ..write('version: $version, ')
          ..write('isInstalled: $isInstalled')
          ..write(')'))
        .toString();
  }

  @override
  int get hashCode => Object.hash(id, name, version, isInstalled);
  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      (other is ModuleRegistryTableData &&
          other.id == this.id &&
          other.name == this.name &&
          other.version == this.version &&
          other.isInstalled == this.isInstalled);
}

class ModuleRegistryTableCompanion
    extends UpdateCompanion<ModuleRegistryTableData> {
  final Value<String> id;
  final Value<String> name;
  final Value<String> version;
  final Value<bool> isInstalled;
  final Value<int> rowid;
  const ModuleRegistryTableCompanion({
    this.id = const Value.absent(),
    this.name = const Value.absent(),
    this.version = const Value.absent(),
    this.isInstalled = const Value.absent(),
    this.rowid = const Value.absent(),
  });
  ModuleRegistryTableCompanion.insert({
    required String id,
    required String name,
    required String version,
    this.isInstalled = const Value.absent(),
    this.rowid = const Value.absent(),
  })  : id = Value(id),
        name = Value(name),
        version = Value(version);
  static Insertable<ModuleRegistryTableData> custom({
    Expression<String>? id,
    Expression<String>? name,
    Expression<String>? version,
    Expression<bool>? isInstalled,
    Expression<int>? rowid,
  }) {
    return RawValuesInsertable({
      if (id != null) 'id': id,
      if (name != null) 'name': name,
      if (version != null) 'version': version,
      if (isInstalled != null) 'is_installed': isInstalled,
      if (rowid != null) 'rowid': rowid,
    });
  }

  ModuleRegistryTableCompanion copyWith(
      {Value<String>? id,
      Value<String>? name,
      Value<String>? version,
      Value<bool>? isInstalled,
      Value<int>? rowid}) {
    return ModuleRegistryTableCompanion(
      id: id ?? this.id,
      name: name ?? this.name,
      version: version ?? this.version,
      isInstalled: isInstalled ?? this.isInstalled,
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
    if (version.present) {
      map['version'] = Variable<String>(version.value);
    }
    if (isInstalled.present) {
      map['is_installed'] = Variable<bool>(isInstalled.value);
    }
    if (rowid.present) {
      map['rowid'] = Variable<int>(rowid.value);
    }
    return map;
  }

  @override
  String toString() {
    return (StringBuffer('ModuleRegistryTableCompanion(')
          ..write('id: $id, ')
          ..write('name: $name, ')
          ..write('version: $version, ')
          ..write('isInstalled: $isInstalled, ')
          ..write('rowid: $rowid')
          ..write(')'))
        .toString();
  }
}

class $ContactsTable extends Contacts with TableInfo<$ContactsTable, Contact> {
  @override
  final GeneratedDatabase attachedDatabase;
  final String? _alias;
  $ContactsTable(this.attachedDatabase, [this._alias]);
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
  static const VerificationMeta _addressMeta =
      const VerificationMeta('address');
  @override
  late final GeneratedColumn<String> address = GeneratedColumn<String>(
      'address', aliasedName, true,
      type: DriftSqlType.string, requiredDuringInsert: false);
  static const VerificationMeta _companyMeta =
      const VerificationMeta('company');
  @override
  late final GeneratedColumn<String> company = GeneratedColumn<String>(
      'company', aliasedName, true,
      type: DriftSqlType.string, requiredDuringInsert: false);
  static const VerificationMeta _isCustomerMeta =
      const VerificationMeta('isCustomer');
  @override
  late final GeneratedColumn<bool> isCustomer = GeneratedColumn<bool>(
      'is_customer', aliasedName, false,
      type: DriftSqlType.bool,
      requiredDuringInsert: false,
      defaultConstraints:
          GeneratedColumn.constraintIsAlways('CHECK ("is_customer" IN (0, 1))'),
      defaultValue: const Constant(true));
  static const VerificationMeta _createdAtMeta =
      const VerificationMeta('createdAt');
  @override
  late final GeneratedColumn<DateTime> createdAt = GeneratedColumn<DateTime>(
      'created_at', aliasedName, false,
      type: DriftSqlType.dateTime,
      requiredDuringInsert: false,
      defaultValue: currentDateAndTime);
  @override
  List<GeneratedColumn> get $columns =>
      [id, name, phone, email, address, company, isCustomer, createdAt];
  @override
  String get aliasedName => _alias ?? actualTableName;
  @override
  String get actualTableName => $name;
  static const String $name = 'contacts';
  @override
  VerificationContext validateIntegrity(Insertable<Contact> instance,
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
    if (data.containsKey('phone')) {
      context.handle(
          _phoneMeta, phone.isAcceptableOrUnknown(data['phone']!, _phoneMeta));
    }
    if (data.containsKey('email')) {
      context.handle(
          _emailMeta, email.isAcceptableOrUnknown(data['email']!, _emailMeta));
    }
    if (data.containsKey('address')) {
      context.handle(_addressMeta,
          address.isAcceptableOrUnknown(data['address']!, _addressMeta));
    }
    if (data.containsKey('company')) {
      context.handle(_companyMeta,
          company.isAcceptableOrUnknown(data['company']!, _companyMeta));
    }
    if (data.containsKey('is_customer')) {
      context.handle(
          _isCustomerMeta,
          isCustomer.isAcceptableOrUnknown(
              data['is_customer']!, _isCustomerMeta));
    }
    if (data.containsKey('created_at')) {
      context.handle(_createdAtMeta,
          createdAt.isAcceptableOrUnknown(data['created_at']!, _createdAtMeta));
    }
    return context;
  }

  @override
  Set<GeneratedColumn> get $primaryKey => {id};
  @override
  Contact map(Map<String, dynamic> data, {String? tablePrefix}) {
    final effectivePrefix = tablePrefix != null ? '$tablePrefix.' : '';
    return Contact(
      id: attachedDatabase.typeMapping
          .read(DriftSqlType.string, data['${effectivePrefix}id'])!,
      name: attachedDatabase.typeMapping
          .read(DriftSqlType.string, data['${effectivePrefix}name'])!,
      phone: attachedDatabase.typeMapping
          .read(DriftSqlType.string, data['${effectivePrefix}phone']),
      email: attachedDatabase.typeMapping
          .read(DriftSqlType.string, data['${effectivePrefix}email']),
      address: attachedDatabase.typeMapping
          .read(DriftSqlType.string, data['${effectivePrefix}address']),
      company: attachedDatabase.typeMapping
          .read(DriftSqlType.string, data['${effectivePrefix}company']),
      isCustomer: attachedDatabase.typeMapping
          .read(DriftSqlType.bool, data['${effectivePrefix}is_customer'])!,
      createdAt: attachedDatabase.typeMapping
          .read(DriftSqlType.dateTime, data['${effectivePrefix}created_at'])!,
    );
  }

  @override
  $ContactsTable createAlias(String alias) {
    return $ContactsTable(attachedDatabase, alias);
  }
}

class Contact extends DataClass implements Insertable<Contact> {
  final String id;
  final String name;
  final String? phone;
  final String? email;
  final String? address;
  final String? company;
  final bool isCustomer;
  final DateTime createdAt;
  const Contact(
      {required this.id,
      required this.name,
      this.phone,
      this.email,
      this.address,
      this.company,
      required this.isCustomer,
      required this.createdAt});
  @override
  Map<String, Expression> toColumns(bool nullToAbsent) {
    final map = <String, Expression>{};
    map['id'] = Variable<String>(id);
    map['name'] = Variable<String>(name);
    if (!nullToAbsent || phone != null) {
      map['phone'] = Variable<String>(phone);
    }
    if (!nullToAbsent || email != null) {
      map['email'] = Variable<String>(email);
    }
    if (!nullToAbsent || address != null) {
      map['address'] = Variable<String>(address);
    }
    if (!nullToAbsent || company != null) {
      map['company'] = Variable<String>(company);
    }
    map['is_customer'] = Variable<bool>(isCustomer);
    map['created_at'] = Variable<DateTime>(createdAt);
    return map;
  }

  ContactsCompanion toCompanion(bool nullToAbsent) {
    return ContactsCompanion(
      id: Value(id),
      name: Value(name),
      phone:
          phone == null && nullToAbsent ? const Value.absent() : Value(phone),
      email:
          email == null && nullToAbsent ? const Value.absent() : Value(email),
      address: address == null && nullToAbsent
          ? const Value.absent()
          : Value(address),
      company: company == null && nullToAbsent
          ? const Value.absent()
          : Value(company),
      isCustomer: Value(isCustomer),
      createdAt: Value(createdAt),
    );
  }

  factory Contact.fromJson(Map<String, dynamic> json,
      {ValueSerializer? serializer}) {
    serializer ??= driftRuntimeOptions.defaultSerializer;
    return Contact(
      id: serializer.fromJson<String>(json['id']),
      name: serializer.fromJson<String>(json['name']),
      phone: serializer.fromJson<String?>(json['phone']),
      email: serializer.fromJson<String?>(json['email']),
      address: serializer.fromJson<String?>(json['address']),
      company: serializer.fromJson<String?>(json['company']),
      isCustomer: serializer.fromJson<bool>(json['isCustomer']),
      createdAt: serializer.fromJson<DateTime>(json['createdAt']),
    );
  }
  @override
  Map<String, dynamic> toJson({ValueSerializer? serializer}) {
    serializer ??= driftRuntimeOptions.defaultSerializer;
    return <String, dynamic>{
      'id': serializer.toJson<String>(id),
      'name': serializer.toJson<String>(name),
      'phone': serializer.toJson<String?>(phone),
      'email': serializer.toJson<String?>(email),
      'address': serializer.toJson<String?>(address),
      'company': serializer.toJson<String?>(company),
      'isCustomer': serializer.toJson<bool>(isCustomer),
      'createdAt': serializer.toJson<DateTime>(createdAt),
    };
  }

  Contact copyWith(
          {String? id,
          String? name,
          Value<String?> phone = const Value.absent(),
          Value<String?> email = const Value.absent(),
          Value<String?> address = const Value.absent(),
          Value<String?> company = const Value.absent(),
          bool? isCustomer,
          DateTime? createdAt}) =>
      Contact(
        id: id ?? this.id,
        name: name ?? this.name,
        phone: phone.present ? phone.value : this.phone,
        email: email.present ? email.value : this.email,
        address: address.present ? address.value : this.address,
        company: company.present ? company.value : this.company,
        isCustomer: isCustomer ?? this.isCustomer,
        createdAt: createdAt ?? this.createdAt,
      );
  Contact copyWithCompanion(ContactsCompanion data) {
    return Contact(
      id: data.id.present ? data.id.value : this.id,
      name: data.name.present ? data.name.value : this.name,
      phone: data.phone.present ? data.phone.value : this.phone,
      email: data.email.present ? data.email.value : this.email,
      address: data.address.present ? data.address.value : this.address,
      company: data.company.present ? data.company.value : this.company,
      isCustomer:
          data.isCustomer.present ? data.isCustomer.value : this.isCustomer,
      createdAt: data.createdAt.present ? data.createdAt.value : this.createdAt,
    );
  }

  @override
  String toString() {
    return (StringBuffer('Contact(')
          ..write('id: $id, ')
          ..write('name: $name, ')
          ..write('phone: $phone, ')
          ..write('email: $email, ')
          ..write('address: $address, ')
          ..write('company: $company, ')
          ..write('isCustomer: $isCustomer, ')
          ..write('createdAt: $createdAt')
          ..write(')'))
        .toString();
  }

  @override
  int get hashCode => Object.hash(
      id, name, phone, email, address, company, isCustomer, createdAt);
  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      (other is Contact &&
          other.id == this.id &&
          other.name == this.name &&
          other.phone == this.phone &&
          other.email == this.email &&
          other.address == this.address &&
          other.company == this.company &&
          other.isCustomer == this.isCustomer &&
          other.createdAt == this.createdAt);
}

class ContactsCompanion extends UpdateCompanion<Contact> {
  final Value<String> id;
  final Value<String> name;
  final Value<String?> phone;
  final Value<String?> email;
  final Value<String?> address;
  final Value<String?> company;
  final Value<bool> isCustomer;
  final Value<DateTime> createdAt;
  final Value<int> rowid;
  const ContactsCompanion({
    this.id = const Value.absent(),
    this.name = const Value.absent(),
    this.phone = const Value.absent(),
    this.email = const Value.absent(),
    this.address = const Value.absent(),
    this.company = const Value.absent(),
    this.isCustomer = const Value.absent(),
    this.createdAt = const Value.absent(),
    this.rowid = const Value.absent(),
  });
  ContactsCompanion.insert({
    required String id,
    required String name,
    this.phone = const Value.absent(),
    this.email = const Value.absent(),
    this.address = const Value.absent(),
    this.company = const Value.absent(),
    this.isCustomer = const Value.absent(),
    this.createdAt = const Value.absent(),
    this.rowid = const Value.absent(),
  })  : id = Value(id),
        name = Value(name);
  static Insertable<Contact> custom({
    Expression<String>? id,
    Expression<String>? name,
    Expression<String>? phone,
    Expression<String>? email,
    Expression<String>? address,
    Expression<String>? company,
    Expression<bool>? isCustomer,
    Expression<DateTime>? createdAt,
    Expression<int>? rowid,
  }) {
    return RawValuesInsertable({
      if (id != null) 'id': id,
      if (name != null) 'name': name,
      if (phone != null) 'phone': phone,
      if (email != null) 'email': email,
      if (address != null) 'address': address,
      if (company != null) 'company': company,
      if (isCustomer != null) 'is_customer': isCustomer,
      if (createdAt != null) 'created_at': createdAt,
      if (rowid != null) 'rowid': rowid,
    });
  }

  ContactsCompanion copyWith(
      {Value<String>? id,
      Value<String>? name,
      Value<String?>? phone,
      Value<String?>? email,
      Value<String?>? address,
      Value<String?>? company,
      Value<bool>? isCustomer,
      Value<DateTime>? createdAt,
      Value<int>? rowid}) {
    return ContactsCompanion(
      id: id ?? this.id,
      name: name ?? this.name,
      phone: phone ?? this.phone,
      email: email ?? this.email,
      address: address ?? this.address,
      company: company ?? this.company,
      isCustomer: isCustomer ?? this.isCustomer,
      createdAt: createdAt ?? this.createdAt,
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
    if (phone.present) {
      map['phone'] = Variable<String>(phone.value);
    }
    if (email.present) {
      map['email'] = Variable<String>(email.value);
    }
    if (address.present) {
      map['address'] = Variable<String>(address.value);
    }
    if (company.present) {
      map['company'] = Variable<String>(company.value);
    }
    if (isCustomer.present) {
      map['is_customer'] = Variable<bool>(isCustomer.value);
    }
    if (createdAt.present) {
      map['created_at'] = Variable<DateTime>(createdAt.value);
    }
    if (rowid.present) {
      map['rowid'] = Variable<int>(rowid.value);
    }
    return map;
  }

  @override
  String toString() {
    return (StringBuffer('ContactsCompanion(')
          ..write('id: $id, ')
          ..write('name: $name, ')
          ..write('phone: $phone, ')
          ..write('email: $email, ')
          ..write('address: $address, ')
          ..write('company: $company, ')
          ..write('isCustomer: $isCustomer, ')
          ..write('createdAt: $createdAt, ')
          ..write('rowid: $rowid')
          ..write(')'))
        .toString();
  }
}

class $LeadsTable extends Leads with TableInfo<$LeadsTable, Lead> {
  @override
  final GeneratedDatabase attachedDatabase;
  final String? _alias;
  $LeadsTable(this.attachedDatabase, [this._alias]);
  static const VerificationMeta _idMeta = const VerificationMeta('id');
  @override
  late final GeneratedColumn<String> id = GeneratedColumn<String>(
      'id', aliasedName, false,
      type: DriftSqlType.string, requiredDuringInsert: true);
  static const VerificationMeta _titleMeta = const VerificationMeta('title');
  @override
  late final GeneratedColumn<String> title = GeneratedColumn<String>(
      'title', aliasedName, false,
      type: DriftSqlType.string, requiredDuringInsert: true);
  static const VerificationMeta _contactIdMeta =
      const VerificationMeta('contactId');
  @override
  late final GeneratedColumn<String> contactId = GeneratedColumn<String>(
      'contact_id', aliasedName, true,
      type: DriftSqlType.string, requiredDuringInsert: false);
  static const VerificationMeta _statusMeta = const VerificationMeta('status');
  @override
  late final GeneratedColumn<String> status = GeneratedColumn<String>(
      'status', aliasedName, false,
      type: DriftSqlType.string,
      requiredDuringInsert: false,
      defaultValue: const Constant('new'));
  static const VerificationMeta _expectedRevenueMeta =
      const VerificationMeta('expectedRevenue');
  @override
  late final GeneratedColumn<double> expectedRevenue = GeneratedColumn<double>(
      'expected_revenue', aliasedName, false,
      type: DriftSqlType.double,
      requiredDuringInsert: false,
      defaultValue: const Constant(0.0));
  static const VerificationMeta _notesMeta = const VerificationMeta('notes');
  @override
  late final GeneratedColumn<String> notes = GeneratedColumn<String>(
      'notes', aliasedName, true,
      type: DriftSqlType.string, requiredDuringInsert: false);
  static const VerificationMeta _sourceMeta = const VerificationMeta('source');
  @override
  late final GeneratedColumn<String> source = GeneratedColumn<String>(
      'source', aliasedName, false,
      type: DriftSqlType.string,
      requiredDuringInsert: false,
      defaultValue: const Constant('direct'));
  static const VerificationMeta _ownerIdMeta =
      const VerificationMeta('ownerId');
  @override
  late final GeneratedColumn<String> ownerId = GeneratedColumn<String>(
      'owner_id', aliasedName, true,
      type: DriftSqlType.string, requiredDuringInsert: false);
  static const VerificationMeta _customFieldsMeta =
      const VerificationMeta('customFields');
  @override
  late final GeneratedColumn<String> customFields = GeneratedColumn<String>(
      'custom_fields', aliasedName, false,
      type: DriftSqlType.string,
      requiredDuringInsert: false,
      defaultValue: const Constant('{}'));
  static const VerificationMeta _createdAtMeta =
      const VerificationMeta('createdAt');
  @override
  late final GeneratedColumn<DateTime> createdAt = GeneratedColumn<DateTime>(
      'created_at', aliasedName, false,
      type: DriftSqlType.dateTime,
      requiredDuringInsert: false,
      defaultValue: currentDateAndTime);
  @override
  List<GeneratedColumn> get $columns => [
        id,
        title,
        contactId,
        status,
        expectedRevenue,
        notes,
        source,
        ownerId,
        customFields,
        createdAt
      ];
  @override
  String get aliasedName => _alias ?? actualTableName;
  @override
  String get actualTableName => $name;
  static const String $name = 'leads';
  @override
  VerificationContext validateIntegrity(Insertable<Lead> instance,
      {bool isInserting = false}) {
    final context = VerificationContext();
    final data = instance.toColumns(true);
    if (data.containsKey('id')) {
      context.handle(_idMeta, id.isAcceptableOrUnknown(data['id']!, _idMeta));
    } else if (isInserting) {
      context.missing(_idMeta);
    }
    if (data.containsKey('title')) {
      context.handle(
          _titleMeta, title.isAcceptableOrUnknown(data['title']!, _titleMeta));
    } else if (isInserting) {
      context.missing(_titleMeta);
    }
    if (data.containsKey('contact_id')) {
      context.handle(_contactIdMeta,
          contactId.isAcceptableOrUnknown(data['contact_id']!, _contactIdMeta));
    }
    if (data.containsKey('status')) {
      context.handle(_statusMeta,
          status.isAcceptableOrUnknown(data['status']!, _statusMeta));
    }
    if (data.containsKey('expected_revenue')) {
      context.handle(
          _expectedRevenueMeta,
          expectedRevenue.isAcceptableOrUnknown(
              data['expected_revenue']!, _expectedRevenueMeta));
    }
    if (data.containsKey('notes')) {
      context.handle(
          _notesMeta, notes.isAcceptableOrUnknown(data['notes']!, _notesMeta));
    }
    if (data.containsKey('source')) {
      context.handle(_sourceMeta,
          source.isAcceptableOrUnknown(data['source']!, _sourceMeta));
    }
    if (data.containsKey('owner_id')) {
      context.handle(_ownerIdMeta,
          ownerId.isAcceptableOrUnknown(data['owner_id']!, _ownerIdMeta));
    }
    if (data.containsKey('custom_fields')) {
      context.handle(
          _customFieldsMeta,
          customFields.isAcceptableOrUnknown(
              data['custom_fields']!, _customFieldsMeta));
    }
    if (data.containsKey('created_at')) {
      context.handle(_createdAtMeta,
          createdAt.isAcceptableOrUnknown(data['created_at']!, _createdAtMeta));
    }
    return context;
  }

  @override
  Set<GeneratedColumn> get $primaryKey => {id};
  @override
  Lead map(Map<String, dynamic> data, {String? tablePrefix}) {
    final effectivePrefix = tablePrefix != null ? '$tablePrefix.' : '';
    return Lead(
      id: attachedDatabase.typeMapping
          .read(DriftSqlType.string, data['${effectivePrefix}id'])!,
      title: attachedDatabase.typeMapping
          .read(DriftSqlType.string, data['${effectivePrefix}title'])!,
      contactId: attachedDatabase.typeMapping
          .read(DriftSqlType.string, data['${effectivePrefix}contact_id']),
      status: attachedDatabase.typeMapping
          .read(DriftSqlType.string, data['${effectivePrefix}status'])!,
      expectedRevenue: attachedDatabase.typeMapping.read(
          DriftSqlType.double, data['${effectivePrefix}expected_revenue'])!,
      notes: attachedDatabase.typeMapping
          .read(DriftSqlType.string, data['${effectivePrefix}notes']),
      source: attachedDatabase.typeMapping
          .read(DriftSqlType.string, data['${effectivePrefix}source'])!,
      ownerId: attachedDatabase.typeMapping
          .read(DriftSqlType.string, data['${effectivePrefix}owner_id']),
      customFields: attachedDatabase.typeMapping
          .read(DriftSqlType.string, data['${effectivePrefix}custom_fields'])!,
      createdAt: attachedDatabase.typeMapping
          .read(DriftSqlType.dateTime, data['${effectivePrefix}created_at'])!,
    );
  }

  @override
  $LeadsTable createAlias(String alias) {
    return $LeadsTable(attachedDatabase, alias);
  }
}

class Lead extends DataClass implements Insertable<Lead> {
  final String id;
  final String title;
  final String? contactId;
  final String status;
  final double expectedRevenue;
  final String? notes;
  final String source;
  final String? ownerId;
  final String customFields;
  final DateTime createdAt;
  const Lead(
      {required this.id,
      required this.title,
      this.contactId,
      required this.status,
      required this.expectedRevenue,
      this.notes,
      required this.source,
      this.ownerId,
      required this.customFields,
      required this.createdAt});
  @override
  Map<String, Expression> toColumns(bool nullToAbsent) {
    final map = <String, Expression>{};
    map['id'] = Variable<String>(id);
    map['title'] = Variable<String>(title);
    if (!nullToAbsent || contactId != null) {
      map['contact_id'] = Variable<String>(contactId);
    }
    map['status'] = Variable<String>(status);
    map['expected_revenue'] = Variable<double>(expectedRevenue);
    if (!nullToAbsent || notes != null) {
      map['notes'] = Variable<String>(notes);
    }
    map['source'] = Variable<String>(source);
    if (!nullToAbsent || ownerId != null) {
      map['owner_id'] = Variable<String>(ownerId);
    }
    map['custom_fields'] = Variable<String>(customFields);
    map['created_at'] = Variable<DateTime>(createdAt);
    return map;
  }

  LeadsCompanion toCompanion(bool nullToAbsent) {
    return LeadsCompanion(
      id: Value(id),
      title: Value(title),
      contactId: contactId == null && nullToAbsent
          ? const Value.absent()
          : Value(contactId),
      status: Value(status),
      expectedRevenue: Value(expectedRevenue),
      notes:
          notes == null && nullToAbsent ? const Value.absent() : Value(notes),
      source: Value(source),
      ownerId: ownerId == null && nullToAbsent
          ? const Value.absent()
          : Value(ownerId),
      customFields: Value(customFields),
      createdAt: Value(createdAt),
    );
  }

  factory Lead.fromJson(Map<String, dynamic> json,
      {ValueSerializer? serializer}) {
    serializer ??= driftRuntimeOptions.defaultSerializer;
    return Lead(
      id: serializer.fromJson<String>(json['id']),
      title: serializer.fromJson<String>(json['title']),
      contactId: serializer.fromJson<String?>(json['contactId']),
      status: serializer.fromJson<String>(json['status']),
      expectedRevenue: serializer.fromJson<double>(json['expectedRevenue']),
      notes: serializer.fromJson<String?>(json['notes']),
      source: serializer.fromJson<String>(json['source']),
      ownerId: serializer.fromJson<String?>(json['ownerId']),
      customFields: serializer.fromJson<String>(json['customFields']),
      createdAt: serializer.fromJson<DateTime>(json['createdAt']),
    );
  }
  @override
  Map<String, dynamic> toJson({ValueSerializer? serializer}) {
    serializer ??= driftRuntimeOptions.defaultSerializer;
    return <String, dynamic>{
      'id': serializer.toJson<String>(id),
      'title': serializer.toJson<String>(title),
      'contactId': serializer.toJson<String?>(contactId),
      'status': serializer.toJson<String>(status),
      'expectedRevenue': serializer.toJson<double>(expectedRevenue),
      'notes': serializer.toJson<String?>(notes),
      'source': serializer.toJson<String>(source),
      'ownerId': serializer.toJson<String?>(ownerId),
      'customFields': serializer.toJson<String>(customFields),
      'createdAt': serializer.toJson<DateTime>(createdAt),
    };
  }

  Lead copyWith(
          {String? id,
          String? title,
          Value<String?> contactId = const Value.absent(),
          String? status,
          double? expectedRevenue,
          Value<String?> notes = const Value.absent(),
          String? source,
          Value<String?> ownerId = const Value.absent(),
          String? customFields,
          DateTime? createdAt}) =>
      Lead(
        id: id ?? this.id,
        title: title ?? this.title,
        contactId: contactId.present ? contactId.value : this.contactId,
        status: status ?? this.status,
        expectedRevenue: expectedRevenue ?? this.expectedRevenue,
        notes: notes.present ? notes.value : this.notes,
        source: source ?? this.source,
        ownerId: ownerId.present ? ownerId.value : this.ownerId,
        customFields: customFields ?? this.customFields,
        createdAt: createdAt ?? this.createdAt,
      );
  Lead copyWithCompanion(LeadsCompanion data) {
    return Lead(
      id: data.id.present ? data.id.value : this.id,
      title: data.title.present ? data.title.value : this.title,
      contactId: data.contactId.present ? data.contactId.value : this.contactId,
      status: data.status.present ? data.status.value : this.status,
      expectedRevenue: data.expectedRevenue.present
          ? data.expectedRevenue.value
          : this.expectedRevenue,
      notes: data.notes.present ? data.notes.value : this.notes,
      source: data.source.present ? data.source.value : this.source,
      ownerId: data.ownerId.present ? data.ownerId.value : this.ownerId,
      customFields: data.customFields.present
          ? data.customFields.value
          : this.customFields,
      createdAt: data.createdAt.present ? data.createdAt.value : this.createdAt,
    );
  }

  @override
  String toString() {
    return (StringBuffer('Lead(')
          ..write('id: $id, ')
          ..write('title: $title, ')
          ..write('contactId: $contactId, ')
          ..write('status: $status, ')
          ..write('expectedRevenue: $expectedRevenue, ')
          ..write('notes: $notes, ')
          ..write('source: $source, ')
          ..write('ownerId: $ownerId, ')
          ..write('customFields: $customFields, ')
          ..write('createdAt: $createdAt')
          ..write(')'))
        .toString();
  }

  @override
  int get hashCode => Object.hash(id, title, contactId, status, expectedRevenue,
      notes, source, ownerId, customFields, createdAt);
  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      (other is Lead &&
          other.id == this.id &&
          other.title == this.title &&
          other.contactId == this.contactId &&
          other.status == this.status &&
          other.expectedRevenue == this.expectedRevenue &&
          other.notes == this.notes &&
          other.source == this.source &&
          other.ownerId == this.ownerId &&
          other.customFields == this.customFields &&
          other.createdAt == this.createdAt);
}

class LeadsCompanion extends UpdateCompanion<Lead> {
  final Value<String> id;
  final Value<String> title;
  final Value<String?> contactId;
  final Value<String> status;
  final Value<double> expectedRevenue;
  final Value<String?> notes;
  final Value<String> source;
  final Value<String?> ownerId;
  final Value<String> customFields;
  final Value<DateTime> createdAt;
  final Value<int> rowid;
  const LeadsCompanion({
    this.id = const Value.absent(),
    this.title = const Value.absent(),
    this.contactId = const Value.absent(),
    this.status = const Value.absent(),
    this.expectedRevenue = const Value.absent(),
    this.notes = const Value.absent(),
    this.source = const Value.absent(),
    this.ownerId = const Value.absent(),
    this.customFields = const Value.absent(),
    this.createdAt = const Value.absent(),
    this.rowid = const Value.absent(),
  });
  LeadsCompanion.insert({
    required String id,
    required String title,
    this.contactId = const Value.absent(),
    this.status = const Value.absent(),
    this.expectedRevenue = const Value.absent(),
    this.notes = const Value.absent(),
    this.source = const Value.absent(),
    this.ownerId = const Value.absent(),
    this.customFields = const Value.absent(),
    this.createdAt = const Value.absent(),
    this.rowid = const Value.absent(),
  })  : id = Value(id),
        title = Value(title);
  static Insertable<Lead> custom({
    Expression<String>? id,
    Expression<String>? title,
    Expression<String>? contactId,
    Expression<String>? status,
    Expression<double>? expectedRevenue,
    Expression<String>? notes,
    Expression<String>? source,
    Expression<String>? ownerId,
    Expression<String>? customFields,
    Expression<DateTime>? createdAt,
    Expression<int>? rowid,
  }) {
    return RawValuesInsertable({
      if (id != null) 'id': id,
      if (title != null) 'title': title,
      if (contactId != null) 'contact_id': contactId,
      if (status != null) 'status': status,
      if (expectedRevenue != null) 'expected_revenue': expectedRevenue,
      if (notes != null) 'notes': notes,
      if (source != null) 'source': source,
      if (ownerId != null) 'owner_id': ownerId,
      if (customFields != null) 'custom_fields': customFields,
      if (createdAt != null) 'created_at': createdAt,
      if (rowid != null) 'rowid': rowid,
    });
  }

  LeadsCompanion copyWith(
      {Value<String>? id,
      Value<String>? title,
      Value<String?>? contactId,
      Value<String>? status,
      Value<double>? expectedRevenue,
      Value<String?>? notes,
      Value<String>? source,
      Value<String?>? ownerId,
      Value<String>? customFields,
      Value<DateTime>? createdAt,
      Value<int>? rowid}) {
    return LeadsCompanion(
      id: id ?? this.id,
      title: title ?? this.title,
      contactId: contactId ?? this.contactId,
      status: status ?? this.status,
      expectedRevenue: expectedRevenue ?? this.expectedRevenue,
      notes: notes ?? this.notes,
      source: source ?? this.source,
      ownerId: ownerId ?? this.ownerId,
      customFields: customFields ?? this.customFields,
      createdAt: createdAt ?? this.createdAt,
      rowid: rowid ?? this.rowid,
    );
  }

  @override
  Map<String, Expression> toColumns(bool nullToAbsent) {
    final map = <String, Expression>{};
    if (id.present) {
      map['id'] = Variable<String>(id.value);
    }
    if (title.present) {
      map['title'] = Variable<String>(title.value);
    }
    if (contactId.present) {
      map['contact_id'] = Variable<String>(contactId.value);
    }
    if (status.present) {
      map['status'] = Variable<String>(status.value);
    }
    if (expectedRevenue.present) {
      map['expected_revenue'] = Variable<double>(expectedRevenue.value);
    }
    if (notes.present) {
      map['notes'] = Variable<String>(notes.value);
    }
    if (source.present) {
      map['source'] = Variable<String>(source.value);
    }
    if (ownerId.present) {
      map['owner_id'] = Variable<String>(ownerId.value);
    }
    if (customFields.present) {
      map['custom_fields'] = Variable<String>(customFields.value);
    }
    if (createdAt.present) {
      map['created_at'] = Variable<DateTime>(createdAt.value);
    }
    if (rowid.present) {
      map['rowid'] = Variable<int>(rowid.value);
    }
    return map;
  }

  @override
  String toString() {
    return (StringBuffer('LeadsCompanion(')
          ..write('id: $id, ')
          ..write('title: $title, ')
          ..write('contactId: $contactId, ')
          ..write('status: $status, ')
          ..write('expectedRevenue: $expectedRevenue, ')
          ..write('notes: $notes, ')
          ..write('source: $source, ')
          ..write('ownerId: $ownerId, ')
          ..write('customFields: $customFields, ')
          ..write('createdAt: $createdAt, ')
          ..write('rowid: $rowid')
          ..write(')'))
        .toString();
  }
}

class $DealsTable extends Deals with TableInfo<$DealsTable, Deal> {
  @override
  final GeneratedDatabase attachedDatabase;
  final String? _alias;
  $DealsTable(this.attachedDatabase, [this._alias]);
  static const VerificationMeta _idMeta = const VerificationMeta('id');
  @override
  late final GeneratedColumn<String> id = GeneratedColumn<String>(
      'id', aliasedName, false,
      type: DriftSqlType.string, requiredDuringInsert: true);
  static const VerificationMeta _titleMeta = const VerificationMeta('title');
  @override
  late final GeneratedColumn<String> title = GeneratedColumn<String>(
      'title', aliasedName, false,
      type: DriftSqlType.string, requiredDuringInsert: true);
  static const VerificationMeta _leadIdMeta = const VerificationMeta('leadId');
  @override
  late final GeneratedColumn<String> leadId = GeneratedColumn<String>(
      'lead_id', aliasedName, true,
      type: DriftSqlType.string, requiredDuringInsert: false);
  static const VerificationMeta _contactIdMeta =
      const VerificationMeta('contactId');
  @override
  late final GeneratedColumn<String> contactId = GeneratedColumn<String>(
      'contact_id', aliasedName, false,
      type: DriftSqlType.string, requiredDuringInsert: true);
  static const VerificationMeta _amountMeta = const VerificationMeta('amount');
  @override
  late final GeneratedColumn<double> amount = GeneratedColumn<double>(
      'amount', aliasedName, false,
      type: DriftSqlType.double, requiredDuringInsert: true);
  static const VerificationMeta _stageMeta = const VerificationMeta('stage');
  @override
  late final GeneratedColumn<String> stage = GeneratedColumn<String>(
      'stage', aliasedName, false,
      type: DriftSqlType.string,
      requiredDuringInsert: false,
      defaultValue: const Constant('proposal'));
  static const VerificationMeta _sourceMeta = const VerificationMeta('source');
  @override
  late final GeneratedColumn<String> source = GeneratedColumn<String>(
      'source', aliasedName, false,
      type: DriftSqlType.string,
      requiredDuringInsert: false,
      defaultValue: const Constant('direct'));
  static const VerificationMeta _ownerIdMeta =
      const VerificationMeta('ownerId');
  @override
  late final GeneratedColumn<String> ownerId = GeneratedColumn<String>(
      'owner_id', aliasedName, true,
      type: DriftSqlType.string, requiredDuringInsert: false);
  static const VerificationMeta _expectedCloseDateMeta =
      const VerificationMeta('expectedCloseDate');
  @override
  late final GeneratedColumn<DateTime> expectedCloseDate =
      GeneratedColumn<DateTime>('expected_close_date', aliasedName, true,
          type: DriftSqlType.dateTime, requiredDuringInsert: false);
  static const VerificationMeta _createdAtMeta =
      const VerificationMeta('createdAt');
  @override
  late final GeneratedColumn<DateTime> createdAt = GeneratedColumn<DateTime>(
      'created_at', aliasedName, false,
      type: DriftSqlType.dateTime,
      requiredDuringInsert: false,
      defaultValue: currentDateAndTime);
  @override
  List<GeneratedColumn> get $columns => [
        id,
        title,
        leadId,
        contactId,
        amount,
        stage,
        source,
        ownerId,
        expectedCloseDate,
        createdAt
      ];
  @override
  String get aliasedName => _alias ?? actualTableName;
  @override
  String get actualTableName => $name;
  static const String $name = 'deals';
  @override
  VerificationContext validateIntegrity(Insertable<Deal> instance,
      {bool isInserting = false}) {
    final context = VerificationContext();
    final data = instance.toColumns(true);
    if (data.containsKey('id')) {
      context.handle(_idMeta, id.isAcceptableOrUnknown(data['id']!, _idMeta));
    } else if (isInserting) {
      context.missing(_idMeta);
    }
    if (data.containsKey('title')) {
      context.handle(
          _titleMeta, title.isAcceptableOrUnknown(data['title']!, _titleMeta));
    } else if (isInserting) {
      context.missing(_titleMeta);
    }
    if (data.containsKey('lead_id')) {
      context.handle(_leadIdMeta,
          leadId.isAcceptableOrUnknown(data['lead_id']!, _leadIdMeta));
    }
    if (data.containsKey('contact_id')) {
      context.handle(_contactIdMeta,
          contactId.isAcceptableOrUnknown(data['contact_id']!, _contactIdMeta));
    } else if (isInserting) {
      context.missing(_contactIdMeta);
    }
    if (data.containsKey('amount')) {
      context.handle(_amountMeta,
          amount.isAcceptableOrUnknown(data['amount']!, _amountMeta));
    } else if (isInserting) {
      context.missing(_amountMeta);
    }
    if (data.containsKey('stage')) {
      context.handle(
          _stageMeta, stage.isAcceptableOrUnknown(data['stage']!, _stageMeta));
    }
    if (data.containsKey('source')) {
      context.handle(_sourceMeta,
          source.isAcceptableOrUnknown(data['source']!, _sourceMeta));
    }
    if (data.containsKey('owner_id')) {
      context.handle(_ownerIdMeta,
          ownerId.isAcceptableOrUnknown(data['owner_id']!, _ownerIdMeta));
    }
    if (data.containsKey('expected_close_date')) {
      context.handle(
          _expectedCloseDateMeta,
          expectedCloseDate.isAcceptableOrUnknown(
              data['expected_close_date']!, _expectedCloseDateMeta));
    }
    if (data.containsKey('created_at')) {
      context.handle(_createdAtMeta,
          createdAt.isAcceptableOrUnknown(data['created_at']!, _createdAtMeta));
    }
    return context;
  }

  @override
  Set<GeneratedColumn> get $primaryKey => {id};
  @override
  Deal map(Map<String, dynamic> data, {String? tablePrefix}) {
    final effectivePrefix = tablePrefix != null ? '$tablePrefix.' : '';
    return Deal(
      id: attachedDatabase.typeMapping
          .read(DriftSqlType.string, data['${effectivePrefix}id'])!,
      title: attachedDatabase.typeMapping
          .read(DriftSqlType.string, data['${effectivePrefix}title'])!,
      leadId: attachedDatabase.typeMapping
          .read(DriftSqlType.string, data['${effectivePrefix}lead_id']),
      contactId: attachedDatabase.typeMapping
          .read(DriftSqlType.string, data['${effectivePrefix}contact_id'])!,
      amount: attachedDatabase.typeMapping
          .read(DriftSqlType.double, data['${effectivePrefix}amount'])!,
      stage: attachedDatabase.typeMapping
          .read(DriftSqlType.string, data['${effectivePrefix}stage'])!,
      source: attachedDatabase.typeMapping
          .read(DriftSqlType.string, data['${effectivePrefix}source'])!,
      ownerId: attachedDatabase.typeMapping
          .read(DriftSqlType.string, data['${effectivePrefix}owner_id']),
      expectedCloseDate: attachedDatabase.typeMapping.read(
          DriftSqlType.dateTime, data['${effectivePrefix}expected_close_date']),
      createdAt: attachedDatabase.typeMapping
          .read(DriftSqlType.dateTime, data['${effectivePrefix}created_at'])!,
    );
  }

  @override
  $DealsTable createAlias(String alias) {
    return $DealsTable(attachedDatabase, alias);
  }
}

class Deal extends DataClass implements Insertable<Deal> {
  final String id;
  final String title;
  final String? leadId;
  final String contactId;
  final double amount;
  final String stage;
  final String source;
  final String? ownerId;
  final DateTime? expectedCloseDate;
  final DateTime createdAt;
  const Deal(
      {required this.id,
      required this.title,
      this.leadId,
      required this.contactId,
      required this.amount,
      required this.stage,
      required this.source,
      this.ownerId,
      this.expectedCloseDate,
      required this.createdAt});
  @override
  Map<String, Expression> toColumns(bool nullToAbsent) {
    final map = <String, Expression>{};
    map['id'] = Variable<String>(id);
    map['title'] = Variable<String>(title);
    if (!nullToAbsent || leadId != null) {
      map['lead_id'] = Variable<String>(leadId);
    }
    map['contact_id'] = Variable<String>(contactId);
    map['amount'] = Variable<double>(amount);
    map['stage'] = Variable<String>(stage);
    map['source'] = Variable<String>(source);
    if (!nullToAbsent || ownerId != null) {
      map['owner_id'] = Variable<String>(ownerId);
    }
    if (!nullToAbsent || expectedCloseDate != null) {
      map['expected_close_date'] = Variable<DateTime>(expectedCloseDate);
    }
    map['created_at'] = Variable<DateTime>(createdAt);
    return map;
  }

  DealsCompanion toCompanion(bool nullToAbsent) {
    return DealsCompanion(
      id: Value(id),
      title: Value(title),
      leadId:
          leadId == null && nullToAbsent ? const Value.absent() : Value(leadId),
      contactId: Value(contactId),
      amount: Value(amount),
      stage: Value(stage),
      source: Value(source),
      ownerId: ownerId == null && nullToAbsent
          ? const Value.absent()
          : Value(ownerId),
      expectedCloseDate: expectedCloseDate == null && nullToAbsent
          ? const Value.absent()
          : Value(expectedCloseDate),
      createdAt: Value(createdAt),
    );
  }

  factory Deal.fromJson(Map<String, dynamic> json,
      {ValueSerializer? serializer}) {
    serializer ??= driftRuntimeOptions.defaultSerializer;
    return Deal(
      id: serializer.fromJson<String>(json['id']),
      title: serializer.fromJson<String>(json['title']),
      leadId: serializer.fromJson<String?>(json['leadId']),
      contactId: serializer.fromJson<String>(json['contactId']),
      amount: serializer.fromJson<double>(json['amount']),
      stage: serializer.fromJson<String>(json['stage']),
      source: serializer.fromJson<String>(json['source']),
      ownerId: serializer.fromJson<String?>(json['ownerId']),
      expectedCloseDate:
          serializer.fromJson<DateTime?>(json['expectedCloseDate']),
      createdAt: serializer.fromJson<DateTime>(json['createdAt']),
    );
  }
  @override
  Map<String, dynamic> toJson({ValueSerializer? serializer}) {
    serializer ??= driftRuntimeOptions.defaultSerializer;
    return <String, dynamic>{
      'id': serializer.toJson<String>(id),
      'title': serializer.toJson<String>(title),
      'leadId': serializer.toJson<String?>(leadId),
      'contactId': serializer.toJson<String>(contactId),
      'amount': serializer.toJson<double>(amount),
      'stage': serializer.toJson<String>(stage),
      'source': serializer.toJson<String>(source),
      'ownerId': serializer.toJson<String?>(ownerId),
      'expectedCloseDate': serializer.toJson<DateTime?>(expectedCloseDate),
      'createdAt': serializer.toJson<DateTime>(createdAt),
    };
  }

  Deal copyWith(
          {String? id,
          String? title,
          Value<String?> leadId = const Value.absent(),
          String? contactId,
          double? amount,
          String? stage,
          String? source,
          Value<String?> ownerId = const Value.absent(),
          Value<DateTime?> expectedCloseDate = const Value.absent(),
          DateTime? createdAt}) =>
      Deal(
        id: id ?? this.id,
        title: title ?? this.title,
        leadId: leadId.present ? leadId.value : this.leadId,
        contactId: contactId ?? this.contactId,
        amount: amount ?? this.amount,
        stage: stage ?? this.stage,
        source: source ?? this.source,
        ownerId: ownerId.present ? ownerId.value : this.ownerId,
        expectedCloseDate: expectedCloseDate.present
            ? expectedCloseDate.value
            : this.expectedCloseDate,
        createdAt: createdAt ?? this.createdAt,
      );
  Deal copyWithCompanion(DealsCompanion data) {
    return Deal(
      id: data.id.present ? data.id.value : this.id,
      title: data.title.present ? data.title.value : this.title,
      leadId: data.leadId.present ? data.leadId.value : this.leadId,
      contactId: data.contactId.present ? data.contactId.value : this.contactId,
      amount: data.amount.present ? data.amount.value : this.amount,
      stage: data.stage.present ? data.stage.value : this.stage,
      source: data.source.present ? data.source.value : this.source,
      ownerId: data.ownerId.present ? data.ownerId.value : this.ownerId,
      expectedCloseDate: data.expectedCloseDate.present
          ? data.expectedCloseDate.value
          : this.expectedCloseDate,
      createdAt: data.createdAt.present ? data.createdAt.value : this.createdAt,
    );
  }

  @override
  String toString() {
    return (StringBuffer('Deal(')
          ..write('id: $id, ')
          ..write('title: $title, ')
          ..write('leadId: $leadId, ')
          ..write('contactId: $contactId, ')
          ..write('amount: $amount, ')
          ..write('stage: $stage, ')
          ..write('source: $source, ')
          ..write('ownerId: $ownerId, ')
          ..write('expectedCloseDate: $expectedCloseDate, ')
          ..write('createdAt: $createdAt')
          ..write(')'))
        .toString();
  }

  @override
  int get hashCode => Object.hash(id, title, leadId, contactId, amount, stage,
      source, ownerId, expectedCloseDate, createdAt);
  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      (other is Deal &&
          other.id == this.id &&
          other.title == this.title &&
          other.leadId == this.leadId &&
          other.contactId == this.contactId &&
          other.amount == this.amount &&
          other.stage == this.stage &&
          other.source == this.source &&
          other.ownerId == this.ownerId &&
          other.expectedCloseDate == this.expectedCloseDate &&
          other.createdAt == this.createdAt);
}

class DealsCompanion extends UpdateCompanion<Deal> {
  final Value<String> id;
  final Value<String> title;
  final Value<String?> leadId;
  final Value<String> contactId;
  final Value<double> amount;
  final Value<String> stage;
  final Value<String> source;
  final Value<String?> ownerId;
  final Value<DateTime?> expectedCloseDate;
  final Value<DateTime> createdAt;
  final Value<int> rowid;
  const DealsCompanion({
    this.id = const Value.absent(),
    this.title = const Value.absent(),
    this.leadId = const Value.absent(),
    this.contactId = const Value.absent(),
    this.amount = const Value.absent(),
    this.stage = const Value.absent(),
    this.source = const Value.absent(),
    this.ownerId = const Value.absent(),
    this.expectedCloseDate = const Value.absent(),
    this.createdAt = const Value.absent(),
    this.rowid = const Value.absent(),
  });
  DealsCompanion.insert({
    required String id,
    required String title,
    this.leadId = const Value.absent(),
    required String contactId,
    required double amount,
    this.stage = const Value.absent(),
    this.source = const Value.absent(),
    this.ownerId = const Value.absent(),
    this.expectedCloseDate = const Value.absent(),
    this.createdAt = const Value.absent(),
    this.rowid = const Value.absent(),
  })  : id = Value(id),
        title = Value(title),
        contactId = Value(contactId),
        amount = Value(amount);
  static Insertable<Deal> custom({
    Expression<String>? id,
    Expression<String>? title,
    Expression<String>? leadId,
    Expression<String>? contactId,
    Expression<double>? amount,
    Expression<String>? stage,
    Expression<String>? source,
    Expression<String>? ownerId,
    Expression<DateTime>? expectedCloseDate,
    Expression<DateTime>? createdAt,
    Expression<int>? rowid,
  }) {
    return RawValuesInsertable({
      if (id != null) 'id': id,
      if (title != null) 'title': title,
      if (leadId != null) 'lead_id': leadId,
      if (contactId != null) 'contact_id': contactId,
      if (amount != null) 'amount': amount,
      if (stage != null) 'stage': stage,
      if (source != null) 'source': source,
      if (ownerId != null) 'owner_id': ownerId,
      if (expectedCloseDate != null) 'expected_close_date': expectedCloseDate,
      if (createdAt != null) 'created_at': createdAt,
      if (rowid != null) 'rowid': rowid,
    });
  }

  DealsCompanion copyWith(
      {Value<String>? id,
      Value<String>? title,
      Value<String?>? leadId,
      Value<String>? contactId,
      Value<double>? amount,
      Value<String>? stage,
      Value<String>? source,
      Value<String?>? ownerId,
      Value<DateTime?>? expectedCloseDate,
      Value<DateTime>? createdAt,
      Value<int>? rowid}) {
    return DealsCompanion(
      id: id ?? this.id,
      title: title ?? this.title,
      leadId: leadId ?? this.leadId,
      contactId: contactId ?? this.contactId,
      amount: amount ?? this.amount,
      stage: stage ?? this.stage,
      source: source ?? this.source,
      ownerId: ownerId ?? this.ownerId,
      expectedCloseDate: expectedCloseDate ?? this.expectedCloseDate,
      createdAt: createdAt ?? this.createdAt,
      rowid: rowid ?? this.rowid,
    );
  }

  @override
  Map<String, Expression> toColumns(bool nullToAbsent) {
    final map = <String, Expression>{};
    if (id.present) {
      map['id'] = Variable<String>(id.value);
    }
    if (title.present) {
      map['title'] = Variable<String>(title.value);
    }
    if (leadId.present) {
      map['lead_id'] = Variable<String>(leadId.value);
    }
    if (contactId.present) {
      map['contact_id'] = Variable<String>(contactId.value);
    }
    if (amount.present) {
      map['amount'] = Variable<double>(amount.value);
    }
    if (stage.present) {
      map['stage'] = Variable<String>(stage.value);
    }
    if (source.present) {
      map['source'] = Variable<String>(source.value);
    }
    if (ownerId.present) {
      map['owner_id'] = Variable<String>(ownerId.value);
    }
    if (expectedCloseDate.present) {
      map['expected_close_date'] = Variable<DateTime>(expectedCloseDate.value);
    }
    if (createdAt.present) {
      map['created_at'] = Variable<DateTime>(createdAt.value);
    }
    if (rowid.present) {
      map['rowid'] = Variable<int>(rowid.value);
    }
    return map;
  }

  @override
  String toString() {
    return (StringBuffer('DealsCompanion(')
          ..write('id: $id, ')
          ..write('title: $title, ')
          ..write('leadId: $leadId, ')
          ..write('contactId: $contactId, ')
          ..write('amount: $amount, ')
          ..write('stage: $stage, ')
          ..write('source: $source, ')
          ..write('ownerId: $ownerId, ')
          ..write('expectedCloseDate: $expectedCloseDate, ')
          ..write('createdAt: $createdAt, ')
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
      'id', aliasedName, false,
      type: DriftSqlType.string, requiredDuringInsert: true);
  static const VerificationMeta _skuMeta = const VerificationMeta('sku');
  @override
  late final GeneratedColumn<String> sku = GeneratedColumn<String>(
      'sku', aliasedName, false,
      type: DriftSqlType.string,
      requiredDuringInsert: true,
      defaultConstraints: GeneratedColumn.constraintIsAlways('UNIQUE'));
  static const VerificationMeta _nameMeta = const VerificationMeta('name');
  @override
  late final GeneratedColumn<String> name = GeneratedColumn<String>(
      'name', aliasedName, false,
      type: DriftSqlType.string, requiredDuringInsert: true);
  static const VerificationMeta _priceMeta = const VerificationMeta('price');
  @override
  late final GeneratedColumn<double> price = GeneratedColumn<double>(
      'price', aliasedName, false,
      type: DriftSqlType.double, requiredDuringInsert: true);
  static const VerificationMeta _costMeta = const VerificationMeta('cost');
  @override
  late final GeneratedColumn<double> cost = GeneratedColumn<double>(
      'cost', aliasedName, false,
      type: DriftSqlType.double, requiredDuringInsert: true);
  static const VerificationMeta _typeMeta = const VerificationMeta('type');
  @override
  late final GeneratedColumn<String> type = GeneratedColumn<String>(
      'type', aliasedName, false,
      type: DriftSqlType.string,
      requiredDuringInsert: false,
      defaultValue: const Constant('product'));
  static const VerificationMeta _barcodeMeta =
      const VerificationMeta('barcode');
  @override
  late final GeneratedColumn<String> barcode = GeneratedColumn<String>(
      'barcode', aliasedName, true,
      type: DriftSqlType.string, requiredDuringInsert: false);
  static const VerificationMeta _customFieldsMeta =
      const VerificationMeta('customFields');
  @override
  late final GeneratedColumn<String> customFields = GeneratedColumn<String>(
      'custom_fields', aliasedName, false,
      type: DriftSqlType.string,
      requiredDuringInsert: false,
      defaultValue: const Constant('{}'));
  static const VerificationMeta _createdAtMeta =
      const VerificationMeta('createdAt');
  @override
  late final GeneratedColumn<DateTime> createdAt = GeneratedColumn<DateTime>(
      'created_at', aliasedName, false,
      type: DriftSqlType.dateTime,
      requiredDuringInsert: false,
      defaultValue: currentDateAndTime);
  @override
  List<GeneratedColumn> get $columns =>
      [id, sku, name, price, cost, type, barcode, customFields, createdAt];
  @override
  String get aliasedName => _alias ?? actualTableName;
  @override
  String get actualTableName => $name;
  static const String $name = 'products';
  @override
  VerificationContext validateIntegrity(Insertable<Product> instance,
      {bool isInserting = false}) {
    final context = VerificationContext();
    final data = instance.toColumns(true);
    if (data.containsKey('id')) {
      context.handle(_idMeta, id.isAcceptableOrUnknown(data['id']!, _idMeta));
    } else if (isInserting) {
      context.missing(_idMeta);
    }
    if (data.containsKey('sku')) {
      context.handle(
          _skuMeta, sku.isAcceptableOrUnknown(data['sku']!, _skuMeta));
    } else if (isInserting) {
      context.missing(_skuMeta);
    }
    if (data.containsKey('name')) {
      context.handle(
          _nameMeta, name.isAcceptableOrUnknown(data['name']!, _nameMeta));
    } else if (isInserting) {
      context.missing(_nameMeta);
    }
    if (data.containsKey('price')) {
      context.handle(
          _priceMeta, price.isAcceptableOrUnknown(data['price']!, _priceMeta));
    } else if (isInserting) {
      context.missing(_priceMeta);
    }
    if (data.containsKey('cost')) {
      context.handle(
          _costMeta, cost.isAcceptableOrUnknown(data['cost']!, _costMeta));
    } else if (isInserting) {
      context.missing(_costMeta);
    }
    if (data.containsKey('type')) {
      context.handle(
          _typeMeta, type.isAcceptableOrUnknown(data['type']!, _typeMeta));
    }
    if (data.containsKey('barcode')) {
      context.handle(_barcodeMeta,
          barcode.isAcceptableOrUnknown(data['barcode']!, _barcodeMeta));
    }
    if (data.containsKey('custom_fields')) {
      context.handle(
          _customFieldsMeta,
          customFields.isAcceptableOrUnknown(
              data['custom_fields']!, _customFieldsMeta));
    }
    if (data.containsKey('created_at')) {
      context.handle(_createdAtMeta,
          createdAt.isAcceptableOrUnknown(data['created_at']!, _createdAtMeta));
    }
    return context;
  }

  @override
  Set<GeneratedColumn> get $primaryKey => {id};
  @override
  Product map(Map<String, dynamic> data, {String? tablePrefix}) {
    final effectivePrefix = tablePrefix != null ? '$tablePrefix.' : '';
    return Product(
      id: attachedDatabase.typeMapping
          .read(DriftSqlType.string, data['${effectivePrefix}id'])!,
      sku: attachedDatabase.typeMapping
          .read(DriftSqlType.string, data['${effectivePrefix}sku'])!,
      name: attachedDatabase.typeMapping
          .read(DriftSqlType.string, data['${effectivePrefix}name'])!,
      price: attachedDatabase.typeMapping
          .read(DriftSqlType.double, data['${effectivePrefix}price'])!,
      cost: attachedDatabase.typeMapping
          .read(DriftSqlType.double, data['${effectivePrefix}cost'])!,
      type: attachedDatabase.typeMapping
          .read(DriftSqlType.string, data['${effectivePrefix}type'])!,
      barcode: attachedDatabase.typeMapping
          .read(DriftSqlType.string, data['${effectivePrefix}barcode']),
      customFields: attachedDatabase.typeMapping
          .read(DriftSqlType.string, data['${effectivePrefix}custom_fields'])!,
      createdAt: attachedDatabase.typeMapping
          .read(DriftSqlType.dateTime, data['${effectivePrefix}created_at'])!,
    );
  }

  @override
  $ProductsTable createAlias(String alias) {
    return $ProductsTable(attachedDatabase, alias);
  }
}

class Product extends DataClass implements Insertable<Product> {
  final String id;
  final String sku;
  final String name;
  final double price;
  final double cost;
  final String type;
  final String? barcode;
  final String customFields;
  final DateTime createdAt;
  const Product(
      {required this.id,
      required this.sku,
      required this.name,
      required this.price,
      required this.cost,
      required this.type,
      this.barcode,
      required this.customFields,
      required this.createdAt});
  @override
  Map<String, Expression> toColumns(bool nullToAbsent) {
    final map = <String, Expression>{};
    map['id'] = Variable<String>(id);
    map['sku'] = Variable<String>(sku);
    map['name'] = Variable<String>(name);
    map['price'] = Variable<double>(price);
    map['cost'] = Variable<double>(cost);
    map['type'] = Variable<String>(type);
    if (!nullToAbsent || barcode != null) {
      map['barcode'] = Variable<String>(barcode);
    }
    map['custom_fields'] = Variable<String>(customFields);
    map['created_at'] = Variable<DateTime>(createdAt);
    return map;
  }

  ProductsCompanion toCompanion(bool nullToAbsent) {
    return ProductsCompanion(
      id: Value(id),
      sku: Value(sku),
      name: Value(name),
      price: Value(price),
      cost: Value(cost),
      type: Value(type),
      barcode: barcode == null && nullToAbsent
          ? const Value.absent()
          : Value(barcode),
      customFields: Value(customFields),
      createdAt: Value(createdAt),
    );
  }

  factory Product.fromJson(Map<String, dynamic> json,
      {ValueSerializer? serializer}) {
    serializer ??= driftRuntimeOptions.defaultSerializer;
    return Product(
      id: serializer.fromJson<String>(json['id']),
      sku: serializer.fromJson<String>(json['sku']),
      name: serializer.fromJson<String>(json['name']),
      price: serializer.fromJson<double>(json['price']),
      cost: serializer.fromJson<double>(json['cost']),
      type: serializer.fromJson<String>(json['type']),
      barcode: serializer.fromJson<String?>(json['barcode']),
      customFields: serializer.fromJson<String>(json['customFields']),
      createdAt: serializer.fromJson<DateTime>(json['createdAt']),
    );
  }
  @override
  Map<String, dynamic> toJson({ValueSerializer? serializer}) {
    serializer ??= driftRuntimeOptions.defaultSerializer;
    return <String, dynamic>{
      'id': serializer.toJson<String>(id),
      'sku': serializer.toJson<String>(sku),
      'name': serializer.toJson<String>(name),
      'price': serializer.toJson<double>(price),
      'cost': serializer.toJson<double>(cost),
      'type': serializer.toJson<String>(type),
      'barcode': serializer.toJson<String?>(barcode),
      'customFields': serializer.toJson<String>(customFields),
      'createdAt': serializer.toJson<DateTime>(createdAt),
    };
  }

  Product copyWith(
          {String? id,
          String? sku,
          String? name,
          double? price,
          double? cost,
          String? type,
          Value<String?> barcode = const Value.absent(),
          String? customFields,
          DateTime? createdAt}) =>
      Product(
        id: id ?? this.id,
        sku: sku ?? this.sku,
        name: name ?? this.name,
        price: price ?? this.price,
        cost: cost ?? this.cost,
        type: type ?? this.type,
        barcode: barcode.present ? barcode.value : this.barcode,
        customFields: customFields ?? this.customFields,
        createdAt: createdAt ?? this.createdAt,
      );
  Product copyWithCompanion(ProductsCompanion data) {
    return Product(
      id: data.id.present ? data.id.value : this.id,
      sku: data.sku.present ? data.sku.value : this.sku,
      name: data.name.present ? data.name.value : this.name,
      price: data.price.present ? data.price.value : this.price,
      cost: data.cost.present ? data.cost.value : this.cost,
      type: data.type.present ? data.type.value : this.type,
      barcode: data.barcode.present ? data.barcode.value : this.barcode,
      customFields: data.customFields.present
          ? data.customFields.value
          : this.customFields,
      createdAt: data.createdAt.present ? data.createdAt.value : this.createdAt,
    );
  }

  @override
  String toString() {
    return (StringBuffer('Product(')
          ..write('id: $id, ')
          ..write('sku: $sku, ')
          ..write('name: $name, ')
          ..write('price: $price, ')
          ..write('cost: $cost, ')
          ..write('type: $type, ')
          ..write('barcode: $barcode, ')
          ..write('customFields: $customFields, ')
          ..write('createdAt: $createdAt')
          ..write(')'))
        .toString();
  }

  @override
  int get hashCode => Object.hash(
      id, sku, name, price, cost, type, barcode, customFields, createdAt);
  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      (other is Product &&
          other.id == this.id &&
          other.sku == this.sku &&
          other.name == this.name &&
          other.price == this.price &&
          other.cost == this.cost &&
          other.type == this.type &&
          other.barcode == this.barcode &&
          other.customFields == this.customFields &&
          other.createdAt == this.createdAt);
}

class ProductsCompanion extends UpdateCompanion<Product> {
  final Value<String> id;
  final Value<String> sku;
  final Value<String> name;
  final Value<double> price;
  final Value<double> cost;
  final Value<String> type;
  final Value<String?> barcode;
  final Value<String> customFields;
  final Value<DateTime> createdAt;
  final Value<int> rowid;
  const ProductsCompanion({
    this.id = const Value.absent(),
    this.sku = const Value.absent(),
    this.name = const Value.absent(),
    this.price = const Value.absent(),
    this.cost = const Value.absent(),
    this.type = const Value.absent(),
    this.barcode = const Value.absent(),
    this.customFields = const Value.absent(),
    this.createdAt = const Value.absent(),
    this.rowid = const Value.absent(),
  });
  ProductsCompanion.insert({
    required String id,
    required String sku,
    required String name,
    required double price,
    required double cost,
    this.type = const Value.absent(),
    this.barcode = const Value.absent(),
    this.customFields = const Value.absent(),
    this.createdAt = const Value.absent(),
    this.rowid = const Value.absent(),
  })  : id = Value(id),
        sku = Value(sku),
        name = Value(name),
        price = Value(price),
        cost = Value(cost);
  static Insertable<Product> custom({
    Expression<String>? id,
    Expression<String>? sku,
    Expression<String>? name,
    Expression<double>? price,
    Expression<double>? cost,
    Expression<String>? type,
    Expression<String>? barcode,
    Expression<String>? customFields,
    Expression<DateTime>? createdAt,
    Expression<int>? rowid,
  }) {
    return RawValuesInsertable({
      if (id != null) 'id': id,
      if (sku != null) 'sku': sku,
      if (name != null) 'name': name,
      if (price != null) 'price': price,
      if (cost != null) 'cost': cost,
      if (type != null) 'type': type,
      if (barcode != null) 'barcode': barcode,
      if (customFields != null) 'custom_fields': customFields,
      if (createdAt != null) 'created_at': createdAt,
      if (rowid != null) 'rowid': rowid,
    });
  }

  ProductsCompanion copyWith(
      {Value<String>? id,
      Value<String>? sku,
      Value<String>? name,
      Value<double>? price,
      Value<double>? cost,
      Value<String>? type,
      Value<String?>? barcode,
      Value<String>? customFields,
      Value<DateTime>? createdAt,
      Value<int>? rowid}) {
    return ProductsCompanion(
      id: id ?? this.id,
      sku: sku ?? this.sku,
      name: name ?? this.name,
      price: price ?? this.price,
      cost: cost ?? this.cost,
      type: type ?? this.type,
      barcode: barcode ?? this.barcode,
      customFields: customFields ?? this.customFields,
      createdAt: createdAt ?? this.createdAt,
      rowid: rowid ?? this.rowid,
    );
  }

  @override
  Map<String, Expression> toColumns(bool nullToAbsent) {
    final map = <String, Expression>{};
    if (id.present) {
      map['id'] = Variable<String>(id.value);
    }
    if (sku.present) {
      map['sku'] = Variable<String>(sku.value);
    }
    if (name.present) {
      map['name'] = Variable<String>(name.value);
    }
    if (price.present) {
      map['price'] = Variable<double>(price.value);
    }
    if (cost.present) {
      map['cost'] = Variable<double>(cost.value);
    }
    if (type.present) {
      map['type'] = Variable<String>(type.value);
    }
    if (barcode.present) {
      map['barcode'] = Variable<String>(barcode.value);
    }
    if (customFields.present) {
      map['custom_fields'] = Variable<String>(customFields.value);
    }
    if (createdAt.present) {
      map['created_at'] = Variable<DateTime>(createdAt.value);
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
          ..write('sku: $sku, ')
          ..write('name: $name, ')
          ..write('price: $price, ')
          ..write('cost: $cost, ')
          ..write('type: $type, ')
          ..write('barcode: $barcode, ')
          ..write('customFields: $customFields, ')
          ..write('createdAt: $createdAt, ')
          ..write('rowid: $rowid')
          ..write(')'))
        .toString();
  }
}

class $StockQuantsTable extends StockQuants
    with TableInfo<$StockQuantsTable, StockQuant> {
  @override
  final GeneratedDatabase attachedDatabase;
  final String? _alias;
  $StockQuantsTable(this.attachedDatabase, [this._alias]);
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
  static const VerificationMeta _locationIdMeta =
      const VerificationMeta('locationId');
  @override
  late final GeneratedColumn<String> locationId = GeneratedColumn<String>(
      'location_id', aliasedName, false,
      type: DriftSqlType.string, requiredDuringInsert: true);
  static const VerificationMeta _quantityMeta =
      const VerificationMeta('quantity');
  @override
  late final GeneratedColumn<double> quantity = GeneratedColumn<double>(
      'quantity', aliasedName, false,
      type: DriftSqlType.double, requiredDuringInsert: true);
  static const VerificationMeta _updatedAtMeta =
      const VerificationMeta('updatedAt');
  @override
  late final GeneratedColumn<DateTime> updatedAt = GeneratedColumn<DateTime>(
      'updated_at', aliasedName, false,
      type: DriftSqlType.dateTime,
      requiredDuringInsert: false,
      defaultValue: currentDateAndTime);
  @override
  List<GeneratedColumn> get $columns =>
      [id, productId, locationId, quantity, updatedAt];
  @override
  String get aliasedName => _alias ?? actualTableName;
  @override
  String get actualTableName => $name;
  static const String $name = 'stock_quants';
  @override
  VerificationContext validateIntegrity(Insertable<StockQuant> instance,
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
    if (data.containsKey('location_id')) {
      context.handle(
          _locationIdMeta,
          locationId.isAcceptableOrUnknown(
              data['location_id']!, _locationIdMeta));
    } else if (isInserting) {
      context.missing(_locationIdMeta);
    }
    if (data.containsKey('quantity')) {
      context.handle(_quantityMeta,
          quantity.isAcceptableOrUnknown(data['quantity']!, _quantityMeta));
    } else if (isInserting) {
      context.missing(_quantityMeta);
    }
    if (data.containsKey('updated_at')) {
      context.handle(_updatedAtMeta,
          updatedAt.isAcceptableOrUnknown(data['updated_at']!, _updatedAtMeta));
    }
    return context;
  }

  @override
  Set<GeneratedColumn> get $primaryKey => {id};
  @override
  StockQuant map(Map<String, dynamic> data, {String? tablePrefix}) {
    final effectivePrefix = tablePrefix != null ? '$tablePrefix.' : '';
    return StockQuant(
      id: attachedDatabase.typeMapping
          .read(DriftSqlType.string, data['${effectivePrefix}id'])!,
      productId: attachedDatabase.typeMapping
          .read(DriftSqlType.string, data['${effectivePrefix}product_id'])!,
      locationId: attachedDatabase.typeMapping
          .read(DriftSqlType.string, data['${effectivePrefix}location_id'])!,
      quantity: attachedDatabase.typeMapping
          .read(DriftSqlType.double, data['${effectivePrefix}quantity'])!,
      updatedAt: attachedDatabase.typeMapping
          .read(DriftSqlType.dateTime, data['${effectivePrefix}updated_at'])!,
    );
  }

  @override
  $StockQuantsTable createAlias(String alias) {
    return $StockQuantsTable(attachedDatabase, alias);
  }
}

class StockQuant extends DataClass implements Insertable<StockQuant> {
  final String id;
  final String productId;
  final String locationId;
  final double quantity;
  final DateTime updatedAt;
  const StockQuant(
      {required this.id,
      required this.productId,
      required this.locationId,
      required this.quantity,
      required this.updatedAt});
  @override
  Map<String, Expression> toColumns(bool nullToAbsent) {
    final map = <String, Expression>{};
    map['id'] = Variable<String>(id);
    map['product_id'] = Variable<String>(productId);
    map['location_id'] = Variable<String>(locationId);
    map['quantity'] = Variable<double>(quantity);
    map['updated_at'] = Variable<DateTime>(updatedAt);
    return map;
  }

  StockQuantsCompanion toCompanion(bool nullToAbsent) {
    return StockQuantsCompanion(
      id: Value(id),
      productId: Value(productId),
      locationId: Value(locationId),
      quantity: Value(quantity),
      updatedAt: Value(updatedAt),
    );
  }

  factory StockQuant.fromJson(Map<String, dynamic> json,
      {ValueSerializer? serializer}) {
    serializer ??= driftRuntimeOptions.defaultSerializer;
    return StockQuant(
      id: serializer.fromJson<String>(json['id']),
      productId: serializer.fromJson<String>(json['productId']),
      locationId: serializer.fromJson<String>(json['locationId']),
      quantity: serializer.fromJson<double>(json['quantity']),
      updatedAt: serializer.fromJson<DateTime>(json['updatedAt']),
    );
  }
  @override
  Map<String, dynamic> toJson({ValueSerializer? serializer}) {
    serializer ??= driftRuntimeOptions.defaultSerializer;
    return <String, dynamic>{
      'id': serializer.toJson<String>(id),
      'productId': serializer.toJson<String>(productId),
      'locationId': serializer.toJson<String>(locationId),
      'quantity': serializer.toJson<double>(quantity),
      'updatedAt': serializer.toJson<DateTime>(updatedAt),
    };
  }

  StockQuant copyWith(
          {String? id,
          String? productId,
          String? locationId,
          double? quantity,
          DateTime? updatedAt}) =>
      StockQuant(
        id: id ?? this.id,
        productId: productId ?? this.productId,
        locationId: locationId ?? this.locationId,
        quantity: quantity ?? this.quantity,
        updatedAt: updatedAt ?? this.updatedAt,
      );
  StockQuant copyWithCompanion(StockQuantsCompanion data) {
    return StockQuant(
      id: data.id.present ? data.id.value : this.id,
      productId: data.productId.present ? data.productId.value : this.productId,
      locationId:
          data.locationId.present ? data.locationId.value : this.locationId,
      quantity: data.quantity.present ? data.quantity.value : this.quantity,
      updatedAt: data.updatedAt.present ? data.updatedAt.value : this.updatedAt,
    );
  }

  @override
  String toString() {
    return (StringBuffer('StockQuant(')
          ..write('id: $id, ')
          ..write('productId: $productId, ')
          ..write('locationId: $locationId, ')
          ..write('quantity: $quantity, ')
          ..write('updatedAt: $updatedAt')
          ..write(')'))
        .toString();
  }

  @override
  int get hashCode =>
      Object.hash(id, productId, locationId, quantity, updatedAt);
  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      (other is StockQuant &&
          other.id == this.id &&
          other.productId == this.productId &&
          other.locationId == this.locationId &&
          other.quantity == this.quantity &&
          other.updatedAt == this.updatedAt);
}

class StockQuantsCompanion extends UpdateCompanion<StockQuant> {
  final Value<String> id;
  final Value<String> productId;
  final Value<String> locationId;
  final Value<double> quantity;
  final Value<DateTime> updatedAt;
  final Value<int> rowid;
  const StockQuantsCompanion({
    this.id = const Value.absent(),
    this.productId = const Value.absent(),
    this.locationId = const Value.absent(),
    this.quantity = const Value.absent(),
    this.updatedAt = const Value.absent(),
    this.rowid = const Value.absent(),
  });
  StockQuantsCompanion.insert({
    required String id,
    required String productId,
    required String locationId,
    required double quantity,
    this.updatedAt = const Value.absent(),
    this.rowid = const Value.absent(),
  })  : id = Value(id),
        productId = Value(productId),
        locationId = Value(locationId),
        quantity = Value(quantity);
  static Insertable<StockQuant> custom({
    Expression<String>? id,
    Expression<String>? productId,
    Expression<String>? locationId,
    Expression<double>? quantity,
    Expression<DateTime>? updatedAt,
    Expression<int>? rowid,
  }) {
    return RawValuesInsertable({
      if (id != null) 'id': id,
      if (productId != null) 'product_id': productId,
      if (locationId != null) 'location_id': locationId,
      if (quantity != null) 'quantity': quantity,
      if (updatedAt != null) 'updated_at': updatedAt,
      if (rowid != null) 'rowid': rowid,
    });
  }

  StockQuantsCompanion copyWith(
      {Value<String>? id,
      Value<String>? productId,
      Value<String>? locationId,
      Value<double>? quantity,
      Value<DateTime>? updatedAt,
      Value<int>? rowid}) {
    return StockQuantsCompanion(
      id: id ?? this.id,
      productId: productId ?? this.productId,
      locationId: locationId ?? this.locationId,
      quantity: quantity ?? this.quantity,
      updatedAt: updatedAt ?? this.updatedAt,
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
    if (locationId.present) {
      map['location_id'] = Variable<String>(locationId.value);
    }
    if (quantity.present) {
      map['quantity'] = Variable<double>(quantity.value);
    }
    if (updatedAt.present) {
      map['updated_at'] = Variable<DateTime>(updatedAt.value);
    }
    if (rowid.present) {
      map['rowid'] = Variable<int>(rowid.value);
    }
    return map;
  }

  @override
  String toString() {
    return (StringBuffer('StockQuantsCompanion(')
          ..write('id: $id, ')
          ..write('productId: $productId, ')
          ..write('locationId: $locationId, ')
          ..write('quantity: $quantity, ')
          ..write('updatedAt: $updatedAt, ')
          ..write('rowid: $rowid')
          ..write(')'))
        .toString();
  }
}

class $StockMovesTable extends StockMoves
    with TableInfo<$StockMovesTable, StockMove> {
  @override
  final GeneratedDatabase attachedDatabase;
  final String? _alias;
  $StockMovesTable(this.attachedDatabase, [this._alias]);
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
  static const VerificationMeta _quantityMeta =
      const VerificationMeta('quantity');
  @override
  late final GeneratedColumn<double> quantity = GeneratedColumn<double>(
      'quantity', aliasedName, false,
      type: DriftSqlType.double, requiredDuringInsert: true);
  static const VerificationMeta _sourceLocationIdMeta =
      const VerificationMeta('sourceLocationId');
  @override
  late final GeneratedColumn<String> sourceLocationId = GeneratedColumn<String>(
      'source_location_id', aliasedName, false,
      type: DriftSqlType.string, requiredDuringInsert: true);
  static const VerificationMeta _destLocationIdMeta =
      const VerificationMeta('destLocationId');
  @override
  late final GeneratedColumn<String> destLocationId = GeneratedColumn<String>(
      'dest_location_id', aliasedName, false,
      type: DriftSqlType.string, requiredDuringInsert: true);
  static const VerificationMeta _statusMeta = const VerificationMeta('status');
  @override
  late final GeneratedColumn<String> status = GeneratedColumn<String>(
      'status', aliasedName, false,
      type: DriftSqlType.string,
      requiredDuringInsert: false,
      defaultValue: const Constant('draft'));
  static const VerificationMeta _dateMeta = const VerificationMeta('date');
  @override
  late final GeneratedColumn<DateTime> date = GeneratedColumn<DateTime>(
      'date', aliasedName, false,
      type: DriftSqlType.dateTime,
      requiredDuringInsert: false,
      defaultValue: currentDateAndTime);
  @override
  List<GeneratedColumn> get $columns =>
      [id, productId, quantity, sourceLocationId, destLocationId, status, date];
  @override
  String get aliasedName => _alias ?? actualTableName;
  @override
  String get actualTableName => $name;
  static const String $name = 'stock_moves';
  @override
  VerificationContext validateIntegrity(Insertable<StockMove> instance,
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
    if (data.containsKey('quantity')) {
      context.handle(_quantityMeta,
          quantity.isAcceptableOrUnknown(data['quantity']!, _quantityMeta));
    } else if (isInserting) {
      context.missing(_quantityMeta);
    }
    if (data.containsKey('source_location_id')) {
      context.handle(
          _sourceLocationIdMeta,
          sourceLocationId.isAcceptableOrUnknown(
              data['source_location_id']!, _sourceLocationIdMeta));
    } else if (isInserting) {
      context.missing(_sourceLocationIdMeta);
    }
    if (data.containsKey('dest_location_id')) {
      context.handle(
          _destLocationIdMeta,
          destLocationId.isAcceptableOrUnknown(
              data['dest_location_id']!, _destLocationIdMeta));
    } else if (isInserting) {
      context.missing(_destLocationIdMeta);
    }
    if (data.containsKey('status')) {
      context.handle(_statusMeta,
          status.isAcceptableOrUnknown(data['status']!, _statusMeta));
    }
    if (data.containsKey('date')) {
      context.handle(
          _dateMeta, date.isAcceptableOrUnknown(data['date']!, _dateMeta));
    }
    return context;
  }

  @override
  Set<GeneratedColumn> get $primaryKey => {id};
  @override
  StockMove map(Map<String, dynamic> data, {String? tablePrefix}) {
    final effectivePrefix = tablePrefix != null ? '$tablePrefix.' : '';
    return StockMove(
      id: attachedDatabase.typeMapping
          .read(DriftSqlType.string, data['${effectivePrefix}id'])!,
      productId: attachedDatabase.typeMapping
          .read(DriftSqlType.string, data['${effectivePrefix}product_id'])!,
      quantity: attachedDatabase.typeMapping
          .read(DriftSqlType.double, data['${effectivePrefix}quantity'])!,
      sourceLocationId: attachedDatabase.typeMapping.read(
          DriftSqlType.string, data['${effectivePrefix}source_location_id'])!,
      destLocationId: attachedDatabase.typeMapping.read(
          DriftSqlType.string, data['${effectivePrefix}dest_location_id'])!,
      status: attachedDatabase.typeMapping
          .read(DriftSqlType.string, data['${effectivePrefix}status'])!,
      date: attachedDatabase.typeMapping
          .read(DriftSqlType.dateTime, data['${effectivePrefix}date'])!,
    );
  }

  @override
  $StockMovesTable createAlias(String alias) {
    return $StockMovesTable(attachedDatabase, alias);
  }
}

class StockMove extends DataClass implements Insertable<StockMove> {
  final String id;
  final String productId;
  final double quantity;
  final String sourceLocationId;
  final String destLocationId;
  final String status;
  final DateTime date;
  const StockMove(
      {required this.id,
      required this.productId,
      required this.quantity,
      required this.sourceLocationId,
      required this.destLocationId,
      required this.status,
      required this.date});
  @override
  Map<String, Expression> toColumns(bool nullToAbsent) {
    final map = <String, Expression>{};
    map['id'] = Variable<String>(id);
    map['product_id'] = Variable<String>(productId);
    map['quantity'] = Variable<double>(quantity);
    map['source_location_id'] = Variable<String>(sourceLocationId);
    map['dest_location_id'] = Variable<String>(destLocationId);
    map['status'] = Variable<String>(status);
    map['date'] = Variable<DateTime>(date);
    return map;
  }

  StockMovesCompanion toCompanion(bool nullToAbsent) {
    return StockMovesCompanion(
      id: Value(id),
      productId: Value(productId),
      quantity: Value(quantity),
      sourceLocationId: Value(sourceLocationId),
      destLocationId: Value(destLocationId),
      status: Value(status),
      date: Value(date),
    );
  }

  factory StockMove.fromJson(Map<String, dynamic> json,
      {ValueSerializer? serializer}) {
    serializer ??= driftRuntimeOptions.defaultSerializer;
    return StockMove(
      id: serializer.fromJson<String>(json['id']),
      productId: serializer.fromJson<String>(json['productId']),
      quantity: serializer.fromJson<double>(json['quantity']),
      sourceLocationId: serializer.fromJson<String>(json['sourceLocationId']),
      destLocationId: serializer.fromJson<String>(json['destLocationId']),
      status: serializer.fromJson<String>(json['status']),
      date: serializer.fromJson<DateTime>(json['date']),
    );
  }
  @override
  Map<String, dynamic> toJson({ValueSerializer? serializer}) {
    serializer ??= driftRuntimeOptions.defaultSerializer;
    return <String, dynamic>{
      'id': serializer.toJson<String>(id),
      'productId': serializer.toJson<String>(productId),
      'quantity': serializer.toJson<double>(quantity),
      'sourceLocationId': serializer.toJson<String>(sourceLocationId),
      'destLocationId': serializer.toJson<String>(destLocationId),
      'status': serializer.toJson<String>(status),
      'date': serializer.toJson<DateTime>(date),
    };
  }

  StockMove copyWith(
          {String? id,
          String? productId,
          double? quantity,
          String? sourceLocationId,
          String? destLocationId,
          String? status,
          DateTime? date}) =>
      StockMove(
        id: id ?? this.id,
        productId: productId ?? this.productId,
        quantity: quantity ?? this.quantity,
        sourceLocationId: sourceLocationId ?? this.sourceLocationId,
        destLocationId: destLocationId ?? this.destLocationId,
        status: status ?? this.status,
        date: date ?? this.date,
      );
  StockMove copyWithCompanion(StockMovesCompanion data) {
    return StockMove(
      id: data.id.present ? data.id.value : this.id,
      productId: data.productId.present ? data.productId.value : this.productId,
      quantity: data.quantity.present ? data.quantity.value : this.quantity,
      sourceLocationId: data.sourceLocationId.present
          ? data.sourceLocationId.value
          : this.sourceLocationId,
      destLocationId: data.destLocationId.present
          ? data.destLocationId.value
          : this.destLocationId,
      status: data.status.present ? data.status.value : this.status,
      date: data.date.present ? data.date.value : this.date,
    );
  }

  @override
  String toString() {
    return (StringBuffer('StockMove(')
          ..write('id: $id, ')
          ..write('productId: $productId, ')
          ..write('quantity: $quantity, ')
          ..write('sourceLocationId: $sourceLocationId, ')
          ..write('destLocationId: $destLocationId, ')
          ..write('status: $status, ')
          ..write('date: $date')
          ..write(')'))
        .toString();
  }

  @override
  int get hashCode => Object.hash(
      id, productId, quantity, sourceLocationId, destLocationId, status, date);
  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      (other is StockMove &&
          other.id == this.id &&
          other.productId == this.productId &&
          other.quantity == this.quantity &&
          other.sourceLocationId == this.sourceLocationId &&
          other.destLocationId == this.destLocationId &&
          other.status == this.status &&
          other.date == this.date);
}

class StockMovesCompanion extends UpdateCompanion<StockMove> {
  final Value<String> id;
  final Value<String> productId;
  final Value<double> quantity;
  final Value<String> sourceLocationId;
  final Value<String> destLocationId;
  final Value<String> status;
  final Value<DateTime> date;
  final Value<int> rowid;
  const StockMovesCompanion({
    this.id = const Value.absent(),
    this.productId = const Value.absent(),
    this.quantity = const Value.absent(),
    this.sourceLocationId = const Value.absent(),
    this.destLocationId = const Value.absent(),
    this.status = const Value.absent(),
    this.date = const Value.absent(),
    this.rowid = const Value.absent(),
  });
  StockMovesCompanion.insert({
    required String id,
    required String productId,
    required double quantity,
    required String sourceLocationId,
    required String destLocationId,
    this.status = const Value.absent(),
    this.date = const Value.absent(),
    this.rowid = const Value.absent(),
  })  : id = Value(id),
        productId = Value(productId),
        quantity = Value(quantity),
        sourceLocationId = Value(sourceLocationId),
        destLocationId = Value(destLocationId);
  static Insertable<StockMove> custom({
    Expression<String>? id,
    Expression<String>? productId,
    Expression<double>? quantity,
    Expression<String>? sourceLocationId,
    Expression<String>? destLocationId,
    Expression<String>? status,
    Expression<DateTime>? date,
    Expression<int>? rowid,
  }) {
    return RawValuesInsertable({
      if (id != null) 'id': id,
      if (productId != null) 'product_id': productId,
      if (quantity != null) 'quantity': quantity,
      if (sourceLocationId != null) 'source_location_id': sourceLocationId,
      if (destLocationId != null) 'dest_location_id': destLocationId,
      if (status != null) 'status': status,
      if (date != null) 'date': date,
      if (rowid != null) 'rowid': rowid,
    });
  }

  StockMovesCompanion copyWith(
      {Value<String>? id,
      Value<String>? productId,
      Value<double>? quantity,
      Value<String>? sourceLocationId,
      Value<String>? destLocationId,
      Value<String>? status,
      Value<DateTime>? date,
      Value<int>? rowid}) {
    return StockMovesCompanion(
      id: id ?? this.id,
      productId: productId ?? this.productId,
      quantity: quantity ?? this.quantity,
      sourceLocationId: sourceLocationId ?? this.sourceLocationId,
      destLocationId: destLocationId ?? this.destLocationId,
      status: status ?? this.status,
      date: date ?? this.date,
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
    if (quantity.present) {
      map['quantity'] = Variable<double>(quantity.value);
    }
    if (sourceLocationId.present) {
      map['source_location_id'] = Variable<String>(sourceLocationId.value);
    }
    if (destLocationId.present) {
      map['dest_location_id'] = Variable<String>(destLocationId.value);
    }
    if (status.present) {
      map['status'] = Variable<String>(status.value);
    }
    if (date.present) {
      map['date'] = Variable<DateTime>(date.value);
    }
    if (rowid.present) {
      map['rowid'] = Variable<int>(rowid.value);
    }
    return map;
  }

  @override
  String toString() {
    return (StringBuffer('StockMovesCompanion(')
          ..write('id: $id, ')
          ..write('productId: $productId, ')
          ..write('quantity: $quantity, ')
          ..write('sourceLocationId: $sourceLocationId, ')
          ..write('destLocationId: $destLocationId, ')
          ..write('status: $status, ')
          ..write('date: $date, ')
          ..write('rowid: $rowid')
          ..write(')'))
        .toString();
  }
}

class $TrustScoresTable extends TrustScores
    with TableInfo<$TrustScoresTable, TrustScore> {
  @override
  final GeneratedDatabase attachedDatabase;
  final String? _alias;
  $TrustScoresTable(this.attachedDatabase, [this._alias]);
  static const VerificationMeta _userIdMeta = const VerificationMeta('userId');
  @override
  late final GeneratedColumn<String> userId = GeneratedColumn<String>(
      'user_id', aliasedName, false,
      type: DriftSqlType.string, requiredDuringInsert: true);
  static const VerificationMeta _overallScoreMeta =
      const VerificationMeta('overallScore');
  @override
  late final GeneratedColumn<double> overallScore = GeneratedColumn<double>(
      'overall_score', aliasedName, false,
      type: DriftSqlType.double,
      requiredDuringInsert: false,
      defaultValue: const Constant(0.0));
  static const VerificationMeta _referralCountMeta =
      const VerificationMeta('referralCount');
  @override
  late final GeneratedColumn<int> referralCount = GeneratedColumn<int>(
      'referral_count', aliasedName, false,
      type: DriftSqlType.int,
      requiredDuringInsert: false,
      defaultValue: const Constant(0));
  static const VerificationMeta _referredByMeta =
      const VerificationMeta('referredBy');
  @override
  late final GeneratedColumn<String> referredBy = GeneratedColumn<String>(
      'referred_by', aliasedName, true,
      type: DriftSqlType.string, requiredDuringInsert: false);
  static const VerificationMeta _completedOrdersMeta =
      const VerificationMeta('completedOrders');
  @override
  late final GeneratedColumn<int> completedOrders = GeneratedColumn<int>(
      'completed_orders', aliasedName, false,
      type: DriftSqlType.int,
      requiredDuringInsert: false,
      defaultValue: const Constant(0));
  static const VerificationMeta _avgRatingMeta =
      const VerificationMeta('avgRating');
  @override
  late final GeneratedColumn<double> avgRating = GeneratedColumn<double>(
      'avg_rating', aliasedName, false,
      type: DriftSqlType.double,
      requiredDuringInsert: false,
      defaultValue: const Constant(0.0));
  static const VerificationMeta _memberSinceMeta =
      const VerificationMeta('memberSince');
  @override
  late final GeneratedColumn<DateTime> memberSince = GeneratedColumn<DateTime>(
      'member_since', aliasedName, false,
      type: DriftSqlType.dateTime,
      requiredDuringInsert: false,
      defaultValue: currentDateAndTime);
  static const VerificationMeta _levelMeta = const VerificationMeta('level');
  @override
  late final GeneratedColumn<String> level = GeneratedColumn<String>(
      'level', aliasedName, false,
      type: DriftSqlType.string,
      requiredDuringInsert: false,
      defaultValue: const Constant('newcomer'));
  static const VerificationMeta _kycVerifiedMeta =
      const VerificationMeta('kycVerified');
  @override
  late final GeneratedColumn<bool> kycVerified = GeneratedColumn<bool>(
      'kyc_verified', aliasedName, false,
      type: DriftSqlType.bool,
      requiredDuringInsert: false,
      defaultConstraints: GeneratedColumn.constraintIsAlways(
          'CHECK ("kyc_verified" IN (0, 1))'),
      defaultValue: const Constant(false));
  @override
  List<GeneratedColumn> get $columns => [
        userId,
        overallScore,
        referralCount,
        referredBy,
        completedOrders,
        avgRating,
        memberSince,
        level,
        kycVerified
      ];
  @override
  String get aliasedName => _alias ?? actualTableName;
  @override
  String get actualTableName => $name;
  static const String $name = 'trust_scores';
  @override
  VerificationContext validateIntegrity(Insertable<TrustScore> instance,
      {bool isInserting = false}) {
    final context = VerificationContext();
    final data = instance.toColumns(true);
    if (data.containsKey('user_id')) {
      context.handle(_userIdMeta,
          userId.isAcceptableOrUnknown(data['user_id']!, _userIdMeta));
    } else if (isInserting) {
      context.missing(_userIdMeta);
    }
    if (data.containsKey('overall_score')) {
      context.handle(
          _overallScoreMeta,
          overallScore.isAcceptableOrUnknown(
              data['overall_score']!, _overallScoreMeta));
    }
    if (data.containsKey('referral_count')) {
      context.handle(
          _referralCountMeta,
          referralCount.isAcceptableOrUnknown(
              data['referral_count']!, _referralCountMeta));
    }
    if (data.containsKey('referred_by')) {
      context.handle(
          _referredByMeta,
          referredBy.isAcceptableOrUnknown(
              data['referred_by']!, _referredByMeta));
    }
    if (data.containsKey('completed_orders')) {
      context.handle(
          _completedOrdersMeta,
          completedOrders.isAcceptableOrUnknown(
              data['completed_orders']!, _completedOrdersMeta));
    }
    if (data.containsKey('avg_rating')) {
      context.handle(_avgRatingMeta,
          avgRating.isAcceptableOrUnknown(data['avg_rating']!, _avgRatingMeta));
    }
    if (data.containsKey('member_since')) {
      context.handle(
          _memberSinceMeta,
          memberSince.isAcceptableOrUnknown(
              data['member_since']!, _memberSinceMeta));
    }
    if (data.containsKey('level')) {
      context.handle(
          _levelMeta, level.isAcceptableOrUnknown(data['level']!, _levelMeta));
    }
    if (data.containsKey('kyc_verified')) {
      context.handle(
          _kycVerifiedMeta,
          kycVerified.isAcceptableOrUnknown(
              data['kyc_verified']!, _kycVerifiedMeta));
    }
    return context;
  }

  @override
  Set<GeneratedColumn> get $primaryKey => {userId};
  @override
  TrustScore map(Map<String, dynamic> data, {String? tablePrefix}) {
    final effectivePrefix = tablePrefix != null ? '$tablePrefix.' : '';
    return TrustScore(
      userId: attachedDatabase.typeMapping
          .read(DriftSqlType.string, data['${effectivePrefix}user_id'])!,
      overallScore: attachedDatabase.typeMapping
          .read(DriftSqlType.double, data['${effectivePrefix}overall_score'])!,
      referralCount: attachedDatabase.typeMapping
          .read(DriftSqlType.int, data['${effectivePrefix}referral_count'])!,
      referredBy: attachedDatabase.typeMapping
          .read(DriftSqlType.string, data['${effectivePrefix}referred_by']),
      completedOrders: attachedDatabase.typeMapping
          .read(DriftSqlType.int, data['${effectivePrefix}completed_orders'])!,
      avgRating: attachedDatabase.typeMapping
          .read(DriftSqlType.double, data['${effectivePrefix}avg_rating'])!,
      memberSince: attachedDatabase.typeMapping
          .read(DriftSqlType.dateTime, data['${effectivePrefix}member_since'])!,
      level: attachedDatabase.typeMapping
          .read(DriftSqlType.string, data['${effectivePrefix}level'])!,
      kycVerified: attachedDatabase.typeMapping
          .read(DriftSqlType.bool, data['${effectivePrefix}kyc_verified'])!,
    );
  }

  @override
  $TrustScoresTable createAlias(String alias) {
    return $TrustScoresTable(attachedDatabase, alias);
  }
}

class TrustScore extends DataClass implements Insertable<TrustScore> {
  final String userId;
  final double overallScore;
  final int referralCount;
  final String? referredBy;
  final int completedOrders;
  final double avgRating;
  final DateTime memberSince;
  final String level;
  final bool kycVerified;
  const TrustScore(
      {required this.userId,
      required this.overallScore,
      required this.referralCount,
      this.referredBy,
      required this.completedOrders,
      required this.avgRating,
      required this.memberSince,
      required this.level,
      required this.kycVerified});
  @override
  Map<String, Expression> toColumns(bool nullToAbsent) {
    final map = <String, Expression>{};
    map['user_id'] = Variable<String>(userId);
    map['overall_score'] = Variable<double>(overallScore);
    map['referral_count'] = Variable<int>(referralCount);
    if (!nullToAbsent || referredBy != null) {
      map['referred_by'] = Variable<String>(referredBy);
    }
    map['completed_orders'] = Variable<int>(completedOrders);
    map['avg_rating'] = Variable<double>(avgRating);
    map['member_since'] = Variable<DateTime>(memberSince);
    map['level'] = Variable<String>(level);
    map['kyc_verified'] = Variable<bool>(kycVerified);
    return map;
  }

  TrustScoresCompanion toCompanion(bool nullToAbsent) {
    return TrustScoresCompanion(
      userId: Value(userId),
      overallScore: Value(overallScore),
      referralCount: Value(referralCount),
      referredBy: referredBy == null && nullToAbsent
          ? const Value.absent()
          : Value(referredBy),
      completedOrders: Value(completedOrders),
      avgRating: Value(avgRating),
      memberSince: Value(memberSince),
      level: Value(level),
      kycVerified: Value(kycVerified),
    );
  }

  factory TrustScore.fromJson(Map<String, dynamic> json,
      {ValueSerializer? serializer}) {
    serializer ??= driftRuntimeOptions.defaultSerializer;
    return TrustScore(
      userId: serializer.fromJson<String>(json['userId']),
      overallScore: serializer.fromJson<double>(json['overallScore']),
      referralCount: serializer.fromJson<int>(json['referralCount']),
      referredBy: serializer.fromJson<String?>(json['referredBy']),
      completedOrders: serializer.fromJson<int>(json['completedOrders']),
      avgRating: serializer.fromJson<double>(json['avgRating']),
      memberSince: serializer.fromJson<DateTime>(json['memberSince']),
      level: serializer.fromJson<String>(json['level']),
      kycVerified: serializer.fromJson<bool>(json['kycVerified']),
    );
  }
  @override
  Map<String, dynamic> toJson({ValueSerializer? serializer}) {
    serializer ??= driftRuntimeOptions.defaultSerializer;
    return <String, dynamic>{
      'userId': serializer.toJson<String>(userId),
      'overallScore': serializer.toJson<double>(overallScore),
      'referralCount': serializer.toJson<int>(referralCount),
      'referredBy': serializer.toJson<String?>(referredBy),
      'completedOrders': serializer.toJson<int>(completedOrders),
      'avgRating': serializer.toJson<double>(avgRating),
      'memberSince': serializer.toJson<DateTime>(memberSince),
      'level': serializer.toJson<String>(level),
      'kycVerified': serializer.toJson<bool>(kycVerified),
    };
  }

  TrustScore copyWith(
          {String? userId,
          double? overallScore,
          int? referralCount,
          Value<String?> referredBy = const Value.absent(),
          int? completedOrders,
          double? avgRating,
          DateTime? memberSince,
          String? level,
          bool? kycVerified}) =>
      TrustScore(
        userId: userId ?? this.userId,
        overallScore: overallScore ?? this.overallScore,
        referralCount: referralCount ?? this.referralCount,
        referredBy: referredBy.present ? referredBy.value : this.referredBy,
        completedOrders: completedOrders ?? this.completedOrders,
        avgRating: avgRating ?? this.avgRating,
        memberSince: memberSince ?? this.memberSince,
        level: level ?? this.level,
        kycVerified: kycVerified ?? this.kycVerified,
      );
  TrustScore copyWithCompanion(TrustScoresCompanion data) {
    return TrustScore(
      userId: data.userId.present ? data.userId.value : this.userId,
      overallScore: data.overallScore.present
          ? data.overallScore.value
          : this.overallScore,
      referralCount: data.referralCount.present
          ? data.referralCount.value
          : this.referralCount,
      referredBy:
          data.referredBy.present ? data.referredBy.value : this.referredBy,
      completedOrders: data.completedOrders.present
          ? data.completedOrders.value
          : this.completedOrders,
      avgRating: data.avgRating.present ? data.avgRating.value : this.avgRating,
      memberSince:
          data.memberSince.present ? data.memberSince.value : this.memberSince,
      level: data.level.present ? data.level.value : this.level,
      kycVerified:
          data.kycVerified.present ? data.kycVerified.value : this.kycVerified,
    );
  }

  @override
  String toString() {
    return (StringBuffer('TrustScore(')
          ..write('userId: $userId, ')
          ..write('overallScore: $overallScore, ')
          ..write('referralCount: $referralCount, ')
          ..write('referredBy: $referredBy, ')
          ..write('completedOrders: $completedOrders, ')
          ..write('avgRating: $avgRating, ')
          ..write('memberSince: $memberSince, ')
          ..write('level: $level, ')
          ..write('kycVerified: $kycVerified')
          ..write(')'))
        .toString();
  }

  @override
  int get hashCode => Object.hash(userId, overallScore, referralCount,
      referredBy, completedOrders, avgRating, memberSince, level, kycVerified);
  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      (other is TrustScore &&
          other.userId == this.userId &&
          other.overallScore == this.overallScore &&
          other.referralCount == this.referralCount &&
          other.referredBy == this.referredBy &&
          other.completedOrders == this.completedOrders &&
          other.avgRating == this.avgRating &&
          other.memberSince == this.memberSince &&
          other.level == this.level &&
          other.kycVerified == this.kycVerified);
}

class TrustScoresCompanion extends UpdateCompanion<TrustScore> {
  final Value<String> userId;
  final Value<double> overallScore;
  final Value<int> referralCount;
  final Value<String?> referredBy;
  final Value<int> completedOrders;
  final Value<double> avgRating;
  final Value<DateTime> memberSince;
  final Value<String> level;
  final Value<bool> kycVerified;
  final Value<int> rowid;
  const TrustScoresCompanion({
    this.userId = const Value.absent(),
    this.overallScore = const Value.absent(),
    this.referralCount = const Value.absent(),
    this.referredBy = const Value.absent(),
    this.completedOrders = const Value.absent(),
    this.avgRating = const Value.absent(),
    this.memberSince = const Value.absent(),
    this.level = const Value.absent(),
    this.kycVerified = const Value.absent(),
    this.rowid = const Value.absent(),
  });
  TrustScoresCompanion.insert({
    required String userId,
    this.overallScore = const Value.absent(),
    this.referralCount = const Value.absent(),
    this.referredBy = const Value.absent(),
    this.completedOrders = const Value.absent(),
    this.avgRating = const Value.absent(),
    this.memberSince = const Value.absent(),
    this.level = const Value.absent(),
    this.kycVerified = const Value.absent(),
    this.rowid = const Value.absent(),
  }) : userId = Value(userId);
  static Insertable<TrustScore> custom({
    Expression<String>? userId,
    Expression<double>? overallScore,
    Expression<int>? referralCount,
    Expression<String>? referredBy,
    Expression<int>? completedOrders,
    Expression<double>? avgRating,
    Expression<DateTime>? memberSince,
    Expression<String>? level,
    Expression<bool>? kycVerified,
    Expression<int>? rowid,
  }) {
    return RawValuesInsertable({
      if (userId != null) 'user_id': userId,
      if (overallScore != null) 'overall_score': overallScore,
      if (referralCount != null) 'referral_count': referralCount,
      if (referredBy != null) 'referred_by': referredBy,
      if (completedOrders != null) 'completed_orders': completedOrders,
      if (avgRating != null) 'avg_rating': avgRating,
      if (memberSince != null) 'member_since': memberSince,
      if (level != null) 'level': level,
      if (kycVerified != null) 'kyc_verified': kycVerified,
      if (rowid != null) 'rowid': rowid,
    });
  }

  TrustScoresCompanion copyWith(
      {Value<String>? userId,
      Value<double>? overallScore,
      Value<int>? referralCount,
      Value<String?>? referredBy,
      Value<int>? completedOrders,
      Value<double>? avgRating,
      Value<DateTime>? memberSince,
      Value<String>? level,
      Value<bool>? kycVerified,
      Value<int>? rowid}) {
    return TrustScoresCompanion(
      userId: userId ?? this.userId,
      overallScore: overallScore ?? this.overallScore,
      referralCount: referralCount ?? this.referralCount,
      referredBy: referredBy ?? this.referredBy,
      completedOrders: completedOrders ?? this.completedOrders,
      avgRating: avgRating ?? this.avgRating,
      memberSince: memberSince ?? this.memberSince,
      level: level ?? this.level,
      kycVerified: kycVerified ?? this.kycVerified,
      rowid: rowid ?? this.rowid,
    );
  }

  @override
  Map<String, Expression> toColumns(bool nullToAbsent) {
    final map = <String, Expression>{};
    if (userId.present) {
      map['user_id'] = Variable<String>(userId.value);
    }
    if (overallScore.present) {
      map['overall_score'] = Variable<double>(overallScore.value);
    }
    if (referralCount.present) {
      map['referral_count'] = Variable<int>(referralCount.value);
    }
    if (referredBy.present) {
      map['referred_by'] = Variable<String>(referredBy.value);
    }
    if (completedOrders.present) {
      map['completed_orders'] = Variable<int>(completedOrders.value);
    }
    if (avgRating.present) {
      map['avg_rating'] = Variable<double>(avgRating.value);
    }
    if (memberSince.present) {
      map['member_since'] = Variable<DateTime>(memberSince.value);
    }
    if (level.present) {
      map['level'] = Variable<String>(level.value);
    }
    if (kycVerified.present) {
      map['kyc_verified'] = Variable<bool>(kycVerified.value);
    }
    if (rowid.present) {
      map['rowid'] = Variable<int>(rowid.value);
    }
    return map;
  }

  @override
  String toString() {
    return (StringBuffer('TrustScoresCompanion(')
          ..write('userId: $userId, ')
          ..write('overallScore: $overallScore, ')
          ..write('referralCount: $referralCount, ')
          ..write('referredBy: $referredBy, ')
          ..write('completedOrders: $completedOrders, ')
          ..write('avgRating: $avgRating, ')
          ..write('memberSince: $memberSince, ')
          ..write('level: $level, ')
          ..write('kycVerified: $kycVerified, ')
          ..write('rowid: $rowid')
          ..write(')'))
        .toString();
  }
}

class $ReferralsTable extends Referrals
    with TableInfo<$ReferralsTable, Referral> {
  @override
  final GeneratedDatabase attachedDatabase;
  final String? _alias;
  $ReferralsTable(this.attachedDatabase, [this._alias]);
  static const VerificationMeta _idMeta = const VerificationMeta('id');
  @override
  late final GeneratedColumn<String> id = GeneratedColumn<String>(
      'id', aliasedName, false,
      type: DriftSqlType.string, requiredDuringInsert: true);
  static const VerificationMeta _inviterIdMeta =
      const VerificationMeta('inviterId');
  @override
  late final GeneratedColumn<String> inviterId = GeneratedColumn<String>(
      'inviter_id', aliasedName, false,
      type: DriftSqlType.string, requiredDuringInsert: true);
  static const VerificationMeta _inviteeIdMeta =
      const VerificationMeta('inviteeId');
  @override
  late final GeneratedColumn<String> inviteeId = GeneratedColumn<String>(
      'invitee_id', aliasedName, true,
      type: DriftSqlType.string, requiredDuringInsert: false);
  static const VerificationMeta _contactInfoMeta =
      const VerificationMeta('contactInfo');
  @override
  late final GeneratedColumn<String> contactInfo = GeneratedColumn<String>(
      'contact_info', aliasedName, false,
      type: DriftSqlType.string, requiredDuringInsert: true);
  static const VerificationMeta _statusMeta = const VerificationMeta('status');
  @override
  late final GeneratedColumn<String> status = GeneratedColumn<String>(
      'status', aliasedName, false,
      type: DriftSqlType.string,
      requiredDuringInsert: false,
      defaultValue: const Constant('sent'));
  static const VerificationMeta _createdAtMeta =
      const VerificationMeta('createdAt');
  @override
  late final GeneratedColumn<DateTime> createdAt = GeneratedColumn<DateTime>(
      'created_at', aliasedName, false,
      type: DriftSqlType.dateTime,
      requiredDuringInsert: false,
      defaultValue: currentDateAndTime);
  static const VerificationMeta _acceptedAtMeta =
      const VerificationMeta('acceptedAt');
  @override
  late final GeneratedColumn<DateTime> acceptedAt = GeneratedColumn<DateTime>(
      'accepted_at', aliasedName, true,
      type: DriftSqlType.dateTime, requiredDuringInsert: false);
  @override
  List<GeneratedColumn> get $columns =>
      [id, inviterId, inviteeId, contactInfo, status, createdAt, acceptedAt];
  @override
  String get aliasedName => _alias ?? actualTableName;
  @override
  String get actualTableName => $name;
  static const String $name = 'referrals';
  @override
  VerificationContext validateIntegrity(Insertable<Referral> instance,
      {bool isInserting = false}) {
    final context = VerificationContext();
    final data = instance.toColumns(true);
    if (data.containsKey('id')) {
      context.handle(_idMeta, id.isAcceptableOrUnknown(data['id']!, _idMeta));
    } else if (isInserting) {
      context.missing(_idMeta);
    }
    if (data.containsKey('inviter_id')) {
      context.handle(_inviterIdMeta,
          inviterId.isAcceptableOrUnknown(data['inviter_id']!, _inviterIdMeta));
    } else if (isInserting) {
      context.missing(_inviterIdMeta);
    }
    if (data.containsKey('invitee_id')) {
      context.handle(_inviteeIdMeta,
          inviteeId.isAcceptableOrUnknown(data['invitee_id']!, _inviteeIdMeta));
    }
    if (data.containsKey('contact_info')) {
      context.handle(
          _contactInfoMeta,
          contactInfo.isAcceptableOrUnknown(
              data['contact_info']!, _contactInfoMeta));
    } else if (isInserting) {
      context.missing(_contactInfoMeta);
    }
    if (data.containsKey('status')) {
      context.handle(_statusMeta,
          status.isAcceptableOrUnknown(data['status']!, _statusMeta));
    }
    if (data.containsKey('created_at')) {
      context.handle(_createdAtMeta,
          createdAt.isAcceptableOrUnknown(data['created_at']!, _createdAtMeta));
    }
    if (data.containsKey('accepted_at')) {
      context.handle(
          _acceptedAtMeta,
          acceptedAt.isAcceptableOrUnknown(
              data['accepted_at']!, _acceptedAtMeta));
    }
    return context;
  }

  @override
  Set<GeneratedColumn> get $primaryKey => {id};
  @override
  Referral map(Map<String, dynamic> data, {String? tablePrefix}) {
    final effectivePrefix = tablePrefix != null ? '$tablePrefix.' : '';
    return Referral(
      id: attachedDatabase.typeMapping
          .read(DriftSqlType.string, data['${effectivePrefix}id'])!,
      inviterId: attachedDatabase.typeMapping
          .read(DriftSqlType.string, data['${effectivePrefix}inviter_id'])!,
      inviteeId: attachedDatabase.typeMapping
          .read(DriftSqlType.string, data['${effectivePrefix}invitee_id']),
      contactInfo: attachedDatabase.typeMapping
          .read(DriftSqlType.string, data['${effectivePrefix}contact_info'])!,
      status: attachedDatabase.typeMapping
          .read(DriftSqlType.string, data['${effectivePrefix}status'])!,
      createdAt: attachedDatabase.typeMapping
          .read(DriftSqlType.dateTime, data['${effectivePrefix}created_at'])!,
      acceptedAt: attachedDatabase.typeMapping
          .read(DriftSqlType.dateTime, data['${effectivePrefix}accepted_at']),
    );
  }

  @override
  $ReferralsTable createAlias(String alias) {
    return $ReferralsTable(attachedDatabase, alias);
  }
}

class Referral extends DataClass implements Insertable<Referral> {
  final String id;
  final String inviterId;
  final String? inviteeId;
  final String contactInfo;
  final String status;
  final DateTime createdAt;
  final DateTime? acceptedAt;
  const Referral(
      {required this.id,
      required this.inviterId,
      this.inviteeId,
      required this.contactInfo,
      required this.status,
      required this.createdAt,
      this.acceptedAt});
  @override
  Map<String, Expression> toColumns(bool nullToAbsent) {
    final map = <String, Expression>{};
    map['id'] = Variable<String>(id);
    map['inviter_id'] = Variable<String>(inviterId);
    if (!nullToAbsent || inviteeId != null) {
      map['invitee_id'] = Variable<String>(inviteeId);
    }
    map['contact_info'] = Variable<String>(contactInfo);
    map['status'] = Variable<String>(status);
    map['created_at'] = Variable<DateTime>(createdAt);
    if (!nullToAbsent || acceptedAt != null) {
      map['accepted_at'] = Variable<DateTime>(acceptedAt);
    }
    return map;
  }

  ReferralsCompanion toCompanion(bool nullToAbsent) {
    return ReferralsCompanion(
      id: Value(id),
      inviterId: Value(inviterId),
      inviteeId: inviteeId == null && nullToAbsent
          ? const Value.absent()
          : Value(inviteeId),
      contactInfo: Value(contactInfo),
      status: Value(status),
      createdAt: Value(createdAt),
      acceptedAt: acceptedAt == null && nullToAbsent
          ? const Value.absent()
          : Value(acceptedAt),
    );
  }

  factory Referral.fromJson(Map<String, dynamic> json,
      {ValueSerializer? serializer}) {
    serializer ??= driftRuntimeOptions.defaultSerializer;
    return Referral(
      id: serializer.fromJson<String>(json['id']),
      inviterId: serializer.fromJson<String>(json['inviterId']),
      inviteeId: serializer.fromJson<String?>(json['inviteeId']),
      contactInfo: serializer.fromJson<String>(json['contactInfo']),
      status: serializer.fromJson<String>(json['status']),
      createdAt: serializer.fromJson<DateTime>(json['createdAt']),
      acceptedAt: serializer.fromJson<DateTime?>(json['acceptedAt']),
    );
  }
  @override
  Map<String, dynamic> toJson({ValueSerializer? serializer}) {
    serializer ??= driftRuntimeOptions.defaultSerializer;
    return <String, dynamic>{
      'id': serializer.toJson<String>(id),
      'inviterId': serializer.toJson<String>(inviterId),
      'inviteeId': serializer.toJson<String?>(inviteeId),
      'contactInfo': serializer.toJson<String>(contactInfo),
      'status': serializer.toJson<String>(status),
      'createdAt': serializer.toJson<DateTime>(createdAt),
      'acceptedAt': serializer.toJson<DateTime?>(acceptedAt),
    };
  }

  Referral copyWith(
          {String? id,
          String? inviterId,
          Value<String?> inviteeId = const Value.absent(),
          String? contactInfo,
          String? status,
          DateTime? createdAt,
          Value<DateTime?> acceptedAt = const Value.absent()}) =>
      Referral(
        id: id ?? this.id,
        inviterId: inviterId ?? this.inviterId,
        inviteeId: inviteeId.present ? inviteeId.value : this.inviteeId,
        contactInfo: contactInfo ?? this.contactInfo,
        status: status ?? this.status,
        createdAt: createdAt ?? this.createdAt,
        acceptedAt: acceptedAt.present ? acceptedAt.value : this.acceptedAt,
      );
  Referral copyWithCompanion(ReferralsCompanion data) {
    return Referral(
      id: data.id.present ? data.id.value : this.id,
      inviterId: data.inviterId.present ? data.inviterId.value : this.inviterId,
      inviteeId: data.inviteeId.present ? data.inviteeId.value : this.inviteeId,
      contactInfo:
          data.contactInfo.present ? data.contactInfo.value : this.contactInfo,
      status: data.status.present ? data.status.value : this.status,
      createdAt: data.createdAt.present ? data.createdAt.value : this.createdAt,
      acceptedAt:
          data.acceptedAt.present ? data.acceptedAt.value : this.acceptedAt,
    );
  }

  @override
  String toString() {
    return (StringBuffer('Referral(')
          ..write('id: $id, ')
          ..write('inviterId: $inviterId, ')
          ..write('inviteeId: $inviteeId, ')
          ..write('contactInfo: $contactInfo, ')
          ..write('status: $status, ')
          ..write('createdAt: $createdAt, ')
          ..write('acceptedAt: $acceptedAt')
          ..write(')'))
        .toString();
  }

  @override
  int get hashCode => Object.hash(
      id, inviterId, inviteeId, contactInfo, status, createdAt, acceptedAt);
  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      (other is Referral &&
          other.id == this.id &&
          other.inviterId == this.inviterId &&
          other.inviteeId == this.inviteeId &&
          other.contactInfo == this.contactInfo &&
          other.status == this.status &&
          other.createdAt == this.createdAt &&
          other.acceptedAt == this.acceptedAt);
}

class ReferralsCompanion extends UpdateCompanion<Referral> {
  final Value<String> id;
  final Value<String> inviterId;
  final Value<String?> inviteeId;
  final Value<String> contactInfo;
  final Value<String> status;
  final Value<DateTime> createdAt;
  final Value<DateTime?> acceptedAt;
  final Value<int> rowid;
  const ReferralsCompanion({
    this.id = const Value.absent(),
    this.inviterId = const Value.absent(),
    this.inviteeId = const Value.absent(),
    this.contactInfo = const Value.absent(),
    this.status = const Value.absent(),
    this.createdAt = const Value.absent(),
    this.acceptedAt = const Value.absent(),
    this.rowid = const Value.absent(),
  });
  ReferralsCompanion.insert({
    required String id,
    required String inviterId,
    this.inviteeId = const Value.absent(),
    required String contactInfo,
    this.status = const Value.absent(),
    this.createdAt = const Value.absent(),
    this.acceptedAt = const Value.absent(),
    this.rowid = const Value.absent(),
  })  : id = Value(id),
        inviterId = Value(inviterId),
        contactInfo = Value(contactInfo);
  static Insertable<Referral> custom({
    Expression<String>? id,
    Expression<String>? inviterId,
    Expression<String>? inviteeId,
    Expression<String>? contactInfo,
    Expression<String>? status,
    Expression<DateTime>? createdAt,
    Expression<DateTime>? acceptedAt,
    Expression<int>? rowid,
  }) {
    return RawValuesInsertable({
      if (id != null) 'id': id,
      if (inviterId != null) 'inviter_id': inviterId,
      if (inviteeId != null) 'invitee_id': inviteeId,
      if (contactInfo != null) 'contact_info': contactInfo,
      if (status != null) 'status': status,
      if (createdAt != null) 'created_at': createdAt,
      if (acceptedAt != null) 'accepted_at': acceptedAt,
      if (rowid != null) 'rowid': rowid,
    });
  }

  ReferralsCompanion copyWith(
      {Value<String>? id,
      Value<String>? inviterId,
      Value<String?>? inviteeId,
      Value<String>? contactInfo,
      Value<String>? status,
      Value<DateTime>? createdAt,
      Value<DateTime?>? acceptedAt,
      Value<int>? rowid}) {
    return ReferralsCompanion(
      id: id ?? this.id,
      inviterId: inviterId ?? this.inviterId,
      inviteeId: inviteeId ?? this.inviteeId,
      contactInfo: contactInfo ?? this.contactInfo,
      status: status ?? this.status,
      createdAt: createdAt ?? this.createdAt,
      acceptedAt: acceptedAt ?? this.acceptedAt,
      rowid: rowid ?? this.rowid,
    );
  }

  @override
  Map<String, Expression> toColumns(bool nullToAbsent) {
    final map = <String, Expression>{};
    if (id.present) {
      map['id'] = Variable<String>(id.value);
    }
    if (inviterId.present) {
      map['inviter_id'] = Variable<String>(inviterId.value);
    }
    if (inviteeId.present) {
      map['invitee_id'] = Variable<String>(inviteeId.value);
    }
    if (contactInfo.present) {
      map['contact_info'] = Variable<String>(contactInfo.value);
    }
    if (status.present) {
      map['status'] = Variable<String>(status.value);
    }
    if (createdAt.present) {
      map['created_at'] = Variable<DateTime>(createdAt.value);
    }
    if (acceptedAt.present) {
      map['accepted_at'] = Variable<DateTime>(acceptedAt.value);
    }
    if (rowid.present) {
      map['rowid'] = Variable<int>(rowid.value);
    }
    return map;
  }

  @override
  String toString() {
    return (StringBuffer('ReferralsCompanion(')
          ..write('id: $id, ')
          ..write('inviterId: $inviterId, ')
          ..write('inviteeId: $inviteeId, ')
          ..write('contactInfo: $contactInfo, ')
          ..write('status: $status, ')
          ..write('createdAt: $createdAt, ')
          ..write('acceptedAt: $acceptedAt, ')
          ..write('rowid: $rowid')
          ..write(')'))
        .toString();
  }
}

class $ServiceListingsTable extends ServiceListings
    with TableInfo<$ServiceListingsTable, ServiceListing> {
  @override
  final GeneratedDatabase attachedDatabase;
  final String? _alias;
  $ServiceListingsTable(this.attachedDatabase, [this._alias]);
  static const VerificationMeta _idMeta = const VerificationMeta('id');
  @override
  late final GeneratedColumn<String> id = GeneratedColumn<String>(
      'id', aliasedName, false,
      type: DriftSqlType.string, requiredDuringInsert: true);
  static const VerificationMeta _providerIdMeta =
      const VerificationMeta('providerId');
  @override
  late final GeneratedColumn<String> providerId = GeneratedColumn<String>(
      'provider_id', aliasedName, false,
      type: DriftSqlType.string, requiredDuringInsert: true);
  static const VerificationMeta _serviceTypeMeta =
      const VerificationMeta('serviceType');
  @override
  late final GeneratedColumn<String> serviceType = GeneratedColumn<String>(
      'service_type', aliasedName, false,
      type: DriftSqlType.string, requiredDuringInsert: true);
  static const VerificationMeta _titleMeta = const VerificationMeta('title');
  @override
  late final GeneratedColumn<String> title = GeneratedColumn<String>(
      'title', aliasedName, false,
      type: DriftSqlType.string, requiredDuringInsert: true);
  static const VerificationMeta _descriptionMeta =
      const VerificationMeta('description');
  @override
  late final GeneratedColumn<String> description = GeneratedColumn<String>(
      'description', aliasedName, false,
      type: DriftSqlType.string, requiredDuringInsert: true);
  static const VerificationMeta _priceMinMeta =
      const VerificationMeta('priceMin');
  @override
  late final GeneratedColumn<double> priceMin = GeneratedColumn<double>(
      'price_min', aliasedName, true,
      type: DriftSqlType.double, requiredDuringInsert: false);
  static const VerificationMeta _priceMaxMeta =
      const VerificationMeta('priceMax');
  @override
  late final GeneratedColumn<double> priceMax = GeneratedColumn<double>(
      'price_max', aliasedName, true,
      type: DriftSqlType.double, requiredDuringInsert: false);
  static const VerificationMeta _locationMeta =
      const VerificationMeta('location');
  @override
  late final GeneratedColumn<String> location = GeneratedColumn<String>(
      'location', aliasedName, true,
      type: DriftSqlType.string, requiredDuringInsert: false);
  static const VerificationMeta _isAvailableMeta =
      const VerificationMeta('isAvailable');
  @override
  late final GeneratedColumn<bool> isAvailable = GeneratedColumn<bool>(
      'is_available', aliasedName, false,
      type: DriftSqlType.bool,
      requiredDuringInsert: false,
      defaultConstraints: GeneratedColumn.constraintIsAlways(
          'CHECK ("is_available" IN (0, 1))'),
      defaultValue: const Constant(true));
  static const VerificationMeta _ratingMeta = const VerificationMeta('rating');
  @override
  late final GeneratedColumn<double> rating = GeneratedColumn<double>(
      'rating', aliasedName, false,
      type: DriftSqlType.double,
      requiredDuringInsert: false,
      defaultValue: const Constant(0.0));
  static const VerificationMeta _completedCountMeta =
      const VerificationMeta('completedCount');
  @override
  late final GeneratedColumn<int> completedCount = GeneratedColumn<int>(
      'completed_count', aliasedName, false,
      type: DriftSqlType.int,
      requiredDuringInsert: false,
      defaultValue: const Constant(0));
  static const VerificationMeta _tagsMeta = const VerificationMeta('tags');
  @override
  late final GeneratedColumn<String> tags = GeneratedColumn<String>(
      'tags', aliasedName, true,
      type: DriftSqlType.string, requiredDuringInsert: false);
  static const VerificationMeta _createdAtMeta =
      const VerificationMeta('createdAt');
  @override
  late final GeneratedColumn<DateTime> createdAt = GeneratedColumn<DateTime>(
      'created_at', aliasedName, false,
      type: DriftSqlType.dateTime,
      requiredDuringInsert: false,
      defaultValue: currentDateAndTime);
  @override
  List<GeneratedColumn> get $columns => [
        id,
        providerId,
        serviceType,
        title,
        description,
        priceMin,
        priceMax,
        location,
        isAvailable,
        rating,
        completedCount,
        tags,
        createdAt
      ];
  @override
  String get aliasedName => _alias ?? actualTableName;
  @override
  String get actualTableName => $name;
  static const String $name = 'service_listings';
  @override
  VerificationContext validateIntegrity(Insertable<ServiceListing> instance,
      {bool isInserting = false}) {
    final context = VerificationContext();
    final data = instance.toColumns(true);
    if (data.containsKey('id')) {
      context.handle(_idMeta, id.isAcceptableOrUnknown(data['id']!, _idMeta));
    } else if (isInserting) {
      context.missing(_idMeta);
    }
    if (data.containsKey('provider_id')) {
      context.handle(
          _providerIdMeta,
          providerId.isAcceptableOrUnknown(
              data['provider_id']!, _providerIdMeta));
    } else if (isInserting) {
      context.missing(_providerIdMeta);
    }
    if (data.containsKey('service_type')) {
      context.handle(
          _serviceTypeMeta,
          serviceType.isAcceptableOrUnknown(
              data['service_type']!, _serviceTypeMeta));
    } else if (isInserting) {
      context.missing(_serviceTypeMeta);
    }
    if (data.containsKey('title')) {
      context.handle(
          _titleMeta, title.isAcceptableOrUnknown(data['title']!, _titleMeta));
    } else if (isInserting) {
      context.missing(_titleMeta);
    }
    if (data.containsKey('description')) {
      context.handle(
          _descriptionMeta,
          description.isAcceptableOrUnknown(
              data['description']!, _descriptionMeta));
    } else if (isInserting) {
      context.missing(_descriptionMeta);
    }
    if (data.containsKey('price_min')) {
      context.handle(_priceMinMeta,
          priceMin.isAcceptableOrUnknown(data['price_min']!, _priceMinMeta));
    }
    if (data.containsKey('price_max')) {
      context.handle(_priceMaxMeta,
          priceMax.isAcceptableOrUnknown(data['price_max']!, _priceMaxMeta));
    }
    if (data.containsKey('location')) {
      context.handle(_locationMeta,
          location.isAcceptableOrUnknown(data['location']!, _locationMeta));
    }
    if (data.containsKey('is_available')) {
      context.handle(
          _isAvailableMeta,
          isAvailable.isAcceptableOrUnknown(
              data['is_available']!, _isAvailableMeta));
    }
    if (data.containsKey('rating')) {
      context.handle(_ratingMeta,
          rating.isAcceptableOrUnknown(data['rating']!, _ratingMeta));
    }
    if (data.containsKey('completed_count')) {
      context.handle(
          _completedCountMeta,
          completedCount.isAcceptableOrUnknown(
              data['completed_count']!, _completedCountMeta));
    }
    if (data.containsKey('tags')) {
      context.handle(
          _tagsMeta, tags.isAcceptableOrUnknown(data['tags']!, _tagsMeta));
    }
    if (data.containsKey('created_at')) {
      context.handle(_createdAtMeta,
          createdAt.isAcceptableOrUnknown(data['created_at']!, _createdAtMeta));
    }
    return context;
  }

  @override
  Set<GeneratedColumn> get $primaryKey => {id};
  @override
  ServiceListing map(Map<String, dynamic> data, {String? tablePrefix}) {
    final effectivePrefix = tablePrefix != null ? '$tablePrefix.' : '';
    return ServiceListing(
      id: attachedDatabase.typeMapping
          .read(DriftSqlType.string, data['${effectivePrefix}id'])!,
      providerId: attachedDatabase.typeMapping
          .read(DriftSqlType.string, data['${effectivePrefix}provider_id'])!,
      serviceType: attachedDatabase.typeMapping
          .read(DriftSqlType.string, data['${effectivePrefix}service_type'])!,
      title: attachedDatabase.typeMapping
          .read(DriftSqlType.string, data['${effectivePrefix}title'])!,
      description: attachedDatabase.typeMapping
          .read(DriftSqlType.string, data['${effectivePrefix}description'])!,
      priceMin: attachedDatabase.typeMapping
          .read(DriftSqlType.double, data['${effectivePrefix}price_min']),
      priceMax: attachedDatabase.typeMapping
          .read(DriftSqlType.double, data['${effectivePrefix}price_max']),
      location: attachedDatabase.typeMapping
          .read(DriftSqlType.string, data['${effectivePrefix}location']),
      isAvailable: attachedDatabase.typeMapping
          .read(DriftSqlType.bool, data['${effectivePrefix}is_available'])!,
      rating: attachedDatabase.typeMapping
          .read(DriftSqlType.double, data['${effectivePrefix}rating'])!,
      completedCount: attachedDatabase.typeMapping
          .read(DriftSqlType.int, data['${effectivePrefix}completed_count'])!,
      tags: attachedDatabase.typeMapping
          .read(DriftSqlType.string, data['${effectivePrefix}tags']),
      createdAt: attachedDatabase.typeMapping
          .read(DriftSqlType.dateTime, data['${effectivePrefix}created_at'])!,
    );
  }

  @override
  $ServiceListingsTable createAlias(String alias) {
    return $ServiceListingsTable(attachedDatabase, alias);
  }
}

class ServiceListing extends DataClass implements Insertable<ServiceListing> {
  final String id;
  final String providerId;
  final String serviceType;
  final String title;
  final String description;
  final double? priceMin;
  final double? priceMax;
  final String? location;
  final bool isAvailable;
  final double rating;
  final int completedCount;
  final String? tags;
  final DateTime createdAt;
  const ServiceListing(
      {required this.id,
      required this.providerId,
      required this.serviceType,
      required this.title,
      required this.description,
      this.priceMin,
      this.priceMax,
      this.location,
      required this.isAvailable,
      required this.rating,
      required this.completedCount,
      this.tags,
      required this.createdAt});
  @override
  Map<String, Expression> toColumns(bool nullToAbsent) {
    final map = <String, Expression>{};
    map['id'] = Variable<String>(id);
    map['provider_id'] = Variable<String>(providerId);
    map['service_type'] = Variable<String>(serviceType);
    map['title'] = Variable<String>(title);
    map['description'] = Variable<String>(description);
    if (!nullToAbsent || priceMin != null) {
      map['price_min'] = Variable<double>(priceMin);
    }
    if (!nullToAbsent || priceMax != null) {
      map['price_max'] = Variable<double>(priceMax);
    }
    if (!nullToAbsent || location != null) {
      map['location'] = Variable<String>(location);
    }
    map['is_available'] = Variable<bool>(isAvailable);
    map['rating'] = Variable<double>(rating);
    map['completed_count'] = Variable<int>(completedCount);
    if (!nullToAbsent || tags != null) {
      map['tags'] = Variable<String>(tags);
    }
    map['created_at'] = Variable<DateTime>(createdAt);
    return map;
  }

  ServiceListingsCompanion toCompanion(bool nullToAbsent) {
    return ServiceListingsCompanion(
      id: Value(id),
      providerId: Value(providerId),
      serviceType: Value(serviceType),
      title: Value(title),
      description: Value(description),
      priceMin: priceMin == null && nullToAbsent
          ? const Value.absent()
          : Value(priceMin),
      priceMax: priceMax == null && nullToAbsent
          ? const Value.absent()
          : Value(priceMax),
      location: location == null && nullToAbsent
          ? const Value.absent()
          : Value(location),
      isAvailable: Value(isAvailable),
      rating: Value(rating),
      completedCount: Value(completedCount),
      tags: tags == null && nullToAbsent ? const Value.absent() : Value(tags),
      createdAt: Value(createdAt),
    );
  }

  factory ServiceListing.fromJson(Map<String, dynamic> json,
      {ValueSerializer? serializer}) {
    serializer ??= driftRuntimeOptions.defaultSerializer;
    return ServiceListing(
      id: serializer.fromJson<String>(json['id']),
      providerId: serializer.fromJson<String>(json['providerId']),
      serviceType: serializer.fromJson<String>(json['serviceType']),
      title: serializer.fromJson<String>(json['title']),
      description: serializer.fromJson<String>(json['description']),
      priceMin: serializer.fromJson<double?>(json['priceMin']),
      priceMax: serializer.fromJson<double?>(json['priceMax']),
      location: serializer.fromJson<String?>(json['location']),
      isAvailable: serializer.fromJson<bool>(json['isAvailable']),
      rating: serializer.fromJson<double>(json['rating']),
      completedCount: serializer.fromJson<int>(json['completedCount']),
      tags: serializer.fromJson<String?>(json['tags']),
      createdAt: serializer.fromJson<DateTime>(json['createdAt']),
    );
  }
  @override
  Map<String, dynamic> toJson({ValueSerializer? serializer}) {
    serializer ??= driftRuntimeOptions.defaultSerializer;
    return <String, dynamic>{
      'id': serializer.toJson<String>(id),
      'providerId': serializer.toJson<String>(providerId),
      'serviceType': serializer.toJson<String>(serviceType),
      'title': serializer.toJson<String>(title),
      'description': serializer.toJson<String>(description),
      'priceMin': serializer.toJson<double?>(priceMin),
      'priceMax': serializer.toJson<double?>(priceMax),
      'location': serializer.toJson<String?>(location),
      'isAvailable': serializer.toJson<bool>(isAvailable),
      'rating': serializer.toJson<double>(rating),
      'completedCount': serializer.toJson<int>(completedCount),
      'tags': serializer.toJson<String?>(tags),
      'createdAt': serializer.toJson<DateTime>(createdAt),
    };
  }

  ServiceListing copyWith(
          {String? id,
          String? providerId,
          String? serviceType,
          String? title,
          String? description,
          Value<double?> priceMin = const Value.absent(),
          Value<double?> priceMax = const Value.absent(),
          Value<String?> location = const Value.absent(),
          bool? isAvailable,
          double? rating,
          int? completedCount,
          Value<String?> tags = const Value.absent(),
          DateTime? createdAt}) =>
      ServiceListing(
        id: id ?? this.id,
        providerId: providerId ?? this.providerId,
        serviceType: serviceType ?? this.serviceType,
        title: title ?? this.title,
        description: description ?? this.description,
        priceMin: priceMin.present ? priceMin.value : this.priceMin,
        priceMax: priceMax.present ? priceMax.value : this.priceMax,
        location: location.present ? location.value : this.location,
        isAvailable: isAvailable ?? this.isAvailable,
        rating: rating ?? this.rating,
        completedCount: completedCount ?? this.completedCount,
        tags: tags.present ? tags.value : this.tags,
        createdAt: createdAt ?? this.createdAt,
      );
  ServiceListing copyWithCompanion(ServiceListingsCompanion data) {
    return ServiceListing(
      id: data.id.present ? data.id.value : this.id,
      providerId:
          data.providerId.present ? data.providerId.value : this.providerId,
      serviceType:
          data.serviceType.present ? data.serviceType.value : this.serviceType,
      title: data.title.present ? data.title.value : this.title,
      description:
          data.description.present ? data.description.value : this.description,
      priceMin: data.priceMin.present ? data.priceMin.value : this.priceMin,
      priceMax: data.priceMax.present ? data.priceMax.value : this.priceMax,
      location: data.location.present ? data.location.value : this.location,
      isAvailable:
          data.isAvailable.present ? data.isAvailable.value : this.isAvailable,
      rating: data.rating.present ? data.rating.value : this.rating,
      completedCount: data.completedCount.present
          ? data.completedCount.value
          : this.completedCount,
      tags: data.tags.present ? data.tags.value : this.tags,
      createdAt: data.createdAt.present ? data.createdAt.value : this.createdAt,
    );
  }

  @override
  String toString() {
    return (StringBuffer('ServiceListing(')
          ..write('id: $id, ')
          ..write('providerId: $providerId, ')
          ..write('serviceType: $serviceType, ')
          ..write('title: $title, ')
          ..write('description: $description, ')
          ..write('priceMin: $priceMin, ')
          ..write('priceMax: $priceMax, ')
          ..write('location: $location, ')
          ..write('isAvailable: $isAvailable, ')
          ..write('rating: $rating, ')
          ..write('completedCount: $completedCount, ')
          ..write('tags: $tags, ')
          ..write('createdAt: $createdAt')
          ..write(')'))
        .toString();
  }

  @override
  int get hashCode => Object.hash(
      id,
      providerId,
      serviceType,
      title,
      description,
      priceMin,
      priceMax,
      location,
      isAvailable,
      rating,
      completedCount,
      tags,
      createdAt);
  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      (other is ServiceListing &&
          other.id == this.id &&
          other.providerId == this.providerId &&
          other.serviceType == this.serviceType &&
          other.title == this.title &&
          other.description == this.description &&
          other.priceMin == this.priceMin &&
          other.priceMax == this.priceMax &&
          other.location == this.location &&
          other.isAvailable == this.isAvailable &&
          other.rating == this.rating &&
          other.completedCount == this.completedCount &&
          other.tags == this.tags &&
          other.createdAt == this.createdAt);
}

class ServiceListingsCompanion extends UpdateCompanion<ServiceListing> {
  final Value<String> id;
  final Value<String> providerId;
  final Value<String> serviceType;
  final Value<String> title;
  final Value<String> description;
  final Value<double?> priceMin;
  final Value<double?> priceMax;
  final Value<String?> location;
  final Value<bool> isAvailable;
  final Value<double> rating;
  final Value<int> completedCount;
  final Value<String?> tags;
  final Value<DateTime> createdAt;
  final Value<int> rowid;
  const ServiceListingsCompanion({
    this.id = const Value.absent(),
    this.providerId = const Value.absent(),
    this.serviceType = const Value.absent(),
    this.title = const Value.absent(),
    this.description = const Value.absent(),
    this.priceMin = const Value.absent(),
    this.priceMax = const Value.absent(),
    this.location = const Value.absent(),
    this.isAvailable = const Value.absent(),
    this.rating = const Value.absent(),
    this.completedCount = const Value.absent(),
    this.tags = const Value.absent(),
    this.createdAt = const Value.absent(),
    this.rowid = const Value.absent(),
  });
  ServiceListingsCompanion.insert({
    required String id,
    required String providerId,
    required String serviceType,
    required String title,
    required String description,
    this.priceMin = const Value.absent(),
    this.priceMax = const Value.absent(),
    this.location = const Value.absent(),
    this.isAvailable = const Value.absent(),
    this.rating = const Value.absent(),
    this.completedCount = const Value.absent(),
    this.tags = const Value.absent(),
    this.createdAt = const Value.absent(),
    this.rowid = const Value.absent(),
  })  : id = Value(id),
        providerId = Value(providerId),
        serviceType = Value(serviceType),
        title = Value(title),
        description = Value(description);
  static Insertable<ServiceListing> custom({
    Expression<String>? id,
    Expression<String>? providerId,
    Expression<String>? serviceType,
    Expression<String>? title,
    Expression<String>? description,
    Expression<double>? priceMin,
    Expression<double>? priceMax,
    Expression<String>? location,
    Expression<bool>? isAvailable,
    Expression<double>? rating,
    Expression<int>? completedCount,
    Expression<String>? tags,
    Expression<DateTime>? createdAt,
    Expression<int>? rowid,
  }) {
    return RawValuesInsertable({
      if (id != null) 'id': id,
      if (providerId != null) 'provider_id': providerId,
      if (serviceType != null) 'service_type': serviceType,
      if (title != null) 'title': title,
      if (description != null) 'description': description,
      if (priceMin != null) 'price_min': priceMin,
      if (priceMax != null) 'price_max': priceMax,
      if (location != null) 'location': location,
      if (isAvailable != null) 'is_available': isAvailable,
      if (rating != null) 'rating': rating,
      if (completedCount != null) 'completed_count': completedCount,
      if (tags != null) 'tags': tags,
      if (createdAt != null) 'created_at': createdAt,
      if (rowid != null) 'rowid': rowid,
    });
  }

  ServiceListingsCompanion copyWith(
      {Value<String>? id,
      Value<String>? providerId,
      Value<String>? serviceType,
      Value<String>? title,
      Value<String>? description,
      Value<double?>? priceMin,
      Value<double?>? priceMax,
      Value<String?>? location,
      Value<bool>? isAvailable,
      Value<double>? rating,
      Value<int>? completedCount,
      Value<String?>? tags,
      Value<DateTime>? createdAt,
      Value<int>? rowid}) {
    return ServiceListingsCompanion(
      id: id ?? this.id,
      providerId: providerId ?? this.providerId,
      serviceType: serviceType ?? this.serviceType,
      title: title ?? this.title,
      description: description ?? this.description,
      priceMin: priceMin ?? this.priceMin,
      priceMax: priceMax ?? this.priceMax,
      location: location ?? this.location,
      isAvailable: isAvailable ?? this.isAvailable,
      rating: rating ?? this.rating,
      completedCount: completedCount ?? this.completedCount,
      tags: tags ?? this.tags,
      createdAt: createdAt ?? this.createdAt,
      rowid: rowid ?? this.rowid,
    );
  }

  @override
  Map<String, Expression> toColumns(bool nullToAbsent) {
    final map = <String, Expression>{};
    if (id.present) {
      map['id'] = Variable<String>(id.value);
    }
    if (providerId.present) {
      map['provider_id'] = Variable<String>(providerId.value);
    }
    if (serviceType.present) {
      map['service_type'] = Variable<String>(serviceType.value);
    }
    if (title.present) {
      map['title'] = Variable<String>(title.value);
    }
    if (description.present) {
      map['description'] = Variable<String>(description.value);
    }
    if (priceMin.present) {
      map['price_min'] = Variable<double>(priceMin.value);
    }
    if (priceMax.present) {
      map['price_max'] = Variable<double>(priceMax.value);
    }
    if (location.present) {
      map['location'] = Variable<String>(location.value);
    }
    if (isAvailable.present) {
      map['is_available'] = Variable<bool>(isAvailable.value);
    }
    if (rating.present) {
      map['rating'] = Variable<double>(rating.value);
    }
    if (completedCount.present) {
      map['completed_count'] = Variable<int>(completedCount.value);
    }
    if (tags.present) {
      map['tags'] = Variable<String>(tags.value);
    }
    if (createdAt.present) {
      map['created_at'] = Variable<DateTime>(createdAt.value);
    }
    if (rowid.present) {
      map['rowid'] = Variable<int>(rowid.value);
    }
    return map;
  }

  @override
  String toString() {
    return (StringBuffer('ServiceListingsCompanion(')
          ..write('id: $id, ')
          ..write('providerId: $providerId, ')
          ..write('serviceType: $serviceType, ')
          ..write('title: $title, ')
          ..write('description: $description, ')
          ..write('priceMin: $priceMin, ')
          ..write('priceMax: $priceMax, ')
          ..write('location: $location, ')
          ..write('isAvailable: $isAvailable, ')
          ..write('rating: $rating, ')
          ..write('completedCount: $completedCount, ')
          ..write('tags: $tags, ')
          ..write('createdAt: $createdAt, ')
          ..write('rowid: $rowid')
          ..write(')'))
        .toString();
  }
}

class $ServiceOrdersTable extends ServiceOrders
    with TableInfo<$ServiceOrdersTable, ServiceOrder> {
  @override
  final GeneratedDatabase attachedDatabase;
  final String? _alias;
  $ServiceOrdersTable(this.attachedDatabase, [this._alias]);
  static const VerificationMeta _idMeta = const VerificationMeta('id');
  @override
  late final GeneratedColumn<String> id = GeneratedColumn<String>(
      'id', aliasedName, false,
      type: DriftSqlType.string, requiredDuringInsert: true);
  static const VerificationMeta _consumerIdMeta =
      const VerificationMeta('consumerId');
  @override
  late final GeneratedColumn<String> consumerId = GeneratedColumn<String>(
      'consumer_id', aliasedName, false,
      type: DriftSqlType.string, requiredDuringInsert: true);
  static const VerificationMeta _providerIdMeta =
      const VerificationMeta('providerId');
  @override
  late final GeneratedColumn<String> providerId = GeneratedColumn<String>(
      'provider_id', aliasedName, false,
      type: DriftSqlType.string, requiredDuringInsert: true);
  static const VerificationMeta _serviceListingIdMeta =
      const VerificationMeta('serviceListingId');
  @override
  late final GeneratedColumn<String> serviceListingId = GeneratedColumn<String>(
      'service_listing_id', aliasedName, false,
      type: DriftSqlType.string, requiredDuringInsert: true);
  static const VerificationMeta _statusMeta = const VerificationMeta('status');
  @override
  late final GeneratedColumn<String> status = GeneratedColumn<String>(
      'status', aliasedName, false,
      type: DriftSqlType.string,
      requiredDuringInsert: false,
      defaultValue: const Constant('pending'));
  static const VerificationMeta _descriptionMeta =
      const VerificationMeta('description');
  @override
  late final GeneratedColumn<String> description = GeneratedColumn<String>(
      'description', aliasedName, false,
      type: DriftSqlType.string, requiredDuringInsert: true);
  static const VerificationMeta _scheduledAtMeta =
      const VerificationMeta('scheduledAt');
  @override
  late final GeneratedColumn<DateTime> scheduledAt = GeneratedColumn<DateTime>(
      'scheduled_at', aliasedName, true,
      type: DriftSqlType.dateTime, requiredDuringInsert: false);
  static const VerificationMeta _completedAtMeta =
      const VerificationMeta('completedAt');
  @override
  late final GeneratedColumn<DateTime> completedAt = GeneratedColumn<DateTime>(
      'completed_at', aliasedName, true,
      type: DriftSqlType.dateTime, requiredDuringInsert: false);
  static const VerificationMeta _totalPriceMeta =
      const VerificationMeta('totalPrice');
  @override
  late final GeneratedColumn<double> totalPrice = GeneratedColumn<double>(
      'total_price', aliasedName, true,
      type: DriftSqlType.double, requiredDuringInsert: false);
  static const VerificationMeta _createdAtMeta =
      const VerificationMeta('createdAt');
  @override
  late final GeneratedColumn<DateTime> createdAt = GeneratedColumn<DateTime>(
      'created_at', aliasedName, false,
      type: DriftSqlType.dateTime,
      requiredDuringInsert: false,
      defaultValue: currentDateAndTime);
  @override
  List<GeneratedColumn> get $columns => [
        id,
        consumerId,
        providerId,
        serviceListingId,
        status,
        description,
        scheduledAt,
        completedAt,
        totalPrice,
        createdAt
      ];
  @override
  String get aliasedName => _alias ?? actualTableName;
  @override
  String get actualTableName => $name;
  static const String $name = 'service_orders';
  @override
  VerificationContext validateIntegrity(Insertable<ServiceOrder> instance,
      {bool isInserting = false}) {
    final context = VerificationContext();
    final data = instance.toColumns(true);
    if (data.containsKey('id')) {
      context.handle(_idMeta, id.isAcceptableOrUnknown(data['id']!, _idMeta));
    } else if (isInserting) {
      context.missing(_idMeta);
    }
    if (data.containsKey('consumer_id')) {
      context.handle(
          _consumerIdMeta,
          consumerId.isAcceptableOrUnknown(
              data['consumer_id']!, _consumerIdMeta));
    } else if (isInserting) {
      context.missing(_consumerIdMeta);
    }
    if (data.containsKey('provider_id')) {
      context.handle(
          _providerIdMeta,
          providerId.isAcceptableOrUnknown(
              data['provider_id']!, _providerIdMeta));
    } else if (isInserting) {
      context.missing(_providerIdMeta);
    }
    if (data.containsKey('service_listing_id')) {
      context.handle(
          _serviceListingIdMeta,
          serviceListingId.isAcceptableOrUnknown(
              data['service_listing_id']!, _serviceListingIdMeta));
    } else if (isInserting) {
      context.missing(_serviceListingIdMeta);
    }
    if (data.containsKey('status')) {
      context.handle(_statusMeta,
          status.isAcceptableOrUnknown(data['status']!, _statusMeta));
    }
    if (data.containsKey('description')) {
      context.handle(
          _descriptionMeta,
          description.isAcceptableOrUnknown(
              data['description']!, _descriptionMeta));
    } else if (isInserting) {
      context.missing(_descriptionMeta);
    }
    if (data.containsKey('scheduled_at')) {
      context.handle(
          _scheduledAtMeta,
          scheduledAt.isAcceptableOrUnknown(
              data['scheduled_at']!, _scheduledAtMeta));
    }
    if (data.containsKey('completed_at')) {
      context.handle(
          _completedAtMeta,
          completedAt.isAcceptableOrUnknown(
              data['completed_at']!, _completedAtMeta));
    }
    if (data.containsKey('total_price')) {
      context.handle(
          _totalPriceMeta,
          totalPrice.isAcceptableOrUnknown(
              data['total_price']!, _totalPriceMeta));
    }
    if (data.containsKey('created_at')) {
      context.handle(_createdAtMeta,
          createdAt.isAcceptableOrUnknown(data['created_at']!, _createdAtMeta));
    }
    return context;
  }

  @override
  Set<GeneratedColumn> get $primaryKey => {id};
  @override
  ServiceOrder map(Map<String, dynamic> data, {String? tablePrefix}) {
    final effectivePrefix = tablePrefix != null ? '$tablePrefix.' : '';
    return ServiceOrder(
      id: attachedDatabase.typeMapping
          .read(DriftSqlType.string, data['${effectivePrefix}id'])!,
      consumerId: attachedDatabase.typeMapping
          .read(DriftSqlType.string, data['${effectivePrefix}consumer_id'])!,
      providerId: attachedDatabase.typeMapping
          .read(DriftSqlType.string, data['${effectivePrefix}provider_id'])!,
      serviceListingId: attachedDatabase.typeMapping.read(
          DriftSqlType.string, data['${effectivePrefix}service_listing_id'])!,
      status: attachedDatabase.typeMapping
          .read(DriftSqlType.string, data['${effectivePrefix}status'])!,
      description: attachedDatabase.typeMapping
          .read(DriftSqlType.string, data['${effectivePrefix}description'])!,
      scheduledAt: attachedDatabase.typeMapping
          .read(DriftSqlType.dateTime, data['${effectivePrefix}scheduled_at']),
      completedAt: attachedDatabase.typeMapping
          .read(DriftSqlType.dateTime, data['${effectivePrefix}completed_at']),
      totalPrice: attachedDatabase.typeMapping
          .read(DriftSqlType.double, data['${effectivePrefix}total_price']),
      createdAt: attachedDatabase.typeMapping
          .read(DriftSqlType.dateTime, data['${effectivePrefix}created_at'])!,
    );
  }

  @override
  $ServiceOrdersTable createAlias(String alias) {
    return $ServiceOrdersTable(attachedDatabase, alias);
  }
}

class ServiceOrder extends DataClass implements Insertable<ServiceOrder> {
  final String id;
  final String consumerId;
  final String providerId;
  final String serviceListingId;
  final String status;
  final String description;
  final DateTime? scheduledAt;
  final DateTime? completedAt;
  final double? totalPrice;
  final DateTime createdAt;
  const ServiceOrder(
      {required this.id,
      required this.consumerId,
      required this.providerId,
      required this.serviceListingId,
      required this.status,
      required this.description,
      this.scheduledAt,
      this.completedAt,
      this.totalPrice,
      required this.createdAt});
  @override
  Map<String, Expression> toColumns(bool nullToAbsent) {
    final map = <String, Expression>{};
    map['id'] = Variable<String>(id);
    map['consumer_id'] = Variable<String>(consumerId);
    map['provider_id'] = Variable<String>(providerId);
    map['service_listing_id'] = Variable<String>(serviceListingId);
    map['status'] = Variable<String>(status);
    map['description'] = Variable<String>(description);
    if (!nullToAbsent || scheduledAt != null) {
      map['scheduled_at'] = Variable<DateTime>(scheduledAt);
    }
    if (!nullToAbsent || completedAt != null) {
      map['completed_at'] = Variable<DateTime>(completedAt);
    }
    if (!nullToAbsent || totalPrice != null) {
      map['total_price'] = Variable<double>(totalPrice);
    }
    map['created_at'] = Variable<DateTime>(createdAt);
    return map;
  }

  ServiceOrdersCompanion toCompanion(bool nullToAbsent) {
    return ServiceOrdersCompanion(
      id: Value(id),
      consumerId: Value(consumerId),
      providerId: Value(providerId),
      serviceListingId: Value(serviceListingId),
      status: Value(status),
      description: Value(description),
      scheduledAt: scheduledAt == null && nullToAbsent
          ? const Value.absent()
          : Value(scheduledAt),
      completedAt: completedAt == null && nullToAbsent
          ? const Value.absent()
          : Value(completedAt),
      totalPrice: totalPrice == null && nullToAbsent
          ? const Value.absent()
          : Value(totalPrice),
      createdAt: Value(createdAt),
    );
  }

  factory ServiceOrder.fromJson(Map<String, dynamic> json,
      {ValueSerializer? serializer}) {
    serializer ??= driftRuntimeOptions.defaultSerializer;
    return ServiceOrder(
      id: serializer.fromJson<String>(json['id']),
      consumerId: serializer.fromJson<String>(json['consumerId']),
      providerId: serializer.fromJson<String>(json['providerId']),
      serviceListingId: serializer.fromJson<String>(json['serviceListingId']),
      status: serializer.fromJson<String>(json['status']),
      description: serializer.fromJson<String>(json['description']),
      scheduledAt: serializer.fromJson<DateTime?>(json['scheduledAt']),
      completedAt: serializer.fromJson<DateTime?>(json['completedAt']),
      totalPrice: serializer.fromJson<double?>(json['totalPrice']),
      createdAt: serializer.fromJson<DateTime>(json['createdAt']),
    );
  }
  @override
  Map<String, dynamic> toJson({ValueSerializer? serializer}) {
    serializer ??= driftRuntimeOptions.defaultSerializer;
    return <String, dynamic>{
      'id': serializer.toJson<String>(id),
      'consumerId': serializer.toJson<String>(consumerId),
      'providerId': serializer.toJson<String>(providerId),
      'serviceListingId': serializer.toJson<String>(serviceListingId),
      'status': serializer.toJson<String>(status),
      'description': serializer.toJson<String>(description),
      'scheduledAt': serializer.toJson<DateTime?>(scheduledAt),
      'completedAt': serializer.toJson<DateTime?>(completedAt),
      'totalPrice': serializer.toJson<double?>(totalPrice),
      'createdAt': serializer.toJson<DateTime>(createdAt),
    };
  }

  ServiceOrder copyWith(
          {String? id,
          String? consumerId,
          String? providerId,
          String? serviceListingId,
          String? status,
          String? description,
          Value<DateTime?> scheduledAt = const Value.absent(),
          Value<DateTime?> completedAt = const Value.absent(),
          Value<double?> totalPrice = const Value.absent(),
          DateTime? createdAt}) =>
      ServiceOrder(
        id: id ?? this.id,
        consumerId: consumerId ?? this.consumerId,
        providerId: providerId ?? this.providerId,
        serviceListingId: serviceListingId ?? this.serviceListingId,
        status: status ?? this.status,
        description: description ?? this.description,
        scheduledAt: scheduledAt.present ? scheduledAt.value : this.scheduledAt,
        completedAt: completedAt.present ? completedAt.value : this.completedAt,
        totalPrice: totalPrice.present ? totalPrice.value : this.totalPrice,
        createdAt: createdAt ?? this.createdAt,
      );
  ServiceOrder copyWithCompanion(ServiceOrdersCompanion data) {
    return ServiceOrder(
      id: data.id.present ? data.id.value : this.id,
      consumerId:
          data.consumerId.present ? data.consumerId.value : this.consumerId,
      providerId:
          data.providerId.present ? data.providerId.value : this.providerId,
      serviceListingId: data.serviceListingId.present
          ? data.serviceListingId.value
          : this.serviceListingId,
      status: data.status.present ? data.status.value : this.status,
      description:
          data.description.present ? data.description.value : this.description,
      scheduledAt:
          data.scheduledAt.present ? data.scheduledAt.value : this.scheduledAt,
      completedAt:
          data.completedAt.present ? data.completedAt.value : this.completedAt,
      totalPrice:
          data.totalPrice.present ? data.totalPrice.value : this.totalPrice,
      createdAt: data.createdAt.present ? data.createdAt.value : this.createdAt,
    );
  }

  @override
  String toString() {
    return (StringBuffer('ServiceOrder(')
          ..write('id: $id, ')
          ..write('consumerId: $consumerId, ')
          ..write('providerId: $providerId, ')
          ..write('serviceListingId: $serviceListingId, ')
          ..write('status: $status, ')
          ..write('description: $description, ')
          ..write('scheduledAt: $scheduledAt, ')
          ..write('completedAt: $completedAt, ')
          ..write('totalPrice: $totalPrice, ')
          ..write('createdAt: $createdAt')
          ..write(')'))
        .toString();
  }

  @override
  int get hashCode => Object.hash(id, consumerId, providerId, serviceListingId,
      status, description, scheduledAt, completedAt, totalPrice, createdAt);
  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      (other is ServiceOrder &&
          other.id == this.id &&
          other.consumerId == this.consumerId &&
          other.providerId == this.providerId &&
          other.serviceListingId == this.serviceListingId &&
          other.status == this.status &&
          other.description == this.description &&
          other.scheduledAt == this.scheduledAt &&
          other.completedAt == this.completedAt &&
          other.totalPrice == this.totalPrice &&
          other.createdAt == this.createdAt);
}

class ServiceOrdersCompanion extends UpdateCompanion<ServiceOrder> {
  final Value<String> id;
  final Value<String> consumerId;
  final Value<String> providerId;
  final Value<String> serviceListingId;
  final Value<String> status;
  final Value<String> description;
  final Value<DateTime?> scheduledAt;
  final Value<DateTime?> completedAt;
  final Value<double?> totalPrice;
  final Value<DateTime> createdAt;
  final Value<int> rowid;
  const ServiceOrdersCompanion({
    this.id = const Value.absent(),
    this.consumerId = const Value.absent(),
    this.providerId = const Value.absent(),
    this.serviceListingId = const Value.absent(),
    this.status = const Value.absent(),
    this.description = const Value.absent(),
    this.scheduledAt = const Value.absent(),
    this.completedAt = const Value.absent(),
    this.totalPrice = const Value.absent(),
    this.createdAt = const Value.absent(),
    this.rowid = const Value.absent(),
  });
  ServiceOrdersCompanion.insert({
    required String id,
    required String consumerId,
    required String providerId,
    required String serviceListingId,
    this.status = const Value.absent(),
    required String description,
    this.scheduledAt = const Value.absent(),
    this.completedAt = const Value.absent(),
    this.totalPrice = const Value.absent(),
    this.createdAt = const Value.absent(),
    this.rowid = const Value.absent(),
  })  : id = Value(id),
        consumerId = Value(consumerId),
        providerId = Value(providerId),
        serviceListingId = Value(serviceListingId),
        description = Value(description);
  static Insertable<ServiceOrder> custom({
    Expression<String>? id,
    Expression<String>? consumerId,
    Expression<String>? providerId,
    Expression<String>? serviceListingId,
    Expression<String>? status,
    Expression<String>? description,
    Expression<DateTime>? scheduledAt,
    Expression<DateTime>? completedAt,
    Expression<double>? totalPrice,
    Expression<DateTime>? createdAt,
    Expression<int>? rowid,
  }) {
    return RawValuesInsertable({
      if (id != null) 'id': id,
      if (consumerId != null) 'consumer_id': consumerId,
      if (providerId != null) 'provider_id': providerId,
      if (serviceListingId != null) 'service_listing_id': serviceListingId,
      if (status != null) 'status': status,
      if (description != null) 'description': description,
      if (scheduledAt != null) 'scheduled_at': scheduledAt,
      if (completedAt != null) 'completed_at': completedAt,
      if (totalPrice != null) 'total_price': totalPrice,
      if (createdAt != null) 'created_at': createdAt,
      if (rowid != null) 'rowid': rowid,
    });
  }

  ServiceOrdersCompanion copyWith(
      {Value<String>? id,
      Value<String>? consumerId,
      Value<String>? providerId,
      Value<String>? serviceListingId,
      Value<String>? status,
      Value<String>? description,
      Value<DateTime?>? scheduledAt,
      Value<DateTime?>? completedAt,
      Value<double?>? totalPrice,
      Value<DateTime>? createdAt,
      Value<int>? rowid}) {
    return ServiceOrdersCompanion(
      id: id ?? this.id,
      consumerId: consumerId ?? this.consumerId,
      providerId: providerId ?? this.providerId,
      serviceListingId: serviceListingId ?? this.serviceListingId,
      status: status ?? this.status,
      description: description ?? this.description,
      scheduledAt: scheduledAt ?? this.scheduledAt,
      completedAt: completedAt ?? this.completedAt,
      totalPrice: totalPrice ?? this.totalPrice,
      createdAt: createdAt ?? this.createdAt,
      rowid: rowid ?? this.rowid,
    );
  }

  @override
  Map<String, Expression> toColumns(bool nullToAbsent) {
    final map = <String, Expression>{};
    if (id.present) {
      map['id'] = Variable<String>(id.value);
    }
    if (consumerId.present) {
      map['consumer_id'] = Variable<String>(consumerId.value);
    }
    if (providerId.present) {
      map['provider_id'] = Variable<String>(providerId.value);
    }
    if (serviceListingId.present) {
      map['service_listing_id'] = Variable<String>(serviceListingId.value);
    }
    if (status.present) {
      map['status'] = Variable<String>(status.value);
    }
    if (description.present) {
      map['description'] = Variable<String>(description.value);
    }
    if (scheduledAt.present) {
      map['scheduled_at'] = Variable<DateTime>(scheduledAt.value);
    }
    if (completedAt.present) {
      map['completed_at'] = Variable<DateTime>(completedAt.value);
    }
    if (totalPrice.present) {
      map['total_price'] = Variable<double>(totalPrice.value);
    }
    if (createdAt.present) {
      map['created_at'] = Variable<DateTime>(createdAt.value);
    }
    if (rowid.present) {
      map['rowid'] = Variable<int>(rowid.value);
    }
    return map;
  }

  @override
  String toString() {
    return (StringBuffer('ServiceOrdersCompanion(')
          ..write('id: $id, ')
          ..write('consumerId: $consumerId, ')
          ..write('providerId: $providerId, ')
          ..write('serviceListingId: $serviceListingId, ')
          ..write('status: $status, ')
          ..write('description: $description, ')
          ..write('scheduledAt: $scheduledAt, ')
          ..write('completedAt: $completedAt, ')
          ..write('totalPrice: $totalPrice, ')
          ..write('createdAt: $createdAt, ')
          ..write('rowid: $rowid')
          ..write(')'))
        .toString();
  }
}

class $ReviewsTable extends Reviews with TableInfo<$ReviewsTable, Review> {
  @override
  final GeneratedDatabase attachedDatabase;
  final String? _alias;
  $ReviewsTable(this.attachedDatabase, [this._alias]);
  static const VerificationMeta _idMeta = const VerificationMeta('id');
  @override
  late final GeneratedColumn<String> id = GeneratedColumn<String>(
      'id', aliasedName, false,
      type: DriftSqlType.string, requiredDuringInsert: true);
  static const VerificationMeta _orderIdMeta =
      const VerificationMeta('orderId');
  @override
  late final GeneratedColumn<String> orderId = GeneratedColumn<String>(
      'order_id', aliasedName, false,
      type: DriftSqlType.string, requiredDuringInsert: true);
  static const VerificationMeta _reviewerIdMeta =
      const VerificationMeta('reviewerId');
  @override
  late final GeneratedColumn<String> reviewerId = GeneratedColumn<String>(
      'reviewer_id', aliasedName, false,
      type: DriftSqlType.string, requiredDuringInsert: true);
  static const VerificationMeta _revieweeIdMeta =
      const VerificationMeta('revieweeId');
  @override
  late final GeneratedColumn<String> revieweeId = GeneratedColumn<String>(
      'reviewee_id', aliasedName, false,
      type: DriftSqlType.string, requiredDuringInsert: true);
  static const VerificationMeta _ratingMeta = const VerificationMeta('rating');
  @override
  late final GeneratedColumn<double> rating = GeneratedColumn<double>(
      'rating', aliasedName, false,
      type: DriftSqlType.double, requiredDuringInsert: true);
  static const VerificationMeta _commentMeta =
      const VerificationMeta('comment');
  @override
  late final GeneratedColumn<String> comment = GeneratedColumn<String>(
      'comment', aliasedName, true,
      type: DriftSqlType.string, requiredDuringInsert: false);
  static const VerificationMeta _createdAtMeta =
      const VerificationMeta('createdAt');
  @override
  late final GeneratedColumn<DateTime> createdAt = GeneratedColumn<DateTime>(
      'created_at', aliasedName, false,
      type: DriftSqlType.dateTime,
      requiredDuringInsert: false,
      defaultValue: currentDateAndTime);
  @override
  List<GeneratedColumn> get $columns =>
      [id, orderId, reviewerId, revieweeId, rating, comment, createdAt];
  @override
  String get aliasedName => _alias ?? actualTableName;
  @override
  String get actualTableName => $name;
  static const String $name = 'reviews';
  @override
  VerificationContext validateIntegrity(Insertable<Review> instance,
      {bool isInserting = false}) {
    final context = VerificationContext();
    final data = instance.toColumns(true);
    if (data.containsKey('id')) {
      context.handle(_idMeta, id.isAcceptableOrUnknown(data['id']!, _idMeta));
    } else if (isInserting) {
      context.missing(_idMeta);
    }
    if (data.containsKey('order_id')) {
      context.handle(_orderIdMeta,
          orderId.isAcceptableOrUnknown(data['order_id']!, _orderIdMeta));
    } else if (isInserting) {
      context.missing(_orderIdMeta);
    }
    if (data.containsKey('reviewer_id')) {
      context.handle(
          _reviewerIdMeta,
          reviewerId.isAcceptableOrUnknown(
              data['reviewer_id']!, _reviewerIdMeta));
    } else if (isInserting) {
      context.missing(_reviewerIdMeta);
    }
    if (data.containsKey('reviewee_id')) {
      context.handle(
          _revieweeIdMeta,
          revieweeId.isAcceptableOrUnknown(
              data['reviewee_id']!, _revieweeIdMeta));
    } else if (isInserting) {
      context.missing(_revieweeIdMeta);
    }
    if (data.containsKey('rating')) {
      context.handle(_ratingMeta,
          rating.isAcceptableOrUnknown(data['rating']!, _ratingMeta));
    } else if (isInserting) {
      context.missing(_ratingMeta);
    }
    if (data.containsKey('comment')) {
      context.handle(_commentMeta,
          comment.isAcceptableOrUnknown(data['comment']!, _commentMeta));
    }
    if (data.containsKey('created_at')) {
      context.handle(_createdAtMeta,
          createdAt.isAcceptableOrUnknown(data['created_at']!, _createdAtMeta));
    }
    return context;
  }

  @override
  Set<GeneratedColumn> get $primaryKey => {id};
  @override
  Review map(Map<String, dynamic> data, {String? tablePrefix}) {
    final effectivePrefix = tablePrefix != null ? '$tablePrefix.' : '';
    return Review(
      id: attachedDatabase.typeMapping
          .read(DriftSqlType.string, data['${effectivePrefix}id'])!,
      orderId: attachedDatabase.typeMapping
          .read(DriftSqlType.string, data['${effectivePrefix}order_id'])!,
      reviewerId: attachedDatabase.typeMapping
          .read(DriftSqlType.string, data['${effectivePrefix}reviewer_id'])!,
      revieweeId: attachedDatabase.typeMapping
          .read(DriftSqlType.string, data['${effectivePrefix}reviewee_id'])!,
      rating: attachedDatabase.typeMapping
          .read(DriftSqlType.double, data['${effectivePrefix}rating'])!,
      comment: attachedDatabase.typeMapping
          .read(DriftSqlType.string, data['${effectivePrefix}comment']),
      createdAt: attachedDatabase.typeMapping
          .read(DriftSqlType.dateTime, data['${effectivePrefix}created_at'])!,
    );
  }

  @override
  $ReviewsTable createAlias(String alias) {
    return $ReviewsTable(attachedDatabase, alias);
  }
}

class Review extends DataClass implements Insertable<Review> {
  final String id;
  final String orderId;
  final String reviewerId;
  final String revieweeId;
  final double rating;
  final String? comment;
  final DateTime createdAt;
  const Review(
      {required this.id,
      required this.orderId,
      required this.reviewerId,
      required this.revieweeId,
      required this.rating,
      this.comment,
      required this.createdAt});
  @override
  Map<String, Expression> toColumns(bool nullToAbsent) {
    final map = <String, Expression>{};
    map['id'] = Variable<String>(id);
    map['order_id'] = Variable<String>(orderId);
    map['reviewer_id'] = Variable<String>(reviewerId);
    map['reviewee_id'] = Variable<String>(revieweeId);
    map['rating'] = Variable<double>(rating);
    if (!nullToAbsent || comment != null) {
      map['comment'] = Variable<String>(comment);
    }
    map['created_at'] = Variable<DateTime>(createdAt);
    return map;
  }

  ReviewsCompanion toCompanion(bool nullToAbsent) {
    return ReviewsCompanion(
      id: Value(id),
      orderId: Value(orderId),
      reviewerId: Value(reviewerId),
      revieweeId: Value(revieweeId),
      rating: Value(rating),
      comment: comment == null && nullToAbsent
          ? const Value.absent()
          : Value(comment),
      createdAt: Value(createdAt),
    );
  }

  factory Review.fromJson(Map<String, dynamic> json,
      {ValueSerializer? serializer}) {
    serializer ??= driftRuntimeOptions.defaultSerializer;
    return Review(
      id: serializer.fromJson<String>(json['id']),
      orderId: serializer.fromJson<String>(json['orderId']),
      reviewerId: serializer.fromJson<String>(json['reviewerId']),
      revieweeId: serializer.fromJson<String>(json['revieweeId']),
      rating: serializer.fromJson<double>(json['rating']),
      comment: serializer.fromJson<String?>(json['comment']),
      createdAt: serializer.fromJson<DateTime>(json['createdAt']),
    );
  }
  @override
  Map<String, dynamic> toJson({ValueSerializer? serializer}) {
    serializer ??= driftRuntimeOptions.defaultSerializer;
    return <String, dynamic>{
      'id': serializer.toJson<String>(id),
      'orderId': serializer.toJson<String>(orderId),
      'reviewerId': serializer.toJson<String>(reviewerId),
      'revieweeId': serializer.toJson<String>(revieweeId),
      'rating': serializer.toJson<double>(rating),
      'comment': serializer.toJson<String?>(comment),
      'createdAt': serializer.toJson<DateTime>(createdAt),
    };
  }

  Review copyWith(
          {String? id,
          String? orderId,
          String? reviewerId,
          String? revieweeId,
          double? rating,
          Value<String?> comment = const Value.absent(),
          DateTime? createdAt}) =>
      Review(
        id: id ?? this.id,
        orderId: orderId ?? this.orderId,
        reviewerId: reviewerId ?? this.reviewerId,
        revieweeId: revieweeId ?? this.revieweeId,
        rating: rating ?? this.rating,
        comment: comment.present ? comment.value : this.comment,
        createdAt: createdAt ?? this.createdAt,
      );
  Review copyWithCompanion(ReviewsCompanion data) {
    return Review(
      id: data.id.present ? data.id.value : this.id,
      orderId: data.orderId.present ? data.orderId.value : this.orderId,
      reviewerId:
          data.reviewerId.present ? data.reviewerId.value : this.reviewerId,
      revieweeId:
          data.revieweeId.present ? data.revieweeId.value : this.revieweeId,
      rating: data.rating.present ? data.rating.value : this.rating,
      comment: data.comment.present ? data.comment.value : this.comment,
      createdAt: data.createdAt.present ? data.createdAt.value : this.createdAt,
    );
  }

  @override
  String toString() {
    return (StringBuffer('Review(')
          ..write('id: $id, ')
          ..write('orderId: $orderId, ')
          ..write('reviewerId: $reviewerId, ')
          ..write('revieweeId: $revieweeId, ')
          ..write('rating: $rating, ')
          ..write('comment: $comment, ')
          ..write('createdAt: $createdAt')
          ..write(')'))
        .toString();
  }

  @override
  int get hashCode => Object.hash(
      id, orderId, reviewerId, revieweeId, rating, comment, createdAt);
  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      (other is Review &&
          other.id == this.id &&
          other.orderId == this.orderId &&
          other.reviewerId == this.reviewerId &&
          other.revieweeId == this.revieweeId &&
          other.rating == this.rating &&
          other.comment == this.comment &&
          other.createdAt == this.createdAt);
}

class ReviewsCompanion extends UpdateCompanion<Review> {
  final Value<String> id;
  final Value<String> orderId;
  final Value<String> reviewerId;
  final Value<String> revieweeId;
  final Value<double> rating;
  final Value<String?> comment;
  final Value<DateTime> createdAt;
  final Value<int> rowid;
  const ReviewsCompanion({
    this.id = const Value.absent(),
    this.orderId = const Value.absent(),
    this.reviewerId = const Value.absent(),
    this.revieweeId = const Value.absent(),
    this.rating = const Value.absent(),
    this.comment = const Value.absent(),
    this.createdAt = const Value.absent(),
    this.rowid = const Value.absent(),
  });
  ReviewsCompanion.insert({
    required String id,
    required String orderId,
    required String reviewerId,
    required String revieweeId,
    required double rating,
    this.comment = const Value.absent(),
    this.createdAt = const Value.absent(),
    this.rowid = const Value.absent(),
  })  : id = Value(id),
        orderId = Value(orderId),
        reviewerId = Value(reviewerId),
        revieweeId = Value(revieweeId),
        rating = Value(rating);
  static Insertable<Review> custom({
    Expression<String>? id,
    Expression<String>? orderId,
    Expression<String>? reviewerId,
    Expression<String>? revieweeId,
    Expression<double>? rating,
    Expression<String>? comment,
    Expression<DateTime>? createdAt,
    Expression<int>? rowid,
  }) {
    return RawValuesInsertable({
      if (id != null) 'id': id,
      if (orderId != null) 'order_id': orderId,
      if (reviewerId != null) 'reviewer_id': reviewerId,
      if (revieweeId != null) 'reviewee_id': revieweeId,
      if (rating != null) 'rating': rating,
      if (comment != null) 'comment': comment,
      if (createdAt != null) 'created_at': createdAt,
      if (rowid != null) 'rowid': rowid,
    });
  }

  ReviewsCompanion copyWith(
      {Value<String>? id,
      Value<String>? orderId,
      Value<String>? reviewerId,
      Value<String>? revieweeId,
      Value<double>? rating,
      Value<String?>? comment,
      Value<DateTime>? createdAt,
      Value<int>? rowid}) {
    return ReviewsCompanion(
      id: id ?? this.id,
      orderId: orderId ?? this.orderId,
      reviewerId: reviewerId ?? this.reviewerId,
      revieweeId: revieweeId ?? this.revieweeId,
      rating: rating ?? this.rating,
      comment: comment ?? this.comment,
      createdAt: createdAt ?? this.createdAt,
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
    if (reviewerId.present) {
      map['reviewer_id'] = Variable<String>(reviewerId.value);
    }
    if (revieweeId.present) {
      map['reviewee_id'] = Variable<String>(revieweeId.value);
    }
    if (rating.present) {
      map['rating'] = Variable<double>(rating.value);
    }
    if (comment.present) {
      map['comment'] = Variable<String>(comment.value);
    }
    if (createdAt.present) {
      map['created_at'] = Variable<DateTime>(createdAt.value);
    }
    if (rowid.present) {
      map['rowid'] = Variable<int>(rowid.value);
    }
    return map;
  }

  @override
  String toString() {
    return (StringBuffer('ReviewsCompanion(')
          ..write('id: $id, ')
          ..write('orderId: $orderId, ')
          ..write('reviewerId: $reviewerId, ')
          ..write('revieweeId: $revieweeId, ')
          ..write('rating: $rating, ')
          ..write('comment: $comment, ')
          ..write('createdAt: $createdAt, ')
          ..write('rowid: $rowid')
          ..write(')'))
        .toString();
  }
}

class $ServiceItemsTable extends ServiceItems
    with TableInfo<$ServiceItemsTable, ServiceItem> {
  @override
  final GeneratedDatabase attachedDatabase;
  final String? _alias;
  $ServiceItemsTable(this.attachedDatabase, [this._alias]);
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
  static const VerificationMeta _categoryMeta =
      const VerificationMeta('category');
  @override
  late final GeneratedColumn<String> category = GeneratedColumn<String>(
      'category', aliasedName, false,
      type: DriftSqlType.string,
      requiredDuringInsert: false,
      defaultValue: const Constant('other'));
  static const VerificationMeta _hourlyRateMeta =
      const VerificationMeta('hourlyRate');
  @override
  late final GeneratedColumn<double> hourlyRate = GeneratedColumn<double>(
      'hourly_rate', aliasedName, false,
      type: DriftSqlType.double, requiredDuringInsert: true);
  static const VerificationMeta _estimatedHoursMeta =
      const VerificationMeta('estimatedHours');
  @override
  late final GeneratedColumn<double> estimatedHours = GeneratedColumn<double>(
      'estimated_hours', aliasedName, false,
      type: DriftSqlType.double,
      requiredDuringInsert: false,
      defaultValue: const Constant(1.0));
  static const VerificationMeta _descriptionMeta =
      const VerificationMeta('description');
  @override
  late final GeneratedColumn<String> description = GeneratedColumn<String>(
      'description', aliasedName, true,
      type: DriftSqlType.string, requiredDuringInsert: false);
  static const VerificationMeta _isActiveMeta =
      const VerificationMeta('isActive');
  @override
  late final GeneratedColumn<bool> isActive = GeneratedColumn<bool>(
      'is_active', aliasedName, false,
      type: DriftSqlType.bool,
      requiredDuringInsert: false,
      defaultConstraints:
          GeneratedColumn.constraintIsAlways('CHECK ("is_active" IN (0, 1))'),
      defaultValue: const Constant(true));
  static const VerificationMeta _customFieldsMeta =
      const VerificationMeta('customFields');
  @override
  late final GeneratedColumn<String> customFields = GeneratedColumn<String>(
      'custom_fields', aliasedName, false,
      type: DriftSqlType.string,
      requiredDuringInsert: false,
      defaultValue: const Constant('{}'));
  static const VerificationMeta _createdAtMeta =
      const VerificationMeta('createdAt');
  @override
  late final GeneratedColumn<DateTime> createdAt = GeneratedColumn<DateTime>(
      'created_at', aliasedName, false,
      type: DriftSqlType.dateTime,
      requiredDuringInsert: false,
      defaultValue: currentDateAndTime);
  @override
  List<GeneratedColumn> get $columns => [
        id,
        name,
        category,
        hourlyRate,
        estimatedHours,
        description,
        isActive,
        customFields,
        createdAt
      ];
  @override
  String get aliasedName => _alias ?? actualTableName;
  @override
  String get actualTableName => $name;
  static const String $name = 'service_items';
  @override
  VerificationContext validateIntegrity(Insertable<ServiceItem> instance,
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
    if (data.containsKey('category')) {
      context.handle(_categoryMeta,
          category.isAcceptableOrUnknown(data['category']!, _categoryMeta));
    }
    if (data.containsKey('hourly_rate')) {
      context.handle(
          _hourlyRateMeta,
          hourlyRate.isAcceptableOrUnknown(
              data['hourly_rate']!, _hourlyRateMeta));
    } else if (isInserting) {
      context.missing(_hourlyRateMeta);
    }
    if (data.containsKey('estimated_hours')) {
      context.handle(
          _estimatedHoursMeta,
          estimatedHours.isAcceptableOrUnknown(
              data['estimated_hours']!, _estimatedHoursMeta));
    }
    if (data.containsKey('description')) {
      context.handle(
          _descriptionMeta,
          description.isAcceptableOrUnknown(
              data['description']!, _descriptionMeta));
    }
    if (data.containsKey('is_active')) {
      context.handle(_isActiveMeta,
          isActive.isAcceptableOrUnknown(data['is_active']!, _isActiveMeta));
    }
    if (data.containsKey('custom_fields')) {
      context.handle(
          _customFieldsMeta,
          customFields.isAcceptableOrUnknown(
              data['custom_fields']!, _customFieldsMeta));
    }
    if (data.containsKey('created_at')) {
      context.handle(_createdAtMeta,
          createdAt.isAcceptableOrUnknown(data['created_at']!, _createdAtMeta));
    }
    return context;
  }

  @override
  Set<GeneratedColumn> get $primaryKey => {id};
  @override
  ServiceItem map(Map<String, dynamic> data, {String? tablePrefix}) {
    final effectivePrefix = tablePrefix != null ? '$tablePrefix.' : '';
    return ServiceItem(
      id: attachedDatabase.typeMapping
          .read(DriftSqlType.string, data['${effectivePrefix}id'])!,
      name: attachedDatabase.typeMapping
          .read(DriftSqlType.string, data['${effectivePrefix}name'])!,
      category: attachedDatabase.typeMapping
          .read(DriftSqlType.string, data['${effectivePrefix}category'])!,
      hourlyRate: attachedDatabase.typeMapping
          .read(DriftSqlType.double, data['${effectivePrefix}hourly_rate'])!,
      estimatedHours: attachedDatabase.typeMapping.read(
          DriftSqlType.double, data['${effectivePrefix}estimated_hours'])!,
      description: attachedDatabase.typeMapping
          .read(DriftSqlType.string, data['${effectivePrefix}description']),
      isActive: attachedDatabase.typeMapping
          .read(DriftSqlType.bool, data['${effectivePrefix}is_active'])!,
      customFields: attachedDatabase.typeMapping
          .read(DriftSqlType.string, data['${effectivePrefix}custom_fields'])!,
      createdAt: attachedDatabase.typeMapping
          .read(DriftSqlType.dateTime, data['${effectivePrefix}created_at'])!,
    );
  }

  @override
  $ServiceItemsTable createAlias(String alias) {
    return $ServiceItemsTable(attachedDatabase, alias);
  }
}

class ServiceItem extends DataClass implements Insertable<ServiceItem> {
  final String id;
  final String name;
  final String category;
  final double hourlyRate;
  final double estimatedHours;
  final String? description;
  final bool isActive;
  final String customFields;
  final DateTime createdAt;
  const ServiceItem(
      {required this.id,
      required this.name,
      required this.category,
      required this.hourlyRate,
      required this.estimatedHours,
      this.description,
      required this.isActive,
      required this.customFields,
      required this.createdAt});
  @override
  Map<String, Expression> toColumns(bool nullToAbsent) {
    final map = <String, Expression>{};
    map['id'] = Variable<String>(id);
    map['name'] = Variable<String>(name);
    map['category'] = Variable<String>(category);
    map['hourly_rate'] = Variable<double>(hourlyRate);
    map['estimated_hours'] = Variable<double>(estimatedHours);
    if (!nullToAbsent || description != null) {
      map['description'] = Variable<String>(description);
    }
    map['is_active'] = Variable<bool>(isActive);
    map['custom_fields'] = Variable<String>(customFields);
    map['created_at'] = Variable<DateTime>(createdAt);
    return map;
  }

  ServiceItemsCompanion toCompanion(bool nullToAbsent) {
    return ServiceItemsCompanion(
      id: Value(id),
      name: Value(name),
      category: Value(category),
      hourlyRate: Value(hourlyRate),
      estimatedHours: Value(estimatedHours),
      description: description == null && nullToAbsent
          ? const Value.absent()
          : Value(description),
      isActive: Value(isActive),
      customFields: Value(customFields),
      createdAt: Value(createdAt),
    );
  }

  factory ServiceItem.fromJson(Map<String, dynamic> json,
      {ValueSerializer? serializer}) {
    serializer ??= driftRuntimeOptions.defaultSerializer;
    return ServiceItem(
      id: serializer.fromJson<String>(json['id']),
      name: serializer.fromJson<String>(json['name']),
      category: serializer.fromJson<String>(json['category']),
      hourlyRate: serializer.fromJson<double>(json['hourlyRate']),
      estimatedHours: serializer.fromJson<double>(json['estimatedHours']),
      description: serializer.fromJson<String?>(json['description']),
      isActive: serializer.fromJson<bool>(json['isActive']),
      customFields: serializer.fromJson<String>(json['customFields']),
      createdAt: serializer.fromJson<DateTime>(json['createdAt']),
    );
  }
  @override
  Map<String, dynamic> toJson({ValueSerializer? serializer}) {
    serializer ??= driftRuntimeOptions.defaultSerializer;
    return <String, dynamic>{
      'id': serializer.toJson<String>(id),
      'name': serializer.toJson<String>(name),
      'category': serializer.toJson<String>(category),
      'hourlyRate': serializer.toJson<double>(hourlyRate),
      'estimatedHours': serializer.toJson<double>(estimatedHours),
      'description': serializer.toJson<String?>(description),
      'isActive': serializer.toJson<bool>(isActive),
      'customFields': serializer.toJson<String>(customFields),
      'createdAt': serializer.toJson<DateTime>(createdAt),
    };
  }

  ServiceItem copyWith(
          {String? id,
          String? name,
          String? category,
          double? hourlyRate,
          double? estimatedHours,
          Value<String?> description = const Value.absent(),
          bool? isActive,
          String? customFields,
          DateTime? createdAt}) =>
      ServiceItem(
        id: id ?? this.id,
        name: name ?? this.name,
        category: category ?? this.category,
        hourlyRate: hourlyRate ?? this.hourlyRate,
        estimatedHours: estimatedHours ?? this.estimatedHours,
        description: description.present ? description.value : this.description,
        isActive: isActive ?? this.isActive,
        customFields: customFields ?? this.customFields,
        createdAt: createdAt ?? this.createdAt,
      );
  ServiceItem copyWithCompanion(ServiceItemsCompanion data) {
    return ServiceItem(
      id: data.id.present ? data.id.value : this.id,
      name: data.name.present ? data.name.value : this.name,
      category: data.category.present ? data.category.value : this.category,
      hourlyRate:
          data.hourlyRate.present ? data.hourlyRate.value : this.hourlyRate,
      estimatedHours: data.estimatedHours.present
          ? data.estimatedHours.value
          : this.estimatedHours,
      description:
          data.description.present ? data.description.value : this.description,
      isActive: data.isActive.present ? data.isActive.value : this.isActive,
      customFields: data.customFields.present
          ? data.customFields.value
          : this.customFields,
      createdAt: data.createdAt.present ? data.createdAt.value : this.createdAt,
    );
  }

  @override
  String toString() {
    return (StringBuffer('ServiceItem(')
          ..write('id: $id, ')
          ..write('name: $name, ')
          ..write('category: $category, ')
          ..write('hourlyRate: $hourlyRate, ')
          ..write('estimatedHours: $estimatedHours, ')
          ..write('description: $description, ')
          ..write('isActive: $isActive, ')
          ..write('customFields: $customFields, ')
          ..write('createdAt: $createdAt')
          ..write(')'))
        .toString();
  }

  @override
  int get hashCode => Object.hash(id, name, category, hourlyRate,
      estimatedHours, description, isActive, customFields, createdAt);
  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      (other is ServiceItem &&
          other.id == this.id &&
          other.name == this.name &&
          other.category == this.category &&
          other.hourlyRate == this.hourlyRate &&
          other.estimatedHours == this.estimatedHours &&
          other.description == this.description &&
          other.isActive == this.isActive &&
          other.customFields == this.customFields &&
          other.createdAt == this.createdAt);
}

class ServiceItemsCompanion extends UpdateCompanion<ServiceItem> {
  final Value<String> id;
  final Value<String> name;
  final Value<String> category;
  final Value<double> hourlyRate;
  final Value<double> estimatedHours;
  final Value<String?> description;
  final Value<bool> isActive;
  final Value<String> customFields;
  final Value<DateTime> createdAt;
  final Value<int> rowid;
  const ServiceItemsCompanion({
    this.id = const Value.absent(),
    this.name = const Value.absent(),
    this.category = const Value.absent(),
    this.hourlyRate = const Value.absent(),
    this.estimatedHours = const Value.absent(),
    this.description = const Value.absent(),
    this.isActive = const Value.absent(),
    this.customFields = const Value.absent(),
    this.createdAt = const Value.absent(),
    this.rowid = const Value.absent(),
  });
  ServiceItemsCompanion.insert({
    required String id,
    required String name,
    this.category = const Value.absent(),
    required double hourlyRate,
    this.estimatedHours = const Value.absent(),
    this.description = const Value.absent(),
    this.isActive = const Value.absent(),
    this.customFields = const Value.absent(),
    this.createdAt = const Value.absent(),
    this.rowid = const Value.absent(),
  })  : id = Value(id),
        name = Value(name),
        hourlyRate = Value(hourlyRate);
  static Insertable<ServiceItem> custom({
    Expression<String>? id,
    Expression<String>? name,
    Expression<String>? category,
    Expression<double>? hourlyRate,
    Expression<double>? estimatedHours,
    Expression<String>? description,
    Expression<bool>? isActive,
    Expression<String>? customFields,
    Expression<DateTime>? createdAt,
    Expression<int>? rowid,
  }) {
    return RawValuesInsertable({
      if (id != null) 'id': id,
      if (name != null) 'name': name,
      if (category != null) 'category': category,
      if (hourlyRate != null) 'hourly_rate': hourlyRate,
      if (estimatedHours != null) 'estimated_hours': estimatedHours,
      if (description != null) 'description': description,
      if (isActive != null) 'is_active': isActive,
      if (customFields != null) 'custom_fields': customFields,
      if (createdAt != null) 'created_at': createdAt,
      if (rowid != null) 'rowid': rowid,
    });
  }

  ServiceItemsCompanion copyWith(
      {Value<String>? id,
      Value<String>? name,
      Value<String>? category,
      Value<double>? hourlyRate,
      Value<double>? estimatedHours,
      Value<String?>? description,
      Value<bool>? isActive,
      Value<String>? customFields,
      Value<DateTime>? createdAt,
      Value<int>? rowid}) {
    return ServiceItemsCompanion(
      id: id ?? this.id,
      name: name ?? this.name,
      category: category ?? this.category,
      hourlyRate: hourlyRate ?? this.hourlyRate,
      estimatedHours: estimatedHours ?? this.estimatedHours,
      description: description ?? this.description,
      isActive: isActive ?? this.isActive,
      customFields: customFields ?? this.customFields,
      createdAt: createdAt ?? this.createdAt,
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
    if (category.present) {
      map['category'] = Variable<String>(category.value);
    }
    if (hourlyRate.present) {
      map['hourly_rate'] = Variable<double>(hourlyRate.value);
    }
    if (estimatedHours.present) {
      map['estimated_hours'] = Variable<double>(estimatedHours.value);
    }
    if (description.present) {
      map['description'] = Variable<String>(description.value);
    }
    if (isActive.present) {
      map['is_active'] = Variable<bool>(isActive.value);
    }
    if (customFields.present) {
      map['custom_fields'] = Variable<String>(customFields.value);
    }
    if (createdAt.present) {
      map['created_at'] = Variable<DateTime>(createdAt.value);
    }
    if (rowid.present) {
      map['rowid'] = Variable<int>(rowid.value);
    }
    return map;
  }

  @override
  String toString() {
    return (StringBuffer('ServiceItemsCompanion(')
          ..write('id: $id, ')
          ..write('name: $name, ')
          ..write('category: $category, ')
          ..write('hourlyRate: $hourlyRate, ')
          ..write('estimatedHours: $estimatedHours, ')
          ..write('description: $description, ')
          ..write('isActive: $isActive, ')
          ..write('customFields: $customFields, ')
          ..write('createdAt: $createdAt, ')
          ..write('rowid: $rowid')
          ..write(')'))
        .toString();
  }
}

class $ServiceBookingsTable extends ServiceBookings
    with TableInfo<$ServiceBookingsTable, ServiceBooking> {
  @override
  final GeneratedDatabase attachedDatabase;
  final String? _alias;
  $ServiceBookingsTable(this.attachedDatabase, [this._alias]);
  static const VerificationMeta _idMeta = const VerificationMeta('id');
  @override
  late final GeneratedColumn<String> id = GeneratedColumn<String>(
      'id', aliasedName, false,
      type: DriftSqlType.string, requiredDuringInsert: true);
  static const VerificationMeta _serviceItemIdMeta =
      const VerificationMeta('serviceItemId');
  @override
  late final GeneratedColumn<String> serviceItemId = GeneratedColumn<String>(
      'service_item_id', aliasedName, false,
      type: DriftSqlType.string, requiredDuringInsert: true);
  static const VerificationMeta _customerNameMeta =
      const VerificationMeta('customerName');
  @override
  late final GeneratedColumn<String> customerName = GeneratedColumn<String>(
      'customer_name', aliasedName, false,
      type: DriftSqlType.string, requiredDuringInsert: true);
  static const VerificationMeta _customerPhoneMeta =
      const VerificationMeta('customerPhone');
  @override
  late final GeneratedColumn<String> customerPhone = GeneratedColumn<String>(
      'customer_phone', aliasedName, true,
      type: DriftSqlType.string, requiredDuringInsert: false);
  static const VerificationMeta _scheduledAtMeta =
      const VerificationMeta('scheduledAt');
  @override
  late final GeneratedColumn<DateTime> scheduledAt = GeneratedColumn<DateTime>(
      'scheduled_at', aliasedName, true,
      type: DriftSqlType.dateTime, requiredDuringInsert: false);
  static const VerificationMeta _actualHoursMeta =
      const VerificationMeta('actualHours');
  @override
  late final GeneratedColumn<double> actualHours = GeneratedColumn<double>(
      'actual_hours', aliasedName, true,
      type: DriftSqlType.double, requiredDuringInsert: false);
  static const VerificationMeta _totalAmountMeta =
      const VerificationMeta('totalAmount');
  @override
  late final GeneratedColumn<double> totalAmount = GeneratedColumn<double>(
      'total_amount', aliasedName, false,
      type: DriftSqlType.double,
      requiredDuringInsert: false,
      defaultValue: const Constant(0.0));
  static const VerificationMeta _statusMeta = const VerificationMeta('status');
  @override
  late final GeneratedColumn<String> status = GeneratedColumn<String>(
      'status', aliasedName, false,
      type: DriftSqlType.string,
      requiredDuringInsert: false,
      defaultValue: const Constant('pending'));
  static const VerificationMeta _notesMeta = const VerificationMeta('notes');
  @override
  late final GeneratedColumn<String> notes = GeneratedColumn<String>(
      'notes', aliasedName, true,
      type: DriftSqlType.string, requiredDuringInsert: false);
  static const VerificationMeta _customFieldsMeta =
      const VerificationMeta('customFields');
  @override
  late final GeneratedColumn<String> customFields = GeneratedColumn<String>(
      'custom_fields', aliasedName, false,
      type: DriftSqlType.string,
      requiredDuringInsert: false,
      defaultValue: const Constant('{}'));
  static const VerificationMeta _createdAtMeta =
      const VerificationMeta('createdAt');
  @override
  late final GeneratedColumn<DateTime> createdAt = GeneratedColumn<DateTime>(
      'created_at', aliasedName, false,
      type: DriftSqlType.dateTime,
      requiredDuringInsert: false,
      defaultValue: currentDateAndTime);
  @override
  List<GeneratedColumn> get $columns => [
        id,
        serviceItemId,
        customerName,
        customerPhone,
        scheduledAt,
        actualHours,
        totalAmount,
        status,
        notes,
        customFields,
        createdAt
      ];
  @override
  String get aliasedName => _alias ?? actualTableName;
  @override
  String get actualTableName => $name;
  static const String $name = 'service_bookings';
  @override
  VerificationContext validateIntegrity(Insertable<ServiceBooking> instance,
      {bool isInserting = false}) {
    final context = VerificationContext();
    final data = instance.toColumns(true);
    if (data.containsKey('id')) {
      context.handle(_idMeta, id.isAcceptableOrUnknown(data['id']!, _idMeta));
    } else if (isInserting) {
      context.missing(_idMeta);
    }
    if (data.containsKey('service_item_id')) {
      context.handle(
          _serviceItemIdMeta,
          serviceItemId.isAcceptableOrUnknown(
              data['service_item_id']!, _serviceItemIdMeta));
    } else if (isInserting) {
      context.missing(_serviceItemIdMeta);
    }
    if (data.containsKey('customer_name')) {
      context.handle(
          _customerNameMeta,
          customerName.isAcceptableOrUnknown(
              data['customer_name']!, _customerNameMeta));
    } else if (isInserting) {
      context.missing(_customerNameMeta);
    }
    if (data.containsKey('customer_phone')) {
      context.handle(
          _customerPhoneMeta,
          customerPhone.isAcceptableOrUnknown(
              data['customer_phone']!, _customerPhoneMeta));
    }
    if (data.containsKey('scheduled_at')) {
      context.handle(
          _scheduledAtMeta,
          scheduledAt.isAcceptableOrUnknown(
              data['scheduled_at']!, _scheduledAtMeta));
    }
    if (data.containsKey('actual_hours')) {
      context.handle(
          _actualHoursMeta,
          actualHours.isAcceptableOrUnknown(
              data['actual_hours']!, _actualHoursMeta));
    }
    if (data.containsKey('total_amount')) {
      context.handle(
          _totalAmountMeta,
          totalAmount.isAcceptableOrUnknown(
              data['total_amount']!, _totalAmountMeta));
    }
    if (data.containsKey('status')) {
      context.handle(_statusMeta,
          status.isAcceptableOrUnknown(data['status']!, _statusMeta));
    }
    if (data.containsKey('notes')) {
      context.handle(
          _notesMeta, notes.isAcceptableOrUnknown(data['notes']!, _notesMeta));
    }
    if (data.containsKey('custom_fields')) {
      context.handle(
          _customFieldsMeta,
          customFields.isAcceptableOrUnknown(
              data['custom_fields']!, _customFieldsMeta));
    }
    if (data.containsKey('created_at')) {
      context.handle(_createdAtMeta,
          createdAt.isAcceptableOrUnknown(data['created_at']!, _createdAtMeta));
    }
    return context;
  }

  @override
  Set<GeneratedColumn> get $primaryKey => {id};
  @override
  ServiceBooking map(Map<String, dynamic> data, {String? tablePrefix}) {
    final effectivePrefix = tablePrefix != null ? '$tablePrefix.' : '';
    return ServiceBooking(
      id: attachedDatabase.typeMapping
          .read(DriftSqlType.string, data['${effectivePrefix}id'])!,
      serviceItemId: attachedDatabase.typeMapping.read(
          DriftSqlType.string, data['${effectivePrefix}service_item_id'])!,
      customerName: attachedDatabase.typeMapping
          .read(DriftSqlType.string, data['${effectivePrefix}customer_name'])!,
      customerPhone: attachedDatabase.typeMapping
          .read(DriftSqlType.string, data['${effectivePrefix}customer_phone']),
      scheduledAt: attachedDatabase.typeMapping
          .read(DriftSqlType.dateTime, data['${effectivePrefix}scheduled_at']),
      actualHours: attachedDatabase.typeMapping
          .read(DriftSqlType.double, data['${effectivePrefix}actual_hours']),
      totalAmount: attachedDatabase.typeMapping
          .read(DriftSqlType.double, data['${effectivePrefix}total_amount'])!,
      status: attachedDatabase.typeMapping
          .read(DriftSqlType.string, data['${effectivePrefix}status'])!,
      notes: attachedDatabase.typeMapping
          .read(DriftSqlType.string, data['${effectivePrefix}notes']),
      customFields: attachedDatabase.typeMapping
          .read(DriftSqlType.string, data['${effectivePrefix}custom_fields'])!,
      createdAt: attachedDatabase.typeMapping
          .read(DriftSqlType.dateTime, data['${effectivePrefix}created_at'])!,
    );
  }

  @override
  $ServiceBookingsTable createAlias(String alias) {
    return $ServiceBookingsTable(attachedDatabase, alias);
  }
}

class ServiceBooking extends DataClass implements Insertable<ServiceBooking> {
  final String id;
  final String serviceItemId;
  final String customerName;
  final String? customerPhone;
  final DateTime? scheduledAt;
  final double? actualHours;
  final double totalAmount;
  final String status;
  final String? notes;
  final String customFields;
  final DateTime createdAt;
  const ServiceBooking(
      {required this.id,
      required this.serviceItemId,
      required this.customerName,
      this.customerPhone,
      this.scheduledAt,
      this.actualHours,
      required this.totalAmount,
      required this.status,
      this.notes,
      required this.customFields,
      required this.createdAt});
  @override
  Map<String, Expression> toColumns(bool nullToAbsent) {
    final map = <String, Expression>{};
    map['id'] = Variable<String>(id);
    map['service_item_id'] = Variable<String>(serviceItemId);
    map['customer_name'] = Variable<String>(customerName);
    if (!nullToAbsent || customerPhone != null) {
      map['customer_phone'] = Variable<String>(customerPhone);
    }
    if (!nullToAbsent || scheduledAt != null) {
      map['scheduled_at'] = Variable<DateTime>(scheduledAt);
    }
    if (!nullToAbsent || actualHours != null) {
      map['actual_hours'] = Variable<double>(actualHours);
    }
    map['total_amount'] = Variable<double>(totalAmount);
    map['status'] = Variable<String>(status);
    if (!nullToAbsent || notes != null) {
      map['notes'] = Variable<String>(notes);
    }
    map['custom_fields'] = Variable<String>(customFields);
    map['created_at'] = Variable<DateTime>(createdAt);
    return map;
  }

  ServiceBookingsCompanion toCompanion(bool nullToAbsent) {
    return ServiceBookingsCompanion(
      id: Value(id),
      serviceItemId: Value(serviceItemId),
      customerName: Value(customerName),
      customerPhone: customerPhone == null && nullToAbsent
          ? const Value.absent()
          : Value(customerPhone),
      scheduledAt: scheduledAt == null && nullToAbsent
          ? const Value.absent()
          : Value(scheduledAt),
      actualHours: actualHours == null && nullToAbsent
          ? const Value.absent()
          : Value(actualHours),
      totalAmount: Value(totalAmount),
      status: Value(status),
      notes:
          notes == null && nullToAbsent ? const Value.absent() : Value(notes),
      customFields: Value(customFields),
      createdAt: Value(createdAt),
    );
  }

  factory ServiceBooking.fromJson(Map<String, dynamic> json,
      {ValueSerializer? serializer}) {
    serializer ??= driftRuntimeOptions.defaultSerializer;
    return ServiceBooking(
      id: serializer.fromJson<String>(json['id']),
      serviceItemId: serializer.fromJson<String>(json['serviceItemId']),
      customerName: serializer.fromJson<String>(json['customerName']),
      customerPhone: serializer.fromJson<String?>(json['customerPhone']),
      scheduledAt: serializer.fromJson<DateTime?>(json['scheduledAt']),
      actualHours: serializer.fromJson<double?>(json['actualHours']),
      totalAmount: serializer.fromJson<double>(json['totalAmount']),
      status: serializer.fromJson<String>(json['status']),
      notes: serializer.fromJson<String?>(json['notes']),
      customFields: serializer.fromJson<String>(json['customFields']),
      createdAt: serializer.fromJson<DateTime>(json['createdAt']),
    );
  }
  @override
  Map<String, dynamic> toJson({ValueSerializer? serializer}) {
    serializer ??= driftRuntimeOptions.defaultSerializer;
    return <String, dynamic>{
      'id': serializer.toJson<String>(id),
      'serviceItemId': serializer.toJson<String>(serviceItemId),
      'customerName': serializer.toJson<String>(customerName),
      'customerPhone': serializer.toJson<String?>(customerPhone),
      'scheduledAt': serializer.toJson<DateTime?>(scheduledAt),
      'actualHours': serializer.toJson<double?>(actualHours),
      'totalAmount': serializer.toJson<double>(totalAmount),
      'status': serializer.toJson<String>(status),
      'notes': serializer.toJson<String?>(notes),
      'customFields': serializer.toJson<String>(customFields),
      'createdAt': serializer.toJson<DateTime>(createdAt),
    };
  }

  ServiceBooking copyWith(
          {String? id,
          String? serviceItemId,
          String? customerName,
          Value<String?> customerPhone = const Value.absent(),
          Value<DateTime?> scheduledAt = const Value.absent(),
          Value<double?> actualHours = const Value.absent(),
          double? totalAmount,
          String? status,
          Value<String?> notes = const Value.absent(),
          String? customFields,
          DateTime? createdAt}) =>
      ServiceBooking(
        id: id ?? this.id,
        serviceItemId: serviceItemId ?? this.serviceItemId,
        customerName: customerName ?? this.customerName,
        customerPhone:
            customerPhone.present ? customerPhone.value : this.customerPhone,
        scheduledAt: scheduledAt.present ? scheduledAt.value : this.scheduledAt,
        actualHours: actualHours.present ? actualHours.value : this.actualHours,
        totalAmount: totalAmount ?? this.totalAmount,
        status: status ?? this.status,
        notes: notes.present ? notes.value : this.notes,
        customFields: customFields ?? this.customFields,
        createdAt: createdAt ?? this.createdAt,
      );
  ServiceBooking copyWithCompanion(ServiceBookingsCompanion data) {
    return ServiceBooking(
      id: data.id.present ? data.id.value : this.id,
      serviceItemId: data.serviceItemId.present
          ? data.serviceItemId.value
          : this.serviceItemId,
      customerName: data.customerName.present
          ? data.customerName.value
          : this.customerName,
      customerPhone: data.customerPhone.present
          ? data.customerPhone.value
          : this.customerPhone,
      scheduledAt:
          data.scheduledAt.present ? data.scheduledAt.value : this.scheduledAt,
      actualHours:
          data.actualHours.present ? data.actualHours.value : this.actualHours,
      totalAmount:
          data.totalAmount.present ? data.totalAmount.value : this.totalAmount,
      status: data.status.present ? data.status.value : this.status,
      notes: data.notes.present ? data.notes.value : this.notes,
      customFields: data.customFields.present
          ? data.customFields.value
          : this.customFields,
      createdAt: data.createdAt.present ? data.createdAt.value : this.createdAt,
    );
  }

  @override
  String toString() {
    return (StringBuffer('ServiceBooking(')
          ..write('id: $id, ')
          ..write('serviceItemId: $serviceItemId, ')
          ..write('customerName: $customerName, ')
          ..write('customerPhone: $customerPhone, ')
          ..write('scheduledAt: $scheduledAt, ')
          ..write('actualHours: $actualHours, ')
          ..write('totalAmount: $totalAmount, ')
          ..write('status: $status, ')
          ..write('notes: $notes, ')
          ..write('customFields: $customFields, ')
          ..write('createdAt: $createdAt')
          ..write(')'))
        .toString();
  }

  @override
  int get hashCode => Object.hash(
      id,
      serviceItemId,
      customerName,
      customerPhone,
      scheduledAt,
      actualHours,
      totalAmount,
      status,
      notes,
      customFields,
      createdAt);
  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      (other is ServiceBooking &&
          other.id == this.id &&
          other.serviceItemId == this.serviceItemId &&
          other.customerName == this.customerName &&
          other.customerPhone == this.customerPhone &&
          other.scheduledAt == this.scheduledAt &&
          other.actualHours == this.actualHours &&
          other.totalAmount == this.totalAmount &&
          other.status == this.status &&
          other.notes == this.notes &&
          other.customFields == this.customFields &&
          other.createdAt == this.createdAt);
}

class ServiceBookingsCompanion extends UpdateCompanion<ServiceBooking> {
  final Value<String> id;
  final Value<String> serviceItemId;
  final Value<String> customerName;
  final Value<String?> customerPhone;
  final Value<DateTime?> scheduledAt;
  final Value<double?> actualHours;
  final Value<double> totalAmount;
  final Value<String> status;
  final Value<String?> notes;
  final Value<String> customFields;
  final Value<DateTime> createdAt;
  final Value<int> rowid;
  const ServiceBookingsCompanion({
    this.id = const Value.absent(),
    this.serviceItemId = const Value.absent(),
    this.customerName = const Value.absent(),
    this.customerPhone = const Value.absent(),
    this.scheduledAt = const Value.absent(),
    this.actualHours = const Value.absent(),
    this.totalAmount = const Value.absent(),
    this.status = const Value.absent(),
    this.notes = const Value.absent(),
    this.customFields = const Value.absent(),
    this.createdAt = const Value.absent(),
    this.rowid = const Value.absent(),
  });
  ServiceBookingsCompanion.insert({
    required String id,
    required String serviceItemId,
    required String customerName,
    this.customerPhone = const Value.absent(),
    this.scheduledAt = const Value.absent(),
    this.actualHours = const Value.absent(),
    this.totalAmount = const Value.absent(),
    this.status = const Value.absent(),
    this.notes = const Value.absent(),
    this.customFields = const Value.absent(),
    this.createdAt = const Value.absent(),
    this.rowid = const Value.absent(),
  })  : id = Value(id),
        serviceItemId = Value(serviceItemId),
        customerName = Value(customerName);
  static Insertable<ServiceBooking> custom({
    Expression<String>? id,
    Expression<String>? serviceItemId,
    Expression<String>? customerName,
    Expression<String>? customerPhone,
    Expression<DateTime>? scheduledAt,
    Expression<double>? actualHours,
    Expression<double>? totalAmount,
    Expression<String>? status,
    Expression<String>? notes,
    Expression<String>? customFields,
    Expression<DateTime>? createdAt,
    Expression<int>? rowid,
  }) {
    return RawValuesInsertable({
      if (id != null) 'id': id,
      if (serviceItemId != null) 'service_item_id': serviceItemId,
      if (customerName != null) 'customer_name': customerName,
      if (customerPhone != null) 'customer_phone': customerPhone,
      if (scheduledAt != null) 'scheduled_at': scheduledAt,
      if (actualHours != null) 'actual_hours': actualHours,
      if (totalAmount != null) 'total_amount': totalAmount,
      if (status != null) 'status': status,
      if (notes != null) 'notes': notes,
      if (customFields != null) 'custom_fields': customFields,
      if (createdAt != null) 'created_at': createdAt,
      if (rowid != null) 'rowid': rowid,
    });
  }

  ServiceBookingsCompanion copyWith(
      {Value<String>? id,
      Value<String>? serviceItemId,
      Value<String>? customerName,
      Value<String?>? customerPhone,
      Value<DateTime?>? scheduledAt,
      Value<double?>? actualHours,
      Value<double>? totalAmount,
      Value<String>? status,
      Value<String?>? notes,
      Value<String>? customFields,
      Value<DateTime>? createdAt,
      Value<int>? rowid}) {
    return ServiceBookingsCompanion(
      id: id ?? this.id,
      serviceItemId: serviceItemId ?? this.serviceItemId,
      customerName: customerName ?? this.customerName,
      customerPhone: customerPhone ?? this.customerPhone,
      scheduledAt: scheduledAt ?? this.scheduledAt,
      actualHours: actualHours ?? this.actualHours,
      totalAmount: totalAmount ?? this.totalAmount,
      status: status ?? this.status,
      notes: notes ?? this.notes,
      customFields: customFields ?? this.customFields,
      createdAt: createdAt ?? this.createdAt,
      rowid: rowid ?? this.rowid,
    );
  }

  @override
  Map<String, Expression> toColumns(bool nullToAbsent) {
    final map = <String, Expression>{};
    if (id.present) {
      map['id'] = Variable<String>(id.value);
    }
    if (serviceItemId.present) {
      map['service_item_id'] = Variable<String>(serviceItemId.value);
    }
    if (customerName.present) {
      map['customer_name'] = Variable<String>(customerName.value);
    }
    if (customerPhone.present) {
      map['customer_phone'] = Variable<String>(customerPhone.value);
    }
    if (scheduledAt.present) {
      map['scheduled_at'] = Variable<DateTime>(scheduledAt.value);
    }
    if (actualHours.present) {
      map['actual_hours'] = Variable<double>(actualHours.value);
    }
    if (totalAmount.present) {
      map['total_amount'] = Variable<double>(totalAmount.value);
    }
    if (status.present) {
      map['status'] = Variable<String>(status.value);
    }
    if (notes.present) {
      map['notes'] = Variable<String>(notes.value);
    }
    if (customFields.present) {
      map['custom_fields'] = Variable<String>(customFields.value);
    }
    if (createdAt.present) {
      map['created_at'] = Variable<DateTime>(createdAt.value);
    }
    if (rowid.present) {
      map['rowid'] = Variable<int>(rowid.value);
    }
    return map;
  }

  @override
  String toString() {
    return (StringBuffer('ServiceBookingsCompanion(')
          ..write('id: $id, ')
          ..write('serviceItemId: $serviceItemId, ')
          ..write('customerName: $customerName, ')
          ..write('customerPhone: $customerPhone, ')
          ..write('scheduledAt: $scheduledAt, ')
          ..write('actualHours: $actualHours, ')
          ..write('totalAmount: $totalAmount, ')
          ..write('status: $status, ')
          ..write('notes: $notes, ')
          ..write('customFields: $customFields, ')
          ..write('createdAt: $createdAt, ')
          ..write('rowid: $rowid')
          ..write(')'))
        .toString();
  }
}

class $OutboxMutationsTable extends OutboxMutations
    with TableInfo<$OutboxMutationsTable, OutboxMutation> {
  @override
  final GeneratedDatabase attachedDatabase;
  final String? _alias;
  $OutboxMutationsTable(this.attachedDatabase, [this._alias]);
  static const VerificationMeta _idMeta = const VerificationMeta('id');
  @override
  late final GeneratedColumn<String> id = GeneratedColumn<String>(
      'id', aliasedName, false,
      type: DriftSqlType.string, requiredDuringInsert: true);
  static const VerificationMeta _targetTableMeta =
      const VerificationMeta('targetTable');
  @override
  late final GeneratedColumn<String> targetTable = GeneratedColumn<String>(
      'target_table', aliasedName, false,
      type: DriftSqlType.string, requiredDuringInsert: true);
  static const VerificationMeta _operationMeta =
      const VerificationMeta('operation');
  @override
  late final GeneratedColumn<String> operation = GeneratedColumn<String>(
      'operation', aliasedName, false,
      type: DriftSqlType.string, requiredDuringInsert: true);
  static const VerificationMeta _payloadMeta =
      const VerificationMeta('payload');
  @override
  late final GeneratedColumn<String> payload = GeneratedColumn<String>(
      'payload', aliasedName, false,
      type: DriftSqlType.string, requiredDuringInsert: true);
  static const VerificationMeta _createdAtMeta =
      const VerificationMeta('createdAt');
  @override
  late final GeneratedColumn<DateTime> createdAt = GeneratedColumn<DateTime>(
      'created_at', aliasedName, false,
      type: DriftSqlType.dateTime,
      requiredDuringInsert: false,
      defaultValue: currentDateAndTime);
  static const VerificationMeta _statusMeta = const VerificationMeta('status');
  @override
  late final GeneratedColumn<String> status = GeneratedColumn<String>(
      'status', aliasedName, false,
      type: DriftSqlType.string,
      requiredDuringInsert: false,
      defaultValue: const Constant('pending'));
  @override
  List<GeneratedColumn> get $columns =>
      [id, targetTable, operation, payload, createdAt, status];
  @override
  String get aliasedName => _alias ?? actualTableName;
  @override
  String get actualTableName => $name;
  static const String $name = 'outbox_mutations';
  @override
  VerificationContext validateIntegrity(Insertable<OutboxMutation> instance,
      {bool isInserting = false}) {
    final context = VerificationContext();
    final data = instance.toColumns(true);
    if (data.containsKey('id')) {
      context.handle(_idMeta, id.isAcceptableOrUnknown(data['id']!, _idMeta));
    } else if (isInserting) {
      context.missing(_idMeta);
    }
    if (data.containsKey('target_table')) {
      context.handle(
          _targetTableMeta,
          targetTable.isAcceptableOrUnknown(
              data['target_table']!, _targetTableMeta));
    } else if (isInserting) {
      context.missing(_targetTableMeta);
    }
    if (data.containsKey('operation')) {
      context.handle(_operationMeta,
          operation.isAcceptableOrUnknown(data['operation']!, _operationMeta));
    } else if (isInserting) {
      context.missing(_operationMeta);
    }
    if (data.containsKey('payload')) {
      context.handle(_payloadMeta,
          payload.isAcceptableOrUnknown(data['payload']!, _payloadMeta));
    } else if (isInserting) {
      context.missing(_payloadMeta);
    }
    if (data.containsKey('created_at')) {
      context.handle(_createdAtMeta,
          createdAt.isAcceptableOrUnknown(data['created_at']!, _createdAtMeta));
    }
    if (data.containsKey('status')) {
      context.handle(_statusMeta,
          status.isAcceptableOrUnknown(data['status']!, _statusMeta));
    }
    return context;
  }

  @override
  Set<GeneratedColumn> get $primaryKey => {id};
  @override
  OutboxMutation map(Map<String, dynamic> data, {String? tablePrefix}) {
    final effectivePrefix = tablePrefix != null ? '$tablePrefix.' : '';
    return OutboxMutation(
      id: attachedDatabase.typeMapping
          .read(DriftSqlType.string, data['${effectivePrefix}id'])!,
      targetTable: attachedDatabase.typeMapping
          .read(DriftSqlType.string, data['${effectivePrefix}target_table'])!,
      operation: attachedDatabase.typeMapping
          .read(DriftSqlType.string, data['${effectivePrefix}operation'])!,
      payload: attachedDatabase.typeMapping
          .read(DriftSqlType.string, data['${effectivePrefix}payload'])!,
      createdAt: attachedDatabase.typeMapping
          .read(DriftSqlType.dateTime, data['${effectivePrefix}created_at'])!,
      status: attachedDatabase.typeMapping
          .read(DriftSqlType.string, data['${effectivePrefix}status'])!,
    );
  }

  @override
  $OutboxMutationsTable createAlias(String alias) {
    return $OutboxMutationsTable(attachedDatabase, alias);
  }
}

class OutboxMutation extends DataClass implements Insertable<OutboxMutation> {
  final String id;
  final String targetTable;
  final String operation;
  final String payload;
  final DateTime createdAt;
  final String status;
  const OutboxMutation(
      {required this.id,
      required this.targetTable,
      required this.operation,
      required this.payload,
      required this.createdAt,
      required this.status});
  @override
  Map<String, Expression> toColumns(bool nullToAbsent) {
    final map = <String, Expression>{};
    map['id'] = Variable<String>(id);
    map['target_table'] = Variable<String>(targetTable);
    map['operation'] = Variable<String>(operation);
    map['payload'] = Variable<String>(payload);
    map['created_at'] = Variable<DateTime>(createdAt);
    map['status'] = Variable<String>(status);
    return map;
  }

  OutboxMutationsCompanion toCompanion(bool nullToAbsent) {
    return OutboxMutationsCompanion(
      id: Value(id),
      targetTable: Value(targetTable),
      operation: Value(operation),
      payload: Value(payload),
      createdAt: Value(createdAt),
      status: Value(status),
    );
  }

  factory OutboxMutation.fromJson(Map<String, dynamic> json,
      {ValueSerializer? serializer}) {
    serializer ??= driftRuntimeOptions.defaultSerializer;
    return OutboxMutation(
      id: serializer.fromJson<String>(json['id']),
      targetTable: serializer.fromJson<String>(json['targetTable']),
      operation: serializer.fromJson<String>(json['operation']),
      payload: serializer.fromJson<String>(json['payload']),
      createdAt: serializer.fromJson<DateTime>(json['createdAt']),
      status: serializer.fromJson<String>(json['status']),
    );
  }
  @override
  Map<String, dynamic> toJson({ValueSerializer? serializer}) {
    serializer ??= driftRuntimeOptions.defaultSerializer;
    return <String, dynamic>{
      'id': serializer.toJson<String>(id),
      'targetTable': serializer.toJson<String>(targetTable),
      'operation': serializer.toJson<String>(operation),
      'payload': serializer.toJson<String>(payload),
      'createdAt': serializer.toJson<DateTime>(createdAt),
      'status': serializer.toJson<String>(status),
    };
  }

  OutboxMutation copyWith(
          {String? id,
          String? targetTable,
          String? operation,
          String? payload,
          DateTime? createdAt,
          String? status}) =>
      OutboxMutation(
        id: id ?? this.id,
        targetTable: targetTable ?? this.targetTable,
        operation: operation ?? this.operation,
        payload: payload ?? this.payload,
        createdAt: createdAt ?? this.createdAt,
        status: status ?? this.status,
      );
  OutboxMutation copyWithCompanion(OutboxMutationsCompanion data) {
    return OutboxMutation(
      id: data.id.present ? data.id.value : this.id,
      targetTable:
          data.targetTable.present ? data.targetTable.value : this.targetTable,
      operation: data.operation.present ? data.operation.value : this.operation,
      payload: data.payload.present ? data.payload.value : this.payload,
      createdAt: data.createdAt.present ? data.createdAt.value : this.createdAt,
      status: data.status.present ? data.status.value : this.status,
    );
  }

  @override
  String toString() {
    return (StringBuffer('OutboxMutation(')
          ..write('id: $id, ')
          ..write('targetTable: $targetTable, ')
          ..write('operation: $operation, ')
          ..write('payload: $payload, ')
          ..write('createdAt: $createdAt, ')
          ..write('status: $status')
          ..write(')'))
        .toString();
  }

  @override
  int get hashCode =>
      Object.hash(id, targetTable, operation, payload, createdAt, status);
  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      (other is OutboxMutation &&
          other.id == this.id &&
          other.targetTable == this.targetTable &&
          other.operation == this.operation &&
          other.payload == this.payload &&
          other.createdAt == this.createdAt &&
          other.status == this.status);
}

class OutboxMutationsCompanion extends UpdateCompanion<OutboxMutation> {
  final Value<String> id;
  final Value<String> targetTable;
  final Value<String> operation;
  final Value<String> payload;
  final Value<DateTime> createdAt;
  final Value<String> status;
  final Value<int> rowid;
  const OutboxMutationsCompanion({
    this.id = const Value.absent(),
    this.targetTable = const Value.absent(),
    this.operation = const Value.absent(),
    this.payload = const Value.absent(),
    this.createdAt = const Value.absent(),
    this.status = const Value.absent(),
    this.rowid = const Value.absent(),
  });
  OutboxMutationsCompanion.insert({
    required String id,
    required String targetTable,
    required String operation,
    required String payload,
    this.createdAt = const Value.absent(),
    this.status = const Value.absent(),
    this.rowid = const Value.absent(),
  })  : id = Value(id),
        targetTable = Value(targetTable),
        operation = Value(operation),
        payload = Value(payload);
  static Insertable<OutboxMutation> custom({
    Expression<String>? id,
    Expression<String>? targetTable,
    Expression<String>? operation,
    Expression<String>? payload,
    Expression<DateTime>? createdAt,
    Expression<String>? status,
    Expression<int>? rowid,
  }) {
    return RawValuesInsertable({
      if (id != null) 'id': id,
      if (targetTable != null) 'target_table': targetTable,
      if (operation != null) 'operation': operation,
      if (payload != null) 'payload': payload,
      if (createdAt != null) 'created_at': createdAt,
      if (status != null) 'status': status,
      if (rowid != null) 'rowid': rowid,
    });
  }

  OutboxMutationsCompanion copyWith(
      {Value<String>? id,
      Value<String>? targetTable,
      Value<String>? operation,
      Value<String>? payload,
      Value<DateTime>? createdAt,
      Value<String>? status,
      Value<int>? rowid}) {
    return OutboxMutationsCompanion(
      id: id ?? this.id,
      targetTable: targetTable ?? this.targetTable,
      operation: operation ?? this.operation,
      payload: payload ?? this.payload,
      createdAt: createdAt ?? this.createdAt,
      status: status ?? this.status,
      rowid: rowid ?? this.rowid,
    );
  }

  @override
  Map<String, Expression> toColumns(bool nullToAbsent) {
    final map = <String, Expression>{};
    if (id.present) {
      map['id'] = Variable<String>(id.value);
    }
    if (targetTable.present) {
      map['target_table'] = Variable<String>(targetTable.value);
    }
    if (operation.present) {
      map['operation'] = Variable<String>(operation.value);
    }
    if (payload.present) {
      map['payload'] = Variable<String>(payload.value);
    }
    if (createdAt.present) {
      map['created_at'] = Variable<DateTime>(createdAt.value);
    }
    if (status.present) {
      map['status'] = Variable<String>(status.value);
    }
    if (rowid.present) {
      map['rowid'] = Variable<int>(rowid.value);
    }
    return map;
  }

  @override
  String toString() {
    return (StringBuffer('OutboxMutationsCompanion(')
          ..write('id: $id, ')
          ..write('targetTable: $targetTable, ')
          ..write('operation: $operation, ')
          ..write('payload: $payload, ')
          ..write('createdAt: $createdAt, ')
          ..write('status: $status, ')
          ..write('rowid: $rowid')
          ..write(')'))
        .toString();
  }
}

class $ProjectsTable extends Projects with TableInfo<$ProjectsTable, Project> {
  @override
  final GeneratedDatabase attachedDatabase;
  final String? _alias;
  $ProjectsTable(this.attachedDatabase, [this._alias]);
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
  static const VerificationMeta _descriptionMeta =
      const VerificationMeta('description');
  @override
  late final GeneratedColumn<String> description = GeneratedColumn<String>(
      'description', aliasedName, true,
      type: DriftSqlType.string, requiredDuringInsert: false);
  static const VerificationMeta _statusMeta = const VerificationMeta('status');
  @override
  late final GeneratedColumn<String> status = GeneratedColumn<String>(
      'status', aliasedName, false,
      type: DriftSqlType.string,
      requiredDuringInsert: false,
      defaultValue: const Constant('active'));
  static const VerificationMeta _createdAtMeta =
      const VerificationMeta('createdAt');
  @override
  late final GeneratedColumn<DateTime> createdAt = GeneratedColumn<DateTime>(
      'created_at', aliasedName, false,
      type: DriftSqlType.dateTime,
      requiredDuringInsert: false,
      defaultValue: currentDateAndTime);
  static const VerificationMeta _customFieldsMeta =
      const VerificationMeta('customFields');
  @override
  late final GeneratedColumn<String> customFields = GeneratedColumn<String>(
      'custom_fields', aliasedName, false,
      type: DriftSqlType.string,
      requiredDuringInsert: false,
      defaultValue: const Constant('{}'));
  @override
  List<GeneratedColumn> get $columns =>
      [id, name, description, status, createdAt, customFields];
  @override
  String get aliasedName => _alias ?? actualTableName;
  @override
  String get actualTableName => $name;
  static const String $name = 'projects';
  @override
  VerificationContext validateIntegrity(Insertable<Project> instance,
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
    if (data.containsKey('description')) {
      context.handle(
          _descriptionMeta,
          description.isAcceptableOrUnknown(
              data['description']!, _descriptionMeta));
    }
    if (data.containsKey('status')) {
      context.handle(_statusMeta,
          status.isAcceptableOrUnknown(data['status']!, _statusMeta));
    }
    if (data.containsKey('created_at')) {
      context.handle(_createdAtMeta,
          createdAt.isAcceptableOrUnknown(data['created_at']!, _createdAtMeta));
    }
    if (data.containsKey('custom_fields')) {
      context.handle(
          _customFieldsMeta,
          customFields.isAcceptableOrUnknown(
              data['custom_fields']!, _customFieldsMeta));
    }
    return context;
  }

  @override
  Set<GeneratedColumn> get $primaryKey => {id};
  @override
  Project map(Map<String, dynamic> data, {String? tablePrefix}) {
    final effectivePrefix = tablePrefix != null ? '$tablePrefix.' : '';
    return Project(
      id: attachedDatabase.typeMapping
          .read(DriftSqlType.string, data['${effectivePrefix}id'])!,
      name: attachedDatabase.typeMapping
          .read(DriftSqlType.string, data['${effectivePrefix}name'])!,
      description: attachedDatabase.typeMapping
          .read(DriftSqlType.string, data['${effectivePrefix}description']),
      status: attachedDatabase.typeMapping
          .read(DriftSqlType.string, data['${effectivePrefix}status'])!,
      createdAt: attachedDatabase.typeMapping
          .read(DriftSqlType.dateTime, data['${effectivePrefix}created_at'])!,
      customFields: attachedDatabase.typeMapping
          .read(DriftSqlType.string, data['${effectivePrefix}custom_fields'])!,
    );
  }

  @override
  $ProjectsTable createAlias(String alias) {
    return $ProjectsTable(attachedDatabase, alias);
  }
}

class Project extends DataClass implements Insertable<Project> {
  final String id;
  final String name;
  final String? description;
  final String status;
  final DateTime createdAt;
  final String customFields;
  const Project(
      {required this.id,
      required this.name,
      this.description,
      required this.status,
      required this.createdAt,
      required this.customFields});
  @override
  Map<String, Expression> toColumns(bool nullToAbsent) {
    final map = <String, Expression>{};
    map['id'] = Variable<String>(id);
    map['name'] = Variable<String>(name);
    if (!nullToAbsent || description != null) {
      map['description'] = Variable<String>(description);
    }
    map['status'] = Variable<String>(status);
    map['created_at'] = Variable<DateTime>(createdAt);
    map['custom_fields'] = Variable<String>(customFields);
    return map;
  }

  ProjectsCompanion toCompanion(bool nullToAbsent) {
    return ProjectsCompanion(
      id: Value(id),
      name: Value(name),
      description: description == null && nullToAbsent
          ? const Value.absent()
          : Value(description),
      status: Value(status),
      createdAt: Value(createdAt),
      customFields: Value(customFields),
    );
  }

  factory Project.fromJson(Map<String, dynamic> json,
      {ValueSerializer? serializer}) {
    serializer ??= driftRuntimeOptions.defaultSerializer;
    return Project(
      id: serializer.fromJson<String>(json['id']),
      name: serializer.fromJson<String>(json['name']),
      description: serializer.fromJson<String?>(json['description']),
      status: serializer.fromJson<String>(json['status']),
      createdAt: serializer.fromJson<DateTime>(json['createdAt']),
      customFields: serializer.fromJson<String>(json['customFields']),
    );
  }
  @override
  Map<String, dynamic> toJson({ValueSerializer? serializer}) {
    serializer ??= driftRuntimeOptions.defaultSerializer;
    return <String, dynamic>{
      'id': serializer.toJson<String>(id),
      'name': serializer.toJson<String>(name),
      'description': serializer.toJson<String?>(description),
      'status': serializer.toJson<String>(status),
      'createdAt': serializer.toJson<DateTime>(createdAt),
      'customFields': serializer.toJson<String>(customFields),
    };
  }

  Project copyWith(
          {String? id,
          String? name,
          Value<String?> description = const Value.absent(),
          String? status,
          DateTime? createdAt,
          String? customFields}) =>
      Project(
        id: id ?? this.id,
        name: name ?? this.name,
        description: description.present ? description.value : this.description,
        status: status ?? this.status,
        createdAt: createdAt ?? this.createdAt,
        customFields: customFields ?? this.customFields,
      );
  Project copyWithCompanion(ProjectsCompanion data) {
    return Project(
      id: data.id.present ? data.id.value : this.id,
      name: data.name.present ? data.name.value : this.name,
      description:
          data.description.present ? data.description.value : this.description,
      status: data.status.present ? data.status.value : this.status,
      createdAt: data.createdAt.present ? data.createdAt.value : this.createdAt,
      customFields: data.customFields.present
          ? data.customFields.value
          : this.customFields,
    );
  }

  @override
  String toString() {
    return (StringBuffer('Project(')
          ..write('id: $id, ')
          ..write('name: $name, ')
          ..write('description: $description, ')
          ..write('status: $status, ')
          ..write('createdAt: $createdAt, ')
          ..write('customFields: $customFields')
          ..write(')'))
        .toString();
  }

  @override
  int get hashCode =>
      Object.hash(id, name, description, status, createdAt, customFields);
  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      (other is Project &&
          other.id == this.id &&
          other.name == this.name &&
          other.description == this.description &&
          other.status == this.status &&
          other.createdAt == this.createdAt &&
          other.customFields == this.customFields);
}

class ProjectsCompanion extends UpdateCompanion<Project> {
  final Value<String> id;
  final Value<String> name;
  final Value<String?> description;
  final Value<String> status;
  final Value<DateTime> createdAt;
  final Value<String> customFields;
  final Value<int> rowid;
  const ProjectsCompanion({
    this.id = const Value.absent(),
    this.name = const Value.absent(),
    this.description = const Value.absent(),
    this.status = const Value.absent(),
    this.createdAt = const Value.absent(),
    this.customFields = const Value.absent(),
    this.rowid = const Value.absent(),
  });
  ProjectsCompanion.insert({
    required String id,
    required String name,
    this.description = const Value.absent(),
    this.status = const Value.absent(),
    this.createdAt = const Value.absent(),
    this.customFields = const Value.absent(),
    this.rowid = const Value.absent(),
  })  : id = Value(id),
        name = Value(name);
  static Insertable<Project> custom({
    Expression<String>? id,
    Expression<String>? name,
    Expression<String>? description,
    Expression<String>? status,
    Expression<DateTime>? createdAt,
    Expression<String>? customFields,
    Expression<int>? rowid,
  }) {
    return RawValuesInsertable({
      if (id != null) 'id': id,
      if (name != null) 'name': name,
      if (description != null) 'description': description,
      if (status != null) 'status': status,
      if (createdAt != null) 'created_at': createdAt,
      if (customFields != null) 'custom_fields': customFields,
      if (rowid != null) 'rowid': rowid,
    });
  }

  ProjectsCompanion copyWith(
      {Value<String>? id,
      Value<String>? name,
      Value<String?>? description,
      Value<String>? status,
      Value<DateTime>? createdAt,
      Value<String>? customFields,
      Value<int>? rowid}) {
    return ProjectsCompanion(
      id: id ?? this.id,
      name: name ?? this.name,
      description: description ?? this.description,
      status: status ?? this.status,
      createdAt: createdAt ?? this.createdAt,
      customFields: customFields ?? this.customFields,
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
    if (description.present) {
      map['description'] = Variable<String>(description.value);
    }
    if (status.present) {
      map['status'] = Variable<String>(status.value);
    }
    if (createdAt.present) {
      map['created_at'] = Variable<DateTime>(createdAt.value);
    }
    if (customFields.present) {
      map['custom_fields'] = Variable<String>(customFields.value);
    }
    if (rowid.present) {
      map['rowid'] = Variable<int>(rowid.value);
    }
    return map;
  }

  @override
  String toString() {
    return (StringBuffer('ProjectsCompanion(')
          ..write('id: $id, ')
          ..write('name: $name, ')
          ..write('description: $description, ')
          ..write('status: $status, ')
          ..write('createdAt: $createdAt, ')
          ..write('customFields: $customFields, ')
          ..write('rowid: $rowid')
          ..write(')'))
        .toString();
  }
}

class $TasksTable extends Tasks with TableInfo<$TasksTable, Task> {
  @override
  final GeneratedDatabase attachedDatabase;
  final String? _alias;
  $TasksTable(this.attachedDatabase, [this._alias]);
  static const VerificationMeta _idMeta = const VerificationMeta('id');
  @override
  late final GeneratedColumn<String> id = GeneratedColumn<String>(
      'id', aliasedName, false,
      type: DriftSqlType.string, requiredDuringInsert: true);
  static const VerificationMeta _projectIdMeta =
      const VerificationMeta('projectId');
  @override
  late final GeneratedColumn<String> projectId = GeneratedColumn<String>(
      'project_id', aliasedName, false,
      type: DriftSqlType.string, requiredDuringInsert: true);
  static const VerificationMeta _titleMeta = const VerificationMeta('title');
  @override
  late final GeneratedColumn<String> title = GeneratedColumn<String>(
      'title', aliasedName, false,
      type: DriftSqlType.string, requiredDuringInsert: true);
  static const VerificationMeta _descriptionMeta =
      const VerificationMeta('description');
  @override
  late final GeneratedColumn<String> description = GeneratedColumn<String>(
      'description', aliasedName, true,
      type: DriftSqlType.string, requiredDuringInsert: false);
  static const VerificationMeta _statusMeta = const VerificationMeta('status');
  @override
  late final GeneratedColumn<String> status = GeneratedColumn<String>(
      'status', aliasedName, false,
      type: DriftSqlType.string,
      requiredDuringInsert: false,
      defaultValue: const Constant('todo'));
  static const VerificationMeta _priorityMeta =
      const VerificationMeta('priority');
  @override
  late final GeneratedColumn<String> priority = GeneratedColumn<String>(
      'priority', aliasedName, false,
      type: DriftSqlType.string,
      requiredDuringInsert: false,
      defaultValue: const Constant('medium'));
  static const VerificationMeta _dueDateMeta =
      const VerificationMeta('dueDate');
  @override
  late final GeneratedColumn<DateTime> dueDate = GeneratedColumn<DateTime>(
      'due_date', aliasedName, true,
      type: DriftSqlType.dateTime, requiredDuringInsert: false);
  static const VerificationMeta _createdAtMeta =
      const VerificationMeta('createdAt');
  @override
  late final GeneratedColumn<DateTime> createdAt = GeneratedColumn<DateTime>(
      'created_at', aliasedName, false,
      type: DriftSqlType.dateTime,
      requiredDuringInsert: false,
      defaultValue: currentDateAndTime);
  static const VerificationMeta _customFieldsMeta =
      const VerificationMeta('customFields');
  @override
  late final GeneratedColumn<String> customFields = GeneratedColumn<String>(
      'custom_fields', aliasedName, false,
      type: DriftSqlType.string,
      requiredDuringInsert: false,
      defaultValue: const Constant('{}'));
  @override
  List<GeneratedColumn> get $columns => [
        id,
        projectId,
        title,
        description,
        status,
        priority,
        dueDate,
        createdAt,
        customFields
      ];
  @override
  String get aliasedName => _alias ?? actualTableName;
  @override
  String get actualTableName => $name;
  static const String $name = 'tasks';
  @override
  VerificationContext validateIntegrity(Insertable<Task> instance,
      {bool isInserting = false}) {
    final context = VerificationContext();
    final data = instance.toColumns(true);
    if (data.containsKey('id')) {
      context.handle(_idMeta, id.isAcceptableOrUnknown(data['id']!, _idMeta));
    } else if (isInserting) {
      context.missing(_idMeta);
    }
    if (data.containsKey('project_id')) {
      context.handle(_projectIdMeta,
          projectId.isAcceptableOrUnknown(data['project_id']!, _projectIdMeta));
    } else if (isInserting) {
      context.missing(_projectIdMeta);
    }
    if (data.containsKey('title')) {
      context.handle(
          _titleMeta, title.isAcceptableOrUnknown(data['title']!, _titleMeta));
    } else if (isInserting) {
      context.missing(_titleMeta);
    }
    if (data.containsKey('description')) {
      context.handle(
          _descriptionMeta,
          description.isAcceptableOrUnknown(
              data['description']!, _descriptionMeta));
    }
    if (data.containsKey('status')) {
      context.handle(_statusMeta,
          status.isAcceptableOrUnknown(data['status']!, _statusMeta));
    }
    if (data.containsKey('priority')) {
      context.handle(_priorityMeta,
          priority.isAcceptableOrUnknown(data['priority']!, _priorityMeta));
    }
    if (data.containsKey('due_date')) {
      context.handle(_dueDateMeta,
          dueDate.isAcceptableOrUnknown(data['due_date']!, _dueDateMeta));
    }
    if (data.containsKey('created_at')) {
      context.handle(_createdAtMeta,
          createdAt.isAcceptableOrUnknown(data['created_at']!, _createdAtMeta));
    }
    if (data.containsKey('custom_fields')) {
      context.handle(
          _customFieldsMeta,
          customFields.isAcceptableOrUnknown(
              data['custom_fields']!, _customFieldsMeta));
    }
    return context;
  }

  @override
  Set<GeneratedColumn> get $primaryKey => {id};
  @override
  Task map(Map<String, dynamic> data, {String? tablePrefix}) {
    final effectivePrefix = tablePrefix != null ? '$tablePrefix.' : '';
    return Task(
      id: attachedDatabase.typeMapping
          .read(DriftSqlType.string, data['${effectivePrefix}id'])!,
      projectId: attachedDatabase.typeMapping
          .read(DriftSqlType.string, data['${effectivePrefix}project_id'])!,
      title: attachedDatabase.typeMapping
          .read(DriftSqlType.string, data['${effectivePrefix}title'])!,
      description: attachedDatabase.typeMapping
          .read(DriftSqlType.string, data['${effectivePrefix}description']),
      status: attachedDatabase.typeMapping
          .read(DriftSqlType.string, data['${effectivePrefix}status'])!,
      priority: attachedDatabase.typeMapping
          .read(DriftSqlType.string, data['${effectivePrefix}priority'])!,
      dueDate: attachedDatabase.typeMapping
          .read(DriftSqlType.dateTime, data['${effectivePrefix}due_date']),
      createdAt: attachedDatabase.typeMapping
          .read(DriftSqlType.dateTime, data['${effectivePrefix}created_at'])!,
      customFields: attachedDatabase.typeMapping
          .read(DriftSqlType.string, data['${effectivePrefix}custom_fields'])!,
    );
  }

  @override
  $TasksTable createAlias(String alias) {
    return $TasksTable(attachedDatabase, alias);
  }
}

class Task extends DataClass implements Insertable<Task> {
  final String id;
  final String projectId;
  final String title;
  final String? description;
  final String status;
  final String priority;
  final DateTime? dueDate;
  final DateTime createdAt;
  final String customFields;
  const Task(
      {required this.id,
      required this.projectId,
      required this.title,
      this.description,
      required this.status,
      required this.priority,
      this.dueDate,
      required this.createdAt,
      required this.customFields});
  @override
  Map<String, Expression> toColumns(bool nullToAbsent) {
    final map = <String, Expression>{};
    map['id'] = Variable<String>(id);
    map['project_id'] = Variable<String>(projectId);
    map['title'] = Variable<String>(title);
    if (!nullToAbsent || description != null) {
      map['description'] = Variable<String>(description);
    }
    map['status'] = Variable<String>(status);
    map['priority'] = Variable<String>(priority);
    if (!nullToAbsent || dueDate != null) {
      map['due_date'] = Variable<DateTime>(dueDate);
    }
    map['created_at'] = Variable<DateTime>(createdAt);
    map['custom_fields'] = Variable<String>(customFields);
    return map;
  }

  TasksCompanion toCompanion(bool nullToAbsent) {
    return TasksCompanion(
      id: Value(id),
      projectId: Value(projectId),
      title: Value(title),
      description: description == null && nullToAbsent
          ? const Value.absent()
          : Value(description),
      status: Value(status),
      priority: Value(priority),
      dueDate: dueDate == null && nullToAbsent
          ? const Value.absent()
          : Value(dueDate),
      createdAt: Value(createdAt),
      customFields: Value(customFields),
    );
  }

  factory Task.fromJson(Map<String, dynamic> json,
      {ValueSerializer? serializer}) {
    serializer ??= driftRuntimeOptions.defaultSerializer;
    return Task(
      id: serializer.fromJson<String>(json['id']),
      projectId: serializer.fromJson<String>(json['projectId']),
      title: serializer.fromJson<String>(json['title']),
      description: serializer.fromJson<String?>(json['description']),
      status: serializer.fromJson<String>(json['status']),
      priority: serializer.fromJson<String>(json['priority']),
      dueDate: serializer.fromJson<DateTime?>(json['dueDate']),
      createdAt: serializer.fromJson<DateTime>(json['createdAt']),
      customFields: serializer.fromJson<String>(json['customFields']),
    );
  }
  @override
  Map<String, dynamic> toJson({ValueSerializer? serializer}) {
    serializer ??= driftRuntimeOptions.defaultSerializer;
    return <String, dynamic>{
      'id': serializer.toJson<String>(id),
      'projectId': serializer.toJson<String>(projectId),
      'title': serializer.toJson<String>(title),
      'description': serializer.toJson<String?>(description),
      'status': serializer.toJson<String>(status),
      'priority': serializer.toJson<String>(priority),
      'dueDate': serializer.toJson<DateTime?>(dueDate),
      'createdAt': serializer.toJson<DateTime>(createdAt),
      'customFields': serializer.toJson<String>(customFields),
    };
  }

  Task copyWith(
          {String? id,
          String? projectId,
          String? title,
          Value<String?> description = const Value.absent(),
          String? status,
          String? priority,
          Value<DateTime?> dueDate = const Value.absent(),
          DateTime? createdAt,
          String? customFields}) =>
      Task(
        id: id ?? this.id,
        projectId: projectId ?? this.projectId,
        title: title ?? this.title,
        description: description.present ? description.value : this.description,
        status: status ?? this.status,
        priority: priority ?? this.priority,
        dueDate: dueDate.present ? dueDate.value : this.dueDate,
        createdAt: createdAt ?? this.createdAt,
        customFields: customFields ?? this.customFields,
      );
  Task copyWithCompanion(TasksCompanion data) {
    return Task(
      id: data.id.present ? data.id.value : this.id,
      projectId: data.projectId.present ? data.projectId.value : this.projectId,
      title: data.title.present ? data.title.value : this.title,
      description:
          data.description.present ? data.description.value : this.description,
      status: data.status.present ? data.status.value : this.status,
      priority: data.priority.present ? data.priority.value : this.priority,
      dueDate: data.dueDate.present ? data.dueDate.value : this.dueDate,
      createdAt: data.createdAt.present ? data.createdAt.value : this.createdAt,
      customFields: data.customFields.present
          ? data.customFields.value
          : this.customFields,
    );
  }

  @override
  String toString() {
    return (StringBuffer('Task(')
          ..write('id: $id, ')
          ..write('projectId: $projectId, ')
          ..write('title: $title, ')
          ..write('description: $description, ')
          ..write('status: $status, ')
          ..write('priority: $priority, ')
          ..write('dueDate: $dueDate, ')
          ..write('createdAt: $createdAt, ')
          ..write('customFields: $customFields')
          ..write(')'))
        .toString();
  }

  @override
  int get hashCode => Object.hash(id, projectId, title, description, status,
      priority, dueDate, createdAt, customFields);
  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      (other is Task &&
          other.id == this.id &&
          other.projectId == this.projectId &&
          other.title == this.title &&
          other.description == this.description &&
          other.status == this.status &&
          other.priority == this.priority &&
          other.dueDate == this.dueDate &&
          other.createdAt == this.createdAt &&
          other.customFields == this.customFields);
}

class TasksCompanion extends UpdateCompanion<Task> {
  final Value<String> id;
  final Value<String> projectId;
  final Value<String> title;
  final Value<String?> description;
  final Value<String> status;
  final Value<String> priority;
  final Value<DateTime?> dueDate;
  final Value<DateTime> createdAt;
  final Value<String> customFields;
  final Value<int> rowid;
  const TasksCompanion({
    this.id = const Value.absent(),
    this.projectId = const Value.absent(),
    this.title = const Value.absent(),
    this.description = const Value.absent(),
    this.status = const Value.absent(),
    this.priority = const Value.absent(),
    this.dueDate = const Value.absent(),
    this.createdAt = const Value.absent(),
    this.customFields = const Value.absent(),
    this.rowid = const Value.absent(),
  });
  TasksCompanion.insert({
    required String id,
    required String projectId,
    required String title,
    this.description = const Value.absent(),
    this.status = const Value.absent(),
    this.priority = const Value.absent(),
    this.dueDate = const Value.absent(),
    this.createdAt = const Value.absent(),
    this.customFields = const Value.absent(),
    this.rowid = const Value.absent(),
  })  : id = Value(id),
        projectId = Value(projectId),
        title = Value(title);
  static Insertable<Task> custom({
    Expression<String>? id,
    Expression<String>? projectId,
    Expression<String>? title,
    Expression<String>? description,
    Expression<String>? status,
    Expression<String>? priority,
    Expression<DateTime>? dueDate,
    Expression<DateTime>? createdAt,
    Expression<String>? customFields,
    Expression<int>? rowid,
  }) {
    return RawValuesInsertable({
      if (id != null) 'id': id,
      if (projectId != null) 'project_id': projectId,
      if (title != null) 'title': title,
      if (description != null) 'description': description,
      if (status != null) 'status': status,
      if (priority != null) 'priority': priority,
      if (dueDate != null) 'due_date': dueDate,
      if (createdAt != null) 'created_at': createdAt,
      if (customFields != null) 'custom_fields': customFields,
      if (rowid != null) 'rowid': rowid,
    });
  }

  TasksCompanion copyWith(
      {Value<String>? id,
      Value<String>? projectId,
      Value<String>? title,
      Value<String?>? description,
      Value<String>? status,
      Value<String>? priority,
      Value<DateTime?>? dueDate,
      Value<DateTime>? createdAt,
      Value<String>? customFields,
      Value<int>? rowid}) {
    return TasksCompanion(
      id: id ?? this.id,
      projectId: projectId ?? this.projectId,
      title: title ?? this.title,
      description: description ?? this.description,
      status: status ?? this.status,
      priority: priority ?? this.priority,
      dueDate: dueDate ?? this.dueDate,
      createdAt: createdAt ?? this.createdAt,
      customFields: customFields ?? this.customFields,
      rowid: rowid ?? this.rowid,
    );
  }

  @override
  Map<String, Expression> toColumns(bool nullToAbsent) {
    final map = <String, Expression>{};
    if (id.present) {
      map['id'] = Variable<String>(id.value);
    }
    if (projectId.present) {
      map['project_id'] = Variable<String>(projectId.value);
    }
    if (title.present) {
      map['title'] = Variable<String>(title.value);
    }
    if (description.present) {
      map['description'] = Variable<String>(description.value);
    }
    if (status.present) {
      map['status'] = Variable<String>(status.value);
    }
    if (priority.present) {
      map['priority'] = Variable<String>(priority.value);
    }
    if (dueDate.present) {
      map['due_date'] = Variable<DateTime>(dueDate.value);
    }
    if (createdAt.present) {
      map['created_at'] = Variable<DateTime>(createdAt.value);
    }
    if (customFields.present) {
      map['custom_fields'] = Variable<String>(customFields.value);
    }
    if (rowid.present) {
      map['rowid'] = Variable<int>(rowid.value);
    }
    return map;
  }

  @override
  String toString() {
    return (StringBuffer('TasksCompanion(')
          ..write('id: $id, ')
          ..write('projectId: $projectId, ')
          ..write('title: $title, ')
          ..write('description: $description, ')
          ..write('status: $status, ')
          ..write('priority: $priority, ')
          ..write('dueDate: $dueDate, ')
          ..write('createdAt: $createdAt, ')
          ..write('customFields: $customFields, ')
          ..write('rowid: $rowid')
          ..write(')'))
        .toString();
  }
}

class $PurchaseOrdersTable extends PurchaseOrders
    with TableInfo<$PurchaseOrdersTable, PurchaseOrder> {
  @override
  final GeneratedDatabase attachedDatabase;
  final String? _alias;
  $PurchaseOrdersTable(this.attachedDatabase, [this._alias]);
  static const VerificationMeta _idMeta = const VerificationMeta('id');
  @override
  late final GeneratedColumn<String> id = GeneratedColumn<String>(
      'id', aliasedName, false,
      type: DriftSqlType.string, requiredDuringInsert: true);
  static const VerificationMeta _orderNumberMeta =
      const VerificationMeta('orderNumber');
  @override
  late final GeneratedColumn<String> orderNumber = GeneratedColumn<String>(
      'order_number', aliasedName, false,
      type: DriftSqlType.string, requiredDuringInsert: true);
  static const VerificationMeta _partnerNameMeta =
      const VerificationMeta('partnerName');
  @override
  late final GeneratedColumn<String> partnerName = GeneratedColumn<String>(
      'partner_name', aliasedName, false,
      type: DriftSqlType.string, requiredDuringInsert: true);
  static const VerificationMeta _orderDateMeta =
      const VerificationMeta('orderDate');
  @override
  late final GeneratedColumn<DateTime> orderDate = GeneratedColumn<DateTime>(
      'order_date', aliasedName, false,
      type: DriftSqlType.dateTime,
      requiredDuringInsert: false,
      defaultValue: currentDateAndTime);
  static const VerificationMeta _totalAmountMeta =
      const VerificationMeta('totalAmount');
  @override
  late final GeneratedColumn<double> totalAmount = GeneratedColumn<double>(
      'total_amount', aliasedName, false,
      type: DriftSqlType.double,
      requiredDuringInsert: false,
      defaultValue: const Constant(0.0));
  static const VerificationMeta _statusMeta = const VerificationMeta('status');
  @override
  late final GeneratedColumn<String> status = GeneratedColumn<String>(
      'status', aliasedName, false,
      type: DriftSqlType.string,
      requiredDuringInsert: false,
      defaultValue: const Constant('draft'));
  static const VerificationMeta _createdAtMeta =
      const VerificationMeta('createdAt');
  @override
  late final GeneratedColumn<DateTime> createdAt = GeneratedColumn<DateTime>(
      'created_at', aliasedName, false,
      type: DriftSqlType.dateTime,
      requiredDuringInsert: false,
      defaultValue: currentDateAndTime);
  static const VerificationMeta _customFieldsMeta =
      const VerificationMeta('customFields');
  @override
  late final GeneratedColumn<String> customFields = GeneratedColumn<String>(
      'custom_fields', aliasedName, false,
      type: DriftSqlType.string,
      requiredDuringInsert: false,
      defaultValue: const Constant('{}'));
  @override
  List<GeneratedColumn> get $columns => [
        id,
        orderNumber,
        partnerName,
        orderDate,
        totalAmount,
        status,
        createdAt,
        customFields
      ];
  @override
  String get aliasedName => _alias ?? actualTableName;
  @override
  String get actualTableName => $name;
  static const String $name = 'purchase_orders';
  @override
  VerificationContext validateIntegrity(Insertable<PurchaseOrder> instance,
      {bool isInserting = false}) {
    final context = VerificationContext();
    final data = instance.toColumns(true);
    if (data.containsKey('id')) {
      context.handle(_idMeta, id.isAcceptableOrUnknown(data['id']!, _idMeta));
    } else if (isInserting) {
      context.missing(_idMeta);
    }
    if (data.containsKey('order_number')) {
      context.handle(
          _orderNumberMeta,
          orderNumber.isAcceptableOrUnknown(
              data['order_number']!, _orderNumberMeta));
    } else if (isInserting) {
      context.missing(_orderNumberMeta);
    }
    if (data.containsKey('partner_name')) {
      context.handle(
          _partnerNameMeta,
          partnerName.isAcceptableOrUnknown(
              data['partner_name']!, _partnerNameMeta));
    } else if (isInserting) {
      context.missing(_partnerNameMeta);
    }
    if (data.containsKey('order_date')) {
      context.handle(_orderDateMeta,
          orderDate.isAcceptableOrUnknown(data['order_date']!, _orderDateMeta));
    }
    if (data.containsKey('total_amount')) {
      context.handle(
          _totalAmountMeta,
          totalAmount.isAcceptableOrUnknown(
              data['total_amount']!, _totalAmountMeta));
    }
    if (data.containsKey('status')) {
      context.handle(_statusMeta,
          status.isAcceptableOrUnknown(data['status']!, _statusMeta));
    }
    if (data.containsKey('created_at')) {
      context.handle(_createdAtMeta,
          createdAt.isAcceptableOrUnknown(data['created_at']!, _createdAtMeta));
    }
    if (data.containsKey('custom_fields')) {
      context.handle(
          _customFieldsMeta,
          customFields.isAcceptableOrUnknown(
              data['custom_fields']!, _customFieldsMeta));
    }
    return context;
  }

  @override
  Set<GeneratedColumn> get $primaryKey => {id};
  @override
  PurchaseOrder map(Map<String, dynamic> data, {String? tablePrefix}) {
    final effectivePrefix = tablePrefix != null ? '$tablePrefix.' : '';
    return PurchaseOrder(
      id: attachedDatabase.typeMapping
          .read(DriftSqlType.string, data['${effectivePrefix}id'])!,
      orderNumber: attachedDatabase.typeMapping
          .read(DriftSqlType.string, data['${effectivePrefix}order_number'])!,
      partnerName: attachedDatabase.typeMapping
          .read(DriftSqlType.string, data['${effectivePrefix}partner_name'])!,
      orderDate: attachedDatabase.typeMapping
          .read(DriftSqlType.dateTime, data['${effectivePrefix}order_date'])!,
      totalAmount: attachedDatabase.typeMapping
          .read(DriftSqlType.double, data['${effectivePrefix}total_amount'])!,
      status: attachedDatabase.typeMapping
          .read(DriftSqlType.string, data['${effectivePrefix}status'])!,
      createdAt: attachedDatabase.typeMapping
          .read(DriftSqlType.dateTime, data['${effectivePrefix}created_at'])!,
      customFields: attachedDatabase.typeMapping
          .read(DriftSqlType.string, data['${effectivePrefix}custom_fields'])!,
    );
  }

  @override
  $PurchaseOrdersTable createAlias(String alias) {
    return $PurchaseOrdersTable(attachedDatabase, alias);
  }
}

class PurchaseOrder extends DataClass implements Insertable<PurchaseOrder> {
  final String id;
  final String orderNumber;
  final String partnerName;
  final DateTime orderDate;
  final double totalAmount;
  final String status;
  final DateTime createdAt;
  final String customFields;
  const PurchaseOrder(
      {required this.id,
      required this.orderNumber,
      required this.partnerName,
      required this.orderDate,
      required this.totalAmount,
      required this.status,
      required this.createdAt,
      required this.customFields});
  @override
  Map<String, Expression> toColumns(bool nullToAbsent) {
    final map = <String, Expression>{};
    map['id'] = Variable<String>(id);
    map['order_number'] = Variable<String>(orderNumber);
    map['partner_name'] = Variable<String>(partnerName);
    map['order_date'] = Variable<DateTime>(orderDate);
    map['total_amount'] = Variable<double>(totalAmount);
    map['status'] = Variable<String>(status);
    map['created_at'] = Variable<DateTime>(createdAt);
    map['custom_fields'] = Variable<String>(customFields);
    return map;
  }

  PurchaseOrdersCompanion toCompanion(bool nullToAbsent) {
    return PurchaseOrdersCompanion(
      id: Value(id),
      orderNumber: Value(orderNumber),
      partnerName: Value(partnerName),
      orderDate: Value(orderDate),
      totalAmount: Value(totalAmount),
      status: Value(status),
      createdAt: Value(createdAt),
      customFields: Value(customFields),
    );
  }

  factory PurchaseOrder.fromJson(Map<String, dynamic> json,
      {ValueSerializer? serializer}) {
    serializer ??= driftRuntimeOptions.defaultSerializer;
    return PurchaseOrder(
      id: serializer.fromJson<String>(json['id']),
      orderNumber: serializer.fromJson<String>(json['orderNumber']),
      partnerName: serializer.fromJson<String>(json['partnerName']),
      orderDate: serializer.fromJson<DateTime>(json['orderDate']),
      totalAmount: serializer.fromJson<double>(json['totalAmount']),
      status: serializer.fromJson<String>(json['status']),
      createdAt: serializer.fromJson<DateTime>(json['createdAt']),
      customFields: serializer.fromJson<String>(json['customFields']),
    );
  }
  @override
  Map<String, dynamic> toJson({ValueSerializer? serializer}) {
    serializer ??= driftRuntimeOptions.defaultSerializer;
    return <String, dynamic>{
      'id': serializer.toJson<String>(id),
      'orderNumber': serializer.toJson<String>(orderNumber),
      'partnerName': serializer.toJson<String>(partnerName),
      'orderDate': serializer.toJson<DateTime>(orderDate),
      'totalAmount': serializer.toJson<double>(totalAmount),
      'status': serializer.toJson<String>(status),
      'createdAt': serializer.toJson<DateTime>(createdAt),
      'customFields': serializer.toJson<String>(customFields),
    };
  }

  PurchaseOrder copyWith(
          {String? id,
          String? orderNumber,
          String? partnerName,
          DateTime? orderDate,
          double? totalAmount,
          String? status,
          DateTime? createdAt,
          String? customFields}) =>
      PurchaseOrder(
        id: id ?? this.id,
        orderNumber: orderNumber ?? this.orderNumber,
        partnerName: partnerName ?? this.partnerName,
        orderDate: orderDate ?? this.orderDate,
        totalAmount: totalAmount ?? this.totalAmount,
        status: status ?? this.status,
        createdAt: createdAt ?? this.createdAt,
        customFields: customFields ?? this.customFields,
      );
  PurchaseOrder copyWithCompanion(PurchaseOrdersCompanion data) {
    return PurchaseOrder(
      id: data.id.present ? data.id.value : this.id,
      orderNumber:
          data.orderNumber.present ? data.orderNumber.value : this.orderNumber,
      partnerName:
          data.partnerName.present ? data.partnerName.value : this.partnerName,
      orderDate: data.orderDate.present ? data.orderDate.value : this.orderDate,
      totalAmount:
          data.totalAmount.present ? data.totalAmount.value : this.totalAmount,
      status: data.status.present ? data.status.value : this.status,
      createdAt: data.createdAt.present ? data.createdAt.value : this.createdAt,
      customFields: data.customFields.present
          ? data.customFields.value
          : this.customFields,
    );
  }

  @override
  String toString() {
    return (StringBuffer('PurchaseOrder(')
          ..write('id: $id, ')
          ..write('orderNumber: $orderNumber, ')
          ..write('partnerName: $partnerName, ')
          ..write('orderDate: $orderDate, ')
          ..write('totalAmount: $totalAmount, ')
          ..write('status: $status, ')
          ..write('createdAt: $createdAt, ')
          ..write('customFields: $customFields')
          ..write(')'))
        .toString();
  }

  @override
  int get hashCode => Object.hash(id, orderNumber, partnerName, orderDate,
      totalAmount, status, createdAt, customFields);
  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      (other is PurchaseOrder &&
          other.id == this.id &&
          other.orderNumber == this.orderNumber &&
          other.partnerName == this.partnerName &&
          other.orderDate == this.orderDate &&
          other.totalAmount == this.totalAmount &&
          other.status == this.status &&
          other.createdAt == this.createdAt &&
          other.customFields == this.customFields);
}

class PurchaseOrdersCompanion extends UpdateCompanion<PurchaseOrder> {
  final Value<String> id;
  final Value<String> orderNumber;
  final Value<String> partnerName;
  final Value<DateTime> orderDate;
  final Value<double> totalAmount;
  final Value<String> status;
  final Value<DateTime> createdAt;
  final Value<String> customFields;
  final Value<int> rowid;
  const PurchaseOrdersCompanion({
    this.id = const Value.absent(),
    this.orderNumber = const Value.absent(),
    this.partnerName = const Value.absent(),
    this.orderDate = const Value.absent(),
    this.totalAmount = const Value.absent(),
    this.status = const Value.absent(),
    this.createdAt = const Value.absent(),
    this.customFields = const Value.absent(),
    this.rowid = const Value.absent(),
  });
  PurchaseOrdersCompanion.insert({
    required String id,
    required String orderNumber,
    required String partnerName,
    this.orderDate = const Value.absent(),
    this.totalAmount = const Value.absent(),
    this.status = const Value.absent(),
    this.createdAt = const Value.absent(),
    this.customFields = const Value.absent(),
    this.rowid = const Value.absent(),
  })  : id = Value(id),
        orderNumber = Value(orderNumber),
        partnerName = Value(partnerName);
  static Insertable<PurchaseOrder> custom({
    Expression<String>? id,
    Expression<String>? orderNumber,
    Expression<String>? partnerName,
    Expression<DateTime>? orderDate,
    Expression<double>? totalAmount,
    Expression<String>? status,
    Expression<DateTime>? createdAt,
    Expression<String>? customFields,
    Expression<int>? rowid,
  }) {
    return RawValuesInsertable({
      if (id != null) 'id': id,
      if (orderNumber != null) 'order_number': orderNumber,
      if (partnerName != null) 'partner_name': partnerName,
      if (orderDate != null) 'order_date': orderDate,
      if (totalAmount != null) 'total_amount': totalAmount,
      if (status != null) 'status': status,
      if (createdAt != null) 'created_at': createdAt,
      if (customFields != null) 'custom_fields': customFields,
      if (rowid != null) 'rowid': rowid,
    });
  }

  PurchaseOrdersCompanion copyWith(
      {Value<String>? id,
      Value<String>? orderNumber,
      Value<String>? partnerName,
      Value<DateTime>? orderDate,
      Value<double>? totalAmount,
      Value<String>? status,
      Value<DateTime>? createdAt,
      Value<String>? customFields,
      Value<int>? rowid}) {
    return PurchaseOrdersCompanion(
      id: id ?? this.id,
      orderNumber: orderNumber ?? this.orderNumber,
      partnerName: partnerName ?? this.partnerName,
      orderDate: orderDate ?? this.orderDate,
      totalAmount: totalAmount ?? this.totalAmount,
      status: status ?? this.status,
      createdAt: createdAt ?? this.createdAt,
      customFields: customFields ?? this.customFields,
      rowid: rowid ?? this.rowid,
    );
  }

  @override
  Map<String, Expression> toColumns(bool nullToAbsent) {
    final map = <String, Expression>{};
    if (id.present) {
      map['id'] = Variable<String>(id.value);
    }
    if (orderNumber.present) {
      map['order_number'] = Variable<String>(orderNumber.value);
    }
    if (partnerName.present) {
      map['partner_name'] = Variable<String>(partnerName.value);
    }
    if (orderDate.present) {
      map['order_date'] = Variable<DateTime>(orderDate.value);
    }
    if (totalAmount.present) {
      map['total_amount'] = Variable<double>(totalAmount.value);
    }
    if (status.present) {
      map['status'] = Variable<String>(status.value);
    }
    if (createdAt.present) {
      map['created_at'] = Variable<DateTime>(createdAt.value);
    }
    if (customFields.present) {
      map['custom_fields'] = Variable<String>(customFields.value);
    }
    if (rowid.present) {
      map['rowid'] = Variable<int>(rowid.value);
    }
    return map;
  }

  @override
  String toString() {
    return (StringBuffer('PurchaseOrdersCompanion(')
          ..write('id: $id, ')
          ..write('orderNumber: $orderNumber, ')
          ..write('partnerName: $partnerName, ')
          ..write('orderDate: $orderDate, ')
          ..write('totalAmount: $totalAmount, ')
          ..write('status: $status, ')
          ..write('createdAt: $createdAt, ')
          ..write('customFields: $customFields, ')
          ..write('rowid: $rowid')
          ..write(')'))
        .toString();
  }
}

class $PurchaseOrderLinesTable extends PurchaseOrderLines
    with TableInfo<$PurchaseOrderLinesTable, PurchaseOrderLine> {
  @override
  final GeneratedDatabase attachedDatabase;
  final String? _alias;
  $PurchaseOrderLinesTable(this.attachedDatabase, [this._alias]);
  static const VerificationMeta _idMeta = const VerificationMeta('id');
  @override
  late final GeneratedColumn<String> id = GeneratedColumn<String>(
      'id', aliasedName, false,
      type: DriftSqlType.string, requiredDuringInsert: true);
  static const VerificationMeta _purchaseOrderIdMeta =
      const VerificationMeta('purchaseOrderId');
  @override
  late final GeneratedColumn<String> purchaseOrderId = GeneratedColumn<String>(
      'purchase_order_id', aliasedName, false,
      type: DriftSqlType.string, requiredDuringInsert: true);
  static const VerificationMeta _productNameMeta =
      const VerificationMeta('productName');
  @override
  late final GeneratedColumn<String> productName = GeneratedColumn<String>(
      'product_name', aliasedName, false,
      type: DriftSqlType.string, requiredDuringInsert: true);
  static const VerificationMeta _quantityMeta =
      const VerificationMeta('quantity');
  @override
  late final GeneratedColumn<double> quantity = GeneratedColumn<double>(
      'quantity', aliasedName, false,
      type: DriftSqlType.double,
      requiredDuringInsert: false,
      defaultValue: const Constant(1.0));
  static const VerificationMeta _unitPriceMeta =
      const VerificationMeta('unitPrice');
  @override
  late final GeneratedColumn<double> unitPrice = GeneratedColumn<double>(
      'unit_price', aliasedName, false,
      type: DriftSqlType.double,
      requiredDuringInsert: false,
      defaultValue: const Constant(0.0));
  static const VerificationMeta _totalPriceMeta =
      const VerificationMeta('totalPrice');
  @override
  late final GeneratedColumn<double> totalPrice = GeneratedColumn<double>(
      'total_price', aliasedName, false,
      type: DriftSqlType.double,
      requiredDuringInsert: false,
      defaultValue: const Constant(0.0));
  static const VerificationMeta _createdAtMeta =
      const VerificationMeta('createdAt');
  @override
  late final GeneratedColumn<DateTime> createdAt = GeneratedColumn<DateTime>(
      'created_at', aliasedName, false,
      type: DriftSqlType.dateTime,
      requiredDuringInsert: false,
      defaultValue: currentDateAndTime);
  @override
  List<GeneratedColumn> get $columns => [
        id,
        purchaseOrderId,
        productName,
        quantity,
        unitPrice,
        totalPrice,
        createdAt
      ];
  @override
  String get aliasedName => _alias ?? actualTableName;
  @override
  String get actualTableName => $name;
  static const String $name = 'purchase_order_lines';
  @override
  VerificationContext validateIntegrity(Insertable<PurchaseOrderLine> instance,
      {bool isInserting = false}) {
    final context = VerificationContext();
    final data = instance.toColumns(true);
    if (data.containsKey('id')) {
      context.handle(_idMeta, id.isAcceptableOrUnknown(data['id']!, _idMeta));
    } else if (isInserting) {
      context.missing(_idMeta);
    }
    if (data.containsKey('purchase_order_id')) {
      context.handle(
          _purchaseOrderIdMeta,
          purchaseOrderId.isAcceptableOrUnknown(
              data['purchase_order_id']!, _purchaseOrderIdMeta));
    } else if (isInserting) {
      context.missing(_purchaseOrderIdMeta);
    }
    if (data.containsKey('product_name')) {
      context.handle(
          _productNameMeta,
          productName.isAcceptableOrUnknown(
              data['product_name']!, _productNameMeta));
    } else if (isInserting) {
      context.missing(_productNameMeta);
    }
    if (data.containsKey('quantity')) {
      context.handle(_quantityMeta,
          quantity.isAcceptableOrUnknown(data['quantity']!, _quantityMeta));
    }
    if (data.containsKey('unit_price')) {
      context.handle(_unitPriceMeta,
          unitPrice.isAcceptableOrUnknown(data['unit_price']!, _unitPriceMeta));
    }
    if (data.containsKey('total_price')) {
      context.handle(
          _totalPriceMeta,
          totalPrice.isAcceptableOrUnknown(
              data['total_price']!, _totalPriceMeta));
    }
    if (data.containsKey('created_at')) {
      context.handle(_createdAtMeta,
          createdAt.isAcceptableOrUnknown(data['created_at']!, _createdAtMeta));
    }
    return context;
  }

  @override
  Set<GeneratedColumn> get $primaryKey => {id};
  @override
  PurchaseOrderLine map(Map<String, dynamic> data, {String? tablePrefix}) {
    final effectivePrefix = tablePrefix != null ? '$tablePrefix.' : '';
    return PurchaseOrderLine(
      id: attachedDatabase.typeMapping
          .read(DriftSqlType.string, data['${effectivePrefix}id'])!,
      purchaseOrderId: attachedDatabase.typeMapping.read(
          DriftSqlType.string, data['${effectivePrefix}purchase_order_id'])!,
      productName: attachedDatabase.typeMapping
          .read(DriftSqlType.string, data['${effectivePrefix}product_name'])!,
      quantity: attachedDatabase.typeMapping
          .read(DriftSqlType.double, data['${effectivePrefix}quantity'])!,
      unitPrice: attachedDatabase.typeMapping
          .read(DriftSqlType.double, data['${effectivePrefix}unit_price'])!,
      totalPrice: attachedDatabase.typeMapping
          .read(DriftSqlType.double, data['${effectivePrefix}total_price'])!,
      createdAt: attachedDatabase.typeMapping
          .read(DriftSqlType.dateTime, data['${effectivePrefix}created_at'])!,
    );
  }

  @override
  $PurchaseOrderLinesTable createAlias(String alias) {
    return $PurchaseOrderLinesTable(attachedDatabase, alias);
  }
}

class PurchaseOrderLine extends DataClass
    implements Insertable<PurchaseOrderLine> {
  final String id;
  final String purchaseOrderId;
  final String productName;
  final double quantity;
  final double unitPrice;
  final double totalPrice;
  final DateTime createdAt;
  const PurchaseOrderLine(
      {required this.id,
      required this.purchaseOrderId,
      required this.productName,
      required this.quantity,
      required this.unitPrice,
      required this.totalPrice,
      required this.createdAt});
  @override
  Map<String, Expression> toColumns(bool nullToAbsent) {
    final map = <String, Expression>{};
    map['id'] = Variable<String>(id);
    map['purchase_order_id'] = Variable<String>(purchaseOrderId);
    map['product_name'] = Variable<String>(productName);
    map['quantity'] = Variable<double>(quantity);
    map['unit_price'] = Variable<double>(unitPrice);
    map['total_price'] = Variable<double>(totalPrice);
    map['created_at'] = Variable<DateTime>(createdAt);
    return map;
  }

  PurchaseOrderLinesCompanion toCompanion(bool nullToAbsent) {
    return PurchaseOrderLinesCompanion(
      id: Value(id),
      purchaseOrderId: Value(purchaseOrderId),
      productName: Value(productName),
      quantity: Value(quantity),
      unitPrice: Value(unitPrice),
      totalPrice: Value(totalPrice),
      createdAt: Value(createdAt),
    );
  }

  factory PurchaseOrderLine.fromJson(Map<String, dynamic> json,
      {ValueSerializer? serializer}) {
    serializer ??= driftRuntimeOptions.defaultSerializer;
    return PurchaseOrderLine(
      id: serializer.fromJson<String>(json['id']),
      purchaseOrderId: serializer.fromJson<String>(json['purchaseOrderId']),
      productName: serializer.fromJson<String>(json['productName']),
      quantity: serializer.fromJson<double>(json['quantity']),
      unitPrice: serializer.fromJson<double>(json['unitPrice']),
      totalPrice: serializer.fromJson<double>(json['totalPrice']),
      createdAt: serializer.fromJson<DateTime>(json['createdAt']),
    );
  }
  @override
  Map<String, dynamic> toJson({ValueSerializer? serializer}) {
    serializer ??= driftRuntimeOptions.defaultSerializer;
    return <String, dynamic>{
      'id': serializer.toJson<String>(id),
      'purchaseOrderId': serializer.toJson<String>(purchaseOrderId),
      'productName': serializer.toJson<String>(productName),
      'quantity': serializer.toJson<double>(quantity),
      'unitPrice': serializer.toJson<double>(unitPrice),
      'totalPrice': serializer.toJson<double>(totalPrice),
      'createdAt': serializer.toJson<DateTime>(createdAt),
    };
  }

  PurchaseOrderLine copyWith(
          {String? id,
          String? purchaseOrderId,
          String? productName,
          double? quantity,
          double? unitPrice,
          double? totalPrice,
          DateTime? createdAt}) =>
      PurchaseOrderLine(
        id: id ?? this.id,
        purchaseOrderId: purchaseOrderId ?? this.purchaseOrderId,
        productName: productName ?? this.productName,
        quantity: quantity ?? this.quantity,
        unitPrice: unitPrice ?? this.unitPrice,
        totalPrice: totalPrice ?? this.totalPrice,
        createdAt: createdAt ?? this.createdAt,
      );
  PurchaseOrderLine copyWithCompanion(PurchaseOrderLinesCompanion data) {
    return PurchaseOrderLine(
      id: data.id.present ? data.id.value : this.id,
      purchaseOrderId: data.purchaseOrderId.present
          ? data.purchaseOrderId.value
          : this.purchaseOrderId,
      productName:
          data.productName.present ? data.productName.value : this.productName,
      quantity: data.quantity.present ? data.quantity.value : this.quantity,
      unitPrice: data.unitPrice.present ? data.unitPrice.value : this.unitPrice,
      totalPrice:
          data.totalPrice.present ? data.totalPrice.value : this.totalPrice,
      createdAt: data.createdAt.present ? data.createdAt.value : this.createdAt,
    );
  }

  @override
  String toString() {
    return (StringBuffer('PurchaseOrderLine(')
          ..write('id: $id, ')
          ..write('purchaseOrderId: $purchaseOrderId, ')
          ..write('productName: $productName, ')
          ..write('quantity: $quantity, ')
          ..write('unitPrice: $unitPrice, ')
          ..write('totalPrice: $totalPrice, ')
          ..write('createdAt: $createdAt')
          ..write(')'))
        .toString();
  }

  @override
  int get hashCode => Object.hash(id, purchaseOrderId, productName, quantity,
      unitPrice, totalPrice, createdAt);
  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      (other is PurchaseOrderLine &&
          other.id == this.id &&
          other.purchaseOrderId == this.purchaseOrderId &&
          other.productName == this.productName &&
          other.quantity == this.quantity &&
          other.unitPrice == this.unitPrice &&
          other.totalPrice == this.totalPrice &&
          other.createdAt == this.createdAt);
}

class PurchaseOrderLinesCompanion extends UpdateCompanion<PurchaseOrderLine> {
  final Value<String> id;
  final Value<String> purchaseOrderId;
  final Value<String> productName;
  final Value<double> quantity;
  final Value<double> unitPrice;
  final Value<double> totalPrice;
  final Value<DateTime> createdAt;
  final Value<int> rowid;
  const PurchaseOrderLinesCompanion({
    this.id = const Value.absent(),
    this.purchaseOrderId = const Value.absent(),
    this.productName = const Value.absent(),
    this.quantity = const Value.absent(),
    this.unitPrice = const Value.absent(),
    this.totalPrice = const Value.absent(),
    this.createdAt = const Value.absent(),
    this.rowid = const Value.absent(),
  });
  PurchaseOrderLinesCompanion.insert({
    required String id,
    required String purchaseOrderId,
    required String productName,
    this.quantity = const Value.absent(),
    this.unitPrice = const Value.absent(),
    this.totalPrice = const Value.absent(),
    this.createdAt = const Value.absent(),
    this.rowid = const Value.absent(),
  })  : id = Value(id),
        purchaseOrderId = Value(purchaseOrderId),
        productName = Value(productName);
  static Insertable<PurchaseOrderLine> custom({
    Expression<String>? id,
    Expression<String>? purchaseOrderId,
    Expression<String>? productName,
    Expression<double>? quantity,
    Expression<double>? unitPrice,
    Expression<double>? totalPrice,
    Expression<DateTime>? createdAt,
    Expression<int>? rowid,
  }) {
    return RawValuesInsertable({
      if (id != null) 'id': id,
      if (purchaseOrderId != null) 'purchase_order_id': purchaseOrderId,
      if (productName != null) 'product_name': productName,
      if (quantity != null) 'quantity': quantity,
      if (unitPrice != null) 'unit_price': unitPrice,
      if (totalPrice != null) 'total_price': totalPrice,
      if (createdAt != null) 'created_at': createdAt,
      if (rowid != null) 'rowid': rowid,
    });
  }

  PurchaseOrderLinesCompanion copyWith(
      {Value<String>? id,
      Value<String>? purchaseOrderId,
      Value<String>? productName,
      Value<double>? quantity,
      Value<double>? unitPrice,
      Value<double>? totalPrice,
      Value<DateTime>? createdAt,
      Value<int>? rowid}) {
    return PurchaseOrderLinesCompanion(
      id: id ?? this.id,
      purchaseOrderId: purchaseOrderId ?? this.purchaseOrderId,
      productName: productName ?? this.productName,
      quantity: quantity ?? this.quantity,
      unitPrice: unitPrice ?? this.unitPrice,
      totalPrice: totalPrice ?? this.totalPrice,
      createdAt: createdAt ?? this.createdAt,
      rowid: rowid ?? this.rowid,
    );
  }

  @override
  Map<String, Expression> toColumns(bool nullToAbsent) {
    final map = <String, Expression>{};
    if (id.present) {
      map['id'] = Variable<String>(id.value);
    }
    if (purchaseOrderId.present) {
      map['purchase_order_id'] = Variable<String>(purchaseOrderId.value);
    }
    if (productName.present) {
      map['product_name'] = Variable<String>(productName.value);
    }
    if (quantity.present) {
      map['quantity'] = Variable<double>(quantity.value);
    }
    if (unitPrice.present) {
      map['unit_price'] = Variable<double>(unitPrice.value);
    }
    if (totalPrice.present) {
      map['total_price'] = Variable<double>(totalPrice.value);
    }
    if (createdAt.present) {
      map['created_at'] = Variable<DateTime>(createdAt.value);
    }
    if (rowid.present) {
      map['rowid'] = Variable<int>(rowid.value);
    }
    return map;
  }

  @override
  String toString() {
    return (StringBuffer('PurchaseOrderLinesCompanion(')
          ..write('id: $id, ')
          ..write('purchaseOrderId: $purchaseOrderId, ')
          ..write('productName: $productName, ')
          ..write('quantity: $quantity, ')
          ..write('unitPrice: $unitPrice, ')
          ..write('totalPrice: $totalPrice, ')
          ..write('createdAt: $createdAt, ')
          ..write('rowid: $rowid')
          ..write(')'))
        .toString();
  }
}

class $AuContactsTable extends AuContacts
    with TableInfo<$AuContactsTable, AuContact> {
  @override
  final GeneratedDatabase attachedDatabase;
  final String? _alias;
  $AuContactsTable(this.attachedDatabase, [this._alias]);
  static const VerificationMeta _idMeta = const VerificationMeta('id');
  @override
  late final GeneratedColumn<String> id = GeneratedColumn<String>(
      'id', aliasedName, false,
      type: DriftSqlType.string, requiredDuringInsert: true);
  static const VerificationMeta _abnMeta = const VerificationMeta('abn');
  @override
  late final GeneratedColumn<String> abn = GeneratedColumn<String>(
      'abn', aliasedName, true,
      type: DriftSqlType.string, requiredDuringInsert: false);
  static const VerificationMeta _abnStatusMeta =
      const VerificationMeta('abnStatus');
  @override
  late final GeneratedColumn<String> abnStatus = GeneratedColumn<String>(
      'abn_status', aliasedName, true,
      type: DriftSqlType.string, requiredDuringInsert: false);
  static const VerificationMeta _isRctiEligibleMeta =
      const VerificationMeta('isRctiEligible');
  @override
  late final GeneratedColumn<bool> isRctiEligible = GeneratedColumn<bool>(
      'is_rcti_eligible', aliasedName, false,
      type: DriftSqlType.bool,
      requiredDuringInsert: false,
      defaultConstraints: GeneratedColumn.constraintIsAlways(
          'CHECK ("is_rcti_eligible" IN (0, 1))'),
      defaultValue: const Constant(false));
  static const VerificationMeta _bpayBillerCodeMeta =
      const VerificationMeta('bpayBillerCode');
  @override
  late final GeneratedColumn<String> bpayBillerCode = GeneratedColumn<String>(
      'bpay_biller_code', aliasedName, true,
      type: DriftSqlType.string, requiredDuringInsert: false);
  static const VerificationMeta _bpayCrnMeta =
      const VerificationMeta('bpayCrn');
  @override
  late final GeneratedColumn<String> bpayCrn = GeneratedColumn<String>(
      'bpay_crn', aliasedName, true,
      type: DriftSqlType.string, requiredDuringInsert: false);
  static const VerificationMeta _bankBsbMeta =
      const VerificationMeta('bankBsb');
  @override
  late final GeneratedColumn<String> bankBsb = GeneratedColumn<String>(
      'bank_bsb', aliasedName, true,
      type: DriftSqlType.string, requiredDuringInsert: false);
  static const VerificationMeta _bankAccountNumberMeta =
      const VerificationMeta('bankAccountNumber');
  @override
  late final GeneratedColumn<String> bankAccountNumber =
      GeneratedColumn<String>('bank_account_number', aliasedName, true,
          type: DriftSqlType.string, requiredDuringInsert: false);
  @override
  List<GeneratedColumn> get $columns => [
        id,
        abn,
        abnStatus,
        isRctiEligible,
        bpayBillerCode,
        bpayCrn,
        bankBsb,
        bankAccountNumber
      ];
  @override
  String get aliasedName => _alias ?? actualTableName;
  @override
  String get actualTableName => $name;
  static const String $name = 'au_contacts';
  @override
  VerificationContext validateIntegrity(Insertable<AuContact> instance,
      {bool isInserting = false}) {
    final context = VerificationContext();
    final data = instance.toColumns(true);
    if (data.containsKey('id')) {
      context.handle(_idMeta, id.isAcceptableOrUnknown(data['id']!, _idMeta));
    } else if (isInserting) {
      context.missing(_idMeta);
    }
    if (data.containsKey('abn')) {
      context.handle(
          _abnMeta, abn.isAcceptableOrUnknown(data['abn']!, _abnMeta));
    }
    if (data.containsKey('abn_status')) {
      context.handle(_abnStatusMeta,
          abnStatus.isAcceptableOrUnknown(data['abn_status']!, _abnStatusMeta));
    }
    if (data.containsKey('is_rcti_eligible')) {
      context.handle(
          _isRctiEligibleMeta,
          isRctiEligible.isAcceptableOrUnknown(
              data['is_rcti_eligible']!, _isRctiEligibleMeta));
    }
    if (data.containsKey('bpay_biller_code')) {
      context.handle(
          _bpayBillerCodeMeta,
          bpayBillerCode.isAcceptableOrUnknown(
              data['bpay_biller_code']!, _bpayBillerCodeMeta));
    }
    if (data.containsKey('bpay_crn')) {
      context.handle(_bpayCrnMeta,
          bpayCrn.isAcceptableOrUnknown(data['bpay_crn']!, _bpayCrnMeta));
    }
    if (data.containsKey('bank_bsb')) {
      context.handle(_bankBsbMeta,
          bankBsb.isAcceptableOrUnknown(data['bank_bsb']!, _bankBsbMeta));
    }
    if (data.containsKey('bank_account_number')) {
      context.handle(
          _bankAccountNumberMeta,
          bankAccountNumber.isAcceptableOrUnknown(
              data['bank_account_number']!, _bankAccountNumberMeta));
    }
    return context;
  }

  @override
  Set<GeneratedColumn> get $primaryKey => {id};
  @override
  AuContact map(Map<String, dynamic> data, {String? tablePrefix}) {
    final effectivePrefix = tablePrefix != null ? '$tablePrefix.' : '';
    return AuContact(
      id: attachedDatabase.typeMapping
          .read(DriftSqlType.string, data['${effectivePrefix}id'])!,
      abn: attachedDatabase.typeMapping
          .read(DriftSqlType.string, data['${effectivePrefix}abn']),
      abnStatus: attachedDatabase.typeMapping
          .read(DriftSqlType.string, data['${effectivePrefix}abn_status']),
      isRctiEligible: attachedDatabase.typeMapping
          .read(DriftSqlType.bool, data['${effectivePrefix}is_rcti_eligible'])!,
      bpayBillerCode: attachedDatabase.typeMapping.read(
          DriftSqlType.string, data['${effectivePrefix}bpay_biller_code']),
      bpayCrn: attachedDatabase.typeMapping
          .read(DriftSqlType.string, data['${effectivePrefix}bpay_crn']),
      bankBsb: attachedDatabase.typeMapping
          .read(DriftSqlType.string, data['${effectivePrefix}bank_bsb']),
      bankAccountNumber: attachedDatabase.typeMapping.read(
          DriftSqlType.string, data['${effectivePrefix}bank_account_number']),
    );
  }

  @override
  $AuContactsTable createAlias(String alias) {
    return $AuContactsTable(attachedDatabase, alias);
  }
}

class AuContact extends DataClass implements Insertable<AuContact> {
  final String id;
  final String? abn;
  final String? abnStatus;
  final bool isRctiEligible;
  final String? bpayBillerCode;
  final String? bpayCrn;
  final String? bankBsb;
  final String? bankAccountNumber;
  const AuContact(
      {required this.id,
      this.abn,
      this.abnStatus,
      required this.isRctiEligible,
      this.bpayBillerCode,
      this.bpayCrn,
      this.bankBsb,
      this.bankAccountNumber});
  @override
  Map<String, Expression> toColumns(bool nullToAbsent) {
    final map = <String, Expression>{};
    map['id'] = Variable<String>(id);
    if (!nullToAbsent || abn != null) {
      map['abn'] = Variable<String>(abn);
    }
    if (!nullToAbsent || abnStatus != null) {
      map['abn_status'] = Variable<String>(abnStatus);
    }
    map['is_rcti_eligible'] = Variable<bool>(isRctiEligible);
    if (!nullToAbsent || bpayBillerCode != null) {
      map['bpay_biller_code'] = Variable<String>(bpayBillerCode);
    }
    if (!nullToAbsent || bpayCrn != null) {
      map['bpay_crn'] = Variable<String>(bpayCrn);
    }
    if (!nullToAbsent || bankBsb != null) {
      map['bank_bsb'] = Variable<String>(bankBsb);
    }
    if (!nullToAbsent || bankAccountNumber != null) {
      map['bank_account_number'] = Variable<String>(bankAccountNumber);
    }
    return map;
  }

  AuContactsCompanion toCompanion(bool nullToAbsent) {
    return AuContactsCompanion(
      id: Value(id),
      abn: abn == null && nullToAbsent ? const Value.absent() : Value(abn),
      abnStatus: abnStatus == null && nullToAbsent
          ? const Value.absent()
          : Value(abnStatus),
      isRctiEligible: Value(isRctiEligible),
      bpayBillerCode: bpayBillerCode == null && nullToAbsent
          ? const Value.absent()
          : Value(bpayBillerCode),
      bpayCrn: bpayCrn == null && nullToAbsent
          ? const Value.absent()
          : Value(bpayCrn),
      bankBsb: bankBsb == null && nullToAbsent
          ? const Value.absent()
          : Value(bankBsb),
      bankAccountNumber: bankAccountNumber == null && nullToAbsent
          ? const Value.absent()
          : Value(bankAccountNumber),
    );
  }

  factory AuContact.fromJson(Map<String, dynamic> json,
      {ValueSerializer? serializer}) {
    serializer ??= driftRuntimeOptions.defaultSerializer;
    return AuContact(
      id: serializer.fromJson<String>(json['id']),
      abn: serializer.fromJson<String?>(json['abn']),
      abnStatus: serializer.fromJson<String?>(json['abnStatus']),
      isRctiEligible: serializer.fromJson<bool>(json['isRctiEligible']),
      bpayBillerCode: serializer.fromJson<String?>(json['bpayBillerCode']),
      bpayCrn: serializer.fromJson<String?>(json['bpayCrn']),
      bankBsb: serializer.fromJson<String?>(json['bankBsb']),
      bankAccountNumber:
          serializer.fromJson<String?>(json['bankAccountNumber']),
    );
  }
  @override
  Map<String, dynamic> toJson({ValueSerializer? serializer}) {
    serializer ??= driftRuntimeOptions.defaultSerializer;
    return <String, dynamic>{
      'id': serializer.toJson<String>(id),
      'abn': serializer.toJson<String?>(abn),
      'abnStatus': serializer.toJson<String?>(abnStatus),
      'isRctiEligible': serializer.toJson<bool>(isRctiEligible),
      'bpayBillerCode': serializer.toJson<String?>(bpayBillerCode),
      'bpayCrn': serializer.toJson<String?>(bpayCrn),
      'bankBsb': serializer.toJson<String?>(bankBsb),
      'bankAccountNumber': serializer.toJson<String?>(bankAccountNumber),
    };
  }

  AuContact copyWith(
          {String? id,
          Value<String?> abn = const Value.absent(),
          Value<String?> abnStatus = const Value.absent(),
          bool? isRctiEligible,
          Value<String?> bpayBillerCode = const Value.absent(),
          Value<String?> bpayCrn = const Value.absent(),
          Value<String?> bankBsb = const Value.absent(),
          Value<String?> bankAccountNumber = const Value.absent()}) =>
      AuContact(
        id: id ?? this.id,
        abn: abn.present ? abn.value : this.abn,
        abnStatus: abnStatus.present ? abnStatus.value : this.abnStatus,
        isRctiEligible: isRctiEligible ?? this.isRctiEligible,
        bpayBillerCode:
            bpayBillerCode.present ? bpayBillerCode.value : this.bpayBillerCode,
        bpayCrn: bpayCrn.present ? bpayCrn.value : this.bpayCrn,
        bankBsb: bankBsb.present ? bankBsb.value : this.bankBsb,
        bankAccountNumber: bankAccountNumber.present
            ? bankAccountNumber.value
            : this.bankAccountNumber,
      );
  AuContact copyWithCompanion(AuContactsCompanion data) {
    return AuContact(
      id: data.id.present ? data.id.value : this.id,
      abn: data.abn.present ? data.abn.value : this.abn,
      abnStatus: data.abnStatus.present ? data.abnStatus.value : this.abnStatus,
      isRctiEligible: data.isRctiEligible.present
          ? data.isRctiEligible.value
          : this.isRctiEligible,
      bpayBillerCode: data.bpayBillerCode.present
          ? data.bpayBillerCode.value
          : this.bpayBillerCode,
      bpayCrn: data.bpayCrn.present ? data.bpayCrn.value : this.bpayCrn,
      bankBsb: data.bankBsb.present ? data.bankBsb.value : this.bankBsb,
      bankAccountNumber: data.bankAccountNumber.present
          ? data.bankAccountNumber.value
          : this.bankAccountNumber,
    );
  }

  @override
  String toString() {
    return (StringBuffer('AuContact(')
          ..write('id: $id, ')
          ..write('abn: $abn, ')
          ..write('abnStatus: $abnStatus, ')
          ..write('isRctiEligible: $isRctiEligible, ')
          ..write('bpayBillerCode: $bpayBillerCode, ')
          ..write('bpayCrn: $bpayCrn, ')
          ..write('bankBsb: $bankBsb, ')
          ..write('bankAccountNumber: $bankAccountNumber')
          ..write(')'))
        .toString();
  }

  @override
  int get hashCode => Object.hash(id, abn, abnStatus, isRctiEligible,
      bpayBillerCode, bpayCrn, bankBsb, bankAccountNumber);
  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      (other is AuContact &&
          other.id == this.id &&
          other.abn == this.abn &&
          other.abnStatus == this.abnStatus &&
          other.isRctiEligible == this.isRctiEligible &&
          other.bpayBillerCode == this.bpayBillerCode &&
          other.bpayCrn == this.bpayCrn &&
          other.bankBsb == this.bankBsb &&
          other.bankAccountNumber == this.bankAccountNumber);
}

class AuContactsCompanion extends UpdateCompanion<AuContact> {
  final Value<String> id;
  final Value<String?> abn;
  final Value<String?> abnStatus;
  final Value<bool> isRctiEligible;
  final Value<String?> bpayBillerCode;
  final Value<String?> bpayCrn;
  final Value<String?> bankBsb;
  final Value<String?> bankAccountNumber;
  final Value<int> rowid;
  const AuContactsCompanion({
    this.id = const Value.absent(),
    this.abn = const Value.absent(),
    this.abnStatus = const Value.absent(),
    this.isRctiEligible = const Value.absent(),
    this.bpayBillerCode = const Value.absent(),
    this.bpayCrn = const Value.absent(),
    this.bankBsb = const Value.absent(),
    this.bankAccountNumber = const Value.absent(),
    this.rowid = const Value.absent(),
  });
  AuContactsCompanion.insert({
    required String id,
    this.abn = const Value.absent(),
    this.abnStatus = const Value.absent(),
    this.isRctiEligible = const Value.absent(),
    this.bpayBillerCode = const Value.absent(),
    this.bpayCrn = const Value.absent(),
    this.bankBsb = const Value.absent(),
    this.bankAccountNumber = const Value.absent(),
    this.rowid = const Value.absent(),
  }) : id = Value(id);
  static Insertable<AuContact> custom({
    Expression<String>? id,
    Expression<String>? abn,
    Expression<String>? abnStatus,
    Expression<bool>? isRctiEligible,
    Expression<String>? bpayBillerCode,
    Expression<String>? bpayCrn,
    Expression<String>? bankBsb,
    Expression<String>? bankAccountNumber,
    Expression<int>? rowid,
  }) {
    return RawValuesInsertable({
      if (id != null) 'id': id,
      if (abn != null) 'abn': abn,
      if (abnStatus != null) 'abn_status': abnStatus,
      if (isRctiEligible != null) 'is_rcti_eligible': isRctiEligible,
      if (bpayBillerCode != null) 'bpay_biller_code': bpayBillerCode,
      if (bpayCrn != null) 'bpay_crn': bpayCrn,
      if (bankBsb != null) 'bank_bsb': bankBsb,
      if (bankAccountNumber != null) 'bank_account_number': bankAccountNumber,
      if (rowid != null) 'rowid': rowid,
    });
  }

  AuContactsCompanion copyWith(
      {Value<String>? id,
      Value<String?>? abn,
      Value<String?>? abnStatus,
      Value<bool>? isRctiEligible,
      Value<String?>? bpayBillerCode,
      Value<String?>? bpayCrn,
      Value<String?>? bankBsb,
      Value<String?>? bankAccountNumber,
      Value<int>? rowid}) {
    return AuContactsCompanion(
      id: id ?? this.id,
      abn: abn ?? this.abn,
      abnStatus: abnStatus ?? this.abnStatus,
      isRctiEligible: isRctiEligible ?? this.isRctiEligible,
      bpayBillerCode: bpayBillerCode ?? this.bpayBillerCode,
      bpayCrn: bpayCrn ?? this.bpayCrn,
      bankBsb: bankBsb ?? this.bankBsb,
      bankAccountNumber: bankAccountNumber ?? this.bankAccountNumber,
      rowid: rowid ?? this.rowid,
    );
  }

  @override
  Map<String, Expression> toColumns(bool nullToAbsent) {
    final map = <String, Expression>{};
    if (id.present) {
      map['id'] = Variable<String>(id.value);
    }
    if (abn.present) {
      map['abn'] = Variable<String>(abn.value);
    }
    if (abnStatus.present) {
      map['abn_status'] = Variable<String>(abnStatus.value);
    }
    if (isRctiEligible.present) {
      map['is_rcti_eligible'] = Variable<bool>(isRctiEligible.value);
    }
    if (bpayBillerCode.present) {
      map['bpay_biller_code'] = Variable<String>(bpayBillerCode.value);
    }
    if (bpayCrn.present) {
      map['bpay_crn'] = Variable<String>(bpayCrn.value);
    }
    if (bankBsb.present) {
      map['bank_bsb'] = Variable<String>(bankBsb.value);
    }
    if (bankAccountNumber.present) {
      map['bank_account_number'] = Variable<String>(bankAccountNumber.value);
    }
    if (rowid.present) {
      map['rowid'] = Variable<int>(rowid.value);
    }
    return map;
  }

  @override
  String toString() {
    return (StringBuffer('AuContactsCompanion(')
          ..write('id: $id, ')
          ..write('abn: $abn, ')
          ..write('abnStatus: $abnStatus, ')
          ..write('isRctiEligible: $isRctiEligible, ')
          ..write('bpayBillerCode: $bpayBillerCode, ')
          ..write('bpayCrn: $bpayCrn, ')
          ..write('bankBsb: $bankBsb, ')
          ..write('bankAccountNumber: $bankAccountNumber, ')
          ..write('rowid: $rowid')
          ..write(')'))
        .toString();
  }
}

class $AccountsTable extends Accounts with TableInfo<$AccountsTable, Account> {
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
      type: DriftSqlType.string, requiredDuringInsert: true);
  static const VerificationMeta _nameMeta = const VerificationMeta('name');
  @override
  late final GeneratedColumn<String> name = GeneratedColumn<String>(
      'name', aliasedName, false,
      type: DriftSqlType.string, requiredDuringInsert: true);
  static const VerificationMeta _categoryMeta =
      const VerificationMeta('category');
  @override
  late final GeneratedColumn<String> category = GeneratedColumn<String>(
      'category', aliasedName, false,
      type: DriftSqlType.string, requiredDuringInsert: true);
  static const VerificationMeta _gstTaxCodeMeta =
      const VerificationMeta('gstTaxCode');
  @override
  late final GeneratedColumn<String> gstTaxCode = GeneratedColumn<String>(
      'gst_tax_code', aliasedName, false,
      type: DriftSqlType.string,
      requiredDuringInsert: false,
      defaultValue: const Constant('GST'));
  static const VerificationMeta _balanceMeta =
      const VerificationMeta('balance');
  @override
  late final GeneratedColumn<double> balance = GeneratedColumn<double>(
      'balance', aliasedName, false,
      type: DriftSqlType.double,
      requiredDuringInsert: false,
      defaultValue: const Constant(0.0));
  static const VerificationMeta _isActiveMeta =
      const VerificationMeta('isActive');
  @override
  late final GeneratedColumn<bool> isActive = GeneratedColumn<bool>(
      'is_active', aliasedName, false,
      type: DriftSqlType.bool,
      requiredDuringInsert: false,
      defaultConstraints:
          GeneratedColumn.constraintIsAlways('CHECK ("is_active" IN (0, 1))'),
      defaultValue: const Constant(true));
  @override
  List<GeneratedColumn> get $columns =>
      [id, code, name, category, gstTaxCode, balance, isActive];
  @override
  String get aliasedName => _alias ?? actualTableName;
  @override
  String get actualTableName => $name;
  static const String $name = 'accounts';
  @override
  VerificationContext validateIntegrity(Insertable<Account> instance,
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
    if (data.containsKey('category')) {
      context.handle(_categoryMeta,
          category.isAcceptableOrUnknown(data['category']!, _categoryMeta));
    } else if (isInserting) {
      context.missing(_categoryMeta);
    }
    if (data.containsKey('gst_tax_code')) {
      context.handle(
          _gstTaxCodeMeta,
          gstTaxCode.isAcceptableOrUnknown(
              data['gst_tax_code']!, _gstTaxCodeMeta));
    }
    if (data.containsKey('balance')) {
      context.handle(_balanceMeta,
          balance.isAcceptableOrUnknown(data['balance']!, _balanceMeta));
    }
    if (data.containsKey('is_active')) {
      context.handle(_isActiveMeta,
          isActive.isAcceptableOrUnknown(data['is_active']!, _isActiveMeta));
    }
    return context;
  }

  @override
  Set<GeneratedColumn> get $primaryKey => {id};
  @override
  Account map(Map<String, dynamic> data, {String? tablePrefix}) {
    final effectivePrefix = tablePrefix != null ? '$tablePrefix.' : '';
    return Account(
      id: attachedDatabase.typeMapping
          .read(DriftSqlType.string, data['${effectivePrefix}id'])!,
      code: attachedDatabase.typeMapping
          .read(DriftSqlType.string, data['${effectivePrefix}code'])!,
      name: attachedDatabase.typeMapping
          .read(DriftSqlType.string, data['${effectivePrefix}name'])!,
      category: attachedDatabase.typeMapping
          .read(DriftSqlType.string, data['${effectivePrefix}category'])!,
      gstTaxCode: attachedDatabase.typeMapping
          .read(DriftSqlType.string, data['${effectivePrefix}gst_tax_code'])!,
      balance: attachedDatabase.typeMapping
          .read(DriftSqlType.double, data['${effectivePrefix}balance'])!,
      isActive: attachedDatabase.typeMapping
          .read(DriftSqlType.bool, data['${effectivePrefix}is_active'])!,
    );
  }

  @override
  $AccountsTable createAlias(String alias) {
    return $AccountsTable(attachedDatabase, alias);
  }
}

class Account extends DataClass implements Insertable<Account> {
  final String id;
  final String code;
  final String name;
  final String category;
  final String gstTaxCode;
  final double balance;
  final bool isActive;
  const Account(
      {required this.id,
      required this.code,
      required this.name,
      required this.category,
      required this.gstTaxCode,
      required this.balance,
      required this.isActive});
  @override
  Map<String, Expression> toColumns(bool nullToAbsent) {
    final map = <String, Expression>{};
    map['id'] = Variable<String>(id);
    map['code'] = Variable<String>(code);
    map['name'] = Variable<String>(name);
    map['category'] = Variable<String>(category);
    map['gst_tax_code'] = Variable<String>(gstTaxCode);
    map['balance'] = Variable<double>(balance);
    map['is_active'] = Variable<bool>(isActive);
    return map;
  }

  AccountsCompanion toCompanion(bool nullToAbsent) {
    return AccountsCompanion(
      id: Value(id),
      code: Value(code),
      name: Value(name),
      category: Value(category),
      gstTaxCode: Value(gstTaxCode),
      balance: Value(balance),
      isActive: Value(isActive),
    );
  }

  factory Account.fromJson(Map<String, dynamic> json,
      {ValueSerializer? serializer}) {
    serializer ??= driftRuntimeOptions.defaultSerializer;
    return Account(
      id: serializer.fromJson<String>(json['id']),
      code: serializer.fromJson<String>(json['code']),
      name: serializer.fromJson<String>(json['name']),
      category: serializer.fromJson<String>(json['category']),
      gstTaxCode: serializer.fromJson<String>(json['gstTaxCode']),
      balance: serializer.fromJson<double>(json['balance']),
      isActive: serializer.fromJson<bool>(json['isActive']),
    );
  }
  @override
  Map<String, dynamic> toJson({ValueSerializer? serializer}) {
    serializer ??= driftRuntimeOptions.defaultSerializer;
    return <String, dynamic>{
      'id': serializer.toJson<String>(id),
      'code': serializer.toJson<String>(code),
      'name': serializer.toJson<String>(name),
      'category': serializer.toJson<String>(category),
      'gstTaxCode': serializer.toJson<String>(gstTaxCode),
      'balance': serializer.toJson<double>(balance),
      'isActive': serializer.toJson<bool>(isActive),
    };
  }

  Account copyWith(
          {String? id,
          String? code,
          String? name,
          String? category,
          String? gstTaxCode,
          double? balance,
          bool? isActive}) =>
      Account(
        id: id ?? this.id,
        code: code ?? this.code,
        name: name ?? this.name,
        category: category ?? this.category,
        gstTaxCode: gstTaxCode ?? this.gstTaxCode,
        balance: balance ?? this.balance,
        isActive: isActive ?? this.isActive,
      );
  Account copyWithCompanion(AccountsCompanion data) {
    return Account(
      id: data.id.present ? data.id.value : this.id,
      code: data.code.present ? data.code.value : this.code,
      name: data.name.present ? data.name.value : this.name,
      category: data.category.present ? data.category.value : this.category,
      gstTaxCode:
          data.gstTaxCode.present ? data.gstTaxCode.value : this.gstTaxCode,
      balance: data.balance.present ? data.balance.value : this.balance,
      isActive: data.isActive.present ? data.isActive.value : this.isActive,
    );
  }

  @override
  String toString() {
    return (StringBuffer('Account(')
          ..write('id: $id, ')
          ..write('code: $code, ')
          ..write('name: $name, ')
          ..write('category: $category, ')
          ..write('gstTaxCode: $gstTaxCode, ')
          ..write('balance: $balance, ')
          ..write('isActive: $isActive')
          ..write(')'))
        .toString();
  }

  @override
  int get hashCode =>
      Object.hash(id, code, name, category, gstTaxCode, balance, isActive);
  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      (other is Account &&
          other.id == this.id &&
          other.code == this.code &&
          other.name == this.name &&
          other.category == this.category &&
          other.gstTaxCode == this.gstTaxCode &&
          other.balance == this.balance &&
          other.isActive == this.isActive);
}

class AccountsCompanion extends UpdateCompanion<Account> {
  final Value<String> id;
  final Value<String> code;
  final Value<String> name;
  final Value<String> category;
  final Value<String> gstTaxCode;
  final Value<double> balance;
  final Value<bool> isActive;
  final Value<int> rowid;
  const AccountsCompanion({
    this.id = const Value.absent(),
    this.code = const Value.absent(),
    this.name = const Value.absent(),
    this.category = const Value.absent(),
    this.gstTaxCode = const Value.absent(),
    this.balance = const Value.absent(),
    this.isActive = const Value.absent(),
    this.rowid = const Value.absent(),
  });
  AccountsCompanion.insert({
    required String id,
    required String code,
    required String name,
    required String category,
    this.gstTaxCode = const Value.absent(),
    this.balance = const Value.absent(),
    this.isActive = const Value.absent(),
    this.rowid = const Value.absent(),
  })  : id = Value(id),
        code = Value(code),
        name = Value(name),
        category = Value(category);
  static Insertable<Account> custom({
    Expression<String>? id,
    Expression<String>? code,
    Expression<String>? name,
    Expression<String>? category,
    Expression<String>? gstTaxCode,
    Expression<double>? balance,
    Expression<bool>? isActive,
    Expression<int>? rowid,
  }) {
    return RawValuesInsertable({
      if (id != null) 'id': id,
      if (code != null) 'code': code,
      if (name != null) 'name': name,
      if (category != null) 'category': category,
      if (gstTaxCode != null) 'gst_tax_code': gstTaxCode,
      if (balance != null) 'balance': balance,
      if (isActive != null) 'is_active': isActive,
      if (rowid != null) 'rowid': rowid,
    });
  }

  AccountsCompanion copyWith(
      {Value<String>? id,
      Value<String>? code,
      Value<String>? name,
      Value<String>? category,
      Value<String>? gstTaxCode,
      Value<double>? balance,
      Value<bool>? isActive,
      Value<int>? rowid}) {
    return AccountsCompanion(
      id: id ?? this.id,
      code: code ?? this.code,
      name: name ?? this.name,
      category: category ?? this.category,
      gstTaxCode: gstTaxCode ?? this.gstTaxCode,
      balance: balance ?? this.balance,
      isActive: isActive ?? this.isActive,
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
    if (category.present) {
      map['category'] = Variable<String>(category.value);
    }
    if (gstTaxCode.present) {
      map['gst_tax_code'] = Variable<String>(gstTaxCode.value);
    }
    if (balance.present) {
      map['balance'] = Variable<double>(balance.value);
    }
    if (isActive.present) {
      map['is_active'] = Variable<bool>(isActive.value);
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
          ..write('category: $category, ')
          ..write('gstTaxCode: $gstTaxCode, ')
          ..write('balance: $balance, ')
          ..write('isActive: $isActive, ')
          ..write('rowid: $rowid')
          ..write(')'))
        .toString();
  }
}

class $TaxRatesTable extends TaxRates with TableInfo<$TaxRatesTable, TaxRate> {
  @override
  final GeneratedDatabase attachedDatabase;
  final String? _alias;
  $TaxRatesTable(this.attachedDatabase, [this._alias]);
  static const VerificationMeta _codeMeta = const VerificationMeta('code');
  @override
  late final GeneratedColumn<String> code = GeneratedColumn<String>(
      'code', aliasedName, false,
      type: DriftSqlType.string, requiredDuringInsert: true);
  static const VerificationMeta _rateMeta = const VerificationMeta('rate');
  @override
  late final GeneratedColumn<double> rate = GeneratedColumn<double>(
      'rate', aliasedName, false,
      type: DriftSqlType.double, requiredDuringInsert: true);
  static const VerificationMeta _descriptionMeta =
      const VerificationMeta('description');
  @override
  late final GeneratedColumn<String> description = GeneratedColumn<String>(
      'description', aliasedName, false,
      type: DriftSqlType.string, requiredDuringInsert: true);
  @override
  List<GeneratedColumn> get $columns => [code, rate, description];
  @override
  String get aliasedName => _alias ?? actualTableName;
  @override
  String get actualTableName => $name;
  static const String $name = 'tax_rates';
  @override
  VerificationContext validateIntegrity(Insertable<TaxRate> instance,
      {bool isInserting = false}) {
    final context = VerificationContext();
    final data = instance.toColumns(true);
    if (data.containsKey('code')) {
      context.handle(
          _codeMeta, code.isAcceptableOrUnknown(data['code']!, _codeMeta));
    } else if (isInserting) {
      context.missing(_codeMeta);
    }
    if (data.containsKey('rate')) {
      context.handle(
          _rateMeta, rate.isAcceptableOrUnknown(data['rate']!, _rateMeta));
    } else if (isInserting) {
      context.missing(_rateMeta);
    }
    if (data.containsKey('description')) {
      context.handle(
          _descriptionMeta,
          description.isAcceptableOrUnknown(
              data['description']!, _descriptionMeta));
    } else if (isInserting) {
      context.missing(_descriptionMeta);
    }
    return context;
  }

  @override
  Set<GeneratedColumn> get $primaryKey => {code};
  @override
  TaxRate map(Map<String, dynamic> data, {String? tablePrefix}) {
    final effectivePrefix = tablePrefix != null ? '$tablePrefix.' : '';
    return TaxRate(
      code: attachedDatabase.typeMapping
          .read(DriftSqlType.string, data['${effectivePrefix}code'])!,
      rate: attachedDatabase.typeMapping
          .read(DriftSqlType.double, data['${effectivePrefix}rate'])!,
      description: attachedDatabase.typeMapping
          .read(DriftSqlType.string, data['${effectivePrefix}description'])!,
    );
  }

  @override
  $TaxRatesTable createAlias(String alias) {
    return $TaxRatesTable(attachedDatabase, alias);
  }
}

class TaxRate extends DataClass implements Insertable<TaxRate> {
  final String code;
  final double rate;
  final String description;
  const TaxRate(
      {required this.code, required this.rate, required this.description});
  @override
  Map<String, Expression> toColumns(bool nullToAbsent) {
    final map = <String, Expression>{};
    map['code'] = Variable<String>(code);
    map['rate'] = Variable<double>(rate);
    map['description'] = Variable<String>(description);
    return map;
  }

  TaxRatesCompanion toCompanion(bool nullToAbsent) {
    return TaxRatesCompanion(
      code: Value(code),
      rate: Value(rate),
      description: Value(description),
    );
  }

  factory TaxRate.fromJson(Map<String, dynamic> json,
      {ValueSerializer? serializer}) {
    serializer ??= driftRuntimeOptions.defaultSerializer;
    return TaxRate(
      code: serializer.fromJson<String>(json['code']),
      rate: serializer.fromJson<double>(json['rate']),
      description: serializer.fromJson<String>(json['description']),
    );
  }
  @override
  Map<String, dynamic> toJson({ValueSerializer? serializer}) {
    serializer ??= driftRuntimeOptions.defaultSerializer;
    return <String, dynamic>{
      'code': serializer.toJson<String>(code),
      'rate': serializer.toJson<double>(rate),
      'description': serializer.toJson<String>(description),
    };
  }

  TaxRate copyWith({String? code, double? rate, String? description}) =>
      TaxRate(
        code: code ?? this.code,
        rate: rate ?? this.rate,
        description: description ?? this.description,
      );
  TaxRate copyWithCompanion(TaxRatesCompanion data) {
    return TaxRate(
      code: data.code.present ? data.code.value : this.code,
      rate: data.rate.present ? data.rate.value : this.rate,
      description:
          data.description.present ? data.description.value : this.description,
    );
  }

  @override
  String toString() {
    return (StringBuffer('TaxRate(')
          ..write('code: $code, ')
          ..write('rate: $rate, ')
          ..write('description: $description')
          ..write(')'))
        .toString();
  }

  @override
  int get hashCode => Object.hash(code, rate, description);
  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      (other is TaxRate &&
          other.code == this.code &&
          other.rate == this.rate &&
          other.description == this.description);
}

class TaxRatesCompanion extends UpdateCompanion<TaxRate> {
  final Value<String> code;
  final Value<double> rate;
  final Value<String> description;
  final Value<int> rowid;
  const TaxRatesCompanion({
    this.code = const Value.absent(),
    this.rate = const Value.absent(),
    this.description = const Value.absent(),
    this.rowid = const Value.absent(),
  });
  TaxRatesCompanion.insert({
    required String code,
    required double rate,
    required String description,
    this.rowid = const Value.absent(),
  })  : code = Value(code),
        rate = Value(rate),
        description = Value(description);
  static Insertable<TaxRate> custom({
    Expression<String>? code,
    Expression<double>? rate,
    Expression<String>? description,
    Expression<int>? rowid,
  }) {
    return RawValuesInsertable({
      if (code != null) 'code': code,
      if (rate != null) 'rate': rate,
      if (description != null) 'description': description,
      if (rowid != null) 'rowid': rowid,
    });
  }

  TaxRatesCompanion copyWith(
      {Value<String>? code,
      Value<double>? rate,
      Value<String>? description,
      Value<int>? rowid}) {
    return TaxRatesCompanion(
      code: code ?? this.code,
      rate: rate ?? this.rate,
      description: description ?? this.description,
      rowid: rowid ?? this.rowid,
    );
  }

  @override
  Map<String, Expression> toColumns(bool nullToAbsent) {
    final map = <String, Expression>{};
    if (code.present) {
      map['code'] = Variable<String>(code.value);
    }
    if (rate.present) {
      map['rate'] = Variable<double>(rate.value);
    }
    if (description.present) {
      map['description'] = Variable<String>(description.value);
    }
    if (rowid.present) {
      map['rowid'] = Variable<int>(rowid.value);
    }
    return map;
  }

  @override
  String toString() {
    return (StringBuffer('TaxRatesCompanion(')
          ..write('code: $code, ')
          ..write('rate: $rate, ')
          ..write('description: $description, ')
          ..write('rowid: $rowid')
          ..write(')'))
        .toString();
  }
}

class $JournalEntriesTable extends JournalEntries
    with TableInfo<$JournalEntriesTable, JournalEntry> {
  @override
  final GeneratedDatabase attachedDatabase;
  final String? _alias;
  $JournalEntriesTable(this.attachedDatabase, [this._alias]);
  static const VerificationMeta _idMeta = const VerificationMeta('id');
  @override
  late final GeneratedColumn<String> id = GeneratedColumn<String>(
      'id', aliasedName, false,
      type: DriftSqlType.string, requiredDuringInsert: true);
  static const VerificationMeta _entryDateMeta =
      const VerificationMeta('entryDate');
  @override
  late final GeneratedColumn<DateTime> entryDate = GeneratedColumn<DateTime>(
      'entry_date', aliasedName, false,
      type: DriftSqlType.dateTime, requiredDuringInsert: true);
  static const VerificationMeta _referenceMeta =
      const VerificationMeta('reference');
  @override
  late final GeneratedColumn<String> reference = GeneratedColumn<String>(
      'reference', aliasedName, true,
      type: DriftSqlType.string, requiredDuringInsert: false);
  static const VerificationMeta _narrationMeta =
      const VerificationMeta('narration');
  @override
  late final GeneratedColumn<String> narration = GeneratedColumn<String>(
      'narration', aliasedName, true,
      type: DriftSqlType.string, requiredDuringInsert: false);
  static const VerificationMeta _createdAtMeta =
      const VerificationMeta('createdAt');
  @override
  late final GeneratedColumn<DateTime> createdAt = GeneratedColumn<DateTime>(
      'created_at', aliasedName, false,
      type: DriftSqlType.dateTime,
      requiredDuringInsert: false,
      defaultValue: currentDateAndTime);
  @override
  List<GeneratedColumn> get $columns =>
      [id, entryDate, reference, narration, createdAt];
  @override
  String get aliasedName => _alias ?? actualTableName;
  @override
  String get actualTableName => $name;
  static const String $name = 'journal_entries';
  @override
  VerificationContext validateIntegrity(Insertable<JournalEntry> instance,
      {bool isInserting = false}) {
    final context = VerificationContext();
    final data = instance.toColumns(true);
    if (data.containsKey('id')) {
      context.handle(_idMeta, id.isAcceptableOrUnknown(data['id']!, _idMeta));
    } else if (isInserting) {
      context.missing(_idMeta);
    }
    if (data.containsKey('entry_date')) {
      context.handle(_entryDateMeta,
          entryDate.isAcceptableOrUnknown(data['entry_date']!, _entryDateMeta));
    } else if (isInserting) {
      context.missing(_entryDateMeta);
    }
    if (data.containsKey('reference')) {
      context.handle(_referenceMeta,
          reference.isAcceptableOrUnknown(data['reference']!, _referenceMeta));
    }
    if (data.containsKey('narration')) {
      context.handle(_narrationMeta,
          narration.isAcceptableOrUnknown(data['narration']!, _narrationMeta));
    }
    if (data.containsKey('created_at')) {
      context.handle(_createdAtMeta,
          createdAt.isAcceptableOrUnknown(data['created_at']!, _createdAtMeta));
    }
    return context;
  }

  @override
  Set<GeneratedColumn> get $primaryKey => {id};
  @override
  JournalEntry map(Map<String, dynamic> data, {String? tablePrefix}) {
    final effectivePrefix = tablePrefix != null ? '$tablePrefix.' : '';
    return JournalEntry(
      id: attachedDatabase.typeMapping
          .read(DriftSqlType.string, data['${effectivePrefix}id'])!,
      entryDate: attachedDatabase.typeMapping
          .read(DriftSqlType.dateTime, data['${effectivePrefix}entry_date'])!,
      reference: attachedDatabase.typeMapping
          .read(DriftSqlType.string, data['${effectivePrefix}reference']),
      narration: attachedDatabase.typeMapping
          .read(DriftSqlType.string, data['${effectivePrefix}narration']),
      createdAt: attachedDatabase.typeMapping
          .read(DriftSqlType.dateTime, data['${effectivePrefix}created_at'])!,
    );
  }

  @override
  $JournalEntriesTable createAlias(String alias) {
    return $JournalEntriesTable(attachedDatabase, alias);
  }
}

class JournalEntry extends DataClass implements Insertable<JournalEntry> {
  final String id;
  final DateTime entryDate;
  final String? reference;
  final String? narration;
  final DateTime createdAt;
  const JournalEntry(
      {required this.id,
      required this.entryDate,
      this.reference,
      this.narration,
      required this.createdAt});
  @override
  Map<String, Expression> toColumns(bool nullToAbsent) {
    final map = <String, Expression>{};
    map['id'] = Variable<String>(id);
    map['entry_date'] = Variable<DateTime>(entryDate);
    if (!nullToAbsent || reference != null) {
      map['reference'] = Variable<String>(reference);
    }
    if (!nullToAbsent || narration != null) {
      map['narration'] = Variable<String>(narration);
    }
    map['created_at'] = Variable<DateTime>(createdAt);
    return map;
  }

  JournalEntriesCompanion toCompanion(bool nullToAbsent) {
    return JournalEntriesCompanion(
      id: Value(id),
      entryDate: Value(entryDate),
      reference: reference == null && nullToAbsent
          ? const Value.absent()
          : Value(reference),
      narration: narration == null && nullToAbsent
          ? const Value.absent()
          : Value(narration),
      createdAt: Value(createdAt),
    );
  }

  factory JournalEntry.fromJson(Map<String, dynamic> json,
      {ValueSerializer? serializer}) {
    serializer ??= driftRuntimeOptions.defaultSerializer;
    return JournalEntry(
      id: serializer.fromJson<String>(json['id']),
      entryDate: serializer.fromJson<DateTime>(json['entryDate']),
      reference: serializer.fromJson<String?>(json['reference']),
      narration: serializer.fromJson<String?>(json['narration']),
      createdAt: serializer.fromJson<DateTime>(json['createdAt']),
    );
  }
  @override
  Map<String, dynamic> toJson({ValueSerializer? serializer}) {
    serializer ??= driftRuntimeOptions.defaultSerializer;
    return <String, dynamic>{
      'id': serializer.toJson<String>(id),
      'entryDate': serializer.toJson<DateTime>(entryDate),
      'reference': serializer.toJson<String?>(reference),
      'narration': serializer.toJson<String?>(narration),
      'createdAt': serializer.toJson<DateTime>(createdAt),
    };
  }

  JournalEntry copyWith(
          {String? id,
          DateTime? entryDate,
          Value<String?> reference = const Value.absent(),
          Value<String?> narration = const Value.absent(),
          DateTime? createdAt}) =>
      JournalEntry(
        id: id ?? this.id,
        entryDate: entryDate ?? this.entryDate,
        reference: reference.present ? reference.value : this.reference,
        narration: narration.present ? narration.value : this.narration,
        createdAt: createdAt ?? this.createdAt,
      );
  JournalEntry copyWithCompanion(JournalEntriesCompanion data) {
    return JournalEntry(
      id: data.id.present ? data.id.value : this.id,
      entryDate: data.entryDate.present ? data.entryDate.value : this.entryDate,
      reference: data.reference.present ? data.reference.value : this.reference,
      narration: data.narration.present ? data.narration.value : this.narration,
      createdAt: data.createdAt.present ? data.createdAt.value : this.createdAt,
    );
  }

  @override
  String toString() {
    return (StringBuffer('JournalEntry(')
          ..write('id: $id, ')
          ..write('entryDate: $entryDate, ')
          ..write('reference: $reference, ')
          ..write('narration: $narration, ')
          ..write('createdAt: $createdAt')
          ..write(')'))
        .toString();
  }

  @override
  int get hashCode =>
      Object.hash(id, entryDate, reference, narration, createdAt);
  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      (other is JournalEntry &&
          other.id == this.id &&
          other.entryDate == this.entryDate &&
          other.reference == this.reference &&
          other.narration == this.narration &&
          other.createdAt == this.createdAt);
}

class JournalEntriesCompanion extends UpdateCompanion<JournalEntry> {
  final Value<String> id;
  final Value<DateTime> entryDate;
  final Value<String?> reference;
  final Value<String?> narration;
  final Value<DateTime> createdAt;
  final Value<int> rowid;
  const JournalEntriesCompanion({
    this.id = const Value.absent(),
    this.entryDate = const Value.absent(),
    this.reference = const Value.absent(),
    this.narration = const Value.absent(),
    this.createdAt = const Value.absent(),
    this.rowid = const Value.absent(),
  });
  JournalEntriesCompanion.insert({
    required String id,
    required DateTime entryDate,
    this.reference = const Value.absent(),
    this.narration = const Value.absent(),
    this.createdAt = const Value.absent(),
    this.rowid = const Value.absent(),
  })  : id = Value(id),
        entryDate = Value(entryDate);
  static Insertable<JournalEntry> custom({
    Expression<String>? id,
    Expression<DateTime>? entryDate,
    Expression<String>? reference,
    Expression<String>? narration,
    Expression<DateTime>? createdAt,
    Expression<int>? rowid,
  }) {
    return RawValuesInsertable({
      if (id != null) 'id': id,
      if (entryDate != null) 'entry_date': entryDate,
      if (reference != null) 'reference': reference,
      if (narration != null) 'narration': narration,
      if (createdAt != null) 'created_at': createdAt,
      if (rowid != null) 'rowid': rowid,
    });
  }

  JournalEntriesCompanion copyWith(
      {Value<String>? id,
      Value<DateTime>? entryDate,
      Value<String?>? reference,
      Value<String?>? narration,
      Value<DateTime>? createdAt,
      Value<int>? rowid}) {
    return JournalEntriesCompanion(
      id: id ?? this.id,
      entryDate: entryDate ?? this.entryDate,
      reference: reference ?? this.reference,
      narration: narration ?? this.narration,
      createdAt: createdAt ?? this.createdAt,
      rowid: rowid ?? this.rowid,
    );
  }

  @override
  Map<String, Expression> toColumns(bool nullToAbsent) {
    final map = <String, Expression>{};
    if (id.present) {
      map['id'] = Variable<String>(id.value);
    }
    if (entryDate.present) {
      map['entry_date'] = Variable<DateTime>(entryDate.value);
    }
    if (reference.present) {
      map['reference'] = Variable<String>(reference.value);
    }
    if (narration.present) {
      map['narration'] = Variable<String>(narration.value);
    }
    if (createdAt.present) {
      map['created_at'] = Variable<DateTime>(createdAt.value);
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
          ..write('entryDate: $entryDate, ')
          ..write('reference: $reference, ')
          ..write('narration: $narration, ')
          ..write('createdAt: $createdAt, ')
          ..write('rowid: $rowid')
          ..write(')'))
        .toString();
  }
}

class $JournalLinesTable extends JournalLines
    with TableInfo<$JournalLinesTable, JournalLine> {
  @override
  final GeneratedDatabase attachedDatabase;
  final String? _alias;
  $JournalLinesTable(this.attachedDatabase, [this._alias]);
  static const VerificationMeta _idMeta = const VerificationMeta('id');
  @override
  late final GeneratedColumn<String> id = GeneratedColumn<String>(
      'id', aliasedName, false,
      type: DriftSqlType.string, requiredDuringInsert: true);
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
  static const VerificationMeta _debitMeta = const VerificationMeta('debit');
  @override
  late final GeneratedColumn<double> debit = GeneratedColumn<double>(
      'debit', aliasedName, false,
      type: DriftSqlType.double,
      requiredDuringInsert: false,
      defaultValue: const Constant(0.0));
  static const VerificationMeta _creditMeta = const VerificationMeta('credit');
  @override
  late final GeneratedColumn<double> credit = GeneratedColumn<double>(
      'credit', aliasedName, false,
      type: DriftSqlType.double,
      requiredDuringInsert: false,
      defaultValue: const Constant(0.0));
  static const VerificationMeta _gstAmountMeta =
      const VerificationMeta('gstAmount');
  @override
  late final GeneratedColumn<double> gstAmount = GeneratedColumn<double>(
      'gst_amount', aliasedName, false,
      type: DriftSqlType.double,
      requiredDuringInsert: false,
      defaultValue: const Constant(0.0));
  static const VerificationMeta _gstTaxCodeMeta =
      const VerificationMeta('gstTaxCode');
  @override
  late final GeneratedColumn<String> gstTaxCode = GeneratedColumn<String>(
      'gst_tax_code', aliasedName, true,
      type: DriftSqlType.string, requiredDuringInsert: false);
  @override
  List<GeneratedColumn> get $columns =>
      [id, journalEntryId, accountId, debit, credit, gstAmount, gstTaxCode];
  @override
  String get aliasedName => _alias ?? actualTableName;
  @override
  String get actualTableName => $name;
  static const String $name = 'journal_lines';
  @override
  VerificationContext validateIntegrity(Insertable<JournalLine> instance,
      {bool isInserting = false}) {
    final context = VerificationContext();
    final data = instance.toColumns(true);
    if (data.containsKey('id')) {
      context.handle(_idMeta, id.isAcceptableOrUnknown(data['id']!, _idMeta));
    } else if (isInserting) {
      context.missing(_idMeta);
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
    if (data.containsKey('debit')) {
      context.handle(
          _debitMeta, debit.isAcceptableOrUnknown(data['debit']!, _debitMeta));
    }
    if (data.containsKey('credit')) {
      context.handle(_creditMeta,
          credit.isAcceptableOrUnknown(data['credit']!, _creditMeta));
    }
    if (data.containsKey('gst_amount')) {
      context.handle(_gstAmountMeta,
          gstAmount.isAcceptableOrUnknown(data['gst_amount']!, _gstAmountMeta));
    }
    if (data.containsKey('gst_tax_code')) {
      context.handle(
          _gstTaxCodeMeta,
          gstTaxCode.isAcceptableOrUnknown(
              data['gst_tax_code']!, _gstTaxCodeMeta));
    }
    return context;
  }

  @override
  Set<GeneratedColumn> get $primaryKey => {id};
  @override
  JournalLine map(Map<String, dynamic> data, {String? tablePrefix}) {
    final effectivePrefix = tablePrefix != null ? '$tablePrefix.' : '';
    return JournalLine(
      id: attachedDatabase.typeMapping
          .read(DriftSqlType.string, data['${effectivePrefix}id'])!,
      journalEntryId: attachedDatabase.typeMapping.read(
          DriftSqlType.string, data['${effectivePrefix}journal_entry_id'])!,
      accountId: attachedDatabase.typeMapping
          .read(DriftSqlType.string, data['${effectivePrefix}account_id'])!,
      debit: attachedDatabase.typeMapping
          .read(DriftSqlType.double, data['${effectivePrefix}debit'])!,
      credit: attachedDatabase.typeMapping
          .read(DriftSqlType.double, data['${effectivePrefix}credit'])!,
      gstAmount: attachedDatabase.typeMapping
          .read(DriftSqlType.double, data['${effectivePrefix}gst_amount'])!,
      gstTaxCode: attachedDatabase.typeMapping
          .read(DriftSqlType.string, data['${effectivePrefix}gst_tax_code']),
    );
  }

  @override
  $JournalLinesTable createAlias(String alias) {
    return $JournalLinesTable(attachedDatabase, alias);
  }
}

class JournalLine extends DataClass implements Insertable<JournalLine> {
  final String id;
  final String journalEntryId;
  final String accountId;
  final double debit;
  final double credit;
  final double gstAmount;
  final String? gstTaxCode;
  const JournalLine(
      {required this.id,
      required this.journalEntryId,
      required this.accountId,
      required this.debit,
      required this.credit,
      required this.gstAmount,
      this.gstTaxCode});
  @override
  Map<String, Expression> toColumns(bool nullToAbsent) {
    final map = <String, Expression>{};
    map['id'] = Variable<String>(id);
    map['journal_entry_id'] = Variable<String>(journalEntryId);
    map['account_id'] = Variable<String>(accountId);
    map['debit'] = Variable<double>(debit);
    map['credit'] = Variable<double>(credit);
    map['gst_amount'] = Variable<double>(gstAmount);
    if (!nullToAbsent || gstTaxCode != null) {
      map['gst_tax_code'] = Variable<String>(gstTaxCode);
    }
    return map;
  }

  JournalLinesCompanion toCompanion(bool nullToAbsent) {
    return JournalLinesCompanion(
      id: Value(id),
      journalEntryId: Value(journalEntryId),
      accountId: Value(accountId),
      debit: Value(debit),
      credit: Value(credit),
      gstAmount: Value(gstAmount),
      gstTaxCode: gstTaxCode == null && nullToAbsent
          ? const Value.absent()
          : Value(gstTaxCode),
    );
  }

  factory JournalLine.fromJson(Map<String, dynamic> json,
      {ValueSerializer? serializer}) {
    serializer ??= driftRuntimeOptions.defaultSerializer;
    return JournalLine(
      id: serializer.fromJson<String>(json['id']),
      journalEntryId: serializer.fromJson<String>(json['journalEntryId']),
      accountId: serializer.fromJson<String>(json['accountId']),
      debit: serializer.fromJson<double>(json['debit']),
      credit: serializer.fromJson<double>(json['credit']),
      gstAmount: serializer.fromJson<double>(json['gstAmount']),
      gstTaxCode: serializer.fromJson<String?>(json['gstTaxCode']),
    );
  }
  @override
  Map<String, dynamic> toJson({ValueSerializer? serializer}) {
    serializer ??= driftRuntimeOptions.defaultSerializer;
    return <String, dynamic>{
      'id': serializer.toJson<String>(id),
      'journalEntryId': serializer.toJson<String>(journalEntryId),
      'accountId': serializer.toJson<String>(accountId),
      'debit': serializer.toJson<double>(debit),
      'credit': serializer.toJson<double>(credit),
      'gstAmount': serializer.toJson<double>(gstAmount),
      'gstTaxCode': serializer.toJson<String?>(gstTaxCode),
    };
  }

  JournalLine copyWith(
          {String? id,
          String? journalEntryId,
          String? accountId,
          double? debit,
          double? credit,
          double? gstAmount,
          Value<String?> gstTaxCode = const Value.absent()}) =>
      JournalLine(
        id: id ?? this.id,
        journalEntryId: journalEntryId ?? this.journalEntryId,
        accountId: accountId ?? this.accountId,
        debit: debit ?? this.debit,
        credit: credit ?? this.credit,
        gstAmount: gstAmount ?? this.gstAmount,
        gstTaxCode: gstTaxCode.present ? gstTaxCode.value : this.gstTaxCode,
      );
  JournalLine copyWithCompanion(JournalLinesCompanion data) {
    return JournalLine(
      id: data.id.present ? data.id.value : this.id,
      journalEntryId: data.journalEntryId.present
          ? data.journalEntryId.value
          : this.journalEntryId,
      accountId: data.accountId.present ? data.accountId.value : this.accountId,
      debit: data.debit.present ? data.debit.value : this.debit,
      credit: data.credit.present ? data.credit.value : this.credit,
      gstAmount: data.gstAmount.present ? data.gstAmount.value : this.gstAmount,
      gstTaxCode:
          data.gstTaxCode.present ? data.gstTaxCode.value : this.gstTaxCode,
    );
  }

  @override
  String toString() {
    return (StringBuffer('JournalLine(')
          ..write('id: $id, ')
          ..write('journalEntryId: $journalEntryId, ')
          ..write('accountId: $accountId, ')
          ..write('debit: $debit, ')
          ..write('credit: $credit, ')
          ..write('gstAmount: $gstAmount, ')
          ..write('gstTaxCode: $gstTaxCode')
          ..write(')'))
        .toString();
  }

  @override
  int get hashCode => Object.hash(
      id, journalEntryId, accountId, debit, credit, gstAmount, gstTaxCode);
  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      (other is JournalLine &&
          other.id == this.id &&
          other.journalEntryId == this.journalEntryId &&
          other.accountId == this.accountId &&
          other.debit == this.debit &&
          other.credit == this.credit &&
          other.gstAmount == this.gstAmount &&
          other.gstTaxCode == this.gstTaxCode);
}

class JournalLinesCompanion extends UpdateCompanion<JournalLine> {
  final Value<String> id;
  final Value<String> journalEntryId;
  final Value<String> accountId;
  final Value<double> debit;
  final Value<double> credit;
  final Value<double> gstAmount;
  final Value<String?> gstTaxCode;
  final Value<int> rowid;
  const JournalLinesCompanion({
    this.id = const Value.absent(),
    this.journalEntryId = const Value.absent(),
    this.accountId = const Value.absent(),
    this.debit = const Value.absent(),
    this.credit = const Value.absent(),
    this.gstAmount = const Value.absent(),
    this.gstTaxCode = const Value.absent(),
    this.rowid = const Value.absent(),
  });
  JournalLinesCompanion.insert({
    required String id,
    required String journalEntryId,
    required String accountId,
    this.debit = const Value.absent(),
    this.credit = const Value.absent(),
    this.gstAmount = const Value.absent(),
    this.gstTaxCode = const Value.absent(),
    this.rowid = const Value.absent(),
  })  : id = Value(id),
        journalEntryId = Value(journalEntryId),
        accountId = Value(accountId);
  static Insertable<JournalLine> custom({
    Expression<String>? id,
    Expression<String>? journalEntryId,
    Expression<String>? accountId,
    Expression<double>? debit,
    Expression<double>? credit,
    Expression<double>? gstAmount,
    Expression<String>? gstTaxCode,
    Expression<int>? rowid,
  }) {
    return RawValuesInsertable({
      if (id != null) 'id': id,
      if (journalEntryId != null) 'journal_entry_id': journalEntryId,
      if (accountId != null) 'account_id': accountId,
      if (debit != null) 'debit': debit,
      if (credit != null) 'credit': credit,
      if (gstAmount != null) 'gst_amount': gstAmount,
      if (gstTaxCode != null) 'gst_tax_code': gstTaxCode,
      if (rowid != null) 'rowid': rowid,
    });
  }

  JournalLinesCompanion copyWith(
      {Value<String>? id,
      Value<String>? journalEntryId,
      Value<String>? accountId,
      Value<double>? debit,
      Value<double>? credit,
      Value<double>? gstAmount,
      Value<String?>? gstTaxCode,
      Value<int>? rowid}) {
    return JournalLinesCompanion(
      id: id ?? this.id,
      journalEntryId: journalEntryId ?? this.journalEntryId,
      accountId: accountId ?? this.accountId,
      debit: debit ?? this.debit,
      credit: credit ?? this.credit,
      gstAmount: gstAmount ?? this.gstAmount,
      gstTaxCode: gstTaxCode ?? this.gstTaxCode,
      rowid: rowid ?? this.rowid,
    );
  }

  @override
  Map<String, Expression> toColumns(bool nullToAbsent) {
    final map = <String, Expression>{};
    if (id.present) {
      map['id'] = Variable<String>(id.value);
    }
    if (journalEntryId.present) {
      map['journal_entry_id'] = Variable<String>(journalEntryId.value);
    }
    if (accountId.present) {
      map['account_id'] = Variable<String>(accountId.value);
    }
    if (debit.present) {
      map['debit'] = Variable<double>(debit.value);
    }
    if (credit.present) {
      map['credit'] = Variable<double>(credit.value);
    }
    if (gstAmount.present) {
      map['gst_amount'] = Variable<double>(gstAmount.value);
    }
    if (gstTaxCode.present) {
      map['gst_tax_code'] = Variable<String>(gstTaxCode.value);
    }
    if (rowid.present) {
      map['rowid'] = Variable<int>(rowid.value);
    }
    return map;
  }

  @override
  String toString() {
    return (StringBuffer('JournalLinesCompanion(')
          ..write('id: $id, ')
          ..write('journalEntryId: $journalEntryId, ')
          ..write('accountId: $accountId, ')
          ..write('debit: $debit, ')
          ..write('credit: $credit, ')
          ..write('gstAmount: $gstAmount, ')
          ..write('gstTaxCode: $gstTaxCode, ')
          ..write('rowid: $rowid')
          ..write(')'))
        .toString();
  }
}

class $PayrollEventsTable extends PayrollEvents
    with TableInfo<$PayrollEventsTable, PayrollEvent> {
  @override
  final GeneratedDatabase attachedDatabase;
  final String? _alias;
  $PayrollEventsTable(this.attachedDatabase, [this._alias]);
  static const VerificationMeta _idMeta = const VerificationMeta('id');
  @override
  late final GeneratedColumn<String> id = GeneratedColumn<String>(
      'id', aliasedName, false,
      type: DriftSqlType.string, requiredDuringInsert: true);
  static const VerificationMeta _payPeriodStartMeta =
      const VerificationMeta('payPeriodStart');
  @override
  late final GeneratedColumn<DateTime> payPeriodStart =
      GeneratedColumn<DateTime>('pay_period_start', aliasedName, false,
          type: DriftSqlType.dateTime, requiredDuringInsert: true);
  static const VerificationMeta _payPeriodEndMeta =
      const VerificationMeta('payPeriodEnd');
  @override
  late final GeneratedColumn<DateTime> payPeriodEnd = GeneratedColumn<DateTime>(
      'pay_period_end', aliasedName, false,
      type: DriftSqlType.dateTime, requiredDuringInsert: true);
  static const VerificationMeta _paymentDateMeta =
      const VerificationMeta('paymentDate');
  @override
  late final GeneratedColumn<DateTime> paymentDate = GeneratedColumn<DateTime>(
      'payment_date', aliasedName, false,
      type: DriftSqlType.dateTime, requiredDuringInsert: true);
  static const VerificationMeta _totalGrossMeta =
      const VerificationMeta('totalGross');
  @override
  late final GeneratedColumn<double> totalGross = GeneratedColumn<double>(
      'total_gross', aliasedName, false,
      type: DriftSqlType.double, requiredDuringInsert: true);
  static const VerificationMeta _totalTaxWithheldMeta =
      const VerificationMeta('totalTaxWithheld');
  @override
  late final GeneratedColumn<double> totalTaxWithheld = GeneratedColumn<double>(
      'total_tax_withheld', aliasedName, false,
      type: DriftSqlType.double, requiredDuringInsert: true);
  static const VerificationMeta _totalSuperMeta =
      const VerificationMeta('totalSuper');
  @override
  late final GeneratedColumn<double> totalSuper = GeneratedColumn<double>(
      'total_super', aliasedName, false,
      type: DriftSqlType.double, requiredDuringInsert: true);
  static const VerificationMeta _stpSubmissionStatusMeta =
      const VerificationMeta('stpSubmissionStatus');
  @override
  late final GeneratedColumn<String> stpSubmissionStatus =
      GeneratedColumn<String>('stp_submission_status', aliasedName, false,
          type: DriftSqlType.string,
          requiredDuringInsert: false,
          defaultValue: const Constant('pending'));
  static const VerificationMeta _stpReceiptNumberMeta =
      const VerificationMeta('stpReceiptNumber');
  @override
  late final GeneratedColumn<String> stpReceiptNumber = GeneratedColumn<String>(
      'stp_receipt_number', aliasedName, true,
      type: DriftSqlType.string, requiredDuringInsert: false);
  static const VerificationMeta _createdAtMeta =
      const VerificationMeta('createdAt');
  @override
  late final GeneratedColumn<DateTime> createdAt = GeneratedColumn<DateTime>(
      'created_at', aliasedName, false,
      type: DriftSqlType.dateTime,
      requiredDuringInsert: false,
      defaultValue: currentDateAndTime);
  @override
  List<GeneratedColumn> get $columns => [
        id,
        payPeriodStart,
        payPeriodEnd,
        paymentDate,
        totalGross,
        totalTaxWithheld,
        totalSuper,
        stpSubmissionStatus,
        stpReceiptNumber,
        createdAt
      ];
  @override
  String get aliasedName => _alias ?? actualTableName;
  @override
  String get actualTableName => $name;
  static const String $name = 'payroll_events';
  @override
  VerificationContext validateIntegrity(Insertable<PayrollEvent> instance,
      {bool isInserting = false}) {
    final context = VerificationContext();
    final data = instance.toColumns(true);
    if (data.containsKey('id')) {
      context.handle(_idMeta, id.isAcceptableOrUnknown(data['id']!, _idMeta));
    } else if (isInserting) {
      context.missing(_idMeta);
    }
    if (data.containsKey('pay_period_start')) {
      context.handle(
          _payPeriodStartMeta,
          payPeriodStart.isAcceptableOrUnknown(
              data['pay_period_start']!, _payPeriodStartMeta));
    } else if (isInserting) {
      context.missing(_payPeriodStartMeta);
    }
    if (data.containsKey('pay_period_end')) {
      context.handle(
          _payPeriodEndMeta,
          payPeriodEnd.isAcceptableOrUnknown(
              data['pay_period_end']!, _payPeriodEndMeta));
    } else if (isInserting) {
      context.missing(_payPeriodEndMeta);
    }
    if (data.containsKey('payment_date')) {
      context.handle(
          _paymentDateMeta,
          paymentDate.isAcceptableOrUnknown(
              data['payment_date']!, _paymentDateMeta));
    } else if (isInserting) {
      context.missing(_paymentDateMeta);
    }
    if (data.containsKey('total_gross')) {
      context.handle(
          _totalGrossMeta,
          totalGross.isAcceptableOrUnknown(
              data['total_gross']!, _totalGrossMeta));
    } else if (isInserting) {
      context.missing(_totalGrossMeta);
    }
    if (data.containsKey('total_tax_withheld')) {
      context.handle(
          _totalTaxWithheldMeta,
          totalTaxWithheld.isAcceptableOrUnknown(
              data['total_tax_withheld']!, _totalTaxWithheldMeta));
    } else if (isInserting) {
      context.missing(_totalTaxWithheldMeta);
    }
    if (data.containsKey('total_super')) {
      context.handle(
          _totalSuperMeta,
          totalSuper.isAcceptableOrUnknown(
              data['total_super']!, _totalSuperMeta));
    } else if (isInserting) {
      context.missing(_totalSuperMeta);
    }
    if (data.containsKey('stp_submission_status')) {
      context.handle(
          _stpSubmissionStatusMeta,
          stpSubmissionStatus.isAcceptableOrUnknown(
              data['stp_submission_status']!, _stpSubmissionStatusMeta));
    }
    if (data.containsKey('stp_receipt_number')) {
      context.handle(
          _stpReceiptNumberMeta,
          stpReceiptNumber.isAcceptableOrUnknown(
              data['stp_receipt_number']!, _stpReceiptNumberMeta));
    }
    if (data.containsKey('created_at')) {
      context.handle(_createdAtMeta,
          createdAt.isAcceptableOrUnknown(data['created_at']!, _createdAtMeta));
    }
    return context;
  }

  @override
  Set<GeneratedColumn> get $primaryKey => {id};
  @override
  PayrollEvent map(Map<String, dynamic> data, {String? tablePrefix}) {
    final effectivePrefix = tablePrefix != null ? '$tablePrefix.' : '';
    return PayrollEvent(
      id: attachedDatabase.typeMapping
          .read(DriftSqlType.string, data['${effectivePrefix}id'])!,
      payPeriodStart: attachedDatabase.typeMapping.read(
          DriftSqlType.dateTime, data['${effectivePrefix}pay_period_start'])!,
      payPeriodEnd: attachedDatabase.typeMapping.read(
          DriftSqlType.dateTime, data['${effectivePrefix}pay_period_end'])!,
      paymentDate: attachedDatabase.typeMapping
          .read(DriftSqlType.dateTime, data['${effectivePrefix}payment_date'])!,
      totalGross: attachedDatabase.typeMapping
          .read(DriftSqlType.double, data['${effectivePrefix}total_gross'])!,
      totalTaxWithheld: attachedDatabase.typeMapping.read(
          DriftSqlType.double, data['${effectivePrefix}total_tax_withheld'])!,
      totalSuper: attachedDatabase.typeMapping
          .read(DriftSqlType.double, data['${effectivePrefix}total_super'])!,
      stpSubmissionStatus: attachedDatabase.typeMapping.read(
          DriftSqlType.string,
          data['${effectivePrefix}stp_submission_status'])!,
      stpReceiptNumber: attachedDatabase.typeMapping.read(
          DriftSqlType.string, data['${effectivePrefix}stp_receipt_number']),
      createdAt: attachedDatabase.typeMapping
          .read(DriftSqlType.dateTime, data['${effectivePrefix}created_at'])!,
    );
  }

  @override
  $PayrollEventsTable createAlias(String alias) {
    return $PayrollEventsTable(attachedDatabase, alias);
  }
}

class PayrollEvent extends DataClass implements Insertable<PayrollEvent> {
  final String id;
  final DateTime payPeriodStart;
  final DateTime payPeriodEnd;
  final DateTime paymentDate;
  final double totalGross;
  final double totalTaxWithheld;
  final double totalSuper;
  final String stpSubmissionStatus;
  final String? stpReceiptNumber;
  final DateTime createdAt;
  const PayrollEvent(
      {required this.id,
      required this.payPeriodStart,
      required this.payPeriodEnd,
      required this.paymentDate,
      required this.totalGross,
      required this.totalTaxWithheld,
      required this.totalSuper,
      required this.stpSubmissionStatus,
      this.stpReceiptNumber,
      required this.createdAt});
  @override
  Map<String, Expression> toColumns(bool nullToAbsent) {
    final map = <String, Expression>{};
    map['id'] = Variable<String>(id);
    map['pay_period_start'] = Variable<DateTime>(payPeriodStart);
    map['pay_period_end'] = Variable<DateTime>(payPeriodEnd);
    map['payment_date'] = Variable<DateTime>(paymentDate);
    map['total_gross'] = Variable<double>(totalGross);
    map['total_tax_withheld'] = Variable<double>(totalTaxWithheld);
    map['total_super'] = Variable<double>(totalSuper);
    map['stp_submission_status'] = Variable<String>(stpSubmissionStatus);
    if (!nullToAbsent || stpReceiptNumber != null) {
      map['stp_receipt_number'] = Variable<String>(stpReceiptNumber);
    }
    map['created_at'] = Variable<DateTime>(createdAt);
    return map;
  }

  PayrollEventsCompanion toCompanion(bool nullToAbsent) {
    return PayrollEventsCompanion(
      id: Value(id),
      payPeriodStart: Value(payPeriodStart),
      payPeriodEnd: Value(payPeriodEnd),
      paymentDate: Value(paymentDate),
      totalGross: Value(totalGross),
      totalTaxWithheld: Value(totalTaxWithheld),
      totalSuper: Value(totalSuper),
      stpSubmissionStatus: Value(stpSubmissionStatus),
      stpReceiptNumber: stpReceiptNumber == null && nullToAbsent
          ? const Value.absent()
          : Value(stpReceiptNumber),
      createdAt: Value(createdAt),
    );
  }

  factory PayrollEvent.fromJson(Map<String, dynamic> json,
      {ValueSerializer? serializer}) {
    serializer ??= driftRuntimeOptions.defaultSerializer;
    return PayrollEvent(
      id: serializer.fromJson<String>(json['id']),
      payPeriodStart: serializer.fromJson<DateTime>(json['payPeriodStart']),
      payPeriodEnd: serializer.fromJson<DateTime>(json['payPeriodEnd']),
      paymentDate: serializer.fromJson<DateTime>(json['paymentDate']),
      totalGross: serializer.fromJson<double>(json['totalGross']),
      totalTaxWithheld: serializer.fromJson<double>(json['totalTaxWithheld']),
      totalSuper: serializer.fromJson<double>(json['totalSuper']),
      stpSubmissionStatus:
          serializer.fromJson<String>(json['stpSubmissionStatus']),
      stpReceiptNumber: serializer.fromJson<String?>(json['stpReceiptNumber']),
      createdAt: serializer.fromJson<DateTime>(json['createdAt']),
    );
  }
  @override
  Map<String, dynamic> toJson({ValueSerializer? serializer}) {
    serializer ??= driftRuntimeOptions.defaultSerializer;
    return <String, dynamic>{
      'id': serializer.toJson<String>(id),
      'payPeriodStart': serializer.toJson<DateTime>(payPeriodStart),
      'payPeriodEnd': serializer.toJson<DateTime>(payPeriodEnd),
      'paymentDate': serializer.toJson<DateTime>(paymentDate),
      'totalGross': serializer.toJson<double>(totalGross),
      'totalTaxWithheld': serializer.toJson<double>(totalTaxWithheld),
      'totalSuper': serializer.toJson<double>(totalSuper),
      'stpSubmissionStatus': serializer.toJson<String>(stpSubmissionStatus),
      'stpReceiptNumber': serializer.toJson<String?>(stpReceiptNumber),
      'createdAt': serializer.toJson<DateTime>(createdAt),
    };
  }

  PayrollEvent copyWith(
          {String? id,
          DateTime? payPeriodStart,
          DateTime? payPeriodEnd,
          DateTime? paymentDate,
          double? totalGross,
          double? totalTaxWithheld,
          double? totalSuper,
          String? stpSubmissionStatus,
          Value<String?> stpReceiptNumber = const Value.absent(),
          DateTime? createdAt}) =>
      PayrollEvent(
        id: id ?? this.id,
        payPeriodStart: payPeriodStart ?? this.payPeriodStart,
        payPeriodEnd: payPeriodEnd ?? this.payPeriodEnd,
        paymentDate: paymentDate ?? this.paymentDate,
        totalGross: totalGross ?? this.totalGross,
        totalTaxWithheld: totalTaxWithheld ?? this.totalTaxWithheld,
        totalSuper: totalSuper ?? this.totalSuper,
        stpSubmissionStatus: stpSubmissionStatus ?? this.stpSubmissionStatus,
        stpReceiptNumber: stpReceiptNumber.present
            ? stpReceiptNumber.value
            : this.stpReceiptNumber,
        createdAt: createdAt ?? this.createdAt,
      );
  PayrollEvent copyWithCompanion(PayrollEventsCompanion data) {
    return PayrollEvent(
      id: data.id.present ? data.id.value : this.id,
      payPeriodStart: data.payPeriodStart.present
          ? data.payPeriodStart.value
          : this.payPeriodStart,
      payPeriodEnd: data.payPeriodEnd.present
          ? data.payPeriodEnd.value
          : this.payPeriodEnd,
      paymentDate:
          data.paymentDate.present ? data.paymentDate.value : this.paymentDate,
      totalGross:
          data.totalGross.present ? data.totalGross.value : this.totalGross,
      totalTaxWithheld: data.totalTaxWithheld.present
          ? data.totalTaxWithheld.value
          : this.totalTaxWithheld,
      totalSuper:
          data.totalSuper.present ? data.totalSuper.value : this.totalSuper,
      stpSubmissionStatus: data.stpSubmissionStatus.present
          ? data.stpSubmissionStatus.value
          : this.stpSubmissionStatus,
      stpReceiptNumber: data.stpReceiptNumber.present
          ? data.stpReceiptNumber.value
          : this.stpReceiptNumber,
      createdAt: data.createdAt.present ? data.createdAt.value : this.createdAt,
    );
  }

  @override
  String toString() {
    return (StringBuffer('PayrollEvent(')
          ..write('id: $id, ')
          ..write('payPeriodStart: $payPeriodStart, ')
          ..write('payPeriodEnd: $payPeriodEnd, ')
          ..write('paymentDate: $paymentDate, ')
          ..write('totalGross: $totalGross, ')
          ..write('totalTaxWithheld: $totalTaxWithheld, ')
          ..write('totalSuper: $totalSuper, ')
          ..write('stpSubmissionStatus: $stpSubmissionStatus, ')
          ..write('stpReceiptNumber: $stpReceiptNumber, ')
          ..write('createdAt: $createdAt')
          ..write(')'))
        .toString();
  }

  @override
  int get hashCode => Object.hash(
      id,
      payPeriodStart,
      payPeriodEnd,
      paymentDate,
      totalGross,
      totalTaxWithheld,
      totalSuper,
      stpSubmissionStatus,
      stpReceiptNumber,
      createdAt);
  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      (other is PayrollEvent &&
          other.id == this.id &&
          other.payPeriodStart == this.payPeriodStart &&
          other.payPeriodEnd == this.payPeriodEnd &&
          other.paymentDate == this.paymentDate &&
          other.totalGross == this.totalGross &&
          other.totalTaxWithheld == this.totalTaxWithheld &&
          other.totalSuper == this.totalSuper &&
          other.stpSubmissionStatus == this.stpSubmissionStatus &&
          other.stpReceiptNumber == this.stpReceiptNumber &&
          other.createdAt == this.createdAt);
}

class PayrollEventsCompanion extends UpdateCompanion<PayrollEvent> {
  final Value<String> id;
  final Value<DateTime> payPeriodStart;
  final Value<DateTime> payPeriodEnd;
  final Value<DateTime> paymentDate;
  final Value<double> totalGross;
  final Value<double> totalTaxWithheld;
  final Value<double> totalSuper;
  final Value<String> stpSubmissionStatus;
  final Value<String?> stpReceiptNumber;
  final Value<DateTime> createdAt;
  final Value<int> rowid;
  const PayrollEventsCompanion({
    this.id = const Value.absent(),
    this.payPeriodStart = const Value.absent(),
    this.payPeriodEnd = const Value.absent(),
    this.paymentDate = const Value.absent(),
    this.totalGross = const Value.absent(),
    this.totalTaxWithheld = const Value.absent(),
    this.totalSuper = const Value.absent(),
    this.stpSubmissionStatus = const Value.absent(),
    this.stpReceiptNumber = const Value.absent(),
    this.createdAt = const Value.absent(),
    this.rowid = const Value.absent(),
  });
  PayrollEventsCompanion.insert({
    required String id,
    required DateTime payPeriodStart,
    required DateTime payPeriodEnd,
    required DateTime paymentDate,
    required double totalGross,
    required double totalTaxWithheld,
    required double totalSuper,
    this.stpSubmissionStatus = const Value.absent(),
    this.stpReceiptNumber = const Value.absent(),
    this.createdAt = const Value.absent(),
    this.rowid = const Value.absent(),
  })  : id = Value(id),
        payPeriodStart = Value(payPeriodStart),
        payPeriodEnd = Value(payPeriodEnd),
        paymentDate = Value(paymentDate),
        totalGross = Value(totalGross),
        totalTaxWithheld = Value(totalTaxWithheld),
        totalSuper = Value(totalSuper);
  static Insertable<PayrollEvent> custom({
    Expression<String>? id,
    Expression<DateTime>? payPeriodStart,
    Expression<DateTime>? payPeriodEnd,
    Expression<DateTime>? paymentDate,
    Expression<double>? totalGross,
    Expression<double>? totalTaxWithheld,
    Expression<double>? totalSuper,
    Expression<String>? stpSubmissionStatus,
    Expression<String>? stpReceiptNumber,
    Expression<DateTime>? createdAt,
    Expression<int>? rowid,
  }) {
    return RawValuesInsertable({
      if (id != null) 'id': id,
      if (payPeriodStart != null) 'pay_period_start': payPeriodStart,
      if (payPeriodEnd != null) 'pay_period_end': payPeriodEnd,
      if (paymentDate != null) 'payment_date': paymentDate,
      if (totalGross != null) 'total_gross': totalGross,
      if (totalTaxWithheld != null) 'total_tax_withheld': totalTaxWithheld,
      if (totalSuper != null) 'total_super': totalSuper,
      if (stpSubmissionStatus != null)
        'stp_submission_status': stpSubmissionStatus,
      if (stpReceiptNumber != null) 'stp_receipt_number': stpReceiptNumber,
      if (createdAt != null) 'created_at': createdAt,
      if (rowid != null) 'rowid': rowid,
    });
  }

  PayrollEventsCompanion copyWith(
      {Value<String>? id,
      Value<DateTime>? payPeriodStart,
      Value<DateTime>? payPeriodEnd,
      Value<DateTime>? paymentDate,
      Value<double>? totalGross,
      Value<double>? totalTaxWithheld,
      Value<double>? totalSuper,
      Value<String>? stpSubmissionStatus,
      Value<String?>? stpReceiptNumber,
      Value<DateTime>? createdAt,
      Value<int>? rowid}) {
    return PayrollEventsCompanion(
      id: id ?? this.id,
      payPeriodStart: payPeriodStart ?? this.payPeriodStart,
      payPeriodEnd: payPeriodEnd ?? this.payPeriodEnd,
      paymentDate: paymentDate ?? this.paymentDate,
      totalGross: totalGross ?? this.totalGross,
      totalTaxWithheld: totalTaxWithheld ?? this.totalTaxWithheld,
      totalSuper: totalSuper ?? this.totalSuper,
      stpSubmissionStatus: stpSubmissionStatus ?? this.stpSubmissionStatus,
      stpReceiptNumber: stpReceiptNumber ?? this.stpReceiptNumber,
      createdAt: createdAt ?? this.createdAt,
      rowid: rowid ?? this.rowid,
    );
  }

  @override
  Map<String, Expression> toColumns(bool nullToAbsent) {
    final map = <String, Expression>{};
    if (id.present) {
      map['id'] = Variable<String>(id.value);
    }
    if (payPeriodStart.present) {
      map['pay_period_start'] = Variable<DateTime>(payPeriodStart.value);
    }
    if (payPeriodEnd.present) {
      map['pay_period_end'] = Variable<DateTime>(payPeriodEnd.value);
    }
    if (paymentDate.present) {
      map['payment_date'] = Variable<DateTime>(paymentDate.value);
    }
    if (totalGross.present) {
      map['total_gross'] = Variable<double>(totalGross.value);
    }
    if (totalTaxWithheld.present) {
      map['total_tax_withheld'] = Variable<double>(totalTaxWithheld.value);
    }
    if (totalSuper.present) {
      map['total_super'] = Variable<double>(totalSuper.value);
    }
    if (stpSubmissionStatus.present) {
      map['stp_submission_status'] =
          Variable<String>(stpSubmissionStatus.value);
    }
    if (stpReceiptNumber.present) {
      map['stp_receipt_number'] = Variable<String>(stpReceiptNumber.value);
    }
    if (createdAt.present) {
      map['created_at'] = Variable<DateTime>(createdAt.value);
    }
    if (rowid.present) {
      map['rowid'] = Variable<int>(rowid.value);
    }
    return map;
  }

  @override
  String toString() {
    return (StringBuffer('PayrollEventsCompanion(')
          ..write('id: $id, ')
          ..write('payPeriodStart: $payPeriodStart, ')
          ..write('payPeriodEnd: $payPeriodEnd, ')
          ..write('paymentDate: $paymentDate, ')
          ..write('totalGross: $totalGross, ')
          ..write('totalTaxWithheld: $totalTaxWithheld, ')
          ..write('totalSuper: $totalSuper, ')
          ..write('stpSubmissionStatus: $stpSubmissionStatus, ')
          ..write('stpReceiptNumber: $stpReceiptNumber, ')
          ..write('createdAt: $createdAt, ')
          ..write('rowid: $rowid')
          ..write(')'))
        .toString();
  }
}

abstract class _$AppDatabase extends GeneratedDatabase {
  _$AppDatabase(QueryExecutor e) : super(e);
  $AppDatabaseManager get managers => $AppDatabaseManager(this);
  late final $AppSettingsTable appSettings = $AppSettingsTable(this);
  late final $UsersTable users = $UsersTable(this);
  late final $ModuleRegistryTableTable moduleRegistryTable =
      $ModuleRegistryTableTable(this);
  late final $ContactsTable contacts = $ContactsTable(this);
  late final $LeadsTable leads = $LeadsTable(this);
  late final $DealsTable deals = $DealsTable(this);
  late final $ProductsTable products = $ProductsTable(this);
  late final $StockQuantsTable stockQuants = $StockQuantsTable(this);
  late final $StockMovesTable stockMoves = $StockMovesTable(this);
  late final $TrustScoresTable trustScores = $TrustScoresTable(this);
  late final $ReferralsTable referrals = $ReferralsTable(this);
  late final $ServiceListingsTable serviceListings =
      $ServiceListingsTable(this);
  late final $ServiceOrdersTable serviceOrders = $ServiceOrdersTable(this);
  late final $ReviewsTable reviews = $ReviewsTable(this);
  late final $ServiceItemsTable serviceItems = $ServiceItemsTable(this);
  late final $ServiceBookingsTable serviceBookings =
      $ServiceBookingsTable(this);
  late final $OutboxMutationsTable outboxMutations =
      $OutboxMutationsTable(this);
  late final $ProjectsTable projects = $ProjectsTable(this);
  late final $TasksTable tasks = $TasksTable(this);
  late final $PurchaseOrdersTable purchaseOrders = $PurchaseOrdersTable(this);
  late final $PurchaseOrderLinesTable purchaseOrderLines =
      $PurchaseOrderLinesTable(this);
  late final $AuContactsTable auContacts = $AuContactsTable(this);
  late final $AccountsTable accounts = $AccountsTable(this);
  late final $TaxRatesTable taxRates = $TaxRatesTable(this);
  late final $JournalEntriesTable journalEntries = $JournalEntriesTable(this);
  late final $JournalLinesTable journalLines = $JournalLinesTable(this);
  late final $PayrollEventsTable payrollEvents = $PayrollEventsTable(this);
  @override
  Iterable<TableInfo<Table, Object?>> get allTables =>
      allSchemaEntities.whereType<TableInfo<Table, Object?>>();
  @override
  List<DatabaseSchemaEntity> get allSchemaEntities => [
        appSettings,
        users,
        moduleRegistryTable,
        contacts,
        leads,
        deals,
        products,
        stockQuants,
        stockMoves,
        trustScores,
        referrals,
        serviceListings,
        serviceOrders,
        reviews,
        serviceItems,
        serviceBookings,
        outboxMutations,
        projects,
        tasks,
        purchaseOrders,
        purchaseOrderLines,
        auContacts,
        accounts,
        taxRates,
        journalEntries,
        journalLines,
        payrollEvents
      ];
}

typedef $$AppSettingsTableCreateCompanionBuilder = AppSettingsCompanion
    Function({
  required String key,
  required String value,
  Value<int> rowid,
});
typedef $$AppSettingsTableUpdateCompanionBuilder = AppSettingsCompanion
    Function({
  Value<String> key,
  Value<String> value,
  Value<int> rowid,
});

class $$AppSettingsTableFilterComposer
    extends Composer<_$AppDatabase, $AppSettingsTable> {
  $$AppSettingsTableFilterComposer({
    required super.$db,
    required super.$table,
    super.joinBuilder,
    super.$addJoinBuilderToRootComposer,
    super.$removeJoinBuilderFromRootComposer,
  });
  ColumnFilters<String> get key => $composableBuilder(
      column: $table.key, builder: (column) => ColumnFilters(column));

  ColumnFilters<String> get value => $composableBuilder(
      column: $table.value, builder: (column) => ColumnFilters(column));
}

class $$AppSettingsTableOrderingComposer
    extends Composer<_$AppDatabase, $AppSettingsTable> {
  $$AppSettingsTableOrderingComposer({
    required super.$db,
    required super.$table,
    super.joinBuilder,
    super.$addJoinBuilderToRootComposer,
    super.$removeJoinBuilderFromRootComposer,
  });
  ColumnOrderings<String> get key => $composableBuilder(
      column: $table.key, builder: (column) => ColumnOrderings(column));

  ColumnOrderings<String> get value => $composableBuilder(
      column: $table.value, builder: (column) => ColumnOrderings(column));
}

class $$AppSettingsTableAnnotationComposer
    extends Composer<_$AppDatabase, $AppSettingsTable> {
  $$AppSettingsTableAnnotationComposer({
    required super.$db,
    required super.$table,
    super.joinBuilder,
    super.$addJoinBuilderToRootComposer,
    super.$removeJoinBuilderFromRootComposer,
  });
  GeneratedColumn<String> get key =>
      $composableBuilder(column: $table.key, builder: (column) => column);

  GeneratedColumn<String> get value =>
      $composableBuilder(column: $table.value, builder: (column) => column);
}

class $$AppSettingsTableTableManager extends RootTableManager<
    _$AppDatabase,
    $AppSettingsTable,
    AppSetting,
    $$AppSettingsTableFilterComposer,
    $$AppSettingsTableOrderingComposer,
    $$AppSettingsTableAnnotationComposer,
    $$AppSettingsTableCreateCompanionBuilder,
    $$AppSettingsTableUpdateCompanionBuilder,
    (AppSetting, BaseReferences<_$AppDatabase, $AppSettingsTable, AppSetting>),
    AppSetting,
    PrefetchHooks Function()> {
  $$AppSettingsTableTableManager(_$AppDatabase db, $AppSettingsTable table)
      : super(TableManagerState(
          db: db,
          table: table,
          createFilteringComposer: () =>
              $$AppSettingsTableFilterComposer($db: db, $table: table),
          createOrderingComposer: () =>
              $$AppSettingsTableOrderingComposer($db: db, $table: table),
          createComputedFieldComposer: () =>
              $$AppSettingsTableAnnotationComposer($db: db, $table: table),
          updateCompanionCallback: ({
            Value<String> key = const Value.absent(),
            Value<String> value = const Value.absent(),
            Value<int> rowid = const Value.absent(),
          }) =>
              AppSettingsCompanion(
            key: key,
            value: value,
            rowid: rowid,
          ),
          createCompanionCallback: ({
            required String key,
            required String value,
            Value<int> rowid = const Value.absent(),
          }) =>
              AppSettingsCompanion.insert(
            key: key,
            value: value,
            rowid: rowid,
          ),
          withReferenceMapper: (p0) => p0
              .map((e) => (e.readTable(table), BaseReferences(db, table, e)))
              .toList(),
          prefetchHooksCallback: null,
        ));
}

typedef $$AppSettingsTableProcessedTableManager = ProcessedTableManager<
    _$AppDatabase,
    $AppSettingsTable,
    AppSetting,
    $$AppSettingsTableFilterComposer,
    $$AppSettingsTableOrderingComposer,
    $$AppSettingsTableAnnotationComposer,
    $$AppSettingsTableCreateCompanionBuilder,
    $$AppSettingsTableUpdateCompanionBuilder,
    (AppSetting, BaseReferences<_$AppDatabase, $AppSettingsTable, AppSetting>),
    AppSetting,
    PrefetchHooks Function()>;
typedef $$UsersTableCreateCompanionBuilder = UsersCompanion Function({
  required String id,
  required String name,
  Value<String?> email,
  Value<String?> phone,
  required String type,
  Value<String> kycStatus,
  Value<DateTime> createdAt,
  Value<int> rowid,
});
typedef $$UsersTableUpdateCompanionBuilder = UsersCompanion Function({
  Value<String> id,
  Value<String> name,
  Value<String?> email,
  Value<String?> phone,
  Value<String> type,
  Value<String> kycStatus,
  Value<DateTime> createdAt,
  Value<int> rowid,
});

class $$UsersTableFilterComposer extends Composer<_$AppDatabase, $UsersTable> {
  $$UsersTableFilterComposer({
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

  ColumnFilters<String> get email => $composableBuilder(
      column: $table.email, builder: (column) => ColumnFilters(column));

  ColumnFilters<String> get phone => $composableBuilder(
      column: $table.phone, builder: (column) => ColumnFilters(column));

  ColumnFilters<String> get type => $composableBuilder(
      column: $table.type, builder: (column) => ColumnFilters(column));

  ColumnFilters<String> get kycStatus => $composableBuilder(
      column: $table.kycStatus, builder: (column) => ColumnFilters(column));

  ColumnFilters<DateTime> get createdAt => $composableBuilder(
      column: $table.createdAt, builder: (column) => ColumnFilters(column));
}

class $$UsersTableOrderingComposer
    extends Composer<_$AppDatabase, $UsersTable> {
  $$UsersTableOrderingComposer({
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

  ColumnOrderings<String> get email => $composableBuilder(
      column: $table.email, builder: (column) => ColumnOrderings(column));

  ColumnOrderings<String> get phone => $composableBuilder(
      column: $table.phone, builder: (column) => ColumnOrderings(column));

  ColumnOrderings<String> get type => $composableBuilder(
      column: $table.type, builder: (column) => ColumnOrderings(column));

  ColumnOrderings<String> get kycStatus => $composableBuilder(
      column: $table.kycStatus, builder: (column) => ColumnOrderings(column));

  ColumnOrderings<DateTime> get createdAt => $composableBuilder(
      column: $table.createdAt, builder: (column) => ColumnOrderings(column));
}

class $$UsersTableAnnotationComposer
    extends Composer<_$AppDatabase, $UsersTable> {
  $$UsersTableAnnotationComposer({
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

  GeneratedColumn<String> get email =>
      $composableBuilder(column: $table.email, builder: (column) => column);

  GeneratedColumn<String> get phone =>
      $composableBuilder(column: $table.phone, builder: (column) => column);

  GeneratedColumn<String> get type =>
      $composableBuilder(column: $table.type, builder: (column) => column);

  GeneratedColumn<String> get kycStatus =>
      $composableBuilder(column: $table.kycStatus, builder: (column) => column);

  GeneratedColumn<DateTime> get createdAt =>
      $composableBuilder(column: $table.createdAt, builder: (column) => column);
}

class $$UsersTableTableManager extends RootTableManager<
    _$AppDatabase,
    $UsersTable,
    User,
    $$UsersTableFilterComposer,
    $$UsersTableOrderingComposer,
    $$UsersTableAnnotationComposer,
    $$UsersTableCreateCompanionBuilder,
    $$UsersTableUpdateCompanionBuilder,
    (User, BaseReferences<_$AppDatabase, $UsersTable, User>),
    User,
    PrefetchHooks Function()> {
  $$UsersTableTableManager(_$AppDatabase db, $UsersTable table)
      : super(TableManagerState(
          db: db,
          table: table,
          createFilteringComposer: () =>
              $$UsersTableFilterComposer($db: db, $table: table),
          createOrderingComposer: () =>
              $$UsersTableOrderingComposer($db: db, $table: table),
          createComputedFieldComposer: () =>
              $$UsersTableAnnotationComposer($db: db, $table: table),
          updateCompanionCallback: ({
            Value<String> id = const Value.absent(),
            Value<String> name = const Value.absent(),
            Value<String?> email = const Value.absent(),
            Value<String?> phone = const Value.absent(),
            Value<String> type = const Value.absent(),
            Value<String> kycStatus = const Value.absent(),
            Value<DateTime> createdAt = const Value.absent(),
            Value<int> rowid = const Value.absent(),
          }) =>
              UsersCompanion(
            id: id,
            name: name,
            email: email,
            phone: phone,
            type: type,
            kycStatus: kycStatus,
            createdAt: createdAt,
            rowid: rowid,
          ),
          createCompanionCallback: ({
            required String id,
            required String name,
            Value<String?> email = const Value.absent(),
            Value<String?> phone = const Value.absent(),
            required String type,
            Value<String> kycStatus = const Value.absent(),
            Value<DateTime> createdAt = const Value.absent(),
            Value<int> rowid = const Value.absent(),
          }) =>
              UsersCompanion.insert(
            id: id,
            name: name,
            email: email,
            phone: phone,
            type: type,
            kycStatus: kycStatus,
            createdAt: createdAt,
            rowid: rowid,
          ),
          withReferenceMapper: (p0) => p0
              .map((e) => (e.readTable(table), BaseReferences(db, table, e)))
              .toList(),
          prefetchHooksCallback: null,
        ));
}

typedef $$UsersTableProcessedTableManager = ProcessedTableManager<
    _$AppDatabase,
    $UsersTable,
    User,
    $$UsersTableFilterComposer,
    $$UsersTableOrderingComposer,
    $$UsersTableAnnotationComposer,
    $$UsersTableCreateCompanionBuilder,
    $$UsersTableUpdateCompanionBuilder,
    (User, BaseReferences<_$AppDatabase, $UsersTable, User>),
    User,
    PrefetchHooks Function()>;
typedef $$ModuleRegistryTableTableCreateCompanionBuilder
    = ModuleRegistryTableCompanion Function({
  required String id,
  required String name,
  required String version,
  Value<bool> isInstalled,
  Value<int> rowid,
});
typedef $$ModuleRegistryTableTableUpdateCompanionBuilder
    = ModuleRegistryTableCompanion Function({
  Value<String> id,
  Value<String> name,
  Value<String> version,
  Value<bool> isInstalled,
  Value<int> rowid,
});

class $$ModuleRegistryTableTableFilterComposer
    extends Composer<_$AppDatabase, $ModuleRegistryTableTable> {
  $$ModuleRegistryTableTableFilterComposer({
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

  ColumnFilters<String> get version => $composableBuilder(
      column: $table.version, builder: (column) => ColumnFilters(column));

  ColumnFilters<bool> get isInstalled => $composableBuilder(
      column: $table.isInstalled, builder: (column) => ColumnFilters(column));
}

class $$ModuleRegistryTableTableOrderingComposer
    extends Composer<_$AppDatabase, $ModuleRegistryTableTable> {
  $$ModuleRegistryTableTableOrderingComposer({
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

  ColumnOrderings<String> get version => $composableBuilder(
      column: $table.version, builder: (column) => ColumnOrderings(column));

  ColumnOrderings<bool> get isInstalled => $composableBuilder(
      column: $table.isInstalled, builder: (column) => ColumnOrderings(column));
}

class $$ModuleRegistryTableTableAnnotationComposer
    extends Composer<_$AppDatabase, $ModuleRegistryTableTable> {
  $$ModuleRegistryTableTableAnnotationComposer({
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

  GeneratedColumn<String> get version =>
      $composableBuilder(column: $table.version, builder: (column) => column);

  GeneratedColumn<bool> get isInstalled => $composableBuilder(
      column: $table.isInstalled, builder: (column) => column);
}

class $$ModuleRegistryTableTableTableManager extends RootTableManager<
    _$AppDatabase,
    $ModuleRegistryTableTable,
    ModuleRegistryTableData,
    $$ModuleRegistryTableTableFilterComposer,
    $$ModuleRegistryTableTableOrderingComposer,
    $$ModuleRegistryTableTableAnnotationComposer,
    $$ModuleRegistryTableTableCreateCompanionBuilder,
    $$ModuleRegistryTableTableUpdateCompanionBuilder,
    (
      ModuleRegistryTableData,
      BaseReferences<_$AppDatabase, $ModuleRegistryTableTable,
          ModuleRegistryTableData>
    ),
    ModuleRegistryTableData,
    PrefetchHooks Function()> {
  $$ModuleRegistryTableTableTableManager(
      _$AppDatabase db, $ModuleRegistryTableTable table)
      : super(TableManagerState(
          db: db,
          table: table,
          createFilteringComposer: () =>
              $$ModuleRegistryTableTableFilterComposer($db: db, $table: table),
          createOrderingComposer: () =>
              $$ModuleRegistryTableTableOrderingComposer(
                  $db: db, $table: table),
          createComputedFieldComposer: () =>
              $$ModuleRegistryTableTableAnnotationComposer(
                  $db: db, $table: table),
          updateCompanionCallback: ({
            Value<String> id = const Value.absent(),
            Value<String> name = const Value.absent(),
            Value<String> version = const Value.absent(),
            Value<bool> isInstalled = const Value.absent(),
            Value<int> rowid = const Value.absent(),
          }) =>
              ModuleRegistryTableCompanion(
            id: id,
            name: name,
            version: version,
            isInstalled: isInstalled,
            rowid: rowid,
          ),
          createCompanionCallback: ({
            required String id,
            required String name,
            required String version,
            Value<bool> isInstalled = const Value.absent(),
            Value<int> rowid = const Value.absent(),
          }) =>
              ModuleRegistryTableCompanion.insert(
            id: id,
            name: name,
            version: version,
            isInstalled: isInstalled,
            rowid: rowid,
          ),
          withReferenceMapper: (p0) => p0
              .map((e) => (e.readTable(table), BaseReferences(db, table, e)))
              .toList(),
          prefetchHooksCallback: null,
        ));
}

typedef $$ModuleRegistryTableTableProcessedTableManager = ProcessedTableManager<
    _$AppDatabase,
    $ModuleRegistryTableTable,
    ModuleRegistryTableData,
    $$ModuleRegistryTableTableFilterComposer,
    $$ModuleRegistryTableTableOrderingComposer,
    $$ModuleRegistryTableTableAnnotationComposer,
    $$ModuleRegistryTableTableCreateCompanionBuilder,
    $$ModuleRegistryTableTableUpdateCompanionBuilder,
    (
      ModuleRegistryTableData,
      BaseReferences<_$AppDatabase, $ModuleRegistryTableTable,
          ModuleRegistryTableData>
    ),
    ModuleRegistryTableData,
    PrefetchHooks Function()>;
typedef $$ContactsTableCreateCompanionBuilder = ContactsCompanion Function({
  required String id,
  required String name,
  Value<String?> phone,
  Value<String?> email,
  Value<String?> address,
  Value<String?> company,
  Value<bool> isCustomer,
  Value<DateTime> createdAt,
  Value<int> rowid,
});
typedef $$ContactsTableUpdateCompanionBuilder = ContactsCompanion Function({
  Value<String> id,
  Value<String> name,
  Value<String?> phone,
  Value<String?> email,
  Value<String?> address,
  Value<String?> company,
  Value<bool> isCustomer,
  Value<DateTime> createdAt,
  Value<int> rowid,
});

class $$ContactsTableFilterComposer
    extends Composer<_$AppDatabase, $ContactsTable> {
  $$ContactsTableFilterComposer({
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

  ColumnFilters<String> get phone => $composableBuilder(
      column: $table.phone, builder: (column) => ColumnFilters(column));

  ColumnFilters<String> get email => $composableBuilder(
      column: $table.email, builder: (column) => ColumnFilters(column));

  ColumnFilters<String> get address => $composableBuilder(
      column: $table.address, builder: (column) => ColumnFilters(column));

  ColumnFilters<String> get company => $composableBuilder(
      column: $table.company, builder: (column) => ColumnFilters(column));

  ColumnFilters<bool> get isCustomer => $composableBuilder(
      column: $table.isCustomer, builder: (column) => ColumnFilters(column));

  ColumnFilters<DateTime> get createdAt => $composableBuilder(
      column: $table.createdAt, builder: (column) => ColumnFilters(column));
}

class $$ContactsTableOrderingComposer
    extends Composer<_$AppDatabase, $ContactsTable> {
  $$ContactsTableOrderingComposer({
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

  ColumnOrderings<String> get phone => $composableBuilder(
      column: $table.phone, builder: (column) => ColumnOrderings(column));

  ColumnOrderings<String> get email => $composableBuilder(
      column: $table.email, builder: (column) => ColumnOrderings(column));

  ColumnOrderings<String> get address => $composableBuilder(
      column: $table.address, builder: (column) => ColumnOrderings(column));

  ColumnOrderings<String> get company => $composableBuilder(
      column: $table.company, builder: (column) => ColumnOrderings(column));

  ColumnOrderings<bool> get isCustomer => $composableBuilder(
      column: $table.isCustomer, builder: (column) => ColumnOrderings(column));

  ColumnOrderings<DateTime> get createdAt => $composableBuilder(
      column: $table.createdAt, builder: (column) => ColumnOrderings(column));
}

class $$ContactsTableAnnotationComposer
    extends Composer<_$AppDatabase, $ContactsTable> {
  $$ContactsTableAnnotationComposer({
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

  GeneratedColumn<String> get phone =>
      $composableBuilder(column: $table.phone, builder: (column) => column);

  GeneratedColumn<String> get email =>
      $composableBuilder(column: $table.email, builder: (column) => column);

  GeneratedColumn<String> get address =>
      $composableBuilder(column: $table.address, builder: (column) => column);

  GeneratedColumn<String> get company =>
      $composableBuilder(column: $table.company, builder: (column) => column);

  GeneratedColumn<bool> get isCustomer => $composableBuilder(
      column: $table.isCustomer, builder: (column) => column);

  GeneratedColumn<DateTime> get createdAt =>
      $composableBuilder(column: $table.createdAt, builder: (column) => column);
}

class $$ContactsTableTableManager extends RootTableManager<
    _$AppDatabase,
    $ContactsTable,
    Contact,
    $$ContactsTableFilterComposer,
    $$ContactsTableOrderingComposer,
    $$ContactsTableAnnotationComposer,
    $$ContactsTableCreateCompanionBuilder,
    $$ContactsTableUpdateCompanionBuilder,
    (Contact, BaseReferences<_$AppDatabase, $ContactsTable, Contact>),
    Contact,
    PrefetchHooks Function()> {
  $$ContactsTableTableManager(_$AppDatabase db, $ContactsTable table)
      : super(TableManagerState(
          db: db,
          table: table,
          createFilteringComposer: () =>
              $$ContactsTableFilterComposer($db: db, $table: table),
          createOrderingComposer: () =>
              $$ContactsTableOrderingComposer($db: db, $table: table),
          createComputedFieldComposer: () =>
              $$ContactsTableAnnotationComposer($db: db, $table: table),
          updateCompanionCallback: ({
            Value<String> id = const Value.absent(),
            Value<String> name = const Value.absent(),
            Value<String?> phone = const Value.absent(),
            Value<String?> email = const Value.absent(),
            Value<String?> address = const Value.absent(),
            Value<String?> company = const Value.absent(),
            Value<bool> isCustomer = const Value.absent(),
            Value<DateTime> createdAt = const Value.absent(),
            Value<int> rowid = const Value.absent(),
          }) =>
              ContactsCompanion(
            id: id,
            name: name,
            phone: phone,
            email: email,
            address: address,
            company: company,
            isCustomer: isCustomer,
            createdAt: createdAt,
            rowid: rowid,
          ),
          createCompanionCallback: ({
            required String id,
            required String name,
            Value<String?> phone = const Value.absent(),
            Value<String?> email = const Value.absent(),
            Value<String?> address = const Value.absent(),
            Value<String?> company = const Value.absent(),
            Value<bool> isCustomer = const Value.absent(),
            Value<DateTime> createdAt = const Value.absent(),
            Value<int> rowid = const Value.absent(),
          }) =>
              ContactsCompanion.insert(
            id: id,
            name: name,
            phone: phone,
            email: email,
            address: address,
            company: company,
            isCustomer: isCustomer,
            createdAt: createdAt,
            rowid: rowid,
          ),
          withReferenceMapper: (p0) => p0
              .map((e) => (e.readTable(table), BaseReferences(db, table, e)))
              .toList(),
          prefetchHooksCallback: null,
        ));
}

typedef $$ContactsTableProcessedTableManager = ProcessedTableManager<
    _$AppDatabase,
    $ContactsTable,
    Contact,
    $$ContactsTableFilterComposer,
    $$ContactsTableOrderingComposer,
    $$ContactsTableAnnotationComposer,
    $$ContactsTableCreateCompanionBuilder,
    $$ContactsTableUpdateCompanionBuilder,
    (Contact, BaseReferences<_$AppDatabase, $ContactsTable, Contact>),
    Contact,
    PrefetchHooks Function()>;
typedef $$LeadsTableCreateCompanionBuilder = LeadsCompanion Function({
  required String id,
  required String title,
  Value<String?> contactId,
  Value<String> status,
  Value<double> expectedRevenue,
  Value<String?> notes,
  Value<String> source,
  Value<String?> ownerId,
  Value<String> customFields,
  Value<DateTime> createdAt,
  Value<int> rowid,
});
typedef $$LeadsTableUpdateCompanionBuilder = LeadsCompanion Function({
  Value<String> id,
  Value<String> title,
  Value<String?> contactId,
  Value<String> status,
  Value<double> expectedRevenue,
  Value<String?> notes,
  Value<String> source,
  Value<String?> ownerId,
  Value<String> customFields,
  Value<DateTime> createdAt,
  Value<int> rowid,
});

class $$LeadsTableFilterComposer extends Composer<_$AppDatabase, $LeadsTable> {
  $$LeadsTableFilterComposer({
    required super.$db,
    required super.$table,
    super.joinBuilder,
    super.$addJoinBuilderToRootComposer,
    super.$removeJoinBuilderFromRootComposer,
  });
  ColumnFilters<String> get id => $composableBuilder(
      column: $table.id, builder: (column) => ColumnFilters(column));

  ColumnFilters<String> get title => $composableBuilder(
      column: $table.title, builder: (column) => ColumnFilters(column));

  ColumnFilters<String> get contactId => $composableBuilder(
      column: $table.contactId, builder: (column) => ColumnFilters(column));

  ColumnFilters<String> get status => $composableBuilder(
      column: $table.status, builder: (column) => ColumnFilters(column));

  ColumnFilters<double> get expectedRevenue => $composableBuilder(
      column: $table.expectedRevenue,
      builder: (column) => ColumnFilters(column));

  ColumnFilters<String> get notes => $composableBuilder(
      column: $table.notes, builder: (column) => ColumnFilters(column));

  ColumnFilters<String> get source => $composableBuilder(
      column: $table.source, builder: (column) => ColumnFilters(column));

  ColumnFilters<String> get ownerId => $composableBuilder(
      column: $table.ownerId, builder: (column) => ColumnFilters(column));

  ColumnFilters<String> get customFields => $composableBuilder(
      column: $table.customFields, builder: (column) => ColumnFilters(column));

  ColumnFilters<DateTime> get createdAt => $composableBuilder(
      column: $table.createdAt, builder: (column) => ColumnFilters(column));
}

class $$LeadsTableOrderingComposer
    extends Composer<_$AppDatabase, $LeadsTable> {
  $$LeadsTableOrderingComposer({
    required super.$db,
    required super.$table,
    super.joinBuilder,
    super.$addJoinBuilderToRootComposer,
    super.$removeJoinBuilderFromRootComposer,
  });
  ColumnOrderings<String> get id => $composableBuilder(
      column: $table.id, builder: (column) => ColumnOrderings(column));

  ColumnOrderings<String> get title => $composableBuilder(
      column: $table.title, builder: (column) => ColumnOrderings(column));

  ColumnOrderings<String> get contactId => $composableBuilder(
      column: $table.contactId, builder: (column) => ColumnOrderings(column));

  ColumnOrderings<String> get status => $composableBuilder(
      column: $table.status, builder: (column) => ColumnOrderings(column));

  ColumnOrderings<double> get expectedRevenue => $composableBuilder(
      column: $table.expectedRevenue,
      builder: (column) => ColumnOrderings(column));

  ColumnOrderings<String> get notes => $composableBuilder(
      column: $table.notes, builder: (column) => ColumnOrderings(column));

  ColumnOrderings<String> get source => $composableBuilder(
      column: $table.source, builder: (column) => ColumnOrderings(column));

  ColumnOrderings<String> get ownerId => $composableBuilder(
      column: $table.ownerId, builder: (column) => ColumnOrderings(column));

  ColumnOrderings<String> get customFields => $composableBuilder(
      column: $table.customFields,
      builder: (column) => ColumnOrderings(column));

  ColumnOrderings<DateTime> get createdAt => $composableBuilder(
      column: $table.createdAt, builder: (column) => ColumnOrderings(column));
}

class $$LeadsTableAnnotationComposer
    extends Composer<_$AppDatabase, $LeadsTable> {
  $$LeadsTableAnnotationComposer({
    required super.$db,
    required super.$table,
    super.joinBuilder,
    super.$addJoinBuilderToRootComposer,
    super.$removeJoinBuilderFromRootComposer,
  });
  GeneratedColumn<String> get id =>
      $composableBuilder(column: $table.id, builder: (column) => column);

  GeneratedColumn<String> get title =>
      $composableBuilder(column: $table.title, builder: (column) => column);

  GeneratedColumn<String> get contactId =>
      $composableBuilder(column: $table.contactId, builder: (column) => column);

  GeneratedColumn<String> get status =>
      $composableBuilder(column: $table.status, builder: (column) => column);

  GeneratedColumn<double> get expectedRevenue => $composableBuilder(
      column: $table.expectedRevenue, builder: (column) => column);

  GeneratedColumn<String> get notes =>
      $composableBuilder(column: $table.notes, builder: (column) => column);

  GeneratedColumn<String> get source =>
      $composableBuilder(column: $table.source, builder: (column) => column);

  GeneratedColumn<String> get ownerId =>
      $composableBuilder(column: $table.ownerId, builder: (column) => column);

  GeneratedColumn<String> get customFields => $composableBuilder(
      column: $table.customFields, builder: (column) => column);

  GeneratedColumn<DateTime> get createdAt =>
      $composableBuilder(column: $table.createdAt, builder: (column) => column);
}

class $$LeadsTableTableManager extends RootTableManager<
    _$AppDatabase,
    $LeadsTable,
    Lead,
    $$LeadsTableFilterComposer,
    $$LeadsTableOrderingComposer,
    $$LeadsTableAnnotationComposer,
    $$LeadsTableCreateCompanionBuilder,
    $$LeadsTableUpdateCompanionBuilder,
    (Lead, BaseReferences<_$AppDatabase, $LeadsTable, Lead>),
    Lead,
    PrefetchHooks Function()> {
  $$LeadsTableTableManager(_$AppDatabase db, $LeadsTable table)
      : super(TableManagerState(
          db: db,
          table: table,
          createFilteringComposer: () =>
              $$LeadsTableFilterComposer($db: db, $table: table),
          createOrderingComposer: () =>
              $$LeadsTableOrderingComposer($db: db, $table: table),
          createComputedFieldComposer: () =>
              $$LeadsTableAnnotationComposer($db: db, $table: table),
          updateCompanionCallback: ({
            Value<String> id = const Value.absent(),
            Value<String> title = const Value.absent(),
            Value<String?> contactId = const Value.absent(),
            Value<String> status = const Value.absent(),
            Value<double> expectedRevenue = const Value.absent(),
            Value<String?> notes = const Value.absent(),
            Value<String> source = const Value.absent(),
            Value<String?> ownerId = const Value.absent(),
            Value<String> customFields = const Value.absent(),
            Value<DateTime> createdAt = const Value.absent(),
            Value<int> rowid = const Value.absent(),
          }) =>
              LeadsCompanion(
            id: id,
            title: title,
            contactId: contactId,
            status: status,
            expectedRevenue: expectedRevenue,
            notes: notes,
            source: source,
            ownerId: ownerId,
            customFields: customFields,
            createdAt: createdAt,
            rowid: rowid,
          ),
          createCompanionCallback: ({
            required String id,
            required String title,
            Value<String?> contactId = const Value.absent(),
            Value<String> status = const Value.absent(),
            Value<double> expectedRevenue = const Value.absent(),
            Value<String?> notes = const Value.absent(),
            Value<String> source = const Value.absent(),
            Value<String?> ownerId = const Value.absent(),
            Value<String> customFields = const Value.absent(),
            Value<DateTime> createdAt = const Value.absent(),
            Value<int> rowid = const Value.absent(),
          }) =>
              LeadsCompanion.insert(
            id: id,
            title: title,
            contactId: contactId,
            status: status,
            expectedRevenue: expectedRevenue,
            notes: notes,
            source: source,
            ownerId: ownerId,
            customFields: customFields,
            createdAt: createdAt,
            rowid: rowid,
          ),
          withReferenceMapper: (p0) => p0
              .map((e) => (e.readTable(table), BaseReferences(db, table, e)))
              .toList(),
          prefetchHooksCallback: null,
        ));
}

typedef $$LeadsTableProcessedTableManager = ProcessedTableManager<
    _$AppDatabase,
    $LeadsTable,
    Lead,
    $$LeadsTableFilterComposer,
    $$LeadsTableOrderingComposer,
    $$LeadsTableAnnotationComposer,
    $$LeadsTableCreateCompanionBuilder,
    $$LeadsTableUpdateCompanionBuilder,
    (Lead, BaseReferences<_$AppDatabase, $LeadsTable, Lead>),
    Lead,
    PrefetchHooks Function()>;
typedef $$DealsTableCreateCompanionBuilder = DealsCompanion Function({
  required String id,
  required String title,
  Value<String?> leadId,
  required String contactId,
  required double amount,
  Value<String> stage,
  Value<String> source,
  Value<String?> ownerId,
  Value<DateTime?> expectedCloseDate,
  Value<DateTime> createdAt,
  Value<int> rowid,
});
typedef $$DealsTableUpdateCompanionBuilder = DealsCompanion Function({
  Value<String> id,
  Value<String> title,
  Value<String?> leadId,
  Value<String> contactId,
  Value<double> amount,
  Value<String> stage,
  Value<String> source,
  Value<String?> ownerId,
  Value<DateTime?> expectedCloseDate,
  Value<DateTime> createdAt,
  Value<int> rowid,
});

class $$DealsTableFilterComposer extends Composer<_$AppDatabase, $DealsTable> {
  $$DealsTableFilterComposer({
    required super.$db,
    required super.$table,
    super.joinBuilder,
    super.$addJoinBuilderToRootComposer,
    super.$removeJoinBuilderFromRootComposer,
  });
  ColumnFilters<String> get id => $composableBuilder(
      column: $table.id, builder: (column) => ColumnFilters(column));

  ColumnFilters<String> get title => $composableBuilder(
      column: $table.title, builder: (column) => ColumnFilters(column));

  ColumnFilters<String> get leadId => $composableBuilder(
      column: $table.leadId, builder: (column) => ColumnFilters(column));

  ColumnFilters<String> get contactId => $composableBuilder(
      column: $table.contactId, builder: (column) => ColumnFilters(column));

  ColumnFilters<double> get amount => $composableBuilder(
      column: $table.amount, builder: (column) => ColumnFilters(column));

  ColumnFilters<String> get stage => $composableBuilder(
      column: $table.stage, builder: (column) => ColumnFilters(column));

  ColumnFilters<String> get source => $composableBuilder(
      column: $table.source, builder: (column) => ColumnFilters(column));

  ColumnFilters<String> get ownerId => $composableBuilder(
      column: $table.ownerId, builder: (column) => ColumnFilters(column));

  ColumnFilters<DateTime> get expectedCloseDate => $composableBuilder(
      column: $table.expectedCloseDate,
      builder: (column) => ColumnFilters(column));

  ColumnFilters<DateTime> get createdAt => $composableBuilder(
      column: $table.createdAt, builder: (column) => ColumnFilters(column));
}

class $$DealsTableOrderingComposer
    extends Composer<_$AppDatabase, $DealsTable> {
  $$DealsTableOrderingComposer({
    required super.$db,
    required super.$table,
    super.joinBuilder,
    super.$addJoinBuilderToRootComposer,
    super.$removeJoinBuilderFromRootComposer,
  });
  ColumnOrderings<String> get id => $composableBuilder(
      column: $table.id, builder: (column) => ColumnOrderings(column));

  ColumnOrderings<String> get title => $composableBuilder(
      column: $table.title, builder: (column) => ColumnOrderings(column));

  ColumnOrderings<String> get leadId => $composableBuilder(
      column: $table.leadId, builder: (column) => ColumnOrderings(column));

  ColumnOrderings<String> get contactId => $composableBuilder(
      column: $table.contactId, builder: (column) => ColumnOrderings(column));

  ColumnOrderings<double> get amount => $composableBuilder(
      column: $table.amount, builder: (column) => ColumnOrderings(column));

  ColumnOrderings<String> get stage => $composableBuilder(
      column: $table.stage, builder: (column) => ColumnOrderings(column));

  ColumnOrderings<String> get source => $composableBuilder(
      column: $table.source, builder: (column) => ColumnOrderings(column));

  ColumnOrderings<String> get ownerId => $composableBuilder(
      column: $table.ownerId, builder: (column) => ColumnOrderings(column));

  ColumnOrderings<DateTime> get expectedCloseDate => $composableBuilder(
      column: $table.expectedCloseDate,
      builder: (column) => ColumnOrderings(column));

  ColumnOrderings<DateTime> get createdAt => $composableBuilder(
      column: $table.createdAt, builder: (column) => ColumnOrderings(column));
}

class $$DealsTableAnnotationComposer
    extends Composer<_$AppDatabase, $DealsTable> {
  $$DealsTableAnnotationComposer({
    required super.$db,
    required super.$table,
    super.joinBuilder,
    super.$addJoinBuilderToRootComposer,
    super.$removeJoinBuilderFromRootComposer,
  });
  GeneratedColumn<String> get id =>
      $composableBuilder(column: $table.id, builder: (column) => column);

  GeneratedColumn<String> get title =>
      $composableBuilder(column: $table.title, builder: (column) => column);

  GeneratedColumn<String> get leadId =>
      $composableBuilder(column: $table.leadId, builder: (column) => column);

  GeneratedColumn<String> get contactId =>
      $composableBuilder(column: $table.contactId, builder: (column) => column);

  GeneratedColumn<double> get amount =>
      $composableBuilder(column: $table.amount, builder: (column) => column);

  GeneratedColumn<String> get stage =>
      $composableBuilder(column: $table.stage, builder: (column) => column);

  GeneratedColumn<String> get source =>
      $composableBuilder(column: $table.source, builder: (column) => column);

  GeneratedColumn<String> get ownerId =>
      $composableBuilder(column: $table.ownerId, builder: (column) => column);

  GeneratedColumn<DateTime> get expectedCloseDate => $composableBuilder(
      column: $table.expectedCloseDate, builder: (column) => column);

  GeneratedColumn<DateTime> get createdAt =>
      $composableBuilder(column: $table.createdAt, builder: (column) => column);
}

class $$DealsTableTableManager extends RootTableManager<
    _$AppDatabase,
    $DealsTable,
    Deal,
    $$DealsTableFilterComposer,
    $$DealsTableOrderingComposer,
    $$DealsTableAnnotationComposer,
    $$DealsTableCreateCompanionBuilder,
    $$DealsTableUpdateCompanionBuilder,
    (Deal, BaseReferences<_$AppDatabase, $DealsTable, Deal>),
    Deal,
    PrefetchHooks Function()> {
  $$DealsTableTableManager(_$AppDatabase db, $DealsTable table)
      : super(TableManagerState(
          db: db,
          table: table,
          createFilteringComposer: () =>
              $$DealsTableFilterComposer($db: db, $table: table),
          createOrderingComposer: () =>
              $$DealsTableOrderingComposer($db: db, $table: table),
          createComputedFieldComposer: () =>
              $$DealsTableAnnotationComposer($db: db, $table: table),
          updateCompanionCallback: ({
            Value<String> id = const Value.absent(),
            Value<String> title = const Value.absent(),
            Value<String?> leadId = const Value.absent(),
            Value<String> contactId = const Value.absent(),
            Value<double> amount = const Value.absent(),
            Value<String> stage = const Value.absent(),
            Value<String> source = const Value.absent(),
            Value<String?> ownerId = const Value.absent(),
            Value<DateTime?> expectedCloseDate = const Value.absent(),
            Value<DateTime> createdAt = const Value.absent(),
            Value<int> rowid = const Value.absent(),
          }) =>
              DealsCompanion(
            id: id,
            title: title,
            leadId: leadId,
            contactId: contactId,
            amount: amount,
            stage: stage,
            source: source,
            ownerId: ownerId,
            expectedCloseDate: expectedCloseDate,
            createdAt: createdAt,
            rowid: rowid,
          ),
          createCompanionCallback: ({
            required String id,
            required String title,
            Value<String?> leadId = const Value.absent(),
            required String contactId,
            required double amount,
            Value<String> stage = const Value.absent(),
            Value<String> source = const Value.absent(),
            Value<String?> ownerId = const Value.absent(),
            Value<DateTime?> expectedCloseDate = const Value.absent(),
            Value<DateTime> createdAt = const Value.absent(),
            Value<int> rowid = const Value.absent(),
          }) =>
              DealsCompanion.insert(
            id: id,
            title: title,
            leadId: leadId,
            contactId: contactId,
            amount: amount,
            stage: stage,
            source: source,
            ownerId: ownerId,
            expectedCloseDate: expectedCloseDate,
            createdAt: createdAt,
            rowid: rowid,
          ),
          withReferenceMapper: (p0) => p0
              .map((e) => (e.readTable(table), BaseReferences(db, table, e)))
              .toList(),
          prefetchHooksCallback: null,
        ));
}

typedef $$DealsTableProcessedTableManager = ProcessedTableManager<
    _$AppDatabase,
    $DealsTable,
    Deal,
    $$DealsTableFilterComposer,
    $$DealsTableOrderingComposer,
    $$DealsTableAnnotationComposer,
    $$DealsTableCreateCompanionBuilder,
    $$DealsTableUpdateCompanionBuilder,
    (Deal, BaseReferences<_$AppDatabase, $DealsTable, Deal>),
    Deal,
    PrefetchHooks Function()>;
typedef $$ProductsTableCreateCompanionBuilder = ProductsCompanion Function({
  required String id,
  required String sku,
  required String name,
  required double price,
  required double cost,
  Value<String> type,
  Value<String?> barcode,
  Value<String> customFields,
  Value<DateTime> createdAt,
  Value<int> rowid,
});
typedef $$ProductsTableUpdateCompanionBuilder = ProductsCompanion Function({
  Value<String> id,
  Value<String> sku,
  Value<String> name,
  Value<double> price,
  Value<double> cost,
  Value<String> type,
  Value<String?> barcode,
  Value<String> customFields,
  Value<DateTime> createdAt,
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

  ColumnFilters<String> get sku => $composableBuilder(
      column: $table.sku, builder: (column) => ColumnFilters(column));

  ColumnFilters<String> get name => $composableBuilder(
      column: $table.name, builder: (column) => ColumnFilters(column));

  ColumnFilters<double> get price => $composableBuilder(
      column: $table.price, builder: (column) => ColumnFilters(column));

  ColumnFilters<double> get cost => $composableBuilder(
      column: $table.cost, builder: (column) => ColumnFilters(column));

  ColumnFilters<String> get type => $composableBuilder(
      column: $table.type, builder: (column) => ColumnFilters(column));

  ColumnFilters<String> get barcode => $composableBuilder(
      column: $table.barcode, builder: (column) => ColumnFilters(column));

  ColumnFilters<String> get customFields => $composableBuilder(
      column: $table.customFields, builder: (column) => ColumnFilters(column));

  ColumnFilters<DateTime> get createdAt => $composableBuilder(
      column: $table.createdAt, builder: (column) => ColumnFilters(column));
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

  ColumnOrderings<String> get sku => $composableBuilder(
      column: $table.sku, builder: (column) => ColumnOrderings(column));

  ColumnOrderings<String> get name => $composableBuilder(
      column: $table.name, builder: (column) => ColumnOrderings(column));

  ColumnOrderings<double> get price => $composableBuilder(
      column: $table.price, builder: (column) => ColumnOrderings(column));

  ColumnOrderings<double> get cost => $composableBuilder(
      column: $table.cost, builder: (column) => ColumnOrderings(column));

  ColumnOrderings<String> get type => $composableBuilder(
      column: $table.type, builder: (column) => ColumnOrderings(column));

  ColumnOrderings<String> get barcode => $composableBuilder(
      column: $table.barcode, builder: (column) => ColumnOrderings(column));

  ColumnOrderings<String> get customFields => $composableBuilder(
      column: $table.customFields,
      builder: (column) => ColumnOrderings(column));

  ColumnOrderings<DateTime> get createdAt => $composableBuilder(
      column: $table.createdAt, builder: (column) => ColumnOrderings(column));
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

  GeneratedColumn<String> get sku =>
      $composableBuilder(column: $table.sku, builder: (column) => column);

  GeneratedColumn<String> get name =>
      $composableBuilder(column: $table.name, builder: (column) => column);

  GeneratedColumn<double> get price =>
      $composableBuilder(column: $table.price, builder: (column) => column);

  GeneratedColumn<double> get cost =>
      $composableBuilder(column: $table.cost, builder: (column) => column);

  GeneratedColumn<String> get type =>
      $composableBuilder(column: $table.type, builder: (column) => column);

  GeneratedColumn<String> get barcode =>
      $composableBuilder(column: $table.barcode, builder: (column) => column);

  GeneratedColumn<String> get customFields => $composableBuilder(
      column: $table.customFields, builder: (column) => column);

  GeneratedColumn<DateTime> get createdAt =>
      $composableBuilder(column: $table.createdAt, builder: (column) => column);
}

class $$ProductsTableTableManager extends RootTableManager<
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
            Value<String> sku = const Value.absent(),
            Value<String> name = const Value.absent(),
            Value<double> price = const Value.absent(),
            Value<double> cost = const Value.absent(),
            Value<String> type = const Value.absent(),
            Value<String?> barcode = const Value.absent(),
            Value<String> customFields = const Value.absent(),
            Value<DateTime> createdAt = const Value.absent(),
            Value<int> rowid = const Value.absent(),
          }) =>
              ProductsCompanion(
            id: id,
            sku: sku,
            name: name,
            price: price,
            cost: cost,
            type: type,
            barcode: barcode,
            customFields: customFields,
            createdAt: createdAt,
            rowid: rowid,
          ),
          createCompanionCallback: ({
            required String id,
            required String sku,
            required String name,
            required double price,
            required double cost,
            Value<String> type = const Value.absent(),
            Value<String?> barcode = const Value.absent(),
            Value<String> customFields = const Value.absent(),
            Value<DateTime> createdAt = const Value.absent(),
            Value<int> rowid = const Value.absent(),
          }) =>
              ProductsCompanion.insert(
            id: id,
            sku: sku,
            name: name,
            price: price,
            cost: cost,
            type: type,
            barcode: barcode,
            customFields: customFields,
            createdAt: createdAt,
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
    Product,
    $$ProductsTableFilterComposer,
    $$ProductsTableOrderingComposer,
    $$ProductsTableAnnotationComposer,
    $$ProductsTableCreateCompanionBuilder,
    $$ProductsTableUpdateCompanionBuilder,
    (Product, BaseReferences<_$AppDatabase, $ProductsTable, Product>),
    Product,
    PrefetchHooks Function()>;
typedef $$StockQuantsTableCreateCompanionBuilder = StockQuantsCompanion
    Function({
  required String id,
  required String productId,
  required String locationId,
  required double quantity,
  Value<DateTime> updatedAt,
  Value<int> rowid,
});
typedef $$StockQuantsTableUpdateCompanionBuilder = StockQuantsCompanion
    Function({
  Value<String> id,
  Value<String> productId,
  Value<String> locationId,
  Value<double> quantity,
  Value<DateTime> updatedAt,
  Value<int> rowid,
});

class $$StockQuantsTableFilterComposer
    extends Composer<_$AppDatabase, $StockQuantsTable> {
  $$StockQuantsTableFilterComposer({
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

  ColumnFilters<String> get locationId => $composableBuilder(
      column: $table.locationId, builder: (column) => ColumnFilters(column));

  ColumnFilters<double> get quantity => $composableBuilder(
      column: $table.quantity, builder: (column) => ColumnFilters(column));

  ColumnFilters<DateTime> get updatedAt => $composableBuilder(
      column: $table.updatedAt, builder: (column) => ColumnFilters(column));
}

class $$StockQuantsTableOrderingComposer
    extends Composer<_$AppDatabase, $StockQuantsTable> {
  $$StockQuantsTableOrderingComposer({
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

  ColumnOrderings<String> get locationId => $composableBuilder(
      column: $table.locationId, builder: (column) => ColumnOrderings(column));

  ColumnOrderings<double> get quantity => $composableBuilder(
      column: $table.quantity, builder: (column) => ColumnOrderings(column));

  ColumnOrderings<DateTime> get updatedAt => $composableBuilder(
      column: $table.updatedAt, builder: (column) => ColumnOrderings(column));
}

class $$StockQuantsTableAnnotationComposer
    extends Composer<_$AppDatabase, $StockQuantsTable> {
  $$StockQuantsTableAnnotationComposer({
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

  GeneratedColumn<String> get locationId => $composableBuilder(
      column: $table.locationId, builder: (column) => column);

  GeneratedColumn<double> get quantity =>
      $composableBuilder(column: $table.quantity, builder: (column) => column);

  GeneratedColumn<DateTime> get updatedAt =>
      $composableBuilder(column: $table.updatedAt, builder: (column) => column);
}

class $$StockQuantsTableTableManager extends RootTableManager<
    _$AppDatabase,
    $StockQuantsTable,
    StockQuant,
    $$StockQuantsTableFilterComposer,
    $$StockQuantsTableOrderingComposer,
    $$StockQuantsTableAnnotationComposer,
    $$StockQuantsTableCreateCompanionBuilder,
    $$StockQuantsTableUpdateCompanionBuilder,
    (StockQuant, BaseReferences<_$AppDatabase, $StockQuantsTable, StockQuant>),
    StockQuant,
    PrefetchHooks Function()> {
  $$StockQuantsTableTableManager(_$AppDatabase db, $StockQuantsTable table)
      : super(TableManagerState(
          db: db,
          table: table,
          createFilteringComposer: () =>
              $$StockQuantsTableFilterComposer($db: db, $table: table),
          createOrderingComposer: () =>
              $$StockQuantsTableOrderingComposer($db: db, $table: table),
          createComputedFieldComposer: () =>
              $$StockQuantsTableAnnotationComposer($db: db, $table: table),
          updateCompanionCallback: ({
            Value<String> id = const Value.absent(),
            Value<String> productId = const Value.absent(),
            Value<String> locationId = const Value.absent(),
            Value<double> quantity = const Value.absent(),
            Value<DateTime> updatedAt = const Value.absent(),
            Value<int> rowid = const Value.absent(),
          }) =>
              StockQuantsCompanion(
            id: id,
            productId: productId,
            locationId: locationId,
            quantity: quantity,
            updatedAt: updatedAt,
            rowid: rowid,
          ),
          createCompanionCallback: ({
            required String id,
            required String productId,
            required String locationId,
            required double quantity,
            Value<DateTime> updatedAt = const Value.absent(),
            Value<int> rowid = const Value.absent(),
          }) =>
              StockQuantsCompanion.insert(
            id: id,
            productId: productId,
            locationId: locationId,
            quantity: quantity,
            updatedAt: updatedAt,
            rowid: rowid,
          ),
          withReferenceMapper: (p0) => p0
              .map((e) => (e.readTable(table), BaseReferences(db, table, e)))
              .toList(),
          prefetchHooksCallback: null,
        ));
}

typedef $$StockQuantsTableProcessedTableManager = ProcessedTableManager<
    _$AppDatabase,
    $StockQuantsTable,
    StockQuant,
    $$StockQuantsTableFilterComposer,
    $$StockQuantsTableOrderingComposer,
    $$StockQuantsTableAnnotationComposer,
    $$StockQuantsTableCreateCompanionBuilder,
    $$StockQuantsTableUpdateCompanionBuilder,
    (StockQuant, BaseReferences<_$AppDatabase, $StockQuantsTable, StockQuant>),
    StockQuant,
    PrefetchHooks Function()>;
typedef $$StockMovesTableCreateCompanionBuilder = StockMovesCompanion Function({
  required String id,
  required String productId,
  required double quantity,
  required String sourceLocationId,
  required String destLocationId,
  Value<String> status,
  Value<DateTime> date,
  Value<int> rowid,
});
typedef $$StockMovesTableUpdateCompanionBuilder = StockMovesCompanion Function({
  Value<String> id,
  Value<String> productId,
  Value<double> quantity,
  Value<String> sourceLocationId,
  Value<String> destLocationId,
  Value<String> status,
  Value<DateTime> date,
  Value<int> rowid,
});

class $$StockMovesTableFilterComposer
    extends Composer<_$AppDatabase, $StockMovesTable> {
  $$StockMovesTableFilterComposer({
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

  ColumnFilters<double> get quantity => $composableBuilder(
      column: $table.quantity, builder: (column) => ColumnFilters(column));

  ColumnFilters<String> get sourceLocationId => $composableBuilder(
      column: $table.sourceLocationId,
      builder: (column) => ColumnFilters(column));

  ColumnFilters<String> get destLocationId => $composableBuilder(
      column: $table.destLocationId,
      builder: (column) => ColumnFilters(column));

  ColumnFilters<String> get status => $composableBuilder(
      column: $table.status, builder: (column) => ColumnFilters(column));

  ColumnFilters<DateTime> get date => $composableBuilder(
      column: $table.date, builder: (column) => ColumnFilters(column));
}

class $$StockMovesTableOrderingComposer
    extends Composer<_$AppDatabase, $StockMovesTable> {
  $$StockMovesTableOrderingComposer({
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

  ColumnOrderings<double> get quantity => $composableBuilder(
      column: $table.quantity, builder: (column) => ColumnOrderings(column));

  ColumnOrderings<String> get sourceLocationId => $composableBuilder(
      column: $table.sourceLocationId,
      builder: (column) => ColumnOrderings(column));

  ColumnOrderings<String> get destLocationId => $composableBuilder(
      column: $table.destLocationId,
      builder: (column) => ColumnOrderings(column));

  ColumnOrderings<String> get status => $composableBuilder(
      column: $table.status, builder: (column) => ColumnOrderings(column));

  ColumnOrderings<DateTime> get date => $composableBuilder(
      column: $table.date, builder: (column) => ColumnOrderings(column));
}

class $$StockMovesTableAnnotationComposer
    extends Composer<_$AppDatabase, $StockMovesTable> {
  $$StockMovesTableAnnotationComposer({
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

  GeneratedColumn<double> get quantity =>
      $composableBuilder(column: $table.quantity, builder: (column) => column);

  GeneratedColumn<String> get sourceLocationId => $composableBuilder(
      column: $table.sourceLocationId, builder: (column) => column);

  GeneratedColumn<String> get destLocationId => $composableBuilder(
      column: $table.destLocationId, builder: (column) => column);

  GeneratedColumn<String> get status =>
      $composableBuilder(column: $table.status, builder: (column) => column);

  GeneratedColumn<DateTime> get date =>
      $composableBuilder(column: $table.date, builder: (column) => column);
}

class $$StockMovesTableTableManager extends RootTableManager<
    _$AppDatabase,
    $StockMovesTable,
    StockMove,
    $$StockMovesTableFilterComposer,
    $$StockMovesTableOrderingComposer,
    $$StockMovesTableAnnotationComposer,
    $$StockMovesTableCreateCompanionBuilder,
    $$StockMovesTableUpdateCompanionBuilder,
    (StockMove, BaseReferences<_$AppDatabase, $StockMovesTable, StockMove>),
    StockMove,
    PrefetchHooks Function()> {
  $$StockMovesTableTableManager(_$AppDatabase db, $StockMovesTable table)
      : super(TableManagerState(
          db: db,
          table: table,
          createFilteringComposer: () =>
              $$StockMovesTableFilterComposer($db: db, $table: table),
          createOrderingComposer: () =>
              $$StockMovesTableOrderingComposer($db: db, $table: table),
          createComputedFieldComposer: () =>
              $$StockMovesTableAnnotationComposer($db: db, $table: table),
          updateCompanionCallback: ({
            Value<String> id = const Value.absent(),
            Value<String> productId = const Value.absent(),
            Value<double> quantity = const Value.absent(),
            Value<String> sourceLocationId = const Value.absent(),
            Value<String> destLocationId = const Value.absent(),
            Value<String> status = const Value.absent(),
            Value<DateTime> date = const Value.absent(),
            Value<int> rowid = const Value.absent(),
          }) =>
              StockMovesCompanion(
            id: id,
            productId: productId,
            quantity: quantity,
            sourceLocationId: sourceLocationId,
            destLocationId: destLocationId,
            status: status,
            date: date,
            rowid: rowid,
          ),
          createCompanionCallback: ({
            required String id,
            required String productId,
            required double quantity,
            required String sourceLocationId,
            required String destLocationId,
            Value<String> status = const Value.absent(),
            Value<DateTime> date = const Value.absent(),
            Value<int> rowid = const Value.absent(),
          }) =>
              StockMovesCompanion.insert(
            id: id,
            productId: productId,
            quantity: quantity,
            sourceLocationId: sourceLocationId,
            destLocationId: destLocationId,
            status: status,
            date: date,
            rowid: rowid,
          ),
          withReferenceMapper: (p0) => p0
              .map((e) => (e.readTable(table), BaseReferences(db, table, e)))
              .toList(),
          prefetchHooksCallback: null,
        ));
}

typedef $$StockMovesTableProcessedTableManager = ProcessedTableManager<
    _$AppDatabase,
    $StockMovesTable,
    StockMove,
    $$StockMovesTableFilterComposer,
    $$StockMovesTableOrderingComposer,
    $$StockMovesTableAnnotationComposer,
    $$StockMovesTableCreateCompanionBuilder,
    $$StockMovesTableUpdateCompanionBuilder,
    (StockMove, BaseReferences<_$AppDatabase, $StockMovesTable, StockMove>),
    StockMove,
    PrefetchHooks Function()>;
typedef $$TrustScoresTableCreateCompanionBuilder = TrustScoresCompanion
    Function({
  required String userId,
  Value<double> overallScore,
  Value<int> referralCount,
  Value<String?> referredBy,
  Value<int> completedOrders,
  Value<double> avgRating,
  Value<DateTime> memberSince,
  Value<String> level,
  Value<bool> kycVerified,
  Value<int> rowid,
});
typedef $$TrustScoresTableUpdateCompanionBuilder = TrustScoresCompanion
    Function({
  Value<String> userId,
  Value<double> overallScore,
  Value<int> referralCount,
  Value<String?> referredBy,
  Value<int> completedOrders,
  Value<double> avgRating,
  Value<DateTime> memberSince,
  Value<String> level,
  Value<bool> kycVerified,
  Value<int> rowid,
});

class $$TrustScoresTableFilterComposer
    extends Composer<_$AppDatabase, $TrustScoresTable> {
  $$TrustScoresTableFilterComposer({
    required super.$db,
    required super.$table,
    super.joinBuilder,
    super.$addJoinBuilderToRootComposer,
    super.$removeJoinBuilderFromRootComposer,
  });
  ColumnFilters<String> get userId => $composableBuilder(
      column: $table.userId, builder: (column) => ColumnFilters(column));

  ColumnFilters<double> get overallScore => $composableBuilder(
      column: $table.overallScore, builder: (column) => ColumnFilters(column));

  ColumnFilters<int> get referralCount => $composableBuilder(
      column: $table.referralCount, builder: (column) => ColumnFilters(column));

  ColumnFilters<String> get referredBy => $composableBuilder(
      column: $table.referredBy, builder: (column) => ColumnFilters(column));

  ColumnFilters<int> get completedOrders => $composableBuilder(
      column: $table.completedOrders,
      builder: (column) => ColumnFilters(column));

  ColumnFilters<double> get avgRating => $composableBuilder(
      column: $table.avgRating, builder: (column) => ColumnFilters(column));

  ColumnFilters<DateTime> get memberSince => $composableBuilder(
      column: $table.memberSince, builder: (column) => ColumnFilters(column));

  ColumnFilters<String> get level => $composableBuilder(
      column: $table.level, builder: (column) => ColumnFilters(column));

  ColumnFilters<bool> get kycVerified => $composableBuilder(
      column: $table.kycVerified, builder: (column) => ColumnFilters(column));
}

class $$TrustScoresTableOrderingComposer
    extends Composer<_$AppDatabase, $TrustScoresTable> {
  $$TrustScoresTableOrderingComposer({
    required super.$db,
    required super.$table,
    super.joinBuilder,
    super.$addJoinBuilderToRootComposer,
    super.$removeJoinBuilderFromRootComposer,
  });
  ColumnOrderings<String> get userId => $composableBuilder(
      column: $table.userId, builder: (column) => ColumnOrderings(column));

  ColumnOrderings<double> get overallScore => $composableBuilder(
      column: $table.overallScore,
      builder: (column) => ColumnOrderings(column));

  ColumnOrderings<int> get referralCount => $composableBuilder(
      column: $table.referralCount,
      builder: (column) => ColumnOrderings(column));

  ColumnOrderings<String> get referredBy => $composableBuilder(
      column: $table.referredBy, builder: (column) => ColumnOrderings(column));

  ColumnOrderings<int> get completedOrders => $composableBuilder(
      column: $table.completedOrders,
      builder: (column) => ColumnOrderings(column));

  ColumnOrderings<double> get avgRating => $composableBuilder(
      column: $table.avgRating, builder: (column) => ColumnOrderings(column));

  ColumnOrderings<DateTime> get memberSince => $composableBuilder(
      column: $table.memberSince, builder: (column) => ColumnOrderings(column));

  ColumnOrderings<String> get level => $composableBuilder(
      column: $table.level, builder: (column) => ColumnOrderings(column));

  ColumnOrderings<bool> get kycVerified => $composableBuilder(
      column: $table.kycVerified, builder: (column) => ColumnOrderings(column));
}

class $$TrustScoresTableAnnotationComposer
    extends Composer<_$AppDatabase, $TrustScoresTable> {
  $$TrustScoresTableAnnotationComposer({
    required super.$db,
    required super.$table,
    super.joinBuilder,
    super.$addJoinBuilderToRootComposer,
    super.$removeJoinBuilderFromRootComposer,
  });
  GeneratedColumn<String> get userId =>
      $composableBuilder(column: $table.userId, builder: (column) => column);

  GeneratedColumn<double> get overallScore => $composableBuilder(
      column: $table.overallScore, builder: (column) => column);

  GeneratedColumn<int> get referralCount => $composableBuilder(
      column: $table.referralCount, builder: (column) => column);

  GeneratedColumn<String> get referredBy => $composableBuilder(
      column: $table.referredBy, builder: (column) => column);

  GeneratedColumn<int> get completedOrders => $composableBuilder(
      column: $table.completedOrders, builder: (column) => column);

  GeneratedColumn<double> get avgRating =>
      $composableBuilder(column: $table.avgRating, builder: (column) => column);

  GeneratedColumn<DateTime> get memberSince => $composableBuilder(
      column: $table.memberSince, builder: (column) => column);

  GeneratedColumn<String> get level =>
      $composableBuilder(column: $table.level, builder: (column) => column);

  GeneratedColumn<bool> get kycVerified => $composableBuilder(
      column: $table.kycVerified, builder: (column) => column);
}

class $$TrustScoresTableTableManager extends RootTableManager<
    _$AppDatabase,
    $TrustScoresTable,
    TrustScore,
    $$TrustScoresTableFilterComposer,
    $$TrustScoresTableOrderingComposer,
    $$TrustScoresTableAnnotationComposer,
    $$TrustScoresTableCreateCompanionBuilder,
    $$TrustScoresTableUpdateCompanionBuilder,
    (TrustScore, BaseReferences<_$AppDatabase, $TrustScoresTable, TrustScore>),
    TrustScore,
    PrefetchHooks Function()> {
  $$TrustScoresTableTableManager(_$AppDatabase db, $TrustScoresTable table)
      : super(TableManagerState(
          db: db,
          table: table,
          createFilteringComposer: () =>
              $$TrustScoresTableFilterComposer($db: db, $table: table),
          createOrderingComposer: () =>
              $$TrustScoresTableOrderingComposer($db: db, $table: table),
          createComputedFieldComposer: () =>
              $$TrustScoresTableAnnotationComposer($db: db, $table: table),
          updateCompanionCallback: ({
            Value<String> userId = const Value.absent(),
            Value<double> overallScore = const Value.absent(),
            Value<int> referralCount = const Value.absent(),
            Value<String?> referredBy = const Value.absent(),
            Value<int> completedOrders = const Value.absent(),
            Value<double> avgRating = const Value.absent(),
            Value<DateTime> memberSince = const Value.absent(),
            Value<String> level = const Value.absent(),
            Value<bool> kycVerified = const Value.absent(),
            Value<int> rowid = const Value.absent(),
          }) =>
              TrustScoresCompanion(
            userId: userId,
            overallScore: overallScore,
            referralCount: referralCount,
            referredBy: referredBy,
            completedOrders: completedOrders,
            avgRating: avgRating,
            memberSince: memberSince,
            level: level,
            kycVerified: kycVerified,
            rowid: rowid,
          ),
          createCompanionCallback: ({
            required String userId,
            Value<double> overallScore = const Value.absent(),
            Value<int> referralCount = const Value.absent(),
            Value<String?> referredBy = const Value.absent(),
            Value<int> completedOrders = const Value.absent(),
            Value<double> avgRating = const Value.absent(),
            Value<DateTime> memberSince = const Value.absent(),
            Value<String> level = const Value.absent(),
            Value<bool> kycVerified = const Value.absent(),
            Value<int> rowid = const Value.absent(),
          }) =>
              TrustScoresCompanion.insert(
            userId: userId,
            overallScore: overallScore,
            referralCount: referralCount,
            referredBy: referredBy,
            completedOrders: completedOrders,
            avgRating: avgRating,
            memberSince: memberSince,
            level: level,
            kycVerified: kycVerified,
            rowid: rowid,
          ),
          withReferenceMapper: (p0) => p0
              .map((e) => (e.readTable(table), BaseReferences(db, table, e)))
              .toList(),
          prefetchHooksCallback: null,
        ));
}

typedef $$TrustScoresTableProcessedTableManager = ProcessedTableManager<
    _$AppDatabase,
    $TrustScoresTable,
    TrustScore,
    $$TrustScoresTableFilterComposer,
    $$TrustScoresTableOrderingComposer,
    $$TrustScoresTableAnnotationComposer,
    $$TrustScoresTableCreateCompanionBuilder,
    $$TrustScoresTableUpdateCompanionBuilder,
    (TrustScore, BaseReferences<_$AppDatabase, $TrustScoresTable, TrustScore>),
    TrustScore,
    PrefetchHooks Function()>;
typedef $$ReferralsTableCreateCompanionBuilder = ReferralsCompanion Function({
  required String id,
  required String inviterId,
  Value<String?> inviteeId,
  required String contactInfo,
  Value<String> status,
  Value<DateTime> createdAt,
  Value<DateTime?> acceptedAt,
  Value<int> rowid,
});
typedef $$ReferralsTableUpdateCompanionBuilder = ReferralsCompanion Function({
  Value<String> id,
  Value<String> inviterId,
  Value<String?> inviteeId,
  Value<String> contactInfo,
  Value<String> status,
  Value<DateTime> createdAt,
  Value<DateTime?> acceptedAt,
  Value<int> rowid,
});

class $$ReferralsTableFilterComposer
    extends Composer<_$AppDatabase, $ReferralsTable> {
  $$ReferralsTableFilterComposer({
    required super.$db,
    required super.$table,
    super.joinBuilder,
    super.$addJoinBuilderToRootComposer,
    super.$removeJoinBuilderFromRootComposer,
  });
  ColumnFilters<String> get id => $composableBuilder(
      column: $table.id, builder: (column) => ColumnFilters(column));

  ColumnFilters<String> get inviterId => $composableBuilder(
      column: $table.inviterId, builder: (column) => ColumnFilters(column));

  ColumnFilters<String> get inviteeId => $composableBuilder(
      column: $table.inviteeId, builder: (column) => ColumnFilters(column));

  ColumnFilters<String> get contactInfo => $composableBuilder(
      column: $table.contactInfo, builder: (column) => ColumnFilters(column));

  ColumnFilters<String> get status => $composableBuilder(
      column: $table.status, builder: (column) => ColumnFilters(column));

  ColumnFilters<DateTime> get createdAt => $composableBuilder(
      column: $table.createdAt, builder: (column) => ColumnFilters(column));

  ColumnFilters<DateTime> get acceptedAt => $composableBuilder(
      column: $table.acceptedAt, builder: (column) => ColumnFilters(column));
}

class $$ReferralsTableOrderingComposer
    extends Composer<_$AppDatabase, $ReferralsTable> {
  $$ReferralsTableOrderingComposer({
    required super.$db,
    required super.$table,
    super.joinBuilder,
    super.$addJoinBuilderToRootComposer,
    super.$removeJoinBuilderFromRootComposer,
  });
  ColumnOrderings<String> get id => $composableBuilder(
      column: $table.id, builder: (column) => ColumnOrderings(column));

  ColumnOrderings<String> get inviterId => $composableBuilder(
      column: $table.inviterId, builder: (column) => ColumnOrderings(column));

  ColumnOrderings<String> get inviteeId => $composableBuilder(
      column: $table.inviteeId, builder: (column) => ColumnOrderings(column));

  ColumnOrderings<String> get contactInfo => $composableBuilder(
      column: $table.contactInfo, builder: (column) => ColumnOrderings(column));

  ColumnOrderings<String> get status => $composableBuilder(
      column: $table.status, builder: (column) => ColumnOrderings(column));

  ColumnOrderings<DateTime> get createdAt => $composableBuilder(
      column: $table.createdAt, builder: (column) => ColumnOrderings(column));

  ColumnOrderings<DateTime> get acceptedAt => $composableBuilder(
      column: $table.acceptedAt, builder: (column) => ColumnOrderings(column));
}

class $$ReferralsTableAnnotationComposer
    extends Composer<_$AppDatabase, $ReferralsTable> {
  $$ReferralsTableAnnotationComposer({
    required super.$db,
    required super.$table,
    super.joinBuilder,
    super.$addJoinBuilderToRootComposer,
    super.$removeJoinBuilderFromRootComposer,
  });
  GeneratedColumn<String> get id =>
      $composableBuilder(column: $table.id, builder: (column) => column);

  GeneratedColumn<String> get inviterId =>
      $composableBuilder(column: $table.inviterId, builder: (column) => column);

  GeneratedColumn<String> get inviteeId =>
      $composableBuilder(column: $table.inviteeId, builder: (column) => column);

  GeneratedColumn<String> get contactInfo => $composableBuilder(
      column: $table.contactInfo, builder: (column) => column);

  GeneratedColumn<String> get status =>
      $composableBuilder(column: $table.status, builder: (column) => column);

  GeneratedColumn<DateTime> get createdAt =>
      $composableBuilder(column: $table.createdAt, builder: (column) => column);

  GeneratedColumn<DateTime> get acceptedAt => $composableBuilder(
      column: $table.acceptedAt, builder: (column) => column);
}

class $$ReferralsTableTableManager extends RootTableManager<
    _$AppDatabase,
    $ReferralsTable,
    Referral,
    $$ReferralsTableFilterComposer,
    $$ReferralsTableOrderingComposer,
    $$ReferralsTableAnnotationComposer,
    $$ReferralsTableCreateCompanionBuilder,
    $$ReferralsTableUpdateCompanionBuilder,
    (Referral, BaseReferences<_$AppDatabase, $ReferralsTable, Referral>),
    Referral,
    PrefetchHooks Function()> {
  $$ReferralsTableTableManager(_$AppDatabase db, $ReferralsTable table)
      : super(TableManagerState(
          db: db,
          table: table,
          createFilteringComposer: () =>
              $$ReferralsTableFilterComposer($db: db, $table: table),
          createOrderingComposer: () =>
              $$ReferralsTableOrderingComposer($db: db, $table: table),
          createComputedFieldComposer: () =>
              $$ReferralsTableAnnotationComposer($db: db, $table: table),
          updateCompanionCallback: ({
            Value<String> id = const Value.absent(),
            Value<String> inviterId = const Value.absent(),
            Value<String?> inviteeId = const Value.absent(),
            Value<String> contactInfo = const Value.absent(),
            Value<String> status = const Value.absent(),
            Value<DateTime> createdAt = const Value.absent(),
            Value<DateTime?> acceptedAt = const Value.absent(),
            Value<int> rowid = const Value.absent(),
          }) =>
              ReferralsCompanion(
            id: id,
            inviterId: inviterId,
            inviteeId: inviteeId,
            contactInfo: contactInfo,
            status: status,
            createdAt: createdAt,
            acceptedAt: acceptedAt,
            rowid: rowid,
          ),
          createCompanionCallback: ({
            required String id,
            required String inviterId,
            Value<String?> inviteeId = const Value.absent(),
            required String contactInfo,
            Value<String> status = const Value.absent(),
            Value<DateTime> createdAt = const Value.absent(),
            Value<DateTime?> acceptedAt = const Value.absent(),
            Value<int> rowid = const Value.absent(),
          }) =>
              ReferralsCompanion.insert(
            id: id,
            inviterId: inviterId,
            inviteeId: inviteeId,
            contactInfo: contactInfo,
            status: status,
            createdAt: createdAt,
            acceptedAt: acceptedAt,
            rowid: rowid,
          ),
          withReferenceMapper: (p0) => p0
              .map((e) => (e.readTable(table), BaseReferences(db, table, e)))
              .toList(),
          prefetchHooksCallback: null,
        ));
}

typedef $$ReferralsTableProcessedTableManager = ProcessedTableManager<
    _$AppDatabase,
    $ReferralsTable,
    Referral,
    $$ReferralsTableFilterComposer,
    $$ReferralsTableOrderingComposer,
    $$ReferralsTableAnnotationComposer,
    $$ReferralsTableCreateCompanionBuilder,
    $$ReferralsTableUpdateCompanionBuilder,
    (Referral, BaseReferences<_$AppDatabase, $ReferralsTable, Referral>),
    Referral,
    PrefetchHooks Function()>;
typedef $$ServiceListingsTableCreateCompanionBuilder = ServiceListingsCompanion
    Function({
  required String id,
  required String providerId,
  required String serviceType,
  required String title,
  required String description,
  Value<double?> priceMin,
  Value<double?> priceMax,
  Value<String?> location,
  Value<bool> isAvailable,
  Value<double> rating,
  Value<int> completedCount,
  Value<String?> tags,
  Value<DateTime> createdAt,
  Value<int> rowid,
});
typedef $$ServiceListingsTableUpdateCompanionBuilder = ServiceListingsCompanion
    Function({
  Value<String> id,
  Value<String> providerId,
  Value<String> serviceType,
  Value<String> title,
  Value<String> description,
  Value<double?> priceMin,
  Value<double?> priceMax,
  Value<String?> location,
  Value<bool> isAvailable,
  Value<double> rating,
  Value<int> completedCount,
  Value<String?> tags,
  Value<DateTime> createdAt,
  Value<int> rowid,
});

class $$ServiceListingsTableFilterComposer
    extends Composer<_$AppDatabase, $ServiceListingsTable> {
  $$ServiceListingsTableFilterComposer({
    required super.$db,
    required super.$table,
    super.joinBuilder,
    super.$addJoinBuilderToRootComposer,
    super.$removeJoinBuilderFromRootComposer,
  });
  ColumnFilters<String> get id => $composableBuilder(
      column: $table.id, builder: (column) => ColumnFilters(column));

  ColumnFilters<String> get providerId => $composableBuilder(
      column: $table.providerId, builder: (column) => ColumnFilters(column));

  ColumnFilters<String> get serviceType => $composableBuilder(
      column: $table.serviceType, builder: (column) => ColumnFilters(column));

  ColumnFilters<String> get title => $composableBuilder(
      column: $table.title, builder: (column) => ColumnFilters(column));

  ColumnFilters<String> get description => $composableBuilder(
      column: $table.description, builder: (column) => ColumnFilters(column));

  ColumnFilters<double> get priceMin => $composableBuilder(
      column: $table.priceMin, builder: (column) => ColumnFilters(column));

  ColumnFilters<double> get priceMax => $composableBuilder(
      column: $table.priceMax, builder: (column) => ColumnFilters(column));

  ColumnFilters<String> get location => $composableBuilder(
      column: $table.location, builder: (column) => ColumnFilters(column));

  ColumnFilters<bool> get isAvailable => $composableBuilder(
      column: $table.isAvailable, builder: (column) => ColumnFilters(column));

  ColumnFilters<double> get rating => $composableBuilder(
      column: $table.rating, builder: (column) => ColumnFilters(column));

  ColumnFilters<int> get completedCount => $composableBuilder(
      column: $table.completedCount,
      builder: (column) => ColumnFilters(column));

  ColumnFilters<String> get tags => $composableBuilder(
      column: $table.tags, builder: (column) => ColumnFilters(column));

  ColumnFilters<DateTime> get createdAt => $composableBuilder(
      column: $table.createdAt, builder: (column) => ColumnFilters(column));
}

class $$ServiceListingsTableOrderingComposer
    extends Composer<_$AppDatabase, $ServiceListingsTable> {
  $$ServiceListingsTableOrderingComposer({
    required super.$db,
    required super.$table,
    super.joinBuilder,
    super.$addJoinBuilderToRootComposer,
    super.$removeJoinBuilderFromRootComposer,
  });
  ColumnOrderings<String> get id => $composableBuilder(
      column: $table.id, builder: (column) => ColumnOrderings(column));

  ColumnOrderings<String> get providerId => $composableBuilder(
      column: $table.providerId, builder: (column) => ColumnOrderings(column));

  ColumnOrderings<String> get serviceType => $composableBuilder(
      column: $table.serviceType, builder: (column) => ColumnOrderings(column));

  ColumnOrderings<String> get title => $composableBuilder(
      column: $table.title, builder: (column) => ColumnOrderings(column));

  ColumnOrderings<String> get description => $composableBuilder(
      column: $table.description, builder: (column) => ColumnOrderings(column));

  ColumnOrderings<double> get priceMin => $composableBuilder(
      column: $table.priceMin, builder: (column) => ColumnOrderings(column));

  ColumnOrderings<double> get priceMax => $composableBuilder(
      column: $table.priceMax, builder: (column) => ColumnOrderings(column));

  ColumnOrderings<String> get location => $composableBuilder(
      column: $table.location, builder: (column) => ColumnOrderings(column));

  ColumnOrderings<bool> get isAvailable => $composableBuilder(
      column: $table.isAvailable, builder: (column) => ColumnOrderings(column));

  ColumnOrderings<double> get rating => $composableBuilder(
      column: $table.rating, builder: (column) => ColumnOrderings(column));

  ColumnOrderings<int> get completedCount => $composableBuilder(
      column: $table.completedCount,
      builder: (column) => ColumnOrderings(column));

  ColumnOrderings<String> get tags => $composableBuilder(
      column: $table.tags, builder: (column) => ColumnOrderings(column));

  ColumnOrderings<DateTime> get createdAt => $composableBuilder(
      column: $table.createdAt, builder: (column) => ColumnOrderings(column));
}

class $$ServiceListingsTableAnnotationComposer
    extends Composer<_$AppDatabase, $ServiceListingsTable> {
  $$ServiceListingsTableAnnotationComposer({
    required super.$db,
    required super.$table,
    super.joinBuilder,
    super.$addJoinBuilderToRootComposer,
    super.$removeJoinBuilderFromRootComposer,
  });
  GeneratedColumn<String> get id =>
      $composableBuilder(column: $table.id, builder: (column) => column);

  GeneratedColumn<String> get providerId => $composableBuilder(
      column: $table.providerId, builder: (column) => column);

  GeneratedColumn<String> get serviceType => $composableBuilder(
      column: $table.serviceType, builder: (column) => column);

  GeneratedColumn<String> get title =>
      $composableBuilder(column: $table.title, builder: (column) => column);

  GeneratedColumn<String> get description => $composableBuilder(
      column: $table.description, builder: (column) => column);

  GeneratedColumn<double> get priceMin =>
      $composableBuilder(column: $table.priceMin, builder: (column) => column);

  GeneratedColumn<double> get priceMax =>
      $composableBuilder(column: $table.priceMax, builder: (column) => column);

  GeneratedColumn<String> get location =>
      $composableBuilder(column: $table.location, builder: (column) => column);

  GeneratedColumn<bool> get isAvailable => $composableBuilder(
      column: $table.isAvailable, builder: (column) => column);

  GeneratedColumn<double> get rating =>
      $composableBuilder(column: $table.rating, builder: (column) => column);

  GeneratedColumn<int> get completedCount => $composableBuilder(
      column: $table.completedCount, builder: (column) => column);

  GeneratedColumn<String> get tags =>
      $composableBuilder(column: $table.tags, builder: (column) => column);

  GeneratedColumn<DateTime> get createdAt =>
      $composableBuilder(column: $table.createdAt, builder: (column) => column);
}

class $$ServiceListingsTableTableManager extends RootTableManager<
    _$AppDatabase,
    $ServiceListingsTable,
    ServiceListing,
    $$ServiceListingsTableFilterComposer,
    $$ServiceListingsTableOrderingComposer,
    $$ServiceListingsTableAnnotationComposer,
    $$ServiceListingsTableCreateCompanionBuilder,
    $$ServiceListingsTableUpdateCompanionBuilder,
    (
      ServiceListing,
      BaseReferences<_$AppDatabase, $ServiceListingsTable, ServiceListing>
    ),
    ServiceListing,
    PrefetchHooks Function()> {
  $$ServiceListingsTableTableManager(
      _$AppDatabase db, $ServiceListingsTable table)
      : super(TableManagerState(
          db: db,
          table: table,
          createFilteringComposer: () =>
              $$ServiceListingsTableFilterComposer($db: db, $table: table),
          createOrderingComposer: () =>
              $$ServiceListingsTableOrderingComposer($db: db, $table: table),
          createComputedFieldComposer: () =>
              $$ServiceListingsTableAnnotationComposer($db: db, $table: table),
          updateCompanionCallback: ({
            Value<String> id = const Value.absent(),
            Value<String> providerId = const Value.absent(),
            Value<String> serviceType = const Value.absent(),
            Value<String> title = const Value.absent(),
            Value<String> description = const Value.absent(),
            Value<double?> priceMin = const Value.absent(),
            Value<double?> priceMax = const Value.absent(),
            Value<String?> location = const Value.absent(),
            Value<bool> isAvailable = const Value.absent(),
            Value<double> rating = const Value.absent(),
            Value<int> completedCount = const Value.absent(),
            Value<String?> tags = const Value.absent(),
            Value<DateTime> createdAt = const Value.absent(),
            Value<int> rowid = const Value.absent(),
          }) =>
              ServiceListingsCompanion(
            id: id,
            providerId: providerId,
            serviceType: serviceType,
            title: title,
            description: description,
            priceMin: priceMin,
            priceMax: priceMax,
            location: location,
            isAvailable: isAvailable,
            rating: rating,
            completedCount: completedCount,
            tags: tags,
            createdAt: createdAt,
            rowid: rowid,
          ),
          createCompanionCallback: ({
            required String id,
            required String providerId,
            required String serviceType,
            required String title,
            required String description,
            Value<double?> priceMin = const Value.absent(),
            Value<double?> priceMax = const Value.absent(),
            Value<String?> location = const Value.absent(),
            Value<bool> isAvailable = const Value.absent(),
            Value<double> rating = const Value.absent(),
            Value<int> completedCount = const Value.absent(),
            Value<String?> tags = const Value.absent(),
            Value<DateTime> createdAt = const Value.absent(),
            Value<int> rowid = const Value.absent(),
          }) =>
              ServiceListingsCompanion.insert(
            id: id,
            providerId: providerId,
            serviceType: serviceType,
            title: title,
            description: description,
            priceMin: priceMin,
            priceMax: priceMax,
            location: location,
            isAvailable: isAvailable,
            rating: rating,
            completedCount: completedCount,
            tags: tags,
            createdAt: createdAt,
            rowid: rowid,
          ),
          withReferenceMapper: (p0) => p0
              .map((e) => (e.readTable(table), BaseReferences(db, table, e)))
              .toList(),
          prefetchHooksCallback: null,
        ));
}

typedef $$ServiceListingsTableProcessedTableManager = ProcessedTableManager<
    _$AppDatabase,
    $ServiceListingsTable,
    ServiceListing,
    $$ServiceListingsTableFilterComposer,
    $$ServiceListingsTableOrderingComposer,
    $$ServiceListingsTableAnnotationComposer,
    $$ServiceListingsTableCreateCompanionBuilder,
    $$ServiceListingsTableUpdateCompanionBuilder,
    (
      ServiceListing,
      BaseReferences<_$AppDatabase, $ServiceListingsTable, ServiceListing>
    ),
    ServiceListing,
    PrefetchHooks Function()>;
typedef $$ServiceOrdersTableCreateCompanionBuilder = ServiceOrdersCompanion
    Function({
  required String id,
  required String consumerId,
  required String providerId,
  required String serviceListingId,
  Value<String> status,
  required String description,
  Value<DateTime?> scheduledAt,
  Value<DateTime?> completedAt,
  Value<double?> totalPrice,
  Value<DateTime> createdAt,
  Value<int> rowid,
});
typedef $$ServiceOrdersTableUpdateCompanionBuilder = ServiceOrdersCompanion
    Function({
  Value<String> id,
  Value<String> consumerId,
  Value<String> providerId,
  Value<String> serviceListingId,
  Value<String> status,
  Value<String> description,
  Value<DateTime?> scheduledAt,
  Value<DateTime?> completedAt,
  Value<double?> totalPrice,
  Value<DateTime> createdAt,
  Value<int> rowid,
});

class $$ServiceOrdersTableFilterComposer
    extends Composer<_$AppDatabase, $ServiceOrdersTable> {
  $$ServiceOrdersTableFilterComposer({
    required super.$db,
    required super.$table,
    super.joinBuilder,
    super.$addJoinBuilderToRootComposer,
    super.$removeJoinBuilderFromRootComposer,
  });
  ColumnFilters<String> get id => $composableBuilder(
      column: $table.id, builder: (column) => ColumnFilters(column));

  ColumnFilters<String> get consumerId => $composableBuilder(
      column: $table.consumerId, builder: (column) => ColumnFilters(column));

  ColumnFilters<String> get providerId => $composableBuilder(
      column: $table.providerId, builder: (column) => ColumnFilters(column));

  ColumnFilters<String> get serviceListingId => $composableBuilder(
      column: $table.serviceListingId,
      builder: (column) => ColumnFilters(column));

  ColumnFilters<String> get status => $composableBuilder(
      column: $table.status, builder: (column) => ColumnFilters(column));

  ColumnFilters<String> get description => $composableBuilder(
      column: $table.description, builder: (column) => ColumnFilters(column));

  ColumnFilters<DateTime> get scheduledAt => $composableBuilder(
      column: $table.scheduledAt, builder: (column) => ColumnFilters(column));

  ColumnFilters<DateTime> get completedAt => $composableBuilder(
      column: $table.completedAt, builder: (column) => ColumnFilters(column));

  ColumnFilters<double> get totalPrice => $composableBuilder(
      column: $table.totalPrice, builder: (column) => ColumnFilters(column));

  ColumnFilters<DateTime> get createdAt => $composableBuilder(
      column: $table.createdAt, builder: (column) => ColumnFilters(column));
}

class $$ServiceOrdersTableOrderingComposer
    extends Composer<_$AppDatabase, $ServiceOrdersTable> {
  $$ServiceOrdersTableOrderingComposer({
    required super.$db,
    required super.$table,
    super.joinBuilder,
    super.$addJoinBuilderToRootComposer,
    super.$removeJoinBuilderFromRootComposer,
  });
  ColumnOrderings<String> get id => $composableBuilder(
      column: $table.id, builder: (column) => ColumnOrderings(column));

  ColumnOrderings<String> get consumerId => $composableBuilder(
      column: $table.consumerId, builder: (column) => ColumnOrderings(column));

  ColumnOrderings<String> get providerId => $composableBuilder(
      column: $table.providerId, builder: (column) => ColumnOrderings(column));

  ColumnOrderings<String> get serviceListingId => $composableBuilder(
      column: $table.serviceListingId,
      builder: (column) => ColumnOrderings(column));

  ColumnOrderings<String> get status => $composableBuilder(
      column: $table.status, builder: (column) => ColumnOrderings(column));

  ColumnOrderings<String> get description => $composableBuilder(
      column: $table.description, builder: (column) => ColumnOrderings(column));

  ColumnOrderings<DateTime> get scheduledAt => $composableBuilder(
      column: $table.scheduledAt, builder: (column) => ColumnOrderings(column));

  ColumnOrderings<DateTime> get completedAt => $composableBuilder(
      column: $table.completedAt, builder: (column) => ColumnOrderings(column));

  ColumnOrderings<double> get totalPrice => $composableBuilder(
      column: $table.totalPrice, builder: (column) => ColumnOrderings(column));

  ColumnOrderings<DateTime> get createdAt => $composableBuilder(
      column: $table.createdAt, builder: (column) => ColumnOrderings(column));
}

class $$ServiceOrdersTableAnnotationComposer
    extends Composer<_$AppDatabase, $ServiceOrdersTable> {
  $$ServiceOrdersTableAnnotationComposer({
    required super.$db,
    required super.$table,
    super.joinBuilder,
    super.$addJoinBuilderToRootComposer,
    super.$removeJoinBuilderFromRootComposer,
  });
  GeneratedColumn<String> get id =>
      $composableBuilder(column: $table.id, builder: (column) => column);

  GeneratedColumn<String> get consumerId => $composableBuilder(
      column: $table.consumerId, builder: (column) => column);

  GeneratedColumn<String> get providerId => $composableBuilder(
      column: $table.providerId, builder: (column) => column);

  GeneratedColumn<String> get serviceListingId => $composableBuilder(
      column: $table.serviceListingId, builder: (column) => column);

  GeneratedColumn<String> get status =>
      $composableBuilder(column: $table.status, builder: (column) => column);

  GeneratedColumn<String> get description => $composableBuilder(
      column: $table.description, builder: (column) => column);

  GeneratedColumn<DateTime> get scheduledAt => $composableBuilder(
      column: $table.scheduledAt, builder: (column) => column);

  GeneratedColumn<DateTime> get completedAt => $composableBuilder(
      column: $table.completedAt, builder: (column) => column);

  GeneratedColumn<double> get totalPrice => $composableBuilder(
      column: $table.totalPrice, builder: (column) => column);

  GeneratedColumn<DateTime> get createdAt =>
      $composableBuilder(column: $table.createdAt, builder: (column) => column);
}

class $$ServiceOrdersTableTableManager extends RootTableManager<
    _$AppDatabase,
    $ServiceOrdersTable,
    ServiceOrder,
    $$ServiceOrdersTableFilterComposer,
    $$ServiceOrdersTableOrderingComposer,
    $$ServiceOrdersTableAnnotationComposer,
    $$ServiceOrdersTableCreateCompanionBuilder,
    $$ServiceOrdersTableUpdateCompanionBuilder,
    (
      ServiceOrder,
      BaseReferences<_$AppDatabase, $ServiceOrdersTable, ServiceOrder>
    ),
    ServiceOrder,
    PrefetchHooks Function()> {
  $$ServiceOrdersTableTableManager(_$AppDatabase db, $ServiceOrdersTable table)
      : super(TableManagerState(
          db: db,
          table: table,
          createFilteringComposer: () =>
              $$ServiceOrdersTableFilterComposer($db: db, $table: table),
          createOrderingComposer: () =>
              $$ServiceOrdersTableOrderingComposer($db: db, $table: table),
          createComputedFieldComposer: () =>
              $$ServiceOrdersTableAnnotationComposer($db: db, $table: table),
          updateCompanionCallback: ({
            Value<String> id = const Value.absent(),
            Value<String> consumerId = const Value.absent(),
            Value<String> providerId = const Value.absent(),
            Value<String> serviceListingId = const Value.absent(),
            Value<String> status = const Value.absent(),
            Value<String> description = const Value.absent(),
            Value<DateTime?> scheduledAt = const Value.absent(),
            Value<DateTime?> completedAt = const Value.absent(),
            Value<double?> totalPrice = const Value.absent(),
            Value<DateTime> createdAt = const Value.absent(),
            Value<int> rowid = const Value.absent(),
          }) =>
              ServiceOrdersCompanion(
            id: id,
            consumerId: consumerId,
            providerId: providerId,
            serviceListingId: serviceListingId,
            status: status,
            description: description,
            scheduledAt: scheduledAt,
            completedAt: completedAt,
            totalPrice: totalPrice,
            createdAt: createdAt,
            rowid: rowid,
          ),
          createCompanionCallback: ({
            required String id,
            required String consumerId,
            required String providerId,
            required String serviceListingId,
            Value<String> status = const Value.absent(),
            required String description,
            Value<DateTime?> scheduledAt = const Value.absent(),
            Value<DateTime?> completedAt = const Value.absent(),
            Value<double?> totalPrice = const Value.absent(),
            Value<DateTime> createdAt = const Value.absent(),
            Value<int> rowid = const Value.absent(),
          }) =>
              ServiceOrdersCompanion.insert(
            id: id,
            consumerId: consumerId,
            providerId: providerId,
            serviceListingId: serviceListingId,
            status: status,
            description: description,
            scheduledAt: scheduledAt,
            completedAt: completedAt,
            totalPrice: totalPrice,
            createdAt: createdAt,
            rowid: rowid,
          ),
          withReferenceMapper: (p0) => p0
              .map((e) => (e.readTable(table), BaseReferences(db, table, e)))
              .toList(),
          prefetchHooksCallback: null,
        ));
}

typedef $$ServiceOrdersTableProcessedTableManager = ProcessedTableManager<
    _$AppDatabase,
    $ServiceOrdersTable,
    ServiceOrder,
    $$ServiceOrdersTableFilterComposer,
    $$ServiceOrdersTableOrderingComposer,
    $$ServiceOrdersTableAnnotationComposer,
    $$ServiceOrdersTableCreateCompanionBuilder,
    $$ServiceOrdersTableUpdateCompanionBuilder,
    (
      ServiceOrder,
      BaseReferences<_$AppDatabase, $ServiceOrdersTable, ServiceOrder>
    ),
    ServiceOrder,
    PrefetchHooks Function()>;
typedef $$ReviewsTableCreateCompanionBuilder = ReviewsCompanion Function({
  required String id,
  required String orderId,
  required String reviewerId,
  required String revieweeId,
  required double rating,
  Value<String?> comment,
  Value<DateTime> createdAt,
  Value<int> rowid,
});
typedef $$ReviewsTableUpdateCompanionBuilder = ReviewsCompanion Function({
  Value<String> id,
  Value<String> orderId,
  Value<String> reviewerId,
  Value<String> revieweeId,
  Value<double> rating,
  Value<String?> comment,
  Value<DateTime> createdAt,
  Value<int> rowid,
});

class $$ReviewsTableFilterComposer
    extends Composer<_$AppDatabase, $ReviewsTable> {
  $$ReviewsTableFilterComposer({
    required super.$db,
    required super.$table,
    super.joinBuilder,
    super.$addJoinBuilderToRootComposer,
    super.$removeJoinBuilderFromRootComposer,
  });
  ColumnFilters<String> get id => $composableBuilder(
      column: $table.id, builder: (column) => ColumnFilters(column));

  ColumnFilters<String> get orderId => $composableBuilder(
      column: $table.orderId, builder: (column) => ColumnFilters(column));

  ColumnFilters<String> get reviewerId => $composableBuilder(
      column: $table.reviewerId, builder: (column) => ColumnFilters(column));

  ColumnFilters<String> get revieweeId => $composableBuilder(
      column: $table.revieweeId, builder: (column) => ColumnFilters(column));

  ColumnFilters<double> get rating => $composableBuilder(
      column: $table.rating, builder: (column) => ColumnFilters(column));

  ColumnFilters<String> get comment => $composableBuilder(
      column: $table.comment, builder: (column) => ColumnFilters(column));

  ColumnFilters<DateTime> get createdAt => $composableBuilder(
      column: $table.createdAt, builder: (column) => ColumnFilters(column));
}

class $$ReviewsTableOrderingComposer
    extends Composer<_$AppDatabase, $ReviewsTable> {
  $$ReviewsTableOrderingComposer({
    required super.$db,
    required super.$table,
    super.joinBuilder,
    super.$addJoinBuilderToRootComposer,
    super.$removeJoinBuilderFromRootComposer,
  });
  ColumnOrderings<String> get id => $composableBuilder(
      column: $table.id, builder: (column) => ColumnOrderings(column));

  ColumnOrderings<String> get orderId => $composableBuilder(
      column: $table.orderId, builder: (column) => ColumnOrderings(column));

  ColumnOrderings<String> get reviewerId => $composableBuilder(
      column: $table.reviewerId, builder: (column) => ColumnOrderings(column));

  ColumnOrderings<String> get revieweeId => $composableBuilder(
      column: $table.revieweeId, builder: (column) => ColumnOrderings(column));

  ColumnOrderings<double> get rating => $composableBuilder(
      column: $table.rating, builder: (column) => ColumnOrderings(column));

  ColumnOrderings<String> get comment => $composableBuilder(
      column: $table.comment, builder: (column) => ColumnOrderings(column));

  ColumnOrderings<DateTime> get createdAt => $composableBuilder(
      column: $table.createdAt, builder: (column) => ColumnOrderings(column));
}

class $$ReviewsTableAnnotationComposer
    extends Composer<_$AppDatabase, $ReviewsTable> {
  $$ReviewsTableAnnotationComposer({
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

  GeneratedColumn<String> get reviewerId => $composableBuilder(
      column: $table.reviewerId, builder: (column) => column);

  GeneratedColumn<String> get revieweeId => $composableBuilder(
      column: $table.revieweeId, builder: (column) => column);

  GeneratedColumn<double> get rating =>
      $composableBuilder(column: $table.rating, builder: (column) => column);

  GeneratedColumn<String> get comment =>
      $composableBuilder(column: $table.comment, builder: (column) => column);

  GeneratedColumn<DateTime> get createdAt =>
      $composableBuilder(column: $table.createdAt, builder: (column) => column);
}

class $$ReviewsTableTableManager extends RootTableManager<
    _$AppDatabase,
    $ReviewsTable,
    Review,
    $$ReviewsTableFilterComposer,
    $$ReviewsTableOrderingComposer,
    $$ReviewsTableAnnotationComposer,
    $$ReviewsTableCreateCompanionBuilder,
    $$ReviewsTableUpdateCompanionBuilder,
    (Review, BaseReferences<_$AppDatabase, $ReviewsTable, Review>),
    Review,
    PrefetchHooks Function()> {
  $$ReviewsTableTableManager(_$AppDatabase db, $ReviewsTable table)
      : super(TableManagerState(
          db: db,
          table: table,
          createFilteringComposer: () =>
              $$ReviewsTableFilterComposer($db: db, $table: table),
          createOrderingComposer: () =>
              $$ReviewsTableOrderingComposer($db: db, $table: table),
          createComputedFieldComposer: () =>
              $$ReviewsTableAnnotationComposer($db: db, $table: table),
          updateCompanionCallback: ({
            Value<String> id = const Value.absent(),
            Value<String> orderId = const Value.absent(),
            Value<String> reviewerId = const Value.absent(),
            Value<String> revieweeId = const Value.absent(),
            Value<double> rating = const Value.absent(),
            Value<String?> comment = const Value.absent(),
            Value<DateTime> createdAt = const Value.absent(),
            Value<int> rowid = const Value.absent(),
          }) =>
              ReviewsCompanion(
            id: id,
            orderId: orderId,
            reviewerId: reviewerId,
            revieweeId: revieweeId,
            rating: rating,
            comment: comment,
            createdAt: createdAt,
            rowid: rowid,
          ),
          createCompanionCallback: ({
            required String id,
            required String orderId,
            required String reviewerId,
            required String revieweeId,
            required double rating,
            Value<String?> comment = const Value.absent(),
            Value<DateTime> createdAt = const Value.absent(),
            Value<int> rowid = const Value.absent(),
          }) =>
              ReviewsCompanion.insert(
            id: id,
            orderId: orderId,
            reviewerId: reviewerId,
            revieweeId: revieweeId,
            rating: rating,
            comment: comment,
            createdAt: createdAt,
            rowid: rowid,
          ),
          withReferenceMapper: (p0) => p0
              .map((e) => (e.readTable(table), BaseReferences(db, table, e)))
              .toList(),
          prefetchHooksCallback: null,
        ));
}

typedef $$ReviewsTableProcessedTableManager = ProcessedTableManager<
    _$AppDatabase,
    $ReviewsTable,
    Review,
    $$ReviewsTableFilterComposer,
    $$ReviewsTableOrderingComposer,
    $$ReviewsTableAnnotationComposer,
    $$ReviewsTableCreateCompanionBuilder,
    $$ReviewsTableUpdateCompanionBuilder,
    (Review, BaseReferences<_$AppDatabase, $ReviewsTable, Review>),
    Review,
    PrefetchHooks Function()>;
typedef $$ServiceItemsTableCreateCompanionBuilder = ServiceItemsCompanion
    Function({
  required String id,
  required String name,
  Value<String> category,
  required double hourlyRate,
  Value<double> estimatedHours,
  Value<String?> description,
  Value<bool> isActive,
  Value<String> customFields,
  Value<DateTime> createdAt,
  Value<int> rowid,
});
typedef $$ServiceItemsTableUpdateCompanionBuilder = ServiceItemsCompanion
    Function({
  Value<String> id,
  Value<String> name,
  Value<String> category,
  Value<double> hourlyRate,
  Value<double> estimatedHours,
  Value<String?> description,
  Value<bool> isActive,
  Value<String> customFields,
  Value<DateTime> createdAt,
  Value<int> rowid,
});

class $$ServiceItemsTableFilterComposer
    extends Composer<_$AppDatabase, $ServiceItemsTable> {
  $$ServiceItemsTableFilterComposer({
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

  ColumnFilters<String> get category => $composableBuilder(
      column: $table.category, builder: (column) => ColumnFilters(column));

  ColumnFilters<double> get hourlyRate => $composableBuilder(
      column: $table.hourlyRate, builder: (column) => ColumnFilters(column));

  ColumnFilters<double> get estimatedHours => $composableBuilder(
      column: $table.estimatedHours,
      builder: (column) => ColumnFilters(column));

  ColumnFilters<String> get description => $composableBuilder(
      column: $table.description, builder: (column) => ColumnFilters(column));

  ColumnFilters<bool> get isActive => $composableBuilder(
      column: $table.isActive, builder: (column) => ColumnFilters(column));

  ColumnFilters<String> get customFields => $composableBuilder(
      column: $table.customFields, builder: (column) => ColumnFilters(column));

  ColumnFilters<DateTime> get createdAt => $composableBuilder(
      column: $table.createdAt, builder: (column) => ColumnFilters(column));
}

class $$ServiceItemsTableOrderingComposer
    extends Composer<_$AppDatabase, $ServiceItemsTable> {
  $$ServiceItemsTableOrderingComposer({
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

  ColumnOrderings<String> get category => $composableBuilder(
      column: $table.category, builder: (column) => ColumnOrderings(column));

  ColumnOrderings<double> get hourlyRate => $composableBuilder(
      column: $table.hourlyRate, builder: (column) => ColumnOrderings(column));

  ColumnOrderings<double> get estimatedHours => $composableBuilder(
      column: $table.estimatedHours,
      builder: (column) => ColumnOrderings(column));

  ColumnOrderings<String> get description => $composableBuilder(
      column: $table.description, builder: (column) => ColumnOrderings(column));

  ColumnOrderings<bool> get isActive => $composableBuilder(
      column: $table.isActive, builder: (column) => ColumnOrderings(column));

  ColumnOrderings<String> get customFields => $composableBuilder(
      column: $table.customFields,
      builder: (column) => ColumnOrderings(column));

  ColumnOrderings<DateTime> get createdAt => $composableBuilder(
      column: $table.createdAt, builder: (column) => ColumnOrderings(column));
}

class $$ServiceItemsTableAnnotationComposer
    extends Composer<_$AppDatabase, $ServiceItemsTable> {
  $$ServiceItemsTableAnnotationComposer({
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

  GeneratedColumn<String> get category =>
      $composableBuilder(column: $table.category, builder: (column) => column);

  GeneratedColumn<double> get hourlyRate => $composableBuilder(
      column: $table.hourlyRate, builder: (column) => column);

  GeneratedColumn<double> get estimatedHours => $composableBuilder(
      column: $table.estimatedHours, builder: (column) => column);

  GeneratedColumn<String> get description => $composableBuilder(
      column: $table.description, builder: (column) => column);

  GeneratedColumn<bool> get isActive =>
      $composableBuilder(column: $table.isActive, builder: (column) => column);

  GeneratedColumn<String> get customFields => $composableBuilder(
      column: $table.customFields, builder: (column) => column);

  GeneratedColumn<DateTime> get createdAt =>
      $composableBuilder(column: $table.createdAt, builder: (column) => column);
}

class $$ServiceItemsTableTableManager extends RootTableManager<
    _$AppDatabase,
    $ServiceItemsTable,
    ServiceItem,
    $$ServiceItemsTableFilterComposer,
    $$ServiceItemsTableOrderingComposer,
    $$ServiceItemsTableAnnotationComposer,
    $$ServiceItemsTableCreateCompanionBuilder,
    $$ServiceItemsTableUpdateCompanionBuilder,
    (
      ServiceItem,
      BaseReferences<_$AppDatabase, $ServiceItemsTable, ServiceItem>
    ),
    ServiceItem,
    PrefetchHooks Function()> {
  $$ServiceItemsTableTableManager(_$AppDatabase db, $ServiceItemsTable table)
      : super(TableManagerState(
          db: db,
          table: table,
          createFilteringComposer: () =>
              $$ServiceItemsTableFilterComposer($db: db, $table: table),
          createOrderingComposer: () =>
              $$ServiceItemsTableOrderingComposer($db: db, $table: table),
          createComputedFieldComposer: () =>
              $$ServiceItemsTableAnnotationComposer($db: db, $table: table),
          updateCompanionCallback: ({
            Value<String> id = const Value.absent(),
            Value<String> name = const Value.absent(),
            Value<String> category = const Value.absent(),
            Value<double> hourlyRate = const Value.absent(),
            Value<double> estimatedHours = const Value.absent(),
            Value<String?> description = const Value.absent(),
            Value<bool> isActive = const Value.absent(),
            Value<String> customFields = const Value.absent(),
            Value<DateTime> createdAt = const Value.absent(),
            Value<int> rowid = const Value.absent(),
          }) =>
              ServiceItemsCompanion(
            id: id,
            name: name,
            category: category,
            hourlyRate: hourlyRate,
            estimatedHours: estimatedHours,
            description: description,
            isActive: isActive,
            customFields: customFields,
            createdAt: createdAt,
            rowid: rowid,
          ),
          createCompanionCallback: ({
            required String id,
            required String name,
            Value<String> category = const Value.absent(),
            required double hourlyRate,
            Value<double> estimatedHours = const Value.absent(),
            Value<String?> description = const Value.absent(),
            Value<bool> isActive = const Value.absent(),
            Value<String> customFields = const Value.absent(),
            Value<DateTime> createdAt = const Value.absent(),
            Value<int> rowid = const Value.absent(),
          }) =>
              ServiceItemsCompanion.insert(
            id: id,
            name: name,
            category: category,
            hourlyRate: hourlyRate,
            estimatedHours: estimatedHours,
            description: description,
            isActive: isActive,
            customFields: customFields,
            createdAt: createdAt,
            rowid: rowid,
          ),
          withReferenceMapper: (p0) => p0
              .map((e) => (e.readTable(table), BaseReferences(db, table, e)))
              .toList(),
          prefetchHooksCallback: null,
        ));
}

typedef $$ServiceItemsTableProcessedTableManager = ProcessedTableManager<
    _$AppDatabase,
    $ServiceItemsTable,
    ServiceItem,
    $$ServiceItemsTableFilterComposer,
    $$ServiceItemsTableOrderingComposer,
    $$ServiceItemsTableAnnotationComposer,
    $$ServiceItemsTableCreateCompanionBuilder,
    $$ServiceItemsTableUpdateCompanionBuilder,
    (
      ServiceItem,
      BaseReferences<_$AppDatabase, $ServiceItemsTable, ServiceItem>
    ),
    ServiceItem,
    PrefetchHooks Function()>;
typedef $$ServiceBookingsTableCreateCompanionBuilder = ServiceBookingsCompanion
    Function({
  required String id,
  required String serviceItemId,
  required String customerName,
  Value<String?> customerPhone,
  Value<DateTime?> scheduledAt,
  Value<double?> actualHours,
  Value<double> totalAmount,
  Value<String> status,
  Value<String?> notes,
  Value<String> customFields,
  Value<DateTime> createdAt,
  Value<int> rowid,
});
typedef $$ServiceBookingsTableUpdateCompanionBuilder = ServiceBookingsCompanion
    Function({
  Value<String> id,
  Value<String> serviceItemId,
  Value<String> customerName,
  Value<String?> customerPhone,
  Value<DateTime?> scheduledAt,
  Value<double?> actualHours,
  Value<double> totalAmount,
  Value<String> status,
  Value<String?> notes,
  Value<String> customFields,
  Value<DateTime> createdAt,
  Value<int> rowid,
});

class $$ServiceBookingsTableFilterComposer
    extends Composer<_$AppDatabase, $ServiceBookingsTable> {
  $$ServiceBookingsTableFilterComposer({
    required super.$db,
    required super.$table,
    super.joinBuilder,
    super.$addJoinBuilderToRootComposer,
    super.$removeJoinBuilderFromRootComposer,
  });
  ColumnFilters<String> get id => $composableBuilder(
      column: $table.id, builder: (column) => ColumnFilters(column));

  ColumnFilters<String> get serviceItemId => $composableBuilder(
      column: $table.serviceItemId, builder: (column) => ColumnFilters(column));

  ColumnFilters<String> get customerName => $composableBuilder(
      column: $table.customerName, builder: (column) => ColumnFilters(column));

  ColumnFilters<String> get customerPhone => $composableBuilder(
      column: $table.customerPhone, builder: (column) => ColumnFilters(column));

  ColumnFilters<DateTime> get scheduledAt => $composableBuilder(
      column: $table.scheduledAt, builder: (column) => ColumnFilters(column));

  ColumnFilters<double> get actualHours => $composableBuilder(
      column: $table.actualHours, builder: (column) => ColumnFilters(column));

  ColumnFilters<double> get totalAmount => $composableBuilder(
      column: $table.totalAmount, builder: (column) => ColumnFilters(column));

  ColumnFilters<String> get status => $composableBuilder(
      column: $table.status, builder: (column) => ColumnFilters(column));

  ColumnFilters<String> get notes => $composableBuilder(
      column: $table.notes, builder: (column) => ColumnFilters(column));

  ColumnFilters<String> get customFields => $composableBuilder(
      column: $table.customFields, builder: (column) => ColumnFilters(column));

  ColumnFilters<DateTime> get createdAt => $composableBuilder(
      column: $table.createdAt, builder: (column) => ColumnFilters(column));
}

class $$ServiceBookingsTableOrderingComposer
    extends Composer<_$AppDatabase, $ServiceBookingsTable> {
  $$ServiceBookingsTableOrderingComposer({
    required super.$db,
    required super.$table,
    super.joinBuilder,
    super.$addJoinBuilderToRootComposer,
    super.$removeJoinBuilderFromRootComposer,
  });
  ColumnOrderings<String> get id => $composableBuilder(
      column: $table.id, builder: (column) => ColumnOrderings(column));

  ColumnOrderings<String> get serviceItemId => $composableBuilder(
      column: $table.serviceItemId,
      builder: (column) => ColumnOrderings(column));

  ColumnOrderings<String> get customerName => $composableBuilder(
      column: $table.customerName,
      builder: (column) => ColumnOrderings(column));

  ColumnOrderings<String> get customerPhone => $composableBuilder(
      column: $table.customerPhone,
      builder: (column) => ColumnOrderings(column));

  ColumnOrderings<DateTime> get scheduledAt => $composableBuilder(
      column: $table.scheduledAt, builder: (column) => ColumnOrderings(column));

  ColumnOrderings<double> get actualHours => $composableBuilder(
      column: $table.actualHours, builder: (column) => ColumnOrderings(column));

  ColumnOrderings<double> get totalAmount => $composableBuilder(
      column: $table.totalAmount, builder: (column) => ColumnOrderings(column));

  ColumnOrderings<String> get status => $composableBuilder(
      column: $table.status, builder: (column) => ColumnOrderings(column));

  ColumnOrderings<String> get notes => $composableBuilder(
      column: $table.notes, builder: (column) => ColumnOrderings(column));

  ColumnOrderings<String> get customFields => $composableBuilder(
      column: $table.customFields,
      builder: (column) => ColumnOrderings(column));

  ColumnOrderings<DateTime> get createdAt => $composableBuilder(
      column: $table.createdAt, builder: (column) => ColumnOrderings(column));
}

class $$ServiceBookingsTableAnnotationComposer
    extends Composer<_$AppDatabase, $ServiceBookingsTable> {
  $$ServiceBookingsTableAnnotationComposer({
    required super.$db,
    required super.$table,
    super.joinBuilder,
    super.$addJoinBuilderToRootComposer,
    super.$removeJoinBuilderFromRootComposer,
  });
  GeneratedColumn<String> get id =>
      $composableBuilder(column: $table.id, builder: (column) => column);

  GeneratedColumn<String> get serviceItemId => $composableBuilder(
      column: $table.serviceItemId, builder: (column) => column);

  GeneratedColumn<String> get customerName => $composableBuilder(
      column: $table.customerName, builder: (column) => column);

  GeneratedColumn<String> get customerPhone => $composableBuilder(
      column: $table.customerPhone, builder: (column) => column);

  GeneratedColumn<DateTime> get scheduledAt => $composableBuilder(
      column: $table.scheduledAt, builder: (column) => column);

  GeneratedColumn<double> get actualHours => $composableBuilder(
      column: $table.actualHours, builder: (column) => column);

  GeneratedColumn<double> get totalAmount => $composableBuilder(
      column: $table.totalAmount, builder: (column) => column);

  GeneratedColumn<String> get status =>
      $composableBuilder(column: $table.status, builder: (column) => column);

  GeneratedColumn<String> get notes =>
      $composableBuilder(column: $table.notes, builder: (column) => column);

  GeneratedColumn<String> get customFields => $composableBuilder(
      column: $table.customFields, builder: (column) => column);

  GeneratedColumn<DateTime> get createdAt =>
      $composableBuilder(column: $table.createdAt, builder: (column) => column);
}

class $$ServiceBookingsTableTableManager extends RootTableManager<
    _$AppDatabase,
    $ServiceBookingsTable,
    ServiceBooking,
    $$ServiceBookingsTableFilterComposer,
    $$ServiceBookingsTableOrderingComposer,
    $$ServiceBookingsTableAnnotationComposer,
    $$ServiceBookingsTableCreateCompanionBuilder,
    $$ServiceBookingsTableUpdateCompanionBuilder,
    (
      ServiceBooking,
      BaseReferences<_$AppDatabase, $ServiceBookingsTable, ServiceBooking>
    ),
    ServiceBooking,
    PrefetchHooks Function()> {
  $$ServiceBookingsTableTableManager(
      _$AppDatabase db, $ServiceBookingsTable table)
      : super(TableManagerState(
          db: db,
          table: table,
          createFilteringComposer: () =>
              $$ServiceBookingsTableFilterComposer($db: db, $table: table),
          createOrderingComposer: () =>
              $$ServiceBookingsTableOrderingComposer($db: db, $table: table),
          createComputedFieldComposer: () =>
              $$ServiceBookingsTableAnnotationComposer($db: db, $table: table),
          updateCompanionCallback: ({
            Value<String> id = const Value.absent(),
            Value<String> serviceItemId = const Value.absent(),
            Value<String> customerName = const Value.absent(),
            Value<String?> customerPhone = const Value.absent(),
            Value<DateTime?> scheduledAt = const Value.absent(),
            Value<double?> actualHours = const Value.absent(),
            Value<double> totalAmount = const Value.absent(),
            Value<String> status = const Value.absent(),
            Value<String?> notes = const Value.absent(),
            Value<String> customFields = const Value.absent(),
            Value<DateTime> createdAt = const Value.absent(),
            Value<int> rowid = const Value.absent(),
          }) =>
              ServiceBookingsCompanion(
            id: id,
            serviceItemId: serviceItemId,
            customerName: customerName,
            customerPhone: customerPhone,
            scheduledAt: scheduledAt,
            actualHours: actualHours,
            totalAmount: totalAmount,
            status: status,
            notes: notes,
            customFields: customFields,
            createdAt: createdAt,
            rowid: rowid,
          ),
          createCompanionCallback: ({
            required String id,
            required String serviceItemId,
            required String customerName,
            Value<String?> customerPhone = const Value.absent(),
            Value<DateTime?> scheduledAt = const Value.absent(),
            Value<double?> actualHours = const Value.absent(),
            Value<double> totalAmount = const Value.absent(),
            Value<String> status = const Value.absent(),
            Value<String?> notes = const Value.absent(),
            Value<String> customFields = const Value.absent(),
            Value<DateTime> createdAt = const Value.absent(),
            Value<int> rowid = const Value.absent(),
          }) =>
              ServiceBookingsCompanion.insert(
            id: id,
            serviceItemId: serviceItemId,
            customerName: customerName,
            customerPhone: customerPhone,
            scheduledAt: scheduledAt,
            actualHours: actualHours,
            totalAmount: totalAmount,
            status: status,
            notes: notes,
            customFields: customFields,
            createdAt: createdAt,
            rowid: rowid,
          ),
          withReferenceMapper: (p0) => p0
              .map((e) => (e.readTable(table), BaseReferences(db, table, e)))
              .toList(),
          prefetchHooksCallback: null,
        ));
}

typedef $$ServiceBookingsTableProcessedTableManager = ProcessedTableManager<
    _$AppDatabase,
    $ServiceBookingsTable,
    ServiceBooking,
    $$ServiceBookingsTableFilterComposer,
    $$ServiceBookingsTableOrderingComposer,
    $$ServiceBookingsTableAnnotationComposer,
    $$ServiceBookingsTableCreateCompanionBuilder,
    $$ServiceBookingsTableUpdateCompanionBuilder,
    (
      ServiceBooking,
      BaseReferences<_$AppDatabase, $ServiceBookingsTable, ServiceBooking>
    ),
    ServiceBooking,
    PrefetchHooks Function()>;
typedef $$OutboxMutationsTableCreateCompanionBuilder = OutboxMutationsCompanion
    Function({
  required String id,
  required String targetTable,
  required String operation,
  required String payload,
  Value<DateTime> createdAt,
  Value<String> status,
  Value<int> rowid,
});
typedef $$OutboxMutationsTableUpdateCompanionBuilder = OutboxMutationsCompanion
    Function({
  Value<String> id,
  Value<String> targetTable,
  Value<String> operation,
  Value<String> payload,
  Value<DateTime> createdAt,
  Value<String> status,
  Value<int> rowid,
});

class $$OutboxMutationsTableFilterComposer
    extends Composer<_$AppDatabase, $OutboxMutationsTable> {
  $$OutboxMutationsTableFilterComposer({
    required super.$db,
    required super.$table,
    super.joinBuilder,
    super.$addJoinBuilderToRootComposer,
    super.$removeJoinBuilderFromRootComposer,
  });
  ColumnFilters<String> get id => $composableBuilder(
      column: $table.id, builder: (column) => ColumnFilters(column));

  ColumnFilters<String> get targetTable => $composableBuilder(
      column: $table.targetTable, builder: (column) => ColumnFilters(column));

  ColumnFilters<String> get operation => $composableBuilder(
      column: $table.operation, builder: (column) => ColumnFilters(column));

  ColumnFilters<String> get payload => $composableBuilder(
      column: $table.payload, builder: (column) => ColumnFilters(column));

  ColumnFilters<DateTime> get createdAt => $composableBuilder(
      column: $table.createdAt, builder: (column) => ColumnFilters(column));

  ColumnFilters<String> get status => $composableBuilder(
      column: $table.status, builder: (column) => ColumnFilters(column));
}

class $$OutboxMutationsTableOrderingComposer
    extends Composer<_$AppDatabase, $OutboxMutationsTable> {
  $$OutboxMutationsTableOrderingComposer({
    required super.$db,
    required super.$table,
    super.joinBuilder,
    super.$addJoinBuilderToRootComposer,
    super.$removeJoinBuilderFromRootComposer,
  });
  ColumnOrderings<String> get id => $composableBuilder(
      column: $table.id, builder: (column) => ColumnOrderings(column));

  ColumnOrderings<String> get targetTable => $composableBuilder(
      column: $table.targetTable, builder: (column) => ColumnOrderings(column));

  ColumnOrderings<String> get operation => $composableBuilder(
      column: $table.operation, builder: (column) => ColumnOrderings(column));

  ColumnOrderings<String> get payload => $composableBuilder(
      column: $table.payload, builder: (column) => ColumnOrderings(column));

  ColumnOrderings<DateTime> get createdAt => $composableBuilder(
      column: $table.createdAt, builder: (column) => ColumnOrderings(column));

  ColumnOrderings<String> get status => $composableBuilder(
      column: $table.status, builder: (column) => ColumnOrderings(column));
}

class $$OutboxMutationsTableAnnotationComposer
    extends Composer<_$AppDatabase, $OutboxMutationsTable> {
  $$OutboxMutationsTableAnnotationComposer({
    required super.$db,
    required super.$table,
    super.joinBuilder,
    super.$addJoinBuilderToRootComposer,
    super.$removeJoinBuilderFromRootComposer,
  });
  GeneratedColumn<String> get id =>
      $composableBuilder(column: $table.id, builder: (column) => column);

  GeneratedColumn<String> get targetTable => $composableBuilder(
      column: $table.targetTable, builder: (column) => column);

  GeneratedColumn<String> get operation =>
      $composableBuilder(column: $table.operation, builder: (column) => column);

  GeneratedColumn<String> get payload =>
      $composableBuilder(column: $table.payload, builder: (column) => column);

  GeneratedColumn<DateTime> get createdAt =>
      $composableBuilder(column: $table.createdAt, builder: (column) => column);

  GeneratedColumn<String> get status =>
      $composableBuilder(column: $table.status, builder: (column) => column);
}

class $$OutboxMutationsTableTableManager extends RootTableManager<
    _$AppDatabase,
    $OutboxMutationsTable,
    OutboxMutation,
    $$OutboxMutationsTableFilterComposer,
    $$OutboxMutationsTableOrderingComposer,
    $$OutboxMutationsTableAnnotationComposer,
    $$OutboxMutationsTableCreateCompanionBuilder,
    $$OutboxMutationsTableUpdateCompanionBuilder,
    (
      OutboxMutation,
      BaseReferences<_$AppDatabase, $OutboxMutationsTable, OutboxMutation>
    ),
    OutboxMutation,
    PrefetchHooks Function()> {
  $$OutboxMutationsTableTableManager(
      _$AppDatabase db, $OutboxMutationsTable table)
      : super(TableManagerState(
          db: db,
          table: table,
          createFilteringComposer: () =>
              $$OutboxMutationsTableFilterComposer($db: db, $table: table),
          createOrderingComposer: () =>
              $$OutboxMutationsTableOrderingComposer($db: db, $table: table),
          createComputedFieldComposer: () =>
              $$OutboxMutationsTableAnnotationComposer($db: db, $table: table),
          updateCompanionCallback: ({
            Value<String> id = const Value.absent(),
            Value<String> targetTable = const Value.absent(),
            Value<String> operation = const Value.absent(),
            Value<String> payload = const Value.absent(),
            Value<DateTime> createdAt = const Value.absent(),
            Value<String> status = const Value.absent(),
            Value<int> rowid = const Value.absent(),
          }) =>
              OutboxMutationsCompanion(
            id: id,
            targetTable: targetTable,
            operation: operation,
            payload: payload,
            createdAt: createdAt,
            status: status,
            rowid: rowid,
          ),
          createCompanionCallback: ({
            required String id,
            required String targetTable,
            required String operation,
            required String payload,
            Value<DateTime> createdAt = const Value.absent(),
            Value<String> status = const Value.absent(),
            Value<int> rowid = const Value.absent(),
          }) =>
              OutboxMutationsCompanion.insert(
            id: id,
            targetTable: targetTable,
            operation: operation,
            payload: payload,
            createdAt: createdAt,
            status: status,
            rowid: rowid,
          ),
          withReferenceMapper: (p0) => p0
              .map((e) => (e.readTable(table), BaseReferences(db, table, e)))
              .toList(),
          prefetchHooksCallback: null,
        ));
}

typedef $$OutboxMutationsTableProcessedTableManager = ProcessedTableManager<
    _$AppDatabase,
    $OutboxMutationsTable,
    OutboxMutation,
    $$OutboxMutationsTableFilterComposer,
    $$OutboxMutationsTableOrderingComposer,
    $$OutboxMutationsTableAnnotationComposer,
    $$OutboxMutationsTableCreateCompanionBuilder,
    $$OutboxMutationsTableUpdateCompanionBuilder,
    (
      OutboxMutation,
      BaseReferences<_$AppDatabase, $OutboxMutationsTable, OutboxMutation>
    ),
    OutboxMutation,
    PrefetchHooks Function()>;
typedef $$ProjectsTableCreateCompanionBuilder = ProjectsCompanion Function({
  required String id,
  required String name,
  Value<String?> description,
  Value<String> status,
  Value<DateTime> createdAt,
  Value<String> customFields,
  Value<int> rowid,
});
typedef $$ProjectsTableUpdateCompanionBuilder = ProjectsCompanion Function({
  Value<String> id,
  Value<String> name,
  Value<String?> description,
  Value<String> status,
  Value<DateTime> createdAt,
  Value<String> customFields,
  Value<int> rowid,
});

class $$ProjectsTableFilterComposer
    extends Composer<_$AppDatabase, $ProjectsTable> {
  $$ProjectsTableFilterComposer({
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

  ColumnFilters<String> get description => $composableBuilder(
      column: $table.description, builder: (column) => ColumnFilters(column));

  ColumnFilters<String> get status => $composableBuilder(
      column: $table.status, builder: (column) => ColumnFilters(column));

  ColumnFilters<DateTime> get createdAt => $composableBuilder(
      column: $table.createdAt, builder: (column) => ColumnFilters(column));

  ColumnFilters<String> get customFields => $composableBuilder(
      column: $table.customFields, builder: (column) => ColumnFilters(column));
}

class $$ProjectsTableOrderingComposer
    extends Composer<_$AppDatabase, $ProjectsTable> {
  $$ProjectsTableOrderingComposer({
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

  ColumnOrderings<String> get description => $composableBuilder(
      column: $table.description, builder: (column) => ColumnOrderings(column));

  ColumnOrderings<String> get status => $composableBuilder(
      column: $table.status, builder: (column) => ColumnOrderings(column));

  ColumnOrderings<DateTime> get createdAt => $composableBuilder(
      column: $table.createdAt, builder: (column) => ColumnOrderings(column));

  ColumnOrderings<String> get customFields => $composableBuilder(
      column: $table.customFields,
      builder: (column) => ColumnOrderings(column));
}

class $$ProjectsTableAnnotationComposer
    extends Composer<_$AppDatabase, $ProjectsTable> {
  $$ProjectsTableAnnotationComposer({
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

  GeneratedColumn<String> get description => $composableBuilder(
      column: $table.description, builder: (column) => column);

  GeneratedColumn<String> get status =>
      $composableBuilder(column: $table.status, builder: (column) => column);

  GeneratedColumn<DateTime> get createdAt =>
      $composableBuilder(column: $table.createdAt, builder: (column) => column);

  GeneratedColumn<String> get customFields => $composableBuilder(
      column: $table.customFields, builder: (column) => column);
}

class $$ProjectsTableTableManager extends RootTableManager<
    _$AppDatabase,
    $ProjectsTable,
    Project,
    $$ProjectsTableFilterComposer,
    $$ProjectsTableOrderingComposer,
    $$ProjectsTableAnnotationComposer,
    $$ProjectsTableCreateCompanionBuilder,
    $$ProjectsTableUpdateCompanionBuilder,
    (Project, BaseReferences<_$AppDatabase, $ProjectsTable, Project>),
    Project,
    PrefetchHooks Function()> {
  $$ProjectsTableTableManager(_$AppDatabase db, $ProjectsTable table)
      : super(TableManagerState(
          db: db,
          table: table,
          createFilteringComposer: () =>
              $$ProjectsTableFilterComposer($db: db, $table: table),
          createOrderingComposer: () =>
              $$ProjectsTableOrderingComposer($db: db, $table: table),
          createComputedFieldComposer: () =>
              $$ProjectsTableAnnotationComposer($db: db, $table: table),
          updateCompanionCallback: ({
            Value<String> id = const Value.absent(),
            Value<String> name = const Value.absent(),
            Value<String?> description = const Value.absent(),
            Value<String> status = const Value.absent(),
            Value<DateTime> createdAt = const Value.absent(),
            Value<String> customFields = const Value.absent(),
            Value<int> rowid = const Value.absent(),
          }) =>
              ProjectsCompanion(
            id: id,
            name: name,
            description: description,
            status: status,
            createdAt: createdAt,
            customFields: customFields,
            rowid: rowid,
          ),
          createCompanionCallback: ({
            required String id,
            required String name,
            Value<String?> description = const Value.absent(),
            Value<String> status = const Value.absent(),
            Value<DateTime> createdAt = const Value.absent(),
            Value<String> customFields = const Value.absent(),
            Value<int> rowid = const Value.absent(),
          }) =>
              ProjectsCompanion.insert(
            id: id,
            name: name,
            description: description,
            status: status,
            createdAt: createdAt,
            customFields: customFields,
            rowid: rowid,
          ),
          withReferenceMapper: (p0) => p0
              .map((e) => (e.readTable(table), BaseReferences(db, table, e)))
              .toList(),
          prefetchHooksCallback: null,
        ));
}

typedef $$ProjectsTableProcessedTableManager = ProcessedTableManager<
    _$AppDatabase,
    $ProjectsTable,
    Project,
    $$ProjectsTableFilterComposer,
    $$ProjectsTableOrderingComposer,
    $$ProjectsTableAnnotationComposer,
    $$ProjectsTableCreateCompanionBuilder,
    $$ProjectsTableUpdateCompanionBuilder,
    (Project, BaseReferences<_$AppDatabase, $ProjectsTable, Project>),
    Project,
    PrefetchHooks Function()>;
typedef $$TasksTableCreateCompanionBuilder = TasksCompanion Function({
  required String id,
  required String projectId,
  required String title,
  Value<String?> description,
  Value<String> status,
  Value<String> priority,
  Value<DateTime?> dueDate,
  Value<DateTime> createdAt,
  Value<String> customFields,
  Value<int> rowid,
});
typedef $$TasksTableUpdateCompanionBuilder = TasksCompanion Function({
  Value<String> id,
  Value<String> projectId,
  Value<String> title,
  Value<String?> description,
  Value<String> status,
  Value<String> priority,
  Value<DateTime?> dueDate,
  Value<DateTime> createdAt,
  Value<String> customFields,
  Value<int> rowid,
});

class $$TasksTableFilterComposer extends Composer<_$AppDatabase, $TasksTable> {
  $$TasksTableFilterComposer({
    required super.$db,
    required super.$table,
    super.joinBuilder,
    super.$addJoinBuilderToRootComposer,
    super.$removeJoinBuilderFromRootComposer,
  });
  ColumnFilters<String> get id => $composableBuilder(
      column: $table.id, builder: (column) => ColumnFilters(column));

  ColumnFilters<String> get projectId => $composableBuilder(
      column: $table.projectId, builder: (column) => ColumnFilters(column));

  ColumnFilters<String> get title => $composableBuilder(
      column: $table.title, builder: (column) => ColumnFilters(column));

  ColumnFilters<String> get description => $composableBuilder(
      column: $table.description, builder: (column) => ColumnFilters(column));

  ColumnFilters<String> get status => $composableBuilder(
      column: $table.status, builder: (column) => ColumnFilters(column));

  ColumnFilters<String> get priority => $composableBuilder(
      column: $table.priority, builder: (column) => ColumnFilters(column));

  ColumnFilters<DateTime> get dueDate => $composableBuilder(
      column: $table.dueDate, builder: (column) => ColumnFilters(column));

  ColumnFilters<DateTime> get createdAt => $composableBuilder(
      column: $table.createdAt, builder: (column) => ColumnFilters(column));

  ColumnFilters<String> get customFields => $composableBuilder(
      column: $table.customFields, builder: (column) => ColumnFilters(column));
}

class $$TasksTableOrderingComposer
    extends Composer<_$AppDatabase, $TasksTable> {
  $$TasksTableOrderingComposer({
    required super.$db,
    required super.$table,
    super.joinBuilder,
    super.$addJoinBuilderToRootComposer,
    super.$removeJoinBuilderFromRootComposer,
  });
  ColumnOrderings<String> get id => $composableBuilder(
      column: $table.id, builder: (column) => ColumnOrderings(column));

  ColumnOrderings<String> get projectId => $composableBuilder(
      column: $table.projectId, builder: (column) => ColumnOrderings(column));

  ColumnOrderings<String> get title => $composableBuilder(
      column: $table.title, builder: (column) => ColumnOrderings(column));

  ColumnOrderings<String> get description => $composableBuilder(
      column: $table.description, builder: (column) => ColumnOrderings(column));

  ColumnOrderings<String> get status => $composableBuilder(
      column: $table.status, builder: (column) => ColumnOrderings(column));

  ColumnOrderings<String> get priority => $composableBuilder(
      column: $table.priority, builder: (column) => ColumnOrderings(column));

  ColumnOrderings<DateTime> get dueDate => $composableBuilder(
      column: $table.dueDate, builder: (column) => ColumnOrderings(column));

  ColumnOrderings<DateTime> get createdAt => $composableBuilder(
      column: $table.createdAt, builder: (column) => ColumnOrderings(column));

  ColumnOrderings<String> get customFields => $composableBuilder(
      column: $table.customFields,
      builder: (column) => ColumnOrderings(column));
}

class $$TasksTableAnnotationComposer
    extends Composer<_$AppDatabase, $TasksTable> {
  $$TasksTableAnnotationComposer({
    required super.$db,
    required super.$table,
    super.joinBuilder,
    super.$addJoinBuilderToRootComposer,
    super.$removeJoinBuilderFromRootComposer,
  });
  GeneratedColumn<String> get id =>
      $composableBuilder(column: $table.id, builder: (column) => column);

  GeneratedColumn<String> get projectId =>
      $composableBuilder(column: $table.projectId, builder: (column) => column);

  GeneratedColumn<String> get title =>
      $composableBuilder(column: $table.title, builder: (column) => column);

  GeneratedColumn<String> get description => $composableBuilder(
      column: $table.description, builder: (column) => column);

  GeneratedColumn<String> get status =>
      $composableBuilder(column: $table.status, builder: (column) => column);

  GeneratedColumn<String> get priority =>
      $composableBuilder(column: $table.priority, builder: (column) => column);

  GeneratedColumn<DateTime> get dueDate =>
      $composableBuilder(column: $table.dueDate, builder: (column) => column);

  GeneratedColumn<DateTime> get createdAt =>
      $composableBuilder(column: $table.createdAt, builder: (column) => column);

  GeneratedColumn<String> get customFields => $composableBuilder(
      column: $table.customFields, builder: (column) => column);
}

class $$TasksTableTableManager extends RootTableManager<
    _$AppDatabase,
    $TasksTable,
    Task,
    $$TasksTableFilterComposer,
    $$TasksTableOrderingComposer,
    $$TasksTableAnnotationComposer,
    $$TasksTableCreateCompanionBuilder,
    $$TasksTableUpdateCompanionBuilder,
    (Task, BaseReferences<_$AppDatabase, $TasksTable, Task>),
    Task,
    PrefetchHooks Function()> {
  $$TasksTableTableManager(_$AppDatabase db, $TasksTable table)
      : super(TableManagerState(
          db: db,
          table: table,
          createFilteringComposer: () =>
              $$TasksTableFilterComposer($db: db, $table: table),
          createOrderingComposer: () =>
              $$TasksTableOrderingComposer($db: db, $table: table),
          createComputedFieldComposer: () =>
              $$TasksTableAnnotationComposer($db: db, $table: table),
          updateCompanionCallback: ({
            Value<String> id = const Value.absent(),
            Value<String> projectId = const Value.absent(),
            Value<String> title = const Value.absent(),
            Value<String?> description = const Value.absent(),
            Value<String> status = const Value.absent(),
            Value<String> priority = const Value.absent(),
            Value<DateTime?> dueDate = const Value.absent(),
            Value<DateTime> createdAt = const Value.absent(),
            Value<String> customFields = const Value.absent(),
            Value<int> rowid = const Value.absent(),
          }) =>
              TasksCompanion(
            id: id,
            projectId: projectId,
            title: title,
            description: description,
            status: status,
            priority: priority,
            dueDate: dueDate,
            createdAt: createdAt,
            customFields: customFields,
            rowid: rowid,
          ),
          createCompanionCallback: ({
            required String id,
            required String projectId,
            required String title,
            Value<String?> description = const Value.absent(),
            Value<String> status = const Value.absent(),
            Value<String> priority = const Value.absent(),
            Value<DateTime?> dueDate = const Value.absent(),
            Value<DateTime> createdAt = const Value.absent(),
            Value<String> customFields = const Value.absent(),
            Value<int> rowid = const Value.absent(),
          }) =>
              TasksCompanion.insert(
            id: id,
            projectId: projectId,
            title: title,
            description: description,
            status: status,
            priority: priority,
            dueDate: dueDate,
            createdAt: createdAt,
            customFields: customFields,
            rowid: rowid,
          ),
          withReferenceMapper: (p0) => p0
              .map((e) => (e.readTable(table), BaseReferences(db, table, e)))
              .toList(),
          prefetchHooksCallback: null,
        ));
}

typedef $$TasksTableProcessedTableManager = ProcessedTableManager<
    _$AppDatabase,
    $TasksTable,
    Task,
    $$TasksTableFilterComposer,
    $$TasksTableOrderingComposer,
    $$TasksTableAnnotationComposer,
    $$TasksTableCreateCompanionBuilder,
    $$TasksTableUpdateCompanionBuilder,
    (Task, BaseReferences<_$AppDatabase, $TasksTable, Task>),
    Task,
    PrefetchHooks Function()>;
typedef $$PurchaseOrdersTableCreateCompanionBuilder = PurchaseOrdersCompanion
    Function({
  required String id,
  required String orderNumber,
  required String partnerName,
  Value<DateTime> orderDate,
  Value<double> totalAmount,
  Value<String> status,
  Value<DateTime> createdAt,
  Value<String> customFields,
  Value<int> rowid,
});
typedef $$PurchaseOrdersTableUpdateCompanionBuilder = PurchaseOrdersCompanion
    Function({
  Value<String> id,
  Value<String> orderNumber,
  Value<String> partnerName,
  Value<DateTime> orderDate,
  Value<double> totalAmount,
  Value<String> status,
  Value<DateTime> createdAt,
  Value<String> customFields,
  Value<int> rowid,
});

class $$PurchaseOrdersTableFilterComposer
    extends Composer<_$AppDatabase, $PurchaseOrdersTable> {
  $$PurchaseOrdersTableFilterComposer({
    required super.$db,
    required super.$table,
    super.joinBuilder,
    super.$addJoinBuilderToRootComposer,
    super.$removeJoinBuilderFromRootComposer,
  });
  ColumnFilters<String> get id => $composableBuilder(
      column: $table.id, builder: (column) => ColumnFilters(column));

  ColumnFilters<String> get orderNumber => $composableBuilder(
      column: $table.orderNumber, builder: (column) => ColumnFilters(column));

  ColumnFilters<String> get partnerName => $composableBuilder(
      column: $table.partnerName, builder: (column) => ColumnFilters(column));

  ColumnFilters<DateTime> get orderDate => $composableBuilder(
      column: $table.orderDate, builder: (column) => ColumnFilters(column));

  ColumnFilters<double> get totalAmount => $composableBuilder(
      column: $table.totalAmount, builder: (column) => ColumnFilters(column));

  ColumnFilters<String> get status => $composableBuilder(
      column: $table.status, builder: (column) => ColumnFilters(column));

  ColumnFilters<DateTime> get createdAt => $composableBuilder(
      column: $table.createdAt, builder: (column) => ColumnFilters(column));

  ColumnFilters<String> get customFields => $composableBuilder(
      column: $table.customFields, builder: (column) => ColumnFilters(column));
}

class $$PurchaseOrdersTableOrderingComposer
    extends Composer<_$AppDatabase, $PurchaseOrdersTable> {
  $$PurchaseOrdersTableOrderingComposer({
    required super.$db,
    required super.$table,
    super.joinBuilder,
    super.$addJoinBuilderToRootComposer,
    super.$removeJoinBuilderFromRootComposer,
  });
  ColumnOrderings<String> get id => $composableBuilder(
      column: $table.id, builder: (column) => ColumnOrderings(column));

  ColumnOrderings<String> get orderNumber => $composableBuilder(
      column: $table.orderNumber, builder: (column) => ColumnOrderings(column));

  ColumnOrderings<String> get partnerName => $composableBuilder(
      column: $table.partnerName, builder: (column) => ColumnOrderings(column));

  ColumnOrderings<DateTime> get orderDate => $composableBuilder(
      column: $table.orderDate, builder: (column) => ColumnOrderings(column));

  ColumnOrderings<double> get totalAmount => $composableBuilder(
      column: $table.totalAmount, builder: (column) => ColumnOrderings(column));

  ColumnOrderings<String> get status => $composableBuilder(
      column: $table.status, builder: (column) => ColumnOrderings(column));

  ColumnOrderings<DateTime> get createdAt => $composableBuilder(
      column: $table.createdAt, builder: (column) => ColumnOrderings(column));

  ColumnOrderings<String> get customFields => $composableBuilder(
      column: $table.customFields,
      builder: (column) => ColumnOrderings(column));
}

class $$PurchaseOrdersTableAnnotationComposer
    extends Composer<_$AppDatabase, $PurchaseOrdersTable> {
  $$PurchaseOrdersTableAnnotationComposer({
    required super.$db,
    required super.$table,
    super.joinBuilder,
    super.$addJoinBuilderToRootComposer,
    super.$removeJoinBuilderFromRootComposer,
  });
  GeneratedColumn<String> get id =>
      $composableBuilder(column: $table.id, builder: (column) => column);

  GeneratedColumn<String> get orderNumber => $composableBuilder(
      column: $table.orderNumber, builder: (column) => column);

  GeneratedColumn<String> get partnerName => $composableBuilder(
      column: $table.partnerName, builder: (column) => column);

  GeneratedColumn<DateTime> get orderDate =>
      $composableBuilder(column: $table.orderDate, builder: (column) => column);

  GeneratedColumn<double> get totalAmount => $composableBuilder(
      column: $table.totalAmount, builder: (column) => column);

  GeneratedColumn<String> get status =>
      $composableBuilder(column: $table.status, builder: (column) => column);

  GeneratedColumn<DateTime> get createdAt =>
      $composableBuilder(column: $table.createdAt, builder: (column) => column);

  GeneratedColumn<String> get customFields => $composableBuilder(
      column: $table.customFields, builder: (column) => column);
}

class $$PurchaseOrdersTableTableManager extends RootTableManager<
    _$AppDatabase,
    $PurchaseOrdersTable,
    PurchaseOrder,
    $$PurchaseOrdersTableFilterComposer,
    $$PurchaseOrdersTableOrderingComposer,
    $$PurchaseOrdersTableAnnotationComposer,
    $$PurchaseOrdersTableCreateCompanionBuilder,
    $$PurchaseOrdersTableUpdateCompanionBuilder,
    (
      PurchaseOrder,
      BaseReferences<_$AppDatabase, $PurchaseOrdersTable, PurchaseOrder>
    ),
    PurchaseOrder,
    PrefetchHooks Function()> {
  $$PurchaseOrdersTableTableManager(
      _$AppDatabase db, $PurchaseOrdersTable table)
      : super(TableManagerState(
          db: db,
          table: table,
          createFilteringComposer: () =>
              $$PurchaseOrdersTableFilterComposer($db: db, $table: table),
          createOrderingComposer: () =>
              $$PurchaseOrdersTableOrderingComposer($db: db, $table: table),
          createComputedFieldComposer: () =>
              $$PurchaseOrdersTableAnnotationComposer($db: db, $table: table),
          updateCompanionCallback: ({
            Value<String> id = const Value.absent(),
            Value<String> orderNumber = const Value.absent(),
            Value<String> partnerName = const Value.absent(),
            Value<DateTime> orderDate = const Value.absent(),
            Value<double> totalAmount = const Value.absent(),
            Value<String> status = const Value.absent(),
            Value<DateTime> createdAt = const Value.absent(),
            Value<String> customFields = const Value.absent(),
            Value<int> rowid = const Value.absent(),
          }) =>
              PurchaseOrdersCompanion(
            id: id,
            orderNumber: orderNumber,
            partnerName: partnerName,
            orderDate: orderDate,
            totalAmount: totalAmount,
            status: status,
            createdAt: createdAt,
            customFields: customFields,
            rowid: rowid,
          ),
          createCompanionCallback: ({
            required String id,
            required String orderNumber,
            required String partnerName,
            Value<DateTime> orderDate = const Value.absent(),
            Value<double> totalAmount = const Value.absent(),
            Value<String> status = const Value.absent(),
            Value<DateTime> createdAt = const Value.absent(),
            Value<String> customFields = const Value.absent(),
            Value<int> rowid = const Value.absent(),
          }) =>
              PurchaseOrdersCompanion.insert(
            id: id,
            orderNumber: orderNumber,
            partnerName: partnerName,
            orderDate: orderDate,
            totalAmount: totalAmount,
            status: status,
            createdAt: createdAt,
            customFields: customFields,
            rowid: rowid,
          ),
          withReferenceMapper: (p0) => p0
              .map((e) => (e.readTable(table), BaseReferences(db, table, e)))
              .toList(),
          prefetchHooksCallback: null,
        ));
}

typedef $$PurchaseOrdersTableProcessedTableManager = ProcessedTableManager<
    _$AppDatabase,
    $PurchaseOrdersTable,
    PurchaseOrder,
    $$PurchaseOrdersTableFilterComposer,
    $$PurchaseOrdersTableOrderingComposer,
    $$PurchaseOrdersTableAnnotationComposer,
    $$PurchaseOrdersTableCreateCompanionBuilder,
    $$PurchaseOrdersTableUpdateCompanionBuilder,
    (
      PurchaseOrder,
      BaseReferences<_$AppDatabase, $PurchaseOrdersTable, PurchaseOrder>
    ),
    PurchaseOrder,
    PrefetchHooks Function()>;
typedef $$PurchaseOrderLinesTableCreateCompanionBuilder
    = PurchaseOrderLinesCompanion Function({
  required String id,
  required String purchaseOrderId,
  required String productName,
  Value<double> quantity,
  Value<double> unitPrice,
  Value<double> totalPrice,
  Value<DateTime> createdAt,
  Value<int> rowid,
});
typedef $$PurchaseOrderLinesTableUpdateCompanionBuilder
    = PurchaseOrderLinesCompanion Function({
  Value<String> id,
  Value<String> purchaseOrderId,
  Value<String> productName,
  Value<double> quantity,
  Value<double> unitPrice,
  Value<double> totalPrice,
  Value<DateTime> createdAt,
  Value<int> rowid,
});

class $$PurchaseOrderLinesTableFilterComposer
    extends Composer<_$AppDatabase, $PurchaseOrderLinesTable> {
  $$PurchaseOrderLinesTableFilterComposer({
    required super.$db,
    required super.$table,
    super.joinBuilder,
    super.$addJoinBuilderToRootComposer,
    super.$removeJoinBuilderFromRootComposer,
  });
  ColumnFilters<String> get id => $composableBuilder(
      column: $table.id, builder: (column) => ColumnFilters(column));

  ColumnFilters<String> get purchaseOrderId => $composableBuilder(
      column: $table.purchaseOrderId,
      builder: (column) => ColumnFilters(column));

  ColumnFilters<String> get productName => $composableBuilder(
      column: $table.productName, builder: (column) => ColumnFilters(column));

  ColumnFilters<double> get quantity => $composableBuilder(
      column: $table.quantity, builder: (column) => ColumnFilters(column));

  ColumnFilters<double> get unitPrice => $composableBuilder(
      column: $table.unitPrice, builder: (column) => ColumnFilters(column));

  ColumnFilters<double> get totalPrice => $composableBuilder(
      column: $table.totalPrice, builder: (column) => ColumnFilters(column));

  ColumnFilters<DateTime> get createdAt => $composableBuilder(
      column: $table.createdAt, builder: (column) => ColumnFilters(column));
}

class $$PurchaseOrderLinesTableOrderingComposer
    extends Composer<_$AppDatabase, $PurchaseOrderLinesTable> {
  $$PurchaseOrderLinesTableOrderingComposer({
    required super.$db,
    required super.$table,
    super.joinBuilder,
    super.$addJoinBuilderToRootComposer,
    super.$removeJoinBuilderFromRootComposer,
  });
  ColumnOrderings<String> get id => $composableBuilder(
      column: $table.id, builder: (column) => ColumnOrderings(column));

  ColumnOrderings<String> get purchaseOrderId => $composableBuilder(
      column: $table.purchaseOrderId,
      builder: (column) => ColumnOrderings(column));

  ColumnOrderings<String> get productName => $composableBuilder(
      column: $table.productName, builder: (column) => ColumnOrderings(column));

  ColumnOrderings<double> get quantity => $composableBuilder(
      column: $table.quantity, builder: (column) => ColumnOrderings(column));

  ColumnOrderings<double> get unitPrice => $composableBuilder(
      column: $table.unitPrice, builder: (column) => ColumnOrderings(column));

  ColumnOrderings<double> get totalPrice => $composableBuilder(
      column: $table.totalPrice, builder: (column) => ColumnOrderings(column));

  ColumnOrderings<DateTime> get createdAt => $composableBuilder(
      column: $table.createdAt, builder: (column) => ColumnOrderings(column));
}

class $$PurchaseOrderLinesTableAnnotationComposer
    extends Composer<_$AppDatabase, $PurchaseOrderLinesTable> {
  $$PurchaseOrderLinesTableAnnotationComposer({
    required super.$db,
    required super.$table,
    super.joinBuilder,
    super.$addJoinBuilderToRootComposer,
    super.$removeJoinBuilderFromRootComposer,
  });
  GeneratedColumn<String> get id =>
      $composableBuilder(column: $table.id, builder: (column) => column);

  GeneratedColumn<String> get purchaseOrderId => $composableBuilder(
      column: $table.purchaseOrderId, builder: (column) => column);

  GeneratedColumn<String> get productName => $composableBuilder(
      column: $table.productName, builder: (column) => column);

  GeneratedColumn<double> get quantity =>
      $composableBuilder(column: $table.quantity, builder: (column) => column);

  GeneratedColumn<double> get unitPrice =>
      $composableBuilder(column: $table.unitPrice, builder: (column) => column);

  GeneratedColumn<double> get totalPrice => $composableBuilder(
      column: $table.totalPrice, builder: (column) => column);

  GeneratedColumn<DateTime> get createdAt =>
      $composableBuilder(column: $table.createdAt, builder: (column) => column);
}

class $$PurchaseOrderLinesTableTableManager extends RootTableManager<
    _$AppDatabase,
    $PurchaseOrderLinesTable,
    PurchaseOrderLine,
    $$PurchaseOrderLinesTableFilterComposer,
    $$PurchaseOrderLinesTableOrderingComposer,
    $$PurchaseOrderLinesTableAnnotationComposer,
    $$PurchaseOrderLinesTableCreateCompanionBuilder,
    $$PurchaseOrderLinesTableUpdateCompanionBuilder,
    (
      PurchaseOrderLine,
      BaseReferences<_$AppDatabase, $PurchaseOrderLinesTable, PurchaseOrderLine>
    ),
    PurchaseOrderLine,
    PrefetchHooks Function()> {
  $$PurchaseOrderLinesTableTableManager(
      _$AppDatabase db, $PurchaseOrderLinesTable table)
      : super(TableManagerState(
          db: db,
          table: table,
          createFilteringComposer: () =>
              $$PurchaseOrderLinesTableFilterComposer($db: db, $table: table),
          createOrderingComposer: () =>
              $$PurchaseOrderLinesTableOrderingComposer($db: db, $table: table),
          createComputedFieldComposer: () =>
              $$PurchaseOrderLinesTableAnnotationComposer(
                  $db: db, $table: table),
          updateCompanionCallback: ({
            Value<String> id = const Value.absent(),
            Value<String> purchaseOrderId = const Value.absent(),
            Value<String> productName = const Value.absent(),
            Value<double> quantity = const Value.absent(),
            Value<double> unitPrice = const Value.absent(),
            Value<double> totalPrice = const Value.absent(),
            Value<DateTime> createdAt = const Value.absent(),
            Value<int> rowid = const Value.absent(),
          }) =>
              PurchaseOrderLinesCompanion(
            id: id,
            purchaseOrderId: purchaseOrderId,
            productName: productName,
            quantity: quantity,
            unitPrice: unitPrice,
            totalPrice: totalPrice,
            createdAt: createdAt,
            rowid: rowid,
          ),
          createCompanionCallback: ({
            required String id,
            required String purchaseOrderId,
            required String productName,
            Value<double> quantity = const Value.absent(),
            Value<double> unitPrice = const Value.absent(),
            Value<double> totalPrice = const Value.absent(),
            Value<DateTime> createdAt = const Value.absent(),
            Value<int> rowid = const Value.absent(),
          }) =>
              PurchaseOrderLinesCompanion.insert(
            id: id,
            purchaseOrderId: purchaseOrderId,
            productName: productName,
            quantity: quantity,
            unitPrice: unitPrice,
            totalPrice: totalPrice,
            createdAt: createdAt,
            rowid: rowid,
          ),
          withReferenceMapper: (p0) => p0
              .map((e) => (e.readTable(table), BaseReferences(db, table, e)))
              .toList(),
          prefetchHooksCallback: null,
        ));
}

typedef $$PurchaseOrderLinesTableProcessedTableManager = ProcessedTableManager<
    _$AppDatabase,
    $PurchaseOrderLinesTable,
    PurchaseOrderLine,
    $$PurchaseOrderLinesTableFilterComposer,
    $$PurchaseOrderLinesTableOrderingComposer,
    $$PurchaseOrderLinesTableAnnotationComposer,
    $$PurchaseOrderLinesTableCreateCompanionBuilder,
    $$PurchaseOrderLinesTableUpdateCompanionBuilder,
    (
      PurchaseOrderLine,
      BaseReferences<_$AppDatabase, $PurchaseOrderLinesTable, PurchaseOrderLine>
    ),
    PurchaseOrderLine,
    PrefetchHooks Function()>;
typedef $$AuContactsTableCreateCompanionBuilder = AuContactsCompanion Function({
  required String id,
  Value<String?> abn,
  Value<String?> abnStatus,
  Value<bool> isRctiEligible,
  Value<String?> bpayBillerCode,
  Value<String?> bpayCrn,
  Value<String?> bankBsb,
  Value<String?> bankAccountNumber,
  Value<int> rowid,
});
typedef $$AuContactsTableUpdateCompanionBuilder = AuContactsCompanion Function({
  Value<String> id,
  Value<String?> abn,
  Value<String?> abnStatus,
  Value<bool> isRctiEligible,
  Value<String?> bpayBillerCode,
  Value<String?> bpayCrn,
  Value<String?> bankBsb,
  Value<String?> bankAccountNumber,
  Value<int> rowid,
});

class $$AuContactsTableFilterComposer
    extends Composer<_$AppDatabase, $AuContactsTable> {
  $$AuContactsTableFilterComposer({
    required super.$db,
    required super.$table,
    super.joinBuilder,
    super.$addJoinBuilderToRootComposer,
    super.$removeJoinBuilderFromRootComposer,
  });
  ColumnFilters<String> get id => $composableBuilder(
      column: $table.id, builder: (column) => ColumnFilters(column));

  ColumnFilters<String> get abn => $composableBuilder(
      column: $table.abn, builder: (column) => ColumnFilters(column));

  ColumnFilters<String> get abnStatus => $composableBuilder(
      column: $table.abnStatus, builder: (column) => ColumnFilters(column));

  ColumnFilters<bool> get isRctiEligible => $composableBuilder(
      column: $table.isRctiEligible,
      builder: (column) => ColumnFilters(column));

  ColumnFilters<String> get bpayBillerCode => $composableBuilder(
      column: $table.bpayBillerCode,
      builder: (column) => ColumnFilters(column));

  ColumnFilters<String> get bpayCrn => $composableBuilder(
      column: $table.bpayCrn, builder: (column) => ColumnFilters(column));

  ColumnFilters<String> get bankBsb => $composableBuilder(
      column: $table.bankBsb, builder: (column) => ColumnFilters(column));

  ColumnFilters<String> get bankAccountNumber => $composableBuilder(
      column: $table.bankAccountNumber,
      builder: (column) => ColumnFilters(column));
}

class $$AuContactsTableOrderingComposer
    extends Composer<_$AppDatabase, $AuContactsTable> {
  $$AuContactsTableOrderingComposer({
    required super.$db,
    required super.$table,
    super.joinBuilder,
    super.$addJoinBuilderToRootComposer,
    super.$removeJoinBuilderFromRootComposer,
  });
  ColumnOrderings<String> get id => $composableBuilder(
      column: $table.id, builder: (column) => ColumnOrderings(column));

  ColumnOrderings<String> get abn => $composableBuilder(
      column: $table.abn, builder: (column) => ColumnOrderings(column));

  ColumnOrderings<String> get abnStatus => $composableBuilder(
      column: $table.abnStatus, builder: (column) => ColumnOrderings(column));

  ColumnOrderings<bool> get isRctiEligible => $composableBuilder(
      column: $table.isRctiEligible,
      builder: (column) => ColumnOrderings(column));

  ColumnOrderings<String> get bpayBillerCode => $composableBuilder(
      column: $table.bpayBillerCode,
      builder: (column) => ColumnOrderings(column));

  ColumnOrderings<String> get bpayCrn => $composableBuilder(
      column: $table.bpayCrn, builder: (column) => ColumnOrderings(column));

  ColumnOrderings<String> get bankBsb => $composableBuilder(
      column: $table.bankBsb, builder: (column) => ColumnOrderings(column));

  ColumnOrderings<String> get bankAccountNumber => $composableBuilder(
      column: $table.bankAccountNumber,
      builder: (column) => ColumnOrderings(column));
}

class $$AuContactsTableAnnotationComposer
    extends Composer<_$AppDatabase, $AuContactsTable> {
  $$AuContactsTableAnnotationComposer({
    required super.$db,
    required super.$table,
    super.joinBuilder,
    super.$addJoinBuilderToRootComposer,
    super.$removeJoinBuilderFromRootComposer,
  });
  GeneratedColumn<String> get id =>
      $composableBuilder(column: $table.id, builder: (column) => column);

  GeneratedColumn<String> get abn =>
      $composableBuilder(column: $table.abn, builder: (column) => column);

  GeneratedColumn<String> get abnStatus =>
      $composableBuilder(column: $table.abnStatus, builder: (column) => column);

  GeneratedColumn<bool> get isRctiEligible => $composableBuilder(
      column: $table.isRctiEligible, builder: (column) => column);

  GeneratedColumn<String> get bpayBillerCode => $composableBuilder(
      column: $table.bpayBillerCode, builder: (column) => column);

  GeneratedColumn<String> get bpayCrn =>
      $composableBuilder(column: $table.bpayCrn, builder: (column) => column);

  GeneratedColumn<String> get bankBsb =>
      $composableBuilder(column: $table.bankBsb, builder: (column) => column);

  GeneratedColumn<String> get bankAccountNumber => $composableBuilder(
      column: $table.bankAccountNumber, builder: (column) => column);
}

class $$AuContactsTableTableManager extends RootTableManager<
    _$AppDatabase,
    $AuContactsTable,
    AuContact,
    $$AuContactsTableFilterComposer,
    $$AuContactsTableOrderingComposer,
    $$AuContactsTableAnnotationComposer,
    $$AuContactsTableCreateCompanionBuilder,
    $$AuContactsTableUpdateCompanionBuilder,
    (AuContact, BaseReferences<_$AppDatabase, $AuContactsTable, AuContact>),
    AuContact,
    PrefetchHooks Function()> {
  $$AuContactsTableTableManager(_$AppDatabase db, $AuContactsTable table)
      : super(TableManagerState(
          db: db,
          table: table,
          createFilteringComposer: () =>
              $$AuContactsTableFilterComposer($db: db, $table: table),
          createOrderingComposer: () =>
              $$AuContactsTableOrderingComposer($db: db, $table: table),
          createComputedFieldComposer: () =>
              $$AuContactsTableAnnotationComposer($db: db, $table: table),
          updateCompanionCallback: ({
            Value<String> id = const Value.absent(),
            Value<String?> abn = const Value.absent(),
            Value<String?> abnStatus = const Value.absent(),
            Value<bool> isRctiEligible = const Value.absent(),
            Value<String?> bpayBillerCode = const Value.absent(),
            Value<String?> bpayCrn = const Value.absent(),
            Value<String?> bankBsb = const Value.absent(),
            Value<String?> bankAccountNumber = const Value.absent(),
            Value<int> rowid = const Value.absent(),
          }) =>
              AuContactsCompanion(
            id: id,
            abn: abn,
            abnStatus: abnStatus,
            isRctiEligible: isRctiEligible,
            bpayBillerCode: bpayBillerCode,
            bpayCrn: bpayCrn,
            bankBsb: bankBsb,
            bankAccountNumber: bankAccountNumber,
            rowid: rowid,
          ),
          createCompanionCallback: ({
            required String id,
            Value<String?> abn = const Value.absent(),
            Value<String?> abnStatus = const Value.absent(),
            Value<bool> isRctiEligible = const Value.absent(),
            Value<String?> bpayBillerCode = const Value.absent(),
            Value<String?> bpayCrn = const Value.absent(),
            Value<String?> bankBsb = const Value.absent(),
            Value<String?> bankAccountNumber = const Value.absent(),
            Value<int> rowid = const Value.absent(),
          }) =>
              AuContactsCompanion.insert(
            id: id,
            abn: abn,
            abnStatus: abnStatus,
            isRctiEligible: isRctiEligible,
            bpayBillerCode: bpayBillerCode,
            bpayCrn: bpayCrn,
            bankBsb: bankBsb,
            bankAccountNumber: bankAccountNumber,
            rowid: rowid,
          ),
          withReferenceMapper: (p0) => p0
              .map((e) => (e.readTable(table), BaseReferences(db, table, e)))
              .toList(),
          prefetchHooksCallback: null,
        ));
}

typedef $$AuContactsTableProcessedTableManager = ProcessedTableManager<
    _$AppDatabase,
    $AuContactsTable,
    AuContact,
    $$AuContactsTableFilterComposer,
    $$AuContactsTableOrderingComposer,
    $$AuContactsTableAnnotationComposer,
    $$AuContactsTableCreateCompanionBuilder,
    $$AuContactsTableUpdateCompanionBuilder,
    (AuContact, BaseReferences<_$AppDatabase, $AuContactsTable, AuContact>),
    AuContact,
    PrefetchHooks Function()>;
typedef $$AccountsTableCreateCompanionBuilder = AccountsCompanion Function({
  required String id,
  required String code,
  required String name,
  required String category,
  Value<String> gstTaxCode,
  Value<double> balance,
  Value<bool> isActive,
  Value<int> rowid,
});
typedef $$AccountsTableUpdateCompanionBuilder = AccountsCompanion Function({
  Value<String> id,
  Value<String> code,
  Value<String> name,
  Value<String> category,
  Value<String> gstTaxCode,
  Value<double> balance,
  Value<bool> isActive,
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

  ColumnFilters<String> get category => $composableBuilder(
      column: $table.category, builder: (column) => ColumnFilters(column));

  ColumnFilters<String> get gstTaxCode => $composableBuilder(
      column: $table.gstTaxCode, builder: (column) => ColumnFilters(column));

  ColumnFilters<double> get balance => $composableBuilder(
      column: $table.balance, builder: (column) => ColumnFilters(column));

  ColumnFilters<bool> get isActive => $composableBuilder(
      column: $table.isActive, builder: (column) => ColumnFilters(column));
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

  ColumnOrderings<String> get category => $composableBuilder(
      column: $table.category, builder: (column) => ColumnOrderings(column));

  ColumnOrderings<String> get gstTaxCode => $composableBuilder(
      column: $table.gstTaxCode, builder: (column) => ColumnOrderings(column));

  ColumnOrderings<double> get balance => $composableBuilder(
      column: $table.balance, builder: (column) => ColumnOrderings(column));

  ColumnOrderings<bool> get isActive => $composableBuilder(
      column: $table.isActive, builder: (column) => ColumnOrderings(column));
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

  GeneratedColumn<String> get category =>
      $composableBuilder(column: $table.category, builder: (column) => column);

  GeneratedColumn<String> get gstTaxCode => $composableBuilder(
      column: $table.gstTaxCode, builder: (column) => column);

  GeneratedColumn<double> get balance =>
      $composableBuilder(column: $table.balance, builder: (column) => column);

  GeneratedColumn<bool> get isActive =>
      $composableBuilder(column: $table.isActive, builder: (column) => column);
}

class $$AccountsTableTableManager extends RootTableManager<
    _$AppDatabase,
    $AccountsTable,
    Account,
    $$AccountsTableFilterComposer,
    $$AccountsTableOrderingComposer,
    $$AccountsTableAnnotationComposer,
    $$AccountsTableCreateCompanionBuilder,
    $$AccountsTableUpdateCompanionBuilder,
    (Account, BaseReferences<_$AppDatabase, $AccountsTable, Account>),
    Account,
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
            Value<String> category = const Value.absent(),
            Value<String> gstTaxCode = const Value.absent(),
            Value<double> balance = const Value.absent(),
            Value<bool> isActive = const Value.absent(),
            Value<int> rowid = const Value.absent(),
          }) =>
              AccountsCompanion(
            id: id,
            code: code,
            name: name,
            category: category,
            gstTaxCode: gstTaxCode,
            balance: balance,
            isActive: isActive,
            rowid: rowid,
          ),
          createCompanionCallback: ({
            required String id,
            required String code,
            required String name,
            required String category,
            Value<String> gstTaxCode = const Value.absent(),
            Value<double> balance = const Value.absent(),
            Value<bool> isActive = const Value.absent(),
            Value<int> rowid = const Value.absent(),
          }) =>
              AccountsCompanion.insert(
            id: id,
            code: code,
            name: name,
            category: category,
            gstTaxCode: gstTaxCode,
            balance: balance,
            isActive: isActive,
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
    Account,
    $$AccountsTableFilterComposer,
    $$AccountsTableOrderingComposer,
    $$AccountsTableAnnotationComposer,
    $$AccountsTableCreateCompanionBuilder,
    $$AccountsTableUpdateCompanionBuilder,
    (Account, BaseReferences<_$AppDatabase, $AccountsTable, Account>),
    Account,
    PrefetchHooks Function()>;
typedef $$TaxRatesTableCreateCompanionBuilder = TaxRatesCompanion Function({
  required String code,
  required double rate,
  required String description,
  Value<int> rowid,
});
typedef $$TaxRatesTableUpdateCompanionBuilder = TaxRatesCompanion Function({
  Value<String> code,
  Value<double> rate,
  Value<String> description,
  Value<int> rowid,
});

class $$TaxRatesTableFilterComposer
    extends Composer<_$AppDatabase, $TaxRatesTable> {
  $$TaxRatesTableFilterComposer({
    required super.$db,
    required super.$table,
    super.joinBuilder,
    super.$addJoinBuilderToRootComposer,
    super.$removeJoinBuilderFromRootComposer,
  });
  ColumnFilters<String> get code => $composableBuilder(
      column: $table.code, builder: (column) => ColumnFilters(column));

  ColumnFilters<double> get rate => $composableBuilder(
      column: $table.rate, builder: (column) => ColumnFilters(column));

  ColumnFilters<String> get description => $composableBuilder(
      column: $table.description, builder: (column) => ColumnFilters(column));
}

class $$TaxRatesTableOrderingComposer
    extends Composer<_$AppDatabase, $TaxRatesTable> {
  $$TaxRatesTableOrderingComposer({
    required super.$db,
    required super.$table,
    super.joinBuilder,
    super.$addJoinBuilderToRootComposer,
    super.$removeJoinBuilderFromRootComposer,
  });
  ColumnOrderings<String> get code => $composableBuilder(
      column: $table.code, builder: (column) => ColumnOrderings(column));

  ColumnOrderings<double> get rate => $composableBuilder(
      column: $table.rate, builder: (column) => ColumnOrderings(column));

  ColumnOrderings<String> get description => $composableBuilder(
      column: $table.description, builder: (column) => ColumnOrderings(column));
}

class $$TaxRatesTableAnnotationComposer
    extends Composer<_$AppDatabase, $TaxRatesTable> {
  $$TaxRatesTableAnnotationComposer({
    required super.$db,
    required super.$table,
    super.joinBuilder,
    super.$addJoinBuilderToRootComposer,
    super.$removeJoinBuilderFromRootComposer,
  });
  GeneratedColumn<String> get code =>
      $composableBuilder(column: $table.code, builder: (column) => column);

  GeneratedColumn<double> get rate =>
      $composableBuilder(column: $table.rate, builder: (column) => column);

  GeneratedColumn<String> get description => $composableBuilder(
      column: $table.description, builder: (column) => column);
}

class $$TaxRatesTableTableManager extends RootTableManager<
    _$AppDatabase,
    $TaxRatesTable,
    TaxRate,
    $$TaxRatesTableFilterComposer,
    $$TaxRatesTableOrderingComposer,
    $$TaxRatesTableAnnotationComposer,
    $$TaxRatesTableCreateCompanionBuilder,
    $$TaxRatesTableUpdateCompanionBuilder,
    (TaxRate, BaseReferences<_$AppDatabase, $TaxRatesTable, TaxRate>),
    TaxRate,
    PrefetchHooks Function()> {
  $$TaxRatesTableTableManager(_$AppDatabase db, $TaxRatesTable table)
      : super(TableManagerState(
          db: db,
          table: table,
          createFilteringComposer: () =>
              $$TaxRatesTableFilterComposer($db: db, $table: table),
          createOrderingComposer: () =>
              $$TaxRatesTableOrderingComposer($db: db, $table: table),
          createComputedFieldComposer: () =>
              $$TaxRatesTableAnnotationComposer($db: db, $table: table),
          updateCompanionCallback: ({
            Value<String> code = const Value.absent(),
            Value<double> rate = const Value.absent(),
            Value<String> description = const Value.absent(),
            Value<int> rowid = const Value.absent(),
          }) =>
              TaxRatesCompanion(
            code: code,
            rate: rate,
            description: description,
            rowid: rowid,
          ),
          createCompanionCallback: ({
            required String code,
            required double rate,
            required String description,
            Value<int> rowid = const Value.absent(),
          }) =>
              TaxRatesCompanion.insert(
            code: code,
            rate: rate,
            description: description,
            rowid: rowid,
          ),
          withReferenceMapper: (p0) => p0
              .map((e) => (e.readTable(table), BaseReferences(db, table, e)))
              .toList(),
          prefetchHooksCallback: null,
        ));
}

typedef $$TaxRatesTableProcessedTableManager = ProcessedTableManager<
    _$AppDatabase,
    $TaxRatesTable,
    TaxRate,
    $$TaxRatesTableFilterComposer,
    $$TaxRatesTableOrderingComposer,
    $$TaxRatesTableAnnotationComposer,
    $$TaxRatesTableCreateCompanionBuilder,
    $$TaxRatesTableUpdateCompanionBuilder,
    (TaxRate, BaseReferences<_$AppDatabase, $TaxRatesTable, TaxRate>),
    TaxRate,
    PrefetchHooks Function()>;
typedef $$JournalEntriesTableCreateCompanionBuilder = JournalEntriesCompanion
    Function({
  required String id,
  required DateTime entryDate,
  Value<String?> reference,
  Value<String?> narration,
  Value<DateTime> createdAt,
  Value<int> rowid,
});
typedef $$JournalEntriesTableUpdateCompanionBuilder = JournalEntriesCompanion
    Function({
  Value<String> id,
  Value<DateTime> entryDate,
  Value<String?> reference,
  Value<String?> narration,
  Value<DateTime> createdAt,
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

  ColumnFilters<DateTime> get entryDate => $composableBuilder(
      column: $table.entryDate, builder: (column) => ColumnFilters(column));

  ColumnFilters<String> get reference => $composableBuilder(
      column: $table.reference, builder: (column) => ColumnFilters(column));

  ColumnFilters<String> get narration => $composableBuilder(
      column: $table.narration, builder: (column) => ColumnFilters(column));

  ColumnFilters<DateTime> get createdAt => $composableBuilder(
      column: $table.createdAt, builder: (column) => ColumnFilters(column));
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

  ColumnOrderings<DateTime> get entryDate => $composableBuilder(
      column: $table.entryDate, builder: (column) => ColumnOrderings(column));

  ColumnOrderings<String> get reference => $composableBuilder(
      column: $table.reference, builder: (column) => ColumnOrderings(column));

  ColumnOrderings<String> get narration => $composableBuilder(
      column: $table.narration, builder: (column) => ColumnOrderings(column));

  ColumnOrderings<DateTime> get createdAt => $composableBuilder(
      column: $table.createdAt, builder: (column) => ColumnOrderings(column));
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

  GeneratedColumn<DateTime> get entryDate =>
      $composableBuilder(column: $table.entryDate, builder: (column) => column);

  GeneratedColumn<String> get reference =>
      $composableBuilder(column: $table.reference, builder: (column) => column);

  GeneratedColumn<String> get narration =>
      $composableBuilder(column: $table.narration, builder: (column) => column);

  GeneratedColumn<DateTime> get createdAt =>
      $composableBuilder(column: $table.createdAt, builder: (column) => column);
}

class $$JournalEntriesTableTableManager extends RootTableManager<
    _$AppDatabase,
    $JournalEntriesTable,
    JournalEntry,
    $$JournalEntriesTableFilterComposer,
    $$JournalEntriesTableOrderingComposer,
    $$JournalEntriesTableAnnotationComposer,
    $$JournalEntriesTableCreateCompanionBuilder,
    $$JournalEntriesTableUpdateCompanionBuilder,
    (
      JournalEntry,
      BaseReferences<_$AppDatabase, $JournalEntriesTable, JournalEntry>
    ),
    JournalEntry,
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
            Value<DateTime> entryDate = const Value.absent(),
            Value<String?> reference = const Value.absent(),
            Value<String?> narration = const Value.absent(),
            Value<DateTime> createdAt = const Value.absent(),
            Value<int> rowid = const Value.absent(),
          }) =>
              JournalEntriesCompanion(
            id: id,
            entryDate: entryDate,
            reference: reference,
            narration: narration,
            createdAt: createdAt,
            rowid: rowid,
          ),
          createCompanionCallback: ({
            required String id,
            required DateTime entryDate,
            Value<String?> reference = const Value.absent(),
            Value<String?> narration = const Value.absent(),
            Value<DateTime> createdAt = const Value.absent(),
            Value<int> rowid = const Value.absent(),
          }) =>
              JournalEntriesCompanion.insert(
            id: id,
            entryDate: entryDate,
            reference: reference,
            narration: narration,
            createdAt: createdAt,
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
    JournalEntry,
    $$JournalEntriesTableFilterComposer,
    $$JournalEntriesTableOrderingComposer,
    $$JournalEntriesTableAnnotationComposer,
    $$JournalEntriesTableCreateCompanionBuilder,
    $$JournalEntriesTableUpdateCompanionBuilder,
    (
      JournalEntry,
      BaseReferences<_$AppDatabase, $JournalEntriesTable, JournalEntry>
    ),
    JournalEntry,
    PrefetchHooks Function()>;
typedef $$JournalLinesTableCreateCompanionBuilder = JournalLinesCompanion
    Function({
  required String id,
  required String journalEntryId,
  required String accountId,
  Value<double> debit,
  Value<double> credit,
  Value<double> gstAmount,
  Value<String?> gstTaxCode,
  Value<int> rowid,
});
typedef $$JournalLinesTableUpdateCompanionBuilder = JournalLinesCompanion
    Function({
  Value<String> id,
  Value<String> journalEntryId,
  Value<String> accountId,
  Value<double> debit,
  Value<double> credit,
  Value<double> gstAmount,
  Value<String?> gstTaxCode,
  Value<int> rowid,
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
  ColumnFilters<String> get id => $composableBuilder(
      column: $table.id, builder: (column) => ColumnFilters(column));

  ColumnFilters<String> get journalEntryId => $composableBuilder(
      column: $table.journalEntryId,
      builder: (column) => ColumnFilters(column));

  ColumnFilters<String> get accountId => $composableBuilder(
      column: $table.accountId, builder: (column) => ColumnFilters(column));

  ColumnFilters<double> get debit => $composableBuilder(
      column: $table.debit, builder: (column) => ColumnFilters(column));

  ColumnFilters<double> get credit => $composableBuilder(
      column: $table.credit, builder: (column) => ColumnFilters(column));

  ColumnFilters<double> get gstAmount => $composableBuilder(
      column: $table.gstAmount, builder: (column) => ColumnFilters(column));

  ColumnFilters<String> get gstTaxCode => $composableBuilder(
      column: $table.gstTaxCode, builder: (column) => ColumnFilters(column));
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
  ColumnOrderings<String> get id => $composableBuilder(
      column: $table.id, builder: (column) => ColumnOrderings(column));

  ColumnOrderings<String> get journalEntryId => $composableBuilder(
      column: $table.journalEntryId,
      builder: (column) => ColumnOrderings(column));

  ColumnOrderings<String> get accountId => $composableBuilder(
      column: $table.accountId, builder: (column) => ColumnOrderings(column));

  ColumnOrderings<double> get debit => $composableBuilder(
      column: $table.debit, builder: (column) => ColumnOrderings(column));

  ColumnOrderings<double> get credit => $composableBuilder(
      column: $table.credit, builder: (column) => ColumnOrderings(column));

  ColumnOrderings<double> get gstAmount => $composableBuilder(
      column: $table.gstAmount, builder: (column) => ColumnOrderings(column));

  ColumnOrderings<String> get gstTaxCode => $composableBuilder(
      column: $table.gstTaxCode, builder: (column) => ColumnOrderings(column));
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
  GeneratedColumn<String> get id =>
      $composableBuilder(column: $table.id, builder: (column) => column);

  GeneratedColumn<String> get journalEntryId => $composableBuilder(
      column: $table.journalEntryId, builder: (column) => column);

  GeneratedColumn<String> get accountId =>
      $composableBuilder(column: $table.accountId, builder: (column) => column);

  GeneratedColumn<double> get debit =>
      $composableBuilder(column: $table.debit, builder: (column) => column);

  GeneratedColumn<double> get credit =>
      $composableBuilder(column: $table.credit, builder: (column) => column);

  GeneratedColumn<double> get gstAmount =>
      $composableBuilder(column: $table.gstAmount, builder: (column) => column);

  GeneratedColumn<String> get gstTaxCode => $composableBuilder(
      column: $table.gstTaxCode, builder: (column) => column);
}

class $$JournalLinesTableTableManager extends RootTableManager<
    _$AppDatabase,
    $JournalLinesTable,
    JournalLine,
    $$JournalLinesTableFilterComposer,
    $$JournalLinesTableOrderingComposer,
    $$JournalLinesTableAnnotationComposer,
    $$JournalLinesTableCreateCompanionBuilder,
    $$JournalLinesTableUpdateCompanionBuilder,
    (
      JournalLine,
      BaseReferences<_$AppDatabase, $JournalLinesTable, JournalLine>
    ),
    JournalLine,
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
            Value<String> id = const Value.absent(),
            Value<String> journalEntryId = const Value.absent(),
            Value<String> accountId = const Value.absent(),
            Value<double> debit = const Value.absent(),
            Value<double> credit = const Value.absent(),
            Value<double> gstAmount = const Value.absent(),
            Value<String?> gstTaxCode = const Value.absent(),
            Value<int> rowid = const Value.absent(),
          }) =>
              JournalLinesCompanion(
            id: id,
            journalEntryId: journalEntryId,
            accountId: accountId,
            debit: debit,
            credit: credit,
            gstAmount: gstAmount,
            gstTaxCode: gstTaxCode,
            rowid: rowid,
          ),
          createCompanionCallback: ({
            required String id,
            required String journalEntryId,
            required String accountId,
            Value<double> debit = const Value.absent(),
            Value<double> credit = const Value.absent(),
            Value<double> gstAmount = const Value.absent(),
            Value<String?> gstTaxCode = const Value.absent(),
            Value<int> rowid = const Value.absent(),
          }) =>
              JournalLinesCompanion.insert(
            id: id,
            journalEntryId: journalEntryId,
            accountId: accountId,
            debit: debit,
            credit: credit,
            gstAmount: gstAmount,
            gstTaxCode: gstTaxCode,
            rowid: rowid,
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
    JournalLine,
    $$JournalLinesTableFilterComposer,
    $$JournalLinesTableOrderingComposer,
    $$JournalLinesTableAnnotationComposer,
    $$JournalLinesTableCreateCompanionBuilder,
    $$JournalLinesTableUpdateCompanionBuilder,
    (
      JournalLine,
      BaseReferences<_$AppDatabase, $JournalLinesTable, JournalLine>
    ),
    JournalLine,
    PrefetchHooks Function()>;
typedef $$PayrollEventsTableCreateCompanionBuilder = PayrollEventsCompanion
    Function({
  required String id,
  required DateTime payPeriodStart,
  required DateTime payPeriodEnd,
  required DateTime paymentDate,
  required double totalGross,
  required double totalTaxWithheld,
  required double totalSuper,
  Value<String> stpSubmissionStatus,
  Value<String?> stpReceiptNumber,
  Value<DateTime> createdAt,
  Value<int> rowid,
});
typedef $$PayrollEventsTableUpdateCompanionBuilder = PayrollEventsCompanion
    Function({
  Value<String> id,
  Value<DateTime> payPeriodStart,
  Value<DateTime> payPeriodEnd,
  Value<DateTime> paymentDate,
  Value<double> totalGross,
  Value<double> totalTaxWithheld,
  Value<double> totalSuper,
  Value<String> stpSubmissionStatus,
  Value<String?> stpReceiptNumber,
  Value<DateTime> createdAt,
  Value<int> rowid,
});

class $$PayrollEventsTableFilterComposer
    extends Composer<_$AppDatabase, $PayrollEventsTable> {
  $$PayrollEventsTableFilterComposer({
    required super.$db,
    required super.$table,
    super.joinBuilder,
    super.$addJoinBuilderToRootComposer,
    super.$removeJoinBuilderFromRootComposer,
  });
  ColumnFilters<String> get id => $composableBuilder(
      column: $table.id, builder: (column) => ColumnFilters(column));

  ColumnFilters<DateTime> get payPeriodStart => $composableBuilder(
      column: $table.payPeriodStart,
      builder: (column) => ColumnFilters(column));

  ColumnFilters<DateTime> get payPeriodEnd => $composableBuilder(
      column: $table.payPeriodEnd, builder: (column) => ColumnFilters(column));

  ColumnFilters<DateTime> get paymentDate => $composableBuilder(
      column: $table.paymentDate, builder: (column) => ColumnFilters(column));

  ColumnFilters<double> get totalGross => $composableBuilder(
      column: $table.totalGross, builder: (column) => ColumnFilters(column));

  ColumnFilters<double> get totalTaxWithheld => $composableBuilder(
      column: $table.totalTaxWithheld,
      builder: (column) => ColumnFilters(column));

  ColumnFilters<double> get totalSuper => $composableBuilder(
      column: $table.totalSuper, builder: (column) => ColumnFilters(column));

  ColumnFilters<String> get stpSubmissionStatus => $composableBuilder(
      column: $table.stpSubmissionStatus,
      builder: (column) => ColumnFilters(column));

  ColumnFilters<String> get stpReceiptNumber => $composableBuilder(
      column: $table.stpReceiptNumber,
      builder: (column) => ColumnFilters(column));

  ColumnFilters<DateTime> get createdAt => $composableBuilder(
      column: $table.createdAt, builder: (column) => ColumnFilters(column));
}

class $$PayrollEventsTableOrderingComposer
    extends Composer<_$AppDatabase, $PayrollEventsTable> {
  $$PayrollEventsTableOrderingComposer({
    required super.$db,
    required super.$table,
    super.joinBuilder,
    super.$addJoinBuilderToRootComposer,
    super.$removeJoinBuilderFromRootComposer,
  });
  ColumnOrderings<String> get id => $composableBuilder(
      column: $table.id, builder: (column) => ColumnOrderings(column));

  ColumnOrderings<DateTime> get payPeriodStart => $composableBuilder(
      column: $table.payPeriodStart,
      builder: (column) => ColumnOrderings(column));

  ColumnOrderings<DateTime> get payPeriodEnd => $composableBuilder(
      column: $table.payPeriodEnd,
      builder: (column) => ColumnOrderings(column));

  ColumnOrderings<DateTime> get paymentDate => $composableBuilder(
      column: $table.paymentDate, builder: (column) => ColumnOrderings(column));

  ColumnOrderings<double> get totalGross => $composableBuilder(
      column: $table.totalGross, builder: (column) => ColumnOrderings(column));

  ColumnOrderings<double> get totalTaxWithheld => $composableBuilder(
      column: $table.totalTaxWithheld,
      builder: (column) => ColumnOrderings(column));

  ColumnOrderings<double> get totalSuper => $composableBuilder(
      column: $table.totalSuper, builder: (column) => ColumnOrderings(column));

  ColumnOrderings<String> get stpSubmissionStatus => $composableBuilder(
      column: $table.stpSubmissionStatus,
      builder: (column) => ColumnOrderings(column));

  ColumnOrderings<String> get stpReceiptNumber => $composableBuilder(
      column: $table.stpReceiptNumber,
      builder: (column) => ColumnOrderings(column));

  ColumnOrderings<DateTime> get createdAt => $composableBuilder(
      column: $table.createdAt, builder: (column) => ColumnOrderings(column));
}

class $$PayrollEventsTableAnnotationComposer
    extends Composer<_$AppDatabase, $PayrollEventsTable> {
  $$PayrollEventsTableAnnotationComposer({
    required super.$db,
    required super.$table,
    super.joinBuilder,
    super.$addJoinBuilderToRootComposer,
    super.$removeJoinBuilderFromRootComposer,
  });
  GeneratedColumn<String> get id =>
      $composableBuilder(column: $table.id, builder: (column) => column);

  GeneratedColumn<DateTime> get payPeriodStart => $composableBuilder(
      column: $table.payPeriodStart, builder: (column) => column);

  GeneratedColumn<DateTime> get payPeriodEnd => $composableBuilder(
      column: $table.payPeriodEnd, builder: (column) => column);

  GeneratedColumn<DateTime> get paymentDate => $composableBuilder(
      column: $table.paymentDate, builder: (column) => column);

  GeneratedColumn<double> get totalGross => $composableBuilder(
      column: $table.totalGross, builder: (column) => column);

  GeneratedColumn<double> get totalTaxWithheld => $composableBuilder(
      column: $table.totalTaxWithheld, builder: (column) => column);

  GeneratedColumn<double> get totalSuper => $composableBuilder(
      column: $table.totalSuper, builder: (column) => column);

  GeneratedColumn<String> get stpSubmissionStatus => $composableBuilder(
      column: $table.stpSubmissionStatus, builder: (column) => column);

  GeneratedColumn<String> get stpReceiptNumber => $composableBuilder(
      column: $table.stpReceiptNumber, builder: (column) => column);

  GeneratedColumn<DateTime> get createdAt =>
      $composableBuilder(column: $table.createdAt, builder: (column) => column);
}

class $$PayrollEventsTableTableManager extends RootTableManager<
    _$AppDatabase,
    $PayrollEventsTable,
    PayrollEvent,
    $$PayrollEventsTableFilterComposer,
    $$PayrollEventsTableOrderingComposer,
    $$PayrollEventsTableAnnotationComposer,
    $$PayrollEventsTableCreateCompanionBuilder,
    $$PayrollEventsTableUpdateCompanionBuilder,
    (
      PayrollEvent,
      BaseReferences<_$AppDatabase, $PayrollEventsTable, PayrollEvent>
    ),
    PayrollEvent,
    PrefetchHooks Function()> {
  $$PayrollEventsTableTableManager(_$AppDatabase db, $PayrollEventsTable table)
      : super(TableManagerState(
          db: db,
          table: table,
          createFilteringComposer: () =>
              $$PayrollEventsTableFilterComposer($db: db, $table: table),
          createOrderingComposer: () =>
              $$PayrollEventsTableOrderingComposer($db: db, $table: table),
          createComputedFieldComposer: () =>
              $$PayrollEventsTableAnnotationComposer($db: db, $table: table),
          updateCompanionCallback: ({
            Value<String> id = const Value.absent(),
            Value<DateTime> payPeriodStart = const Value.absent(),
            Value<DateTime> payPeriodEnd = const Value.absent(),
            Value<DateTime> paymentDate = const Value.absent(),
            Value<double> totalGross = const Value.absent(),
            Value<double> totalTaxWithheld = const Value.absent(),
            Value<double> totalSuper = const Value.absent(),
            Value<String> stpSubmissionStatus = const Value.absent(),
            Value<String?> stpReceiptNumber = const Value.absent(),
            Value<DateTime> createdAt = const Value.absent(),
            Value<int> rowid = const Value.absent(),
          }) =>
              PayrollEventsCompanion(
            id: id,
            payPeriodStart: payPeriodStart,
            payPeriodEnd: payPeriodEnd,
            paymentDate: paymentDate,
            totalGross: totalGross,
            totalTaxWithheld: totalTaxWithheld,
            totalSuper: totalSuper,
            stpSubmissionStatus: stpSubmissionStatus,
            stpReceiptNumber: stpReceiptNumber,
            createdAt: createdAt,
            rowid: rowid,
          ),
          createCompanionCallback: ({
            required String id,
            required DateTime payPeriodStart,
            required DateTime payPeriodEnd,
            required DateTime paymentDate,
            required double totalGross,
            required double totalTaxWithheld,
            required double totalSuper,
            Value<String> stpSubmissionStatus = const Value.absent(),
            Value<String?> stpReceiptNumber = const Value.absent(),
            Value<DateTime> createdAt = const Value.absent(),
            Value<int> rowid = const Value.absent(),
          }) =>
              PayrollEventsCompanion.insert(
            id: id,
            payPeriodStart: payPeriodStart,
            payPeriodEnd: payPeriodEnd,
            paymentDate: paymentDate,
            totalGross: totalGross,
            totalTaxWithheld: totalTaxWithheld,
            totalSuper: totalSuper,
            stpSubmissionStatus: stpSubmissionStatus,
            stpReceiptNumber: stpReceiptNumber,
            createdAt: createdAt,
            rowid: rowid,
          ),
          withReferenceMapper: (p0) => p0
              .map((e) => (e.readTable(table), BaseReferences(db, table, e)))
              .toList(),
          prefetchHooksCallback: null,
        ));
}

typedef $$PayrollEventsTableProcessedTableManager = ProcessedTableManager<
    _$AppDatabase,
    $PayrollEventsTable,
    PayrollEvent,
    $$PayrollEventsTableFilterComposer,
    $$PayrollEventsTableOrderingComposer,
    $$PayrollEventsTableAnnotationComposer,
    $$PayrollEventsTableCreateCompanionBuilder,
    $$PayrollEventsTableUpdateCompanionBuilder,
    (
      PayrollEvent,
      BaseReferences<_$AppDatabase, $PayrollEventsTable, PayrollEvent>
    ),
    PayrollEvent,
    PrefetchHooks Function()>;

class $AppDatabaseManager {
  final _$AppDatabase _db;
  $AppDatabaseManager(this._db);
  $$AppSettingsTableTableManager get appSettings =>
      $$AppSettingsTableTableManager(_db, _db.appSettings);
  $$UsersTableTableManager get users =>
      $$UsersTableTableManager(_db, _db.users);
  $$ModuleRegistryTableTableTableManager get moduleRegistryTable =>
      $$ModuleRegistryTableTableTableManager(_db, _db.moduleRegistryTable);
  $$ContactsTableTableManager get contacts =>
      $$ContactsTableTableManager(_db, _db.contacts);
  $$LeadsTableTableManager get leads =>
      $$LeadsTableTableManager(_db, _db.leads);
  $$DealsTableTableManager get deals =>
      $$DealsTableTableManager(_db, _db.deals);
  $$ProductsTableTableManager get products =>
      $$ProductsTableTableManager(_db, _db.products);
  $$StockQuantsTableTableManager get stockQuants =>
      $$StockQuantsTableTableManager(_db, _db.stockQuants);
  $$StockMovesTableTableManager get stockMoves =>
      $$StockMovesTableTableManager(_db, _db.stockMoves);
  $$TrustScoresTableTableManager get trustScores =>
      $$TrustScoresTableTableManager(_db, _db.trustScores);
  $$ReferralsTableTableManager get referrals =>
      $$ReferralsTableTableManager(_db, _db.referrals);
  $$ServiceListingsTableTableManager get serviceListings =>
      $$ServiceListingsTableTableManager(_db, _db.serviceListings);
  $$ServiceOrdersTableTableManager get serviceOrders =>
      $$ServiceOrdersTableTableManager(_db, _db.serviceOrders);
  $$ReviewsTableTableManager get reviews =>
      $$ReviewsTableTableManager(_db, _db.reviews);
  $$ServiceItemsTableTableManager get serviceItems =>
      $$ServiceItemsTableTableManager(_db, _db.serviceItems);
  $$ServiceBookingsTableTableManager get serviceBookings =>
      $$ServiceBookingsTableTableManager(_db, _db.serviceBookings);
  $$OutboxMutationsTableTableManager get outboxMutations =>
      $$OutboxMutationsTableTableManager(_db, _db.outboxMutations);
  $$ProjectsTableTableManager get projects =>
      $$ProjectsTableTableManager(_db, _db.projects);
  $$TasksTableTableManager get tasks =>
      $$TasksTableTableManager(_db, _db.tasks);
  $$PurchaseOrdersTableTableManager get purchaseOrders =>
      $$PurchaseOrdersTableTableManager(_db, _db.purchaseOrders);
  $$PurchaseOrderLinesTableTableManager get purchaseOrderLines =>
      $$PurchaseOrderLinesTableTableManager(_db, _db.purchaseOrderLines);
  $$AuContactsTableTableManager get auContacts =>
      $$AuContactsTableTableManager(_db, _db.auContacts);
  $$AccountsTableTableManager get accounts =>
      $$AccountsTableTableManager(_db, _db.accounts);
  $$TaxRatesTableTableManager get taxRates =>
      $$TaxRatesTableTableManager(_db, _db.taxRates);
  $$JournalEntriesTableTableManager get journalEntries =>
      $$JournalEntriesTableTableManager(_db, _db.journalEntries);
  $$JournalLinesTableTableManager get journalLines =>
      $$JournalLinesTableTableManager(_db, _db.journalLines);
  $$PayrollEventsTableTableManager get payrollEvents =>
      $$PayrollEventsTableTableManager(_db, _db.payrollEvents);
}
