package com.navora.navora.car

import androidx.car.app.CarAppService
import androidx.car.app.Session
import androidx.car.app.validation.HostValidator

/**
 * Entry point for Android Auto (projection).
 * Declared in AndroidManifest with the NAVIGATION category + automotive_app_desc.xml.
 */
class NavoraCarAppService : CarAppService() {
  override fun createHostValidator(): HostValidator {
    // TODO(P1, Play release): restrict to the Play allowlist instead of ALLOW_ALL.
    // ALLOW_ALL is correct for DHU + sideload testing; Play review expects a
    // restrictive validator (HostValidator.Builder with hosts_allowlist).
    return HostValidator.ALLOW_ALL_HOSTS_VALIDATOR
  }

  override fun onCreateSession(): Session = NavoraSession()
}
