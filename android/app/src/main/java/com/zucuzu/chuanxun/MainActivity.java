package com.zucuzu.chuanxun;

import androidx.annotation.NonNull;

import com.zucuzu.chuanxun.core.DeviceIdProvider;
import com.zucuzu.chuanxun.CallForegroundService;
import com.zucuzu.chuanxun.ConnectionKeepAliveService;

import io.flutter.embedding.android.FlutterFragmentActivity;
import io.flutter.embedding.engine.FlutterEngine;
import io.flutter.plugin.common.MethodChannel;

public class MainActivity extends FlutterFragmentActivity {
    private static final String DEVICE_ID_CHANNEL = "device_id_channel";
    private static final String CALL_SERVICE_CHANNEL = "call_service_channel";
    private static final String CONNECTION_SERVICE_CHANNEL = "connection_service_channel";

    @Override
    public void configureFlutterEngine(@NonNull FlutterEngine flutterEngine) {
        super.configureFlutterEngine(flutterEngine);
        new MethodChannel(flutterEngine.getDartExecutor().getBinaryMessenger(), DEVICE_ID_CHANNEL)
                .setMethodCallHandler((call, result) -> {
                    if ("getDeviceHash".equals(call.method)) {
                        result.success(DeviceIdProvider.INSTANCE.getDeviceHash(this));
                    } else {
                        result.notImplemented();
                    }
        });
        MethodChannel callChannel = new MethodChannel(flutterEngine.getDartExecutor().getBinaryMessenger(), CALL_SERVICE_CHANNEL);
        CallFloatingWindowManager.attachChannel(callChannel);
        CallForegroundService.attachChannel(callChannel);
        callChannel.setMethodCallHandler((call, result) -> {
            if ("startCallService".equals(call.method)) {
                String peerName = call.argument("peerName");
                String avatar = call.argument("avatar");
                String status = call.argument("status");
                Boolean isCalling = call.argument("isCalling");
                Number startTs = call.argument("startTs");
                CallForegroundService.start(
                        this,
                        peerName,
                        avatar,
                        startTs != null ? startTs.longValue() : System.currentTimeMillis(),
                        status,
                        isCalling != null && isCalling);
                result.success(null);
            } else if ("stopCallService".equals(call.method)) {
                CallForegroundService.stop(this);
                result.success(null);
            } else if ("showFloatingWindow".equals(call.method)) {
                String peerName = call.argument("peerName");
                String avatar = call.argument("avatar");
                String status = call.argument("status");
                CallFloatingWindowManager.show(this, peerName, avatar, status);
                result.success(null);
            } else if ("hideFloatingWindow".equals(call.method)) {
                CallFloatingWindowManager.hide(this);
                result.success(null);
            } else {
                result.notImplemented();
            }
        });
        new MethodChannel(flutterEngine.getDartExecutor().getBinaryMessenger(), CONNECTION_SERVICE_CHANNEL)
                .setMethodCallHandler((call, result) -> {
                    if ("startConnectionService".equals(call.method)) {
                        ConnectionKeepAliveService.start(this);
                        result.success(null);
                    } else if ("stopConnectionService".equals(call.method)) {
                        ConnectionKeepAliveService.stop(this);
                        result.success(null);
                    } else {
                        result.notImplemented();
                    }
                });
    }
}

