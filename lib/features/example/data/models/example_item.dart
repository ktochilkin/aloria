import 'package:freezed_annotation/freezed_annotation.dart';

part 'example_item.freezed.dart';
part 'example_item.g.dart';

@freezed
class ExampleItem with _$ExampleItem {
  const factory ExampleItem({
    required String id,
    required String title,
    String? description,
  }) = _ExampleItem;

  factory ExampleItem.fromJson(Map<String, dynamic> json) =>
      _$ExampleItemFromJson(json);
}
