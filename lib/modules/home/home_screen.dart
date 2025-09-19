import 'package:conditional_builder_null_safety/conditional_builder_null_safety.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:pharmanow/core/Blocs/home%20cubit/home_states.dart';
import 'package:pharmanow/core/styles/colors.dart';
import 'package:pharmanow/modules/home/search_screen.dart';
import 'package:pharmanow/shared/widgets.dart';

import '../../core/Blocs/home cubit/home_cubit.dart';
import 'edit_drug_screen.dart';
import 'endrawer.dart';
import 'insert_drug_screen.dart';

class HomeScreen extends StatelessWidget {
  const HomeScreen({super.key});

  Color _getStockColor(int stock) {
    if (stock <= 5) return Colors.red;
    if (stock <= 20) return Colors.orange;
    return Colors.green;
  }

  void _showDrugDetails(BuildContext context, drug) {
    // Add haptic feedback for better user experience
    HapticFeedback.lightImpact();

    final cubit = HomeCubit.get(context); // Get cubit reference early
    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      isDismissible: true,
      enableDrag: true,
      // Optimize modal performance
      useSafeArea: true,
      showDragHandle: true,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
      ),
      builder: (context) => Container(
        padding: const EdgeInsets.all(20),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                Hero(
                  tag: 'drug_icon_${drug.id}',
                  child: Container(
                    width: 60,
                    height: 60,
                    decoration: BoxDecoration(
                      color: Colors.blue.shade100,
                      borderRadius: BorderRadius.circular(15),
                    ),
                    child: const Icon(
                      Icons.medication,
                      color: Colors.blue,
                      size: 30,
                    ),
                  ),
                ),
                const SizedBox(width: 16),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        drug.name,
                        style: const TextStyle(
                          fontSize: 20,
                          fontWeight: FontWeight.bold,
                        ),
                      ),
                    ],
                  ),
                ),
              ],
            ),
            const SizedBox(height: 20),
            _buildDetailRow('Stock Quantity', '${drug.stock}', _getStockColor(drug.stock)),
            const SizedBox(height: 12),
            _buildDetailRow('Expiry Date', drug.expiryDate, Colors.grey.shade700),
            const SizedBox(height: 20),
            SizedBox(
              width: double.infinity,
              child: ElevatedButton(
                onPressed: () async {
                  Navigator.pop(context); // Close the details modal first

                  final result = await showModalBottomSheet<bool>(
                    context: context,
                    isScrollControlled: true,
                    backgroundColor: Colors.transparent,
                    useSafeArea: true,
                    builder: (context) => EditDrugScreen(cubit: cubit, drugToEdit: drug),
                  );

                  // Refresh the drug list if a drug was updated successfully
                  if (result == true) {
                    cubit.getDrugs(); // Use the saved cubit reference
                  }
                },
                style: ElevatedButton.styleFrom(
                  backgroundColor: Colors.green,
                  padding: const EdgeInsets.symmetric(vertical: 12),
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(10),
                  ),
                ),
                child: const Text(
                  'Edit Drug',
                  style: TextStyle(
                    color: Colors.white,
                    fontSize: 16,
                    fontWeight: FontWeight.w600,
                  ),
                ),
              ),
            ),
            const SizedBox(height: 10.0),
            SizedBox(
              width: double.infinity,
              child: ElevatedButton(
                onPressed: () => Navigator.pop(context),
                style: ElevatedButton.styleFrom(
                  backgroundColor: Colors.blue,
                  padding: const EdgeInsets.symmetric(vertical: 12),
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(10),
                  ),
                ),
                child: const Text(
                  'Close',
                  style: TextStyle(
                    color: Colors.white,
                    fontSize: 16,
                    fontWeight: FontWeight.w600,
                  ),
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildDetailRow(String label, String value, Color valueColor) {
    return Row(
      mainAxisAlignment: MainAxisAlignment.spaceBetween,
      children: [
        Text(
          label,
          style: const TextStyle(
            fontSize: 16,
            fontWeight: FontWeight.w500,
          ),
        ),
        Text(
          value,
          style: TextStyle(
            fontSize: 16,
            fontWeight: FontWeight.w600,
            color: valueColor,
          ),
        ),
      ],
    );
  }

  @override
  Widget build(BuildContext context) {
    return BlocConsumer<HomeCubit, HomeStates>(
      builder: (BuildContext context, state) {
        final cubit = HomeCubit.get(context);

        return Scaffold(
          // Optimize keyboard handling
          resizeToAvoidBottomInset: true,
          appBar: AppBar(
            title: const Text('PHARMA NOW'),
            centerTitle: true,
            actions: [
              Builder(
                builder: (context) => IconButton(
                  icon: const Icon(Icons.menu),
                  tooltip: 'Menu',
                  onPressed: () {
                    HapticFeedback.lightImpact();
                    Scaffold.of(context).openEndDrawer();
                  },
                ),
              ),
              IconButton(
                icon: const Icon(Icons.search),
                onPressed: () {
                  HapticFeedback.lightImpact();
                  navigateTo(context, SearchScreen());
                },
              ),
            ],
            elevation: 0,
          ),
          endDrawer: const EndDrawer(),
          floatingActionButton: FloatingActionButton(
              tooltip: 'Add Drug',
              backgroundColor: primaryColor,
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(15),
              ),
              onPressed: () async {
                HapticFeedback.mediumImpact();
                final result = await showModalBottomSheet<bool>(
                  context: context,
                  isScrollControlled: true,
                  backgroundColor: Colors.transparent,
                  useSafeArea: true,
                  isDismissible: true,
                  enableDrag: true,
                  builder: (context) => InsertDrugScreen(cubit: cubit),
                );

                // Refresh the drug list if a drug was added successfully
                if (result == true) {
                  cubit.getDrugs();
                }
              },
              child: const Icon(Icons.add, size: 30, color: Colors.white,)
          ),
          body: ConditionalBuilder(
              condition: cubit.drugs.isNotEmpty || state is! GetDrugsLoadingState,
              builder: (BuildContext context) => RefreshIndicator(
                onRefresh: () async {
                  HapticFeedback.lightImpact();
                  cubit.getDrugs();
                  // Wait for the operation to complete
                  await Future.delayed(const Duration(milliseconds: 500));
                },
                color: Colors.blue,
                backgroundColor: Colors.white,
                child: ListView.builder(
                  physics: const AlwaysScrollableScrollPhysics(),
                  padding: const EdgeInsets.all(16),
                  itemCount: cubit.drugs.length,
                  // Add performance optimizations
                  cacheExtent: 500,
                  addAutomaticKeepAlives: false,
                  addRepaintBoundaries: false,
                  itemBuilder: (BuildContext context, int index) {
                    final drug = cubit.drugs[index];
                    return RepaintBoundary(
                      child: Card(
                        margin: const EdgeInsets.only(bottom: 12),
                        elevation: 2,
                        child: ListTile(
                          leading: Hero(
                            tag: 'drug_icon_${drug.id}',
                            child: Container(
                              width: 50,
                              height: 50,
                              decoration: BoxDecoration(
                                color: _getStockColor(drug.stock).withAlpha(30),
                                borderRadius: BorderRadius.circular(10),
                              ),
                              child: Icon(
                                Icons.medication,
                                color: _getStockColor(drug.stock),
                                size: 24,
                              ),
                            ),
                          ),
                          title: Text(
                            drug.name,
                            style: const TextStyle(
                              fontWeight: FontWeight.w600,
                              fontSize: 16,
                            ),
                            maxLines: 1,
                            overflow: TextOverflow.ellipsis,
                          ),
                          subtitle: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              const SizedBox(height: 4),
                              Row(
                                children: [
                                  Icon(
                                    Icons.inventory,
                                    size: 16,
                                    color: Colors.grey.shade600,
                                  ),
                                  const SizedBox(width: 4),
                                  Text(
                                    'Stock: ${drug.stock}',
                                    style: TextStyle(
                                      color: _getStockColor(drug.stock),
                                      fontWeight: FontWeight.w500,
                                    ),
                                  ),
                                ],
                              ),
                              const SizedBox(height: 2),
                              Row(
                                children: [
                                  Icon(
                                    Icons.calendar_today,
                                    size: 16,
                                    color: Colors.grey.shade600,
                                  ),
                                  const SizedBox(width: 4),
                                  Expanded(
                                    child: Text(
                                      'Expires: ${drug.expiryDate}',
                                      style: TextStyle(
                                        color: Colors.grey.shade600,
                                      ),
                                      maxLines: 1,
                                      overflow: TextOverflow.ellipsis,
                                    ),
                                  ),
                                ],
                              ),
                            ],
                          ),
                          trailing: Icon(
                            Icons.arrow_forward_ios,
                            size: 16,
                            color: Colors.grey.shade400,
                          ),
                          onTap: () {
                            _showDrugDetails(context, drug);
                          },
                        ),
                      ),
                    );
                  },
                ),
              ),
            fallback: (BuildContext context) => const Center(
              child: Column(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  CircularProgressIndicator(
                    color: Colors.blue,
                    strokeWidth: 3,
                  ),
                  SizedBox(height: 20),
                  Text(
                    'Loading drugs...',
                    style: TextStyle(
                      fontSize: 16,
                      color: Colors.grey,
                      fontWeight: FontWeight.w500,
                    ),
                  ),
                ],
              ),
            )
          ),
        );

      },
      listener: (BuildContext context, state) {  },
    );
  }
}
