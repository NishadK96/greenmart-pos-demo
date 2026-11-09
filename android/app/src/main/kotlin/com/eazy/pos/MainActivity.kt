package com.eazy.pos

import android.Manifest
import android.app.PendingIntent
import android.bluetooth.BluetoothClass
import android.bluetooth.BluetoothManager
import android.bluetooth.BluetoothSocket
import android.content.BroadcastReceiver
import android.content.Context
import android.content.Intent
import android.content.IntentFilter
import android.content.pm.PackageManager
import android.hardware.usb.UsbConstants
import android.hardware.usb.UsbDevice
import android.hardware.usb.UsbEndpoint
import android.hardware.usb.UsbInterface
import android.hardware.usb.UsbManager
import android.os.Build
import io.flutter.embedding.android.FlutterActivity
import io.flutter.embedding.engine.FlutterEngine
import io.flutter.plugin.common.MethodCall
import io.flutter.plugin.common.MethodChannel
import java.util.UUID

class MainActivity : FlutterActivity() {
    private val channelName = "com.eazy.pos/bluetooth_printer"
    private val usbPermissionAction = "com.eazy.pos.USB_PRINTER_PERMISSION"
    private val connectPermissionRequest = 3017
    private val serialPortUuid = UUID.fromString("00001101-0000-1000-8000-00805F9B34FB")
    private var pendingListResult: MethodChannel.Result? = null
    private var pendingUsbPrint: PendingUsbPrint? = null
    private var usbReceiverRegistered = false

    private data class PendingUsbPrint(
        val deviceId: Int,
        val bytes: ByteArray,
        val result: MethodChannel.Result,
    )

    private val usbPermissionReceiver = object : BroadcastReceiver() {
        override fun onReceive(context: Context?, intent: Intent?) {
            if (intent?.action != usbPermissionAction) return
            val pending = pendingUsbPrint ?: return
            val device = usbDeviceFrom(intent)
            if (device == null || device.deviceId != pending.deviceId) return
            pendingUsbPrint = null
            if (intent.getBooleanExtra(UsbManager.EXTRA_PERMISSION_GRANTED, false)) {
                writeUsb(device, pending.bytes, pending.result)
            } else {
                pending.result.error(
                    "USB_PERMISSION",
                    "Allow Eazy POS to access the USB printer, then try again.",
                    null,
                )
            }
        }
    }

    override fun configureFlutterEngine(flutterEngine: FlutterEngine) {
        super.configureFlutterEngine(flutterEngine)
        registerUsbPermissionReceiver()
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
            val bluetooth = adapter.bondedDevices
                .filter { it.bluetoothClass?.majorDeviceClass != BluetoothClass.Device.Major.AUDIO_VIDEO }
                .map { device ->
                    mapOf(
                        "transport" to "bluetooth",
                        "name" to (device.name ?: "Bluetooth printer"),
                        "address" to device.address,
                    )
                }
            val usb = usbPrinterDevices().map { device ->
                mapOf(
                    "transport" to "usb",
                    "name" to usbPrinterName(device),
                    // Android's deviceId is temporary and changes after a USB
                    // reconnect. Persist hardware IDs so saved routes survive.
                    "address" to usbPrinterAddress(device),
                )
            }
            result.success(usb + bluetooth)
        } catch (error: SecurityException) {
            result.error("BLUETOOTH_PERMISSION", "Allow Nearby devices for Eazy POS.", null)
        }
    }

    private fun printBytes(call: MethodCall, result: MethodChannel.Result) {
        val transport = call.argument<String>("transport") ?: "bluetooth"
        if (transport == "usb") {
            printUsb(call, result)
            return
        }
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

    private fun printUsb(call: MethodCall, result: MethodChannel.Result) {
        val address = call.argument<String>("address")
        val bytes = call.argument<ByteArray>("bytes")
        if (address.isNullOrBlank() || bytes == null || bytes.isEmpty()) {
            result.error("INVALID_PRINT_JOB", "USB printer or receipt data is missing.", null)
            return
        }
        val manager = getSystemService(Context.USB_SERVICE) as UsbManager
        val legacyDeviceId = address.toIntOrNull()
        val printers = manager.deviceList.values.filter { printerEndpoint(it) != null }
        val exactDevice = printers.firstOrNull {
            if (legacyDeviceId != null) it.deviceId == legacyDeviceId
            else usbPrinterAddress(it) == address
        }
        // Routes created by older releases contain Android's temporary
        // deviceId. It changes after reconnect/reboot. If there is only one
        // actual USB printer attached, safely recover that stale route.
        val device = exactDevice ?: printers.singleOrNull()
        if (device == null || printerEndpoint(device) == null) {
            result.error(
                "USB_PRINTER_NOT_FOUND",
                "The USB printer was disconnected. Reconnect it, scan again, and retry.",
                null,
            )
            return
        }
        if (manager.hasPermission(device)) {
            writeUsb(device, bytes, result)
            return
        }
        if (pendingUsbPrint != null) {
            result.error("USB_PRINT_BUSY", "Another USB printer permission request is active.", null)
            return
        }
        pendingUsbPrint = PendingUsbPrint(device.deviceId, bytes, result)
        val permissionIntent = PendingIntent.getBroadcast(
            this,
            device.deviceId,
            Intent(usbPermissionAction).setPackage(packageName),
            PendingIntent.FLAG_UPDATE_CURRENT or PendingIntent.FLAG_MUTABLE,
        )
        manager.requestPermission(device, permissionIntent)
    }

    private fun writeUsb(device: UsbDevice, bytes: ByteArray, result: MethodChannel.Result) {
        Thread {
            val manager = getSystemService(Context.USB_SERVICE) as UsbManager
            val target = printerEndpoint(device)
            if (target == null) {
                runOnUiThread {
                    result.error("USB_PRINTER_NOT_FOUND", "No writable USB printer endpoint was found.", null)
                }
                return@Thread
            }
            val (usbInterface, endpoint) = target
            val connection = manager.openDevice(device)
            if (connection == null) {
                runOnUiThread {
                    result.error("USB_OPEN_FAILED", "Could not open the USB printer.", null)
                }
                return@Thread
            }
            try {
                if (!connection.claimInterface(usbInterface, true)) {
                    throw IllegalStateException("Could not claim the USB printer interface.")
                }
                var offset = 0
                while (offset < bytes.size) {
                    // Low-cost ESC/POS printers have small input buffers. Use
                    // conservative packets and briefly retry when the device
                    // applies back-pressure instead of aborting the receipt.
                    val count = minOf(2 * 1024, bytes.size - offset)
                    val chunk = bytes.copyOfRange(offset, offset + count)
                    var written = -1
                    for (attempt in 0 until 4) {
                        written = connection.bulkTransfer(endpoint, chunk, chunk.size, 10_000)
                        if (written > 0) break
                        Thread.sleep(60L * (attempt + 1))
                    }
                    if (written <= 0) {
                        throw IllegalStateException("USB printer stopped accepting receipt data.")
                    }
                    offset += written
                    Thread.sleep(8)
                }
                runOnUiThread { result.success(true) }
            } catch (error: Exception) {
                runOnUiThread {
                    result.error(
                        "USB_PRINT_FAILED",
                        error.message ?: "Could not print over USB.",
                        null,
                    )
                }
            } finally {
                try { connection.releaseInterface(usbInterface) } catch (_: Exception) { }
                connection.close()
            }
        }.start()
    }

    private fun usbPrinterDevices(): List<UsbDevice> {
        val manager = getSystemService(Context.USB_SERVICE) as UsbManager
        return manager.deviceList.values.filter { printerEndpoint(it) != null }
    }

    private fun printerEndpoint(device: UsbDevice): Pair<UsbInterface, UsbEndpoint>? {
        var fallback: Pair<UsbInterface, UsbEndpoint>? = null
        for (interfaceIndex in 0 until device.interfaceCount) {
            val usbInterface = device.getInterface(interfaceIndex)
            for (endpointIndex in 0 until usbInterface.endpointCount) {
                val endpoint = usbInterface.getEndpoint(endpointIndex)
                if (endpoint.direction != UsbConstants.USB_DIR_OUT ||
                    endpoint.type != UsbConstants.USB_ENDPOINT_XFER_BULK) continue
                val candidate = usbInterface to endpoint
                if (usbInterface.interfaceClass == UsbConstants.USB_CLASS_PRINTER) return candidate
                fallback ?: run { fallback = candidate }
            }
        }
        return fallback
    }

    private fun usbPrinterName(device: UsbDevice): String {
        val product = try { device.productName } catch (_: SecurityException) { null }
        val manufacturer = try { device.manufacturerName } catch (_: SecurityException) { null }
        return listOfNotNull(manufacturer, product)
            .map { it.trim() }
            .filter { it.isNotEmpty() }
            .distinct()
            .joinToString(" ")
            .ifEmpty { "USB thermal printer" }
    }

    private fun usbPrinterAddress(device: UsbDevice): String =
        "${device.vendorId}:${device.productId}"

    @Suppress("DEPRECATION")
    private fun usbDeviceFrom(intent: Intent): UsbDevice? =
        if (Build.VERSION.SDK_INT >= Build.VERSION_CODES.TIRAMISU) {
            intent.getParcelableExtra(UsbManager.EXTRA_DEVICE, UsbDevice::class.java)
        } else {
            intent.getParcelableExtra(UsbManager.EXTRA_DEVICE)
        }

    private fun registerUsbPermissionReceiver() {
        if (usbReceiverRegistered) return
        val filter = IntentFilter(usbPermissionAction)
        if (Build.VERSION.SDK_INT >= Build.VERSION_CODES.TIRAMISU) {
            registerReceiver(usbPermissionReceiver, filter, Context.RECEIVER_NOT_EXPORTED)
        } else {
            @Suppress("DEPRECATION")
            registerReceiver(usbPermissionReceiver, filter)
        }
        usbReceiverRegistered = true
    }

    override fun onDestroy() {
        if (usbReceiverRegistered) {
            unregisterReceiver(usbPermissionReceiver)
            usbReceiverRegistered = false
        }
        pendingUsbPrint?.result?.error("USB_PRINT_CANCELLED", "USB print was cancelled.", null)
        pendingUsbPrint = null
        super.onDestroy()
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
