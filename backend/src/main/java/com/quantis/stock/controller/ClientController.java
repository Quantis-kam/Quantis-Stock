package com.quantis.stock.controller;

import com.quantis.stock.dto.ApiResponse;
import com.quantis.stock.dto.PagedResponse;
import com.quantis.stock.exception.ResourceNotFoundException;
import com.quantis.stock.model.Client;
import com.quantis.stock.repository.ClientRepository;
import jakarta.validation.Valid;
import lombok.RequiredArgsConstructor;
import org.springframework.data.domain.Page;
import org.springframework.data.domain.PageRequest;
import org.springframework.data.domain.Pageable;
import org.springframework.http.HttpStatus;
import org.springframework.http.ResponseEntity;
import org.springframework.security.access.prepost.PreAuthorize;
import org.springframework.web.bind.annotation.*;

@RestController
@RequestMapping("/clients")
@RequiredArgsConstructor
public class ClientController {

    private final ClientRepository clientRepository;

    @GetMapping
    public ResponseEntity<ApiResponse<PagedResponse<Client>>> findAll(
            @RequestParam(defaultValue = "0") int page,
            @RequestParam(defaultValue = "20") int size) {
        Pageable pageable = PageRequest.of(page, Math.min(size, 100));
        Page<Client> result = clientRepository.findByActifTrue(pageable);
        return ResponseEntity.ok(ApiResponse.success(toPagedResponse(result)));
    }

    @GetMapping("/{id}")
    public ResponseEntity<ApiResponse<Client>> findById(@PathVariable Long id) {
        Client client = clientRepository.findById(id)
                .orElseThrow(() -> new ResourceNotFoundException("Client", "id", id));
        return ResponseEntity.ok(ApiResponse.success(client));
    }

    @GetMapping("/search")
    public ResponseEntity<ApiResponse<PagedResponse<Client>>> search(
            @RequestParam String q,
            @RequestParam(defaultValue = "0") int page,
            @RequestParam(defaultValue = "20") int size) {
        Pageable pageable = PageRequest.of(page, Math.min(size, 100));
        Page<Client> result = clientRepository.search(q, pageable);
        return ResponseEntity.ok(ApiResponse.success(toPagedResponse(result)));
    }

    @PostMapping
    @PreAuthorize("hasAnyRole('ADMIN','GERANT','CAISSIER')")
    public ResponseEntity<ApiResponse<Client>> create(@Valid @RequestBody Client client) {
        client.setId(null);
        Client saved = clientRepository.save(client);
        return new ResponseEntity<>(ApiResponse.success("Client créé", saved), HttpStatus.CREATED);
    }

    @PutMapping("/{id}")
    @PreAuthorize("hasAnyRole('ADMIN','GERANT','CAISSIER')")
    public ResponseEntity<ApiResponse<Client>> update(@PathVariable Long id, @Valid @RequestBody Client request) {
        Client client = clientRepository.findById(id)
                .orElseThrow(() -> new ResourceNotFoundException("Client", "id", id));
        client.setNom(request.getNom());
        client.setTelephone(request.getTelephone());
        client.setEmail(request.getEmail());
        client.setAdresse(request.getAdresse());
        client.setNotes(request.getNotes());
        return ResponseEntity.ok(ApiResponse.success("Client mis à jour", clientRepository.save(client)));
    }

    private <T> PagedResponse<T> toPagedResponse(Page<T> page) {
        return PagedResponse.<T>builder()
                .content(page.getContent())
                .page(page.getNumber())
                .size(page.getSize())
                .totalElements(page.getTotalElements())
                .totalPages(page.getTotalPages())
                .last(page.isLast())
                .first(page.isFirst())
                .build();
    }
}
