import 'dart:io';
import 'package:mqtt_client/mqtt_client.dart';
import 'package:mqtt_client/mqtt_server_client.dart';

class MqttService {
  late MqttServerClient client;
  bool isConnected = false;
  int reconnectAttempts = 0;
  static const int maxReconnectAttempts = 3;

  final String broker = '8b25e7c8fa7f43ddbfd68b4553830dd2.s1.eu.hivemq.cloud';
  final int port = 8883;
  final String username = 'bekirdgr';
  final String password = 'Bekirdgr2';

  Future<bool> initialize() async {
    try {
      final clientId = 'flutter_${DateTime.now().millisecondsSinceEpoch}';
      
      client = MqttServerClient.withPort(broker, clientId, port);
      
      client.onConnected = _onConnected;
      client.onDisconnected = _onDisconnected;
      client.onSubscribed = _onSubscribed;
      client.onSubscribeFail = _onSubscribeFail;
      client.pongCallback = _pong;
      client.secure = true;

      client.securityContext = SecurityContext.defaultContext;
      client.onBadCertificate = (Object certificate) => true;

      client.logging(on: true);
      client.keepAlivePeriod = 60;
      client.connectTimeoutPeriod = 5000;
      client.autoReconnect = true;
      client.resubscribeOnAutoReconnect = true;
      
      final connMessage = MqttConnectMessage()
          .withClientIdentifier(clientId)
          .authenticateAs(username, password)
          .withWillTopic('willtopic')
          .withWillMessage('Client disconnecting')
          .withWillQos(MqttQos.atLeastOnce)
          .withWillRetain()
          .startClean();

      print('MQTT Broker\'a bağlanılıyor...');
      client.connectionMessage = connMessage;

      try {
        await client.connect();
        return _checkConnection();
      } catch (e) {
        print('Bağlantı hatası: $e');
        return await _handleReconnect();
      }

    } catch (e) {
      print('MQTT Hatası: $e');
      return false;
    }
  }

  Future<bool> _handleReconnect() async {
    if (reconnectAttempts < maxReconnectAttempts) {
      reconnectAttempts++;
      print('Yeniden bağlanma denemesi: $reconnectAttempts');
      await Future.delayed(Duration(seconds: reconnectAttempts * 2));
      return initialize();
    } else {
      print('Maksimum yeniden bağlanma denemesi aşıldı');
      return false;
    }
  }

  bool _checkConnection() {
    if (client.connectionStatus!.state == MqttConnectionState.connected) {
      print('Broker\'a bağlandı');
      isConnected = true;
      reconnectAttempts = 0;
      _subscribeToTopics();
      return true;
    } else {
      print('Bağlantı başarısız: ${client.connectionStatus!.returnCode}');
      return false;
    }
  }

  void _onConnected() {
    print('>> Broker\'a bağlandı');
    isConnected = true;
  }

  void _onDisconnected() {
    print('>> Broker bağlantısı kesildi');
    isConnected = false;
  }

  void _onSubscribed(String topic) {
    print('>> Topic\'e abone olundu: $topic');
  }

  void _onSubscribeFail(String topic) {
    print('>> Topic aboneliği başarısız: $topic');
  }

  void _pong() {
    print('>> Ping yanıtı alındı');
  }

  void _subscribeToTopics() {
    if (isConnected) {
      client.subscribe("smartlight/control", MqttQos.atLeastOnce);
      client.subscribe("smartlight/status", MqttQos.atLeastOnce);
      client.subscribe("smartlight/sensorData", MqttQos.atLeastOnce);
      client.subscribe("smartlight/color", MqttQos.atLeastOnce);
      client.subscribe("smartlight/brightness", MqttQos.atLeastOnce);
      client.subscribe("smartlight/tone", MqttQos.atLeastOnce);
      print('Topic\'lere abone olundu');
    }
  }

  bool sendMessage(String topic, String message) {
    if (!isConnected) {
      print('MQTT bağlantısı yok!');
      return false;
    }

    try {
      final builder = MqttClientPayloadBuilder();
      builder.addString(message);
      
      print('Mesaj gönderiliyor: $topic -> $message');
      client.publishMessage(topic, MqttQos.atLeastOnce, builder.payload!);
      print('Mesaj gönderildi');
      return true;
    } catch (e) {
      print('Mesaj gönderme hatası: $e');
      return false;
    }
  }

  void listenToMessages(Function(String, String) onMessageReceived) {
    client.updates?.listen((List<MqttReceivedMessage<MqttMessage>> c) {
      final recMess = c[0].payload as MqttPublishMessage;
      final message = MqttPublishPayload.bytesToStringAsString(recMess.payload.message);
      print('Mesaj alındı: ${c[0].topic} -> $message');
      onMessageReceived(c[0].topic, message);
    });
  }

  void _disconnect() {
    try {
      client.disconnect();
    } catch (e) {
      print('Bağlantı kesme hatası: $e');
    }
    isConnected = false;
  }

  void disconnect() {
    _disconnect();
    print('MQTT bağlantısı kapatıldı');
  }

  void unsubscribe(String topic) {
    if (client?.connectionStatus?.state == MqttConnectionState.connected) {
      print('MQTT: $topic konusundan abonelik kaldırılıyor');
      client?.unsubscribe(topic);
    }
  }
}
