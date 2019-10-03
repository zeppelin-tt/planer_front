import 'package:flutter/material.dart';
import 'package:oktoast/oktoast.dart';
import 'package:planer/notebook/screens/note_list.dart';


void main() {
  UniversalController<NoteListState> noteListController = UniversalController();
  return runApp(
      OKToast(
          child: MaterialApp(
            title: 'Simple Planer',
            //debugShowCheckedModeBanner: false,
            theme: new ThemeData(
              brightness: Brightness.dark,
              textTheme: new TextTheme(
                body1: new TextStyle(color: Colors.grey),
              ),
            ),
            home: NoteList(universalController: noteListController),
          )
      )
  );
}
