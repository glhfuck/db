-- Выбор студентов, обучающихся на факультете прикладной математики

SELECT s.id,
       s.first_name,
       s.second_name,
       s.year,
       f.name AS faculty_name
FROM t_student s
INNER JOIN t_faculty f ON s.faculty_id = f.id
WHERE f.name = 'Faculty of Computer Science'
ORDER BY s.second_name;

-- Подсчёт числа студентов на каждом факультете.

SELECT f.name AS faculty_name,
       COUNT(s.id) AS student_count
FROM t_faculty f
LEFT JOIN t_student s ON f.id = s.faculty_id
GROUP BY f.name
ORDER BY student_count DESC;

-- Курсы и количество зачисленных студентов

SELECT c.name AS course_name,
       (SELECT COUNT(*) 
          FROM t_student_to_course stc 
         WHERE stc.course_id = c.id) AS enrolled_count
FROM t_course c
ORDER BY enrolled_count DESC;

-- Курсы с информацией о лекторе

SELECT c.id,
       c.name AS course_name,
       l.first_name,
       l.second_name,
       cl.period_start,
       cl.period_end
FROM t_course c
LEFT JOIN t_course_lecturer cl ON c.id = cl.course_id
LEFT JOIN t_lecturer l ON cl.lecturer_id = l.id
ORDER BY c.name;

-- Поиск курсов с числом зачисленных студентов больше, чем среднее по всем курсам

WITH course_counts AS (
  SELECT c.id, c.name,
         (SELECT COUNT(*) FROM t_student_to_course stc WHERE stc.course_id = c.id) AS enrolled_count
  FROM t_course c
)
SELECT id, name, enrolled_count
FROM course_counts
WHERE enrolled_count > (SELECT AVG(enrolled_count) FROM course_counts)
ORDER BY enrolled_count DESC;

-- Ранжирование студентов по фамилии внутри каждого курса

SELECT s.id,
       s.first_name,
       s.second_name,
       s.year,
       RANK() OVER (PARTITION BY s.year ORDER BY s.second_name) AS rank_in_year
FROM t_student s
ORDER BY s.year, rank_in_year;

-- Поиск студентов, записанных на курс алгоритмов с оператором IN

SELECT s.id,
       s.first_name,
       s.second_name
FROM t_student s
WHERE s.id IN (
  SELECT stc.student_id
  FROM t_student_to_course stc
  WHERE stc.course_id = '44444444-4444-4444-4444-444444444002'
)
ORDER BY s.second_name;

-- Найти курсы, на которые записаны не больше студентов, чем на все курсы первого курса.

SELECT c.id,
       c.name,
       (SELECT COUNT(*) FROM t_student_to_course stc WHERE stc.course_id = c.id) AS enrolled_count
FROM t_course c
WHERE (SELECT COUNT(*) FROM t_student_to_course stc WHERE stc.course_id = c.id)
      <= ALL (
         SELECT (SELECT COUNT(*) FROM t_student_to_course stc2 WHERE stc2.course_id = c1.id)
         FROM t_course c1
         WHERE c1.year = 1
      )
ORDER BY enrolled_count DESC;

-- Курсы с распределением студентов по типу обязательности  

SELECT 
  c.id,
  c.name,
  c.year,
  SUM(CASE WHEN stc.obligation ='mandatory' THEN 1 ELSE 0 END) AS mandatory_count,
  SUM(CASE WHEN stc.obligation = 'elective' THEN 1 ELSE 0 END) AS elective_count,
  SUM(CASE WHEN stc.obligation = 'auditing' THEN 1 ELSE 0 END) AS auditing_count,
  COUNT(stc.student_id) AS total_enrolled
FROM t_course c
LEFT JOIN t_student_to_course stc ON c.id = stc.course_id
GROUP BY c.id, c.name, c.year
ORDER BY total_enrolled DESC;

-- Курсы у каждого лектора с отметкой о превышении средней нагрузки 

/*
Подробнее:

Для каждого лектора выбираются курсы, которые он ведёт, 
а также рассчитывается число студентов на каждом курсе. 
С использованием оконной функции AVG() рассчитывается 
среднее значение числа зачислений по курсам данного лектора, 
и для каждого курса определяется, превышает ли его enrolled_count этот средний показатель.
*/

WITH lecturer_courses AS (
  SELECT
    cl.lecturer_id,
    c.id          AS course_id,
    c.name        AS course_name,
    COUNT(stc.student_id) AS enrolled_count
  FROM t_course_lecturer cl
  INNER JOIN t_course c ON cl.course_id = c.id
  LEFT JOIN t_student_to_course stc ON c.id = stc.course_id
  GROUP BY cl.lecturer_id, c.id, c.name
)
SELECT 
  lc.lecturer_id,
  lc.course_id,
  lc.course_name,
  lc.enrolled_count,
  AVG(lc.enrolled_count) OVER (PARTITION BY lc.lecturer_id) AS avg_enrollment,
  CASE 
    WHEN lc.enrolled_count > AVG(lc.enrolled_count) OVER (PARTITION BY lc.lecturer_id) 
         THEN 'Above Average'
         ELSE 'Below or Equal Average'
  END AS performance_flag
FROM lecturer_courses lc
ORDER BY lc.lecturer_id, lc.enrolled_count DESC;
