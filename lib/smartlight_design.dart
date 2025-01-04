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
  bool turnOnWhenThresholdExceeded = false;

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
      backgroundColor: Colors.grey[50],
      appBar: AppBar(
        elevation: 0,
        backgroundColor: Colors.white,
        leading: IconButton(
          icon: const Icon(Icons.arrow_back, color: Colors.black87),
          onPressed: () => Navigator.pop(context),
        ),
        title: const Text(
          "Akıllı Işık Kontrolü",
          style: TextStyle(
            color: Colors.black87,
            fontSize: 20,
            fontWeight: FontWeight.w500,
          ),
        ),
      ),
      body: SingleChildScrollView(
        child: Column(
          children: [
            // Durum ve Parlaklık Kartı
            _buildControlCard(),
            
            // Renk Seçici Kartı
            _buildColorCard(),
            
            // Ton Seçici Kartı
            _buildToneCard(),
            
            // Zamanlayıcı Kartı
            _buildTimerCard(),
            
            // Otomasyon Kartları
            _buildAutomationCards(),
          ],
        ),
      ),
    );
  }

  Widget _buildControlCard() {
    return Padding(
      padding: const EdgeInsets.all(16.0),
      child: Card(
        elevation: 0,
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(16),
          side: BorderSide(color: Colors.grey[200]!),
        ),
        child: Padding(
          padding: const EdgeInsets.all(20),
          child: Column(
            children: [
              // Güç Düğmesi
              GestureDetector(
                onTap: _togglePower,
                child: Container(
                  width: 80,
                  height: 80,
                  decoration: BoxDecoration(
                    shape: BoxShape.circle,
                    color: isPowerOn ? Colors.blue[700] : Colors.grey[300],
                  ),
                  child: Icon(
                    Icons.power_settings_new,
                    size: 40,
                    color: Colors.white,
                  ),
                ),
              ),
              const SizedBox(height: 20),
              
              // Parlaklık Kontrolü
              Text(
                "Parlaklık: ${intensity.round()}%",
                style: const TextStyle(
                  fontSize: 16,
                  fontWeight: FontWeight.w500,
                ),
              ),
              const SizedBox(height: 10),
              SliderTheme(
                data: SliderThemeData(
                  activeTrackColor: Colors.blue[700],
                  thumbColor: Colors.blue[700],
                  inactiveTrackColor: Colors.grey[300],
                ),
                child: Slider(
                  value: intensity,
                  min: 0,
                  max: 100,
                  onChanged: (value) {
                    setState(() {
                      intensity = value;
                    });
                    _updateBrightness(value);
                  },
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildColorCard() {
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 16),
      child: Card(
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
                "Renk Seçimi",
                style: TextStyle(
                  fontSize: 18,
                  fontWeight: FontWeight.w600,
                ),
              ),
              const SizedBox(height: 16),
              Container(
                height: 120,
                child: GridView.builder(
                  gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
                    crossAxisCount: 8,
                    crossAxisSpacing: 8,
                    mainAxisSpacing: 8,
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
                      },
                      child: Container(
                        decoration: BoxDecoration(
                          color: color,
                          shape: BoxShape.circle,
                          border: Border.all(
                            color: selectedColor == color 
                                ? Colors.blue[700]! 
                                : Colors.grey[300]!,
                            width: 2,
                          ),
                        ),
                      ),
                    );
                  },
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildToneCard() {
    return Padding(
      padding: const EdgeInsets.all(16),
      child: Card(
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
                "Işık Tonu",
                style: TextStyle(
                  fontSize: 18,
                  fontWeight: FontWeight.w600,
                ),
              ),
              const SizedBox(height: 16),
              Row(
                children: [
                  Expanded(
                    child: GestureDetector(
                      onTap: () {
                        setState(() {
                          isWarmTone = true;
                        });
                        mqttService.sendMessage("smartlight/tone", "warm");
                      },
                      child: Container(
                        padding: const EdgeInsets.symmetric(vertical: 12),
                        decoration: BoxDecoration(
                          color: isWarmTone ? Colors.amber[100] : Colors.transparent,
                          borderRadius: BorderRadius.circular(12),
                          border: Border.all(
                            color: isWarmTone ? Colors.amber[700]! : Colors.grey[300]!,
                          ),
                        ),
                        child: Column(
                          children: [
                            Icon(
                              Icons.wb_sunny,
                              color: isWarmTone ? Colors.amber[700] : Colors.grey[400],
                            ),
                            const SizedBox(height: 8),
                            Text(
                              "Sıcak",
                              style: TextStyle(
                                color: isWarmTone ? Colors.amber[700] : Colors.grey[600],
                              ),
                            ),
                          ],
                        ),
                      ),
                    ),
                  ),
                  const SizedBox(width: 16),
                  Expanded(
                    child: GestureDetector(
                      onTap: () {
                        setState(() {
                          isWarmTone = false;
                        });
                        mqttService.sendMessage("smartlight/tone", "cold");
                      },
                      child: Container(
                        padding: const EdgeInsets.symmetric(vertical: 12),
                        decoration: BoxDecoration(
                          color: !isWarmTone ? Colors.blue[100] : Colors.transparent,
                          borderRadius: BorderRadius.circular(12),
                          border: Border.all(
                            color: !isWarmTone ? Colors.blue[700]! : Colors.grey[300]!,
                          ),
                        ),
                        child: Column(
                          children: [
                            Icon(
                              Icons.nights_stay,
                              color: !isWarmTone ? Colors.blue[700] : Colors.grey[400],
                            ),
                            const SizedBox(height: 8),
                            Text(
                              "Soğuk",
                              style: TextStyle(
                                color: !isWarmTone ? Colors.blue[700] : Colors.grey[600],
                              ),
                            ),
                          ],
                        ),
                      ),
                    ),
                  ),
                ],
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildTimerCard() {
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 16),
      child: Card(
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
              Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  const Text(
                    "Zamanlayıcı",
                    style: TextStyle(
                      fontSize: 18,
                      fontWeight: FontWeight.w600,
                    ),
                  ),
                  Switch(
                    value: isScheduleEnabled,
                    activeColor: Colors.blue[700],
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
              if (scheduledTimeInSeconds > 0) ...[
                const SizedBox(height: 12),
                Text(
                  "Kalan Süre: ${_formatTime(scheduledTimeInSeconds)}",
                  style: TextStyle(
                    fontSize: 16,
                    color: Colors.grey[600],
                  ),
                ),
              ],
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildAutomationCards() {
    return Padding(
      padding: const EdgeInsets.all(16),
      child: Column(
        children: [
          // Mesafe Kontrolü Kartı
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
                  Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      const Text(
                        "Hareket Sensörü",
                        style: TextStyle(
                          fontSize: 18,
                          fontWeight: FontWeight.w600,
                        ),
                      ),
                      Switch(
                        value: isMotionControlEnabled,
                        activeColor: Colors.blue[700],
                        onChanged: (value) {
                          setState(() {
                            isMotionControlEnabled = value;
                            wasNearLastTime = false;
                          });
                        },
                      ),
                    ],
                  ),
                  if (isMotionControlEnabled) ...[
                    const SizedBox(height: 12),
                    Text(
                      "Mesafe: ${sensorData['Distance'] ?? 'N/A'}",
                      style: TextStyle(
                        fontSize: 16,
                        color: Colors.grey[600],
                      ),
                    ),
                  ],
                ],
              ),
            ),
          ),
          
          const SizedBox(height: 16),
          
          // Otomatik Kontrol Kartı
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
                  Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      const Text(
                        "Otomatik Kontrol",
                        style: TextStyle(
                          fontSize: 18,
                          fontWeight: FontWeight.w600,
                        ),
                      ),
                      Switch(
                        value: isAutoControlEnabled,
                        activeColor: Colors.blue[700],
                        onChanged: (value) {
                          setState(() {
                            isAutoControlEnabled = value;
                          });
                        },
                      ),
                    ],
                  ),
                  if (isAutoControlEnabled) ...[
                    const SizedBox(height: 16),
                    Row(
                      mainAxisAlignment: MainAxisAlignment.spaceBetween,
                      children: [
                        Text(
                          "Eşik Aşıldığında:",
                          style: TextStyle(
                            fontSize: 16,
                            color: Colors.grey[600],
                          ),
                        ),
                        Row(
                          children: [
                            GestureDetector(
                              onTap: () {
                                setState(() {
                                  turnOnWhenThresholdExceeded = true;
                                });
                              },
                              child: Container(
                                padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
                                decoration: BoxDecoration(
                                  color: turnOnWhenThresholdExceeded ? Colors.blue[700] : Colors.transparent,
                                  borderRadius: const BorderRadius.horizontal(left: Radius.circular(20)),
                                  border: Border.all(
                                    color: turnOnWhenThresholdExceeded ? Colors.blue[700]! : Colors.grey[300]!,
                                  ),
                                ),
                                child: Text(
                                  "Aç",
                                  style: TextStyle(
                                    color: turnOnWhenThresholdExceeded ? Colors.white : Colors.grey[600],
                                  ),
                                ),
                              ),
                            ),
                            GestureDetector(
                              onTap: () {
                                setState(() {
                                  turnOnWhenThresholdExceeded = false;
                                });
                              },
                              child: Container(
                                padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
                                decoration: BoxDecoration(
                                  color: !turnOnWhenThresholdExceeded ? Colors.blue[700] : Colors.transparent,
                                  borderRadius: const BorderRadius.horizontal(right: Radius.circular(20)),
                                  border: Border.all(
                                    color: !turnOnWhenThresholdExceeded ? Colors.blue[700]! : Colors.grey[300]!,
                                  ),
                                ),
                                child: Text(
                                  "Kapat",
                                  style: TextStyle(
                                    color: !turnOnWhenThresholdExceeded ? Colors.white : Colors.grey[600],
                                  ),
                                ),
                              ),
                            ),
                          ],
                        ),
                      ],
                    ),
                    const SizedBox(height: 16),
                    Text(
                      "Sıcaklık Eşiği: ${tempThreshold.round()}°C",
                      style: TextStyle(
                        fontSize: 16,
                        color: Colors.grey[600],
                      ),
                    ),
                    SliderTheme(
                      data: SliderThemeData(
                        activeTrackColor: Colors.blue[700],
                        thumbColor: Colors.blue[700],
                        inactiveTrackColor: Colors.grey[300],
                      ),
                      child: Slider(
                        value: tempThreshold,
                        min: 0,
                        max: 50,
                        onChanged: (value) {
                          setState(() {
                            tempThreshold = value;
                          });
                        },
                      ),
                    ),
                    Text(
                      "Nem Eşiği: ${humThreshold.round()}%",
                      style: TextStyle(
                        fontSize: 16,
                        color: Colors.grey[600],
                      ),
                    ),
                    SliderTheme(
                      data: SliderThemeData(
                        activeTrackColor: Colors.blue[700],
                        thumbColor: Colors.blue[700],
                        inactiveTrackColor: Colors.grey[300],
                      ),
                      child: Slider(
                        value: humThreshold,
                        min: 0,
                        max: 100,
                        onChanged: (value) {
                          setState(() {
                            humThreshold = value;
                          });
                        },
                      ),
                    ),
                    const SizedBox(height: 20),
                    // Sensör Verileri
                    if (sensorData.isNotEmpty) ...[
                      const Text(
                        "Anlık Sensör Verileri",
                        style: TextStyle(
                          fontSize: 16,
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
                  ],
                ],
              ),
            ),
          ),
        ],
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

  @override
  void dispose() {
    countdownTimer?.cancel();
    mqttService.unsubscribe("smartlight/sensorData");
    super.dispose();
  }

  void _processSensorData(String message) {
    if (!mounted) return;
    
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
}