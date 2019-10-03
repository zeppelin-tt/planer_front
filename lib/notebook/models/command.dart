import 'dart:convert';

import 'package:json_annotation/json_annotation.dart';

import 'note.dart';

part 'command.g.dart';

@JsonSerializable(includeIfNull: false)
class Command {

  String cmd;
  int id;
  Note note;
  List<Note> notes;
  int unfinishedCount;
  int errorCode;
  String errorDescription;

  Command({this.cmd, this.id, this.note, this.notes, this.unfinishedCount, this.errorCode, this.errorDescription});

  factory Command.fromJson(Map<String, dynamic> json) => _$CommandFromJson(json);

  factory Command.fromStringJson(String json) => _$CommandFromJson(jsonDecode(json));

  Map<String, dynamic> toJson() => _$CommandToJson(this);

  String toStringJson() => json.encode(this.toJson());

  @override
  String toString() {
    return '''Command{cmd: $cmd, id: $id, note: $note, notes: $notes, unfinishedCount: $unfinishedCount, 
                      errorCode: $errorCode, errorDescription: $errorDescription}''';
  }

}
