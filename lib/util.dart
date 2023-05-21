
import 'package:pointycastle/ecc/api.dart';
import 'dart:math';
import 'dart:typed_data';

class Util {

  static ECPoint ser_to_point(Uint8List serializedPoint, ECDomainParameters params) {
    var point = params.curve.decodePoint(serializedPoint);
    if (point == null) {
      throw FormatException('Point decoding failed');
    }
    return point;
  }

  static Uint8List point_to_ser(ECPoint point, bool compress) {
    return point.getEncoded(compress);
  }


  static BigInt secureRandomBigInt(int bitLength) {
    final random = Random.secure();
    final bytes = (bitLength + 7) ~/ 8; // ceil division
    final Uint8List randomBytes = Uint8List(bytes);

    for (int i = 0; i < bytes; i++) {
      randomBytes[i] = random.nextInt(256);
    }

    BigInt randomNumber = BigInt.parse(randomBytes.map((e) => e.toRadixString(16).padLeft(2, '0')).join(), radix: 16);
    return randomNumber;
  }
 static ECPoint combinePubKeys(List<ECPoint> pubKeys) {
    if (pubKeys.isEmpty) throw ArgumentError('pubKeys cannot be empty');

    ECPoint combined = pubKeys.first.curve.infinity!;
    for (var pubKey in pubKeys) {
      combined = (combined + pubKey)!;
    }

    if (combined.isInfinity) {
      throw Exception('Combined point is at infinity');
    }

    return combined;
  }

 static bool isPointOnCurve(ECPoint point, ECCurve curve) {
    var x = point.x!.toBigInteger()!;
    var y = point.y!.toBigInteger()!;
    var a = curve.a!.toBigInteger()!;
    var b = curve.b!.toBigInteger()!;

    // Calculate the left and right sides of the equation
    var left = y * y;
    var right = (x * x * x) + (a * x) + b;

    // Check if the point is on the curve
    return left == right;
  }



} //  END OF CLASS

