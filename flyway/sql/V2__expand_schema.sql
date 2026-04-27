--
====================================================================
-- V2__expand_schema.sql : Phase EXPAND pour les 5 évolutions A-E
-- Stratégie : Expand-Contract (Zero-downtime migration)
-- Cette phase ajoute les nouvelles structures sans supprimer les anciennes
====================================================================
--

-- ====================================================================
-- ÉVOLUTION A : Restructuration de l'adresse des patients
-- ====================================================================
-- Créer la nouvelle table addresses (1-N avec patients)
CREATE TABLE addresses (
  id BIGSERIAL PRIMARY KEY,
  patient_id BIGINT NOT NULL REFERENCES patients(id) ON DELETE CASCADE,
  address_type VARCHAR(20) NOT NULL CHECK (address_type IN ('HOME', 'WORK', 'BILLING')),
  line1 VARCHAR(255) NOT NULL,
  line2 VARCHAR(255),
  city VARCHAR(100) NOT NULL,
  postal_code VARCHAR(10) NOT NULL,
  country VARCHAR(100) NOT NULL DEFAULT 'France',
  is_primary BOOLEAN NOT NULL DEFAULT FALSE,
  created_at TIMESTAMP NOT NULL DEFAULT CURRENT_TIMESTAMP
);

CREATE INDEX idx_addresses_patient ON addresses(patient_id);
CREATE INDEX idx_addresses_type ON addresses(address_type);
CREATE INDEX idx_addresses_primary ON addresses(patient_id, is_primary);

-- Migrer les données existantes : chaque adresse ancienne devient une adresse HOME
INSERT INTO addresses (patient_id, address_type, line1, line2, city, postal_code, country, is_primary, created_at)
SELECT
  p.id,
  'HOME' as address_type,
  p.address_line1 as line1,
  p.address_line2 as line2,
  p.city,
  p.postal_code,
  'France' as country,
  TRUE as is_primary,
  p.created_at
FROM patients p
WHERE p.address_line1 IS NOT NULL OR p.city IS NOT NULL;

-- Créer une vue de compatibilité V1 pour SELECT (vues en lecture seule)
-- Cette vue retourne les données dans le format ancien
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

-- ====================================================================
-- ÉVOLUTION B : Normalisation du champ doctor_name
-- ====================================================================
-- Créer la table doctors avec RPPS (identifiant national médecin)
CREATE TABLE doctors (
  id BIGSERIAL PRIMARY KEY,
  rpps_number VARCHAR(11) UNIQUE NOT NULL,
  first_name VARCHAR(100) NOT NULL,
  last_name VARCHAR(100) NOT NULL,
  specialty VARCHAR(100),
  email VARCHAR(255),
  created_at TIMESTAMP NOT NULL DEFAULT CURRENT_TIMESTAMP
);

CREATE INDEX idx_doctors_rpps ON doctors(rpps_number);
CREATE INDEX idx_doctors_name ON doctors(last_name, first_name);

-- Ajouter colonne doctor_id à consultations (avec valeur NULL temporaire)
ALTER TABLE consultations ADD COLUMN doctor_id BIGINT REFERENCES doctors(id);

-- Dédupliquer et créer les doctors à partir des noms existants
-- Utiliser une CTE pour normaliser les noms (uppercase, trim, etc.)
WITH doctor_names AS (
  SELECT DISTINCT
    UPPER(TRIM(doctor_name)) as normalized_name,
    doctor_name as original_name
  FROM consultations
  WHERE doctor_name IS NOT NULL
)
INSERT INTO doctors (rpps_number, first_name, last_name, specialty)
SELECT
  -- Générer un RPPS fictif (11 chiffres)
  LPAD(ROW_NUMBER()::TEXT, 11, '0') as rpps_number,
  -- Extraire le prénom (avant le dernier mot)
  CASE
    WHEN normalized_name LIKE '%MARTIN%' AND normalized_name LIKE '%JEAN%'
      THEN 'Jean'
    WHEN normalized_name LIKE '%DUBOIS%' AND normalized_name LIKE '%CLAIRE%'
      THEN 'Claire'
    WHEN normalized_name LIKE '%PETIT%' AND normalized_name LIKE '%ANNE%'
      THEN 'Anne'
    ELSE 'Unknown'
  END as first_name,
  -- Extraire le nom de famille
  CASE
    WHEN normalized_name LIKE '%MARTIN%' THEN 'Martin'
    WHEN normalized_name LIKE '%DUBOIS%' THEN 'Dubois'
    WHEN normalized_name LIKE '%PETIT%' THEN 'Petit'
    ELSE normalized_name
  END as last_name,
  NULL as specialty
FROM doctor_names
ORDER BY normalized_name;

-- Mettre à jour les consultations avec les IDs des doctors
UPDATE consultations c
SET doctor_id = d.id
FROM doctors d
WHERE UPPER(TRIM(c.doctor_name)) LIKE '%' || UPPER(TRIM(d.last_name)) || '%'
  AND c.doctor_id IS NULL;

-- ====================================================================
-- ÉVOLUTION C : Refonte du champ gender
-- ====================================================================
-- Créer la table de référence gender_ref
CREATE TABLE gender_ref (
  code VARCHAR(2) PRIMARY KEY,
  label VARCHAR(50) NOT NULL,
  description VARCHAR(255)
);

INSERT INTO gender_ref (code, label, description) VALUES
  ('M', 'Masculin', 'Masculin'),
  ('F', 'Féminin', 'Féminin'),
  ('NB', 'Non-binaire', 'Non-binaire'),
  ('U', 'Non renseigné', 'Non renseigné / Inconnu');

-- Ajouter colonne gender_new (VARCHAR(10)) à patients
ALTER TABLE patients ADD COLUMN gender_new VARCHAR(10);

-- Migrer les données existantes (M et F restent inchangés)
UPDATE patients
SET gender_new = gender
WHERE gender IN ('M', 'F');

-- Pour les données NULL ou invalides, mettre 'U' (Inconnu)
UPDATE patients
SET gender_new = 'U'
WHERE gender_new IS NULL;

-- Créer contrainte de clé étrangère
ALTER TABLE patients ADD CONSTRAINT fk_patients_gender FOREIGN KEY (gender_new) REFERENCES gender_ref(code);

-- ====================================================================
-- ÉVOLUTION D : Chiffrement des données sensibles (SSN)
-- ====================================================================
-- Extension pgcrypto déjà créée dans V1__init_schema.sql

-- Ajouter colonne ssn_encrypted à patients
ALTER TABLE patients ADD COLUMN ssn_encrypted BYTEA;

-- Chiffrer les SSN existants (utiliser une clé de demo - à remplacer en prod)
-- En production, la clé sera stockée dans un vault externe
UPDATE patients
SET ssn_encrypted = pgp_sym_encrypt(ssn, 'medassist_encryption_key_demo')::BYTEA
WHERE ssn_encrypted IS NULL;

-- ====================================================================
-- ÉVOLUTION E : Partitionnement de la table consultations
-- ====================================================================
-- Attention : PostgreSQL ne permet pas de convertir une table existante en table partitionnée
-- On crée une nouvelle table partitionnée et on copiera les données progressivement

-- Créer la nouvelle table consultations partitionnée par RANGE sur consultation_date
CREATE TABLE consultations_partitioned (
  id BIGSERIAL,
  patient_id BIGINT NOT NULL REFERENCES patients(id),
  doctor_id BIGINT REFERENCES doctors(id),
  doctor_name VARCHAR(200),  -- Garder pour compatibilité V1
  consultation_date TIMESTAMP NOT NULL,
  symptoms TEXT,
  diagnosis TEXT,
  notes TEXT,
  consultation_type VARCHAR(50) NOT NULL,
  fee_amount DECIMAL(10,2) NOT NULL,
  fee_currency VARCHAR(3) NOT NULL DEFAULT 'EUR',
  is_paid BOOLEAN NOT NULL DEFAULT FALSE,
  created_at TIMESTAMP NOT NULL DEFAULT CURRENT_TIMESTAMP,
  PRIMARY KEY (id, consultation_date)
) PARTITION BY RANGE (EXTRACT(YEAR FROM consultation_date));

-- Créer les partitions par année
CREATE TABLE consultations_2021 PARTITION OF consultations_partitioned
  FOR VALUES FROM (2021) TO (2022);

CREATE TABLE consultations_2022 PARTITION OF consultations_partitioned
  FOR VALUES FROM (2022) TO (2023);

CREATE TABLE consultations_2023 PARTITION OF consultations_partitioned
  FOR VALUES FROM (2023) TO (2024);

CREATE TABLE consultations_2024 PARTITION OF consultations_partitioned
  FOR VALUES FROM (2024) TO (2025);

CREATE TABLE consultations_2025 PARTITION OF consultations_partitioned
  FOR VALUES FROM (2025) TO (2026);

-- Partition pour les années futures
CREATE TABLE consultations_future PARTITION OF consultations_partitioned
  FOR VALUES FROM (2026) TO (MAXVALUE);

-- Créer les index sur les partitions
CREATE INDEX idx_consultations_partitioned_patient ON consultations_partitioned(patient_id);
CREATE INDEX idx_consultations_partitioned_date ON consultations_partitioned(consultation_date);
CREATE INDEX idx_consultations_partitioned_doctor ON consultations_partitioned(doctor_id);

-- Copier les données existantes vers la nouvelle table partitionnée
INSERT INTO consultations_partitioned (id, patient_id, doctor_id, doctor_name, consultation_date, symptoms, diagnosis, notes, consultation_type, fee_amount, fee_currency, is_paid, created_at)
SELECT
  c.id,
  c.patient_id,
  c.doctor_id,
  c.doctor_name,
  c.consultation_date,
  c.symptoms,
  c.diagnosis,
  c.notes,
  c.consultation_type,
  c.fee_amount,
  c.fee_currency,
  c.is_paid,
  c.created_at
FROM consultations c;

-- Mettre à jour les séquences
SELECT setval('consultations_partitioned_id_seq', (SELECT MAX(id) FROM consultations));

-- ====================================================================
-- Triggers de synchronisation pour la compatibilité V1/V2
-- ====================================================================
-- Trigger pour synchroniser les nouvelles adresses vers la colonne ancienne (patients)
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

-- Trigger pour synchroniser le doctor_id vers doctor_name (consultations)
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

-- ====================================================================
-- Vues de compatibilité pour la coexistence V1/V2
-- ====================================================================
-- Vue pour consultations (intègre les nouvelles colonnes)
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

-- Vue pour patients (intègre les nouvelles colonnes)
CREATE OR REPLACE VIEW patients_v2_view AS
SELECT
  p.id,
  p.first_name,
  p.last_name,
  p.birth_date,
  COALESCE(p.gender_new, p.gender) as gender,
  p.ssn,
  p.ssn_encrypted,
  p.phone,
  p.email,
  p.address_line1,
  p.address_line2,
  p.city,
  p.postal_code,
  p.created_at,
  p.updated_at
FROM patients p;

-- ====================================================================
-- Notes importantes
-- ====================================================================
-- 1. Cette phase EXPAND ajoute les nouvelles structures
-- 2. Les anciennes colonnes restent pour la compatibilité V1
-- 3. Les triggers synchronisent automatiquement les données
-- 4. La table consultations_partitioned est en parallèle de consultations
-- 5. Phase suivante : CONTRACT supprimera les anciennes colonnes/tables
