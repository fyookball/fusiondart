
import 'dart:convert';
import 'dart:math';
import 'fusion.pb.dart';
import 'util.dart';
import 'dart:typed_data';
import 'package:fixnum/fixnum.dart';



class Input {
  List<int> prevTxid;
  int prevIndex;
  List<int> pubKey;
  int amount;

  Input({required this.prevTxid, required this.prevIndex, required this.pubKey, required this.amount});

  int sizeOfInput() {
    assert(1 < pubKey.length && pubKey.length < 76);  // need to assume regular push opcode
    return 108 + pubKey.length;
  }
}

class Address {
  String addr="";

  List<int>toScript() {
    return [];
  }
}

class Output {
  int value;
  Address addr;

  Output({required this.value, required this.addr});

  int sizeOfOutput() {
    List<int> scriptpubkey = addr.toScript(); // assuming addr.toScript() returns List<int> that represents the scriptpubkey
    assert(scriptpubkey.length < 253);  // need to assume 1-byte varint
    return 9 + scriptpubkey.length;
  }
}



// Class to handle fusion
class Fusion {

static void foo() {
print ("hello");
}

static bool walletCanFuse() {
  return true;

  // Implement logic here to return false if the wallet can't fuse.  (If its read only or non P2PKH)
}

static double nextDoubleNonZero(Random rng) {
  double value = 0.0;
  while (value == 0.0) {
    value = rng.nextDouble();
  }
  return value;
}

static List<int>? randomOutputsForTier(Random rng, int inputAmount, int scale, int offset, int maxCount) {

  if (inputAmount < offset) {
  return [];
  }
  double lambd = 1.0 / scale;
  int remaining = inputAmount;
  List<double> values = [];  // list of fractional random values without offset

  for (int i = 0; i < maxCount + 1; i++) {
    double val = -lambd * log(nextDoubleNonZero(rng));
     remaining -= (val.ceil() + offset);
    if (remaining < 0) {
      break;
    }
    values.add(val);
  }

  assert(values.length <= maxCount);

  if (values.isEmpty) {
    // Our first try put us over the limit, so we have nothing to work with.
    // (most likely, scale was too large)
    return [];
  }

  int desiredRandomSum = inputAmount - values.length * offset;
  assert(desiredRandomSum >= 0, 'desiredRandomSum is less than 0');

  /*Now we need to rescale and round the values so they fill up the desired.
  input amount exactly. We perform rounding in cumulative space so that the
  sum is exact, and the rounding is distributed fairly.
   */

  // Dart equivalent of itertools.accumulate
  List<double> cumsum = [];
  double sum = 0;
  for (double value in values) {
    sum += value;
    cumsum.add(sum);
  }

  double rescale = desiredRandomSum / cumsum[cumsum.length - 1];
  List<int> normedCumsum = cumsum.map((v) => (rescale * v).round()).toList();
  assert(normedCumsum[normedCumsum.length - 1] == desiredRandomSum, 'Last element of normedCumsum is not equal to desiredRandomSum');
  List<int> differences = [];
  differences.add(normedCumsum[0]);  // First element
  for (int i = 1; i < normedCumsum.length; i++) {
    differences.add(normedCumsum[i] - normedCumsum[i - 1]);
  }

  List<int> result = differences.map((d) => offset + d).toList();
  assert(result.reduce((a, b) => a + b) == inputAmount, 'Sum of result is not equal to inputAmount');
  return result;

}

static void genComponents(int numBlanks, List<Input> inputs, List<Output> outputs, int feerate) {
  assert(numBlanks >= 0);

  List<Tuple<Component, int>> components = [];

  for (Input input in inputs) {
    int fee = Util.componentFee(input.sizeOfInput(), feerate);

    var comp = Component();
    comp.input = InputComponent(
        prevTxid: Uint8List.fromList(input.prevTxid.reversed.toList()),
        prevIndex: input.prevIndex,
        pubkey: input.pubKey,
        amount: Int64(input.amount)
    );
    components.add(Tuple<Component, int>(comp, input.amount - fee));
  }

  for (Output output in outputs) {
    var script = output.addr.toScript(); // assuming addr.toScript() is a method that returns the scriptPubKey
    int fee = Util.componentFee(output.sizeOfOutput(), feerate);

    var comp = Component();
    comp.output = OutputComponent(
        scriptpubkey: script,  // assuming script is a List<int>
        amount: Int64(output.value)
    );
    components.add(Tuple<Component, int>(comp, -output.value - fee));
  }

  for (int i = 0; i < numBlanks; i++) {
    var comp = Component();
    comp.blank = BlankComponent();
    components.add(Tuple<Component, int>(comp, 0));
  }

  // Rest of the function logic will be implemented later
  return;
}



} //  END OF CLASS

