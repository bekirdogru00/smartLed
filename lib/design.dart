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
    print('İşlenen sensör verisi: $message');
    
    // Regex ile değerleri ayıklama
    RegExp tempRegex = RegExp(r'Temperature: ([\d.]+)C');
    RegExp humRegex = RegExp(r'Humidity: ([\d.]+)%');
    RegExp distRegex = RegExp(r'Distance: ([\d.]+)cm');

    String? temp = tempRegex.firstMatch(message)?.group(1);
    String? hum = humRegex.firstMatch(message)?.group(1);
    String? dist = distRegex.firstMatch(message)?.group(1);

    setState(() {
      sensorData = {
        'Temperature': temp != null ? '$temp°C' : 'N/A',
        'Humidity': hum != null ? '$hum%' : 'N/A',
        'Distance': dist != null ? '${dist}cm' : 'N/A'
      };
    });

    print('Güncellenmiş sensör verileri: $sensorData');
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
     backgroundColor: Colors.grey[50],
     appBar: AppBar(
       elevation: 0,
       backgroundColor: Colors.white,
       title: const Column(
         children: [
           SizedBox(height: 40),
           Row(
             mainAxisAlignment: MainAxisAlignment.start,
             crossAxisAlignment: CrossAxisAlignment.center,
             children: [
               Text(
                 "Akıllı Ev Kontrolü",
                 style: TextStyle(
                   color: Colors.black87,
                   fontSize: 20,
                   fontWeight: FontWeight.w500,
                 ),
               ),
             ],
           ),
         ],
       ),
     ),
     body: SingleChildScrollView(
       child: Padding(
         padding: const EdgeInsets.all(16.0),
         child: Column(
           crossAxisAlignment: CrossAxisAlignment.start,
           children: [
             // Oda Seçici
             Container(
               height: 60,
               child: ListView(
                 scrollDirection: Axis.horizontal,
                 children: [
                   _buildRoomSelector("Oturma Odası"),
                   const SizedBox(width: 20),
                   _buildRoomSelector("Mutfak"),
                   const SizedBox(width: 20),
                   _buildRoomSelector("Yatak Odası"),
                 ],
               ),
             ),
             const SizedBox(height: 24),
             
             // Sensör Verileri
             if (sensorData.isNotEmpty) ...[
               Card(
                 elevation: 0,
                 shape: RoundedRectangleBorder(
                   borderRadius: BorderRadius.circular(16),
                   side: BorderSide(color: Colors.grey[200]!),
                 ),
                 child: Padding(
                   padding: const EdgeInsets.all(20),
                   child: Column(
                     crossAxisAlignment: CrossAxisAlignment.start,
                     children: [
                       const Text(
                         "Sensör Verileri",
                         style: TextStyle(
                           fontSize: 18,
                           fontWeight: FontWeight.w600,
                         ),
                       ),
                       const SizedBox(height: 16),
                       Row(
                         mainAxisAlignment: MainAxisAlignment.spaceAround,
                         children: [
                           _buildSensorItem(
                             Icons.thermostat,
                             "Sıcaklık",
                             "${sensorData['Temperature'] ?? 'N/A'}",
                             Colors.orange,
                           ),
                           _buildSensorItem(
                             Icons.water_drop,
                             "Nem",
                             "${sensorData['Humidity'] ?? 'N/A'}",
                             Colors.blue,
                           ),
                           _buildSensorItem(
                             Icons.straighten,
                             "Mesafe",
                             "${sensorData['Distance'] ?? 'N/A'}",
                             Colors.purple,
                           ),
                         ],
                       ),
                     ],
                   ),
                 ),
               ),
               const SizedBox(height: 24),
             ],
             
             // Cihaz Kartları
             _buildDeviceCard(
               "Akıllı Işık",
               isSmartLightOn,
               Icons.lightbulb,
               Colors.amber,
               () {
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
             ),
             const SizedBox(height: 16),
             _buildDeviceCard(
               "Akıllı Klima",
               isSmartACOn,
               Icons.ac_unit,
               Colors.blue,
               () {
                 setState(() {
                   isSmartACOn = !isSmartACOn;
                 });
                 _savePreferences();
               },
             ),
             
             /* // Yeni Cihaz Ekleme
             const SizedBox(height: 24),
             Card(
               elevation: 0,
               shape: RoundedRectangleBorder(
                 borderRadius: BorderRadius.circular(16),
                 side: BorderSide(color: Colors.grey[200]!),
               ),
               child: Padding(
                 padding: const EdgeInsets.all(20),
                 child: Column(
                   crossAxisAlignment: CrossAxisAlignment.start,
                   children: [
                     const Text(
                       "Yeni Cihaz Ekle",
                       style: TextStyle(
                         fontSize: 18,
                         fontWeight: FontWeight.w600,
                       ),
                     ),
                     const SizedBox(height: 16),
                     Row(
                       children: [
                         Expanded(
                           child: TextField(
                             controller: newDeviceController,
                             decoration: InputDecoration(
                               hintText: 'Cihaz adı',
                               border: OutlineInputBorder(
                                 borderRadius: BorderRadius.circular(12),
                                 borderSide: BorderSide(color: Colors.grey[300]!),
                               ),
                               enabledBorder: OutlineInputBorder(
                                 borderRadius: BorderRadius.circular(12),
                                 borderSide: BorderSide(color: Colors.grey[300]!),
                               ),
                               focusedBorder: OutlineInputBorder(
                                 borderRadius: BorderRadius.circular(12),
                                 borderSide: BorderSide(color: Colors.blue[700]!),
                               ),
                             ),
                           ),
                         ),
                         const SizedBox(width: 12),
                         IconButton(
                           icon: Icon(Icons.add_circle, color: Colors.blue[700], size: 32),
                           onPressed: _addNewDevice,
                         ),
                       ],
                     ),
                     const SizedBox(height: 16),
                     Wrap(
                       spacing: 8,
                       runSpacing: 8,
                       children: devices.map((device) {
                         return Chip(
                           label: Text(device),
                           backgroundColor: Colors.grey[100],
                           side: BorderSide(color: Colors.grey[300]!),
                           deleteIcon: const Icon(Icons.close, size: 18),
                           onDeleted: () {
                             setState(() {
                               devices.remove(device);
                             });
                             _savePreferences();
                           },
                         );
                       }).toList(),
                     ),
                   ],
                 ),
               ),
             ), */
           ],
         ),
       ),
     ),
   );
 }
  Widget _buildRoomSelector(String roomName) {
   bool isSelected = selectedRoom == roomName;
   return GestureDetector(
     onTap: () => _changeRoom(roomName),
     child: Container(
       padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 12),
       decoration: BoxDecoration(
         color: isSelected ? Colors.blue[700] : Colors.transparent,
         borderRadius: BorderRadius.circular(30),
         border: Border.all(
           color: isSelected ? Colors.blue[700]! : Colors.grey[300]!,
         ),
       ),
       child: Text(
         roomName,
         style: TextStyle(
           color: isSelected ? Colors.white : Colors.grey[600],
           fontWeight: isSelected ? FontWeight.w600 : FontWeight.normal,
         ),
       ),
     ),
   );
 }

 Widget _buildSensorItem(IconData icon, String label, String value, Color color) {
   return Column(
     children: [
       Container(
         padding: const EdgeInsets.all(12),
         decoration: BoxDecoration(
           color: color.withOpacity(0.1),
           shape: BoxShape.circle,
         ),
         child: Icon(icon, color: color, size: 24),
       ),
       const SizedBox(height: 8),
       Text(
         label,
         style: TextStyle(
           color: Colors.grey[600],
           fontSize: 14,
         ),
       ),
       const SizedBox(height: 4),
       Text(
         value,
         style: const TextStyle(
           fontWeight: FontWeight.w600,
           fontSize: 16,
         ),
       ),
     ],
   );
 }

 Widget _buildDeviceCard(String title, bool isOn, IconData icon, Color color, VoidCallback onTap) {
   return Card(
     elevation: 0,
     shape: RoundedRectangleBorder(
       borderRadius: BorderRadius.circular(16),
       side: BorderSide(color: Colors.grey[200]!),
     ),
     child: InkWell(
       onTap: onTap,
       borderRadius: BorderRadius.circular(16),
       child: Padding(
         padding: const EdgeInsets.all(20),
         child: Row(
           children: [
             Container(
               padding: const EdgeInsets.all(12),
               decoration: BoxDecoration(
                 color: isOn ? color.withOpacity(0.1) : Colors.grey[100],
                 shape: BoxShape.circle,
               ),
               child: Icon(
                 icon,
                 color: isOn ? color : Colors.grey,
                 size: 24,
               ),
             ),
             const SizedBox(width: 16),
             Expanded(
               child: Text(
                 title,
                 style: const TextStyle(
                   fontSize: 16,
                   fontWeight: FontWeight.w500,
                 ),
               ),
             ),
             Switch(
               value: isOn,
               activeColor: color,
               onChanged: (value) => onTap(),
             ),
           ],
         ),
       ),
     ),
   );
 }
}