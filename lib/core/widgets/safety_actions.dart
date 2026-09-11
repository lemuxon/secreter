import 'package:flutter/material.dart';

import '../../services/block_service.dart';
import '../i18n/app_localizations.dart';
import '../../utils/app_theme.dart';

/// 🛡️ ENGELLE / ŞİKÂYET — ortak eylem sayfası.
///
/// Tek yerde tanımlı; profil ekranı, sohbet menüsü ve çağrı geçmişi
/// aynı akışı kullanır (davranış her yerde birebir aynı olsun diye).
class SafetyActions {
  /// Engelle/engeli kaldır onayı. Sonuç: yeni engel durumu (true=engelli)
  static Future<bool?> confirmBlock(
    BuildContext context, {
    required String myUid,
    required String otherUid,
    required String username,
    required bool currentlyBlocked,
  }) async {
    if (currentlyBlocked) {
      await BlockService.unblock(myUid, otherUid);
      if (context.mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('@$username · ${context.tr('unblock_user')}')),
        );
      }
      return false;
    }

    final ok = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        backgroundColor: AppTheme.surface,
        title: Text('${context.tr('block_user')} · @$username',
            style: const TextStyle(color: AppTheme.textPrimary, fontSize: 17)),
        content: Text(context.tr('block_confirm'),
            style: const TextStyle(color: AppTheme.textSecondary)),
        actions: [
          TextButton(
              onPressed: () => Navigator.pop(ctx, false),
              child: Text(context.tr('cancel'))),
          TextButton(
            onPressed: () => Navigator.pop(ctx, true),
            child: Text(context.tr('block_user'),
                style: const TextStyle(color: AppTheme.danger)),
          ),
        ],
      ),
    );
    if (ok != true) return null;

    await BlockService.block(myUid, otherUid);
    if (context.mounted) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text(context.tr('blocked_notice'))),
      );
    }
    return true;
  }

  /// Şikâyet sayfası: sebep seçimi + isteğe bağlı not + engelleme.
  ///
  /// ── ⚠️ `messageId` PARAMETRESİ KALDIRILDI (§4ao) ──
  /// İmzada vardı, **hiçbir çağıran geçmiyordu** ve geçse bile
  /// `BlockService.report`a iletilmiyordu — yani üç katman boyunca ölü
  /// bir yüzeydi. Bir sonraki geliştirici onu "mesaj şikâyeti çalışıyor"
  /// sanabilirdi (§4t/§4aj'nin dersi).
  ///
  /// Kaldırıldı çünkü mesaj düzeyinde şikâyet bu mimaride **içerik
  /// tabanlı olamaz**: mesajlar uçtan uca şifreli, yani konsola bir
  /// mesaj kimliği göndermek okunamayan bir dokümanı işaret eder.
  /// Sunucuya içerik göndermek ise E2EE'yi tam da moderasyon için
  /// delmek olurdu. Buradaki gerçekçi kaldıraçlar: **şikâyet + engelle
  /// + hesap düzeyinde işlem** (konsoldan).
  static Future<void> report(
    BuildContext context, {
    required String myUid,
    required String otherUid,
    required String username,
    String? chatId,
  }) async {
    var reason = BlockService.reportReasons.first;
    // Şikâyet eden kişi çoğu zaman o kişiyi görmeyi de bırakmak
    // istiyor; ayrı bir adıma bırakmak, şikâyet edip yine de taciz
    // görmeye devam etmek demekti. Varsayılan AÇIK, ama zorunlu değil.
    var alsoBlock = true;
    final noteCtrl = TextEditingController();

    final sent = await showModalBottomSheet<bool>(
      context: context,
      backgroundColor: AppTheme.surface,
      isScrollControlled: true,
      builder: (ctx) => StatefulBuilder(
        builder: (ctx, setSheet) => Padding(
          padding:
              EdgeInsets.only(bottom: MediaQuery.of(ctx).viewInsets.bottom),
          child: SafeArea(
            child: SingleChildScrollView(
              padding: const EdgeInsets.fromLTRB(18, 18, 18, 14),
              child: Column(
                mainAxisSize: MainAxisSize.min,
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    children: [
                      const Icon(Icons.flag_outlined,
                          color: AppTheme.danger, size: 20),
                      const SizedBox(width: 8),
                      Expanded(
                        child: Text('${context.tr('report_user')} · @$username',
                            style: const TextStyle(
                                color: AppTheme.textPrimary,
                                fontSize: 16,
                                fontWeight: FontWeight.w600)),
                      ),
                    ],
                  ),
                  const SizedBox(height: 14),
                  Text(context.tr('report_reason'),
                      style: const TextStyle(
                          color: AppTheme.textSecondary, fontSize: 12.5)),
                  const SizedBox(height: 6),
                  // Radio'nun groupValue/onChanged parametreleri Flutter
                  // 3.32'de kullanimdan kaldirildi; secim durumu artik
                  // RadioGroup atasinda tutuluyor.
                  RadioGroup<String>(
                    groupValue: reason,
                    onChanged: (v) => setSheet(() => reason = v ?? reason),
                    child: Column(
                      mainAxisSize: MainAxisSize.min,
                      children: BlockService.reportReasons
                          .map(
                            (r) => RadioListTile<String>(
                              value: r,
                              dense: true,
                              contentPadding: EdgeInsets.zero,
                              activeColor: AppTheme.primary,
                              title: Text(context.tr(r),
                                  style: const TextStyle(
                                      color: AppTheme.textPrimary)),
                            ),
                          )
                          .toList(),
                    ),
                  ),
                  const SizedBox(height: 6),
                  TextField(
                    controller: noteCtrl,
                    maxLength: 200,
                    maxLines: 2,
                    style: const TextStyle(color: AppTheme.textPrimary),
                    decoration: InputDecoration(
                      hintText: context.tr('report_note_hint'),
                      counterText: '',
                    ),
                  ),
                  CheckboxListTile(
                    value: alsoBlock,
                    onChanged: (v) => setSheet(() => alsoBlock = v ?? true),
                    dense: true,
                    contentPadding: EdgeInsets.zero,
                    controlAffinity: ListTileControlAffinity.leading,
                    activeColor: AppTheme.primary,
                    title: Text(context.tr('report_also_block'),
                        style: const TextStyle(color: AppTheme.textPrimary)),
                  ),
                  const SizedBox(height: 12),
                  SizedBox(
                    width: double.infinity,
                    child: FilledButton(
                      onPressed: () => Navigator.pop(ctx, true),
                      child: Text(context.tr('send_report')),
                    ),
                  ),
                ],
              ),
            ),
          ),
        ),
      ),
    );

    if (sent != true) return;
    try {
      await BlockService.report(
        reporterUid: myUid,
        reportedUid: otherUid,
        reason: reason,
        note: noteCtrl.text,
        chatId: chatId,
      );
      // ⚠️ ENGELLEME ŞİKÂYETTEN SONRA — ve şikâyet başarısız olursa
      // ÇALIŞMAZ. Sıra bilinçli: engelleme kullanıcının kendi
      // cihazında hemen etkili olan kısım, şikâyet ise sunucuya
      // bırakılan kısım. Şikâyet yazılamadıysa kullanıcıya hata
      // gösteriliyor; sessizce yalnızca engelleyip "şikâyet gönderildi"
      // demek yanıltıcı olurdu.
      if (alsoBlock) {
        await BlockService.block(myUid, otherUid);
      }
      if (context.mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text(context.tr('report_sent'))),
        );
      }
    } catch (e) {
      if (context.mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text(context.tr('err_unexpected'))),
        );
      }
    }
  }
}
