package com.navora.navora.car

import androidx.car.app.navigation.model.Maneuver
import org.junit.Assert.*
import org.junit.Before
import org.junit.Test

class CarNavStateTest {
  @Before fun reset() {
    CarNavState.clearNavigation()
    CarNavState.setTrips(emptyList())
    CarNavState.setMutedState(false)
  }

  @Test fun updateNavigation_acceptsValidPayload() {
    val ok = CarNavState.updateNavigation(
      destination = "Wagholi, Pune",
      maneuverText = "Head north toward Nagar Road",
      road = "Nagar Road",
      remainingM = 8200.0,
      remainingSec = 720L,
      stepM = 350.0,
    )
    assertTrue(ok)
    assertTrue(CarNavState.navigating)
    assertEquals("Wagholi, Pune", CarNavState.destinationName)
  }

  @Test fun updateNavigation_rejectsBadPayload() {
    assertFalse(CarNavState.updateNavigation("", "x", "", 10.0, 5L, 1.0))
    assertFalse(CarNavState.updateNavigation("X", "x", "", -1.0, 5L, 1.0))
    assertFalse(CarNavState.updateNavigation("X", "x", "", 10.0, -1L, 1.0))
    assertFalse(CarNavState.navigating)
  }

  @Test fun setTrips_capsAtSixAndDedupes() {
    CarNavState.setTrips(listOf("A", " ", "A", "B", "C", "D", "E", "F", "G"))
    assertEquals(listOf("A", "B", "C", "D", "E", "F"), CarNavState.tripTitles)
  }

  @Test fun maneuverMapping_coversCoreCases() {
    CarNavState.updateNavigation("D", "Turn right onto MG Road", "", 100.0, 60L, 50.0)
    assertEquals(Maneuver.TYPE_TURN_NORMAL_RIGHT, CarNavState.maneuverTypeForCar())
    CarNavState.updateNavigation("D", "At the roundabout take the 2nd exit", "", 100.0, 60L, 50.0)
    assertEquals(Maneuver.TYPE_ROUNDABOUT_ENTER_AND_EXIT_CW, CarNavState.maneuverTypeForCar())
    CarNavState.updateNavigation("D", "Arrived at destination", "", 0.0, 0L, 0.0)
    assertEquals(Maneuver.TYPE_DESTINATION, CarNavState.maneuverTypeForCar())
  }

  @Test fun bridgeValidation_mirrorsDart() {
    assertTrue(CarBridge.isValidNavigationPayload(mapOf(
      "destination" to "Wagholi", "distanceM" to 10.0,
      "durationS" to 5L, "stepM" to 1.0)))
    assertFalse(CarBridge.isValidNavigationPayload(mapOf(
      "destination" to "  ", "distanceM" to 10.0,
      "durationS" to 5L, "stepM" to 1.0)))
    assertFalse(CarBridge.isValidNavigationPayload(null))
    assertEquals(listOf("A", "B"), CarBridge.sanitizeTitles(listOf(" A ", "", "A", "B")))
  }

  @Test fun displayDistance_switchesUnitsAt1km() {
    CarNavState.updateNavigation("D", "go", "", 500.0, 60L, 100.0)
    val (v, u) = CarNavState.displayDistance()
    assertEquals(500.0, v, 0.001)
    CarNavState.updateNavigation("D", "go", "", 8200.0, 60L, 100.0)
    val (v2, _) = CarNavState.displayDistance()
    assertEquals(8.2, v2, 0.001)
  }
}
