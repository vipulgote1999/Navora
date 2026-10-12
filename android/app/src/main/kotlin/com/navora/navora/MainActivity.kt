package com.navora.navora

import android.content.Intent
import android.os.Handler
import android.os.Looper
import com.navora.navora.car.CarBridge
import com.navora.navora.car.CarNavState
import com.navora.navora.service.NavoraNavigationService
import io.flutter.embedding.android.FlutterActivity
import io.flutter.embedding.engine.FlutterEngine
import io.flutter.plugin.common.EventChannel
import io.flutter.plugin.common.MethodChannel

/**
 * Phone Activity + Dart<->Auto bridge.
 *
 * Dart (source of truth) pushes navigation/trips here; we mirror into
 * [CarNavState] for the car host and run the foreground service.
 * Car actions flow back to Dart over the EventChannel (polled, 1s).
 */
class MainActivity : FlutterActivity() {
  private var commandSink: EventChannel.EventSink? = null
  private val commandHandler = Handler(Looper.getMainLooper())
  private var lastSeenCommandAtMs: Long = 0L

  private val commandPoll = object : Runnable {
    override fun run() {
      val sink = commandSink
      if (sink != null && CarNavState.lastCarCommandAtMs != lastSeenCommandAtMs &&
        CarNavState.lastCarCommand.isNotBlank()
      ) {
        lastSeenCommandAtMs = CarNavState.lastCarCommandAtMs
        sink.success(
          mapOf(
            "command" to CarNavState.lastCarCommand,
            "arg" to CarNavState.lastCarCommandArg,
            "atMs" to CarNavState.lastCarCommandAtMs,
          ),
        )
      }
      commandHandler.postDelayed(this, 1000L)
    }
  }

  override fun configureFlutterEngine(flutterEngine: FlutterEngine) {
    super.configureFlutterEngine(flutterEngine)

    MethodChannel(flutterEngine.dartExecutor.binaryMessenger, CarBridge.METHOD_CHANNEL)
      .setMethodCallHandler { call, result ->
        when (call.method) {
          CarBridge.METHOD_UPDATE_NAVIGATION -> {
            @Suppress("UNCHECKED_CAST")
            val args = call.arguments as? Map<*, *>
            if (!CarBridge.isValidNavigationPayload(args)) {
              result.error("BAD_ARGS", "invalid navigation payload", null)
              return@setMethodCallHandler
            }
            val dest = (args!![CarBridge.KEY_DESTINATION] as? String) ?: ""
            val maneuver = (args[CarBridge.KEY_MANEUVER_TEXT] as? String) ?: ""
            val road = (args[CarBridge.KEY_ROAD] as? String) ?: ""
            val dist = (args[CarBridge.KEY_DISTANCE_M] as? Number)?.toDouble() ?: 0.0
            val dur = (args[CarBridge.KEY_DURATION_S] as? Number)?.toLong() ?: 0L
            val step = (args[CarBridge.KEY_STEP_M] as? Number)?.toDouble() ?: 0.0
            val ok = CarNavState.updateNavigation(dest, maneuver, road, dist, dur, step)
            if (ok) {
              startService(Intent(this, NavoraNavigationService::class.java).apply {
                action = NavoraNavigationService.ACTION_START
              })
              result.success(true)
            } else {
              result.error("REJECTED", "payload failed car constraints", null)
            }
          }
          CarBridge.METHOD_CLEAR_NAVIGATION -> {
            CarNavState.clearNavigation()
            startService(Intent(this, NavoraNavigationService::class.java).apply {
              action = NavoraNavigationService.ACTION_STOP
            })
            result.success(true)
          }
          CarBridge.METHOD_UPDATE_TRIPS -> {
            @Suppress("UNCHECKED_CAST")
            val args = call.arguments as? Map<*, *>
            @Suppress("UNCHECKED_CAST")
            val raw = args?.get(CarBridge.KEY_TITLES) as? List<*>
            CarNavState.setTrips(CarBridge.sanitizeTitles(raw))
            result.success(true)
          }
          CarBridge.METHOD_GET_STATE -> {
            result.success(
              mapOf(
                "navigating" to CarNavState.navigating,
                CarBridge.KEY_DESTINATION to CarNavState.destinationName,
                CarBridge.KEY_MANEUVER_TEXT to CarNavState.nextManeuverText,
                CarBridge.KEY_ROAD to CarNavState.roadName,
                CarBridge.KEY_DISTANCE_M to CarNavState.distanceM,
                CarBridge.KEY_DURATION_S to CarNavState.durationSec,
                CarBridge.KEY_STEP_M to CarNavState.stepDistanceM,
                CarBridge.KEY_TITLES to CarNavState.tripTitles,
                "muted" to CarNavState.muted,
                "lastCommand" to CarNavState.lastCarCommand,
                "lastCommandArg" to CarNavState.lastCarCommandArg,
              ),
            )
          }
          else -> result.notImplemented()
        }
      }

    EventChannel(flutterEngine.dartExecutor.binaryMessenger, CarBridge.EVENT_CHANNEL)
      .setStreamHandler(object : EventChannel.StreamHandler {
        override fun onListen(arguments: Any?, events: EventChannel.EventSink?) {
          commandSink = events
          lastSeenCommandAtMs = CarNavState.lastCarCommandAtMs
          commandHandler.post(commandPoll)
        }

        override fun onCancel(arguments: Any?) {
          commandSink = null
          commandHandler.removeCallbacks(commandPoll)
        }
      })
  }

  override fun onDestroy() {
    commandHandler.removeCallbacks(commandPoll)
    commandSink = null
    super.onDestroy()
  }
}
