package com.example.buzzcart.fragments

import android.os.Bundle
import android.view.LayoutInflater
import android.view.View
import android.view.ViewGroup
import androidx.fragment.app.Fragment
import com.example.buzzcart.databinding.FragmentReelsBinding

class ReelsFragment : Fragment() {
    private var _binding: FragmentReelsBinding? = null
    private val binding get() = _binding!!

    override fun onCreateView(
        inflater: LayoutInflater,
        container: ViewGroup?,
        savedInstanceState: Bundle?
    ): View {
        _binding = FragmentReelsBinding.inflate(inflater, container, false)
        return binding.root
    }

    override fun onViewCreated(view: View, savedInstanceState: Bundle?) {
        super.onViewCreated(view, savedInstanceState)

        binding.reelsTitle.text = "Product Reels"
        binding.reelsDescription.text = "Watch exciting product videos and reviews!"
    }

    override fun onDestroyView() {
        super.onDestroyView()
        _binding = null
    }
}
