import 'dart:convert';

class LoginCertificate {
  String userID;
  String imToken;
  String chatToken;
  bool needProfile;
  String? account;
  String? password;
  String? email;
  String? nickname;
  String? faceURL;

  LoginCertificate.fromJson(Map<String, dynamic> map)
      : userID = map["userID"] ?? '',
        imToken = map["imToken"] ?? map['token'] ?? '',
        chatToken = map['chatToken'] ?? map['token'] ?? '',
        needProfile = map['needProfile'] ?? true,
        account = map['account'],
        password = map['password'],
        email = map['email'],
        nickname = map['nickname'],
        faceURL = map['faceURL'];

  Map<String, dynamic> toJson() {
    final data = <String, dynamic>{};
    data['userID'] = userID;
    data['imToken'] = imToken;
    data['chatToken'] = chatToken;
    data['needProfile'] = needProfile;
    if (account != null) data['account'] = account;
    if (password != null) data['password'] = password;
    if (email != null) data['email'] = email;
    if (nickname != null) data['nickname'] = nickname;
    if (faceURL != null) data['faceURL'] = faceURL;
    return data;
  }

  @override
  String toString() {
    return jsonEncode(this);
  }
}
