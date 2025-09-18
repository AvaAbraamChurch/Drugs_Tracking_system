import 'package:supabase_flutter/supabase_flutter.dart';
import '../models/Drugs/drug_model.dart';

class DrugsRepository {
  final SupabaseClient _supabaseClient = Supabase.instance.client;
  static const String _tableName = 'drugs';

  // Get all drugs
  Future<List<DrugModel>> getAllDrugs() async {
    try {
      final response = await _supabaseClient
          .from(_tableName)
          .select()
          .order('name', ascending: true);

      return (response as List)
          .map((drug) => DrugModel.fromJson(drug))
          .toList();
    } catch (e) {
      throw Exception('Failed to fetch drugs: $e');
    }
  }

  // Get drug by ID
  Future<DrugModel?> getDrugById(String id) async {
    try {
      final response = await _supabaseClient
          .from(_tableName)
          .select()
          .eq('id', id)
          .single();

      return DrugModel.fromJson(response);
    } catch (e) {
      throw Exception('Failed to fetch drug: $e');
    }
  }

  // Add new drug
  Future<DrugModel> addDrug(DrugModel drug) async {
    try {
      // Create a map without the id field for insertion
      final drugData = drug.toJson();
      drugData.remove('id'); // Remove the id field to let database auto-generate it

      final response = await _supabaseClient
          .from(_tableName)
          .insert(drugData)
          .select()
          .single();

      return DrugModel.fromJson(response);
    } catch (e) {
      throw Exception('Failed to add drug: $e');
    }
  }

  // Update existing drug
  Future<DrugModel> updateDrug(DrugModel drug) async {
    try {
      final response = await _supabaseClient
          .from(_tableName)
          .update(drug.toJson())
          .eq('id', drug.id!)
          .select()
          .single();

      return DrugModel.fromJson(response);
    } catch (e) {
      throw Exception('Failed to update drug: $e');
    }
  }

  // Delete drug
  Future<void> deleteDrug(String id) async {
    try {
      await _supabaseClient
          .from(_tableName)
          .delete()
          .eq('id', id);
    } catch (e) {
      throw Exception('Failed to delete drug: $e');
    }
  }

  // Search drugs by name
  Future<List<DrugModel>> searchDrugsByName(String query) async {
    try {
      final response = await _supabaseClient
          .from(_tableName)
          .select()
          .ilike('name', '%$query%')
          .order('name', ascending: true);

      return (response as List)
          .map((drug) => DrugModel.fromJson(drug))
          .toList();
    } catch (e) {
      throw Exception('Failed to search drugs: $e');
    }
  }

  // Get drugs with low stock (below specified threshold)
  Future<List<DrugModel>> getLowStockDrugs(int threshold) async {
    try {
      final response = await _supabaseClient
          .from(_tableName)
          .select()
          .lt('stock', threshold)
          .order('stock', ascending: true);

      return (response as List)
          .map((drug) => DrugModel.fromJson(drug))
          .toList();
    } catch (e) {
      throw Exception('Failed to fetch low stock drugs: $e');
    }
  }

  // Get expired drugs (past expiry date)
  Future<List<DrugModel>> getExpiredDrugs() async {
    try {
      final today = DateTime.now().toIso8601String().split('T')[0];
      final response = await _supabaseClient
          .from(_tableName)
          .select()
          .lt('expiry_date', today)
          .order('expiry_date', ascending: true);

      return (response as List)
          .map((drug) => DrugModel.fromJson(drug))
          .toList();
    } catch (e) {
      throw Exception('Failed to fetch expired drugs: $e');
    }
  }

  // Get drugs expiring soon (within specified days)
  Future<List<DrugModel>> getDrugsExpiringSoon(int daysAhead) async {
    try {
      final today = DateTime.now();
      final futureDate = today.add(Duration(days: daysAhead));
      final todayStr = today.toIso8601String().split('T')[0];
      final futureDateStr = futureDate.toIso8601String().split('T')[0];

      final response = await _supabaseClient
          .from(_tableName)
          .select()
          .gte('expiry_date', todayStr)
          .lte('expiry_date', futureDateStr)
          .order('expiry_date', ascending: true);

      return (response as List)
          .map((drug) => DrugModel.fromJson(drug))
          .toList();
    } catch (e) {
      throw Exception('Failed to fetch drugs expiring soon: $e');
    }
  }

  // Update drug stock
  Future<DrugModel> updateDrugStock(String id, int newStock) async {
    try {
      final response = await _supabaseClient
          .from(_tableName)
          .update({'stock': newStock})
          .eq('id', id)
          .select()
          .single();

      return DrugModel.fromJson(response);
    } catch (e) {
      throw Exception('Failed to update drug stock: $e');
    }
  }

  // Get total number of drugs
  Future<int> getTotalDrugsCount() async {
    try {
      final response = await _supabaseClient
          .from(_tableName)
          .select('id');

      return (response as List).length;
    } catch (e) {
      throw Exception('Failed to get drugs count: $e');
    }
  }

  // Check if drug exists by name
  Future<bool> drugExistsByName(String name) async {
    try {
      final response = await _supabaseClient
          .from(_tableName)
          .select('id')
          .ilike('name', name)
          .limit(1);

      return (response as List).isNotEmpty;
    } catch (e) {
      throw Exception('Failed to check if drug exists: $e');
    }
  }

  // Get drugs sorted by expiry date
  Future<List<DrugModel>> getDrugsSortedByExpiry() async {
    try {
      final response = await _supabaseClient
          .from(_tableName)
          .select()
          .order('expiry_date', ascending: true);

      return (response as List)
          .map((drug) => DrugModel.fromJson(drug))
          .toList();
    } catch (e) {
      throw Exception('Failed to fetch drugs sorted by expiry: $e');
    }
  }
}
