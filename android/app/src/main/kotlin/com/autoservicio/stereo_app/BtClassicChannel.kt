package com.autoservicio.stereo_app

import android.annotation.SuppressLint
import android.bluetooth.BluetoothAdapter
import android.bluetooth.BluetoothManager
import android.bluetooth.BluetoothSocket
import android.content.Context
import android.os.Handler
import android.os.Looper
import io.flutter.plugin.common.BinaryMessenger
import io.flutter.plugin.common.EventChannel
import io.flutter.plugin.common.MethodCall
import io.flutter.plugin.common.MethodChannel
import java.io.IOException
import java.util.UUID
import java.util.concurrent.ExecutorService
import java.util.concurrent.Executors

/**
 * Bluetooth clasico (SPP / RFCOMM) para adaptadores ELM327.
 * Los permisos en tiempo de ejecucion los solicita el lado Dart antes de llamar aqui.
 */
@SuppressLint("MissingPermission")
class BtClassicChannel(context: Context, messenger: BinaryMessenger) :
    MethodChannel.MethodCallHandler, EventChannel.StreamHandler {

    private val adapter: BluetoothAdapter? =
        (context.getSystemService(Context.BLUETOOTH_SERVICE) as? BluetoothManager)?.adapter
    private val methods = MethodChannel(messenger, "stereoapp/bt_classic")
    private val events = EventChannel(messenger, "stereoapp/bt_classic/datos")
    private val main = Handler(Looper.getMainLooper())
    private val io: ExecutorService = Executors.newSingleThreadExecutor()

    @Volatile private var socket: BluetoothSocket? = null
    @Volatile private var sink: EventChannel.EventSink? = null

    init {
        methods.setMethodCallHandler(this)
        events.setStreamHandler(this)
    }

    fun dispose() {
        methods.setMethodCallHandler(null)
        events.setStreamHandler(null)
        cerrar()
        io.shutdownNow()
    }

    override fun onListen(arguments: Any?, eventSink: EventChannel.EventSink?) {
        sink = eventSink
    }

    override fun onCancel(arguments: Any?) {
        sink = null
    }

    override fun onMethodCall(call: MethodCall, result: MethodChannel.Result) {
        when (call.method) {
            "disponible" -> result.success(adapter != null)
            "encendido" -> result.success(adapter?.isEnabled == true)
            "emparejados" -> emparejados(result)
            "conectar" -> conectar(call.argument<String>("direccion") ?: "", result)
            "escribir" -> escribir(call.argument<ByteArray>("datos") ?: ByteArray(0), result)
            "desconectar" -> {
                cerrar()
                result.success(null)
            }
            else -> result.notImplemented()
        }
    }

    private fun emparejados(result: MethodChannel.Result) {
        try {
            val lista = adapter?.bondedDevices.orEmpty().map {
                mapOf("nombre" to (it.name ?: ""), "direccion" to it.address)
            }
            result.success(lista)
        } catch (e: SecurityException) {
            result.error("permiso", "Falta el permiso de Bluetooth", null)
        }
    }

    private fun conectar(direccion: String, result: MethodChannel.Result) {
        val bt = adapter
        if (bt == null || !bt.isEnabled) {
            result.error("apagado", "El Bluetooth esta apagado", null)
            return
        }
        cerrar()
        Thread {
            try {
                val device = bt.getRemoteDevice(direccion)
                bt.cancelDiscovery()
                // Algunos clones de ELM327 solo aceptan el socket inseguro.
                val s = try {
                    device.createRfcommSocketToServiceRecord(SPP).also { it.connect() }
                } catch (e: IOException) {
                    device.createInsecureRfcommSocketToServiceRecord(SPP).also { it.connect() }
                }
                socket = s
                main.post { result.success(null) }
                leer(s)
            } catch (e: Exception) {
                cerrar()
                main.post { result.error("conexion", e.message ?: "No se pudo conectar", null) }
            }
        }.start()
    }

    private fun leer(s: BluetoothSocket) {
        val buffer = ByteArray(1024)
        try {
            val entrada = s.inputStream
            while (true) {
                val n = entrada.read(buffer)
                if (n < 0) break
                val datos = buffer.copyOf(n)
                main.post { sink?.success(datos) }
            }
        } catch (_: IOException) {
        }
        // Solo avisamos si este socket sigue siendo el activo (no fue un cierre pedido).
        if (socket === s) {
            cerrar()
            main.post { sink?.success("desconectado") }
        }
    }

    private fun escribir(datos: ByteArray, result: MethodChannel.Result) {
        val s = socket
        if (s == null) {
            result.error("desconectado", "No hay conexion", null)
            return
        }
        io.execute {
            try {
                s.outputStream.write(datos)
                s.outputStream.flush()
                main.post { result.success(null) }
            } catch (e: IOException) {
                main.post { result.error("escritura", e.message, null) }
            }
        }
    }

    private fun cerrar() {
        val s = socket
        socket = null
        try {
            s?.close()
        } catch (_: IOException) {
        }
    }

    companion object {
        private val SPP: UUID = UUID.fromString("00001101-0000-1000-8000-00805F9B34FB")
    }
}
