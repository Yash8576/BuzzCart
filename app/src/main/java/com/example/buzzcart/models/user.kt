package com.example.buzzcart.models

import android.os.Parcelable
import kotlinx.parcelize.Parcelize
import com.google.firebase.database.IgnoreExtraProperties

@Parcelize
@IgnoreExtraProperties
data class User(
    var userId: String = "",
    var fullName: String = "",
    var email: String = "",
    var fullNameLower: String = "",
    var followersCount: Long = 0L,
    var followingCount: Long = 0L,
    var postsCount: Long = 0L,
    var likesReceived: Long = 0L,
    var profileViews: Long = 0L,
    var popularityScore: Double = 0.0,
    var lastActive: Long = 0L,

    // CRITICAL FIX: Use HashMap instead of List to match Firebase structure
    var followers: HashMap<String, String> = HashMap(),
    var following: HashMap<String, String> = HashMap()
) : Parcelable {

    // No-argument constructor required by Firebase
    constructor() : this("", "", "", "", 0L, 0L, 0L, 0L, 0L, 0.0, 0L, HashMap(), HashMap())

    // Helper methods to work with followers/following as lists when needed
    fun getFollowersList(): List<String> {
        return followers.values.toList()
    }

    fun getFollowingList(): List<String> {
        return following.values.toList()
    }

    fun addFollower(followerId: String) {
        val key = System.currentTimeMillis().toString()
        followers[key] = followerId
    }

    fun removeFollower(followerId: String) {
        followers.entries.removeAll { it.value == followerId }
    }

    fun addFollowing(followingId: String) {
        val key = System.currentTimeMillis().toString()
        following[key] = followingId
    }

    fun removeFollowing(followingId: String) {
        following.entries.removeAll { it.value == followingId }
    }
}
