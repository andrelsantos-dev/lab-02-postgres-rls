GRANT USAGE ON SCHEMA public TO app_user;

GRANT SELECT
ON patients
TO app_user;

--
ALTER TABLE patients  
ENABLE ROW LEVEL SECURITY; 

--
CREATE POLICY patients_allow_all
ON patients
FOR SELECT
TO app_user
USING (true);