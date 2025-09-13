package com.example.buzzcart

import android.content.Intent
import android.os.Bundle
import android.util.Log
import androidx.activity.OnBackPressedCallback
import androidx.activity.enableEdgeToEdge
import androidx.appcompat.app.AppCompatActivity
import androidx.core.view.ViewCompat
import androidx.core.view.WindowInsetsCompat
import androidx.core.view.updatePadding
import androidx.fragment.app.Fragment
import androidx.fragment.app.FragmentTransaction
import com.example.buzzcart.databinding.ActivityMainBinding
import com.example.buzzcart.fragments.CartFragment
import com.example.buzzcart.fragments.HomeFragment
import com.example.buzzcart.fragments.MenuFragment
import com.example.buzzcart.fragments.OtherUserProfileFragment
import com.example.buzzcart.fragments.ProductsFragment
import com.example.buzzcart.fragments.ProfileFragment
import com.example.buzzcart.fragments.ReelsFragment
import com.example.buzzcart.fragments.SearchFragment
import com.example.buzzcart.models.User
import com.google.firebase.auth.FirebaseAuth
import com.google.firebase.database.DataSnapshot
import com.google.firebase.database.DatabaseError
import com.google.firebase.database.FirebaseDatabase
import com.google.firebase.database.ValueEventListener

class MainActivity : AppCompatActivity() {
    private lateinit var binding: ActivityMainBinding
    private lateinit var auth: FirebaseAuth
    private var userFullName: String = "User"
    private var isUserDataLoaded = false

    // Cache user stats for immediate loading
    private var cachedFollowersCount: Long = 0L
    private var cachedFollowingCount: Long = 0L

    // Fragment management with preservation
    private val fragmentMap = mutableMapOf<String, Fragment>()
    private var activeFragment: Fragment? = null

    // Stack management for each tab
    private val tabStacks = mutableMapOf<Int, MutableList<String>>()
    private var currentTabId = R.id.nav_home

    // State management
    private var isHomeInSearchMode = false
    private var isProfileInMenuMode = false
    private var savedSearchFilter = "accounts"
    private var savedSearchQuery = ""

    // Back pressed callback handler
    private lateinit var onBackPressedCallback: OnBackPressedCallback

    // Callback for when user data is loaded
    private var onUserDataLoadedCallback: (() -> Unit)? = null

    override fun onCreate(savedInstanceState: Bundle?) {
        super.onCreate(savedInstanceState)
        enableEdgeToEdge()
        binding = ActivityMainBinding.inflate(layoutInflater)
        setContentView(binding.root)
        auth = FirebaseAuth.getInstance()

        // Setup enhanced back press handling
        setupBackPressHandler()

        // Safe area
        ViewCompat.setOnApplyWindowInsetsListener(binding.main) { v, insets ->
            val systemBars = insets.getInsets(WindowInsetsCompat.Type.systemBars())
            v.updatePadding(top = systemBars.top, bottom = systemBars.bottom)
            WindowInsetsCompat.CONSUMED
        }

        // Check if user is logged in
        val currentUser = auth.currentUser
        if (currentUser == null) {
            startActivity(Intent(this, LoginActivity::class.java))
            finish()
            return
        }

        // Initialize tab stacks
        initializeTabStacks()
        // Setup bottom navigation
        setupBottomNavigation()
        // Fetch user's full name BEFORE loading fragments
        fetchUserDataAndInitialize(currentUser.uid, currentUser.email ?: "User")
    }

    private fun initializeTabStacks() {
        tabStacks[R.id.nav_home] = mutableListOf()
        tabStacks[R.id.nav_reels] = mutableListOf()
        tabStacks[R.id.nav_products] = mutableListOf()
        tabStacks[R.id.nav_cart] = mutableListOf()
        tabStacks[R.id.nav_profile] = mutableListOf()
    }

    private fun setupBackPressHandler() {
        onBackPressedCallback = object : OnBackPressedCallback(true) {
            override fun handleOnBackPressed() {
                handleBackNavigation()
            }
        }
        onBackPressedDispatcher.addCallback(this, onBackPressedCallback)
    }

    private fun handleBackNavigation() {
        val currentStack = tabStacks[currentTabId] ?: mutableListOf()
        Log.d("MainActivity", "Back pressed - Current tab: $currentTabId, Stack size: ${currentStack.size}")

        when {
            // If current tab has fragments in stack, pop them
            currentStack.size > 1 -> {
                val currentFragmentTag = currentStack.removeLastOrNull()
                val previousFragmentTag = currentStack.lastOrNull()
                Log.d("MainActivity", "Popping from $currentFragmentTag to $previousFragmentTag")
                if (previousFragmentTag != null) {
                    showFragment(previousFragmentTag)
                }
            }
            // If we're on home and no stack, show exit confirmation
            currentTabId == R.id.nav_home -> {
                showExitConfirmation()
            }
            // Default: go to home tab
            else -> {
                switchToTab(R.id.nav_home)
                binding.bottomNavigation.selectedItemId = R.id.nav_home
            }
        }
    }

    private fun showExitConfirmation() {
        androidx.appcompat.app.AlertDialog.Builder(this)
            .setTitle("Exit App")
            .setMessage("Are you sure you want to exit?")
            .setPositiveButton("Yes") { _, _ ->
                finishAffinity()
            }
            .setNegativeButton("No", null)
            .show()
    }

    private fun fetchUserDataAndInitialize(uid: String, email: String) {
        Log.d("MainActivity", "Fetching user data for UID: $uid")
        FirebaseDatabase.getInstance().getReference("users").child(uid)
            .addListenerForSingleValueEvent(object : ValueEventListener {
                override fun onDataChange(snapshot: DataSnapshot) {
                    // DEBUG: Check what data is actually in Firebase
                    Log.d("MainActivity", "Raw snapshot: ${snapshot.value}")
                    Log.d("MainActivity", "Snapshot exists: ${snapshot.exists()}")
                    val fullName = snapshot.child("fullName").getValue(String::class.java)
                    Log.d("MainActivity", "Full name from DB: $fullName")
                    userFullName = fullName ?: email.split("@")[0]

                    // Cache the counts for immediate loading
                    cachedFollowersCount = snapshot.child("followersCount").getValue(Long::class.java) ?: 0L
                    cachedFollowingCount = snapshot.child("followingCount").getValue(Long::class.java) ?: 0L
                    Log.d("MainActivity", "Cached followers: $cachedFollowersCount, following: $cachedFollowingCount")

                    isUserDataLoaded = true
                    Log.d("MainActivity", "Final userFullName: $userFullName")

                    // Now load the default fragment with correct user data
                    if (fragmentMap.isEmpty()) {
                        switchToTab(R.id.nav_home)
                        binding.bottomNavigation.selectedItemId = R.id.nav_home
                    }

                    // Notify any waiting callbacks
                    onUserDataLoadedCallback?.invoke()
                }

                override fun onCancelled(error: DatabaseError) {
                    Log.e("MainActivity", "Database error: ${error.message}")
                    userFullName = email.split("@")[0]
                    cachedFollowersCount = 0L
                    cachedFollowingCount = 0L
                    isUserDataLoaded = true
                    // Still initialize
                    if (fragmentMap.isEmpty()) {
                        switchToTab(R.id.nav_home)
                        binding.bottomNavigation.selectedItemId = R.id.nav_home
                    }
                    onUserDataLoadedCallback?.invoke()
                }
            })
    }

    private fun setupBottomNavigation() {
        binding.bottomNavigation.setOnItemSelectedListener { item ->
            when (item.itemId) {
                R.id.nav_home -> {
                    handleHomeButtonNavigation()
                }
                R.id.nav_profile -> {
                    handleProfileButtonNavigation()
                }
                else -> {
                    switchToTab(item.itemId)
                }
            }
            true
        }
    }

    private fun handleProfileButtonNavigation() {
        val profileStack = tabStacks[R.id.nav_profile] ?: mutableListOf()
        val topFragment = profileStack.lastOrNull() ?: "profile"

        if (currentTabId == R.id.nav_profile) {
            // Already on profile tab: reset stack and remove menu fragment
            profileStack.clear()
            profileStack.add("profile")

            // Safely remove menu fragment
            val menuFragment = fragmentMap["menu"]
            if (menuFragment != null && menuFragment.isAdded) {
                try {
                    supportFragmentManager.beginTransaction().remove(menuFragment).commitNowAllowingStateLoss()
                } catch (e: Exception) {
                    Log.e("MainActivity", "Error removing menu fragment: ${e.message}")
                }
                fragmentMap.remove("menu")
            }
            isProfileInMenuMode = false
            showFragment("profile")
        } else {
            // From other tab: restore last on profile stack (could be menu or profile)
            currentTabId = R.id.nav_profile
            showFragment(topFragment)
        }
    }

    private fun handleHomeButtonNavigation() {
        val homeStack = tabStacks[R.id.nav_home] ?: mutableListOf()
        val topFragment = homeStack.lastOrNull() ?: "home"

        if (currentTabId == R.id.nav_home) {
            // Already on home tab: reset stack and remove search/user_profile fragments
            homeStack.clear()
            homeStack.add("home")

            // Safely remove fragments
            fragmentMap.keys.filter { it == "search" || it.startsWith("user_profile_") }
                .forEach { key ->
                    val fragment = fragmentMap[key]
                    if (fragment != null && fragment.isAdded) {
                        try {
                            supportFragmentManager.beginTransaction().remove(fragment).commitNowAllowingStateLoss()
                        } catch (e: Exception) {
                            Log.e("MainActivity", "Error removing fragment: ${e.message}")
                        }
                    }
                    fragmentMap.remove(key)
                }
            isHomeInSearchMode = false
            showFragment("home")
        } else {
            // From other tab: restore last on home stack
            currentTabId = R.id.nav_home
            showFragment(topFragment)
        }
    }

    private fun switchToTab(tabId: Int) {
        currentTabId = tabId
        val stack = tabStacks[tabId] ?: mutableListOf()
        val fragmentTag = if (stack.isNotEmpty()) {
            stack.last() // ← Always show whatever is last on the stack for the selected tab
        } else {
            // Create initial fragment for this tab
            val initialTag = getInitialFragmentTag(tabId)
            stack.add(initialTag)
            tabStacks[tabId] = stack
            initialTag
        }
        showFragment(fragmentTag)
    }

    private fun getInitialFragmentTag(tabId: Int): String {
        return when (tabId) {
            R.id.nav_home -> if (isHomeInSearchMode) "search" else "home"
            R.id.nav_reels -> "reels"
            R.id.nav_products -> "products"
            R.id.nav_cart -> "cart"
            R.id.nav_profile -> if (isProfileInMenuMode) "menu" else "profile"
            else -> "home"
        }
    }

    private fun showFragment(tag: String) {
        val transaction = supportFragmentManager.beginTransaction()
        // Hide current active fragment
        activeFragment?.let {
            transaction.hide(it)
            Log.d("MainActivity", "Hiding fragment: ${it.javaClass.simpleName}")
        }

        // Get or create the target fragment
        var targetFragment = fragmentMap[tag]
        if (targetFragment == null) {
            targetFragment = createFragment(tag)
            fragmentMap[tag] = targetFragment
            transaction.add(R.id.fragment_container, targetFragment, tag)
            Log.d("MainActivity", "Created new fragment: $tag")
        } else {
            transaction.show(targetFragment)
            Log.d("MainActivity", "Showing existing fragment: $tag")
        }

        transaction.commit()
        activeFragment = targetFragment
    }

    private fun createFragment(tag: String): Fragment {
        return when (tag) {
            "home" -> HomeFragment()
            "search" -> {
                val searchFragment = SearchFragment()
                searchFragment.setSearchState(savedSearchFilter, savedSearchQuery)
                searchFragment
            }
            "reels" -> ReelsFragment()
            "products" -> ProductsFragment()
            "cart" -> CartFragment()
            "profile" -> ProfileFragment()
            "menu" -> MenuFragment()
            else -> {
                // Handle user profile fragments
                if (tag.startsWith("user_profile_")) {
                    // This should be handled by the fragment navigation method
                    HomeFragment()
                } else {
                    HomeFragment()
                }
            }
        }
    }

    // Method to navigate to user profile (called from SearchFragment)
    fun navigateToUserProfile(user: User) {
        // Remove existing user profile fragments on stack
        val homeStack = tabStacks[R.id.nav_home] ?: mutableListOf()
        homeStack.removeAll { it.startsWith("user_profile_") }

        val profileTag = "user_profile_${user.userId}_${System.currentTimeMillis()}"
        val userProfileFragment = OtherUserProfileFragment.newInstance(user)
        homeStack.add(profileTag)
        fragmentMap[profileTag] = userProfileFragment
        val transaction = supportFragmentManager.beginTransaction()
        activeFragment?.let { transaction.hide(it) }
        transaction.add(R.id.fragment_container, userProfileFragment, profileTag)
        transaction.commit()
        activeFragment = userProfileFragment
        Log.d("MainActivity", "Navigated to user profile: ${user.fullName}, tag: $profileTag")
    }

    // Navigation methods - UPDATED
    fun openSearchFragment() {
        isHomeInSearchMode = true
        val homeStack = tabStacks[R.id.nav_home] ?: mutableListOf()
        // Remove previous search fragment if present
        if (homeStack.contains("search")) {
            homeStack.remove("search")
            if (fragmentMap.containsKey("search")) {
                val fragment = fragmentMap.remove("search")
                supportFragmentManager.beginTransaction().remove(fragment!!).commitNowAllowingStateLoss()
            }
        }
        // Remove any orphan profile fragments above home (optional, for strict reset)
        homeStack.removeAll { it.startsWith("user_profile_") }
        // Clear search state vars as well
        savedSearchFilter = "accounts"
        savedSearchQuery = ""
        homeStack.add("search")
        showFragment("search")
    }

    fun goBackToHome() {
        val currentStack = tabStacks[R.id.nav_home] ?: mutableListOf()
        // Handle the back navigation from search fragment back button
        if (currentStack.size > 1) {
            // Remove the current fragment (search) and show previous
            currentStack.removeLastOrNull()
            val previousTag = currentStack.lastOrNull() ?: "home"

            // If we're going back to home, clear search mode
            if (previousTag == "home") {
                isHomeInSearchMode = false
            }

            showFragment(previousTag)
            Log.d("MainActivity", "Going back from search via back button, showing: $previousTag, stack: $currentStack")
        } else {
            // If only one item in stack, ensure we show home
            isHomeInSearchMode = false
            currentStack.clear()
            currentStack.add("home")
            showFragment("home")
            Log.d("MainActivity", "Reset to home fragment via back button, stack: $currentStack")
        }
        binding.bottomNavigation.selectedItemId = R.id.nav_home
    }

    fun openMenuFragment() {
        isProfileInMenuMode = true
        val currentStack = tabStacks[R.id.nav_profile] ?: mutableListOf()
        if (!currentStack.contains("menu")) {
            currentStack.add("menu")
        }
        showFragment("menu")
        Log.d("MainActivity", "Opened menu fragment, profile stack: $currentStack")
    }

    fun closeMenuFragment() {
        val currentStack = tabStacks[R.id.nav_profile] ?: mutableListOf()
        // Handle the back navigation from menu fragment back button
        if (currentStack.size > 1) {
            // Remove the current fragment (menu) and show previous
            currentStack.removeLastOrNull()
            val previousTag = currentStack.lastOrNull() ?: "profile"

            // If we're going back to profile, clear menu mode
            if (previousTag == "profile") {
                isProfileInMenuMode = false
            }

            showFragment(previousTag)
            Log.d("MainActivity", "Going back from menu via back button, showing: $previousTag, stack: $currentStack")
        } else {
            // If only one item in stack, ensure we show profile
            isProfileInMenuMode = false
            currentStack.clear()
            currentStack.add("profile")
            showFragment("profile")
            Log.d("MainActivity", "Reset to profile fragment via back button, stack: $currentStack")
        }
    }

    // User data methods
    fun getUserFullName(): String = userFullName
    fun isUserDataReady(): Boolean = isUserDataLoaded

    // NEW: Cached data getters for immediate loading
    fun getCachedFollowersCount(): Long = cachedFollowersCount
    fun getCachedFollowingCount(): Long = cachedFollowingCount

    // Update cached counts when they change
    fun updateCachedCounts(followers: Long, following: Long) {
        cachedFollowersCount = followers
        cachedFollowingCount = following
    }

    fun onUserDataReady(callback: () -> Unit) {
        if (isUserDataLoaded) {
            callback()
        } else {
            onUserDataLoadedCallback = callback
        }
    }

    // Search state methods
    fun saveSearchState(filter: String, query: String) {
        savedSearchFilter = filter
        savedSearchQuery = query
        Log.d("MainActivity", "Search state saved: filter=$filter, query=$query")
    }

    fun getSavedSearchFilter(): String = savedSearchFilter
    fun getSavedSearchQuery(): String = savedSearchQuery

    // User interaction tracking
    fun trackUserInteraction(targetUserId: String, interactionType: String = "profile_view") {
        val currentUserId = auth.currentUser?.uid ?: return
        val database = FirebaseDatabase.getInstance()
        val interactionRef = database.getReference("userInteractions")
            .child(currentUserId)
            .child("interactions")
            .child(targetUserId)

        interactionRef.addListenerForSingleValueEvent(object : ValueEventListener {
            override fun onDataChange(snapshot: DataSnapshot) {
                val currentCount = snapshot.getValue(Int::class.java) ?: 0
                interactionRef.setValue(currentCount + 1)
            }

            override fun onCancelled(error: DatabaseError) {
                Log.e("MainActivity", "Failed to track interaction: ${error.message}")
            }
        })
        Log.d("MainActivity", "Tracked interaction: $interactionType with user $targetUserId")
    }

    fun signOutUser() {
        // Clear all fragments and stacks
        fragmentMap.clear()
        tabStacks.clear()
        auth.signOut()
        val intent = Intent(this, LoginActivity::class.java)
        intent.flags = Intent.FLAG_ACTIVITY_NEW_TASK or Intent.FLAG_ACTIVITY_CLEAR_TASK
        startActivity(intent)
        finish()
    }

    override fun onSaveInstanceState(outState: Bundle) {
        super.onSaveInstanceState(outState)
        outState.putString("saved_search_filter", savedSearchFilter)
        outState.putString("saved_search_query", savedSearchQuery)
        outState.putBoolean("is_home_in_search_mode", isHomeInSearchMode)
        outState.putBoolean("is_profile_in_menu_mode", isProfileInMenuMode)
        outState.putInt("current_tab_id", currentTabId)
        outState.putLong("cached_followers", cachedFollowersCount)
        outState.putLong("cached_following", cachedFollowingCount)
    }

    override fun onRestoreInstanceState(savedInstanceState: Bundle) {
        super.onRestoreInstanceState(savedInstanceState)
        savedSearchFilter = savedInstanceState.getString("saved_search_filter", "accounts")
        savedSearchQuery = savedInstanceState.getString("saved_search_query", "")
        isHomeInSearchMode = savedInstanceState.getBoolean("is_home_in_search_mode", false)
        isProfileInMenuMode = savedInstanceState.getBoolean("is_profile_in_menu_mode", false)
        currentTabId = savedInstanceState.getInt("current_tab_id", R.id.nav_home)
        cachedFollowersCount = savedInstanceState.getLong("cached_followers", 0L)
        cachedFollowingCount = savedInstanceState.getLong("cached_following", 0L)
    }

    override fun onDestroy() {
        super.onDestroy()
        fragmentMap.clear()
        tabStacks.clear()
        onBackPressedCallback.remove()
        Log.d("MainActivity", "MainActivity destroyed")
    }

    // Debug method
    fun logCurrentState() {
        Log.d("MainActivity", """
            |=== MainActivity State ===
            |Current Tab: $currentTabId
            |Active Fragment: ${activeFragment?.javaClass?.simpleName}
            |Fragment Map Size: ${fragmentMap.size}
            |Tab Stacks: ${tabStacks.mapValues { it.value.size }}
            |Home in Search Mode: $isHomeInSearchMode
            |Cached Followers: $cachedFollowersCount
            |Cached Following: $cachedFollowingCount
            |=========================
        """.trimMargin())
    }
}
