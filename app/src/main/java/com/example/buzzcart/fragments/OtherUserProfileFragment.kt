package com.example.buzzcart.fragments

import android.os.Bundle
import android.util.Log
import android.view.LayoutInflater
import android.view.View
import android.view.ViewGroup
import android.widget.Toast
import androidx.fragment.app.Fragment
import com.example.buzzcart.MainActivity
import com.example.buzzcart.R
import com.example.buzzcart.databinding.FragmentOtherUserProfileBinding
import com.example.buzzcart.models.User
import com.google.firebase.auth.FirebaseAuth
import com.google.firebase.database.DataSnapshot
import com.google.firebase.database.DatabaseError
import com.google.firebase.database.DatabaseReference
import com.google.firebase.database.FirebaseDatabase
import com.google.firebase.database.MutableData
import com.google.firebase.database.ServerValue
import com.google.firebase.database.Transaction
import com.google.firebase.database.ValueEventListener

class OtherUserProfileFragment : Fragment() {
    private var _binding: FragmentOtherUserProfileBinding? = null
    private val binding get() = _binding!!

    private var currentContentFilter = "posts"
    private var targetUser: User? = null
    private var isFollowing = false
    private var isProcessingFollow = false

    // Store listeners to remove them later
    private var followStateListener: ValueEventListener? = null
    private var userStatsListener: ValueEventListener? = null

    override fun onCreateView(
        inflater: LayoutInflater,
        container: ViewGroup?,
        savedInstanceState: Bundle?
    ): View {
        _binding = FragmentOtherUserProfileBinding.inflate(inflater, container, false)
        return binding.root
    }

    override fun onViewCreated(view: View, savedInstanceState: Bundle?) {
        super.onViewCreated(view, savedInstanceState)

        // Get user data from arguments using Parcelable
        targetUser = arguments?.getParcelable<User>("user")

        if (targetUser == null) {
            Toast.makeText(context, "Error loading user profile", Toast.LENGTH_SHORT).show()
            return
        }

        // Setup profile info
        setupProfileInfo()

        // Setup content filter buttons
        setupContentFilters()

        // Setup back button
        setupBackButton()

        // Setup follow button
        setupFollowButton()

        // Load follow state with real-time updates
        checkFollowState()

        // Initialize with posts filter
        setActiveContentFilter("posts")
        updateContentArea("posts")
    }

    private fun setupProfileInfo() {
        val user = targetUser ?: return

        binding.profileName.text = user.fullName
        binding.profileTitle.text = user.fullName

        // Set initial follow counts
        binding.followersCount.text = formatCount(user.followersCount)
        binding.followingCount.text = formatCount(user.followingCount)

        // Load real-time data with persistent listener
        loadUserStatsRealTime(user.userId)
    }

    private fun loadUserStatsRealTime(userId: String) {
        val database = FirebaseDatabase.getInstance().getReference("users").child(userId)

        // Create real-time listener for follower counts
        userStatsListener = object : ValueEventListener {
            override fun onDataChange(snapshot: DataSnapshot) {
                if (_binding == null) return

                val followersCount = snapshot.child("followersCount").getValue(Long::class.java) ?: 0L
                val followingCount = snapshot.child("followingCount").getValue(Long::class.java) ?: 0L

                Log.d("OtherUserProfile", "Real-time update for ${snapshot.child("fullName").getValue(String::class.java)} - Followers: $followersCount, Following: $followingCount")

                // Update UI with real-time data
                binding.followersCount.text = formatCount(followersCount)
                binding.followingCount.text = formatCount(followingCount)
            }

            override fun onCancelled(error: DatabaseError) {
                Log.e("OtherUserProfile", "Failed to load user stats: ${error.message}")
            }
        }

        // Attach listener for real-time updates
        database.addValueEventListener(userStatsListener!!)
    }


    private fun checkFollowState() {
        val currentUserId = FirebaseAuth.getInstance().currentUser?.uid ?: return
        val targetUserId = targetUser?.userId ?: return

        if (currentUserId == targetUserId) {
            // Hide follow button for own profile
            binding.followButton.visibility = View.GONE
            return
        }

        val database = FirebaseDatabase.getInstance().getReference("users")
            .child(currentUserId)
            .child("following")

        // Create real-time listener for follow state
        followStateListener = object : ValueEventListener {
            override fun onDataChange(snapshot: DataSnapshot) {
                isFollowing = false

                for (child in snapshot.children) {
                    if (child.value == targetUserId) {
                        isFollowing = true
                        break
                    }
                }

                updateFollowButton()
            }

            override fun onCancelled(error: DatabaseError) {
                Log.e("OtherUserProfile", "Failed to check follow state: ${error.message}")
            }
        }

        // Attach listener for real-time follow state updates
        database.addValueEventListener(followStateListener!!)
    }

    private fun updateFollowButton() {
        if (isFollowing) {
            binding.followButton.text = "Unfollow"
            binding.followButton.setBackgroundColor(resources.getColor(android.R.color.darker_gray, null))
        } else {
            binding.followButton.text = "Follow"
            binding.followButton.setBackgroundColor(resources.getColor(android.R.color.holo_blue_light, null))
        }
    }

    private fun setupFollowButton() {
        binding.followButton.setOnClickListener {
            if (isProcessingFollow) return@setOnClickListener

            if (isFollowing) {
                unfollowUser()
            } else {
                followUser()
            }
        }
    }

    private fun followUser() {
        val currentUserId = FirebaseAuth.getInstance().currentUser?.uid ?: return
        val targetUserId = targetUser?.userId ?: return

        isProcessingFollow = true
        binding.followButton.isEnabled = false
        binding.followButton.text = "Following..."

        val database = FirebaseDatabase.getInstance()

        var operationsCompleted = 0
        val totalOperations = 4
        var hasErrors = false

        val checkCompletion = {
            operationsCompleted++
            if (operationsCompleted >= totalOperations) {
                isProcessingFollow = false
                binding.followButton.isEnabled = true
                if (hasErrors) {
                    Toast.makeText(context, "Some operations failed", Toast.LENGTH_SHORT).show()
                }
            }
        }

        // FIXED: Correct database paths
        // Operation 1: Add to current user's following list
        database.getReference("users").child(currentUserId).child("following")
            .push().setValue(targetUserId)
            .addOnSuccessListener {
                Log.d("OtherUserProfile", "✅ Added to following list")
                checkCompletion()
            }
            .addOnFailureListener { exception ->
                Log.e("OtherUserProfile", "❌ Failed to add to following list", exception)
                hasErrors = true
                checkCompletion()
            }

        // Operation 2: Add to target user's followers list
        database.getReference("users").child(targetUserId).child("followers")
            .push().setValue(currentUserId)
            .addOnSuccessListener {
                Log.d("OtherUserProfile", "✅ Added to followers list")
                checkCompletion()
            }
            .addOnFailureListener { exception ->
                Log.e("OtherUserProfile", "❌ Failed to add to followers list", exception)
                hasErrors = true
                checkCompletion()
            }

        // Operation 3: Increment current user's following count
        database.getReference("users").child(currentUserId).child("followingCount")
            .runTransaction(object : Transaction.Handler {
                override fun doTransaction(mutableData: MutableData): Transaction.Result {
                    val currentValue = mutableData.getValue(Long::class.java) ?: 0L
                    mutableData.value = currentValue + 1
                    Log.d("OtherUserProfile", "Incrementing following count: $currentValue -> ${currentValue + 1}")
                    return Transaction.success(mutableData)
                }

                override fun onComplete(error: DatabaseError?, committed: Boolean, currentData: DataSnapshot?) {
                    if (committed) {
                        Log.d("OtherUserProfile", "✅ Following count incremented successfully")
                    } else {
                        Log.e("OtherUserProfile", "❌ Failed to increment following count", error?.toException())
                        hasErrors = true
                    }
                    checkCompletion()
                }
            })

        // Operation 4: Increment target user's followers count
        database.getReference("users").child(targetUserId).child("followersCount")
            .runTransaction(object : Transaction.Handler {
                override fun doTransaction(mutableData: MutableData): Transaction.Result {
                    val currentValue = mutableData.getValue(Long::class.java) ?: 0L
                    mutableData.value = currentValue + 1
                    Log.d("OtherUserProfile", "Incrementing followers count: $currentValue -> ${currentValue + 1}")
                    return Transaction.success(mutableData)
                }

                override fun onComplete(error: DatabaseError?, committed: Boolean, currentData: DataSnapshot?) {
                    if (committed) {
                        Log.d("OtherUserProfile", "✅ Followers count incremented successfully")
                    } else {
                        Log.e("OtherUserProfile", "❌ Failed to increment followers count", error?.toException())
                        hasErrors = true
                    }
                    checkCompletion()
                }
            })
    }


    private fun unfollowUser() {
        val currentUserId = FirebaseAuth.getInstance().currentUser?.uid ?: return
        val targetUserId = targetUser?.userId ?: return

        isProcessingFollow = true
        binding.followButton.isEnabled = false
        binding.followButton.text = "Unfollowing..."

        val database = FirebaseDatabase.getInstance()

        var operationsCompleted = 0
        val totalOperations = 4
        var hasErrors = false

        val checkCompletion = {
            operationsCompleted++
            Log.d("OtherUserProfile", "Unfollow operation completed: $operationsCompleted/$totalOperations, hasErrors: $hasErrors")

            if (operationsCompleted >= totalOperations) {
                isProcessingFollow = false
                binding.followButton.isEnabled = true

                if (!hasErrors) {
                    Log.d("OtherUserProfile", "✅ Successfully unfollowed user")
                } else {
                    Toast.makeText(context, "Some operations failed", Toast.LENGTH_SHORT).show()
                    Log.e("OtherUserProfile", "❌ Some unfollow operations failed")
                }
            }
        }

        // Operation 1: Remove from current user's following list
        database.getReference("users").child(currentUserId).child("following")
            .addListenerForSingleValueEvent(object : ValueEventListener {
                override fun onDataChange(snapshot: DataSnapshot) {
                    var found = false
                    for (child in snapshot.children) {
                        if (child.value == targetUserId) {
                            child.ref.removeValue()
                                .addOnSuccessListener {
                                    Log.d("OtherUserProfile", "✅ Removed from following list")
                                    checkCompletion()
                                }
                                .addOnFailureListener { exception ->
                                    Log.e("OtherUserProfile", "❌ Failed to remove from following", exception)
                                    hasErrors = true
                                    checkCompletion()
                                }
                            found = true
                            break
                        }
                    }
                    if (!found) {
                        Log.w("OtherUserProfile", "⚠️ User not found in following list")
                        checkCompletion()
                    }
                }

                override fun onCancelled(error: DatabaseError) {
                    Log.e("OtherUserProfile", "❌ Failed to read following list", error.toException())
                    hasErrors = true
                    checkCompletion()
                }
            })

        // Operation 2: Remove from target user's followers list
        database.getReference("users").child(targetUserId).child("followers")
            .addListenerForSingleValueEvent(object : ValueEventListener {
                override fun onDataChange(snapshot: DataSnapshot) {
                    var found = false
                    for (child in snapshot.children) {
                        if (child.value == currentUserId) {
                            child.ref.removeValue()
                                .addOnSuccessListener {
                                    Log.d("OtherUserProfile", "✅ Removed from followers list")
                                    checkCompletion()
                                }
                                .addOnFailureListener { exception ->
                                    Log.e("OtherUserProfile", "❌ Failed to remove from followers", exception)
                                    hasErrors = true
                                    checkCompletion()
                                }
                            found = true
                            break
                        }
                    }
                    if (!found) {
                        Log.w("OtherUserProfile", "⚠️ User not found in followers list")
                        checkCompletion()
                    }
                }

                override fun onCancelled(error: DatabaseError) {
                    Log.e("OtherUserProfile", "❌ Failed to read followers list", error.toException())
                    hasErrors = true
                    checkCompletion()
                }
            })

        // Operation 3: Atomic decrement current user's following count (prevents negative values)
        database.getReference("users").child(currentUserId).child("followingCount")
            .runTransaction(object : Transaction.Handler {
                override fun doTransaction(mutableData: MutableData): Transaction.Result {
                    val currentValue = mutableData.getValue(Long::class.java) ?: 0L
                    val newValue = if (currentValue > 0) currentValue - 1 else 0L
                    mutableData.value = newValue
                    Log.d("OtherUserProfile", "Decrementing following count: $currentValue -> $newValue")
                    return Transaction.success(mutableData)
                }

                override fun onComplete(
                    error: DatabaseError?,
                    committed: Boolean,
                    currentData: DataSnapshot?
                ) {
                    if (committed) {
                        Log.d("OtherUserProfile", "✅ Following count decremented successfully")
                    } else {
                        Log.e("OtherUserProfile", "❌ Failed to decrement following count", error?.toException())
                        hasErrors = true
                    }
                    checkCompletion()
                }
            })

        // Operation 4: Atomic decrement target user's followers count (prevents negative values)
        database.getReference("users").child(targetUserId).child("followersCount")
            .runTransaction(object : Transaction.Handler {
                override fun doTransaction(mutableData: MutableData): Transaction.Result {
                    val currentValue = mutableData.getValue(Long::class.java) ?: 0L
                    val newValue = if (currentValue > 0) currentValue - 1 else 0L
                    mutableData.value = newValue
                    Log.d("OtherUserProfile", "Decrementing followers count: $currentValue -> $newValue")
                    return Transaction.success(mutableData)
                }

                override fun onComplete(
                    error: DatabaseError?,
                    committed: Boolean,
                    currentData: DataSnapshot?
                ) {
                    if (committed) {
                        Log.d("OtherUserProfile", "✅ Followers count decremented successfully")
                    } else {
                        Log.e("OtherUserProfile", "❌ Failed to decrement followers count", error?.toException())
                        hasErrors = true
                        Toast.makeText(context, "Failed to update follower count", Toast.LENGTH_SHORT).show()
                    }
                    checkCompletion()
                }
            })
    }

    private fun formatCount(count: Long): String {
        return when {
            count >= 1_000_000 -> String.format("%.1fM", count / 1_000_000.0)
            count >= 1_000 -> String.format("%.1fK", count / 1_000.0)
            else -> count.toString()
        }
    }

    private fun setupBackButton() {
        binding.backButton.setOnClickListener {
            // Safe back navigation
            if (parentFragmentManager.backStackEntryCount > 0) {
                parentFragmentManager.popBackStack()
            } else {
                // Fall back to main activity if no back stack
                activity?.onBackPressed()
            }
        }
    }

    private fun setupContentFilters() {
        binding.filterPosts.setOnClickListener {
            setActiveContentFilter("posts")
            updateContentArea("posts")
        }

        binding.filterReels.setOnClickListener {
            setActiveContentFilter("reels")
            updateContentArea("reels")
        }

        binding.filterVideos.setOnClickListener {
            setActiveContentFilter("videos")
            updateContentArea("videos")
        }
    }

    private fun setActiveContentFilter(filter: String) {
        currentContentFilter = filter

        // Reset all buttons to outlined style
        binding.filterPosts.setBackgroundResource(R.drawable.filter_button_outlined)
        binding.filterReels.setBackgroundResource(R.drawable.filter_button_outlined)
        binding.filterVideos.setBackgroundResource(R.drawable.filter_button_outlined)

        // Reset text colors
        binding.filterPosts.setTextColor(resources.getColor(android.R.color.black, null))
        binding.filterReels.setTextColor(resources.getColor(android.R.color.black, null))
        binding.filterVideos.setTextColor(resources.getColor(android.R.color.black, null))

        // Set active button to filled style
        when (filter) {
            "posts" -> {
                binding.filterPosts.setBackgroundResource(R.drawable.filter_button_filled)
                binding.filterPosts.setTextColor(resources.getColor(android.R.color.white, null))
            }
            "reels" -> {
                binding.filterReels.setBackgroundResource(R.drawable.filter_button_filled)
                binding.filterReels.setTextColor(resources.getColor(android.R.color.white, null))
            }
            "videos" -> {
                binding.filterVideos.setBackgroundResource(R.drawable.filter_button_filled)
                binding.filterVideos.setTextColor(resources.getColor(android.R.color.white, null))
            }
        }
    }

    private fun updateContentArea(filter: String) {
        val userName = targetUser?.fullName ?: "User"
        binding.contentTitle.text = "${userName}'s ${filter.replaceFirstChar { it.uppercase() }}"

        val content = when (filter) {
            "posts" -> "${userName}'s posts will appear here..."
            "reels" -> "${userName}'s reels will appear here..."
            "videos" -> "${userName}'s videos will appear here..."
            else -> "Content will appear here..."
        }

        binding.contentDescription.text = content
    }

    companion object {
        fun newInstance(user: User): OtherUserProfileFragment {
            val fragment = OtherUserProfileFragment()
            val args = Bundle().apply {
                putParcelable("user", user)
            }
            fragment.arguments = args
            return fragment
        }
    }

    override fun onDestroyView() {
        super.onDestroyView()

        // Remove Firebase listeners to prevent memory leaks
        val database = FirebaseDatabase.getInstance()
        val targetUserId = targetUser?.userId
        val currentUserId = FirebaseAuth.getInstance().currentUser?.uid

        if (targetUserId != null && userStatsListener != null) {
            database.getReference("users").child(targetUserId)
                .removeEventListener(userStatsListener!!)
        }

        if (currentUserId != null && targetUserId != null && followStateListener != null) {
            database.getReference("users").child(currentUserId).child("following")
                .removeEventListener(followStateListener!!)
        }

        _binding = null
    }
}
