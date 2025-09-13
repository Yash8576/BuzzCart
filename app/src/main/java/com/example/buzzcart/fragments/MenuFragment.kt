package com.example.buzzcart.fragments

import android.os.Bundle
import android.view.LayoutInflater
import android.view.View
import android.view.ViewGroup
import android.widget.Toast
import androidx.fragment.app.Fragment
import com.example.buzzcart.MainActivity
import com.example.buzzcart.R
import com.example.buzzcart.databinding.FragmentMenuBinding

class MenuFragment : Fragment() {
    private var _binding: FragmentMenuBinding? = null
    private val binding get() = _binding!!

    override fun onCreateView(
        inflater: LayoutInflater,
        container: ViewGroup?,
        savedInstanceState: Bundle?
    ): View {
        _binding = FragmentMenuBinding.inflate(inflater, container, false)
        return binding.root
    }

    override fun onViewCreated(view: View, savedInstanceState: Bundle?) {
        super.onViewCreated(view, savedInstanceState)

        setupMenuItems()
    }

    private fun setupMenuItems() {
        val mainActivity = activity as MainActivity

        // Close button
        binding.closeButton.setOnClickListener {
            mainActivity.closeMenuFragment()
        }

        // Profile Settings
        binding.menuProfileSettings.setOnClickListener {
            showComingSoonToast(R.string.menu_profile_settings)
        }

        // Account Settings
        binding.menuAccountSettings.setOnClickListener {
            showComingSoonToast(R.string.menu_account_settings)
        }

        // Privacy & Security
        binding.menuPrivacy.setOnClickListener {
            showComingSoonToast(R.string.menu_privacy_security)
        }

        // Notifications
        binding.menuNotifications.setOnClickListener {
            showComingSoonToast(R.string.menu_notifications)
        }

        // Payment & Billing
        binding.menuPayment.setOnClickListener {
            showComingSoonToast(R.string.menu_payment_billing)
        }

        // Order History
        binding.menuOrders.setOnClickListener {
            showComingSoonToast(R.string.menu_order_history)
        }

        // Help & Support
        binding.menuHelp.setOnClickListener {
            showComingSoonToast(R.string.menu_help_support)
        }

        // About
        binding.menuAbout.setOnClickListener {
            showComingSoonToast(R.string.menu_about)
        }

        // Logout
        binding.menuLogout.setOnClickListener {
            mainActivity.signOutUser()
        }
    }

    private fun showComingSoonToast(stringRes: Int) {
        val message = getString(R.string.coming_soon, getString(stringRes))
        Toast.makeText(context, message, Toast.LENGTH_SHORT).show()
    }

    override fun onDestroyView() {
        super.onDestroyView()
        _binding = null
    }
}
