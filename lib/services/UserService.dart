import 'dart:async';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import '../models/User.dart';

class UserService {
  static final _auth = FirebaseAuth.instance;
  static final _firestore = Firestore.instance;

  static Future<User> getDbUser(String uid) async {
    User user;
    await _firestore.collection('/users').document(uid).get().then((userDoc) {
      if (userDoc.data == null) { return null; }
      user = User.fromDocument(userDoc);
    } );
    return user;
  }

  static Future<bool> anonymousLogin() async {
    try {
      final FirebaseUser _anonUser = await _auth.signInAnonymously();
      //Check if the user exists in the db
      User dbUser = await getDbUser(_anonUser.uid);
      //Create the user in the database
      if (dbUser == null) {
        dbUser = User(
          age: 0,
          gender: "X",
          userId: _anonUser.uid,
        );
      }      
      _firestore.collection('/users').document(_anonUser.uid).setData(dbUser.toJson());
    } catch(ex) {
      print (ex);
      return false;
    }
  }
}