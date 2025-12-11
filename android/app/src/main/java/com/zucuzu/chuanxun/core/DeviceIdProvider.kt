package com.zucuzu.chuanxun.core

import android.content.Context
import android.os.Build
import android.provider.Settings
import java.security.MessageDigest

object DeviceIdProvider {
    private const val APP_SALT = "wP6vR9tN4kZ3sB8qF2xL1dH7"

    fun getDeviceHash(context: Context): String {
        val androidId =
            Settings.Secure.getString(context.contentResolver, Settings.Secure.ANDROID_ID) ?: ""
        val brand = Build.BRAND ?: ""
        val model = Build.MODEL ?: ""
        val raw = "$androidId|$brand|$model|$APP_SALT"
        return raw.toSha256()
    }

    private fun String.toSha256(): String {
        val digest = MessageDigest.getInstance("SHA-256")
        val bytes = digest.digest(toByteArray())
        return bytes.joinToString("") { "%02x".format(it) }
    }
}
