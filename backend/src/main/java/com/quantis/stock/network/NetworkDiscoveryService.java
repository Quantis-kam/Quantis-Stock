package com.quantis.stock.network;

import com.fasterxml.jackson.databind.ObjectMapper;
import jakarta.annotation.PreDestroy;
import org.slf4j.Logger;
import org.slf4j.LoggerFactory;
import org.springframework.beans.factory.annotation.Value;
import org.springframework.boot.autoconfigure.condition.ConditionalOnProperty;
import org.springframework.boot.context.event.ApplicationReadyEvent;
import org.springframework.context.event.EventListener;
import org.springframework.stereotype.Component;

import java.net.DatagramPacket;
import java.net.DatagramSocket;
import java.net.InetAddress;
import java.net.InetSocketAddress;
import java.net.SocketException;
import java.nio.charset.StandardCharsets;
import java.util.ArrayList;
import java.util.LinkedHashMap;
import java.util.LinkedHashSet;
import java.util.List;
import java.util.Map;
import java.util.Set;
import java.util.concurrent.Executors;
import java.util.concurrent.ScheduledExecutorService;
import java.util.concurrent.TimeUnit;
import java.util.concurrent.atomic.AtomicBoolean;

/**
 * Service de découverte automatique UDP sur réseau local et Point d'accès mobile.
 *
 * Fonctionne en double mode sans configuration manuelle :
 * 1. Répondeur actif : répond immédiatement en unicast UDP à toute sonde "QUANTIS_DISCOVER"
 *    envoyée par l'application mobile.
 * 2. Balise périodique : annonce toutes les 2 secondes la présence du serveur sur le broadcast
 *    de chaque interface active ET directement en unicast vers la passerelle par défaut
 *    (qui est le téléphone lui-même en mode Point d'accès mobile).
 */
@Component
@ConditionalOnProperty(name = "app.discovery.enabled", havingValue = "true", matchIfMissing = true)
public class NetworkDiscoveryService {

    private static final Logger log = LoggerFactory.getLogger(NetworkDiscoveryService.class);
    public static final String DISCOVERY_MAGIC = "QUANTIS_DISCOVER";

    private final ObjectMapper objectMapper;

    @Value("${server.port:8080}")
    private int serverPort;

    @Value("${server.servlet.context-path:/api/v1}")
    private String contextPath;

    @Value("${app.discovery.udp-port:45808}")
    private int discoveryPort;

    @Value("${app.discovery.beacon-interval-ms:2000}")
    private long beaconIntervalMs;

    private final AtomicBoolean running = new AtomicBoolean(false);
    private volatile DatagramSocket listenerSocket;
    private Thread listenerThread;
    private ScheduledExecutorService beaconExecutor;
    private volatile String lastLoggedPrimaryIp;

    public NetworkDiscoveryService(ObjectMapper objectMapper) {
        this.objectMapper = objectMapper;
    }

    @EventListener(ApplicationReadyEvent.class)
    public void start() {
        if (!running.compareAndSet(false, true)) {
            return;
        }

        try {
            DatagramSocket socket = new DatagramSocket(null);
            socket.setReuseAddress(true);
            socket.setBroadcast(true);
            socket.bind(new InetSocketAddress("0.0.0.0", discoveryPort));
            this.listenerSocket = socket;

            listenerThread = new Thread(this::listenLoop, "quantis-udp-discovery-listener");
            listenerThread.setDaemon(true);
            listenerThread.start();

            beaconExecutor = Executors.newSingleThreadScheduledExecutor(r -> {
                Thread t = new Thread(r, "quantis-udp-discovery-beacon");
                t.setDaemon(true);
                return t;
            });
            long interval = Math.max(1000L, beaconIntervalMs);
            beaconExecutor.scheduleAtFixedRate(this::broadcastBeacon, 500L, interval, TimeUnit.MILLISECONDS);

            logCurrentNetworkBanner();
        } catch (Exception e) {
            running.set(false);
            log.warn("Impossible de démarrer la découverte UDP sur le port {} : {}", discoveryPort, e.getMessage());
        }
    }

    private void listenLoop() {
        byte[] buffer = new byte[512];
        while (running.get()) {
            DatagramSocket socket = this.listenerSocket;
            if (socket == null || socket.isClosed()) {
                break;
            }
            try {
                DatagramPacket packet = new DatagramPacket(buffer, buffer.length);
                socket.receive(packet);

                String message = new String(
                    packet.getData(),
                    packet.getOffset(),
                    packet.getLength(),
                    StandardCharsets.UTF_8
                ).trim();

                if (message.startsWith(DISCOVERY_MAGIC)) {
                    String senderIp = packet.getAddress().getHostAddress();
                    List<NetworkUtils.InterfaceInfo> interfaces = NetworkUtils.getActiveInterfaces();
                    String matchingIp = pickBestIpForPeer(senderIp, interfaces);
                    byte[] responseBytes = buildPayloadBytes(matchingIp, interfaces);

                    DatagramPacket reply = new DatagramPacket(
                        responseBytes,
                        responseBytes.length,
                        packet.getAddress(),
                        packet.getPort()
                    );
                    socket.send(reply);
                    log.debug("Réponse découverte UDP envoyée à {}:{} -> IP serveur {}",
                        senderIp, packet.getPort(), matchingIp);
                }
            } catch (SocketException se) {
                if (!running.get()) {
                    break;
                }
                log.debug("Socket découverte UDP interrompu : {}", se.getMessage());
            } catch (Exception e) {
                if (running.get()) {
                    log.debug("Erreur réception découverte UDP : {}", e.getMessage());
                }
            }
        }
    }

    private void broadcastBeacon() {
        if (!running.get()) {
            return;
        }
        try {
            List<NetworkUtils.InterfaceInfo> interfaces = NetworkUtils.getActiveInterfaces();
            if (interfaces.isEmpty()) {
                return;
            }

            String primaryIp = NetworkUtils.getPrimaryIp(interfaces);
            if (!primaryIp.equals(lastLoggedPrimaryIp)) {
                lastLoggedPrimaryIp = primaryIp;
                log.info("[Quantis Discovery] Réseau actif détecté -> API : http://{}:{}{} (UDP {})",
                    primaryIp, serverPort, contextPath, discoveryPort);
            }

            for (NetworkUtils.InterfaceInfo iface : interfaces) {
                byte[] payload = buildPayloadBytes(iface.ip(), interfaces);
                Set<String> targets = new LinkedHashSet<>();

                // 1. Broadcast dirigé du sous-réseau (ex: 10.x.y.255 ou 192.168.x.255)
                if (iface.broadcast() != null && !iface.broadcast().isBlank()) {
                    targets.add(iface.broadcast());
                }
                // 2. Unicast direct vers la passerelle par défaut (= le téléphone en mode Point d'accès !)
                if (iface.gateway() != null && !iface.gateway().isBlank() && !iface.gateway().equals(iface.ip())) {
                    targets.add(iface.gateway());
                }
                // 3. Repli passerelle .1 (Windows / macOS)
                String dotOne = subnetDotOne(iface.ip());
                if (dotOne != null && !dotOne.equals(iface.ip())) {
                    targets.add(dotOne);
                }

                sendBeaconOnInterface(iface.ip(), payload, targets);
            }
        } catch (Exception e) {
            log.debug("Erreur émission balise UDP : {}", e.getMessage());
        }
    }

    private void sendBeaconOnInterface(String localIp, byte[] payload, Set<String> targets) {
        DatagramSocket sendSocket = null;
        try {
            try {
                sendSocket = new DatagramSocket(new InetSocketAddress(InetAddress.getByName(localIp), 0));
            } catch (Exception e) {
                sendSocket = new DatagramSocket();
            }
            sendSocket.setBroadcast(true);
            for (String targetIp : targets) {
                try {
                    InetAddress target = InetAddress.getByName(targetIp);
                    DatagramPacket packet = new DatagramPacket(payload, payload.length, target, discoveryPort);
                    sendSocket.send(packet);
                } catch (Exception ignored) {
                    // Interface ou cible temporairement injoignable pendant un changement de réseau
                }
            }
        } catch (Exception ignored) {
            // Interface retirée entre-temps
        } finally {
            if (sendSocket != null && !sendSocket.isClosed()) {
                sendSocket.close();
            }
        }
    }

    private void logCurrentNetworkBanner() {
        List<NetworkUtils.InterfaceInfo> interfaces = NetworkUtils.getActiveInterfaces();
        String primaryIp = NetworkUtils.getPrimaryIp(interfaces);
        lastLoggedPrimaryIp = primaryIp;
        log.info("==================================================================");
        log.info(" Quantis Stock API — Découverte mobile UDP active (port {})", discoveryPort);
        log.info(" URL API principale : http://{}:{}{}", primaryIp, serverPort, contextPath);
        for (NetworkUtils.InterfaceInfo info : interfaces) {
            log.info("  - [{}] {} ({}) gw={}",
                info.interfaceName(), info.ip(), info.type(),
                info.gateway() != null ? info.gateway() : "n/a");
        }
        log.info("==================================================================");
    }

    private String pickBestIpForPeer(String peerIp, List<NetworkUtils.InterfaceInfo> interfaces) {
        String peerPrefix = subnetPrefix24(peerIp);
        if (peerPrefix != null) {
            for (NetworkUtils.InterfaceInfo iface : interfaces) {
                if (peerPrefix.equals(subnetPrefix24(iface.ip()))) {
                    return iface.ip();
                }
            }
        }
        return NetworkUtils.getPrimaryIp(interfaces);
    }

    private byte[] buildPayloadBytes(String primaryIp, List<NetworkUtils.InterfaceInfo> interfaces) throws Exception {
        List<String> ips = new ArrayList<>();
        if (primaryIp != null && !"localhost".equals(primaryIp)) {
            ips.add(primaryIp);
        }
        for (NetworkUtils.InterfaceInfo iface : interfaces) {
            if (!ips.contains(iface.ip())) {
                ips.add(iface.ip());
            }
        }

        String hostname = "quantis-pc";
        try {
            hostname = InetAddress.getLocalHost().getHostName();
        } catch (Exception ignored) {}

        Map<String, Object> payload = new LinkedHashMap<>();
        payload.put("app", "quantis-stock");
        payload.put("type", "QUANTIS_SERVER");
        payload.put("version", "1.0.0");
        payload.put("port", serverPort);
        payload.put("contextPath", contextPath);
        payload.put("primaryIp", primaryIp);
        payload.put("ips", ips);
        payload.put("hostname", hostname);
        payload.put("apiUrl", "http://" + primaryIp + ":" + serverPort + contextPath);

        return objectMapper.writeValueAsString(payload).getBytes(StandardCharsets.UTF_8);
    }

    private static String subnetPrefix24(String ip) {
        if (ip == null) return null;
        int lastDot = ip.lastIndexOf('.');
        return lastDot > 0 ? ip.substring(0, lastDot) : null;
    }

    private static String subnetDotOne(String ip) {
        String prefix = subnetPrefix24(ip);
        return prefix != null ? prefix + ".1" : null;
    }

    @PreDestroy
    public void stop() {
        running.set(false);
        DatagramSocket socket = this.listenerSocket;
        if (socket != null && !socket.isClosed()) {
            socket.close();
        }
        if (beaconExecutor != null) {
            beaconExecutor.shutdownNow();
        }
    }
}
