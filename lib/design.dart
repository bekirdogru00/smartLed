import 'package:flutter/material.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'mqtt_service.dart'; // MqttService'i import ediyoruz
import 'smartlight_design.dart'; // SmartlightDesign sayfasını içe aktardık

class Design extends StatefulWidget {
  const Design({super.key});

  @override
  State<Design> createState() => _DesignState();
}

class _DesignState extends State<Design> {
 String selectedRoom = "";
 bool isSmartLightOn = false;
 bool isSmartACOn = false;
 List<String> devices = [];
 Map<String, dynamic> sensorData = {};
  TextEditingController newDeviceController = TextEditingController();
 late MqttService mqttService;
  @override
   void initState() {
        super.initState();
        mqttService = MqttService();
        _initializeMqtt();
        _loadSelectedRoom();
     }
      Future<void> _initializeMqtt() async {
        print('MQTT başlatılıyor...');
        bool connected = await mqttService.initialize();
        if (connected) {
           print('MQTT bağlantısı başarılı');
           mqttService.listenToMessages((topic, message) {
              print('MQTT mesajı alındı: $topic -> $message');
              
              // Sensör verilerini işle
              if (topic == "smartlight/sensorData") {
                 _processSensorData(message);
              }
           });
        } else {
           print('MQTT bağlantısı başarısız!');
           // 5 saniye sonra tekrar dene
           Future.delayed(const Duration(seconds: 5), () {
              _initializeMqtt();
           });
        }
     }
  void _processSensorData(String message) {
     try {
        Map<String, String> newData = {};
        List<String> pairs = message.split(", ");
        
        for (String pair in pairs) {
           List<String> keyValue = pair.split(": ");
           if (keyValue.length == 2) {
              String key = keyValue[0].trim();
              String value = keyValue[1].trim();
              // Birimleri temizle
              value = value.replaceAll("C", "").replaceAll("%", "").replaceAll("cm", "");
              newData[key] = value;
           }
        }
         setState(() {
           sensorData = newData;
        });
        print('Sensör verileri güncellendi: $sensorData');
     } catch (e) {
        print('Sensör verisi işleme hatası: $e');
     }
  }
   Future<void> _loadPreferences() async {
     SharedPreferences prefs = await SharedPreferences.getInstance();
     setState(() {
        isSmartLightOn = prefs.getBool('${selectedRoom}_isSmartLightOn') ?? false;
        isSmartACOn = prefs.getBool('${selectedRoom}_isSmartACOn') ?? false;
        devices = prefs.getStringList('${selectedRoom}_devices') ?? [];
     });
  }
   Future<void> _savePreferences() async {
     SharedPreferences prefs = await SharedPreferences.getInstance();
     await prefs.setBool('${selectedRoom}_isSmartLightOn', isSmartLightOn);
     await prefs.setBool('${selectedRoom}_isSmartACOn', isSmartACOn);
     await prefs.setStringList('${selectedRoom}_devices', devices);
  }
   Future<void> _loadSelectedRoom() async {
     SharedPreferences prefs = await SharedPreferences.getInstance();
     setState(() {
        selectedRoom = prefs.getString('selectedRoom') ?? 'Oturma odası';
     });
     await _loadPreferences();
  }
   Future<void> _changeRoom(String roomName) async {
     await _savePreferences();
     SharedPreferences prefs = await SharedPreferences.getInstance();
     await prefs.setString('selectedRoom', roomName);
     setState(() {
        selectedRoom = roomName;
     });
     await _loadPreferences();
  }
   void _addNewDevice() {
     if (newDeviceController.text.isNotEmpty) {
        setState(() {
           devices.add(newDeviceController.text);
           newDeviceController.clear();
        });
        _savePreferences();
     }
  }
   void _toggleSmartLight() {
     print('\n=== LED Kontrol ===');
     print('Mevcut durum: ${isSmartLightOn ? 'AÇIK' : 'KAPALI'}');
     
     setState(() {
        isSmartLightOn = !isSmartLightOn;
     });
     
     print('Yeni durum: ${isSmartLightOn ? 'AÇIK' : 'KAPALI'}');
     print('MQTT mesajı gönderiliyor...');
     
     mqttService.sendMessage(
        "smartlight/control", 
        isSmartLightOn ? "on" : "off"
     );
     
     print('İşlem tamamlandı');
     print('==================\n');
  }
  @override
 Widget build(BuildContext context) {
   return Scaffold(
     appBar: AppBar(
       title: const Column(
         children: [
           SizedBox(height: 40),
           Row(
             mainAxisAlignment: MainAxisAlignment.start,
             crossAxisAlignment: CrossAxisAlignment.center,
             children: [
               Text(
                 "Merhaba, İSİM",
                 style: TextStyle(fontWeight: FontWeight.bold),
               ),
               SizedBox(width: 10),
             ],
           ),
         ],
       ),
     ),
     body: SingleChildScrollView(
       child: Padding(
         padding: const EdgeInsets.all(16.0),
         child: Column(
           mainAxisAlignment: MainAxisAlignment.start,
           crossAxisAlignment: CrossAxisAlignment.center,
           children: [
             const SizedBox(height: 30),
             Row(
               mainAxisAlignment: MainAxisAlignment.center,
               children: [
                 _buildRoomSelector("Oturma odası"),
                 const SizedBox(width: 20),
                 _buildRoomSelector("Mutfak"),
                 const SizedBox(width: 20),
                 _buildRoomSelector("Yatak Odası"),
               ],
             ),
             const SizedBox(height: 30),
             
             // Sensör verileri gösterimi
             if (sensorData.isNotEmpty) ...[
               Container(
                 padding: const EdgeInsets.all(16),
                 decoration: BoxDecoration(
                   color: Colors.grey[200],
                   borderRadius: BorderRadius.circular(10),
                 ),
                 child: Column(
                   crossAxisAlignment: CrossAxisAlignment.start,
                   children: [
                     Text("Sıcaklık: ${sensorData['Temperature'] ?? 'N/A'}"),
                     Text("Nem: ${sensorData['Humidity'] ?? 'N/A'}"),
                     Text("Mesafe: ${sensorData['Distance'] ?? 'N/A'}"),
                   ],
                 ),
               ),
               const SizedBox(height: 20),
             ],
              // Smart Light kontrolü
             GestureDetector(
               onTap: () {
                 _toggleSmartLight();
                 if (isSmartLightOn) {
                   Navigator.push(
                     context,
                     MaterialPageRoute(
                       builder: (context) => const SmartlightDesign(),
                     ),
                   );
                 }
               },
               child: Container(
                 padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 100),
                 decoration: BoxDecoration(
                   color: isSmartLightOn
                       ? const Color.fromARGB(255, 107, 97, 5)
                       : Colors.grey,
                   borderRadius: BorderRadius.circular(40),
                 ),
                 child: Row(
                   children: [
                     const SizedBox(width: 20),
                     Text(
                       "Smart Light ${isSmartLightOn ? "Açık" : "Kapalı"}",
                       style: const TextStyle(
                         color: Colors.white,
                         fontWeight: FontWeight.bold,
                       ),
                     ),
                   ],
                 ),
               ),
             ),
              const SizedBox(height: 20),
              // Smart AC kontrolü
             GestureDetector(
               onTap: () {
                 setState(() {
                   isSmartACOn = !isSmartACOn;
                 });
                 _savePreferences();
               },
               child: Container(
                 padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 100),
                 decoration: BoxDecoration(
                   color: isSmartACOn ? Colors.blue : Colors.grey,
                   borderRadius: BorderRadius.circular(40),
                 ),
                 child: Row(
                   children: [
                     const SizedBox(width: 20),
                     Text(
                       "Smart AC ${isSmartACOn ? "Açık" : "Kapalı"}",
                       style: const TextStyle(
                         color: Colors.white,
                         fontWeight: FontWeight.bold,
                       ),
                     ),
                   ],
                 ),
               ),
             ),
              const SizedBox(height: 30),
              // Yeni cihaz ekleme
             Padding(
               padding: const EdgeInsets.symmetric(horizontal: 20),
               child: Row(
                 children: [
                   Expanded(
                     child: TextField(
                       controller: newDeviceController,
                       decoration: const InputDecoration(
                         labelText: 'Yeni cihaz adı girin',
                         border: OutlineInputBorder(),
                       ),
                     ),
                   ),
                   IconButton(
                     icon: const Icon(Icons.add),
                     onPressed: _addNewDevice,
                   ),
                 ],
               ),
             ),
              const SizedBox(height: 20),
              // Cihaz listesi
             ...devices.map((device) {
               return Padding(
                 padding: const EdgeInsets.symmetric(vertical: 5),
                 child: Chip(
                   label: Text(device),
                   deleteIcon: const Icon(Icons.delete),
                   onDeleted: () {
                     setState(() {
                       devices.remove(device);
                     });
                     _savePreferences();
                   },
                 ),
               );
             }).toList(),
           ],
         ),
       ),
     ),
   );
 }
  Widget _buildRoomSelector(String roomName) {
   return GestureDetector(
     onTap: () => _changeRoom(roomName),
     child: Column(
       children: [
         Text(
           roomName,
           style: TextStyle(
             fontWeight:
                 selectedRoom == roomName ? FontWeight.bold : FontWeight.w100,
           ),
         ),
         if (selectedRoom == roomName)
           Container(
             margin: const EdgeInsets.only(top: 5),
             height: 2,
             width: 80,
             color: Colors.black,
           ),
       ],
     ),
   );
 }
}