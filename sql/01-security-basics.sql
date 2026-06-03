CREATE ROLE app_user
LOGIN
PASSWORD 'app_password';

CREATE ROLE migration_user
LOGIN
PASSWORD 'migration_password';

CREATE ROLE readonly_user
LOGIN
PASSWORD 'readonly_password';