// GENERATED CODE - DO NOT MODIFY BY HAND

part of 'app_database.dart';

// ignore_for_file: type=lint
class $RollsTable extends Rolls with TableInfo<$RollsTable, RollRow> {
  @override
  final GeneratedDatabase attachedDatabase;
  final String? _alias;
  $RollsTable(this.attachedDatabase, [this._alias]);
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
  static const VerificationMeta _filmIdMeta = const VerificationMeta('filmId');
  @override
  late final GeneratedColumn<String> filmId = GeneratedColumn<String>(
    'film_id',
    aliasedName,
    false,
    type: DriftSqlType.string,
    requiredDuringInsert: true,
  );
  static const VerificationMeta _lengthMeta = const VerificationMeta('length');
  @override
  late final GeneratedColumn<int> length = GeneratedColumn<int>(
    'length',
    aliasedName,
    false,
    type: DriftSqlType.int,
    requiredDuringInsert: true,
  );
  @override
  late final GeneratedColumnWithTypeConverter<RollMode, String> mode =
      GeneratedColumn<String>(
        'mode',
        aliasedName,
        false,
        type: DriftSqlType.string,
        requiredDuringInsert: true,
      ).withConverter<RollMode>($RollsTable.$convertermode);
  @override
  late final GeneratedColumnWithTypeConverter<DevelopDelay, String>
  developDelay = GeneratedColumn<String>(
    'develop_delay',
    aliasedName,
    false,
    type: DriftSqlType.string,
    requiredDuringInsert: true,
  ).withConverter<DevelopDelay>($RollsTable.$converterdevelopDelay);
  @override
  late final GeneratedColumnWithTypeConverter<RollState, String> state =
      GeneratedColumn<String>(
        'state',
        aliasedName,
        false,
        type: DriftSqlType.string,
        requiredDuringInsert: true,
      ).withConverter<RollState>($RollsTable.$converterstate);
  static const VerificationMeta _createdAtMeta = const VerificationMeta(
    'createdAt',
  );
  @override
  late final GeneratedColumn<int> createdAt = GeneratedColumn<int>(
    'created_at',
    aliasedName,
    false,
    type: DriftSqlType.int,
    requiredDuringInsert: true,
  );
  static const VerificationMeta _closedAtMeta = const VerificationMeta(
    'closedAt',
  );
  @override
  late final GeneratedColumn<int> closedAt = GeneratedColumn<int>(
    'closed_at',
    aliasedName,
    true,
    type: DriftSqlType.int,
    requiredDuringInsert: false,
  );
  static const VerificationMeta _developAtMeta = const VerificationMeta(
    'developAt',
  );
  @override
  late final GeneratedColumn<int> developAt = GeneratedColumn<int>(
    'develop_at',
    aliasedName,
    true,
    type: DriftSqlType.int,
    requiredDuringInsert: false,
  );
  static const VerificationMeta _developedAtMeta = const VerificationMeta(
    'developedAt',
  );
  @override
  late final GeneratedColumn<int> developedAt = GeneratedColumn<int>(
    'developed_at',
    aliasedName,
    true,
    type: DriftSqlType.int,
    requiredDuringInsert: false,
  );
  static const VerificationMeta _lostAtMeta = const VerificationMeta('lostAt');
  @override
  late final GeneratedColumn<int> lostAt = GeneratedColumn<int>(
    'lost_at',
    aliasedName,
    true,
    type: DriftSqlType.int,
    requiredDuringInsert: false,
  );
  static const VerificationMeta _nameMeta = const VerificationMeta('name');
  @override
  late final GeneratedColumn<String> name = GeneratedColumn<String>(
    'name',
    aliasedName,
    true,
    type: DriftSqlType.string,
    requiredDuringInsert: false,
  );
  @override
  List<GeneratedColumn> get $columns => [
    id,
    filmId,
    length,
    mode,
    developDelay,
    state,
    createdAt,
    closedAt,
    developAt,
    developedAt,
    lostAt,
    name,
  ];
  @override
  String get aliasedName => _alias ?? actualTableName;
  @override
  String get actualTableName => $name;
  static const String $name = 'rolls';
  @override
  VerificationContext validateIntegrity(
    Insertable<RollRow> instance, {
    bool isInserting = false,
  }) {
    final context = VerificationContext();
    final data = instance.toColumns(true);
    if (data.containsKey('id')) {
      context.handle(_idMeta, id.isAcceptableOrUnknown(data['id']!, _idMeta));
    }
    if (data.containsKey('film_id')) {
      context.handle(
        _filmIdMeta,
        filmId.isAcceptableOrUnknown(data['film_id']!, _filmIdMeta),
      );
    } else if (isInserting) {
      context.missing(_filmIdMeta);
    }
    if (data.containsKey('length')) {
      context.handle(
        _lengthMeta,
        length.isAcceptableOrUnknown(data['length']!, _lengthMeta),
      );
    } else if (isInserting) {
      context.missing(_lengthMeta);
    }
    if (data.containsKey('created_at')) {
      context.handle(
        _createdAtMeta,
        createdAt.isAcceptableOrUnknown(data['created_at']!, _createdAtMeta),
      );
    } else if (isInserting) {
      context.missing(_createdAtMeta);
    }
    if (data.containsKey('closed_at')) {
      context.handle(
        _closedAtMeta,
        closedAt.isAcceptableOrUnknown(data['closed_at']!, _closedAtMeta),
      );
    }
    if (data.containsKey('develop_at')) {
      context.handle(
        _developAtMeta,
        developAt.isAcceptableOrUnknown(data['develop_at']!, _developAtMeta),
      );
    }
    if (data.containsKey('developed_at')) {
      context.handle(
        _developedAtMeta,
        developedAt.isAcceptableOrUnknown(
          data['developed_at']!,
          _developedAtMeta,
        ),
      );
    }
    if (data.containsKey('lost_at')) {
      context.handle(
        _lostAtMeta,
        lostAt.isAcceptableOrUnknown(data['lost_at']!, _lostAtMeta),
      );
    }
    if (data.containsKey('name')) {
      context.handle(
        _nameMeta,
        name.isAcceptableOrUnknown(data['name']!, _nameMeta),
      );
    }
    return context;
  }

  @override
  Set<GeneratedColumn> get $primaryKey => {id};
  @override
  RollRow map(Map<String, dynamic> data, {String? tablePrefix}) {
    final effectivePrefix = tablePrefix != null ? '$tablePrefix.' : '';
    return RollRow(
      id: attachedDatabase.typeMapping.read(
        DriftSqlType.int,
        data['${effectivePrefix}id'],
      )!,
      filmId: attachedDatabase.typeMapping.read(
        DriftSqlType.string,
        data['${effectivePrefix}film_id'],
      )!,
      length: attachedDatabase.typeMapping.read(
        DriftSqlType.int,
        data['${effectivePrefix}length'],
      )!,
      mode: $RollsTable.$convertermode.fromSql(
        attachedDatabase.typeMapping.read(
          DriftSqlType.string,
          data['${effectivePrefix}mode'],
        )!,
      ),
      developDelay: $RollsTable.$converterdevelopDelay.fromSql(
        attachedDatabase.typeMapping.read(
          DriftSqlType.string,
          data['${effectivePrefix}develop_delay'],
        )!,
      ),
      state: $RollsTable.$converterstate.fromSql(
        attachedDatabase.typeMapping.read(
          DriftSqlType.string,
          data['${effectivePrefix}state'],
        )!,
      ),
      createdAt: attachedDatabase.typeMapping.read(
        DriftSqlType.int,
        data['${effectivePrefix}created_at'],
      )!,
      closedAt: attachedDatabase.typeMapping.read(
        DriftSqlType.int,
        data['${effectivePrefix}closed_at'],
      ),
      developAt: attachedDatabase.typeMapping.read(
        DriftSqlType.int,
        data['${effectivePrefix}develop_at'],
      ),
      developedAt: attachedDatabase.typeMapping.read(
        DriftSqlType.int,
        data['${effectivePrefix}developed_at'],
      ),
      lostAt: attachedDatabase.typeMapping.read(
        DriftSqlType.int,
        data['${effectivePrefix}lost_at'],
      ),
      name: attachedDatabase.typeMapping.read(
        DriftSqlType.string,
        data['${effectivePrefix}name'],
      ),
    );
  }

  @override
  $RollsTable createAlias(String alias) {
    return $RollsTable(attachedDatabase, alias);
  }

  static JsonTypeConverter2<RollMode, String, String> $convertermode =
      const EnumNameConverter<RollMode>(RollMode.values);
  static JsonTypeConverter2<DevelopDelay, String, String>
  $converterdevelopDelay = const EnumNameConverter<DevelopDelay>(
    DevelopDelay.values,
  );
  static JsonTypeConverter2<RollState, String, String> $converterstate =
      const EnumNameConverter<RollState>(RollState.values);
}

class RollRow extends DataClass implements Insertable<RollRow> {
  /// The id of the roll.
  final int id;

  /// The film of the roll.
  final String filmId;

  /// The number of frames of the roll (12, 24, 36 or 27).
  final int length;

  /// Whether the roll is rewound or disposable.
  final RollMode mode;

  /// How long the roll takes to develop once it is closed.
  final DevelopDelay developDelay;

  /// The state of the roll.
  final RollState state;

  /// When the roll was opened.
  final int createdAt;

  /// When the roll was closed; null while it is open.
  final int? closedAt;

  /// When the roll starts developing; null while it is open.
  final int? developAt;

  /// When the roll finished developing; null while it has not.
  final int? developedAt;
  final int? lostAt;

  /// The name the user gave the roll; null when it has none (the screens then
  /// call it "Carrete 07"). At most 40 characters, see `normalizeRollName`.
  final String? name;
  const RollRow({
    required this.id,
    required this.filmId,
    required this.length,
    required this.mode,
    required this.developDelay,
    required this.state,
    required this.createdAt,
    this.closedAt,
    this.developAt,
    this.developedAt,
    this.lostAt,
    this.name,
  });
  @override
  Map<String, Expression> toColumns(bool nullToAbsent) {
    final map = <String, Expression>{};
    map['id'] = Variable<int>(id);
    map['film_id'] = Variable<String>(filmId);
    map['length'] = Variable<int>(length);
    {
      map['mode'] = Variable<String>($RollsTable.$convertermode.toSql(mode));
    }
    {
      map['develop_delay'] = Variable<String>(
        $RollsTable.$converterdevelopDelay.toSql(developDelay),
      );
    }
    {
      map['state'] = Variable<String>($RollsTable.$converterstate.toSql(state));
    }
    map['created_at'] = Variable<int>(createdAt);
    if (!nullToAbsent || closedAt != null) {
      map['closed_at'] = Variable<int>(closedAt);
    }
    if (!nullToAbsent || developAt != null) {
      map['develop_at'] = Variable<int>(developAt);
    }
    if (!nullToAbsent || developedAt != null) {
      map['developed_at'] = Variable<int>(developedAt);
    }
    if (!nullToAbsent || lostAt != null) {
      map['lost_at'] = Variable<int>(lostAt);
    }
    if (!nullToAbsent || name != null) {
      map['name'] = Variable<String>(name);
    }
    return map;
  }

  RollsCompanion toCompanion(bool nullToAbsent) {
    return RollsCompanion(
      id: Value(id),
      filmId: Value(filmId),
      length: Value(length),
      mode: Value(mode),
      developDelay: Value(developDelay),
      state: Value(state),
      createdAt: Value(createdAt),
      closedAt: closedAt == null && nullToAbsent
          ? const Value.absent()
          : Value(closedAt),
      developAt: developAt == null && nullToAbsent
          ? const Value.absent()
          : Value(developAt),
      developedAt: developedAt == null && nullToAbsent
          ? const Value.absent()
          : Value(developedAt),
      lostAt: lostAt == null && nullToAbsent
          ? const Value.absent()
          : Value(lostAt),
      name: name == null && nullToAbsent ? const Value.absent() : Value(name),
    );
  }

  factory RollRow.fromJson(
    Map<String, dynamic> json, {
    ValueSerializer? serializer,
  }) {
    serializer ??= driftRuntimeOptions.defaultSerializer;
    return RollRow(
      id: serializer.fromJson<int>(json['id']),
      filmId: serializer.fromJson<String>(json['filmId']),
      length: serializer.fromJson<int>(json['length']),
      mode: $RollsTable.$convertermode.fromJson(
        serializer.fromJson<String>(json['mode']),
      ),
      developDelay: $RollsTable.$converterdevelopDelay.fromJson(
        serializer.fromJson<String>(json['developDelay']),
      ),
      state: $RollsTable.$converterstate.fromJson(
        serializer.fromJson<String>(json['state']),
      ),
      createdAt: serializer.fromJson<int>(json['createdAt']),
      closedAt: serializer.fromJson<int?>(json['closedAt']),
      developAt: serializer.fromJson<int?>(json['developAt']),
      developedAt: serializer.fromJson<int?>(json['developedAt']),
      lostAt: serializer.fromJson<int?>(json['lostAt']),
      name: serializer.fromJson<String?>(json['name']),
    );
  }
  @override
  Map<String, dynamic> toJson({ValueSerializer? serializer}) {
    serializer ??= driftRuntimeOptions.defaultSerializer;
    return <String, dynamic>{
      'id': serializer.toJson<int>(id),
      'filmId': serializer.toJson<String>(filmId),
      'length': serializer.toJson<int>(length),
      'mode': serializer.toJson<String>(
        $RollsTable.$convertermode.toJson(mode),
      ),
      'developDelay': serializer.toJson<String>(
        $RollsTable.$converterdevelopDelay.toJson(developDelay),
      ),
      'state': serializer.toJson<String>(
        $RollsTable.$converterstate.toJson(state),
      ),
      'createdAt': serializer.toJson<int>(createdAt),
      'closedAt': serializer.toJson<int?>(closedAt),
      'developAt': serializer.toJson<int?>(developAt),
      'developedAt': serializer.toJson<int?>(developedAt),
      'lostAt': serializer.toJson<int?>(lostAt),
      'name': serializer.toJson<String?>(name),
    };
  }

  RollRow copyWith({
    int? id,
    String? filmId,
    int? length,
    RollMode? mode,
    DevelopDelay? developDelay,
    RollState? state,
    int? createdAt,
    Value<int?> closedAt = const Value.absent(),
    Value<int?> developAt = const Value.absent(),
    Value<int?> developedAt = const Value.absent(),
    Value<int?> lostAt = const Value.absent(),
    Value<String?> name = const Value.absent(),
  }) => RollRow(
    id: id ?? this.id,
    filmId: filmId ?? this.filmId,
    length: length ?? this.length,
    mode: mode ?? this.mode,
    developDelay: developDelay ?? this.developDelay,
    state: state ?? this.state,
    createdAt: createdAt ?? this.createdAt,
    closedAt: closedAt.present ? closedAt.value : this.closedAt,
    developAt: developAt.present ? developAt.value : this.developAt,
    developedAt: developedAt.present ? developedAt.value : this.developedAt,
    lostAt: lostAt.present ? lostAt.value : this.lostAt,
    name: name.present ? name.value : this.name,
  );
  RollRow copyWithCompanion(RollsCompanion data) {
    return RollRow(
      id: data.id.present ? data.id.value : this.id,
      filmId: data.filmId.present ? data.filmId.value : this.filmId,
      length: data.length.present ? data.length.value : this.length,
      mode: data.mode.present ? data.mode.value : this.mode,
      developDelay: data.developDelay.present
          ? data.developDelay.value
          : this.developDelay,
      state: data.state.present ? data.state.value : this.state,
      createdAt: data.createdAt.present ? data.createdAt.value : this.createdAt,
      closedAt: data.closedAt.present ? data.closedAt.value : this.closedAt,
      developAt: data.developAt.present ? data.developAt.value : this.developAt,
      developedAt: data.developedAt.present
          ? data.developedAt.value
          : this.developedAt,
      lostAt: data.lostAt.present ? data.lostAt.value : this.lostAt,
      name: data.name.present ? data.name.value : this.name,
    );
  }

  @override
  String toString() {
    return (StringBuffer('RollRow(')
          ..write('id: $id, ')
          ..write('filmId: $filmId, ')
          ..write('length: $length, ')
          ..write('mode: $mode, ')
          ..write('developDelay: $developDelay, ')
          ..write('state: $state, ')
          ..write('createdAt: $createdAt, ')
          ..write('closedAt: $closedAt, ')
          ..write('developAt: $developAt, ')
          ..write('developedAt: $developedAt, ')
          ..write('lostAt: $lostAt, ')
          ..write('name: $name')
          ..write(')'))
        .toString();
  }

  @override
  int get hashCode => Object.hash(
    id,
    filmId,
    length,
    mode,
    developDelay,
    state,
    createdAt,
    closedAt,
    developAt,
    developedAt,
    lostAt,
    name,
  );
  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      (other is RollRow &&
          other.id == this.id &&
          other.filmId == this.filmId &&
          other.length == this.length &&
          other.mode == this.mode &&
          other.developDelay == this.developDelay &&
          other.state == this.state &&
          other.createdAt == this.createdAt &&
          other.closedAt == this.closedAt &&
          other.developAt == this.developAt &&
          other.developedAt == this.developedAt &&
          other.lostAt == this.lostAt &&
          other.name == this.name);
}

class RollsCompanion extends UpdateCompanion<RollRow> {
  final Value<int> id;
  final Value<String> filmId;
  final Value<int> length;
  final Value<RollMode> mode;
  final Value<DevelopDelay> developDelay;
  final Value<RollState> state;
  final Value<int> createdAt;
  final Value<int?> closedAt;
  final Value<int?> developAt;
  final Value<int?> developedAt;
  final Value<int?> lostAt;
  final Value<String?> name;
  const RollsCompanion({
    this.id = const Value.absent(),
    this.filmId = const Value.absent(),
    this.length = const Value.absent(),
    this.mode = const Value.absent(),
    this.developDelay = const Value.absent(),
    this.state = const Value.absent(),
    this.createdAt = const Value.absent(),
    this.closedAt = const Value.absent(),
    this.developAt = const Value.absent(),
    this.developedAt = const Value.absent(),
    this.lostAt = const Value.absent(),
    this.name = const Value.absent(),
  });
  RollsCompanion.insert({
    this.id = const Value.absent(),
    required String filmId,
    required int length,
    required RollMode mode,
    required DevelopDelay developDelay,
    required RollState state,
    required int createdAt,
    this.closedAt = const Value.absent(),
    this.developAt = const Value.absent(),
    this.developedAt = const Value.absent(),
    this.lostAt = const Value.absent(),
    this.name = const Value.absent(),
  }) : filmId = Value(filmId),
       length = Value(length),
       mode = Value(mode),
       developDelay = Value(developDelay),
       state = Value(state),
       createdAt = Value(createdAt);
  static Insertable<RollRow> custom({
    Expression<int>? id,
    Expression<String>? filmId,
    Expression<int>? length,
    Expression<String>? mode,
    Expression<String>? developDelay,
    Expression<String>? state,
    Expression<int>? createdAt,
    Expression<int>? closedAt,
    Expression<int>? developAt,
    Expression<int>? developedAt,
    Expression<int>? lostAt,
    Expression<String>? name,
  }) {
    return RawValuesInsertable({
      if (id != null) 'id': id,
      if (filmId != null) 'film_id': filmId,
      if (length != null) 'length': length,
      if (mode != null) 'mode': mode,
      if (developDelay != null) 'develop_delay': developDelay,
      if (state != null) 'state': state,
      if (createdAt != null) 'created_at': createdAt,
      if (closedAt != null) 'closed_at': closedAt,
      if (developAt != null) 'develop_at': developAt,
      if (developedAt != null) 'developed_at': developedAt,
      if (lostAt != null) 'lost_at': lostAt,
      if (name != null) 'name': name,
    });
  }

  RollsCompanion copyWith({
    Value<int>? id,
    Value<String>? filmId,
    Value<int>? length,
    Value<RollMode>? mode,
    Value<DevelopDelay>? developDelay,
    Value<RollState>? state,
    Value<int>? createdAt,
    Value<int?>? closedAt,
    Value<int?>? developAt,
    Value<int?>? developedAt,
    Value<int?>? lostAt,
    Value<String?>? name,
  }) {
    return RollsCompanion(
      id: id ?? this.id,
      filmId: filmId ?? this.filmId,
      length: length ?? this.length,
      mode: mode ?? this.mode,
      developDelay: developDelay ?? this.developDelay,
      state: state ?? this.state,
      createdAt: createdAt ?? this.createdAt,
      closedAt: closedAt ?? this.closedAt,
      developAt: developAt ?? this.developAt,
      developedAt: developedAt ?? this.developedAt,
      lostAt: lostAt ?? this.lostAt,
      name: name ?? this.name,
    );
  }

  @override
  Map<String, Expression> toColumns(bool nullToAbsent) {
    final map = <String, Expression>{};
    if (id.present) {
      map['id'] = Variable<int>(id.value);
    }
    if (filmId.present) {
      map['film_id'] = Variable<String>(filmId.value);
    }
    if (length.present) {
      map['length'] = Variable<int>(length.value);
    }
    if (mode.present) {
      map['mode'] = Variable<String>(
        $RollsTable.$convertermode.toSql(mode.value),
      );
    }
    if (developDelay.present) {
      map['develop_delay'] = Variable<String>(
        $RollsTable.$converterdevelopDelay.toSql(developDelay.value),
      );
    }
    if (state.present) {
      map['state'] = Variable<String>(
        $RollsTable.$converterstate.toSql(state.value),
      );
    }
    if (createdAt.present) {
      map['created_at'] = Variable<int>(createdAt.value);
    }
    if (closedAt.present) {
      map['closed_at'] = Variable<int>(closedAt.value);
    }
    if (developAt.present) {
      map['develop_at'] = Variable<int>(developAt.value);
    }
    if (developedAt.present) {
      map['developed_at'] = Variable<int>(developedAt.value);
    }
    if (lostAt.present) {
      map['lost_at'] = Variable<int>(lostAt.value);
    }
    if (name.present) {
      map['name'] = Variable<String>(name.value);
    }
    return map;
  }

  @override
  String toString() {
    return (StringBuffer('RollsCompanion(')
          ..write('id: $id, ')
          ..write('filmId: $filmId, ')
          ..write('length: $length, ')
          ..write('mode: $mode, ')
          ..write('developDelay: $developDelay, ')
          ..write('state: $state, ')
          ..write('createdAt: $createdAt, ')
          ..write('closedAt: $closedAt, ')
          ..write('developAt: $developAt, ')
          ..write('developedAt: $developedAt, ')
          ..write('lostAt: $lostAt, ')
          ..write('name: $name')
          ..write(')'))
        .toString();
  }
}

class $ShotsTable extends Shots with TableInfo<$ShotsTable, ShotRow> {
  @override
  final GeneratedDatabase attachedDatabase;
  final String? _alias;
  $ShotsTable(this.attachedDatabase, [this._alias]);
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
  static const VerificationMeta _rollIdMeta = const VerificationMeta('rollId');
  @override
  late final GeneratedColumn<int> rollId = GeneratedColumn<int>(
    'roll_id',
    aliasedName,
    true,
    type: DriftSqlType.int,
    requiredDuringInsert: false,
    defaultConstraints: GeneratedColumn.constraintIsAlways(
      'REFERENCES rolls (id) ON DELETE CASCADE',
    ),
  );
  static const VerificationMeta _frameNumberMeta = const VerificationMeta(
    'frameNumber',
  );
  @override
  late final GeneratedColumn<int> frameNumber = GeneratedColumn<int>(
    'frame_number',
    aliasedName,
    true,
    type: DriftSqlType.int,
    requiredDuringInsert: false,
  );
  static const VerificationMeta _filmIdMeta = const VerificationMeta('filmId');
  @override
  late final GeneratedColumn<String> filmId = GeneratedColumn<String>(
    'film_id',
    aliasedName,
    false,
    type: DriftSqlType.string,
    requiredDuringInsert: true,
  );
  @override
  late final GeneratedColumnWithTypeConverter<ShotFormat, String> format =
      GeneratedColumn<String>(
        'format',
        aliasedName,
        false,
        type: DriftSqlType.string,
        requiredDuringInsert: true,
      ).withConverter<ShotFormat>($ShotsTable.$converterformat);
  @override
  late final GeneratedColumnWithTypeConverter<ShotLens, String> lens =
      GeneratedColumn<String>(
        'lens',
        aliasedName,
        false,
        type: DriftSqlType.string,
        requiredDuringInsert: true,
      ).withConverter<ShotLens>($ShotsTable.$converterlens);
  static const VerificationMeta _takenAtMeta = const VerificationMeta(
    'takenAt',
  );
  @override
  late final GeneratedColumn<int> takenAt = GeneratedColumn<int>(
    'taken_at',
    aliasedName,
    false,
    type: DriftSqlType.int,
    requiredDuringInsert: true,
  );
  static const VerificationMeta _vaultPathMeta = const VerificationMeta(
    'vaultPath',
  );
  @override
  late final GeneratedColumn<String> vaultPath = GeneratedColumn<String>(
    'vault_path',
    aliasedName,
    true,
    type: DriftSqlType.string,
    requiredDuringInsert: false,
  );
  static const VerificationMeta _galleryUriMeta = const VerificationMeta(
    'galleryUri',
  );
  @override
  late final GeneratedColumn<String> galleryUri = GeneratedColumn<String>(
    'gallery_uri',
    aliasedName,
    true,
    type: DriftSqlType.string,
    requiredDuringInsert: false,
  );
  static const VerificationMeta _widthMeta = const VerificationMeta('width');
  @override
  late final GeneratedColumn<int> width = GeneratedColumn<int>(
    'width',
    aliasedName,
    true,
    type: DriftSqlType.int,
    requiredDuringInsert: false,
  );
  static const VerificationMeta _heightMeta = const VerificationMeta('height');
  @override
  late final GeneratedColumn<int> height = GeneratedColumn<int>(
    'height',
    aliasedName,
    true,
    type: DriftSqlType.int,
    requiredDuringInsert: false,
  );
  static const VerificationMeta _intensityMeta = const VerificationMeta(
    'intensity',
  );
  @override
  late final GeneratedColumn<double> intensity = GeneratedColumn<double>(
    'intensity',
    aliasedName,
    false,
    type: DriftSqlType.double,
    requiredDuringInsert: false,
    defaultValue: const Constant(1),
  );
  static const VerificationMeta _overridesJsonMeta = const VerificationMeta(
    'overridesJson',
  );
  @override
  late final GeneratedColumn<String> overridesJson = GeneratedColumn<String>(
    'overrides_json',
    aliasedName,
    true,
    type: DriftSqlType.string,
    requiredDuringInsert: false,
  );
  static const VerificationMeta _captureJobJsonMeta = const VerificationMeta(
    'captureJobJson',
  );
  @override
  late final GeneratedColumn<String> captureJobJson = GeneratedColumn<String>(
    'capture_job_json',
    aliasedName,
    true,
    type: DriftSqlType.string,
    requiredDuringInsert: false,
  );
  static const VerificationMeta _developFailureMeta = const VerificationMeta(
    'developFailure',
  );
  @override
  late final GeneratedColumn<String> developFailure = GeneratedColumn<String>(
    'develop_failure',
    aliasedName,
    true,
    type: DriftSqlType.string,
    requiredDuringInsert: false,
  );
  @override
  List<GeneratedColumn> get $columns => [
    id,
    rollId,
    frameNumber,
    filmId,
    format,
    lens,
    takenAt,
    vaultPath,
    galleryUri,
    width,
    height,
    intensity,
    overridesJson,
    captureJobJson,
    developFailure,
  ];
  @override
  String get aliasedName => _alias ?? actualTableName;
  @override
  String get actualTableName => $name;
  static const String $name = 'shots';
  @override
  VerificationContext validateIntegrity(
    Insertable<ShotRow> instance, {
    bool isInserting = false,
  }) {
    final context = VerificationContext();
    final data = instance.toColumns(true);
    if (data.containsKey('id')) {
      context.handle(_idMeta, id.isAcceptableOrUnknown(data['id']!, _idMeta));
    }
    if (data.containsKey('roll_id')) {
      context.handle(
        _rollIdMeta,
        rollId.isAcceptableOrUnknown(data['roll_id']!, _rollIdMeta),
      );
    }
    if (data.containsKey('frame_number')) {
      context.handle(
        _frameNumberMeta,
        frameNumber.isAcceptableOrUnknown(
          data['frame_number']!,
          _frameNumberMeta,
        ),
      );
    }
    if (data.containsKey('film_id')) {
      context.handle(
        _filmIdMeta,
        filmId.isAcceptableOrUnknown(data['film_id']!, _filmIdMeta),
      );
    } else if (isInserting) {
      context.missing(_filmIdMeta);
    }
    if (data.containsKey('taken_at')) {
      context.handle(
        _takenAtMeta,
        takenAt.isAcceptableOrUnknown(data['taken_at']!, _takenAtMeta),
      );
    } else if (isInserting) {
      context.missing(_takenAtMeta);
    }
    if (data.containsKey('vault_path')) {
      context.handle(
        _vaultPathMeta,
        vaultPath.isAcceptableOrUnknown(data['vault_path']!, _vaultPathMeta),
      );
    }
    if (data.containsKey('gallery_uri')) {
      context.handle(
        _galleryUriMeta,
        galleryUri.isAcceptableOrUnknown(data['gallery_uri']!, _galleryUriMeta),
      );
    }
    if (data.containsKey('width')) {
      context.handle(
        _widthMeta,
        width.isAcceptableOrUnknown(data['width']!, _widthMeta),
      );
    }
    if (data.containsKey('height')) {
      context.handle(
        _heightMeta,
        height.isAcceptableOrUnknown(data['height']!, _heightMeta),
      );
    }
    if (data.containsKey('intensity')) {
      context.handle(
        _intensityMeta,
        intensity.isAcceptableOrUnknown(data['intensity']!, _intensityMeta),
      );
    }
    if (data.containsKey('overrides_json')) {
      context.handle(
        _overridesJsonMeta,
        overridesJson.isAcceptableOrUnknown(
          data['overrides_json']!,
          _overridesJsonMeta,
        ),
      );
    }
    if (data.containsKey('capture_job_json')) {
      context.handle(
        _captureJobJsonMeta,
        captureJobJson.isAcceptableOrUnknown(
          data['capture_job_json']!,
          _captureJobJsonMeta,
        ),
      );
    }
    if (data.containsKey('develop_failure')) {
      context.handle(
        _developFailureMeta,
        developFailure.isAcceptableOrUnknown(
          data['develop_failure']!,
          _developFailureMeta,
        ),
      );
    }
    return context;
  }

  @override
  Set<GeneratedColumn> get $primaryKey => {id};
  @override
  ShotRow map(Map<String, dynamic> data, {String? tablePrefix}) {
    final effectivePrefix = tablePrefix != null ? '$tablePrefix.' : '';
    return ShotRow(
      id: attachedDatabase.typeMapping.read(
        DriftSqlType.int,
        data['${effectivePrefix}id'],
      )!,
      rollId: attachedDatabase.typeMapping.read(
        DriftSqlType.int,
        data['${effectivePrefix}roll_id'],
      ),
      frameNumber: attachedDatabase.typeMapping.read(
        DriftSqlType.int,
        data['${effectivePrefix}frame_number'],
      ),
      filmId: attachedDatabase.typeMapping.read(
        DriftSqlType.string,
        data['${effectivePrefix}film_id'],
      )!,
      format: $ShotsTable.$converterformat.fromSql(
        attachedDatabase.typeMapping.read(
          DriftSqlType.string,
          data['${effectivePrefix}format'],
        )!,
      ),
      lens: $ShotsTable.$converterlens.fromSql(
        attachedDatabase.typeMapping.read(
          DriftSqlType.string,
          data['${effectivePrefix}lens'],
        )!,
      ),
      takenAt: attachedDatabase.typeMapping.read(
        DriftSqlType.int,
        data['${effectivePrefix}taken_at'],
      )!,
      vaultPath: attachedDatabase.typeMapping.read(
        DriftSqlType.string,
        data['${effectivePrefix}vault_path'],
      ),
      galleryUri: attachedDatabase.typeMapping.read(
        DriftSqlType.string,
        data['${effectivePrefix}gallery_uri'],
      ),
      width: attachedDatabase.typeMapping.read(
        DriftSqlType.int,
        data['${effectivePrefix}width'],
      ),
      height: attachedDatabase.typeMapping.read(
        DriftSqlType.int,
        data['${effectivePrefix}height'],
      ),
      intensity: attachedDatabase.typeMapping.read(
        DriftSqlType.double,
        data['${effectivePrefix}intensity'],
      )!,
      overridesJson: attachedDatabase.typeMapping.read(
        DriftSqlType.string,
        data['${effectivePrefix}overrides_json'],
      ),
      captureJobJson: attachedDatabase.typeMapping.read(
        DriftSqlType.string,
        data['${effectivePrefix}capture_job_json'],
      ),
      developFailure: attachedDatabase.typeMapping.read(
        DriftSqlType.string,
        data['${effectivePrefix}develop_failure'],
      ),
    );
  }

  @override
  $ShotsTable createAlias(String alias) {
    return $ShotsTable(attachedDatabase, alias);
  }

  static TypeConverter<ShotFormat, String> $converterformat =
      const ShotFormatConverter();
  static JsonTypeConverter2<ShotLens, String, String> $converterlens =
      const EnumNameConverter<ShotLens>(ShotLens.values);
}

class ShotRow extends DataClass implements Insertable<ShotRow> {
  /// The id of the photo.
  final int id;

  /// The roll the photo belongs to; null for a loose photo.
  final int? rollId;

  /// The frame of the roll the photo took; null for a loose photo.
  final int? frameNumber;

  /// The film the photo was taken with.
  final String filmId;

  /// The aspect ratio of the photo.
  final ShotFormat format;

  /// The lens that took the photo.
  final ShotLens lens;

  /// When the photo was taken.
  final int takenAt;

  /// The file of the photo while it is undeveloped; null once it is in the
  /// gallery.
  final String? vaultPath;

  /// The place of the photo in the gallery of the system; null while it is
  /// not saved.
  final String? galleryUri;

  /// The width of the photo in pixels.
  final int? width;

  /// The height of the photo in pixels.
  final int? height;

  /// How strong the film look is (1 is the recipe as it is).
  final double intensity;

  /// The values the user changed in the photo, as JSON.
  final String? overridesJson;

  /// Versioned FailedShots JSON, null for legacy v1 shots.
  final String? captureJobJson;

  /// Permanent failure (for example an authenticated vault corruption).
  final String? developFailure;
  const ShotRow({
    required this.id,
    this.rollId,
    this.frameNumber,
    required this.filmId,
    required this.format,
    required this.lens,
    required this.takenAt,
    this.vaultPath,
    this.galleryUri,
    this.width,
    this.height,
    required this.intensity,
    this.overridesJson,
    this.captureJobJson,
    this.developFailure,
  });
  @override
  Map<String, Expression> toColumns(bool nullToAbsent) {
    final map = <String, Expression>{};
    map['id'] = Variable<int>(id);
    if (!nullToAbsent || rollId != null) {
      map['roll_id'] = Variable<int>(rollId);
    }
    if (!nullToAbsent || frameNumber != null) {
      map['frame_number'] = Variable<int>(frameNumber);
    }
    map['film_id'] = Variable<String>(filmId);
    {
      map['format'] = Variable<String>(
        $ShotsTable.$converterformat.toSql(format),
      );
    }
    {
      map['lens'] = Variable<String>($ShotsTable.$converterlens.toSql(lens));
    }
    map['taken_at'] = Variable<int>(takenAt);
    if (!nullToAbsent || vaultPath != null) {
      map['vault_path'] = Variable<String>(vaultPath);
    }
    if (!nullToAbsent || galleryUri != null) {
      map['gallery_uri'] = Variable<String>(galleryUri);
    }
    if (!nullToAbsent || width != null) {
      map['width'] = Variable<int>(width);
    }
    if (!nullToAbsent || height != null) {
      map['height'] = Variable<int>(height);
    }
    map['intensity'] = Variable<double>(intensity);
    if (!nullToAbsent || overridesJson != null) {
      map['overrides_json'] = Variable<String>(overridesJson);
    }
    if (!nullToAbsent || captureJobJson != null) {
      map['capture_job_json'] = Variable<String>(captureJobJson);
    }
    if (!nullToAbsent || developFailure != null) {
      map['develop_failure'] = Variable<String>(developFailure);
    }
    return map;
  }

  ShotsCompanion toCompanion(bool nullToAbsent) {
    return ShotsCompanion(
      id: Value(id),
      rollId: rollId == null && nullToAbsent
          ? const Value.absent()
          : Value(rollId),
      frameNumber: frameNumber == null && nullToAbsent
          ? const Value.absent()
          : Value(frameNumber),
      filmId: Value(filmId),
      format: Value(format),
      lens: Value(lens),
      takenAt: Value(takenAt),
      vaultPath: vaultPath == null && nullToAbsent
          ? const Value.absent()
          : Value(vaultPath),
      galleryUri: galleryUri == null && nullToAbsent
          ? const Value.absent()
          : Value(galleryUri),
      width: width == null && nullToAbsent
          ? const Value.absent()
          : Value(width),
      height: height == null && nullToAbsent
          ? const Value.absent()
          : Value(height),
      intensity: Value(intensity),
      overridesJson: overridesJson == null && nullToAbsent
          ? const Value.absent()
          : Value(overridesJson),
      captureJobJson: captureJobJson == null && nullToAbsent
          ? const Value.absent()
          : Value(captureJobJson),
      developFailure: developFailure == null && nullToAbsent
          ? const Value.absent()
          : Value(developFailure),
    );
  }

  factory ShotRow.fromJson(
    Map<String, dynamic> json, {
    ValueSerializer? serializer,
  }) {
    serializer ??= driftRuntimeOptions.defaultSerializer;
    return ShotRow(
      id: serializer.fromJson<int>(json['id']),
      rollId: serializer.fromJson<int?>(json['rollId']),
      frameNumber: serializer.fromJson<int?>(json['frameNumber']),
      filmId: serializer.fromJson<String>(json['filmId']),
      format: serializer.fromJson<ShotFormat>(json['format']),
      lens: $ShotsTable.$converterlens.fromJson(
        serializer.fromJson<String>(json['lens']),
      ),
      takenAt: serializer.fromJson<int>(json['takenAt']),
      vaultPath: serializer.fromJson<String?>(json['vaultPath']),
      galleryUri: serializer.fromJson<String?>(json['galleryUri']),
      width: serializer.fromJson<int?>(json['width']),
      height: serializer.fromJson<int?>(json['height']),
      intensity: serializer.fromJson<double>(json['intensity']),
      overridesJson: serializer.fromJson<String?>(json['overridesJson']),
      captureJobJson: serializer.fromJson<String?>(json['captureJobJson']),
      developFailure: serializer.fromJson<String?>(json['developFailure']),
    );
  }
  @override
  Map<String, dynamic> toJson({ValueSerializer? serializer}) {
    serializer ??= driftRuntimeOptions.defaultSerializer;
    return <String, dynamic>{
      'id': serializer.toJson<int>(id),
      'rollId': serializer.toJson<int?>(rollId),
      'frameNumber': serializer.toJson<int?>(frameNumber),
      'filmId': serializer.toJson<String>(filmId),
      'format': serializer.toJson<ShotFormat>(format),
      'lens': serializer.toJson<String>(
        $ShotsTable.$converterlens.toJson(lens),
      ),
      'takenAt': serializer.toJson<int>(takenAt),
      'vaultPath': serializer.toJson<String?>(vaultPath),
      'galleryUri': serializer.toJson<String?>(galleryUri),
      'width': serializer.toJson<int?>(width),
      'height': serializer.toJson<int?>(height),
      'intensity': serializer.toJson<double>(intensity),
      'overridesJson': serializer.toJson<String?>(overridesJson),
      'captureJobJson': serializer.toJson<String?>(captureJobJson),
      'developFailure': serializer.toJson<String?>(developFailure),
    };
  }

  ShotRow copyWith({
    int? id,
    Value<int?> rollId = const Value.absent(),
    Value<int?> frameNumber = const Value.absent(),
    String? filmId,
    ShotFormat? format,
    ShotLens? lens,
    int? takenAt,
    Value<String?> vaultPath = const Value.absent(),
    Value<String?> galleryUri = const Value.absent(),
    Value<int?> width = const Value.absent(),
    Value<int?> height = const Value.absent(),
    double? intensity,
    Value<String?> overridesJson = const Value.absent(),
    Value<String?> captureJobJson = const Value.absent(),
    Value<String?> developFailure = const Value.absent(),
  }) => ShotRow(
    id: id ?? this.id,
    rollId: rollId.present ? rollId.value : this.rollId,
    frameNumber: frameNumber.present ? frameNumber.value : this.frameNumber,
    filmId: filmId ?? this.filmId,
    format: format ?? this.format,
    lens: lens ?? this.lens,
    takenAt: takenAt ?? this.takenAt,
    vaultPath: vaultPath.present ? vaultPath.value : this.vaultPath,
    galleryUri: galleryUri.present ? galleryUri.value : this.galleryUri,
    width: width.present ? width.value : this.width,
    height: height.present ? height.value : this.height,
    intensity: intensity ?? this.intensity,
    overridesJson: overridesJson.present
        ? overridesJson.value
        : this.overridesJson,
    captureJobJson: captureJobJson.present
        ? captureJobJson.value
        : this.captureJobJson,
    developFailure: developFailure.present
        ? developFailure.value
        : this.developFailure,
  );
  ShotRow copyWithCompanion(ShotsCompanion data) {
    return ShotRow(
      id: data.id.present ? data.id.value : this.id,
      rollId: data.rollId.present ? data.rollId.value : this.rollId,
      frameNumber: data.frameNumber.present
          ? data.frameNumber.value
          : this.frameNumber,
      filmId: data.filmId.present ? data.filmId.value : this.filmId,
      format: data.format.present ? data.format.value : this.format,
      lens: data.lens.present ? data.lens.value : this.lens,
      takenAt: data.takenAt.present ? data.takenAt.value : this.takenAt,
      vaultPath: data.vaultPath.present ? data.vaultPath.value : this.vaultPath,
      galleryUri: data.galleryUri.present
          ? data.galleryUri.value
          : this.galleryUri,
      width: data.width.present ? data.width.value : this.width,
      height: data.height.present ? data.height.value : this.height,
      intensity: data.intensity.present ? data.intensity.value : this.intensity,
      overridesJson: data.overridesJson.present
          ? data.overridesJson.value
          : this.overridesJson,
      captureJobJson: data.captureJobJson.present
          ? data.captureJobJson.value
          : this.captureJobJson,
      developFailure: data.developFailure.present
          ? data.developFailure.value
          : this.developFailure,
    );
  }

  @override
  String toString() {
    return (StringBuffer('ShotRow(')
          ..write('id: $id, ')
          ..write('rollId: $rollId, ')
          ..write('frameNumber: $frameNumber, ')
          ..write('filmId: $filmId, ')
          ..write('format: $format, ')
          ..write('lens: $lens, ')
          ..write('takenAt: $takenAt, ')
          ..write('vaultPath: $vaultPath, ')
          ..write('galleryUri: $galleryUri, ')
          ..write('width: $width, ')
          ..write('height: $height, ')
          ..write('intensity: $intensity, ')
          ..write('overridesJson: $overridesJson, ')
          ..write('captureJobJson: $captureJobJson, ')
          ..write('developFailure: $developFailure')
          ..write(')'))
        .toString();
  }

  @override
  int get hashCode => Object.hash(
    id,
    rollId,
    frameNumber,
    filmId,
    format,
    lens,
    takenAt,
    vaultPath,
    galleryUri,
    width,
    height,
    intensity,
    overridesJson,
    captureJobJson,
    developFailure,
  );
  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      (other is ShotRow &&
          other.id == this.id &&
          other.rollId == this.rollId &&
          other.frameNumber == this.frameNumber &&
          other.filmId == this.filmId &&
          other.format == this.format &&
          other.lens == this.lens &&
          other.takenAt == this.takenAt &&
          other.vaultPath == this.vaultPath &&
          other.galleryUri == this.galleryUri &&
          other.width == this.width &&
          other.height == this.height &&
          other.intensity == this.intensity &&
          other.overridesJson == this.overridesJson &&
          other.captureJobJson == this.captureJobJson &&
          other.developFailure == this.developFailure);
}

class ShotsCompanion extends UpdateCompanion<ShotRow> {
  final Value<int> id;
  final Value<int?> rollId;
  final Value<int?> frameNumber;
  final Value<String> filmId;
  final Value<ShotFormat> format;
  final Value<ShotLens> lens;
  final Value<int> takenAt;
  final Value<String?> vaultPath;
  final Value<String?> galleryUri;
  final Value<int?> width;
  final Value<int?> height;
  final Value<double> intensity;
  final Value<String?> overridesJson;
  final Value<String?> captureJobJson;
  final Value<String?> developFailure;
  const ShotsCompanion({
    this.id = const Value.absent(),
    this.rollId = const Value.absent(),
    this.frameNumber = const Value.absent(),
    this.filmId = const Value.absent(),
    this.format = const Value.absent(),
    this.lens = const Value.absent(),
    this.takenAt = const Value.absent(),
    this.vaultPath = const Value.absent(),
    this.galleryUri = const Value.absent(),
    this.width = const Value.absent(),
    this.height = const Value.absent(),
    this.intensity = const Value.absent(),
    this.overridesJson = const Value.absent(),
    this.captureJobJson = const Value.absent(),
    this.developFailure = const Value.absent(),
  });
  ShotsCompanion.insert({
    this.id = const Value.absent(),
    this.rollId = const Value.absent(),
    this.frameNumber = const Value.absent(),
    required String filmId,
    required ShotFormat format,
    required ShotLens lens,
    required int takenAt,
    this.vaultPath = const Value.absent(),
    this.galleryUri = const Value.absent(),
    this.width = const Value.absent(),
    this.height = const Value.absent(),
    this.intensity = const Value.absent(),
    this.overridesJson = const Value.absent(),
    this.captureJobJson = const Value.absent(),
    this.developFailure = const Value.absent(),
  }) : filmId = Value(filmId),
       format = Value(format),
       lens = Value(lens),
       takenAt = Value(takenAt);
  static Insertable<ShotRow> custom({
    Expression<int>? id,
    Expression<int>? rollId,
    Expression<int>? frameNumber,
    Expression<String>? filmId,
    Expression<String>? format,
    Expression<String>? lens,
    Expression<int>? takenAt,
    Expression<String>? vaultPath,
    Expression<String>? galleryUri,
    Expression<int>? width,
    Expression<int>? height,
    Expression<double>? intensity,
    Expression<String>? overridesJson,
    Expression<String>? captureJobJson,
    Expression<String>? developFailure,
  }) {
    return RawValuesInsertable({
      if (id != null) 'id': id,
      if (rollId != null) 'roll_id': rollId,
      if (frameNumber != null) 'frame_number': frameNumber,
      if (filmId != null) 'film_id': filmId,
      if (format != null) 'format': format,
      if (lens != null) 'lens': lens,
      if (takenAt != null) 'taken_at': takenAt,
      if (vaultPath != null) 'vault_path': vaultPath,
      if (galleryUri != null) 'gallery_uri': galleryUri,
      if (width != null) 'width': width,
      if (height != null) 'height': height,
      if (intensity != null) 'intensity': intensity,
      if (overridesJson != null) 'overrides_json': overridesJson,
      if (captureJobJson != null) 'capture_job_json': captureJobJson,
      if (developFailure != null) 'develop_failure': developFailure,
    });
  }

  ShotsCompanion copyWith({
    Value<int>? id,
    Value<int?>? rollId,
    Value<int?>? frameNumber,
    Value<String>? filmId,
    Value<ShotFormat>? format,
    Value<ShotLens>? lens,
    Value<int>? takenAt,
    Value<String?>? vaultPath,
    Value<String?>? galleryUri,
    Value<int?>? width,
    Value<int?>? height,
    Value<double>? intensity,
    Value<String?>? overridesJson,
    Value<String?>? captureJobJson,
    Value<String?>? developFailure,
  }) {
    return ShotsCompanion(
      id: id ?? this.id,
      rollId: rollId ?? this.rollId,
      frameNumber: frameNumber ?? this.frameNumber,
      filmId: filmId ?? this.filmId,
      format: format ?? this.format,
      lens: lens ?? this.lens,
      takenAt: takenAt ?? this.takenAt,
      vaultPath: vaultPath ?? this.vaultPath,
      galleryUri: galleryUri ?? this.galleryUri,
      width: width ?? this.width,
      height: height ?? this.height,
      intensity: intensity ?? this.intensity,
      overridesJson: overridesJson ?? this.overridesJson,
      captureJobJson: captureJobJson ?? this.captureJobJson,
      developFailure: developFailure ?? this.developFailure,
    );
  }

  @override
  Map<String, Expression> toColumns(bool nullToAbsent) {
    final map = <String, Expression>{};
    if (id.present) {
      map['id'] = Variable<int>(id.value);
    }
    if (rollId.present) {
      map['roll_id'] = Variable<int>(rollId.value);
    }
    if (frameNumber.present) {
      map['frame_number'] = Variable<int>(frameNumber.value);
    }
    if (filmId.present) {
      map['film_id'] = Variable<String>(filmId.value);
    }
    if (format.present) {
      map['format'] = Variable<String>(
        $ShotsTable.$converterformat.toSql(format.value),
      );
    }
    if (lens.present) {
      map['lens'] = Variable<String>(
        $ShotsTable.$converterlens.toSql(lens.value),
      );
    }
    if (takenAt.present) {
      map['taken_at'] = Variable<int>(takenAt.value);
    }
    if (vaultPath.present) {
      map['vault_path'] = Variable<String>(vaultPath.value);
    }
    if (galleryUri.present) {
      map['gallery_uri'] = Variable<String>(galleryUri.value);
    }
    if (width.present) {
      map['width'] = Variable<int>(width.value);
    }
    if (height.present) {
      map['height'] = Variable<int>(height.value);
    }
    if (intensity.present) {
      map['intensity'] = Variable<double>(intensity.value);
    }
    if (overridesJson.present) {
      map['overrides_json'] = Variable<String>(overridesJson.value);
    }
    if (captureJobJson.present) {
      map['capture_job_json'] = Variable<String>(captureJobJson.value);
    }
    if (developFailure.present) {
      map['develop_failure'] = Variable<String>(developFailure.value);
    }
    return map;
  }

  @override
  String toString() {
    return (StringBuffer('ShotsCompanion(')
          ..write('id: $id, ')
          ..write('rollId: $rollId, ')
          ..write('frameNumber: $frameNumber, ')
          ..write('filmId: $filmId, ')
          ..write('format: $format, ')
          ..write('lens: $lens, ')
          ..write('takenAt: $takenAt, ')
          ..write('vaultPath: $vaultPath, ')
          ..write('galleryUri: $galleryUri, ')
          ..write('width: $width, ')
          ..write('height: $height, ')
          ..write('intensity: $intensity, ')
          ..write('overridesJson: $overridesJson, ')
          ..write('captureJobJson: $captureJobJson, ')
          ..write('developFailure: $developFailure')
          ..write(')'))
        .toString();
  }
}

abstract class _$AppDatabase extends GeneratedDatabase {
  _$AppDatabase(QueryExecutor e) : super(e);
  $AppDatabaseManager get managers => $AppDatabaseManager(this);
  late final $RollsTable rolls = $RollsTable(this);
  late final $ShotsTable shots = $ShotsTable(this);
  late final Index shotsRollFrame = Index(
    'shots_roll_frame',
    'CREATE UNIQUE INDEX shots_roll_frame ON shots (roll_id, frame_number)',
  );
  @override
  Iterable<TableInfo<Table, Object?>> get allTables =>
      allSchemaEntities.whereType<TableInfo<Table, Object?>>();
  @override
  List<DatabaseSchemaEntity> get allSchemaEntities => [
    rolls,
    shots,
    shotsRollFrame,
  ];
  @override
  StreamQueryUpdateRules get streamUpdateRules => const StreamQueryUpdateRules([
    WritePropagation(
      on: TableUpdateQuery.onTableName(
        'rolls',
        limitUpdateKind: UpdateKind.delete,
      ),
      result: [TableUpdate('shots', kind: UpdateKind.delete)],
    ),
  ]);
}

typedef $$RollsTableCreateCompanionBuilder = RollsCompanion Function({
  Value<int> id,
  required String filmId,
  required int length,
  required RollMode mode,
  required DevelopDelay developDelay,
  required RollState state,
  required int createdAt,
  Value<int?> closedAt,
  Value<int?> developAt,
  Value<int?> developedAt,
  Value<int?> lostAt,
  Value<String?> name,
});
typedef $$RollsTableUpdateCompanionBuilder = RollsCompanion Function({
  Value<int> id,
  Value<String> filmId,
  Value<int> length,
  Value<RollMode> mode,
  Value<DevelopDelay> developDelay,
  Value<RollState> state,
  Value<int> createdAt,
  Value<int?> closedAt,
  Value<int?> developAt,
  Value<int?> developedAt,
  Value<int?> lostAt,
  Value<String?> name,
});

final class $$RollsTableReferences
    extends BaseReferences<_$AppDatabase, $RollsTable, RollRow> {
  $$RollsTableReferences(super.$_db, super.$_table, super.$_typedResult);

  static MultiTypedResultKey<$ShotsTable, List<ShotRow>> _shotsRefsTable(
    _$AppDatabase db,
  ) => MultiTypedResultKey.fromTable(
    db.shots,
    aliasName: 'rolls__id__shots__roll_id',
  );

  $$ShotsTableProcessedTableManager get shotsRefs {
    final manager = $$ShotsTableTableManager(
      $_db,
      $_db.shots,
    ).filter((f) => f.rollId.id.sqlEquals($_itemColumn<int>('id')!));

    final cache = $_typedResult.readTableOrNull(_shotsRefsTable($_db));
    return ProcessedTableManager(
      manager.$state.copyWith(prefetchedData: cache),
    );
  }
}

class $$RollsTableFilterComposer extends Composer<_$AppDatabase, $RollsTable> {
  $$RollsTableFilterComposer({
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

  ColumnFilters<String> get filmId => $composableBuilder(
    column: $table.filmId,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<int> get length => $composableBuilder(
    column: $table.length,
    builder: (column) => ColumnFilters(column),
  );

  ColumnWithTypeConverterFilters<RollMode, RollMode, String> get mode =>
      $composableBuilder(
        column: $table.mode,
        builder: (column) => ColumnWithTypeConverterFilters(column),
      );

  ColumnWithTypeConverterFilters<DevelopDelay, DevelopDelay, String>
  get developDelay => $composableBuilder(
    column: $table.developDelay,
    builder: (column) => ColumnWithTypeConverterFilters(column),
  );

  ColumnWithTypeConverterFilters<RollState, RollState, String> get state =>
      $composableBuilder(
        column: $table.state,
        builder: (column) => ColumnWithTypeConverterFilters(column),
      );

  ColumnFilters<int> get createdAt => $composableBuilder(
    column: $table.createdAt,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<int> get closedAt => $composableBuilder(
    column: $table.closedAt,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<int> get developAt => $composableBuilder(
    column: $table.developAt,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<int> get developedAt => $composableBuilder(
    column: $table.developedAt,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<int> get lostAt => $composableBuilder(
    column: $table.lostAt,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<String> get name => $composableBuilder(
    column: $table.name,
    builder: (column) => ColumnFilters(column),
  );

  Expression<bool> shotsRefs(
    Expression<bool> Function($$ShotsTableFilterComposer f) f,
  ) {
    final $$ShotsTableFilterComposer composer = $composerBuilder(
      composer: this,
      getCurrentColumn: (t) => t.id,
      referencedTable: $db.shots,
      getReferencedColumn: (t) => t.rollId,
      builder:
          (
            joinBuilder, {
            $addJoinBuilderToRootComposer,
            $removeJoinBuilderFromRootComposer,
          }) => $$ShotsTableFilterComposer(
            $db: $db,
            $table: $db.shots,
            $addJoinBuilderToRootComposer: $addJoinBuilderToRootComposer,
            joinBuilder: joinBuilder,
            $removeJoinBuilderFromRootComposer:
                $removeJoinBuilderFromRootComposer,
          ),
    );
    return f(composer);
  }
}

class $$RollsTableOrderingComposer
    extends Composer<_$AppDatabase, $RollsTable> {
  $$RollsTableOrderingComposer({
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

  ColumnOrderings<String> get filmId => $composableBuilder(
    column: $table.filmId,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<int> get length => $composableBuilder(
    column: $table.length,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<String> get mode => $composableBuilder(
    column: $table.mode,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<String> get developDelay => $composableBuilder(
    column: $table.developDelay,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<String> get state => $composableBuilder(
    column: $table.state,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<int> get createdAt => $composableBuilder(
    column: $table.createdAt,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<int> get closedAt => $composableBuilder(
    column: $table.closedAt,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<int> get developAt => $composableBuilder(
    column: $table.developAt,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<int> get developedAt => $composableBuilder(
    column: $table.developedAt,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<int> get lostAt => $composableBuilder(
    column: $table.lostAt,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<String> get name => $composableBuilder(
    column: $table.name,
    builder: (column) => ColumnOrderings(column),
  );
}

class $$RollsTableAnnotationComposer
    extends Composer<_$AppDatabase, $RollsTable> {
  $$RollsTableAnnotationComposer({
    required super.$db,
    required super.$table,
    super.joinBuilder,
    super.$addJoinBuilderToRootComposer,
    super.$removeJoinBuilderFromRootComposer,
  });
  GeneratedColumn<int> get id =>
      $composableBuilder(column: $table.id, builder: (column) => column);

  GeneratedColumn<String> get filmId =>
      $composableBuilder(column: $table.filmId, builder: (column) => column);

  GeneratedColumn<int> get length =>
      $composableBuilder(column: $table.length, builder: (column) => column);

  GeneratedColumnWithTypeConverter<RollMode, String> get mode =>
      $composableBuilder(column: $table.mode, builder: (column) => column);

  GeneratedColumnWithTypeConverter<DevelopDelay, String> get developDelay =>
      $composableBuilder(
        column: $table.developDelay,
        builder: (column) => column,
      );

  GeneratedColumnWithTypeConverter<RollState, String> get state =>
      $composableBuilder(column: $table.state, builder: (column) => column);

  GeneratedColumn<int> get createdAt =>
      $composableBuilder(column: $table.createdAt, builder: (column) => column);

  GeneratedColumn<int> get closedAt =>
      $composableBuilder(column: $table.closedAt, builder: (column) => column);

  GeneratedColumn<int> get developAt =>
      $composableBuilder(column: $table.developAt, builder: (column) => column);

  GeneratedColumn<int> get developedAt => $composableBuilder(
    column: $table.developedAt,
    builder: (column) => column,
  );

  GeneratedColumn<int> get lostAt =>
      $composableBuilder(column: $table.lostAt, builder: (column) => column);

  GeneratedColumn<String> get name =>
      $composableBuilder(column: $table.name, builder: (column) => column);

  Expression<T> shotsRefs<T extends Object>(
    Expression<T> Function($$ShotsTableAnnotationComposer a) f,
  ) {
    final $$ShotsTableAnnotationComposer composer = $composerBuilder(
      composer: this,
      getCurrentColumn: (t) => t.id,
      referencedTable: $db.shots,
      getReferencedColumn: (t) => t.rollId,
      builder:
          (
            joinBuilder, {
            $addJoinBuilderToRootComposer,
            $removeJoinBuilderFromRootComposer,
          }) => $$ShotsTableAnnotationComposer(
            $db: $db,
            $table: $db.shots,
            $addJoinBuilderToRootComposer: $addJoinBuilderToRootComposer,
            joinBuilder: joinBuilder,
            $removeJoinBuilderFromRootComposer:
                $removeJoinBuilderFromRootComposer,
          ),
    );
    return f(composer);
  }
}

class $$RollsTableTableManager
    extends
        RootTableManager<
          _$AppDatabase,
          $RollsTable,
          RollRow,
          $$RollsTableFilterComposer,
          $$RollsTableOrderingComposer,
          $$RollsTableAnnotationComposer,
          $$RollsTableCreateCompanionBuilder,
          $$RollsTableUpdateCompanionBuilder,
          (RollRow, $$RollsTableReferences),
          RollRow,
          PrefetchHooks Function({bool shotsRefs})
        > {
  $$RollsTableTableManager(_$AppDatabase db, $RollsTable table)
    : super(
        TableManagerState(
          db: db,
          table: table,
          createFilteringComposer: () =>
              $$RollsTableFilterComposer($db: db, $table: table),
          createOrderingComposer: () =>
              $$RollsTableOrderingComposer($db: db, $table: table),
          createComputedFieldComposer: () =>
              $$RollsTableAnnotationComposer($db: db, $table: table),
          updateCompanionCallback:
              ({
                Value<int> id = const Value.absent(),
                Value<String> filmId = const Value.absent(),
                Value<int> length = const Value.absent(),
                Value<RollMode> mode = const Value.absent(),
                Value<DevelopDelay> developDelay = const Value.absent(),
                Value<RollState> state = const Value.absent(),
                Value<int> createdAt = const Value.absent(),
                Value<int?> closedAt = const Value.absent(),
                Value<int?> developAt = const Value.absent(),
                Value<int?> developedAt = const Value.absent(),
                Value<int?> lostAt = const Value.absent(),
                Value<String?> name = const Value.absent(),
              }) => RollsCompanion(
                id: id,
                filmId: filmId,
                length: length,
                mode: mode,
                developDelay: developDelay,
                state: state,
                createdAt: createdAt,
                closedAt: closedAt,
                developAt: developAt,
                developedAt: developedAt,
                lostAt: lostAt,
                name: name,
              ),
          createCompanionCallback:
              ({
                Value<int> id = const Value.absent(),
                required String filmId,
                required int length,
                required RollMode mode,
                required DevelopDelay developDelay,
                required RollState state,
                required int createdAt,
                Value<int?> closedAt = const Value.absent(),
                Value<int?> developAt = const Value.absent(),
                Value<int?> developedAt = const Value.absent(),
                Value<int?> lostAt = const Value.absent(),
                Value<String?> name = const Value.absent(),
              }) => RollsCompanion.insert(
                id: id,
                filmId: filmId,
                length: length,
                mode: mode,
                developDelay: developDelay,
                state: state,
                createdAt: createdAt,
                closedAt: closedAt,
                developAt: developAt,
                developedAt: developedAt,
                lostAt: lostAt,
                name: name,
              ),
          withReferenceMapper: (p0) => p0
              .map(
                (e) => (
                  e.readTable<$RollsTable, RollRow>(table),
                  $$RollsTableReferences(db, table, e),
                ),
              )
              .toList(),
          prefetchHooksCallback: ({shotsRefs = false}) {
            return PrefetchHooks(
              db: db,
              explicitlyWatchedTables: [if (shotsRefs) db.shots],
              addJoins: null,
              getPrefetchedDataCallback: (items) async {
                return [
                  if (shotsRefs)
                    await $_getPrefetchedDataByColumns<
                      RollRow,
                      $RollsTable,
                      ShotRow,
                      $ShotsTable
                    >(
                      currentTable: table,
                      referencedTable: $$RollsTableReferences._shotsRefsTable(
                        db,
                      ),
                      managerFromTypedResult: (p0) =>
                          $$RollsTableReferences(db, table, p0).shotsRefs,
                      currentColumn: 'id',
                      referencedColumn: 'roll_id',
                      typedResults: items,
                    ),
                ];
              },
            );
          },
        ),
      );
}

typedef $$RollsTableProcessedTableManager =
    ProcessedTableManager<
      _$AppDatabase,
      $RollsTable,
      RollRow,
      $$RollsTableFilterComposer,
      $$RollsTableOrderingComposer,
      $$RollsTableAnnotationComposer,
      $$RollsTableCreateCompanionBuilder,
      $$RollsTableUpdateCompanionBuilder,
      (RollRow, $$RollsTableReferences),
      RollRow,
      PrefetchHooks Function({bool shotsRefs})
    >;
typedef $$ShotsTableCreateCompanionBuilder = ShotsCompanion Function({
  Value<int> id,
  Value<int?> rollId,
  Value<int?> frameNumber,
  required String filmId,
  required ShotFormat format,
  required ShotLens lens,
  required int takenAt,
  Value<String?> vaultPath,
  Value<String?> galleryUri,
  Value<int?> width,
  Value<int?> height,
  Value<double> intensity,
  Value<String?> overridesJson,
  Value<String?> captureJobJson,
  Value<String?> developFailure,
});
typedef $$ShotsTableUpdateCompanionBuilder = ShotsCompanion Function({
  Value<int> id,
  Value<int?> rollId,
  Value<int?> frameNumber,
  Value<String> filmId,
  Value<ShotFormat> format,
  Value<ShotLens> lens,
  Value<int> takenAt,
  Value<String?> vaultPath,
  Value<String?> galleryUri,
  Value<int?> width,
  Value<int?> height,
  Value<double> intensity,
  Value<String?> overridesJson,
  Value<String?> captureJobJson,
  Value<String?> developFailure,
});

final class $$ShotsTableReferences
    extends BaseReferences<_$AppDatabase, $ShotsTable, ShotRow> {
  $$ShotsTableReferences(super.$_db, super.$_table, super.$_typedResult);

  static $RollsTable _rollIdTable(_$AppDatabase db) =>
      db.rolls.createAlias('shots__roll_id__rolls__id');

  $$RollsTableProcessedTableManager? get rollId {
    final $_column = $_itemColumn<int>('roll_id');
    if ($_column == null) return null;
    final manager = $$RollsTableTableManager(
      $_db,
      $_db.rolls,
    ).filter((f) => f.id.sqlEquals($_column));
    final item = $_typedResult.readTableOrNull(_rollIdTable($_db));
    if (item == null) return manager;
    return ProcessedTableManager(
      manager.$state.copyWith(prefetchedData: [item]),
    );
  }
}

class $$ShotsTableFilterComposer extends Composer<_$AppDatabase, $ShotsTable> {
  $$ShotsTableFilterComposer({
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

  ColumnFilters<int> get frameNumber => $composableBuilder(
    column: $table.frameNumber,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<String> get filmId => $composableBuilder(
    column: $table.filmId,
    builder: (column) => ColumnFilters(column),
  );

  ColumnWithTypeConverterFilters<ShotFormat, ShotFormat, String> get format =>
      $composableBuilder(
        column: $table.format,
        builder: (column) => ColumnWithTypeConverterFilters(column),
      );

  ColumnWithTypeConverterFilters<ShotLens, ShotLens, String> get lens =>
      $composableBuilder(
        column: $table.lens,
        builder: (column) => ColumnWithTypeConverterFilters(column),
      );

  ColumnFilters<int> get takenAt => $composableBuilder(
    column: $table.takenAt,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<String> get vaultPath => $composableBuilder(
    column: $table.vaultPath,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<String> get galleryUri => $composableBuilder(
    column: $table.galleryUri,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<int> get width => $composableBuilder(
    column: $table.width,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<int> get height => $composableBuilder(
    column: $table.height,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<double> get intensity => $composableBuilder(
    column: $table.intensity,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<String> get overridesJson => $composableBuilder(
    column: $table.overridesJson,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<String> get captureJobJson => $composableBuilder(
    column: $table.captureJobJson,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<String> get developFailure => $composableBuilder(
    column: $table.developFailure,
    builder: (column) => ColumnFilters(column),
  );

  $$RollsTableFilterComposer get rollId {
    final $$RollsTableFilterComposer composer = $composerBuilder(
      composer: this,
      getCurrentColumn: (t) => t.rollId,
      referencedTable: $db.rolls,
      getReferencedColumn: (t) => t.id,
      builder:
          (
            joinBuilder, {
            $addJoinBuilderToRootComposer,
            $removeJoinBuilderFromRootComposer,
          }) => $$RollsTableFilterComposer(
            $db: $db,
            $table: $db.rolls,
            $addJoinBuilderToRootComposer: $addJoinBuilderToRootComposer,
            joinBuilder: joinBuilder,
            $removeJoinBuilderFromRootComposer:
                $removeJoinBuilderFromRootComposer,
          ),
    );
    return composer;
  }
}

class $$ShotsTableOrderingComposer
    extends Composer<_$AppDatabase, $ShotsTable> {
  $$ShotsTableOrderingComposer({
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

  ColumnOrderings<int> get frameNumber => $composableBuilder(
    column: $table.frameNumber,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<String> get filmId => $composableBuilder(
    column: $table.filmId,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<String> get format => $composableBuilder(
    column: $table.format,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<String> get lens => $composableBuilder(
    column: $table.lens,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<int> get takenAt => $composableBuilder(
    column: $table.takenAt,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<String> get vaultPath => $composableBuilder(
    column: $table.vaultPath,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<String> get galleryUri => $composableBuilder(
    column: $table.galleryUri,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<int> get width => $composableBuilder(
    column: $table.width,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<int> get height => $composableBuilder(
    column: $table.height,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<double> get intensity => $composableBuilder(
    column: $table.intensity,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<String> get overridesJson => $composableBuilder(
    column: $table.overridesJson,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<String> get captureJobJson => $composableBuilder(
    column: $table.captureJobJson,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<String> get developFailure => $composableBuilder(
    column: $table.developFailure,
    builder: (column) => ColumnOrderings(column),
  );

  $$RollsTableOrderingComposer get rollId {
    final $$RollsTableOrderingComposer composer = $composerBuilder(
      composer: this,
      getCurrentColumn: (t) => t.rollId,
      referencedTable: $db.rolls,
      getReferencedColumn: (t) => t.id,
      builder:
          (
            joinBuilder, {
            $addJoinBuilderToRootComposer,
            $removeJoinBuilderFromRootComposer,
          }) => $$RollsTableOrderingComposer(
            $db: $db,
            $table: $db.rolls,
            $addJoinBuilderToRootComposer: $addJoinBuilderToRootComposer,
            joinBuilder: joinBuilder,
            $removeJoinBuilderFromRootComposer:
                $removeJoinBuilderFromRootComposer,
          ),
    );
    return composer;
  }
}

class $$ShotsTableAnnotationComposer
    extends Composer<_$AppDatabase, $ShotsTable> {
  $$ShotsTableAnnotationComposer({
    required super.$db,
    required super.$table,
    super.joinBuilder,
    super.$addJoinBuilderToRootComposer,
    super.$removeJoinBuilderFromRootComposer,
  });
  GeneratedColumn<int> get id =>
      $composableBuilder(column: $table.id, builder: (column) => column);

  GeneratedColumn<int> get frameNumber => $composableBuilder(
    column: $table.frameNumber,
    builder: (column) => column,
  );

  GeneratedColumn<String> get filmId =>
      $composableBuilder(column: $table.filmId, builder: (column) => column);

  GeneratedColumnWithTypeConverter<ShotFormat, String> get format =>
      $composableBuilder(column: $table.format, builder: (column) => column);

  GeneratedColumnWithTypeConverter<ShotLens, String> get lens =>
      $composableBuilder(column: $table.lens, builder: (column) => column);

  GeneratedColumn<int> get takenAt =>
      $composableBuilder(column: $table.takenAt, builder: (column) => column);

  GeneratedColumn<String> get vaultPath =>
      $composableBuilder(column: $table.vaultPath, builder: (column) => column);

  GeneratedColumn<String> get galleryUri => $composableBuilder(
    column: $table.galleryUri,
    builder: (column) => column,
  );

  GeneratedColumn<int> get width =>
      $composableBuilder(column: $table.width, builder: (column) => column);

  GeneratedColumn<int> get height =>
      $composableBuilder(column: $table.height, builder: (column) => column);

  GeneratedColumn<double> get intensity =>
      $composableBuilder(column: $table.intensity, builder: (column) => column);

  GeneratedColumn<String> get overridesJson => $composableBuilder(
    column: $table.overridesJson,
    builder: (column) => column,
  );

  GeneratedColumn<String> get captureJobJson => $composableBuilder(
    column: $table.captureJobJson,
    builder: (column) => column,
  );

  GeneratedColumn<String> get developFailure => $composableBuilder(
    column: $table.developFailure,
    builder: (column) => column,
  );

  $$RollsTableAnnotationComposer get rollId {
    final $$RollsTableAnnotationComposer composer = $composerBuilder(
      composer: this,
      getCurrentColumn: (t) => t.rollId,
      referencedTable: $db.rolls,
      getReferencedColumn: (t) => t.id,
      builder:
          (
            joinBuilder, {
            $addJoinBuilderToRootComposer,
            $removeJoinBuilderFromRootComposer,
          }) => $$RollsTableAnnotationComposer(
            $db: $db,
            $table: $db.rolls,
            $addJoinBuilderToRootComposer: $addJoinBuilderToRootComposer,
            joinBuilder: joinBuilder,
            $removeJoinBuilderFromRootComposer:
                $removeJoinBuilderFromRootComposer,
          ),
    );
    return composer;
  }
}

class $$ShotsTableTableManager
    extends
        RootTableManager<
          _$AppDatabase,
          $ShotsTable,
          ShotRow,
          $$ShotsTableFilterComposer,
          $$ShotsTableOrderingComposer,
          $$ShotsTableAnnotationComposer,
          $$ShotsTableCreateCompanionBuilder,
          $$ShotsTableUpdateCompanionBuilder,
          (ShotRow, $$ShotsTableReferences),
          ShotRow,
          PrefetchHooks Function({bool rollId})
        > {
  $$ShotsTableTableManager(_$AppDatabase db, $ShotsTable table)
    : super(
        TableManagerState(
          db: db,
          table: table,
          createFilteringComposer: () =>
              $$ShotsTableFilterComposer($db: db, $table: table),
          createOrderingComposer: () =>
              $$ShotsTableOrderingComposer($db: db, $table: table),
          createComputedFieldComposer: () =>
              $$ShotsTableAnnotationComposer($db: db, $table: table),
          updateCompanionCallback:
              ({
                Value<int> id = const Value.absent(),
                Value<int?> rollId = const Value.absent(),
                Value<int?> frameNumber = const Value.absent(),
                Value<String> filmId = const Value.absent(),
                Value<ShotFormat> format = const Value.absent(),
                Value<ShotLens> lens = const Value.absent(),
                Value<int> takenAt = const Value.absent(),
                Value<String?> vaultPath = const Value.absent(),
                Value<String?> galleryUri = const Value.absent(),
                Value<int?> width = const Value.absent(),
                Value<int?> height = const Value.absent(),
                Value<double> intensity = const Value.absent(),
                Value<String?> overridesJson = const Value.absent(),
                Value<String?> captureJobJson = const Value.absent(),
                Value<String?> developFailure = const Value.absent(),
              }) => ShotsCompanion(
                id: id,
                rollId: rollId,
                frameNumber: frameNumber,
                filmId: filmId,
                format: format,
                lens: lens,
                takenAt: takenAt,
                vaultPath: vaultPath,
                galleryUri: galleryUri,
                width: width,
                height: height,
                intensity: intensity,
                overridesJson: overridesJson,
                captureJobJson: captureJobJson,
                developFailure: developFailure,
              ),
          createCompanionCallback:
              ({
                Value<int> id = const Value.absent(),
                Value<int?> rollId = const Value.absent(),
                Value<int?> frameNumber = const Value.absent(),
                required String filmId,
                required ShotFormat format,
                required ShotLens lens,
                required int takenAt,
                Value<String?> vaultPath = const Value.absent(),
                Value<String?> galleryUri = const Value.absent(),
                Value<int?> width = const Value.absent(),
                Value<int?> height = const Value.absent(),
                Value<double> intensity = const Value.absent(),
                Value<String?> overridesJson = const Value.absent(),
                Value<String?> captureJobJson = const Value.absent(),
                Value<String?> developFailure = const Value.absent(),
              }) => ShotsCompanion.insert(
                id: id,
                rollId: rollId,
                frameNumber: frameNumber,
                filmId: filmId,
                format: format,
                lens: lens,
                takenAt: takenAt,
                vaultPath: vaultPath,
                galleryUri: galleryUri,
                width: width,
                height: height,
                intensity: intensity,
                overridesJson: overridesJson,
                captureJobJson: captureJobJson,
                developFailure: developFailure,
              ),
          withReferenceMapper: (p0) => p0
              .map(
                (e) => (
                  e.readTable<$ShotsTable, ShotRow>(table),
                  $$ShotsTableReferences(db, table, e),
                ),
              )
              .toList(),
          prefetchHooksCallback: ({rollId = false}) {
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
                    if (rollId) {
                      state = state.withJoin(
                        currentTable: table,
                        currentColumn: table.rollId,
                        referencedTable: $$ShotsTableReferences._rollIdTable(
                          db,
                        ),
                        referencedColumn: $$ShotsTableReferences
                            ._rollIdTable(db)
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

typedef $$ShotsTableProcessedTableManager =
    ProcessedTableManager<
      _$AppDatabase,
      $ShotsTable,
      ShotRow,
      $$ShotsTableFilterComposer,
      $$ShotsTableOrderingComposer,
      $$ShotsTableAnnotationComposer,
      $$ShotsTableCreateCompanionBuilder,
      $$ShotsTableUpdateCompanionBuilder,
      (ShotRow, $$ShotsTableReferences),
      ShotRow,
      PrefetchHooks Function({bool rollId})
    >;

class $AppDatabaseManager {
  final _$AppDatabase _db;
  $AppDatabaseManager(this._db);
  $$RollsTableTableManager get rolls =>
      $$RollsTableTableManager(_db, _db.rolls);
  $$ShotsTableTableManager get shots =>
      $$ShotsTableTableManager(_db, _db.shots);
}
