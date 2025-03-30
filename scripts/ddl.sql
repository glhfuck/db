CREATE TABLE t_faculty (
  id UUID PRIMARY KEY,
  name TEXT NOT NULL,
  director TEXT
);

CREATE TABLE t_student (
  id UUID PRIMARY KEY,
  faculty_id UUID REFERENCES t_faculty(id) ON DELETE CASCADE ON UPDATE CASCADE,
  first_name TEXT NOT NULL,
  second_name TEXT NOT NULL,
  year INTEGER
);

CREATE TABLE t_department (
  id UUID PRIMARY KEY,
  faculty_id UUID REFERENCES t_faculty(id) ON DELETE CASCADE ON UPDATE CASCADE,
  name TEXT NOT NULL,
  head TEXT
);

CREATE TABLE t_course (
  id UUID PRIMARY KEY,
  department_id UUID REFERENCES t_department(id) ON DELETE CASCADE ON UPDATE CASCADE,
  name TEXT NOT NULL,
  year INTEGER NOT NULL
);

CREATE TYPE obligation_type AS ENUM (
  'mandatory',
  'elective',
  'auditing'
);


CREATE TABLE t_student_to_course (
  id UUID PRIMARY KEY,
  student_id UUID REFERENCES t_student(id) ON DELETE CASCADE ON UPDATE CASCADE,
  course_id UUID REFERENCES t_course(id) ON DELETE CASCADE ON UPDATE CASCADE,
  obligation obligation_type NOT NULL
);

CREATE TYPE lecturer_degree_type AS ENUM (
  'assistant',
  'associate_professor',
  'professor'
);

CREATE TABLE t_lecturer (
  id UUID PRIMARY KEY,
  first_name TEXT NOT NULL,
  second_name TEXT NOT NULL,
  degree lecturer_degree_type NOT NULL
);

CREATE TABLE t_course_lecturer (
  id UUID PRIMARY KEY,
  lecturer_id UUID REFERENCES t_lecturer(id) ON DELETE CASCADE ON UPDATE CASCADE,
  course_id UUID REFERENCES t_course(id) ON DELETE CASCADE ON UPDATE CASCADE,
  period_start DATE,
  period_end DATE
);