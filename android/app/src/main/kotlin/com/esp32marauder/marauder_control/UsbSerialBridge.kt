package com.esp32marauder.marauder_control

import android.app.PendingIntent
import android.content.BroadcastReceiver
import android.content.Context
import android.content.Intent
import android.content.IntentFilter
import android.hardware.usb.UsbDevice
import android.hardware.usb.UsbDeviceConnection
import android.hardware.usb.UsbManager
import android.os.Build
import android.os.Handler
import android.os.Looper
import com.hoho.android.usbserial.driver.UsbSerialPort
import com.hoho.android.usbserial.driver.UsbSerialProber
import com.hoho.android.usbserial.util.SerialInputOutputManager
import io.flutter.embedding.engine.FlutterEngine
import io.flutter.plugin.common.EventChannel
import io.flutter.plugin.common.MethodCall
import io.flutter.plugin.common.MethodChannel
import java.io.IOException

/** Android USB Host transport for CDC/ACM and USB-UART devices including CH340/CH341. */
class UsbSerialBridge(private val context: Context) :
    MethodChannel.MethodCallHandler,
    EventChannel.StreamHandler,
    SerialInputOutputManager.Listener {

    private val usbManager = context.getSystemService(Context.USB_SERVICE) as UsbManager
    private val mainHandler = Handler(Looper.getMainLooper())
    private var eventSink: EventChannel.EventSink? = null
    private var serialPort: UsbSerialPort? = null
    private var connection: UsbDeviceConnection? = null
    private var ioManager: SerialInputOutputManager? = null
    private var pendingBaudRate = DEFAULT_BAUD_RATE
    private var receiverRegistered = false

    private val permissionAction = "${context.packageName}.USB_PERMISSION"
    private val permissionReceiver = object : BroadcastReceiver() {
        override fun onReceive(receiverContext: Context, intent: Intent) {
            if (intent.action != permissionAction) return
            val device = usbDeviceFromIntent(intent) ?: return
            if (intent.getBooleanExtra(UsbManager.EXTRA_PERMISSION_GRANTED, false)) {
                try {
                    openDevice(device, pendingBaudRate)
                } catch (error: Exception) {
                    emitError(error.message ?: "打开串口失败")
                }
            } else {
                emitError("USB 权限被拒绝")
            }
        }
    }

    fun register(engine: FlutterEngine) {
        EventChannel(engine.dartExecutor.binaryMessenger, EVENTS).setStreamHandler(this)
        MethodChannel(engine.dartExecutor.binaryMessenger, METHODS).setMethodCallHandler(this)
    }

    override fun onListen(arguments: Any?, events: EventChannel.EventSink?) {
        eventSink = events
    }

    override fun onCancel(arguments: Any?) {
        eventSink = null
    }

    override fun onMethodCall(call: MethodCall, result: MethodChannel.Result) {
        when (call.method) {
            "listDevices" -> result.success(usbManager.deviceList.values.map(::deviceMap))
            "requestPermission" -> {
                val device = deviceFromCall(call)
                if (device == null) result.error("DEVICE_NOT_FOUND", "USB device not found", null)
                else requestPermission(device, call.argument<Int>("baudRate") ?: DEFAULT_BAUD_RATE, result)
            }
            "connect" -> {
                val device = deviceFromCall(call)
                if (device == null) {
                    result.error("DEVICE_NOT_FOUND", "USB device not found", null)
                } else {
                    connect(device, call.argument<Int>("baudRate") ?: DEFAULT_BAUD_RATE, result)
                }
            }
            "disconnect" -> {
                disconnect("用户断开连接")
                result.success(null)
            }
            "write" -> {
                val bytes = call.arguments as? ByteArray
                if (bytes == null) {
                    result.error("INVALID_DATA", "Expected byte array", null)
                } else {
                    try {
                        val port = serialPort ?: throw IOException("串口未连接")
                        port.write(bytes, WRITE_TIMEOUT_MILLIS)
                        result.success(null)
                    } catch (error: Exception) {
                        result.error("WRITE_FAILED", error.message, null)
                    }
                }
            }
            else -> result.notImplemented()
        }
    }

    private fun connect(device: UsbDevice, baudRate: Int, result: MethodChannel.Result) {
        if (!usbManager.hasPermission(device)) {
            pendingBaudRate = baudRate
            requestPermission(device, baudRate, result)
            return
        }
        try {
            openDevice(device, baudRate)
            result.success(null)
        } catch (error: Exception) {
            disconnect(error.message ?: "打开串口失败")
            result.error("CONNECT_FAILED", error.message, null)
        }
    }

    private fun requestPermission(device: UsbDevice, baudRate: Int, result: MethodChannel.Result) {
        pendingBaudRate = baudRate
        registerPermissionReceiver()
        val flags = if (Build.VERSION.SDK_INT >= Build.VERSION_CODES.M) PendingIntent.FLAG_MUTABLE else 0
        val intent = Intent(permissionAction).setPackage(context.packageName)
        val permissionIntent = PendingIntent.getBroadcast(context, device.deviceId, intent, flags)
        usbManager.requestPermission(device, permissionIntent)
        result.success(mapOf("permissionRequested" to true))
    }

    private fun openDevice(device: UsbDevice, baudRate: Int) {
        val driver = UsbSerialProber.getDefaultProber().probeDevice(device)
            ?: throw IOException("未找到 USB 串口驱动（支持 CH340/CH341、CDC/ACM 等）")
        val port = driver.ports.firstOrNull() ?: throw IOException("USB 设备没有可用串口")
        val usbConnection = usbManager.openDevice(device) ?: throw IOException("无法打开 USB 设备")
        disconnect("切换 USB 设备")
        try {
            port.open(usbConnection)
            port.setParameters(baudRate, UsbSerialPort.DATABITS_8, UsbSerialPort.STOPBITS_1, UsbSerialPort.PARITY_NONE)
        } catch (error: Exception) {
            try { port.close() } catch (_: Exception) { }
            usbConnection.close()
            throw error
        }
        serialPort = port
        connection = usbConnection
        ioManager = SerialInputOutputManager(port, this).also { it.start() }
        mainHandler.post {
            eventSink?.success(mapOf(
                "type" to "connected",
                "driver" to driver.javaClass.simpleName,
                "deviceId" to device.deviceId.toString(),
                "vendorId" to device.vendorId,
                "productId" to device.productId,
                "name" to (device.productName ?: "USB serial device"),
                "baudRate" to baudRate,
            ))
        }
    }

    private fun disconnect(message: String) {
        ioManager?.stop()
        ioManager = null
        try { serialPort?.close() } catch (_: Exception) { }
        serialPort = null
        connection?.close()
        connection = null
        mainHandler.post { eventSink?.success(mapOf("type" to "disconnected", "message" to message)) }
    }

    override fun onNewData(data: ByteArray) {
        mainHandler.post { eventSink?.success(data) }
    }

    override fun onRunError(error: Exception) {
        mainHandler.post {
            eventSink?.success(mapOf("type" to "error", "message" to (error.message ?: "USB 串口读取失败")))
            disconnect("串口读取失败")
        }
    }

    private fun registerPermissionReceiver() {
        if (receiverRegistered) return
        val filter = IntentFilter(permissionAction)
        if (Build.VERSION.SDK_INT >= Build.VERSION_CODES.TIRAMISU) {
            context.registerReceiver(permissionReceiver, filter, Context.RECEIVER_NOT_EXPORTED)
        } else {
            @Suppress("DEPRECATION")
            context.registerReceiver(permissionReceiver, filter)
        }
        receiverRegistered = true
    }

    private fun deviceFromCall(call: MethodCall): UsbDevice? {
        val deviceId = call.argument<String>("deviceId")?.toIntOrNull() ?: return null
        return usbManager.deviceList[deviceId.toString()] ?: usbManager.deviceList.values.firstOrNull { it.deviceId == deviceId }
    }

    private fun usbDeviceFromIntent(intent: Intent): UsbDevice? {
        @Suppress("DEPRECATION")
        return if (Build.VERSION.SDK_INT >= Build.VERSION_CODES.TIRAMISU) {
            intent.getParcelableExtra(UsbManager.EXTRA_DEVICE, UsbDevice::class.java)
        } else {
            intent.getParcelableExtra(UsbManager.EXTRA_DEVICE)
        }
    }

    private fun emitError(message: String) {
        mainHandler.post { eventSink?.success(mapOf("type" to "error", "message" to message)) }
    }

    private fun deviceMap(device: UsbDevice): Map<String, Any?> = mapOf(
        "id" to device.deviceId.toString(),
        "name" to (device.productName ?: "USB serial device"),
        "vendorId" to device.vendorId,
        "productId" to device.productId,
        "manufacturer" to device.manufacturerName,
        "product" to device.productName,
        "serialNumber" to try { device.serialNumber } catch (_: SecurityException) { null },
    )

    companion object {
        const val METHODS = "marauder/usb_serial"
        const val EVENTS = "marauder/usb_serial_events"
        const val DEFAULT_BAUD_RATE = 115200
        const val WRITE_TIMEOUT_MILLIS = 2000
    }
}
