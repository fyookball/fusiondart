import 'dart:io';
import 'dart:async';
import 'dart:convert';
import 'dart:typed_data';
import 'package:convert/convert.dart';
import 'package:collection/collection.dart';

/*
This file might need some fixing up because each time we call fillBuf, we're trying to
remove data from a buffer but its a local copy , might not actually
remove the data from the socket buffer.  We may need a wrapper class for the buffer??

 */

class BadFrameError extends Error {
  final String message;

  BadFrameError(this.message);

  @override
  String toString() => message;
}

Future<Socket> openConnection(String host, int port,
    {double connTimeout = 5.0,
      double defaultTimeout = 5.0,
      bool ssl = false,
      dynamic socksOpts}) async {
  // Replace this with actual implementation later.
  return Future.error('openConnection not implemented yet');
}

class Connection {
  Duration timeout = Duration(seconds: 1);
  Socket? socket;

  static const int MAX_MSG_LENGTH = 200*1024;
  static final Uint8List magic = Uint8List.fromList([0x76, 0x5b, 0xe8, 0xb4, 0xe4, 0x39, 0x6d, 0xcf]);

  Future<void> sendMessage(List<int> msg, {Duration? timeout}) async {
    timeout ??= this.timeout;

    final lengthBytes = Uint8List(4);
    final byteData = ByteData.view(lengthBytes.buffer);
    byteData.setUint32(0, msg.length, Endian.big);

    final frame = <int>[]
      ..addAll(Connection.magic)
      ..addAll(lengthBytes)
      ..addAll(msg);

    try {
      socket?.add(frame);
      await socket?.flush();
    } on SocketException catch (e) {
      throw TimeoutException('Socket write timed out', timeout);
    }
  }


  void close() {
    socket?.close();
  }



  Future<List<int>> fillBuf(int n, {Duration? timeout}) async {
    final recvBuf = <int>[];
    final maxTime = timeout != null ? DateTime.now().add(timeout) : null;

    await for (var data in socket!.cast<List<int>>()) {
      if (maxTime != null && DateTime.now().isAfter(maxTime)) {
        throw SocketException('Timeout');
      }

      if (data.isEmpty) {
        if (recvBuf.isNotEmpty) {
          throw SocketException('Connection ended mid-message.');
        } else {
          throw SocketException('Connection ended while awaiting message.');
        }
      }

      recvBuf.addAll(data);

      if (recvBuf.length >= n) {
        break;
      }
    }

    return recvBuf;
  }

  Future<List<int>> recv_message({Duration? timeout}) async {
    if (timeout == null) {
      timeout = this.timeout;
    }

    final maxTime = timeout != null ? DateTime.now().add(timeout) : null;

    final recvBuf = await fillBuf(12, timeout: timeout);
    final magic = recvBuf.sublist(0, 8);

    if (!ListEquality().equals(magic, Connection.magic)) {
      throw BadFrameError('Bad magic in frame: ${hex.encode(magic)}');
    }

    final byteData = ByteData.view(Uint8List.fromList(recvBuf.sublist(8, 12)).buffer);
    final messageLength = byteData.getUint32(0, Endian.big);

    if (messageLength > MAX_MSG_LENGTH) {
      throw BadFrameError('Got a frame with msg_length=$messageLength > $MAX_MSG_LENGTH (max)');
    }

    final fullRecvBuf = await fillBuf(12 + messageLength, timeout: timeout);

    // We have a complete message
    final message = fullRecvBuf.sublist(12, 12 + messageLength);


    return message;
  }
} // END OF CLASS
