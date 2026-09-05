package com.quantis.stock;

import com.quantis.stock.model.AuditLog;
import com.quantis.stock.model.enums.Role;
import com.quantis.stock.model.Utilisateur;
import com.quantis.stock.repository.AuditLogRepository;
import com.quantis.stock.repository.UtilisateurRepository;
import com.quantis.stock.service.AuthService;
import org.junit.jupiter.api.Test;
import org.springframework.beans.factory.annotation.Autowired;
import org.springframework.boot.test.context.SpringBootTest;
import org.springframework.test.context.ActiveProfiles;
import org.springframework.transaction.annotation.Transactional;

import java.util.List;

import static org.junit.jupiter.api.Assertions.*;

@SpringBootTest
@ActiveProfiles("test")
@Transactional
class StockApiApplicationTests {

	@Autowired
	private UtilisateurRepository utilisateurRepository;

	@Autowired
	private AuthService authService;

	@Autowired
	private AuditLogRepository auditLogRepository;

	@Test
	void testAuditLoggingFlow() {
		// 1. Enregistrer un utilisateur
		Utilisateur user = Utilisateur.builder()
				.nom("Dupont")
				.prenom("Jean")
				.email("jean.gerant@quantis.tech")
				.motDePasseHash("password_hash")
				.role(Role.GERANT)
				.actif(true)
				.build();
		user = utilisateurRepository.save(user);

		// 2. Simuler déconnexion
		authService.logout("jean.gerant@quantis.tech", "127.0.0.1");

		// 3. Vérifier les logs d'audit
		List<AuditLog> logs = auditLogRepository.findAll();
		assertFalse(logs.isEmpty(), "Des logs d'audit doivent être présents");

		boolean logoutLogFound = false;
		for (AuditLog log : logs) {
			if ("LOGOUT".equals(log.getAction()) && "jean.gerant@quantis.tech".equals(log.getUtilisateur().getEmail())) {
				logoutLogFound = true;
				assertEquals("127.0.0.1", log.getIpAddress());
				assertEquals("Utilisateur", log.getEntite());
				break;
			}
		}
		assertTrue(logoutLogFound, "Le log d'audit de déconnexion doit être présent");
	}
}
