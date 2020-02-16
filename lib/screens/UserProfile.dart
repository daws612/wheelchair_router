import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/material.dart';
import 'package:numberpicker/numberpicker.dart';
import 'package:routing/models/User.dart';
import '../services/UserService.dart';

class UserProfile extends StatefulWidget {
  final User user;

  UserProfile({this.user});

  @override
  _UserProfileState createState() => _UserProfileState();
}

class _UserProfileState extends State<UserProfile> {
  final _formKey = GlobalKey<FormState>();
  List<String> _genders = ['Male', 'Female', 'Unspecified'];
  List<String> _wheelchairTypes = ['Electric', 'Manual', 'Unspecified'];
  int _age = 0;
  String _gender = "Unspecified";
  String _wheelchairType = "Unspecified";

  @override
  void initState() {
    super.initState();
    _age = widget.user.age;
    _gender = widget.user.gender;
    _wheelchairType = widget.user.wheelchairtype;
  }

  _submit() async {
    User user = User(userId: widget.user.userId, age: _age, gender: _gender, wheelchairtype: _wheelchairType);
    UserService.updateUser(user);
    Navigator.pop(context);
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: Text("User Preferences"),
      ),
      body: Container(
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
                      onChanged: (newValue) => setState(() => _age = newValue)),
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
    );
  }
}
