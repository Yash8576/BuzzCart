package com.example.buzzcart.models

data class UserInteraction(
    val targetUserId: String = "",
    val interactionCount: Int = 0,
    val lastInteraction: Long = 0
)
