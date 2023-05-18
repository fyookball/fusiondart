
import 'package:pointycastle/ecc/api.dart';

class Util {


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

