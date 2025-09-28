-- 1. drivers — водители (персоны)
CREATE TABLE drivers (
    driver_id SERIAL PRIMARY KEY,
    last_name VARCHAR(60) NOT NULL,
    first_name VARCHAR(60) NOT NULL,
    middle_name VARCHAR(60),
    birth_date DATE NOT NULL CHECK (birth_date <= CURRENT_DATE - INTERVAL '16 years'),
    passport_number VARCHAR(30) UNIQUE NOT NULL,
    phone VARCHAR(20),
    address TEXT,
    created_at TIMESTAMP WITHOUT TIME ZONE DEFAULT CURRENT_TIMESTAMP
);

-- 2. persons_documents — вспомогательные документы (ID, паспорт, и т.д.)
CREATE TABLE persons_documents (
    document_id SERIAL PRIMARY KEY,
    driver_id INT NOT NULL REFERENCES drivers(driver_id) ON DELETE CASCADE ON UPDATE CASCADE,
    doc_type VARCHAR(50) NOT NULL CHECK (doc_type IN ('Паспорт','ID','Свидетельство о рождении','Военный билет','Иностр. паспорт')),
    doc_number VARCHAR(50) NOT NULL,
    issue_date DATE,
    issuer TEXT,
    UNIQUE(driver_id, doc_type, doc_number)
);

-- 3. employees — сотрудники МРЕО (инспектора, регистраторы, экзаменаторы)
CREATE TABLE employees (
    employee_id SERIAL PRIMARY KEY,
    full_name VARCHAR(120) NOT NULL,
    position_id INT NOT NULL,
    hire_date DATE,
    phone VARCHAR(20),
    email VARCHAR(100),
    active BOOLEAN DEFAULT TRUE
);

-- 4. positions — справочник должностей сотрудников
CREATE TABLE positions (
    position_id SERIAL PRIMARY KEY,
    position_name VARCHAR(60) UNIQUE NOT NULL CHECK (position_name IN ('Инспектор','Регистратор','Экзаменатор','Администратор','Техник'))
);

-- 5. license_categories — категории водительских прав (A, B, C...)
CREATE TABLE license_categories (
    category_code VARCHAR(5) PRIMARY KEY,
    description TEXT
);

-- 6. driver_licenses — сами водительские удостоверения (центральная таблица для "прав")
CREATE TABLE driver_licenses (
    license_id SERIAL PRIMARY KEY,
    license_number VARCHAR(30) UNIQUE NOT NULL,
    driver_id INT NOT NULL REFERENCES drivers(driver_id) ON DELETE CASCADE ON UPDATE CASCADE,
    issued_by_employee INT REFERENCES employees(employee_id) ON DELETE SET NULL ON UPDATE CASCADE,
    issue_date DATE NOT NULL,
    expiry_date DATE NOT NULL CHECK (expiry_date > issue_date),
    active BOOLEAN DEFAULT TRUE,
    created_at TIMESTAMP WITHOUT TIME ZONE DEFAULT CURRENT_TIMESTAMP
);

-- 7. license_categories_map — связь лицензии ↔ категории (одна лицензия может иметь несколько категорий)
CREATE TABLE license_categories_map (
    license_id INT NOT NULL REFERENCES driver_licenses(license_id) ON DELETE CASCADE ON UPDATE CASCADE,
    category_code VARCHAR(5) NOT NULL REFERENCES license_categories(category_code) ON DELETE RESTRICT ON UPDATE CASCADE,
    granted_date DATE,
    PRIMARY KEY (license_id, category_code)
);

-- 8. license_issuance — записи о выдаче прав (почему/кем/когда — журнал)
CREATE TABLE license_issuance (
    issuance_id SERIAL PRIMARY KEY,
    license_id INT NOT NULL REFERENCES driver_licenses(license_id) ON DELETE CASCADE,
    issuance_date DATE NOT NULL DEFAULT CURRENT_DATE,
    issuance_type VARCHAR(50) NOT NULL CHECK (issuance_type IN ('Первичное получение','После потери','После кражи','Обмен')),
    employee_id INT REFERENCES employees(employee_id) ON DELETE SET NULL,
    note TEXT
);

-- 9. license_renewals — переоформления/продления прав
CREATE TABLE license_renewals (
    renewal_id SERIAL PRIMARY KEY,
    license_id INT NOT NULL REFERENCES driver_licenses(license_id) ON DELETE CASCADE,
    renewal_date DATE NOT NULL DEFAULT CURRENT_DATE,
    new_expiry_date DATE NOT NULL,
    reason VARCHAR(60) NOT NULL CHECK (reason IN ('Окончание срока','Изменение данных','Повреждение','Другой')),
    employee_id INT REFERENCES employees(employee_id) ON DELETE SET NULL,
    CHECK (new_expiry_date > renewal_date)
);

-- 10. license_retests — пересдачи экзаменов (теория/практика)
CREATE TABLE license_retests (
    retest_id SERIAL PRIMARY KEY,
    license_id INT NOT NULL REFERENCES driver_licenses(license_id) ON DELETE CASCADE,
    exam_type VARCHAR(20) NOT NULL CHECK (exam_type IN ('Теоретический','Практический')),
    exam_date DATE NOT NULL DEFAULT CURRENT_DATE,
    result VARCHAR(20) NOT NULL CHECK (result IN ('Сдал','Не сдал')),
    examiner_id INT REFERENCES employees(employee_id) ON DELETE SET NULL,
    attempt_number INT NOT NULL DEFAULT 1,
    UNIQUE(license_id, exam_type, exam_date, attempt_number)
);

-- 11. license_suspensions — временная приостановка/аннулирование прав
CREATE TABLE license_suspensions (
    suspension_id SERIAL PRIMARY KEY,
    license_id INT NOT NULL REFERENCES driver_licenses(license_id) ON DELETE CASCADE,
    start_date DATE NOT NULL,
    end_date DATE,
    reason TEXT NOT NULL,
    imposed_by_employee INT REFERENCES employees(employee_id) ON DELETE SET NULL,
    CHECK (end_date IS NULL OR end_date >= start_date)
);

-- 12. license_reinstatements — восстановление/снятие приостановки
CREATE TABLE license_reinstatements (
    reinstatement_id SERIAL PRIMARY KEY,
    suspension_id INT NOT NULL REFERENCES license_suspensions(suspension_id) ON DELETE CASCADE,
    reinstatement_date DATE NOT NULL,
    employee_id INT REFERENCES employees(employee_id) ON DELETE SET NULL,
    note TEXT
);

-- 13. training_courses — курсы/автошколы (внутренние записи)
CREATE TABLE training_courses (
    course_id SERIAL PRIMARY KEY,
    course_name VARCHAR(120) NOT NULL,
    course_type VARCHAR(30) NOT NULL CHECK (course_type IN ('Теория','Практика','Комбинированный')),
    duration_hours INT NOT NULL CHECK (duration_hours > 0),
    provider VARCHAR(120)
);

-- 14. course_enrollments — запись водителя на курс / прохождение курса
CREATE TABLE course_enrollments (
    enrollment_id SERIAL PRIMARY KEY,
    course_id INT NOT NULL REFERENCES training_courses(course_id) ON DELETE RESTRICT,
    driver_id INT NOT NULL REFERENCES drivers(driver_id) ON DELETE CASCADE,
    enroll_date DATE NOT NULL DEFAULT CURRENT_DATE,
    completed BOOLEAN DEFAULT FALSE,
    completion_date DATE,
    UNIQUE(course_id, driver_id)
);

-- 15. exam_tests — шаблоны экзаменов (вопросы/практика) — справочник
CREATE TABLE exam_tests (
    test_id SERIAL PRIMARY KEY,
    test_name VARCHAR(120) NOT NULL,
    test_type VARCHAR(20) NOT NULL CHECK (test_type IN ('Теоретический','Практический')),
    max_score INT NOT NULL CHECK (max_score > 0)
);

-- 16. exam_attempts — попытки сдачи конкретного теста (можно связывать с license_retests)
CREATE TABLE exam_attempts (
    attempt_id SERIAL PRIMARY KEY,
    test_id INT NOT NULL REFERENCES exam_tests(test_id) ON DELETE RESTRICT,
    driver_id INT NOT NULL REFERENCES drivers(driver_id) ON DELETE CASCADE,
    attempt_date DATE NOT NULL DEFAULT CURRENT_DATE,
    score INT CHECK (score >= 0),
    passed BOOLEAN,
    examiner_id INT REFERENCES employees(employee_id) ON DELETE SET NULL
);

-- 17. vehicles — транспортные средства (если нужно связать с техосмотром и регистрацией)
CREATE TABLE vehicles (
    vehicle_id SERIAL PRIMARY KEY,
    vin VARCHAR(17) UNIQUE NOT NULL,
    registration_number VARCHAR(15) UNIQUE,
    brand VARCHAR(60),
    model VARCHAR(60),
    year INT CHECK (year >= 1886),
    owner_driver_id INT REFERENCES drivers(driver_id) ON DELETE SET NULL
);

-- 18. vehicle_registrations — регистрация ТС (связь с водителем и авто)
CREATE TABLE vehicle_registrations (
    reg_id SERIAL PRIMARY KEY,
    vehicle_id INT NOT NULL REFERENCES vehicles(vehicle_id) ON DELETE CASCADE,
    owner_driver_id INT NOT NULL REFERENCES drivers(driver_id) ON DELETE CASCADE,
    reg_date DATE NOT NULL DEFAULT CURRENT_DATE,
    registration_type VARCHAR(40) NOT NULL CHECK (registration_type IN ('Первичная','Перерегистрация','Снятие с учета','Временная регистрация')),
    registered_by INT REFERENCES employees(employee_id) ON DELETE SET NULL
);

-- 19. technical_inspections — техосмотры (связаны с vehicle_registrations и водителем)
CREATE TABLE technical_inspections (
    inspection_id SERIAL PRIMARY KEY,
    reg_id INT NOT NULL REFERENCES vehicle_registrations(reg_id) ON DELETE CASCADE,
    vehicle_id INT NOT NULL REFERENCES vehicles(vehicle_id) ON DELETE CASCADE,
    inspector_id INT REFERENCES employees(employee_id) ON DELETE SET NULL,
    inspection_date DATE NOT NULL DEFAULT CURRENT_DATE,
    result VARCHAR(20) NOT NULL CHECK (result IN ('Пройден','Не пройден')),
    next_due_date DATE,
    notes TEXT,
    CHECK (next_due_date IS NULL OR next_due_date > inspection_date)
);

-- 20. applications — заявления/запросы от водителя (заявления на выдачу, переоформление, регистрацию и т.д.)
CREATE TABLE applications (
    application_id SERIAL PRIMARY KEY,
    driver_id INT NOT NULL REFERENCES drivers(driver_id) ON DELETE CASCADE,
    application_type VARCHAR(60) NOT NULL CHECK (application_type IN ('Выдача прав','Переоформление прав','Пересдача экзамена','Регистрация ТС','Снятие с учета')),
    submitted_date DATE NOT NULL DEFAULT CURRENT_DATE,
    processed BOOLEAN DEFAULT FALSE,
    processed_date DATE,
    processed_by INT REFERENCES employees(employee_id) ON DELETE SET NULL,
    related_license_id INT REFERENCES driver_licenses(license_id) ON DELETE SET NULL,
    related_reg_id INT REFERENCES vehicle_registrations(reg_id) ON DELETE SET NULL,
    note TEXT
);

-- Дополнительные индексы (поиск по водителю/лицензии)
CREATE INDEX idx_driver_licenses_driver ON driver_licenses(driver_id);
CREATE INDEX idx_vehicle_reg_owner ON vehicle_registrations(owner_driver_id);
CREATE INDEX idx_techins_vehicle ON technical_inspections(vehicle_id);
