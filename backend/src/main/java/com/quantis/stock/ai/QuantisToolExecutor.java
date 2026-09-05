package com.quantis.stock.ai;

import com.fasterxml.jackson.core.type.TypeReference;
import com.fasterxml.jackson.databind.ObjectMapper;
import com.quantis.stock.dto.MouvementRequest;
import com.quantis.stock.dto.ProduitRequest;
import com.quantis.stock.model.*;
import com.quantis.stock.model.enums.MotifMouvement;
import com.quantis.stock.model.enums.TypeMouvement;
import com.quantis.stock.service.*;
import lombok.RequiredArgsConstructor;
import lombok.extern.slf4j.Slf4j;
import com.quantis.stock.repository.DepotRepository;
import com.quantis.stock.repository.ProduitRepository;
import org.springframework.data.domain.Page;
import org.springframework.data.domain.PageRequest;
import org.springframework.stereotype.Component;

import java.math.BigDecimal;
import java.util.*;

/**
 * Exécute les appels d'outils (function calls) demandés par l'IA
 * en les routant vers les services métier Spring existants.
 *
 * Ce composant fait le pont entre le modèle IA (qui génère des appels d'outils JSON)
 * et les vrais services backend de Quantis Stock.
 */
@Slf4j
@Component
@RequiredArgsConstructor
public class QuantisToolExecutor {

    private final DashboardService dashboardService;
    private final StockService stockService;
    private final ProduitService produitService;
    private final CategorieService categorieService;
    private final ProduitRepository produitRepository;
    private final DepotRepository depotRepository;
    private final ObjectMapper objectMapper;

    /**
     * Exécute un appel d'outil et retourne le résultat sous forme de texte.
     *
     * @param toolName   Nom de l'outil à exécuter
     * @param argsJson   Arguments au format JSON
     * @param userEmail  Email de l'utilisateur connecté (pour les actions)
     * @return Résultat textuel de l'exécution
     */
    public ToolResult execute(String toolName, String argsJson, String userEmail) {
        try {
            Map<String, Object> args = parseArgs(argsJson);
            log.info("Exécution outil '{}' avec args: {}", toolName, args);

            return switch (toolName) {
                // ── Consultation ──
                case "get_dashboard_kpis" -> getDashboardKpis();
                case "get_stock_alerts" -> getStockAlerts();
                case "get_stock_ruptures" -> getStockRuptures();
                case "search_products" -> searchProducts(args);
                case "get_product_details" -> getProductDetails(args);
                case "get_stock_by_product" -> getStockByProduct(args);
                case "get_patrimoine" -> getPatrimoine();
                case "get_ventes_par_mois" -> getVentesParMois(args);

                // ── Actions ──
                case "create_product" -> createProduct(args);
                case "stock_entry" -> stockEntry(args, userEmail);
                case "stock_exit" -> stockExit(args, userEmail);
                case "stock_adjustment" -> stockAdjustment(args, userEmail);

                default -> ToolResult.error("Outil inconnu : " + toolName);
            };
        } catch (Exception e) {
            log.error("Erreur lors de l'exécution de l'outil '{}': {}", toolName, e.getMessage(), e);
            return ToolResult.error("Erreur lors de l'exécution : " + e.getMessage());
        }
    }

    /**
     * Retourne la liste des outils disponibles au format JSON Schema
     * (compatible avec le function calling de Gemini/OpenAI).
     */
    public List<Map<String, Object>> getToolDefinitions() {
        return List.of(
            toolDef("get_dashboard_kpis",
                "Récupère les KPIs du tableau de bord : CA, alertes stock, ruptures, nombre de produits/clients/fournisseurs",
                Map.of()),

            toolDef("get_stock_alerts",
                "Liste les produits dont le stock est en dessous du seuil d'alerte",
                Map.of()),

            toolDef("get_stock_ruptures",
                "Liste les produits en rupture de stock (quantité = 0)",
                Map.of()),

            toolDef("search_products",
                "Recherche des produits par nom, SKU ou code-barres",
                Map.of("query", propDef("string", "Terme de recherche (nom, SKU, ou code-barres)"))),

            toolDef("get_product_details",
                "Récupère les détails complets d'un produit par son ID",
                Map.of("product_id", propDef("integer", "ID du produit"))),

            toolDef("get_stock_by_product",
                "Affiche les niveaux de stock par dépôt pour un produit donné",
                Map.of("product_id", propDef("integer", "ID du produit"))),

            toolDef("get_patrimoine",
                "Calcule la valeur du patrimoine : stock + caisses + créances - dettes fournisseurs",
                Map.of()),

            toolDef("get_ventes_par_mois",
                "Récupère les ventes et dépenses par mois pour une année donnée",
                Map.of("year", propDef("integer", "Année (ex: 2026)"))),

            toolDef("create_product",
                "Crée un nouveau produit dans le catalogue",
                Map.of(
                    "sku", propDef("string", "Code SKU unique du produit"),
                    "nom", propDef("string", "Nom du produit"),
                    "prix_achat", propDef("number", "Prix d'achat en FCFA"),
                    "prix_vente", propDef("number", "Prix de vente en FCFA"),
                    "description", propDef("string", "Description du produit (optionnel)"),
                    "seuil_alerte", propDef("integer", "Seuil d'alerte de stock bas (défaut: 10)")
                )),

            toolDef("stock_entry",
                "Enregistre une entrée de stock (réception de marchandises)",
                Map.of(
                    "product_id", propDef("integer", "ID du produit"),
                    "quantity", propDef("number", "Quantité à ajouter"),
                    "depot_id", propDef("integer", "ID du dépôt de destination"),
                    "comment", propDef("string", "Commentaire (optionnel)")
                )),

            toolDef("stock_exit",
                "Enregistre une sortie de stock",
                Map.of(
                    "product_id", propDef("integer", "ID du produit"),
                    "quantity", propDef("number", "Quantité à retirer"),
                    "depot_id", propDef("integer", "ID du dépôt source"),
                    "comment", propDef("string", "Commentaire (optionnel)")
                )),

            toolDef("stock_adjustment",
                "Ajuste le stock d'un produit à une quantité précise (inventaire)",
                Map.of(
                    "product_id", propDef("integer", "ID du produit"),
                    "new_quantity", propDef("number", "Nouvelle quantité"),
                    "depot_id", propDef("integer", "ID du dépôt"),
                    "comment", propDef("string", "Commentaire (optionnel)")
                ))
        );
    }

    // ═══════════════════════════════════════════════════
    // IMPLÉMENTATIONS DES OUTILS
    // ═══════════════════════════════════════════════════

    private ToolResult getDashboardKpis() {
        Map<String, Object> kpis = dashboardService.getKpis();
        return ToolResult.success(formatKpis(kpis));
    }

    private ToolResult getStockAlerts() {
        List<StockCourant> alertes = stockService.getAlertesBasses();
        if (alertes.isEmpty()) {
            return ToolResult.success("✅ Aucune alerte de stock bas. Tous les produits sont au-dessus de leur seuil.");
        }
        StringBuilder sb = new StringBuilder("⚠️ **Alertes de stock bas** (" + alertes.size() + " produit(s)) :\n\n");
        sb.append("| Produit | SKU | Stock actuel | Seuil | Dépôt |\n");
        sb.append("|---------|-----|:------------:|:-----:|-------|\n");
        for (StockCourant sc : alertes) {
            sb.append("| ").append(sc.getProduit().getNom())
              .append(" | ").append(sc.getProduit().getSku())
              .append(" | ").append(sc.getQuantite())
              .append(" | ").append(sc.getProduit().getSeuilAlerte())
              .append(" | ").append(sc.getDepot() != null ? sc.getDepot().getNom() : "Principal")
              .append(" |\n");
        }
        return ToolResult.success(sb.toString());
    }

    private ToolResult getStockRuptures() {
        List<StockCourant> ruptures = stockService.getRuptures();
        if (ruptures.isEmpty()) {
            return ToolResult.success("✅ Aucune rupture de stock. Tous les produits sont disponibles.");
        }
        StringBuilder sb = new StringBuilder("🚨 **Ruptures de stock** (" + ruptures.size() + " produit(s)) :\n\n");
        for (StockCourant sc : ruptures) {
            sb.append("- **").append(sc.getProduit().getNom()).append("** (")
              .append(sc.getProduit().getSku()).append(") — Dépôt: ")
              .append(sc.getDepot() != null ? sc.getDepot().getNom() : "Principal").append("\n");
        }
        return ToolResult.success(sb.toString());
    }

    private ToolResult searchProducts(Map<String, Object> args) {
        String query = getStringArg(args, "query", "");
        if (query.isEmpty()) return ToolResult.error("Le terme de recherche est requis.");

        Page<Produit> results = produitService.search(query, PageRequest.of(0, 10));
        if (results.isEmpty()) {
            return ToolResult.success("Aucun produit trouvé pour \"" + query + "\".");
        }

        StringBuilder sb = new StringBuilder("📦 **Résultats pour \"" + query + "\"** (" + results.getTotalElements() + " produit(s)) :\n\n");
        sb.append("| ID | Nom | SKU | Prix Vente | Catégorie |\n");
        sb.append("|----|-----|-----|:----------:|-----------|\n");
        for (Produit p : results) {
            sb.append("| ").append(p.getId())
              .append(" | ").append(p.getNom())
              .append(" | ").append(p.getSku())
              .append(" | ").append(p.getPrixVente()).append(" FCFA")
              .append(" | ").append(p.getCategorie() != null ? p.getCategorie().getNom() : "-")
              .append(" |\n");
        }
        return ToolResult.success(sb.toString());
    }

    private ToolResult getProductDetails(Map<String, Object> args) {
        Long productId = getLongArg(args, "product_id", null);
        if (productId == null) return ToolResult.error("L'ID du produit est requis.");

        Produit p = produitService.findById(productId);
        List<StockCourant> stocks = stockService.getStockByProduit(productId);

        StringBuilder sb = new StringBuilder();
        sb.append("## 📦 ").append(p.getNom()).append("\n\n");
        sb.append("| Attribut | Valeur |\n");
        sb.append("|----------|--------|\n");
        sb.append("| **SKU** | ").append(p.getSku()).append(" |\n");
        sb.append("| **Code-barres** | ").append(p.getCodeBarres() != null ? p.getCodeBarres() : "-").append(" |\n");
        sb.append("| **Prix d'achat** | ").append(p.getPrixAchat()).append(" FCFA |\n");
        sb.append("| **Prix de vente** | ").append(p.getPrixVente()).append(" FCFA |\n");
        sb.append("| **TVA** | ").append(p.getTauxTva()).append("% |\n");
        sb.append("| **Seuil d'alerte** | ").append(p.getSeuilAlerte()).append(" |\n");
        sb.append("| **Catégorie** | ").append(p.getCategorie() != null ? p.getCategorie().getNom() : "-").append(" |\n");

        if (!stocks.isEmpty()) {
            sb.append("\n### 📊 Stock par dépôt\n\n");
            sb.append("| Dépôt | Quantité |\n");
            sb.append("|-------|:--------:|\n");
            for (StockCourant sc : stocks) {
                sb.append("| ").append(sc.getDepot() != null ? sc.getDepot().getNom() : "Principal")
                  .append(" | ").append(sc.getQuantite()).append(" |\n");
            }
        }

        return ToolResult.success(sb.toString());
    }

    private ToolResult getStockByProduct(Map<String, Object> args) {
        Long productId = getLongArg(args, "product_id", null);
        if (productId == null) return ToolResult.error("L'ID du produit est requis.");

        List<StockCourant> stocks = stockService.getStockByProduit(productId);
        if (stocks.isEmpty()) {
            return ToolResult.success("Aucun stock enregistré pour ce produit.");
        }

        Produit p = stocks.get(0).getProduit();
        StringBuilder sb = new StringBuilder("📊 **Stock de " + p.getNom() + "** :\n\n");
        BigDecimal total = BigDecimal.ZERO;
        for (StockCourant sc : stocks) {
            sb.append("- **").append(sc.getDepot() != null ? sc.getDepot().getNom() : "Principal")
              .append("** : ").append(sc.getQuantite()).append(" unité(s)\n");
            total = total.add(sc.getQuantite());
        }
        sb.append("\n**Total tous dépôts** : ").append(total).append(" unité(s)");
        return ToolResult.success(sb.toString());
    }

    private ToolResult getPatrimoine() {
        Map<String, Object> patrimoine = dashboardService.getPatrimoine();
        StringBuilder sb = new StringBuilder("## 💰 Patrimoine de l'entreprise\n\n");
        sb.append("| Poste | Montant |\n");
        sb.append("|-------|--------:|\n");
        sb.append("| Valeur du stock | ").append(patrimoine.getOrDefault("valeurStock", 0)).append(" FCFA |\n");
        sb.append("| Solde des caisses | ").append(patrimoine.getOrDefault("soldeCaisses", 0)).append(" FCFA |\n");
        sb.append("| Créances clients | ").append(patrimoine.getOrDefault("creancesClients", 0)).append(" FCFA |\n");
        sb.append("| Dettes fournisseurs | -").append(patrimoine.getOrDefault("dettesFournisseurs", 0)).append(" FCFA |\n");
        sb.append("| **Patrimoine net** | **").append(patrimoine.getOrDefault("patrimoineNet", 0)).append(" FCFA** |\n");
        return ToolResult.success(sb.toString());
    }

    private ToolResult getVentesParMois(Map<String, Object> args) {
        int year = getIntArg(args, "year", java.time.LocalDate.now().getYear());
        List<Map<String, Object>> ventes = dashboardService.getVentesParMois(year);
        String[] moisNoms = {"Jan", "Fév", "Mar", "Avr", "Mai", "Juin", "Juil", "Août", "Sep", "Oct", "Nov", "Déc"};

        StringBuilder sb = new StringBuilder("## 📈 Ventes " + year + "\n\n");
        sb.append("| Mois | Entrées | Sorties | Marge |\n");
        sb.append("|------|--------:|--------:|------:|\n");
        for (Map<String, Object> v : ventes) {
            int moisIdx = ((Number) v.get("mois")).intValue() - 1;
            sb.append("| ").append(moisNoms[moisIdx])
              .append(" | ").append(v.get("entrees")).append(" FCFA")
              .append(" | ").append(v.get("sorties")).append(" FCFA")
              .append(" | ").append(v.get("marge")).append(" FCFA |\n");
        }
        return ToolResult.success(sb.toString());
    }

    private ToolResult createProduct(Map<String, Object> args) {
        ProduitRequest request = ProduitRequest.builder()
            .sku(getStringArg(args, "sku", ""))
            .nom(getStringArg(args, "nom", ""))
            .prixAchat(getBigDecimalArg(args, "prix_achat", BigDecimal.ZERO))
            .prixVente(getBigDecimalArg(args, "prix_vente", BigDecimal.ZERO))
            .description(getStringArg(args, "description", null))
            .seuilAlerte(getIntArg(args, "seuil_alerte", 10))
            .build();

        Produit p = produitService.create(request);
        return ToolResult.success("✅ Produit **" + p.getNom() + "** créé avec succès !\n" +
            "- ID: " + p.getId() + "\n" +
            "- SKU: " + p.getSku() + "\n" +
            "- Prix de vente: " + p.getPrixVente() + " FCFA");
    }

    private ToolResult stockEntry(Map<String, Object> args, String userEmail) {
        Long depotId = getLongArg(args, "depot_id", null);
        if (depotId == null) {
            depotId = getDefaultDepotId();
        }

        MouvementRequest request = new MouvementRequest();
        request.setProduitId(getLongArg(args, "product_id", null));
        request.setQuantite(getBigDecimalArg(args, "quantity", null));
        request.setDepotDestId(depotId);
        request.setType(TypeMouvement.ENTREE);
        request.setMotif(MotifMouvement.ACHAT);
        request.setCommentaire(getStringArg(args, "comment", "Entrée via Quantis AI"));

        MouvementStock m = stockService.enregistrerMouvement(request, userEmail);
        Produit p = m.getProduit();
        return ToolResult.success("✅ **Entrée de stock effectuée avec succès !** 📦\n\n" +
            "| Information | Détail |\n" +
            "|-------------|--------|\n" +
            "| Produit | **" + p.getNom() + "** (" + p.getSku() + ") |\n" +
            "| Quantité ajoutée | **+" + m.getQuantite() + "** |\n" +
            "| Dépôt | " + (m.getDepotDest() != null ? m.getDepotDest().getNom() : "Principal") + " |\n" +
            "| Opérateur | " + userEmail + " |");
    }

    private ToolResult stockExit(Map<String, Object> args, String userEmail) {
        Long depotId = getLongArg(args, "depot_id", null);
        if (depotId == null) {
            depotId = getDefaultDepotId();
        }

        MouvementRequest request = new MouvementRequest();
        request.setProduitId(getLongArg(args, "product_id", null));
        request.setQuantite(getBigDecimalArg(args, "quantity", null));
        request.setDepotSourceId(depotId);
        request.setType(TypeMouvement.SORTIE);
        request.setMotif(MotifMouvement.VENTE);
        request.setCommentaire(getStringArg(args, "comment", "Sortie via Quantis AI"));

        MouvementStock m = stockService.enregistrerMouvement(request, userEmail);
        Produit p = m.getProduit();
        return ToolResult.success("✅ **Sortie de stock enregistrée !** 📉\n\n" +
            "| Information | Détail |\n" +
            "|-------------|--------|\n" +
            "| Produit | **" + p.getNom() + "** (" + p.getSku() + ") |\n" +
            "| Quantité retirée | **-" + m.getQuantite() + "** |\n" +
            "| Dépôt | " + (m.getDepotSource() != null ? m.getDepotSource().getNom() : "Principal") + " |\n" +
            "| Opérateur | " + userEmail + " |");
    }

    private ToolResult stockAdjustment(Map<String, Object> args, String userEmail) {
        Long depotId = getLongArg(args, "depot_id", null);
        if (depotId == null) {
            depotId = getDefaultDepotId();
        }

        MouvementRequest request = new MouvementRequest();
        request.setProduitId(getLongArg(args, "product_id", null));
        request.setQuantite(getBigDecimalArg(args, "new_quantity", null));
        request.setDepotDestId(depotId);
        request.setDepotSourceId(depotId);
        request.setType(TypeMouvement.AJUSTEMENT);
        request.setMotif(MotifMouvement.INVENTAIRE);
        request.setCommentaire(getStringArg(args, "comment", "Ajustement via Quantis AI"));

        MouvementStock m = stockService.enregistrerMouvement(request, userEmail);
        Produit p = m.getProduit();
        return ToolResult.success("✅ **Stock ajusté avec succès !** ⚖️\n\n" +
            "| Information | Détail |\n" +
            "|-------------|--------|\n" +
            "| Produit | **" + p.getNom() + "** (" + p.getSku() + ") |\n" +
            "| Nouveau stock | **" + m.getQuantite() + "** unité(s) |\n" +
            "| Dépôt | " + (m.getDepotDest() != null ? m.getDepotDest().getNom() : "Principal") + " |");
    }

    public Produit findOrCreateProduct(String name, BigDecimal prixAchat, BigDecimal prixVente) {
        Page<Produit> found = produitRepository.search(name, PageRequest.of(0, 5));
        if (!found.isEmpty()) {
            return found.getContent().get(0);
        }
        String clean = name.replaceAll("[^a-zA-Z0-9]", "").toUpperCase();
        if (clean.length() > 6) clean = clean.substring(0, 6);
        String sku = clean + "-" + (100 + new Random().nextInt(900));

        ProduitRequest req = ProduitRequest.builder()
            .nom(name)
            .sku(sku)
            .prixAchat(prixAchat != null ? prixAchat : BigDecimal.valueOf(500))
            .prixVente(prixVente != null ? prixVente : BigDecimal.valueOf(1000))
            .seuilAlerte(10)
            .build();
        return produitService.create(req);
    }

    public Long getDefaultDepotId() {
        return depotRepository.findAll().stream()
            .filter(d -> d.getEstActif() == null || Boolean.TRUE.equals(d.getEstActif()))
            .map(Depot::getId)
            .findFirst()
            .orElse(null);
    }

    // ═══════════════════════════════════════════════════
    // UTILITAIRES
    // ═══════════════════════════════════════════════════

    private String formatKpis(Map<String, Object> kpis) {
        StringBuilder sb = new StringBuilder("## 📊 Tableau de bord\n\n");
        sb.append("| Indicateur | Valeur |\n");
        sb.append("|------------|--------|\n");
        sb.append("| Produits | ").append(kpis.getOrDefault("totalProduits", 0)).append(" |\n");
        sb.append("| Clients | ").append(kpis.getOrDefault("totalClients", 0)).append(" |\n");
        sb.append("| Fournisseurs | ").append(kpis.getOrDefault("totalFournisseurs", 0)).append(" |\n");
        sb.append("| ⚠️ Alertes stock | ").append(kpis.getOrDefault("alertesStock", 0)).append(" |\n");
        sb.append("| 🚨 Ruptures | ").append(kpis.getOrDefault("rupturesStock", 0)).append(" |\n");
        sb.append("| 💰 CA du mois | ").append(kpis.getOrDefault("caMois", 0)).append(" FCFA |\n");
        sb.append("| 📉 Dépenses du mois | ").append(kpis.getOrDefault("depensesMois", 0)).append(" FCFA |\n");
        sb.append("| 📈 Marge du mois | ").append(kpis.getOrDefault("margeMois", 0)).append(" FCFA |\n");
        return sb.toString();
    }

    @SuppressWarnings("unchecked")
    private Map<String, Object> parseArgs(String argsJson) {
        if (argsJson == null || argsJson.isBlank()) return Map.of();
        try {
            return objectMapper.readValue(argsJson, new TypeReference<Map<String, Object>>() {});
        } catch (Exception e) {
            return Map.of();
        }
    }

    private String getStringArg(Map<String, Object> args, String key, String defaultValue) {
        Object val = args.get(key);
        return val != null ? val.toString() : defaultValue;
    }

    private Long getLongArg(Map<String, Object> args, String key, Long defaultValue) {
        Object val = args.get(key);
        if (val instanceof Number n) return n.longValue();
        if (val instanceof String s) { try { return Long.parseLong(s); } catch (Exception e) { return defaultValue; } }
        return defaultValue;
    }

    private int getIntArg(Map<String, Object> args, String key, int defaultValue) {
        Object val = args.get(key);
        if (val instanceof Number n) return n.intValue();
        if (val instanceof String s) { try { return Integer.parseInt(s); } catch (Exception e) { return defaultValue; } }
        return defaultValue;
    }

    private BigDecimal getBigDecimalArg(Map<String, Object> args, String key, BigDecimal defaultValue) {
        Object val = args.get(key);
        if (val instanceof Number n) return BigDecimal.valueOf(n.doubleValue());
        if (val instanceof String s) { try { return new BigDecimal(s); } catch (Exception e) { return defaultValue; } }
        return defaultValue;
    }

    private Map<String, Object> toolDef(String name, String description, Map<String, Map<String, String>> properties) {
        Map<String, Object> params = new LinkedHashMap<>();
        params.put("type", "object");
        params.put("properties", properties);
        params.put("required", properties.keySet().stream()
            .filter(k -> !k.equals("comment") && !k.equals("description") && !k.equals("seuil_alerte"))
            .toList());

        return Map.of(
            "name", name,
            "description", description,
            "parameters", params
        );
    }

    private Map<String, String> propDef(String type, String description) {
        return Map.of("type", type, "description", description);
    }

    // ─── Résultat d'exécution ───

    public record ToolResult(boolean success, String content) {
        public static ToolResult success(String content) { return new ToolResult(true, content); }
        public static ToolResult error(String content) { return new ToolResult(false, content); }
    }
}
