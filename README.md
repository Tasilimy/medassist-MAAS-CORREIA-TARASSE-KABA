# MedAssist - Migration V1 → V2 (BDD)

Projet de migration de base de données pour la plateforme MedAssist, système de gestion de dossiers médicaux.

## 📋 Contexte

- **Plateforme** : MedAssist (SaaS gestion dossiers médicaux)
- **Clients** : 350 cabinets médicaux en France
- **Volume** : ~2,4M patients, ~18M consultations, ~45M prescriptions
- **SLA** : 99,9% (8h44 downtime/an max)
- **Fenêtre maintenance** : Dimanche 2h-6h (4 heures)
- **Réglementation** : HDS + RGPD (données sensibles)

## 🎯 Objectif

Implémenter 5 évolutions du schéma de base de données avec **zéro downtime** grâce à la stratégie **Expand-Contract** :

### Évolution A : Restructuration des adresses
- ❌ Avant : adresse dans colonnes séparées (patients)
- ✅ Après : table dédiée `addresses` (1-N avec patients)

### Évolution B : Normalisation des médecins
- ❌ Avant : `doctor_name` texte libre avec incohérences
- ✅ Après : table `doctors` avec déduplication

### Évolution C : Refonte du genre
- ❌ Avant : `gender` = CHAR(1) avec M/F seulement
- ✅ Après : `gender_new` VARCHAR(10) avec M/F/NB/U

### Évolution D : Chiffrement SSN
- ❌ Avant : `ssn` en clair
- ✅ Après : `ssn_encrypted` chiffré avec pgcrypto

### Évolution E : Partitionnement consultations
- ❌ Avant : table monolithique 18M lignes
- ✅ Après : table partitionnée par année

## 🏗️ Structure du projet

```
medassist-MAAS-CORREIA-TARASSE-KABA/
├── docker-compose.yml          # PostgreSQL 16 + Flyway 10
├── README.md                   # Ce fichier
├── flyway/
│   ├── conf/
│   │   └── flyway.conf        # Configuration Flyway
│   └── sql/
│       ├── V1__init_schema.sql          # Schéma initial (fourni)
│       ├── V1.1__seed_data.sql          # Données test (fourni)
│       ├── V2__expand_schema.sql        # Phase EXPAND (migrations)
│       └── V3__contract_schema.sql      # Phase CONTRACT (finalisation)
├── rollback/
│   ├── R_V2__rollback.sql               # Rollback V2
│   └── R_V3__rollback.sql               # Rollback V3
├── tests/
│   ├── README.md                        # Guide des tests
│   ├── test_evolution_A.sql             # Tests pour Adresses
│   ├── test_evolution_B.sql             # Tests pour Doctors
│   ├── test_evolution_C.sql             # Tests pour Gender
│   ├── test_evolution_D.sql             # Tests pour Chiffrement
│   ├── test_evolution_E.sql             # Tests pour Partitionnement
│   └── test_contract.sql                # Tests pour Phase CONTRACT
└── rapport/
    └── rapport_strategie.md             # À compléter
```

## 🚀 Démarrage rapide

### 1. Lancer l'environnement Docker

```bash
cd medassist-MAAS-CORREIA-TARASSE-KABA

# Démarrer PostgreSQL
docker-compose up -d postgres

# Attendre que PostgreSQL soit prêt
sleep 5

# Exécuter les migrations Flyway
docker-compose run --rm flyway migrate

# Vérifier les migrations
docker-compose run --rm flyway info
```

### 2. Connecter à la base

```bash
docker exec -it medassist_pg psql -U medassist_user -d medassist
```

### 3. Exécuter les tests

```bash
# Tester l'évolution A
docker exec -it medassist_pg psql -U medassist_user -d medassist < tests/test_evolution_A.sql

# Ou tous les tests
for test in tests/test_evolution_*.sql; do
  echo "=== $test ==="
  docker exec -it medassist_pg psql -U medassist_user -d medassist < "$test"
done
```

## 🔄 Stratégie : Expand-Contract

Cette migration utilise la stratégie **Expand-Contract** pour garantir le zéro downtime.

### Phase 1 : EXPAND (V2__expand_schema.sql) ✅
- Ajouter les **nouvelles** structures (tables, colonnes)
- **Conserver** les anciennes structures
- Migrer les données
- Créer les **triggers** de synchronisation
- Créer les **vues** de compatibilité

### Phase 2 : CONTRACT (V3__contract_schema.sql) ✅
- Supprimer les **anciennes** structures
- Supprimer les triggers de synchronisation
- Finaliser les index et optimisations
- **Irréversible** - À exécuter UNIQUEMENT après validation en production

**État actuel** : 
- **Phase EXPAND** ✅ Complétée (V2)
- **Phase CONTRACT** ✅ Implémentée (V3)
- **Rollback** ✅ Disponible pour V2 et V3

## 📝 Fichiers créés

✅ **V2__expand_schema.sql** - Phase EXPAND (migrations pour 5 évolutions)
✅ **V3__contract_schema.sql** - Phase CONTRACT (finalisation)
✅ **R_V2__rollback.sql** - Script de rollback V2
✅ **R_V3__rollback.sql** - Script de rollback V3
✅ **test_evolution_A.sql** - Tests Adresses
✅ **test_evolution_B.sql** - Tests Doctors
✅ **test_evolution_C.sql** - Tests Gender
✅ **test_evolution_D.sql** - Tests Chiffrement
✅ **test_evolution_E.sql** - Tests Partitionnement
✅ **test_contract.sql** - Tests Phase CONTRACT
✅ **tests/README.md** - Guide complet des tests

## 📚 Documentation

Voir [tests/README.md](tests/README.md) pour le guide complet des tests et validations.
