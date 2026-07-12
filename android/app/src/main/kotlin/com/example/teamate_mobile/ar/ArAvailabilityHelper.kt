package com.example.teamate_mobile.ar

import android.app.Activity
import android.content.Context
import com.google.ar.core.ArCoreApk
import com.google.ar.core.exceptions.UnavailableDeviceNotCompatibleException
import com.google.ar.core.exceptions.UnavailableUserDeclinedInstallationException

/** Wraps ArCoreApk's availability check + Play Services for AR install flow for the MethodChannel. */
object ArAvailabilityHelper {

    fun checkAvailability(context: Context): String {
        return when (ArCoreApk.getInstance().checkAvailability(context)) {
            ArCoreApk.Availability.SUPPORTED_INSTALLED -> "SUPPORTED_INSTALLED"
            ArCoreApk.Availability.SUPPORTED_APK_TOO_OLD -> "SUPPORTED_APK_TOO_OLD"
            ArCoreApk.Availability.SUPPORTED_NOT_INSTALLED -> "SUPPORTED_NOT_INSTALLED"
            ArCoreApk.Availability.UNSUPPORTED_DEVICE_NOT_CAPABLE -> "UNSUPPORTED"
            else -> "UNKNOWN_CHECKING" // UNKNOWN_CHECKING / UNKNOWN_ERROR / UNKNOWN_TIMED_OUT
        }
    }

    /**
     * Must be called from an Activity — ARCore's install flow relies on the calling Activity's
     * onResume to detect completion after returning from the Play Store.
     */
    fun requestInstall(activity: Activity, userRequestedInstall: Boolean): String {
        return try {
            when (ArCoreApk.getInstance().requestInstall(activity, userRequestedInstall)) {
                ArCoreApk.InstallStatus.INSTALLED -> "INSTALLED"
                ArCoreApk.InstallStatus.INSTALL_REQUESTED -> "INSTALL_REQUESTED"
                else -> "INSTALL_REQUESTED"
            }
        } catch (e: UnavailableDeviceNotCompatibleException) {
            "UNSUPPORTED"
        } catch (e: UnavailableUserDeclinedInstallationException) {
            "DECLINED"
        } catch (e: Exception) {
            "ERROR"
        }
    }
}
