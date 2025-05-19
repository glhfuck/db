CREATE EXTENSION IF NOT EXISTS "uuid-ossp";

CREATE TYPE obligation_type AS ENUM (
  'mandatory',
  'elective',
  'auditing'
);

CREATE TYPE lecturer_degree_type AS ENUM (
  'assistant',
  'associate_professor',
  'professor'
);

CREATE TABLE t_faculty (
  id UUID PRIMARY KEY DEFAULT uuid_generate_v4(),
  name TEXT NOT NULL CHECK (trim(name) <> ''),
  director TEXT
);

CREATE TABLE t_student (
  id UUID PRIMARY KEY DEFAULT uuid_generate_v4(),
  faculty_id UUID REFERENCES t_faculty(id) ON DELETE CASCADE ON UPDATE CASCADE,
  first_name TEXT NOT NULL CHECK (trim(first_name) <> ''),
  second_name TEXT NOT NULL CHECK (trim(second_name) <> ''),
  year INTEGER CHECK (year IS NULL OR year >= 0)
);

CREATE TABLE t_department (
  id UUID PRIMARY KEY DEFAULT uuid_generate_v4(),
  faculty_id UUID REFERENCES t_faculty(id) ON DELETE CASCADE ON UPDATE CASCADE,
  name TEXT NOT NULL CHECK (trim(name) <> ''),
  head TEXT
);

CREATE TABLE t_course (
  id UUID PRIMARY KEY DEFAULT uuid_generate_v4(),
  department_id UUID REFERENCES t_department(id) ON DELETE CASCADE ON UPDATE CASCADE,
  name TEXT NOT NULL CHECK (trim(name) <> ''),
  year INTEGER NOT NULL CHECK (year >= 0)
);

CREATE TABLE t_student_to_course (
  id UUID PRIMARY KEY DEFAULT uuid_generate_v4(),
  student_id UUID REFERENCES t_student(id) ON DELETE CASCADE ON UPDATE CASCADE,
  course_id UUID REFERENCES t_course(id) ON DELETE CASCADE ON UPDATE CASCADE,
  obligation obligation_type NOT NULL
);

CREATE TABLE t_lecturer (
  id UUID PRIMARY KEY DEFAULT uuid_generate_v4(),
  first_name TEXT NOT NULL CHECK (trim(first_name) <> ''),
  second_name TEXT NOT NULL CHECK (trim(second_name) <> ''),
  degree lecturer_degree_type NOT NULL
);

CREATE TABLE t_course_lecturer (
  id UUID PRIMARY KEY DEFAULT uuid_generate_v4(),
  lecturer_id UUID REFERENCES t_lecturer(id) ON DELETE CASCADE ON UPDATE CASCADE,
  course_id UUID REFERENCES t_course(id) ON DELETE CASCADE ON UPDATE CASCADE,
  period_start DATE,
  period_end DATE,
  CHECK (period_start IS NULL OR period_end IS NULL OR period_start <= period_end)
);

CREATE OR REPLACE FUNCTION check_course_lecturer_overlap()
RETURNS trigger AS $$
BEGIN
  IF EXISTS (
    SELECT 1 FROM t_course_lecturer
    WHERE
      course_id = NEW.course_id
      AND lecturer_id = NEW.lecturer_id
      AND id <> NEW.id
      AND (
        (NEW.period_start IS NOT NULL AND period_start IS NOT NULL AND
         (NEW.period_end IS NULL OR period_end IS NULL OR NEW.period_start <= period_end) AND
         (period_end IS NULL OR NEW.period_end IS NULL OR period_start <= NEW.period_end)
        ) OR
        (NEW.period_start IS NULL AND period_start IS NULL)
      )
  ) THEN
    RAISE EXCEPTION 'Lecturer already assigned to this course in overlapping period';
  END IF;
  RETURN NEW;
END;
$$ LANGUAGE plpgsql;

CREATE TRIGGER trg_check_course_lecturer_overlap
BEFORE INSERT OR UPDATE ON t_course_lecturer
FOR EACH ROW
EXECUTE FUNCTION check_course_lecturer_overlap();

CREATE INDEX CONCURRENTLY IF NOT EXISTS idx_t_student_id_hash ON t_student USING hash(id);
CREATE INDEX CONCURRENTLY IF NOT EXISTS idx_t_course_id_hash ON t_course USING hash(id);
CREATE INDEX CONCURRENTLY IF NOT EXISTS idx_t_lecturer_id_hash ON t_lecturer USING hash(id);

-- Вьюшка 1: Статистика: сколько студентов на каждом факультете

CREATE OR REPLACE VIEW v_faculty_student_count AS
SELECT
  f.id AS faculty_id,
  f.name AS faculty_name,
  COUNT(s.id) AS student_count
FROM t_faculty f
LEFT JOIN t_student s ON s.faculty_id = f.id
GROUP BY f.id, f.name;

-- Вьюшка 2: Список курсов с кафедрами и преподавателями
 
CREATE OR REPLACE VIEW v_course_department_lecturer AS
SELECT
  c.id AS course_id,
  c.name AS course_name,
  d.id AS department_id,
  d.name AS department_name,
  l.id AS lecturer_id,
  l.first_name || ' ' || l.second_name AS lecturer_full_name,
  cl.period_start,
  cl.period_end
FROM t_course c
JOIN t_department d ON c.department_id = d.id
JOIN t_course_lecturer cl ON c.id = cl.course_id
JOIN t_lecturer l ON l.id = cl.lecturer_id;

CREATE TABLE t_faculty_director_version (
    id uuid PRIMARY KEY DEFAULT uuid_generate_v4(),
    faculty_id uuid REFERENCES t_faculty(id) ON DELETE CASCADE ON UPDATE CASCADE,
    old_director text,
    new_director text,
    changed_at timestamp NOT NULL DEFAULT now()
);

-- Функция для смены директора с версионированием

CREATE OR REPLACE FUNCTION update_faculty_director(fid uuid, new_director text)
RETURNS void AS $$
DECLARE
    old_director text;
BEGIN
    SELECT director INTO old_director FROM t_faculty WHERE id = fid;
    -- если директор реально меняется, пишем в версионную таблицу
    IF old_director IS DISTINCT FROM new_director THEN
        INSERT INTO t_faculty_director_version(faculty_id, old_director, new_director)
        VALUES (fid, old_director, new_director);
        UPDATE t_faculty SET director = new_director WHERE id = fid;
    END IF;
END;
$$ LANGUAGE plpgsql;

-- Функция статистики (кол-во студентов на кафедре)

CREATE OR REPLACE FUNCTION department_student_count(dep_id uuid)
RETURNS integer AS $$
DECLARE
    cnt integer;
BEGIN
    SELECT COUNT(DISTINCT s.id)
    INTO cnt
    FROM t_student s
    JOIN t_faculty f ON s.faculty_id = f.id
    JOIN t_department d ON d.faculty_id = f.id
    WHERE d.id = dep_id;
    RETURN cnt;
END;
$$ LANGUAGE plpgsql;


-- Функция по студенту: список ЕГО курсов и оценок

ALTER TABLE t_student_to_course ADD COLUMN mark integer;  -- NULL если не сдано

CREATE OR REPLACE FUNCTION student_passed_courses_count(stud_id uuid)
RETURNS integer AS $$
DECLARE
    cnt integer;
BEGIN
    SELECT COUNT(*)
    INTO cnt
    FROM t_student_to_course
    WHERE student_id = stud_id
      AND mark IS NOT NULL
      AND mark >= 60;     -- например, зачтено если ≥60!
    RETURN cnt;
END;
$$ LANGUAGE plpgsql;


-- Процедура — смена head кафедры

CREATE OR REPLACE PROCEDURE update_department_head(dep_id uuid, new_head text)
LANGUAGE plpgsql
AS $$
BEGIN
    UPDATE t_department SET head = new_head WHERE id = dep_id;
END;
$$;


