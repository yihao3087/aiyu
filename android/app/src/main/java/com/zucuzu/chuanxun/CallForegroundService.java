package com.zucuzu.chuanxun;

import android.app.NotificationChannel;
import android.app.NotificationManager;
import android.app.PendingIntent;
import android.app.Service;
import android.content.Context;
import android.content.Intent;
import android.content.pm.PackageManager;
import android.content.pm.ServiceInfo;
import android.graphics.Bitmap;
import android.graphics.BitmapFactory;
import android.os.Build;
import android.os.IBinder;
import android.os.Handler;
import android.os.Looper;

import androidx.annotation.Nullable;
import androidx.core.app.NotificationCompat;
import androidx.core.content.ContextCompat;

import java.net.URL;
import java.util.concurrent.ExecutorService;
import java.util.concurrent.Executors;

import io.flutter.plugin.common.MethodChannel;

public class CallForegroundService extends Service {
    public static final String ACTION_START = "com.zucuzu.chuanxun.action.START";
    public static final String ACTION_STOP = "com.zucuzu.chuanxun.action.STOP";
    public static final String ACTION_HANGUP = "com.zucuzu.chuanxun.action.HANGUP";
    public static final String EXTRA_PEER = "peer_name";
    public static final String EXTRA_AVATAR = "peer_avatar";
    public static final String EXTRA_START_TS = "start_ts";
    public static final String EXTRA_STATUS = "status_text";
    public static final String EXTRA_IS_CALLING = "is_calling";
    private static final String CHANNEL_ID = "call_foreground_channel";
    private static final int NOTIFICATION_ID = 5011;

    private static MethodChannel sChannel;
    private static final ExecutorService avatarExecutor = Executors.newSingleThreadExecutor();

    @Nullable
    @Override
    public IBinder onBind(Intent intent) {
        return null;
    }

    @Override
    public int onStartCommand(Intent intent, int flags, int startId) {
        if (intent == null) {
            stopSelf();
            return START_NOT_STICKY;
        }
        String action = intent.getAction();
        if (ACTION_STOP.equals(action)) {
            CallFloatingWindowManager.hide(this);
            stopForeground(true);
            stopSelf();
            return START_NOT_STICKY;
        } else if (ACTION_HANGUP.equals(action)) {
            notifyHangup();
            stopForeground(true);
            stopSelf();
            return START_NOT_STICKY;
        }

        createNotificationChannel();
        String peer = intent.getStringExtra(EXTRA_PEER);
        String avatar = intent.getStringExtra(EXTRA_AVATAR);
        long startTs = intent.getLongExtra(EXTRA_START_TS, System.currentTimeMillis());
        String status = intent.getStringExtra(EXTRA_STATUS);
        boolean isCalling = intent.getBooleanExtra(EXTRA_IS_CALLING, false);

        NotificationCompat.Builder builder = buildNotification(peer, status, startTs, isCalling, avatar);
        if (Build.VERSION.SDK_INT >= Build.VERSION_CODES.Q) {
            startForeground(NOTIFICATION_ID, builder.build(), ServiceInfo.FOREGROUND_SERVICE_TYPE_MICROPHONE);
        } else {
            startForeground(NOTIFICATION_ID, builder.build());
        }
        return START_STICKY;
    }

    private void createNotificationChannel() {
        if (Build.VERSION.SDK_INT >= Build.VERSION_CODES.O) {
            NotificationChannel channel = new NotificationChannel(
                    CHANNEL_ID,
                    "语音通话",
                    NotificationManager.IMPORTANCE_HIGH
            );
            channel.setDescription("保持语音通话在后台运行");
            channel.enableLights(false);
            channel.enableVibration(false);
            NotificationManager manager = getSystemService(NotificationManager.class);
            if (manager != null) {
                manager.createNotificationChannel(channel);
            }
        }
    }

    private NotificationCompat.Builder buildNotification(String peer, String status, long startTs, boolean isCalling, String avatarUrl) {
        Intent launchIntent = new Intent(this, MainActivity.class);
        launchIntent.setFlags(Intent.FLAG_ACTIVITY_CLEAR_TOP | Intent.FLAG_ACTIVITY_SINGLE_TOP);
        PendingIntent pendingIntent = PendingIntent.getActivity(
                this,
                0,
                launchIntent,
                PendingIntent.FLAG_IMMUTABLE | PendingIntent.FLAG_UPDATE_CURRENT
        );

        Intent hangupIntent = new Intent(this, CallForegroundService.class);
        hangupIntent.setAction(ACTION_HANGUP);
        PendingIntent hangupPendingIntent = PendingIntent.getService(
                this,
                1,
                hangupIntent,
                PendingIntent.FLAG_IMMUTABLE | PendingIntent.FLAG_UPDATE_CURRENT
        );

        String peerText = (peer == null || peer.isEmpty()) ? "对方" : peer;
        String content = (status != null && !status.isEmpty()) ? status : "正在与 " + peerText + " 通话";
        NotificationCompat.Builder builder = new NotificationCompat.Builder(this, CHANNEL_ID)
                .setContentTitle(peerText)
                .setContentText(content)
                .setSmallIcon(R.mipmap.ic_launcher)
                .setContentIntent(pendingIntent)
                .setOngoing(true)
                .setUsesChronometer(isCalling)
                .setWhen(isCalling ? startTs : System.currentTimeMillis())
                .setPriority(NotificationCompat.PRIORITY_HIGH)
                .setCategory(NotificationCompat.CATEGORY_CALL)
                .setVisibility(NotificationCompat.VISIBILITY_PUBLIC)
                .addAction(android.R.drawable.ic_menu_close_clear_cancel, "挂断", hangupPendingIntent)
                .setStyle(new androidx.media.app.NotificationCompat.MediaStyle().setShowActionsInCompactView(0));

        if (avatarUrl != null && !avatarUrl.isEmpty()) {
            loadAvatarAsync(builder, avatarUrl);
        }
        return builder;
    }

    private static boolean hasMicrophonePermission(Context context) {
        return ContextCompat.checkSelfPermission(context, android.Manifest.permission.RECORD_AUDIO) == PackageManager.PERMISSION_GRANTED;
    }

    public static void start(Context context, String peerName, String avatarUrl, long startTs, String status, boolean isCalling) {
        if (!hasMicrophonePermission(context)) {
            return;
        }
        if (Build.VERSION.SDK_INT >= Build.VERSION_CODES.TIRAMISU &&
                ContextCompat.checkSelfPermission(context, android.Manifest.permission.FOREGROUND_SERVICE_MICROPHONE)
                        != PackageManager.PERMISSION_GRANTED) {
            return;
        }
        Intent intent = new Intent(context, CallForegroundService.class);
        intent.setAction(ACTION_START);
        intent.putExtra(EXTRA_PEER, peerName);
        intent.putExtra(EXTRA_AVATAR, avatarUrl);
        intent.putExtra(EXTRA_START_TS, startTs);
        intent.putExtra(EXTRA_STATUS, status);
        intent.putExtra(EXTRA_IS_CALLING, isCalling);
        try {
            if (Build.VERSION.SDK_INT >= Build.VERSION_CODES.O) {
                context.startForegroundService(intent);
            } else {
                context.startService(intent);
            }
        } catch (SecurityException ignored) {
        }
    }

    public static void stop(Context context) {
        Intent intent = new Intent(context, CallForegroundService.class);
        intent.setAction(ACTION_STOP);
        context.startService(intent);
    }

    private void loadAvatarAsync(NotificationCompat.Builder builder, String avatarUrl) {
        if (avatarUrl == null || avatarUrl.isEmpty()) return;
        avatarExecutor.execute(() -> {
            NotificationManager manager = (NotificationManager) getSystemService(Context.NOTIFICATION_SERVICE);
            if (manager == null) return;
            try {
                Bitmap bmp = BitmapFactory.decodeStream(new URL(avatarUrl).openStream());
                if (bmp != null) {
                    builder.setLargeIcon(bmp);
                    manager.notify(NOTIFICATION_ID, builder.build());
                }
            } catch (Exception ignored) {
            }
        });
    }

    private void notifyHangup() {
        MethodChannel channel = sChannel;
        if (channel == null) return;
        new Handler(Looper.getMainLooper()).post(() -> {
            try {
                channel.invokeMethod("notificationHangup", null);
            } catch (Exception ignored) {
            }
        });
    }

    public static void attachChannel(MethodChannel channel) {
        sChannel = channel;
    }
}
