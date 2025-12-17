# Exercice 8 : Ajouter la Publication Docker Hub

[⬅️ Exercice précédent](Exercice-07.md) | [🏠 Sommaire](README.md) | [Exercice suivant ➡️](Exercice-09.md)

---

## 🎯 Objectif

Publier l'image Docker sur Docker Hub avec génération de SBOM (Software Bill of Materials).

## ⏱️ Durée Estimée

30 minutes

---

## 📝 Instructions

### Étape 8.1 : Configurer les Secrets Docker Hub

1. Allez sur https://hub.docker.com/settings/security
2. Cliquez sur **New Access Token**
3. Nom : `GitHub Actions CI/CD`
4. Copiez le token

Dans GitHub : **Settings → Secrets → Actions**, ajoutez :
- `DOCKERHUB_USERNAME` : votre nom d'utilisateur Docker Hub
- `DOCKERHUB_TOKEN` : le token que vous venez de créer

### Étape 8.2 : Créer le workflow

Créez `.github/workflows/publish-docker-hub.yml` :

```yaml
on:
  workflow_call:
    secrets:
      DOCKERHUB_USERNAME:
        required: true
      DOCKERHUB_TOKEN:
        required: true

jobs:
  publish-docker-hub:
    name: 📤 Publish
    runs-on: ubuntu-latest
    steps:
      - name: Checkout code
        uses: actions/checkout@v4

      - name: Set up Docker Buildx
        uses: docker/setup-buildx-action@v3

      - name: Login to Docker Hub
        uses: docker/login-action@v3
        with:
          username: ${{ secrets.DOCKERHUB_USERNAME }}
          password: ${{ secrets.DOCKERHUB_TOKEN }}

      - name: Build and push Docker image
        uses: docker/build-push-action@v5
        with:
          context: .
          file: ./Dockerfile
          push: true
          tags: |
            ${{ secrets.DOCKERHUB_USERNAME }}/${{ secrets.DEPLOY_APPLI_NAME }}:latest
            ${{ secrets.DOCKERHUB_USERNAME }}/${{ secrets.DEPLOY_APPLI_NAME }}:${{ github.sha }}
          cache-from: type=gha
          cache-to: type=gha,mode=max

      - name: Generate SBOM
        uses: anchore/sbom-action@v0
        with:
          image: ${{ secrets.DOCKERHUB_USERNAME }}/${{ secrets.DEPLOY_APPLI_NAME }}:latest
          format: spdx-json
          output-file: sbom.spdx.json

      - name: Upload SBOM
        uses: actions/upload-artifact@v4
        with:
          name: sbom
          path: sbom.spdx.json
```

### Étape 8.3 : Ajouter au pipeline principal

Modifiez `main-pipeline.yml` :

```yaml
  build-and-scan-docker:
    uses: ./.github/workflows/build-docker-image.yml
    secrets: inherit

  # ═══════════════════════════════════════════════
  # ÉTAPE 8 : PUBLICATION DOCKER HUB
  # ═══════════════════════════════════════════════
  publish-docker-hub:
    needs: [build-and-scan-docker]
    uses: ./.github/workflows/publish-docker-hub.yml
    secrets: inherit
```

### Étape 8.4 : Tester

```bash
git add .
git commit -m "feat: add Docker Hub publication with SBOM"
git push origin main
```

Vérifiez sur Docker Hub que l'image est bien publiée !

---

## ✅ Critères de Validation

- [ ] L'image est **build + push** directement vers Docker Hub
- [ ] Deux tags sont créés : `latest` et le SHA du commit
- [ ] Le SBOM est généré au format SPDX-JSON
- [ ] Le SBOM est uploadé comme artefact
- [ ] Les secrets `DOCKERHUB_USERNAME`, `DOCKERHUB_TOKEN`, et `DEPLOY_APPLI_NAME` sont déclarés
- [ ] Les secrets sont partagés avec `secrets: inherit`
- [ ] Utilise Docker Buildx avec cache GitHub Actions
- [ ] L'image est visible sur https://hub.docker.com/r/USERNAME/demo-boost-startup-java

---

## 🤔 Questions de Compréhension

1. **Pourquoi utiliser un token au lieu d'un mot de passe ?**
   <details>
   <summary>Voir la réponse</summary>

   **Avantages des tokens :**
   - Plus sécurisés que les mots de passe
   - Peuvent être révoqués indépendamment
   - Ont des permissions limitées (scope)
   - Pas d'impact si compromis (juste révoquer)
   - Bonnes pratiques pour l'automatisation

   **Mot de passe :**
   - Accès complet au compte
   - Difficile à révoquer sans changer partout
   - Risque de compromission du compte entier
   </details>

2. **Qu'est-ce qu'un SBOM et pourquoi est-il important ?**
   <details>
   <summary>Voir la réponse</summary>

   **SBOM = Software Bill of Materials**

   C'est une liste exhaustive de tous les composants de votre application :
   - Bibliothèques Java (Spring Boot, etc.)
   - Version exacte de chaque dépendance
   - Packages OS (Alpine Linux)
   - Licences logicielles

   **Pourquoi c'est important :**
   - **Conformité** : Exigé par certaines régulations (USA Executive Order)
   - **Sécurité** : Savoir exactement ce qui est déployé
   - **Vulnérabilités** : Identifier rapidement si une CVE vous affecte
   - **Audit** : Traçabilité complète
   - **Licences** : Vérifier la conformité des licences

   Exemple : Log4Shell (2021) → avec un SBOM, vous savez immédiatement si vous êtes affecté.
   </details>

3. **Pourquoi rebuild l'image au lieu de télécharger l'artifact ?**
   <details>
   <summary>Voir la réponse</summary>

   **Avantages du rebuild direct :**
   - **Pas de stockage d'artifact** : Économise de l'espace GitHub (Docker images sont lourdes)
   - **Plus simple** : Pas besoin de save/load/tag
   - **Cache GitHub Actions** : `cache-from/cache-to` accélère considérablement le build
   - **Toujours frais** : L'image est construite au moment de la publication

   **Inconvénient :** Rebuild prend ~2-3 minutes (mais avec cache, c'est rapide)

   **Alternative (si vous préférez l'artifact) :**
   - Download artifact → Load image → Tag → Push
   - Utile si le build est très long (>10 min)
   </details>

4. **Pourquoi deux tags : `latest` et `<sha>` ?**
   <details>
   <summary>Voir la réponse</summary>

   **Tag `latest` :**
   - Toujours la dernière version
   - Facile à déployer : `docker pull user/app:latest`
   - Bon pour dev/staging

   **Tag `<sha>` (commit SHA) :**
   - Version immuable et traçable
   - Permet le rollback exact
   - Bon pour production
   - Lien direct avec le commit Git

   **Best practice :** Déployer avec le SHA, utiliser `latest` pour le dev.
   </details>

---

## 🎯 Architecture Actuelle

```
build-and-scan-docker
    └── publish-docker-hub
```

L'image est rebuild et publiée directement après avoir été validée par Trivy.

---

## 💡 Points Importants

### Partage de Secrets

```yaml
uses: ./.github/workflows/publish-docker-hub.yml
secrets: inherit  # ⚠️ OBLIGATOIRE
```

Sans `secrets: inherit`, le workflow réutilisable n'a **pas accès** aux secrets du repository !

### Gestion des Tags

Stratégies de tagging Docker :

```yaml
# 1. Latest (pour dev)
username/app:latest

# 2. Commit SHA (pour production)
username/app:abc123def

# 3. Version sémantique (pour releases)
username/app:v1.2.3

# 4. Branch + SHA (pour feature branches)
username/app:feature-xyz-abc123
```

---

## 📚 Ressources

- [Docker Hub](https://hub.docker.com/)
- [Docker Login Action](https://github.com/docker/login-action)
- [SBOM - SPDX Format](https://spdx.dev/)
- [Anchore SBOM Action](https://github.com/anchore/sbom-action)
- [Executive Order on Cybersecurity](https://www.nist.gov/itl/executive-order-14028-improving-nations-cybersecurity)

---

## 🎉 Félicitations !

Votre image Docker est maintenant publiée et traçable avec un SBOM ! Dans l'exercice suivant, vous allez ajouter les tests DAST avec OWASP ZAP.

[Exercice suivant : Tests DAST ➡️](Exercice-09.md)
