#!/usr/bin/env bash
#
# 🔐 SECRETER — yayın imzalama parolasını döndür
#
# Kullanım (proje kökünde, Git Bash):
#   bash scripts/imza_parolasi_dondur.sh
#
# ── NEDEN ──
# `android/key.properties` içindeki parola bir denetim sırasında ekranda
# görüntülendi (DEVAM.md: "Sızmış sırlar — döndürülmeli").
#
# ⚠️ DÜRÜST RİSK DEĞERLENDİRMESİ — bu bir ACİL DURUM DEĞİL.
# Parola tek başına işe yaramaz; imzalamak için `.jks` DOSYASI da
# gerekir ve o dosya bu makineden hiç çıkmadı (`.gitignore`da:
# `*.jks`, `android/key.properties`). Yine de ifşa olmuş bir parolayı
# döndürmek doğru hijyendir.
#
# ⚠️ BU BETİK PAROLAYI GÖRMEZ. `keytool` eski ve yeni parolayı kendisi
# sorar; betik yalnızca sırayı, yedeği ve doğrulamayı yönetir. Parola
# hiçbir komut satırına yazılmaz (yazılsaydı kabuk geçmişine ve
# `ps` çıktısına düşerdi).
#
# ⚠️ DAHA GÜÇLÜ SEÇENEK: parolayı değil ANAHTARIN KENDİSİNİ döndürmek.
# Play App Signing kullanıldığı için buradaki anahtar "yükleme
# anahtarı"dır ve Play Console'dan yenisiyle değiştirilebilir. Parola
# döndürmek bunun yerine geçmez; yalnızca ifşa olan değeri geçersiz
# kılar. Anahtarı döndürmek istersen Play Console → Uygulama bütünlüğü →
# Yükleme anahtarı sıfırlama.
#
set -euo pipefail

KP="android/key.properties"
[[ -f "$KP" ]] || { echo "✖ $KP yok. Proje kökünde misin?" >&2; exit 1; }

oku() { grep -E "^$1=" "$KP" | head -1 | cut -d= -f2- | tr -d '\r'; }

DEPO="$(oku storeFile)"
TAKMA_AD="$(oku keyAlias)"

[[ -n "$DEPO" && -n "$TAKMA_AD" ]] || {
  echo "✖ key.properties eksik (storeFile / keyAlias)." >&2; exit 1; }
[[ -f "$DEPO" ]] || { echo "✖ Anahtar deposu bulunamadı: $DEPO" >&2; exit 1; }

echo "▶ Depo      : $DEPO"
echo "▶ Takma ad  : $TAKMA_AD"
echo

# ── 1. YEDEK ──
# ⚠️ ÖNCE YEDEK. Parola değiştirme sırasında bir şey ters giderse ve
# depo bozulursa, bu uygulamaya bir daha GÜNCELLEME YAYINLAYAMAZSIN
# (Play'den yükleme anahtarı sıfırlatmak günler sürer).
DAMGA="$(date +%Y%m%d-%H%M%S)"
YEDEK="${DEPO}.yedek-${DAMGA}"
cp -p "$DEPO" "$YEDEK"
[[ -s "$YEDEK" ]] || { echo "✖ Yedek alınamadı, DURDURULDU." >&2; exit 1; }
echo "✅ Yedek: $YEDEK"
echo "   (İşlem bitip derleme doğrulanana kadar SİLME.)"
echo

cat <<'BILGI'
Şimdi keytool iki kez parola soracak:

  1) DEPO parolası  — önce eskisini, sonra yenisini (iki kez)
  2) ANAHTAR parolası — aynı şekilde

💡 Yeni parolayı üretmek için (ayrı bir terminalde):
     openssl rand -base64 24
   Sonra parola yöneticine kaydet. Bu betik parolayı GÖRMEZ ve
   HİÇBİR YERE yazmaz.

BILGI
read -r -p "Devam edilsin mi? [e/H] " yanit
[[ "$yanit" == "e" || "$yanit" == "E" ]] || { echo "Vazgeçildi."; exit 0; }

echo
echo "── 1/2: DEPO parolası ──"
keytool -storepasswd -keystore "$DEPO"

echo
echo "── 2/2: ANAHTAR parolası ──"
# Depo parolası az önce değişti; keytool burada YENİ depo parolasını
# soracak, sonra anahtarın eski ve yeni parolasını.
keytool -keypasswd -keystore "$DEPO" -alias "$TAKMA_AD"

echo
echo "✅ keytool tamam. Şimdi key.properties güncellenecek."
echo "   (Girdiğin değer ekranda GÖRÜNMEZ.)"
echo

read -r -s -p "Yeni DEPO parolası    : " YENI_DEPO; echo
read -r -s -p "Yeni ANAHTAR parolası : " YENI_ANAHTAR; echo

[[ -n "$YENI_DEPO" && -n "$YENI_ANAHTAR" ]] || {
  echo "✖ Boş parola kabul edilmez. key.properties DEĞİŞTİRİLMEDİ." >&2
  exit 1; }

cp -p "$KP" "${KP}.yedek-${DAMGA}"

# ⚠️ `sed` yerine satır satır yeniden yazım: parola içinde `/`, `&`, `\`
# gibi sed'in ANLAMLI saydığı karakterler olabilir ve dosyayı sessizce
# bozardı. `openssl rand -base64` çıktısında `/` sık görülür.
GECICI="$(mktemp)"
while IFS= read -r satir || [[ -n "$satir" ]]; do
  case "$satir" in
    storePassword=*) printf 'storePassword=%s\n' "$YENI_DEPO" ;;
    keyPassword=*)   printf 'keyPassword=%s\n'   "$YENI_ANAHTAR" ;;
    *)               printf '%s\n' "$satir" ;;
  esac
done < "$KP" > "$GECICI"
mv "$GECICI" "$KP"
unset YENI_DEPO YENI_ANAHTAR
echo "✅ key.properties güncellendi (yedeği: ${KP}.yedek-${DAMGA})"

# ── DOĞRULAMA ──
# ⚠️ ASIL KANIT DERLEMEDİR. `keytool -list` yalnızca depo parolasını
# doğrular; Gradle'ın ANAHTAR parolasıyla gerçekten imzalayabildiğini
# göstermez. Yanlış anahtar parolası ancak derleme sırasında patlar —
# ve o ana kadar her şey doğru görünür.
echo
echo "▶ Doğrulama derlemesi başlıyor (~3 dk)…"
if flutter build appbundle --release \
     --dart-define=GIPHY_API_KEY="${GIPHY_API_KEY:-}" >/dev/null 2>&1; then
  echo "✅ İmzalama çalışıyor. Yedekleri artık silebilirsin:"
  echo "     $YEDEK"
  echo "     ${KP}.yedek-${DAMGA}"
  echo
  echo "⚠️ Bu derlemede GIPHY_API_KEY ortam değişkeni verilmediyse GIF"
  echo "   sekmesi KAPALI gelir. Play'e YÜKLEME — yalnızca imza testiydi."
else
  echo "✖ DERLEME BAŞARISIZ — parola muhtemelen yanlış girildi." >&2
  echo "  Geri almak için:" >&2
  echo "    cp '$YEDEK' '$DEPO'" >&2
  echo "    cp '${KP}.yedek-${DAMGA}' '$KP'" >&2
  exit 1
fi
