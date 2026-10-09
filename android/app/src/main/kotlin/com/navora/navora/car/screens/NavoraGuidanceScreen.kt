package com.navora.navora.car.screens

import androidx.car.app.CarContext
import androidx.car.app.Screen
import androidx.car.app.model.Action
import androidx.car.app.model.ActionStrip
import androidx.car.app.model.CarText
import androidx.car.app.model.DateTimeWithZone
import androidx.car.app.model.Distance
import androidx.car.app.model.MessageTemplate
import androidx.car.app.model.Template
import androidx.car.app.navigation.model.Maneuver
import androidx.car.app.navigation.model.NavigationTemplate
import androidx.car.app.navigation.model.RoutingInfo
import androidx.car.app.navigation.model.Step
import androidx.car.app.navigation.model.TravelEstimate
import com.navora.navora.car.CarBridge
import com.navora.navora.car.CarNavState
import java.util.TimeZone

/**
 * Active guidance. MVP renders maneuver + ETA without a live map Surface
 * (map SurfaceCallback lands in Phase 2c with native MapLibre).
 */
class NavoraGuidanceScreen(carContext: CarContext) : Screen(carContext) {
  override fun onGetTemplate(): Template {
    if (!CarNavState.navigating) {
      return MessageTemplate.Builder("Not navigating — pick a trip or search.")
        .setHeaderAction(Action.BACK)
        .addAction(
          Action.Builder()
            .setTitle("Trips")
            .setOnClickListener { screenManager.popToRoot() }
            .build(),
        )
        .build()
    }
    val dest = CarNavState.destinationName.ifBlank { "Destination" }
    val cue = CarNavState.nextManeuverText.ifBlank { "Head to " + dest }
    val road = CarNavState.roadName.ifBlank { dest }

    val maneuver = Maneuver.Builder(CarNavState.maneuverTypeForCar()).build()
    val step = Step.Builder(CarText.create(cue))
      .setRoad(road)
      .setManeuver(maneuver)
      .build()
    val (stepValue, stepUnit) = CarNavState.displayStepDistance()
    val routing = RoutingInfo.Builder()
      .setCurrentStep(step, Distance.create(stepValue, stepUnit))
      .build()

    val (distValue, distUnit) = CarNavState.displayDistance()
    val arrivalMs = System.currentTimeMillis() + CarNavState.durationSec * 1000L
    val estimate = TravelEstimate.Builder(
      Distance.create(distValue, distUnit),
      DateTimeWithZone.create(arrivalMs, TimeZone.getDefault()),
    )
      .setRemainingTimeSeconds(CarNavState.durationSec)
      .setTripText(CarText.create(dest))
      .build()

    return NavigationTemplate.Builder()
      .setNavigationInfo(routing)
      .setDestinationTravelEstimate(estimate)
      .setActionStrip(
        ActionStrip.Builder()
          .addAction(
            Action.Builder()
              .setTitle(if (CarNavState.muted) "Unmute" else "Mute")
              .setOnClickListener {
                CarNavState.setMutedState(!CarNavState.muted)
                CarNavState.postCarCommand(CarBridge.CMD_TOGGLE_MUTE)
                invalidate()
              }
              .build(),
          )
          .addAction(
            Action.Builder()
              .setTitle("End")
              .setOnClickListener {
                CarNavState.postCarCommand(CarBridge.CMD_END_NAVIGATION)
                CarNavState.clearNavigation()
                screenManager.popToRoot()
              }
              .build(),
          )
          .build(),
      )
      .build()
  }
}
