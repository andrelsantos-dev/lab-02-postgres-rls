CREATE OR REPLACE FUNCTION get_patients_invoker()
RETURNS TABLE (
    id uuid,
    tenant_id uuid,
    name varchar
)
LANGUAGE sql
AS $$
    SELECT
        p.id,
        p.tenant_id,
        p.name
    FROM patients p;
$$;

--

GRANT EXECUTE
ON FUNCTION get_patients_invoker()
TO app_user;

--


CREATE OR REPLACE FUNCTION get_patients_definer2()
RETURNS TABLE (
    id uuid,
    tenant_id uuid,
    name varchar
)
LANGUAGE sql
SECURITY DEFINER
AS $$
    SELECT
        p.id,
        p.tenant_id,
        p.name
    FROM patients p;
$$;


GRANT EXECUTE
ON FUNCTION get_patients_definer2()
TO app_user;