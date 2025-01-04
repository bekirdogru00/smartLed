# Akıllı LED Kontrol Sistemi

Bu proje, ESP32 mikrodenetleyici ve MQTT protokolü kullanarak LED şeritleri kontrol eden bir mobil uygulamadır. Uygulama, akıllı ev otomasyonu için tasarlanmış olup, LED'lerin renk, parlaklık ve çalışma modlarını kontrol etmenin yanı sıra çeşitli sensör verilerini de görüntüleyebilmektedir.

## Özellikler

- 🌈 LED renk kontrolü
- 💡 Parlaklık ayarı
- 🌡️ Sıcaklık sensörü desteği
- 💧 Nem sensörü desteği
- 📏 Mesafe sensörü desteği
- ⏱️ Zamanlayıcı fonksiyonu
- 🔄 Otomatik kontrol modu
- 🏠 Çoklu oda desteği
- 🌙 Sıcak/Soğuk ton ayarı

## Teknolojiler

- **Flutter**: UI geliştirme için
- **MQTT**: IoT cihaz iletişimi için
- **ESP32**: Donanım kontrolü için
- **DHT11**: Sıcaklık ve nem ölçümü için
- **HC-SR04**: Mesafe ölçümü için

## Kurulum

1. Projeyi klonlayın:
```bash
git clone [repo-url]
```

2. Bağımlılıkları yükleyin:
```bash
flutter pub get
```

3. MQTT broker ayarlarını yapılandırın:
```dart
// lib/mqtt_service.dart dosyasında:
final String broker = 'your-broker-address';
final int port = 1883;
final String username = 'your-username';
final String password = 'your-password';
```

4. Uygulamayı çalıştırın:
```bash
flutter run
```

## Donanım Gereksinimleri

- ESP32 Geliştirme Kartı
- DHT11 Sıcaklık ve Nem Sensörü
- HC-SR04 Ultrasonik Mesafe Sensörü
- WS2812B LED Şerit
- 5V Güç Kaynağı

## Özellik Detayları

### LED Kontrol
- RGB renk seçimi
- Parlaklık ayarı (%0-%100)
- Sıcak/Soğuk ton modu
- Açma/Kapama kontrolü

### Sensör İzleme
- Gerçek zamanlı sıcaklık takibi
- Nem oranı görüntüleme
- Mesafe ölçümü

### Otomasyon
- Sıcaklık bazlı otomatik kontrol
- Nem bazlı otomatik kontrol
- Hareket sensörü ile otomatik açma/kapama
- Zamanlayıcı ile otomatik açma/kapama

### Çoklu Oda Desteği
- Farklı odalar için ayrı kontrol
- Oda bazlı ayarları kaydetme
- Hızlı oda geçişi

## Katkıda Bulunma

1. Bu depoyu fork edin
2. Yeni bir özellik dalı oluşturun (`git checkout -b yeni-ozellik`)
3. Değişikliklerinizi commit edin (`git commit -am 'Yeni özellik eklendi'`)
4. Dalınıza push yapın (`git push origin yeni-ozellik`)
5. Bir Pull Request oluşturun

## Lisans

Bu proje MIT lisansı altında lisanslanmıştır. Daha fazla bilgi için `LICENSE` dosyasına bakın.

## İletişim

Sorularınız veya önerileriniz için bir Issue açabilirsiniz.
