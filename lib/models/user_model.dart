import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart' as auth;

enum UserRole {
  admin,
  supplier,
  delivery,
  customer,
} 

class AddressModel {
  final String id;
  final String block;
  final String? road;
  final String building;

  AddressModel({
    required this.id,
    required this.block,
    this.road,
    required this.building,
  });

  factory AddressModel.fromMap(Map<String, dynamic> map, String id) {
    return AddressModel(
      id: id,
      block: map['block'] ?? '',
      road: map['road'],
      building: map['building'] ?? '',
    );
  }

  Map<String, dynamic> toMap() {
    return {
      'block': block,
      'road': road,
      'building': building,
    };
  }
}

class UserModel {
  final String id;
  final String email;
  final String name;
  final String role;
  final bool isActive;
  final List<AddressModel> addresses;
  final String phone;

  UserModel({
    required this.id,
    required this.email,
    required this.name,
    required this.role,
    required this.phone,
    this.isActive = true,
    this.addresses = const [],
  });

  factory UserModel.fromFirestore(DocumentSnapshot doc) {
    final data = doc.data() as Map<String, dynamic>;
    final addresses = (data['addresses'] as List<dynamic>? ?? [])
        .asMap()
        .entries
        .map((e) => AddressModel.fromMap(e.value as Map<String, dynamic>, e.key.toString()))
        .toList();

    return UserModel(
      id: doc.id,
      email: data['email'] ?? '',
      name: data['name'] ?? '',
      role: data['role'] ?? 'customer',
      phone: data['phone'] ?? '',
      isActive: data['isActive'] ?? true,
      addresses: addresses,
    );
  }

  factory UserModel.fromFirebaseUser(auth.User user) {
    return UserModel(
      id: user.uid,
      email: user.email ?? '',
      name: user.displayName ?? '',
      role: 'customer', // Default role
      phone: '',
      isActive: true,
    );
  }

  factory UserModel.fromJson(Map<String, dynamic> json, String uid) {
    final addresses = (json['addresses'] as List<dynamic>? ?? [])
        .asMap()
        .entries
        .map((e) => AddressModel.fromMap(e.value as Map<String, dynamic>, e.key.toString()))
        .toList();

    return UserModel(
      id: uid,
      email: json['email'] ?? '',
      name: json['name'] ?? '',
      role: json['role'] ?? 'customer',
      phone: json['phone'] ?? '',
      isActive: json['isActive'] ?? true,
      addresses: addresses,
    );
  }

  Map<String, dynamic> toJson() {
    return {
      'email': email,
      'name': name,
      'role': role,
      'phone': phone,
      'isActive': isActive,
      'addresses': addresses.map((a) => a.toMap()).toList(),
    };
  }

  Map<String, dynamic> toMap() {
    return {
      'email': email,
      'name': name,
      'role': role,
      'phone': phone,
      'isActive': isActive,
      'addresses': addresses.map((a) => a.toMap()).toList(),
    };
  }

  UserModel copyWith({
    String? id,
    String? email,
    String? name,
    String? role,
    String? phone,
    bool? isActive,
    List<AddressModel>? addresses,
  }) {
    return UserModel(
      id: id ?? this.id,
      email: email ?? this.email,
      name: name ?? this.name,
      role: role ?? this.role,
      phone: phone ?? this.phone,
      isActive: isActive ?? this.isActive,
      addresses: addresses ?? this.addresses,
    );
  }

  bool get isAdmin => role == 'admin';
  bool get isSupplier => role == 'supplier';
  bool get isDelivery => role == 'delivery';
  bool get isCustomer => role == 'customer';

  bool canManageProducts() => isAdmin || isSupplier;
  bool canManageOrders() => isAdmin || isSupplier || isDelivery;
  bool canManageCategories() => isAdmin;
  bool canManageUsers() => isAdmin;
  bool canViewDashboard() => isAdmin || isSupplier || isDelivery;
  bool canViewReports() => isAdmin;
  bool canManageStock() => isAdmin || isSupplier;
  bool canManageDeliveries() => isAdmin || isDelivery;
} 