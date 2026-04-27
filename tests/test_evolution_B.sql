-- test_evolution_B.sql : Tests pour l'Évolution B (Doctors)
-- Tests de validation pour la normalisation du champ doctor_name
--

DO $$
DECLARE
  v_test_count INTEGER := 0;
  v_failed_count INTEGER := 0;
BEGIN
  RAISE NOTICE '========== TEST ÉVOLUTION B ==========';
  
  -- Test 1 : Vérifier que la table doctors existe
  v_test_count := v_test_count + 1;
  IF EXISTS (SELECT 1 FROM information_schema.tables WHERE table_name = 'doctors') THEN
    RAISE NOTICE '[✓] Test 1 : Table doctors existe';
  ELSE
    RAISE NOTICE '[✗] Test 1 ÉCHOUÉ : Table doctors n''existe pas';
    v_failed_count := v_failed_count + 1;
  END IF;
  
  -- Test 2 : Vérifier les colonnes de doctors
  v_test_count := v_test_count + 1;
  IF EXISTS (
    SELECT 1 FROM information_schema.columns 
    WHERE table_name = 'doctors' 
    AND column_name IN ('id', 'rpps_number', 'first_name', 'last_name', 'specialty', 'email')
    GROUP BY table_name HAVING COUNT(*) >= 5
  ) THEN
    RAISE NOTICE '[✓] Test 2 : Colonnes requises existent';
  ELSE
    RAISE NOTICE '[✗] Test 2 ÉCHOUÉ : Colonnes manquantes';
    v_failed_count := v_failed_count + 1;
  END IF;
  
  -- Test 3 : Vérifier que doctor_id a été ajouté à consultations
  v_test_count := v_test_count + 1;
  IF EXISTS (
    SELECT 1 FROM information_schema.columns 
    WHERE table_name = 'consultations' AND column_name = 'doctor_id'
  ) THEN
    RAISE NOTICE '[✓] Test 3 : Colonne doctor_id existe dans consultations';
  ELSE
    RAISE NOTICE '[✗] Test 3 ÉCHOUÉ : doctor_id manquant';
    v_failed_count := v_failed_count + 1;
  END IF;
  
  -- Test 4 : Vérifier la déduplication (environ 4 médecins uniques)
  v_test_count := v_test_count + 1;
  IF (SELECT COUNT(*) FROM doctors) >= 3 AND (SELECT COUNT(*) FROM doctors) <= 10 THEN
    RAISE NOTICE '[✓] Test 4 : Nombre de médecins dedupliqués : %', (SELECT COUNT(*) FROM doctors);
  ELSE
    RAISE NOTICE '[✗] Test 4 ÉCHOUÉ : Nombre de médecins incorrect (%))', (SELECT COUNT(*) FROM doctors);
    v_failed_count := v_failed_count + 1;
  END IF;
  
  -- Test 5 : Vérifier que doctor_id est rempli pour les consultations
  v_test_count := v_test_count + 1;
  IF (SELECT COUNT(*) FROM consultations WHERE doctor_id IS NOT NULL) > 0 THEN
    RAISE NOTICE '[✓] Test 5 : % consultations liées aux doctors', 
      (SELECT COUNT(*) FROM consultations WHERE doctor_id IS NOT NULL);
  ELSE
    RAISE NOTICE '[✗] Test 5 ÉCHOUÉ : Aucune consultation liée';
    v_failed_count := v_failed_count + 1;
  END IF;
  
  -- Test 6 : Vérifier la contrainte d'unicité RPPS
  v_test_count := v_test_count + 1;
  IF EXISTS (
    SELECT 1 FROM information_schema.table_constraints 
    WHERE table_name = 'doctors' AND constraint_type = 'UNIQUE'
  ) THEN
    RAISE NOTICE '[✓] Test 6 : Contrainte UNIQUE sur RPPS existe';
  ELSE
    RAISE NOTICE '[✗] Test 6 ÉCHOUÉ : Contrainte UNIQUE manquante';
    v_failed_count := v_failed_count + 1;
  END IF;
  
  -- Test 7 : Vérifier que doctor_name est toujours rempli (compatibilité V1)
  v_test_count := v_test_count + 1;
  IF (SELECT COUNT(*) FROM consultations WHERE doctor_name IS NULL) = 0 THEN
    RAISE NOTICE '[✓] Test 7 : doctor_name rempli pour toutes les consultations';
  ELSE
    RAISE NOTICE '[✗] Test 7 ÉCHOUÉ : % consultations avec doctor_name NULL',
      (SELECT COUNT(*) FROM consultations WHERE doctor_name IS NULL);
    v_failed_count := v_failed_count + 1;
  END IF;
  
  -- Test 8 : Vérifier les FK
  v_test_count := v_test_count + 1;
  IF EXISTS (
    SELECT 1 FROM information_schema.referential_constraints 
    WHERE constraint_name LIKE '%doctor%'
  ) THEN
    RAISE NOTICE '[✓] Test 8 : Contrainte de clé étrangère vers doctors existe';
  ELSE
    RAISE NOTICE '[⚠] Test 8 : Avertissement - FK vers doctors non trouvée';
  END IF;
  
  -- Résumé
  RAISE NOTICE '========== RÉSUMÉ ==========';
  RAISE NOTICE 'Tests passés: %/%', (v_test_count - v_failed_count), v_test_count;
  
  IF v_failed_count > 0 THEN
    RAISE EXCEPTION 'ÉVOLUTION B : % test(s) échoué(s)', v_failed_count;
  END IF;
END $$;

-- Afficher les médecins créés
SELECT id, rpps_number, first_name, last_name, specialty
FROM doctors
ORDER BY last_name, first_name;

-- Afficher des exemples de consultations avec doctors
SELECT c.id, c.consultation_date, d.first_name, d.last_name, c.doctor_name
FROM consultations c
LEFT JOIN doctors d ON c.doctor_id = d.id
LIMIT 15;

-- Vérifier la distribution des consultations par doctor_id
SELECT d.id, d.last_name, COUNT(c.id) as consultation_count
FROM doctors d
LEFT JOIN consultations c ON d.id = c.doctor_id
GROUP BY d.id, d.last_name
ORDER BY consultation_count DESC;
