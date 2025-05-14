import 'package:cloud_firestore/cloud_firestore.dart';
import 'user_model.dart';

enum OrderFulfillment {
  draft,
  pending,
  unfulfilled,
  fulfilled,
  cancelled,
  import,
}

class OrderLine {
  final String id; // product id
  final int quantity;
  final double? price; // Added for import orders

  OrderLine({
    required this.id,
    required this.quantity,
    this.price,
  });

  factory OrderLine.fromMap(Map<String, dynamic> map) {
    return OrderLine(
      id: map['id'] ?? '',
      quantity: map['quantity'] ?? 0,
      price: map['price']?.toDouble(),
    );
  }

  Map<String, dynamic> toMap() {
    return {
      'id': id,
      'quantity': quantity,
      if (price != null) 'price': price,
    };
  }

  OrderLine copyWith({
    String? id,
    int? quantity,
    double? price,
  }) {
    return OrderLine(
      id: id ?? this.id,
      quantity: quantity ?? this.quantity,
      price: price ?? this.price,
    );
  }
}

class OrderModel {
  final String id; // document id
  final String? cid; // customer id, nullable for import orders
  final List<OrderLine> orderlines;
  final OrderFulfillment fulfillment;
  final bool? paid; // nullable for import orders
  final DateTime? orderedAt;
  final int? ref;
  final String? did; // delivery id
  final AddressModel? address; // nullable for import orders
  final String? sourceId; // Added for import orders

  OrderModel({
    required this.id,
    this.cid,
    required this.orderlines,
    required this.fulfillment,
    this.paid,
    this.orderedAt,
    this.ref,
    this.did,
    this.address,
    this.sourceId,
  });

  factory OrderModel.fromFirestore(DocumentSnapshot doc) {
    final data = doc.data() as Map<String, dynamic>;
    return OrderModel(
      id: doc.id,
      cid: data['cid'],
      orderlines: (data['orderlines'] as List)
          .map((item) => OrderLine.fromMap(item))
          .toList(),
      fulfillment: OrderFulfillment.values.firstWhere(
        (e) => e.toString() == 'OrderFulfillment.${data['fulfillment']}',
        orElse: () => OrderFulfillment.pending,
      ),
      paid: data['paid'],
      orderedAt: data['orderedAt'] != null ? (data['orderedAt'] as Timestamp).toDate() : null,
      ref: data['ref'],
      did: data['did'],
      address: data['address'] != null ? AddressModel.fromMap(data['address'], '') : null,
      sourceId: data['sourceId'],
    );
  }

  Map<String, dynamic> toMap() {
    final map = {
      'orderlines': orderlines.map((line) => line.toMap()).toList(),
      'fulfillment': fulfillment.toString().split('.').last,
      'orderedAt': orderedAt != null ? Timestamp.fromDate(orderedAt!) : null,
      'ref': ref,
    };

    // Only include these fields for non-import orders
    if (fulfillment != OrderFulfillment.import) {
      map['cid'] = cid;
      map['paid'] = paid;
      map['did'] = did;
      map['address'] = address?.toMap();
    } else {
      map['sourceId'] = sourceId;
    }

    return map;
  }

  OrderModel copyWith({
    String? id,
    String? cid,
    List<OrderLine>? orderlines,
    OrderFulfillment? fulfillment,
    bool? paid,
    DateTime? orderedAt,
    int? ref,
    String? did,
    AddressModel? address,
    String? sourceId,
  }) {
    return OrderModel(
      id: id ?? this.id,
      cid: cid ?? this.cid,
      orderlines: orderlines ?? this.orderlines,
      fulfillment: fulfillment ?? this.fulfillment,
      paid: paid ?? this.paid,
      orderedAt: orderedAt ?? this.orderedAt,
      ref: ref ?? this.ref,
      did: did ?? this.did,
      address: address ?? this.address,
      sourceId: sourceId ?? this.sourceId,
    );
  }

  bool get isImport => fulfillment == OrderFulfillment.import;
} 