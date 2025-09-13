package com.example.buzzcart.fragments

import android.os.Bundle
import android.util.Log
import android.view.LayoutInflater
import android.view.View
import android.view.ViewGroup
import androidx.fragment.app.Fragment
import com.example.buzzcart.MainActivity
import com.example.buzzcart.R
import com.example.buzzcart.databinding.FragmentHomeBinding
import com.example.buzzcart.models.User
import com.google.firebase.auth.FirebaseAuth
import com.google.firebase.database.DataSnapshot
import com.google.firebase.database.DatabaseError
import com.google.firebase.database.FirebaseDatabase
import com.google.firebase.database.ValueEventListener

class HomeFragment : Fragment() {
    private var _binding: FragmentHomeBinding? = null
    private val binding get() = _binding!!

    override fun onCreateView(
        inflater: LayoutInflater,
        container: ViewGroup?,
        savedInstanceState: Bundle?
    ): View {
        _binding = FragmentHomeBinding.inflate(inflater, container, false)
        return binding.root
    }

    override fun onViewCreated(view: View, savedInstanceState: Bundle?) {
        super.onViewCreated(view, savedInstanceState)

        // Setup home screen
        setupHomeScreen()

        // Load user data and display welcome message
        loadUserData()
    }

    private fun setupHomeScreen() {
        // Setup search button click - using the correct ID from your XML
        binding.searchButton.setOnClickListener {
            val mainActivity = activity as MainActivity
            mainActivity.openSearchFragment()
            Log.d("HomeFragment", "Search button clicked")
        }
    }

    private fun loadUserData() {
        val currentUser = FirebaseAuth.getInstance().currentUser

        if (currentUser != null) {
            // Try to load user data from Firebase Realtime Database
            val database = FirebaseDatabase.getInstance()
            val userRef = database.getReference("users").child(currentUser.uid)

            userRef.addListenerForSingleValueEvent(object : ValueEventListener {
                override fun onDataChange(snapshot: DataSnapshot) {
                    if (_binding == null) return // Fragment destroyed

                    try {
                        // FIXED: Now uses the corrected User model that handles HashMap structure
                        val userData = snapshot.getValue(User::class.java)
                        val displayName = userData?.fullName
                            ?: currentUser.displayName
                            ?: currentUser.email?.substringBefore('@')
                            ?: "User"

                        // Update welcome message using the correct ID from your XML
                        binding.welcomeText.text = "Welcome, $displayName!"

                        Log.d("HomeFragment", "Welcome message set to: Welcome, $displayName!")

                        // Log additional user info if available
                        userData?.let { user ->
                            Log.d("HomeFragment", "User data: ${user.fullName}, Followers: ${user.followersCount}, Following: ${user.followingCount}")
                        }

                    } catch (e: Exception) {
                        Log.e("HomeFragment", "Error deserializing user data", e)
                        handleFallbackName(currentUser)
                    }
                }

                override fun onCancelled(error: DatabaseError) {
                    if (_binding == null) return // Fragment destroyed

                    Log.e("HomeFragment", "Failed to load user data: ${error.message}")
                    handleFallbackName(currentUser)
                }
            })
        } else {
            // No user signed in
            if (_binding != null) {
                binding.welcomeText.text = "Welcome, Guest!"
            }
        }
    }

    private fun handleFallbackName(currentUser: com.google.firebase.auth.FirebaseUser) {
        // Fallback to email or generic message
        val displayName = currentUser.displayName
            ?: currentUser.email?.substringBefore('@')
            ?: "User"

        if (_binding != null) {
            binding.welcomeText.text = "Welcome, $displayName!"
        }
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
        _binding = null
    }
}
