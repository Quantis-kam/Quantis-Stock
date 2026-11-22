package com.quantis.stock.security;

import org.junit.jupiter.api.Test;

import static org.junit.jupiter.api.Assertions.*;

class JwtSessionExpirationTest {

    private static final String TEST_SECRET = "quantis-stock-unit-test-secret-key-2026-32bytes-min";

    @Test
    void accessEtRefreshTokensSontDistinguesEtValides() {
        JwtTokenProvider provider = new JwtTokenProvider(TEST_SECRET, 900_000L, 1_800_000L);

        String access = provider.generateAccessToken(1L, "gerant@quantisbf.com", "ADMIN");
        String refresh = provider.generateRefreshToken("gerant@quantisbf.com");

        assertTrue(provider.validateToken(access));
        assertTrue(provider.validateToken(refresh));
        assertFalse(provider.isRefreshToken(access));
        assertTrue(provider.isRefreshToken(refresh));
        assertEquals("gerant@quantisbf.com", provider.getEmailFromToken(access));
        assertEquals("gerant@quantisbf.com", provider.getEmailFromToken(refresh));
    }

    @Test
    void tokenExpireEstRejete() {
        JwtTokenProvider expiredProvider = new JwtTokenProvider(TEST_SECRET, -1_000L, -1_000L);

        String expiredAccess = expiredProvider.generateAccessToken(1L, "gerant@quantisbf.com", "ADMIN");
        String expiredRefresh = expiredProvider.generateRefreshToken("gerant@quantisbf.com");

        assertFalse(expiredProvider.validateToken(expiredAccess));
        assertFalse(expiredProvider.validateToken(expiredRefresh));
    }
}

