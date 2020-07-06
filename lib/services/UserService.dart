import 'dart:async';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:dio/dio.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:routing/Constants.dart';
import '../models/User.dart';

class UserService {
  static final _auth = FirebaseAuth.instance;
  static final _firestore = Firestore.instance;

  static Future<User> getDbUser(String uid) async {
    print("Get user with uid :: " + uid);
    User user;
    await _firestore.collection('/users').document(uid).get().then((userDoc) {
      if (userDoc.data == null) {
        return null;
      }
      user = User.fromDocument(userDoc);
    });
    return user;
  }

  static Future<FirebaseUser> currentUser() async {
    return await FirebaseAuth.instance.currentUser().then((onValue) {
      return onValue;
    });
  }

  static void updateUser(User user) {
    _firestore
        .collection('/users')
        .document(user.userId)
        .updateData(user.toJson());
    updateClusters();
  }

  static Future<String> getFirebaseUserId() async {
    try {
      final FirebaseUser _anonUser = await _auth.signInAnonymously();
      return _anonUser.uid;
    } catch (ex) {
      print(ex);
      return "";
    }
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
          gender: "Unspecified",
          userId: _anonUser.uid,
          createdAt: DateTime.now().toUtc(),
        );
      }
      _firestore
          .collection('/users')
          .document(_anonUser.uid)
          .setData(dbUser.toJson());
      return true;
    } catch (ex) {
      print(ex);
      return false;
    }
  }

  static updateClusters() async {
    print("*********************CLUSTER USERS********************");
    var url = Constants.serverUrl + '/updateclusters';
    try {
      Response response = await Dio().get(url);
      if (response.statusCode == 200) {
        print("Users clustered successfully");
      }
    } catch (exception) {
      print(exception);
    }
  }
}
