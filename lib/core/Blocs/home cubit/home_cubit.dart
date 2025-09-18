import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:pharmanow/core/models/Drugs/drug_model.dart';

import '../../repositories/drugs_repositories.dart';
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
      emit(GetDrugsSuccessState());
    } catch (error) {
      emit(GetDrugsErrorState(error.toString()));
      print(error.toString());
    }
  }

  void insertDrug(DrugModel drug) async {
    emit(insertDrugsLoadingState());
    try {
      await DrugsRepository().addDrug(drug);
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
      emit(updateDrugsSuccessState());
    } catch (error) {
      emit(updateDrugsErrorState(error.toString()));
      print(error.toString());
    }
  }

  void deleteDrug(String id) async {
    emit(deleteDrugsLoadingState());
    try {
      await DrugsRepository().deleteDrug(id);
      emit(deleteDrugsSuccessState());
    } catch (error) {
      emit(deleteDrugsErrorState(error.toString()));
      print(error.toString());
    }
  }


}