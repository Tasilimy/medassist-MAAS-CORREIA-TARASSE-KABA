# Guide de Déploiement - Phases EXPAND-CONTRACT

Ce document décrit les étapes et le timeline pour déployer les migrations MedAssist en production.

## 🎯 Vue d'ensemble

La migration utilise la stratégie **Expand-Contract** sur **3 fenêtres de maintenance** (3 dimanches) :

| Fenêtre | Durée | Phase | Risque | Rollback |
|---------|-------|-------|--------|----------|
| **Dimanche 1** | 4h | EXPAND (V2) | ⚠️ Modéré | ✅ Facile (R_V2) |
| **Dimanche 2** | 4h | Validation | ✅ Nul | N/A |
| **Dimanche 3** | 4h | CONTRACT (V3) | ❌ Critique | ✅ Complexe (R_V3) |

## ⏱️ Timeline de déploiement

### Préparation (Semaine 0)
```
Lundi-Vendredi :
├─ Code review des scripts Flyway (V2, V3)
├─ Validation des tests en environnement de test
├─ Préparation des rollback procedures
├─ Formation de l'équipe ops
└─ Communication aux clients
```

### Dimanche 1 - Phase EXPAND (Zéro-downtime) ✅
```
02:00 - Préparation
├─ 02:00-02:15 : Backup complet de la base
├─ 02:15-02:30 : Vérifier l'absence de transactions longues
└─ 02:30 : GO / NO-GO decision

02:30 - Migration EXPAND (V2)
├─ 02:30-03:00 : Exécuter V2__expand_schema.sql
│                 (créer addresses, doctors, partitions, etc.)
├─ 03:00-03:30 : Valider les données migrées
│                 (exécuter test_evolution_*.sql)
└─ 03:30 : Notifier équipe dev que les structures sont prêtes

03:30-04:00 : Validation post-déploiement
├─ Vérifier que Flyway historique est correct
├─ Vérifier les performances (queries < 120ms)
├─ Valider les triggers de synchro
└─ Logs clean (0 erreurs)

Résultat : V1 et V2 coexistent ✅ (Application V1 toujours en prod)
```

### Semaine 1 - Monitoring et tests
```
Lundi-Samedi :
├─ Monitoring 24/7 des performances
├─ Vérifier la synchronisation V1 ↔ V2
├─ Application V1 continue à fonctionner normalement
├─ Tests de charge progressifs
└─ Validation que les données restent cohérentes
```

### Dimanche 2 - Déploiement Application V2 (Zéro-downtime)
```
02:00 - Déploiement application V2
├─ 02:00-02:15 : Rolling deploy (K8s : 1 pod → 2 pods)
├─ 02:15-03:00 : Tester les 2 versions en parallèle
├─ 03:00-04:00 : Augmenter à 100% V2 (0% V1)
│                 (Load balancer : V1 → V2 progressivement)
└─ Vérifier logs et monitoring

Résultat : Application V2 en production ✅ (Base : V2 + anciennes structures)
```

### Semaine 2 - Sécurité
```
Lundi-Samedi :
├─ Monitoring application V2 (24/7)
├─ Vérifier intégrité données
├─ Pas de régressions détectées ?
├─ Performance stable ?
└─ Vraiment prêt pour phase CONTRACT ?
```

### Dimanche 3 - Phase CONTRACT (Irréversible) ❌
```
02:00 - Checkpoint critique
├─ 02:00-02:15 : Backup complet + snapshots volumes
├─ 02:15-02:30 : Dernier check : V2 stable ? Erreurs prod ? 
└─ 02:30 : GO / NO-GO **FINAL DECISION**

02:30 - Migration CONTRACT (V3)
├─ 02:30-03:00 : Exécuter V3__contract_schema.sql
│                 (supprimer anciennes colonnes, triggers, etc.)
├─ 03:00-03:30 : Valider structure finale
│                 (exécuter test_contract.sql)
└─ 03:30 : Vérifier Flyway historique

03:30-04:00 : Validation finale
├─ Vérifier que l'app V2 fonctionne 100% OK
├─ Requêtes rapides ? (< 120ms)
├─ Logs clean ? (0 erreurs)
└─ Si ERREUR : Exécuter R_V3__rollback.sql immédiatement

Résultat : Schéma V2 finalisé ✅ (Anciennes colonnes/triggers supprimés)
```

## 🚨 Procédures de Rollback

### Rollback Phase EXPAND (Dimanche 1)
Si problème détecté entre 02:30-04:00 :
```bash
# Exécuter avant 04:00
docker exec -i medassist_pg psql -U medassist_user -d medassist < rollback/R_V2__rollback.sql

# Supprimer l'entrée Flyway
DELETE FROM flyway_schema_history WHERE version = '2.0';
```

**Temps de récupération** : ~15 minutes
**Impact** : Zéro données perdues, application V1 continue

---

### Rollback Phase CONTRACT (Dimanche 3)
Si problème détecté entre 02:30-04:00 :
```bash
# Exécuter avant 04:00
docker exec -i medassist_pg psql -U medassist_user -d medassist < rollback/R_V3__rollback.sql

# Supprimer l'entrée Flyway
DELETE FROM flyway_schema_history WHERE version = '3.0';
```

**Temps de récupération** : ~15 minutes
**Impact** : Restaure les anciennes colonnes, triggers redeviennent actifs
**Limitation** : Nécessite une décision managériale (irréversible en prod)

---

## ✅ Checklist pré-déploiement

### Avant Dimanche 1 (Phase EXPAND)
- [ ] Tous les tests passent localement
- [ ] V2__expand_schema.sql review OK
- [ ] R_V2__rollback.sql testé et validé
- [ ] Backup procedure testée
- [ ] Monitoring dashboards prêts
- [ ] Team ops formée
- [ ] Communication clients envoyée

### Avant Dimanche 2 (Déploiement App V2)
- [ ] Phase EXPAND s'est bien déroulée
- [ ] 0 erreurs en logs pendant 1 semaine
- [ ] Performances stables (requêtes < 120ms)
- [ ] Données cohérentes V1 ↔ V2
- [ ] Application V2 testée en pré-prod
- [ ] Rollback V2 procédure en place
- [ ] Load balancer config prêt

### Avant Dimanche 3 (Phase CONTRACT)
- [ ] Application V2 stable en production depuis 1 semaine
- [ ] V3__contract_schema.sql review OK
- [ ] R_V3__rollback.sql testé
- [ ] 0 erreurs en logs
- [ ] Performances stables
- [ ] Vraiment prêt ? 🤔

---

## 📊 Métriques de succès

Chaque phase doit valider :

| Métrique | Cible | Test |
|----------|-------|------|
| **Zéro downtime** | SLA 99.9% | Monitoring uptime |
| **Pas de perte données** | 100% intégrité | Row count avant/après |
| **Performance** | < 120ms | EXPLAIN ANALYZE |
| **0 erreurs applicatives** | 0 ERRORs en logs | Grep logs |
| **Triggers synchronisés** | Cohérence V1/V2 | SQL tests |

---

## 🛠️ Commandes d'exécution

### Déployer V2 (Phase EXPAND)
```bash
docker-compose run --rm flyway migrate
# Ou cible spécifique
docker-compose run --rm flyway -target=2 migrate
```

### Tester Phase EXPAND
```bash
docker exec -it medassist_pg psql -U medassist_user -d medassist < tests/test_evolution_A.sql
docker exec -it medassist_pg psql -U medassist_user -d medassist < tests/test_evolution_B.sql
docker exec -it medassist_pg psql -U medassist_user -d medassist < tests/test_evolution_C.sql
docker exec -it medassist_pg psql -U medassist_user -d medassist < tests/test_evolution_D.sql
docker exec -it medassist_pg psql -U medassist_user -d medassist < tests/test_evolution_E.sql
```

### Déployer V3 (Phase CONTRACT)
```bash
docker-compose run --rm flyway migrate
# Ou cible spécifique
docker-compose run --rm flyway -target=3 migrate
```

### Tester Phase CONTRACT
```bash
docker exec -it medassist_pg psql -U medassist_user -d medassist < tests/test_contract.sql
```

---

## 🔔 Points critiques

### ⚠️ Dimanche 1 - EXPAND
- **Risque** : Table gonflée temporairement (15% de ressources en plus)
- **Solution** : Monitoring des `pg_table_size` pendant migration
- **Mitigation** : INDEX créés en parallèle (non-bloquant)

### ❌ Dimanche 3 - CONTRACT
- **Risque** : Irréversible - impossible de revenir au vrai schéma V1
- **Solution** : Rollback R_V3 restaure colonnes mais pas dans le bon ordre
- **Mitigation** : 1 semaine de monitoring avant CONTRACT + decision managériale

### 🔥 En cas de panique
**Pendant n'importe quelle phase** :
1. **Panique ?** → Exécuter rollback immédiatement
2. **Connecté ?** → Check logs + performances
3. **Données OK ?** → Relancer la phase
4. **Données corrompues ?** → Restaurer du backup

---

## 📞 Escalade

| Problème | Action | Qui | Quand |
|----------|--------|-----|-------|
| Migration lente | Monitor pg_stat_activity | DBA | En live |
| Erreurs SQL | Vérifier logs Flyway | Dev | En live |
| Données incohérentes | Comparer row counts | DBA | En live |
| Performance dégradée | Rollback immédiat | Ops | En live |
| Panique générale | Rollback complet | Manager | Décision |

---

## 📝 Logs à monitorer

### Pendant Phase EXPAND
```bash
# Logs Flyway
docker logs medassist_flyway

# Logs PostgreSQL
docker logs medassist_pg | grep -E "ERROR|WARNING"

# Monitoring basique
docker stats medassist_pg

# Vérifier séquence Flyway
SELECT * FROM flyway_schema_history ORDER BY installed_rank DESC LIMIT 5;
```

### Performance
```sql
-- Requêtes lentes ?
SELECT * FROM pg_stat_statements ORDER BY mean_time DESC LIMIT 10;

-- Locks ?
SELECT * FROM pg_locks;

-- Table size ?
SELECT relname, pg_size_pretty(pg_total_relation_size(relid)) 
FROM pg_stat_user_tables ORDER BY pg_total_relation_size(relid) DESC;
```

---

## ✨ Après CONTRACT - Optimisations futures

Une fois V3 déployée, on peut :
- Supprimer la table `consultations` (garder `consultations_partitioned`)
- Supprimer les vues de compatibilité
- Purger les logs Flyway anciens
- Archiver les anciennes données si nécessaire

Mais ce n'est pas urgent - le schéma V3 fonctionne parfaitement tel quel.
