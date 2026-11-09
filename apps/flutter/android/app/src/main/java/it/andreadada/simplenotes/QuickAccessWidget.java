package it.andreadada.simplenotes;

import android.app.PendingIntent;
import android.appwidget.AppWidgetManager;
import android.appwidget.AppWidgetProvider;
import android.content.Context;
import android.content.Intent;
import android.widget.RemoteViews;

/** No task contents or cached login state are displayed on the launcher. */
public class QuickAccessWidget extends AppWidgetProvider {
    private static PendingIntent navigation(
            Context context, int requestCode, String destination) {
        Intent intent = new Intent(context, MainActivity.class);
        intent.setAction(MainActivity.WIDGET_ACTION);
        intent.putExtra(MainActivity.WIDGET_DESTINATION, destination);
        intent.addFlags(Intent.FLAG_ACTIVITY_CLEAR_TOP |
                Intent.FLAG_ACTIVITY_NEW_TASK);
        return PendingIntent.getActivity(context, requestCode, intent,
                PendingIntent.FLAG_UPDATE_CURRENT | PendingIntent.FLAG_IMMUTABLE);
    }

    @Override
    public void onUpdate(Context context, AppWidgetManager manager,
                         int[] appWidgetIds) {
        for (int id : appWidgetIds) {
            RemoteViews views = new RemoteViews(
                    context.getPackageName(), R.layout.simple_notes_quick_widget);
            views.setOnClickPendingIntent(R.id.quick_today,
                    navigation(context, 701, "today"));
            views.setOnClickPendingIntent(R.id.quick_inbox,
                    navigation(context, 702, "inbox"));
            views.setOnClickPendingIntent(R.id.quick_new,
                    navigation(context, 703, "new"));
            manager.updateAppWidget(id, views);
        }
    }
}
