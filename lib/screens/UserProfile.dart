import 'package:flutter/gestures.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:numberpicker/numberpicker.dart';
import 'package:routing/models/User.dart';
import 'package:url_launcher/url_launcher.dart';
import '../services/UserService.dart';

class UserProfile extends StatefulWidget {
  final User user;

  UserProfile({this.user});

  @override
  _UserProfileState createState() => _UserProfileState();
}

class _UserProfileState extends State<UserProfile> {
  final _formKey = GlobalKey<FormState>();
  final GlobalKey<ScaffoldState> _scaffoldKey = new GlobalKey<ScaffoldState>();
  List<String> _genders = ['Male', 'Female', 'Unspecified'];
  List<String> _wheelchairTypes = ['Electric', 'Manual', 'Unspecified'];
  int _age = 0;
  String _gender = "Unspecified";
  String _wheelchairType = "Unspecified";
  bool _accepted = false;
  bool showError = false;

  @override
  void initState() {
    super.initState();
    _age = widget.user.age;
    _gender = widget.user.gender;
    _wheelchairType = widget.user.wheelchairtype;
    _accepted = widget.user.accepted;
  }

  _submit() async {
    User user = User(
        userId: widget.user.userId,
        age: _age,
        gender: _gender,
        wheelchairtype: _wheelchairType,
        accepted: _accepted);
    UserService.updateUser(user);
    if (_accepted)
      Navigator.pop(context);
    else {
      if (!mounted) return;
      setState(() {
        showError = true;
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      key: _scaffoldKey,
      appBar: AppBar(
        title: Text("User Preferences"),
      ),
      body: WillPopScope(
          child: Container(
            child: Padding(
              padding: const EdgeInsets.all(20.0),
              child: Column(children: <Widget>[
                Container(
                  child: Row(
                    children: <Widget>[
                      Text("Age:"),
                      Spacer(),
                      new NumberPicker.horizontal(
                          initialValue: _age,
                          minValue: 0,
                          maxValue: 110,
                          step: 1,
                          onChanged: (newValue) =>
                              setState(() => _age = newValue)),
                      Spacer(),
                    ],
                  ),
                ),
                Container(
                  child: Row(
                    children: <Widget>[
                      Text("Gender:"),
                      Spacer(),
                      DropdownButton(
                       // validator: (value) => value == 'Unspecified' ? 'Please choose your gender' : null,
                        hint: Text(
                            'Please choose a location'), // Not necessary for Option 1
                        value: _gender,
                        onChanged: (newValue) {
                          if (!mounted) return;
                          setState(() {
                            _gender = newValue;
                          });
                        },
                        items: _genders.map((location) {
                          return DropdownMenuItem(
                            child: new Text(location),
                            value: location,
                          );
                        }).toList(),
                      ),
                      Spacer(),
                    ],
                  ),
                ),
                Container(
                  child: Row(
                    children: <Widget>[
                      Text("Wheelchair Type:"),
                      Spacer(),
                      DropdownButton(
                        //validator: (value) => value == null ? 'Please choose your wheelchair type' : null,
                        hint: Text(
                            'Please choose a wheelchair type'), // Not necessary for Option 1
                        value: _wheelchairType,
                        onChanged: (newValue) {
                          if (!mounted) return;
                          setState(() {
                            _wheelchairType = newValue;
                          });
                        },
                        items: _wheelchairTypes.map((location) {
                          return DropdownMenuItem(
                            child: new Text(location),
                            value: location,
                          );
                        }).toList(),
                      ),
                      Spacer(),
                    ],
                  ),
                ),
                Container(
                  child: CheckboxListTile(
                    title: new RichText(
                      text: new TextSpan(
                        children: [
                          new TextSpan(
                            text: "I've read and accept the ",
                            style: new TextStyle(color: Colors.black),
                          ),
                          new TextSpan(
                            text: 'Privacy policy',
                            style: new TextStyle(color: Colors.blue),
                            recognizer: new TapGestureRecognizer()
                              ..onTap = () {
                                launch('https://jaywjay.com');
                              },
                          ),
                        ],
                      ),
                    ),
                    value: _accepted,
                    onChanged: (newValue) {
                      if (!mounted) return;
                      setState(() {
                        _accepted = newValue;
                      });
                    },
                    controlAffinity: ListTileControlAffinity
                        .leading, //  <-- leading Checkbox
                  ),
                ),
                showError
                    ? Container(
                        child: Text(
                            "Please accept our privacy policy before you proceed. Thank you.",
                            style: TextStyle(color: Colors.red)),
                      )
                    : Container(
                        width: 0,
                        height: 0,
                      ),
                Container(
                  margin: EdgeInsets.all(40),
                  child: FlatButton(
                    onPressed: _submit,
                    textColor: Colors.white,
                    color: Colors.lightBlue,
                    child: Text(
                      'Save',
                      style: TextStyle(fontSize: 18),
                    ),
                  ),
                ),
              ]),
            ),
          ),
          onWillPop: _askToExit),
    );
  }

  DateTime backbuttonpressedTime;

  Future<bool> onWillPop() async {
    DateTime currentTime = DateTime.now();

    //Statement 1 Or statement2
    bool backButton = backbuttonpressedTime == null ||
        currentTime.difference(backbuttonpressedTime) > Duration(seconds: 3);

    if (backButton) {
      backbuttonpressedTime = currentTime;
      final snackBar = SnackBar(
        duration: Duration(minutes: 5),
        content: Text('Double tap to exit app'),
      );
      WidgetsBinding.instance.addPostFrameCallback(
          (_) => _scaffoldKey.currentState.showSnackBar(snackBar));
      return false;
    }
    return true;
  }

  Future<bool> _askToExit() {
    if (!widget.user.accepted) {
      return //WidgetsBinding.instance.addPostFrameCallback((_) => {
          showDialog(
                  context: context,
                  barrierDismissible: false,
                  builder: (BuildContext context) {
                    return new AlertDialog(
                      title: new Text('Please save your details'),
                      content: new Text(
                          'Please accept the privacy policy and make sure you save your details in order to proceed. This enables us to store your information and use it for our research. Thank you for your contribution.'),
                      actions: <Widget>[
                        new FlatButton(
                          child: new Text('Back'),
                          onPressed: () {
                            Navigator.of(context).pop();
                          },
                        ),
                        new FlatButton(
                          child: new Text('Exit'),
                          onPressed: () {
                            SystemChannels.platform
                                .invokeMethod('SystemNavigator.pop');
                          },
                        ),
                      ],
                    );
                  }) ??
              false;

      //return  Future.value(false);
      //});
    } else {
      return new Future.value(true);
    }
  }
}
