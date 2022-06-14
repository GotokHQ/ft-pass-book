import 'package:solana/solana.dart';

class PassbookProgram {
  static const prefix = 'passbook';
  static const programId = 'passjvPvHQWN4SvBCmHk1gdrtBvoHRERtQK9MKemreQ';

  static Future<Ed25519HDPublicKey> findProgramAuthority() {
    return Ed25519HDPublicKey.findProgramAddress(seeds: [
      prefix.codeUnits,
      Ed25519HDPublicKey.fromBase58(PassbookProgram.programId).bytes,
    ], programId: Ed25519HDPublicKey.fromBase58(programId));
  }
}
