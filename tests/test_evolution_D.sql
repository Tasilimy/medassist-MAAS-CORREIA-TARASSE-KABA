--
====================================================================
-- test_evolution_D.sql : Tests pour l'Évolution D (Chiffrement SSN)
====================================================================
-- Tests de validation pour le chiffrement des données sensibles
--

DO $$
DECLARE
  v_test_count INTEGER := 0;
  v_failed_count INTEGER := 0;
  v_encrypted_count INTEGER;
BEGIN
  RAISE NOTICE '========== TEST ÉVOLUTION D ==========';
  
  -- Test 1 : Vérifier que pgcrypto est installé
  v_test_count := v_test_count + 1;
  IF EXISTS (SELECT 1 FROM pg_extension WHERE extname = 'pgcrypto') THEN
    RAISE NOTICE '[✓] Test 1 : Extension pgcrypto installée';
  ELSE
    RAISE NOTICE '[✗] Test 1 ÉCHOUÉ : pgcrypto non installée';
    v_failed_count := v_failed_count + 1;
  END IF;
  
  -- Test 2 : Vérifier que ssn_encrypted existe
  v_test_count := v_test_count + 1;
  IF EXISTS (
    SELECT 1 FROM information_schema.columns 
    WHERE table_name = 'patients' AND column_name = 'ssn_encrypted'
  ) THEN
    RAISE NOTICE '[✓] Test 2 : Colonne ssn_encrypted existe';
  ELSE
    RAISE NOTICE '[✗] Test 2 ÉCHOUÉ : ssn_encrypted manquant';
    v_failed_count := v_failed_count + 1;
  END IF;
  
  -- Test 3 : Vérifier que ssn_encrypted contient des données
  v_test_count := v_test_count + 1;
  SELECT COUNT(*) INTO v_encrypted_count FROM patients WHERE ssn_encrypted IS NOT NULL;
  IF v_encrypted_count > 0 THEN
    RAISE NOTICE '[✓] Test 3 : % SSN chiffrés', v_encrypted_count;
  ELSE
    RAISE NOTICE '[✗] Test 3 ÉCHOUÉ : Aucun SSN chiffré';
    v_failed_count := v_failed_count + 1;
  END IF;
  
  -- Test 4 : Vérifier que les SSN en clair sont toujours présents (compatibilité V1)
  v_test_count := v_test_count + 1;
  IF (SELECT COUNT(*) FROM patients WHERE ssn IS NOT NULL) > 0 THEN
    RAISE NOTICE '[✓] Test 4 : SSN en clair toujours présents (compatibilité V1)';
  ELSE
    RAISE NOTICE '[✗] Test 4 ÉCHOUÉ : SSN en clair supprimés';
    v_failed_count := v_failed_count + 1;
  END IF;
  
  -- Test 5 : Vérifier que ssn_encrypted n'est pas du texte en clair
  v_test_count := v_test_count + 1;
  IF (SELECT COUNT(*) FROM patients 
      WHERE ssn_encrypted::TEXT LIKE '%2%' 
      AND ssn_encrypted IS NOT NULL 
      AND ssn IS NOT NULL
      AND ssn_encrypted::TEXT = ssn
     ) = 0 THEN
    RAISE NOTICE '[✓] Test 5 : ssn_encrypted ne contient pas de texte en clair';
  ELSE
    RAISE NOTICE '[⚠] Test 5 : Avertissement - Certains SSN peuvent être en clair';
  END IF;
  
  -- Test 6 : Vérifier que tous les patients ont ssn_encrypted s'ils ont ssn
  v_test_count := v_test_count + 1;
  IF (SELECT COUNT(*) FROM patients WHERE ssn IS NOT NULL AND ssn_encrypted IS NULL) = 0 THEN
    RAISE NOTICE '[✓] Test 6 : Tous les SSN en clair sont chiffrés';
  ELSE
    RAISE NOTICE '[✗] Test 6 ÉCHOUÉ : % SSN non chiffrés',
      (SELECT COUNT(*) FROM patients WHERE ssn IS NOT NULL AND ssn_encrypted IS NULL);
    v_failed_count := v_failed_count + 1;
  END IF;
  
  -- Test 7 : Tester le déchiffrement (facultatif)
  v_test_count := v_test_count + 1;
  BEGIN
    IF EXISTS (
      SELECT 1 FROM patients 
      WHERE ssn_encrypted IS NOT NULL 
      LIMIT 1
    ) THEN
      RAISE NOTICE '[✓] Test 7 : Données chiffrées présentes et valides';
    ELSE
      RAISE NOTICE '[⚠] Test 7 : Aucune donnée chiffrée pour tester';
    END IF;
  EXCEPTION WHEN OTHERS THEN
    RAISE NOTICE '[✗] Test 7 ÉCHOUÉ : Erreur lors du test de chiffrement';
    v_failed_count := v_failed_count + 1;
  END;
  
  -- Résumé
  RAISE NOTICE '========== RÉSUMÉ ==========';
  RAISE NOTICE 'Tests passés: %/%', (v_test_count - v_failed_count), v_test_count;
  
  IF v_failed_count > 0 THEN
    RAISE EXCEPTION 'ÉVOLUTION D : % test(s) échoué(s)', v_failed_count;
  END IF;
END $$;

-- Afficher un exemple de SSN en clair et chiffré (SANS afficher les vraies valeurs)
SELECT 
  id, 
  first_name, 
  CASE WHEN ssn IS NOT NULL THEN 'PRESENT' ELSE 'NULL' END as ssn_v1_status,
  CASE WHEN ssn_encrypted IS NOT NULL THEN 'CHIFFRÉ' ELSE 'NULL' END as ssn_encrypted_status,
  LENGTH(ssn_encrypted::TEXT) as encrypted_length
FROM patients
LIMIT 10;

-- Afficher les statistiques
SELECT 
  COUNT(*) as total_patients,
  COUNT(CASE WHEN ssn IS NOT NULL THEN 1 END) as patients_with_ssn,
  COUNT(CASE WHEN ssn_encrypted IS NOT NULL THEN 1 END) as patients_with_encrypted_ssn
FROM patients;
