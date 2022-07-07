import 'dart:typed_data';

import 'package:passbook/accounts/constants.dart';
import 'package:passbook/passbook_program.dart';
import 'package:passbook/utils/endian.dart';
import 'package:passbook/utils/struct_reader.dart';
import 'package:solana/base58.dart';
import 'package:solana/dto.dart' as dto;
import 'package:solana/encoder.dart';
import 'package:solana/solana.dart';

class StoreAuthorityAccount {
  const StoreAuthorityAccount({
    required this.address,
    required this.storeAuthority,
  });
  final String address;
  final StoreAuthority storeAuthority;
}

class StoreAuthority {
  const StoreAuthority({
    required this.key,
    required this.store,
    required this.allowedRedemptions,
    required this.bump,
  });

  factory StoreAuthority.fromBinary(List<int> sourceBytes) {
    final bytes = Int8List.fromList(sourceBytes);
    final reader = StructReader(bytes.buffer)..skip(1);
    final store = base58encode(reader.nextBytes(32));
    final BigInt allowedRedemptions =
        decodeBigInt(reader.nextBytes(8), Endian.little);
    final bump = reader.nextBytes(1).first;

    return StoreAuthority(
      key: AccountKey.storeAuthority,
      store: store,
      allowedRedemptions: allowedRedemptions,
      bump: bump,
    );
  }

  final AccountKey key;
  final String store;
  final BigInt allowedRedemptions;
  final int bump;

  static const prefix = 'admin';

  static Future<Ed25519HDPublicKey> pda(
    Ed25519HDPublicKey store,
    Ed25519HDPublicKey user,
  ) {
    final programID = Ed25519HDPublicKey.fromBase58(PassbookProgram.programId);
    return Ed25519HDPublicKey.findProgramAddress(seeds: [
      PassbookProgram.prefix.codeUnits,
      programID.bytes,
      store.bytes,
      user.bytes,
      StoreAuthority.prefix.codeUnits,
    ], programId: programID);
  }
}

extension ProgramAccountExt on dto.ProgramAccount {
  dto.SplTokenAccountDataInfo? toPassBookAccountDataOrNull() {
    final data = account.data;
    if (data is dto.ParsedAccountData) {
      return data.maybeMap(
        orElse: () => null,
        splToken: (data) => data.parsed.maybeMap(
          orElse: () => null,
          account: (data) {
            final info = data.info;
            final tokenAmount = info.tokenAmount;
            final amount = int.parse(tokenAmount.amount);

            if (tokenAmount.decimals != 0 || amount != 1) {
              return null;
            }

            return info;
          },
        ),
      );
    } else {
      return null;
    }
  }
}

extension UseAuthorityExtension on RpcClient {
  Future<StoreAuthorityAccount?> getUseAuthorityAccount({
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
      return StoreAuthorityAccount(
          address: address.toBase58(),
          storeAuthority: StoreAuthority.fromBinary(data.data));
    } else {
      return null;
    }
  }

  Future<List<StoreAuthorityAccount>> findUseAuthorities(
      {String? store}) async {
    final filters = [
      dto.ProgramDataFilter.memcmp(
          offset: 0,
          bytes: ByteArray.u8(AccountKey.storeAuthority.id).toList()),
      if (store != null)
        dto.ProgramDataFilter.memcmpBase58(offset: 1, bytes: store),
    ];
    final accounts = await getProgramAccounts(
      PassbookProgram.programId,
      encoding: dto.Encoding.base64,
      filters: filters,
    );
    return accounts
        .map(
          (acc) => StoreAuthorityAccount(
            address: acc.pubkey,
            storeAuthority: StoreAuthority.fromBinary(
                (acc.account.data as dto.BinaryAccountData).data),
          ),
        )
        .toList();
  }
}
