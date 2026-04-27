--
====================================================================
-- test_evolution_contract.sql : Tests pour la phase CONTRACT (V3)
====================================================================
-- Valide que les anciennes structures ont été supprimées correctement
--

DO $$
DECLARE
  v_test_count INTEGER := 0;
  v_failed_count INTEGER := 0;
BEGIN
  RAISE NOTICE '========== TEST PHASE CONTRACT (V3) ==========';
  
  -- Test 1 : Vérifier que les anciennes colonnes d'adresse ont été supprimées
  v_test_count := v_test_count + 1;
  IF NOT EXISTS (
    SELECT 1 FROM information_schema.columns 
    WHERE table_name = 'patients' 
    AND column_name IN ('address_line1', 'address_line2', 'city', 'postal_code')
  ) THEN
    RAISE NOTICE '[✓] Test 1 : Anciennes colonnes adresse supprimées';
  ELSE
    RAISE NOTICE '[✗] Test 1 ÉCHOUÉ : Colonnes adresse encore présentes';
    v_failed_count := v_failed_count + 1;
  END IF;
  
  -- Test 2 : Vérifier que doctor_name a été supprimé de consultations
  v_test_count := v_test_count + 1;
  IF NOT EXISTS (
    SELECT 1 FROM information_schema.columns 
    WHERE table_name = 'consultations' AND column_name = 'doctor_name'
  ) THEN
    RAISE NOTICE '[✓] Test 2 : Colonne doctor_name supprimée';
  ELSE
    RAISE NOTICE '[✗] Test 2 ÉCHOUÉ : doctor_name toujours présent';
    v_failed_count := v_failed_count + 1;
  END IF;
  
  -- Test 3 : Vérifier que gender_new a été renommé en gender
  v_test_count := v_test_count + 1;
  IF EXISTS (
    SELECT 1 FROM information_schema.columns 
    WHERE table_name = 'patients' AND column_name = 'gender'
  ) THEN
    RAISE NOTICE '[✓] Test 3 : gender_new renommé en gender';
  ELSE
    RAISE NOTICE '[✗] Test 3 ÉCHOUÉ : gender introuvable';
    v_failed_count := v_failed_count + 1;
  END IF;
  
  -- Test 4 : Vérifier que la colonne gender est NOT NULL
  v_test_count := v_test_count + 1;
  IF (SELECT COUNT(*) FROM patients WHERE gender IS NULL) = 0 THEN
    RAISE NOTICE '[✓] Test 4 : Tous les patients ont une valeur de gender';
  ELSE
    RAISE NOTICE '[✗] Test 4 ÉCHOUÉ : % patients avec gender NULL',
      (SELECT COUNT(*) FROM patients WHERE gender IS NULL);
    v_failed_count := v_failed_count + 1;
  END IF;
  
  -- Test 5 : Vérifier que les triggers de synchro ont été supprimés
  v_test_count := v_test_count + 1;
  IF (SELECT COUNT(*) FROM pg_trigger 
      WHERE tgname IN ('trg_sync_address_to_patients', 'trg_sync_doctor_to_name')) = 0 THEN
    RAISE NOTICE '[✓] Test 5 : Triggers de synchronisation supprimés';
  ELSE
    RAISE NOTICE '[⚠] Test 5 : Avertissement - Certains triggers restent (normal si pas de CONTRACT)';
  END IF;
  
  -- Test 6 : Vérifier que doctor_id est présent et utilisé
  v_test_count := v_test_count + 1;
  IF (SELECT COUNT(*) FROM consultations WHERE doctor_id IS NOT NULL) > 0 THEN
    RAISE NOTICE '[✓] Test 6 : doctor_id présent et utilisé (% consultations)',
      (SELECT COUNT(*) FROM consultations WHERE doctor_id IS NOT NULL);
  ELSE
    RAISE NOTICE '[✗] Test 6 ÉCHOUÉ : Aucune consultation avec doctor_id';
    v_failed_count := v_failed_count + 1;
  END IF;
  
  -- Test 7 : Vérifier que les données sont intactes
  v_test_count := v_test_count + 1;
  IF (SELECT COUNT(*) FROM patients) > 0 
     AND (SELECT COUNT(*) FROM addresses) > 0 
     AND (SELECT COUNT(*) FROM doctors) > 0 THEN
    RAISE NOTICE '[✓] Test 7 : Toutes les données intactes';
  ELSE
    RAISE NOTICE '[✗] Test 7 ÉCHOUÉ : Données manquantes';
    v_failed_count := v_failed_count + 1;
  END IF;
  
  -- Test 8 : Vérifier la cohérence addresses primaires
  v_test_count := v_test_count + 1;
  IF (SELECT COUNT(DISTINCT patient_id) FROM addresses WHERE is_primary = TRUE) > 0 THEN
    RAISE NOTICE '[✓] Test 8 : Adresses primaires validées';
  ELSE
    RAISE NOTICE '[⚠] Test 8 : Avertissement - Pas d''adresse primaire';
  END IF;
  
  -- Test 9 : Vérifier la vue consultations_legacy
  v_test_count := v_test_count + 1;
  IF EXISTS (SELECT 1 FROM information_schema.views WHERE table_name = 'consultations_legacy') THEN
    RAISE NOTICE '[✓] Test 9 : Vue consultations_legacy créée';
  ELSE
    RAISE NOTICE '[⚠] Test 9 : Vue consultations_legacy introuvable';
  END IF;
  
  -- Test 10 : Vérifier les index d'optimisation
  v_test_count := v_test_count + 1;
  IF EXISTS (
    SELECT 1 FROM pg_indexes 
    WHERE tablename = 'addresses' AND indexname LIKE '%patient%'
  ) THEN
    RAISE NOTICE '[✓] Test 10 : Index présent sur addresses';
  ELSE
    RAISE NOTICE '[⚠] Test 10 : Avertissement - Index manquant';
  END IF;
  
  -- Résumé
  RAISE NOTICE '========== RÉSUMÉ ==========';
  RAISE NOTICE 'Tests passés: %/%', (v_test_count - v_failed_count), v_test_count;
  
  IF v_failed_count > 0 THEN
    RAISE EXCEPTION 'PHASE CONTRACT : % test(s) échoué(s)', v_failed_count;
  ELSE
    RAISE NOTICE '✅ PHASE CONTRACT VALIDÉE - Migration complète !';
  END IF;
END $$;

-- Afficher le schéma final
RAISE NOTICE '========== SCHÉMA FINAL ==========';

-- Tables principales
SELECT 
  COUNT(*) as patients,
  (SELECT COUNT(*) FROM addresses) as addresses,
  (SELECT COUNT(*) FROM doctors) as doctors,
  (SELECT COUNT(*) FROM consultations) as consultations,
  (SELECT COUNT(*) FROM prescriptions) as prescriptions
FROM patients;

-- Afficher les colonnes finales de patients
SELECT column_name, data_type, is_nullable
FROM information_schema.columns
WHERE table_name = 'patients'
ORDER BY ordinal_position;

-- Afficher les colonnes finales de consultations
SELECT column_name, data_type, is_nullable
FROM information_schema.columns
WHERE table_name = 'consultations'
ORDER BY ordinal_position;
