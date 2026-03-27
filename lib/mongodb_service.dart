import 'package:mongo_dart/mongo_dart.dart';
import 'package:flutter/foundation.dart';

class MongoService {
  // MongoDB Atlas or local URI - Using a placeholder local URI for now
  // For production, this should be moved to a secure configuration
  // Integrated MongoDB Atlas (Cloud) for universal wireless access.
  static const String _mongoUrl = "";
  static const String _collectionName = "product";

  static Db? _db;
  static DbCollection? _collection;

  static Future<void> connect() async {
    if (_db != null && _db!.isConnected) return;
    
    try {
      debugPrint("Attempting to connect to MongoDB at: $_mongoUrl");
      _db = await Db.create(_mongoUrl);
      
      // Add a timeout to prevent the app from hanging forever
      await _db!.open().timeout(
        const Duration(seconds: 10),
        onTimeout: () {
          throw Exception("Connection timed out after 10 seconds. Check if MongoDB is running and your connection settings.");
        },
      );
      
      _collection = _db!.collection(_collectionName);
      debugPrint("Connected to MongoDB successfully");
      
      // Create index for product name for faster searching
      await _collection!.createIndex(key: 'productName');
    } catch (e) {
      debugPrint("CRITICAL: MongoDB Connection Error!");
      debugPrint("URI tried: $_mongoUrl");
      debugPrint("Error details: $e");
      rethrow;
    }
  }

  static Future<void> saveStock(String name, double quantity, double price) async {
    await connect();
    try {
      // Use findAndModify (upsert) to update existing product or create new one
      await _collection!.update(
        where.eq('productName', name),
        {
          '\$set': {
            'productName': name,
            'price': price,
            'lastUpdated': DateTime.now().toIso8601String(),
          },
          '\$inc': {'quantity': quantity}
        },
        upsert: true,
      );
      debugPrint("Stock saved/updated: $name");
    } catch (e) {
      debugPrint("Error saving stock to MongoDB: $e");
      rethrow;
    }
  }

  static Future<List<Map<String, dynamic>>> searchProducts(String query) async {
    await connect();
    try {
      if (query.isEmpty) return [];
      
      // Case-insensitive search starting with query
      final results = await _collection!
          .find(where.match('productName', '^$query', caseInsensitive: true))
          .toList();
          
      return results;
    } catch (e) {
      debugPrint("Error searching products in MongoDB: $e");
      return [];
    }
  }

  static Future<Map<String, dynamic>?> getProduct(String name) async {
    await connect();
    try {
      return await _collection!.findOne(where.eq('productName', name));
    } catch (e) {
      debugPrint("Error fetching product from MongoDB: $e");
      return null;
    }
  }
}
