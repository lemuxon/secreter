import 'package:equatable/equatable.dart';

/// Metadata gizlilik ayarları.
///
/// Her biri bir metadata sızıntısını kontrol eder. Varsayılanlar
/// GİZLİLİK-ÖNCE: hassas sinyaller kapalı başlar, kullanıcı isterse açar.
class PrivacySettings extends Equatable {
  /// Okundu bilgisi gönder (kapalıysa karşı taraf mesajı gördüğünü bilemez)
  final bool sendReadReceipts;

  /// "Yazıyor..." göstergesi gönder
  final bool sendTypingIndicator;

  /// Çevrimiçi durumu / son görülme paylaş
  final bool sharePresence;

  /// Zaman damgalarını kabalaştır (dakikaya yuvarla — zamanlama analizini zorlaştırır)
  final bool coarseTimestamps;

  /// Kilitlenme/hata telemetrisi onayı (varsayılan KAPALI)
  final bool crashReportingConsent;

  const PrivacySettings({
    this.sendReadReceipts = false,
    this.sendTypingIndicator = false,
    this.sharePresence = false,
    this.coarseTimestamps = true,
    this.crashReportingConsent = false,
  });

  /// Maksimum gizlilik (her şey kapalı)
  factory PrivacySettings.maxPrivacy() => const PrivacySettings(
        sendReadReceipts: false,
        sendTypingIndicator: false,
        sharePresence: false,
        coarseTimestamps: true,
        crashReportingConsent: false,
      );

  /// Tam özellikli (sosyal sinyaller açık — daha az gizli)
  factory PrivacySettings.standard() => const PrivacySettings(
        sendReadReceipts: true,
        sendTypingIndicator: true,
        sharePresence: true,
        coarseTimestamps: false,
        crashReportingConsent: false,
      );

  PrivacySettings copyWith({
    bool? sendReadReceipts,
    bool? sendTypingIndicator,
    bool? sharePresence,
    bool? coarseTimestamps,
    bool? crashReportingConsent,
  }) {
    return PrivacySettings(
      sendReadReceipts: sendReadReceipts ?? this.sendReadReceipts,
      sendTypingIndicator: sendTypingIndicator ?? this.sendTypingIndicator,
      sharePresence: sharePresence ?? this.sharePresence,
      coarseTimestamps: coarseTimestamps ?? this.coarseTimestamps,
      crashReportingConsent:
          crashReportingConsent ?? this.crashReportingConsent,
    );
  }

  Map<String, dynamic> toMap() => {
        'sendReadReceipts': sendReadReceipts,
        'sendTypingIndicator': sendTypingIndicator,
        'sharePresence': sharePresence,
        'coarseTimestamps': coarseTimestamps,
        'crashReportingConsent': crashReportingConsent,
      };

  factory PrivacySettings.fromMap(Map<String, dynamic> map) => PrivacySettings(
        sendReadReceipts: map['sendReadReceipts'] ?? false,
        sendTypingIndicator: map['sendTypingIndicator'] ?? false,
        sharePresence: map['sharePresence'] ?? false,
        coarseTimestamps: map['coarseTimestamps'] ?? true,
        crashReportingConsent: map['crashReportingConsent'] ?? false,
      );

  @override
  List<Object?> get props => [
        sendReadReceipts,
        sendTypingIndicator,
        sharePresence,
        coarseTimestamps,
        crashReportingConsent,
      ];
}
