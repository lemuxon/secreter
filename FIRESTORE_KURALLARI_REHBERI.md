# Firestore Güvenlik Kuralları — sıfırdan

## 1. Neden bu iş acil?

Projeyi kurarken Firebase muhtemelen **"test modu"** kuralları verdi:

```
allow read, write: if request.time < timestamp.date(2026, 8, 15);
```

Bunun anlamı: **o tarihe kadar internetteki HERKES** veritabanının tamamını
okuyabilir ve silebilir. Uygulamandan geçmesine gerek yok — proje kimliğin
zaten uygulamanın içinde (`firebase_options.dart`), ki bu normaldir. Güvenliği
sağlayan tek şey kurallardır.

İki risk:
- **Bugün:** herkes tüm mesajları okuyabilir/silebilir
- **O tarihten sonra:** kurallar kapanır ve **uygulaman tamamen çalışmaz olur**

Yani bu iş hem güvenlik hem işlevsellik meselesi.

---

## 2. Kurallar nasıl çalışır — 3 dakikada

Kurallar bir "izin listesi"dir. Varsayılan **her şey yasak**; sen tek tek
izin verirsin.

```
match /users/{uid} {          // hangi yola uygulanıyor
  allow read: if signedIn();  // ne yapılabilir + koşul
  allow write: if isMe(uid);
}
```

Bilinmesi gereken üç değişken:

| Değişken | Anlamı |
|---|---|
| `request.auth.uid` | İsteği yapan kişinin kimliği (giriş yapmamışsa `null`) |
| `resource.data` | Dokümanın **mevcut** hâli (okuma/güncelleme/silmede) |
| `request.resource.data` | **Yazılmak istenen** yeni hâli (oluşturma/güncellemede) |

Örnek okuma: *"Bu sohbeti yalnızca `memberIds` dizisinde uid'i olan görebilir."*

```
allow read: if request.auth.uid in resource.data.memberIds;
```

---

## 3. Uygulama — adım adım

### Adım 1: Mevcut kuralları yedekle
1. **console.firebase.google.com** → projen (**gizlichat-f2a99**)
2. Sol menü → **Firestore Database** → üst sekme **Rules**
3. Ekrandaki metnin **tamamını kopyala**, bir yere kaydet
   *(bir şey ters giderse geri dönebilmek için)*

### Adım 2: Yeni kuralları yapıştır
1. `firestore.rules` dosyasının içeriğini kopyala
2. Rules ekranındaki her şeyi sil, bunu yapıştır
3. **Henüz "Publish" deme** → önce test

### Adım 3: Test et (bu adımı atlama)
Rules ekranında **Rules Playground** (Kuralları test et) bölümünü aç:

**Test 1 — kendi mesajını okuma (GEÇMELİ)**
- Simulation type: `get`
- Location: `/chats/AAA_BBB/messages/msg1`
- Authenticated: **açık**, Firebase UID: kendi uid'in
- ⚠️ Not: `chats/AAA_BBB` dokümanının `memberIds` alanında uid'in olmalı
- Beklenen: **Allow**

**Test 2 — başkasının sohbetini okuma (ENGELLENMELİ)**
- Aynı ayarlar, ama UID olarak rastgele bir değer yaz
- Beklenen: **Deny**

**Test 3 — giriş yapmadan okuma (ENGELLENMELİ)**
- Authenticated: **kapalı**
- Location: `/users/herhangiBirUid`
- Beklenen: **Deny**

Üçü de beklendiği gibiyse **Publish**.

### Adım 4: Uygulamayı gerçekten dene
Yayınladıktan sonra telefonda **her akışı** test et:
- Mesaj gönder/al · fotoğraf · sesli mesaj
- Grup ve kanal oluştur, davet kodu
- Arama yap, çağrı geçmişi
- Hikâye paylaş, izle
- Engelle / şikâyet et
- Hesap silme

Bir yerde **"permission-denied"** hatası alırsan: hangi ekran ve hangi işlem
olduğunu bana yaz; ilgili kuralı düzeltirim. (Bu normaldir — kural yazarken
bir koleksiyon atlanmış olabilir.)

---

## 4. Bu kurallar ne yapıyor — özet

| Koleksiyon | Kim okur | Kim yazar |
|---|---|---|
| `users` | Giriş yapmış herkes *(kullanıcı adıyla arama için şart)* | Yalnızca kendi dokümanına |
| `keyBundles` | Herkes *(açık anahtar — zaten paylaşılmak içindir)* | Yalnızca sahibi |
| `chats` | Yalnızca üyeler | Yalnızca üyeler |
| `chats/{id}/messages` | Yalnızca sohbet üyeleri | Üyeler; **gönderen kendi adına** yazmak zorunda |
| `stories` | Giriş yapmış herkes | Sahibi oluşturur/siler |
| `calls` | Yalnızca arayan ve aranan | Arayan **engellenmemişse** başlatabilir |
| `callLogs` | Yalnızca katılımcılar | Katılımcılar; **silme kapalı** |
| `reports` | **Hiç kimse** | Herkes oluşturur *(şikâyetler gizli)* |
| `scheduledMessages` | Yalnızca sahibi | Yalnızca sahibi |
| Diğer her şey | **Kapalı** | **Kapalı** |

**Engelleme artık sunucuda zorlanıyor:** Engellediğin kişi, uygulamayı
değiştirse bile seni arayamaz — kural sunucuda kontrol ediyor.

---

## 5. Dikkat edilecekler

**Yeni koleksiyon eklersen kural da ekle.** En sondaki
`match /{document=**} { allow read, write: if false; }` satırı, kuralı
olmayan her şeyi kapatır. Güvenli varsayılan budur ama unutursan yeni
özellik çalışmaz.

**`get()` çağrıları ücretlidir.** `isChatMember()` ve `notBlockedBy()`
başka doküman okur; her istekte 1 ek okuma sayılır. Güvenlik için buna
değer, ama maliyet takibinde aklında olsun.

**Storage kuralları ayrıdır.** Firestore ≠ Storage. Medya dosyaların için
**Storage → Rules** bölümünü de kapatman gerekir. Şu an muhtemelen test
modunda:

```
rules_version = '2';
service firebase.storage {
  match /b/{bucket}/o {
    match /{allPaths=**} {
      allow read, write: if request.auth != null;
    }
  }
}
```

Bu, "yalnızca giriş yapmış kullanıcılar" demektir — test modundan çok daha
iyidir, başlangıç için yeterli.

---

## 6. Dizinler (index) — ayrı bir konu

Kurallardan bağımsız olarak, bazı sorgular **bileşik dizin** ister.
Logda şunu gördük:

```
Çağrı geçmişi dizinsiz moda düştü: FAILED_PRECONDITION
The query requires an index. You can create it here: https://console...
```

**Yapılacak:** O uzun bağlantıya tıkla → **Create index** → 1-2 dakika bekle.
Uygulama şu an yedek moda düşüp çalışıyor (bu yüzden fark etmedin), ama
dizinle çok daha hızlı olur.

Gereken dizinler:
- `chats`: `memberIds` (Arrays) + `lastMessageTime` (Descending)
- `callLogs`: `participants` (Arrays) + `createdAt` (Descending)
