import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:pharmanow/core/Blocs/home%20cubit/home_cubit.dart';
import 'package:pharmanow/core/Blocs/home%20cubit/home_states.dart';
import 'package:pharmanow/core/models/Drugs/drug_model.dart';

class NotificationCenterScreen extends StatefulWidget {
  final String? notificationType; // 'expiry' or 'stock'
  final List<DrugModel>? filteredDrugs; // Optional pre-filtered drugs

  const NotificationCenterScreen({
    Key? key,
    this.notificationType,
    this.filteredDrugs,
  }) : super(key: key);

  @override
  State<NotificationCenterScreen> createState() => _NotificationCenterScreenState();
}

class _NotificationCenterScreenState extends State<NotificationCenterScreen> {
  String selectedTab = 'all';

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Notification Center'),
        backgroundColor: Theme.of(context).primaryColor,
        foregroundColor: Colors.white,
        elevation: 0,
      ),
      body: Column(
        children: [
          _buildTabSelector(),
          Expanded(
            child: BlocConsumer<HomeCubit, HomeStates>(
              listener: (context, state) {
                // Handle any error states if needed
              },
              builder: (context, state) {
                if (state is GetDrugsLoadingState) {
                  return const Center(child: CircularProgressIndicator());
                }

                final drugs = widget.filteredDrugs ??
                    (state is GetDrugsSuccessState ? state.drugs : <DrugModel>[]);

                return _buildNotificationList(drugs);
              },
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildTabSelector() {
    return Container(
      padding: const EdgeInsets.all(16.0),
      child: Row(
        children: [
          _buildTabButton('All', 'all'),
          const SizedBox(width: 12),
          _buildTabButton('Low Stock', 'stock'),
          const SizedBox(width: 12),
          _buildTabButton('Expiring', 'expiry'),
        ],
      ),
    );
  }

  Widget _buildTabButton(String title, String type) {
    final isSelected = selectedTab == type;
    return Expanded(
      child: GestureDetector(
        onTap: () {
          setState(() {
            selectedTab = type;
          });
        },
        child: Container(
          padding: const EdgeInsets.symmetric(vertical: 12, horizontal: 16),
          decoration: BoxDecoration(
            color: isSelected ? Theme.of(context).primaryColor : Colors.grey[200],
            borderRadius: BorderRadius.circular(25),
          ),
          child: Text(
            title,
            textAlign: TextAlign.center,
            style: TextStyle(
              color: isSelected ? Colors.white : Colors.grey[600],
              fontWeight: FontWeight.bold,
            ),
          ),
        ),
      ),
    );
  }

  Widget _buildNotificationList(List<DrugModel> drugs) {
    List<DrugModel> filteredDrugs = _filterDrugs(drugs);

    if (filteredDrugs.isEmpty) {
      return _buildEmptyState();
    }

    return RefreshIndicator(
      onRefresh: () async {
        context.read<HomeCubit>().getDrugs();
      },
      child: ListView.builder(
        padding: const EdgeInsets.all(16),
        itemCount: filteredDrugs.length,
        itemBuilder: (context, index) {
          final drug = filteredDrugs[index];
          return _buildNotificationCard(drug);
        },
      ),
    );
  }

  List<DrugModel> _filterDrugs(List<DrugModel> drugs) {
    final now = DateTime.now();
    final oneMonthFromNow = now.add(const Duration(days: 30));

    switch (selectedTab) {
      case 'stock':
        return drugs.where((drug) => drug.stock <= 5).toList();
      case 'expiry':
        return drugs.where((drug) {
          final expiryDate = DateTime.tryParse(drug.expiryDate);
          return expiryDate != null &&
                 expiryDate.isAfter(now) &&
                 expiryDate.isBefore(oneMonthFromNow);
        }).toList();
      default:
        return drugs.where((drug) {
          final expiryDate = DateTime.tryParse(drug.expiryDate);
          final isExpiring = expiryDate != null &&
                           expiryDate.isAfter(now) &&
                           expiryDate.isBefore(oneMonthFromNow);
          final isLowStock = drug.stock <= 5;
          return isExpiring || isLowStock;
        }).toList();
    }
  }

  Widget _buildNotificationCard(DrugModel drug) {
    final now = DateTime.now();
    final expiryDate = DateTime.tryParse(drug.expiryDate);
    final isExpiring = expiryDate != null &&
                      expiryDate.isAfter(now) &&
                      expiryDate.isBefore(now.add(const Duration(days: 30)));
    final isLowStock = drug.stock <= 5;
    final isCriticalStock = drug.stock == 0;

    return Card(
      margin: const EdgeInsets.only(bottom: 12),
      elevation: 2,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        drug.name,
                        style: const TextStyle(
                          fontSize: 18,
                          fontWeight: FontWeight.bold,
                        ),
                      ),
                      const SizedBox(height: 8),
                      _buildStatusRow(drug, isExpiring, isLowStock, isCriticalStock),
                    ],
                  ),
                ),
                if (drug.imageUrl.isNotEmpty)
                  ClipRRect(
                    borderRadius: BorderRadius.circular(8),
                    child: Image.network(
                      drug.imageUrl,
                      width: 60,
                      height: 60,
                      fit: BoxFit.cover,
                      errorBuilder: (context, error, stackTrace) =>
                          const Icon(Icons.medication, size: 60),
                    ),
                  ),
              ],
            ),
            const SizedBox(height: 12),
            _buildActionButtons(drug, isCriticalStock),
          ],
        ),
      ),
    );
  }

  Widget _buildStatusRow(DrugModel drug, bool isExpiring, bool isLowStock, bool isCriticalStock) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(
          children: [
            Icon(Icons.inventory, size: 16, color: Colors.grey[600]),
            const SizedBox(width: 4),
            Text(
              'Stock: ${drug.stock} units',
              style: TextStyle(
                color: isCriticalStock ? Colors.red : isLowStock ? Colors.orange : Colors.grey[600],
                fontWeight: isCriticalStock || isLowStock ? FontWeight.bold : FontWeight.normal,
              ),
            ),
          ],
        ),
        const SizedBox(height: 4),
        Row(
          children: [
            Icon(Icons.calendar_today, size: 16, color: Colors.grey[600]),
            const SizedBox(width: 4),
            Text(
              'Expires: ${drug.expiryDate}',
              style: TextStyle(
                color: isExpiring ? Colors.orange : Colors.grey[600],
                fontWeight: isExpiring ? FontWeight.bold : FontWeight.normal,
              ),
            ),
          ],
        ),
        const SizedBox(height: 8),
        _buildAlertChips(isExpiring, isLowStock, isCriticalStock),
      ],
    );
  }

  Widget _buildAlertChips(bool isExpiring, bool isLowStock, bool isCriticalStock) {
    return Wrap(
      spacing: 8,
      children: [
        if (isCriticalStock)
          Chip(
            label: const Text('OUT OF STOCK', style: TextStyle(fontSize: 12)),
            backgroundColor: Colors.red,
            labelStyle: const TextStyle(color: Colors.white, fontWeight: FontWeight.bold),
          ),
        if (isLowStock && !isCriticalStock)
          Chip(
            label: const Text('LOW STOCK', style: TextStyle(fontSize: 12)),
            backgroundColor: Colors.orange,
            labelStyle: const TextStyle(color: Colors.white, fontWeight: FontWeight.bold),
          ),
        if (isExpiring)
          Chip(
            label: const Text('EXPIRING SOON', style: TextStyle(fontSize: 12)),
            backgroundColor: Colors.amber,
            labelStyle: const TextStyle(color: Colors.white, fontWeight: FontWeight.bold),
          ),
      ],
    );
  }

  Widget _buildActionButtons(DrugModel drug, bool isCriticalStock) {
    return Row(
      mainAxisAlignment: MainAxisAlignment.end,
      children: [
        if (isCriticalStock)
          ElevatedButton.icon(
            onPressed: () => _showRestockDialog(drug),
            icon: const Icon(Icons.add_shopping_cart, size: 18),
            label: const Text('Restock'),
            style: ElevatedButton.styleFrom(
              backgroundColor: Colors.red,
              foregroundColor: Colors.white,
            ),
          )
        else
          TextButton.icon(
            onPressed: () => _showRestockDialog(drug),
            icon: const Icon(Icons.edit, size: 18),
            label: const Text('Update Stock'),
          ),
      ],
    );
  }

  Widget _buildEmptyState() {
    String message;
    IconData icon;

    switch (selectedTab) {
      case 'stock':
        message = 'No low stock items';
        icon = Icons.inventory_2;
        break;
      case 'expiry':
        message = 'No drugs expiring soon';
        icon = Icons.calendar_today;
        break;
      default:
        message = 'No notifications at this time';
        icon = Icons.notifications_none;
        break;
    }

    return Center(
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Icon(icon, size: 64, color: Colors.grey[400]),
          const SizedBox(height: 16),
          Text(
            message,
            style: TextStyle(
              fontSize: 18,
              color: Colors.grey[600],
              fontWeight: FontWeight.w500,
            ),
          ),
          const SizedBox(height: 8),
          Text(
            'Pull to refresh',
            style: TextStyle(
              fontSize: 14,
              color: Colors.grey[500],
            ),
          ),
        ],
      ),
    );
  }

  void _showRestockDialog(DrugModel drug) {
    final TextEditingController stockController = TextEditingController();
    
    showDialog(
      context: context,
      builder: (BuildContext context) {
        return AlertDialog(
          title: Text('Update Stock - ${drug.name}'),
          content: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Text('Current stock: ${drug.stock} units'),
              const SizedBox(height: 16),
              TextField(
                controller: stockController,
                keyboardType: TextInputType.number,
                decoration: const InputDecoration(
                  labelText: 'New Stock Quantity',
                  border: OutlineInputBorder(),
                  hintText: 'Enter new stock amount',
                ),
              ),
            ],
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.of(context).pop(),
              child: const Text('Cancel'),
            ),
            ElevatedButton(
              onPressed: () {
                final newStock = int.tryParse(stockController.text);
                if (newStock != null && newStock >= 0) {
                  _updateDrugStock(drug, newStock);
                  Navigator.of(context).pop();
                }
              },
              child: const Text('Update'),
            ),
          ],
        );
      },
    );
  }

  void _updateDrugStock(DrugModel drug, int newStock) {
    final updatedDrug = drug.copyWith(stock: newStock);
    context.read<HomeCubit>().updateDrug(updatedDrug);
    
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text('${drug.name} stock updated to $newStock units'),
        backgroundColor: Colors.green,
      ),
    );
  }
}
