--
====================================================================
-- R_V3__rollback.sql : Retour en arrière pour annuler V3__contract_schema.sql
-- Restaure les anciennes colonnes/vues/triggers supprimés
====================================================================
--

-- ⚠️ ATTENTION : Ce rollback restaure la structure mais PAS les données supprimées
-- Les données dans les nouvelles tables (addresses, doctors) restent intactes

-- ====================================================================
-- Restaurer ÉVOLUTION A : Adresses
-- ====================================================================
-- Recréer les colonnes supprimées dans patients
ALTER TABLE patients
  ADD COLUMN address_line1 VARCHAR(255),
  ADD COLUMN address_line2 VARCHAR(255),
  ADD COLUMN city VARCHAR(100),
  ADD COLUMN postal_code VARCHAR(10);

-- Repeupler les colonnes depuis addresses
UPDATE patients p
SET
  address_line1 = a.line1,
  address_line2 = a.line2,
  city = a.city,
  postal_code = a.postal_code
FROM addresses a
WHERE a.patient_id = p.id AND a.is_primary = TRUE;

-- Recréer le trigger de synchronisation
CREATE OR REPLACE FUNCTION sync_address_to_patients()
RETURNS TRIGGER AS $$
BEGIN
  IF NEW.is_primary = TRUE THEN
    UPDATE patients
    SET
      address_line1 = NEW.line1,
      address_line2 = NEW.line2,
      city = NEW.city,
      postal_code = NEW.postal_code,
      updated_at = CURRENT_TIMESTAMP
    WHERE id = NEW.patient_id;
  END IF;
  RETURN NEW;
END;
$$ LANGUAGE plpgsql;

CREATE TRIGGER trg_sync_address_to_patients
AFTER INSERT OR UPDATE ON addresses
FOR EACH ROW
EXECUTE FUNCTION sync_address_to_patients();

-- Recréer la vue de compatibilité V1
CREATE OR REPLACE VIEW patients_v1_view AS
SELECT
  p.id,
  p.first_name,
  p.last_name,
  p.birth_date,
  p.gender,
  p.ssn,
  p.phone,
  p.email,
  COALESCE(a.line1, '') as address_line1,
  COALESCE(a.line2, '') as address_line2,
  COALESCE(a.city, '') as city,
  COALESCE(a.postal_code, '') as postal_code,
  p.created_at,
  p.updated_at
FROM patients p
LEFT JOIN addresses a ON p.id = a.patient_id AND a.is_primary = TRUE;

RAISE NOTICE '[✓] ROLLBACK ÉVOLUTION A : Adresses restaurées';

-- ====================================================================
-- Restaurer ÉVOLUTION B : Doctors
-- ====================================================================
-- Recréer la colonne doctor_name dans consultations
ALTER TABLE consultations ADD COLUMN doctor_name VARCHAR(200);

-- Repeupler doctor_name depuis doctors
UPDATE consultations c
SET doctor_name = 'Dr ' || d.first_name || ' ' || d.last_name
FROM doctors d
WHERE c.doctor_id = d.id AND c.doctor_name IS NULL;

-- Recréer le trigger de synchronisation doctor
CREATE OR REPLACE FUNCTION sync_doctor_to_name()
RETURNS TRIGGER AS $$
DECLARE
  v_doctor_name VARCHAR(200);
BEGIN
  IF NEW.doctor_id IS NOT NULL THEN
    SELECT 'Dr ' || d.first_name || ' ' || d.last_name INTO v_doctor_name
    FROM doctors d
    WHERE d.id = NEW.doctor_id;
    
    NEW.doctor_name := v_doctor_name;
  END IF;
  RETURN NEW;
END;
$$ LANGUAGE plpgsql;

CREATE TRIGGER trg_sync_doctor_to_name
BEFORE INSERT OR UPDATE ON consultations
FOR EACH ROW
EXECUTE FUNCTION sync_doctor_to_name();

-- Recréer la vue de compatibilité
CREATE OR REPLACE VIEW consultations_v2_view AS
SELECT
  c.id,
  c.patient_id,
  COALESCE(d.first_name || ' ' || d.last_name, c.doctor_name) as doctor_name,
  c.consultation_date,
  c.symptoms,
  c.diagnosis,
  c.notes,
  c.consultation_type,
  c.fee_amount,
  c.fee_currency,
  c.is_paid,
  c.created_at,
  c.doctor_id
FROM consultations c
LEFT JOIN doctors d ON c.doctor_id = d.id;

RAISE NOTICE '[✓] ROLLBACK ÉVOLUTION B : Doctors restaurés';

-- ====================================================================
-- Restaurer ÉVOLUTION C : Gender
-- ====================================================================
-- Recréer la colonne gender_old (CHAR(1))
ALTER TABLE patients ADD COLUMN gender_old CHAR(1);

-- Repeupler gender_old depuis gender
UPDATE patients
SET gender_old = gender
WHERE gender IN ('M', 'F');

-- Renommer les colonnes pour restaurer l'ordre
ALTER TABLE patients RENAME COLUMN gender TO gender_new;
ALTER TABLE patients RENAME COLUMN gender_old TO gender;

-- Ajouter la contrainte CHECK sur l'ancien gender
ALTER TABLE patients ADD CONSTRAINT check_gender_old CHECK (gender IN ('M', 'F', 'M', 'F', 'NB', 'U'));

RAISE NOTICE '[✓] ROLLBACK ÉVOLUTION C : Gender restauré';

-- ====================================================================
-- Restaurer ÉVOLUTION D : Chiffrement
-- ====================================================================
-- Les colonnes ssn et ssn_encrypted restent intactes
-- Aucune action nécessaire

-- Supprimer l'index créé (optionnel)
DROP INDEX IF EXISTS idx_patients_ssn_encrypted;

RAISE NOTICE '[✓] ROLLBACK ÉVOLUTION D : Chiffrement inchangé';

-- ====================================================================
-- Restaurer ÉVOLUTION E : Partitionnement
-- ====================================================================
-- Supprimer la vue consultations_legacy
DROP VIEW IF EXISTS consultations_legacy;

-- Les tables consultations et consultations_partitioned restent intactes

RAISE NOTICE '[✓] ROLLBACK ÉVOLUTION E : Partitionnement inchangé';

-- ====================================================================
-- Résumé du rollback
-- ====================================================================
RAISE NOTICE '========== ROLLBACK V3 COMPLÉTÉ ==========';
RAISE NOTICE 'État restauré : Phase EXPAND (V2)';
RAISE NOTICE 'Les données restent intactes';
RAISE NOTICE 'Les triggers de synchronisation sont actifs';
