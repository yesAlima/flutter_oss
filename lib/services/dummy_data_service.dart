import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import '../models/user_model.dart';
import '../models/category_model.dart';
import '../models/order_model.dart';

class DummyDataService {
  final FirebaseFirestore _firestore = FirebaseFirestore.instance;
  final FirebaseAuth _auth = FirebaseAuth.instance;

  Future<void> populateDatabase() async {
    try {
      // Clear all existing data
      await clearAllData();
      
      // Create test users
      await _createTestUsers();
      
      // Create test categories
      final categories = await _createTestCategories();
      
      // Create test products
      await _createTestProducts(categories);
      
      // Create test sources
      await _createTestSources();
      
      // Create test orders and ensure draft orders exist
      await _createTestOrders();
      
      print('Database populated successfully!');
    } catch (e) {
      print('Error populating database: $e');
      rethrow;
    }
  }

  Future<void> clearAllData() async {
    try {
      // Clear Firestore collections
      await _clearFirestoreCollection('users');
      await _clearFirestoreCollection('categories');
      await _clearFirestoreCollection('products');
      await _clearFirestoreCollection('orders');
      await _clearFirestoreCollection('sources');

      // Clear Firebase Auth users
      await _clearFirebaseAuthUsers();
      
      print('All existing data cleared successfully');
    } catch (e) {
      print('Error clearing data: $e');
      rethrow;
    }
  }

  Future<void> _clearFirestoreCollection(String collection) async {
    final snapshot = await _firestore.collection(collection).get();
    final batch = _firestore.batch();
    
    for (var doc in snapshot.docs) {
      batch.delete(doc.reference);
    }
    
    await batch.commit();
  }

  Future<void> _clearFirebaseAuthUsers() async {
    try {
      // Note: Firebase Auth users can only be deleted by the user themselves
      // or through the Admin SDK. We'll just log this limitation.
      print('Note: Firebase Auth users must be deleted manually through the Firebase Console');
    } catch (e) {
      print('Error clearing Firebase Auth users: $e');
    }
  }

  Future<void> _createTestUsers() async {
    final users = [
      {
        'email': 'admin@test.com',
        'password': 'Admin123!',
        'name': 'Admin',
        'role': UserRole.admin,
        'phone': '31234567',
        'addresses': [],
      },
      // Supplier users
      {
        'email': 'supp1@test.com',
        'password': 'Supplier123!',
        'name': 'Supplier 1',
        'role': UserRole.supplier,
        'phone': '31234568',
        'addresses': [],
      },
      {
        'email': 'supp2@test.com',
        'password': 'Supplier123!',
        'name': 'Supplier 2',
        'role': UserRole.supplier,
        'phone': '31234569',
        'addresses': [],
      },
      {
        'email': 'supp3@test.com',
        'password': 'Supplier123!',
        'name': 'Supplier 3',
        'role': UserRole.supplier,
        'phone': '31234570',
        'addresses': [],
      },
      {
        'email': 'supp4@test.com',
        'password': 'Supplier123!',
        'name': 'Supplier 4',
        'role': UserRole.supplier,
        'phone': '31234571',
        'addresses': [],
      },
      // Delivery users
      {
        'email': 'deliv1@test.com',
        'password': 'Delivery123!',
        'name': 'Delivery 1',
        'role': UserRole.delivery,
        'phone': '61234567',
        'addresses': [],
      },
      {
        'email': 'deliv2@test.com',
        'password': 'Delivery123!',
        'name': 'Delivery 2',
        'role': UserRole.delivery,
        'phone': '61234568',
        'addresses': [],
      },
      {
        'email': 'deliv3@test.com',
        'password': 'Delivery123!',
        'name': 'Delivery 3',
        'role': UserRole.delivery,
        'phone': '61234569',
        'addresses': [],
      },
      {
        'email': 'deliv4@test.com',
        'password': 'Delivery123!',
        'name': 'Delivery 4',
        'role': UserRole.delivery,
        'phone': '61234570',
        'addresses': [],
      },
      // Customer users
      {
        'email': 'cust1@test.com',
        'password': 'Customer123!',
        'name': 'Customer 1',
        'role': UserRole.customer,
        'phone': '31234572',
        'addresses': [
          {
            'block': '132',
            'road': '465',
            'building': '798',
          },
          {
            'block': '133',
            'road': '466',
            'building': '799',
          },
          {
            'block': '134',
            'road': '467',
            'building': '800',
          },
        ],
      },
      {
        'email': 'cust2@test.com',
        'password': 'Customer123!',
        'name': 'Customer 2',
        'role': UserRole.customer,
        'phone': '31234573',
        'addresses': [
          {
            'block': '133',
            'road': '466',
            'building': '799',
          },
          {
            'block': '135',
            'road': '468',
            'building': '801',
          },
        ],
      },
      {
        'email': 'cust3@test.com',
        'password': 'Customer123!',
        'name': 'Customer 3',
        'role': UserRole.customer,
        'phone': '31234574',
        'addresses': [
          {
            'block': '134',
            'road': '467',
            'building': '800',
          },
          {
            'block': '136',
            'road': '469',
            'building': '802',
          },
          {
            'block': '137',
            'road': '470',
            'building': '803',
          },
        ],
      },
      {
        'email': 'cust4@test.com',
        'password': 'Customer123!',
        'name': 'Customer 4',
        'role': UserRole.customer,
        'phone': '31234575',
        'addresses': [
          {
            'block': '135',
            'road': '468',
            'building': '801',
          },
          {
            'block': '138',
            'road': '471',
            'building': '804',
          },
        ],
      },
      {
        'email': 'cust5@test.com',
        'password': 'Customer123!',
        'name': 'Customer 5',
        'role': UserRole.customer,
        'phone': '31234576',
        'addresses': [
          {
            'block': '136',
            'road': '469',
            'building': '802',
          },
          {
            'block': '139',
            'road': '472',
            'building': '805',
          },
          {
            'block': '140',
            'road': '473',
            'building': '806',
          },
        ],
      },
    ];

    for (var userData in users) {
      try {
        final userCredential = await _auth.createUserWithEmailAndPassword(
          email: userData['email'] as String,
          password: userData['password'] as String,
        );

        final addresses = (userData['addresses'] as List)
            .asMap()
            .entries
            .map((e) => AddressModel(
                  id: e.key.toString(),
                  block: e.value['block'] as String,
                  road: e.value['road'] as String?,
                  building: e.value['building'] as String,
                ))
            .toList();

        final user = UserModel(
          id: userCredential.user!.uid,
          email: userData['email'] as String,
          name: userData['name'] as String,
          role: (userData['role'] as UserRole).toString().split('.').last,
          phone: userData['phone'] as String,
          isActive: true,
          addresses: addresses,
        );

        await _firestore.collection('users').doc(user.id).set(user.toMap());
      } catch (e) {
        print('Error creating user ${userData['email']}: $e');
      }
    }
  }

  Future<List<CategoryModel>> _createTestCategories() async {
    // Clear existing categories
    final existingCategories = await _firestore.collection('categories').get();
    for (var doc in existingCategories.docs) {
      await doc.reference.delete();
    }

    final categories = [
      {
        'name': 'Electronics',
        'description': 'Smartphones, laptops, and accessories',
      },
      {
        'name': 'Clothing',
        'description': 'Men\'s and women\'s fashion',
      },
      {
        'name': 'Home & Kitchen',
        'description': 'Appliances and kitchen essentials',
      },
      {
        'name': 'Sports & Outdoors',
        'description': 'Fitness equipment and outdoor gear',
      },
    ];

    final List<CategoryModel> createdCategories = [];
    
    for (var categoryData in categories) {
      final docRef = await _firestore.collection('categories').add({
        'name': categoryData['name'],
        'description': categoryData['description'],
      });

      final category = CategoryModel(
        id: docRef.id,
        name: categoryData['name'] as String,
        description: categoryData['description'] as String,
      );

      createdCategories.add(category);
    }

    return createdCategories;
  }

  Future<void> _createTestProducts(List<CategoryModel> categories) async {
    // Clear existing products
    final existingProducts = await _firestore.collection('products').get();
    for (var doc in existingProducts.docs) {
      await doc.reference.delete();
    }

    final products = [
      // Electronics Category
      {
        'name': 'iPhone 15 Pro',
        'description': 'Latest Apple smartphone with A17 Pro chip',
        'price': 999.500,
        'stock': 50,
        'alert': 10,
        'categoryId': categories[0].id,
      },
      {
        'name': 'MacBook Pro M3',
        'description': 'Professional laptop with M3 chip',
        'price': 1999.000,
        'stock': 30,
        'alert': 5,
        'categoryId': categories[0].id,
      },
      {
        'name': 'Samsung Galaxy S24',
        'description': 'Android flagship with AI features',
        'price': 899.950,
        'stock': 45,
        'alert': 8,
        'categoryId': categories[0].id,
      },
      {
        'name': 'Sony WH-1000XM5',
        'description': 'Premium noise-cancelling headphones',
        'price': 399.500,
        'stock': 25,
        'alert': 5,
        'categoryId': categories[0].id,
      },
      {
        'name': 'iPad Pro 12.9"',
        'description': 'Professional tablet with M2 chip',
        'price': 1099.000,
        'stock': 20,
        'alert': 4,
        'categoryId': categories[0].id,
      },

      // Clothing Category
      {
        'name': 'Men\'s Casual Jacket',
        'description': 'Water-resistant jacket for all seasons',
        'price': 89.950,
        'stock': 100,
        'alert': 20,
        'categoryId': categories[1].id,
      },
      {
        'name': 'Women\'s Running Shoes',
        'description': 'Lightweight running shoes with cushioning',
        'price': 129.500,
        'stock': 75,
        'alert': 15,
        'categoryId': categories[1].id,
      },
      {
        'name': 'Designer Handbag',
        'description': 'Premium leather handbag with multiple compartments',
        'price': 299.000,
        'stock': 30,
        'alert': 6,
        'categoryId': categories[1].id,
      },
      {
        'name': 'Men\'s Business Suit',
        'description': 'Classic fit wool blend suit',
        'price': 399.950,
        'stock': 40,
        'alert': 8,
        'categoryId': categories[1].id,
      },
      {
        'name': 'Women\'s Summer Dress',
        'description': 'Floral print cotton dress',
        'price': 79.500,
        'stock': 60,
        'alert': 12,
        'categoryId': categories[1].id,
      },

      // Home & Kitchen Category
      {
        'name': 'Smart Refrigerator',
        'description': 'WiFi-enabled refrigerator with touchscreen',
        'price': 1499.950,
        'stock': 15,
        'alert': 3,
        'categoryId': categories[2].id,
      },
      {
        'name': 'Professional Blender',
        'description': 'High-power blender for smoothies and food prep',
        'price': 199.000,
        'stock': 25,
        'alert': 5,
        'categoryId': categories[2].id,
      },
      {
        'name': 'Smart Coffee Maker',
        'description': 'Programmable coffee maker with app control',
        'price': 149.500,
        'stock': 35,
        'alert': 7,
        'categoryId': categories[2].id,
      },
      {
        'name': 'Kitchen Knife Set',
        'description': 'Professional 8-piece stainless steel knife set',
        'price': 129.950,
        'stock': 45,
        'alert': 9,
        'categoryId': categories[2].id,
      },
      {
        'name': 'Smart Air Purifier',
        'description': 'HEPA air purifier with air quality monitoring',
        'price': 249.500,
        'stock': 20,
        'alert': 4,
        'categoryId': categories[2].id,
      },

      // Sports & Outdoors Category
      {
        'name': 'Fitness Tracker',
        'description': 'Smart watch with health monitoring',
        'price': 149.950,
        'stock': 60,
        'alert': 10,
        'categoryId': categories[3].id,
      },
      {
        'name': 'Camping Tent',
        'description': '4-person waterproof tent',
        'price': 299.000,
        'stock': 20,
        'alert': 4,
        'categoryId': categories[3].id,
      },
      {
        'name': 'Mountain Bike',
        'description': '21-speed mountain bike with suspension',
        'price': 599.500,
        'stock': 15,
        'alert': 3,
        'categoryId': categories[3].id,
      },
      {
        'name': 'Yoga Mat Set',
        'description': 'Premium yoga mat with accessories',
        'price': 49.950,
        'stock': 80,
        'alert': 16,
        'categoryId': categories[3].id,
      },
      {
        'name': 'Dumbbell Set',
        'description': 'Adjustable weight dumbbell set',
        'price': 199.500,
        'stock': 30,
        'alert': 6,
        'categoryId': categories[3].id,
      },
    ];

    for (var productData in products) {
      await _firestore.collection('products').add({
        ...productData,
        'isActive': true,
      });
    }
  }

  Future<void> _createTestSources() async {
    // Clear existing sources
    final existingSources = await _firestore.collection('sources').get();
    for (var doc in existingSources.docs) {
      await doc.reference.delete();
    }

    final sources = [
      {
        'name': 'Local Supplier',
        'description': 'Primary local supplier for electronics and gadgets',
      },
      {
        'name': 'International Wholesaler',
        'description': 'Global supplier for bulk orders and special items',
      },
      {
        'name': 'Direct Manufacturer',
        'description': 'Direct partnership with product manufacturers',
      },
      {
        'name': 'Regional Distributor',
        'description': 'Regional supplier for home and kitchen items',
      },
      {
        'name': 'Specialty Vendor',
        'description': 'Specialized supplier for sports and outdoor equipment',
      },
    ];

    for (var sourceData in sources) {
      await _firestore.collection('sources').add(sourceData);
    }
  }

  Future<void> _createTestOrders() async {
    final customerDocs = await _firestore
        .collection('users')
        .where('role', isEqualTo: 'customer')
        .get();

    if (customerDocs.docs.isEmpty) return;

    final products = await _firestore.collection('products').get();
    if (products.docs.isEmpty) return;

    final deliveryDocs = await _firestore
        .collection('users')
        .where('role', isEqualTo: 'delivery')
        .get();

    if (deliveryDocs.docs.isEmpty) return;

    final sources = await _firestore.collection('sources').get();
    if (sources.docs.isEmpty) return;

    // First, ensure each customer has a draft order
    for (var customerDoc in customerDocs.docs) {
      final draftQuery = await _firestore
          .collection('orders')
          .where('cid', isEqualTo: customerDoc.id)
          .where('fulfillment', isEqualTo: OrderFulfillment.draft.toString().split('.').last)
          .get();

      if (draftQuery.docs.isEmpty) {
        // Get customer's addresses
        final customer = UserModel.fromFirestore(customerDoc);
        final address = customer.addresses.isNotEmpty ? customer.addresses.first.toMap() : null;

        await _firestore.collection('orders').add({
          'cid': customerDoc.id,
          'orderlines': [],
          'fulfillment': OrderFulfillment.draft.toString().split('.').last,
          'paid': false,
          if (address != null) 'address': address,
        });
      }
    }

    // Get count of non-draft orders for ref number
    final nonDraftOrders = await _firestore
        .collection('orders')
        .where('fulfillment', isNotEqualTo: OrderFulfillment.draft.toString().split('.').last)
        .get();
    int refCounter = nonDraftOrders.docs.length + 1;

    // Create regular orders with chronological ordering
    final orders = [
      // Oldest orders (30 days ago)
      {
        'cid': customerDocs.docs[0].id,
        'orderlines': [
          {
            'id': products.docs[0].id,
            'quantity': 1,
          },
          {
            'id': products.docs[2].id,
            'quantity': 2,
          },
        ],
        'fulfillment': OrderFulfillment.fulfilled.toString().split('.').last,
        'paid': true,
        'orderedAt': DateTime.now().subtract(const Duration(days: 30)),
        'ref': 1,
        'did': deliveryDocs.docs[0].id,
        'address': UserModel.fromFirestore(customerDocs.docs[0]).addresses.first.toMap(),
      },
      {
        'cid': customerDocs.docs[1].id,
        'orderlines': [
          {
            'id': products.docs[3].id,
            'quantity': 1,
          },
        ],
        'fulfillment': OrderFulfillment.fulfilled.toString().split('.').last,
        'paid': true,
        'orderedAt': DateTime.now().subtract(const Duration(days: 29)),
        'ref': 2,
        'did': deliveryDocs.docs[1].id,
        'address': UserModel.fromFirestore(customerDocs.docs[1]).addresses.first.toMap(),
      },
      // First import order (28 days ago)
      {
        'orderlines': [
          {
            'id': products.docs[0].id,
            'quantity': 10,
            'price': 899.500,
          },
        ],
        'fulfillment': OrderFulfillment.import.toString().split('.').last,
        'orderedAt': DateTime.now().subtract(const Duration(days: 28)),
        'ref': 3,
        'sourceId': sources.docs[0].id,
      },

      // Orders from 25-27 days ago
      {
        'cid': customerDocs.docs[2].id,
        'orderlines': [
          {
            'id': products.docs[5].id,
            'quantity': 2,
          },
          {
            'id': products.docs[6].id,
            'quantity': 1,
          },
        ],
        'fulfillment': OrderFulfillment.fulfilled.toString().split('.').last,
        'paid': true,
        'orderedAt': DateTime.now().subtract(const Duration(days: 25)),
        'ref': 4,
        'did': deliveryDocs.docs[2].id,
        'address': UserModel.fromFirestore(customerDocs.docs[2]).addresses.first.toMap(),
      },
      // Import order (25 days ago)
      {
        'orderlines': [
          {
            'id': products.docs[2].id,
            'quantity': 12,
            'price': 399.500,
          },
        ],
        'fulfillment': OrderFulfillment.import.toString().split('.').last,
        'orderedAt': DateTime.now().subtract(const Duration(days: 25)),
        'ref': 5,
        'sourceId': sources.docs[0].id,
      },
      {
        'cid': customerDocs.docs[3].id,
        'orderlines': [
          {
            'id': products.docs[7].id,
            'quantity': 1,
          },
        ],
        'fulfillment': OrderFulfillment.cancelled.toString().split('.').last,
        'paid': false,
        'orderedAt': DateTime.now().subtract(const Duration(days: 24)),
        'ref': 6,
        'address': UserModel.fromFirestore(customerDocs.docs[3]).addresses.first.toMap(),
      },

      // Orders from 15-20 days ago
      // Import order (20 days ago)
      {
        'orderlines': [
          {
            'id': products.docs[5].id,
            'quantity': 20,
            'price': 79.950,
          },
        ],
        'fulfillment': OrderFulfillment.import.toString().split('.').last,
        'orderedAt': DateTime.now().subtract(const Duration(days: 20)),
        'ref': 7,
        'sourceId': sources.docs[1].id,
      },
      {
        'cid': customerDocs.docs[0].id,
        'orderlines': [
          {
            'id': products.docs[10].id,
            'quantity': 1,
          },
        ],
        'fulfillment': OrderFulfillment.fulfilled.toString().split('.').last,
        'paid': true,
        'orderedAt': DateTime.now().subtract(const Duration(days: 15)),
        'ref': 8,
        'did': deliveryDocs.docs[3].id,
        'address': UserModel.fromFirestore(customerDocs.docs[0]).addresses[1].toMap(),
      },
      {
        'cid': customerDocs.docs[1].id,
        'orderlines': [
          {
            'id': products.docs[11].id,
            'quantity': 1,
          },
          {
            'id': products.docs[12].id,
            'quantity': 1,
          },
        ],
        'fulfillment': OrderFulfillment.unfulfilled.toString().split('.').last,
        'paid': true,
        'orderedAt': DateTime.now().subtract(const Duration(days: 14)),
        'ref': 9,
        'did': deliveryDocs.docs[0].id,
        'address': UserModel.fromFirestore(customerDocs.docs[1]).addresses[1].toMap(),
      },

      // Orders from 10-12 days ago
      // Import order (12 days ago)
      {
        'orderlines': [
          {
            'id': products.docs[10].id,
            'quantity': 5,
            'price': 1399.000,
          },
        ],
        'fulfillment': OrderFulfillment.import.toString().split('.').last,
        'orderedAt': DateTime.now().subtract(const Duration(days: 12)),
        'ref': 10,
        'sourceId': sources.docs[2].id,
      },
      // Import order (10 days ago)
      {
        'orderlines': [
          {
            'id': products.docs[12].id,
            'quantity': 8,
            'price': 149.950,
          },
        ],
        'fulfillment': OrderFulfillment.import.toString().split('.').last,
        'orderedAt': DateTime.now().subtract(const Duration(days: 10)),
        'ref': 11,
        'sourceId': sources.docs[2].id,
      },
      {
        'cid': customerDocs.docs[2].id,
        'orderlines': [
          {
            'id': products.docs[15].id,
            'quantity': 1,
          },
        ],
        'fulfillment': OrderFulfillment.pending.toString().split('.').last,
        'paid': true,
        'orderedAt': DateTime.now().subtract(const Duration(days: 7)),
        'ref': 12,
        'address': UserModel.fromFirestore(customerDocs.docs[2]).addresses[1].toMap(),
      },

      // Orders from 5-7 days ago
      {
        'cid': customerDocs.docs[3].id,
        'orderlines': [
          {
            'id': products.docs[16].id,
            'quantity': 2,
          },
          {
            'id': products.docs[17].id,
            'quantity': 1,
          },
        ],
        'fulfillment': OrderFulfillment.unfulfilled.toString().split('.').last,
        'paid': true,
        'orderedAt': DateTime.now().subtract(const Duration(days: 6)),
        'ref': 13,
        'did': deliveryDocs.docs[1].id,
        'address': UserModel.fromFirestore(customerDocs.docs[3]).addresses[1].toMap(),
      },

      // Orders from 1-5 days ago
      // Import order (5 days ago)
      {
        'orderlines': [
          {
            'id': products.docs[15].id,
            'quantity': 15,
            'price': 129.500,
          },
        ],
        'fulfillment': OrderFulfillment.import.toString().split('.').last,
        'orderedAt': DateTime.now().subtract(const Duration(days: 5)),
        'ref': 14,
        'sourceId': sources.docs[3].id,
      },
      // Import order (4 days ago)
      {
        'orderlines': [
          {
            'id': products.docs[17].id,
            'quantity': 18,
            'price': 599.500,
          },
        ],
        'fulfillment': OrderFulfillment.import.toString().split('.').last,
        'orderedAt': DateTime.now().subtract(const Duration(days: 4)),
        'ref': 15,
        'sourceId': sources.docs[3].id,
      },
      {
        'cid': customerDocs.docs[4].id,
        'orderlines': [
          {
            'id': products.docs[18].id,
            'quantity': 1,
          },
        ],
        'fulfillment': OrderFulfillment.pending.toString().split('.').last,
        'paid': true,
        'orderedAt': DateTime.now().subtract(const Duration(days: 3)),
        'ref': 16,
        'address': UserModel.fromFirestore(customerDocs.docs[4]).addresses.first.toMap(),
      },
      // Import order (2 days ago)
      {
        'orderlines': [
          {
            'id': products.docs[18].id,
            'quantity': 8,
            'price': 39.950,
          },
        ],
        'fulfillment': OrderFulfillment.import.toString().split('.').last,
        'orderedAt': DateTime.now().subtract(const Duration(days: 2)),
        'ref': 17,
        'sourceId': sources.docs[4].id,
      },
      {
        'cid': customerDocs.docs[0].id,
        'orderlines': [
          {
            'id': products.docs[19].id,
            'quantity': 1,
          },
        ],
        'fulfillment': OrderFulfillment.pending.toString().split('.').last,
        'paid': true,
        'orderedAt': DateTime.now().subtract(const Duration(days: 1)),
        'ref': 18,
        'address': UserModel.fromFirestore(customerDocs.docs[0]).addresses[2].toMap(),
      },
      // Import order (1 day ago)
      {
        'orderlines': [
          {
            'id': products.docs[19].id,
            'quantity': 30,
            'price': 199.500,
          },
        ],
        'fulfillment': OrderFulfillment.import.toString().split('.').last,
        'orderedAt': DateTime.now().subtract(const Duration(days: 1)),
        'ref': 19,
        'sourceId': sources.docs[4].id,
      },
    ];

    for (var orderData in orders) {
      await _firestore.collection('orders').add(orderData);
    }
  }
} 