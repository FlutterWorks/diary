import 'package:client/native.dart';
import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import 'package:prompt_dialog/prompt_dialog.dart';

import '../edit_command.dart';
import '../password_manager.dart';
import '../storage.dart';

class EditorPage extends StatefulWidget {
  final EditCommand cmd;

  const EditorPage({super.key, required this.cmd});

  @override
  State<StatefulWidget> createState() => _EditorPageState();
}

class _EditorPageState extends State<EditorPage> {
  static final DateFormat _dateFormat = DateFormat('dd. MMMM yyyy');

  String _originalText = "";
  final ScrollController _scrollController = ScrollController();
  final TextEditingController _textEditingController = TextEditingController();

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: _buildAppBar(context),
      body: SafeArea(
        child: FutureBuilder(
          builder: (context, snapshot) {
            if (snapshot.connectionState == ConnectionState.done) {
              return _buildTextfield();
            } else {
              return _buildLoadingIndicator();
            }
          },
          future: _load(context),
        ),
      ),
    );
  }

  Center _buildLoadingIndicator() =>
      const Center(child: CircularProgressIndicator());

  AppBar _buildAppBar(BuildContext context) {
    return AppBar(
      title: Text(_dateFormat.format(widget.cmd.date)),
      centerTitle: true,
      leading: BackButton(onPressed: () => _requestClose(context)),
      backgroundColor: Colors.transparent,
      foregroundColor: Colors.black,
      elevation: 0,
    );
  }

  Scrollbar _buildTextfield() => Scrollbar(
        controller: _scrollController,
        child: TextField(
          controller: _textEditingController,
          scrollController: _scrollController,
          autofocus: true,
          expands: true,
          keyboardType: TextInputType.multiline,
          maxLines: null,
          autocorrect: false,
          onChanged: (s) => {},
          decoration: const InputDecoration(
            border: InputBorder.none,
            contentPadding: EdgeInsets.all(20.0),
            isDense: true,
          ),
        ),
      );

  Future<void> _requestClose(BuildContext context) async {
    bool isUnchanged = _originalText == _textEditingController.text;
    if (isUnchanged) {
      Navigator.pop(context);
      return;
    }

    bool saveChanges = await showDialog(
      context: context,
      barrierDismissible: false,
      builder: (ctx) => _buildCloseDialog(ctx),
    );

    if (saveChanges) {
      await _save(context);

      final snackBar = SnackBar(
        content:
            Text('Changes to ${_dateFormat.format(widget.cmd.date)} saved'),
      );

      ScaffoldMessenger.of(context).showSnackBar(snackBar);
    }

    Navigator.pop(context);
  }

  _buildCloseDialog(BuildContext ctx) {
    return AlertDialog(
      title: const Text('Save changes?'),
      content: const Text('Do you want to save your changes?'),
      actions: [
        TextButton(
          onPressed: () => Navigator.of(ctx).pop(false),
          child: const Text('Discard'),
        ),
        TextButton(
          onPressed: () => Navigator.of(ctx).pop(true),
          child: const Text('Save'),
        ),
      ],
    );
  }

  Future<void> _load(BuildContext context) async {
    var diaryFile = _getDiaryFile();

    var text = "";
    var shouldLoadEntry = !widget.cmd.createNewEntry;
    while (shouldLoadEntry) {
      try {
        var password = await _requestPassword(context);

        text = await api.load(
          filePath: diaryFile,
          password: password,
        );
        break;
      } catch (e) {
        if (e is bool && !e) {
          Navigator.pop(context);
          return;
        }

        await PasswordManager.clear();

        const snackBar = SnackBar(
          content: Text(
              'The diary could not be decrypted. Maybe the password is wrong?'),
        );

        ScaffoldMessenger.of(context).showSnackBar(snackBar);
      }
    }

    _originalText = text;
    _textEditingController.text = text;
  }

  Future<void> _save(BuildContext context) async {
    var diaryFile = _getDiaryFile();
    var password = await _requestPassword(context);

    api.save(
      filePath: diaryFile,
      password: password,
      data: text,
    );
  }

  String _getDiaryFile() => DiaryStorage.getDiaryFilePath(
        widget.cmd.date.year,
        widget.cmd.date.month,
        widget.cmd.date.day,
      );

  String get text => _textEditingController.text;

  Future<String> _requestPassword(BuildContext context) async {
    if (await PasswordManager.hasPassword()) {
      return await PasswordManager.readPassword() ?? "";
    } else {
      var password = await prompt(
        context,
        title: const Text('Enter password'),
        obscureText: true,
        autoFocus: true,
        showPasswordIcon: true
      );
      if (password == null) {
        throw false;
      }

      await PasswordManager.savePassword(password);

      return password;
    }
  }
}
