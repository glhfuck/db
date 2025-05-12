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
