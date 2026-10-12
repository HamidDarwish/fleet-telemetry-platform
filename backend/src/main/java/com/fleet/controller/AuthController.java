package com.fleet.controller;

import com.fleet.dto.Dtos;
import com.fleet.model.User;
import com.fleet.repository.UserRepository;
import com.fleet.security.JwtService;
import jakarta.validation.Valid;
import lombok.RequiredArgsConstructor;
import org.springframework.http.HttpStatus;
import org.springframework.security.crypto.password.PasswordEncoder;
import org.springframework.web.bind.annotation.*;
import org.springframework.web.server.ResponseStatusException;

@RestController
@RequestMapping("/api/auth")
@RequiredArgsConstructor
public class AuthController {
    private final UserRepository users;
    private final PasswordEncoder encoder;
    private final JwtService jwt;

    /** FR-1.1 */
    @PostMapping("/login")
    public Dtos.LoginResponse login(@Valid @RequestBody Dtos.LoginRequest r) {
        User u = users.findByEmail(r.email())
                .filter(User::isActive)
                .filter(x -> encoder.matches(r.password(), x.getPasswordHash()))
                .orElseThrow(() -> new ResponseStatusException(HttpStatus.UNAUTHORIZED, "Invalid email or password"));
        return new Dtos.LoginResponse(jwt.generate(u), u.getId(), u.getName(), u.getRole().name());
    }
}
