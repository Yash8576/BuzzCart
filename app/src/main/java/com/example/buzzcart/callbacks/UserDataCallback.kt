package com.example.buzzcart.callbacks

import com.example.buzzcart.models.User

interface UserDataCallback {
    fun onUserDataRead(user: User?)
}
