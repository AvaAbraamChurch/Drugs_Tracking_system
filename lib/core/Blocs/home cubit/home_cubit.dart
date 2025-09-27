import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:pharmanow/core/models/Drugs/drug_model.dart';
import '../../repositories/drugs_repositories.dart';
import '../../utils/notifications_service.dart';
import 'home_states.dart';

class HomeCubit extends Cubit<HomeStates> {

  HomeCubit() : super(HomeInitialState());

  static HomeCubit get(context) => BlocProvider.of(context);

  List<DrugModel> drugs = [];

  void getDrugs() async {
    emit(GetDrugsLoadingState());
    try {
      final drugsList = await DrugsRepository().getAllDrugs();
      drugs = drugsList;

      // Convert DrugModel objects to maps for notification service
      final drugsData = drugs.map((drug) => drug.toJson()).toList();

      // Update notifications service with the latest drug list for real-time monitoring
      await NotificationsService.monitorAndTriggerCriticalAlerts(drugsData);

      emit(GetDrugsSuccessState(drugs)); // Pass drugs to the state
    } catch (error) {
      emit(GetDrugsErrorState(error.toString()));
      print(error.toString());
    }
  }

  void insertDrug(DrugModel drug) async {
    emit(insertDrugsLoadingState());
    try {
      await DrugsRepository().addDrug(drug);

      // Immediately refresh the list to show the new drug
      getDrugs();

      emit(insertDrugsSuccessState());
    } catch (error) {
      emit(insertDrugsErrorState(error.toString()));
      print(error.toString());
    }
  }

  void updateDrug(DrugModel drug) async {
    emit(updateDrugsLoadingState());
    try {
      await DrugsRepository().updateDrug(drug);

      // Update the local drugs list immediately for real-time response
      final index = drugs.indexWhere((d) => d.id == drug.id);
      if (index != -1) {
        drugs[index] = drug;
        // Update the state immediately with the modified list
        emit(GetDrugsSuccessState(List.from(drugs)));
      }

      // Convert to maps for notification service
      final drugsData = drugs.map((drug) => drug.toJson()).toList();

      // Check and notify about critical situations after update
      await NotificationsService.monitorAndTriggerCriticalAlerts(drugsData);

      // Update the notifications service with the current drug list
      await NotificationsService.updateDrugsList(drugsData);

      emit(updateDrugsSuccessState());

      // Refresh the complete drugs list from database to ensure consistency
      getDrugs();
    } catch (error) {
      emit(updateDrugsErrorState(error.toString()));
      print(error.toString());
    }
  }

  void deleteDrug(String id) async {
    emit(deleteDrugsLoadingState());
    try {
      await DrugsRepository().deleteDrug(id);

      // Remove the drug from local list immediately for real-time response
      drugs.removeWhere((drug) => drug.id == id);
      emit(GetDrugsSuccessState(List.from(drugs)));

      // Convert to maps for notification service
      final drugsData = drugs.map((drug) => drug.toJson()).toList();

      // Update notifications service with the updated list
      await NotificationsService.updateDrugsList(drugsData);

      emit(deleteDrugsSuccessState());

      // Refresh the complete drugs list to ensure consistency
      getDrugs();
    } catch (error) {
      emit(deleteDrugsErrorState(error.toString()));
      print(error.toString());
    }
  }

}