#!/bin/bash
# ==============================================================================
# Script de Connexion Téléphone (Point d'accès & Wi-Fi) — Quantis Stock
# ==============================================================================

echo "=============================================================================="
echo "          QUANTIS STOCK — CONNEXION TÉLÉPHONE / POINT D'ACCÈS                "
echo "=============================================================================="
echo ""

# 1. Détection de l'interface et de l'IP actives via la table de routage
DEFAULT_ROUTE=$(ip -4 route show default 2>/dev/null | head -n 1)
ACTIVE_IFACE=$(echo "$DEFAULT_ROUTE" | awk '{for(i=1;i<=NF;i++) if($i=="dev") print $(i+1)}')
ACTIVE_GW=$(echo "$DEFAULT_ROUTE" | awk '{for(i=1;i<=NF;i++) if($i=="via") print $(i+1)}')

# Liste des IP physiques actives (en ignorant loopback, Docker, bridges, VPN)
PHYSICAL_IPS=$(ip -4 -o addr show up 2>/dev/null \
    | awk '$2 !~ /^(lo|docker|br-|veth|virbr|vboxnet|vmnet|tun|tap|wg|tailscale|cni|flannel|podman|kube|dummy)/ {split($4,a,"/"); print $2, a[1]}' \
    | grep -vE ' 127\.| 169\.254\.| 172\.17\.')

if [ -z "$PHYSICAL_IPS" ]; then
    echo "⚠️  Aucun réseau Wi-Fi ou Point d'accès détecté sur ce PC."
    echo "   Veuillez activer le Point d'accès sur votre téléphone et connecter ce PC."
    echo ""
    exit 1
fi

PRIMARY_IP=""
if [ -n "$ACTIVE_IFACE" ]; then
    PRIMARY_IP=$(echo "$PHYSICAL_IPS" | awk -v dev="$ACTIVE_IFACE" '$1==dev {print $2; exit}')
fi
if [ -z "$PRIMARY_IP" ]; then
    PRIMARY_IP=$(echo "$PHYSICAL_IPS" | awk '{print $2; exit}')
fi

# Détecter si on est probablement sur un point d'accès mobile
IS_HOTSPOT=0
if echo "$PRIMARY_IP" | grep -qE "^192\.168\.43\.|^172\.20\.10\.|^192\.168\.42\."; then
    IS_HOTSPOT=1
elif echo "$ACTIVE_IFACE" | grep -qE "^(wl|usb|rndis)"; then
    if [ -n "$ACTIVE_GW" ] && ! echo "$ACTIVE_GW" | grep -qE "\.(1|254)$"; then
        IS_HOTSPOT=1
    elif echo "$PRIMARY_IP" | grep -qE "^10\." && ! echo "$PRIMARY_IP" | grep -qE "^10\.0\.0\."; then
        IS_HOTSPOT=1
    fi
fi

if [ "$IS_HOTSPOT" -eq 1 ]; then
    echo "🔥 POINT D'ACCÈS MOBILE DÉTECTÉ !"
else
    echo "📶 RÉSEAU LOCAL DÉTECTÉ :"
fi

echo "   Interface active : ${ACTIVE_IFACE:-inconnue}"
echo "   IP de ce PC      : $PRIMARY_IP"
if [ -n "$ACTIVE_GW" ]; then
    echo "   Passerelle (Tél) : $ACTIVE_GW"
fi
echo ""
echo "   Toutes les interfaces physiques :"
echo "$PHYSICAL_IPS" | awk '{printf "     - %-12s : %s\n", $1, $2}'
echo ""
echo "------------------------------------------------------------------------------"
echo "  1. APPLICATION ANDROID (APK) :"
echo "     ✨ Auto-détection automatique via UDP 45808 + scan du sous-réseau !"
echo "     👉 URL API manuelle : http://$PRIMARY_IP:8080/api/v1"
echo ""
echo "  2. ACCÈS NAVIGATEUR TÉLÉPHONE (Chrome / Safari) :"
echo "     👉 http://$PRIMARY_IP:3000"
echo "------------------------------------------------------------------------------"
echo ""

echo "Vérification des services sur ce PC :"
if ss -tln 2>/dev/null | grep -qE ":8080\b"; then
    echo "   ✅ Backend API (TCP 8080)      : EN COURS D'EXÉCUTION"
else
    echo "   ⚠️  Backend API (TCP 8080)      : NON DÉTECTÉ"
    echo "      Lancez : cd backend && ./mvnw spring-boot:run -Dspring-boot.run.profiles=dev"
fi

if ss -uln 2>/dev/null | grep -qE ":45808\b"; then
    echo "   ✅ Auto-découverte (UDP 45808) : ACTIVE"
else
    echo "   ⚠️  Auto-découverte (UDP 45808) : NON DÉTECTÉE (redémarrez le backend mis à jour)"
fi

if ss -tln 2>/dev/null | grep -qE ":3000\b"; then
    echo "   ✅ Serveur Web (TCP 3000)      : EN COURS D'EXÉCUTION"
else
    echo "   ℹ️  Serveur Web (TCP 3000)      : Non démarré (optionnel pour l'APK)"
fi

# Vérification pare-feu (si ufw est actif)
if [ -r /etc/ufw/ufw.conf ] && grep -qE "^ENABLED=yes" /etc/ufw/ufw.conf 2>/dev/null; then
    echo ""
    echo "🛡️  Pare-feu UFW actif détecté — assurez-vous que les ports sont ouverts :"
    echo "   sudo ufw allow 8080/tcp"
    echo "   sudo ufw allow 45808/udp"
fi

# Détection téléphone branché en USB (ADB reverse)
if command -v adb >/dev/null 2>&1; then
    USB_DEV=$(adb devices 2>/dev/null | awk 'NR>1 && $2=="device" {print $1; exit}')
    if [ -n "$USB_DEV" ]; then
        echo ""
        echo "🔌 Téléphone USB détecté ($USB_DEV) !"
        echo "   Pour forcer le pont USB (127.0.0.1:8080 sur le téléphone) :"
        echo "   adb reverse tcp:8080 tcp:8080"
    fi
fi

echo ""
echo "=============================================================================="
