# Exercice 4 : Ajouter la Détection de Secrets

[⬅️ Exercice précédent](Exercice-03.md) | [🏠 Sommaire](README.md) | [Exercice suivant ➡️](Exercice-05.md)

---

## 🎯 Objectif

Détecter les secrets (clés API, tokens, mots de passe) accidentellement commités dans le code source et l'historique Git avec Gitleaks.

## ⏱️ Durée Estimée

20 minutes

---

## 📝 Instructions

### Étape 4.1 : Créer le workflow

Créez `.github/workflows/secret-scanning.yml` :

```yaml
name: Secret Scanning

on:
  workflow_call:

jobs:
  secret-scanning:
    name: Secret Scanning with Gitleaks
    runs-on: ubuntu-latest

    steps:
      - name: 📥 Checkout code
        uses: actions/checkout@v4
        with:
          fetch-depth: 0  # ⚠️ Important : scanne tout l'historique

      - name: 🔐 Run Gitleaks
        uses: gitleaks/gitleaks-action@v2
        env:
          GITHUB_TOKEN: ${{ secrets.GITHUB_TOKEN }}
          GITLEAKS_ENABLE_SUMMARY: true
```

### Étape 4.2 : Ajouter au pipeline principal

Modifiez `main-pipeline.yml`, ajoutez après `code-quality-sast` :

```yaml
  code-quality-sast:
    needs: build-and-test
    uses: ./.github/workflows/code-quality-sast.yml

  # ═══════════════════════════════════════════════
  # ÉTAPE 3 : DÉTECTION DE SECRETS
  # ═══════════════════════════════════════════════
  secret-scanning:
    needs: build-and-test  # ⚠️ S'exécute en PARALLÈLE avec code-quality-sast
    uses: ./.github/workflows/secret-scanning.yml
```

### Étape 4.3 : Créer un fichier avec un VRAI secret (expérience pédagogique)

**🎯 Objectif** : Voir Gitleaks détecter un véritable secret AWS.

Créez un fichier `config/aws-config.txt` (à la racine du projet) :

```bash
mkdir -p config
cat > config/aws-config.txt << 'EOF'
# Configuration AWS (NE PAS COMMITER EN PRODUCTION !)
AWS_ACCESS_KEY_ID=AKIAIOSFODNN7PROD123
AWS_SECRET_ACCESS_KEY=wJalrXUtnFEMI/K7MDENG/bPxRfiCYPROD123KEY
AWS_REGION=eu-west-1
EOF
```

**⚠️ Note** : Ces clés AWS sont des **exemples officiels d'Amazon** (non fonctionnelles), utilisées dans leur documentation. Ce ne sont pas de vraies clés actives.

### Étape 4.4 : Premier test (échec attendu - DOUBLE détection !)

```bash
git add .
git commit -m "feat: add secret scanning with Gitleaks"
git push origin main
```

**🎓 Observation attendue** : Le job `secret-scanning` va **échouer** avec **2 secrets détectés** ! C'est normal et pédagogique.

**Erreurs affichées** :
```
🛑 Gitleaks detected secrets 🛑
Rule ID             Commit    File                    Start Line
aws-access-token    xxxxx     config/aws-config.txt   2
generic-api-key     xxxxx     config/aws-config.txt   3
private-key         xxxxx     tp/SECRETS.md           74
```

**Pourquoi ?**
1. **Secret AWS détecté** (lignes 2-3 de `config/aws-config.txt`) : Gitleaks reconnaît le format des clés AWS
2. **Exemple SSH détecté** (ligne 74 de `tp/SECRETS.md`) : Format de clé privée dans la documentation

### Étape 4.5 : Supprimer le VRAI secret et gérer les faux positifs

**🚨 ÉTAPE CRITIQUE : Suppression du secret AWS**

1. **Supprimez le fichier avec le secret AWS** :
```bash
rm -rf config/
git add config/
```

2. **Ajoutez le répertoire config/ au .gitignore** (pour éviter de recommiter) :
```bash
echo "# Ne jamais commiter de fichiers de configuration avec secrets" >> .gitignore
echo "config/" >> .gitignore
git add .gitignore
```

3. **Créez `.gitleaksignore` pour le faux positif de documentation** :
```bash
cat > gitleaksignore << 'EOF'
# Gitleaks ignore file
# Documentation examples - not real secrets

# SECRETS.md contains example SSH key format for documentation purposes
tp/SECRETS.md:74
tp/SECRETS.md:75
EOF
git add gitleaksignore
```

### Étape 4.6 : Retester après nettoyage

```bash
git commit -m "fix: remove AWS secrets and add gitleaksignore for docs"
git push origin main
```

**🎉 Cette fois, le job `secret-scanning` devrait passer avec succès !**

**Vérifiez** :
- ✅ Le fichier `config/aws-config.txt` n'existe plus
- ✅ Le répertoire `config/` est dans `.gitignore`
- ✅ Le fichier `.gitleaksignore` ignore uniquement la documentation
- ✅ Le job GitHub Actions est **vert** (réussi)

---

## 🎓 Apprentissage Clé

Cette double expérience intentionnelle démontre :

1. ✅ **Gitleaks détecte les VRAIS secrets** : Il a identifié les clés AWS (format standard)
2. ✅ **Gitleaks détecte aussi les exemples** : Même la doc technique est scannée
3. ✅ **Distinction vrai secret vs faux positif** :
   - `config/aws-config.txt` → **VRAI secret** → ❌ Supprimer + Révoquer
   - `tp/SECRETS.md:74` → **Faux positif** → ✅ Ignorer avec `.gitleaksignore`
4. ✅ **Prévention future** : `.gitignore` empêche de recommiter des secrets
5. ✅ **Traçabilité** : Chaque ignore doit être commenté et justifié

**Dans un projet réel** :
- Si Gitleaks détecte un vrai secret → **RÉVOQUER IMMÉDIATEMENT** + Supprimer + Nettoyer l'historique
- Si c'est un faux positif → Vérifier, commenter, puis ajouter à `.gitleaksignore`
- Utiliser `.gitignore` pour empêcher le commit de fichiers sensibles

---

### Étape 4.6 : (Optionnel) Configuration avancée avec `.gitleaks.toml`

Pour des règles globales, vous pouvez créer `.gitleaks.toml` :

```toml
title = "Gitleaks Configuration"

[allowlist]
description = "Allowlist for false positives"
paths = [
  '''(^|/)\.gitleaks\.toml$''',
]

# Ignorer les secrets de test (patterns)
regexes = [
  '''EXAMPLE_.*''',
  '''TEST_SECRET''',
]
```

**Différence** :
- `.gitleaksignore` : Ignore des **lignes spécifiques**
- `.gitleaks.toml` : Ignore des **patterns/chemins globaux**

---

### Étape 4.7 : Vérification finale

Vérifiez dans l'onglet **Actions** de GitHub :

✅ Le job `secret-scanning` doit être **vert** (réussi)
✅ Les logs doivent afficher : `✅ No leaks detected`
✅ Le fichier `.gitleaksignore` est bien pris en compte

---

## ✅ Critères de Validation

- [ ] **Étape 4.3** : Création du fichier `config/aws-config.txt` avec clés AWS exemple
- [ ] **Étape 4.4** : Premier push → ❌ Échec avec **2-3 secrets détectés** :
  - `aws-access-token` dans `config/aws-config.txt:2`
  - `generic-api-key` dans `config/aws-config.txt:3`
  - `private-key` dans `tp/SECRETS.md:74`
- [ ] **Étape 4.5** : Vous avez :
  - Supprimé le répertoire `config/`
  - Ajouté `config/` au `.gitignore`
  - Créé `.gitleaksignore` pour ignorer `tp/SECRETS.md:74-75`
- [ ] **Étape 4.6** : Deuxième push → ✅ Succès (aucun secret détecté)
- [ ] Le workflow s'exécute **en parallèle** avec `code-quality-sast`
- [ ] Gitleaks scanne tout l'historique Git (`fetch-depth: 0`)
- [ ] Les deux jobs (SAST + Secrets) démarrent en même temps

---

## 🤔 Questions de Compréhension

1. **Pourquoi `fetch-depth: 0` est crucial ?**
   <details>
   <summary>Voir la réponse</summary>

   - Par défaut, GitHub Actions clone seulement le dernier commit (`fetch-depth: 1`)
   - `fetch-depth: 0` clone **tout l'historique Git**
   - Gitleaks peut ainsi scanner tous les commits passés
   - Important car un secret peut avoir été commité puis supprimé
   </details>

2. **Comment deux jobs peuvent s'exécuter en parallèle ?**
   <details>
   <summary>Voir la réponse</summary>

   Quand deux jobs ont le **même** `needs:`, ils s'exécutent en parallèle :
   ```yaml
   code-quality-sast:
     needs: build-and-test

   secret-scanning:
     needs: build-and-test  # Même dépendance = parallèle
   ```

   Ils démarrent tous les deux dès que `build-and-test` est terminé.
   </details>

3. **Que détecte Gitleaks exactement ?**
   <details>
   <summary>Voir la réponse</summary>

   Gitleaks détecte :
   - Clés API (AWS, GCP, Azure, etc.)
   - Tokens (GitHub, GitLab, Slack, etc.)
   - Mots de passe
   - Clés privées SSH/PGP
   - Credentials de base de données
   - Plus de 100 patterns prédéfinis
   </details>

3bis. **Quelle est la différence entre `GITHUB_TOKEN` et `GITLEAKS_ENABLE_SUMMARY` ?**
   <details>
   <summary>Voir la réponse</summary>

   **`GITHUB_TOKEN`** :
   - Token d'authentification automatique fourni par GitHub Actions
   - Permet à Gitleaks d'accéder au repo et de poster des commentaires
   - Disponible automatiquement dans tous les workflows
   - Pas besoin de le configurer manuellement

   **`GITLEAKS_ENABLE_SUMMARY`** :
   - Active l'affichage d'un résumé dans les logs GitHub Actions
   - Améliore la lisibilité des résultats de scan
   - Valeur: `true` pour activer

   **Note sur `GITLEAKS_LICENSE`** :
   - Variable obsolète (n'existe plus dans Gitleaks v2+)
   - Gitleaks est maintenant open-source sans licence commerciale requise
   - NE PAS utiliser dans les nouveaux workflows
   </details>

4. **Que faire si un secret est détecté ?**
   <details>
   <summary>Voir la réponse</summary>

   **Si c'est un VRAI secret** :
   1. ⚠️ **RÉVOQUER le secret immédiatement** (côté service)
   2. Régénérer un nouveau secret
   3. Supprimer le secret du code
   4. Réécrire l'historique Git (`git filter-branch` ou BFG Repo-Cleaner)
   5. Forcer le push : `git push --force`

   **Si c'est un FAUX POSITIF** (comme dans cet exercice) :
   1. ✅ Vérifier que ce n'est vraiment pas un secret
   2. ✅ Ajouter à `.gitleaksignore` avec un commentaire explicatif
   3. ✅ Commiter et pousser

   **Règle d'or** : En cas de doute, considérez-le comme un vrai secret !
   </details>

5. **Pourquoi cet exercice inclut volontairement un échec avec DEUX types de secrets ?**
   <details>
   <summary>Voir la réponse</summary>

   **Objectifs pédagogiques avancés** :
   1. ✅ **Détecter un VRAI secret** : Clés AWS (format réaliste d'Amazon)
   2. ✅ **Détecter un faux positif** : Documentation technique
   3. ✅ **Apprendre à DISTINGUER** : Vrai secret ≠ Faux positif
   4. ✅ **Deux stratégies différentes** :
      - Vrai secret → Supprimer + Prévenir (`.gitignore`)
      - Faux positif → Ignorer (`.gitleaksignore`)
   5. ✅ **Développer le jugement critique** : Ne pas tout ignorer aveuglément

   **Cas réels où cela arrive** :
   - 🔴 **Vrais secrets** : Fichiers `.env`, `config.json`, `.aws/credentials` commités par erreur
   - 🟡 **Faux positifs** : Documentation, tests unitaires, exemples de code

   **Statistiques réelles** :
   - 70% des détections Gitleaks sont de vrais secrets
   - 30% sont des faux positifs légitimes
   - **Il faut savoir distinguer les deux !**

   Sans cette double expérience, vous pourriez :
   - ❌ Ignorer aveuglément un vrai secret (danger)
   - ❌ Supprimer toute la documentation (overkill)
   </details>

6. **Pourquoi utilise-t-on les clés AWS d'exemple d'Amazon ?**
   <details>
   <summary>Voir la réponse</summary>

   Les clés utilisées dans cet exercice sont **officielles d'Amazon** :
   - `AKIAIOSFODNN7EXAMPLE` (Access Key ID)
   - `wJalrXUtnFEMI/K7MDENG/bPxRfiCYEXAMPLEKEY` (Secret Access Key)

   **Source** : [AWS Documentation officielle](https://docs.aws.amazon.com/IAM/latest/UserGuide/id_credentials_access-keys.html)

   **Avantages** :
   - ✅ Format **100% réaliste** (pattern AWS authentique)
   - ✅ **Non fonctionnelles** (pas de risque réel)
   - ✅ Gitleaks les détecte comme de vraies clés AWS
   - ✅ Expérience pédagogique sécurisée

   **Important** : Même si ce sont des exemples, Gitleaks les traite comme des vrais secrets (c'est le but !). Cela vous montre exactement ce qui se passerait avec de vraies clés AWS.
   </details>

---

## 🎯 Architecture Actuelle

```
build-and-test
    ├── code-quality-sast    (parallèle)
    └── secret-scanning      (parallèle)
```

**Les deux scans de sécurité s'exécutent maintenant en parallèle !** ⚡

Cela réduit le temps total du pipeline.

---

## 💡 Points Importants

### 🎯 Démarche Pédagogique de cet Exercice

Cet exercice suit une approche **"fail-first"** intentionnelle avec **double détection** :

1. **Étape 4.3** : Création intentionnelle d'un fichier avec clés AWS
2. **Étape 4.4** : Premier push → ❌ Échec avec **2 types de secrets** :
   - 🔴 **VRAI secret** : Clés AWS dans `config/aws-config.txt`
   - 🟡 **Faux positif** : Exemple de doc dans `tp/SECRETS.md`
3. **Étape 4.5** : Nettoyage différencié :
   - VRAI secret → ❌ **Suppression** + `.gitignore`
   - Faux positif → ✅ **Ignore** avec `.gitleaksignore`
4. **Étape 4.6** : Deuxième push → ✅ Succès

**Pourquoi cette approche enrichie ?**
- ✅ Vous voyez Gitleaks **détecter un VRAI secret AWS**
- ✅ Vous apprenez à **différencier** vrai secret vs faux positif
- ✅ Vous pratiquez **deux stratégies de résolution** différentes
- ✅ Vous comprenez l'importance de `.gitignore` en **prévention**
- ✅ Vous utilisez `.gitleaksignore` uniquement pour les **vrais faux positifs**

**Scénario ultra-réaliste** : C'est exactement ce qui arrive quand un développeur commit accidentellement un fichier de config AWS ! 🚨

### Exécution Parallèle

```yaml
# Ces deux jobs s'exécutent en parallèle
job-a:
  needs: build

job-b:
  needs: build  # Même dépendance = parallèle
```

```yaml
# Ce job attend que job-a ET job-b soient terminés
job-c:
  needs: [job-a, job-b]  # Séquentiel
```

### Sécurité de l'Historique Git

Un secret commité, même supprimé, reste dans l'historique Git ! C'est pourquoi :
- Gitleaks scanne tout l'historique (`fetch-depth: 0`)
- Il faut réécrire l'historique pour vraiment supprimer un secret
- Mieux vaut prévenir que guérir : utiliser des pre-commit hooks

### Gestion des Faux Positifs : Bonnes Pratiques

✅ **À FAIRE** :
- Vérifier manuellement chaque détection
- Commenter **pourquoi** c'est un faux positif
- Utiliser `.gitleaksignore` pour les lignes spécifiques
- Utiliser `.gitleaks.toml` pour des patterns globaux

❌ **À ÉVITER** :
- Ignorer aveuglément sans vérifier
- Désactiver complètement Gitleaks
- Ignorer des répertoires entiers sans justification
- Laisser des vrais secrets "parce que c'est juste du dev"

---

## 📚 Ressources

- [Gitleaks Documentation](https://github.com/gitleaks/gitleaks)
- [GitHub Secret Scanning](https://docs.github.com/en/code-security/secret-scanning)
- [Removing Sensitive Data](https://docs.github.com/en/authentication/keeping-your-account-and-data-secure/removing-sensitive-data-from-a-repository)

---

## 🎉 Félicitations !

Votre pipeline scanne maintenant le code ET l'historique Git pour détecter les secrets !

[Exercice suivant : Analyse des Dépendances ➡️](Exercice-05.md)
