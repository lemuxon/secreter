package com.secreter.app

import android.media.MediaCodec
import android.media.MediaExtractor
import android.media.MediaFormat
import android.media.MediaMetadataRetriever
import android.media.MediaMuxer
import android.util.Log
import java.io.File
import java.nio.ByteBuffer

/**
 * 🎬 VİDEO KIRPMA — yeniden kodlama YOK
 *
 * ── NEDEN FFMPEG DEĞİL ──
 * `ffmpeg_kit_flutter` APK'ya 30–80 MB ekler. Uygulama zaten ~103 MB;
 * yalnızca kırpma için bu boyutu ödemek mantıksız. Android'in yerleşik
 * `MediaExtractor` + `MediaMuxer` ikilisi aynı işi:
 *   • ek boyut olmadan (işletim sisteminin parçası),
 *   • yeniden KODLAMADAN (sample'lar olduğu gibi kopyalanır),
 *   • bu yüzden çok hızlı ve kalite kaybı SIFIR
 * şekilde yapar.
 *
 * ── SINIR: ANAHTAR KARE (keyframe) HİZASI ──
 * Sample'lar yeniden kodlanmadığı için kesim, istenen noktadan ÖNCEKİ en
 * yakın anahtar kareden başlar (video çözücü referans kare olmadan
 * çözemez). Pratikte 0–2 saniyelik bir sapma olur; bu, hızlı kırpma
 * yapan tüm uygulamalarda (WhatsApp/Telegram dâhil) böyledir.
 *
 * ── DÖNÜŞ ──
 * Başarılıysa çıktı dosyasının yolu, aksi halde `null`.
 */
object VideoTrimmer {

    private const val TAG = "VideoTrimmer"

    /** Ayırıcıya ayrılacak varsayılan tampon (format bildirmezse). */
    private const val DEFAULT_BUFFER = 2 * 1024 * 1024

    fun trim(
        srcPath: String,
        dstPath: String,
        startMs: Long,
        endMs: Long
    ): String? {
        if (startMs < 0 || endMs <= startMs) {
            Log.w(TAG, "Geçersiz aralık: $startMs..$endMs")
            return null
        }

        var extractor: MediaExtractor? = null
        var muxer: MediaMuxer? = null

        try {
            extractor = MediaExtractor()
            extractor.setDataSource(srcPath)

            // Çıktı klasörü hazır olmalı
            File(dstPath).parentFile?.mkdirs()
            muxer = MediaMuxer(dstPath, MediaMuxer.OutputFormat.MUXER_OUTPUT_MPEG_4)

            // ── 1. Ses ve görüntü izlerini eşle ──
            val indexMap = HashMap<Int, Int>()
            var bufferSize = 0
            for (i in 0 until extractor.trackCount) {
                val format = extractor.getTrackFormat(i)
                val mime = format.getString(MediaFormat.KEY_MIME) ?: continue
                if (!mime.startsWith("video/") && !mime.startsWith("audio/")) continue

                extractor.selectTrack(i)
                indexMap[i] = muxer.addTrack(format)

                if (format.containsKey(MediaFormat.KEY_MAX_INPUT_SIZE)) {
                    val s = format.getInteger(MediaFormat.KEY_MAX_INPUT_SIZE)
                    if (s > bufferSize) bufferSize = s
                }
            }
            if (indexMap.isEmpty()) {
                Log.w(TAG, "Kopyalanacak iz yok")
                return null
            }
            if (bufferSize <= 0) bufferSize = DEFAULT_BUFFER

            // ── 2. Döndürme bilgisini KORU ──
            // Bu olmadan dikey çekilmiş videolar yan yatık kaydedilir.
            //
            // ⚠️ `.use { }` KULLANILMAZ: MediaMetadataRetriever `AutoCloseable`
            // arayüzünü ancak API 29'da kazandı; minSdk 24 olduğu için
            // Android 7–9 cihazlarda `NoSuchMethodError` ile ÇÖKERDİ
            // (derleme compileSdk yüksek olduğu için sorunsuz geçer, hata
            // yalnızca çalışma zamanında görülür). Bu yüzden elle release.
            runCatching { muxer.setOrientationHint(readRotation(srcPath)) }
                .onFailure { Log.w(TAG, "Döndürme bilgisi okunamadı", it) }

            // ── 3. Başlangıca yakın ANAHTAR KAREYE atla ──
            val startUs = startMs * 1000
            val endUs = endMs * 1000
            extractor.seekTo(startUs, MediaExtractor.SEEK_TO_PREVIOUS_SYNC)

            // Gerçek başlangıç, atlanan anahtar karedir. Zaman damgalarını
            // buna göre kaydırırsak çıktı 0'dan başlar (aksi halde oynatıcı
            // videonun başında donuk bekler).
            val firstSampleUs = extractor.sampleTime.takeIf { it >= 0 } ?: 0L

            muxer.start()

            val buffer = ByteBuffer.allocate(bufferSize)
            val info = MediaCodec.BufferInfo()
            var written = 0L

            while (true) {
                val sampleSize = extractor.readSampleData(buffer, 0)
                if (sampleSize < 0) break

                val sampleTimeUs = extractor.sampleTime
                if (sampleTimeUs > endUs) break

                val dstTrack = indexMap[extractor.sampleTrackIndex]
                if (dstTrack != null) {
                    info.offset = 0
                    info.size = sampleSize
                    info.presentationTimeUs = (sampleTimeUs - firstSampleUs)
                        .coerceAtLeast(0L)
                    info.flags = extractor.sampleFlags
                    muxer.writeSampleData(dstTrack, buffer, info)
                    written++
                }
                if (!extractor.advance()) break
            }

            if (written == 0L) {
                Log.w(TAG, "Hiç sample yazılmadı")
                return null
            }
            return dstPath
        } catch (e: Exception) {
            Log.e(TAG, "Kırpma başarısız", e)
            // Yarım kalmış çıktı, "geçerli video" sanılmasın.
            runCatching { File(dstPath).delete() }
            return null
        } finally {
            // stop() yazılmamış iz varsa fırlatabilir; release her durumda.
            runCatching { muxer?.stop() }
            runCatching { muxer?.release() }
            runCatching { extractor?.release() }
        }
    }

    /** Videonun toplam süresi (ms). Okunamazsa 0. */
    fun durationMs(path: String): Long = readMetadata(path) { mr ->
        mr.extractMetadata(MediaMetadataRetriever.METADATA_KEY_DURATION)
            ?.toLongOrNull() ?: 0L
    } ?: 0L

    private fun readRotation(path: String): Int = readMetadata(path) { mr ->
        mr.extractMetadata(MediaMetadataRetriever.METADATA_KEY_VIDEO_ROTATION)
            ?.toIntOrNull() ?: 0
    } ?: 0

    /**
     * `MediaMetadataRetriever`'ı güvenle kullan ve HER DURUMDA release et.
     *
     * `use { }` (AutoCloseable) API 29 gerektirir; minSdk 24 olduğu için
     * kullanılamaz — bkz. [trim] içindeki not.
     */
    private fun <T> readMetadata(path: String, block: (MediaMetadataRetriever) -> T): T? {
        val mr = MediaMetadataRetriever()
        return try {
            mr.setDataSource(path)
            block(mr)
        } catch (e: Exception) {
            Log.w(TAG, "Üst veri okunamadı: $path", e)
            null
        } finally {
            runCatching { mr.release() }
        }
    }
}
