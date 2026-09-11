# TransitCore Database

Hand-written T-SQL for SQL Server, run manually in SSMS (or `sqlcmd`). No ORM
migrations — these scripts are the source of truth for schema.

**Status: Identity slice only** (this is a work in progress, built alongside
the TransitCore.Api rewrite one domain slice at a time — see `/PLAN.md` at the
repo root for the full sequencing). Fleet/Ops/Billing schemas land in later
slices and will extend this README's ER diagram as they're added.

## Prerequisites

- SQL Server 2019+ (developed against SQL Server's current T-SQL surface;
  no version-specific syntax used beyond `STRING_AGG`, which needs 2017+).
- A database named `TransitCoreDb` must already exist:
  ```sql
  CREATE DATABASE TransitCoreDb;
  ```
- SSMS with **SQLCMD Mode** enabled (Query menu → SQLCMD Mode) if running
  `run-all.sql`, since it uses `:r` include directives. Alternatively, run
  each file in the order below individually — every script is idempotent, so
  re-running any of them is safe.

## Run order

```
01-schema/001_lookup_core.sql
01-schema/002_identity_schema.sql
02-programmability/001_identity_procs.sql
03-seed/001_lookup_seed.sql
03-seed/002_identity_seed.sql
```

Or just run `run-all.sql` from this folder in SQLCMD mode.

## Key strategy

`INT IDENTITY` on every table. Nothing in this system syncs across databases
or generates IDs client-side, so `UNIQUEIDENTIFIER` would only add index
bloat and worse join performance for no benefit here.

## Conventions

- Explicit schemas always (`identity.`, `lookup.`, and — in later slices —
  `fleet.`, `ops.`, `billing.`). Never unqualified/`dbo.` for business tables.
- Named constraints: `PK_Table`, `FK_Child_Parent`, `UQ_Table_Column`,
  `IX_Table_Column`, `CK_Table_Rule`, `DF_Table_Column` for defaults.
- Every business table has `CreatedAt`, `CreatedBy`, `ModifiedAt`,
  `ModifiedBy`, `IsDeleted` (soft delete).
- Every script is idempotent: `IF NOT EXISTS (...)` guards for
  tables/indexes/schemas, `DROP ... IF EXISTS` before `CREATE` for
  procedures, `MERGE` for seed data.
- No cascading deletes on anything that isn't a pure child-ownership
  relationship scoped to one aggregate (e.g. `UserRoles`/`RolePermissions`
  rows die with their `User`/`Role`, but a `Branch` is never deleted just
  because a `User` referencing it is).

## Password hashing

`identity.Users.PasswordHash`/`PasswordSalt` are PBKDF2-HMACSHA256 output
(100,000 iterations, 16-byte salt, 32-byte derived key), both stored as
Base64. The comparison happens in `TransitCore.Infrastructure.Security.PasswordHasher`
(.NET), not in T-SQL — `identity.usp_GetUserForLogin` only returns the stored
hash/salt for the app layer to verify. This keeps the hashing parameters easy
to change later without a database migration.

Demo users seeded by `03-seed/002_identity_seed.sql` (local/dev only —
rotate before using in any shared environment):

| Email | Password | Role |
|---|---|---|
| admin@transitcore.local | Admin@123 | Admin |
| manager@transitcore.local | Manager@123 | Manager |
| ops@transitcore.local | User@123 | User |

## ER diagram (current slice)

```mermaid
erDiagram
    REGIONS ||--o{ BRANCHES : "has"
    REGIONS ||--o{ USERS : "assigned to"
    DESIGNATIONS ||--o{ USERS : "assigned to"
    WORKING_DESIGNATIONS ||--o{ USERS : "assigned to"
    USERS ||--o{ USER_ROLES : "has"
    ROLES ||--o{ USER_ROLES : "granted to"
    ROLES ||--o{ ROLE_PERMISSIONS : "grants"
    PERMISSIONS ||--o{ ROLE_PERMISSIONS : "granted via"
    USERS ||--o{ USER_BRANCHES : "assigned to"
    BRANCHES ||--o{ USER_BRANCHES : "staffed by"
    USERS ||--o{ REFRESH_TOKENS : "issues"

    REGIONS {
        int Id PK
        nvarchar Name
    }
    BRANCHES {
        int Id PK
        nvarchar Name
        int RegionId FK
    }
    DESIGNATIONS {
        int Id PK
        nvarchar Code
        nvarchar Name
    }
    WORKING_DESIGNATIONS {
        int Id PK
        nvarchar Name
    }
    USERS {
        int Id PK
        nvarchar Email
        nvarchar PasswordHash
        nvarchar PasswordSalt
        nvarchar DisplayName
        int DesignationId FK
        int WorkingDesignationId FK
        int RegionId FK
        bit IsActive
    }
    ROLES {
        int Id PK
        nvarchar Name
    }
    PERMISSIONS {
        int Id PK
        nvarchar Name
    }
    ROLE_PERMISSIONS {
        int RoleId PK_FK
        int PermissionId PK_FK
    }
    USER_ROLES {
        int UserId PK_FK
        int RoleId PK_FK
    }
    USER_BRANCHES {
        int UserId PK_FK
        int BranchId PK_FK
    }
    REFRESH_TOKENS {
        int Id PK
        int UserId FK
        nvarchar TokenHash
        datetime2 ExpiresAt
        datetime2 RevokedAt
    }
