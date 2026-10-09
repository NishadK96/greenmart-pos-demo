package com.eazy.pos

import android.Manifest
import android.bluetooth.BluetoothManager
import android.bluetooth.BluetoothSocket
import android.content.Context
import android.content.pm.PackageManager
import android.os.Build
import io.flutter.embedding.android.FlutterActivity
import io.flutter.embedding.engine.FlutterEngine
import io.flutter.plugin.common.MethodCall
import io.flutter.plugin.common.MethodChannel
import java.util.UUID

class MainActivity : FlutterActivity() {
    private val channelName = "com.eazy.pos/bluetooth_printer"
    private val connectPermissionRequest = 3017
    private val serialPortUuid = UUID.fromString("00001101-0000-1000-8000-00805F9B34FB")
    private var pendingListResult: MethodChannel.Result? = null

    override fun configureFlutterEngine(flutterEngine: FlutterEngine) {
        super.configureFlutterEngine(flutterEngine)
        MethodChannel(flutterEngine.dartExecutor.binaryMessenger, channelName)
            .setMethodCallHandler { call, result ->
                when (call.method) {
                    "listPairedPrinters" -> listPairedPrinters(result)
                    "printBytes" -> printBytes(call, result)
                    else -> result.notImplemented()
                }
            }
    }

    private fun hasConnectPermission(): Boolean =
        Build.VERSION.SDK_INT < Build.VERSION_CODES.S ||
            checkSelfPermission(Manifest.permission.BLUETOOTH_CONNECT) == PackageManager.PERMISSION_GRANTED

    private fun listPairedPrinters(result: MethodChannel.Result) {
        if (!hasConnectPermission()) {
            pendingListResult = result
            requestPermissions(arrayOf(Manifest.permission.BLUETOOTH_CONNECT), connectPermissionRequest)
            return
        }
        try {
            val adapter = (getSystemService(Context.BLUETOOTH_SERVICE) as BluetoothManager).adapter
            if (adapter == null || !adapter.isEnabled) {
                result.error("BLUETOOTH_OFF", "Turn on Bluetooth on this tablet.", null)
                return
            }
            result.success(adapter.bondedDevices.map { device ->
                mapOf("name" to (device.name ?: "Bluetooth printer"), "address" to device.address)
            })
        } catch (error: SecurityException) {
            result.error("BLUETOOTH_PERMISSION", "Allow Nearby devices for Eazy POS.", null)
        }
    }

    private fun printBytes(call: MethodCall, result: MethodChannel.Result) {
        if (!hasConnectPermission()) {
            result.error("BLUETOOTH_PERMISSION", "Allow Nearby devices for Eazy POS in Android Settings.", null)
            return
        }
        val address = call.argument<String>("address")
        val bytes = call.argument<ByteArray>("bytes")
        if (address.isNullOrBlank() || bytes == null || bytes.isEmpty()) {
            result.error("INVALID_PRINT_JOB", "Printer address or receipt data is missing.", null)
            return
        }
        Thread {
            var socket: BluetoothSocket? = null
            try {
                val adapter = (getSystemService(Context.BLUETOOTH_SERVICE) as BluetoothManager).adapter
                    ?: throw IllegalStateException("Bluetooth is not available on this tablet.")
                if (!adapter.isEnabled) throw IllegalStateException("Turn on Bluetooth on this tablet.")
                val device = adapter.bondedDevices.firstOrNull { it.address == address }
                    ?: throw IllegalStateException("Printer is not paired. Pair it in Android Bluetooth settings first.")
                val secureSocket = device.createRfcommSocketToServiceRecord(serialPortUuid)
                try {
                    secureSocket.connect()
                    socket = secureSocket
                } catch (_: Exception) {
                    try { secureSocket.close() } catch (_: Exception) { }
                    val insecureSocket = device.createInsecureRfcommSocketToServiceRecord(serialPortUuid)
                    insecureSocket.connect()
                    socket = insecureSocket
                }
                val connectedSocket = socket ?: throw IllegalStateException("Could not connect to the printer.")
                connectedSocket.outputStream.use { output ->
                    var offset = 0
                    while (offset < bytes.size) {
                        val count = minOf(4096, bytes.size - offset)
                        output.write(bytes, offset, count)
                        output.flush()
                        offset += count
                    }
                }
                runOnUiThread { result.success(true) }
            } catch (error: Exception) {
                runOnUiThread {
                    result.error("BLUETOOTH_PRINT_FAILED", error.message ?: "Could not print over Bluetooth.", null)
                }
            } finally {
                try { socket?.close() } catch (_: Exception) { }
            }
        }.start()
    }

    override fun onRequestPermissionsResult(
        requestCode: Int,
        permissions: Array<out String>,
        grantResults: IntArray,
    ) {
        super.onRequestPermissionsResult(requestCode, permissions, grantResults)
        if (requestCode != connectPermissionRequest) return
        val result = pendingListResult ?: return
        pendingListResult = null
        if (grantResults.firstOrNull() == PackageManager.PERMISSION_GRANTED) {
            listPairedPrinters(result)
        } else {
            result.error("BLUETOOTH_PERMISSION", "Allow Nearby devices to find paired printers.", null)
        }
    }
}
