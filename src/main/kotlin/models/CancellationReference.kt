package com.example.models

data class CancellationReference(
    val reference: Int,
    val status: String // Either "COMPLETED" or "FAILED"
)