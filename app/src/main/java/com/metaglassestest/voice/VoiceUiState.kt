package com.metaglassestest.voice

import com.meta.wearable.dat.camera.types.StreamSessionState
import com.meta.wearable.dat.core.types.DeviceIdentifier
import com.meta.wearable.dat.core.types.RegistrationState

data class VoiceUiState(
    val registrationState: RegistrationState? = null,
    val devices: List<DeviceIdentifier> = emptyList(),
    val hasActiveDevice: Boolean = false,
    val bluetoothRouted: Boolean = false,
    val onDeviceSttAvailable: Boolean = false,
    val listening: Boolean = false,
    val partialText: String = "",
    val transcript: String = "",
    val statusMessage: String? = null,
    val errorMessage: String? = null,
    val barcodeScanning: Boolean = false,
    val streamSessionState: StreamSessionState? = null,
    val lastBarcodeFormat: String? = null,
    val lastBarcodeRaw: String? = null,
)
