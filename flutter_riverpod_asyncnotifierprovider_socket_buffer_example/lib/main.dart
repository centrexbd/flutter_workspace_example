import 'dart:io';
import 'dart:async';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

// nc -l 12345

final tcpClientProvider = AsyncNotifierProvider<TcpClientNotifier, TcpClient>(
    () => TcpClientNotifier());

class TcpClientNotifier extends AsyncNotifier<TcpClient> {
  late TcpClient _tcpClient;
  bool connected = false;

  TcpClientNotifier() {
    _initializeTcpClient();
  }

  Future<void> _initializeTcpClient() async {
    _tcpClient = await TcpClient.connect(host: '127.0.0.1', port: 12345);
    // Update the state with the connected TcpClient.
    state = AsyncData(_tcpClient);
    connected = true;
  }

  @override
  FutureOr<TcpClient> build() async {
    return _tcpClient;
  }

  Future<void> connectToServer(String host, int port) async {
    if (!connected) {
      state = AsyncLoading();
      try {
        var tcpClient = await TcpClient.connect(host: '127.0.0.1', port: 12345);
        _tcpClient = tcpClient;
        state = AsyncData(tcpClient);
        connected = true; // Update the connected status
      } catch (error, stackTrace) {
        state = AsyncError(error, stackTrace);
      }
    }
  }

  Future<void> disconnectFromServer() async {
    if (connected) {
      await _tcpClient.disconnectFromServer();
      state = AsyncData(_tcpClient);
      connected = false;
    }
  }

  Future<void> sendData(String data) async {
    if (connected) {
      await _tcpClient.sendData(data);
    } else {
      print('Error: TcpClient is not properly initialized.');
    }
  }
}

class TcpClient {
  late Socket socket;
  late StringBuffer buffer = StringBuffer();

  TcpClient(this.socket);

  static Future<TcpClient> connect(
      {required String host, required int port}) async {
    var socket = await Socket.connect(host, port);
    var client = TcpClient(socket);
    return client;
  }

  Future<void> connectToServer(String host, int port) async {
    socket = await Socket.connect(host, port);
    socket.listen(
      (List<int> data) {
        final receivedString = String.fromCharCodes(data);
        buffer.write(receivedString);
      },
      onDone: () {
        socket.destroy();
      },
      onError: (error) {
        print('Error: $error');
      },
    );
  }

  Future<void> disconnectFromServer() async {
    await socket.close();
  }

  Future<void> sendData(String data) async {
    socket.write(data);
  }
}

void main() {
  runApp(ProviderScope(child: MyApp()));
}

class MyApp extends StatelessWidget {
  final TextEditingController _dataController = TextEditingController();

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      home: Scaffold(
        appBar: AppBar(
          title: Text('TCP Buffer Example'),
        ),
        body: Center(
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: <Widget>[
              Consumer(
                builder: (context, ref, child) {
                  final asyncValue = ref.watch(tcpClientProvider);

                  if (asyncValue is AsyncValue<TcpClient>) {
                    final isConnected =
                        ref.read(tcpClientProvider.notifier).connected;

                    if (!isConnected) {
                      return ElevatedButton(
                        onPressed: () {
                          ref
                              .read(tcpClientProvider.notifier)
                              .connectToServer('127.0.0.1', 12345);
                        },
                        child: Text('Connect to Server'),
                      );
                    } else {
                      return Column(children: <Widget>[
                        ElevatedButton(
                          onPressed: () {
                            ref
                                .read(tcpClientProvider.notifier)
                                .disconnectFromServer();
                          },
                          child: Text('Disconnect from Server'),
                        ),
                        asyncValue.when(
                          loading: () => CircularProgressIndicator(),
                          error: (error, stackTrace) => Text('Error: $error'),
                          data: (tcpClient) {
                            final bufferData = tcpClient.buffer.toString();
                            return Padding(
                              padding: EdgeInsets.all(16),
                              child: Text('Buffered Data: $bufferData'),
                            );
                          },
                        ),
                        SizedBox.shrink(),
                      ]);
                    }
                  } else {
                    return Text("not asyncvalue<tcpclient>");
                  }
                },
              ),
              TextField(
                controller: _dataController,
                decoration: InputDecoration(labelText: 'Enter Data'),
              ),
              Consumer(builder: (context, ref, child) {
                return ElevatedButton(
                  onPressed: () {
                    final String data = _dataController.text;
                    if (data.isNotEmpty) {
                      ref.read(tcpClientProvider.notifier).sendData(data);
                      _dataController.clear();
                    } else {
                      ScaffoldMessenger.of(context).showSnackBar(SnackBar(
                        content: Text('Please enter data to send.'),
                      ));
                    }
                  },
                  child: Text('Send Data'),
                );
              }),
            ],
          ),
        ),
      ),
    );
  }
}
