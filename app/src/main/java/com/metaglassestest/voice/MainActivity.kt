package com.metaglassestest.voice

import android.Manifest
import android.os.Bundle
import androidx.activity.ComponentActivity
import androidx.activity.compose.setContent
import androidx.activity.enableEdgeToEdge
import androidx.activity.result.contract.ActivityResultContracts
import androidx.activity.viewModels
import androidx.compose.foundation.layout.Arrangement
import androidx.compose.foundation.layout.Column
import androidx.compose.foundation.layout.Row
import androidx.compose.foundation.layout.Spacer
import androidx.compose.foundation.layout.fillMaxSize
import androidx.compose.foundation.layout.fillMaxWidth
import androidx.compose.foundation.layout.height
import androidx.compose.foundation.layout.padding
import androidx.compose.foundation.layout.width
import androidx.compose.foundation.rememberScrollState
import androidx.compose.foundation.verticalScroll
import androidx.compose.material.icons.Icons
import androidx.compose.material.icons.filled.Mic
import androidx.compose.material.icons.filled.MicOff
import androidx.compose.material3.Button
import androidx.compose.material3.Card
import androidx.compose.material3.CardDefaults
import androidx.compose.material3.ExperimentalMaterial3Api
import androidx.compose.material3.Icon
import androidx.compose.material3.MaterialTheme
import androidx.compose.material3.OutlinedButton
import androidx.compose.material3.Scaffold
import androidx.compose.material3.SnackbarHost
import androidx.compose.material3.SnackbarHostState
import androidx.compose.material3.Text
import androidx.compose.material3.TextButton
import androidx.compose.material3.TopAppBar
import androidx.compose.material3.darkColorScheme
import androidx.compose.runtime.Composable
import androidx.compose.runtime.LaunchedEffect
import androidx.compose.runtime.collectAsState
import androidx.compose.runtime.getValue
import androidx.compose.runtime.remember
import androidx.compose.runtime.rememberCoroutineScope
import androidx.compose.ui.Alignment
import androidx.compose.ui.Modifier
import androidx.compose.ui.graphics.Color
import androidx.compose.ui.text.font.FontFamily
import androidx.compose.ui.unit.dp
import com.meta.wearable.dat.core.Wearables
import com.meta.wearable.dat.core.types.Permission
import com.meta.wearable.dat.core.types.PermissionStatus
import com.meta.wearable.dat.core.types.RegistrationState
import kotlin.coroutines.resume
import kotlinx.coroutines.CancellableContinuation
import kotlinx.coroutines.launch
import kotlinx.coroutines.suspendCancellableCoroutine
import kotlinx.coroutines.sync.Mutex
import kotlinx.coroutines.sync.withLock

class MainActivity : ComponentActivity() {

    private val viewModel: VoiceViewModel by viewModels()

    private val permissionLauncher =
        registerForActivityResult(ActivityResultContracts.RequestMultiplePermissions()) { result ->
            val allGranted = result.values.all { it }
            if (allGranted) {
                Wearables.initialize(this)
                viewModel.startMonitoring()
            }
        }

    private var permissionContinuation: CancellableContinuation<PermissionStatus>? = null
    private val permissionMutex = Mutex()

    private val wearablesPermissionLauncher =
        registerForActivityResult(Wearables.RequestPermissionContract()) { result ->
            val status = result.getOrDefault(PermissionStatus.Denied)
            permissionContinuation?.resume(status)
            permissionContinuation = null
        }

    private suspend fun requestWearablePermission(permission: Permission): PermissionStatus {
        return permissionMutex.withLock {
            suspendCancellableCoroutine { continuation ->
                permissionContinuation = continuation
                continuation.invokeOnCancellation { permissionContinuation = null }
                wearablesPermissionLauncher.launch(permission)
            }
        }
    }

    @OptIn(ExperimentalMaterial3Api::class)
    override fun onCreate(savedInstanceState: Bundle?) {
        super.onCreate(savedInstanceState)
        enableEdgeToEdge()
        setContent {
            val snackbarHostState = remember { SnackbarHostState() }
            val uiState by viewModel.uiState.collectAsState()
            val scope = rememberCoroutineScope()

            LaunchedEffect(uiState.errorMessage) {
                val msg = uiState.errorMessage
                if (msg != null) {
                    snackbarHostState.showSnackbar(msg)
                    viewModel.clearError()
                }
            }

            MetaGlassesTheme {
                Scaffold(
                    topBar = {
                        TopAppBar(
                            title = { Text("Meta Glasses Voice") },
                        )
                    },
                    snackbarHost = { SnackbarHost(snackbarHostState) },
                ) { padding ->
                    VoiceScreen(
                        modifier = Modifier.padding(padding),
                        uiState = uiState,
                        onRegister = { viewModel.startRegistration(this@MainActivity) },
                        onUnregister = { viewModel.startUnregistration(this@MainActivity) },
                        onRouteBluetooth = { viewModel.routeAudioToGlassesBluetooth() },
                        onClearRoute = { viewModel.clearBluetoothRoute() },
                        onToggleListen = { viewModel.toggleListening() },
                        onClearTranscript = { viewModel.clearTranscript() },
                        onStartBarcodeScan = {
                            scope.launch {
                                viewModel.startBarcodeScan { perm ->
                                    requestWearablePermission(perm)
                                }
                            }
                        },
                        onStopBarcodeScan = { viewModel.stopBarcodeScan() },
                        onClearBarcode = { viewModel.clearLastBarcode() },
                    )
                }
            }
        }
    }

    override fun onStart() {
        super.onStart()
        permissionLauncher.launch(
            arrayOf(
                Manifest.permission.BLUETOOTH,
                Manifest.permission.BLUETOOTH_CONNECT,
                Manifest.permission.INTERNET,
                Manifest.permission.RECORD_AUDIO,
            ),
        )
    }
}

@Composable
private fun MetaGlassesTheme(content: @Composable () -> Unit) {
    val scheme =
        darkColorScheme(
            primary = Color(0xFF7EC8E3),
            secondary = Color(0xFFB8D4E3),
            tertiary = Color(0xFFE3C87E),
            background = Color(0xFF0D1520),
            surface = Color(0xFF152030),
        )
    MaterialTheme(colorScheme = scheme, content = content)
}

@Composable
private fun VoiceScreen(
    modifier: Modifier = Modifier,
    uiState: VoiceUiState,
    onRegister: () -> Unit,
    onUnregister: () -> Unit,
    onRouteBluetooth: () -> Unit,
    onClearRoute: () -> Unit,
    onToggleListen: () -> Unit,
    onClearTranscript: () -> Unit,
    onStartBarcodeScan: () -> Unit,
    onStopBarcodeScan: () -> Unit,
    onClearBarcode: () -> Unit,
) {
    Column(
        modifier =
            modifier
                .fillMaxSize()
                .padding(16.dp)
                .verticalScroll(rememberScrollState()),
        verticalArrangement = Arrangement.spacedBy(12.dp),
    ) {
        Text(
            text = registrationLabel(uiState.registrationState),
            style = MaterialTheme.typography.bodyMedium,
        )
        Text(
            text =
                "Devices: ${uiState.devices.size} · Active: ${if (uiState.hasActiveDevice) "yes" else "no"}",
            style = MaterialTheme.typography.bodySmall,
            color = MaterialTheme.colorScheme.onSurfaceVariant,
        )
        Text(
            text =
                "On-device STT: ${if (uiState.onDeviceSttAvailable) "available" else "not available (fallback may use network)"}",
            style = MaterialTheme.typography.bodySmall,
            color = MaterialTheme.colorScheme.onSurfaceVariant,
        )

        Text(
            text =
                "Barcode stream: ${if (uiState.barcodeScanning) "on (${uiState.streamSessionState})" else "off"}",
            style = MaterialTheme.typography.bodySmall,
            color = MaterialTheme.colorScheme.onSurfaceVariant,
        )

        Button(onClick = onRegister, modifier = Modifier.fillMaxWidth()) {
            Text("Register with Meta AI")
        }
        OutlinedButton(onClick = onUnregister, modifier = Modifier.fillMaxWidth()) {
            Text("Unregister")
        }

        Button(onClick = onRouteBluetooth, modifier = Modifier.fillMaxWidth()) {
            Text("Route audio to Bluetooth (glasses)")
        }
        OutlinedButton(onClick = onClearRoute, modifier = Modifier.fillMaxWidth()) {
            Text("Clear Bluetooth route")
        }

        Text(
            text = "Point the glasses camera at a barcode or QR code. Audio is spoken via TTS (use Route audio for glasses).",
            style = MaterialTheme.typography.bodySmall,
            color = MaterialTheme.colorScheme.onSurfaceVariant,
        )

        Button(
            onClick = onStartBarcodeScan,
            enabled = !uiState.barcodeScanning,
            modifier = Modifier.fillMaxWidth(),
        ) {
            Text("Start barcode scan (glasses camera)")
        }
        OutlinedButton(
            onClick = onStopBarcodeScan,
            enabled = uiState.barcodeScanning,
            modifier = Modifier.fillMaxWidth(),
        ) {
            Text("Stop barcode scan")
        }

        Button(
            onClick = onToggleListen,
            modifier = Modifier.fillMaxWidth(),
        ) {
            Row(
                verticalAlignment = Alignment.CenterVertically,
                horizontalArrangement = Arrangement.Center,
            ) {
                Icon(
                    imageVector = if (uiState.listening) Icons.Default.MicOff else Icons.Default.Mic,
                    contentDescription = null,
                )
                Spacer(Modifier.width(8.dp))
                Text(if (uiState.listening) "Stop listening" else "Start listening")
            }
        }

        uiState.statusMessage?.let { Text(it, style = MaterialTheme.typography.labelMedium) }

        RowActions(onClearTranscript, onClearBarcode)

        Card(
            modifier = Modifier.fillMaxWidth(),
            colors =
                CardDefaults.cardColors(
                    containerColor = MaterialTheme.colorScheme.surface,
                ),
        ) {
            Column(modifier = Modifier.padding(16.dp)) {
                Text("Last barcode", style = MaterialTheme.typography.titleMedium)
                Spacer(Modifier.height(8.dp))
                val fmt = uiState.lastBarcodeFormat
                val raw = uiState.lastBarcodeRaw
                val text =
                    if (fmt == null && raw == null) {
                        "(scan a code)"
                    } else {
                        "${fmt ?: "Unknown"}: ${raw ?: ""}"
                    }
                Text(
                    text = text,
                    style = MaterialTheme.typography.bodyLarge,
                    fontFamily = FontFamily.Monospace,
                )
            }
        }

        Card(
            modifier = Modifier.fillMaxWidth(),
            colors =
                CardDefaults.cardColors(
                    containerColor = MaterialTheme.colorScheme.surface,
                ),
        ) {
            Column(modifier = Modifier.padding(16.dp)) {
                Text("Transcript", style = MaterialTheme.typography.titleMedium)
                Spacer(Modifier.height(8.dp))
                val display =
                    buildString {
                        append(uiState.transcript)
                        if (uiState.partialText.isNotEmpty()) {
                            if (isNotEmpty()) append("\n")
                            append(uiState.partialText)
                            if (uiState.listening) append("…")
                        }
                    }
                Text(
                    text = if (display.isEmpty()) "(spoken text appears here)" else display,
                    style = MaterialTheme.typography.bodyLarge,
                    fontFamily = FontFamily.Monospace,
                    color =
                        if (display.isEmpty()) {
                            MaterialTheme.colorScheme.onSurfaceVariant
                        } else {
                            MaterialTheme.colorScheme.onSurface
                        },
                )
            }
        }
    }
}

@Composable
private fun RowActions(onClearTranscript: () -> Unit, onClearBarcode: () -> Unit) {
    Row(
        modifier = Modifier.fillMaxWidth(),
        horizontalArrangement = Arrangement.End,
        verticalAlignment = Alignment.CenterVertically,
    ) {
        TextButton(onClick = onClearBarcode) {
            Text("Clear barcode")
        }
        TextButton(onClick = onClearTranscript) {
            Text("Clear transcript")
        }
    }
}

private fun registrationLabel(state: RegistrationState?): String =
    when (state) {
        null -> "Registration: …"
        is RegistrationState.Available -> "Registration: ready to register"
        is RegistrationState.Registered -> "Registration: registered"
        is RegistrationState.Registering -> "Registration: registering…"
        is RegistrationState.Unregistering -> "Registration: unregistering…"
        is RegistrationState.Unavailable -> "Registration: unavailable"
    }
