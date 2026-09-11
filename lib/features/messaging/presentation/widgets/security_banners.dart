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
/// İkisi de 38 piksel yüksekliğindedir; sohbet ekranı bantları üst üste
/// dizerken bu sabite dayanır.
const double kSecurityBannerHeight = 38;

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
  final VoidCallback onRetry;

  const GroupKeyRotationBanner({super.key, required this.onRetry});

  @override
  Widget build(BuildContext context) => Material(
        color: const Color(0xFF3A1B23),
        child: SizedBox(
          height: kSecurityBannerHeight,
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
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style:
                        const TextStyle(color: AppTheme.danger, fontSize: 12.5),
                  ),
                ),
                TextButton(
                  onPressed: onRetry,
                  style: TextButton.styleFrom(
                    foregroundColor: AppTheme.danger,
                    padding: const EdgeInsets.symmetric(horizontal: 8),
                    minimumSize: const Size(0, 30),
                    tapTargetSize: MaterialTapTargetSize.shrinkWrap,
                  ),
                  child: Text(context.tr('sec_rotation_retry'),
                      style: const TextStyle(
                          fontSize: 12.5, fontWeight: FontWeight.w600)),
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
          height: kSecurityBannerHeight,
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
                      maxLines: 1,
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
          height: kSecurityBannerHeight,
          child: Padding(
            padding: const EdgeInsets.symmetric(horizontal: 16),
            child: Row(
              children: [
                const Icon(Icons.lock_open_rounded, color: _amber, size: 17),
                const SizedBox(width: 8),
                Expanded(
                  child: Text(
                    context.tr('sec_group_plaintext'),
                    maxLines: 1,
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
