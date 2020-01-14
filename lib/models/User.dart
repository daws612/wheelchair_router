import 'package:cloud_firestore/cloud_firestore.dart';

class User {
  String userId;
  int age;
  String gender;

  User({
    this.userId,
    this.age,
    this.gender
  });

  factory User.fromJson(Map<String, dynamic> json) => new User(
    userId: json["userId"],
    age: int.parse(json["age"]) ?? 0,
    gender: json["gender"]
  );

  Map<String, dynamic> toJson() => {
    "age": age,
    "gender": gender
  };

  factory User.fromDocument(DocumentSnapshot doc) {
    if (doc == null || doc.data == null) return null; 

    User ret = User(
      userId: doc.documentID,
      age: doc["age"],
      gender: doc["gender"],
    );

    return ret;
  }
}

