# SECRETER — Mimari Geçiş Durumu

Eski koddan (`lib/screens`, `lib/services`) Clean Architecture'a
(`lib/features`, `lib/core`) geçiş **TAMAMLANDI**.

## Durum

| # | Adım | Durum |
|---|------|-------|
| 1 | Çekirdek döngü (ConversationsScreen + MessagingScreen) | ✅ |
| 2 | Auth (repository + controller + Register ekranı) | ✅ |
| 3 | Arama + sohbet başlatma | ✅ |
| 4a | Grup/Kanal oluşturma | ✅ |
| 4b | Grup bilgisi/yönetimi (rol, susturma, atma, davet, ayrıl) | ✅ |
| 5 | Çağrılar (WebRTC) | ✅ derlendi · canlı çift-cihaz testi bekliyor |
| 6 | Hikâyeler (creator + viewer + halka) | ✅ |
| 7 | Ayarlar/Gizlilik + PIN/Kilit | ✅ |
| 8 | **Eski motorun silinmesi** | ✅ **tamamlandı** |

**Doğrulama (ölçüldü):** `flutter analyze` → 0 error, 0 warning ·
`flutter test` → 60/60 geçiyor · Firestore kuralları → 50/50 geçiyor.

## Eski motor neden silindi?

`lib/services/chat_service.dart` ve `lib/models/message_model.dart`
kaldırıldı. Bunlar yeni katmanla **aynı Firestore koleksiyonlarına farklı
şemalarla** yazıyordu ve üç kritik hatanın doğrudan kaynağıydı:

1. **`reactions` şema çakışması.** Eski motor bu alanı LİSTE, yeni katman
   ve Cloud Function HARİTA olarak yazıyordu. Karşı şemaya rastlayan
   okuyucu `TypeError` fırlatıyor, bu hata mesaj akışını düşürüyor ve
   **sohbet ekranı hiç açılmıyordu**. Hikâye yanıtı eski motoru
   kullandığı için erişilebilir bir yoldu.
2. **Düz metin önizleme sızıntısı.** Eski motor, içerik şifreli olsa bile
   mesajın tam metnini `chats.lastMessage` alanına düz yazıyordu.
3. **Ratchet aşırı ilerlemesi.** Eski mesaj akışı her snapshot'ta tüm
   listeyi yeniden çözmeye kalkıyor ve alma zincirini her seferinde
   ilerletiyordu; sonuçta **yalnızca en yeni mesaj okunabiliyordu**.

Devralınan tek meşru sorumluluk olan "birebir sohbet dokümanı oluştur"
işi `lib/services/direct_chat_service.dart` dosyasına taşındı.

## Mimari son durum

- **`lib/features/`** + **`lib/core/`** — Clean Architecture
  (domain / data / presentation)
- **`lib/services/`** — korunan MOTORLAR: `AuthService`, `CallService`,
  `EncryptionService`, `KeyManagementService`, `X3DHService`,
  `DoubleRatchetService`, `E2EESessionService`, `MultiAccountService`,
  `NotificationService`, `PrivacyService`, `BiometricService`,
  `BackupService`, `DirectChatService`. Repository/datasource'lar
  bunları sarmalar.
- **`lib/models/`** — `user`, `chat`, `call` (mesaj modeli artık yalnızca
  `features/messaging/data/models` altında, TEK şema)
- **`lib/screens/splash_screen.dart`** — giriş köprüsü

## Bilinen sınırlar (bilinçli ödünler)

- **DH ratchet yok.** Simetrik zincir + atlanan mesaj anahtarı desteği var
  (forward secrecy sağlanır), ancak "break-in recovery"
  (post-compromise security) YOKTUR.
- **Grup/kanal mesajları E2EE değildir.** Sender-key şeması kurulana
  kadar içerik sunucuda düz metindir. Kullanıcıya arayüzde kilit simgesi
  gösterilmez ve `index.html` bunu açıkça yazar.
- **Düzenlenen mesajlar düz metne düşer.** Ratchet düzenlemeyi
  desteklemediği için `isE2EE` bayrağı `false` yapılır — yani arayüz
  artık yanıltıcı kilit simgesi göstermez.
- **Çağrılarda IP gizliliği TURN'e bağlıdır.** `SECRETER_TURN_URL`
  tanımlıysa `iceTransportPolicy: relay` ile IP sızmaz; tanımlı değilse
  P2P kurulur ve taraflar birbirinin IP'sini görür.
