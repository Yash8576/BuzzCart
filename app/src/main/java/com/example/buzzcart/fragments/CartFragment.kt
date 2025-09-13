package com.example.buzzcart.fragments

import android.os.Bundle
import android.view.LayoutInflater
import android.view.View
import android.view.ViewGroup
import androidx.fragment.app.Fragment
import com.example.buzzcart.databinding.FragmentCartBinding

class CartFragment : Fragment() {
    private var _binding: FragmentCartBinding? = null
    private val binding get() = _binding!!

    override fun onCreateView(
        inflater: LayoutInflater,
        container: ViewGroup?,
        savedInstanceState: Bundle?
    ): View {
        _binding = FragmentCartBinding.inflate(inflater, container, false)
        return binding.root
    }

    override fun onViewCreated(view: View, savedInstanceState: Bundle?) {
        super.onViewCreated(view, savedInstanceState)

        binding.cartTitle.text = "Shopping Cart"
        binding.cartDescription.text = "Your selected items will appear here"
        binding.emptyCartMessage.text = "Your cart is empty\nStart shopping to add items!"
    }

    override fun onDestroyView() {
        super.onDestroyView()
        _binding = null
    }
}
