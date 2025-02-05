import 'dart:async';
import 'package:web_socket_channel/web_socket_channel.dart';

class RoomController {
  static final RoomController _instance = RoomController._internal();
  late WebSocketChannel _channel;
  late String _roomCode;
  StreamController<String> _eventController =
      StreamController<String>.broadcast();
  Timer? _keepAliveTimer;

  factory RoomController() {
    return _instance;
  }

  RoomController._internal();

  // Initialize the WebSocket connection with the room code
  void connect(
      String roomCode, StreamController<String> passedEventReceiver) async {
    _roomCode = roomCode;
    _eventController = passedEventReceiver;

    final uri =
        Uri.parse('wss://openRave.zeitvertreib.vip/backend/?room=$_roomCode');
    _channel = WebSocketChannel.connect(uri);

    // Listen for incoming messages immediately
    _channel.stream.listen(
      (message) {
        _eventController.add("alive");
        _handleMessage(message);
      },
      onError: (error) {
        print('WebSocket error: $error');
        _eventController.add("error");
      },
      onDone: () {
        print('WebSocket connection closed');
        _eventController.add("closed");
      },
      cancelOnError: true, // Ensures errors don't leave a hanging connection
    );

    // Start keepalive to maintain connection
    _startKeepAlive();
  }

  // Send a play command to the server
  void play() {
    _sendMessage('playing');
  }

  // Send a pause command to the server
  void pause() {
    _sendMessage('paused');
  }

  // Send a seek command to the server with the desired timestamp
  void seek(double timestampInSeconds) {
    _sendMessage('seek: $timestampInSeconds');
  }

  // Close the WebSocket connection and event controller
  void dispose() {
    _channel.sink.close();
    _eventController.close();
    _keepAliveTimer?.cancel();
  }

  // Send a message to the server
  void _sendMessage(String message) {
    _channel.sink.add(message);
  }

  // Handle incoming messages from the server
  void _handleMessage(String message) {
    if (message.startsWith('videoId: ')) {
      _eventController.add(message);
    } else if (message.startsWith('seek: ')) {
      _eventController.add(message);
    } else if (message == 'playing') {
      _eventController.add(message);
    } else if (message == 'paused') {
      _eventController.add(message);
    } else if (message.startsWith('catchUp: ')) {
      //"catchUp: uMkBuxEDkyg 104.7096185064935"
      _eventController.add(message);
      print('received a catchUp message');
    }
    print('Received message: $message');
  }

  // Keepalive function to send periodic "keepalive" messages
  void _startKeepAlive() {
    _keepAliveTimer = Timer.periodic(Duration(seconds: 15), (timer) {
      _sendMessage('keepalive');
    });
  }
}
