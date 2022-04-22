import 'package:solana/encoder.dart';
import 'package:solana/solana.dart';

class PassbookProgram {
  static const prefix = 'passbook';
  static const programId = 'passjvPvHQWN4SvBCmHk1gdrtBvoHRERtQK9MKemreQ';

  static Future<Ed25519HDPublicKey> findProgramAuthority() {
    return Ed25519HDPublicKey.findProgramAddress(seeds: [
      Buffer.fromBase58(prefix),
      Buffer.fromBase58(PassbookProgram.programId),
    ], programId: Ed25519HDPublicKey.fromBase58(programId));
  }
}
