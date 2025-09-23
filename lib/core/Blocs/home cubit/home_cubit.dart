import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:pharmanow/core/models/Drugs/drug_model.dart';
import '../../repositories/drugs_repositories.dart';
import '../../utils/notifications_service.dart';
import 'home_states.dart';

class HomeCubit extends Cubit<HomeStates> {

  HomeCubit() : super(HomeInitialState());

  static HomeCubit get(context) => BlocProvider.of(context);

  int currentIndex = 0;

  void changeBottomNav(int index) {
    currentIndex = index;
    emit(HomeChangeBottomNavState());
  }

  List<DrugModel> drugs = [];

  void getDrugs() async {
    emit(GetDrugsLoadingState());
    try {
      final drugsList = await DrugsRepository().getAllDrugs();
      drugs = drugsList;

      // Update notifications service with the latest drug list for real-time monitoring
      await NotificationsService.updateDrugsList(drugs);

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

      // Check and notify about stock levels after update
      await NotificationsService.checkAndNotifyStockLevels([drug]);

      // Update the notifications service with the current drug list
      await NotificationsService.updateDrugsList(drugs);

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

      // Update notifications service with the updated list
      await NotificationsService.updateDrugsList(drugs);

      emit(deleteDrugsSuccessState());

      // Refresh the complete drugs list to ensure consistency
      getDrugs();
    } catch (error) {
      emit(deleteDrugsErrorState(error.toString()));
      print(error.toString());
    }
  }

}