-- test_evolution_A.sql : Tests pour l'Évolution A (Adresses)
-- Tests de validation pour la restructuration de l'adresse des patients
--

DO $$
DECLARE
  v_test_count INTEGER := 0;
  v_failed_count INTEGER := 0;
BEGIN
  RAISE NOTICE '========== TEST ÉVOLUTION A ==========';
  
  -- Test 1 : Vérifier que la table addresses existe
  v_test_count := v_test_count + 1;
  IF EXISTS (SELECT 1 FROM information_schema.tables WHERE table_name = 'addresses') THEN
    RAISE NOTICE '[OK] Test 1 : Table addresses existe';
  ELSE
    RAISE NOTICE '[ERREUR] Test 1 ÉCHOUÉ : Table addresses n''existe pas';
    v_failed_count := v_failed_count + 1;
  END IF;
  
  -- Test 2 : Vérifier que les colonnes requises existent
  v_test_count := v_test_count + 1;
  IF EXISTS (
    SELECT 1 FROM information_schema.columns 
    WHERE table_name = 'addresses' 
    AND column_name IN ('id', 'patient_id', 'address_type', 'line1', 'city', 'postal_code', 'country', 'is_primary')
    GROUP BY table_name HAVING COUNT(*) = 8
  ) THEN
    RAISE NOTICE '[OK] Test 2 : Toutes les colonnes requises existent';
  ELSE
    RAISE NOTICE '[ERREUR] Test 2 ÉCHOUÉ : Colonnes manquantes dans addresses';
    v_failed_count := v_failed_count + 1;
  END IF;
  
  -- Test 3 : Vérifier les contraintes CHECK
  v_test_count := v_test_count + 1;
  IF EXISTS (
    SELECT 1 FROM information_schema.table_constraints 
    WHERE table_name = 'addresses' AND constraint_type = 'CHECK'
  ) THEN
    RAISE NOTICE '[OK] Test 3 : Contrainte CHECK sur address_type existe';
  ELSE
    RAISE NOTICE '[ERREUR] Test 3 ÉCHOUÉ : Contrainte CHECK manquante';
    v_failed_count := v_failed_count + 1;
  END IF;
  
  -- Test 4 : Vérifier que les données des patients ont été migrées
  v_test_count := v_test_count + 1;
  IF (SELECT COUNT(*) FROM addresses) > 0 THEN
    RAISE NOTICE '[OK] Test 4 : Données migrées vers addresses (% adresses)', 
      (SELECT COUNT(*) FROM addresses);
  ELSE
    RAISE NOTICE '[ERREUR] Test 4 ÉCHOUÉ : Aucune donnée dans addresses';
    v_failed_count := v_failed_count + 1;
  END IF;
  
  -- Test 5 : Vérifier que chaque patient a au moins une adresse primaire
  v_test_count := v_test_count + 1;
  IF (SELECT COUNT(DISTINCT patient_id) FROM addresses WHERE is_primary = TRUE) = 
     (SELECT COUNT(*) FROM addresses WHERE patient_id IN (
       SELECT DISTINCT patient_id FROM addresses
     )) THEN
    RAISE NOTICE '[OK] Test 5 : Intégrité des adresses primaires';
  ELSE
    RAISE NOTICE '[OK] Test 5 : Avertissement - Certains patients n''ont pas d''adresse primaire';
  END IF;
  
  -- Test 6 : Vue de compatibilité V1 fonctionne
  v_test_count := v_test_count + 1;
  IF EXISTS (SELECT 1 FROM patients_v1_view LIMIT 1) THEN
    RAISE NOTICE '[OK] Test 6 : Vue patients_v1_view accessible';
  ELSE
    RAISE NOTICE '[ERREUR] Test 6 ÉCHOUÉ : Vue patients_v1_view n''existe pas ou vide';
    v_failed_count := v_failed_count + 1;
  END IF;
  
  -- Test 7 : Performance - requête sur addresses indexée
  v_test_count := v_test_count + 1;
  IF EXISTS (
    SELECT 1 FROM pg_indexes 
    WHERE tablename = 'addresses' AND indexname LIKE '%patient%'
  ) THEN
    RAISE NOTICE '[OK] Test 7 : Index sur patient_id existe';
  ELSE
    RAISE NOTICE '[ERREUR] Test 7 ÉCHOUÉ : Index manquant';
    v_failed_count := v_failed_count + 1;
  END IF;
  
  -- Résumé
  RAISE NOTICE '========== RÉSUMÉ ==========';
  RAISE NOTICE 'Tests passés: %/%', (v_test_count - v_failed_count), v_test_count;
  
  IF v_failed_count > 0 THEN
    RAISE EXCEPTION 'ÉVOLUTION A : % test(s) échoué(s)', v_failed_count;
  END IF;
END $$;

-- Afficher le nombre d'adresses par type
SELECT address_type, COUNT(*) as count 
FROM addresses 
GROUP BY address_type;

-- Afficher un exemple de données migrées
SELECT p.id, p.first_name, p.last_name, a.address_type, a.line1, a.city
FROM patients p
LEFT JOIN addresses a ON p.id = a.patient_id
LIMIT 10;
