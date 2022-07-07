import 'dart:typed_data';

import 'package:passbook/accounts/constants.dart';
import 'package:passbook/passbook_program.dart';
import 'package:passbook/utils/endian.dart';
import 'package:passbook/utils/struct_reader.dart';
import 'package:solana/base58.dart';
import 'package:solana/dto.dart' as dto;
import 'package:solana/encoder.dart';
import 'package:solana/solana.dart';

class MembershipAccount {
  const MembershipAccount({
    required this.address,
    required this.membership,
  });
  final String address;
  final Membership membership;
}

class Membership {
  const Membership({
    required this.key,
    required this.store,
    required this.state,
    required this.owner,
    this.passbook,
    this.pass,
    this.expiresAt,
    this.activatedAt,
  });

  factory Membership.fromBinary(List<int> sourceBytes) {
    final bytes = Int8List.fromList(sourceBytes);
    final reader = StructReader(bytes.buffer)..skip(1);
    final store = base58encode(reader.nextBytes(32));
    final state = MembershipStateExtension.fromId(reader.nextBytes(1).first);
    final owner = base58encode(reader.nextBytes(32));

    final hasPassbook = reader.nextBytes(1).first == 1;
    final String? passbook =
        hasPassbook ? base58encode(reader.nextBytes(32)) : null;

    final hasPass = reader.nextBytes(1).first == 1;
    final String? pass = hasPass ? base58encode(reader.nextBytes(32)) : null;

    final hasExpiresAt = reader.nextBytes(1).first == 1;
    final BigInt? expiresAt =
        hasExpiresAt ? decodeBigInt(reader.nextBytes(8), Endian.little) : null;

    final hasActivatedAt = reader.nextBytes(1).first == 1;
    final BigInt? activatedAt = hasActivatedAt
        ? decodeBigInt(reader.nextBytes(8), Endian.little)
        : null;

    return Membership(
      key: AccountKey.membership,
      store: store,
      state: state,
      owner: owner,
      passbook: passbook,
      pass: pass,
      expiresAt: expiresAt != null
          ? DateTime.fromMillisecondsSinceEpoch(
              (expiresAt * BigInt.from(1000)).toInt())
          : null,
      activatedAt: activatedAt != null
          ? DateTime.fromMillisecondsSinceEpoch(
              (activatedAt * BigInt.from(1000)).toInt())
          : null,
    );
  }

  final AccountKey key;
  final String store;
  final MembershipState state;
  final String owner;
  final String? passbook;
  final String? pass;
  final DateTime? expiresAt;
  final DateTime? activatedAt;

  static const prefix = 'membership';

  static Future<Ed25519HDPublicKey> pda(
    Ed25519HDPublicKey store,
    Ed25519HDPublicKey wallet,
  ) {
    final programID = Ed25519HDPublicKey.fromBase58(PassbookProgram.programId);
    return Ed25519HDPublicKey.findProgramAddress(seeds: [
      PassbookProgram.prefix.codeUnits,
      programID.bytes,
      store.bytes,
      wallet.bytes,
      Membership.prefix.codeUnits,
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

extension MembershipExtension on RpcClient {
  Future<MembershipAccount?> getMembershipAccount({
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
      return MembershipAccount(
          address: address.toBase58(),
          membership: Membership.fromBinary(data.data));
    } else {
      return null;
    }
  }

  Future<List<MembershipAccount>> findMemberships(
      {MembershipState? state, String? store, String? owner}) async {
    final filters = [
      dto.ProgramDataFilter.memcmp(
          offset: 0, bytes: ByteArray.u8(AccountKey.membership.id).toList()),
      if (store != null)
        dto.ProgramDataFilter.memcmpBase58(offset: 1, bytes: store),
      if (state != null)
        dto.ProgramDataFilter.memcmp(
            offset: 33, bytes: ByteArray.u8(state.id).toList()),
      if (owner != null)
        dto.ProgramDataFilter.memcmpBase58(offset: 34, bytes: owner),
    ];
    final accounts = await getProgramAccounts(
      PassbookProgram.programId,
      encoding: dto.Encoding.base64,
      filters: filters,
    );
    return accounts
        .map(
          (acc) => MembershipAccount(
            address: acc.pubkey,
            membership: Membership.fromBinary(
                (acc.account.data as dto.BinaryAccountData).data),
          ),
        )
        .toList();
  }

  Future<List<MembershipAccount>> findMembershipsByOwner(String owner) async {
    return findMemberships(owner: owner);
  }
}
