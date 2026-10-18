import 'dart:async';

import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/material.dart';
import 'package:shared_preferences/shared_preferences.dart';

import '../models.dart';

enum AuthStatus { loading, signedOut, ready }

class AppState extends ChangeNotifier {
  AuthStatus status = AuthStatus.loading;
  AppUser? user;
  ThemeMode themeMode = ThemeMode.light;

  StreamSubscription? _authSub;
  StreamSubscription? _userSub;

  AppState() {
    _loadTheme();
    _authSub = FirebaseAuth.instance.authStateChanges().listen(_onAuth);
  }

  Future<void> _loadTheme() async {
    try {
      final p = await SharedPreferences.getInstance();
      themeMode = p.getBool('dark') == true ? ThemeMode.dark : ThemeMode.light;
      notifyListeners();
    } catch (_) {}
  }

  Future<void> setDark(bool dark) async {
    themeMode = dark ? ThemeMode.dark : ThemeMode.light;
    notifyListeners();
    try {
      (await SharedPreferences.getInstance()).setBool('dark', dark);
    } catch (_) {}
  }

  void _onAuth(User? u) {
    _userSub?.cancel();
    if (u == null) {
      user = null;
      status = AuthStatus.signedOut;
      notifyListeners();
      return;
    }
    _userSub = FirebaseFirestore.instance.collection('users').doc(u.uid).snapshots().listen((d) {
      user = d.exists ? AppUser.fromDoc(d) : null;
      status = AuthStatus.ready;
      notifyListeners();
    });
  }

  Future<void> login(String email, String pass) =>
      FirebaseAuth.instance.signInWithEmailAndPassword(email: email.trim(), password: pass);

  /// Registro libre: queda pendiente hasta que la Hanagá lo apruebe.
  Future<void> register({
    required String email,
    required String pass,
    required String nombre,
    required String apodo,
  }) async {
    final c = await FirebaseAuth.instance
        .createUserWithEmailAndPassword(email: email.trim(), password: pass);
    await FirebaseFirestore.instance.collection('users').doc(c.user!.uid).set({
      'email': email.trim(),
      'nombre': nombre.trim(),
      'apodo': apodo.trim(),
      'rol': 'janij',
      'kuvthzaId': null,
      'aprobado': false,
      'fotoUrl': null,
      'creado': FieldValue.serverTimestamp(),
    });
  }

  Future<void> logout() => FirebaseAuth.instance.signOut();

  Future<void> changePassword(String current, String next) async {
    final u = FirebaseAuth.instance.currentUser!;
    await u.reauthenticateWithCredential(
        EmailAuthProvider.credential(email: u.email!, password: current));
    await u.updatePassword(next);
  }

  @override
  void dispose() {
    _authSub?.cancel();
    _userSub?.cancel();
    super.dispose();
  }
}
