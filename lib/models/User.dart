import 'package:cloud_firestore/cloud_firestore.dart';

class User {
  String userId;
  int age;
  String gender;
  DateTime createdAt;
  DateTime updatedAt;

  User({
    this.userId,
    this.age,
    this.gender,
    this.createdAt,
    this.updatedAt
  });

  factory User.fromJson(Map<String, dynamic> json) => new User(
    userId: json["userId"],
    age: int.parse(json["age"]) ?? 0,
    gender: json["gender"],
    createdAt: DateTime.fromMillisecondsSinceEpoch(json['createdAt'], isUtc: true),
    updatedAt: DateTime.fromMillisecondsSinceEpoch(json['updatedAt'], isUtc: true),
  );

  Map<String, dynamic> toJson() => {
    "age": age,
    "gender": gender,
    'updatedAt': DateTime.now().toUtc().millisecondsSinceEpoch,
  };

  factory User.fromDocument(DocumentSnapshot doc) {
    if (doc == null || doc.data == null) return null; 

    User ret = User(
      userId: doc.documentID,
      age: doc["age"],
      gender: doc["gender"],
      createdAt: doc['createdAt'] != null ? DateTime.fromMillisecondsSinceEpoch(doc['createdAt'], isUtc: true) : null,
      updatedAt: doc['updatedAt'] != null ? DateTime.fromMillisecondsSinceEpoch(doc['updatedAt'], isUtc: true) : null,
    );

    return ret;
  }
}

