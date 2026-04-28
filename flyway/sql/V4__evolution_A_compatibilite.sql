-- V4_evolution_A_compatibilite.sql
-- Cette vue permet aux applications V1 de continuer à lire les adresses 
-- alors qu'elles ont été déplacées dans une autre table[cite: 293, 401].

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
    a.line1 AS address_line1,
    a.line2 AS address_line2,
    a.city,
    a.postal_code,
    p.created_at, 
    p.updated_at
FROM patients p
LEFT JOIN addresses a ON p.id = a.patient_id AND a.is_primary = TRUE;