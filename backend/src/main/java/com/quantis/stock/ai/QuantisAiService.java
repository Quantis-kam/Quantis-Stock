package com.quantis.stock.ai;

import com.fasterxml.jackson.databind.JsonNode;
import com.fasterxml.jackson.databind.ObjectMapper;
import com.fasterxml.jackson.databind.node.ArrayNode;
import com.fasterxml.jackson.databind.node.ObjectNode;
import com.quantis.stock.ai.dto.ChatRequest;
import com.quantis.stock.ai.dto.ChatResponse;
import lombok.RequiredArgsConstructor;
import lombok.extern.slf4j.Slf4j;
import org.springframework.stereotype.Service;

import java.math.BigDecimal;
import java.net.URI;
import java.net.http.HttpClient;
import java.net.http.HttpRequest;
import java.net.http.HttpResponse;
import java.time.Duration;
import java.time.Instant;
import java.util.*;
import java.util.concurrent.ConcurrentHashMap;

/**
 * Service principal de Quantis AI.
 *
 * Orchestre le flux complet :
 * 1. Construit le prompt système avec contexte métier
 * 2. Envoie la requête au LLM (Gemini, OpenAI ou Ollama)
 * 3. Gère le function calling (appels d'outils)
 * 4. Retourne une réponse enrichie au frontend
 */
@Slf4j
@Service
@RequiredArgsConstructor
public class QuantisAiService {

    private final QuantisAiConfig config;
    private final QuantisPromptBuilder promptBuilder;
    private final QuantisToolExecutor toolExecutor;
    private final ObjectMapper objectMapper;

    /** Cache des historiques de conversation (en mémoire, à remplacer par DB en prod) */
    private final Map<String, List<Map<String, String>>> conversationHistory = new ConcurrentHashMap<>();

    private final HttpClient httpClient = HttpClient.newBuilder()
            .connectTimeout(Duration.ofSeconds(10))
            .build();

    /**
     * Traite un message utilisateur et retourne la réponse de Quantis.
     */
    public ChatResponse chat(ChatRequest request, String userEmail) {
        if (!config.isEnabled()) {
            return ChatResponse.builder()
                    .message("L'assistant Quantis est désactivé. Activez-le dans la configuration.")
                    .type(ChatResponse.ResponseType.ERROR)
                    .build();
        }

        String conversationId = request.getConversationId();
        if (conversationId == null || conversationId.isBlank()) {
            conversationId = UUID.randomUUID().toString();
        }

        try {
            // Récupérer ou créer l'historique de conversation
            List<Map<String, String>> history = conversationHistory.computeIfAbsent(
                    conversationId, k -> new ArrayList<>());

            // Ajouter le message de l'utilisateur
            history.add(Map.of("role", "user", "content", request.getMessage()));

            // Tronquer l'historique si nécessaire
            if (history.size() > config.getMaxHistoryMessages()) {
                history = new ArrayList<>(history.subList(
                        history.size() - config.getMaxHistoryMessages(), history.size()));
                conversationHistory.put(conversationId, history);
            }

            String response;
            // Si aucune clé API n'est fournie pour un provider cloud, basculer sur le moteur expert local
            if (isCloudWithoutKey()) {
                response = handleOfflineFallback(request.getMessage(), userEmail);
            } else {
                try {
                    // Appeler le LLM avec function calling
                    response = callLlmWithTools(history, userEmail);
                } catch (Exception llmEx) {
                    log.warn("Appel LLM échoué ({}), bascule sur moteur expert local", llmEx.getMessage());
                    response = handleOfflineFallback(request.getMessage(), userEmail);
                }
            }

            // Ajouter la réponse à l'historique
            history.add(Map.of("role", "assistant", "content", response));

            // Construire les suggestions contextuelles
            List<String> suggestions = generateSuggestions(request.getMessage());

            return ChatResponse.builder()
                    .message(response)
                    .conversationId(conversationId)
                    .timestamp(Instant.now())
                    .type(ChatResponse.ResponseType.TEXT)
                    .suggestions(suggestions)
                    .build();

        } catch (Exception e) {
            log.error("Erreur Quantis AI: {}", e.getMessage(), e);
            return ChatResponse.builder()
                    .message("Désolé, une erreur est survenue. Veuillez réessayer. 🔄")
                    .conversationId(conversationId)
                    .type(ChatResponse.ResponseType.ERROR)
                    .build();
        }
    }

    private boolean isCloudWithoutKey() {
        return ("gemini".equalsIgnoreCase(config.getProvider()) || "openai".equalsIgnoreCase(config.getProvider()))
                && (config.getApiKey() == null || config.getApiKey().isBlank());
    }

    /**
     * Moteur de réponse expert local (déterministe et ultra-rapide)
     * Fonctionne 100% hors-ligne même sans clé API ou sans internet.
     * Priorise l'exécution des actions réelles sur les requêtes de consultation.
     */
    private String handleOfflineFallback(String userMessage, String userEmail) {
        String msg = userMessage.toLowerCase().trim();

        // ─────────────────────────────────────────────────────────────
        // 1. ACTIONS DE STOCK & GESTION (PRIORITÉ ABSOLUE)
        // ─────────────────────────────────────────────────────────────

        // A. Entrée de stock / Réapprovisionnement / Ajout en stock
        if (msg.contains("reapprovisionnement") || msg.contains("réapprovisionnement")
                || msg.contains("entrée") || msg.contains("entree")
                || msg.contains("approvisionnement") || msg.contains("reception")
                || (msg.contains("ajoute") && (msg.contains("quantit") || msg.contains("stock")))) {

            BigDecimal quantity = extractQuantity(userMessage, BigDecimal.valueOf(100));
            String productName = extractProductName(userMessage);

            if (productName.isBlank()) {
                productName = "Produit Standard";
            }

            // Trouver ou créer le produit
            com.quantis.stock.model.Produit produit = toolExecutor.findOrCreateProduct(
                    productName, BigDecimal.valueOf(500), BigDecimal.valueOf(1000));

            // Enregistrer l'entrée de stock
            String argsJson = "{\"product_id\":" + produit.getId() + ",\"quantity\":" + quantity + ",\"comment\":\"Réapprovisionnement via Quantis AI\"}";
            QuantisToolExecutor.ToolResult result = toolExecutor.execute("stock_entry", argsJson, userEmail);

            return "🎉 **Action exécutée par Quantis :**\n\n"
                 + result.content() + "\n\n"
                 + "💡 *Le niveau de stock a été actualisé en temps réel dans votre application.*";
        }

        // B. Sortie de stock / Vente / Retrait
        if (msg.contains("sortie") || msg.contains("retire") || msg.contains("retrait")
                || (msg.contains("vendre") && msg.contains("quantit"))) {

            BigDecimal quantity = extractQuantity(userMessage, BigDecimal.valueOf(1));
            String productName = extractProductName(userMessage);

            if (!productName.isBlank()) {
                com.quantis.stock.model.Produit produit = toolExecutor.findOrCreateProduct(
                        productName, BigDecimal.valueOf(500), BigDecimal.valueOf(1000));
                String argsJson = "{\"product_id\":" + produit.getId() + ",\"quantity\":" + quantity + ",\"comment\":\"Sortie via Quantis AI\"}";
                QuantisToolExecutor.ToolResult result = toolExecutor.execute("stock_exit", argsJson, userEmail);
                return "📉 **Action de sortie exécutée :**\n\n" + result.content();
            }
        }

        // C. Ajustement de stock / Inventaire
        if (msg.contains("ajust") || msg.contains("inventaire") || msg.contains("régularise")) {
            BigDecimal quantity = extractQuantity(userMessage, BigDecimal.ZERO);
            String productName = extractProductName(userMessage);

            if (!productName.isBlank()) {
                com.quantis.stock.model.Produit produit = toolExecutor.findOrCreateProduct(
                        productName, BigDecimal.valueOf(500), BigDecimal.valueOf(1000));
                String argsJson = "{\"product_id\":" + produit.getId() + ",\"new_quantity\":" + quantity + "}";
                QuantisToolExecutor.ToolResult result = toolExecutor.execute("stock_adjustment", argsJson, userEmail);
                return "⚖️ **Ajustement d'inventaire appliqué :**\n\n" + result.content();
            }
        }

        // D. Création de produit seule
        if ((msg.contains("créer") || msg.contains("creer") || msg.contains("nouveau produit") || msg.contains("ajoute produit"))
                && !msg.contains("stock")) {
            String productName = extractProductName(userMessage);
            if (!productName.isBlank()) {
                com.quantis.stock.model.Produit produit = toolExecutor.findOrCreateProduct(
                        productName, BigDecimal.valueOf(500), BigDecimal.valueOf(1000));
                return "✅ **Produit créé avec succès dans le catalogue !**\n\n"
                     + "- **Nom** : " + produit.getNom() + "\n"
                     + "- **SKU** : `" + produit.getSku() + "`\n"
                     + "- **Prix de vente** : " + produit.getPrixVente() + " FCFA\n"
                     + "- **Seuil d'alerte** : " + produit.getSeuilAlerte() + " unités";
            }
        }

        // ─────────────────────────────────────────────────────────────
        // 2. REQUÊTES DE CONSULTATION & DIAGNOSTIC
        // ─────────────────────────────────────────────────────────────

        if (msg.contains("bonjour") || msg.contains("salut") || msg.contains("coucou") || msg.contains("hello")) {
            return "Bonjour ! Je suis **Quantis**, votre assistant expert en gestion de stock et logistique. 📦✨\n\n"
                 + "Je suis connecté à votre base de données en direct. Que souhaitez-vous savoir ou effectuer aujourd'hui ?";
        }

        if (msg.contains("rupture")) {
            QuantisToolExecutor.ToolResult res = toolExecutor.execute("get_stock_ruptures", "{}", userEmail);
            return res.content();
        }

        if (msg.contains("alerte") || msg.contains("stock bas") || msg.contains("seuil")) {
            QuantisToolExecutor.ToolResult res = toolExecutor.execute("get_stock_alerts", "{}", userEmail);
            return res.content();
        }

        if (msg.contains("patrimoine") || msg.contains("valeur") || msg.contains("créance") || msg.contains("dette")) {
            QuantisToolExecutor.ToolResult res = toolExecutor.execute("get_patrimoine", "{}", userEmail);
            return res.content();
        }

        if (msg.contains("vente") || msg.contains("chiffre d'affaires") || msg.contains("ca") || msg.contains("marge")) {
            QuantisToolExecutor.ToolResult res = toolExecutor.execute("get_ventes_par_mois", "{}", userEmail);
            return res.content();
        }

        if (msg.contains("stock") || msg.contains("comment va") || msg.contains("tableau de bord") || msg.contains("kpi") || msg.contains("état")) {
            QuantisToolExecutor.ToolResult kpis = toolExecutor.execute("get_dashboard_kpis", "{}", userEmail);
            QuantisToolExecutor.ToolResult alertes = toolExecutor.execute("get_stock_alerts", "{}", userEmail);
            QuantisToolExecutor.ToolResult ruptures = toolExecutor.execute("get_stock_ruptures", "{}", userEmail);

            return "Voici l'état actuel de votre stock et de votre activité :\n\n"
                 + kpis.content() + "\n\n"
                 + alertes.content() + "\n\n"
                 + ruptures.content();
        }

        if (msg.contains("produit") || msg.contains("catalogue") || msg.contains("recherche") || msg.contains("article")) {
            String query = msg.replaceAll("(?i)(recherche|trouve|cherche|les|le|la|un|des|produit|produits|catalogue)", "").trim();
            if (query.length() >= 2) {
                QuantisToolExecutor.ToolResult search = toolExecutor.execute("search_products", "{\"query\":\"" + query + "\"}", userEmail);
                return search.content();
            }
            QuantisToolExecutor.ToolResult kpis = toolExecutor.execute("get_dashboard_kpis", "{}", userEmail);
            return "Vous pouvez me demander de rechercher un produit spécifique (ex: *« Recherche ciment »* ou *« Trouver sac »*).\n\n" + kpis.content();
        }

        // Réponse générale
        QuantisToolExecutor.ToolResult kpis = toolExecutor.execute("get_dashboard_kpis", "{}", userEmail);
        return "Je suis à votre disposition pour vous assister. Voici un résumé rapide de votre activité :\n\n"
             + kpis.content() + "\n\n"
             + "💡 *Vous pouvez me demander :*\n"
             + "- *« Réapprovisionnement de 500 unités pour Lait Bonnet Rouge »*\n"
             + "- *« Comment va mon stock ? »*\n"
             + "- *« Y a-t-il des ruptures de stock ? »*\n"
             + "- *« Quel est le patrimoine de l'entreprise ? »*";
    }

    /**
     * Extrait une quantité numérique depuis une phrase en français.
     */
    private BigDecimal extractQuantity(String text, BigDecimal defaultValue) {
        java.util.regex.Pattern pattern = java.util.regex.Pattern.compile("(?:quantit[eé]|de|valeur|stock|quantite)?\\s*(?:de\\s*)?([0-9]+(?:[\\.,][0-9]+)?)");
        java.util.regex.Matcher matcher = pattern.matcher(text);

        BigDecimal lastFound = null;
        while (matcher.find()) {
            try {
                String val = matcher.group(1).replace(",", ".");
                BigDecimal bd = new BigDecimal(val);
                if (bd.compareTo(BigDecimal.ZERO) > 0) {
                    lastFound = bd;
                }
            } catch (Exception ignored) {}
        }
        return lastFound != null ? lastFound : defaultValue;
    }

    /**
     * Extrait le nom potentiel du produit depuis une commande utilisateur.
     */
    private String extractProductName(String text) {
        String clean = text;
        // Supprimer les préfixes d'action
        clean = clean.replaceAll("(?i)^.*?(ajoute|créer|creer|reapprovisionnement|réapprovisionnement|entree|entrée|sortie|retire|ajustement|ajuste)\\s+(un\\s+)?(nouveau\\s+)?(produit\\s+)?(en\\s+stock\\s+)?(de\\s+)?", "");
        // Supprimer les suffixes de quantité
        clean = clean.replaceAll("(?i)[,;]?\\s*(reapprovisionnement|réapprovisionnement|d'une|dune|quantit[eé]|avec|pour|de|quantite|au|prix).*$", "");
        // Nettoyer espaces
        clean = clean.replaceAll("(?i)(en stock|produit)", "").trim();

        if (clean.length() < 2) {
            // Fallback : rechercher des mots connus comme Lait, Ciment, Sac, etc.
            java.util.regex.Matcher m = java.util.regex.Pattern.compile("(?i)(Lait[\\w\\s\\d]+|Riz[\\w\\s\\d]+|Huile[\\w\\s\\d]+|Sucre[\\w\\s\\d]+|Savon[\\w\\s\\d]+)").matcher(text);
            if (m.find()) return m.group(1).trim();
        }

        return clean.isEmpty() ? "Lait Bonnet Rouge 400g" : clean;
    }

    /**
     * Appelle le LLM avec les outils disponibles et gère les boucles de function calling.
     */
    private String callLlmWithTools(List<Map<String, String>> history, String userEmail) throws Exception {
        String systemPrompt = promptBuilder.buildSystemPrompt();
        int maxIterations = 5; // Limite anti-boucle infinie

        for (int i = 0; i < maxIterations; i++) {
            String responseJson = switch (config.getProvider()) {
                case "gemini" -> callGemini(systemPrompt, history);
                case "openai" -> callOpenAI(systemPrompt, history);
                case "ollama" -> callOllama(systemPrompt, history);
                default -> throw new IllegalArgumentException("Provider inconnu: " + config.getProvider());
            };

            // Parser la réponse
            JsonNode root = objectMapper.readTree(responseJson);

            // Vérifier s'il y a des function calls
            List<ToolCallInfo> toolCalls = extractToolCalls(root);

            if (toolCalls.isEmpty()) {
                // Pas de function call — extraire le texte final
                return extractTextResponse(root);
            }

            // Exécuter les function calls
            for (ToolCallInfo tc : toolCalls) {
                QuantisToolExecutor.ToolResult result = toolExecutor.execute(tc.name, tc.arguments, userEmail);

                // Ajouter le résultat à l'historique pour le tour suivant
                history.add(Map.of(
                        "role", "assistant",
                        "content", "[Appel outil: " + tc.name + "]"
                ));
                history.add(Map.of(
                        "role", "user",
                        "content", "Résultat de l'outil " + tc.name + " :\n" + result.content()
                ));
            }
        }

        return "J'ai atteint la limite d'actions pour cette requête. Pouvez-vous reformuler votre demande ?";
    }

    // ═══════════════════════════════════════════════════
    // PROVIDERS
    // ═══════════════════════════════════════════════════

    private String callGemini(String systemPrompt, List<Map<String, String>> history) throws Exception {
        String url = "https://generativelanguage.googleapis.com/v1beta/models/"
                + config.getModel() + ":generateContent?key=" + config.getApiKey();

        ObjectNode body = objectMapper.createObjectNode();

        // System instruction
        ObjectNode systemInstruction = objectMapper.createObjectNode();
        ObjectNode systemPart = objectMapper.createObjectNode();
        systemPart.put("text", systemPrompt);
        systemInstruction.set("parts", objectMapper.createArrayNode().add(systemPart));
        body.set("system_instruction", systemInstruction);

        // Contents (historique de conversation)
        ArrayNode contents = objectMapper.createArrayNode();
        for (Map<String, String> msg : history) {
            ObjectNode content = objectMapper.createObjectNode();
            String role = msg.get("role").equals("assistant") ? "model" : "user";
            content.put("role", role);
            ObjectNode part = objectMapper.createObjectNode();
            part.put("text", msg.get("content"));
            content.set("parts", objectMapper.createArrayNode().add(part));
            contents.add(content);
        }
        body.set("contents", contents);

        // Tools (function declarations)
        ArrayNode toolsArray = objectMapper.createArrayNode();
        ObjectNode toolsObj = objectMapper.createObjectNode();
        ArrayNode funcDeclarations = objectMapper.createArrayNode();
        for (Map<String, Object> toolDef : toolExecutor.getToolDefinitions()) {
            funcDeclarations.add(objectMapper.valueToTree(toolDef));
        }
        toolsObj.set("function_declarations", funcDeclarations);
        toolsArray.add(toolsObj);
        body.set("tools", toolsArray);

        // Generation config
        ObjectNode genConfig = objectMapper.createObjectNode();
        genConfig.put("temperature", config.getTemperature());
        genConfig.put("maxOutputTokens", config.getMaxTokens());
        body.set("generationConfig", genConfig);

        return httpPost(url, body.toString());
    }

    private String callOpenAI(String systemPrompt, List<Map<String, String>> history) throws Exception {
        String url = "https://api.openai.com/v1/chat/completions";

        ObjectNode body = objectMapper.createObjectNode();
        body.put("model", config.getModel());
        body.put("temperature", config.getTemperature());
        body.put("max_tokens", config.getMaxTokens());

        // Messages
        ArrayNode messages = objectMapper.createArrayNode();
        ObjectNode sysMsg = objectMapper.createObjectNode();
        sysMsg.put("role", "system");
        sysMsg.put("content", systemPrompt);
        messages.add(sysMsg);

        for (Map<String, String> msg : history) {
            ObjectNode m = objectMapper.createObjectNode();
            m.put("role", msg.get("role"));
            m.put("content", msg.get("content"));
            messages.add(m);
        }
        body.set("messages", messages);

        // Tools
        ArrayNode tools = objectMapper.createArrayNode();
        for (Map<String, Object> toolDef : toolExecutor.getToolDefinitions()) {
            ObjectNode tool = objectMapper.createObjectNode();
            tool.put("type", "function");
            tool.set("function", objectMapper.valueToTree(toolDef));
            tools.add(tool);
        }
        body.set("tools", tools);

        HttpRequest request = HttpRequest.newBuilder()
                .uri(URI.create(url))
                .header("Content-Type", "application/json")
                .header("Authorization", "Bearer " + config.getApiKey())
                .timeout(Duration.ofSeconds(config.getTimeoutSeconds()))
                .POST(HttpRequest.BodyPublishers.ofString(body.toString()))
                .build();

        HttpResponse<String> response = httpClient.send(request, HttpResponse.BodyHandlers.ofString());
        return response.body();
    }

    private String callOllama(String systemPrompt, List<Map<String, String>> history) throws Exception {
        String url = config.getOllamaHost() + "/api/chat";

        ObjectNode body = objectMapper.createObjectNode();
        body.put("model", config.getOllamaModel());
        body.put("stream", false);

        ArrayNode messages = objectMapper.createArrayNode();
        ObjectNode sysMsg = objectMapper.createObjectNode();
        sysMsg.put("role", "system");
        sysMsg.put("content", systemPrompt);
        messages.add(sysMsg);

        for (Map<String, String> msg : history) {
            ObjectNode m = objectMapper.createObjectNode();
            m.put("role", msg.get("role"));
            m.put("content", msg.get("content"));
            messages.add(m);
        }
        body.set("messages", messages);

        // Ollama tools format
        ArrayNode tools = objectMapper.createArrayNode();
        for (Map<String, Object> toolDef : toolExecutor.getToolDefinitions()) {
            ObjectNode tool = objectMapper.createObjectNode();
            tool.put("type", "function");
            ObjectNode func = objectMapper.createObjectNode();
            func.put("name", toolDef.get("name").toString());
            func.put("description", toolDef.get("description").toString());
            func.set("parameters", objectMapper.valueToTree(toolDef.get("parameters")));
            tool.set("function", func);
            tools.add(tool);
        }
        body.set("tools", tools);

        ObjectNode options = objectMapper.createObjectNode();
        options.put("temperature", config.getTemperature());
        options.put("num_predict", config.getMaxTokens());
        body.set("options", options);

        return httpPost(url, body.toString());
    }

    // ═══════════════════════════════════════════════════
    // PARSING DES RÉPONSES
    // ═══════════════════════════════════════════════════

    private record ToolCallInfo(String name, String arguments) {}

    private List<ToolCallInfo> extractToolCalls(JsonNode root) {
        List<ToolCallInfo> calls = new ArrayList<>();

        // Gemini format
        JsonNode candidates = root.path("candidates");
        if (candidates.isArray() && !candidates.isEmpty()) {
            JsonNode parts = candidates.get(0).path("content").path("parts");
            if (parts.isArray()) {
                for (JsonNode part : parts) {
                    if (part.has("functionCall")) {
                        JsonNode fc = part.get("functionCall");
                        calls.add(new ToolCallInfo(
                                fc.get("name").asText(),
                                fc.has("args") ? fc.get("args").toString() : "{}"
                        ));
                    }
                }
            }
        }

        // OpenAI format
        JsonNode choices = root.path("choices");
        if (choices.isArray() && !choices.isEmpty()) {
            JsonNode message = choices.get(0).path("message");
            JsonNode toolCalls = message.path("tool_calls");
            if (toolCalls.isArray()) {
                for (JsonNode tc : toolCalls) {
                    JsonNode func = tc.path("function");
                    calls.add(new ToolCallInfo(
                            func.get("name").asText(),
                            func.get("arguments").asText()
                    ));
                }
            }
        }

        // Ollama format
        JsonNode ollamaMessage = root.path("message");
        if (ollamaMessage.has("tool_calls")) {
            JsonNode toolCalls = ollamaMessage.get("tool_calls");
            if (toolCalls.isArray()) {
                for (JsonNode tc : toolCalls) {
                    JsonNode func = tc.path("function");
                    calls.add(new ToolCallInfo(
                            func.get("name").asText(),
                            func.has("arguments") ? func.get("arguments").toString() : "{}"
                    ));
                }
            }
        }

        return calls;
    }

    private String extractTextResponse(JsonNode root) {
        String text = null;
        // Gemini
        JsonNode candidates = root.path("candidates");
        if (candidates.isArray() && !candidates.isEmpty()) {
            JsonNode parts = candidates.get(0).path("content").path("parts");
            if (parts.isArray() && !parts.isEmpty()) {
                JsonNode t = parts.get(0).path("text");
                if (!t.isMissingNode()) text = t.asText();
            }
        }

        // OpenAI
        if (text == null) {
            JsonNode choices = root.path("choices");
            if (choices.isArray() && !choices.isEmpty()) {
                JsonNode content = choices.get(0).path("message").path("content");
                if (!content.isMissingNode() && !content.isNull()) text = content.asText();
            }
        }

        // Ollama
        if (text == null) {
            JsonNode ollamaContent = root.path("message").path("content");
            if (!ollamaContent.isMissingNode() && !ollamaContent.isNull()) text = ollamaContent.asText();
        }

        // Erreur API
        JsonNode error = root.path("error");
        if (!error.isMissingNode()) {
            log.error("Erreur API LLM: {}", error);
            return "Désolé, je rencontre un problème technique avec le modèle d'IA. Veuillez vérifier la configuration. 🔧";
        }

        if (text != null && !text.isBlank()) {
            // Nettoyer les balises <think>...</think> générées par certains modèles (ex: Qwen / DeepSeek)
            text = text.replaceAll("(?s)<think>.*?</think>", "").trim();
            return text;
        }

        return "Je n'ai pas pu générer de réponse. Veuillez réessayer.";
    }

    // ═══════════════════════════════════════════════════
    // SUGGESTIONS CONTEXTUELLES
    // ═══════════════════════════════════════════════════

    private List<String> generateSuggestions(String userMessage) {
        String lower = userMessage.toLowerCase();

        if (lower.contains("stock") || lower.contains("rupture") || lower.contains("alerte")) {
            return List.of(
                "📊 Afficher le tableau de bord complet",
                "⚠️ Voir les produits en alerte",
                "📦 Rechercher un produit"
            );
        }
        if (lower.contains("produit") || lower.contains("article") || lower.contains("catalogue")) {
            return List.of(
                "➕ Ajouter un nouveau produit",
                "🔍 Rechercher dans le catalogue",
                "📊 Voir les niveaux de stock"
            );
        }
        if (lower.contains("vente") || lower.contains("chiffre") || lower.contains("ca")) {
            return List.of(
                "📈 Ventes par mois",
                "💰 Valeur du patrimoine",
                "📊 KPIs du mois"
            );
        }

        // Suggestions par défaut
        return List.of(
            "📊 Comment va mon stock ?",
            "⚠️ Y a-t-il des ruptures ?",
            "💰 Quel est mon chiffre d'affaires ?"
        );
    }

    /**
     * Efface l'historique d'une conversation.
     */
    public void clearConversation(String conversationId) {
        conversationHistory.remove(conversationId);
    }

    // ═══════════════════════════════════════════════════
    // HTTP
    // ═══════════════════════════════════════════════════

    private String httpPost(String url, String jsonBody) throws Exception {
        HttpRequest request = HttpRequest.newBuilder()
                .uri(URI.create(url))
                .header("Content-Type", "application/json")
                .timeout(Duration.ofSeconds(config.getTimeoutSeconds()))
                .POST(HttpRequest.BodyPublishers.ofString(jsonBody))
                .build();

        HttpResponse<String> response = httpClient.send(request, HttpResponse.BodyHandlers.ofString());

        if (response.statusCode() >= 400) {
            log.error("Erreur HTTP {} de l'API LLM: {}", response.statusCode(), response.body());
            throw new RuntimeException("Erreur API LLM (HTTP " + response.statusCode() + ")");
        }

        return response.body();
    }
}
