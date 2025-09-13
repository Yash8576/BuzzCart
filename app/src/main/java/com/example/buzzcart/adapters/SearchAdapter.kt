package com.example.buzzcart.adapters

import android.view.LayoutInflater
import android.view.ViewGroup
import androidx.recyclerview.widget.RecyclerView
import com.example.buzzcart.databinding.ItemSearchUserBinding
import com.example.buzzcart.models.User

class SearchAdapter(
    private val users: MutableList<User>,
    private val onUserClick: (User) -> Unit
) : RecyclerView.Adapter<SearchAdapter.UserViewHolder>() {

    override fun onCreateViewHolder(parent: ViewGroup, viewType: Int): UserViewHolder {
        val binding = ItemSearchUserBinding.inflate(
            LayoutInflater.from(parent.context),
            parent,
            false
        )
        return UserViewHolder(binding)
    }

    override fun onBindViewHolder(holder: UserViewHolder, position: Int) {
        holder.bind(users[position])
    }

    override fun getItemCount(): Int = users.size

    inner class UserViewHolder(private val binding: ItemSearchUserBinding) :
        RecyclerView.ViewHolder(binding.root) {

        fun bind(user: User) {
            binding.userName.text = user.fullName
            binding.userEmail.text = user.email

            // Format follower counts with proper pluralization
            val followersText = formatCount(user.followersCount, "follower", "followers")
            val followingText = formatCount(user.followingCount, "following", "following")
            binding.userStats.text = "$followersText • $followingText"

            // Handle click
            binding.root.setOnClickListener {
                onUserClick(user)
            }
        }

        private fun formatCount(count: Long, singular: String, plural: String): String {
            val formattedCount = when {
                count >= 1_000_000 -> String.format("%.1fM", count / 1_000_000.0)
                count >= 1_000 -> String.format("%.1fK", count / 1_000.0)
                else -> count.toString()
            }

            return if (count == 1L) "$formattedCount $singular" else "$formattedCount $plural"
        }
    }
}
