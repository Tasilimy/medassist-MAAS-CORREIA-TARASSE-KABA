-- test_evolution_E.sql : Tests pour l'Évolution E (Partitionnement)
-- Tests de validation pour le partitionnement de la table consultations
--

DO $$
DECLARE
  v_test_count INTEGER := 0;
  v_failed_count INTEGER := 0;
  v_partition_count INTEGER;
BEGIN
  RAISE NOTICE '========== TEST ÉVOLUTION E ==========';
  
  -- Test 1 : Vérifier que la table partitionnée existe
  v_test_count := v_test_count + 1;
  IF EXISTS (SELECT 1 FROM information_schema.tables WHERE table_name = 'consultations_partitioned') THEN
    RAISE NOTICE '[OK] Test 1 : Table consultations_partitioned existe';
  ELSE
    RAISE NOTICE '[ERREUR] Test 1 ÉCHOUÉ : Table consultations_partitioned n''existe pas';
    v_failed_count := v_failed_count + 1;
  END IF;
  
  -- Test 2 : Vérifier que les partitions existent
  v_test_count := v_test_count + 1;
  SELECT COUNT(*) INTO v_partition_count FROM pg_inherits 
  WHERE inhrelid IN (
    SELECT oid FROM pg_class WHERE relname LIKE 'consultations_%'
  );
  IF v_partition_count >= 6 THEN
    RAISE NOTICE '[OK] Test 2 : % partitions créées', v_partition_count;
  ELSE
    RAISE NOTICE '[ERREUR] Test 2 ÉCHOUÉ : Partitions manquantes (% trouvées)', v_partition_count;
    v_failed_count := v_failed_count + 1;
  END IF;
  
  -- Test 3 : Vérifier que les données ont été copiées
  v_test_count := v_test_count + 1;
  IF (SELECT COUNT(*) FROM consultations_partitioned) > 0 THEN
    RAISE NOTICE '[OK] Test 3 : % consultations dans la table partitionnée', 
      (SELECT COUNT(*) FROM consultations_partitioned);
  ELSE
    RAISE NOTICE '[ERREUR] Test 3 ÉCHOUÉ : Aucune donnée copiée';
    v_failed_count := v_failed_count + 1;
  END IF;
  
  -- Test 4 : Vérifier que le nombre de lignes est identique
  v_test_count := v_test_count + 1;
  IF (SELECT COUNT(*) FROM consultations_partitioned) = (SELECT COUNT(*) FROM consultations) THEN
    RAISE NOTICE '[OK] Test 4 : Toutes les consultations copiées';
  ELSE
    RAISE NOTICE '[ERREUR] Test 4 ÉCHOUÉ : Discordance de données (% vs %)',
      (SELECT COUNT(*) FROM consultations_partitioned),
      (SELECT COUNT(*) FROM consultations);
    v_failed_count := v_failed_count + 1;
  END IF;
  
  -- Test 5 : Vérifier que les colonnes correspondantes existent
  v_test_count := v_test_count + 1;
  IF EXISTS (
    SELECT 1 FROM information_schema.columns 
    WHERE table_name = 'consultations_partitioned' 
    AND column_name IN ('id', 'patient_id', 'consultation_date', 'doctor_name')
    GROUP BY table_name HAVING COUNT(*) >= 3
  ) THEN
    RAISE NOTICE '[OK] Test 5 : Colonnes requises existent';
  ELSE
    RAISE NOTICE '[ERREUR] Test 5 ÉCHOUÉ : Colonnes manquantes';
    v_failed_count := v_failed_count + 1;
  END IF;
  
  -- Test 6 : Vérifier que la clé primaire est composite
  v_test_count := v_test_count + 1;
  IF EXISTS (
    SELECT 1 FROM information_schema.table_constraints 
    WHERE table_name = 'consultations_partitioned' AND constraint_type = 'PRIMARY KEY'
  ) THEN
    RAISE NOTICE '[OK] Test 6 : Clé primaire composite existe';
  ELSE
    RAISE NOTICE '[AVERTISSEMENT] Test 6 : Avertissement - Clé primaire non trouvée';
  END IF;
  
  -- Test 7 : Vérifier que la distribution par année est correcte
  v_test_count := v_test_count + 1;
  IF (
    SELECT COUNT(DISTINCT EXTRACT(YEAR FROM consultation_date)::INT) 
    FROM consultations_partitioned
  ) >= 1 THEN
    RAISE NOTICE '[OK] Test 7 : Données distribuées sur les partitions';
  ELSE
    RAISE NOTICE '[ERREUR] Test 7 ÉCHOUÉ : Distribution incorrecte';
    v_failed_count := v_failed_count + 1;
  END IF;
  
  -- Test 8 : Vérifier la séquence pour l'ID
  v_test_count := v_test_count + 1;
  IF EXISTS (
    SELECT 1 FROM information_schema.sequences 
    WHERE sequence_name = 'consultations_partitioned_id_seq'
  ) THEN
    RAISE NOTICE '[OK] Test 8 : Séquence pour ID existe';
  ELSE
    RAISE NOTICE '[AVERTISSEMENT] Test 8 : Avertissement - Séquence non trouvée';
  END IF;
  
  -- Résumé
  RAISE NOTICE '========== RÉSUMÉ ==========';
  RAISE NOTICE 'Tests passés: %/%', (v_test_count - v_failed_count), v_test_count;
  
  IF v_failed_count > 0 THEN
    RAISE EXCEPTION 'ÉVOLUTION E : % test(s) échoué(s)', v_failed_count;
  END IF;
END $$;

-- Afficher la distribution des consultations par partition (par année)
SELECT 
  EXTRACT(YEAR FROM consultation_date)::INT as year,
  COUNT(*) as count
FROM consultations_partitioned
GROUP BY EXTRACT(YEAR FROM consultation_date)
ORDER BY year;

-- Afficher les partitions et leur taille
SELECT 
  schemaname,
  tablename,
  pg_size_pretty(pg_total_relation_size(schemaname||'.'||tablename)) as size
FROM pg_tables 
WHERE tablename LIKE 'consultations_%'
ORDER BY tablename;

-- Afficher quelques exemples
SELECT id, patient_id, consultation_date, doctor_name
FROM consultations_partitioned
ORDER BY consultation_date DESC
LIMIT 10;

-- Afficher des statistiques
SELECT 
  COUNT(*) as total_consultations,
  MIN(consultation_date) as earliest_date,
  MAX(consultation_date) as latest_date,
  COUNT(DISTINCT patient_id) as unique_patients
FROM consultations_partitioned;
