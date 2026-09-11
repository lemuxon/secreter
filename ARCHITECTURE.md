# GizliChat — Mimari Rehber (v9)

Bu döküman, v9'da kurulan Clean Architecture + Riverpod + DI yapısını ve
bunu diğer modüllere (story, call, group) nasıl uygulayacağını anlatır.

---

## Neden Bu Mimari?

**Eski sorun:** Tüm mantık `Service` sınıflarındaydı. `chat_screen.dart` 1075
satırdı — UI, iş mantığı, Firestore erişimi, şifreleme hepsi iç içeydi.
Büyüdükçe test edilemez, değiştirilemez hale geliyordu.

**Çözüm:** Sorumlulukları katmanlara ayır. Her katman tek bir işi yapar ve
sadece komşusunu tanır.

---

## Katmanlar (içten dışa)

```
┌─────────────────────────────────────────────┐
│  PRESENTATION (UI)                           │
│  - MessagingScreen (ConsumerWidget)          │
│  - MessagingNotifier (StateNotifier)         │
│  - MessagingState (immutable)                │
│         ↓ sadece domain'i çağırır            │
├─────────────────────────────────────────────┤
│  DOMAIN (saf iş mantığı — framework yok)     │
│  - MessageEntity (saf nesne)                 │
│  - MessageRepository (soyut arayüz)          │
│  - UseCase'ler (SendTextMessage, ...)        │
│         ↑ data bunu implemente eder          │
├─────────────────────────────────────────────┤
│  DATA (veri erişimi)                         │
│  - MessageModel (entity + serileştirme)      │
│  - MessageRepositoryImpl                     │
│  - RemoteDataSource (Firestore)              │
│  - EncryptionDataSource (E2EE/AES)           │
└─────────────────────────────────────────────┘
```

**Altın kural:** Oklar hep içe doğru. Domain dışarıyı bilmez. UI ve Data
domain'e bağımlı, domain hiçbir şeye bağımlı değil. Firestore'u Isar ile
değiştirirsen sadece Data katmanı değişir — Domain ve UI'a dokunmazsın.

---

## Bir İsteğin Yolculuğu (örnek: mesaj gönder)

1. **UI:** Kullanıcı gönder'e basar → `notifier.sendText(text)`
2. **Notifier:** `SendTextMessage` use case'ini çağırır
3. **UseCase:** Validasyon yapar (boş mu? çok uzun mu?) → repository'yi çağırır
4. **Repository:** Şifreler (EncryptionDataSource) → kaydeder (RemoteDataSource)
5. **DataSource:** Firestore'a yazar, exception fırlatabilir
6. **Repository:** Exception'ı `Either<Failure, Unit>`'e çevirir
7. **Notifier:** Sonucu state'e yansıtır (`isSending`, `error`)
8. **UI:** State değişince otomatik rebuild olur

Her adım test edilebilir, çünkü her katman bağımlılıklarını arayüz olarak alır.

---

## Hata Yönetimi: Either<Failure, T>

Exception fırlatmak yerine `dartz` paketinin `Either` tipini kullanırız:

```dart
final result = await sendTextMessage(params);
result.fold(
  (failure) => showError(failure.message),  // Sol = hata
  (success) => doNothing(),                  // Sağ = başarı
);
```

Avantaj: Hata yolu tip sisteminde görünür. "Bu fonksiyon hata verebilir mi?"
sorusu imzaya bakılarak cevaplanır. Unutulamaz.

---

## Dependency Injection (get_it)

`core/di/injection.dart` tüm bağımlılıkları kaydeder. Bir sınıf başka bir
sınıfa ihtiyaç duyduğunda `new` ile oluşturmaz — `getIt()` ile ister.

```dart
// Kayıt (bir kez, main'de)
getIt.registerLazySingleton<MessageRepository>(
  () => MessageRepositoryImpl(remoteDataSource: getIt(), ...),
);

// Kullanım (her yerde)
final repo = getIt<MessageRepository>();
```

Avantaj: Test sırasında gerçek repository yerine sahte (mock) repository
kaydedebilirsin. Üretim kodu değişmez.

---

## Riverpod (State Management)

`StateNotifier` + `StateNotifierProvider.family.autoDispose`:

- **family:** Her sohbet için ayrı notifier (chatId parametreli)
- **autoDispose:** Ekran kapanınca otomatik temizlenir (bellek sızıntısı yok)

```dart
// Dinle (rebuild olur)
final state = ref.watch(messagingNotifierProvider(chatId));

// Eylem çağır (rebuild olmaz)
ref.read(messagingNotifierProvider(chatId).notifier).sendText(text);

// Yan etki dinle (snackbar vb.)
ref.listen(messagingNotifierProvider(chatId), (prev, next) { ... });
```

---

## Bu Deseni Başka Modüle Uygulamak

Diyelim **story** modülünü taşıyacaksın. Aynı klasör yapısını kur:

```
features/story/
  domain/
    entities/story_entity.dart          ← saf nesne
    repositories/story_repository.dart  ← soyut arayüz
    usecases/post_story.dart            ← tek iş
    usecases/watch_stories.dart
  data/
    models/story_model.dart             ← entity + fromMap/toMap
    datasources/story_remote_datasource.dart  ← Firestore
    repositories/story_repository_impl.dart    ← orkestrasyon
  presentation/
    state/story_state.dart
    providers/story_notifier.dart
    screens/story_screen.dart
```

Sonra `injection.dart`'a `_initStory()` ekle. Bitti.

**Adım adım:**
1. Mevcut `StoryService`'in metodlarına bak
2. Her metodu bir use case yap (`PostStory`, `WatchStories`, `DeleteStory`)
3. Firestore erişimini `StoryRemoteDataSource`'a taşı
4. `StoryRepositoryImpl` ikisini birleştirsin
5. `StoryNotifier` UI olaylarını yönetsin
6. Ekranı `ConsumerWidget` yap

---

## Geçiş Stratejisi (önemli)

Eski `services/` ve `screens/` klasörleri **henüz silinmedi** — uygulama
hâlâ onlarla çalışıyor. v9'da messaging modülü yeni mimariye taşındı ve
referans olarak duruyor.

**Önerilen geçiş:** Big-bang değil, modül modül. Her sprint'te bir modülü
(story → call → group → auth) yeni mimariye taşı, test et, eskisini sil.
Böylece uygulama her an çalışır durumda kalır.

---

## Sonraki Adımlar (v10+)

Bu temel kurulduğuna göre, üzerine eklenebilecekler:
- **Offline:** `LocalDataSource` (Isar) ekle, repository remote+local'i birleştirsin
- **Retry kuyruğu:** Başarısız mesajlar local'de "pending" işaretlenir, bağlanınca gönderilir
- **Test:** Her use case için unit test (repository mock'lanır)
- **Codegen:** `riverpod_generator` ile provider'ları otomatik üret

---

## v10 — Offline Katmanı (Eklendi ✅)

Offline desteği, mimarinin gücünü kanıtladı: **Domain ve UI'a hiç dokunmadan**,
sadece Data katmanına ekleme yaparak geldi.

### Eklenen parçalar

```
core/network/network_info.dart          ← bağlantı durumu (connectivity_plus)
data/datasources/
  message_local_datasource.dart         ← Hive cache + pending kuyruğu
  message_sync_service.dart             ← retry: bağlanınca pending'leri gönder
presentation/providers/
  connectivity_provider.dart            ← UI'a offline banner için
```

### Cache-then-network stratejisi

`watchMessages` artık iki aşamalı:

```dart
Stream watchMessages(chatId) async* {
  // 1. ÖNCE: cache'ten anında yayınla (offline'da bile çalışır)
  yield cachedMessages;
  // 2. SONRA: ağdan canlı dinle, geleni cache'le, yayınla
  yield* remoteStream.map(cache_and_emit);
}
```

Sonuç: Uygulama açılır açılmaz son mesajlar görünür (boş ekran beklemez),
sonra arka planda ağdan güncellenir.

### Offline mesaj gönderimi (optimistic update)

```dart
sendText(text) {
  cacheMessage(message);        // UI anında gösterir
  if (online) {
    remoteDataSource.send();    // direkt gönder
  } else {
    addPendingMessage();        // kuyruğa ekle (status: sending)
  }
}
```

Offline'da gönderilen mesaj saat ikonuyla (⏱️) görünür. Ağ gelince
`MessageSyncService` kuyruğu işler, mesajları gönderir, ikon tike (✓) döner.

### Hive notu (codegen'siz)

Hive'da `@HiveType` codegen yerine **ham Map** saklıyoruz:
`MessageModel.toMap()` → Hive box → `MessageModel.fromMap()`. Bu sayede
`build_runner` çalıştırmaya gerek yok, ama tip güvenliği için her okuma
`Map<String, dynamic>.from()` ile yapılır.

### Bu deseni başka modüle uygulamak

Story/group için aynı: `XLocalDataSource` (Hive) ekle, repository'de
cache-then-network uygula, gerekiyorsa `XSyncService` kur. Şablon hazır.

---

## v12 — Test Altyapısı (Eklendi ✅)

Testler mimarinin asıl kazanımını kanıtladı: her katman bağımlılıklarını
arayüz olarak aldığı için izole test edilebilir.

### Test piramidi

```
        /\        integration_test/  (az, yavaş, gerçek cihaz)
       /  \       app_test.dart
      /----\
     /      \     widget testleri (orta)
    /        \    security_warning_screen_test.dart
   /----------\
  /            \  unit testleri (çok, hızlı)
 /______________\ usecase + repository + model + failure
```

### mocktail (codegen'siz mock)

`mockito` codegen gerektirir; `mocktail` gerektirmez:

```dart
class MockMessageRepository extends Mock implements MessageRepository {}

// Stub
when(() => mock.sendTextMessage(...)).thenAnswer((_) async => Right(unit));
// Doğrula
verify(() => mock.sendTextMessage(...)).called(1);
verifyNever(() => mock.addPendingMessage(any()));
```

### Test ettiğimiz kritik senaryolar

**Use case (validasyon):**
- Boş/çok uzun mesaj → `ValidationFailure`, repository hiç çağrılmaz
- Geçerli mesaj → trim'lenip repository'ye iletilir

**Repository (offline mantığı):**
- ONLINE → `remote.sendMessage` çağrılır, pending'e EKLENMEZ
- OFFLINE → `local.addPendingMessage` çağrılır, remote'a GİTMEZ
- Her durumda önce `cacheMessage` (optimistic update)

**Model (serileştirme):**
- `toMap → fromMap` round-trip veriyi korur
- Eksik alanlar varsayılana düşer (bozuk veri toleransı)

**Widget:**
- Kritik tehditte "devam et" butonu yok; uyarıda var

### Statik bağımlılık dersi (önemli)

Testleri yazarken keşfettik: `MessageRepositoryImpl` doğrudan
`AuthService.currentUid` (statik) çağırıyordu → mock'lanamıyordu.

**Çözüm:** `CurrentUserProvider` arayüzü ekledik, repository'ye enjekte
ettik. Artık testte `MockCurrentUserProvider` veriliyor. Bu, "statik
bağımlılıklardan kaçın, enjekte et" kuralının canlı örneği — ve testlerin
neden değerli olduğunun kanıtı (tasarım hatasını ortaya çıkardı).

### Çalıştırma

```bash
flutter test                          # tüm unit + widget testleri
flutter test --coverage               # coverage ile
flutter test test/features/messaging/domain/  # sadece use case'ler
flutter test integration_test/app_test.dart   # integration (cihaz gerekir)
```

### CI (GitHub Actions)

`.github/workflows/ci.yml` her push'ta:
1. **analyze:** format + statik analiz
2. **test:** unit/widget testleri + coverage
3. **build:** (sadece main) release APK derler, artifact yükler

Firebase için `GOOGLE_SERVICES_JSON` secret'ı base64 olarak eklenmelidir.

---

## v13 — Modül Geçişi Tamamlandı (✅)

v9'da messaging için kurulan şablon artık **dört modülün hepsine** uygulandı.
Tüm iş mantığı `services/` God-object'lerinden çıkıp katmanlara dağıldı.

### Geçiş durumu

| Modül | domain | data | presentation | Durum |
|-------|--------|------|--------------|-------|
| messaging | entity, repo, 4 usecase | model, 4 datasource, repo | state, notifier, screen | ✅ + offline + test |
| story | entity, repo, 5 usecase | model, datasource, repo | notifier | ✅ |
| group | entity, repo, 7 usecase | model, datasource, repo | notifier | ✅ |
| call | entity, repo, 6 usecase | model, datasource, repo | providers | ✅ |

### Her modülün öne çıkan iş kuralları (domain'de)

**story:** 24 saat dolan hikayeler `isExpired` ile filtrelenir + auto-delete;
kullanıcı bazında gruplama (`UserStoriesEntity`); 280 karakter metin limiti.

**group:** Rol hiyerarşisi (`owner` > `admin` > `member`); `canPost`,
`canModerate`, `isBanned` iş kuralları entity'de. Moderasyon use case'leri
**yetki kontrolü** içerir — örn. `ChangeMemberRole` actor'ın `canModerate`
olduğunu doğrular, owner'ın rolünü korur. Bu kritik: yetki kontrolü UI'da
değil, use case'de (UI atlanabilir, use case atlanamaz).

**call:** Önemli mimari karar — çağrı **sinyalleşmesi** (offer/answer/ICE/
durum) repository'ye taşındı, ama canlı `RTCPeerConnection` ve `MediaStream`
eski `CallService`'te kaldı. Neden: bunlar serileştirilemez, UI-ömürlü canlı
kaynaklar; Clean Architecture'ın "data" katmanı serileştirilebilir veri
içindir. Provider sadece "kim arıyor" sinyalini sağlar, medya akışını değil.

### call modülü: kısmi geçişin gerekçesi

Her şeyi zorla bir desene sokmak yanlıştır. WebRTC'nin doğası gereği:
- **Taşındı (data katmanı):** Firestore signaling — saf veri, test edilebilir
- **Kaldı (service):** `RTCPeerConnection`, kamera/mikrofon, `MediaStream` —
  donanım kaynakları, UI yaşam döngüsüne bağlı

Bu, "pragmatik Clean Architecture" — dogma değil, fayda önemli.

### Eski kod durumu

`lib/services/` ve `lib/screens/` **hâlâ duruyor**. Yeni `features/`
modülleri referans + yeni geliştirme için. Tam kesişe (eski kodu silme)
geçmeden önce: her ekranı yeni notifier'a bağla, manuel test et, sonra eski
service'i kaldır. Bu kademeli yaklaşım uygulamayı her an çalışır tutar.

### Sıradaki (eski kodu emekliye ayırma)

1. `chat_screen.dart` → `MessagingScreen` (zaten var) ile değiştir
2. Story/group/call ekranlarını yeni notifier'lara bağla
3. Yeşil testlerle doğrula
4. `lib/services/*_service.dart` ve eski ekranları sil
5. `lib/models/` → entity'ler feature'lara taşındığı için kaldır
