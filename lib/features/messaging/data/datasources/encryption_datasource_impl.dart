import '../../../../core/error/exceptions.dart';
import '../../../../core/privacy/message_padding.dart';
import '../../../../services/auth_service.dart';
import '../../../../services/e2ee_session_service.dart';
import '../../../../services/group_key_service.dart';
import '../../../../services/rehandshake_service.dart';
import '../../../../services/self_note_service.dart';
import '../../../../services/x3dh_service.dart';
import 'encryption_datasource.dart';
import '../../../../core/observability/handled_error.dart';
import '../../../../core/security/security_alerts.dart';

/// EncryptionDataSource'un somut implementasyonu.
///
/// X3DH + Double Ratchet servislerini mesajlaşma katmanına köprüler.
/// İleride libsignal'e geçilirse yalnızca bu dosya değişir.
class EncryptionDataSourceImpl implements EncryptionDataSource {
  /// Son bilinen şifreleme durumu (sohbet başına).
  ///
  /// Bayrak `SharedPreferences`ta durur; her mesajda yazmak gereksiz
  /// disk trafiği olurdu. Yalnızca durum DEĞİŞTİĞİNDE yazılır.
  static final Map<String, bool> _plaintextState = {};

  static void _noteGroupPlaintext(String chatId, bool plaintext) {
    if (_plaintextState[chatId] == plaintext) return;
    _plaintextState[chatId] = plaintext;
    SecurityAlerts.setGroupSendsPlaintext(chatId, plaintext);
  }

  /// Bu çalıştırmada oturumu ZATEN sıfırlanmış sohbetler (§4av).
  ///
  /// Sıfırlama sohbet başına BİR KEZ denenir: her başarısız çözmede
  /// sıfırlamak, kötü niyetli bir üyenin sürekli oturum sıfırlatmasına
  /// (ve her seferinde yeniden el sıkışmaya) yol açardı.
  static final Set<String> _sifirlanan = {};

  /// Şifrelenemeyen mesaj için kullanıcıya gösterilen işaret.
  static const String lostMarker = EncryptionDataSource.lostMarker;

  @override
  Future<EncryptionResult> encrypt({
    required String chatId,
    required String otherUserId,
    required String plaintext,
    List<String> memberIds = const [],
  }) async {
    Map<String, dynamic>? header;

    // METADATA GİZLİLİĞİ: şifrelemeden önce sabit kovaya doldur, böylece
    // şifreli metnin uzunluğu içerik boyutunu ele vermez.
    final padded = MessagePadding.pad(plaintext);

    // ── 🗒️ KENDİNE MESAJ — HER ŞEYDEN ÖNCE ──
    //
    // ⚠️ SIRA KRİTİK. `uid_uid` sohbetinde `otherUserId` boş döner, yani
    // aşağıdaki grup dalına düşer; üye sayısı 1 olduğu için de
    // "dejenere grup" sayılıp mesaj **DÜZ METİN** giderdi. Özellik tam
    // olarak bu yüzden ertelenmişti. Kontrol buraya, her şeyin önüne
    // konur ki o dala hiç varılmasın.
    if (SelfNoteService.isSelfChat(chatId, AuthService.currentUid)) {
      return EncryptionResult(
        ciphertext: await SelfNoteService.encrypt(padded),
        isEncrypted: true,
      );
    }

    // ── GRUP / KANAL: SENDER KEY ──
    // Eskiden grup içeriği sunucuda DÜZ METİN duruyordu; yani "kimse
    // mesajlarını okuyamaz" iddiası yalnızca birebir sohbetler için
    // geçerliydi. Artık grup mesajları da uçtan uca şifrelenir.
    if (otherUserId.isEmpty) {
      final myUid = AuthService.currentUid;
      if (myUid == null || memberIds.length < 2) {
        // ── DEJENERE GRUP: şifrelenecek bir karşı taraf yok ──
        // ⚠️ Bu dal eskiden bir ARIZAYI da yutuyordu: üye listesi
        // okunamadığında repository `const []` dönüyordu ve mesaj burada
        // "dejenere grup" sayılıp ŞİFRESİZ gidiyordu. Artık okuma hatası
        // yukarı gidiyor (bkz. `MessageRepositoryImpl._membersOf`), yani
        // buraya yalnızca GERÇEKTEN tek kişilik bir grup düşer.
        //
        // §4aa/§4ae'de bant bağlanmıştı ama telemetri yoktu; diğer üç düz
        // metin yolu gibi burası da ÖLÇÜLEBİLİR olmalı — aksi halde bu
        // dalın gerçekte ne sıklıkta çalıştığı bilinemez.
        reportHandled('Grup dejenere (üye < 2) — mesaj ŞİFRESİZ',
            StateError('degenerate_group'));
        _noteGroupPlaintext(chatId, true);
        return EncryptionResult(ciphertext: plaintext, isEncrypted: false);
      }
      try {
        final envelope = await GroupKeyService.encrypt(
          chatId: chatId,
          myUid: myUid,
          memberIds: memberIds,
          plaintext: padded,
        );
        if (envelope != null) {
          _noteGroupPlaintext(chatId, false);
          return EncryptionResult(ciphertext: envelope, isEncrypted: true);
        }
        // ── BİLİNÇLİ TERCİH: kimsenin anahtarı yok ──
        // Hiçbir üyeye anahtar ulaştırılamadı. Şifrelemek mesajı HERKES
        // için okunmaz yapardı; erişilebilirlik gizliliğe tercih edilir.
        // Bu bir HATA DEĞİL, bir durum — ama sessiz kalmamalı: gerçekte
        // ne sıklıkta olduğu ölçülmeden bu tercihin bedeli bilinemez.
        reportHandled(
            'Grup E2EE kurulamadı (kimsenin anahtarı yok) — mesaj ŞİFRESİZ',
            StateError('no_group_key'));
        // Kullanıcı da bilmeli: sohbet ekranı bunu bant olarak gösterir.
        _noteGroupPlaintext(chatId, true);
      } catch (e, s) {
        // ⚠️ C-06 BURADA KAPATILDI.
        //
        // Eskiden buradan düşen mesaj aşağıda ŞİFRESİZ gönderiliyordu.
        // Ama bir İSTİSNA ile "kimsenin anahtarı yok" durumu AYNI ŞEY
        // DEĞİL: ilki bir arıza, ikincisi belgelenmiş bir tercih.
        // Arıza yüzünden düz metne düşmek, C-06'nın ta kendisiydi
        // ("şifreleme hatası sessizce DÜZ METNE düşüyordu").
        //
        // Artık FIRLATIR: mesaj GÖNDERİLMEZ ve kullanıcı bilgilendirilir
        // (`sendTextMessage` bunu `EncryptionFailure`a çevirir). Şifreli
        // sanılan bir mesajın açıkta gitmesindense gönderilmemesi
        // yeğdir; kullanıcı tekrar deneyebilir.
        reportHandled('Grup şifrelemesi başarısız — mesaj GÖNDERİLMEDİ', e,
            stack: s);
        throw const EncryptionException('err_encrypt_failed');
      }
      return EncryptionResult(ciphertext: plaintext, isEncrypted: false);
    }

    try {
      // Oturum yoksa X3DH ile kur.
      if (!await E2EESessionService.hasSession(chatId)) {
        final initHeader = await E2EESessionService.initiateSession(
          chatId: chatId,
          otherUserId: otherUserId,
        );
        if (initHeader == null) {
          // Karşı tarafın anahtar paketi yok (henüz uygulamayı açmamış).
          // Mesaj okunabilir olsun diye ŞİFRESİZ gider ve arayüzde kilit
          // simgesi GÖRÜNMEZ — kullanıcı durumu görebilir.
          // ⚠️ BİREBİR sohbette de düz metne düşülüyor. §4aa yalnızca
          // GRUP yolunu kapsıyordu; burası sinyalsiz kalıyordu ve kullanıcı
          // durumu ancak kilit simgesinin YOKLUĞUNDAN anlayabilirdi —
          // kimsenin fark etmediği bir sinyal.
          reportHandled('Karşı tarafın anahtar paketi yok — mesaj ŞİFRESİZ',
              StateError('no_peer_key'));
          _noteGroupPlaintext(chatId, true);
          return EncryptionResult(ciphertext: plaintext, isEncrypted: false);
        }
        header = initHeader.toMap();
      } else {
        // ── OTURUM VAR AMA ONAYLANMADIYSA BAŞLIĞI YİNE EKLE (§4be) ──
        //
        // 🐞 GERÇEK KULLANICIDA TEKRAR TEKRAR GÖRÜLDÜ: başlık YALNIZCA
        // ilk mesaja ekleniyordu. İki taraf da aynı anda yazmaya
        // başlarsa ("çapraz el sıkışma") her biri KENDİ oturumunu kurar;
        // diğerinin başlığını kimlik değişmediği için yok sayar
        // (`ensureSessionFromHeader` yalnızca kimlik/efemeral değişimine
        // bakar ve başlatan taraf karşının efemeralini saklamaz).
        // Sonraki mesajlarda başlık olmadığı için ortada onarılacak
        // malzeme kalmaz ve sohbet TEK YÖNLÜ donar.
        //
        // Artık oturum onaylanana kadar başlık her mesajla gider. Tıkanan
        // taraf çözemediğinde elinde başlık BULUR ve aşağıdaki §4av
        // kurtarması oturumu sıfırlayıp başlıktan yeniden kurar — o yol
        // kimlik denetimine takılmaz.
        //
        // Onay = karşı taraftan en az bir mesajı çözebilmek.
        header = await E2EESessionService.pendingInitHeader(chatId);
      }

      final encrypted = await E2EESessionService.encryptMessage(
        chatId: chatId,
        plaintext: padded,
      );

      if (encrypted == null) {
        // Oturum durumu okunamadı. ⚠️ Eski kod burada mesajı GÖNDERENİN
        // KENDİ anahtarıyla AES'leyip `isEncrypted: false` işaretliyordu;
        // alıcı o anahtara sahip olmadığı için ekranda base64 çöplüğü
        // görüyordu. Artık böyle bir yol yok: ya gerçek E2EE ya da
        // açıkça şifresiz.
        // ⚠️ Bu bir DURUM değil, bir ARIZA: oturum deposu okunamadı.
        // §4x'in mantığıyla kapatılması (göndermemek) tartışılmalı — ama
        // önce ne sıklıkta olduğu ölçülmeli. Bkz. `DEVAM.md` §3b.
        reportHandled('E2EE oturum durumu okunamadı — mesaj ŞİFRESİZ',
            StateError('session_unreadable'));
        _noteGroupPlaintext(chatId, true);
        return EncryptionResult(ciphertext: plaintext, isEncrypted: false);
      }

      // Şifreleme çalıştı → varsa uyarı bandını kaldır. Kalıcı bant,
      // karşı taraf anahtarlarını yayınladıktan sonra da asılı kalır ve
      // bir süre sonra görmezden gelinirdi.
      _noteGroupPlaintext(chatId, false);
      return EncryptionResult(
        ciphertext: encrypted,
        isEncrypted: true,
        e2eeHeader: header,
      );
    } on X3DHException catch (e) {
      // İmza doğrulanamadı / anahtar bozuk → ARAYA GİRME olasılığı.
      // Bu durumda sessizce şifresiz göndermek TEHLİKELİDİR; hata
      // yükseltilir ve kullanıcıya gösterilir.
      throw EncryptionException(e.key);
    } catch (e, s) {
      reportHandled('Şifreleme başarısız', e, stack: s);
      throw const EncryptionException('err_crypto');
    }
  }

  /// Birebir sohbette karşı tarafın uid'si; grup/kanal ise null.
  ///
  /// `chatId` sıralı uid'lerin birleşimidir (`a_b`). Kendine sohbette
  /// iki parça AYNI olduğu için null döner — orada el sıkışacak kimse
  /// yoktur.
  static String? _birebirKarsiTaraf(String chatId, String? myUid) {
    if (myUid == null || myUid.isEmpty) return null;
    final parts = chatId.split('_');
    if (parts.length != 2) return null;
    final karsi = parts.firstWhere((p) => p != myUid, orElse: () => '');
    return karsi.isEmpty ? null : karsi;
  }

  @override
  Future<String> decrypt({
    required String chatId,
    required String ciphertext,
    required bool isFromMe,
    required String messageId,
    Map<String, dynamic>? e2eeHeader,
    bool isGroup = false,
  }) async {
    try {
      // ── 1. İDEMPOTAN ÇÖZME ──
      // Ratchet tek yönlü ve tek seferliktir: bir şifreli metin yalnızca bir
      // kez çözülebilir. Arayüz her snapshot'ta tüm listeyi yeniden çözmeye
      // kalktığı için, çözülmüş metin cihazda saklanır ve tekrar çözülmez.
      final cached = await E2EESessionService.getPlaintext(messageId);
      if (cached != null) return cached;

      // ── 1b. KENDİNE MESAJ ──
      // Grup dalından ÖNCE: `uid_uid` sohbetinde `isGroup` true gelir ve
      // zarf grup çözücüsüne gider, oradan da `lostMarker`a düşerdi.
      if (SelfNoteService.isSelfEnvelope(ciphertext)) {
        // ⚠️ DÜZ METİN ÖNBELLEĞE YAZILMAZ — bilerek.
        //
        // Diğer yollarda önbellek ZORUNLU: ratchet ileri gittiği için
        // gönderen kendi şifreli metnini bir daha çözemez. Burada ise
        // anahtar simetrik ve sabittir; zarf her seferinde yeniden
        // çözülebilir. Önbellek yalnızca cihazda FAZLADAN bir düz metin
        // kopyası bırakırdı.
        return MessagePadding.unpad(await SelfNoteService.decrypt(ciphertext));
      }

      // ── 2. GRUP ZARFI ──
      // Grup mesajları gönderenin "sender key" zincirinden çözülür.
      // Gönderen kendi mesajını da çözebilir (zincir kendisinde).
      if (isGroup || GroupKeyService.isGroupEnvelope(ciphertext)) {
        final myUid = AuthService.currentUid;
        if (myUid == null) return lostMarker;
        final plain = await GroupKeyService.decrypt(
          chatId: chatId,
          myUid: myUid,
          ciphertext: ciphertext,
        );
        if (plain == null) return lostMarker;
        final unpadded = MessagePadding.unpad(plain);
        await E2EESessionService.cachePlaintext(messageId, unpadded);
        return unpadded;
      }

      // ── 3. GÖNDEREN KENDİ MESAJI (birebir) ──
      // Ratchet ileri gittiği için gönderen kendi şifreli metnini çözemez;
      // düz metni gönderirken sakladık. Cache yoksa (yeniden kurulum,
      // güvenli depo sıfırlanması) kurtarma imkânı yoktur.
      if (isFromMe) return lostMarker;

      // ── 4. GELEN BAŞLIKLA OTURUMU HAZIRLA ──
      // Eskiden yalnızca "oturum YOKSA" kuruluyordu. Karşı taraf
      // uygulamayı yeniden kurduğunda yeni kimlik anahtarıyla yeni bir
      // başlık gönderir; oturum güncellenmediği için o sohbetteki
      // sonraki TÜM mesajlar sessizce çözülemez hâle geliyordu.
      // Artık anahtar değişimi fark edilir: oturum yenilenir, kullanıcı
      // doğrulaması düşer ve sohbette uyarı bandı gösterilir.
      E2EEInitHeader? gecerliBaslik;
      if (e2eeHeader != null) {
        final header = E2EEInitHeader.fromMap(e2eeHeader);
        if (header.isValid) {
          gecerliBaslik = header;
          await E2EESessionService.ensureSessionFromHeader(
            chatId: chatId,
            header: header,
          );
        } else if (!await E2EESessionService.hasSession(chatId)) {
          // Bozuk başlık + kurulu oturum yok → çözülecek bir şey yok.
          return lostMarker;
        }
      }

      var decrypted = await E2EESessionService.decryptMessage(
        chatId: chatId,
        ciphertext: ciphertext,
        // Düz metin, ratchet ilerlemesi kalıcılaşmadan ÖNCE yazılsın:
        // arada uygulama ölürse mesaj kalıcı olarak çözülemez olurdu.
        messageId: messageId,
      );

      // ── KURTARMA: BOZUK OTURUMU BAŞLIKTAN YENİDEN KUR (§4av) ──
      //
      // 🐞 GERÇEK KULLANICIDA GÖRÜLDÜ. `ensureSessionFromHeader` oturumu
      // YALNIZCA karşı tarafın KİMLİK anahtarı değişince yeniler:
      //
      //     if (pinned == header.identityKey) return false;  // dokunma
      //
      // Ama oturumu bozan şey kimlik değişimi olmak zorunda değil.
      // §4au'daki hatada kimlik AYNI kaldı, bozulan İMZALI ÖN-ANAHTARDI:
      // karşı taraf bizim eski (ezilmiş) ön-anahtarımızla oturum kurmuştu.
      // Paket sonradan onarıldı ama OTURUM bozuk kaldı ve o sohbetteki
      // her mesaj sessizce "çözülemiyor" oldu — kurtarma yolu yoktu.
      //
      // Artık: çözme başarısızsa ve elimizde GEÇERLİ bir başlık varsa,
      // oturum sıfırlanıp başlıktan yeniden kurulur ve BİR KEZ denenir.
      // Başlık, gönderenin kendi kimlik/ön-anahtarını taşır; yani yeniden
      // kurmak için gereken her şey elimizdedir.
      //
      // ⚠️ TEK DENEME. Döngüye girmemesi için yalnızca bir kez.
      if (decrypted == null && gecerliBaslik != null) {
        reportHandled('E2EE oturumu bozuk — başlıktan yeniden kuruluyor',
            StateError('session_rebuild_attempt'),
            context: {'chatId': chatId});
        await E2EESessionService.resetSession(chatId);
        await E2EESessionService.ensureSessionFromHeader(
          chatId: chatId,
          header: gecerliBaslik,
        );
        decrypted = await E2EESessionService.decryptMessage(
          chatId: chatId,
          ciphertext: ciphertext,
          messageId: messageId,
        );
      }

      // ── BAŞLIKSIZ BAŞARISIZLIK: OTURUMU SIFIRLA (§4av) ──
      //
      // 🐞 Başlık YALNIZCA gönderen oturumu ilk kurarken eklenir; sonraki
      // mesajlarda yoktur. Yani alıcının oturumu bozulursa alıcının
      // elinde yeniden kuracak hiçbir şey KALMAZ — yukarıdaki kurtarma
      // da bu yüzden tetiklenemez. Sohbet kalıcı olarak ölür.
      //
      // Tek çıkış, oturumu yeniden GÖNDERENİN başlatması. Bunu tetiklemek
      // için kendi oturumumuzu siliyoruz: bu sohbete bir sonraki
      // yazışımızda `encrypt()` "oturum yok" görüp X3DH'i baştan kurar ve
      // BAŞLIK ekler; karşı taraf o başlıkla kendi tarafını onarır.
      //
      // ⚠️ Mesajı KURTARMAZ — o mesaj çözülemez kalır. Sohbetin bundan
      // SONRASINI kurtarır.
      if (decrypted == null && _sifirlanan.add(chatId)) {
        reportHandled(
            'E2EE oturumu çözemedi ve başlık yok — oturum sıfırlandı, '
            'sessiz el sıkışma yayımlanıyor',
            StateError('session_reset_for_rehandshake'),
            context: {'chatId': chatId});
        await E2EESessionService.resetSession(chatId);

        // ── 🤝 SESSİZ YENİDEN EL SIKIŞMA (§4cc) ──
        //
        // Eskiden burada DURULUYOR ve onarım KULLANICININ bir şey
        // yazmasına bırakılıyordu. Gerçek kullanımda bu eziyet üretti:
        // karşı taraf saatler sonra dönüp mesajlarının "çözülemedi"
        // olduğunu görüyor ve konuşmanın tamamı yeniden anlatılıyordu.
        // WhatsApp/Signal böyle davranmaz.
        //
        // Artık X3DH'i biz başlatır ve başlığı yayımlarız; karşı taraf
        // o sohbeti AÇMADAN kendi tarafını onarır.
        //
        // ⚠️ Yalnızca BİREBİR sohbette. Grupta oturum kavramı farklıdır
        // (sender key) ve bu yol uygulanamaz.
        final ben = AuthService.currentUid;
        final karsi = _birebirKarsiTaraf(chatId, ben);
        if (!isGroup && ben != null && karsi != null) {
          await RehandshakeService.yayinla(
            chatId: chatId,
            otherUserId: karsi,
            myUid: ben,
          );
        }
      }

      if (decrypted == null) return lostMarker;

      final plain = MessagePadding.unpad(decrypted);
      // Bir daha ratchet'i ilerletmemek için sakla.
      await E2EESessionService.cachePlaintext(messageId, plain);
      return plain;
    } on X3DHException catch (e, s) {
      // Tek kullanımlık ön-anahtar eksik / imza geçersiz. Sessizce
      // "çözülemedi" göstermek yerine logla: oturum sıfırlanıp yeniden
      // kurulabilir.
      reportHandled('E2EE oturumu kurulamadı', e,
          stack: s, context: {'anahtar': e.key});
      return lostMarker;
    } catch (e, s) {
      // ⚠️ BURASI SESSİZDİ VE TEŞHİSİ İMKÂNSIZ KILIYORDU.
      //
      // `debugPrint` YAYIN derlemesinde hiçbir yere gitmez. "Bazı
      // mesajlar çözülemiyor" şikâyeti geldiğinde elde SEBEP yoktu:
      // çözme başarısız mı oldu, istisna mı attı, hangi aşamada —
      // hiçbiri bilinmiyordu. Bu dosyadaki diğer düz-metin/başarısızlık
      // yolları ÖLÇÜLEBİLİR (hepsi `reportHandled` çağırıyor); en sık
      // düşülen yolun ölçülmemesi, bu turda birkaç kez teşhisi tıkadı.
      //
      // `chatId` DEĞİL, yalnızca istisna türü raporlanır: sohbet kimliği
      // iki uid içerir ve telemetriye kim-kiminle bilgisi taşınamaz
      // (§4k/§4o'nun aynı ilkesi).
      reportHandled('Mesaj çözülemedi', e,
          stack: s, context: {'asama': 'decrypt', 'grup': isGroup});
      return lostMarker;
    }
  }

  @override
  Future<void> cachePlaintext(String messageId, String plaintext) =>
      E2EESessionService.cachePlaintext(messageId, plaintext);

  @override
  Future<void> warmPlaintextCache() => E2EESessionService.warmPlaintextCache();

  @override
  Future<void> forgetPlaintext(String messageId) =>
      E2EESessionService.forgetPlaintext(messageId);

  @override
  Future<void> forgetPlaintexts(Iterable<String> messageIds) =>
      E2EESessionService.forgetPlaintexts(messageIds);

  @override
  Future<void> wipeAllPlaintexts() => E2EESessionService.wipeAllPlaintexts();
}
