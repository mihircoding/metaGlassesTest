package com.metaglassestest.voice

import android.app.Activity
import android.app.Application
import android.content.Intent
import android.media.AudioDeviceInfo
import android.media.AudioManager
import android.os.Bundle
import android.os.Handler
import android.os.Looper
import android.speech.RecognitionListener
import android.speech.RecognizerIntent
import android.speech.SpeechRecognizer
import androidx.lifecycle.AndroidViewModel
import androidx.lifecycle.viewModelScope
import com.meta.wearable.dat.core.Wearables
import kotlinx.coroutines.flow.MutableStateFlow
import kotlinx.coroutines.flow.StateFlow
import kotlinx.coroutines.flow.asStateFlow
import kotlinx.coroutines.flow.update
import kotlinx.coroutines.launch
import java.util.Locale

class VoiceViewModel(application: Application) : AndroidViewModel(application) {

    private val mainHandler = Handler(Looper.getMainLooper())
    private var speechRecognizer: SpeechRecognizer? = null

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
        mainHandler.post {
            speechRecognizer?.destroy()
            speechRecognizer = null
        }
    }
}
