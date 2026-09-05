package com.quantis.stock.security;

import com.quantis.stock.model.Utilisateur;
import com.quantis.stock.repository.UtilisateurRepository;
import lombok.RequiredArgsConstructor;
import org.springframework.security.core.authority.SimpleGrantedAuthority;
import org.springframework.security.core.userdetails.User;
import org.springframework.security.core.userdetails.UserDetails;
import org.springframework.security.core.userdetails.UserDetailsService;
import org.springframework.security.core.userdetails.UsernameNotFoundException;
import org.springframework.stereotype.Service;

import java.util.List;

/**
 * Charge les détails utilisateur depuis la base pour Spring Security.
 */
@Service
@RequiredArgsConstructor
public class CustomUserDetailsService implements UserDetailsService {

    private final UtilisateurRepository utilisateurRepository;

    @Override
    public UserDetails loadUserByUsername(String email) throws UsernameNotFoundException {
        Utilisateur user = utilisateurRepository.findByEmail(email)
                .orElseThrow(() -> new UsernameNotFoundException("Utilisateur introuvable : " + email));

        if (!user.getActif()) {
            throw new UsernameNotFoundException("Compte désactivé : " + email);
        }

        java.util.List<SimpleGrantedAuthority> authorities = new java.util.ArrayList<>();
        authorities.add(new SimpleGrantedAuthority("ROLE_" + user.getRole().name()));
        for (com.quantis.stock.model.enums.Permission perm : user.getPermissionsEffectives()) {
            authorities.add(new SimpleGrantedAuthority(perm.name()));
        }

        return new User(
                user.getEmail(),
                user.getMotDePasseHash(),
                authorities
        );
    }
}
