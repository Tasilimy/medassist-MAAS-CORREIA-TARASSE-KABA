# Tests de Migration MedAssist

Ce dossier contient les scripts de test SQL pour valider chacune des 5 évolutions (A-E) de la migration MedAssist V1 → V2.

## Structure

- `test_evolution_A.sql` - Tests pour la restructuration des adresses
- `test_evolution_B.sql` - Tests pour la normalisation des médecins
- `test_evolution_C.sql` - Tests pour la refonte du champ gender
- `test_evolution_D.sql` - Tests pour le chiffrement des SSN
- `test_evolution_E.sql` - Tests pour le partitionnement des consultations

## Comment exécuter les tests

### Option 1 : Via psql en ligne de commande

```bash
# Tester l'évolution A
docker exec -it medassist_pg psql -U medassist_user -d medassist -f /tests/test_evolution_A.sql

# Tester l'évolution B
docker exec -it medassist_pg psql -U medassist_user -d medassist -f /tests/test_evolution_B.sql
```

### Option 2 : Via psql interactif

```bash
docker exec -it medassist_pg psql -U medassist_user -d medassist

# Puis dans psql :
\i /tests/test_evolution_A.sql
\i /tests/test_evolution_B.sql
```

### Option 3 : Via docker-compose

```bash
docker-compose exec postgres psql -U medassist_user -d medassist < tests/test_evolution_A.sql
```

## Structure des tests

Chaque script de test :
1.  Vérifie l'existence des tables et colonnes créées
2.  Valide les contraintes et index
3.  Teste la migration des données
4.  Vérifie la compatibilité V1/V2
5.  Affiche des statistiques

Les tests utilisent des blocs SQL `DO $$...$$ LANGUAGE plpgsql` qui :
- Comptent les tests passés/échoués
- Lèvent une `EXCEPTION` en cas d'erreur
- Affichent `NOTICE` avec les résultats

## Critères de succès

**Test réussi** : "Tests passés: X/X" (tous les tests passent)
**Test échoué** : "EXCEPTION : ÉVOLUTION X : Y test(s) échoué(s)"

## Exemples de sortie

```
========== TEST ÉVOLUTION A ==========
[OK] Test 1 : Table addresses existe
[OK] Test 2 : Toutes les colonnes requises existent
[OK] Test 3 : Contrainte CHECK sur address_type existe
[OK] Test 4 : Données migrées vers addresses (8 adresses)
[OK] Test 5 : Intégrité des adresses primaires
[OK] Test 6 : Vue patients_v1_view accessible
[OK] Test 7 : Index sur patient_id existe
========== RÉSUMÉ ==========
Tests passés: 7/7
```

## Validations par évolution

### Évolution A (Adresses)
- Table `addresses` créée avec les bonnes colonnes
- Données migrées depuis `patients`
- Chaque adresse a un type (HOME, WORK, BILLING)
- Vue `patients_v1_view` pour compatibilité

### Évolution B (Doctors)
- Table `doctors` créée avec déduplication
- Colonne `doctor_id` ajoutée à `consultations`
- Toutes les consultations liées aux doctors
- `doctor_name` toujours rempli

### Évolution C (Gender)
- Table `gender_ref` avec 4 valeurs (M, F, NB, U)
- Colonne `gender_new` dans `patients`
- Toutes les valeurs valides
- FK vers `gender_ref`

### Évolution D (Chiffrement)
- Extension `pgcrypto` installée
- Colonne `ssn_encrypted` créée
- SSN chiffrés présents
- SSN en clair toujours présents (compatibilité)

### Évolution E (Partitionnement)
- Table `consultations_partitioned` créée
- 6 partitions par année (2021-2025 + future)
- Données copiées correctement
- Distribution par année validée

## Dépannage

### Les tests échouent ?

1. Vérifier que les migrations Flyway se sont exécutées :
```sql
SELECT * FROM flyway_schema_history;
```

2. Vérifier la structure de la table :
```sql
\d addresses
\d doctors
\d patients
```

3. Vérifier les triggers :
```sql
SELECT * FROM pg_trigger WHERE tgrelid::regclass IN ('addresses'::regclass, 'consultations'::regclass);
```

4. Afficher les erreurs Flyway :
```bash
docker logs medassist_flyway
```

## Performance

Les tests incluent des validations de performance :
- Vérification des index pertinents
- Vérification du partitionnement pour E

Pour une analyse plus approfondie :
```sql
EXPLAIN ANALYZE SELECT * FROM addresses WHERE patient_id = 1;
EXPLAIN ANALYZE SELECT * FROM consultations_partitioned WHERE EXTRACT(YEAR FROM consultation_date) = 2024;
```
