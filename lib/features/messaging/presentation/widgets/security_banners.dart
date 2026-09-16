import 'package:flutter/material.dart';

import '../../../../core/i18n/app_localizations.dart';
import '../../../../utils/app_theme.dart';

/// 🛡️ SOHBET EKRANI GÜVENLİK BANTLARI
///
/// Sohbet ekranından AYRI dosyada duruyorlar çünkü tek başlarına
/// sınanabilmeleri gerekiyor: bir bandın doğru koşulda çıkması bir
/// güvenlik özelliğidir, "herhalde çalışıyordur" denecek bir şey değil.
/// `MessagingScreen` içinde gömülü olsalardı test etmek için Firestore,
/// Riverpod ve E2EE oturumu ayağa kaldırmak gerekirdi.
///
/// Her bant KENDİ yüksekliğini söyler (`.height`); sohbet ekranı
/// bantları üst üste dizerken ve liste dolgusunu hesaplarken bu
/// değerleri toplar.
///
/// ⚠️ ESKİDEN TEK SABİT VARDI (`kSecurityBannerHeight = 38`) ve tüm
/// bantlar tek satıra sıkışıyordu. İki ayrı arıza çıktı:
///
///  1. Metinler KIRPILIYORDU. Türkçe doğrulama önerisi 360dp'lik bir
///     telefonda "…bu sohbeti doğr…" diye kesiliyordu; yarısı görünen
///     güvenlik bandı, görünmeyenle aynı işe yarar.
///  2. Sözleşme zaten TUTMUYORDU: kimlik değişimi bandı sohbet ekranının
///     içinde ayrı yazılmıştı ve yüksekliği elle `38` girilmişti —
///     sabit değişse bantlar mesaj listesiyle çakışacaktı. (Bu yüzden
///     o bant da buraya taşındı; kardeşleriyle aynı yerde ve aynı
///     testin altında.)
///
/// 📏 Satır sayıları TAHMİN DEĞİL: 16 dilin tamamı gerçek Roboto
/// metrikleriyle 360dp'de ölçüldü. Ortak bir yükseklik dayatmak, en
/// uzun metni (anahtar rotasyonu — Almanca/Ukraynaca) herkese ödetirdi:
/// doğrulama önerisi neredeyse HER doğrulanmamış sohbette görünüyor,
/// rotasyon uyarısı ise yalnızca rotasyon başarısız olduğunda.
///
/// `kirpilma` kapısı (`security_banners_test.dart`) bu değerlerin
/// yettiğini 16 dilde ölçer.
double bantYuksekligi(int satir) => satir * 16.0 + 20;

/// Bant sonundaki eylem düğmesinin alabileceği en fazla genişlik.
/// Çevrilmiş etiketler çok uzayabiliyor; sınır olmadan uyarı metninin
/// payını yiyorlar.
const double _kEylemEniMaks = 84;

/// 🔑 KARŞI TARAFIN KİMLİK ANAHTARI DEĞİŞTİ.
///
/// Genellikle uygulamayı yeniden kurmuş ya da cihaz değiştirmiştir —
/// ama araya girme girişimi de aynı görünür ve ikisi AYIRT EDİLEMEZ.
/// Bu yüzden kırmızı, kapatılamaz ve dokununca güvenlik numarası
/// ekranını açar.
///
/// ⚠️ Bu bant sohbet ekranının İÇİNDE yazılıydı ve iki şeyi birden
/// kaçırıyordu: yüksekliği elle `38` girilmişti (kardeşlerinin sabitine
/// bağlı değildi — sabit değişse bantlar mesaj listesiyle çakışırdı) ve
/// `maxLines: 1` olduğu için metni kırpılıyordu. Buraya taşındı;
/// kardeşleriyle aynı kapının altında.
class IdentityChangedBanner extends StatelessWidget {
  /// Uyarı metni en uzun olanlardan; 3 satır ölçüldü.
  static const int maxLines = 3;
  static final double height = bantYuksekligi(maxLines);

  final VoidCallback onOpen;

  const IdentityChangedBanner({super.key, required this.onOpen});

  @override
  Widget build(BuildContext context) => Material(
        color: const Color(0xFF3A1B23),
        child: InkWell(
          onTap: onOpen,
          child: SizedBox(
            height: height,
            child: const Padding(
              padding: EdgeInsets.symmetric(horizontal: 16),
              child: Row(
                children: [
                  Icon(Icons.gpp_maybe_rounded,
                      color: AppTheme.danger, size: 17),
                  SizedBox(width: 8),
                  Expanded(child: _KimlikMetni()),
                  Icon(Icons.chevron_right, color: AppTheme.danger, size: 18),
                ],
              ),
            ),
          ),
        ),
      );
}

class _KimlikMetni extends StatelessWidget {
  const _KimlikMetni();

  @override
  Widget build(BuildContext context) => Text(
        context.tr('safety_banner_changed'),
        maxLines: IdentityChangedBanner.maxLines,
        overflow: TextOverflow.ellipsis,
        style: const TextStyle(color: AppTheme.danger, fontSize: 12.5),
      );
}

/// ⚠️ GRUP ANAHTARI YENİLENEMEDİ.
///
/// Bir üye gruptan atıldığında anahtar rotasyona girer. Rotasyon
/// başarısız olursa **atılan üye elindeki anahtarla sonraki mesajları
/// çözmeye devam edebilir** — kullanıcı ise "onu attım, artık okuyamaz"
/// sanır. Bu yüzden bant:
///
///  * kimlik değişimi uyarısıyla AYNI ağırlıkta (kırmızı) çizilir,
///  * **kapatılamaz** — kullanıcı görmezden gelebilseydi durumu hiç
///    öğrenemezdi,
///  * doğrudan bir çözüm sunar: **Tekrar dene**.
class GroupKeyRotationBanner extends StatelessWidget {
  /// ⚠️ En uzun metin bu bantta. Sondaki "Tekrar dene" düğmesi de
  /// çevrilebilir ve bazı dillerde çok geniş ("Спробувати ще раз",
  /// "Erneut versuchen") — metne kalan payı o daraltıyor.
  static const int maxLines = 4;
  static final double height = bantYuksekligi(maxLines);

  final VoidCallback onRetry;

  const GroupKeyRotationBanner({super.key, required this.onRetry});

  @override
  Widget build(BuildContext context) => Material(
        color: const Color(0xFF3A1B23),
        child: SizedBox(
          height: height,
          child: Padding(
            padding: const EdgeInsets.only(left: 16, right: 8),
            child: Row(
              children: [
                const Icon(Icons.key_off_rounded,
                    color: AppTheme.danger, size: 17),
                const SizedBox(width: 8),
                Expanded(
                  child: Text(
                    context.tr('sec_rotation_failed'),
                    maxLines: maxLines,
                    overflow: TextOverflow.ellipsis,
                    style:
                        const TextStyle(color: AppTheme.danger, fontSize: 12.5),
                  ),
                ),
                // ⚠️ DÜĞME SINIRLI. Etiketi çevrilebilir ve bazı dillerde
                // çok geniş ("Спробувати ще раз", "Erneut versuchen");
                // sınırsız bırakılınca UYARI METNİNİN payını yiyor ve
                // asıl bilgi kırpılıyordu. Düğme sığmazsa etiketi
                // küçülür — uyarı metni kırpılmaz.
                ConstrainedBox(
                  constraints: const BoxConstraints(maxWidth: _kEylemEniMaks),
                  child: TextButton(
                    onPressed: onRetry,
                    style: TextButton.styleFrom(
                      foregroundColor: AppTheme.danger,
                      padding: const EdgeInsets.symmetric(horizontal: 8),
                      minimumSize: const Size(0, 30),
                      tapTargetSize: MaterialTapTargetSize.shrinkWrap,
                    ),
                    child: FittedBox(
                      fit: BoxFit.scaleDown,
                      child: Text(context.tr('sec_rotation_retry'),
                          maxLines: 1,
                          softWrap: false,
                          style: const TextStyle(
                              fontSize: 12.5, fontWeight: FontWeight.w600)),
                    ),
                  ),
                ),
              ],
            ),
          ),
        ),
      );
}

/// 🛡️ BU SOHBETİ DOĞRULA (öneri).
///
/// Güvenlik numarası ekranı vardı ama hiçbir yer oraya yönlendirmiyordu;
/// özellik pratikte kullanılmıyordu.
///
/// Uyarı DEĞİL öneri olduğu için nötr renkte ve **kapatılabilir**:
/// kapatılamayan bir öneri gürültüye dönüşür ve kullanıcı bir süre sonra
/// gerçek uyarıları da görmezden gelmeye başlar.
class VerifyPromptBanner extends StatelessWidget {
  /// Uzun dillerde bile 2 satır yetiyor (ölçüldü). Bu bant neredeyse
  /// her doğrulanmamış sohbette görünür; gereksiz yükseklik burada
  /// en pahalıya mal olur.
  static const int maxLines = 2;
  static final double height = bantYuksekligi(maxLines);

  final VoidCallback onOpen;
  final VoidCallback onDismiss;

  const VerifyPromptBanner({
    super.key,
    required this.onOpen,
    required this.onDismiss,
  });

  @override
  Widget build(BuildContext context) => Material(
        color: AppTheme.surface,
        child: SizedBox(
          height: height,
          child: Padding(
            padding: const EdgeInsets.only(left: 16, right: 8),
            child: Row(
              children: [
                const Icon(Icons.shield_outlined,
                    color: AppTheme.textSecondary, size: 17),
                const SizedBox(width: 8),
                Expanded(
                  child: GestureDetector(
                    behavior: HitTestBehavior.opaque,
                    onTap: onOpen,
                    child: Text(
                      context.tr('sec_verify_prompt'),
                      maxLines: maxLines,
                      overflow: TextOverflow.ellipsis,
                      style: const TextStyle(
                          color: AppTheme.textSecondary, fontSize: 12.5),
                    ),
                  ),
                ),
                TextButton(
                  onPressed: onDismiss,
                  style: TextButton.styleFrom(
                    foregroundColor: AppTheme.textSecondary,
                    padding: const EdgeInsets.symmetric(horizontal: 8),
                    minimumSize: const Size(0, 30),
                    tapTargetSize: MaterialTapTargetSize.shrinkWrap,
                  ),
                  child: Text(context.tr('sec_verify_later'),
                      style: const TextStyle(fontSize: 12.5)),
                ),
              ],
            ),
          ),
        ),
      );
}

/// 🔓 BU GRUPTA MESAJLAR ŞİFRESİZ GİDİYOR.
///
/// §4x arıza yolunu kapattı (istisnada mesaj gönderilmiyor). Geriye
/// **bilinçli** tercih kaldı: hiçbir üyeye anahtar ulaştırılamadıysa
/// mesaj şifresiz gider — aksi halde HERKES için okunmaz olurdu.
///
/// Tercih savunulabilir, GÖRÜNMEZ olması değil: arayüzde şifreli
/// mesajlar kilit ikonu taşıyor, şifresiz olan yalnızca kilidin
/// YOKLUĞUYLA belli oluyordu. Kimse bunu fark etmez.
///
/// Uyarı ama felaket değil — bu yüzden kırmızı değil **turuncu** ve
/// kapatılamaz (bir güvenlik sözü tutulamıyor; kullanıcı bunu
/// görmezden gelebilseydi şifreli sandığı grupta konuşmaya devam
/// ederdi).
class GroupPlaintextBanner extends StatelessWidget {
  /// Yunanca metin 3 satır istiyor; kalanı 2'de kalıyor.
  static const int maxLines = 3;
  static final double height = bantYuksekligi(maxLines);

  /// Temada "uyarı" rengi yok (yalnızca `danger` ve `secure` var).
  /// Kırmızı kullanmak bu bandı kimlik değişimi/anahtar rotasyonu
  /// uyarılarıyla aynı ağırlıkta gösterirdi; oysa bu, bilinçli bir
  /// tercihin sonucudur — ciddi ama felaket değil.
  static const Color _amber = Color(0xFFE0A458);

  const GroupPlaintextBanner({super.key});

  @override
  Widget build(BuildContext context) => Material(
        color: const Color(0xFF3A2A18),
        child: SizedBox(
          height: height,
          child: Padding(
            padding: const EdgeInsets.symmetric(horizontal: 16),
            child: Row(
              children: [
                const Icon(Icons.lock_open_rounded, color: _amber, size: 17),
                const SizedBox(width: 8),
                Expanded(
                  child: Text(
                    context.tr('sec_group_plaintext'),
                    maxLines: maxLines,
                    overflow: TextOverflow.ellipsis,
                    style: const TextStyle(color: _amber, fontSize: 12.5),
                  ),
                ),
              ],
            ),
          ),
        ),
      );
}
