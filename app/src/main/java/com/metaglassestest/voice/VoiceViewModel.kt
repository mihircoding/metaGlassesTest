package com.metaglassestest.voice

import android.app.Activity
import android.app.Application
import android.content.Intent
import android.media.AudioDeviceInfo
import android.media.AudioManager
import android.os.Bundle
import android.os.Handler
import android.os.Looper
import android.os.SystemClock
import android.speech.RecognitionListener
import android.speech.RecognizerIntent
import android.speech.SpeechRecognizer
import android.speech.tts.TextToSpeech
import androidx.lifecycle.AndroidViewModel
import androidx.lifecycle.viewModelScope
import com.google.mlkit.vision.barcode.BarcodeScanner
import com.google.mlkit.vision.barcode.BarcodeScannerOptions
import com.google.mlkit.vision.barcode.BarcodeScanning
import com.google.mlkit.vision.barcode.common.Barcode
import com.google.mlkit.vision.common.InputImage
import com.meta.wearable.dat.camera.StreamSession
import com.meta.wearable.dat.camera.startStreamSession
import com.meta.wearable.dat.camera.types.StreamConfiguration
import com.meta.wearable.dat.camera.types.StreamSessionState
import com.meta.wearable.dat.camera.types.VideoFrame
import com.meta.wearable.dat.camera.types.VideoQuality
import com.meta.wearable.dat.core.Wearables
import com.meta.wearable.dat.core.selectors.AutoDeviceSelector
import com.meta.wearable.dat.core.types.Permission
import com.meta.wearable.dat.core.types.PermissionStatus
import kotlinx.coroutines.Dispatchers
import kotlinx.coroutines.Job
import kotlinx.coroutines.flow.MutableStateFlow
import kotlinx.coroutines.flow.StateFlow
import kotlinx.coroutines.flow.asStateFlow
import kotlinx.coroutines.flow.update
import kotlinx.coroutines.launch
import java.util.Locale

class VoiceViewModel(application: Application) : AndroidViewModel(application) {

    private val mainHandler = Handler(Looper.getMainLooper())
    private var speechRecognizer: SpeechRecognizer? = null

    private val deviceSelector = AutoDeviceSelector()
    private var streamSession: StreamSession? = null
    private var streamVideoJob: Job? = null
    private var streamStateJob: Job? = null

    private val barcodeScanner: BarcodeScanner =
        BarcodeScanning.getClient(
            BarcodeScannerOptions.Builder()
                .setBarcodeFormats(
                    Barcode.FORMAT_QR_CODE,
                    Barcode.FORMAT_CODE_128,
                    Barcode.FORMAT_CODE_39,
                    Barcode.FORMAT_CODE_93,
                    Barcode.FORMAT_CODABAR,
                    Barcode.FORMAT_DATA_MATRIX,
                    Barcode.FORMAT_EAN_13,
                    Barcode.FORMAT_EAN_8,
                    Barcode.FORMAT_ITF,
                    Barcode.FORMAT_UPC_A,
                    Barcode.FORMAT_UPC_E,
                    Barcode.FORMAT_PDF417,
                    Barcode.FORMAT_AZTEC,
                )
                .build(),
        )

    @Volatile
    private var barcodeDecodeBusy = false

    private var lastBarcodeProcessRealtimeMs = 0L
    private var lastAnnouncedRaw: String? = null
    private var lastAnnouncedAtMs = 0L

    private var tts: TextToSpeech? = null

    private val _uiState = MutableStateFlow(VoiceUiState())
    val uiState: StateFlow<VoiceUiState> = _uiState.asStateFlow()

    private val recognitionListener =
        object : RecognitionListener {
            override fun onReadyForSpeech(params: Bundle?) {
                _uiState.update { it.copy(statusMessage = "Listening…") }
            }

            override fun onBeginningOfSpeech() {}

            override fun onRmsChanged(rmsdB: Float) {}

            override fun onBufferReceived(buffer: ByteArray?) {}

            override fun onEndOfSpeech() {
                _uiState.update { it.copy(statusMessage = "Processing…") }
            }

            override fun onError(error: Int) {
                val msg =
                    when (error) {
                        SpeechRecognizer.ERROR_AUDIO -> "Audio recording error"
                        SpeechRecognizer.ERROR_CLIENT -> "Client error"
                        SpeechRecognizer.ERROR_INSUFFICIENT_PERMISSIONS -> "Microphone permission denied"
                        SpeechRecognizer.ERROR_NETWORK -> "Network error"
                        SpeechRecognizer.ERROR_NETWORK_TIMEOUT -> "Network timeout"
                        SpeechRecognizer.ERROR_NO_MATCH -> "No speech recognized"
                        SpeechRecognizer.ERROR_RECOGNIZER_BUSY -> "Recognizer busy"
                        SpeechRecognizer.ERROR_SERVER -> "Server error"
                        SpeechRecognizer.ERROR_SPEECH_TIMEOUT -> "No speech detected"
                        SpeechRecognizer.ERROR_LANGUAGE_UNAVAILABLE ->
                            "Offline language model unavailable — open system settings to download"
                        else -> "Speech error ($error)"
                    }
                _uiState.update {
                    it.copy(
                        listening = false,
                        statusMessage = null,
                        errorMessage = msg,
                    )
                }
            }

            override fun onResults(results: Bundle?) {
                val matches =
                    results?.getStringArrayList(SpeechRecognizer.RESULTS_RECOGNITION)
                        ?: return
                val spoken = matches.firstOrNull()?.trim().orEmpty()
                if (spoken.isNotEmpty()) {
                    _uiState.update { state ->
                        val block = state.transcript
                        val next =
                            if (block.isEmpty()) spoken else "$block\n$spoken"
                        state.copy(
                            transcript = next,
                            partialText = "",
                            listening = false,
                            statusMessage = null,
                        )
                    }
                } else {
                    _uiState.update { it.copy(listening = false, statusMessage = null) }
                }
            }

            override fun onPartialResults(partialResults: Bundle?) {
                val partial =
                    partialResults
                        ?.getStringArrayList(SpeechRecognizer.RESULTS_RECOGNITION)
                        ?.firstOrNull()
                        .orEmpty()
                _uiState.update { it.copy(partialText = partial) }
            }

            override fun onEvent(eventType: Int, params: Bundle?) {}
        }

    init {
        mainHandler.post {
            val ctx = getApplication<Application>()
            tts =
                TextToSpeech(ctx) { status ->
                    if (status == TextToSpeech.SUCCESS) {
                        tts?.language = Locale.getDefault()
                    }
                }
        }
    }

    fun startMonitoring() {
        val app = getApplication<Application>()
        val onDevice = SpeechRecognizer.isOnDeviceRecognitionAvailable(app)
        _uiState.update { it.copy(onDeviceSttAvailable = onDevice) }

        viewModelScope.launch {
            Wearables.registrationState.collect { state ->
                _uiState.update { it.copy(registrationState = state) }
            }
        }
        viewModelScope.launch {
            Wearables.devices.collect { devices ->
                val list = devices.toList()
                _uiState.update {
                    it.copy(
                        devices = list,
                        hasActiveDevice = list.isNotEmpty(),
                    )
                }
            }
        }
    }

    fun startRegistration(activity: Activity) {
        Wearables.startRegistration(activity)
    }

    fun startUnregistration(activity: Activity) {
        Wearables.startUnregistration(activity)
    }

    /**
     * Streams glasses camera, decodes barcodes with ML Kit, shows result, and speaks it via TTS (route audio to glasses first).
     */
    fun startBarcodeScan(requestWearablePermission: suspend (Permission) -> PermissionStatus) {
        viewModelScope.launch {
            clearError()
            val check = Wearables.checkPermissionStatus(Permission.CAMERA)
            check.onFailure { err, _ ->
                _uiState.update { it.copy(errorMessage = "Permission check error: ${err.description}") }
                return@launch
            }
            var granted = check.getOrNull() == PermissionStatus.Granted
            if (!granted) {
                val requested = requestWearablePermission(Permission.CAMERA)
                granted = requested == PermissionStatus.Granted
            }
            if (!granted) {
                _uiState.update { it.copy(errorMessage = "Glasses camera permission denied") }
                return@launch
            }

            stopBarcodeStreamInternal()

            val session =
                try {
                    Wearables.startStreamSession(
                        getApplication(),
                        deviceSelector,
                        StreamConfiguration(videoQuality = VideoQuality.LOW, frameRate = 15),
                    )
                } catch (e: Exception) {
                    _uiState.update {
                        it.copy(errorMessage = e.message ?: "Could not start glasses camera stream")
                    }
                    return@launch
                }

            streamSession = session
            _uiState.update { it.copy(barcodeScanning = true) }

            streamVideoJob =
                viewModelScope.launch(Dispatchers.Default) {
                    session.videoStream.collect { frame -> processFrameForBarcode(frame) }
                }
            streamStateJob =
                viewModelScope.launch {
                    session.state.collect { st ->
                        _uiState.update { it.copy(streamSessionState = st) }
                        if (st == StreamSessionState.STOPPED) {
                            stopBarcodeStreamInternal()
                        }
                    }
                }
        }
    }

    fun stopBarcodeScan() {
        viewModelScope.launch { stopBarcodeStreamInternal() }
    }

    private fun stopBarcodeStreamInternal() {
        streamVideoJob?.cancel()
        streamStateJob?.cancel()
        streamVideoJob = null
        streamStateJob = null
        try {
            streamSession?.close()
        } catch (_: Exception) {
        }
        streamSession = null
        barcodeDecodeBusy = false
        _uiState.update {
            it.copy(
                barcodeScanning = false,
                streamSessionState = null,
            )
        }
    }

    private fun processFrameForBarcode(frame: VideoFrame) {
        if (barcodeDecodeBusy) return
        val now = SystemClock.elapsedRealtime()
        if (now - lastBarcodeProcessRealtimeMs < 400) return
        lastBarcodeProcessRealtimeMs = now
        barcodeDecodeBusy = true

        val bitmap = YuvToBitmapConverter.convert(frame.buffer, frame.width, frame.height)
        if (bitmap == null) {
            barcodeDecodeBusy = false
            return
        }

        val image = InputImage.fromBitmap(bitmap, 0)
        barcodeScanner
            .process(image)
            .addOnSuccessListener { barcodes ->
                val b = barcodes.firstOrNull()
                if (b != null) {
                    val raw = b.rawValue ?: b.displayValue
                    if (!raw.isNullOrBlank()) {
                        val format = barcodeFormatLabel(b.format)
                        mainHandler.post { announceBarcodeIfNew(raw.trim(), format) }
                    }
                }
            }
            .addOnCompleteListener {
                if (!bitmap.isRecycled) {
                    bitmap.recycle()
                }
                barcodeDecodeBusy = false
            }
    }

    private fun announceBarcodeIfNew(raw: String, format: String) {
        val t = SystemClock.elapsedRealtime()
        if (raw == lastAnnouncedRaw && t - lastAnnouncedAtMs < 5000) return
        lastAnnouncedRaw = raw
        lastAnnouncedAtMs = t

        _uiState.update {
            it.copy(
                lastBarcodeRaw = raw,
                lastBarcodeFormat = format,
                statusMessage = "Heard via glasses speaker (use Route audio)",
            )
        }

        val line = "Scanned $format. The value is $raw."
        speakWithTts(line)
    }

    private fun speakWithTts(text: String) {
        mainHandler.post {
            val engine = tts
            if (engine == null) {
                tts =
                    TextToSpeech(getApplication()) { status ->
                        if (status == TextToSpeech.SUCCESS) {
                            tts?.language = Locale.getDefault()
                            tts?.speak(text, TextToSpeech.QUEUE_FLUSH, null, "barcode-${System.nanoTime()}")
                        }
                    }
            } else {
                engine.speak(text, TextToSpeech.QUEUE_FLUSH, null, "barcode-${System.nanoTime()}")
            }
        }
    }

    fun routeAudioToGlassesBluetooth() {
        val context = getApplication<Application>()
        val audioManager = context.getSystemService(AudioManager::class.java)
        val devices = audioManager.availableCommunicationDevices
        val preferredOrder =
            listOf(
                AudioDeviceInfo.TYPE_BLUETOOTH_SCO,
                AudioDeviceInfo.TYPE_BLE_HEADSET,
                AudioDeviceInfo.TYPE_BLUETOOTH_A2DP,
            )
        var selected: AudioDeviceInfo? = null
        for (type in preferredOrder) {
            selected = devices.firstOrNull { it.type == type }
            if (selected != null) break
        }
        if (selected != null) {
            audioManager.mode = AudioManager.MODE_IN_COMMUNICATION
            val ok = audioManager.setCommunicationDevice(selected)
            _uiState.update {
                it.copy(
                    bluetoothRouted = ok,
                    errorMessage = if (ok) null else "Could not set Bluetooth communication device",
                )
            }
        } else {
            _uiState.update {
                it.copy(
                    bluetoothRouted = false,
                    errorMessage = "No Bluetooth communication device found. Pair glasses in Meta AI app first.",
                )
            }
        }
    }

    fun clearBluetoothRoute() {
        val audioManager = getApplication<Application>().getSystemService(AudioManager::class.java)
        audioManager.clearCommunicationDevice()
        audioManager.mode = AudioManager.MODE_NORMAL
        _uiState.update { it.copy(bluetoothRouted = false) }
    }

    fun clearError() {
        _uiState.update { it.copy(errorMessage = null) }
    }

    fun clearTranscript() {
        _uiState.update { it.copy(transcript = "", partialText = "") }
    }

    fun clearLastBarcode() {
        _uiState.update { it.copy(lastBarcodeRaw = null, lastBarcodeFormat = null) }
    }

    fun toggleListening() {
        if (_uiState.value.listening) {
            stopListening()
        } else {
            startListening()
        }
    }

    private fun startListening() {
        val context = getApplication<Application>()
        mainHandler.post {
            clearError()
            if (speechRecognizer == null) {
                speechRecognizer =
                    if (SpeechRecognizer.isOnDeviceRecognitionAvailable(context)) {
                        SpeechRecognizer.createOnDeviceSpeechRecognizer(context)
                    } else {
                        SpeechRecognizer.createSpeechRecognizer(context)
                    }
                speechRecognizer?.setRecognitionListener(recognitionListener)
            }
            val intent =
                Intent(RecognizerIntent.ACTION_RECOGNIZE_SPEECH).apply {
                    putExtra(
                        RecognizerIntent.EXTRA_LANGUAGE_MODEL,
                        RecognizerIntent.LANGUAGE_MODEL_FREE_FORM,
                    )
                    putExtra(RecognizerIntent.EXTRA_PARTIAL_RESULTS, true)
                    putExtra(
                        RecognizerIntent.EXTRA_LANGUAGE,
                        Locale.getDefault().toLanguageTag(),
                    )
                }
            try {
                speechRecognizer?.startListening(intent)
                _uiState.update { it.copy(listening = true, statusMessage = "Starting…") }
            } catch (e: Exception) {
                _uiState.update {
                    it.copy(
                        listening = false,
                        errorMessage = e.message ?: "Could not start speech recognition",
                    )
                }
            }
        }
    }

    private fun stopListening() {
        mainHandler.post {
            try {
                speechRecognizer?.stopListening()
            } catch (_: Exception) {
            }
            _uiState.update { it.copy(listening = false, statusMessage = null) }
        }
    }

    override fun onCleared() {
        super.onCleared()
        streamVideoJob?.cancel()
        streamStateJob?.cancel()
        try {
            streamSession?.close()
        } catch (_: Exception) {
        }
        streamSession = null
        try {
            barcodeScanner.close()
        } catch (_: Exception) {
        }
        mainHandler.post {
            speechRecognizer?.destroy()
            speechRecognizer = null
            tts?.stop()
            tts?.shutdown()
            tts = null
        }
    }
}
