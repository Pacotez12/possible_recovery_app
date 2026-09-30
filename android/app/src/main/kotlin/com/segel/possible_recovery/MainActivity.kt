package com.segel.possible_recovery

import android.content.BroadcastReceiver
import android.content.Context
import android.content.Intent
import android.content.IntentFilter
import android.media.AudioManager
import android.media.ToneGenerator
import android.util.Log
import android.view.KeyEvent
import com.rscja.barcode.BarcodeDecoder
import com.rscja.barcode.BarcodeFactory
import com.rscja.barcode.BarcodeUtility
import com.rscja.deviceapi.RFIDWithUHFUART
import com.rscja.deviceapi.entity.BarcodeEntity
import com.rscja.deviceapi.entity.UHFTAGInfo
import com.rscja.deviceapi.interfaces.IUHFInventoryCallback
import android.os.Handler
import android.os.Looper
import io.flutter.embedding.android.FlutterActivity
import io.flutter.embedding.engine.FlutterEngine
import io.flutter.plugin.common.MethodChannel
import java.lang.Exception

class MainActivity : FlutterActivity() {
    private val channelName = "com.segel.possible_recovery/rfid"
    private var uhf: RFIDWithUHFUART? = null
    private var isReaderInitialized = false
    private lateinit var channel: MethodChannel
    private var toneGenerator: ToneGenerator? = null

    private var barcodeDecoder: BarcodeDecoder? = null
    private var isScannerOpen = false
    private var isWaitingSku = false
    private var currentKeyMode = "rfid"
    private var isBarcodeScanActive = false
    private val mainHandler = Handler(Looper.getMainLooper())

    private val barcodeFallbackRunnable = Runnable {
        if (isBarcodeScanActive && currentKeyMode == "barcode") {
            Log.i("BARCODE_DEBUG", "triggerBarcodeScan fallback: 3s elapsed without broadcast result, trying barcodeDecoder.startScan()")
            try {
                if (!isScannerOpen || barcodeDecoder == null) {
                    initBarcodeDecoder()
                }
                barcodeDecoder?.startScan()
            } catch (e: Exception) {
                Log.e("BARCODE_DEBUG", "Fallback barcodeDecoder.startScan() error: ${e.message}")
            }
        }
    }

    private val burstLock = Any()
    private var isBurstActive = false
    private val burstTags = mutableMapOf<String, Double>()

    private var isScanKeyPressed = false
    private var lastDeliveredBarcode = ""
    private var lastDeliveredAt = 0L
    private var simulatedTagEpc: String? = null
    private val loggedEpcTags = java.util.concurrent.ConcurrentHashMap.newKeySet<String>()

    private fun normalizeEpc(epc: String, pcWords: Int? = null): String {
        val clean = epc.replace(" ", "").trim().uppercase()
        if (clean.isEmpty()) return ""

        if (pcWords != null && pcWords > 0) {
            val targetLen = pcWords * 4
            if (clean.length > targetLen) {
                return clean.substring(0, targetLen)
            }
            return clean
        }

        // Respaldo cuando no hay PC utilizable: si epc tiene 32 hex, empieza con '30' y termina en '00000000' -> recortar a 24
        if (clean.length == 32 && clean.startsWith("30") && clean.endsWith("00000000")) {
            return clean.substring(0, 24)
        }

        return clean
    }

    private fun normalizeEpcWithTag(tagInfo: UHFTAGInfo): String {
        val epcRaw = (tagInfo.epc ?: "").replace(" ", "").trim().uppercase()
        val pcStr = try { tagInfo.pc?.replace(" ", "")?.trim() } catch (e: Throwable) { null }

        var words = 0
        if (!pcStr.isNullOrEmpty()) {
            try {
                val pcVal = pcStr.toInt(16)
                if (pcVal != 0) {
                    words = (pcVal shr 11) and 0x1F
                }
            } catch (e: Exception) {
                words = 0
            }
        }
        val epcHexLen = words * 4

        val epcFinal = normalizeEpc(epcRaw, if (words > 0) words else null)

        if (epcRaw.isNotEmpty() && loggedEpcTags.add(epcRaw)) {
            Log.i("RFID_DEBUG", "Tag normalize: epcRaw=$epcRaw, pc=$pcStr, epcHexLen=$epcHexLen, epcFinal=$epcFinal")
        }

        return epcFinal
    }

    private val scannerReceiver = object : BroadcastReceiver() {
        override fun onReceive(context: Context?, intent: Intent?) {
            if (intent == null) return
            val action = intent.action
            Log.i("BARCODE_DEBUG", "scannerReceiver.onReceive action=$action")
            if (action == "com.segel.possible_recovery.SIMULATE_TAG") {
                val epc = intent.getStringExtra("epc") ?: "309373E167B0610BDCE43394"
                val normalizedEpc = normalizeEpc(epc)
                Log.i("RFID_DEBUG", "SIMULATE_TAG received: epc=$epc, normalized=$normalizedEpc")
                simulatedTagEpc = normalizedEpc
                runOnUiThread {
                    channel.invokeMethod("onTriggerPressed", null)
                    channel.invokeMethod("trigger", null)
                }
                return
            }
            intent.extras?.let { bundle ->
                for (key in bundle.keySet()) {
                    Log.i("BARCODE_DEBUG", "Intent extra: key='$key', value='${bundle.get(key)}'")
                }
            }
            val barcode = intent.getStringExtra("data")
                ?: intent.getStringExtra("scannerdata")
                ?: intent.getStringExtra("barcode")
                ?: intent.getStringExtra("barcodeStringData")
                ?: intent.getByteArrayExtra("dataBytes")?.let { String(it) }
                ?: intent.getByteArrayExtra("barcodeByteData")?.let { String(it) }

            Log.i("BARCODE_DEBUG", "scannerReceiver extracted barcode: '$barcode'")
            if (!barcode.isNullOrEmpty()) {
                val trimmed = barcode.trim()
                val lower = trimmed.lowercase()
                if (lower == "cancel" || lower == "failuer" || lower == "failure" || lower == "timeout") {
                    Log.i("BARCODE_DEBUG", "scannerReceiver ignoring scanner status: '$barcode'")
                    return
                }
                onBarcodeReceived(trimmed, "BroadcastReceiver($action)")
            }
        }
    }
    private var isReceiverRegistered = false

    private fun registerScannerReceiver() {
        if (isReceiverRegistered) return
        try {
            val filter = IntentFilter().apply {
                addAction("com.scanner.broadcast")
                addAction("com.rscja.scanner.action.SCAN_RESULT_BROADCAST")
                addAction("android.intent.action.SCAN_RESULT_BROADCAST")
                addAction("com.rscja.barcode2d.scanner.result")
                addAction("com.segel.possible_recovery.SIMULATE_TAG")
            }
            registerReceiver(scannerReceiver, filter)
            isReceiverRegistered = true
            Log.i("BARCODE_DEBUG", "registerScannerReceiver: successfully registered for actions: com.scanner.broadcast, etc.")
        } catch (e: Exception) {
            Log.e("BARCODE_DEBUG", "registerScannerReceiver error: ${e.message}", e)
        }
    }

    private fun unregisterScannerReceiver() {
        if (!isReceiverRegistered) return
        try {
            unregisterReceiver(scannerReceiver)
            isReceiverRegistered = false
            Log.i("BARCODE_DEBUG", "unregisterScannerReceiver: unregistered")
        } catch (e: Exception) {
            Log.e("BARCODE_DEBUG", "unregisterScannerReceiver error: ${e.message}", e)
        }
    }

    private fun isBroadcastScannerAvailable(): Boolean {
        return try {
            packageManager.getPackageInfo("com.rscja.scanner", 0) != null
        } catch (e: Exception) {
            false
        }
    }

    private fun onBarcodeReceived(data: String, source: String) {
        val trimmed = data.trim()
        if (trimmed.isEmpty()) return

        val lower = trimmed.lowercase()
        if (lower == "cancel" || lower == "failuer" || lower == "failure" || lower == "timeout") {
            Log.i("BARCODE_DEBUG", "onBarcodeReceived ignoring scanner status from $source: '$trimmed'")
            return
        }

        val now = System.currentTimeMillis()
        if (trimmed == lastDeliveredBarcode && (now - lastDeliveredAt) < 1500L) {
            Log.i("BARCODE_DEBUG", "Ignoring duplicate barcode from $source: $trimmed (< 1500ms since last delivery)")
            // Repeated discards do NOT update lastDeliveredAt!
            return
        }

        // Successfully receiving a valid barcode cancels fallback runnable and active flag
        mainHandler.removeCallbacks(barcodeFallbackRunnable)
        isBarcodeScanActive = false

        lastDeliveredBarcode = trimmed
        lastDeliveredAt = now
        Log.i("BARCODE_DEBUG", "Delivering barcode from $source to Flutter: $trimmed")
        try {
            toneGenerator?.startTone(ToneGenerator.TONE_PROP_BEEP, 40)
        } catch (e: Exception) {
            // ignore audio error
        }
        runOnUiThread {
            channel.invokeMethod("barcode", trimmed)
        }
    }

    private fun initBarcodeDecoder(): Boolean {
        Log.i("BARCODE_DEBUG", "initBarcodeDecoder called. Current isScannerOpen=$isScannerOpen, barcodeDecoder=$barcodeDecoder")
        if (isScannerOpen && barcodeDecoder != null) {
            Log.i("BARCODE_DEBUG", "initBarcodeDecoder: already open, returning true")
            return true
        }
        return try {
            Log.i("BARCODE_DEBUG", "initBarcodeDecoder: calling BarcodeFactory.getInstance()")
            val factory = BarcodeFactory.getInstance()
            Log.i("BARCODE_DEBUG", "initBarcodeDecoder: BarcodeFactory instance = $factory")
            if (factory == null) {
                Log.i("BARCODE_DEBUG", "initBarcodeDecoder: BarcodeFactory is null")
                isScannerOpen = false
                return false
            }
            barcodeDecoder = factory.barcodeDecoder
            Log.i("BARCODE_DEBUG", "initBarcodeDecoder: barcodeDecoder = $barcodeDecoder")
            if (barcodeDecoder == null) {
                Log.i("BARCODE_DEBUG", "initBarcodeDecoder: barcodeDecoder is null")
                isScannerOpen = false
                return false
            }
            Log.i("BARCODE_DEBUG", "initBarcodeDecoder: calling barcodeDecoder.open(applicationContext)...")
            val opened = barcodeDecoder?.open(applicationContext) ?: false
            Log.i("BARCODE_DEBUG", "initBarcodeDecoder: barcodeDecoder.open returned $opened")
            if (opened) {
                isScannerOpen = true
                barcodeDecoder?.setDecodeCallback(object : BarcodeDecoder.DecodeCallback {
                    override fun onDecodeComplete(entity: BarcodeEntity?) {
                        Log.i("BARCODE_DEBUG", "DecodeCallback onDecodeComplete: entity=$entity, code=${entity?.resultCode}, data=${entity?.barcodeData}")
                        if (entity != null && entity.resultCode == BarcodeDecoder.DECODE_SUCCESS) {
                            val data = entity.barcodeData
                            if (!data.isNullOrEmpty()) {
                                onBarcodeReceived(data, "BarcodeDecoderCallback")
                            }
                        }
                    }
                })
                true
            } else {
                isScannerOpen = false
                false
            }
        } catch (e: Throwable) {
            Log.i("BARCODE_DEBUG", "initBarcodeDecoder exception: ${e.message}", e)
            isScannerOpen = false
            false
        }
    }

    private fun closeBarcodeDecoder() {
        Log.i("BARCODE_DEBUG", "closeBarcodeDecoder called, isScannerOpen=$isScannerOpen")
        try {
            if (isScannerOpen) {
                barcodeDecoder?.stopScan()
                barcodeDecoder?.close()
            }
        } catch (e: Throwable) {
            Log.i("BARCODE_DEBUG", "closeBarcodeDecoder error: ${e.message}")
        } finally {
            barcodeDecoder = null
            isScannerOpen = false
        }
    }

    private fun triggerBarcodeScan(): Boolean {
        Log.i("BARCODE_DEBUG", "triggerBarcodeScan called, currentKeyMode=$currentKeyMode, isBurstActive=$isBurstActive")
        if (isBurstActive) {
            Log.i("BARCODE_DEBUG", "triggerBarcodeScan aborted: RFID burst is currently active")
            return false
        }
        isBarcodeScanActive = true
        mainHandler.removeCallbacks(barcodeFallbackRunnable)
        mainHandler.postDelayed(barcodeFallbackRunnable, 3000)

        return try {
            val scanIntent = Intent("com.rscja.scanner.action.BARCODESTARTSCAN")
            sendBroadcast(scanIntent)
            Log.i("BARCODE_DEBUG", "triggerBarcodeScan sent BARCODESTARTSCAN broadcast")
            true
        } catch (e: Exception) {
            Log.e("BARCODE_DEBUG", "triggerBarcodeScan send BARCODESTARTSCAN error: ${e.message}")
            false
        }
    }

    private fun stopBarcodeScan() {
        mainHandler.removeCallbacks(barcodeFallbackRunnable)
        isBarcodeScanActive = false
        try {
            sendBroadcast(Intent("com.rscja.scanner.action.BARCODESTOPSCAN"))
            Log.i("BARCODE_DEBUG", "stopBarcodeScan sent BARCODESTOPSCAN broadcast")
        } catch (e: Exception) {}
        try {
            if (isScannerOpen) {
                barcodeDecoder?.stopScan()
            }
        } catch (e: Exception) {}
    }

    override fun onKeyDown(keyCode: Int, event: KeyEvent?): Boolean {
        val isTriggerKey = (keyCode == 293)
        val isSideKey = (keyCode == 139 || keyCode == 291 || keyCode == 292 || keyCode == 294)
        val isScanKey = isTriggerKey || isSideKey

        Log.d("C72_KEY", "onKeyDown keyCode=$keyCode (isTrigger=$isTriggerKey, isSide=$isSideKey), mode=$currentKeyMode, burstActive=$isBurstActive, barcodeActive=$isBarcodeScanActive, repeat=${event?.repeatCount}")

        if (isScanKey) {
            val repeat = event?.repeatCount ?: 0
            if (repeat > 0 || isScanKeyPressed) {
                Log.d("C72_KEY", "Ignoring repeat onKeyDown keyCode=$keyCode (repeat=$repeat, isScanKeyPressed=$isScanKeyPressed)")
                return true
            }
            isScanKeyPressed = true

            when (currentKeyMode) {
                "rfid" -> {
                    if (isTriggerKey) {
                        if (isBarcodeScanActive) {
                            Log.i("C72_KEY", "Ignoring RFID trigger 293 because barcode scan is active")
                            return true
                        }
                        Log.d("C72_KEY", "Trigger 293 pressed in rfid mode, invoking trigger to Flutter")
                        channel.invokeMethod("onTriggerPressed", null)
                        channel.invokeMethod("trigger", null)
                        return true
                    } else {
                        Log.d("C72_KEY", "Side key $keyCode ignored in rfid mode")
                        return true
                    }
                }
                "barcode" -> {
                    if (isBurstActive) {
                        Log.i("C72_KEY", "Ignoring scan key $keyCode because RFID burst is active")
                        return true
                    }
                    Log.i("BARCODE_DEBUG", "Scan key $keyCode pressed in barcode mode: listening for system scanner broadcast (no BARCODESTARTSCAN sent)")
                    isBarcodeScanActive = true
                    mainHandler.removeCallbacks(barcodeFallbackRunnable)
                    mainHandler.postDelayed(barcodeFallbackRunnable, 3000)
                    return true
                }
                "none" -> {
                    Log.d("C72_KEY", "Scan key $keyCode consumed and ignored in none mode")
                    return true
                }
                else -> {
                    Log.d("C72_KEY", "Scan key $keyCode consumed in mode $currentKeyMode")
                    return true
                }
            }
        }

        channel.invokeMethod("onKeyDown", mapOf("keyCode" to keyCode))
        return super.onKeyDown(keyCode, event)
    }

    override fun onKeyUp(keyCode: Int, event: KeyEvent?): Boolean {
        val isTriggerKey = (keyCode == 293)
        val isSideKey = (keyCode == 139 || keyCode == 291 || keyCode == 292 || keyCode == 294)
        val isScanKey = isTriggerKey || isSideKey

        if (isScanKey) {
            Log.d("C72_KEY", "onKeyUp keyCode=$keyCode, releasing isScanKeyPressed")
            isScanKeyPressed = false
            return true
        }

        return super.onKeyUp(keyCode, event)
    }

    override fun configureFlutterEngine(flutterEngine: FlutterEngine) {
        super.configureFlutterEngine(flutterEngine)
        channel = MethodChannel(flutterEngine.dartExecutor.binaryMessenger, channelName)

        registerScannerReceiver()
        try {
            sendBroadcast(Intent("com.rscja.scanner.action.BARCODELOCKSCANKEY"))
            Log.i("C72_KEY", "configureFlutterEngine: broadcasted BARCODELOCKSCANKEY")
        } catch (e: Exception) {
            Log.e("C72_KEY", "configureFlutterEngine error: ${e.message}")
        }

        Thread {
            Log.i("BARCODE_DEBUG", "Initial probe of initBarcodeDecoder() on app startup...")
            val probeOk = initBarcodeDecoder()
            Log.i("BARCODE_DEBUG", "Startup probe initBarcodeDecoder() returned $probeOk")
        }.start()

        try {
            toneGenerator = ToneGenerator(AudioManager.STREAM_MUSIC, 100)
        } catch (e: Exception) {
            Log.e("RFID_DEBUG", "Audio error: ${e.message}")
        }

        channel.setMethodCallHandler { call, result ->
            when (call.method) {
                "setKeyMode" -> {
                    val mode = when (val args = call.arguments) {
                        is String -> args
                        is Map<*, *> -> args["mode"]?.toString() ?: "none"
                        else -> "none"
                    }.lowercase()
                    currentKeyMode = mode
                    Log.i("C72_KEY", "setKeyMode updated to: $currentKeyMode")
                    if (currentKeyMode != "barcode") {
                        stopBarcodeScan()
                    }
                    result.success(true)
                }

                "initReader" -> {
                    if (isReaderInitialized) {
                        result.success(true)
                        return@setMethodCallHandler
                    }
                    Thread {
                        try {
                            uhf = RFIDWithUHFUART.getInstance()
                            isReaderInitialized = uhf?.init(applicationContext) ?: false
                            if (isReaderInitialized) {
                                uhf?.setInventoryCallback(object : IUHFInventoryCallback {
                                    override fun callback(tagInfo: UHFTAGInfo?) {
                                        if (tagInfo?.epc != null) {
                                            val epcRead = normalizeEpcWithTag(tagInfo)
                                            if (epcRead.isEmpty()) return
                                            val rssiRaw = tagInfo.rssi?.replace(Regex("[^0-9-]"), "") ?: "-100"
                                            var rssiValue = rssiRaw.toDoubleOrNull() ?: -100.0
                                            if (rssiValue < -500 || rssiValue > 500) {
                                                rssiValue /= 100.0
                                            }

                                            if (isBurstActive) {
                                                synchronized(burstLock) {
                                                    val curr = burstTags[epcRead]
                                                    if (curr == null || rssiValue > curr) {
                                                        burstTags[epcRead] = rssiValue
                                                    }
                                                }
                                            }

                                            runOnUiThread {
                                                channel.invokeMethod(
                                                    "onTagRead",
                                                    mapOf(
                                                        "epc" to epcRead,
                                                        "rssi" to rssiValue
                                                    )
                                                )
                                            }

                                            try {
                                                toneGenerator?.startTone(ToneGenerator.TONE_PROP_BEEP, 40)
                                            } catch (e: Exception) {
                                                // ignore audio error
                                            }
                                        }
                                    }
                                })
                                runOnUiThread { result.success(true) }
                            } else {
                                runOnUiThread { result.success(false) }
                            }
                        } catch (e: Exception) {
                            Log.e("RFID_DEBUG", "Init error: ${e.message}")
                            runOnUiThread { result.success(false) }
                        }
                    }.start()
                }

                "freeReader" -> {
                    try {
                        uhf?.stopInventory()
                        if (isReaderInitialized) {
                            uhf?.free()
                            isReaderInitialized = false
                        }
                        result.success(true)
                    } catch (e: Exception) {
                        result.success(false)
                    }
                }

                "openScanner" -> {
                    lastDeliveredBarcode = ""
                    lastDeliveredAt = 0L
                    currentKeyMode = "barcode"
                    registerScannerReceiver()
                    try {
                        val utility = BarcodeUtility.getInstance()
                        utility.setOutputMode(applicationContext, 2)
                        utility.setScanResultBroadcast(
                            applicationContext,
                            "com.rscja.scanner.action.SCAN_RESULT_BROADCAST",
                            "data"
                        )
                    } catch (e: Throwable) {
                        Log.i("BARCODE_DEBUG", "BarcodeUtility note: ${e.message}")
                    }
                    Thread {
                        initBarcodeDecoder()
                    }.start()
                    result.success(true)
                }

                "resetBarcodeDedupe" -> {
                    lastDeliveredBarcode = ""
                    lastDeliveredAt = 0L
                    result.success(true)
                }

                "startScan" -> {
                    Log.i("BARCODE_DEBUG", "MethodChannel startScan called")
                    val started = triggerBarcodeScan()
                    result.success(started)
                }

                "stopScan" -> {
                    Log.i("BARCODE_DEBUG", "MethodChannel stopScan called")
                    stopBarcodeScan()
                    result.success(true)
                }

                "closeScanner" -> {
                    Log.i("BARCODE_DEBUG", "MethodChannel closeScanner called")
                    lastDeliveredBarcode = ""
                    lastDeliveredAt = 0L
                    stopBarcodeScan()
                    closeBarcodeDecoder()
                    result.success(true)
                }

                "setWaitingSku" -> {
                    val waiting = call.arguments as? Boolean ?: false
                    currentKeyMode = if (waiting) "barcode" else "rfid"
                    Log.i("C72_KEY", "setWaitingSku ($waiting) -> currentKeyMode=$currentKeyMode")
                    if (currentKeyMode != "barcode") {
                        stopBarcodeScan()
                    }
                    result.success(true)
                }

                "readBurst" -> {
                    val durationMs = when (val arg = call.arguments) {
                        is Number -> arg.toInt()
                        is Map<*, *> -> (arg["durationMs"] as? Number)?.toInt() ?: 1000
                        else -> 1000
                    }

                    stopBarcodeScan()
                    Thread {
                        try {
                            synchronized(burstLock) {
                                burstTags.clear()
                                isBurstActive = true
                                val sim = simulatedTagEpc
                                if (sim != null) {
                                    burstTags[sim] = -40.0
                                    simulatedTagEpc = null
                                }
                            }

                            val started = uhf?.startInventoryTag() ?: false
                            if (!started) {
                                val collected = synchronized(burstLock) {
                                    isBurstActive = false
                                    burstTags.map { (epc, rssi) ->
                                        mapOf("epc" to epc, "rssi" to rssi)
                                    }
                                }
                                runOnUiThread { result.success(collected) }
                                return@Thread
                            }

                            val startTime = System.currentTimeMillis()
                            while (System.currentTimeMillis() - startTime < durationMs) {
                                synchronized(burstLock) {
                                    val sim = simulatedTagEpc
                                    if (sim != null) {
                                        burstTags[sim] = -40.0
                                        simulatedTagEpc = null
                                    }
                                }
                                val tag = uhf?.readTagFromBuffer()
                                if (tag != null && !tag.epc.isNullOrEmpty()) {
                                    val epcRead = normalizeEpcWithTag(tag)
                                    if (epcRead.isNotEmpty()) {
                                        val rssiRaw = tag.rssi?.replace(Regex("[^0-9-]"), "") ?: "-100"
                                        var rssiValue = rssiRaw.toDoubleOrNull() ?: -100.0
                                        if (rssiValue < -500 || rssiValue > 500) {
                                            rssiValue /= 100.0
                                        }
                                        synchronized(burstLock) {
                                            val curr = burstTags[epcRead]
                                            if (curr == null || rssiValue > curr) {
                                                burstTags[epcRead] = rssiValue
                                            }
                                        }
                                        try {
                                            toneGenerator?.startTone(ToneGenerator.TONE_PROP_BEEP, 40)
                                        } catch (e: Exception) {
                                            // ignore audio error
                                        }
                                    }
                                } else {
                                    Thread.sleep(15)
                                }
                            }

                            uhf?.stopInventory()
                            val collected = synchronized(burstLock) {
                                isBurstActive = false
                                burstTags.map { (epc, rssi) ->
                                    mapOf("epc" to epc, "rssi" to rssi)
                                }
                            }
                            runOnUiThread { result.success(collected) }
                        } catch (e: Exception) {
                            Log.e("RFID_BURST", "Burst error: ${e.message}")
                            try { uhf?.stopInventory() } catch (ignored: Exception) {}
                            synchronized(burstLock) { isBurstActive = false }
                            runOnUiThread { result.error("BURST_ERROR", e.message, null) }
                        }
                    }.start()
                }

                "getPower" -> {
                    result.success(uhf?.power ?: 30)
                }

                "setPower" -> {
                    val power = when (val arg = call.arguments) {
                        is Number -> arg.toInt()
                        is Map<*, *> -> (arg["power"] as? Number)?.toInt() ?: 10
                        else -> 10
                    }
                    result.success(uhf?.setPower(power) ?: false)
                }

                "openAppSettings" -> {
                    try {
                        val intent = android.content.Intent(android.provider.Settings.ACTION_APPLICATION_DETAILS_SETTINGS).apply {
                            data = android.net.Uri.fromParts("package", packageName, null)
                            flags = android.content.Intent.FLAG_ACTIVITY_NEW_TASK
                        }
                        startActivity(intent)
                        result.success(true)
                    } catch (e: Exception) {
                        result.success(false)
                    }
                }

                else -> result.notImplemented()
            }
        }
    }

    override fun onResume() {
        super.onResume()
        isScanKeyPressed = false
        registerScannerReceiver()
        try {
            sendBroadcast(Intent("com.rscja.scanner.action.BARCODELOCKSCANKEY"))
            Log.i("C72_KEY", "onResume: broadcasted BARCODELOCKSCANKEY")
        } catch (e: Exception) {
            Log.e("C72_KEY", "onResume BARCODELOCKSCANKEY error: ${e.message}")
        }
    }

    override fun onPause() {
        isScanKeyPressed = false
        try {
            sendBroadcast(Intent("com.rscja.scanner.action.BARCODEUNLOCKSCANKEY"))
            Log.i("C72_KEY", "onPause: broadcasted BARCODEUNLOCKSCANKEY")
        } catch (e: Exception) {
            Log.e("C72_KEY", "onPause BARCODEUNLOCKSCANKEY error: ${e.message}")
        }
        stopBarcodeScan()
        closeBarcodeDecoder()
        unregisterScannerReceiver()
        super.onPause()
    }

    override fun onDestroy() {
        try {
            sendBroadcast(Intent("com.rscja.scanner.action.BARCODEUNLOCKSCANKEY"))
            Log.i("C72_KEY", "onDestroy: broadcasted BARCODEUNLOCKSCANKEY")
        } catch (e: Exception) {
            Log.e("C72_KEY", "onDestroy BARCODEUNLOCKSCANKEY error: ${e.message}")
        }
        stopBarcodeScan()
        closeBarcodeDecoder()
        unregisterScannerReceiver()
        toneGenerator?.release()
        if (isReaderInitialized) {
            uhf?.free()
        }
        super.onDestroy()
    }
}
