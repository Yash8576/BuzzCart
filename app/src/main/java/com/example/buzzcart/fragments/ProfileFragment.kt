package com.example.buzzcart.fragments

import android.content.Intent
import android.os.Bundle
import android.util.Log
import android.view.LayoutInflater
import android.view.View
import android.view.ViewGroup
import androidx.fragment.app.Fragment
import com.example.buzzcart.LoginActivity
import com.example.buzzcart.MainActivity
import com.example.buzzcart.R
import com.example.buzzcart.databinding.FragmentProfileBinding
import com.google.firebase.auth.FirebaseAuth
import com.google.firebase.database.DataSnapshot
import com.google.firebase.database.DatabaseError
import com.google.firebase.database.FirebaseDatabase
import com.google.firebase.database.ValueEventListener

class ProfileFragment : Fragment() {
    private var _binding: FragmentProfileBinding? = null
    private val binding get() = _binding!!
    private var userStatsListener: ValueEventListener? = null
    private var currentContentFilter = "posts"

    override fun onCreateView(
        inflater: LayoutInflater,
        container: ViewGroup?,
        savedInstanceState: Bundle?
    ): View {
        _binding = FragmentProfileBinding.inflate(inflater, container, false)
        return binding.root
    }

    override fun onViewCreated(view: View, savedInstanceState: Bundle?) {
        super.onViewCreated(view, savedInstanceState)
        setupUI()
        loadUserProfile()
        setupContentFilters()
    }

    private fun setupUI() {
        // Menu button - matches your XML id: menu_button
        binding.menuButton.setOnClickListener {
            val mainActivity = activity as MainActivity
            mainActivity.openMenuFragment()
        }
    }

    private fun setupContentFilters() {
        // Set initial filter
        setActiveContentFilter("posts")
        // Setup filter button clicks - these IDs match your XML
        binding.filterPosts.setOnClickListener {
            setActiveContentFilter("posts")
        }

        binding.filterReels.setOnClickListener {
            setActiveContentFilter("reels")
        }

        binding.filterVideos.setOnClickListener {
            setActiveContentFilter("videos")
        }
    }

    private fun setActiveContentFilter(filter: String) {
        currentContentFilter = filter
        // Reset all filter buttons to outlined style
        binding.filterPosts.setBackgroundResource(R.drawable.filter_button_outlined)
        binding.filterReels.setBackgroundResource(R.drawable.filter_button_outlined)
        binding.filterVideos.setBackgroundResource(R.drawable.filter_button_outlined)
        binding.filterPosts.setTextColor(resources.getColor(android.R.color.black, null))
        binding.filterReels.setTextColor(resources.getColor(android.R.color.black, null))
        binding.filterVideos.setTextColor(resources.getColor(android.R.color.black, null))

        // Set active filter button to filled style
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

        // Update content area
        updateContentArea()
    }

    private fun updateContentArea() {
        when (currentContentFilter) {
            "posts" -> {
                binding.contentTitle.text = "My Posts"
                binding.contentDescription.text = "Your posts will appear here...\n\nShare your thoughts, photos, and updates with your followers!"
            }
            "reels" -> {
                binding.contentTitle.text = "My Reels"
                binding.contentDescription.text = "Your reels will appear here...\n\nCreate engaging short videos to share with your audience!"
            }
            "videos" -> {
                binding.contentTitle.text = "My Videos"
                binding.contentDescription.text = "Your videos will appear here...\n\nUpload longer videos to showcase your content!"
            }
        }
    }

    private fun loadUserProfile() {
        val currentUser = FirebaseAuth.getInstance().currentUser
        if (currentUser == null) {
            // Redirect to login
            startActivity(Intent(requireContext(), LoginActivity::class.java))
            activity?.finish()
            return
        }

        // Set basic user info first
        val mainActivity = activity as MainActivity
        mainActivity.onUserDataReady {
            val userName = mainActivity.getUserFullName()
            binding.profileName.text = userName
            binding.profileTitle.text = "My Profile"

            // IMMEDIATELY set cached values (no loading delay!)
            binding.followersCount.text = formatCount(mainActivity.getCachedFollowersCount())
            binding.followingCount.text = formatCount(mainActivity.getCachedFollowingCount())
            Log.d("ProfileFragment", "Set cached values: followers=${mainActivity.getCachedFollowersCount()}, following=${mainActivity.getCachedFollowingCount()}")

            // THEN setup real-time listener for updates
            setupRealTimeCountsListener(currentUser.uid)
        }
    }

    private fun setupRealTimeCountsListener(userId: String) {
        val database = FirebaseDatabase.getInstance().getReference("users").child(userId)

        // Create real-time listener for follower/following counts
        userStatsListener = object : ValueEventListener {
            override fun onDataChange(snapshot: DataSnapshot) {
                if (_binding == null) return

                // Get real-time counts from Firebase
                val followersCount = snapshot.child("followersCount").getValue(Long::class.java) ?: 0L
                val followingCount = snapshot.child("followingCount").getValue(Long::class.java) ?: 0L

                Log.d("ProfileFragment", "Real-time update - Followers: $followersCount, Following: $followingCount")

                // Update UI with real-time data
                binding.followersCount.text = formatCount(followersCount)
                binding.followingCount.text = formatCount(followingCount)

                // Update cached values in MainActivity
                val mainActivity = activity as? MainActivity
                mainActivity?.updateCachedCounts(followersCount, followingCount)
            }

            override fun onCancelled(error: DatabaseError) {
                Log.e("ProfileFragment", "Failed to load user stats: ${error.message}")
            }
        }

        // Attach listener for real-time updates
        database.addValueEventListener(userStatsListener!!)
    }

    private fun formatCount(count: Long): String {
        return when {
            count >= 1_000_000 -> String.format("%.1fM", count / 1_000_000.0)
            count >= 1_000 -> String.format("%.1fK", count / 1_000.0)
            else -> count.toString()
        }
    }

    override fun onDestroyView() {
        super.onDestroyView()
        // CRITICAL: Remove Firebase listener to prevent memory leaks
        val currentUser = FirebaseAuth.getInstance().currentUser
        if (currentUser != null && userStatsListener != null) {
            FirebaseDatabase.getInstance().getReference("users").child(currentUser.uid)
                .removeEventListener(userStatsListener!!)
        }

        _binding = null
        Log.d("ProfileFragment", "ProfileFragment view destroyed safely")
    }
}
