
import 'package:cashfusion/fusion.dart';
import 'package:pointycastle/ecc/api.dart';
import 'dart:math';
import 'dart:typed_data';
import 'package:crypto/crypto.dart' as crypto;

class Tuple<T1, T2> {
  T1 item1;
  T2 item2;

  Tuple(this.item1, this.item2);

  set setItem1(T1 value) {
    this.item1 = value;
  }

  set setItem2(T2 value) {
    this.item2 = value;
  }
}

class Util {

  static void unreserve_change_address(Address addr) {
    //implement later based on wallet.
    return;
  }

  static bool walletHasTransaction(String txid) {
    // implement later based on wallet.
    return true;
  }

static Uint8List bigIntToBytes(BigInt bigInt) {
    return Uint8List.fromList(bigInt.toRadixString(16).padLeft(32, '0').codeUnits);
  }

static Tuple<Uint8List, Uint8List> genKeypair() {
  var params = ECDomainParameters('secp256k1');
  var privKeyBigInt = _generatePrivateKey(params.n.bitLength);
  var pubKeyPoint = params.G * privKeyBigInt;

  if (pubKeyPoint == null) {
    throw Exception("Error generating public key.");
  }

  Uint8List privKey = bigIntToBytes(privKeyBigInt);
  Uint8List pubKey = pubKeyPoint.getEncoded(true);

  return Tuple(privKey, pubKey);
}



// Generates a cryptographically secure private key
  static BigInt _generatePrivateKey(int bitLength) {
    final random = Random.secure();
    var bytes = bitLength ~/ 8; // floor division
    var remBit = bitLength % 8;

    // Generate random BigInt
    List<int> rnd = List<int>.generate(bytes, (_) => random.nextInt(256));
    var rndBit = random.nextInt(1 << remBit);
    rnd.add(rndBit);
    var privateKey = BigInt.parse(rnd.map((x) => x.toRadixString(16).padLeft(2, '0')).join(), radix: 16);

    return privateKey;
  }

  // Additional helper function to convert bytes to hex
  static String bytesToHex(Uint8List bytes) {
    return bytes.map((byte) => byte.toRadixString(16).padLeft(2, '0')).join();
  }


  static Uint8List sha256(Uint8List bytes) {
    crypto.Digest digest = crypto.sha256.convert(bytes);
    return Uint8List.fromList(digest.bytes);
  }
  static Uint8List tokenBytes([int nbytes = 32]) {
    final Random _random = Random.secure();

    return Uint8List.fromList(List<int>.generate(nbytes, (i) => _random.nextInt(256)));
  }

  static int componentFee(int size, int feerate) {
    // feerate in sat/kB
    // size and feerate should both be integer
    // fee is always rounded up
    return ((size * feerate) + 999) ~/ 1000;
  }


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

