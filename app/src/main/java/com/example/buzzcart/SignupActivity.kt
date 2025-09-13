package com.example.buzzcart

import android.content.Intent
import android.os.Bundle
import android.util.Log
import android.widget.Toast
import androidx.activity.enableEdgeToEdge
import androidx.appcompat.app.AppCompatActivity
import androidx.core.view.ViewCompat
import androidx.core.view.WindowInsetsCompat
import androidx.core.view.updatePadding
import com.example.buzzcart.databinding.ActivitySignupBinding
import com.google.firebase.auth.FirebaseAuth
import com.google.firebase.database.FirebaseDatabase
import com.google.firebase.database.ServerValue

class SignupActivity : AppCompatActivity() {

    private lateinit var binding: ActivitySignupBinding
    private lateinit var auth: FirebaseAuth

    override fun onCreate(savedInstanceState: Bundle?) {
        super.onCreate(savedInstanceState)
        enableEdgeToEdge()
        binding = ActivitySignupBinding.inflate(layoutInflater)
        setContentView(binding.root)

        auth = FirebaseAuth.getInstance()

        // Safe area - using signupMain instead of main
        ViewCompat.setOnApplyWindowInsetsListener(binding.signupMain) { v, insets ->
            val systemBars = insets.getInsets(WindowInsetsCompat.Type.systemBars())
            v.updatePadding(top = systemBars.top, bottom = systemBars.bottom)
            WindowInsetsCompat.CONSUMED
        }

        binding.buttonRegister.setOnClickListener {
            registerUser()
        }

        // Add navigation to LoginActivity if needed
        // binding.loginText.setOnClickListener {
        //     startActivity(Intent(this, LoginActivity::class.java))
        //     finish()
        // }
    }

    private fun registerUser() {
        val name = binding.userName.text.toString().trim()
        val email = binding.userEmail.text.toString().trim()
        val password = binding.userPass.text.toString().trim()
        val confirmPassword = binding.userPassRetype.text.toString().trim()

        if (name.isEmpty() || email.isEmpty() || password.isEmpty() || confirmPassword.isEmpty()) {
            Toast.makeText(this, "Please fill all fields", Toast.LENGTH_SHORT).show()
            return
        }

        if (password != confirmPassword) {
            Toast.makeText(this, "Passwords do not match", Toast.LENGTH_SHORT).show()
            return
        }

        if (password.length < 6) {
            Toast.makeText(this, "Password must be at least 6 characters", Toast.LENGTH_SHORT).show()
            return
        }

        auth.createUserWithEmailAndPassword(email, password)
            .addOnCompleteListener(this) { task ->
                if (task.isSuccessful) {
                    Log.d("SignupActivity", "createUserWithEmail:success")
                    val user = auth.currentUser
                    user?.let {
                        saveUserToDatabase(it.uid, name, email)
                    }
                } else {
                    Log.w("SignupActivity", "createUserWithEmail:failure", task.exception)
                    Toast.makeText(this, "Registration failed: ${task.exception?.message}", Toast.LENGTH_SHORT).show()
                }
            }
    }

    private fun saveUserToDatabase(userId: String, name: String, email: String) {
        val database = FirebaseDatabase.getInstance().getReference("users")

        // User data with social metrics initialized to 0
        val userMap = mapOf(
            "fullName" to name,
            "fullNameLower" to name.lowercase(), // For search indexing
            "email" to email,
            // Social metrics - Everyone starts with 0
            "followersCount" to 0,
            "followingCount" to 0,
            "postsCount" to 0,
            "likesReceived" to 0,
            "profileViews" to 0,
            "popularityScore" to 0.0,
            "lastActive" to ServerValue.TIMESTAMP
        )

        database.child(userId).setValue(userMap)
            .addOnSuccessListener {
                Log.d("SignupActivity", "User data saved to database")

                // Also create user interactions node
                createUserInteractionsNode(userId)

                Toast.makeText(this, "Registration successful!", Toast.LENGTH_SHORT).show()
                startActivity(Intent(this, MainActivity::class.java))
                finish()
            }
            .addOnFailureListener { exception ->
                Log.e("SignupActivity", "Failed to save user data", exception)
                Toast.makeText(this, "Failed to save user data", Toast.LENGTH_SHORT).show()
            }
    }

    private fun createUserInteractionsNode(userId: String) {
        val database = FirebaseDatabase.getInstance().getReference("userInteractions")

        val interactionsMap = mapOf(
            "searchHistory" to mapOf<String, Any>(),
            "profileVisits" to mapOf<String, Long>(),
            "interactions" to mapOf<String, Int>(),
            "preferences" to mapOf<String, Any>()
        )

        database.child(userId).setValue(interactionsMap)
            .addOnSuccessListener {
                Log.d("SignupActivity", "User interactions node created")
            }
            .addOnFailureListener { exception ->
                Log.e("SignupActivity", "Failed to create interactions node", exception)
            }
    }
}
