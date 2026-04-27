--
====================================================================
-- R_V2__rollback.sql : Retour en arrière pour annuler V2__expand_schema.sql
-- ATTENTION: Ce script supprime les nouvelles structures créées
====================================================================
--

-- Sauvegarder les données chiffrées avant suppression (optionnel)
-- INSERT INTO ssn_backup SELECT * FROM patients WHERE ssn_encrypted IS NOT NULL;

-- ====================================================================
-- Supprimer les triggers de synchronisation
-- ====================================================================
DROP TRIGGER IF EXISTS trg_sync_address_to_patients ON addresses;
DROP FUNCTION IF EXISTS sync_address_to_patients();

DROP TRIGGER IF EXISTS trg_sync_doctor_to_name ON consultations;
DROP FUNCTION IF EXISTS sync_doctor_to_name();

-- ====================================================================
-- Supprimer les vues de compatibilité
-- ====================================================================
DROP VIEW IF EXISTS patients_v1_view;
DROP VIEW IF EXISTS patients_v2_view;
DROP VIEW IF EXISTS consultations_v2_view;

-- ====================================================================
-- Supprimer les colonnes ajoutées à consultations
-- ====================================================================
ALTER TABLE consultations DROP COLUMN IF EXISTS doctor_id;

-- ====================================================================
-- Supprimer les colonnes ajoutées à patients
-- ====================================================================
ALTER TABLE patients DROP COLUMN IF EXISTS gender_new;
ALTER TABLE patients DROP COLUMN IF EXISTS ssn_encrypted;

-- ====================================================================
-- Supprimer les tables créées
-- ====================================================================
-- Supprimer les contraintes de clé étrangère vers doctors
ALTER TABLE IF EXISTS consultations DROP CONSTRAINT IF EXISTS fk_consultations_doctor_id;

-- Supprimer la table consultations_partitioned et ses partitions
DROP TABLE IF EXISTS consultations_partitioned CASCADE;

-- Supprimer la table doctors
DROP TABLE IF EXISTS doctors CASCADE;

-- Supprimer la table gender_ref
DROP TABLE IF EXISTS gender_ref CASCADE;

-- Supprimer la table addresses et restaurer les données dans patients
-- (Les données sont toujours dans patients car on n'a pas supprimé les colonnes)
DROP TABLE IF EXISTS addresses CASCADE;

-- ====================================================================
-- État final
-- ====================================================================
-- Le schéma est revenu à l'état V1
-- Les colonnes address_line1, address_line2, city, postal_code de patients sont toujours remplies
-- Le champ doctor_name dans consultations est toujours présent
-- Les colonnes new/encrypted dans patients ont été supprimées
