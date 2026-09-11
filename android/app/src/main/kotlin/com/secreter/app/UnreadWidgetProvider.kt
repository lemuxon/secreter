package com.secreter.app

import android.app.PendingIntent
import android.appwidget.AppWidgetManager
import android.appwidget.AppWidgetProvider
import android.content.Context
import android.content.Intent
import android.widget.RemoteViews

// GizliChat ana ekran widget'i — GIZLILIK: yalnizca SAYI gosterir,
// asla mesaj icerigi/isim gostermez. Dokununca uygulama acilir.
class UnreadWidgetProvider : AppWidgetProvider() {
    override fun onUpdate(
        context: Context,
        appWidgetManager: AppWidgetManager,
        appWidgetIds: IntArray
    ) {
        // home_widget eklentisinin yazdigi paylasilan tercihler
        val prefs = context.getSharedPreferences(
            "HomeWidgetPreferences", Context.MODE_PRIVATE
        )
        val raw = prefs.all["unread_total"]
        val unread = (raw as? Int) ?: (raw as? Long)?.toInt() ?: 0

        for (widgetId in appWidgetIds) {
            val views = RemoteViews(context.packageName, R.layout.unread_widget)
            views.setTextViewText(R.id.widget_count, unread.toString())
            // YERELLEŞTİRME: metin artık strings.xml'den gelir (sabit Türkçe
            // metin, uygulamanın 8 dil desteğiyle çelişiyordu).
            views.setTextViewText(
                R.id.widget_label,
                context.getString(
                    if (unread == 0) R.string.widget_no_unread
                    else R.string.widget_unread
                )
            )
            val intent = Intent(context, MainActivity::class.java)
            val pending = PendingIntent.getActivity(
                context, 0, intent,
                PendingIntent.FLAG_UPDATE_CURRENT or PendingIntent.FLAG_IMMUTABLE
            )
            views.setOnClickPendingIntent(R.id.widget_root, pending)
            appWidgetManager.updateAppWidget(widgetId, views)
        }
    }
}
