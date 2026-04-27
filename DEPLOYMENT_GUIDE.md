# Guide de Deploiement - Phases Expand-Contract

Ce document decrit la procedure de deploiement des migrations MedAssist en production.

## 1. Vue d'ensemble

La migration suit une strategie Expand-Contract en 3 fenetres de maintenance (3 dimanches).

| Fenetre | Duree | Phase | Niveau de risque | Rollback |
|---------|-------|-------|------------------|----------|
| Dimanche 1 | 4h | EXPAND (V2) | Modere | R_V2 |
| Dimanche 2 | 4h | Validation applicative | Faible | N/A |
| Dimanche 3 | 4h | CONTRACT (V3) | Eleve | R_V3 |

## 2. Timeline de deploiement

### Preparation (Semaine 0)
- Revue des scripts Flyway (V2 et V3)
- Validation des tests en environnement de pre-production
- Preparation et test des scripts de rollback
- Validation du plan d'exploitation
- Communication vers les equipes concernees

### Dimanche 1 - Phase EXPAND
- 02:00-02:15 : Backup complet de la base
- 02:15-02:30 : Verification des transactions longues
- 02:30 : Decision GO/NO-GO
- 02:30-03:00 : Execution de V2__expand_schema.sql
- 03:00-03:30 : Validation des donnees migrees (tests A a E)
- 03:30-04:00 : Validation post-deploiement

Resultat attendu : coexistence des structures V1 et V2.

### Semaine 1 - Monitoring
- Monitoring des performances et erreurs applicatives
- Verification de la synchronisation V1/V2
- Verification de la coherence des donnees

### Dimanche 2 - Deploiement applicatif V2
- 02:00-02:15 : Debut du deploiement progressif
- 02:15-03:00 : Verification en parallele
- 03:00-04:00 : Bascule progressive vers V2

Resultat attendu : application V2 active, avec structures V2 et compatibilite transitoire.

### Semaine 2 - Stabilisation
- Monitoring renforce
- Verification d'absence de regressions
- Revue finale avant phase CONTRACT

### Dimanche 3 - Phase CONTRACT
- 02:00-02:15 : Backup complet et snapshots
- 02:15-02:30 : Verification finale de stabilite
- 02:30 : Decision GO/NO-GO finale
- 02:30-03:00 : Execution de V3__contract_schema.sql
- 03:00-03:30 : Execution de test_contract.sql
- 03:30-04:00 : Validation finale

Resultat attendu : schema final V2 sans structures V1 obsoletes.

## 3. Procedures de rollback

### Rollback de la phase EXPAND (Dimanche 1)
En cas d'incident entre 02:30 et 04:00 :

```bash
docker exec -i medassist_pg psql -U medassist_user -d medassist < rollback/R_V2__rollback.sql
```

Puis, si necessaire :

```sql
DELETE FROM flyway_schema_history WHERE version = '2.0';
```

Temps de recuperation cible : environ 15 minutes.

### Rollback de la phase CONTRACT (Dimanche 3)
En cas d'incident entre 02:30 et 04:00 :

```bash
docker exec -i medassist_pg psql -U medassist_user -d medassist < rollback/R_V3__rollback.sql
```

Puis, si necessaire :

```sql
DELETE FROM flyway_schema_history WHERE version = '3.0';
```

Temps de recuperation cible : environ 15 minutes.

## 4. Checklist pre-deploiement

### Avant Dimanche 1 (EXPAND)
- [ ] Tous les tests passent en pre-production
- [ ] Revue V2 terminee
- [ ] Rollback V2 teste
- [ ] Procedure de backup validee
- [ ] Monitoring operationnel

### Avant Dimanche 2 (Application V2)
- [ ] Phase EXPAND validee
- [ ] Donnees coherentes V1/V2
- [ ] Application V2 validee
- [ ] Procedure de rollback disponible

### Avant Dimanche 3 (CONTRACT)
- [ ] Application V2 stable en production
- [ ] Revue V3 terminee
- [ ] Rollback V3 teste
- [ ] Performances stables

## 5. Metriques de succes

| Metrique | Cible | Verification |
|----------|-------|--------------|
| Disponibilite | SLA 99.9% | Monitoring uptime |
| Integrite des donnees | 100% | Comparaison avant/apres |
| Performance | < 120 ms | Requetes de controle |
| Erreurs applicatives | 0 critique | Logs applicatifs |

## 6. Commandes d'execution

### Migration V2
```bash
docker-compose run --rm flyway -target=2 migrate
```

### Tests phase EXPAND
```bash
docker exec -i medassist_pg psql -U medassist_user -d medassist < tests/test_evolution_A.sql
docker exec -i medassist_pg psql -U medassist_user -d medassist < tests/test_evolution_B.sql
docker exec -i medassist_pg psql -U medassist_user -d medassist < tests/test_evolution_C.sql
docker exec -i medassist_pg psql -U medassist_user -d medassist < tests/test_evolution_D.sql
docker exec -i medassist_pg psql -U medassist_user -d medassist < tests/test_evolution_E.sql
```

### Migration V3
```bash
docker-compose run --rm flyway -target=3 migrate
```

### Test phase CONTRACT
```bash
docker exec -i medassist_pg psql -U medassist_user -d medassist < tests/test_contract.sql
```

## 7. Escalade

| Probleme | Action immediate | Responsable |
|----------|------------------|-------------|
| Migration lente | Analyse pg_stat_activity | DBA |
| Erreurs SQL | Analyse logs Flyway | Dev |
| Donnees incoherentes | Verification des volumes | DBA |
| Performance degradee | Activation rollback | Ops |

## 8. Logs et controles

```bash
docker logs medassist_pg
docker stats medassist_pg
```

```sql
SELECT * FROM flyway_schema_history ORDER BY installed_rank DESC LIMIT 5;
SELECT * FROM pg_locks;
```
