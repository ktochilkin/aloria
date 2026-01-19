// coverage:ignore-file
// GENERATED CODE - DO NOT MODIFY BY HAND
// ignore_for_file: type=lint
// ignore_for_file: unused_element, deprecated_member_use, deprecated_member_use_from_same_package, use_function_type_syntax_for_parameters, unnecessary_const, avoid_init_to_null, invalid_override_different_default_values_named, prefer_expression_function_bodies, annotate_overrides, invalid_annotation_target, unnecessary_question_mark

part of 'example_item.dart';

// **************************************************************************
// FreezedGenerator
// **************************************************************************

T _$identity<T>(T value) => value;

final _privateConstructorUsedError = UnsupportedError(
  'It seems like you constructed your class using `MyClass._()`. This constructor is only meant to be used by freezed and you are not supposed to need it nor use it.\nPlease check the documentation here for more information: https://github.com/rrousselGit/freezed#adding-getters-and-methods-to-our-models',
);

ExampleItem _$ExampleItemFromJson(Map<String, dynamic> json) {
  return _ExampleItem.fromJson(json);
}

/// @nodoc
mixin _$ExampleItem {
  String get id => throw _privateConstructorUsedError;
  String get title => throw _privateConstructorUsedError;
  String? get description => throw _privateConstructorUsedError;

  /// Serializes this ExampleItem to a JSON map.
  Map<String, dynamic> toJson() => throw _privateConstructorUsedError;

  /// Create a copy of ExampleItem
  /// with the given fields replaced by the non-null parameter values.
  @JsonKey(includeFromJson: false, includeToJson: false)
  $ExampleItemCopyWith<ExampleItem> get copyWith =>
      throw _privateConstructorUsedError;
}

/// @nodoc
abstract class $ExampleItemCopyWith<$Res> {
  factory $ExampleItemCopyWith(
    ExampleItem value,
    $Res Function(ExampleItem) then,
  ) = _$ExampleItemCopyWithImpl<$Res, ExampleItem>;
  @useResult
  $Res call({String id, String title, String? description});
}

/// @nodoc
class _$ExampleItemCopyWithImpl<$Res, $Val extends ExampleItem>
    implements $ExampleItemCopyWith<$Res> {
  _$ExampleItemCopyWithImpl(this._value, this._then);

  // ignore: unused_field
  final $Val _value;
  // ignore: unused_field
  final $Res Function($Val) _then;

  /// Create a copy of ExampleItem
  /// with the given fields replaced by the non-null parameter values.
  @pragma('vm:prefer-inline')
  @override
  $Res call({
    Object? id = null,
    Object? title = null,
    Object? description = freezed,
  }) {
    return _then(
      _value.copyWith(
            id: null == id
                ? _value.id
                : id // ignore: cast_nullable_to_non_nullable
                      as String,
            title: null == title
                ? _value.title
                : title // ignore: cast_nullable_to_non_nullable
                      as String,
            description: freezed == description
                ? _value.description
                : description // ignore: cast_nullable_to_non_nullable
                      as String?,
          )
          as $Val,
    );
  }
}

/// @nodoc
abstract class _$$ExampleItemImplCopyWith<$Res>
    implements $ExampleItemCopyWith<$Res> {
  factory _$$ExampleItemImplCopyWith(
    _$ExampleItemImpl value,
    $Res Function(_$ExampleItemImpl) then,
  ) = __$$ExampleItemImplCopyWithImpl<$Res>;
  @override
  @useResult
  $Res call({String id, String title, String? description});
}

/// @nodoc
class __$$ExampleItemImplCopyWithImpl<$Res>
    extends _$ExampleItemCopyWithImpl<$Res, _$ExampleItemImpl>
    implements _$$ExampleItemImplCopyWith<$Res> {
  __$$ExampleItemImplCopyWithImpl(
    _$ExampleItemImpl _value,
    $Res Function(_$ExampleItemImpl) _then,
  ) : super(_value, _then);

  /// Create a copy of ExampleItem
  /// with the given fields replaced by the non-null parameter values.
  @pragma('vm:prefer-inline')
  @override
  $Res call({
    Object? id = null,
    Object? title = null,
    Object? description = freezed,
  }) {
    return _then(
      _$ExampleItemImpl(
        id: null == id
            ? _value.id
            : id // ignore: cast_nullable_to_non_nullable
                  as String,
        title: null == title
            ? _value.title
            : title // ignore: cast_nullable_to_non_nullable
                  as String,
        description: freezed == description
            ? _value.description
            : description // ignore: cast_nullable_to_non_nullable
                  as String?,
      ),
    );
  }
}

/// @nodoc
@JsonSerializable()
class _$ExampleItemImpl implements _ExampleItem {
  const _$ExampleItemImpl({
    required this.id,
    required this.title,
    this.description,
  });

  factory _$ExampleItemImpl.fromJson(Map<String, dynamic> json) =>
      _$$ExampleItemImplFromJson(json);

  @override
  final String id;
  @override
  final String title;
  @override
  final String? description;

  @override
  String toString() {
    return 'ExampleItem(id: $id, title: $title, description: $description)';
  }

  @override
  bool operator ==(Object other) {
    return identical(this, other) ||
        (other.runtimeType == runtimeType &&
            other is _$ExampleItemImpl &&
            (identical(other.id, id) || other.id == id) &&
            (identical(other.title, title) || other.title == title) &&
            (identical(other.description, description) ||
                other.description == description));
  }

  @JsonKey(includeFromJson: false, includeToJson: false)
  @override
  int get hashCode => Object.hash(runtimeType, id, title, description);

  /// Create a copy of ExampleItem
  /// with the given fields replaced by the non-null parameter values.
  @JsonKey(includeFromJson: false, includeToJson: false)
  @override
  @pragma('vm:prefer-inline')
  _$$ExampleItemImplCopyWith<_$ExampleItemImpl> get copyWith =>
      __$$ExampleItemImplCopyWithImpl<_$ExampleItemImpl>(this, _$identity);

  @override
  Map<String, dynamic> toJson() {
    return _$$ExampleItemImplToJson(this);
  }
}

abstract class _ExampleItem implements ExampleItem {
  const factory _ExampleItem({
    required final String id,
    required final String title,
    final String? description,
  }) = _$ExampleItemImpl;

  factory _ExampleItem.fromJson(Map<String, dynamic> json) =
      _$ExampleItemImpl.fromJson;

  @override
  String get id;
  @override
  String get title;
  @override
  String? get description;

  /// Create a copy of ExampleItem
  /// with the given fields replaced by the non-null parameter values.
  @override
  @JsonKey(includeFromJson: false, includeToJson: false)
  _$$ExampleItemImplCopyWith<_$ExampleItemImpl> get copyWith =>
      throw _privateConstructorUsedError;
}
