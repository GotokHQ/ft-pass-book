enum AccountKey {
  uninitialized,
  pass,
  passStore,
  passBook,
}

extension AccountKeyExtension on AccountKey {
  static AccountKey fromId(int id) {
    switch (id) {
      case 0:
        return AccountKey.uninitialized;
      case 1:
        return AccountKey.pass;
      case 2:
        return AccountKey.passStore;
      case 3:
        return AccountKey.passBook;
    }
    throw StateError('Invalid account key');
  }

  int get id {
    switch (this) {
      case AccountKey.uninitialized:
        return 0;
      case AccountKey.pass:
        return 1;
      case AccountKey.passStore:
        return 2;
      case AccountKey.passBook:
        return 3;
    }
  }
}

enum PassState {
  notActivated,
  activated,
  deactivated,
  ended,
}

extension PassStateExtension on PassState {
  static PassState fromId(int id) {
    switch (id) {
      case 0:
        return PassState.notActivated;
      case 1:
        return PassState.activated;
      case 2:
        return PassState.deactivated;
      case 3:
        return PassState.ended;
    }
    throw StateError('Invalid pass key');
  }

  int get id {
    switch (this) {
      case PassState.notActivated:
        return 0;
      case PassState.activated:
        return 1;
      case PassState.deactivated:
        return 2;
      case PassState.ended:
        return 3;
    }
  }
}
