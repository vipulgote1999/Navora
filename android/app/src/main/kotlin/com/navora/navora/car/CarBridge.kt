package com.navora.navora.car

/**
 * Method/EventChannel contract between Dart and the native car shell.
 * Must stay in sync with lib/features/car/car_channel.dart.
 */
object CarBridge {
  const val METHOD_CHANNEL = "navora/car"
  const val EVENT_CHANNEL = "navora/car/commands"

  const val METHOD_UPDATE_NAVIGATION = "updateNavigation"
  const val METHOD_CLEAR_NAVIGATION = "clearNavigation"
  const val METHOD_UPDATE_TRIPS = "updateTrips"
  const val METHOD_GET_STATE = "getState"

  const val KEY_DESTINATION = "destination"
  const val KEY_MANEUVER_TEXT = "maneuverText"
  const val KEY_ROAD = "road"
  const val KEY_DISTANCE_M = "distanceM"
  const val KEY_DURATION_S = "durationS"
  const val KEY_STEP_M = "stepM"
  const val KEY_TITLES = "titles"

  // Car -> phone commands (EventChannel payloads + CarNavState.lastCarCommand).
  const val CMD_START_DEMO = "startDemo"
  const val CMD_END_NAVIGATION = "endNavigation"
  const val CMD_TOGGLE_MUTE = "toggleMute"
  const val CMD_SEARCH = "search"
  const val CMD_SELECT_TRIP = "selectTrip"

  /** Pure validation for updateNavigation payloads (also mirrored in Dart tests). */
  fun isValidNavigationPayload(map: Map<*, *>?): Boolean {
    if (map == null) return false
    val dest = map[KEY_DESTINATION] as? String ?: return false
    if (dest.trim().isEmpty()) return false
    val dist = (map[KEY_DISTANCE_M] as? Number)?.toDouble() ?: return false
    val dur = (map[KEY_DURATION_S] as? Number)?.toLong() ?: return false
    val step = (map[KEY_STEP_M] as? Number)?.toDouble() ?: return false
    return dist >= 0 && dur >= 0 && step >= 0
  }

  fun sanitizeTitle(raw: String?): String =
    (raw ?: "").trim().take(CarNavState.MAX_TITLE_CHARS)

  fun sanitizeTitles(raw: List<*>?): List<String> =
    (raw ?: emptyList<Any>())
      .mapNotNull { it as? String }
      .map { it.trim().take(CarNavState.MAX_TITLE_CHARS) }
      .filter { it.isNotEmpty() }
      .distinct()
      .take(CarNavState.MAX_TRIPS)
}
