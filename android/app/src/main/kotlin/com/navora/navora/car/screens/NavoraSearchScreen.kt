package com.navora.navora.car.screens

import androidx.car.app.CarContext
import androidx.car.app.Screen
import androidx.car.app.model.Action
import androidx.car.app.model.ItemList
import androidx.car.app.model.Row
import androidx.car.app.model.SearchTemplate
import androidx.car.app.model.Template
import com.navora.navora.car.CarBridge
import com.navora.navora.car.CarNavState

/**
 * Destination search. While driving the host may restrict the keyboard;
 * results are capped and every tap posts a command for Dart to resolve
 * via Photon/OSRM on the phone.
 */
class NavoraSearchScreen(carContext: CarContext) : Screen(carContext) {
  @Volatile private var query: String = ""
  @Volatile private var submitted: String = ""

  private val callback = object : SearchTemplate.SearchCallback {
    override fun onSearchTextChanged(searchText: String) {
      query = searchText.take(80)
      invalidate()
    }

    override fun onSearchSubmitted(searchText: String) {
      submitted = searchText.take(80).trim()
      if (submitted.isNotEmpty()) {
        CarNavState.postCarCommand(CarBridge.CMD_SEARCH, submitted)
      }
      invalidate()
    }
  }

  override fun onGetTemplate(): Template {
    val list = ItemList.Builder()
    if (submitted.isEmpty()) {
      list.setNoItemsMessage("Type a place, then Search")
    } else {
      // MVP: echo the submitted query as a single startable row. Full
      // Photon results arrive in Phase 2b via updateTrips/searchResults.
      list.addItem(
        Row.Builder()
          .setTitle("Navigate to \"" + submitted.take(40) + "\"")
          .addText("Resolves on the phone via Photon + OSRM")
          .setOnClickListener {
            CarNavState.postCarCommand(CarBridge.CMD_SEARCH, submitted)
            CarNavState.updateNavigation(
              destination = submitted.take(40),
              maneuverText = "Head to " + submitted.take(40),
              road = "",
              remainingM = 0.0,
              remainingSec = 0L,
              stepM = 0.0,
            )
            screenManager.push(NavoraGuidanceScreen(carContext))
          }
          .build(),
      )
    }
    return SearchTemplate.Builder(callback)
      .setSearchHint("Search places")
      .setHeaderAction(Action.BACK)
      .setItemList(list.build())
      .setShowKeyboardByDefault(false)
      .build()
  }
}
