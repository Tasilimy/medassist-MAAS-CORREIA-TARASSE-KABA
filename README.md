# MedAssist - Migration V1 vers V2

Projet de migration de base de données pour la plateforme MedAssist.

## 1. Contexte

- **Plateforme** : MedAssist, solution SaaS de gestion de dossiers médicaux
- **Clients** : 350 cabinets médicaux en France
- **Volume** : ~2,4M patients, ~18M consultations, ~45M prescriptions
- **SLA** : 99,9% (8h44 downtime/an max)
- **Fenêtre maintenance** : Dimanche 2h-6h (4 heures)
- **Réglementation** : HDS + RGPD (données sensibles)

## 2. Objectif

Implémenter cinq évolutions du schéma de base de données avec une strategie Expand-Contract.

### Evolution A : restructuration des adresses
- Avant : adresse dans des colonnes séparées dans `patients`
- Après : table dédiée `addresses` avec relation un vers plusieurs

### Evolution B : normalisation des médecins
- Avant : `doctor_name` en texte libre avec incohérences
- Après : table `doctors` avec déduplication

### Evolution C : refonte du genre
- Avant : `gender` en CHAR(1) avec M/F uniquement
- Après : `gender_new` en VARCHAR(10) avec M/F/NB/U

### Evolution D : chiffrement du SSN
- Avant : `ssn` en clair
- Après : `ssn_encrypted` chiffre avec pgcrypto

### Evolution E : partitionnement des consultations
- Avant : table monolithique de 18 millions de lignes
- Après : table partitionnee par année

## 3. Structure du projet

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

## 4. Demarrage rapide

### 4.1 Lancer l'environnement Docker

```bash
cd medassist-MAAS-CORREIA-TARASSE-KABA

# Demarrer PostgreSQL
docker-compose up -d postgres

# Attendre que PostgreSQL soit prêt
sleep 5

# Executer les migrations Flyway
docker-compose run --rm flyway migrate

# Verifier les migrations
docker-compose run --rm flyway info
```

### 4.2 Se connecter à la base

```bash
docker exec -it medassist_pg psql -U medassist_user -d medassist
```

### 4.3 Executer les tests

```bash
# Tester l'evolution A
docker exec -it medassist_pg psql -U medassist_user -d medassist < tests/test_evolution_A.sql

# Ou tous les tests
for test in tests/test_evolution_*.sql; do
  echo "=== $test ==="
  docker exec -it medassist_pg psql -U medassist_user -d medassist < "$test"
done
```

## 5. Strategie Expand-Contract

Cette migration utilise la strategie Expand-Contract pour reduire l'impact en production.

### 5.1 Phase EXPAND (V2__expand_schema.sql)
- Ajouter les **nouvelles** structures (tables, colonnes)
- **Conserver** les anciennes structures
- Migrer les données
- Créer les **triggers** de synchronisation
- Créer les **vues** de compatibilité

### 5.2 Phase CONTRACT (V3__contract_schema.sql)
- Supprimer les **anciennes** structures
- Supprimer les triggers de synchronisation
- Finaliser les index et optimisations
- **Irréversible** - A executer uniquement apres validation en production

## 6. Fichiers du projet

- `V2__expand_schema.sql` - Phase EXPAND
- `V3__contract_schema.sql` - Phase CONTRACT
- `rollback/R_V2__rollback.sql` - Script de rollback V2
- `rollback/R_V3__rollback.sql` - Script de rollback V3
- `tests/test_evolution_A.sql` - Tests Adresses
- `tests/test_evolution_B.sql` - Tests Doctors
- `tests/test_evolution_C.sql` - Tests Gender
- `tests/test_evolution_D.sql` - Tests Chiffrement
- `tests/test_evolution_E.sql` - Tests Partitionnement
- `tests/test_contract.sql` - Tests phase CONTRACT
- `tests/README.md` - Guide des tests

## 7. Documentation

- [DEPLOYMENT_GUIDE.md](DEPLOYMENT_GUIDE.md) : procedure de deploiement et rollback
- [tests/README.md](tests/README.md) : guide des tests et validations
