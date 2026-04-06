package com.metaglassestest.voice

import com.google.mlkit.vision.barcode.common.Barcode

internal fun barcodeFormatLabel(format: Int): String =
    when (format) {
        Barcode.FORMAT_UNKNOWN -> "Unknown"
        Barcode.FORMAT_CODE_128 -> "Code 128"
        Barcode.FORMAT_CODE_39 -> "Code 39"
        Barcode.FORMAT_CODE_93 -> "Code 93"
        Barcode.FORMAT_CODABAR -> "Codabar"
        Barcode.FORMAT_DATA_MATRIX -> "Data Matrix"
        Barcode.FORMAT_EAN_13 -> "EAN 13"
        Barcode.FORMAT_EAN_8 -> "EAN 8"
        Barcode.FORMAT_ITF -> "ITF"
        Barcode.FORMAT_QR_CODE -> "QR code"
        Barcode.FORMAT_UPC_A -> "UPC A"
        Barcode.FORMAT_UPC_E -> "UPC E"
        Barcode.FORMAT_PDF417 -> "PDF417"
        Barcode.FORMAT_AZTEC -> "Aztec"
        else -> "Barcode"
    }
