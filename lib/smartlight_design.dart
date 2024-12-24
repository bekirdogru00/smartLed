import 'package:flutter/material.dart';
import 'dart:async';
import 'mqtt_service.dart';

class SmartlightDesign extends StatefulWidget {
  const SmartlightDesign({super.key});

  @override
  State<SmartlightDesign> createState() => _SmartlightDesignState();
}

class _SmartlightDesignState extends State<SmartlightDesign> {
  bool isPowerOn = true;
  double intensity = 35;
  bool isWarmTone = true;
  bool isScheduleEnabled = false;
  Color selectedColor = Colors.white;
  int scheduledTimeInSeconds = 0;
  Timer? countdownTimer;
  late MqttService mqttService;
  
  // Sensör ve kontrol değişkenleri
  Map<String, String> sensorData = {};
  double tempThreshold = 25.0;
  double humThreshold = 60.0;
  double distanceThreshold = 10.0; // Mesafe eşiği (cm)
  bool isAutoControlEnabled = false;
  bool turnOffAboveThreshold = true;
  bool isMotionControlEnabled = false; // Mesafe kontrolü için
  double currentTemp = 0.0;
  double currentHum = 0.0;
  double currentDistance = 0.0;
  bool wasNearLastTime = false; // Mesafe kontrolü için durum takibi

  @override
  void initState() {
    super.initState();
    mqttService = MqttService();
    mqttService.initialize();
    mqttService.listenToMessages((topic, message) {
      if (topic == "smartlight/status") {
        setState(() {
          isPowerOn = message == "on";
        });
      }
      if (topic == "smartlight/sensorData") {
        _parseSensorData(message);
      }
    });
  }
    // Renk seçici metodu
  void _showColorPicker(BuildContext context) {
    showModalBottomSheet(
      context: context,
      builder: (BuildContext context) {
        return Padding(
          padding: const EdgeInsets.all(8.0),
          child: GridView.builder(
            gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
              crossAxisCount: 4,
              crossAxisSpacing: 10,
              mainAxisSpacing: 10,
            ),
            itemCount: 16,
            itemBuilder: (context, index) {
              Color color = _getColor(index);
              return GestureDetector(
                onTap: () {
                  setState(() {
                    selectedColor = color;
                  });
                  _updateLightColor(color);
                  Navigator.pop(context);
                },
                child: Container(
                  decoration: BoxDecoration(
                    color: color,
                    border: Border.all(color: Colors.grey),
                    borderRadius: BorderRadius.circular(8),
                  ),
                ),
              );
            },
          ),
        );
      },
    );
  }

  // Renk listesi metodu
  Color _getColor(int index) {
    List<Color> colors = [
      Colors.red,
      Colors.orange,
      Colors.yellow,
      Colors.green,
      Colors.blue,
      Colors.indigo,
      Colors.purple,
      Colors.pink,
      Colors.cyan,
      Colors.teal,
      Colors.lime,
      Colors.amber,
      Colors.brown,
      Colors.blueGrey,
      Colors.grey,
      Colors.white,
    ];
    return colors[index];
  }

  // Zamanlayıcı seçici metodu
  void _showSchedulePicker(BuildContext context) {
    showModalBottomSheet(
      context: context,
      builder: (BuildContext context) {
        int hours = 0, minutes = 0, seconds = 0;
        return StatefulBuilder(
          builder: (context, setState) {
            return Padding(
              padding: const EdgeInsets.all(16.0),
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  const Text(
                    "Zamanlayıcı Ayarla",
                    style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold),
                  ),
                  Row(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      _timePickerUnit("Saat", hours, (value) {
                        setState(() {
                          hours = value;
                        });
                      }),
                      _timePickerUnit("Dakika", minutes, (value) {
                        setState(() {
                          minutes = value;
                        });
                      }),
                      _timePickerUnit("Saniye", seconds, (value) {
                        setState(() {
                          seconds = value;
                        });
                      }),
                    ],
                  ),
                  const SizedBox(height: 20),
                  ElevatedButton(
                    onPressed: () {
                      this.setState(() {
                        scheduledTimeInSeconds = hours * 3600 + minutes * 60 + seconds;
                      });
                      _startTimer();
                      Navigator.pop(context);
                    },
                    child: const Text("Ayarla"),
                  ),
                ],
              ),
            );
          },
        );
      },
    );
  }

  // Zamanlayıcı birim seçici widget'ı
  Widget _timePickerUnit(String label, int value, Function(int) onChanged) {
    return Padding(
      padding: const EdgeInsets.all(8.0),
      child: Column(
        children: [
          Text(label),
          SizedBox(
            width: 60,
            child: TextField(
              keyboardType: TextInputType.number,
              textAlign: TextAlign.center,
              decoration: InputDecoration(
                border: const OutlineInputBorder(),
                contentPadding: const EdgeInsets.symmetric(horizontal: 8, vertical: 0),
                hintText: '0',
              ),
              onChanged: (text) {
                int? newValue = int.tryParse(text);
                if (newValue != null) {
                  onChanged(newValue);
                }
              },
            ),
          ),
        ],
      ),
    );
  }

  void _parseSensorData(String data) {
    try {
      RegExp tempRegex = RegExp(r'Temperature: ([\d.]+)C');
      RegExp humRegex = RegExp(r'Humidity: ([\d.]+)%');
      RegExp distRegex = RegExp(r'Distance: ([\d.]+)cm');
      
      var tempMatch = tempRegex.firstMatch(data);
      var humMatch = humRegex.firstMatch(data);
      var distMatch = distRegex.firstMatch(data);
      
      setState(() {
        if (tempMatch != null) {
          sensorData['Temperature'] = '${tempMatch.group(1)}°C';
          currentTemp = double.parse(tempMatch.group(1)!);
        }
        if (humMatch != null) {
          sensorData['Humidity'] = '${humMatch.group(1)}%';
          currentHum = double.parse(humMatch.group(1)!);
        }
        if (distMatch != null) {
          sensorData['Distance'] = '${distMatch.group(1)}cm';
          currentDistance = double.parse(distMatch.group(1)!);
            double distance = double.parse(distMatch.group(1)!);
         if (isMotionControlEnabled) {  // Switch'in durumunu kontrol et
          double distance = double.parse(distMatch.group(1)!);
          if (distance < 10) {
            _togglePower();
          }
          // Mesafe kontrolü
          if (isMotionControlEnabled) {
            bool isNearNow = currentDistance < distanceThreshold;
            
            if (isNearNow != wasNearLastTime) {
              // Durum değiştiğinde ışığı aç/kapat
              _togglePower();
              wasNearLastTime = isNearNow;
            }
          }
        }

        // Sıcaklık ve nem kontrolü
        if (isAutoControlEnabled) {
          bool shouldTurnOff = (currentTemp > tempThreshold || currentHum > humThreshold);
          
          if (shouldTurnOff && turnOffAboveThreshold && isPowerOn) {
            _togglePower(); // Eşik üstündeyse ve kapatma seçiliyse kapat
          } else if (shouldTurnOff && !turnOffAboveThreshold && !isPowerOn) {
            _togglePower(); // Eşik üstündeyse ve açma seçiliyse aç
          } else if (!shouldTurnOff && turnOffAboveThreshold && !isPowerOn) {
            _togglePower(); // Eşik altındaysa ve kapatma seçiliyse aç
          } else if (!shouldTurnOff && !turnOffAboveThreshold && isPowerOn) {
            _togglePower(); // Eşik altındaysa ve açma seçiliyse kapat
          }
          
        }
      }});
    } catch (e) {
      print('Veri ayrıştırma hatası: $e');
    }
  }
  

  void _togglePower() {
    setState(() {
      isPowerOn = !isPowerOn;
      mqttService.sendMessage("smartlight/control", isPowerOn ? "on" : "off");
    });
  }

  void _updateLightColor(Color color) {
    String colorMessage = "${color.red},${color.green},${color.blue}";
    mqttService.sendMessage("smartlight/color", colorMessage);
  }

  void _updateBrightness(double value) {
    mqttService.sendMessage("smartlight/brightness", value.round().toString());
  }

  void _startTimer() {
    countdownTimer?.cancel();
    countdownTimer = Timer.periodic(const Duration(seconds: 1), (timer) {
      setState(() {
        if (scheduledTimeInSeconds > 0) {
          scheduledTimeInSeconds--;
        } else {
          timer.cancel();
          _togglePower();
          isScheduleEnabled = false;
        }
      });
    });
  }

  String _formatTime(int seconds) {
    int hours = seconds ~/ 3600;
    int minutes = (seconds % 3600) ~/ 60;
    int remainingSeconds = seconds % 60;
    return "${hours.toString().padLeft(2, '0')}:${minutes.toString().padLeft(2, '0')}:${remainingSeconds.toString().padLeft(2, '0')}";
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text("Akıllı Işık Kontrolü"),
        leading: IconButton(
          icon: const Icon(Icons.arrow_back),
          onPressed: () => Navigator.pop(context),
        ),
      ),
      body: SingleChildScrollView(
        padding: const EdgeInsets.all(16.0),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // Güç Kontrolü
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                const Text(
                  "Güç",
                  style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold),
                ),
                Switch(
                  value: isPowerOn,
                  onChanged: (value) => _togglePower(),
                ),
              ],
            ),

            // Sensör Verileri
            if (sensorData.isNotEmpty) ...[
              const SizedBox(height: 20),
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
            ],

            // Renk Kontrolü
            const SizedBox(height: 20),
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                const Text(
                  "Renk",
                  style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold),
                ),
                Row(
                  children: [
                    IconButton(
                      icon: const Icon(Icons.color_lens),
                      onPressed: () => _showColorPicker(context),
                    ),
                    Container(
                      width: 30,
                      height: 30,
                      decoration: BoxDecoration(
                        color: selectedColor,
                        shape: BoxShape.circle,
                        border: Border.all(color: Colors.grey),
                      ),
                    ),
                  ],
                ),
              ],
            ),

            // Ton Kontrolü
            const SizedBox(height: 20),
            const Text(
              "Ton",
              style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold),
            ),
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceEvenly,
              children: [
                ChoiceChip(
                  label: const Text("Sıcak"),
                  selected: isWarmTone,
                  onSelected: (selected) {
                    setState(() {
                      isWarmTone = true;
                      mqttService.sendMessage("smartlight/tone", "warm");
                    });
                  },
                ),
                ChoiceChip(
                  label: const Text("Soğuk"),
                  selected: !isWarmTone,
                  onSelected: (selected) {
                    setState(() {
                      isWarmTone = false;
                      mqttService.sendMessage("smartlight/tone", "cold");
                    });
                  },
                ),
              ],
            ),

            // Parlaklık Kontrolü
            const SizedBox(height: 20),
            const Text(
              "Parlaklık",
              style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold),
            ),
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                const Text("Kapalı"),
                Expanded(
                  child: Slider(
                    value: intensity,
                    min: 0,
                    max: 100,
                    divisions: 100,
                    label: "${intensity.round()}%",
                    onChanged: (value) {
                      setState(() {
                        intensity = value;
                      });
                      _updateBrightness(value);
                    },
                  ),
                ),
                Text("${intensity.round()}%"),
              ],
            ),

            // Zamanlayıcı
            const SizedBox(height: 20),
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                const Text(
                  "Zamanlayıcı",
                  style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold),
                ),
                Switch(
                  value: isScheduleEnabled,
                  onChanged: (value) {
                    setState(() {
                      isScheduleEnabled = value;
                    });
                    if (isScheduleEnabled) {
                      _showSchedulePicker(context);
                    } else {
                      countdownTimer?.cancel();
                      scheduledTimeInSeconds = 0;
                    }
                  },
                ),
              ],
            ),
            if (scheduledTimeInSeconds > 0)
              Text(
                "Kalan Süre: ${_formatTime(scheduledTimeInSeconds)}",
                style: const TextStyle(fontSize: 16),
              ),

            // Mesafe Kontrolü
            const SizedBox(height: 20),
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                const Text(
                  "Mesafe Kontrolü",
                  style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold),
                ),
                Switch(
                  value: isMotionControlEnabled,
                  onChanged: (value) {
                    setState(() {
                      isMotionControlEnabled = value;
                      wasNearLastTime = false; // Kontrolü sıfırla
                    });
                  },
                ),
              ],
            ),

            // Otomatik Kontrol
            const SizedBox(height: 20),
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                const Text(
                  "Otomatik Kontrol",
                  style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold),
                ),
                Switch(
                  value: isAutoControlEnabled,
                  onChanged: (value) {
                    setState(() {
                      isAutoControlEnabled = value;
                    });
                  },
                ),
              ],
            ),
            if (isAutoControlEnabled) ...[
              const SizedBox(height: 10),
              Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  const Text("Eşik değeri aşıldığında:"),
                  SegmentedButton<bool>(
                    segments: const [
                      ButtonSegment<bool>(
                        value: true,
                        label: Text('Kapat'),
                      ),
                      ButtonSegment<bool>(
                        value: false,
                        label: Text('Aç'),
                      ),
                    ],
                    selected: {turnOffAboveThreshold},
                    onSelectionChanged: (Set<bool> newSelection) {
                      setState(() {
                        turnOffAboveThreshold = newSelection.first;
                      });
                    },
                  ),
                ],
              ),
              const SizedBox(height: 20),
              Row(
                children: [
                  const Text("Sıcaklık Eşiği: "),
                  Expanded(
                    child: Slider(
                      value: tempThreshold,
                      min: 0,
                      max: 50,
                      divisions: 50,
                      label: "${tempThreshold.round()}°C",
                      onChanged: (value) {
                        setState(() {
                          tempThreshold = value;
                        });
                      },
                    ),
                  ),
                  Text("${tempThreshold.round()}°C"),
                ],
              ),
              const SizedBox(height: 10),
              Row(
                children: [
                  const Text("Nem Eşiği: "),
                  Expanded(
                    child: Slider(
                      value: humThreshold,
                      min: 0,
                      max: 100,
                      divisions: 100,
                      label: "${humThreshold.round()}%",
                      onChanged: (value) {
                        setState(() {
                          humThreshold = value;
                        });
                      },
                    ),
                  ),
                  Text("${humThreshold.round()}%"),
                ],
              ),
            ],
          ],
        ),
      ),
    );
  }

  @override
  void dispose() {
    countdownTimer?.cancel();
    super.dispose();
  }
}