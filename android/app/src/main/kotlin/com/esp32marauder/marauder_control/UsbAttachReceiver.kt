package com.esp32marauder.marauder_control

import android.content.BroadcastReceiver
import android.content.Context
import android.content.Intent

class UsbAttachReceiver : BroadcastReceiver() {
    override fun onReceive(context: Context, intent: Intent) {
        // The Flutter screen refreshes the device list on demand. This receiver
        // reserves the lifecycle boundary for future attach notifications.
    }
}
