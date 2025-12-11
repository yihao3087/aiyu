package com.zucuzu.chuanxun;

import android.content.Context;
import android.content.Intent;
import android.graphics.PixelFormat;
import android.os.Build;
import android.provider.Settings;
import android.view.Gravity;
import android.view.LayoutInflater;
import android.view.MotionEvent;
import android.view.View;
import android.view.ViewConfiguration;
import android.view.WindowManager;
import android.widget.ImageView;
import android.widget.TextView;
import android.text.TextUtils;

import androidx.annotation.Nullable;

import com.bumptech.glide.Glide;

import io.flutter.plugin.common.MethodChannel;

class CallFloatingWindowManager {
    private static View floatingView;
    private static WindowManager windowManager;
    private static WindowManager.LayoutParams layoutParams;
    private static MethodChannel methodChannel;

    static void attachChannel(MethodChannel channel) {
        methodChannel = channel;
    }

    static void show(Context context, @Nullable String peerName, @Nullable String avatarUrl, @Nullable String status) {
        if (floatingView != null) return;
        if (Build.VERSION.SDK_INT >= Build.VERSION_CODES.M && !Settings.canDrawOverlays(context)) {
            return;
        }
        Context appContext = context.getApplicationContext();
        windowManager = (WindowManager) appContext.getSystemService(Context.WINDOW_SERVICE);
        if (windowManager == null) return;

        LayoutInflater inflater = LayoutInflater.from(appContext);
        floatingView = inflater.inflate(R.layout.view_call_floating_window, null);
        TextView statusView = floatingView.findViewById(R.id.call_window_label);
        TextView peerView = floatingView.findViewById(R.id.call_window_peer);
        ImageView avatarView = floatingView.findViewById(R.id.call_window_avatar);

        if (TextUtils.isEmpty(status)) {
            statusView.setText(R.string.float_call_status);
        } else {
            statusView.setText(status);
        }
        if (TextUtils.isEmpty(peerName)) {
            peerName = appContext.getString(R.string.app_name);
        }
        peerView.setText(peerName);
        if (avatarView != null) {
            if (TextUtils.isEmpty(avatarUrl)) {
                avatarView.setImageResource(R.mipmap.ic_launcher);
            } else {
                Glide.with(appContext)
                        .load(avatarUrl)
                        .placeholder(R.mipmap.ic_launcher)
                        .error(R.mipmap.ic_launcher)
                        .circleCrop()
                        .into(avatarView);
            }
        }

        int type = Build.VERSION.SDK_INT >= Build.VERSION_CODES.O
                ? WindowManager.LayoutParams.TYPE_APPLICATION_OVERLAY
                : WindowManager.LayoutParams.TYPE_PHONE;

        layoutParams = new WindowManager.LayoutParams(
                WindowManager.LayoutParams.WRAP_CONTENT,
                WindowManager.LayoutParams.WRAP_CONTENT,
                type,
                WindowManager.LayoutParams.FLAG_NOT_FOCUSABLE
                        | WindowManager.LayoutParams.FLAG_LAYOUT_NO_LIMITS
                        | WindowManager.LayoutParams.FLAG_LAYOUT_IN_SCREEN,
                PixelFormat.TRANSLUCENT
        );
        layoutParams.gravity = Gravity.TOP | Gravity.START;
        layoutParams.x = 60;
        layoutParams.y = 220;

        final int touchSlop = ViewConfiguration.get(appContext).getScaledTouchSlop();

        floatingView.setOnTouchListener(new View.OnTouchListener() {
            private int initialX;
            private int initialY;
            private float initialTouchX;
            private float initialTouchY;
            private boolean isDragging;

            @Override
            public boolean onTouch(View v, MotionEvent event) {
                switch (event.getAction()) {
                    case MotionEvent.ACTION_DOWN:
                        initialX = layoutParams.x;
                        initialY = layoutParams.y;
                        initialTouchX = event.getRawX();
                        initialTouchY = event.getRawY();
                        isDragging = false;
                        return true;
                    case MotionEvent.ACTION_MOVE:
                        int dx = (int) (event.getRawX() - initialTouchX);
                        int dy = (int) (event.getRawY() - initialTouchY);
                        if (!isDragging && (Math.abs(dx) > touchSlop || Math.abs(dy) > touchSlop)) {
                            isDragging = true;
                        }
                        if (isDragging) {
                            layoutParams.x = initialX + dx;
                            layoutParams.y = initialY + dy;
                            windowManager.updateViewLayout(floatingView, layoutParams);
                        }
                        return true;
                    case MotionEvent.ACTION_UP:
                        if (!isDragging) {
                            openCallScreen(appContext);
                        }
                        return true;
                }
                return false;
            }
        });

        View actionView = floatingView.findViewById(R.id.call_window_action);
        if (actionView != null) {
            actionView.setOnClickListener(v -> openCallScreen(appContext));
        }

        windowManager.addView(floatingView, layoutParams);
    }

    static void hide(Context context) {
        if (windowManager != null && floatingView != null) {
            windowManager.removeView(floatingView);
            floatingView = null;
            layoutParams = null;
            windowManager = null;
        }
    }

    private static void openCallScreen(Context appContext) {
        notifyFloatingWindowTapped();
        Intent intent = new Intent(appContext, MainActivity.class);
        intent.addFlags(Intent.FLAG_ACTIVITY_NEW_TASK | Intent.FLAG_ACTIVITY_SINGLE_TOP | Intent.FLAG_ACTIVITY_CLEAR_TOP);
        appContext.startActivity(intent);
    }

    private static void notifyFloatingWindowTapped() {
        if (methodChannel != null) {
            methodChannel.invokeMethod("floatingWindowTapped", null);
        }
    }
}
