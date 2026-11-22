package com.quantis.stock.network;

import com.fasterxml.jackson.databind.JsonNode;
import com.fasterxml.jackson.databind.ObjectMapper;
import org.junit.jupiter.api.DisplayName;
import org.junit.jupiter.api.Test;
import org.springframework.test.util.ReflectionTestUtils;

import java.net.DatagramPacket;
import java.net.DatagramSocket;
import java.net.InetAddress;
import java.nio.ByteOrder;
import java.nio.charset.StandardCharsets;

import static org.junit.jupiter.api.Assertions.*;

class NetworkDiscoveryTest {

    @Test
    @DisplayName("Décodage /proc/net/route pour passerelle Wi-Fi et Point d'accès aléatoire")
    void testParseProcRouteIp() {
        if (ByteOrder.nativeOrder() == ByteOrder.LITTLE_ENDIAN) {
            // 192.168.11.1 => C0.A8.0B.01 => little-endian 010BA8C0
            assertEquals("192.168.11.1", NetworkUtils.parseProcRouteIp("010BA8C0"));
            // 10.213.61.194 => 0A.D5.3D.C2 => little-endian C23DD50A
            assertEquals("10.213.61.194", NetworkUtils.parseProcRouteIp("C23DD50A"));
        } else {
            assertEquals("192.168.11.1", NetworkUtils.parseProcRouteIp("C0A80B01"));
            assertEquals("10.213.61.194", NetworkUtils.parseProcRouteIp("0AD53DC2"));
        }
        assertNull(NetworkUtils.parseProcRouteIp("invalid"));
    }

    @Test
    @DisplayName("Filtrage des interfaces Docker/VPN vs interfaces physiques")
    void testIgnoredInterfaces() {
        assertTrue(NetworkUtils.isIgnoredInterfaceName("docker0"));
        assertTrue(NetworkUtils.isIgnoredInterfaceName("br-929e5fc3ea14"));
        assertTrue(NetworkUtils.isIgnoredInterfaceName("veth1234"));
        assertTrue(NetworkUtils.isIgnoredInterfaceName("tun0"));
        assertTrue(NetworkUtils.isIgnoredInterfaceName("wg0"));
        assertTrue(NetworkUtils.isIgnoredInterfaceName("lo"));

        assertFalse(NetworkUtils.isIgnoredInterfaceName("wlan0"));
        assertFalse(NetworkUtils.isIgnoredInterfaceName("wlp2s0"));
        assertFalse(NetworkUtils.isIgnoredInterfaceName("eth0"));
        assertFalse(NetworkUtils.isIgnoredInterfaceName("usb0"));
    }

    @Test
    @DisplayName("Broadcast fallback pour iPhone /28 et réseaux standards /24")
    void testFallbackBroadcast() {
        assertEquals("172.20.10.15", NetworkUtils.computeFallbackBroadcast("172.20.10.4"));
        assertEquals("10.84.192.255", NetworkUtils.computeFallbackBroadcast("10.84.192.225"));
        assertEquals("192.168.43.255", NetworkUtils.computeFallbackBroadcast("192.168.43.120"));
    }

    @Test
    @DisplayName("Répondeur UDP QUANTIS_DISCOVER renvoie un JSON serveur valide")
    void testUdpDiscoveryResponder() throws Exception {
        ObjectMapper mapper = new ObjectMapper();
        NetworkDiscoveryService service = new NetworkDiscoveryService(mapper);
        int testPort = 45909;
        ReflectionTestUtils.setField(service, "serverPort", 8080);
        ReflectionTestUtils.setField(service, "contextPath", "/api/v1");
        ReflectionTestUtils.setField(service, "discoveryPort", testPort);
        ReflectionTestUtils.setField(service, "beaconIntervalMs", 60000L);

        service.start();
        try (DatagramSocket client = new DatagramSocket()) {
            client.setSoTimeout(3000);
            byte[] probe = NetworkDiscoveryService.DISCOVERY_MAGIC.getBytes(StandardCharsets.UTF_8);
            DatagramPacket req = new DatagramPacket(
                probe, probe.length, InetAddress.getByName("127.0.0.1"), testPort
            );
            client.send(req);

            byte[] buf = new byte[2048];
            DatagramPacket resp = new DatagramPacket(buf, buf.length);
            client.receive(resp);

            String json = new String(resp.getData(), resp.getOffset(), resp.getLength(), StandardCharsets.UTF_8);
            JsonNode root = mapper.readTree(json);
            assertEquals("quantis-stock", root.get("app").asText());
            assertEquals("QUANTIS_SERVER", root.get("type").asText());
            assertEquals(8080, root.get("port").asInt());
            assertEquals("/api/v1", root.get("contextPath").asText());
        } finally {
            service.stop();
        }
    }
}

