
import 'util.dart';
import 'connection.dart';
import 'fusion.dart';
import 'fusion.pb.dart';
import 'dart:io';
import 'dart:async';
import 'package:protobuf/protobuf.dart';

typedef PbCreateFunc = GeneratedMessage Function();

Map<Type, PbCreateFunc> pbClassCreators = {
  CovertResponse: () => CovertResponse(),
  // add other protobuf message classes here
};


Future<void> send_pb(Connection connection, GeneratedMessage msg, {Duration? timeout}) async {
  final msgBytes = msg.writeToBuffer();
  try {
    await connection.sendMessage(msgBytes, timeout: timeout);
  } on SocketException {
    throw FusionError('Connection closed by remote');
  } on TimeoutException {
    throw FusionError('Timed out during send');
  } catch (e) {
    throw FusionError('Communications error: ${e.runtimeType}: $e');
  }
}


Future<Tuple<GeneratedMessage, String>> recvPb(Connection connection, Type pbClass, List<String> expectedFieldNames, {Duration? timeout}) async {
  try {
    List<int> blob = await connection.recv_message(timeout: timeout);

    var pbMessage = pbClassCreators[pbClass]!()..mergeFromBuffer(blob);

    if (!pbMessage.isInitialized()) {
      throw FusionError('Incomplete message received');
    }

    for (var name in expectedFieldNames) {
      var fieldInfo = pbMessage.info_.byName[name];

      if (fieldInfo == null) {
        throw FusionError('Expected field not found in message: $name');
      }

      if (pbMessage.hasField(fieldInfo.tagNumber)) {
        return Tuple(pbMessage, name);
      }
    }

    throw FusionError('None of the expected fields found in the received message');

  } catch (e) {
    // Handle different exceptions here
    if (e is SocketException) {
      throw FusionError('Connection closed by remote');
    } else if (e is InvalidProtocolBufferException) {
      throw FusionError('Message decoding error: ' + e.toString());
    } else if (e is TimeoutException) {
      throw FusionError('Timed out during receive');
    } else if (e is OSError && e.errorCode == 9) {
      throw FusionError('Connection closed by local');
    } else {
      throw FusionError('Communications error: ${e.runtimeType}: ${e.toString()}');
    }
  }
}

