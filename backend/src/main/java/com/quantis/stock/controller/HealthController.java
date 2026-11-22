package com.quantis.stock.controller;

import com.quantis.stock.dto.ApiResponse;
import com.quantis.stock.network.NetworkUtils;
import org.springframework.beans.factory.annotation.Value;
import org.springframework.web.bind.annotation.GetMapping;
import org.springframework.web.bind.annotation.RestController;

import java.time.Instant;
import java.util.LinkedHashMap;
import java.util.List;
import java.util.Map;

/**
 * Contrôleur de vérification de santé et informations réseau de l'API.
 */
@RestController
public class HealthController {

    @Value("${server.port:8080}")
    private int serverPort;

    @Value("${server.servlet.context-path:/api/v1}")
    private String contextPath;

    @Value("${app.discovery.udp-port:45808}")
    private int discoveryPort;

    @GetMapping({"/health", "/auth/health", "/network/info"})
    public ApiResponse<Map<String, Object>> health() {
        List<NetworkUtils.InterfaceInfo> interfaces = NetworkUtils.getActiveInterfaces();
        List<String> ips = interfaces.stream().map(NetworkUtils.InterfaceInfo::ip).distinct().toList();
        String primaryIp = NetworkUtils.getPrimaryIp(interfaces);

        Map<String, Object> data = new LinkedHashMap<>();
        data.put("status", "UP");
        data.put("application", "Quantis Stock API");
        data.put("version", "1.0.0");
        data.put("timestamp", Instant.now().toString());
        data.put("port", serverPort);
        data.put("discoveryPort", discoveryPort);
        data.put("primaryIp", primaryIp);
        data.put("localIps", ips);
        data.put("interfaces", interfaces.stream().map(NetworkUtils.InterfaceInfo::toMap).toList());
        data.put("webUrl", "http://" + primaryIp + ":3000");
        data.put("apiUrl", "http://" + primaryIp + ":" + serverPort + contextPath);

        return ApiResponse.success(data);
    }
}
