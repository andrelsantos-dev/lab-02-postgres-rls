--Tenants
INSERT INTO tenants (name)
VALUES
    ('Tenant A'),
    ('Tenant B');

SELECT * FROM tenants;

-- Patients
INSERT INTO patients (tenant_id, name)
VALUES
    ('tenant_id1', 'João'),
    ('tenant_id2', 'Maria');    

SELECT * FROM patients;


-- Appointments
INSERT INTO appointments (patient_id, description)
VALUES
    ('uuid-joao', 'Cardiologist'),
    ('uuid-joao', 'Follow-up'),
    ('uuid-maria', 'Orthopedic'),
    ('uuid-maria', 'Exam Review');

SELECT * FROM appointments;