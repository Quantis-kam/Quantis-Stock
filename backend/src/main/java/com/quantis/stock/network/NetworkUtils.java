package com.quantis.stock.network;

import java.net.DatagramSocket;
import java.net.Inet4Address;
import java.net.InetAddress;
import java.net.InterfaceAddress;
import java.net.NetworkInterface;
import java.nio.ByteOrder;
import java.nio.file.Files;
import java.nio.file.Path;
import java.util.ArrayList;
import java.util.Comparator;
import java.util.Enumeration;
import java.util.LinkedHashMap;
import java.util.LinkedHashSet;
import java.util.List;
import java.util.Locale;
import java.util.Map;
import java.util.Set;

/**
 * Utilitaire réseau pour détecter de manière fiable les interfaces actives du PC
 * (Point d'accès mobile Android/iOS, Wi-Fi, Ethernet, USB Tethering),
 * en ignorant les interfaces virtuelles (Docker, VPN, bridges, loopback).
 */
public final class NetworkUtils {

    private NetworkUtils() {}

    public record InterfaceInfo(
        String interfaceName,
        String ip,
        String broadcast,
        String gateway,
        String type,
        boolean isPrimary
    ) {
        public Map<String, Object> toMap() {
            Map<String, Object> map = new LinkedHashMap<>();
            map.put("interfaceName", interfaceName);
            map.put("ip", ip);
            map.put("broadcast", broadcast);
            map.put("gateway", gateway);
            map.put("type", type);
            map.put("isPrimary", isPrimary);
            return map;
        }
    }

    private record RouteEntry(String iface, String gateway, int metric) {}

    /**
     * Retourne toutes les interfaces IPv4 physiques/actives triées par priorité
     * (interface portant la route par défaut en premier).
     */
    public static List<InterfaceInfo> getActiveInterfaces() {
        List<RouteEntry> defaultRoutes = readLinuxDefaultRoutes();
        Map<String, String> gatewayByIface = new LinkedHashMap<>();
        String defaultRouteIface = null;
        for (RouteEntry route : defaultRoutes) {
            gatewayByIface.putIfAbsent(route.iface(), route.gateway());
            if (defaultRouteIface == null) {
                defaultRouteIface = route.iface();
            }
        }

        String osOutboundIp = detectActiveOutboundIp();

        List<InterfaceInfo> raw = new ArrayList<>();
        try {
            Enumeration<NetworkInterface> interfaces = NetworkInterface.getNetworkInterfaces();
            if (interfaces == null) {
                return List.of();
            }
            while (interfaces.hasMoreElements()) {
                NetworkInterface iface = interfaces.nextElement();
                if (!isCandidateInterface(iface)) {
                    continue;
                }
                String ifaceName = iface.getName();
                String gateway = gatewayByIface.get(ifaceName);

                for (InterfaceAddress ifAddr : iface.getInterfaceAddresses()) {
                    InetAddress addr = ifAddr.getAddress();
                    if (!(addr instanceof Inet4Address) || addr.isLoopbackAddress() || addr.isLinkLocalAddress()) {
                        continue;
                    }
                    String ip = addr.getHostAddress();
                    if (isIgnoredIp(ip)) {
                        continue;
                    }
                    String broadcast = ifAddr.getBroadcast() != null
                        ? ifAddr.getBroadcast().getHostAddress()
                        : computeFallbackBroadcast(ip);
                    String type = classifyInterface(ifaceName, ip, gateway);
                    boolean primary = ip.equals(osOutboundIp)
                        || (osOutboundIp == null && ifaceName.equals(defaultRouteIface));
                    raw.add(new InterfaceInfo(ifaceName, ip, broadcast, gateway, type, primary));
                }
            }
        } catch (Exception ignored) {
            // Best-effort network enumeration
        }

        // Trier : primary d'abord, puis hotspot/usb_tethering, puis wifi, puis ethernet, puis autres
        raw.sort(Comparator
            .comparing((InterfaceInfo i) -> !i.isPrimary())
            .thenComparingInt(i -> typePriority(i.type()))
            .thenComparing(InterfaceInfo::interfaceName));

        // S'assurer qu'au moins une interface est marquée primary si la liste n'est pas vide
        if (!raw.isEmpty() && raw.stream().noneMatch(InterfaceInfo::isPrimary)) {
            InterfaceInfo first = raw.get(0);
            raw.set(0, new InterfaceInfo(
                first.interfaceName(),
                first.ip(),
                first.broadcast(),
                first.gateway(),
                first.type(),
                true
            ));
        }

        return raw;
    }

    /**
     * Retourne uniquement la liste des adresses IPv4 locales triées par priorité.
     */
    public static List<String> getLocalIpAddresses() {
        List<String> ips = new ArrayList<>();
        for (InterfaceInfo info : getActiveInterfaces()) {
            if (!ips.contains(info.ip())) {
                ips.add(info.ip());
            }
        }
        return ips;
    }

    /**
     * Retourne l'adresse IPv4 principale du PC sur le réseau actif.
     */
    public static String getPrimaryIp(List<InterfaceInfo> interfaces) {
        if (interfaces.isEmpty()) {
            return "localhost";
        }
        for (InterfaceInfo info : interfaces) {
            if (info.isPrimary()) {
                return info.ip();
            }
        }
        return interfaces.get(0).ip();
    }

    /**
     * Retourne toutes les passerelles par défaut actives (sur point d'accès mobile,
     * la passerelle par défaut du PC EST l'adresse IP du téléphone).
     */
    public static Set<String> getDefaultGateways() {
        Set<String> gateways = new LinkedHashSet<>();
        for (RouteEntry entry : readLinuxDefaultRoutes()) {
            if (entry.gateway() != null && !entry.gateway().isBlank()) {
                gateways.add(entry.gateway());
            }
        }
        return gateways;
    }

    /**
     * Interroge la table de routage OS via un connect UDP sans envoi de paquet
     * pour connaître l'IP locale utilisée vers la passerelle par défaut.
     */
    private static String detectActiveOutboundIp() {
        String[] probes = {"1.1.1.1", "8.8.8.8"};
        for (String target : probes) {
            try (DatagramSocket socket = new DatagramSocket()) {
                socket.connect(InetAddress.getByName(target), 53);
                InetAddress local = socket.getLocalAddress();
                if (local instanceof Inet4Address
                    && !local.isLoopbackAddress()
                    && !local.isAnyLocalAddress()
                    && !local.isLinkLocalAddress()) {
                    String ip = local.getHostAddress();
                    if (!isIgnoredIp(ip)) {
                        return ip;
                    }
                }
            } catch (Exception ignored) {
                // Pas de route Internet active — on utilisera /proc/net/route
            }
        }
        return null;
    }

    /**
     * Lit /proc/net/route sur Linux pour obtenir la ou les passerelles par défaut
     * (fonctionne même quand le point d'accès du téléphone n'a pas de données mobiles actives).
     */
    private static List<RouteEntry> readLinuxDefaultRoutes() {
        Path routeFile = Path.of("/proc/net/route");
        if (!Files.isReadable(routeFile)) {
            return List.of();
        }
        List<RouteEntry> routes = new ArrayList<>();
        try {
            List<String> lines = Files.readAllLines(routeFile);
            for (int i = 1; i < lines.size(); i++) {
                String line = lines.get(i).trim();
                if (line.isEmpty()) continue;
                String[] parts = line.split("\\s+");
                if (parts.length < 8) continue;
                String iface = parts[0];
                String destination = parts[1];
                String gatewayHex = parts[2];
                int metric = 0;
                try {
                    metric = Integer.parseInt(parts[6]);
                } catch (NumberFormatException ignored) {}

                if ("00000000".equals(destination)
                    && !"00000000".equals(gatewayHex)
                    && !isIgnoredInterfaceName(iface)) {
                    String gw = parseProcRouteIp(gatewayHex);
                    if (gw != null) {
                        routes.add(new RouteEntry(iface, gw, metric));
                    }
                }
            }
        } catch (Exception ignored) {
            // Non-Linux ou accès restreint
        }
        routes.sort(Comparator.comparingInt(RouteEntry::metric));
        return routes;
    }

    static String parseProcRouteIp(String hex) {
        if (hex == null || hex.length() != 8) {
            return null;
        }
        try {
            long val = Long.parseLong(hex, 16);
            int b0, b1, b2, b3;
            if (ByteOrder.nativeOrder() == ByteOrder.LITTLE_ENDIAN) {
                b0 = (int) (val & 0xFF);
                b1 = (int) ((val >> 8) & 0xFF);
                b2 = (int) ((val >> 16) & 0xFF);
                b3 = (int) ((val >> 24) & 0xFF);
            } else {
                b0 = (int) ((val >> 24) & 0xFF);
                b1 = (int) ((val >> 16) & 0xFF);
                b2 = (int) ((val >> 8) & 0xFF);
                b3 = (int) (val & 0xFF);
            }
            return b0 + "." + b1 + "." + b2 + "." + b3;
        } catch (NumberFormatException e) {
            return null;
        }
    }

    private static boolean isCandidateInterface(NetworkInterface iface) {
        try {
            if (!iface.isUp() || iface.isLoopback() || iface.isVirtual() || iface.isPointToPoint()) {
                return false;
            }
            return !isIgnoredInterfaceName(iface.getName());
        } catch (Exception e) {
            return false;
        }
    }

    static boolean isIgnoredInterfaceName(String rawName) {
        if (rawName == null) return true;
        String name = rawName.toLowerCase(Locale.ROOT);
        return name.equals("lo")
            || name.startsWith("docker")
            || name.startsWith("br-")
            || name.startsWith("veth")
            || name.startsWith("virbr")
            || name.startsWith("vboxnet")
            || name.startsWith("vmnet")
            || name.startsWith("tun")
            || name.startsWith("tap")
            || name.startsWith("utun")
            || name.startsWith("wg")
            || name.startsWith("tailscale")
            || name.startsWith("cni")
            || name.startsWith("flannel")
            || name.startsWith("podman")
            || name.startsWith("kube")
            || name.startsWith("dummy");
    }

    private static boolean isIgnoredIp(String ip) {
        return ip.startsWith("127.")
            || ip.startsWith("169.254.")
            || ip.startsWith("172.17.");
    }

    private static String classifyInterface(String ifaceName, String ip, String gateway) {
        String name = ifaceName.toLowerCase(Locale.ROOT);
        // Point d'accès mobile connu (Android classique, iPhone)
        if (ip.startsWith("192.168.43.") || ip.startsWith("172.20.10.")) {
            return "hotspot";
        }
        // Partage USB Android (RNDIS)
        if (ip.startsWith("192.168.42.") || name.startsWith("usb") || name.startsWith("rndis")) {
            return "usb_tethering";
        }
        // Wi-Fi connecté à un point d'accès Android 11+ (sous-réseau aléatoire 10.x.y.z
        // ou passerelle avec dernier octet non standard différent de .1 et .254)
        boolean isWifi = name.startsWith("wl") || name.startsWith("wi") || name.contains("wlan");
        if (isWifi) {
            if (gateway != null) {
                boolean unusualGatewayOctet = !gateway.endsWith(".1") && !gateway.endsWith(".254");
                if (unusualGatewayOctet || (ip.startsWith("10.") && !ip.startsWith("10.0.0."))) {
                    return "hotspot";
                }
            }
            return "wifi";
        }
        if (name.startsWith("en") || name.startsWith("eth")) {
            return "ethernet";
        }
        return "other";
    }

    private static int typePriority(String type) {
        return switch (type) {
            case "hotspot" -> 0;
            case "usb_tethering" -> 1;
            case "wifi" -> 2;
            case "ethernet" -> 3;
            default -> 4;
        };
    }

    static String computeFallbackBroadcast(String ip) {
        if (ip.startsWith("172.20.10.")) {
            return "172.20.10.15";
        }
        int lastDot = ip.lastIndexOf('.');
        if (lastDot > 0) {
            return ip.substring(0, lastDot) + ".255";
        }
        return "255.255.255.255";
    }
}

