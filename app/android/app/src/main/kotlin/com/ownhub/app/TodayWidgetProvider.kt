package com.ownhub.app

import android.appwidget.AppWidgetManager
import android.content.Context
import android.content.SharedPreferences
import android.net.Uri
import android.view.View
import android.widget.RemoteViews
import es.antonborri.home_widget.HomeWidgetLaunchIntent
import es.antonborri.home_widget.HomeWidgetProvider
import org.json.JSONObject
import java.util.Calendar
import java.util.Locale

/**
 * The Android twin of ios/OwnHubWidgets/TodayWidget.swift.
 *
 * Reads only the allow-listed fields of the payload that
 * lib/app_state/home_widget_sync.dart writes under [PAYLOAD_KEY]: v, state,
 * lang, dayKey, weekId, done, target, meal and the sentences under "s".
 * Nothing else is read. It never shows a session or programme title.
 */
class TodayWidgetProvider : HomeWidgetProvider() {

    override fun onUpdate(
        context: Context,
        appWidgetManager: AppWidgetManager,
        appWidgetIds: IntArray,
        widgetData: SharedPreferences,
    ) {
        val model = Model.read(widgetData.getString(PAYLOAD_KEY, null), Calendar.getInstance())
        for (id in appWidgetIds) {
            appWidgetManager.updateAppWidget(id, build(context, model))
        }
    }

    private fun build(context: Context, m: Model): RemoteViews {
        val layout = if (m.lang == "ar") R.layout.today_widget_rtl else R.layout.today_widget
        val views = RemoteViews(context.packageName, layout)

        views.setOnClickPendingIntent(R.id.widget_root, launch(context, "T01"))
        views.setOnClickPendingIntent(R.id.widget_week, launch(context, "P01"))
        views.setOnClickPendingIntent(R.id.widget_status, launch(context, "R03"))
        views.setOnClickPendingIntent(R.id.widget_meal, launch(context, "E01"))

        when (m.mode) {
            Mode.CLOSED -> {
                views.setTextViewText(R.id.widget_today, "")
                views.setTextViewText(
                    R.id.widget_week,
                    m.closed ?: context.getString(R.string.widget_closed_text),
                )
                views.setViewVisibility(R.id.widget_segments, View.GONE)
                views.setViewVisibility(R.id.widget_status, View.GONE)
                views.setViewVisibility(R.id.widget_meal, View.GONE)
                views.setContentDescription(R.id.widget_root, m.closed)
            }
            Mode.PREVIEW -> {
                views.setTextViewText(R.id.widget_today, "")
                views.setTextViewText(
                    R.id.widget_week,
                    context.getString(R.string.widget_preview_text),
                )
                segments(views, 0, m.target)
                views.setViewVisibility(R.id.widget_status, View.GONE)
                views.setViewVisibility(R.id.widget_meal, View.GONE)
            }
            Mode.OPEN -> {
                views.setTextViewText(
                    R.id.widget_today,
                    m.todayTitle ?: context.getString(R.string.widget_today_label),
                )
                views.setTextViewText(R.id.widget_week, m.week ?: "")
                segments(views, m.done, m.target)
                views.setTextViewText(R.id.widget_status, m.status ?: "")
                views.setTextViewText(R.id.widget_meal, m.meal ?: "")
                views.setViewVisibility(R.id.widget_status, View.VISIBLE)
                views.setViewVisibility(R.id.widget_meal, View.VISIBLE)
                views.setContentDescription(R.id.widget_root, m.a11y)
            }
        }
        return views
    }

    /** Up to [MAX_SEGMENTS] bars, the first [done] filled. */
    private fun segments(views: RemoteViews, done: Int, target: Int) {
        val shown = target.coerceIn(1, MAX_SEGMENTS)
        for (i in 0 until MAX_SEGMENTS) {
            val id = SEGMENT_IDS[i]
            views.setViewVisibility(id, if (i < shown) View.VISIBLE else View.GONE)
            views.setInt(
                id,
                "setBackgroundResource",
                if (i < done) R.drawable.widget_segment_done else R.drawable.widget_segment_empty,
            )
        }
        views.setViewVisibility(R.id.widget_segments, View.VISIBLE)
    }

    private fun launch(context: Context, to: String) =
        HomeWidgetLaunchIntent.getActivity(
            context,
            MainActivity::class.java,
            Uri.parse("ownhub://widget?homeWidget=1&to=$to"),
        )

    private enum class Mode { CLOSED, PREVIEW, OPEN }

    /** What the widget draws at one moment, as `WidgetModel` does on iOS. */
    private class Model(
        val mode: Mode,
        val lang: String? = null,
        val done: Int = 0,
        val target: Int = 3,
        val todayTitle: String? = null,
        val week: String? = null,
        val a11y: String? = null,
        val status: String? = null,
        val meal: String? = null,
        val closed: String? = null,
    ) {
        companion object {
            /**
             * A missing or unreadable payload is the empty preview. Anything
             * not "open" (signed out, not verified) is closed. Past midnight
             * the day line asks her to open the app; past Monday the week
             * counts from zero.
             */
            fun read(raw: String?, now: Calendar): Model {
                if (raw == null) return Model(Mode.PREVIEW)
                val p = try {
                    JSONObject(raw)
                } catch (e: Exception) {
                    return Model(Mode.PREVIEW)
                }
                if (p.optInt("v", 0) != 1) return Model(Mode.PREVIEW)
                val lang = p.optString("lang").takeIf { it == "ar" || it == "en" }
                val s = p.optJSONObject("s") ?: JSONObject()
                fun str(key: String): String? =
                    if (s.has(key) && !s.isNull(key)) s.optString(key).takeIf { it.isNotEmpty() } else null

                if (p.optString("state") != "open" ||
                    !p.has("dayKey") || !p.has("weekId") || !p.has("done") || !p.has("target")
                ) {
                    return Model(Mode.CLOSED, lang = lang, closed = str("closed"))
                }
                val sameWeek = p.optString("weekId") == weekId(now)
                val sameDay = sameWeek && p.optString("dayKey") == dayKey(now)
                val logged = sameDay && p.optBoolean("meal", false)
                return Model(
                    Mode.OPEN,
                    lang = lang,
                    done = if (sameWeek) maxOf(p.optInt("done", 0), 0) else 0,
                    target = maxOf(p.optInt("target", 1), 1),
                    todayTitle = str("today"),
                    week = if (sameWeek) str("week") else str("weekFresh"),
                    a11y = if (sameWeek) str("a11y") else str("a11yFresh"),
                    status = if (sameDay) str("status") else str("stale"),
                    meal = if (logged) str("meal") else str("mealNone"),
                    closed = str("closed"),
                )
            }

            /** `yyyy-MM-dd` on this phone, Western digits, Gregorian. */
            fun dayKey(c: Calendar): String = String.format(
                Locale.US, "%04d-%02d-%02d",
                c.get(Calendar.YEAR), c.get(Calendar.MONTH) + 1, c.get(Calendar.DAY_OF_MONTH),
            )

            /** `yyyy-Www`, the ISO week on this phone, as `WeekKey` in the app. */
            fun weekId(now: Calendar): String {
                val c = Calendar.getInstance(now.timeZone, Locale.US)
                c.firstDayOfWeek = Calendar.MONDAY
                c.minimalDaysInFirstWeek = 4
                c.timeInMillis = now.timeInMillis
                return String.format(
                    Locale.US, "%04d-W%02d", c.weekYear, c.get(Calendar.WEEK_OF_YEAR),
                )
            }
        }
    }

    companion object {
        /** `kWidgetPayloadKey` in lib/features/today/domain/widget_projection.dart. */
        const val PAYLOAD_KEY = "ownhub.widget.v1"
        private const val MAX_SEGMENTS = 7
        private val SEGMENT_IDS = intArrayOf(
            R.id.seg0, R.id.seg1, R.id.seg2, R.id.seg3, R.id.seg4, R.id.seg5, R.id.seg6,
        )
    }
}
