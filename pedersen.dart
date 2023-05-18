import 'package:pointycastle/ecc/api.dart';
import 'util.dart';
import 'dart:math';
import 'dart:typed_data';


class PedersenSetup {
  late ECPoint _H;
  late ECPoint _HG;
  late ECDomainParameters _params;

  PedersenSetup(this._H) {
    _params = new ECDomainParameters("secp256k1");
    // validate H point
    if (!Util.isPointOnCurve(_H, _params.curve)) {
      throw Exception('H is not a valid point on the curve');
    }
    _HG = Util.combinePubKeys([_H, _params.G]);
  }

  Uint8List get H => _H.getEncoded(false);
  Uint8List get HG => _HG.getEncoded(false);
}

