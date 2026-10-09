package com.navora.navora.car

import android.content.Intent
import androidx.car.app.Screen
import androidx.car.app.Session
import com.navora.navora.car.screens.NavoraRootScreen

class NavoraSession : Session() {
  override fun onCreateScreen(intent: Intent): Screen = NavoraRootScreen(carContext)
}
