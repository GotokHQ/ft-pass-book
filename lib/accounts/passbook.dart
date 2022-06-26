import 'dart:typed_data';

import 'package:passbook/accounts/constants.dart';
import 'package:passbook/passbook_program.dart';
import 'package:passbook/utils/endian.dart';
import 'package:passbook/utils/struct_reader.dart';
import 'package:collection/collection.dart';
import 'package:solana/base58.dart';
import 'package:solana/dto.dart' as dto;
import 'package:solana/encoder.dart';
import 'package:solana/solana.dart';

class PassBookAccount {
  const PassBookAccount({
    required this.address,
    required this.passBook,
  });
  final String address;
  final PassBook passBook;
}

class PassBook {
  const PassBook(
      {required this.key,
      required this.name,
      required this.description,
      required this.uri,
      required this.authority,
      required this.mint,
      required this.mutable,
      required this.passState,
      required this.totalPasses,
      required this.createdAt,
      required this.price,
      required this.priceMint,
      required this.token,
      this.access,
      this.duration,
      this.maxSupply,
      this.blurHash,
      this.marketAuthority,
      this.creators});

  factory PassBook.fromBinary(List<int> sourceBytes) {
    final bytes = Int8List.fromList(sourceBytes);
    final reader = StructReader(bytes.buffer)..skip(1);
    final authority = base58encode(reader.nextBytes(32));
    final mint = base58encode(reader.nextBytes(32));
    final name = reader.nextString();
    final description = reader.nextString();
    final uri = reader.nextString();
    final mutable = reader.nextBytes(1).first == 1;
    final passState = PassStateExtension.fromId(reader.nextBytes(1).first);
    final hasAccess = reader.nextBytes(1).first == 1;
    final BigInt? access =
        hasAccess ? decodeBigInt(reader.nextBytes(8), Endian.little) : null;
    final hasDuration = reader.nextBytes(1).first == 1;
    final BigInt? duration =
        hasDuration ? decodeBigInt(reader.nextBytes(8), Endian.little) : null;
    final BigInt totalPasses = decodeBigInt(reader.nextBytes(8), Endian.little);
    final hasMaxSupply = reader.nextBytes(1).first == 1;
    final BigInt? maxSupply =
        hasMaxSupply ? decodeBigInt(reader.nextBytes(8), Endian.little) : null;

    final hasBlurHash = reader.nextBytes(1).first == 1;
    final String? blurHash = hasBlurHash ? reader.nextString() : null;

    final BigInt createdAt = decodeBigInt(reader.nextBytes(8), Endian.little);
    final BigInt price = decodeBigInt(reader.nextBytes(8), Endian.little);
    final priceMint = base58encode(reader.nextBytes(32));
    final token = base58encode(reader.nextBytes(32));
    final hasMarketAuthority = reader.nextBytes(1).first == 1;
    final String? marketAuthority =
        hasMarketAuthority ? base58encode(reader.nextBytes(32)) : null;
    final hasCreators = reader.nextBytes(1).first == 1;
    final creatorLength = hasCreators
        ? decodeBigInt(reader.nextBytes(4), Endian.little)
        : BigInt.zero;
    final List<String> creators = List.generate(
        creatorLength.toInt(), (index) => base58encode(reader.nextBytes(32)));
    return PassBook(
        key: AccountKey.passBook,
        name: name,
        description: description,
        uri: uri,
        authority: authority,
        mint: mint,
        mutable: mutable,
        passState: passState,
        access: access,
        duration: duration,
        totalPasses: totalPasses,
        maxSupply: maxSupply,
        blurHash: blurHash,
        createdAt: DateTime.fromMillisecondsSinceEpoch(
            (createdAt * BigInt.from(1000)).toInt()),
        price: price,
        priceMint: priceMint,
        token: token,
        marketAuthority: marketAuthority,
        creators: creators);
  }

  final AccountKey key;
  final String name;
  final String description;
  final String uri;
  final String authority;
  final String mint;
  final String? blurHash;
  final bool mutable;
  final PassState passState;
  final BigInt? access;
  final BigInt? duration;
  final BigInt totalPasses;
  final BigInt? maxSupply;
  final DateTime createdAt;
  final BigInt price;
  final String priceMint;
  final String token;
  final String? marketAuthority;
  final List<String>? creators;

  static Future<Ed25519HDPublicKey> pda(Ed25519HDPublicKey mint) {
    final programID = Ed25519HDPublicKey.fromBase58(PassbookProgram.programId);
    return Ed25519HDPublicKey.findProgramAddress(seeds: [
      PassbookProgram.prefix.codeUnits,
      programID.bytes,
      mint.bytes,
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

extension PassBookExtension on RpcClient {
  Future<PassBookAccount?> getPassBookAccount({
    required Ed25519HDPublicKey mint,
  }) async {
    final programAddress = await PassBook.pda(mint);
    final account = await getAccountInfo(
      programAddress.toBase58(),
      encoding: dto.Encoding.base64,
    );
    if (account == null) {
      return null;
    }

    final data = account.data;

    if (data is dto.BinaryAccountData) {
      return PassBookAccount(
          address: programAddress.toBase58(),
          passBook: PassBook.fromBinary(data.data));
    } else {
      return null;
    }
  }

  Future<List<PassBookAccount>> findPassBooks(
      {String? mint, String? authority}) async {
    final filters = [
      dto.ProgramDataFilter.memcmp(
          offset: 0, bytes: ByteArray.u8(AccountKey.passBook.id).toList()),
      if (authority != null)
        dto.ProgramDataFilter.memcmpBase58(offset: 1, bytes: authority),
      if (mint != null)
        dto.ProgramDataFilter.memcmpBase58(offset: 33, bytes: mint),
    ];
    final accounts = await getProgramAccounts(
      PassbookProgram.programId,
      encoding: dto.Encoding.base64,
      filters: filters,
    );
    return accounts
        .map(
          (acc) => PassBookAccount(
            address: acc.pubkey,
            passBook: PassBook.fromBinary(
                (acc.account.data as dto.BinaryAccountData).data),
          ),
        )
        .toList();
  }

  Future<List<PassBookAccount>> findPassBooksByOwner(String owner) async {
    final accounts = await getTokenAccountsByOwner(
      owner,
      const dto.TokenAccountsFilter.byProgramId(TokenProgram.programId),
      commitment: Commitment.confirmed,
      encoding: dto.Encoding.jsonParsed,
    );
    final mints =
        accounts.map((d) => d.toPassBookAccountDataOrNull()).whereNotNull();
    final unfiltered = await Future.wait(
      mints.map((info) async {
        final pda = await getPassBookAccount(
            mint: Ed25519HDPublicKey.fromBase58(info.mint));
        return pda;
      }),
    );
    return unfiltered.whereNotNull().toList();
  }
}
