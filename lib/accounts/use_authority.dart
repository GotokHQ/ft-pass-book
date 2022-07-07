import 'dart:typed_data';

import 'package:passbook/accounts/constants.dart';
import 'package:passbook/passbook_program.dart';
import 'package:passbook/utils/endian.dart';
import 'package:passbook/utils/struct_reader.dart';
import 'package:solana/base58.dart';
import 'package:solana/dto.dart' as dto;
import 'package:solana/encoder.dart';
import 'package:solana/solana.dart';

class UseAuthorityAccount {
  const UseAuthorityAccount({
    required this.address,
    required this.useAuthority,
  });
  final String address;
  final UseAuthority useAuthority;
}

class UseAuthority {
  const UseAuthority({
    required this.key,
    required this.membership,
    required this.allowedUses,
    required this.bump,
  });

  factory UseAuthority.fromBinary(List<int> sourceBytes) {
    final bytes = Int8List.fromList(sourceBytes);
    final reader = StructReader(bytes.buffer)..skip(1);
    final membership = base58encode(reader.nextBytes(32));
    final BigInt allowedUses = decodeBigInt(reader.nextBytes(8), Endian.little);
    final bump = reader.nextBytes(1).first;

    return UseAuthority(
      key: AccountKey.useAuthority,
      membership: membership,
      allowedUses: allowedUses,
      bump: bump,
    );
  }

  final AccountKey key;
  final String membership;
  final BigInt allowedUses;
  final int bump;

  static const prefix = 'user';

  static Future<Ed25519HDPublicKey> pda(
    Ed25519HDPublicKey membership,
    Ed25519HDPublicKey user,
  ) {
    final programID = Ed25519HDPublicKey.fromBase58(PassbookProgram.programId);
    return Ed25519HDPublicKey.findProgramAddress(seeds: [
      PassbookProgram.prefix.codeUnits,
      programID.bytes,
      membership.bytes,
      user.bytes,
      UseAuthority.prefix.codeUnits,
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
  Future<UseAuthorityAccount?> getUseAuthorityAccount({
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
      return UseAuthorityAccount(
          address: address.toBase58(),
          useAuthority: UseAuthority.fromBinary(data.data));
    } else {
      return null;
    }
  }

  Future<List<UseAuthorityAccount>> findUseAuthorities(
      {String? membership}) async {
    final filters = [
      dto.ProgramDataFilter.memcmp(
          offset: 0, bytes: ByteArray.u8(AccountKey.membership.id).toList()),
      if (membership != null)
        dto.ProgramDataFilter.memcmpBase58(offset: 1, bytes: membership),
    ];
    final accounts = await getProgramAccounts(
      PassbookProgram.programId,
      encoding: dto.Encoding.base64,
      filters: filters,
    );
    return accounts
        .map(
          (acc) => UseAuthorityAccount(
            address: acc.pubkey,
            useAuthority: UseAuthority.fromBinary(
                (acc.account.data as dto.BinaryAccountData).data),
          ),
        )
        .toList();
  }
}
