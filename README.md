Проект по курсу "Базы Данных", весна 2025

Эта база данных предназначена для управления академической информацией в учебном заведении, таком как университет или институт.

База данных будет в 3НФ.

![Концептуальная модель](docs/conceptual-model.jpg "Концептуальная модель")

![Логическая модель](docs/logical-model.jpg "Логическая модель")

Вот как можно **дополнить/улучшить описание физической модели в README.md**, чтобы отразить все наши новые ограничения:

---

## Физическая модель

### Таблица t_faculty

| Column   | Type | Constraints                                                                                     |
|----------|------|------------------------------------------------------------------------------------------------|
| id       | UUID | PRIMARY KEY, DEFAULT uuid_generate_v4()                                                        |
| name     | TEXT | NOT NULL, строка не может быть пустой или состоять из пробелов                                 |
| director | TEXT |                                                                                                |

---

### Таблица t_student

| Column      | Type   | Constraints                                                                                                          |
|-------------|--------|----------------------------------------------------------------------------------------------------------------------|
| id          | UUID   | PRIMARY KEY, DEFAULT uuid_generate_v4()                                                                              |
| faculty_id  | UUID   | REFERENCES t_faculty(id)                                                                                             |
| first_name  | TEXT   | NOT NULL, строка не может быть пустой или состоять из пробелов                                                       |
| second_name | TEXT   | NOT NULL, строка не может быть пустой или состоять из пробелов                                                       |
| year        | INTEGER| Неотрицательное число (**>= 0**) или NULL                                                                            |

---

### Таблица t_department

| Column      | Type   | Constraints                                                                                   |
|-------------|--------|----------------------------------------------------------------------------------------------|
| id          | UUID   | PRIMARY KEY, DEFAULT uuid_generate_v4()                                                      |
| faculty_id  | UUID   | REFERENCES t_faculty(id)                                                                     |
| name        | TEXT   | NOT NULL, строка не может быть пустой или состоять из пробелов                               |
| head        | TEXT   |                                                                                              |

---

### Таблица t_course

| Column        | Type      | Constraints                                                                            |
|---------------|-----------|----------------------------------------------------------------------------------------|
| id            | UUID      | PRIMARY KEY, DEFAULT uuid_generate_v4()                                                |
| department_id | UUID      | REFERENCES t_department(id)                                                            |
| name          | TEXT      | NOT NULL, строка не может быть пустой или состоять из пробелов                         |
| year          | INTEGER   | NOT NULL, неотрицательное число (**>= 0**)                                             |

---

### Таблица t_student_to_course

| Column      | Type           | Constraints                                    |
|-------------|----------------|------------------------------------------------|
| id          | UUID           | PRIMARY KEY, DEFAULT uuid_generate_v4()        |
| student_id  | UUID           | REFERENCES t_student(id)                       |
| course_id   | UUID           | REFERENCES t_course(id)                        |
| obligation  | obligation_type| NOT NULL                                       |

---

### Таблица t_lecturer

| Column      | Type                | Constraints                                                                        |
|-------------|---------------------|-------------------------------------------------------------------------------------|
| id          | UUID                | PRIMARY KEY, DEFAULT uuid_generate_v4()                                             |
| first_name  | TEXT                | NOT NULL, строка не может быть пустой или состоять из пробелов                      |
| second_name | TEXT                | NOT NULL, строка не может быть пустой или состоять из пробелов                      |
| degree      | lecturer_degree_type| NOT NULL                                                                            |

---

### Таблица t_course_lecturer

| Column       | Type   | Constraints                                                                                                                      |
|--------------|--------|---------------------------------------------------------------------------------------------------------------------------------|
| id           | UUID   | PRIMARY KEY, DEFAULT uuid_generate_v4()                                                                                        |
| lecturer_id  | UUID   | REFERENCES t_lecturer(id)                                                                                                       |
| course_id    | UUID   | REFERENCES t_course(id)                                                                                                         |
| period_start | DATE   | См. ниже                                                                                                                        |
| period_end   | DATE   | **Периоды (period_start, period_end) должны быть валидными: period_start <= period_end; для каждого курса и лектора периоды не могут пересекаться** (см. триггер) |

- **Триггер предотвращает пересечение периодов для одной и той же пары (lecturer_id, course_id).**

---

### Тип obligation_type

Используется в таблице t_student_to_course для определения обязательности курса для студента.

| Value      | Описание                                                 |
|------------|---------------------------------------------------------|
| mandatory  | Обязательный курс                                       |
| elective   | Факультативный курс                                     |
| auditing   | Курс посещается только как слушатель, без обязательств  |

---

### Тип lecturer_degree_type

Используется в таблице t_lecturer для определения академической степени преподавателя.

| Value              | Описание                       |
|--------------------|-------------------------------|
| assistant          | Ассистент                     |
| associate_professor| Доцент                        |
| professor          | Профессор                     |

