package com.navora.navora.car.screens

import androidx.car.app.CarContext
import androidx.car.app.Screen
import androidx.car.app.model.Action
import androidx.car.app.model.ActionStrip
import androidx.car.app.model.CarText
import androidx.car.app.model.ItemList
import androidx.car.app.model.PlaceListMapTemplate
import androidx.car.app.model.Row
import androidx.car.app.model.Template
import com.navora.navora.car.CarNavState

/**
 * Car root: trips that can be started from the head unit.
 * Distraction-safe: max 6 rows, no text entry while driving (see Search screen).
 */
class NavoraRootScreen(carContext: CarContext) : Screen(carContext) {
  override fun onGetTemplate(): Template {
    val trips = CarNavState.tripTitles.take(CarNavState.MAX_TRIPS)
    val list = ItemList.Builder()
    if (trips.isEmpty()) {
      list.setNoItemsMessage("No trips yet — create one on the phone")
    } else {
      trips.forEachIndexed { index, title ->
        list.addItem(
          Row.Builder()
            .setTitle(title)
            .addText("Trip ${index + 1} · open on phone for details")
            .setOnClickListener {
              CarNavState.postCarCommand(
                com.navora.navora.car.CarBridge.CMD_SELECT_TRIP, title)
              CarNavState.startDemo()
              screenManager.push(NavoraGuidanceScreen(carContext))
            }
            .build(),
        )
      }
    }
    // If the phone is already guiding, surface a resume row.
    if (CarNavState.navigating) {
      list.addItem(
        Row.Builder()
          .setTitle("Resume guidance: ${CarNavState.destinationName}")
          .addText(CarNavState.nextManeuverText.ifBlank { "Tap to open guidance" })
          .setOnClickListener { screenManager.push(NavoraGuidanceScreen(carContext)) }
          .build(),
      )
    }
    return PlaceListMapTemplate.Builder()
      .setTitle("Navora trips")
      .setItemList(list.build())
      .setHeaderAction(Action.APP_ICON)
      .setActionStrip(
        ActionStrip.Builder()
          .addAction(
            Action.Builder()
              .setTitle("Search")
              .setOnClickListener { screenManager.push(NavoraSearchScreen(carContext)) }
              .build(),
          )
          .addAction(
            Action.Builder()
              .setTitle("Demo")
              .setOnClickListener {
                CarNavState.postCarCommand(
                  com.navora.navora.car.CarBridge.CMD_START_DEMO)
                CarNavState.startDemo()
                screenManager.push(NavoraGuidanceScreen(carContext))
              }
              .build(),
          )
          .build(),
      )
      .build()
  }
}
