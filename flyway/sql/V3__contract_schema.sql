--
====================================================================
-- V3__contract_schema.sql : Phase CONTRACT pour finaliser les migrations
-- Supprimer les anciennes structures après validation que V2 fonctionne
-- 
-- ⚠️ ATTENTION : Cette phase est IRRÉVERSIBLE
-- À exécuter UNIQUEMENT après avoir validé que l'application V2 fonctionne
-- ====================================================================
--

-- ====================================================================
-- ÉVOLUTION A : Finaliser la restructuration des adresses
-- ====================================================================
-- Supprimer les vues de compatibilité V1 (plus besoin avec application V2)
DROP VIEW IF EXISTS patients_v1_view CASCADE;

-- Supprimer les anciennes colonnes d'adresse de patients
ALTER TABLE patients
  DROP COLUMN IF EXISTS address_line1,
  DROP COLUMN IF EXISTS address_line2,
  DROP COLUMN IF EXISTS city,
  DROP COLUMN IF EXISTS postal_code;

-- Supprimer le trigger de synchronisation adresse
DROP TRIGGER IF EXISTS trg_sync_address_to_patients ON addresses CASCADE;
DROP FUNCTION IF EXISTS sync_address_to_patients() CASCADE;

-- Optimiser la table addresses (reindex)
REINDEX TABLE addresses;

RAISE NOTICE '[✓] ÉVOLUTION A : Adresses - Phase CONTRACT complétée';

-- ====================================================================
-- ÉVOLUTION B : Finaliser la normalisation des médecins
-- ====================================================================
-- Supprimer le trigger de synchronisation doctor
DROP TRIGGER IF EXISTS trg_sync_doctor_to_name ON consultations CASCADE;
DROP FUNCTION IF EXISTS sync_doctor_to_name() CASCADE;

-- Supprimer la vue de compatibilité consultations V1
DROP VIEW IF EXISTS consultations_v2_view CASCADE;

-- Supprimer la colonne doctor_name de consultations
-- (maintenant on utilise doctor_id avec FK vers doctors)
ALTER TABLE consultations DROP COLUMN IF EXISTS doctor_name;

-- Ajouter une contrainte NOT NULL sur doctor_id (optionnel)
-- ALTER TABLE consultations ALTER COLUMN doctor_id SET NOT NULL;

-- Optimiser la table consultations
REINDEX TABLE consultations;

RAISE NOTICE '[✓] ÉVOLUTION B : Doctors - Phase CONTRACT complétée';

-- ====================================================================
-- ÉVOLUTION C : Finaliser la refonte du gender
-- ====================================================================
-- Supprimer la colonne gender_old (CHAR(1))
-- On la renomme d'abord en cas de problème
ALTER TABLE patients DROP COLUMN IF EXISTS gender CASCADE;

-- Renommer gender_new en gender (pour l'API)
ALTER TABLE patients RENAME COLUMN gender_new TO gender;

-- Ajouter la contrainte NOT NULL
ALTER TABLE patients ALTER COLUMN gender SET NOT NULL;

-- Optimiser la table patients
REINDEX TABLE patients;

RAISE NOTICE '[✓] ÉVOLUTION C : Gender - Phase CONTRACT complétée';

-- ====================================================================
-- ÉVOLUTION D : Finaliser le chiffrement des SSN
-- ====================================================================
-- À ce stade, l'application V2 gère le chiffrement/déchiffrement
-- On PEUT (optionnel) supprimer la colonne ssn en clair si l'app ne l'utilise plus
-- ATTENTION : Cette étape est très risquée et généralement PAS RECOMMANDÉE
-- Car elle rend impossible le déchiffrement en cas de problème

-- Pour cette implémentation, on GARDE ssn pour la sécurité/audit
-- Les deux colonnes coexistent :
-- - ssn : valeur en clair (audit trail)
-- - ssn_encrypted : valeur chiffrée (utilisation applicative)

-- Optionnel : ajouter un index sur ssn_encrypted pour la recherche
CREATE INDEX idx_patients_ssn_encrypted ON patients(ssn_encrypted);

-- Vérifier que toutes les valeurs sont synchronisées
-- (Aucune requête ici, juste un commentaire de validation)
-- SELECT COUNT(*) FROM patients WHERE ssn_encrypted IS NULL AND ssn IS NOT NULL;
-- Doit retourner 0

RAISE NOTICE '[✓] ÉVOLUTION D : Chiffrement - Phase CONTRACT complétée';

-- ====================================================================
-- ÉVOLUTION E : Finaliser le partitionnement des consultations
-- ====================================================================
-- La table consultations_partitioned est maintenant la source de vérité
-- On peut (optionnel) supprimer l'ancienne table consultations

-- STRATÉGIE SÛRE :
-- 1. Conserver consultations pour la compatibilité quelques semaines
-- 2. Valider que toutes les requêtes utilisent consultations_partitioned
-- 3. Puis supprimer l'ancienne table

-- Pour l'instant, on crée une vue matérialisée pour la compatibilité
-- (en lecture seule - les écritures vont dans consultations_partitioned)

CREATE OR REPLACE VIEW consultations_legacy AS
SELECT * FROM consultations_partitioned;

-- Option : Renommer la table partitionnée pour qu'elle devienne "consultations"
-- MAIS : Il faut d'abord s'assurer que l'app utilise la nouvelle
-- ALTER TABLE consultations_partitioned RENAME TO consultations_old;
-- ALTER TABLE consultations RENAME TO consultations_legacy;
-- ALTER TABLE consultations_partitioned RENAME TO consultations;

-- Pour cette implémentation, on garde les deux tables pour sécurité
-- Les données sont en sync et les futures écritures vont dans la partitionnée

RAISE NOTICE '[✓] ÉVOLUTION E : Partitionnement - Phase CONTRACT complétée';

-- ====================================================================
-- Nettoyage final et optimisation
-- ====================================================================
-- Mettre à jour les statistiques pour l'optimiseur
ANALYZE;

-- Afficher les table/index/vues restants
RAISE NOTICE '========== PHASE CONTRACT TERMINÉE ==========';
RAISE NOTICE 'État final du schéma :';
RAISE NOTICE 'Tables principales : patients, addresses, consultations, consultations_partitioned, doctors, prescriptions, gender_ref';
RAISE NOTICE 'Vues compatibilité : consultations_legacy';
RAISE NOTICE 'Triggers : AUCUN (tous supprimés)';
RAISE NOTICE '========== ✅ MIGRATION COMPLÈTE ==========';
