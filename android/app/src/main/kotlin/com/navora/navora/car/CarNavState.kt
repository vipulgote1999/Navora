package com.navora.navora.car

import androidx.car.app.model.Distance
import androidx.car.app.navigation.model.Maneuver

/**
 * Single source of truth for Android Auto templates.
 *
 * Dart (phone) is the brain: MainActivity forwards MethodChannel payloads here.
 * Car Screens only read. Car actions write back via [postCarCommand], which
 * MainActivity relays to Dart over the EventChannel.
 *
 * Kept free of Flutter imports so it stays unit-testable on the JVM.
 */
object CarNavState {
  const val MAX_TRIPS = 6
  const val MAX_TITLE_CHARS = 40
  const val MAX_TEXT_CHARS = 120

  @Volatile var navigating: Boolean = false
  @Volatile var destinationName: String = ""
  @Volatile var roadName: String = ""
  @Volatile var nextManeuverText: String = ""
  @Volatile var stepDistanceM: Double = 0.0
  @Volatile var distanceM: Double = 0.0
  @Volatile var durationSec: Long = 0L
  @Volatile var muted: Boolean = false
  @Volatile var tripTitles: List<String> = emptyList()

  @Volatile var lastCarCommand: String = ""
  @Volatile var lastCarCommandArg: String = ""
  @Volatile var lastCarCommandAtMs: Long = 0L

  @Synchronized
  fun updateNavigation(
    destination: String,
    maneuverText: String,
    road: String,
    remainingM: Double,
    remainingSec: Long,
    stepM: Double,
  ): Boolean {
    if (remainingM < 0 || remainingSec < 0 || stepM < 0) return false
    val dest = destination.take(MAX_TITLE_CHARS).trim()
    if (dest.isEmpty()) return false
    destinationName = dest
    nextManeuverText = maneuverText.take(MAX_TEXT_CHARS).trim()
    roadName = road.take(MAX_TITLE_CHARS).trim()
    distanceM = remainingM.coerceAtMost(9_999_999.0)
    durationSec = remainingSec.coerceAtMost(99_999L)
    stepDistanceM = stepM.coerceAtMost(9_999_999.0)
    navigating = true
    return true
  }

  @Synchronized
  fun clearNavigation() {
    navigating = false
    destinationName = ""
    roadName = ""
    nextManeuverText = ""
    distanceM = 0.0
    durationSec = 0L
    stepDistanceM = 0.0
  }

  @Synchronized
  fun setTrips(titles: List<String>) {
    tripTitles = titles
      .map { it.trim().take(MAX_TITLE_CHARS) }
      .filter { it.isNotEmpty() }
      .distinct()
      .take(MAX_TRIPS)
  }

  @Synchronized
  fun setMutedState(m: Boolean) {
    muted = m
  }

  @Synchronized
  fun postCarCommand(command: String, arg: String = "") {
    if (command.isBlank()) return
    lastCarCommand = command.take(32)
    lastCarCommandArg = arg.take(MAX_TEXT_CHARS)
    lastCarCommandAtMs = System.currentTimeMillis()
  }

  /** Demo fallback so DHU works before the Dart bridge streams live data. */
  @Synchronized
  fun startDemo() {
    updateNavigation(
      destination = "Wagholi, Pune",
      maneuverText = "Head north toward Nagar Road",
      road = "Nagar Road",
      remainingM = 8200.0,
      remainingSec = 720L,
      stepM = 350.0,
    )
    if (tripTitles.isEmpty()) {
      setTrips(listOf("Weekend Convoy", "Bhosari Demo", "Airport Run"))
    }
  }

  /** Keyword mapping from OSRM-style instructions to car Maneuver types. */
  fun maneuverTypeForCar(): Int {
    val t = nextManeuverText.lowercase()
    return when {
      "destination" in t || "arriv" in t -> Maneuver.TYPE_DESTINATION
      "roundabout" in t || "rotary" in t -> Maneuver.TYPE_ROUNDABOUT_ENTER_AND_EXIT_CW
      "u-turn" in t || "u turn" in t -> Maneuver.TYPE_U_TURN_RIGHT
      "sharp right" in t -> Maneuver.TYPE_TURN_SHARP_RIGHT
      "sharp left" in t -> Maneuver.TYPE_TURN_SHARP_LEFT
      "slight right" in t || "keep right" in t -> Maneuver.TYPE_TURN_SLIGHT_RIGHT
      "slight left" in t || "keep left" in t -> Maneuver.TYPE_TURN_SLIGHT_LEFT
      " right" in t -> Maneuver.TYPE_TURN_NORMAL_RIGHT
      " left" in t -> Maneuver.TYPE_TURN_NORMAL_LEFT
      "ramp" in t -> Maneuver.TYPE_ON_RAMP_NORMAL_RIGHT
      "fork" in t -> Maneuver.TYPE_FORK_RIGHT
      "merge" in t -> Maneuver.TYPE_MERGE_LEFT
      "ferry" in t -> Maneuver.TYPE_FERRY_BOAT
      "depart" in t || "head" in t || "start" in t -> Maneuver.TYPE_DEPART
      t.isBlank() -> Maneuver.TYPE_STRAIGHT
      else -> Maneuver.TYPE_STRAIGHT
    }
  }

  /** Value + Distance unit pair for car templates (meters below 1km, else km). */
  fun displayDistance(): Pair<Double, Int> =
    if (distanceM < 1000) distanceM to Distance.UNIT_METERS
    else (distanceM / 1000.0) to Distance.UNIT_KILOMETERS_P1

  fun displayStepDistance(): Pair<Double, Int> =
    if (stepDistanceM < 1000) stepDistanceM to Distance.UNIT_METERS
    else (stepDistanceM / 1000.0) to Distance.UNIT_KILOMETERS_P1
}
