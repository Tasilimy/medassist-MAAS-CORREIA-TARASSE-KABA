-- test_evolution_C.sql : Tests pour l'Évolution C (Gender)
-- Tests de validation pour la refonte du champ gender
--

DO $$
DECLARE
  v_test_count INTEGER := 0;
  v_failed_count INTEGER := 0;
BEGIN
  RAISE NOTICE '========== TEST ÉVOLUTION C ==========';
  
  -- Test 1 : Vérifier que la table gender_ref existe
  v_test_count := v_test_count + 1;
  IF EXISTS (SELECT 1 FROM information_schema.tables WHERE table_name = 'gender_ref') THEN
    RAISE NOTICE '[OK] Test 1 : Table gender_ref existe';
  ELSE
    RAISE NOTICE '[ERREUR] Test 1 ÉCHOUÉ : Table gender_ref n''existe pas';
    v_failed_count := v_failed_count + 1;
  END IF;
  
  -- Test 2 : Vérifier que gender_new existe dans patients
  v_test_count := v_test_count + 1;
  IF EXISTS (
    SELECT 1 FROM information_schema.columns 
    WHERE table_name = 'patients' AND column_name = 'gender_new'
  ) THEN
    RAISE NOTICE '[OK] Test 2 : Colonne gender_new existe dans patients';
  ELSE
    RAISE NOTICE '[ERREUR] Test 2 ÉCHOUÉ : gender_new manquant';
    v_failed_count := v_failed_count + 1;
  END IF;
  
  -- Test 3 : Vérifier que gender_ref contient les 4 valeurs
  v_test_count := v_test_count + 1;
  IF (SELECT COUNT(*) FROM gender_ref) = 4 THEN
    RAISE NOTICE '[OK] Test 3 : 4 valeurs de référence (M, F, NB, U)';
  ELSE
    RAISE NOTICE '[ERREUR] Test 3 ÉCHOUÉ : Nombre incorrect de valeurs';
    v_failed_count := v_failed_count + 1;
  END IF;
  
  -- Test 4 : Vérifier que gender_new n'a pas de NULL
  v_test_count := v_test_count + 1;
  IF (SELECT COUNT(*) FROM patients WHERE gender_new IS NULL) = 0 THEN
    RAISE NOTICE '[OK] Test 4 : Tous les patients ont une valeur de gender_new';
  ELSE
    RAISE NOTICE '[ERREUR] Test 4 ÉCHOUÉ : % patients avec gender_new NULL',
      (SELECT COUNT(*) FROM patients WHERE gender_new IS NULL);
    v_failed_count := v_failed_count + 1;
  END IF;
  
  -- Test 5 : Vérifier que gender_new contient uniquement des valeurs valides
  v_test_count := v_test_count + 1;
  IF (SELECT COUNT(*) FROM patients WHERE gender_new NOT IN ('M', 'F', 'NB', 'U')) = 0 THEN
    RAISE NOTICE '[OK] Test 5 : Toutes les valeurs de gender_new sont valides';
  ELSE
    RAISE NOTICE '[ERREUR] Test 5 ÉCHOUÉ : Valeurs invalides détectées';
    v_failed_count := v_failed_count + 1;
  END IF;
  
  -- Test 6 : Vérifier la FK vers gender_ref
  v_test_count := v_test_count + 1;
  IF EXISTS (
    SELECT 1 FROM information_schema.referential_constraints 
    WHERE constraint_name LIKE '%gender%'
  ) THEN
    RAISE NOTICE '[OK] Test 6 : FK vers gender_ref existe';
  ELSE
    RAISE NOTICE '[AVERTISSEMENT] Test 6 : Avertissement - FK vers gender_ref non trouvée';
  END IF;
  
  -- Test 7 : Vérifier la compatibilité (gender ancien toujours présent)
  v_test_count := v_test_count + 1;
  IF EXISTS (
    SELECT 1 FROM information_schema.columns 
    WHERE table_name = 'patients' AND column_name = 'gender'
  ) THEN
    RAISE NOTICE '[OK] Test 7 : Colonne gender (V1) toujours présente';
  ELSE
    RAISE NOTICE '[ERREUR] Test 7 ÉCHOUÉ : gender supprimé';
    v_failed_count := v_failed_count + 1;
  END IF;
  
  -- Résumé
  RAISE NOTICE '========== RÉSUMÉ ==========';
  RAISE NOTICE 'Tests passés: %/%', (v_test_count - v_failed_count), v_test_count;
  
  IF v_failed_count > 0 THEN
    RAISE EXCEPTION 'ÉVOLUTION C : % test(s) échoué(s)', v_failed_count;
  END IF;
END $$;

-- Afficher la distribution des valeurs de gender_new
SELECT gender_new, COUNT(*) as count
FROM patients
GROUP BY gender_new
ORDER BY gender_new;

-- Vérifier la référence
SELECT * FROM gender_ref ORDER BY code;

-- Afficher des exemples
SELECT id, first_name, last_name, gender, gender_new
FROM patients
LIMIT 10;
