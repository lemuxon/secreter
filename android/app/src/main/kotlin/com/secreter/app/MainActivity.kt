package com.secreter.app

import android.content.ComponentName
import android.content.pm.PackageManager
import android.os.Bundle
import android.view.WindowManager
import io.flutter.embedding.android.FlutterFragmentActivity
import io.flutter.embedding.engine.FlutterEngine
import io.flutter.plugin.common.MethodChannel
import java.io.File
import java.net.InetSocketAddress
import java.net.Socket
import java.util.concurrent.Executors

/**
 * local_auth (biyometrik) paketi FlutterFragmentActivity gerektirir.
 * Ayrıca FLAG_SECURE ve native güvenlik kontrolleri için method channel.
 */
class MainActivity : FlutterFragmentActivity() {

    private val securityChannel = "com.gizlichat.app/security"
    private val mediaChannel = "com.gizlichat.app/media"

    // Güvenlik kontrolleri ağ/dosya I/O yapar; ANA THREAD'DE ÇALIŞTIRILAMAZ.
    private val io = Executors.newSingleThreadExecutor()

    override fun onCreate(savedInstanceState: Bundle?) {
        super.onCreate(savedInstanceState)

        // FLAG_SECURE: ekran görüntüsü + son kullanılanlar önizlemesi + ekran
        // kaydını engeller. GÜVENLİ VARSAYILAN olarak açılışta set edilir;
        // kullanıcı ayarlardan kapatana kadar açık kalır.
        window.setFlags(
            WindowManager.LayoutParams.FLAG_SECURE,
            WindowManager.LayoutParams.FLAG_SECURE
        )
    }

    override fun configureFlutterEngine(flutterEngine: FlutterEngine) {
        super.configureFlutterEngine(flutterEngine)

        MethodChannel(
            flutterEngine.dartExecutor.binaryMessenger,
            securityChannel
        ).setMethodCallHandler { call, result ->
            when (call.method) {
                "setSecureFlag" -> {
                    val enable = call.argument<Boolean>("enable") ?: true
                    if (enable) {
                        window.setFlags(
                            WindowManager.LayoutParams.FLAG_SECURE,
                            WindowManager.LayoutParams.FLAG_SECURE
                        )
                    } else {
                        window.clearFlags(WindowManager.LayoutParams.FLAG_SECURE)
                    }
                    result.success(true)
                }

                "isDebuggerAttached" -> {
                    result.success(android.os.Debug.isDebuggerConnected())
                }

                "checkFridaPort" -> {
                    // ÖNCEKİ HATA: soket bağlantısı ana thread'de açılıyordu.
                    // Android bunu NetworkOnMainThreadException ile reddediyor,
                    // istisna da yakalanıp `false` döndürülüyordu — yani kontrol
                    // HER ZAMAN "temiz" sonuç veriyor, hiçbir işe yaramıyordu.
                    // Artık arka plan thread'inde çalışır ve sonucu ana thread'e
                    // döndürür.
                    io.execute {
                        val detected = isFridaPortOpen() || hasHookingArtifacts()
                        runOnUiThread { result.success(detected) }
                    }
                }

                // ── 🥸 UYGULAMA KILIĞI ──
                "isDisguised" -> {
                    result.success(isComponentEnabled(ALIAS_DISGUISED))
                }

                "setDisguise" -> {
                    val on = call.argument<Boolean>("enabled") ?: false
                    try {
                        setDisguise(on)
                        result.success(true)
                    } catch (e: Exception) {
                        result.error("DISGUISE_FAILED", e.message, null)
                    }
                }

                else -> result.notImplemented()
            }
        }

        // ── 🎬 MEDYA KANALI: video kırpma ──
        // Kırpma dosya I/O ve muxing yapar; büyük videolarda saniyeler
        // sürebilir. ANA THREAD'de çalıştırılırsa arayüz donar (ANR), bu
        // yüzden arka plan thread'ine alınır.
        MethodChannel(
            flutterEngine.dartExecutor.binaryMessenger,
            mediaChannel
        ).setMethodCallHandler { call, result ->
            when (call.method) {
                "trimVideo" -> {
                    val src = call.argument<String>("src")
                    val dst = call.argument<String>("dst")
                    val startMs = (call.argument<Number>("startMs") ?: 0).toLong()
                    val endMs = (call.argument<Number>("endMs") ?: 0).toLong()
                    if (src == null || dst == null) {
                        result.error("ARGS", "src ve dst gerekli", null)
                        return@setMethodCallHandler
                    }
                    io.execute {
                        val out = VideoTrimmer.trim(src, dst, startMs, endMs)
                        runOnUiThread { result.success(out) }
                    }
                }

                "videoDuration" -> {
                    val src = call.argument<String>("src")
                    if (src == null) {
                        result.error("ARGS", "src gerekli", null)
                        return@setMethodCallHandler
                    }
                    io.execute {
                        val ms = VideoTrimmer.durationMs(src)
                        runOnUiThread { result.success(ms) }
                    }
                }

                else -> result.notImplemented()
            }
        }
    }

    /** Frida varsayılan portları açık mı? (sezgisel tespit) */
    private fun isFridaPortOpen(): Boolean {
        for (port in intArrayOf(27042, 27043)) {
            try {
                Socket().use { s ->
                    s.connect(InetSocketAddress("127.0.0.1", port), 150)
                }
                return true
            } catch (e: Exception) {
                // port kapalı — normal
            }
        }
        return false
    }

    /**
     * Bellek haritasında ve dosya sisteminde hooking izleri.
     * Atlatılabilir; savunmanın TEK katmanı değildir (asıl koruma E2EE ve
     * sunucu kurallarıdır) ama ucuz bir ek sinyal sağlar.
     */
    private fun hasHookingArtifacts(): Boolean {
        try {
            val maps = File("/proc/self/maps")
            if (maps.canRead()) {
                val text = maps.readText()
                for (needle in listOf("frida", "xposed", "substrate", "gadget")) {
                    if (text.contains(needle, ignoreCase = true)) return true
                }
            }
        } catch (e: Exception) {
            // okunamıyorsa sinyal yok
        }
        for (path in listOf(
            "/sbin/magisk", "/system/bin/magisk", "/data/adb/magisk",
            "/system/framework/XposedBridge.jar"
        )) {
            try {
                if (File(path).exists()) return true
            } catch (e: Exception) {
                // erişim yok — sinyal yok
            }
        }
        return false
    }

    override fun onDestroy() {
        io.shutdownNow()
        super.onDestroy()
    }

    // ═══════════════ UYGULAMA KILIĞI ═══════════════
    //
    // Başlatıcıdaki simge/ad iki activity-alias ile temsil edilir; her an
    // yalnızca biri etkindir.
    //
    // ⚠️ SIRA KRİTİKTİR: önce YENİ alias açılır, sonra eskisi kapatılır.
    // Ters sırada, iki işlem arasında hiçbir LAUNCHER bileşeni kalmaz ve
    // süreç o anda öldürülürse uygulama başlatıcıdan AÇILAMAZ hâle gelir
    // (kullanıcının tek kurtuluşu yeniden kurulum olurdu).
    //
    // DONT_KILL_APP kullanılır: aksi halde Android kendi bileşenini
    // değiştiren uygulamayı anında öldürür ve kullanıcı ayarlar
    // ekranından atılır. Bedeli, bazı başlatıcıların simgeyi birkaç
    // saniye gecikmeyle tazelemesidir.
    private fun setDisguise(on: Boolean) {
        val enable = if (on) ALIAS_DISGUISED else ALIAS_NORMAL
        val disable = if (on) ALIAS_NORMAL else ALIAS_DISGUISED

        setComponentEnabled(enable, true)
        setComponentEnabled(disable, false)
    }

    private fun setComponentEnabled(alias: String, enabled: Boolean) {
        val state = if (enabled) {
            PackageManager.COMPONENT_ENABLED_STATE_ENABLED
        } else {
            PackageManager.COMPONENT_ENABLED_STATE_DISABLED
        }
        packageManager.setComponentEnabledSetting(
            ComponentName(packageName, packageName + alias),
            state,
            PackageManager.DONT_KILL_APP
        )
    }

    private fun isComponentEnabled(alias: String): Boolean {
        val component = ComponentName(packageName, packageName + alias)
        return when (packageManager.getComponentEnabledSetting(component)) {
            PackageManager.COMPONENT_ENABLED_STATE_ENABLED -> true
            PackageManager.COMPONENT_ENABLED_STATE_DISABLED -> false
            // VARSAYILAN: manifest'teki `android:enabled` değeri geçerli.
            // Kılık alias'ı manifest'te KAPALI tanımlıdır.
            else -> false
        }
    }

    companion object {
        private const val ALIAS_NORMAL = ".Launcher"
        private const val ALIAS_DISGUISED = ".LauncherDisguised"
    }
}
