# 🎟️ PREMIUM — hesaba BAĞLANMAYAN yetki mimarisi

> Bu dosya premium altyapısının **neden** böyle kurulduğunu anlatır.
> Kod: `lib/core/premium/`, `functions/index.js → issueEntitlement`.

---

## 1. Neden basit yol reddedildi

Akla ilk gelen çözüm:

```dart
users/{uid}.isPremium = true
```

Bu, SECRETER'de **yapılamaz**. Uygulama telefon numarası istemez, kimlik
yalnızca cihazda durur ve tüm iddiası şu zincirin kurulamamasına dayanır:

```
gerçek kimlik → Google hesabı → Play satın alması → SECRETER uid → sohbetler
```

Google zaten ilk üç halkayı biliyor. Sunucumuz dördüncü halkayı da
öğrenirse zincir tamamlanır ve "kim olduğunuzu bilmiyoruz" iddiası
çöker — üstelik **ödeme yapan kullanıcılar için**, yani uygulamaya en
çok güvenenler için.

`DEVAM.md` bu uyarıyı baştan taşıyordu: *"Sonradan eklemek çok daha zor;
baştan böyle kurulmalı."*

---

## 2. Çözüm: kör imza (Chaum)

Sunucu, **görmediği** bir değeri imzalar.

```
1. İstemci rastgele bir nonce üretir              (cihazda kalır)
2. Onu körleştirir:  b = FDH(nonce) · rᵉ mod n    (r cihazda kalır)
3. Sunucuya gider:   b + Play satın alma jetonu
4. Sunucu satın almayı Google'a doğrular,
   jetonu "kullanıldı" işaretler,
   kör imzalar:      s = b^d mod n
5. İstemci körlüğü kaldırır: sig = s · r⁻¹ mod n
```

Sonuç: istemcinin elinde, sunucunun **hiç görmediği** `nonce` üzerine
geçerli bir imza vardır. Yetki sunulduğunda sunucu imzayı doğrular ama
onu hangi satın almanın ürettiğini bilemez.

> **Sunucu "biri ödedi" der, "bu uid ödedi" demez.**

---

## 3. Kritik tasarım kararları

### 3.1 Uç nokta KİMLİK DOĞRULAMASIZ — kasıtlı

`issueEntitlement` bir `onCall` değil, `onRequest`tir ve Firebase
kimliği istemez.

`onCall` kullanılsaydı sunucu çağrıyla birlikte **uid'yi görürdü** ve
kör imzanın tüm anlamı kaybolurdu: körleştirme, sunucunun zaten bildiği
bir bağlantıyı gizlemez. Kanıt, satın alma jetonunun kendisidir.

### 3.2 Sunucu körleştirilmiş değeri SAKLAMAZ

Bu, yapılması en kolay hata. Sunucu `blinded` ve `blindSignature`
değerlerini saklarsa, sonradan sunulan `(nonce, sig)` için:

```
r' = blindSignature · sig⁻¹ mod n
blinded =? FDH(nonce) · r'ᵉ mod n
```

eşitliğini sınayarak sunumu satın almaya **bağlayabilir**. Yani jetonu
saklamak kör imzayı tamamen anlamsız kılar.

**Saklanan:** satın alma jetonunun ÖZETİ + körleştirilmiş değerin ÖZETİ.
**Saklanmayan:** değerlerin kendisi.

Özetten `blinded` geri getirilemediği için saldırı mümkün değildir.

### 3.3 Güvenli tekrar deneme

Ağ, imzalamadan sonra koparsa kullanıcı ödemiş ama yetki alamamış olur.
Çözüm özet saklamanın yan faydasıdır: istemci **aynı** körleştirilmiş
değerle tekrar çağırır, sunucu özetin eşleştiğini görüp yeniden imzalar.
RSA imzası deterministiktir, sonuç aynıdır.

Farklı bir körleştirilmiş değer gelirse (aynı satın almadan ikinci yetki
çıkarma denemesi) `409 already_redeemed` döner.

### 3.4 Son kullanma tarihi ANAHTARDA, jetonda değil

Sunucu körleştirilmiş değeri göremediği için içine tarih **yazamaz**;
istemci kendi yazsa istediği tarihi uydurur.

Bu yüzden her dönem için ayrı imza anahtarı kullanılır
(`prem-2026-10` gibi) ve yetkinin ömrü **o anahtarın geçerlilik
penceresidir**. Privacy Pass'in "epoch key" yaklaşımı.

> ⚠️ **Anonimlik kümesi = o dönemde yetki alan herkes.** Dönem ne kadar
> kısa olursa küme o kadar küçülür ve bağlanabilirlik artar. Aylıktan
> daha kısa yapılmamalıdır.

---

## 4. Dürüst sınırlar

* **İstemci tarafı kontrol bir kapı değildir.** Değiştirilmiş bir
  istemci yerel kontrolü atlar. Sunucuda uygulanan özellikler jetonu
  sunucuya göndermeli ve orada doğrulanmalıdır — kör imza tam da bunu
  güvenli kılmak için var.
* **IP gizlenmez.** Yetki sunulurken sunucu IP'yi görür. Bu, TURN'deki
  sorunla aynı sınıftır (bkz. `GUVENLIK_DUZELTMELERI.md` §4f) ve ayrı
  bir konudur.
* **Zamanlama korelasyonu.** Satın alma ile ilk kullanım arasındaki süre
  çok kısaysa sunucu istatistiksel tahmin yürütebilir. Kullanım
  koleksiyonu istemciye kapalıdır ama sunucu operatörü kendi kayıtlarını
  görür.
* **Klasik Chaum kurulumu.** Üretimde RFC 9474 (RSABSSA) tercih
  edilebilir. İmza anahtarı YALNIZCA yetki için kullanılmalıdır; aynı
  anahtarı başka amaçla kullanmak "bir-fazla imza" saldırısına kapı
  açar.

---

## 5. Yapılanlar / Kalanlar

### ✅ Yapıldı
* Kör imza matematiği (`blind_signature.dart`) — 15 test
* Yetki jetonu + doğrulayıcı (`entitlement.dart`) — 11 test
* `issueEntitlement` Cloud Function iskeleti (tek kullanım, güvenli
  tekrar deneme, özet-saklama)
* `entitlementRedemptions` koleksiyonu istemciye tamamen kapalı — 3 kural
  testi

### ❌ Kalanlar (altyapı gerektirir)

1. **Play Console ürünleri** — abonelik/ürün tanımları.
2. **Hizmet hesabı + Play Developer API** — `issueEntitlement` içindeki
   `purchaseVerified` şu an `false`; doğrulama bağlanana kadar fonksiyon
   `501` döner. **Doğrulama bağlanmadan üretime çıkarılmamalıdır.**
3. **Dönem anahtarları** — RSA 2048+, ortam değişkeni olarak:
   `ENTITLEMENT_KEY_PREM_2026_10` (PEM). Açık anahtar istemciye gömülür.
   Rotasyon takvimi belirlenmelidir.
4. **İstemci satın alma akışı** — `in_app_purchase` paketi, satın alma
   sonrası `issueEntitlement` çağrısı, jetonu `SecureStore`a yazma.
5. **Hangi özellikler premium?** Henüz belirlenmedi. Sunucuda uygulanan
   bir özellik varsa jeton sunucuya gönderilmeli.

> ⚠️ Kalanların hiçbiri mimariyi değiştirmez. Zor olan kısım —
> bağlanamazlık — kurulu ve test altında.
