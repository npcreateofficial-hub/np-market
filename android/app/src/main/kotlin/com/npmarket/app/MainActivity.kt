package com.npmarket.app

import io.flutter.embedding.android.FlutterActivity
import io.flutter.embedding.engine.FlutterEngine
import io.flutter.plugin.common.MethodChannel
import org.json.JSONObject
import java.util.UUID

class MainActivity : FlutterActivity() {
    private val channelName = "np_market/local_profile"
    private val prefsName = "np_market_local_profile"
    private val ownerIdKey = "owner_id"

    override fun configureFlutterEngine(flutterEngine: FlutterEngine) {
        super.configureFlutterEngine(flutterEngine)
        MethodChannel(flutterEngine.dartExecutor.binaryMessenger, channelName).setMethodCallHandler { call, result ->
            val prefs = getSharedPreferences(prefsName, MODE_PRIVATE)
            when (call.method) {
                "loadFavorites" -> {
                    val ownerId = prefs.getString(ownerIdKey, null) ?: UUID.randomUUID().toString().also {
                        prefs.edit().putString(ownerIdKey, it).apply()
                    }
                    val ids = prefs.getStringSet(favoritesKey(ownerId), emptySet())?.toList() ?: emptyList()
                    result.success(mapOf("ownerId" to ownerId, "ids" to ids, "views" to readViews(prefs.getString(viewsKey(ownerId), "{}") ?: "{}")))
                }
                "saveFavorites" -> {
                    val ownerId = call.argument<String>("ownerId") ?: prefs.getString(ownerIdKey, null) ?: UUID.randomUUID().toString()
                    val ids = call.argument<List<String>>("ids") ?: emptyList()
                    val views = call.argument<Map<String, Any>>("views") ?: emptyMap()
                    prefs.edit()
                        .putString(ownerIdKey, ownerId)
                        .putStringSet(favoritesKey(ownerId), ids.take(100).toSet())
                        .putString(viewsKey(ownerId), JSONObject(views).toString())
                        .apply()
                    result.success(true)
                }
                else -> result.notImplemented()
            }
        }
    }

    private fun favoritesKey(ownerId: String): String = "favorites_$ownerId"

    private fun viewsKey(ownerId: String): String = "views_$ownerId"

    private fun readViews(raw: String): Map<String, Int> {
        val json = JSONObject(raw)
        val out = mutableMapOf<String, Int>()
        json.keys().forEach { key -> out[key] = json.optInt(key, 0) }
        return out
    }
}
