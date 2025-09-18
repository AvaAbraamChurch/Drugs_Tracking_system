abstract class HomeStates {}

class HomeInitialState extends HomeStates {}

class HomeChangeBottomNavState extends HomeStates {}

class GetDrugsLoadingState extends HomeStates {}

class GetDrugsSuccessState extends HomeStates {}

class GetDrugsErrorState extends HomeStates {
  final String error;

  GetDrugsErrorState(this.error);
}

class insertDrugsLoadingState extends HomeStates {}

class insertDrugsSuccessState extends HomeStates {}

class insertDrugsErrorState extends HomeStates {
  final String error;

  insertDrugsErrorState(this.error);
}

class updateDrugsLoadingState extends HomeStates {}

class updateDrugsSuccessState extends HomeStates {}

class updateDrugsErrorState extends HomeStates {
  final String error;

  updateDrugsErrorState(this.error);
}

class deleteDrugsLoadingState extends HomeStates {}

class deleteDrugsSuccessState extends HomeStates {}

class deleteDrugsErrorState extends HomeStates {
  final String error;

  deleteDrugsErrorState(this.error);
}

