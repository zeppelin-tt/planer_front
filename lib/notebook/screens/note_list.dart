import 'dart:core';

import 'package:collection/collection.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_spinkit/flutter_spinkit.dart';
import 'package:logger/logger.dart';
import 'package:oktoast/oktoast.dart';
import 'package:planer/notebook/models/command.dart';
import 'package:planer/notebook/models/note.dart';
import 'package:w_transport/vm.dart' show vmTransportPlatform;
import 'package:w_transport/w_transport.dart' as Transport;

class UniversalController<T> {
  T _state;

  connect(T state) {
    _state = state;
  }

  getState() {
    return _state;
  }
}

class NoteList extends StatefulWidget {
  final UniversalController<NoteListState> universalController;

  NoteList({this.universalController});

  @override
  NoteListState createState() => NoteListState();
}

class NoteListState extends State<NoteList> with SingleTickerProviderStateMixin, WidgetsBindingObserver {

  final log = Logger();

  final GlobalKey<AnimatedListState> _animatedListKey = GlobalKey<AnimatedListState>();

  TextEditingController _inputController = TextEditingController();
  BlacklistingTextInputFormatter _blacklistingTextInputFormatter;
  IconData _sendIconData;
  List<Note> _noteList;
  bool _isAnimatedDelete = true;
  Note _updatingNote;
  final FocusNode inputFocusNode = FocusNode();
  List<AppLifecycleState> _statusHistory = [];

  Transport.WebSocket _webSocket;
  Uri _address;

  @override
  void initState() {
    super.initState();
//    _address = Uri(scheme: 'ws', host: '192.168.1.56', port: 8001, path: 'endpoint');
//    _address = Uri(scheme: 'ws', host: '84.201.140.32', port: 8000, path: 'endpoint');
    _address = Uri(scheme: 'ws', host: '84.201.140.32', port: 8001, path: 'endpoint');
    _blacklistingTextInputFormatter = BlacklistingTextInputFormatter(RegExp('^\n'));
    _initAndListen();
    this.widget.universalController.connect(this);
    WidgetsBinding.instance.addObserver(this);
  }

  @override
  void dispose() {
    WidgetsBinding.instance.removeObserver(this);
    super.dispose();
  }


  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    setState(() {
      _buildStatusHistory(state);
    });
    if (_statusHistory.length > 3 && state == AppLifecycleState.resumed && !_isOpenConnection()) {
      _initAndListen();
      log.i('was reopen after dissconnect');
    }
  }

  _buildStatusHistory(state) {
    if (_statusHistory.length < 5) {
      _statusHistory.add(state);
    }
    else {
      _statusHistory.removeAt(0);
      _statusHistory.add(state);
    }
  }

  @override
  Widget build(BuildContext context) => _buildScaffold(_noteList != null, context);

  Scaffold _buildScaffold(isLoaded, context) {
    return Scaffold(
        appBar: AppBar(
          title: Text('Planer'),
          actions: <Widget>[
            isLoaded ? _deleteAllButton() : Container(),
          ],
        ),
        body: isLoaded ? _buildBody(context) : _buildLoadingWidget()
    );
  }

  Center _buildLoadingWidget() {
    return Center(
      child: SpinKitWave(
        color: Colors.white,
        type: SpinKitWaveType.start,
      ),
    );
  }

  IconButton _deleteAllButton() {
    return IconButton(
      padding: EdgeInsets.only(right: 20),
      icon: Icon(Icons.clear_all),
      onPressed: () => _wsDeleteAll(),
    );
  }

  Column _buildBody(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: <Widget>[
        _buildNoteList(context),
        _buildTextInput(),
      ],
    );
  }

  Expanded _buildNoteList(BuildContext context) {
    return Expanded(
      child: GestureDetector(
          onTap: () {
            FocusScope.of(context).requestFocus(FocusNode());
//            FocusScope.of(context).unfocus();
          }, //todo придумать, как подружить вертикальный с горизонтальным
          child: AnimatedList(
            key: _animatedListKey,
            initialItemCount: _noteList.length,
            itemBuilder: (context, index, animation) => _buildItem(context, _noteList[index], animation),
          )
      ),
    );
  }

  Container _buildTextInput() {
    return Container(
      color: Colors.black26,
      child: TextField( //TODO ждать, когда исправят баг. Пока работает с исключениями.
        minLines: 1,
        maxLines: 2,
        textDirection: TextDirection.ltr,
        controller: _inputController,
        inputFormatters: [ _blacklistingTextInputFormatter],
        focusNode: inputFocusNode,
        onChanged: (value) {
          setState(() {
            _sendIconData = _inputController.text.isEmpty ? null : Icons.label_important;
          });
        },
        decoration: InputDecoration(
          border: InputBorder.none,
          hintText: 'Todo',
          contentPadding: EdgeInsets.only(left: 15, top: 15, right: 10),
          suffixIcon: IconButton(
            icon: Icon(_sendIconData),
            onPressed: () {
              if (_sendIconData == null)
                return null;
              else
                setState(() {
                  _sendIconData = null;
                  _updatingNote != null
                      ? _wsUpdateNote(_updatingNote.changeTitle(_inputController.text))
                      : _wsCreateNote(Note.withTitle(_inputController.text));
                  WidgetsBinding.instance.addPostFrameCallback((_) => _inputController.clear());
                  _inputController.text = '';
                });
            },
          ),
        ),
      ),
    );
  }

  _addNote(int unfinishedCount, Note dbNote, int durationMills) {
    setState(() {
      _animatedListKey.currentState.insertItem(unfinishedCount - 1, duration: Duration(milliseconds: durationMills));
      _noteList.insert(unfinishedCount - 1, dbNote);
    });
    log.i('note created: ${dbNote.toString()}');
  }

  _updateNote(Note dbNote, int durationMills) {
    var indexById = _getIndexById(dbNote.id);
    setState(() {
      Note removedNote = _noteList.removeAt(indexById);
      _animatedListKey.currentState.removeItem(indexById,
              (context, animation) => _buildItem(context, removedNote, animation), duration: Duration(milliseconds: durationMills));
      _animatedListKey.currentState.insertItem(indexById, duration: Duration(milliseconds: durationMills));
      _noteList.insert(indexById, dbNote);
      _updatingNote = null;
    });
    log.i('note updated: ${dbNote.toString()}');
  }

  _addAll(List<Note> notes, int durationMills) {
    setState(() {
      for (var i = 0; i < notes.length; i++) {
        _animatedListKey.currentState.insertItem(i, duration: Duration(milliseconds: durationMills));
        _noteList.insert(i, notes[i]);
      }
    });
  }

  _removeNote(int id, bool withAnimation) {
    var indexById = _getIndexById(id);
    setState(() {
      Note removedNote = _noteList.removeAt(indexById);
      if (withAnimation)
        _animatedListKey.currentState.removeItem(indexById,
                (context, animation) => _buildItem(context, removedNote, animation), duration: const Duration(milliseconds: 500));
      else
        _animatedListKey.currentState.removeItem(indexById, (context, animation) => Container());
    });
  }

  _removeAll(bool withAnimation) {
    setState(() {
      for (var i = _noteList.length - 1; i >= 0; i--) {
        Note itemToRemove = _noteList[i];
        if (withAnimation)
          _animatedListKey.currentState.removeItem(i, (context, animation) =>
              _buildItem(context, itemToRemove, animation), duration: const Duration(milliseconds: 500));
        else
          _animatedListKey.currentState.removeItem(i, (context, animation) => Container());
      }
      _noteList.clear();
    });
    log.i('notes cleared');
  }

  _toggleNoteState(int unfinishedCount, Note dbNote) {
    var index = _getIndexById(dbNote.id);
    if (index != null) {
      setState(() {
        if ((dbNote.done && index == unfinishedCount) || (!dbNote.done && index == unfinishedCount - 1)) {
          _noteList[index] = dbNote;
        } else {
          _animatedListKey.currentState.removeItem(
              index, (context, animation) => _buildItem(context, _noteList[index], animation), duration: const Duration(milliseconds: 200)
          );
          _noteList.removeAt(index);
          if (dbNote.done) {
            _animatedListKey.currentState.insertItem(unfinishedCount, duration: const Duration(milliseconds: 200));
            _noteList.insert(unfinishedCount, dbNote);
          } else {
            _animatedListKey.currentState.insertItem(unfinishedCount - 1, duration: const Duration(milliseconds: 200));
            _noteList.insert(unfinishedCount - 1, dbNote);
          }
        }
      });
    } else {
      dbNote.done = !dbNote.done;
      _initAndListenWithCmd(["TOGGLE", dbNote]);
      log.w('not found Note by id: ${dbNote.id}');
    }
    log.i('note toggled: ${dbNote.toString()}');
  }

  int _getIndexById(int id) {
    for (var i = 0; i < _noteList.length; i++) {
      if (id == _noteList[i].id) {
        return i;
      }
    }
    return null;
  }

  TextStyle _getCurrentNoteTextStyle(Note note) =>
      TextStyle(
        decoration: note.done ? TextDecoration.lineThrough : TextDecoration.none,
        fontFamily: 'FiraSansCondensed',
        fontWeight: FontWeight.w400,
        color: _updatingNote != null && _updatingNote.id == note.id
            ? Colors.orange
            : note.done ? Colors.grey[600] : Colors.grey[300],
        fontSize: 26,
      );

  Widget _buildItem(BuildContext context, Note note, Animation<double> animation) {
    return SizeTransition(
      key: Key('${note.hashCode}'),
      sizeFactor: animation,
      child: Dismissible(
        key: Key(UniqueKey().toString()),
        background: _buildDismissBackground(EdgeInsets.only(left: 25), Alignment.centerLeft),
        secondaryBackground: _buildDismissBackground(EdgeInsets.only(right: 25), Alignment.centerRight),
        confirmDismiss: (DismissDirection direction) {
          if (_updatingNote != null && _updatingNote.id == note.id) {
            _showToast('finish editing before deleting');
            return Future.value(false);
          } else {
            return Future.value(true);
          }
        },
        onDismissed: (direction) {
          setState(() {
            _isAnimatedDelete = false;
          });
          _wsDeleteNote(note.id);
        },
        child: Column(children: [
          GestureDetector(
            onLongPress: () {
              FocusScope.of(context).requestFocus(inputFocusNode);
              setState(() {
                _updatingNote = note;
                _inputController.text = note.title;
//                    TextEditingController
//                    .fromValue(TextEditingValue(text: note.title))
//                    .value;
              });
            },
            child: CheckboxListTile(
              title: Padding(
                padding: EdgeInsets.only(left: 5),
                child: Text(
                  note.title,
                  textDirection: TextDirection.ltr,
                  style: _getCurrentNoteTextStyle(note),
                ),
              ),
              value: note.done,
              onChanged: (bool newValue) {
                if (_updatingNote == null)
                  _wsToggleNoteState(note);
                else
                  _showToast('finish editing before changing status');
              },
              dense: true,
              controlAffinity: ListTileControlAffinity.trailing,
              selected: true,
            ),
          ),
          Divider(height: 1, color: Colors.black26,)
        ]),
      ),
    );
  }

  Container _buildDismissBackground(padding, alignment) {
    return Container(
      color: Colors.grey,
      child: Padding(
        padding: padding,
        child: Align(
          alignment: alignment,
          child: Icon(
            Icons.delete_forever,
            color: Colors.black,
          ),
        ),
      ),
    );
  }

  _initAndListen() {
    _initAndListenWithCmd(null);
  }

  _initAndListenWithCmd(List<dynamic> withCmd) async {
    log.i('try to connect...');
    try {
      _webSocket = await Transport.WebSocket.connect(_address, transportPlatform: vmTransportPlatform)
          .timeout(Duration(seconds: 10), onTimeout: () => null);
    } catch (ex) {
      log.w('connection error: ${ex.toString()}');
      return;
    }
    if (_webSocket == null) {
      _showToast('Connection Error');
      log.w('not connected after timeout');
      return;
    }
    _webSocket.listen((message) async {
      Command command;
      try {
        command = Command.fromStringJson(message);
      } catch (e) {
        log.w('parsing command error');
        return;
      }
      try {
        var note = command.note;
        switch (command.cmd) {
          case 'GET_ALL':
            _getAllNotes(command);
            break;
          case 'CREATE':
            _addNote(command.unfinishedCount, note, 500);
            break;
          case 'UPDATE':
            _updateNote(note, 500);
            break;
          case 'TOGGLE':
            _toggleNoteState(command.unfinishedCount, note);
            break;
          case 'DELETE':
            _deleteOperation(command);
            break;
          case 'DELETE_ALL':
            _removeAll(true);
            break;
          case 'ERROR':
            _errorOperation(command);
            break;
          default:
            log.wtf('command not supported: ${command.cmd}');
        }
      } catch (error) {
        log.w('Error: ${error.toString()}');
      }
    }, onError: (error) {
      log.w('Error: ${error.toString()}');
    }, onDone: () {
      log.w('connestionwas closed');
    });
    if (withCmd != null)
      _reprocessing(withCmd);
  }

  _getAllNotes(Command command) {
    setState(() {
      _noteList = command.notes;
    });
    log.i('notes received: ${command.notes}');
  }

  void _deleteOperation(Command command) {
    log.i('note deleted by id: ${command.id} animatiom: $_isAnimatedDelete');
    if (_isAnimatedDelete) {
      _removeNote(command.id, _isAnimatedDelete);
    } else {
      setState(() {
        _isAnimatedDelete = true;
      }); // operation already done for correct animation: crooked nail!!!
    }
  }

  void _errorOperation(Command command) {
    if (command.errorCode == 3 && !ListEquality().equals(_noteList, command.notes)) {
      _updatingNote = null;
      _removeAll(false);
      _addAll(command.notes, 0);
    }
    _showToast(command.errorDescription);
    log.i('Error: [code = ${command.errorCode}; description = ${command.errorDescription}]');
  }

  void _reprocessing(List withCmd) {
    if (withCmd != null) { //todo validation!
      switch (withCmd[0].toString()) {
        case "CREATE":
          _wsCreateNote(withCmd[1]);
          break;
        case "UPDATE":
          _wsUpdateNote(withCmd[1]);
          break;
        case "TOGGLE":
          _wsToggleNoteState(withCmd[1]);
          break;
        case "DELETE":
          _wsDeleteNote(withCmd[1]);
          break;
        case "DELETE_ALL":
          _wsDeleteAll();
          break;
      }
    }
    withCmd = null;
  }

  void _wsCreateNote(Note noteToCreate) {
    if (_isOpenConnection())
      _webSocket.add(Command(cmd: 'CREATE', note: noteToCreate).toStringJson());
    else
      _initAndListenWithCmd(["CREATE", noteToCreate]);
  }

  void _wsUpdateNote(Note noteToUpdate) {
    if (_isOpenConnection())
      _webSocket.add(Command(cmd: 'UPDATE', note: noteToUpdate).toStringJson());
    else
      _initAndListenWithCmd(["UPDATE", noteToUpdate]);
  }

  void _wsToggleNoteState(Note note) {
    if (_isOpenConnection()) {
      FocusScope.of(context).requestFocus(FocusNode());
//      FocusScope.of(context).unfocus();
      _webSocket.add(Command(cmd: 'TOGGLE', note: note).toStringJson());
    } else {
      _initAndListenWithCmd(["TOGGLE", note]);
    }
  }

  void _wsDeleteNote(int id) {
    if (_isOpenConnection()) {
      _removeNote(id, _isAnimatedDelete);
      _webSocket.add(Command(cmd: 'DELETE', id: id).toStringJson());
    } else
      _initAndListenWithCmd(['DELETE', id]);
  }

  void _wsDeleteAll() {
    if (_isOpenConnection())
      _webSocket.add(Command(cmd: 'DELETE_ALL').toStringJson());
    else
      _initAndListenWithCmd(['DELETE_ALL']);
  }

  bool _isOpenConnection() => (_webSocket != null && _webSocket.closeCode == null);

  void _showToast(msg) =>
      showToast(msg,
          duration: Duration(seconds: 3),
          radius: 4,
          backgroundColor: Colors.black.withOpacity(0.7),
          position: ToastPosition.bottom,
          dismissOtherToast: true,
          textStyle: TextStyle(fontSize: 20.0)
      );

}
