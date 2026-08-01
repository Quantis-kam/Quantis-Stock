package com.quantis.stock.config;

import org.springframework.context.annotation.Configuration;
import org.springframework.data.jpa.repository.config.EnableJpaAuditing;

/**
 * Active l'audit JPA automatique (created_at, updated_at).
 */
@Configuration
@EnableJpaAuditing
public class JpaConfig {
}
