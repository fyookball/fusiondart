
import 'dart:convert';
import 'dart:math';
import 'fusion.pb.dart';

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


static void genComponents() {

/*
WIP----


List<Component> components = [];
for (var input in inputs.entries) {
  var phash = input.key[0];
  var pn = input.key[1];
  var pubkey = input.value[0];
  var value = input.value[1];

  var fee = componentFee(sizeOfInput(pubkey), feerate);

  var comp = Component();

  // Assuming that phash and pubkey are hexadecimal strings.
  comp.input.prevTxid = hex.decode(phash).reversed.toList();
  comp.input.prevIndex = pn;
  comp.input.pubkey = hex.decode(pubkey);
  comp.input.amount = Int64(value);

  components.add(comp);
}


// WIP.  Inputs will be something like Map<List<String>, List<dynamic>> 
// phash and pubkey are hexadecimal strings?
// we also need helper funcionts   componentFee() and sizeOfInput()  
 //Int64 comes from the fixnum package, which we need to import.


//---

*/

return;
}





} //  END OF CLASS

