package it.andreadada.simplenotes;

import android.content.Intent;
import android.os.Bundle;

import androidx.annotation.NonNull;
import androidx.annotation.Nullable;

import io.flutter.embedding.android.FlutterActivity;
import io.flutter.embedding.engine.FlutterEngine;
import io.flutter.plugin.common.MethodChannel;

/** The widget only requests navigation. It never reads user data or bypasses
 * Flutter's cold-start restore gate, login, database or sync safeguards. */
public class MainActivity extends FlutterActivity {
    static final String WIDGET_ACTION = "it.andreadada.simplenotes.widget.OPEN";
    static final String WIDGET_DESTINATION = "destination";
    static final String CHANNEL = "it.andreadada.simplenotes/widget";
    private String pendingDestination;
    private MethodChannel widgetChannel;

    private static String acceptedDestination(@Nullable Intent intent) {
        if (intent == null || !WIDGET_ACTION.equals(intent.getAction())) {
            return null;
        }
        String requested = intent.getStringExtra(WIDGET_DESTINATION);
        if ("today".equals(requested) || "inbox".equals(requested)
                || "new".equals(requested)) {
            return requested;
        }
        return null;
    }

    @Override
    protected void onCreate(@Nullable Bundle state) {
        pendingDestination = acceptedDestination(getIntent());
        super.onCreate(state);
    }

    @Override
    public void configureFlutterEngine(@NonNull FlutterEngine engine) {
        super.configureFlutterEngine(engine);
        widgetChannel = new MethodChannel(
                engine.getDartExecutor().getBinaryMessenger(), CHANNEL);
        widgetChannel.setMethodCallHandler((call, result) -> {
            if ("takePendingAction".equals(call.method)) {
                String action = pendingDestination;
                pendingDestination = null;
                result.success(action);
            } else {
                result.notImplemented();
            }
        });
    }

    @Override
    protected void onNewIntent(@NonNull Intent intent) {
        super.onNewIntent(intent);
        setIntent(intent);
        String action = acceptedDestination(intent);
        if (action != null) {
            pendingDestination = action;
            if (widgetChannel != null) {
                widgetChannel.invokeMethod("widgetAction", action);
            }
        }
    }
}
