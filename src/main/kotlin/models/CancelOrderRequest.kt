package com.example.models

import com.fasterxml.jackson.dataformat.xml.annotation.JacksonXmlProperty
import com.fasterxml.jackson.dataformat.xml.annotation.JacksonXmlRootElement

@JacksonXmlRootElement(localName = "CancelOrderRequest")
data class CancelOrderRequest(
    @JacksonXmlProperty(localName = "id")
    val id: Int
)