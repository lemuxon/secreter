# 🔀 TURN SUNUCUSU KURULUMU

> **Neden gerekli:** TURN olmadan aramalar P2P kurulur ve **arayan ile
> aranan birbirinin gerçek IP adresini görür**. Telefon numarası
> istemeyen bir uygulamada IP, kimliğin en güçlü belirleyicilerinden
> biridir — bu, uygulamanın anonimlik iddiasındaki en büyük açıktır.
>
> TURN yapılandırıldığında `iceTransportPolicy: relay` devreye girer:
> yalnızca relay adayları toplanır, IP karşı tarafa **hiç gitmez**.

---

## 0. Karar: kendi sunucun mu, hazır servis mi

| | Kendi coturn'ün | Hazır servis (Twilio/Metered) |
|---|---|---|
| Maliyet | VPS kirası (aylık ~5 $) | GB başına ücret |
| Trafiği kim görür | **sen** | **servis sağlayıcı** |
| Kurulum | bu doküman | sağlayıcının API'si |
| Bu depodaki kod | hazır | kimlik akışı ayrıca yazılmalı |

Anonimlik iddiası taşıyan bir uygulamada **kendi sunucun** tercih
edilmelidir: relay, iki tarafın IP'sini gören tek noktadır. Bunu üçüncü
bir tarafa vermek, kaçınmaya çalıştığın ifşayı başka birine devretmek
olur.

> ⚠️ **Dürüst uyarı:** kendi TURN'ünü çalıştırırsan **sen** iki tarafın
> IP'sini görebilecek konuma geçersin. Coturn varsayılan olarak günlük
> tutar; aşağıdaki yapılandırma bunu kapatır. Gizlilik politikanda bu
> durumu yazmak gerekir.

---

## 1. Sunucu gereksinimleri

* Ubuntu 22.04+ (veya Debian 12+) bir VPS
* **Kalıcı** genel IP
* Bir alan adı (TLS için şart, ör. `turn.ornek.com`)
* Bant genişliği: her arama **çift yönlü** relay'lenir. Kaba hesap:
  * sesli arama ≈ 50 kbit/sn → saatte ~45 MB
  * görüntülü arama ≈ 500 kbit/sn → saatte ~450 MB

Portlar:

| Port | Protokol | Ne için |
|---|---|---|
| 3478 | UDP + TCP | standart TURN |
| 5349 | TCP | TURN over TLS (turns:) |
| **443** | TCP | **kısıtlı ağlar için kritik** — kurumsal güvenlik duvarları 3478'i kapatır, 443'ü kapatamaz |
| 49152–65535 | UDP | relay aralığı |

---

## 1b. Hızlı yol — `scripts/turn_kur.sh`

Aşağıdaki 2–4. bölümlerin tamamını tek komut yapar (sunucuda, root):

```bash
sudo bash turn_kur.sh turn.ornek.com
```

Elle yapılırken en sık atlanan ve **sessiz arızaya** yol açan üç şeyi
kendiliğinden halleder:

| Atlanırsa | Ne olur |
|---|---|
| `external-ip` | NAT arkasında aday toplanır ama medya HİÇ akmaz |
| Günlük kapatma | Relay iki tarafın IP'sini görür; kayıt diske yazılır |
| Yenileme kancası | Sertifika 90 gün sonra eskir, `turns:` çalışmaz |

Betik var olan sırrı **korur** (yeniden üretmek Cloud Function'daki
değerle ayrışma ve "kimlik reddedildi" demektir) ve eski yapılandırmayı
yedekler. Sonunda `functions/.env` için hazır satırları yazdırır.

> Ne yaptığını satır satır görmek istersen aşağıdaki bölümler betiğin
> yaptığı işin aynısıdır.

---

## 2. Coturn kurulumu

```bash
sudo apt update && sudo apt install -y coturn
sudo sed -i 's/^#TURNSERVER_ENABLED/TURNSERVER_ENABLED/' /etc/default/coturn
```

### TLS sertifikası (Let's Encrypt)

```bash
sudo apt install -y certbot
sudo certbot certonly --standalone -d turn.ornek.com
sudo usermod -a -G ssl-cert turnserver
sudo chgrp ssl-cert /etc/letsencrypt/live /etc/letsencrypt/archive
sudo chmod g+rx /etc/letsencrypt/live /etc/letsencrypt/archive
```

### Paylaşılan sırrı üret

Bu değer `TURN_SECRET` ile **birebir aynı** olmalı:

```bash
openssl rand -hex 32
```

---

## 3. `/etc/turnserver.conf`

```conf
listening-port=3478
tls-listening-port=5349
# Kisitli aglar icin 443/TCP — kurumsal guvenlik duvarlari 3478'i kapatir
alt-tls-listening-port=443

# VPS'in gercek IP'si. NAT arkasindaysa: external-ip=GENEL_IP/OZEL_IP
listening-ip=0.0.0.0
external-ip=SUNUCU_GENEL_IP

realm=turn.ornek.com
server-name=turn.ornek.com

# ── KIMLIK DOGRULAMA ──
# Kisa omurlu (REST) kimlik. Kalici kullanici/parola TANIMLANMAZ:
# istemciye gomulen bir parola APK'dan cikarilabilir.
use-auth-secret
static-auth-secret=YUKARIDA_URETILEN_SIR

cert=/etc/letsencrypt/live/turn.ornek.com/fullchain.pem
pkey=/etc/letsencrypt/live/turn.ornek.com/privkey.pem

# ── GIZLILIK ──
# Coturn varsayilan olarak her oturumu (IP'lerle birlikte) gunluge yazar.
# Iki tarafin IP'sini goren tek nokta burasi; kayit tutmamak esastir.
no-stdout-log
syslog
# Ayrintili oturum gunlugunu kapat
no-cli

# ── SERTLESTIRME ──
# Ic aglara relay YASAK: aksi halde TURN, ic agini taramak icin
# kullanilabilecek bir sicrama tahtasina donusur (SSRF benzeri).
denied-peer-ip=0.0.0.0-0.255.255.255
denied-peer-ip=10.0.0.0-10.255.255.255
denied-peer-ip=127.0.0.0-127.255.255.255
denied-peer-ip=169.254.0.0-169.254.255.255
denied-peer-ip=172.16.0.0-172.31.255.255
denied-peer-ip=192.168.0.0-192.168.255.255
denied-peer-ip=::1
denied-peer-ip=fc00::-fdff:ffff:ffff:ffff:ffff:ffff:ffff:ffff
denied-peer-ip=fe80::-febf:ffff:ffff:ffff:ffff:ffff:ffff:ffff

# Eski/zayif protokoller
no-tlsv1
no-tlsv1_1
no-multicast-peers

# Kotuye kullanim sinirlari
user-quota=12
total-quota=1200
max-bps=0

min-port=49152
max-port=65535

fingerprint
```

Başlat:

```bash
sudo systemctl enable coturn && sudo systemctl restart coturn
sudo systemctl status coturn
```

### Güvenlik duvarı

```bash
sudo ufw allow 3478/udp
sudo ufw allow 3478/tcp
sudo ufw allow 5349/tcp
sudo ufw allow 443/tcp
sudo ufw allow 49152:65535/udp
```

---

## 4. Cloud Function yapılandırması

Function, coturn'ün beklediği kimliği üretir:

```
username = <bitiş-zaman-damgası>:<opak-kimlik>
password = base64(HMAC-SHA1(TURN_SECRET, username))
```

Kullanıcı adında **uid kullanılmaz**, rastgele opak bir değer üretilir —
aksi halde TURN sunucusu IP ile hesabı kalıcı olarak ilişkilendirebilirdi.

### Basit yol — `functions/.env`

```bash
cat > functions/.env <<'EOF'
TURN_SECRET=YUKARIDA_URETILEN_SIR
TURN_URLS=turns:turn.ornek.com:443?transport=tcp,turn:turn.ornek.com:3478?transport=udp,turn:turn.ornek.com:3478?transport=tcp
TURN_TTL_SECONDS=43200
EOF
```

`.env` kök `.gitignore` tarafından zaten dışlanır — **doğrula**:

```bash
git check-ignore -v functions/.env
```

### Daha iyisi — Secret Manager

```bash
firebase functions:secrets:set TURN_SECRET
```

Ardından `functions/index.js` içindeki `getTurnCredentials` tanımını
şu hâle getir (gövde **değişmez**, sır yine `process.env`'den okunur):

```js
exports.getTurnCredentials = onCall({ secrets: ["TURN_SECRET"] }, async (req) => {
```

> Varsayılanda bağlanmaz: tanımlı olmayan bir sırrı bağlamak, TURN
> kullanmayan bir projede `firebase deploy --only functions` komutunu
> tamamen kırar.

### Dağıt

```bash
firebase deploy --only functions:getTurnCredentials
```

**URL sırası önemlidir.** En kısıtlı ağda çalışanı (`turns:443`) başa
koy: WebRTC listeyi sırayla dener.

---

## 5. Doğrulama

### a) Sunucu ayakta mı

```bash
sudo turnutils_uclient -T -u test -w test turn.ornek.com
```

(Kimlik hatası vermesi **normaldir** — `use-auth-secret` açık. Bağlantı
kurulup kimlik reddediliyorsa sunucu çalışıyor demektir.)

### b) Kimlik üretimi doğru mu

Function'ın ürettiğiyle aynı hesabı yerelde yap:

```bash
node -e '
const crypto=require("crypto");
const secret="YUKARIDA_URETILEN_SIR";
const username=`${Math.floor(Date.now()/1000)+43200}:test`;
console.log("username:", username);
console.log("credential:", crypto.createHmac("sha1",secret).update(username).digest("base64"));
'
```

Çıkan değerleri <https://icetest.info> veya Trickle ICE sayfasında dene:
**`relay` türünde aday** görünmelidir. Yalnızca `host`/`srflx` çıkıyorsa
TURN çalışmıyordur.

### c) Uygulamada

İki cihazla arama yap. Arama ekranında **🔒 "IP adresin gizli (relay)"**
yazmalıdır.

* ⚠️ **"IP adresin karşı tarafa görünüyor"** → TURN devrede değil.
  Function `configured: false` dönüyor olabilir; `firebase functions:log`
  bakılmalı.
* ☁️ **"Relay sunucusuna ulaşılamıyor"** → TURN yapılandırılmış ama
  erişilemiyor. Port/güvenlik duvarı/sertifika kontrol edilmeli.
  `relay` politikasında başka aday kaynağı olmadığı için arama kurulamaz.

```bash
adb logcat -d | grep -i turn
```

---

## 6. Sürdürme

* **Sertifika yenileme:** certbot yeniler ama coturn yeniden başlamazsa
  eski sertifikayı kullanmaya devam eder:

  ```bash
  echo '#!/bin/sh
  systemctl restart coturn' | sudo tee /etc/letsencrypt/renewal-hooks/deploy/coturn.sh
  sudo chmod +x /etc/letsencrypt/renewal-hooks/deploy/coturn.sh
  ```

* **Sır döndürme:** `static-auth-secret` ile `TURN_SECRET` **aynı anda**
  değişmelidir; arada kalan aramalar kopar. Sakin bir saatte yap.
  Kimlikler en fazla `TURN_TTL_SECONDS` kadar yaşadığı için eski sır o
  süre sonunda tamamen geçersizleşir.

* **Bant genişliği izleme:** relay tüm medyayı taşır. `total-quota` ve
  VPS trafik limitine dikkat et; sınır aşılırsa aramalar sessizce
  başarısız olur.

---

## 7. Uygulama tarafında ne değişti

| Dosya | Ne yapar |
|---|---|
| `functions/index.js` → `getTurnCredentials` | Kısa ömürlü kimlik üretir; yapılandırılmamışsa hata değil `{configured:false}` döner |
| `lib/services/turn_credentials_service.dart` | Kimliği alır, süresi dolana dek önbellekler, başarısızsa `--dart-define` yedeğine düşer |
| `lib/services/call_service.dart` | ICE yapılandırmasını bu servisten alır; TURN erişilemezliğini ayırt eder |
| `lib/services/active_call.dart` | Relay durumunu arama ekranına taşır |
| `lib/features/call/presentation/screens/call_screen.dart` | 🔒/⚠️ gizlilik rozetini gösterir |

**Yedek yol (önerilmez):** function dağıtılamıyorsa

```bash
flutter build appbundle --release \
  --dart-define=SECRETER_TURN_URL=turns:turn.ornek.com:443?transport=tcp,turn:turn.ornek.com:3478 \
  --dart-define=SECRETER_TURN_USER=... \
  --dart-define=SECRETER_TURN_PASS=...
```

> ❗ Bu değerler **APK'dan çıkarılabilir**. Kalıcı bir coturn kullanıcısı
> gerektirir (`user=...`), yani `use-auth-secret` ile birlikte
> kullanılamaz. Yalnızca geçiş dönemi içindir.
