package com.fleet.controller;

import com.fleet.dto.Dtos;
import com.fleet.model.User;
import com.fleet.service.UserService;
import jakarta.validation.Valid;
import lombok.RequiredArgsConstructor;
import org.springframework.security.access.prepost.PreAuthorize;
import org.springframework.web.bind.annotation.*;

import java.util.List;

/** FR-1.4 - only the System Admin manages users. */
@RestController
@RequestMapping("/api/users")
@PreAuthorize("hasRole('ADMIN')")
@RequiredArgsConstructor
public class UserController {
    private final UserService users;

    @GetMapping
    public List<User> list() {
        return users.all();
    }

    @PostMapping
    public User create(@Valid @RequestBody Dtos.UserRequest r) {
        return users.create(r);
    }

    @PutMapping("/{id}")
    public User update(@PathVariable Long id, @Valid @RequestBody Dtos.UserRequest r) {
        return users.update(id, r);
    }
}
