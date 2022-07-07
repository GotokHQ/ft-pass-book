enum AccountKey {
  uninitialized,
  pass,
  passStore,
  passBook,
  payout,
  tradeHistory,
  membership,
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
      case 4:
        return AccountKey.payout;
      case 5:
        return AccountKey.tradeHistory;
      case 6:
        return AccountKey.membership;
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
      case AccountKey.payout:
        return 4;
      case AccountKey.tradeHistory:
        return 5;
      case AccountKey.membership:
        return 6;
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

enum MembershipState {
  notActivated,
  activated,
  expired,
}

extension MembershipStateExtension on MembershipState {
  static MembershipState fromId(int id) {
    switch (id) {
      case 0:
        return MembershipState.notActivated;
      case 1:
        return MembershipState.activated;
      case 2:
        return MembershipState.expired;
    }
    throw StateError('Invalid membership key');
  }

  int get id {
    switch (this) {
      case MembershipState.notActivated:
        return 0;
      case MembershipState.activated:
        return 1;
      case MembershipState.expired:
        return 2;
    }
  }
}
