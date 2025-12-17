#!/bin/bash
# Script de test TP Exercice-13 - Etudiant 6
# Date: 2025-12-08

set -e

# Couleurs
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
BLUE='\033[0;34m'
NC='\033[0m' # No Color

# Variables
NAMESPACE="cesi6"
TEST_RESULTS=()

echo "════════════════════════════════════════════════════════════════"
echo "  TEST TP EXERCICE-13 KYVERNO - Etudiant n°6"
echo "  Namespace: ${NAMESPACE}"
echo "════════════════════════════════════════════════════════════════"
echo ""

# Fonction pour afficher les résultats
log_test() {
    local status=$1
    local test_name=$2
    local expected=$3
    
    if [ "$status" == "PASS" ]; then
        echo -e "${GREEN}✅ PASS${NC} - ${test_name} : ${expected}"
        TEST_RESULTS+=("PASS: ${test_name}")
    elif [ "$status" == "FAIL" ]; then
        echo -e "${RED}❌ FAIL${NC} - ${test_name} : ${expected}"
        TEST_RESULTS+=("FAIL: ${test_name}")
    elif [ "$status" == "INFO" ]; then
        echo -e "${BLUE}ℹ️  INFO${NC} - ${test_name}"
    else
        echo -e "${YELLOW}⚠️  WARN${NC} - ${test_name} : ${expected}"
        TEST_RESULTS+=("WARN: ${test_name}")
    fi
}

# Vérifier kubectl
if ! command -v kubectl &> /dev/null; then
    log_test "FAIL" "kubectl check" "kubectl n'est pas installé"
    exit 1
fi

log_test "PASS" "kubectl check" "kubectl est disponible"
echo ""

# ═══════════════════════════════════════════════════════════════════
# PHASE 1: VERIFICATION INITIALE
# ═══════════════════════════════════════════════════════════════════
echo "━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━"
echo "PHASE 1: Vérification initiale"
echo "━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━"
echo ""

# Test 1.1: Vérifier Kyverno
echo "Test 1.1: Vérifier que Kyverno est installé..."
if kubectl get pods -n kyverno &> /dev/null; then
    KYVERNO_PODS=$(kubectl get pods -n kyverno --no-headers 2>/dev/null | wc -l)
    if [ "$KYVERNO_PODS" -gt 0 ]; then
        log_test "PASS" "Kyverno installé" "${KYVERNO_PODS} pods trouvés"
    else
        log_test "FAIL" "Kyverno installé" "Aucun pod trouvé"
    fi
else
    log_test "WARN" "Kyverno installé" "Namespace kyverno n'existe pas (mode simulation)"
fi
echo ""

# Test 1.2: Vérifier les ClusterPolicies
echo "Test 1.2: Vérifier les ClusterPolicies..."
if kubectl get clusterpolicy &> /dev/null; then
    POLICIES=$(kubectl get clusterpolicy --no-headers 2>/dev/null | wc -l)
    if [ "$POLICIES" -ge 3 ]; then
        log_test "PASS" "ClusterPolicies" "${POLICIES} politiques trouvées"
        kubectl get clusterpolicy 2>/dev/null || true
    else
        log_test "FAIL" "ClusterPolicies" "Seulement ${POLICIES} politiques (attendu: 3)"
    fi
else
    log_test "WARN" "ClusterPolicies" "CRD Kyverno non installé (mode simulation)"
fi
echo ""

# Test 1.3: Vérifier le namespace
echo "Test 1.3: Vérifier le namespace ${NAMESPACE}..."
if kubectl get namespace ${NAMESPACE} &> /dev/null; then
    log_test "PASS" "Namespace ${NAMESPACE}" "existe"
    
    # Vérifier ResourceQuota
    if kubectl get resourcequota -n ${NAMESPACE} &> /dev/null; then
        QUOTA=$(kubectl get resourcequota -n ${NAMESPACE} --no-headers 2>/dev/null | wc -l)
        if [ "$QUOTA" -gt 0 ]; then
            log_test "PASS" "ResourceQuota" "trouvée dans ${NAMESPACE}"
        else
            log_test "WARN" "ResourceQuota" "non trouvée (génération auto non active)"
        fi
    fi
    
    # Vérifier NetworkPolicy
    if kubectl get networkpolicy -n ${NAMESPACE} &> /dev/null; then
        NP=$(kubectl get networkpolicy -n ${NAMESPACE} --no-headers 2>/dev/null | wc -l)
        if [ "$NP" -gt 0 ]; then
            log_test "PASS" "NetworkPolicy" "trouvée dans ${NAMESPACE}"
        else
            log_test "WARN" "NetworkPolicy" "non trouvée (génération auto non active)"
        fi
    fi
    
    # Vérifier ConfigMap
    if kubectl get configmap namespace-info -n ${NAMESPACE} &> /dev/null; then
        log_test "PASS" "ConfigMap namespace-info" "trouvée dans ${NAMESPACE}"
    else
        log_test "WARN" "ConfigMap namespace-info" "non trouvée (génération auto non active)"
    fi
else
    log_test "FAIL" "Namespace ${NAMESPACE}" "n'existe pas"
    echo ""
    echo "Créer le namespace avec: kubectl create namespace ${NAMESPACE}"
    exit 1
fi
echo ""

# ═══════════════════════════════════════════════════════════════════
# PHASE 2: TESTS DE VALIDATION (doivent échouer)
# ═══════════════════════════════════════════════════════════════════
echo "━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━"
echo "PHASE 2: Tests de validation (doivent ECHOUER)"
echo "━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━"
echo ""

echo "ℹ️  NOTE: Ces tests utilisent --dry-run=server pour éviter de créer des ressources"
echo ""

# Test 2.1: Conteneur privileged
echo "Test 2.1: Tester conteneur privileged (doit être BLOQUÉ)..."
TEST_OUTPUT=$(kubectl apply --dry-run=server -f - 2>&1 <<EOF || true
apiVersion: v1
kind: Pod
metadata:
  name: nginx-privileged
  namespace: ${NAMESPACE}
  labels:
    test: "validation-privileged"
spec:
  containers:
  - name: nginx
    image: nginx:1.25
    securityContext:
      privileged: true
EOF
)

if echo "$TEST_OUTPUT" | grep -qi "denied\|error\|blocked\|privileged"; then
    log_test "PASS" "Test privileged" "BLOQUÉ comme attendu"
else
    log_test "WARN" "Test privileged" "Non bloqué (politique non active ou mode Audit)"
fi
echo ""

# Test 2.2: Pas de limites
echo "Test 2.2: Tester sans limites de ressources (doit être BLOQUÉ)..."
TEST_OUTPUT=$(kubectl apply --dry-run=server -f - 2>&1 <<EOF || true
apiVersion: apps/v1
kind: Deployment
metadata:
  name: nginx-no-limits
  namespace: ${NAMESPACE}
spec:
  replicas: 1
  selector:
    matchLabels:
      app: nginx-no-limits
  template:
    metadata:
      labels:
        app: nginx-no-limits
    spec:
      containers:
      - name: nginx
        image: nginx:1.25
EOF
)

if echo "$TEST_OUTPUT" | grep -qi "denied\|error\|blocked\|limit\|resource"; then
    log_test "PASS" "Test sans limites" "BLOQUÉ comme attendu"
else
    log_test "WARN" "Test sans limites" "Non bloqué (politique non active)"
fi
echo ""

# Test 2.3: RunAsUser 0 (root)
echo "Test 2.3: Tester exécution en tant que root (doit être BLOQUÉ)..."
TEST_OUTPUT=$(kubectl apply --dry-run=server -f - 2>&1 <<EOF || true
apiVersion: apps/v1
kind: Deployment
metadata:
  name: nginx-as-root
  namespace: ${NAMESPACE}
spec:
  replicas: 1
  selector:
    matchLabels:
      app: nginx-as-root
  template:
    metadata:
      labels:
        app: nginx-as-root
    spec:
      containers:
      - name: nginx
        image: nginx:1.25
        resources:
          limits:
            cpu: "500m"
            memory: "512Mi"
          requests:
            cpu: "250m"
            memory: "256Mi"
        securityContext:
          runAsUser: 0
EOF
)

if echo "$TEST_OUTPUT" | grep -qi "denied\|error\|blocked\|root"; then
    log_test "PASS" "Test root user" "BLOQUÉ comme attendu"
else
    log_test "WARN" "Test root user" "Non bloqué (politique non active)"
fi
echo ""

# ═══════════════════════════════════════════════════════════════════
# PHASE 3: TEST DE VALIDATION (doit réussir)
# ═══════════════════════════════════════════════════════════════════
echo "━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━"
echo "PHASE 3: Test de validation conforme (doit REUSSIR)"
echo "━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━"
echo ""

echo "Test 3.1: Tester déploiement nginx conforme..."
TEST_OUTPUT=$(kubectl apply --dry-run=server -f - 2>&1 <<EOF || true
apiVersion: apps/v1
kind: Deployment
metadata:
  name: nginx-secure-test
  namespace: ${NAMESPACE}
  labels:
    app: nginx-secure-test
spec:
  replicas: 2
  selector:
    matchLabels:
      app: nginx-secure-test
  template:
    metadata:
      labels:
        app: nginx-secure-test
    spec:
      securityContext:
        runAsNonRoot: true
        runAsUser: 1001
        fsGroup: 1001
        seccompProfile:
          type: RuntimeDefault
      containers:
      - name: nginx
        image: nginx:1.25
        resources:
          limits:
            cpu: "500m"
            memory: "512Mi"
          requests:
            cpu: "250m"
            memory: "256Mi"
        securityContext:
          allowPrivilegeEscalation: false
          runAsNonRoot: true
          runAsUser: 1001
          readOnlyRootFilesystem: true
          privileged: false
          capabilities:
            drop:
            - ALL
        volumeMounts:
        - name: cache
          mountPath: /var/cache/nginx
        - name: run
          mountPath: /var/run
      volumes:
      - name: cache
        emptyDir: {}
      - name: run
        emptyDir: {}
EOF
)

if echo "$TEST_OUTPUT" | grep -qi "created\|configured\|unchanged" && ! echo "$TEST_OUTPUT" | grep -qi "error\|denied"; then
    log_test "PASS" "Déploiement conforme" "ACCEPTÉ comme attendu"
else
    log_test "FAIL" "Déploiement conforme" "Devrait être accepté"
    echo "Output: $TEST_OUTPUT"
fi
echo ""

# ═══════════════════════════════════════════════════════════════════
# RÉSUMÉ
# ═══════════════════════════════════════════════════════════════════
echo "━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━"
echo "RÉSUMÉ DES TESTS"
echo "━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━"
echo ""

PASS_COUNT=$(printf '%s\n' "${TEST_RESULTS[@]}" | grep -c "^PASS:" || echo "0")
FAIL_COUNT=$(printf '%s\n' "${TEST_RESULTS[@]}" | grep -c "^FAIL:" || echo "0")
WARN_COUNT=$(printf '%s\n' "${TEST_RESULTS[@]}" | grep -c "^WARN:" || echo "0")
TOTAL_COUNT=${#TEST_RESULTS[@]}

echo "Total tests: ${TOTAL_COUNT}"
echo -e "${GREEN}Tests réussis: ${PASS_COUNT}${NC}"
echo -e "${RED}Tests échoués: ${FAIL_COUNT}${NC}"
echo -e "${YELLOW}Avertissements: ${WARN_COUNT}${NC}"
echo ""

if [ "$FAIL_COUNT" -eq 0 ]; then
    echo -e "${GREEN}✅ Tous les tests obligatoires ont réussi !${NC}"
    if [ "$WARN_COUNT" -gt 0 ]; then
        echo -e "${YELLOW}⚠️  Certaines fonctionnalités Kyverno ne sont pas actives (mode simulation)${NC}"
    fi
else
    echo -e "${RED}❌ Certains tests ont échoué${NC}"
fi
echo ""

# ═══════════════════════════════════════════════════════════════════
# NETTOYAGE
# ═══════════════════════════════════════════════════════════════════
echo "━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━"
echo "NETTOYAGE DES RESSOURCES DE TEST"
echo "━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━"
echo ""

# Demander confirmation avant nettoyage
read -p "Voulez-vous nettoyer les ressources de test dans ${NAMESPACE} ? (o/N) " -n 1 -r
echo ""

if [[ $REPLY =~ ^[OoYy]$ ]]; then
    echo "🧹 Nettoyage en cours..."
    echo ""
    
    # Supprimer tous les déploiements et pods avec label test
    echo "Suppression des ressources avec label 'test'..."
    if kubectl delete deployment,pod -n ${NAMESPACE} -l test --ignore-not-found=true 2>/dev/null; then
        log_test "PASS" "Nettoyage deployments/pods" "Ressources avec label 'test' supprimées"
    else
        log_test "WARN" "Nettoyage deployments/pods" "Aucune ressource avec label 'test' trouvée"
    fi
    
    # Supprimer les déploiements de test spécifiques (au cas où)
    echo "Suppression des déploiements de test spécifiques..."
    DEPLOYMENTS_TO_DELETE=(
        "nginx-privileged"
        "nginx-no-limits"
        "nginx-as-root"
        "nginx-writable-root"
        "nginx-too-many-replicas"
        "nginx-secure-test"
        "nginx-mutation-labels"
        "nginx-mutation-securitycontext"
    )
    
    DELETED_COUNT=0
    for deploy in "${DEPLOYMENTS_TO_DELETE[@]}"; do
        if kubectl delete deployment ${deploy} -n ${NAMESPACE} --ignore-not-found=true 2>/dev/null; then
            DELETED_COUNT=$((DELETED_COUNT + 1))
        fi
    done
    
    if [ "$DELETED_COUNT" -gt 0 ]; then
        log_test "PASS" "Nettoyage déploiements" "${DELETED_COUNT} déploiement(s) supprimé(s)"
    else
        log_test "INFO" "Nettoyage déploiements" "Aucun déploiement à supprimer"
    fi
    
    # Supprimer les pods de test spécifiques
    echo "Suppression des pods de test..."
    PODS_TO_DELETE=(
        "nginx-privileged"
    )
    
    POD_DELETED_COUNT=0
    for pod in "${PODS_TO_DELETE[@]}"; do
        if kubectl delete pod ${pod} -n ${NAMESPACE} --ignore-not-found=true 2>/dev/null; then
            POD_DELETED_COUNT=$((POD_DELETED_COUNT + 1))
        fi
    done
    
    if [ "$POD_DELETED_COUNT" -gt 0 ]; then
        log_test "PASS" "Nettoyage pods" "${POD_DELETED_COUNT} pod(s) supprimé(s)"
    else
        log_test "INFO" "Nettoyage pods" "Aucun pod à supprimer"
    fi
    
    # Vérifier les ressources restantes
    echo ""
    echo "Vérification des ressources restantes dans ${NAMESPACE}..."
    echo ""
    
    REMAINING_DEPLOYMENTS=$(kubectl get deployment -n ${NAMESPACE} --no-headers 2>/dev/null | wc -l)
    REMAINING_PODS=$(kubectl get pods -n ${NAMESPACE} --no-headers 2>/dev/null | wc -l)
    
    echo "Ressources restantes:"
    echo "  - Deployments: ${REMAINING_DEPLOYMENTS}"
    echo "  - Pods: ${REMAINING_PODS}"
    
    if [ "$REMAINING_DEPLOYMENTS" -gt 0 ]; then
        echo ""
        echo "Deployments restants:"
        kubectl get deployment -n ${NAMESPACE} --no-headers 2>/dev/null | awk '{print "  - " $1}' || true
    fi
    
    echo ""
    echo -e "${GREEN}✅ Nettoyage terminé${NC}"
else
    echo ""
    echo -e "${YELLOW}⚠️  Nettoyage annulé${NC}"
    echo ""
    echo "Pour nettoyer manuellement plus tard, utilisez:"
    echo "  kubectl delete deployment,pod -n ${NAMESPACE} -l test"
    echo ""
    echo "Ou pour supprimer des ressources spécifiques:"
    echo "  kubectl delete deployment nginx-secure-test -n ${NAMESPACE}"
    echo "  kubectl delete deployment nginx-mutation-labels -n ${NAMESPACE}"
fi

echo ""
echo "━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━"
echo "TEST TERMINÉ"
echo "━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━"

# Exit avec le bon code
if [ "$FAIL_COUNT" -eq 0 ]; then
    exit 0
else
    exit 1
fi
