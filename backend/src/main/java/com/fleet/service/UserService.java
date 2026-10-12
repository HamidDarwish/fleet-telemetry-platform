package com.fleet.service;

import com.fleet.dto.Dtos;
import com.fleet.model.User;
import com.fleet.repository.UserRepository;
import lombok.RequiredArgsConstructor;
import org.springframework.security.core.Authentication;
import org.springframework.security.crypto.password.PasswordEncoder;
import org.springframework.stereotype.Service;

import java.util.List;
import java.util.NoSuchElementException;

@Service
@RequiredArgsConstructor
public class UserService {
    private final UserRepository users;
    private final PasswordEncoder encoder;

    /** The logged-in user of the current request. */
    public User current(Authentication auth) {
        return users.findByEmail(auth.getName())
                .orElseThrow(() -> new NoSuchElementException("User not found"));
    }

    public List<User> all() {
        return users.findAll();
    }

    public User create(Dtos.UserRequest r) {
        if (r.password() == null || r.password().length() < 6)
            throw new IllegalArgumentException("Password must be at least 6 characters");
        if (users.findByEmail(r.email()).isPresent())
            throw new IllegalArgumentException("Email already exists");
        User u = new User();
        u.setName(r.name());
        u.setEmail(r.email());
        u.setPasswordHash(encoder.encode(r.password()));
        u.setRole(r.role());
        u.setActive(r.active() == null || r.active());
        return users.save(u);
    }

    public User update(Long id, Dtos.UserRequest r) {
        User u = users.findById(id).orElseThrow(() -> new NoSuchElementException("User not found"));
        u.setName(r.name());
        u.setRole(r.role());
        if (r.active() != null) u.setActive(r.active());
        if (r.password() != null && !r.password().isBlank()) {
            if (r.password().length() < 6) throw new IllegalArgumentException("Password must be at least 6 characters");
            u.setPasswordHash(encoder.encode(r.password()));
        }
        return users.save(u);
    }
}
