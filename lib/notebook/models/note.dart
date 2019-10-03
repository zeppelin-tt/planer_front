import 'dart:convert';

import 'package:json_annotation/json_annotation.dart';

part 'note.g.dart';

@JsonSerializable(includeIfNull: false)
class Note {

  int id;
  String title;
  bool done = false;

  Note({this.id, this.title, this.done});

  Note.withTitle(this.title);

  factory Note.fromJson(Map<String, dynamic> json) => _$NoteFromJson(json);

  factory Note.fromJsonString(String jsonStr) => _$NoteFromJson(json.decode(jsonStr));

  Map<String, dynamic> toJson() => _$NoteToJson(this);

  Note changeTitle(String title) {
    this.title = title;
    return this;
  }

  @override
  String toString() => 'Note{id: $id, title: $title, done: $done}';

}
