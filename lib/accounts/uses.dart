import 'dart:typed_data';

import 'package:passbook/utils/endian.dart';
import 'package:passbook/utils/struct_reader.dart';

const kMaxUsesLength = 24;

class Uses {
  const Uses({
    required this.remaining,
    required this.total,
  });

  factory Uses.fromBinary(List<int> sourceBytes) {
    final bytes = Int8List.fromList(sourceBytes);
    final reader = StructReader(bytes.buffer);
    final remaining = decodeBigInt(reader.nextBytes(8), Endian.little);
    final total = decodeBigInt(reader.nextBytes(8), Endian.little);

    return Uses(
      remaining: remaining,
      total: total,
    );
  }

  final BigInt remaining;
  final BigInt total;
}
