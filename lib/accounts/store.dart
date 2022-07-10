import 'dart:typed_data';

import 'package:passbook/accounts/constants.dart';
import 'package:passbook/passbook_program.dart';
import 'package:passbook/utils/endian.dart';
import 'package:passbook/utils/struct_reader.dart';
import 'package:solana/base58.dart';
import 'package:solana/solana.dart';
import 'package:solana/dto.dart' as dto;
import 'package:solana/encoder.dart';

class StoreAccount {
  const StoreAccount({
    required this.address,
    required this.store,
  });
  final String address;
  final Store store;
}

class Store {
  const Store(
      {required this.key,
      required this.authority,
      required this.redemptionsCount,
      required this.membershipCount,
      required this.activeMembershipCount,
      required this.passCount,
      required this.passBookCount,
      this.referrer,
      this.referralEndDate});

  static const prefix = 'store';

  factory Store.fromBinary(List<int> sourceBytes) {
    final bytes = Int8List.fromList(sourceBytes);
    final reader = StructReader(bytes.buffer)..skip(1);
    final authority = base58encode(reader.nextBytes(32));
    final redemptionsCount = decodeBigInt(reader.nextBytes(8), Endian.little);
    final membershipCount = decodeBigInt(reader.nextBytes(8), Endian.little);
    final activeMembershipCount =
        decodeBigInt(reader.nextBytes(8), Endian.little);
    final passCount = decodeBigInt(reader.nextBytes(8), Endian.little);
    final passBookCount = decodeBigInt(reader.nextBytes(8), Endian.little);
    final hasReferrer = reader.nextBytes(1).first == 1;
    final String? referrer =
        hasReferrer ? base58encode(reader.nextBytes(32)) : null;
    final hasReferralEndDate = reader.nextBytes(1).first == 1;
    final DateTime? referralEndDate = hasReferralEndDate
        ? DateTime.fromMillisecondsSinceEpoch(
            (decodeBigInt(reader.nextBytes(8), Endian.little) *
                    BigInt.from(1000))
                .toInt())
        : null;

    return Store(
        key: AccountKey.passStore,
        authority: authority,
        redemptionsCount: redemptionsCount,
        membershipCount: membershipCount,
        activeMembershipCount: activeMembershipCount,
        passCount: passCount,
        passBookCount: passBookCount,
        referrer: referrer,
        referralEndDate: referralEndDate);
  }

  final AccountKey key;
  final String authority;
  final BigInt redemptionsCount;
  final BigInt membershipCount;
  final BigInt activeMembershipCount;
  final BigInt passCount;
  final BigInt passBookCount;
  final String? referrer;
  final DateTime? referralEndDate;

  static Future<Ed25519HDPublicKey> pda(String authority) {
    final programID = Ed25519HDPublicKey.fromBase58(PassbookProgram.programId);
    return Ed25519HDPublicKey.findProgramAddress(seeds: [
      PassbookProgram.prefix.codeUnits,
      programID.bytes,
      Ed25519HDPublicKey.fromBase58(authority).bytes,
      Store.prefix.codeUnits,
    ], programId: programID);
  }
}

extension StoreExtension on RpcClient {
  Future<StoreAccount?> getStoreAccount({
    required Ed25519HDPublicKey address,
  }) async {
    final account = await getAccountInfo(
      address.toBase58(),
      encoding: dto.Encoding.base64,
    );
    if (account == null) {
      return null;
    }

    final data = account.data;

    if (data is dto.BinaryAccountData) {
      return StoreAccount(
        address: address.toBase58(),
        store: Store.fromBinary(data.data),
      );
    } else {
      return null;
    }
  }
}
