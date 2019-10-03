part of 'command.dart';

Command _$CommandFromJson(Map<String, dynamic> json) {
  return Command(
    cmd: json['cmd'] as String,
    id: json['id'] as int,
    note: json['note'] == null ? null : Note.fromJson(json['note'] as Map<String, dynamic>),
    notes: json['notes'] == null ? null : (json['notes'] as List)
        ?.map((note) => note == null ? null : Note.fromJson(note))
        ?.toList(),
    unfinishedCount: json['unfinishedCount'] as int,
    errorCode: json['errorCode'] as int,
    errorDescription: json['errorDescription'] as String,
  );
}

Map<String, dynamic> _$CommandToJson(Command instance) =>
    <String, dynamic>{
      'cmd': instance.cmd,
      'id': instance.id,
      'note': instance.note == null ? null : instance.note.toJson(),
      'notes': instance.notes == null ? null : _notesToJson(instance.notes),
      'unfinishedCount': instance.unfinishedCount,
      'errorCode': instance.errorCode,
      'errorDescription': instance.errorDescription,
    };

List<Map<String, dynamic>> _notesToJson(List<Note> notes) {
  var list = List();
  notes.forEach((note) => list.add(note.toJson()));
  return list;
}
