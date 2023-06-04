
import 'package:protobuf/protobuf.dart';
import 'dart:convert';
import 'dart:math';
import 'fusion.pb.dart';
import 'util.dart';
import 'dart:typed_data';
import 'package:fixnum/fixnum.dart';
import 'pedersen.dart';
import 'dart:io';
import 'package:crypto/crypto.dart';
import 'dart:async';
import 'comms.dart';
import 'protocol.dart';

import "package:pointycastle/export.dart";
import 'covert.dart';
import 'connection.dart';

class FusionError implements Exception {
  final String message;
  FusionError(this.message);
  String toString() => "FusionError: $message";
}


class ComponentResult {
  final Uint8List commitment;
  final int counter;
  final Uint8List component;
  final Proof proof;
  final Uint8List privateKey;

  ComponentResult(this.commitment, this.counter, this.component, this.proof, this.privateKey);
}



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

  int get value {
    return amount;
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

  List<Input> coins = [];
  List<Output> outputs =[];
  bool server_connected_and_greeted = false;
  bool stopping = false;
  bool stopping_if_not_running = false;
  String stopReason="";
  String tor_host="";
  String server_host ="";
  bool server_ssl= false;
  int server_port = 0;
  int tor_port = 0;
  int roundcount = 0;
  String txid="";

    Tuple<String, String> status = Tuple("", "");
  Connection? connection;

  int numComponents =0;
  double componentFeerate=0;
  double minExcessFee=0;
  double maxExcessFee=0;
  List<int> availableTiers =[];

  int maxOutputs=0;
  int safety_sum_in =0;
  Map<int, int> safety_exess_fees = {};


  Map<int, List<int>> tierOutputs ={};

  Future<void> initializeConnection(String host, int port) async {
    Socket socket = await Socket.connect(host, port);
    connection = Connection()..socket = socket;
  }


  Future<void> fusion_run() async {

    try {

      try {

        // Check compatibility  - This was done in python version to see if fast libsec installed.
        // For now , in dart, just pass this test.
        ;
      } on Exception catch(e) {
        // handle exception, rethrow as a custom FusionError
        throw FusionError("Incompatible: " + e.toString());
      }

      // Check if can connect to Tor proxy, if not, raise FusionError. Empty String treated as no host.
      if (tor_host.isNotEmpty && tor_port != 0 && !is_tor_port(tor_host, tor_port)) {
        throw FusionError("Can't connect to Tor proxy at $tor_host:$tor_port");
      }
      // Check stop condition
     check_stop(running: false);

      // Check coins
      check_coins();

      // Connect to server
      status = Tuple("connecting", "");
      try {
        Socket socket = await openConnection(server_host, server_port, connTimeout: 5.0, defaultTimeout: 5.0, ssl: server_ssl);
        connection = Connection()..socket = socket;
      }  catch (e) {
        print("Connect failed: $e");
        String sslstr = server_ssl ? ' SSL ' : '';
        throw FusionError('Could not connect to $sslstr$server_host:$server_port');
      }


      // Once connection is successful, wrap operations inside this block
      // Within this block, version checks, downloads server params, handles coins and runs rounds
      try {
        // Version check and download server params.
        greet();

        server_connected_and_greeted = true;
        notify_server_status(true);

        // In principle we can hook a pause in here -- user can insert coins after seeing server params.

        if (coins.isEmpty) {
          throw FusionError('Started with no coins');
        }
        allocate_outputs();

        // In principle we can hook a pause in here -- user can tweak tier_outputs, perhaps cancelling some unwanted tiers.

        // Register for tiers, wait for a pool.
        register_and_wait();

        // launch the covert submitter
        CovertSubmitter covert = await start_covert();
        try {
          // Pool started. Keep running rounds until fail or complete.
          while (true) {
            roundcount += 1;
            if (await run_round(covert)) {
              break;
            }
          }
        } finally {
          covert.stop();
        }
      } finally {
        (await connection)?.close();
      }

      for (int i = 0; i < 60; i++) {
        if (stopping) {
          break; // not an error
        }

        if (Util.walletHasTransaction(txid)) {
          break;
        }

        await Future.delayed(Duration(seconds: 1));
      }

      // Set status to 'complete' with 'time_wait'
      status = Tuple('complete', 'txid: $txid');

      // Wait for transaction to show up in wallets
      // Set status to 'complete' with txid

    } on FusionError catch(err) {
      print('Failed: ${err}');
      status.item1 = "failed";
      status.item2 = err.toString();  // setting the error message
    } catch(exc) {
      print('Exception: ${exc}');
      status.item1 = "failed";
      status.item2= "Exception: ${exc.toString()}";  // setting the exception message
    } finally {
      clear_coins();
      if (status.item1 != 'complete') {
        for (var output in outputs) {
          Util.unreserve_change_address(output.addr);
        }
        if (!server_connected_and_greeted) {
          notify_server_status(false, tup: status);
        }
      }
    }


  }  // end fusion_run function.



  void allocate_outputs() {
  }

  void register_and_wait() {
  }

  Future<CovertSubmitter> start_covert() async {
    // Function implementation here...

    // For now, just return a new instance of CovertSubmitter
    return CovertSubmitter();
  }


  Future<bool> run_round(CovertSubmitter covert) async {
    // function implementation here...

    // placeholder return statement
    return Future.value(false);
  }

  void notify_server_status(bool b, {Tuple? tup}) {
    // Function implementation goes here
  }


  void stop([String reason = 'stopped', bool notIfRunning = false]) {
    if (stopping) {
      return;
    }
    if (notIfRunning) {
      if (stopping_if_not_running) {
        return;
      }
      stopReason = reason;
      stopping_if_not_running = true;
    } else {
      stopReason = reason;
      stopping = true;
    }
    // note the reason is only overwritten if we were not already stopping this way.
  }

  void check_stop({bool running = true}) {
    // Gets called occasionally from fusion thread to allow a stop point.
    if (stopping || (!running && stopping_if_not_running)) {
      throw FusionError(stopReason ?? 'Unknown stop reason');
    }
  }

void check_coins() {
    // Implement by calling wallet layer to check the coins are ok.
    return;
}

  static void foo() {
print ("hello");
}

 void clear_coins() {
    coins = [];
 }

  void addCoins(List<Input> newCoins) {
    coins.addAll(newCoins);
  }

  void notify_coins_UI() {
    return;
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


static List<ComponentResult> genComponents(int numBlanks, List<Input> inputs, List<Output> outputs, int feerate) {
  assert(numBlanks >= 0);

  List<Tuple<Component, int>> components = [];

  // Set up Pedersen setup instance
  Uint8List HBytes = Uint8List.fromList([0x02] + 'CashFusion gives us fungibility.'.codeUnits);
  ECDomainParameters params = ECDomainParameters('secp256k1');
  ECPoint? HMaybe = params.curve.decodePoint(HBytes);
  if (HMaybe == null) {
    throw Exception('Failed to decode point');
  }
  ECPoint H = HMaybe;
  PedersenSetup setup = PedersenSetup(H);

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
    var script = output.addr.toScript();
    int fee = Util.componentFee(output.sizeOfOutput(), feerate);

    var comp = Component();
    comp.output = OutputComponent(
        scriptpubkey: script,
        amount: Int64(output.value)
    );
    components.add(Tuple<Component, int>(comp, -output.value - fee));
  }

  for (int i = 0; i < numBlanks; i++) {
    var comp = Component();
    comp.blank = BlankComponent();
    components.add(Tuple<Component, int>(comp, 0));
  }

  List<ComponentResult> resultList = [];

  components.asMap().forEach((cnum, Tuple<Component, int> componentTuple) {
    Uint8List salt = Util.tokenBytes(32);
    componentTuple.item1.saltCommitment = Util.sha256(salt);
    var compser = componentTuple.item1.writeToBuffer();

    Tuple<Uint8List, Uint8List> keyPair = Util.genKeypair();
    Uint8List privateKey = keyPair.item1;
    Uint8List pubKey = keyPair.item2;

    Commitment commitmentInstance = setup.commit(BigInt.from(componentTuple.item2));
    Uint8List amountCommitment = commitmentInstance.PUncompressed;


// Convert BigInt nonce to Uint8List
    Uint8List pedersenNonce = Uint8List.fromList([int.parse(commitmentInstance.nonce.toRadixString(16), radix: 16)]);

// Generating initial commitment
    InitialCommitment commitment = InitialCommitment(
        saltedComponentHash: Util.sha256(Uint8List.fromList([...compser, ...salt])),
        amountCommitment: amountCommitment,
        communicationKey: pubKey
    );

    Uint8List commitser = commitment.writeToBuffer();

    // Generating proof
    Proof proof = Proof(
        componentIdx: cnum,
        salt: salt,
        pedersenNonce: pedersenNonce
    );

    // Adding result to list
    resultList.add(ComponentResult(commitser, cnum, compser, proof, privateKey));
  });

  return resultList;
}

  Future<GeneratedMessage> recv(List<String> expectedMsgNames, {Duration? timeout}) async {
    if (connection == null) {
      throw FusionError('Connection not initialized');
    }

    var result = await recvPb(
        connection!,
        ServerMessage,  // this is the changed line
        expectedMsgNames,
        timeout: timeout
    );

    var submsg = result.item1;
    var mtype = result.item2;

    if (mtype == 'error') {
      throw FusionError('server error: ${submsg.toString()}');
    }

    return submsg;
  }

  void send(GeneratedMessage submsg, {Duration? timeout}) {
    send_pb(connection!, submsg, timeout: timeout);
  }

  void greet() async {
    print('greeting server');
    send(ClientHello(version: utf8.encode(Protocol.VERSION), genesisHash: Util.get_current_genesis_hash()));
    ServerHello reply = await recv(['serverhello']) as ServerHello;

    numComponents = reply.numComponents;
    componentFeerate = reply.componentFeerate.toDouble();
    minExcessFee = reply.minExcessFee.toDouble();
    maxExcessFee = reply.maxExcessFee.toDouble();
    availableTiers = List<int>.from(reply.tiers);

    // Enforce some sensible limits, in case server is crazy
    if (componentFeerate > Protocol.MAX_COMPONENT_FEERATE) {
      throw FusionError('excessive component feerate from server');
    }
    if (minExcessFee > 400) { // note this threshold should be far below MAX_EXCESS_FEE
      throw FusionError('excessive min excess fee from server');
    }
    if (minExcessFee > maxExcessFee) {
      throw FusionError('bad config on server: fees');
    }
    if (numComponents < Protocol.MIN_TX_COMPONENTS * 1.5) {
      throw FusionError('bad config on server: num_components');
    }
  }

  void allocateOutputs() {
    assert(['setup', 'connecting'].contains(status.item1));

    List<Input> inputs = coins;
    int numInputs = inputs.length;

    int maxComponents = min(numComponents, Protocol.MAX_COMPONENTS);
    int maxOutputs = maxComponents - numInputs;
    if (maxOutputs < 1) {
      throw FusionError('Too many inputs ($numInputs >= $maxComponents)');
    }

    if (maxOutputs != null) {
      assert(maxOutputs >= 1);
      maxOutputs = min(maxOutputs, maxOutputs);
    }

    int numDistinct = inputs.map((e) => e.value).toSet().length;
    int minOutputs = max(Protocol.MIN_TX_COMPONENTS - numDistinct, 1);
    if (maxOutputs < minOutputs) {
      throw FusionError('Too few distinct inputs selected ($numDistinct); cannot satisfy output count constraint (>= $minOutputs, <= $maxOutputs)');
    }

    int sumInputsValue = inputs.map((e) => e.value).reduce((a, b) => a + b);
    int inputFees = inputs.map((e) => Util.componentFee(e.sizeOfInput(), componentFeerate.toInt())).reduce((a, b) => a + b);
    int availForOutputs = sumInputsValue - inputFees - minExcessFee.toInt();

    int feePerOutput = Util.componentFee(34, componentFeerate.toInt());

    int offsetPerOutput = Protocol.MIN_OUTPUT + feePerOutput;

    if (availForOutputs < offsetPerOutput) {
      throw FusionError('Selected inputs had too little value');
    }

    var rng = Random();
    var seed = List<int>.generate(32, (_) => rng.nextInt(256));

    tierOutputs = {};
    var excessFees = <int, int>{};
    for (var scale in availableTiers) {
      int fuzzFeeMax = scale ~/ 1000000;
      int fuzzFeeMaxReduced = min(fuzzFeeMax, min(Protocol.MAX_EXCESS_FEE - minExcessFee.toInt(), maxExcessFee.toInt()));

      assert(fuzzFeeMaxReduced >= 0);
      int fuzzFee = rng.nextInt(fuzzFeeMaxReduced + 1);

      int reducedAvailForOutputs = availForOutputs - fuzzFee;
      if (reducedAvailForOutputs < offsetPerOutput) {
        continue;
      }

      var outputs = randomOutputsForTier(rng, reducedAvailForOutputs, scale, offsetPerOutput, maxOutputs);
      if (outputs == null || outputs.length < minOutputs) {
        continue;
      }
      outputs = outputs.map((o) => o - feePerOutput).toList();

      assert(inputs.length + (outputs?.length ?? 0) <= Protocol.MAX_COMPONENTS);
      excessFees[scale] = sumInputsValue - inputFees - reducedAvailForOutputs;
      tierOutputs[scale] = outputs!;
    }

    print('Possible tiers: $tierOutputs');

    safety_sum_in = sumInputsValue;
    safety_exess_fees = excessFees;
  }



} //  END OF CLASS

