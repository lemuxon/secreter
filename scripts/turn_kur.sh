#!/usr/bin/env bash
#
# 🔀 SECRETER — coturn kurulumu (Ubuntu 22.04+ / Debian 12+)
#
# Kullanım (sunucuda, root olarak):
#   sudo bash turn_kur.sh turn.ornek.com
#
# Adımları TURN_KURULUMU.md anlatıyor; bu betik onları tek komuta
# indirir. Elle yapılırken en sık atlanan üç şey burada otomatiktir ve
# üçü de SESSİZ arızaya yol açar:
#
#   1. `external-ip` — NAT arkasındaki VPS'te yazılmazsa coturn yanlış
#      adres duyurur; aday toplanır ama medya HİÇ akmaz.
#   2. Günlük kapatma — coturn varsayılan olarak her oturumu IP'lerle
#      birlikte diske yazar. Relay, iki tarafın IP'sini gören TEK
#      noktadır; orada kayıt tutmak, kaçınılmaya çalışılan ifşayı
#      kalıcı hâle getirir.
#   3. Sertifika yenileme kancası — Let's Encrypt 90 günde bir yeniler,
#      coturn yenilenen dosyayı KENDİLİĞİNDEN okumaz. Kanca olmazsa
#      aramalar üç ay sonra, hiçbir değişiklik yapılmadan bozulur.
#
set -euo pipefail

ALAN="${1:-}"
if [[ -z "$ALAN" ]]; then
  echo "Kullanım: sudo bash turn_kur.sh turn.ornek.com" >&2
  exit 1
fi

if [[ $EUID -ne 0 ]]; then
  echo "Bu betik root yetkisi ister: sudo bash turn_kur.sh $ALAN" >&2
  exit 1
fi

# VPS'in genel IP'si. Sağlayıcı NAT kullanıyorsa (Hetzner/DO genelde
# kullanmaz, AWS/GCP kullanır) coturn'ün duyurması gereken adres budur.
GENEL_IP="$(curl -fsS https://api.ipify.org || true)"
if [[ -z "$GENEL_IP" ]]; then
  echo "Genel IP öğrenilemedi. EXTERNAL_IP ortam değişkeniyle ver:" >&2
  echo "  EXTERNAL_IP=1.2.3.4 sudo -E bash turn_kur.sh $ALAN" >&2
  GENEL_IP="${EXTERNAL_IP:-}"
  [[ -z "$GENEL_IP" ]] && exit 1
fi
GENEL_IP="${EXTERNAL_IP:-$GENEL_IP}"

echo "▶ Alan adı : $ALAN"
echo "▶ Genel IP : $GENEL_IP"
echo

# ── DNS DENETİMİ ──
# Sertifika alımı DNS'e bağlı. Kayıt yoksa certbot yarı yolda düşer ve
# yarım bir kurulum bırakır; önce söylemek daha iyidir.
COZUM="$(getent hosts "$ALAN" | awk '{print $1}' | head -1 || true)"
if [[ -z "$COZUM" ]]; then
  echo "✖ $ALAN hiçbir adrese çözülmüyor. Önce A kaydını $GENEL_IP yap." >&2
  exit 1
fi
if [[ "$COZUM" != "$GENEL_IP" ]]; then
  echo "⚠ $ALAN → $COZUM, ama bu sunucu $GENEL_IP görünüyor."
  echo "  NAT arkasındaysan normal olabilir; değilse A kaydını düzelt."
  read -r -p "  Devam edilsin mi? [e/H] " yanit
  [[ "$yanit" == "e" || "$yanit" == "E" ]] || exit 1
fi

echo "▶ Paketler kuruluyor…"
export DEBIAN_FRONTEND=noninteractive
apt-get update -qq
apt-get install -y -qq coturn certbot

echo "▶ Sertifika alınıyor…"
# --standalone 80'i kısa süre kullanır; coturn 80'i dinlemez, çakışmaz.
certbot certonly --standalone --non-interactive --agree-tos \
  --register-unsafely-without-email -d "$ALAN"

# coturn, sertifika dosyalarını turnserver kullanıcısıyla okur.
usermod -a -G ssl-cert turnserver
chgrp ssl-cert /etc/letsencrypt/live /etc/letsencrypt/archive
chmod g+rx /etc/letsencrypt/live /etc/letsencrypt/archive

# ── PAYLAŞILAN SIR ──
# Varsa KORUNUR: yeniden üretmek, Cloud Function'daki değerle
# ayrışmaya ve "kimlik reddedildi" arızasına yol açardı.
SIR_DOSYA=/etc/turnserver.secret
if [[ -f "$SIR_DOSYA" ]]; then
  SIR="$(cat "$SIR_DOSYA")"
  echo "▶ Var olan sır korunuyor ($SIR_DOSYA)"
else
  SIR="$(openssl rand -hex 32)"
  printf '%s' "$SIR" > "$SIR_DOSYA"
  chmod 600 "$SIR_DOSYA"
  echo "▶ Yeni sır üretildi"
fi

if [[ -f /etc/turnserver.conf ]]; then
  cp -a /etc/turnserver.conf "/etc/turnserver.conf.yedek.$(date +%s)"
  echo "▶ Eski yapılandırma yedeklendi"
fi

sed -i 's/^#TURNSERVER_ENABLED/TURNSERVER_ENABLED/' /etc/default/coturn || true

echo "▶ /etc/turnserver.conf yazılıyor…"
cat > /etc/turnserver.conf <<CONF
listening-port=3478
tls-listening-port=5349
# Kisitli aglar icin 443/TCP — kurumsal guvenlik duvarlari 3478'i kapatir
alt-tls-listening-port=443

listening-ip=0.0.0.0
external-ip=$GENEL_IP

realm=$ALAN
server-name=$ALAN

# ── KIMLIK DOGRULAMA ──
# Kisa omurlu (REST) kimlik. Kalici kullanici/parola TANIMLANMAZ:
# istemciye gomulen bir parola APK'dan cikarilabilir.
use-auth-secret
static-auth-secret=$SIR

cert=/etc/letsencrypt/live/$ALAN/fullchain.pem
pkey=/etc/letsencrypt/live/$ALAN/privkey.pem

# ── GIZLILIK ──
# Relay, iki tarafin IP'sini goren TEK noktadir; kayit tutulmaz.
no-stdout-log
syslog
no-cli

# ── SERTLESTIRME ──
# Ic aglara relay YASAK: aksi halde TURN, ic agi taramak icin
# kullanilabilecek bir sicrama tahtasina donusur.
denied-peer-ip=0.0.0.0-0.255.255.255
denied-peer-ip=10.0.0.0-10.255.255.255
denied-peer-ip=127.0.0.0-127.255.255.255
denied-peer-ip=169.254.0.0-169.254.255.255
denied-peer-ip=172.16.0.0-172.31.255.255
denied-peer-ip=192.168.0.0-192.168.255.255
denied-peer-ip=::1
denied-peer-ip=fc00::-fdff:ffff:ffff:ffff:ffff:ffff:ffff:ffff
denied-peer-ip=fe80::-febf:ffff:ffff:ffff:ffff:ffff:ffff:ffff

no-tlsv1
no-tlsv1_1
no-multicast-peers

user-quota=12
total-quota=1200
max-bps=0

min-port=49152
max-port=65535

fingerprint
CONF
chmod 640 /etc/turnserver.conf

# ── SERTİFİKA YENİLEME KANCASI ──
# Bu olmadan aramalar 90 gün sonra, hiçbir şey değişmeden bozulur.
mkdir -p /etc/letsencrypt/renewal-hooks/deploy
cat > /etc/letsencrypt/renewal-hooks/deploy/coturn.sh <<'HOOK'
#!/bin/sh
# Yenilenen sertifikayi coturn'e okut. Kanca yoksa TLS 90 gun sonra
# sessizce eskir ve "turns:" baglantilari kurulmaz.
systemctl restart coturn
HOOK
chmod +x /etc/letsencrypt/renewal-hooks/deploy/coturn.sh

echo "▶ Güvenlik duvarı…"
if command -v ufw >/dev/null 2>&1; then
  ufw allow 3478/udp  >/dev/null
  ufw allow 3478/tcp  >/dev/null
  ufw allow 5349/tcp  >/dev/null
  ufw allow 443/tcp   >/dev/null
  ufw allow 49152:65535/udp >/dev/null
else
  echo "  ⚠ ufw yok — 3478/udp+tcp, 5349/tcp, 443/tcp ve"
  echo "    49152-65535/udp portlarını sağlayıcının panelinden aç."
fi

systemctl enable coturn >/dev/null
systemctl restart coturn
sleep 2
systemctl --no-pager --lines=5 status coturn || true

cat <<SON

──────────────────────────────────────────────────────────
✅ coturn kuruldu.

Şimdi UYGULAMA tarafı — bunları geliştirme makinende çalıştır:

  cd gizli_chat
  cat > functions/.env <<'EOF'
TURN_SECRET=$SIR
TURN_URLS=turns:$ALAN:443?transport=tcp,turn:$ALAN:3478?transport=udp,turn:$ALAN:3478?transport=tcp
TURN_TTL_SECONDS=43200
EOF
  firebase deploy --only functions:getTurnCredentials

⚠️ URL SIRASI ÖNEMLİ: WebRTC listeyi sırayla dener; en kısıtlı ağda
   çalışan (turns:443) başta olmalı.

⚠️ Bu sır uygulamanın TURN kimliğidir. Kaybolursa yenisini üretip
   HEM buradaki HEM functions/.env'deki değeri birlikte değiştir;
   yalnızca birini değiştirmek "kimlik reddedildi" demektir.

Doğrulama: iki cihazla arama yap. Arama ekranındaki rozet
"Aktarmalı bağlantı" 🔒 demeli — "Doğrudan bağlantı" diyorsa TURN
devrede değildir.
──────────────────────────────────────────────────────────
SON
