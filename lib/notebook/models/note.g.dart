part of 'note.dart';

Note _$NoteFromJson(Map<String, dynamic> json) {
  return Note(
    id: json['id'] as int,
    title: json['title'] as String,
    done: json['done'] as bool,
  );
}

Map<String, dynamic> _$NoteToJson(Note instance) =>
    <String, dynamic>{
      'id': instance.id,
      'title': instance.title,
      'done': instance.done,
    };
