## Phase 00 - PostgreSQL Security Basics

### Objective

Understand PostgreSQL identities and permission evaluation before implementing Row Level Security (RLS).
These concepts are essential to understand how PostgreSQL evaluates access permissions and RLS policies.

### Topics

- Roles
- Login Roles
- current_user
- session_user
- SET ROLE
- RESET ROLE
- Superuser
- BYPASSRLS

### Experiments

#### Initial session

```sql

rls_lab=# SELECT current_user;
 current_user 
--------------
 postgres
(1 row)

rls_lab=# SELECT session_user;
 session_user 
--------------
 postgres
(1 row)

```

**Observation**

Both `current_user` and `session_user` are `postgres` because the session was opened using the PostgreSQL superuser.

#### Assume role

```sql

rls_lab=# SET ROLE app_user;

rls_lab=> SELECT current_user;
 current_user 
--------------
 app_user
(1 row)

rls_lab=> SELECT session_user;

 session_user 
--------------
 postgres
(1 row)

```
**Observation**

`SET ROLE` changes the effective identity (`current_user`) while preserving the original session identity (`session_user`).

**Note**

The psql prompt changed from:

```text
rls_lab=#
```

to:

```text
rls_lab=>
```

after `SET ROLE app_user`, indicating a different execution context.


#### Reset role

```sql

rls_lab=> RESET ROLE;

rls_lab=# SELECT current_user;
SELECT session_user;
 current_user 
--------------
 postgres
(1 row)

 session_user 
--------------
 postgres
(1 row)

```
**Observation**

`RESET ROLE` restores the original session role, causing `current_user`
to become `postgres` again.

The psql prompt also changes back from:

```text
rls_lab=>
```

to:

```text
rls_lab=#
```

indicating that the session returned to its original execution context.

### Key Learnings

- A PostgreSQL role can represent either a user or a group of permissions.
- `session_user` is the identity that opened the connection.
- `current_user` is the effective identity used for permission checks.
- `SET ROLE` changes the effective identity without changing the session identity.
- `RESET ROLE` restores the original session role.
- PostgreSQL superusers bypass Row Level Security (RLS) by default.
- Superusers should not be used to validate tenant isolation behavior.
