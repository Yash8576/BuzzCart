package com.example.buzzcart.fragments

import android.os.Bundle
import android.text.Editable
import android.text.TextWatcher
import android.util.Log
import android.view.LayoutInflater
import android.view.View
import android.view.ViewGroup
import androidx.fragment.app.Fragment
import androidx.recyclerview.widget.LinearLayoutManager
import com.example.buzzcart.MainActivity
import com.example.buzzcart.R
import com.example.buzzcart.adapters.SearchAdapter
import com.example.buzzcart.databinding.FragmentSearchBinding
import com.example.buzzcart.models.User
import com.google.firebase.database.DataSnapshot
import com.google.firebase.database.DatabaseError
import com.google.firebase.database.FirebaseDatabase
import com.google.firebase.database.ValueEventListener
import java.util.Locale

class SearchFragment : Fragment() {
    private var _binding: FragmentSearchBinding? = null
    private val binding get() = _binding!!

    private var isFragmentActive = false
    private var currentFilter = "accounts"
    private var currentQuery = ""

    // Search results management
    private lateinit var searchAdapter: SearchAdapter
    private val searchResults = mutableListOf<User>()
    private var searchListener: ValueEventListener? = null

    override fun onCreateView(
        inflater: LayoutInflater,
        container: ViewGroup?,
        savedInstanceState: Bundle?
    ): View {
        _binding = FragmentSearchBinding.inflate(inflater, container, false)
        isFragmentActive = true
        return binding.root
    }

    override fun onViewCreated(view: View, savedInstanceState: Bundle?) {
        super.onViewCreated(view, savedInstanceState)

        // Setup UI components
        setupSearchUI()
        setupRecyclerView()
        setupFilters()

        // Load saved state if available
        restoreSearchState()

        // Setup back navigation
        setupBackButton()
    }

    private fun setupSearchUI() {
        // Setup search input with text watcher using your exact ID: search_edit_text
        binding.searchEditText.addTextChangedListener(object : TextWatcher {
            override fun beforeTextChanged(s: CharSequence?, start: Int, count: Int, after: Int) {}
            override fun onTextChanged(s: CharSequence?, start: Int, before: Int, count: Int) {}

            override fun afterTextChanged(s: Editable?) {
                val query = s?.toString() ?: ""
                currentQuery = query

                // Save search state
                saveSearchState()

                // Perform search
                performSearch(query)
            }
        })
    }

    private fun setupRecyclerView() {
        searchAdapter = SearchAdapter(searchResults) { user ->
            // Handle user item click - navigate to user profile
            val mainActivity = activity as MainActivity
            mainActivity.navigateToUserProfile(user)
            mainActivity.trackUserInteraction(user.userId, "search_profile_click")
        }

        // Using your exact ID: search_results_recycler_view
        binding.searchResultsRecyclerView.apply {
            layoutManager = LinearLayoutManager(context)
            adapter = searchAdapter
        }
    }

    private fun setupFilters() {
        // Set initial filter
        setActiveFilter(currentFilter)

        // Setup filter button clicks using your exact IDs
        binding.filterAccounts.setOnClickListener {
            setActiveFilter("accounts")
            performSearch(currentQuery)
        }

        binding.filterSellers.setOnClickListener {
            setActiveFilter("sellers")
            performSearch(currentQuery)
        }

        binding.filterReels.setOnClickListener {
            setActiveFilter("reels")
            performSearch(currentQuery)
        }

        binding.filterProducts.setOnClickListener {
            setActiveFilter("products")
            performSearch(currentQuery)
        }
    }

    private fun setActiveFilter(filter: String) {
        currentFilter = filter

        // Save search state
        saveSearchState()

        // Update filter button states
        updateFilterButtons()

        // Update UI for current filter
        updateUIForCurrentFilter()
    }

    private fun updateFilterButtons() {
        // Reset all filter buttons to outlined style
        binding.filterAccounts.setBackgroundResource(R.drawable.filter_button_outlined)
        binding.filterSellers.setBackgroundResource(R.drawable.filter_button_outlined)
        binding.filterReels.setBackgroundResource(R.drawable.filter_button_outlined)
        binding.filterProducts.setBackgroundResource(R.drawable.filter_button_outlined)

        binding.filterAccounts.setTextColor(resources.getColor(android.R.color.black, null))
        binding.filterSellers.setTextColor(resources.getColor(android.R.color.black, null))
        binding.filterReels.setTextColor(resources.getColor(android.R.color.black, null))
        binding.filterProducts.setTextColor(resources.getColor(android.R.color.black, null))

        // Set active filter button to filled style
        when (currentFilter) {
            "accounts" -> {
                binding.filterAccounts.setBackgroundResource(R.drawable.filter_button_filled)
                binding.filterAccounts.setTextColor(resources.getColor(android.R.color.white, null))
            }
            "sellers" -> {
                binding.filterSellers.setBackgroundResource(R.drawable.filter_button_filled)
                binding.filterSellers.setTextColor(resources.getColor(android.R.color.white, null))
            }
            "reels" -> {
                binding.filterReels.setBackgroundResource(R.drawable.filter_button_filled)
                binding.filterReels.setTextColor(resources.getColor(android.R.color.white, null))
            }
            "products" -> {
                binding.filterProducts.setBackgroundResource(R.drawable.filter_button_filled)
                binding.filterProducts.setTextColor(resources.getColor(android.R.color.white, null))
            }
        }
    }

    private fun updateUIForCurrentFilter() {
        when (currentFilter) {
            "accounts" -> {
                if (currentQuery.isNotEmpty()) {
                    performSearch(currentQuery)
                } else {
                    updateUIForAccountSearch("", 0)
                }
            }
            "sellers" -> {
                updateUIForSellerSearch("", 0)
            }
            "reels" -> {
                updateUIForReelSearch("", 0)
            }
            "products" -> {
                updateUIForProductSearch("", 0)
            }
        }
    }

    private fun performSearch(query: String) {
        if (!isFragmentActive || _binding == null) {
            Log.d("SearchFragment", "Fragment not active, skipping search")
            return
        }

        when (currentFilter) {
            "accounts" -> performAccountSearch(query)
            "sellers" -> performSellerSearch(query)
            "reels" -> performReelSearch(query)
            "products" -> performProductSearch(query)
        }
    }

    private fun performAccountSearch(query: String) {
        // Remove previous listener if exists
        searchListener?.let { listener ->
            FirebaseDatabase.getInstance().getReference("users").removeEventListener(listener)
        }

        if (query.length < 2) {
            searchResults.clear()
            searchAdapter.notifyDataSetChanged()
            updateUIForAccountSearch(query, 0)
            return
        }

        val database = FirebaseDatabase.getInstance().getReference("users")
        val queryLower = query.lowercase(Locale.getDefault())

        searchListener = object : ValueEventListener {
            override fun onDataChange(snapshot: DataSnapshot) {
                if (!isFragmentActive || _binding == null) {
                    Log.d("SearchFragment", "Fragment destroyed, skipping search results")
                    return
                }

                val results = mutableListOf<User>()

                try {
                    for (userSnapshot in snapshot.children) {
                        try {
                            // CRITICAL FIX: Only try to convert to User if it looks like a User object
                            if (userSnapshot.hasChild("fullName") && userSnapshot.hasChild("email")) {
                                val user = userSnapshot.getValue(User::class.java)
                                user?.let {
                                    // Safely check fullNameLower exists and isn't null
                                    val fullNameLower = it.fullNameLower?.lowercase(Locale.getDefault()) ?: ""
                                    if (fullNameLower.isNotEmpty() && fullNameLower.contains(queryLower)) {
                                        results.add(it)
                                    }
                                }
                            } else {
                                // Skip this node - it's not a User object (probably a Long, String, or other data)
                                Log.d("SearchFragment", "Skipping non-user node: ${userSnapshot.key}")
                            }
                        } catch (e: Exception) {
                            // Skip individual problematic nodes
                            Log.w("SearchFragment", "Skipping problematic node: ${userSnapshot.key}, error: ${e.message}")
                        }
                    }

                    // Sort results by relevance (exact matches first, then partial matches)
                    results.sortWith { user1, user2 ->
                        val name1 = user1.fullNameLower?.lowercase(Locale.getDefault()) ?: ""
                        val name2 = user2.fullNameLower?.lowercase(Locale.getDefault()) ?: ""

                        when {
                            name1.startsWith(queryLower) && !name2.startsWith(queryLower) -> -1
                            !name1.startsWith(queryLower) && name2.startsWith(queryLower) -> 1
                            else -> name1.compareTo(name2)
                        }
                    }

                    // Update results
                    searchResults.clear()
                    searchResults.addAll(results)
                    searchAdapter.notifyDataSetChanged()

                    // Update UI
                    updateUIForAccountSearch(query, results.size)

                    Log.d("SearchFragment", "Account search completed: ${results.size} results for '$query'")

                } catch (e: Exception) {
                    Log.e("SearchFragment", "Error processing search results", e)
                    updateUIForAccountSearch(query, 0, "Error searching accounts")
                }
            }

            override fun onCancelled(error: DatabaseError) {
                if (!isFragmentActive || _binding == null) return

                Log.e("SearchFragment", "Search cancelled: ${error.message}")
                updateUIForAccountSearch(query, 0, "Search failed: ${error.message}")
            }
        }

        // Attach the listener
        database.addValueEventListener(searchListener!!)
    }

    // Updated method for UI feedback with pluralization
    private fun updateUIForAccountSearch(query: String, resultCount: Int, error: String? = null) {
        // CRITICAL: Always check if binding is available before using it
        if (!isFragmentActive || _binding == null) {
            Log.d("SearchFragment", "Skipping UI update - fragment destroyed")
            return
        }

        // Update title with proper pluralization using your exact ID: search_results_title
        binding.searchResultsTitle.text = "Accounts - ${pluralizeResults(resultCount)}"

        val content = when {
            error != null -> error
            query.isEmpty() -> "Start typing to search for accounts by full name...\n\nResults will show people using this app."
            query.length < 2 -> "Type at least 2 characters to search..."
            resultCount == 0 -> "No accounts found for \"$query\""
            else -> "Found ${pluralizeResults(resultCount)} matching \"$query\""
        }

        // Using your exact ID: search_results_content
        binding.searchResultsContent.text = content

        if (resultCount > 0) {
            binding.searchResultsRecyclerView.visibility = View.VISIBLE
            binding.searchResultsContent.visibility = View.GONE
        } else {
            binding.searchResultsRecyclerView.visibility = View.GONE
            binding.searchResultsContent.visibility = View.VISIBLE
        }
    }

    private fun performSellerSearch(query: String) {
        // Placeholder for seller search - implement as needed
        updateUIForSellerSearch(query, 0)
    }

    private fun updateUIForSellerSearch(query: String, resultCount: Int) {
        if (!isFragmentActive || _binding == null) return

        binding.searchResultsTitle.text = "Sellers - ${pluralizeResults(resultCount)}"

        val content = when {
            query.isEmpty() -> "Search for sellers and stores..."
            query.length < 2 -> "Type at least 2 characters..."
            resultCount == 0 -> "No sellers found for \"$query\""
            else -> "Found ${pluralizeResults(resultCount)} matching \"$query\""
        }

        binding.searchResultsContent.text = content

        // Hide RecyclerView for sellers (not implemented)
        binding.searchResultsRecyclerView.visibility = View.GONE
        binding.searchResultsContent.visibility = View.VISIBLE
    }

    private fun performReelSearch(query: String) {
        // Placeholder for reel search - implement as needed
        updateUIForReelSearch(query, 0)
    }

    private fun updateUIForReelSearch(query: String, resultCount: Int) {
        if (!isFragmentActive || _binding == null) return

        binding.searchResultsTitle.text = "Reels - ${pluralizeResults(resultCount)}"

        val content = when {
            query.isEmpty() -> "Search for reels and videos..."
            query.length < 2 -> "Type at least 2 characters..."
            resultCount == 0 -> "No reels found for \"$query\""
            else -> "Found ${pluralizeResults(resultCount)} matching \"$query\""
        }

        binding.searchResultsContent.text = content

        // Hide RecyclerView for reels (not implemented)
        binding.searchResultsRecyclerView.visibility = View.GONE
        binding.searchResultsContent.visibility = View.VISIBLE
    }

    private fun performProductSearch(query: String) {
        // Placeholder for product search - implement as needed
        updateUIForProductSearch(query, 0)
    }

    private fun updateUIForProductSearch(query: String, resultCount: Int) {
        if (!isFragmentActive || _binding == null) return

        binding.searchResultsTitle.text = "Products - ${pluralizeResults(resultCount)}"

        val content = when {
            query.isEmpty() -> "Search for products and deals..."
            query.length < 2 -> "Type at least 2 characters..."
            resultCount == 0 -> "No products found for \"$query\""
            else -> "Found ${pluralizeResults(resultCount)} matching \"$query\""
        }

        binding.searchResultsContent.text = content

        // Hide RecyclerView for products (not implemented)
        binding.searchResultsRecyclerView.visibility = View.GONE
        binding.searchResultsContent.visibility = View.VISIBLE
    }

    // Helper function for pluralizing search results
    private fun pluralizeResults(count: Int): String {
        return if (count == 1) "1 result" else "$count results"
    }

    // Helper function for general pluralization
    private fun pluralize(count: Long, singular: String, plural: String): String {
        return if (count == 1L) "1 $singular" else "$count $plural"
    }

    private fun setupBackButton() {
        // Using your exact ID: back_button
        binding.backButton.setOnClickListener {
            val mainActivity = activity as MainActivity
            mainActivity.goBackToHome()
        }
    }

    // Public methods for MainActivity to interact with
    fun setSearchState(filter: String, query: String) {
        currentFilter = filter
        currentQuery = query
    }

    private fun saveSearchState() {
        val mainActivity = activity as MainActivity
        mainActivity.saveSearchState(currentFilter, currentQuery)
    }

    private fun restoreSearchState() {
        val mainActivity = activity as MainActivity

        // Restore filter and query
        currentFilter = mainActivity.getSavedSearchFilter()
        currentQuery = mainActivity.getSavedSearchQuery()

        // Update UI - using your exact ID: search_edit_text
        binding.searchEditText.setText(currentQuery)
        setActiveFilter(currentFilter)

        // Perform search if query exists
        if (currentQuery.isNotEmpty()) {
            performSearch(currentQuery)
        }
    }

    override fun onResume() {
        super.onResume()
        isFragmentActive = true
        Log.d("SearchFragment", "Fragment resumed")
    }

    override fun onPause() {
        super.onPause()
        isFragmentActive = false
        Log.d("SearchFragment", "Fragment paused")
    }

    override fun onDestroyView() {
        super.onDestroyView()
        isFragmentActive = false

        // Remove Firebase listeners to prevent memory leaks
        searchListener?.let { listener ->
            FirebaseDatabase.getInstance().getReference("users").removeEventListener(listener)
        }

        _binding = null
        Log.d("SearchFragment", "SearchFragment view destroyed safely")
    }
}
