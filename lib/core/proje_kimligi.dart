/// 📖 PROJENİN AÇIK KAYNAK KİMLİĞİ
///
/// ── NEDEN AYRI DOSYA ──
/// "Açık kaynak" bir pazarlama cümlesi değil, **doğrulanabilir bir
/// iddia**. Kullanıcı bunu okuduğunda kodu gidip görebilmeli. Bu yüzden
/// iddianın kendisi tek bir yerden, depo adresine BAĞLI olarak
/// üretiliyor.
///
/// ── 🔴 EN ÖNEMLİ KURAL ──
/// [depoAdresi] boşken arayüzde "açık kaynak" **yazmaz**. Bu kasıtlı:
/// kod yayımlanmadan bu cümleyi göstermek, gizlilik iddiası taşıyan bir
/// uygulamada yanlış beyan olur. Biri kontrol etmek isteyip hiçbir şey
/// bulamazsa en çok o iddia zarar görür.
///
/// Yani sıra şudur: **önce yayımla, sonra söyle.** Depoyu açtığın gün
/// buraya adresi yaz — satır o anda kendiliğinden görünür hâle gelir.
/// `proje_kimligi_test.dart` bu bağı ölçüyor.
library;

/// Genel depo adresi. **Depo gerçekten yayımlanana kadar BOŞ kalmalı.**
///
/// Doldurunca: Ayarlar → Hakkında altında "Açık kaynak" satırı belirir
/// ve dokunulduğunda buraya gider.
const String depoAdresi = 'https://github.com/lemuxon/secreter';

/// Kodun dağıtıldığı lisans. Depo yayımlanınca kök dizindeki `LICENSE`
/// dosyasıyla aynı olmalı.
const String lisansAdi = 'AGPL-3.0';

/// Arayüz "açık kaynak" diyebilir mi?
///
/// Tek koşul: gidip bakılabilecek bir adres olması. Lisans dosyası tek
/// başına yetmez — kimse okuyamıyorsa iddia doğrulanabilir değildir.
bool get acikKaynakGosterilebilir => depoAdresi.trim().isNotEmpty;
